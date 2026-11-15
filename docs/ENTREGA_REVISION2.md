# Entrega de la revisión 2 — partes A y B

Fecha: 14 de noviembre de 2026. Rama: `feature/revision_2`. Todo lo que aquí figura como verificado se ejecutó en el Docker de WSL del equipo; las salidas están en `evidencias/RESULTADOS_AB.md`.

## 1. Problema principal: n8n respondía 502

| Pregunta | Resultado |
|---|---|
| ¿Por qué n8n no terminaba de iniciar? | TypeORM ejecuta siempre `CREATE SCHEMA IF NOT EXISTS "n8n"`. PostgreSQL exige `CREATE` sobre la **base** antes de comprobar si el esquema existe; `monitor_db` no lo tenía (`permission denied for database nutrianimales`). n8n no aborta ante ese error: queda bloqueado y nunca abre el puerto 5678. |
| Conexión real n8n → PostgreSQL | Funcionaba: SCRAM + TLS 1.3 con verificación de CA. El fallo era de autorización, no de conexión. |
| Certificado SSL | PEM válido, `CN=postgres`, SAN `postgres,nutrianimales_db`, vigente hasta 14/11/2027, termina con un `\n` estándar. El aviso de *whitespace* es informativo; no se modificó. |
| `USAGE`/`CREATE` sobre el esquema `n8n` | `monitor_db` tenía ambos porque era dueño del esquema, pero faltaba `CREATE` sobre la base. Ahora el dueño es `n8n_app` y `monitor_db` ya no tiene privilegios sobre el esquema. |
| Crear/actualizar tablas internas | `n8n_app` creó 114 tablas y registró 204 migraciones; se comprobó también un CREATE/DROP manual en `n8n`. |
| Migraciones y versión | n8n 2.30.8; migraciones completas. La imagen se fijó en `n8nio/n8n:2.30.8` (mismo digest que el `latest` validado). |
| Volumen `n8n_data` | Intacto: contiene `config` con la clave de cifrado, que coincide con `N8N_ENCRYPTION_KEY`. No había flujos ni credenciales previos (el esquema tenía 0 tablas). |
| Proxy Nginx | Correcto, sin cambios: resolución dinámica de `n8n:5678` y soporte WebSocket (`/rest/push` → 101). |
| Puerto 5678 | `n8n ready on ::, port 5678`; `healthz` → `{"status":"ok"}`. |
| `https://localhost:8443` | HTTP 200 con `<title>n8n.io - Workflow Automation</title>`. El navegador mostrará la advertencia del certificado autofirmado hasta que se confíe en él. |

### Decisión de seguridad: cuenta `n8n_app`

`monitor_db` es una cuenta de monitoreo y no debe administrar tablas. Por eso se creó `n8n_app` con estas características:

- Es `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`, con un límite de 20 conexiones.
- Es dueña únicamente del esquema `n8n`, con `search_path = n8n`.
- Tiene `CONNECT` y `CREATE` sobre `nutrianimales`. `CREATE` es el mínimo que exige la sentencia de TypeORM. Riesgo residual: permite crear esquemas nuevos, pero no leer ni modificar objetos de otros.
- No tiene permisos sobre `public` ni sobre las tablas de auditoría; se comprobó con `permission denied`.
- Mantiene TLS con `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true`. No se desactivó SSL ni se usó `postgres`.

### Procedimiento de migración (instalación existente)

```bash
bash scripts/migrate-n8n-app.sh
```

1. Si falta, agrega `N8N_DB_PASSWORD` a `.env`, sin tocar las demás variables, y mantiene el modo 600.
2. Respaldo verificable en `.runtime/backup-<fecha>/` (modo 700, ignorado por Git):
   - `nutrianimales.dump`: `pg_dump -Fc` completo, verificado con `pg_restore --list`;
   - `roles.sql`: roles sin contraseñas;
   - `n8n_data.tgz`: volumen n8n, verificado con `tar -t`.
3. Aplica `db/sql/06-n8n.sqb` (idempotente).
4. Recrea solo el contenedor n8n (`--no-deps`) y espera `healthz` y HTTP 200.

Reversión, si fuera necesaria. Es la opción de último recurso y vuelve al estado con 502:

```bash
# Volver a monitor_db en compose.yaml (DB_POSTGRESDB_USER / PASSWORD) y luego:
docker compose up -d --no-deps n8n
# Restaurar el volumen n8n desde el respaldo:
docker compose stop n8n
docker run --rm -v nutrianimales-seguridad_n8n_data:/data -v "$PWD/.runtime/backup-<fecha>:/b:ro" \
  --entrypoint sh n8nio/n8n:2.30.8 -c 'cd /data && tar -xzf /b/n8n_data.tgz'
docker compose start n8n
```

## 2. Parte A — estado de los 12 controles

Todos están **verificados** en este equipo; el detalle está en `docs/CUMPLIMIENTO.md`. El único control que pasó de parcial a completo es **A10**:
- `log_file_mode` cambió de `0644` a `0600`: los logs de PostgreSQL, con conexiones y DDL, eran legibles por cualquier usuario del host;
- el directorio de logs pasó a 700;
- el volumen n8n pasó a 700, con `config` en 600.

Capturas: `sh scripts/capturas-ab.sh A1` … `A12` (una orden por captura).

## 3. Parte B — estado

B1–B9 están **verificados**:
- tablas, conteos, PK y FK;
- `fn_auditoria()` y los 20 eventos de trigger;
- UPDATE y DELETE auditados con la fila ficticia 1504;
- baseline 7/7;
- inicialización limpia, que ahora incluye `n8n_app`;
- permisos de aplicación intactos frente a la auditoría.

No se duplicaron datos ni se recrearon triggers; los clientes siguen en 1.500.

## 4. Archivos modificados en esta revisión

| Archivo | Cambio | Motivo |
|---|---|---|
| `db/sql/06-n8n.sqb` | Nuevo | Crea `n8n_app` y el esquema `n8n` con permisos limitados (idempotente). |
| `db/sql/00-init.sh` | +2 líneas | Ejecuta `06-n8n.sqb` en una inicialización limpia. |
| `compose.yaml` | n8n usa `n8n_app`/`N8N_DB_PASSWORD`; imagen `2.30.8`; PostgreSQL recibe `N8N_DB_PASSWORD` para initdb | Corrección del 502 y versión reproducible. |
| `.env.example` | `N8N_DB_PASSWORD=` vacío | Nueva variable obligatoria, sin valor. |
| `.env` (local, no se entrega) | Se añadió `N8N_DB_PASSWORD` | No se modificó ni rotó ninguna otra variable; Telegram y Groq intactos. |
| `scripts/prepare-ab.sh` | Genera `N8N_DB_PASSWORD` y la agrega a un `.env` existente si falta | Instalaciones nuevas y antiguas. |
| `scripts/migrate-n8n-app.sh` | Nuevo | Respaldo verificable + migración + comprobación. |
| `scripts/test-init-ab.sh` | Comprueba además el dueño del esquema `n8n` y que `n8n_app` no tiene grants en `public` | B9. |
| `scripts/capturas-ab.sh` | Nuevo | Una orden por cada captura obligatoria (A1–A12, B1–B4, N8N). |
| `infra/postgresql.conf` | `log_file_mode = 0600` | A10. |
| Volúmenes (en caliente) | `chmod 700` en `/var/log/postgresql` y `/home/node/.n8n`; logs a 600 | A10. |
| `README.md`, `docs/CUMPLIMIENTO.md`, `docs/COMANDOS.md`, `docs/INFORME.md`, `docs/ESTADO_ACTUAL.md`, `docs/VERIFICACION.md`, `docs/EVIDENCIAS.md`, `docs/EXPOSICION.md`, `docs/ARQUITECTURA.md`, `docs/DEPENDENCIAS.md`, `evidencias/RESULTADOS_AB.md` | Se sustituyeron las afirmaciones «n8n 502» por los resultados reales; se agregaron la sección A.5 (problemas y soluciones), B.6 y los resultados de la revisión 2 | Documentación coherente con lo verificado. |

No se modificaron `nginx.conf`, `pg_hba.conf`, los certificados, los SQL 01–05, `demo-audit.sql`, `filebeat.yml` ni los flujos JSON.

## 5. Guía rápida para demostrar al profesor

1. `docker compose ps`: los cinco servicios, PostgreSQL `healthy` y solo Nginx publicado.
2. `sh scripts/capturas-ab.sh A1` … `A12`: una captura por control.
3. `sh scripts/capturas-ab.sh B1`, `B2`, `B3` y `B4` (demostración UPDATE/DELETE con fila ficticia).
4. `sh scripts/capturas-ab.sh N8N` y abrir <https://localhost:8443> en el navegador (aceptar o importar el certificado local).
5. Explicar la causa del 502 y por qué `n8n_app` respeta el mínimo privilegio (sección 1).

## 6. Pendientes que no pudieron verificarse

- **Capturas de pantalla**: no se generaron imágenes; los comandos exactos están en `scripts/capturas-ab.sh`.
- **Cuenta propietaria de n8n**: se crea en el navegador en el primer acceso. No se creó para no inventar credenciales.
- **Flujos JSON**: no se importaron. Corresponde a monitoreo y bot; requieren el servicio `monitor` y credenciales de Telegram y Groq, que no están en el checkout. Comando de referencia, una vez creada la cuenta: `docker compose cp n8n/workflows n8n:/tmp/workflows && docker compose exec -T n8n n8n import:workflow --separate --input=/tmp/workflows`.
- **Telegram, Groq y las 17 alertas**: no se probaron y no se declaran funcionales.
- **Filebeat/UFW**: `/var/log/ufw.log` del host es un directorio vacío creado por Docker. Para resolverlo hay que habilitar UFW con registro (y rsyslog) en el host, borrar ese directorio y recrear Filebeat. No se modificó porque es tarea del integrante de monitoreo y requiere `sudo` en el host.
- **Logstash/Loki, monitor, `lab.py`, `host_agent.py`**: no están en el checkout.
- **Informe PDF/Word y rúbrica oficial**: no están disponibles. `docs/INFORME.md` contiene las secciones A y B actualizadas, listas para integrar en el documento original.
- **Instalación nueva del volumen n8n**: en una instalación desde cero, aplicar una vez `docker compose exec -T n8n chmod 700 /home/node/.n8n`. La imagen crea el directorio con modo 755.
