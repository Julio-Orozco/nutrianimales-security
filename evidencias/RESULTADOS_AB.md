# Salidas reales de verificación A y B

Ejecución: 14 de noviembre de 2026, en el entorno Docker disponible en esta sesión. Datos ficticios. Este registro resume salidas reales de comandos; no son capturas de pantalla ni resultados de otra computadora.

## A. Infraestructura y hardening

### A1, A3 y A4 — Identidades, red y puertos

`docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Ports}}'` mostró:

```text
SERVICE    STATE     PORTS
postgres   running   5432/tcp
filebeat   running
n8n        running   5678/tcp
nginx      running   127.0.0.1:8080->8080/tcp, 80/tcp, 127.0.0.1:8443->8443/tcp
pgadmin    running   80/tcp, 443/tcp
```

Los contenedores están en `nutrianimales-seguridad_nutrianimales-net`, bridge `172.20.0.0/16`, `internal=false`, cinco miembros. No se asigna esta subred fija en el Compose: PostgreSQL usa HBA `samenet`.

Identidades efectivas:

```text
n8n: uid=1000(node) gid=1000(node)
nginx: uid=1000 gid=1000
pgadmin: uid=5050(pgadmin) gid=0(root)
filebeat: uid=1000(filebeat) gid=1000(filebeat),4(adm)
postgres: proceso servidor uid=999 (postgres)
```

PostgreSQL y pgAdmin no tienen puerto publicado; pgAdmin se sirve mediante Nginx. Filebeat usa el grupo `adm` para una posible lectura de logs de Ubuntu; en este entorno no se confirmó un log UFW funcional.

### A2 y A10 — Permisos locales y volúmenes

```text
600 1000:1000 .env
600 1000:1000 infra/certs/server.key
600 999:999 infra/postgres-tls/server.key
700 999:999 /var/lib/postgresql/data
755 1000:1000 /home/node/.n8n
```

`git check-ignore -v` confirmó que `.env`, la clave Nginx y `infra/postgres-tls/` están excluidos por `.gitignore`. `.env.example` no tiene contraseñas predeterminadas. El `.env` local existía antes y no fue sobrescrito; no se incluyen ni divulgan sus contenidos. La verificación acredita modo/exclusión, no una rotación de sus valores.

### A5 y A6 — SCRAM y TLS PostgreSQL

Valores efectivos:

```text
ssl=on
password_encryption=scram-sha-256
log_min_duration_statement=1s
log_connections=on
```

Reglas host leídas por PostgreSQL:

```text
local all postgres trust
local all all scram-sha-256
hostssl all all samenet scram-sha-256
host all all 0.0.0.0/0 reject
host all all ::/0 reject
```

Una conexión autenticada de `agente_ia` con `sslmode=verify-full` devolvió 50 productos y `ssl=t`, `TLSv1.3`, cipher `TLS_AES_256_GCM_SHA384`.

Los siete roles de base comprobados almacenan verificador SCRAM-SHA-256. Una conexión de `agente_ia` con `sslmode=disable` fue rechazada por `pg_hba.conf` con `no encryption`.

### A7 — agente_ia de solo lectura

La consulta SELECT fue exitosa; los ensayos de escritura devolvieron:

```text
INSERT: ERROR: cannot execute INSERT in a read-only transaction
UPDATE: ERROR: cannot execute UPDATE in a read-only transaction
DELETE: ERROR: cannot execute DELETE in a read-only transaction
agente_write_grants: 0
```

### A8 y A9 — Nginx HTTPS, headers y certificado

`curl --fail --cacert infra/certs/server.crt -I https://localhost:8443/auditoria.html` devolvió HTTP 200 y los headers:

```text
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=86400
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss://localhost:8443; frame-ancestors 'none'; base-uri 'self'
```

`openssl verify -CAfile infra/certs/server.crt -verify_hostname localhost infra/certs/server.crt` devolvió `infra/certs/server.crt: OK`. SAN: `DNS:localhost`, `IP Address:127.0.0.1`. Es autofirmado y no tiene confianza pública.

El navegador integrado rechazó el certificado (`ERR_CERT_AUTHORITY_INVALID`) y no se guardó captura; la validación autenticada de terminal con `--cacert` fue exitosa.

La ruta pgAdmin respondió HTTP 302 hacia autenticación y HTTP 200 al seguir la redirección. El puerto host 5050 no está publicado. La ruta raíz de n8n respondió HTTP 502 y el contenedor no abrió el puerto 5678; queda pendiente.

### A11 y A12 — Logs lentos, estadísticas y baseline

Una consulta real `SELECT pg_sleep(1.1);` produjo:

```text
LOG: duration: 1144.541 ms statement: SELECT pg_sleep(1.1);
pg_stat_statements: calls=2, query=SELECT pg_sleep($1)
```

`pg_settings_baseline` tuvo siete filas; la comparación con `pg_settings` dio `all_match=t`:

```text
log_connections=on
log_min_duration_statement=1000
max_connections=100
password_encryption=scram-sha-256
shared_preload_libraries=pg_stat_statements
ssl=on
work_mem=4096
```

## B. Base de datos y auditoría

La inicialización limpia se probó con `bash scripts/test-init-ab.sh` en un contenedor temporal sin red ni puertos publicados. Resultado real: `tables=14, triggers=20, baseline=7`; el contenedor temporal se eliminó al terminar.

Conteos consultados directamente:

```text
plantas             3
productos          50
materias_primas   100
lotes_produccion  500
clientes         1500
ventas           1500
control_calidad   300
gastos            200
```

Se observaron 14 tablas públicas, 14 claves primarias, cinco foráneas y 20 eventos de trigger. `fn_auditoria()` pertenece a `audit_owner` y es SECURITY DEFINER. Los índices de `auditoria_datos` incluyen tabla, usuario y fecha.

### B5 y B6 — UPDATE y DELETE reales

Comando: `docker compose exec -T postgres psql -X -U postgres -d nutrianimales < db/demo-audit.sql`.

Resultado de la fila ficticia 1503:

```text
tabla    operacion usuario  fila_id nombre_anterior              segmento_anterior segmento_nuevo valor_nuevo_es_null
clientes INSERT    postgres    1503                              —                 antes          f
clientes UPDATE    postgres    1503 Prueba auditoria controlada  antes             despues        f
clientes DELETE    postgres    1503 Prueba auditoria controlada  despues           —              t
```

El script confirmó la transacción y eliminó esa fila temporal. El evento de auditoría DELETE quedó almacenado con el JSON anterior y `valor_nuevo` nulo.

## Límites

- n8n no respondió en el puerto 5678; no se probaron importación de flujos ni funcionalidades conectadas.
- Filebeat no recibió un log UFW del host; no existe Logstash/Loki en este checkout.
- No se generaron capturas de pantalla, no se probaron Telegram/Groq ni otros escenarios, y no está el PDF/Word original ni la rúbrica oficial.
- El `.env` fue protegido, no rotado. La preparación conserva intencionalmente un `.env` existente. Antes de usar esta instancia fuera del laboratorio, rotar sus credenciales en coordinación con PostgreSQL, pgAdmin y n8n.
