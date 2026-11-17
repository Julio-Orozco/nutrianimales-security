#!/usr/bin/env bash
# Agente del host (Ubuntu/WSL) para las alertas que nacen FUERA de PostgreSQL:
#   H1 / A3 -> cambios en las reglas UFW (hash de "ufw status" + user.rules)
#   R4 / A1 -> intentos SSH fallidos leídos de /var/log/auth.log
# No envía Telegram: deja el evento en PostgreSQL (como monitor_db) y los flujos
# n8n H1 y R4 lo detectan y notifican. Basado en scripts/check-h1-ufw.sh (integrante 3).
#
# Uso:  sudo bash scripts/agente-host.sh            # bucle cada 10 s (dejar abierto)
#       sudo bash scripts/agente-host.sh --una-vez  # una sola revisión
# Requiere root para leer UFW. Sin root solo vigila SSH (grupo adm).
set -euo pipefail
cd "$(dirname "$0")/.."

INTERVALO="${INTERVALO:-10}"
ESTADO=".runtime/agente"
AUTH_LOG="${AUTH_LOG:-/var/log/auth.log}"
mkdir -p "$ESTADO"; chmod 700 .runtime "$ESTADO"

MONITOR_PASSWORD=$(grep -E '^MONITOR_PASSWORD=' .env | cut -d= -f2-)
[ -n "$MONITOR_PASSWORD" ] || { echo "Falta MONITOR_PASSWORD en .env" >&2; exit 1; }

psql_monitor() {
  # Las variables psql (-v) se citan con :'var', sin concatenar texto en SQL.
  docker compose exec -T -e PGPASSWORD="$MONITOR_PASSWORD" postgres \
    psql -X -q -t -A -v ON_ERROR_STOP=1 -U monitor_db -d nutrianimales "$@"
}

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

# ---------------------------------------------------------------- UFW (H1)
revisar_ufw() {
  if [ "$(id -u)" -ne 0 ]; then return 0; fi
  command -v ufw >/dev/null || return 0
  local estado reglas hash anterior agregadas eliminadas det
  estado=$(ufw status verbose 2>/dev/null || echo "ufw_sin_estado")
  reglas=$(cat /etc/ufw/user.rules /etc/ufw/user6.rules 2>/dev/null || true)
  hash=$(printf '%s\n%s' "$estado" "$reglas" | sha256sum | awk '{print $1}')

  if [ ! -f "$ESTADO/ufw.sha256" ]; then
    echo "$hash" > "$ESTADO/ufw.sha256"; printf '%s\n' "$estado" > "$ESTADO/ufw.status"
    log "UFW: baseline registrado (${hash:0:12}…)"; return 0
  fi
  anterior=$(cat "$ESTADO/ufw.sha256")
  [ "$hash" = "$anterior" ] && return 0

  agregadas=$(comm -13 <(sort "$ESTADO/ufw.status") <(printf '%s\n' "$estado" | sort) | grep -v '^\s*$' || true)
  eliminadas=$(comm -23 <(sort "$ESTADO/ufw.status") <(printf '%s\n' "$estado" | sort) | grep -v '^\s*$' || true)
  det=$(jq -cn --arg a "$anterior" --arg n "$hash" --arg ag "$agregadas" --arg el "$eliminadas" \
        --arg st "$(printf '%s\n' "$estado" | head -1)" \
        '{fuente:"host-ufw", hash_anterior:$a, hash_actual:$n, estado:$st,
          agregadas:($ag|split("\n")|map(select(length>0))),
          eliminadas:($el|split("\n")|map(select(length>0)))}')

  if ! psql_monitor -v det="$det" -v hash="$hash" >/dev/null <<'SQL'
INSERT INTO alertas_auditoria (tipo, alerta, mensaje, detalles, severidad, huella, estado)
VALUES ('hardening','H1','Reglas UFW modificadas', :'det'::jsonb, 'critica',
        'H1-' || :'hash' || '-' || extract(epoch FROM clock_timestamp())::bigint, 'pendiente');
SELECT registrar_evento('ufw','regla_modificada', :'det'::jsonb, 'ufw-' || :'hash', now());
SQL
  then log "UFW: ERROR al registrar el cambio (se reintenta en el siguiente ciclo)"; return 1; fi
  echo "$hash" > "$ESTADO/ufw.sha256"; printf '%s\n' "$estado" > "$ESTADO/ufw.status"
  log "UFW: CAMBIO detectado -> alerta H1 pendiente. Agregadas: ${agregadas:-ninguna} | Eliminadas: ${eliminadas:-ninguna}"
}

# ---------------------------------------------------------------- SSH (R4)
revisar_ssh() {
  [ -r "$AUTH_LOG" ] || return 0
  local tam off lineas n
  tam=$(stat -c %s "$AUTH_LOG")
  if [ ! -f "$ESTADO/auth.offset" ]; then echo "$tam" > "$ESTADO/auth.offset"; log "SSH: vigilando $AUTH_LOG desde ahora"; return 0; fi
  off=$(cat "$ESTADO/auth.offset")
  [ "$tam" -lt "$off" ] && off=0   # el log se rotó
  [ "$tam" -eq "$off" ] && return 0
  lineas=$(tail -c +"$((off + 1))" "$AUTH_LOG" | grep -E 'sshd.*(Failed password|Invalid user)' || true)
  if [ -n "$lineas" ]; then
    # Un evento por conexión SSH (PID de sshd): "Invalid user" y "Failed password"
    # de un mismo intento no se cuentan dos veces.
    if ! n=$(psql_monitor -v lineas="$lineas" <<'SQL'
WITH l AS (
  SELECT l, coalesce(substring(l from 'sshd(?:-session)?\[(\d+)\]'), md5(l)) AS pid
  FROM regexp_split_to_table(:'lineas', E'\n') AS l WHERE l <> ''
), r AS (
  SELECT registrar_evento('ssh', 'auth_fallida',
    jsonb_build_object('linea', left(l, 300),
      'usuario', substring(l from '(?:for|user) (?:invalid user )?(\S+) from'),
      'ip', substring(l from 'from (\S+) port')),
    'ssh-' || pid || '-' || to_char(now(), 'YYYYMMDDHH24'),
    CASE WHEN l ~ '^\d{4}-\d{2}-\d{2}T' THEN split_part(l, ' ', 1)::timestamptz ELSE now() END)
  FROM l
)
SELECT (SELECT count(DISTINCT pid) FROM l) FROM (SELECT count(*) FROM r) x;
SQL
    ); then log "SSH: ERROR al registrar (se reintenta en el siguiente ciclo)"; return 1; fi
    log "SSH: $n intento(s) de login fallido registrados en eventos_seguridad -> R4 los evalúa"
  fi
  echo "$tam" > "$ESTADO/auth.offset"
}

[ "$(id -u)" -ne 0 ] && log "AVISO: sin root no se vigila UFW (H1). Ejecutar con sudo."
log "Agente del host iniciado (cada ${INTERVALO}s). Ctrl+C para detener."
while true; do
  revisar_ufw || log "UFW: error en la revisión"
  revisar_ssh || log "SSH: error en la revisión"
  [ "${1:-}" = "--una-vez" ] && break
  sleep "$INTERVALO"
done
