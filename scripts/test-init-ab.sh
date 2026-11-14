#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
name=nutri-ab-init-check
if docker container inspect "$name" >/dev/null 2>&1; then
  printf 'Container name already in use: %s\n' "$name" >&2
  exit 1
fi

cleanup() {
  if docker container inspect "$name" >/dev/null 2>&1; then
    docker stop "$name" >/dev/null
    for attempt in $(seq 1 30); do
      if ! docker container inspect "$name" >/dev/null 2>&1; then
        return
      fi
      sleep 1
    done
    printf 'Temporary container was not removed: %s\n' "$name" >&2
    exit 1
  fi
}
trap cleanup EXIT

docker run -d --rm --name "$name" --network none --env-file .env \
  -e POSTGRES_USER=postgres -e POSTGRES_DB=nutrianimales \
  -e 'POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=trust' \
  -v "$PWD/db/sql:/docker-entrypoint-initdb.d:ro" \
  -v "$PWD/infra/postgresql.conf:/etc/postgresql/postgresql.conf:ro" \
  -v "$PWD/infra/pg_hba.conf:/etc/postgresql/pg_hba.conf:ro" \
  -v "$PWD/infra/postgres-tls:/run/pg-tls:ro" \
  -v /var/log/postgresql \
  postgres:16.14 postgres -c config_file=/etc/postgresql/postgresql.conf \
  >/dev/null

ready=0
for attempt in $(seq 1 90); do
  if initialized="$(docker exec "$name" psql -X -U postgres -d nutrianimales \
    -Atqc "SELECT current_setting('listen_addresses')='*' AND (SELECT count(*) FROM clientes)=1500 AND (SELECT count(*) FROM pg_settings_baseline)=7 AND (SELECT count(*) FROM information_schema.triggers WHERE trigger_schema='public')=20" 2>/dev/null)"; then
    if [ "$initialized" = "t" ]; then
      ready=1
      break
    fi
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  printf '%s\n' 'Fresh database initialization did not reach the expected seed count.' >&2
  exit 1
fi

docker exec "$name" psql -X -U postgres -d nutrianimales -Atqc \
  "SELECT 'tables='||(SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE')||', triggers='||(SELECT count(*) FROM information_schema.triggers WHERE trigger_schema='public')||', baseline='||(SELECT count(*) FROM pg_settings_baseline)"
