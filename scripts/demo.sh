#!/usr/bin/env bash
# Escenarios de la demostración en vivo: cada subcomando provoca UNA alerta.
# Uso: bash scripts/demo.sh <escenario>      (bash scripts/demo.sh ayuda)
# Las alertas llegan a Telegram en el siguiente ciclo de n8n (<= 30 s).
set -euo pipefail
cd "$(dirname "$0")/.."

envv() { grep -E "^$1=" .env | cut -d= -f2-; }
sql()  { docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d nutrianimales "$@"; }
como() { # como <usuario> <VAR_PASSWORD> psql-args...
  local u=$1 v=$2; shift 2
  docker compose exec -T -e PGPASSWORD="$(envv "$v")" postgres psql -X -v ON_ERROR_STOP=1 -U "$u" -d nutrianimales "$@"; }
titulo() { printf '\n\033[1;36m== %s\033[0m\n%s\n\n' "$1" "$2"; }

case "${1:-ayuda}" in
r1)
  titulo "R1 Consulta lenta" "Ejecuta una consulta de 1,5 s (umbral 1 s). Fuente: pg_stat_statements."
  sql -c "SELECT pg_sleep(1.5) AS consulta_lenta_simulada;" ;;
r2)
  titulo "R2 Saturación de conexiones" "Abre 12 sesiones activas simultáneas durante 45 s (umbral 10)."
  for _ in $(seq 1 12); do sql -q -c "SELECT pg_sleep(45);" >/dev/null & done
  sleep 2; sql -c "SELECT count(*) AS sesiones_activas FROM pg_stat_activity WHERE state='active' AND backend_type='client backend';"
  echo "Esperando que terminen (45 s)…"; wait ;;
r3)
  H=$(sql -tA -c "SELECT extract(hour FROM now() AT TIME ZONE 'America/Costa_Rica')::int" | tr -d '\r')
  titulo "R3 Conexión en horario no laboral" "Para demostrarlo en horario de clase se declara temporalmente no laboral la hora actual (${H}:00), gerente_db se conecta 45 s y luego se restaura 23:00-06:00."
  sql -c "UPDATE parametros_alerta SET valor='$H' WHERE clave='r3_hora_inicio'; UPDATE parametros_alerta SET valor='$(( (H + 1) % 24 ))' WHERE clave='r3_hora_fin'; SELECT * FROM parametros_alerta;"
  como gerente_db GERENTE_PASSWORD -c "SELECT current_user, now()::time(0) AS hora, pg_sleep(45) IS NULL AS sesion_abierta;" || true
  sql -c "UPDATE parametros_alerta SET valor='23' WHERE clave='r3_hora_inicio'; UPDATE parametros_alerta SET valor='6' WHERE clave='r3_hora_fin'; SELECT * FROM parametros_alerta;" ;;
r4)
  titulo "R4 Autenticación fallida en PostgreSQL" "8 intentos con contraseña incorrecta para gerente_db (umbral: más de 5 en 10 min). Fuente: log JSON de PostgreSQL."
  for i in $(seq 1 8); do
    docker compose exec -T -e PGPASSWORD="clave_incorrecta_$i" postgres \
      psql -X "host=127.0.0.1 sslmode=require dbname=nutrianimales user=gerente_db" -c "SELECT 1" 2>&1 | tail -1 || true
  done ;;
a1)
  titulo "A1 Fuerza bruta SSH" "20 intentos SSH con usuario y contraseña incorrectos contra este equipo. El agente del host (sudo bash scripts/agente-host.sh) debe estar corriendo; R4 alerta."
  command -v sshpass >/dev/null || { echo "Instala sshpass: sudo apt install -y sshpass"; exit 1; }
  for i in $(seq 1 20); do
    sshpass -p "clave_incorrecta_$i" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o PubkeyAuthentication=no -o PreferredAuthentications=password -o LogLevel=ERROR -o ConnectTimeout=5 \
      atacante@localhost true 2>/dev/null || printf 'intento %2d: Permission denied\n' "$i"
  done
  echo; grep -E 'sshd.*(Failed password|Invalid user)' /var/log/auth.log | tail -3 ;;
r5)
  titulo "R5 Cambio en postgresql.conf" "ALTER SYSTEM SET work_mem = '8MB' + recarga. Revertir con: bash scripts/demo.sh r5-revertir"
  sql -c "ALTER SYSTEM SET work_mem = '8MB';" -c "SELECT pg_reload_conf();" -c "SHOW work_mem;" ;;
r5-revertir)
  sql -c "ALTER SYSTEM RESET work_mem;" -c "SELECT pg_reload_conf();" -c "SHOW work_mem;" ;;
h2)
  titulo "H2 pg_hba.conf modificado" "Se agrega una línea al final de infra/pg_hba.conf (archivo montado en el contenedor). Revertir con: bash scripts/demo.sh h2-revertir"
  mkdir -p .runtime; chmod 700 .runtime
  [ -f .runtime/pg_hba.conf.original ] || cp infra/pg_hba.conf .runtime/pg_hba.conf.original
  echo "# cambio no autorizado $(date '+%F %T')" >> infra/pg_hba.conf   # >> conserva el inodo del bind mount
  tail -2 infra/pg_hba.conf
  sql -c "SELECT key AS archivo, left(value,16) AS hash_actual FROM jsonb_each_text(security_snapshot()->'hashes');" ;;
h2-revertir)
  [ -f .runtime/pg_hba.conf.original ] || { echo "No hay copia original"; exit 1; }
  cat .runtime/pg_hba.conf.original > infra/pg_hba.conf && rm .runtime/pg_hba.conf.original   # cat > conserva el inodo
  git diff --stat -- infra/pg_hba.conf; echo "pg_hba.conf restaurado." ;;
h3|a4)
  titulo "A4 / H3 Escalada de privilegios" "GRANT INSERT ON ALL TABLES IN SCHEMA public TO agente_ia. Revertir con: bash scripts/demo.sh h3-revertir"
  sql -c "GRANT INSERT ON ALL TABLES IN SCHEMA public TO agente_ia;" \
      -c "SELECT security_snapshot()->'privilegios_agente'->'escritura' AS tablas_con_escritura;" ;;
h3-revertir)
  sql -c "REVOKE INSERT ON ALL TABLES IN SCHEMA public FROM agente_ia;" \
      -c "SELECT security_snapshot()->'privilegios_agente' AS agente_ia;" ;;
h4)
  titulo "H4 Conexión desde IP fuera de la red Docker" "Se conecta la BD a una red 'red-externa' (10.99.0.0/24) y un cliente de esa red abre sesión 45 s; luego se desconecta y se borra la red."
  docker network create --subnet 10.99.0.0/24 red-externa >/dev/null 2>&1 || true
  docker network connect red-externa nutrianimales_db 2>/dev/null || true
  docker run --rm --network red-externa -e PGPASSWORD="$(envv GERENTE_PASSWORD)" postgres:16.14 \
    psql "host=nutrianimales_db dbname=nutrianimales user=gerente_db sslmode=require" \
    -c "SELECT inet_client_addr() AS mi_ip, pg_sleep(45) IS NULL AS sesion_abierta;" || true
  docker network disconnect red-externa nutrianimales_db 2>/dev/null || true
  docker network rm red-externa >/dev/null 2>&1 || true
  echo "Red externa retirada." ;;
h5)
  titulo "H5 Autenticación degradada a MD5" "ALTER SYSTEM SET password_encryption = 'md5' + recarga (también dispara R5 y H2). Revertir con: bash scripts/demo.sh h5-revertir"
  sql -c "ALTER SYSTEM SET password_encryption = 'md5';" -c "SELECT pg_reload_conf();" -c "SHOW password_encryption;" ;;
h5-revertir)
  sql -c "ALTER SYSTEM RESET password_encryption;" -c "SELECT pg_reload_conf();" -c "SHOW password_encryption;" ;;
d1)
  titulo "D1 DELETE masivo sin WHERE" "Sobre una copia de ventas (como en la guía): DELETE sin WHERE de 1500 filas (umbral 100)."
  sql -c "DROP TABLE IF EXISTS prueba_delete;" -c "CREATE TABLE prueba_delete AS SELECT * FROM ventas;" \
      -c "DELETE FROM prueba_delete;" -c "DROP TABLE prueba_delete;" ;;
d2)
  titulo "D2 Crecimiento anormal de tabla" "Inserta 400 ventas ficticias de golpe (+26 %, umbral 20 % en 30 min)."
  sql -c "INSERT INTO ventas (cliente_id, producto_id, cantidad, precio_total, estado)
          SELECT 1 + (n % 1500), 1 + (n % 50), 1, 100, 'prueba_d2' FROM generate_series(1, 400) n;" \
      -c "SELECT count(*) AS total_ventas FROM ventas;" ;;
d3)
  titulo "D3 Backup obsoleto" "La alerta se dispara sola si no hay backup 'ok' en 24 h. Estado actual de la tabla backups:"
  sql -c "SELECT id, fecha, estado, ruta FROM backups ORDER BY id DESC LIMIT 5;"
  echo "Para resolverla: bash scripts/backup.sh" ;;
d4)
  titulo "D4 Duplicados en tabla crítica" "Inserta 6 clientes con el mismo correo (umbral 5). Revertir con: bash scripts/demo.sh d4-revertir"
  sql -c "INSERT INTO clientes (nombre, tipo, correo, segmento)
          SELECT 'Cliente duplicado '||n, 'persona', 'duplicado.demo@example.invalid', 'demo' FROM generate_series(1, 6) n;" \
      -c "SELECT correo, count(*) FROM clientes GROUP BY correo HAVING count(*) > 5;" ;;
d4-revertir)
  sql -c "DELETE FROM clientes WHERE correo = 'duplicado.demo@example.invalid';" ;;
d5)
  titulo "D5 Transacción bloqueada" "La sesión A bloquea el producto 1 durante 50 s; la sesión B espera el bloqueo (> 30 s)."
  sql -q -c "BEGIN; UPDATE productos SET precio_unitario = precio_unitario WHERE id = 1; SELECT pg_sleep(50); COMMIT;" >/dev/null &
  until sql -tA -c "SELECT count(*) FROM pg_stat_activity WHERE query LIKE 'BEGIN; UPDATE productos%' AND state = 'active'" | grep -q '^1'; do sleep 0.5; done
  echo "Sesión A mantiene el bloqueo; la sesión B queda esperando…"
  sql -c "UPDATE productos SET precio_unitario = precio_unitario WHERE id = 1;" -c "SELECT 'bloqueo liberado' AS estado;"
  wait ;;
d6)
  titulo "D6 UPDATE masivo sin WHERE" "Escenario de la guía: copia de 200 lotes y UPDATE sin WHERE (umbral 50)."
  sql -c "DROP TABLE IF EXISTS prueba_update;" -c "CREATE TABLE prueba_update AS SELECT * FROM lotes_produccion LIMIT 200;" \
      -c "UPDATE prueba_update SET estado = 'cancelado';" -c "DROP TABLE prueba_update;" ;;
d6-real)
  titulo "D6 sobre la tabla real + recuperación desde auditoría" "UPDATE sin WHERE en lotes_produccion y restauración usando auditoria_datos.valor_antes."
  sql -c "UPDATE lotes_produccion SET estado = 'cancelado';" \
      -c "SELECT estado, count(*) FROM lotes_produccion GROUP BY estado;" \
      -c "UPDATE lotes_produccion l SET estado = a.valor_antes->>'estado'
          FROM (SELECT DISTINCT ON (fila_id) fila_id, valor_antes FROM auditoria_datos
                WHERE tabla='lotes_produccion' AND operacion='UPDATE' AND valor_nuevo->>'estado'='cancelado'
                ORDER BY fila_id, id DESC) a
          WHERE l.id = a.fila_id;" \
      -c "SELECT estado, count(*) FROM lotes_produccion GROUP BY estado;" ;;
d7|a5)
  titulo "A5 / D7 Exfiltración" "SELECT * FROM clientes con el usuario agente_ia (devuelve 1500+ filas, umbral 1000)."
  como agente_ia AGENTE_IA_PASSWORD -c "SELECT * FROM clientes;" | tail -2
  como agente_ia AGENTE_IA_PASSWORD -c "INSERT INTO clientes(nombre,tipo,correo,segmento) VALUES ('x','x','x','x');" 2>&1 | tail -1 || true ;;
estado)
  sql -c "SELECT alerta, estado, to_char(fecha,'HH24:MI:SS') AS hora, left(mensaje,45) AS mensaje FROM alertas_auditoria ORDER BY fecha DESC LIMIT 15;" ;;
*)
  cat <<'EOF'
Escenarios:  r1 r2 r3 r4 r5 | a1 (SSH) | h2 h3/a4 h4 h5 | d1 d2 d3 d4 d5 d6 d6-real d7/a5 | estado
Reversión:   r5-revertir h2-revertir h3-revertir h5-revertir d4-revertir
H1/A3 (UFW) se hace a mano:  sudo ufw allow 5432/tcp   y luego   sudo ufw delete allow 5432/tcp
A2 (SQL injection) se hace desde Telegram:  Lista datos; DROP TABLE clientes; --
EOF
  ;;
esac
