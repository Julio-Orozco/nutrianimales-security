#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
umask 077

if [ ! -f .env ]; then
  {
    printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'MONITOR_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'AGENTE_IA_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'GERENTE_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'TI_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'AUDITOR_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'BACKUP_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'N8N_ENCRYPTION_KEY=%s\n' "$(openssl rand -hex 32)"
    printf 'PGADMIN_DEFAULT_EMAIL=%s\n' 'ti@nutrianimales.test'
    printf 'PGADMIN_DEFAULT_PASSWORD=%s\n' "$(openssl rand -hex 32)"
    printf 'TELEGRAM_BOT_TOKEN=\n'
    printf 'GROQ_API_KEY=\n'
  } > .env
fi
chmod 600 .env

mkdir -p infra/certs infra/postgres-tls
if [ ! -s infra/certs/server.crt ] || [ ! -s infra/certs/server.key ]; then
  openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
    -keyout infra/certs/server.key -out infra/certs/server.crt \
    -subj '/C=CR/O=NutriAnimales/CN=localhost' \
    -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'
fi
chmod 600 infra/certs/server.key
chmod 644 infra/certs/server.crt

if [ ! -s infra/postgres-tls/server.crt ] || [ ! -s infra/postgres-tls/server.key ]; then
  openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
    -keyout infra/postgres-tls/server.key -out infra/postgres-tls/server.crt \
    -subj '/O=NutriAnimales/CN=postgres' \
    -addext 'subjectAltName=DNS:postgres,DNS:nutrianimales_db'
fi
chmod 644 infra/postgres-tls/server.crt

postgres_uid="$(docker run --rm --entrypoint id postgres:16.14 -u postgres)"
postgres_gid="$(docker run --rm --entrypoint id postgres:16.14 -g postgres)"
if [ "$(stat -c %u infra/postgres-tls/server.key)" != "$postgres_uid" ] ||
   [ "$(stat -c %g infra/postgres-tls/server.key)" != "$postgres_gid" ]; then
  sudo chown "$postgres_uid:$postgres_gid" infra/postgres-tls/server.key
fi
if [ "$(stat -c %a infra/postgres-tls/server.key)" != "600" ]; then
  sudo chmod 600 infra/postgres-tls/server.key
fi

printf '%s\n' 'Preparación completada: .env protegido y certificados locales disponibles.'
printf '%s\n' 'No compartas .env ni las claves privadas de infra/certs o infra/postgres-tls.'
