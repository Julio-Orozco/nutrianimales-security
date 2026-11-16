#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/nutrianimales-seguridad"
cd "$REPO_DIR"

mkdir -p .runtime
BASELINE_FILE=".runtime/h1-ufw-baseline.sha256"

if command -v ufw >/dev/null 2>&1; then
  UFW_ESTADO=$(sudo ufw status numbered 2>/dev/null || echo "ufw_sin_estado")
  UFW_REGLAS=$(sudo cat /etc/ufw/user.rules /etc/ufw/user6.rules 2>/dev/null || echo "$UFW_ESTADO")
else
  UFW_ESTADO="ufw_no_instalado"
  UFW_REGLAS="ufw_no_instalado"
fi

HASH_ACTUAL=$(printf '%s\n%s' "$UFW_ESTADO" "$UFW_REGLAS" | sha256sum | awk '{print $1}')

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "$HASH_ACTUAL" > "$BASELINE_FILE"
  echo "Baseline inicial de UFW guardado: $HASH_ACTUAL"
  exit 0
fi

HASH_ANTERIOR=$(tr -d '[:space:]' < "$BASELINE_FILE")

if [[ "$HASH_ACTUAL" == "$HASH_ANTERIOR" ]]; then
  echo "Sin cambios en reglas UFW (hash: ${HASH_ACTUAL:0:12}...)"
  exit 0
fi

echo "Cambio detectado en reglas UFW: ${HASH_ANTERIOR:0:12}... -> ${HASH_ACTUAL:0:12}..."

PASS=$(grep '^MONITOR_PASSWORD=' .env | cut -d= -f2-)
HUELLA="H1-${HASH_ACTUAL}-$(date +%s)"

DETALLE=$(printf '{"regla":"H1","fuente":"host-ubuntu-ufw","hash_anterior":"%s","hash_actual":"%s"}' \
  "$HASH_ANTERIOR" "$HASH_ACTUAL")

sudo docker compose exec -T -e PGPASSWORD="$PASS" postgres psql -X -v ON_ERROR_STOP=1 -U monitor_db -d nutrianimales \
  -c "INSERT INTO alertas_auditoria (tipo, alerta, mensaje, detalles, severidad, huella, estado)
      VALUES ('hardening', 'H1', 'Modificación detectada en las reglas del firewall UFW', '$DETALLE'::jsonb, 'media', '$HUELLA', 'pendiente')
      ON CONFLICT (huella) DO NOTHING
      RETURNING id, huella;"

echo "$HASH_ACTUAL" > "$BASELINE_FILE"
echo "Alerta H1 registrada como pendiente en alertas_auditoria"
