set -euo pipefail
psql -v ON_ERROR_STOP=1 --username postgres --dbname nutrianimales \
  -v monitor_password="$MONITOR_PASSWORD" -v agente_password="$AGENTE_IA_PASSWORD" \
  -v gerente_password="$GERENTE_PASSWORD" -v ti_password="$TI_PASSWORD" \
  -v auditor_password="$AUDITOR_PASSWORD" -v backup_password="$BACKUP_PASSWORD" \
  -f /docker-entrypoint-initdb.d/01-roles.sqb

for sql in 02-schema.sqb 03-seed.sqb 04-audit.sqb 05-access.sqb; do
  psql -v ON_ERROR_STOP=1 --username postgres --dbname nutrianimales \
    -f "/docker-entrypoint-initdb.d/$sql"
done