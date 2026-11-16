#!/usr/bin/env bash
# Conexiones TCP reales como las tres cuentas, usando solo secretos del contenedor.
# No imprime contrasenas ni modifica roles o datos.
set -euo pipefail
umask 077

# Exigir cifrado, confianza en el certificado local y coincidencia del nombre DNS.
export PGHOST=postgres
export PGDATABASE=nutrianimales
export PGSSLMODE=verify-full
export PGSSLROOTCERT=/run/pg-tls/server.crt
export PGCONNECT_TIMEOUT=5
export PGCLIENTENCODING=UTF8
export LC_ALL=C
test -r "$PGSSLROOTCERT"

# Nombres fijos del repo. La indireccion Bash obtiene el secreto sin mostrarlo.
for par in gerente_db:GERENTE_PASSWORD ti_db:TI_PASSWORD auditor_db:AUDITOR_PASSWORD; do
    cuenta=${par%%:*}
    variable=${par#*:}
    if [[ -z ${!variable:-} ]]; then
        printf 'ERROR: falta la variable %s dentro del contenedor.\n' "$variable" >&2
        exit 1
    fi
    # -w impide prompts; -X ignora psqlrc; -qAt devuelve solo el resultado medido.
    # La clave se pasa como entorno del proceso, no como argumento visible de psql.
    resultado=$(PGUSER="$cuenta" PGPASSWORD="${!variable}" \
        psql -X -w -qAt -v ON_ERROR_STOP=1 \
        -c 'SELECT session_user, current_user, ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid();')
    IFS='|' read -r sesion rol tls protocolo <<< "$resultado"
    if [[ "$sesion" != "$cuenta" || "$rol" != "$cuenta" || "$tls" != 't' || -z "$protocolo" ]]; then
        printf 'FALLO: identidad o TLS inesperados para %s.\n' "$cuenta" >&2
        exit 1
    fi
    printf 'PASS | login real: %s | session_user=%s | current_user=%s | TLS=%s | verify-full\n' \
        "$cuenta" "$sesion" "$rol" "$protocolo"
done

# Un unico intento con clave incorrecta comprueba el rechazo de autenticacion.
# El archivo temporal es privado y se elimina incluso si se interrumpe el ensayo.
errores=$(mktemp /tmp/parte-e-auth.XXXXXX)
trap 'rm -f "$errores"' EXIT
if PGUSER=gerente_db PGPASSWORD='credencial_invalida_prueba_E_no_usar' \
    psql -X -w -qAt -v ON_ERROR_STOP=1 -c 'SELECT current_user;' >"$errores" 2>&1; then
    printf '%s\n' 'FALLO: una clave incorrecta permitio entrar como gerente_db.' >&2
    exit 1
fi

# Un problema de red o certificado no cuenta como rechazo por contrasena.
if grep -q 'password authentication failed' "$errores"; then
    printf '%s\n' 'PASS | clave incorrecta rechazada por PostgreSQL: password authentication failed'
else
    printf '%s\n' 'ERROR: el intento fallo por un motivo distinto de contrasena; revisar:' >&2
    cat "$errores" >&2
    exit 1
fi
printf '%s\n' 'FIN E04 | 3 logins TCP con TLS y 1 rechazo por clave incorrecta comprobados.'
