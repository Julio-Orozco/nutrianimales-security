#!/bin/sh
# Migra n8n de monitor_db a la cuenta dedicada n8n_app sin borrar volúmenes.
# 1) respalda la base y el volumen n8n_data y verifica los respaldos;
# 2) aplica db/sql/06-n8n.sqb (idempotente) en la base existente;
# 3) recrea solo el contenedor n8n y comprueba que escucha en 5678.
set -eu

cd "$(dirname "$0")/.."
umask 077

[ -f .env ] || { echo 'Falta .env: ejecuta scripts/prepare-ab.sh' >&2; exit 1; }
if ! grep -q '^N8N_DB_PASSWORD=.' .env; then
  printf 'N8N_DB_PASSWORD=%s\n' "$(openssl rand -hex 32)" >> .env
  echo 'Se agregó N8N_DB_PASSWORD a .env (las demás variables no se modificaron).'
fi
chmod 600 .env
n8n_password="$(sed -n 's/^N8N_DB_PASSWORD=//p' .env | tail -1)"

# --- 1. Respaldo verificable -------------------------------------------------
backup=".runtime/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
chmod 700 .runtime "$backup"
docker exec nutrianimales_db pg_dump -U postgres -d nutrianimales -Fc > "$backup/nutrianimales.dump"
docker exec nutrianimales_db pg_dumpall -U postgres --roles-only --no-role-passwords > "$backup/roles.sql"
docker exec nutrianimales_n8n tar -czf - -C /home/node/.n8n . > "$backup/n8n_data.tgz"
objetos="$(docker exec -i nutrianimales_db pg_restore --list < "$backup/nutrianimales.dump" | grep -vc '^;')"
tar -tzf "$backup/n8n_data.tgz" | grep -q '^./config$'
grep -q 'CREATE ROLE monitor_db' "$backup/roles.sql"
echo "Respaldo verificado en $backup ($objetos objetos en el dump; n8n_data contiene config)."

# --- 2. Cuenta dedicada n8n_app ----------------------------------------------
{
  printf "\\set n8n_password '%s'\n" "$n8n_password"
  cat db/sql/06-n8n.sqb
} | docker exec -i nutrianimales_db psql -X -q -v ON_ERROR_STOP=1 -U postgres -d nutrianimales

docker exec nutrianimales_db psql -X -U postgres -d nutrianimales -Atc "
SELECT 'n8n owner='||pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='n8n';
SELECT 'n8n_app USAGE='||has_schema_privilege('n8n_app','n8n','USAGE')||' CREATE='||has_schema_privilege('n8n_app','n8n','CREATE');
SELECT 'monitor_db USAGE='||has_schema_privilege('monitor_db','n8n','USAGE')||' CREATE='||has_schema_privilege('monitor_db','n8n','CREATE');
SELECT 'n8n_app superuser='||rolsuper||' createrole='||rolcreaterole||' createdb='||rolcreatedb FROM pg_roles WHERE rolname='n8n_app';"

# --- 3. Recrear solo n8n -----------------------------------------------------
docker compose up -d --no-deps n8n
for intento in $(seq 1 90); do
  if docker exec nutrianimales_n8n wget -qO- http://127.0.0.1:5678/healthz 2>/dev/null | grep -q ok; then
    echo "n8n escucha en 5678 (healthz ok tras ${intento}s)."
    curl -ks -o /dev/null -w 'https://localhost:8443/ -> HTTP %{http_code}\n' https://localhost:8443/
    exit 0
  fi
  sleep 1
done
echo 'n8n no respondió en 90 s: revisa docker logs nutrianimales_n8n' >&2
exit 1
