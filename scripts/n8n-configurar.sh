#!/usr/bin/env bash
# Configura n8n completo desde .env, sin pasos manuales en la interfaz:
#   1. Crea la cuenta propietaria si la instancia es nueva (N8N_OWNER_EMAIL/PASSWORD).
#   2. Crea/actualiza las 4 credenciales cifradas (Postgres monitor_db y agente_ia,
#      Telegram y Groq) con los valores de .env.
#   3. Importa los 18 flujos de n8n/workflows (17 alertas + bot B0), reemplaza los
#      marcadores __CRED_*__ / __TELEGRAM_*__ y los deja publicados (activos).
#   4. Reinicia n8n y verifica que todos queden activos.
#
# Uso:  bash scripts/n8n-configurar.sh                 # todo
#       bash scripts/n8n-configurar.sh --credenciales  # solo rotación de secretos
# Idempotente: se puede ejecutar las veces que haga falta.
set -euo pipefail
cd "$(dirname "$0")/.."

for v in N8N_OWNER_EMAIL N8N_OWNER_PASSWORD TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID GROQ_API_KEY MONITOR_PASSWORD AGENTE_IA_PASSWORD; do
  val=$(grep -E "^${v}=" .env | head -1 | cut -d= -f2- || true)
  [ -n "$val" ] || { echo "Falta $v en .env" >&2; exit 1; }
  printf -v "$v" '%s' "$val"
done
TELEGRAM_CHATS_EXTRA=$(grep -E '^TELEGRAM_CHATS_EXTRA=' .env | cut -d= -f2- || true)

BASE=https://localhost:8443
TMP=.runtime/n8n-config
mkdir -p "$TMP"; chmod 700 .runtime "$TMP"
JAR="$TMP/cookies"
trap 'rm -rf "$TMP"' EXIT
api() { curl -sS --fail-with-body --cacert infra/certs/server.crt -b "$JAR" -c "$JAR" -H 'Content-Type: application/json' "$@"; }

esperar_n8n() {
  for _ in $(seq 1 60); do
    if curl -s --cacert infra/certs/server.crt "$BASE/healthz" 2>/dev/null | grep -q '"ok"'; then
      curl -s -o /dev/null -w '%{http_code}' --cacert infra/certs/server.crt "$BASE/rest/settings" | grep -q 200 && return 0
    fi
    sleep 3
  done
  echo "n8n no respondió en $BASE" >&2; exit 1
}

echo "==> Esperando n8n en $BASE"
esperar_n8n

if api "$BASE/rest/settings" | jq -e '.data.userManagement.showSetupOnFirstLoad == true' >/dev/null; then
  echo "==> Instancia nueva: creando la cuenta propietaria $N8N_OWNER_EMAIL"
  api -X POST "$BASE/rest/owner/setup" -d "$(jq -n --arg e "$N8N_OWNER_EMAIL" --arg p "$N8N_OWNER_PASSWORD" \
      '{email:$e, firstName:"TI", lastName:"NutriAnimales", password:$p}')" >/dev/null
fi

echo "==> Iniciando sesión como $N8N_OWNER_EMAIL"
OWNER_ID=$(api -X POST "$BASE/rest/login" -d "$(jq -n --arg e "$N8N_OWNER_EMAIL" --arg p "$N8N_OWNER_PASSWORD" \
    '{emailOrLdapLoginId:$e, password:$p}')" | jq -r '.data.id')

CREDS=$(api "$BASE/rest/credentials")
upsert_cred() { # nombre tipo json_data -> imprime id
  local nombre=$1 tipo=$2 data=$3 id body
  id=$(jq -r --arg n "$nombre" '.data[] | select(.name==$n) | .id' <<<"$CREDS" | head -1)
  body=$(jq -n --arg n "$nombre" --arg t "$tipo" --argjson d "$data" '{name:$n, type:$t, data:$d}')
  if [ -n "$id" ]; then api -X PATCH "$BASE/rest/credentials/$id" -d "$body" >/dev/null; echo "$id"
  else api -X POST "$BASE/rest/credentials" -d "$body" | jq -r '.data.id'; fi
}
pg_data() { jq -n --arg u "$1" --arg p "$2" \
  '{host:"postgres", database:"nutrianimales", user:$u, password:$p, port:5432, ssl:"require", allowUnauthorizedCerts:false}'; }

echo "==> Credenciales cifradas en n8n (valores tomados de .env)"
CRED_MONITOR=$(upsert_cred "Nutri Postgres monitor_db" postgres "$(pg_data monitor_db "$MONITOR_PASSWORD")")
CRED_AGENTE=$(upsert_cred "Nutri Postgres agente_ia" postgres "$(pg_data agente_ia "$AGENTE_IA_PASSWORD")")
CRED_TELEGRAM=$(upsert_cred "Nutri Telegram bot" telegramApi "$(jq -n --arg t "$TELEGRAM_BOT_TOKEN" '{accessToken:$t, baseUrl:"https://api.telegram.org"}')")
CRED_GROQ=$(upsert_cred "Nutri Groq" groqApi "$(jq -n --arg k "$GROQ_API_KEY" '{apiKey:$k}')")
echo "    monitor_db=$CRED_MONITOR agente_ia=$CRED_AGENTE telegram=$CRED_TELEGRAM groq=$CRED_GROQ"

if [ "${1:-}" = "--credenciales" ]; then
  echo "OK: credenciales actualizadas. Los flujos usan la nueva versión en su siguiente ejecución."
  echo "    (Si rotaste TELEGRAM_BOT_TOKEN, ejecuta el script completo: el bot B0 también lo usa.)"
  exit 0
fi

CHATS="[$TELEGRAM_CHAT_ID${TELEGRAM_CHATS_EXTRA:+,$TELEGRAM_CHATS_EXTRA}]"
echo "==> Preparando 18 flujos (chat de alertas $TELEGRAM_CHAT_ID; chats del bot $CHATS)"
mkdir -p "$TMP/flujos"
for f in n8n/workflows/*.json; do
  sed -e "s|__CRED_MONITOR__|$CRED_MONITOR|g" -e "s|__CRED_AGENTE__|$CRED_AGENTE|g" \
      -e "s|__CRED_TELEGRAM__|$CRED_TELEGRAM|g" -e "s|__CRED_GROQ__|$CRED_GROQ|g" \
      -e "s|__TELEGRAM_CHAT_ID__|$TELEGRAM_CHAT_ID|g" -e "s|__TELEGRAM_BOT_TOKEN__|$TELEGRAM_BOT_TOKEN|g" \
      -e "s|__TELEGRAM_CHATS_PERMITIDOS__|$CHATS|g" "$f" > "$TMP/flujos/$(basename "$f")"
done
if grep -l '__[A-Z_]*__' "$TMP"/flujos/*.json; then echo "Quedaron marcadores sin reemplazar" >&2; exit 1; fi

# Los flujos que aún no existen se importan con la CLI (conserva su id fijo);
# los existentes se actualizan por la API REST: la CLI no sobrescribe flujos ya creados.
mkdir -p "$TMP/nuevos"
for f in "$TMP"/flujos/*.json; do
  id=$(jq -r '.id' "$f")
  code=$(curl -s -o /dev/null -w '%{http_code}' --cacert infra/certs/server.crt -b "$JAR" "$BASE/rest/workflows/$id")
  [ "$code" = 200 ] || cp "$f" "$TMP/nuevos/"
done
if ls "$TMP"/nuevos/*.json >/dev/null 2>&1; then
  echo "==> Importando $(ls "$TMP"/nuevos/*.json | wc -l) flujo(s) nuevos (CLI import:workflow)"
  docker compose exec -T -u root n8n rm -rf /tmp/nutri-flujos
  docker compose cp "$TMP/nuevos" n8n:/tmp/nutri-flujos >/dev/null 2>&1
  docker compose exec -T -u root n8n chmod -R a+rX /tmp/nutri-flujos
  docker compose exec -T n8n n8n import:workflow --separate --input=/tmp/nutri-flujos \
    --userId="$OWNER_ID" 2>&1 | grep -iE 'success|error|import' | grep -vi 'tracking' || true
  docker compose exec -T -u root n8n rm -rf /tmp/nutri-flujos
  echo "==> Reiniciando n8n para cargar los flujos importados"
  docker compose restart n8n >/dev/null 2>&1
  esperar_n8n
  api -X POST "$BASE/rest/login" -d "$(jq -n --arg e "$N8N_OWNER_EMAIL" --arg p "$N8N_OWNER_PASSWORD" \
      '{emailOrLdapLoginId:$e, password:$p}')" >/dev/null
fi

echo "==> Actualizando y publicando (activando) los 18 flujos"
for f in "$TMP"/flujos/*.json; do
  id=$(jq -r '.id' "$f")
  actual=$(api "$BASE/rest/workflows/$id")
  body=$(jq -c --slurpfile nuevo "$f" '{versionId: .data.versionId, name: $nuevo[0].name,
          nodes: $nuevo[0].nodes, connections: $nuevo[0].connections, settings: $nuevo[0].settings}' <<<"$actual")
  version=$(api -X PATCH "$BASE/rest/workflows/$id" -d "$body" | jq -r '.data.versionId')
  if ! api -X POST "$BASE/rest/workflows/$id/activate" -d "$(jq -cn --arg v "$version" '{versionId:$v}')" >/dev/null; then
    echo "    ERROR al activar $(jq -r '.name' "$f")" >&2
  fi
done

echo
api "$BASE/rest/workflows" | jq -r '.data[] | select(.name|startswith("Nutri ")) | [(if .active then "ACTIVO  " else "inactivo" end), .name] | @tsv' | sort -k2
TOTAL=$(api "$BASE/rest/workflows" | jq '[.data[] | select((.name|startswith("Nutri ")) and .active)] | length')
echo
echo "Flujos Nutri activos: $TOTAL / 18"
[ "$TOTAL" -eq 18 ] || { echo "ATENCIÓN: no todos los flujos quedaron activos" >&2; exit 1; }
