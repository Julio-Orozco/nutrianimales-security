# Comandos reproducibles para A y B

Ejecutar desde la raíz del proyecto. Cada control también se puede ejecutar para su captura con `sh scripts/capturas-ab.sh <A1…A12|B1…B4|N8N|todo>`. Las salidas son evidencia solo cuando se obtienen del entorno del equipo; las líneas «esperado» describen el criterio, no una prueba.

## A. Infraestructura y hardening

| Control | Comando de verificación | Criterio |
|---|---|---|
| A1. Usuarios | `docker compose exec -T n8n id`; repetir con `pgadmin` y `filebeat`; para PostgreSQL: `docker compose exec -T postgres ps -eo user,pid,args \| grep '[p]ostgres'` | n8n, pgAdmin, Filebeat y proceso PostgreSQL no ejecutan la aplicación como root. |
| A2. `.env` | `stat -c '%a %n' .env`; `git check-ignore -v .env`; `grep -E '^[A-Z0-9_]+=' .env.example` | Modo `600`, ignorado por Git y sin valores secretos en el ejemplo. No mostrar el contenido de `.env`. |
| A3. Red | `network=$(docker inspect --format='{{range $name, $value := .NetworkSettings.Networks}}{{$name}}{{end}}' "$(docker compose ps -q postgres)")`; después `docker network inspect "$network"` | Los servicios comparten la red bridge privada del proyecto; PostgreSQL acepta clientes únicamente desde la subred conectada y requiere TLS/SCRAM. |
| A4. Puertos | `docker compose ps` | Solo Nginx publica `127.0.0.1:8080` y `127.0.0.1:8443`. No debe aparecer un mapeo host para 5432, 5678, 5050 ni Filebeat. |
| A5. SCRAM | `docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SHOW password_encryption; SELECT line_number,type,address,auth_method,error FROM pg_hba_file_rules ORDER BY line_number;"` | `scram-sha-256`; redes host usan `hostssl`/SCRAM y el resto se rechaza. `local ... trust` solo aplica al socket dentro del contenedor. |
| A6. TLS PostgreSQL | `docker compose exec -T postgres sh -c 'PGPASSWORD="$AGENTE_IA_PASSWORD" psql "host=postgres dbname=nutrianimales user=agente_ia sslmode=verify-full sslrootcert=/run/pg-tls/server.crt" -c "SELECT ssl,version,cipher FROM pg_stat_ssl WHERE pid=pg_backend_pid();"'` | Conexión verificada por nombre, con `ssl=t` y versión/cipher TLS. |
| A7. Solo lectura | Para cada operación, ejecutar el comando de prueba de abajo usando `INSERT`, `UPDATE` y `DELETE`. | El SELECT responde; las tres escrituras fallan con transacción de solo lectura y cero grants de escritura para agente_ia. |
| A8. Headers | `curl --fail --cacert infra/certs/server.crt -I https://localhost:8443/auditoria.html` | Respuesta HTTPS contiene X-Frame-Options, HSTS, X-Content-Type-Options y CSP. |
| A9. Certificado | `openssl verify -CAfile infra/certs/server.crt -verify_hostname localhost infra/certs/server.crt`; `openssl x509 -in infra/certs/server.crt -noout -dates -ext subjectAltName` | Cadena autofirmada validada explícitamente y SAN para localhost. La confianza del navegador requiere importar el certificado local. |
| A10. Permisos | `stat -c '%a %n' .env infra/certs/server.key`; `docker compose exec -T postgres sh -c 'stat -c "%a %U %n" /var/lib/postgresql/data /var/log/postgresql /var/log/postgresql/*; find /var/lib/postgresql/data -perm /077 \| wc -l'`; `docker compose exec -T n8n stat -c '%a %U %n' /home/node/.n8n /home/node/.n8n/config` | `.env` y claves `600`; PGDATA `700` y 0 archivos permisivos; logs `600` en directorio `700`; volumen n8n `700` y `config` `600`. En una instalación nueva, aplicar una vez `docker compose exec -T n8n chmod 700 /home/node/.n8n`. |
| A11. Logs/métricas | `docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c 'SELECT pg_sleep(1.1);'`; luego `docker compose exec -T postgres sh -c 'grep pg_sleep /var/log/postgresql/postgresql-$(date -u +%F).log \| tail -1'` (con `logging_collector=on` el log no aparece en `docker compose logs`) y `docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT calls,query FROM pg_stat_statements WHERE query LIKE '%pg_sleep%' LIMIT 3;"` | El log incluye duración mayor a 1000 ms y pg_stat_statements muestra la consulta. |
| A12. Baseline | `docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT name,valor_esperado,setting,valor_esperado=setting AS coincide FROM pg_settings_baseline JOIN pg_settings USING(name) ORDER BY name;"` | Siete filas; `coincide=t` en todas. |

Pruebas de escritura de `agente_ia` (cada comando debe fallar; no son cambios ejecutados como superusuario):

```bash
docker compose exec -T postgres sh -c 'PGPASSWORD="$AGENTE_IA_PASSWORD" psql "host=postgres dbname=nutrianimales user=agente_ia sslmode=verify-full sslrootcert=/run/pg-tls/server.crt" -v ON_ERROR_STOP=1' <<'SQL'
INSERT INTO clientes(nombre,tipo,correo,segmento) VALUES ('prueba','prueba','prueba@example.invalid','prueba');
SQL
docker compose exec -T postgres sh -c 'PGPASSWORD="$AGENTE_IA_PASSWORD" psql "host=postgres dbname=nutrianimales user=agente_ia sslmode=verify-full sslrootcert=/run/pg-tls/server.crt" -v ON_ERROR_STOP=1' <<'SQL'
UPDATE clientes SET nombre=nombre WHERE id=1;
SQL
docker compose exec -T postgres sh -c 'PGPASSWORD="$AGENTE_IA_PASSWORD" psql "host=postgres dbname=nutrianimales user=agente_ia sslmode=verify-full sslrootcert=/run/pg-tls/server.crt" -v ON_ERROR_STOP=1' <<'SQL'
DELETE FROM clientes WHERE id=1;
SQL
```

Para comprobar la respuesta esperada sin alterar la terminal tras cada error, se pueden ejecutar individualmente como `if comando; then echo FALLO; else echo DENEGADO; fi`.

## B. Base de datos y auditoría

Conteos de datos de prueba:

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -P pager=off -c "SELECT 'plantas',count(*) FROM plantas UNION ALL SELECT 'productos',count(*) FROM productos UNION ALL SELECT 'materias_primas',count(*) FROM materias_primas UNION ALL SELECT 'lotes_produccion',count(*) FROM lotes_produccion UNION ALL SELECT 'clientes',count(*) FROM clientes UNION ALL SELECT 'ventas',count(*) FROM ventas UNION ALL SELECT 'control_calidad',count(*) FROM control_calidad UNION ALL SELECT 'gastos',count(*) FROM gastos;"
```

El esquema tiene 14 tablas (ocho empresariales y seis de auditoría/monitoreo), tres vistas de reporte, claves primarias y foráneas. Listados útiles:

```bash
bash scripts/test-init-ab.sh
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c '\dt'
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT event_object_table,trigger_name,event_manipulation FROM information_schema.triggers WHERE trigger_schema='public' ORDER BY 1,2,3;"
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c '\d auditoria_datos'
```

Demostración repetible y segura de INSERT/UPDATE/DELETE:

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales < db/demo-audit.sql
```

Inserta una fila ficticia, actualiza y elimina esa misma fila en una transacción confirmada: el registro empresarial queda eliminado y las tres auditorías persisten. El resultado debe mostrar usuario, operación, `fila_id`, JSON anterior y posterior; en DELETE `valor_nuevo_es_null=t`.

## n8n (revisión 2)

```bash
docker compose exec -T n8n wget -qO- http://127.0.0.1:5678/healthz
curl --fail -s --cacert infra/certs/server.crt -o /dev/null -w '%{http_code}\n' https://localhost:8443/
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT pg_get_userbyid(nspowner) AS owner, (SELECT count(*) FROM pg_tables WHERE schemaname='n8n') AS tablas FROM pg_namespace WHERE nspname='n8n';"
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT has_schema_privilege('n8n_app','n8n','USAGE') AS usage, has_schema_privilege('n8n_app','n8n','CREATE') AS create, has_schema_privilege('monitor_db','n8n','CREATE') AS monitor_create;"
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT usename, ssl, version FROM pg_stat_activity JOIN pg_stat_ssl USING(pid) WHERE usename='n8n_app';"
```

Esperado: `{"status":"ok"}`, `200`, owner `n8n_app` con más de 100 tablas, `usage=t create=t monitor_create=f` y sesiones `ssl=t TLSv1.3`. Si devuelve 502 en una instalación previa, ejecutar `bash scripts/migrate-n8n-app.sh`.

## Guardado de evidencia

Guardar comandos y salidas auténticas sin copiar `.env`, valores de credenciales, claves privadas ni datos personales. Si un comando no se ejecutó en la computadora de exposición, marcar la evidencia pendiente. Para detener el laboratorio sin borrar datos: `docker compose stop`. No usar `down -v` para una demostración.
