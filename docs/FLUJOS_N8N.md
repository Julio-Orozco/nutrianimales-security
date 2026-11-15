# Flujos n8n: qué hacer con los 18 JSON

Para: integrantes 3 (monitoreo: R1–R5, H1–H5) y 4 (bot y datos: B0, D1–D7).

## Situación actual

Los 18 archivos de `n8n/workflows/` vienen de una versión anterior del proyecto que usaba un servicio en **Python** llamado `monitor`. **El proyecto no usa Python**, así que ese servicio no existe ni se va a crear. En todos los flujos los nodos HTTP llaman a `http://monitor:8000/...`, por lo que **ninguno funciona tal como está**.

Cada flujo de detección (R, H, D) tiene esta forma:

```text
[Cada 30 segundos] ─┐
                    ├─> [Detectar XX: HTTP a monitor] ─> [Hay hallazgo: IF] ─> [Notificar XX: HTTP a monitor]
[Prueba manual] ────┘
```

## Decisión por flujo

| Flujo | Qué hacer | Por qué |
|---|---|---|
| R1, R2, R3, R5 | **Modificar** | La detección se resuelve con SQL contra PostgreSQL. |
| H2, H3, H4, H5 | **Modificar** | Ídem; H2, H3 y H5 usan la función existente `security_snapshot()`. |
| D1–D7 | **Modificar** | Ídem; D1 y D6 usan la tabla `auditoria_sentencias`, que ya llenan los triggers. |
| R4 | **Rehacer** | Requiere leer logs (fallos de autenticación de PostgreSQL y SSH), no se obtiene por SQL. |
| H1 | **Rehacer** | Requiere leer el estado de UFW del host; hoy no existe esa fuente en WSL. |
| B0 | **Rehacer** | Era el bot de Telegram en Python; debe construirse con nodos de n8n (Telegram y Groq). |

«Modificar» significa conservar el disparador, la prueba manual, el IF y las notas, y **reemplazar solo los dos nodos HTTP**.

## Cómo modificar un flujo de detección (los 15 casos «Modificar»)

### 1. Crear la credencial de PostgreSQL (una vez, en n8n)

*Credentials → Add credential → Postgres*:

| Campo | Valor |
|---|---|
| Host | `postgres` |
| Database | `nutrianimales` |
| User | `monitor_db` |
| Password | el valor de `MONITOR_PASSWORD` de **su** `.env` |
| Port | `5432` |
| SSL | `Require` |

- **No** activar «Ignore SSL Issues» ni usar `postgres` u otra cuenta: `monitor_db` ya tiene exactamente los permisos necesarios (lectura, `pg_monitor`, `security_snapshot()` e inserción/actualización solo en `alertas_auditoria`).
- PostgreSQL rechaza conexiones sin TLS (`pg_hba.conf`). El contenedor n8n confía en el certificado del laboratorio mediante `NODE_EXTRA_CA_CERTS=/run/pg-ca/server.crt` (en `compose.yaml`), por lo que la prueba de la credencial con `SSL: Require` da «Connection successful» sin ignorar errores SSL. Verificado el 14/11/2026.
- En la instalación oficial ya existen las credenciales `Nutri Postgres monitor_db`, `Nutri Telegram bot` y `Nutri Groq` (las tres probadas con OK). Al importar los flujos allí, asignar esas. El `chat_id` del grupo «Alertas NutriAnimales» está en `TELEGRAM_CHAT_ID` del `.env`.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` impide leer `.env` desde los nodos: la contraseña y los tokens se escriben en la credencial, nunca en el JSON ni en un nodo.

### 2. Reemplazar «Detectar XX»

Borrar el nodo HTTP y poner un nodo **Postgres → Execute Query** con la credencial anterior y la consulta de la tabla de reglas (sección 4). Cada consulta devuelve filas solo cuando hay hallazgo (o una columna `detectado`).

### 3. Ajustar «Hay hallazgo»

- Para consultas que devuelven filas solo con hallazgo: activar en el nodo Postgres *Settings → Always Output Data* y en el IF comprobar que el resultado no esté vacío (por ejemplo `{{ $json.id }}` / la columna clave *is not empty*).
- Para consultas con columna `detectado`: `{{ $json.detectado }}` *is true* (como está ahora con `detected`).

### 4. Reemplazar «Notificar XX» por dos nodos

1. **Postgres → Execute Query**: registrar la alerta sin duplicarla.

   ```sql
   INSERT INTO alertas_auditoria (tipo, alerta, mensaje, detalles, severidad, huella)
   VALUES ('rendimiento', 'R1', 'Consulta lenta detectada', '{{ JSON.stringify($json) }}'::jsonb, 'media',
           'R1-{{ $json.queryid }}')
   ON CONFLICT (huella) DO NOTHING
   RETURNING id;
   ```

   La `huella` identifica el hallazgo (regla + dato que lo distingue): si ya existe, no se inserta ni se notifica otra vez. Usar parámetros de consulta (*Query Parameters*) en lugar de interpolar texto cuando el valor venga de datos de usuarios.

2. **Telegram → Send Message** (credencial Telegram con el token del bot), solo si el paso anterior devolvió `id`. Después, opcionalmente, `UPDATE alertas_auditoria SET estado='enviada', enviada_en=now() WHERE id = ...`.

`tipo` sugerido: `rendimiento` (R), `hardening` (H), `datos` (D). Severidad: `alta` para H3, H5, D1, D6 y D7; `media` para el resto (ajustable por el equipo).

## Consultas de detección (probadas como `monitor_db`)

Todas se ejecutaron el 14/11/2026 autenticadas como `monitor_db` por TLS y funcionan con los permisos actuales.

| Regla | Consulta | Hay hallazgo si… | Huella sugerida |
|---|---|---|---|
| R1 Consulta lenta | `SELECT queryid, calls, round(mean_exec_time) AS ms_promedio, left(query,200) AS consulta FROM pg_stat_statements WHERE mean_exec_time > 1000 AND query NOT ILIKE '%pg_stat_statements%' ORDER BY mean_exec_time DESC LIMIT 5;` | devuelve filas | `R1-<queryid>-<calls>` |
| R2 Conexiones activas | `SELECT count(*) AS activos, count(*) > 10 AS detectado FROM pg_stat_activity WHERE backend_type='client backend' AND state='active';` | `detectado = true` | `R2-<fecha hasta el minuto>` |
| R3 Fuera de horario | `SELECT pid, usename, client_addr, backend_start FROM pg_stat_activity WHERE backend_type='client backend' AND usename IS NOT NULL AND (extract(hour FROM now() AT TIME ZONE 'America/Costa_Rica') >= 23 OR extract(hour FROM now() AT TIME ZONE 'America/Costa_Rica') < 6);` | devuelve filas | `R3-<pid>-<backend_start>` |
| R5 Configuración modificada | `SELECT b.name, b.valor_esperado, s.setting, s.pending_restart FROM pg_settings_baseline b JOIN pg_settings s USING(name) WHERE b.valor_esperado <> s.setting OR s.pending_restart;` | devuelve filas | `R5-<name>-<setting>` |
| H2 Archivo PostgreSQL modificado | `SELECT security_snapshot() -> 'hashes' AS hashes;` y comparar con los hashes guardados la primera vez (por ejemplo en una fila de `eventos_seguridad` mediante `registrar_evento`) | algún hash cambia | `H2-<hash nuevo>` |
| H3 Permisos indebidos a agente_ia | `SELECT security_snapshot() -> 'privilegios_agente' AS p;` | `superuser`, `createrole`, `createdb` o `create_schema` es `true`, o `escritura` no es `[]` | `H3-<contenido de p>` |
| H4 Origen fuera de red | `SELECT pid, usename, client_addr FROM pg_stat_activity WHERE client_addr IS NOT NULL AND NOT (client_addr <<= inet '172.20.0.0/16');` (confirmar la subred con `sh scripts/capturas-ab.sh A3`) | devuelve filas | `H4-<pid>-<client_addr>` |
| H5 Autenticación/TLS degradados | `SELECT name, setting FROM pg_settings WHERE (name='ssl' AND setting<>'on') OR (name='password_encryption' AND setting<>'scram-sha-256') UNION ALL SELECT 'hba_md5', 'true' WHERE (security_snapshot()->>'hba_md5')::boolean;` | devuelve filas | `H5-<name>-<setting>` |
| D1 DELETE masivo | `SELECT id, tabla, usuario, filas, fecha FROM auditoria_sentencias WHERE operacion='DELETE' AND filas > 100 AND fecha > now() - interval '10 minutes';` | devuelve filas | `D1-<id>` |
| D2 Crecimiento anormal | `SELECT count(*) FILTER (WHERE operacion='INSERT' AND fecha > now() - interval '30 minutes') AS nuevas, (SELECT count(*) FROM ventas) AS total FROM auditoria_datos WHERE tabla='ventas';` | `nuevas > 0.2 × (total − nuevas)` (calcular en el IF o en el SQL) | `D2-<fecha hasta 30 min>` |
| D3 Backup obsoleto | `SELECT max(fecha) AS ultimo_ok, coalesce(max(fecha) < now() - interval '24 hours', true) AS detectado FROM backups WHERE estado='ok';` | `detectado = true` | `D3-<fecha del día>` |
| D4 Duplicados | `SELECT correo, count(*) AS repeticiones FROM clientes GROUP BY correo HAVING count(*) > 5;` | devuelve filas | `D4-<correo>-<repeticiones>` |
| D5 Transacción bloqueada | `SELECT pid, usename, pg_blocking_pids(pid) AS bloqueado_por, now() - query_start AS espera FROM pg_stat_activity WHERE wait_event_type='Lock' AND now() - query_start > interval '30 seconds';` | devuelve filas | `D5-<pid>-<query_start>` |
| D6 UPDATE masivo | `SELECT id, tabla, usuario, filas, fecha FROM auditoria_sentencias WHERE operacion='UPDATE' AND filas > 50 AND fecha > now() - interval '10 minutes';` | devuelve filas | `D6-<id>` |
| D7 Posible exfiltración | `SELECT queryid, calls, rows, left(query,200) AS consulta FROM pg_stat_statements WHERE rows > 1000 AND query ~* '\m(clientes\|ventas)\M' ORDER BY rows DESC LIMIT 5;` | devuelve filas | `D7-<queryid>-<rows>` |

Notas:

- **D7 genera falsos positivos con los respaldos.** En la prueba detectó el `pg_dump` del respaldo (`COPY public.clientes ... TO stdout`). Excluir esas consultas (`AND query NOT ILIKE 'COPY %'` o filtrar por `userid` de `backup_db`) y documentarlo.
- `pg_stat_statements` es **acumulado**: R1 y D7 reportan un hallazgo nuevo cuando cambian `calls`/`rows` (por eso la huella los incluye). Para «solo ejecuciones nuevas», guardar el último valor visto.
- D1/D6 usan los triggers por sentencia de la parte B: solo cubren `productos`, `lotes_produccion`, `ventas` y `clientes`.
- Las descripciones originales mencionaban «AST SQL» (análisis con una librería de Python); con SQL no se analiza la sentencia, se mide su efecto (filas afectadas). Explicarlo así en el informe.

## Flujos que hay que rehacer

### B0 — Bot de Telegram (integrante 4)

Construirlo desde cero en n8n, sin el servicio `monitor`:

- Recepción: el nodo *Telegram Trigger* necesita una URL HTTPS pública (webhook) y el laboratorio solo escucha en `127.0.0.1`. La alternativa sin exponer nada es un *Schedule Trigger* + *HTTP Request* a `https://api.telegram.org/bot<token>/getUpdates` con `offset` (guardar el último `update_id`).
- Autorizar el chat (lista de `chat_id` permitidos) **antes** de consultar datos.
- Consultas: credencial Postgres con `agente_ia` (solo lectura, `statement_timeout` 5 s) y **solo SQL fijo** sobre `reporte_ventas`, `reporte_inventario` y `reporte_produccion`. Nunca ejecutar SQL generado por el usuario ni por la IA.
- Groq: nodo *Groq Chat Model* / *HTTP Request* con la credencial de Groq para **resumir** el resultado, no para generar SQL.
- Los tokens van en credenciales de n8n, no en el JSON ni en Git.

### R4 — Autenticaciones fallidas (integrante 3)

Los fallos de autenticación solo quedan en los logs de PostgreSQL (`/var/log/postgresql/*.json`) y de SSH; no hay vista SQL. Opciones a decidir con el integrante A:

1. Montar los logs de PostgreSQL en n8n en solo lectura y leerlos con *Read/Write Files from Disk* + *Extract From File*. **Conflicto con A10**: desde la revisión 2 los logs tienen modo `600` (solo el usuario `postgres`) para que no los lea cualquiera; habilitar la lectura exige acordar un grupo compartido (por ejemplo `log_file_mode = 0640`) y documentarlo como excepción justificada.
2. Usar Filebeat (ya está en el stack) para leer los logs y enviarlos a un webhook de n8n.

No cambiar los permisos de A10 sin coordinarlo.

### H1 — Reglas UFW (integrante 3)

Depende de una fuente de UFW en el host. Hoy, en WSL, `/var/log/ufw.log` es un directorio vacío creado por Docker (no hay UFW con registro activo). Pasos previos: habilitar UFW y su registro (rsyslog) en Ubuntu, eliminar ese directorio vacío y recrear Filebeat. Después, calcular el hash de `ufw status numbered` o de `/etc/ufw/*.rules` desde una tarea del host (shell/cron, sin Python) y entregarlo a n8n (webhook o archivo montado en solo lectura).

## Cómo guardar los flujos en Git

1. Construir y probar el flujo en el editor (botón *Prueba manual*), provocando el hallazgo real (por ejemplo `SELECT pg_sleep(1.3);` para R1).
2. Exportarlo: menú del flujo → *Download*, o
   `docker compose exec -T n8n n8n export:workflow --id=<ID> --output=/tmp/R1.json && docker compose cp n8n:/tmp/R1.json n8n/workflows/R1.json`.
3. Revisar que el JSON **no contenga tokens ni contraseñas** (las credenciales se exportan solo como referencia de nombre/id) y hacer commit en su rama.
4. Para importarlos en otra computadora: `docker compose cp n8n/workflows n8n:/tmp/workflows && docker compose exec -T n8n n8n import:workflow --separate --input=/tmp/workflows` y luego reasignar las credenciales en cada nodo.

## Qué no se debe hacer

- No crear servicios ni scripts en Python.
- No usar el superusuario `postgres` ni dar más permisos a `monitor_db`/`agente_ia` para que un flujo funcione; si falta un permiso, coordinarlo con el integrante B.
- No desactivar SSL ni activar «Ignore SSL Issues».
- No declarar una regla como funcional sin haber provocado el hallazgo y visto la alerta en `alertas_auditoria` y en Telegram.
