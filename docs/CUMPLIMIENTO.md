# Matriz de cumplimiento de A y B

Estados basados en comandos ejecutados en esta instalación Docker el 14 de noviembre de 2026. La matriz no sustituye las capturas que debe tomar el equipo durante la exposición. Para comandos completos, ver `docs/COMANDOS.md`; salidas reales seleccionadas, `evidencias/RESULTADOS_AB.md`.

## Parte A — 12 controles de hardening

| # | Requisito / estado | Archivos relacionados | Comando de verificación | Resultado esperado | Resultado obtenido / evidencia |
|---|---|---|---|---|---|
| A1 | **Verificado**: servicios de aplicación sin root | `compose.yaml` | `docker compose exec -T <n8n\|nginx\|pgadmin\|filebeat> id`; inspección del proceso PostgreSQL | UID de proceso distinto de 0 en todos los servicios. | n8n 1000, Nginx 1000, pgAdmin 5050, Filebeat 1000 (grupo adm), PostgreSQL 999. E01. |
| A2 | **Verificado**: protección del `.env` | `.gitignore`, `.env.example`, `scripts/prepare-ab.sh` | `stat -c '%a %n' .env`; `git check-ignore -v .env` | Modo 600; ignorado por Git; ejemplo sin secretos. | Modo 600 y Git lo ignora; el ejemplo contiene valores vacíos. Credenciales del `.env` preexistente no se rotaron. E02. |
| A3 | **Verificado**: red de proyecto y comunicación autenticada | `compose.yaml`, `infra/pg_hba.conf` | Inspeccionar red real; agente_ia conecta a `postgres` con TLS `verify-full` | Servicios conectados a red bridge del proyecto; tráfico PostgreSQL solo con TLS/SCRAM; no afirmar `internal=true`. | Cinco contenedores en bridge `172.20.0.0/16`, `internal=false`; HBA usa `samenet`; agente_ia conecta cifrado. E03. |
| A4 | **Verificado**: sin exposición directa innecesaria | `compose.yaml`, `infra/nginx/nginx.conf` | `docker compose ps` | Solo Nginx expone loopback 8080/8443; sin mapeo host de 5432, 5050, 5678. | Solo aparecen `127.0.0.1:8080/8443`; pgAdmin funciona por proxy y 5050 no está publicado. E04. |
| A5 | **Verificado**: SCRAM efectivo | `infra/postgresql.conf`, `infra/pg_hba.conf`, `compose.yaml` | `SHOW password_encryption`; `pg_hba_file_rules`; intento con `sslmode=disable` | Password encryption SCRAM; host requiere TLS/SCRAM; sin TLS rechazado. | `scram-sha-256`; los siete roles tienen verificador SCRAM; conexión sin TLS rechazada. `local ... trust` se limita al socket del contenedor. E05. |
| A6 | **Verificado**: TLS PostgreSQL funcional | `infra/postgresql.conf`, `infra/pg_hba.conf`, `compose.yaml` | `psql ... sslmode=verify-full`; `pg_stat_ssl` | Conexión cifrada, nombre/CA verificados y sesión reportada con `ssl=t`. | Agente_ia usó TLS 1.3 y certificado verificado por nombre. E06. |
| A7 | **Verificado**: agente_ia de solo lectura | `db/sql/01-roles.sqb`, `db/sql/05-access.sqb` | SELECT y ensayos INSERT/UPDATE/DELETE autenticados como agente_ia; contar grants | SELECT permitido; las tres escrituras denegadas; cero grants de escritura. | SELECT devuelve 50 productos; INSERT/UPDATE/DELETE fallan por read-only; cero grants. E07. |
| A8 | **Verificado**: headers web requeridos | `infra/nginx/nginx.conf` | `curl --cacert infra/certs/server.crt -I https://localhost:8443/auditoria.html` | Respuesta HTTPS 200 con X-Frame-Options, HSTS, X-Content-Type-Options y CSP. | HTTP 200 y los cuatro headers están presentes. E08. |
| A9 | **Verificado**: certificado HTTPS válido para host de laboratorio | `infra/certs/server.crt`, `scripts/prepare-ab.sh` | `openssl verify -CAfile ... -verify_hostname localhost ...` | Certificado vigente, SAN localhost/IP y confianza explícita de CA autofirmada. | Verificación `OK`; SAN localhost/127.0.0.1. No equivale a confianza pública. E09. |
| A10 | **Parcialmente verificado**: permisos de archivos y volúmenes | `.gitignore`, `scripts/prepare-ab.sh`, `compose.yaml` | `stat` de `.env`, claves y volúmenes PostgreSQL/n8n | `.env`/claves 600; PGDATA 700; datos propiedad del UID del servicio; montajes sensibles de solo lectura. | `.env` y claves 600; PGDATA 700 UID 999; n8n UID 1000. No se auditó cada archivo interno de todas las imágenes. E10. |
| A11 | **Verificado**: log de consulta lenta y estadísticas | `infra/postgresql.conf`, `db/sql/02-schema.sqb` | Ejecutar `pg_sleep(1.1)`, buscar su log y consultar `pg_stat_statements` | Consulta >1.000 ms registrada y visible en estadísticas. | El log registró 1.144 s y `pg_stat_statements` contabilizó la consulta. E11. |
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

## Pendientes fuera del resultado confirmado

- Repetir las capturas en la computadora de exposición. Esta sesión generó salidas de consola reales, no imágenes.
- Adjuntar el PDF/Word original y la rúbrica oficial: no están en el checkout recibido.
- Validar los flujos n8n end-to-end, monitor, Telegram, UFW real, Logstash/Loki, backups y escenarios que dependen de fuentes no incluidas. No son parte de los resultados A/B demostrados aquí.
