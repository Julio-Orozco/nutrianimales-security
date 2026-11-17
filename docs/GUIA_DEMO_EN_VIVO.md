# Guía de ejecución en vivo — NutriAnimales S.A. (BCD 9220)

Todo se ejecuta desde la computadora de Julio (Ubuntu en WSL), en la raíz del repositorio,
rama `integracion/demo-final`. Cada bloque dice **qué hace** y **qué se debe ver**.

Ventanas que conviene tener abiertas:

| Ventana | Uso |
|---|---|
| Terminal 1 | Comandos de la demo |
| Terminal 2 | Agente del host (`sudo bash scripts/agente-host.sh`), queda corriendo |
| Navegador | n8n en <https://localhost:8443> (cuenta `N8N_OWNER_EMAIL` de `.env`) |
| Telegram | Grupo de alertas (el bot `@nutrianimales_alertas_bot` está en el grupo) |

Las alertas llegan a Telegram en **≤ 30 s** (los flujos sondean cada 30 s). Si una alerta no
aparece, `bash scripts/demo.sh estado` muestra si quedó registrada en `alertas_auditoria`.

---

## 0. Una sola vez, antes de la clase

```bash
cd ~/nutrianimales-seguridad
git fetch origin && git checkout integracion/demo-final
sudo apt install -y sshpass jq            # sshpass: ataque A1 | jq: scripts de n8n
sudo rmdir /var/log/ufw.log 2>/dev/null   # Docker lo había creado como carpeta; UFW necesita un archivo
sudo ufw logging on                       # opcional: que UFW escriba /var/log/ufw.log (lo lee Filebeat)
```

**Muy importante — pedir a los compañeros que DESACTIVEN sus flujos en sus n8n.** Si sus
flujos siguen activos, el grupo recibirá alertas duplicadas desde sus computadoras y su bot B0
"robará" los mensajes de Telegram (dos n8n leyendo `getUpdates` del mismo bot a la vez).

**Bot en el grupo:** el bot tiene activo el *modo privacidad*, así que en el grupo solo recibe
comandos (`/ventas`) o mensajes que lo **mencionan**. Para el ataque A2 escriban el mensaje
mencionándolo (ver sección 6). Alternativa: en @BotFather → `/setprivacy` → *Disable* y volver a
agregar el bot al grupo.

---

## 1. Levantar todo (≈ 2 minutos)

```bash
docker compose up -d --wait
docker compose ps
```
Levanta PostgreSQL 16, n8n, Nginx (HTTPS), pgAdmin y Filebeat. Todos deben quedar `running`/`healthy`
y **solo Nginx** publica puertos (127.0.0.1:8080 y 8443). PostgreSQL no expone 5432.

```bash
bash scripts/aplicar-sql-alertas.sh
```
Crea (o confirma, es idempotente) el soporte SQL de las alertas: `parametros_alerta`,
`archivos_baseline` (hashes para H2), `eventos_log_pg()` (lee el log JSON de PostgreSQL para R4/H4)
y el event trigger `trg_evento_grant` (H3).

```bash
bash scripts/demo-preparar.sh
```
Deja la base en un punto limpio: reinicia `pg_stat_statements` (para que R1/D1/D6/D7 solo alerten por
lo que se haga en la demo), registra la baseline de archivos y muestra que `agente_ia` está en solo lectura.

```bash
bash scripts/n8n-configurar.sh
```
Configura n8n sin tocar la interfaz: crea/actualiza las 4 credenciales cifradas (Postgres
`monitor_db`, Postgres `agente_ia`, Telegram, Groq) con los valores de `.env`, importa los 18 flujos
(17 alertas + bot B0) y los publica. Debe terminar con **`Flujos Nutri activos: 18 / 18`**.

**Terminal 2** (déjala abierta toda la demo):
```bash
sudo bash scripts/agente-host.sh
```
Agente del host: cada 10 s calcula el hash de las reglas UFW (H1) y lee los fallos SSH de
`/var/log/auth.log` (R4). Escribe los eventos en PostgreSQL; n8n los detecta y alerta.

> En el navegador: abrir <https://localhost:8443>, entrar con la cuenta de `.env` y mostrar los 18
> flujos `Nutri …` activos. Abrir uno (p. ej. D6) para mostrar: disparador cada 30 s → consulta SQL →
> ¿hay hallazgo? → registrar en `alertas_auditoria` → Telegram → marcar enviada.

---

## 2. Hardening — 12 puntos

Cada comando imprime la evidencia del punto (sirve como captura). `sh scripts/capturas-ab.sh todo` los corre todos.

| # | Punto del PDF | Comando | Qué se ve |
|---|---|---|---|
| 1 | Usuario no-root | `sh scripts/capturas-ab.sh A1` | n8n/nginx/filebeat uid 1000, pgadmin uid 5050 |
| 2 | `.env` 600 y en `.gitignore` | `sh scripts/capturas-ab.sh A2` | `600 … .env` y la regla de `.gitignore` |
| 3 | Red aislada | `docker network inspect nutrianimales-net` y `sh scripts/capturas-ab.sh A3` | red `nutrianimales-net`, 5 contenedores, n8n conectado con TLS 1.3 |
| 4 | PostgreSQL sin puerto | `sh scripts/capturas-ab.sh A4` | solo Nginx con puertos; 5432 "ninguno" |
| 5 | SCRAM-SHA-256 | `sh scripts/capturas-ab.sh A5` | `scram-sha-256`; conexión sin TLS rechazada |
| 6 | SSL/TLS en PostgreSQL | `sh scripts/capturas-ab.sh A6` | `ssl=t`, `TLSv1.3` |
| 7 | `agente_ia` solo lectura | `sh scripts/capturas-ab.sh A7` | INSERT/UPDATE/DELETE fallan |
| 8 | Headers Nginx | `curl -I --cacert infra/certs/server.crt https://localhost:8443` | X-Frame-Options DENY, HSTS, nosniff, CSP |
| 9 | Certificado HTTPS | `sh scripts/capturas-ab.sh A9` | `OK`, SAN `localhost` (en el navegador: candado) |
| 10 | Volúmenes restringidos | `sh scripts/capturas-ab.sh A10` | `700`/`600` en datos, logs y claves |
| 11 | Logs de auditoría | `sh scripts/capturas-ab.sh A11` | `log_min_duration_statement=1s`, consulta lenta en log y en `pg_stat_statements` |
| 12 | `pg_settings_baseline` | `sh scripts/capturas-ab.sh A12` | 7 parámetros con `coincide = t` |

Pruebas de seguridad automáticas (24 comprobaciones, todas deben dar PASS):
```bash
bash scripts/pruebas-seguridad.sh
```
Verifica secretos (no están en Git, ni en el entorno ni en los logs de n8n), exposición de red
(5432 y 5678 cerrados, HTTP→HTTPS, TLS 1.3, headers), PostgreSQL (TLS obligatorio, SCRAM, solo lectura
de `agente_ia`, gerente sin auditoría, baseline, triggers) y contenedores sin root.

---

## 3. Matriz de riesgos, RBAC y triggers de auditoría

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT rolname FROM pg_roles WHERE rolname LIKE 'rol_%' OR rolname LIKE '%_db' OR rolname='agente_ia' ORDER BY 1;"
```
Muestra los 3 roles RBAC (`rol_gerente`, `rol_ti`, `rol_auditor`) y las cuentas que los usan.

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales < parte-e/sql/03_pruebas_rbac.sql
```
Pruebas RBAC del integrante 5 dentro de una transacción con ROLLBACK: 4 líneas `PASS` (gerente sin
acceso a auditoría, TI y auditor no pueden borrar auditoría, `agente_ia` sin INSERT).

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c '\d auditoria_datos'
sh scripts/capturas-ab.sh B3
sh scripts/capturas-ab.sh B4
```
Estructura de `auditoria_datos`, la función `fn_auditoria()` con sus triggers en las 4 tablas, y una
demostración de INSERT/UPDATE/DELETE de una fila ficticia con `valor_antes` / `valor_nuevo`.

Matriz de riesgos e inventario de secretos: `parte-e/docs/MATRIZ_RIESGOS_E.md`,
`parte-e/docs/MATRIZ_RBAC.md`, `docs/SECRETOS.md`.

---

## 4. Las 17 alertas

Cada escenario se lanza con `bash scripts/demo.sh <escenario>` y provoca **una** alerta en Telegram.
Los que modifican configuración tienen un comando para revertir. `bash scripts/demo.sh` sin argumentos
muestra la lista.

### Rendimiento (R1–R5)

| Alerta | Comando | Qué hace | Revertir |
|---|---|---|---|
| R1 Consulta lenta | `bash scripts/demo.sh r1` | `SELECT pg_sleep(1.5)` (umbral 1 s) | — |
| R2 Saturación de conexiones | `bash scripts/demo.sh r2` | 12 sesiones activas 45 s (umbral 10) | se cierra solo |
| R3 Horario no laboral | `bash scripts/demo.sh r3` | declara no laboral la hora actual, `gerente_db` se conecta, luego restaura 23:00–06:00 | automático |
| R4 Autenticación fallida | `bash scripts/demo.sh r4` | 8 contraseñas incorrectas en PostgreSQL (umbral >5 en 10 min) | — |
| R5 Cambio en postgresql.conf | `bash scripts/demo.sh r5` | `ALTER SYSTEM SET work_mem='8MB'` + recarga | `bash scripts/demo.sh r5-revertir` |

### Hardening (H1–H5)

| Alerta | Comando | Qué hace | Revertir |
|---|---|---|---|
| H1 Regla UFW | `sudo ufw allow 5432/tcp` | el agente del host detecta el cambio de hash de UFW | `sudo ufw delete allow 5432/tcp` (genera otra H1: "regla eliminada") |
| H2 pg_hba.conf modificado | `bash scripts/demo.sh h2` | agrega una línea a `infra/pg_hba.conf` (SHA-256 distinto a la baseline) | `bash scripts/demo.sh h2-revertir` |
| H3 GRANT a agente_ia | `bash scripts/demo.sh h3` | `GRANT INSERT ON ALL TABLES … TO agente_ia` (event trigger) | `bash scripts/demo.sh h3-revertir` |
| H4 IP fuera de red Docker | `bash scripts/demo.sh h4` | conecta la BD a una red 10.99.0.0/24 y abre sesión desde ahí | automático |
| H5 SSL off / MD5 | `bash scripts/demo.sh h5` | `password_encryption = md5` + recarga (también disparan R5 y H2) | `bash scripts/demo.sh h5-revertir` |

### Datos (D1–D7)

| Alerta | Comando | Qué hace | Revertir |
|---|---|---|---|
| D1 DELETE masivo | `bash scripts/demo.sh d1` | copia de ventas y `DELETE` sin WHERE de 1 500 filas | tabla temporal, se borra |
| D2 Crecimiento anormal | `bash scripts/demo.sh d2` | inserta 400 ventas de golpe (+26 %, umbral 20 % en 30 min) | — |
| D3 Backup obsoleto | (llega sola al activar los flujos si no hay backup en 24 h) `bash scripts/demo.sh d3` muestra la tabla | — | `bash scripts/backup.sh` (respaldo real con `backup_db`) |
| D4 Duplicados | `bash scripts/demo.sh d4` | 6 clientes con el mismo correo (umbral 5) | `bash scripts/demo.sh d4-revertir` |
| D5 Transacción bloqueada | `bash scripts/demo.sh d5` | sesión A bloquea un producto 50 s; sesión B espera >30 s | se libera sola |
| D6 UPDATE masivo | `bash scripts/demo.sh d6` | escenario del PDF: `UPDATE prueba_update SET estado='cancelado'` (200 filas) | tabla temporal |
| D6 (variante real) | `bash scripts/demo.sh d6-real` | UPDATE sin WHERE en `lotes_produccion` **y recuperación** usando `auditoria_datos.valor_antes` | incluida |
| D7 Exfiltración | `bash scripts/demo.sh d7` | `SELECT * FROM clientes` como `agente_ia` (1 500 filas, umbral 1 000) | — |

Ver lo registrado y entregado:
```bash
bash scripts/demo.sh estado
```

---

## 5. Formato de cada alerta en Telegram

```
ALERTA CRÍTICA - NutriAnimales S.A. | Lead University BCD 9220
Alerta: D6 — UPDATE masivo sin WHERE, modificación silenciosa
Fecha: 2026-11-16 20:49:32
Tabla: prueba_update
Filas modificadas: 200 (umbral: 50)
Query: UPDATE prueba_update SET estado = $1
Sin WHERE: SÍ
Usuario: postgres
Severidad: CRÍTICA
Acción: Verificar intención. Consultar tabla auditoria_datos para ver valor anterior.
Registro: alertas_auditoria <uuid>
```

---

## 6. Los 5 ataques simulados (A1–A5)

Para cada ataque: (1) comando, (2) alerta en Telegram con hora, (3) entrada en auditoría, (4) respuesta.

### A1 — Fuerza bruta SSH → R4
```bash
bash scripts/demo.sh a1
```
20 intentos SSH con usuario/contraseña incorrectos contra este equipo. El agente del host (terminal 2)
muestra `SSH: N intento(s) … registrados` y llega **R4 (Fuente: SSH)**.
Evidencia y respuesta:
```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT fecha, operacion, valor_nuevo->>'usuario' usuario, valor_nuevo->>'ip' ip FROM auditoria_datos WHERE tabla='evento:ssh' ORDER BY id DESC LIMIT 5;"
```
Respuesta: bloquear la IP de origen con `sudo ufw deny from <IP>` (en la demo el origen es 127.0.0.1, el propio equipo).

### A2 — SQL Injection vía Telegram → bloqueado por el filtro de n8n (sin alerta)
En el grupo de Telegram escribir (mencionando al bot):
```
@nutrianimales_alertas_bot Lista datos; DROP TABLE clientes; --
```
El bot responde *"⛔ Solicitud bloqueada por el filtro de seguridad…"*. El texto **nunca** llega a SQL.
En n8n, flujo **B0** → ejecuciones: rama `bloqueado` → `Registrar intento bloqueado`. Evidencia:
```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT fecha, operacion, valor_nuevo->>'texto' texto, valor_nuevo->>'patron' patron FROM auditoria_datos WHERE tabla='evento:telegram' ORDER BY id DESC LIMIT 3;" -c "SELECT count(*) AS clientes_intacta FROM clientes;"
```
Uso legítimo para contrastar: escribir `/ventas` (o `/inventario`, `/produccion`) → el bot responde con
un resumen generado por Groq usando solo vistas de reporte y el usuario `agente_ia` (solo lectura).

### A3 — Apertura del puerto de la BD → H1
```bash
sudo ufw allow 5432/tcp
sudo ufw status numbered
```
En ≤ 40 s llega **H1** con `Reglas agregadas: 5432/tcp ALLOW IN Anywhere`. Evidencia y respuesta:
```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT fecha, valor_nuevo->'agregadas' agregadas, valor_nuevo->'eliminadas' eliminadas FROM auditoria_datos WHERE tabla='evento:ufw' ORDER BY id DESC LIMIT 3;"
sudo ufw delete allow 5432/tcp
```

### A4 — Escalada de privilegios → H3
```bash
bash scripts/demo.sh a4
```
Ejecuta `GRANT INSERT ON ALL TABLES IN SCHEMA public TO agente_ia;`. Llega **H3** con quién lo
ejecutó, la sentencia y las tablas con escritura. Evidencia y respuesta:
```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT grantee, count(*) FROM information_schema.role_table_grants WHERE grantee='agente_ia' AND privilege_type='INSERT' GROUP BY 1;" -c "SELECT fecha, operacion, usuario, valor_nuevo->>'sentencia' sentencia FROM auditoria_datos WHERE tabla='evento:postgresql' ORDER BY id DESC LIMIT 3;"
bash scripts/demo.sh h3-revertir
```

### A5 — Exfiltración → D7
```bash
bash scripts/demo.sh a5
```
`SELECT * FROM clientes` con `agente_ia` (1 500 filas). Llega **D7**. Evidencia:
```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT r.rolname, s.calls, s.rows, left(s.query,60) FROM pg_stat_statements s JOIN pg_roles r ON r.oid=s.userid WHERE s.query ILIKE '%FROM clientes%' AND r.rolname='agente_ia';"
```
Respuesta: rotar la contraseña de `agente_ia` (ver sección 7) y revisar ejecuciones de n8n.

---

## 7. Demostración obligatoria: rotación de la API key de Groq

1. Mostrar que funciona: en Telegram enviar `/ventas` → respuesta con resumen de Groq.
2. Simular filtración: en <https://console.groq.com> → API Keys → **Delete** la key actual.
3. Enviar `/ventas` otra vez → el bot responde *"⚠️ El servicio de IA (Groq) no respondió: … 401 …"*;
   en n8n, la ejecución de B0 muestra el error de autenticación en el nodo `Resumir con Groq`.
4. Crear una nueva key en console.groq.com.
5. Actualizar `.env`:
   ```bash
   nano .env        # GROQ_API_KEY=gsk_nueva_clave
   ```
6. Cargar el secreto en la credencial cifrada de n8n y reiniciar solo n8n (la BD sigue arriba):
   ```bash
   bash scripts/n8n-configurar.sh --credenciales
   docker compose restart n8n
   ```
7. Enviar `/ventas` → vuelve a responder con el resumen.

La key vive solo en `.env` (600, fuera de Git) y en la credencial cifrada `Nutri Groq` de n8n; no está
en ningún nodo ni en variables de entorno del contenedor (`bash scripts/pruebas-seguridad.sh` lo comprueba).

---

## 8. Cierre

```bash
bash scripts/demo.sh estado      # resumen de alertas registradas/enviadas
bash scripts/demo-preparar.sh    # confirma que todo volvió a la baseline
docker compose stop              # detiene sin borrar datos (NUNCA usar "down -v")
```
En la terminal 2: `Ctrl+C` para detener el agente del host.

---

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `Flujos Nutri activos: x / 18` | Volver a ejecutar `bash scripts/n8n-configurar.sh` |
| Llegan alertas repetidas desde otro equipo | Algún compañero tiene sus flujos activos: desactivarlos |
| El bot no responde en el grupo | Mencionarlo (`@nutrianimales_alertas_bot …`) o usar comandos `/ventas`; revisar que nadie más tenga B0 activo |
| H1 no llega | ¿Está corriendo `sudo bash scripts/agente-host.sh`? Sin root no lee UFW |
| R4 por SSH no llega | Igual: el agente debe estar corriendo; `sshd` debe estar activo (`systemctl status ssh`) |
| n8n responde 502 al arrancar | Esperar 20–30 s (n8n tarda en iniciar) |
| Una alerta no se repite al rehacer la demo | Las alertas tienen huella única para no repetir el mismo hallazgo; `bash scripts/demo-preparar.sh` reinicia estadísticas |
| R1 no llega al repetir `r1` | Por diseño R1 avisa máximo 1 vez por consulta cada 10 min (evita ráfagas): esperar 10 min o mostrar la alerta anterior |
