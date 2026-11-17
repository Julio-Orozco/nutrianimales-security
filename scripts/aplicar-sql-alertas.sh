#!/usr/bin/env bash
# Aplica db/sql/07-alertas.sqb sobre una base YA inicializada (idempotente).
# En una instalación limpia no hace falta: 00-init.sh ya lo ejecuta.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T postgres psql -X -q -v ON_ERROR_STOP=1 -U postgres -d nutrianimales \
  -f /docker-entrypoint-initdb.d/07-alertas.sqb
echo "OK: soporte de alertas aplicado (parametros_alerta, archivos_baseline, eventos_log_pg, trg_evento_grant)."
