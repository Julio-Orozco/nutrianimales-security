#!/usr/bin/env bash
# Pruebas de seguridad rápidas para mostrar en vivo (no modifican nada).
# Cada línea imprime PASS/FALLA. No imprime ningún secreto.
set -u   # sin pipefail: varias pruebas esperan que el primer comando falle
cd "$(dirname "$0")/.."
ok=0; mal=0
check() { # descripción, comando que debe devolver 0
  if eval "$2" >/dev/null 2>&1; then printf '  \033[32mPASS\033[0m  %s\n' "$1"; ok=$((ok+1))
  else printf '  \033[31mFALLA\033[0m %s\n' "$1"; mal=$((mal+1)); fi
}
PSQL='docker compose exec -T postgres psql -X -tA -U postgres -d nutrianimales -c'
K=$(grep -E '^GROQ_API_KEY=' .env | cut -d= -f2-); T=$(grep -E '^TELEGRAM_BOT_TOKEN=' .env | cut -d= -f2-)

echo "== Secretos"
check ".env con permisos 600"                       '[ "$(stat -c %a .env)" = 600 ]'
check ".env ignorado por Git y nunca versionado"     'git check-ignore -q .env && [ -z "$(git log --all --format=%H -- .env)" ]'
check "Sin API keys/tokens en el historial de Git"   '! git log --all -p | grep -qE "gsk_[A-Za-z0-9]{20}|bot[0-9]{8,10}:[A-Za-z0-9_-]{30}"'
check "n8n no recibe secretos por variables de entorno" '! docker compose exec -T n8n env | grep -qE "GROQ|TELEGRAM|MONITOR_PASSWORD|AGENTE_IA"'
check "Los logs de n8n no contienen secretos"        '! docker compose logs n8n 2>&1 | grep -qF -e "$K" -e "$T"'
check "Los JSON de flujos no contienen secretos"     '! grep -rqF -e "$K" -e "$T" n8n/'
check "n8n bloquea \$env en nodos (N8N_BLOCK_ENV_ACCESS_IN_NODE)" 'docker compose exec -T n8n env | grep -qx "N8N_BLOCK_ENV_ACCESS_IN_NODE=true"'

echo "== Red y exposición"
check "PostgreSQL 5432 NO accesible desde el host"   '! timeout 2 bash -c "</dev/tcp/127.0.0.1/5432"'
check "n8n 5678 NO accesible directamente"           '! timeout 2 bash -c "</dev/tcp/127.0.0.1/5678"'
check "HTTP 8080 redirige a HTTPS"                   'curl -sI http://localhost:8080 | grep -qiE "^location: https://"'
check "HTTPS 8443 con TLS 1.3"                       'openssl s_client -connect localhost:8443 -servername localhost </dev/null 2>/dev/null | grep -q TLSv1.3'
check "Cabeceras HSTS, X-Frame-Options DENY, nosniff y CSP" 'h=$(curl -sI --cacert infra/certs/server.crt https://localhost:8443/); for x in strict-transport-security "x-frame-options: deny" nosniff content-security-policy; do grep -qi "$x" <<<"$h" || exit 1; done'
check "Puertos de Nginx solo en 127.0.0.1"           '! docker compose ps --format "{{.Ports}}" | grep -q "0.0.0.0"'

echo "== PostgreSQL"
check "ssl = on"                                     '[ "$($PSQL "SHOW ssl")" = on ]'
check "password_encryption = scram-sha-256"          '[ "$($PSQL "SHOW password_encryption")" = scram-sha-256 ]'
check "Conexión de red sin TLS es rechazada"         'docker compose exec -T postgres sh -c "PGPASSWORD=\$AGENTE_IA_PASSWORD psql -X \"host=postgres dbname=nutrianimales user=agente_ia sslmode=disable\" -c \"SELECT 1\"" 2>&1 | grep -q "pg_hba.conf rejects"'
check "agente_ia no puede escribir (INSERT falla)"   'docker compose exec -T postgres sh -c "PGPASSWORD=\$AGENTE_IA_PASSWORD psql -X -U agente_ia -d nutrianimales -c \"INSERT INTO clientes(nombre,tipo,correo,segmento) VALUES (1,1,1,1)\"" 2>&1 | grep -qE "read-only|permission denied"'
check "rol_gerente sin acceso a auditoria_datos"     'docker compose exec -T postgres sh -c "PGPASSWORD=\$GERENTE_PASSWORD psql -X -U gerente_db -d nutrianimales -c \"SELECT 1 FROM auditoria_datos LIMIT 1\"" 2>&1 | grep -q "permission denied"'
check "Ninguna cuenta de aplicación es superusuario" '[ "$($PSQL "SELECT count(*) FROM pg_roles WHERE rolsuper AND rolname<>'"'"'postgres'"'"'")" = 0 ]'
check "Configuración igual a pg_settings_baseline"   '[ "$($PSQL "SELECT count(*) FROM pg_settings s JOIN pg_settings_baseline b USING(name) WHERE s.setting<>b.valor_esperado")" = 0 ]'
check "Triggers de auditoría en las 4 tablas críticas" '[ "$($PSQL "SELECT count(DISTINCT event_object_table) FROM information_schema.triggers WHERE trigger_name LIKE '"'"'trg_auditoria_%'"'"'")" = 4 ]'

echo "== Contenedores y n8n"
check "n8n, nginx, filebeat y pgadmin sin root"      'for s in n8n nginx filebeat pgadmin; do [ "$(docker compose exec -T $s id -u | tr -d "\r")" != 0 ] || exit 1; done'
check "Todos los contenedores en ejecución"          '[ "$(docker compose ps --status running -q | wc -l)" -ge 5 ]'
check "n8n responde por HTTPS (healthz)"             'curl -s --cacert infra/certs/server.crt https://localhost:8443/healthz | grep -q ok'

echo; echo "Resultado: $ok PASS, $mal FALLA"
[ "$mal" -eq 0 ]
