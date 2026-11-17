#!/bin/sh
# Ejecuta la verificación real de un control para tomar su captura en WSL.
# Uso: sh scripts/capturas-ab.sh A1   (A1..A12, B1..B4, N8N o todo)
# No muestra contraseñas ni el contenido de .env. No modifica datos de negocio:
# B4 inserta, actualiza y elimina únicamente una fila ficticia (db/demo-audit.sql).
set -u
cd "$(dirname "$0")/.."

PSQL='docker compose exec -T postgres psql -X -P pager=off -U postgres -d nutrianimales'
AGENTE="host=postgres dbname=nutrianimales user=agente_ia sslmode=verify-full sslrootcert=/run/pg-tls/server.crt"

titulo() { printf '\n===== %s — %s =====\n' "$1" "$2"; date '+%Y-%m-%d %H:%M:%S %Z'; }
agente() { docker compose exec -T postgres sh -c "PGPASSWORD=\"\$AGENTE_IA_PASSWORD\" psql -X -P pager=off \"$AGENTE\" -c \"$1\"" 2>&1; }

A1() { titulo A1 'Usuarios no-root'
  for s in n8n nginx pgadmin filebeat; do printf '%-9s ' "$s:"; docker compose exec -T "$s" id; done
  printf '%-9s ' 'postgres:'; docker compose exec -T postgres ps -o user=,pid=,args= -p 1; }
A2() { titulo A2 '.env con permisos 600 y excluido de Git'
  stat -c '%a %U %n' .env; git check-ignore -v .env
  echo '--- .env.example (sin valores):'; grep -E '^[A-Z0-9_]+=' .env.example; }
A3() { titulo A3 'Red Docker aislada y comunicación restringida'
  red=$(docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$(docker compose ps -q postgres)")
  docker network inspect "$red" --format 'red={{.Name}} driver={{.Driver}} internal={{.Internal}} subred={{range .IPAM.Config}}{{.Subnet}}{{end}}'
  docker network inspect "$red" --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'
  $PSQL -c "SELECT usename, client_addr, ssl, version FROM pg_stat_activity JOIN pg_stat_ssl USING(pid) WHERE usename IS NOT NULL AND client_addr IS NOT NULL;"; }
A4() { titulo A4 'PostgreSQL sin 5432 publicado'
  docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
  printf -- '--- puertos publicados por PostgreSQL al host: '; docker port "$(docker compose ps -q postgres)" | grep . || echo 'ninguno'
  ss -ltn 2>/dev/null | grep -E ':(5432|5678|5050)\b' || echo 'ninguno de 5432/5678/5050 escucha en el host'; }
A5() { titulo A5 'SCRAM-SHA-256 efectivo'
  $PSQL -c "SHOW password_encryption;" -c "SELECT line_number,type,database,user_name,address,auth_method FROM pg_hba_file_rules ORDER BY line_number;" \
        -c "SELECT rolname, left(rolpassword,13) AS metodo FROM pg_authid WHERE rolcanlogin ORDER BY rolname;"
  echo '--- intento sin TLS (debe rechazarse):'
  docker compose exec -T postgres sh -c 'PGPASSWORD="$AGENTE_IA_PASSWORD" psql -X "host=postgres dbname=nutrianimales user=agente_ia sslmode=disable" -c "SELECT 1"' 2>&1 | tail -1; }
A6() { titulo A6 'TLS de PostgreSQL activo y verificado'
  agente "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
  $PSQL -c "SELECT usename, ssl, version FROM pg_stat_activity JOIN pg_stat_ssl USING(pid) WHERE usename='n8n_app';"; }
A7() { titulo A7 'agente_ia de solo lectura'
  agente "SELECT count(*) AS productos FROM productos;"
  agente "INSERT INTO clientes(nombre,tipo,correo,segmento) VALUES ('x','x','x@example.invalid','x');" | tail -1
  agente "UPDATE clientes SET nombre=nombre WHERE id=1;" | tail -1
  agente "DELETE FROM clientes WHERE id=1;" | tail -1
  $PSQL -c "SELECT count(*) AS grants_escritura_agente FROM information_schema.role_table_grants WHERE grantee='agente_ia' AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE');"; }
A8() { titulo A8 'Headers de seguridad de Nginx'
  curl --fail -sS --cacert infra/certs/server.crt -I https://localhost:8443/ | grep -iE '^(HTTP|x-frame|x-content|referrer|strict|content-security)'; }
A9() { titulo A9 'Certificado HTTPS del laboratorio'
  openssl verify -CAfile infra/certs/server.crt -verify_hostname localhost infra/certs/server.crt
  openssl x509 -in infra/certs/server.crt -noout -subject -dates -ext subjectAltName; }
A10() { titulo A10 'Permisos de directorios y volúmenes'
  stat -c '%a %U %n' .env infra/certs/server.key infra/certs/server.crt
  sudo -n stat -c '%a %u %n' infra/postgres-tls/server.key infra/postgres-logs 2>/dev/null || stat -c '%a %u %n' infra/postgres-tls/server.key infra/postgres-logs
  docker compose exec -T postgres sh -c 'stat -c "%a %U %n" /var/lib/postgresql/data /var/log/postgresql /var/log/postgresql/* /run/pg-tls/server.key; echo "archivos de PGDATA accesibles a grupo/otros: $(find /var/lib/postgresql/data -perm /077 | wc -l)"'
  docker compose exec -T n8n sh -c 'stat -c "%a %U %n" /home/node/.n8n /home/node/.n8n/config'
  for c in $(docker compose ps -q); do docker inspect "$c" --format '{{.Name}}: {{range .Mounts}}{{.Destination}}({{if .RW}}rw{{else}}ro{{end}}) {{end}}'; done; }
A11() { titulo A11 'Logs de auditoría y consultas lentas'
  $PSQL -c "SHOW log_min_duration_statement;" -c "SHOW log_connections;" -c "SHOW log_statement;"
  $PSQL -c "SELECT pg_sleep(1.1);" >/dev/null
  sleep 1
  docker compose exec -T postgres sh -c 'grep "pg_sleep" "$(psql -X -U postgres -d nutrianimales -Atc "SELECT pg_current_logfile()")" | tail -1'
  $PSQL -c "SELECT calls, round(mean_exec_time) AS ms_promedio, query FROM pg_stat_statements WHERE query LIKE '%pg_sleep%' LIMIT 3;"; }
A12() { titulo A12 'pg_settings_baseline'
  $PSQL -c "SELECT b.name, b.valor_esperado, s.setting, b.valor_esperado = s.setting AS coincide FROM pg_settings_baseline b JOIN pg_settings s USING(name) ORDER BY b.name;"; }
B1() { titulo B1 'Tablas, PK y FK'
  $PSQL -c '\dt' -c "SELECT count(*) FILTER (WHERE contype='p') AS pk, count(*) FILTER (WHERE contype='f') AS fk FROM pg_constraint WHERE connamespace='public'::regnamespace;"; }
B2() { titulo B2 'Datos de prueba'
  $PSQL -c "SELECT 'plantas' t,count(*) FROM plantas UNION ALL SELECT 'productos',count(*) FROM productos UNION ALL SELECT 'materias_primas',count(*) FROM materias_primas UNION ALL SELECT 'lotes_produccion',count(*) FROM lotes_produccion UNION ALL SELECT 'clientes',count(*) FROM clientes UNION ALL SELECT 'ventas',count(*) FROM ventas UNION ALL SELECT 'control_calidad',count(*) FROM control_calidad UNION ALL SELECT 'gastos',count(*) FROM gastos;"; }
B3() { titulo B3 'fn_auditoria() y triggers'
  $PSQL -c "SELECT proname, pg_get_userbyid(proowner) AS owner, prosecdef AS security_definer FROM pg_proc WHERE proname LIKE 'fn_auditoria%';" \
        -c "SELECT event_object_table, trigger_name, string_agg(event_manipulation, ',' ORDER BY event_manipulation) AS eventos, action_orientation FROM information_schema.triggers WHERE trigger_schema='public' GROUP BY 1,2,4 ORDER BY 1,2;"; }
B4() { titulo B4 'Demostración UPDATE y DELETE auditados (fila ficticia)'
  $PSQL < db/demo-audit.sql; }
N8N() { titulo N8N 'n8n detrás de Nginx'
  docker compose exec -T n8n wget -qO- http://127.0.0.1:5678/healthz; echo
  curl -sS --cacert infra/certs/server.crt -o /dev/null -w 'https://localhost:8443/ -> HTTP %{http_code}\n' https://localhost:8443/
  curl -sS --cacert infra/certs/server.crt https://localhost:8443/ | grep -o '<title>[^<]*</title>'
  $PSQL -c "SELECT pg_get_userbyid(nspowner) AS owner_esquema_n8n, (SELECT count(*) FROM pg_tables WHERE schemaname='n8n') AS tablas_n8n FROM pg_namespace WHERE nspname='n8n';" \
        -c "SELECT has_schema_privilege('n8n_app','n8n','USAGE') AS n8n_app_usage, has_schema_privilege('n8n_app','n8n','CREATE') AS n8n_app_create, has_schema_privilege('monitor_db','n8n','CREATE') AS monitor_db_create;"; }

case "${1:-}" in
  A1|A2|A3|A4|A5|A6|A7|A8|A9|A10|A11|A12|B1|B2|B3|B4|N8N) "$1" ;;
  todo) for c in A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 B1 B2 B3 B4 N8N; do "$c"; done ;;
  *) echo 'Uso: sh scripts/capturas-ab.sh A1..A12 | B1..B4 | N8N | todo' >&2; exit 2 ;;
esac
