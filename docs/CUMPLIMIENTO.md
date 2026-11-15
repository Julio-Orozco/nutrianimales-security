# Matriz de cumplimiento de A y B

Estados basados en comandos ejecutados en esta instalación Docker el 14 de noviembre de 2026; revisados de nuevo tras la corrección de n8n (revisión 2). La matriz no sustituye las capturas que debe tomar el equipo durante la exposición. Para comandos completos, ver `docs/COMANDOS.md`; salidas reales seleccionadas, `evidencias/RESULTADOS_AB.md`.

## Parte A — 12 controles de hardening

| # | Requisito / estado | Archivos relacionados | Comando de verificación | Resultado esperado | Resultado obtenido / evidencia |
|---|---|---|---|---|---|
| A1 | **Verificado**: servicios de aplicación sin root | `compose.yaml` | `docker compose exec -T <n8n\|nginx\|pgadmin\|filebeat> id`; inspección del proceso PostgreSQL | UID de proceso distinto de 0 en todos los servicios. | n8n 1000, Nginx 1000, pgAdmin 5050, Filebeat 1000 (grupo adm), PostgreSQL 999. Revisión 2: sin cambios. E01. |
| A2 | **Verificado**: protección del `.env` | `.gitignore`, `.env.example`, `scripts/prepare-ab.sh` | `stat -c '%a %n' .env`; `git check-ignore -v .env` | Modo 600; ignorado por Git; ejemplo sin secretos. | Modo 600 y Git lo ignora; el ejemplo contiene valores vacíos. Credenciales del `.env` preexistente no se rotaron. E02. |
| A3 | **Verificado**: red de proyecto y comunicación autenticada | `compose.yaml`, `infra/pg_hba.conf` | Inspeccionar red real; agente_ia conecta a `postgres` con TLS `verify-full` | Servicios conectados a red bridge del proyecto; tráfico PostgreSQL solo con TLS/SCRAM; no afirmar `internal=true`. | Cinco contenedores en bridge `172.20.0.0/16`, `internal=false`; HBA usa `samenet`; agente_ia y n8n_app conectan con TLS 1.3. Nginx→n8n y Nginx→pgAdmin responden por nombre DNS interno. E03. |
| A4 | **Verificado**: sin exposición directa innecesaria | `compose.yaml`, `infra/nginx/nginx.conf` | `docker compose ps` | Solo Nginx expone loopback 8080/8443; sin mapeo host de 5432, 5050, 5678. | Solo aparecen `127.0.0.1:8080/8443`; pgAdmin funciona por proxy y 5050 no está publicado. E04. |
| A5 | **Verificado**: SCRAM efectivo | `infra/postgresql.conf`, `infra/pg_hba.conf`, `compose.yaml` | `SHOW password_encryption`; `pg_hba_file_rules`; intento con `sslmode=disable` | Password encryption SCRAM; host requiere TLS/SCRAM; sin TLS rechazado. | `scram-sha-256`; los ocho roles con login (incluido el nuevo `n8n_app`) tienen verificador SCRAM; conexión sin TLS rechazada. `local ... trust` se limita al socket del contenedor. E05. |
| A6 | **Verificado**: TLS PostgreSQL funcional | `infra/postgresql.conf`, `infra/pg_hba.conf`, `compose.yaml` | `psql ... sslmode=verify-full`; `pg_stat_ssl` | Conexión cifrada, nombre/CA verificados y sesión reportada con `ssl=t`. | Agente_ia usó TLS 1.3 y certificado verificado por nombre. E06. |
| A7 | **Verificado**: agente_ia de solo lectura | `db/sql/01-roles.sqb`, `db/sql/05-access.sqb` | SELECT y ensayos INSERT/UPDATE/DELETE autenticados como agente_ia; contar grants | SELECT permitido; las tres escrituras denegadas; cero grants de escritura. | SELECT devuelve 50 productos; INSERT/UPDATE/DELETE fallan por read-only; cero grants. E07. |
| A8 | **Verificado**: headers web requeridos | `infra/nginx/nginx.conf` | `curl --cacert infra/certs/server.crt -I https://localhost:8443/auditoria.html` | Respuesta HTTPS 200 con X-Frame-Options, HSTS, X-Content-Type-Options y CSP. | HTTP 200 y los cuatro headers están presentes. E08. |
| A9 | **Verificado**: certificado HTTPS válido para host de laboratorio | `infra/certs/server.crt`, `scripts/prepare-ab.sh` | `openssl verify -CAfile ... -verify_hostname localhost ...` | Certificado vigente, SAN localhost/IP y confianza explícita de CA autofirmada. | Verificación `OK`; SAN localhost/127.0.0.1. No equivale a confianza pública. E09. |
| A10 | **Verificado** (corregido en revisión 2): permisos de archivos y volúmenes | `.gitignore`, `scripts/prepare-ab.sh`, `compose.yaml`, `infra/postgresql.conf` | `sh scripts/capturas-ab.sh A10` | `.env`/claves 600; PGDATA 700 sin archivos accesibles a grupo/otros; logs PostgreSQL 600 en directorio 700; volumen n8n 700 con `config` 600; montajes de configuración y claves en solo lectura. | `.env` y claves 600; PGDATA 700 UID 999 y 0 archivos permisivos; logs 600/directorio 700 (antes 644/755, `log_file_mode` corregido a `0600`); `/home/node/.n8n` 700 y `config` 600 (antes 755); montajes de configuración `ro`. Alcance: volúmenes y archivos del proyecto, no cada archivo interno de las imágenes. E10. |
| A11 | **Verificado**: log de consulta lenta y estadísticas | `infra/postgresql.conf`, `db/sql/02-schema.sqb` | `sh scripts/capturas-ab.sh A11` (lee el log dentro del contenedor; `docker compose logs` no lo muestra porque `logging_collector=on`) | Consulta >1.000 ms registrada y visible en estadísticas. | El log registró 1.144 s y `pg_stat_statements` contabilizó la consulta. E11. |
| A12 | **Verificado**: baseline de siete parámetros | `db/sql/02-schema.sqb`, `infra/postgresql.conf` | Comparar `pg_settings_baseline` y `pg_settings` | Siete filas comparadas; todos los valores coinciden con la configuración aprobada. | Siete filas; las siete coinciden. E12. |

## Parte B — base y auditoría

| Requisito / estado | Resultado esperado | Comando / evidencia | Resultado real |
|---|---|---|---|
| B1. Esquema **verificado** | 14 tablas, PK/FK y scripts inicializables | `bash scripts/test-init-ab.sh`; `\dt`; catálogos PK/FK | Contenedor limpio: 14 tablas, 20 triggers, 7 baseline; 14 PK, 5 FK y tres vistas en la base activa. |
| B2. Semilla **verificada** | 3, 50, 100, 500, 1.500, 1.500, 300, 200 | Consulta de conteos en `docs/COMANDOS.md` | Los ocho conteos coinciden en la base activa. |
| B3. Auditoría **verificada** | Usuario/fecha/operación/tabla/fila y JSON anterior/posterior | `\d auditoria_datos`; consulta de eventos | `fn_auditoria()` SECURITY DEFINER; índices por tabla, usuario y fecha. UPDATE y DELETE registrados. |
| B4. Triggers **verificados** | INSERT/UPDATE/DELETE por fila y UPDATE/DELETE por sentencia en cuatro tablas | `information_schema.triggers` | 20 eventos de triggers activos en productos, lotes, ventas y clientes. |
| B5. UPDATE **verificado** | Valores anterior y posterior correctos | `db/demo-audit.sql` | La fila 1503 registró `antes` → `despues` con usuario y fecha. |
| B6. DELETE **verificado** | Registro de auditoría conserva fila anterior; posterior NULL; la fila de prueba no queda | `db/demo-audit.sql` | DELETE de fila ficticia 1503 auditado; valor anterior presente y `valor_nuevo IS NULL`. |
| B7. Baseline **verificado** | Siete parámetros; SSL, autenticación y logging conforme | Join baseline/settings | Siete parámetros coinciden; SSL activo y log lento/conexiones habilitados. |
| B8. Inicialización limpia **verificada** (revisión 2) | Scripts crean esquema, datos, auditoría y la cuenta de n8n en un volumen vacío | `bash scripts/test-init-ab.sh` | `tables=14, triggers=20, baseline=7, n8n_owner=n8n_app, n8n_app_public_grants=0`; contenedor temporal eliminado. |
| B9. Permisos de aplicación **verificados** (revisión 2) | La auditoría no amplía permisos; cada cuenta conserva su alcance | Consultas autenticadas por TLS con cada rol | auditor_db lee auditoría y no la borra; ti_db lee clientes y auditoría, no borra auditoría; agente_ia no lee auditoría y no escribe; n8n_app sin acceso a `public` ni a la auditoría; `monitor_db` sin privilegios sobre `n8n`. |

## Integración n8n (revisión 2)

| Requisito / estado | Archivos | Comando | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| n8n **verificado**: interfaz por Nginx | `compose.yaml`, `db/sql/06-n8n.sqb`, `db/sql/00-init.sh`, `scripts/migrate-n8n-app.sh` | `sh scripts/capturas-ab.sh N8N` | `healthz` ok; `https://localhost:8443/` 200 con la interfaz; tablas internas en el esquema `n8n` propiedad de `n8n_app` | `{"status":"ok"}`; HTTP 200, `<title>n8n.io - Workflow Automation</title>`; WebSocket `/rest/push` 101; 114 tablas y 204 migraciones registradas; conexión TLS 1.3 con verificación de CA. |
| Flujos, Telegram, Groq y 17 alertas **pendientes** | `n8n/workflows/*.json` | — | Importados y probados por sus responsables | No importados ni probados en esta revisión; no se declaran funcionales. |

## Correcciones y captura requerida por control

| Control | ¿Se corrigió algo en la revisión 2? | Captura para el profesor (`sh scripts/capturas-ab.sh <control>`) |
|---|---|---|
| A1 | No; ya era correcto. | A1: salida de `id` de los cinco servicios. |
| A2 | `.env.example` y `scripts/prepare-ab.sh` incluyen `N8N_DB_PASSWORD` (vacía en el ejemplo). | A2: modo 600, `git check-ignore` y ejemplo sin valores. |
| A3 | No en la red; n8n ahora conecta con su propia cuenta. | A3: red bridge, cinco miembros y sesiones TLS internas. |
| A4 | No. | A4: `docker compose ps` y «ninguno» publicado para PostgreSQL. |
| A5 | Se añadió `n8n_app` con verificador SCRAM. | A5: `password_encryption`, reglas HBA, métodos de los roles y rechazo sin TLS. |
| A6 | No; n8n mantiene `SSL_REJECT_UNAUTHORIZED=true`. | A6: `pg_stat_ssl` de agente_ia y de n8n_app. |
| A7 | No. | A7: SELECT correcto y tres escrituras denegadas. |
| A8 | No. | A8: headers en `https://localhost:8443/`. |
| A9 | No. | A9: `openssl verify` OK y SAN. |
| A10 | `infra/postgresql.conf` (`log_file_mode = 0600`), permisos del directorio de logs y del volumen n8n. | A10: modos de `.env`, claves, PGDATA, logs, volumen n8n y montajes `ro`. |
| A11 | Solo el comando de verificación (lectura del log dentro del contenedor). | A11: duración >1000 ms en el log y `pg_stat_statements`. |
| A12 | No. | A12: siete filas con `coincide = t`. |

## Pendientes fuera del resultado confirmado

- Repetir las capturas en la computadora de exposición. Esta sesión generó salidas de consola reales, no imágenes.
- Adjuntar el PDF/Word original y la rúbrica oficial: no están en el checkout recibido.
- Validar los flujos n8n end-to-end, monitor, Telegram, UFW real, Logstash/Loki, backups y escenarios que dependen de fuentes no incluidas. No son parte de los resultados A/B demostrados aquí.
- Filebeat/UFW: en este WSL `/var/log/ufw.log` es un directorio vacío creado por Docker; se necesita UFW con registro activo (rsyslog) en el host. Corresponde a monitoreo y no se modificó.
- Crear la cuenta propietaria de n8n en el navegador (primer acceso) e importar los flujos.
