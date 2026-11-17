#!/usr/bin/env bash
# Respaldo lógico con la cuenta de mínimo privilegio backup_db (pg_read_all_data).
# Registra el resultado en la tabla backups: es la fuente de la alerta D3.
set -euo pipefail
cd "$(dirname "$0")/.."
BACKUP_PASSWORD=$(grep -E '^BACKUP_PASSWORD=' .env | cut -d= -f2-)
DIR=.runtime/backups; mkdir -p "$DIR"; chmod 700 .runtime "$DIR"
ARCHIVO="$DIR/nutrianimales-$(date +%Y%m%d-%H%M%S).dump"
pg() { docker compose exec -T -e PGPASSWORD="$BACKUP_PASSWORD" postgres "$@"; }

if pg pg_dump -U backup_db -d nutrianimales -Fc > "$ARCHIVO"; then
  chmod 600 "$ARCHIVO"
  SHA=$(sha256sum "$ARCHIVO" | awk '{print $1}'); TAM=$(stat -c %s "$ARCHIVO")
  pg psql -X -q -v ON_ERROR_STOP=1 -U backup_db -d nutrianimales -v ruta="$ARCHIVO" -v sha="$SHA" -v tam="$TAM" \
    >/dev/null <<'SQL'
INSERT INTO backups (estado, ruta, sha256, tamano) VALUES ('ok', :'ruta', :'sha', :'tam'::bigint);
SQL
  echo "OK: respaldo $ARCHIVO ($TAM bytes, sha256 ${SHA:0:16}…) registrado en la tabla backups."
else
  pg psql -X -q -U backup_db -d nutrianimales -v ruta="$ARCHIVO" >/dev/null <<'SQL' || true
INSERT INTO backups (estado, ruta) VALUES ('fallido', :'ruta');
SQL
  echo "ERROR: el respaldo falló; quedó registrado como 'fallido'." >&2; exit 1
fi
