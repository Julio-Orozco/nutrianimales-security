#!/usr/bin/env bash
# Adaptación de preparación para la parte E en Docker Desktop sobre Windows.
# No ejecuta SQL ni modifica los archivos originales del equipo.
set -euo pipefail

# Todo archivo nuevo nace privado; después se abren solo los archivos públicos.
umask 077

# Fallar con un mensaje útil si no se está usando la imagen prevista.
command -v openssl >/dev/null || {
    printf '%s\n' 'ERROR: se necesita OpenSSL dentro de postgres:16.14.' >&2
    exit 1
}
id postgres >/dev/null

# Antes de copiar, comprobar que está presente el conjunto de SQL del equipo.
for archivo in 00-init.sh 01-roles.sqb 02-schema.sqb 03-seed.sqb \
    04-audit.sqb 05-access.sqb 06-n8n.sqb; do
    test -f "/entrada/sql/$archivo" || {
        printf 'ERROR: falta db/sql/%s en el repositorio.\n' "$archivo" >&2
        exit 1
    }
done

# Estos directorios son puntos de montaje de volúmenes, no carpetas NTFS.
install -d -m 755 /salida/init /salida/tls /salida/logs

# Copiar el SQL sin cambiar sus instrucciones; quitar solo el CR de fin de línea.
# La extensión .sqb es intencional: 00-init.sh la pasa explícitamente a psql.
for archivo in /entrada/sql/*.sqb; do
    sed 's/\r$//' "$archivo" > "/salida/init/$(basename "$archivo")"
    chmod 644 "/salida/init/$(basename "$archivo")"
done

# El inicializador del equipo no tiene shebang. Añadirlo a la copia permite
# ejecutarlo como proceso Bash propio, sin filtrar `set -u` al entrypoint oficial.
{
    printf '%s\n' '#!/usr/bin/env bash'
    sed 's/\r$//' /entrada/sql/00-init.sh
} > /salida/init/00-init.sh
chmod 755 /salida/init/00-init.sh

# Conservar un certificado ya generado. No rotar una clave por reiniciar el servicio.
if [[ -e /salida/tls/server.key || -e /salida/tls/server.crt ]]; then
    if [[ ! -s /salida/tls/server.key || ! -s /salida/tls/server.crt ]]; then
        printf '%s\n' 'ERROR: el volumen TLS está incompleto; revisar antes de continuar.' >&2
        exit 1
    fi
    openssl x509 -in /salida/tls/server.crt -noout -checkend 0 >/dev/null
    printf '%s\n' 'TLS: se conserva el certificado del laboratorio.'
else
    # Certificado autofirmado exclusivo para esta instancia local del proyecto.
    # Los SAN permiten validar el nombre postgres usado en la red de Compose.
    openssl req -x509 -nodes -newkey rsa:3072 -sha256 -days 365 \
        -keyout /salida/tls/server.key \
        -out /salida/tls/server.crt \
        -subj '/CN=postgres' \
        -addext 'subjectAltName=DNS:postgres,DNS:nutrianimales_db,DNS:nutrianimales_e_db,DNS:localhost,IP:127.0.0.1' \
        2>/salida/tls/generacion.log || {
            cat /salida/tls/generacion.log >&2
            exit 1
        }
    rm -f /salida/tls/generacion.log
    printf '%s\n' 'TLS: certificado local nuevo generado.'
fi

# Resolver el UID/GID por nombre en la misma imagen, sin fijar un número supuesto.
# PostgreSQL exige restringir el archivo de clave privada dentro de Linux.
chown postgres:postgres /salida/tls /salida/tls/server.key /salida/tls/server.crt /salida/logs
chmod 600 /salida/tls/server.key
chmod 644 /salida/tls/server.crt

# Comprobar sintaxis del inicializador copiado sin ejecutarlo todavía.
bash -n /salida/init/00-init.sh
printf '%s\n' 'Preparación E terminada: SQL con LF, clave privada 600 y logs escribibles por postgres.'
