# Soporte para comprobar la parte E desde Windows

Grupo 3 · NutriAnimales S.A. · Preparado el 16 de noviembre de 2026.

Base revisada: `feature/integrantes-A_B`, commit `8ea8c12500aa7375ea11f57c406d7b11211c4190`.
Rama de trabajo de E: `feature/integrante5-riesgos-rbac`.

## Qué agrega y por qué

El `compose.yaml` del equipo espera preparar certificados y permisos desde Linux.
Este complemento conserva su PostgreSQL 16.14, configuración TLS, roles, datos,
triggers y permisos; adapta la preparación a Docker Desktop desde PowerShell.
No necesita instalar una distribución Ubuntu en WSL.

Se agregan únicamente `compose.parte-e.windows.yaml` y esta carpeta `parte-e/windows`.
No se reemplaza ningún archivo del equipo. El `.env` local existente se conserva.
No se incluyen contraseñas, certificados privados ni datos de PostgreSQL en este paquete.

## Paso a paso

Ejecutar desde la raíz del clon, donde está `compose.yaml`.
El `.env` debe contener las variables requeridas por el Compose del equipo.

### 1. Revisar la combinación sin imprimir secretos

```powershell
docker compose -p nutrianimales-e -f compose.yaml -f compose.parte-e.windows.yaml config --quiet
```

Si termina sin errores y sin salida, la configuración se pudo resolver.
Esto no comprueba todavía que PostgreSQL arranque ni que sus permisos sean correctos.

| Fragmento | Qué hace | Por qué se usa |
|---|---|---|
| `docker compose` | Gestiona servicios definidos en YAML. | Reutiliza el proyecto del equipo. |
| `-p nutrianimales-e` | Da un nombre propio a la instancia local. | Separa su red y volúmenes de otras instancias Compose. |
| `-f compose.yaml` | Lee la definición original primero. | Mantiene el SQL y las opciones del equipo. |
| `-f compose.parte-e.windows.yaml` | Aplica el complemento después. | Sustituye los montajes de TLS, init y logs por volúmenes Linux. |
| `config --quiet` | Valida sin imprimir el modelo con sus variables resueltas. | Evita mostrar contraseñas en la terminal o capturas. |

### 2. Iniciar solamente la base para las pruebas de E

```powershell
docker compose -p nutrianimales-e -f compose.yaml -f compose.parte-e.windows.yaml up -d --wait --wait-timeout 180 postgres
```

`up` crea o inicia los servicios; `-d` los deja en segundo plano; `--wait` espera el
estado saludable; `--wait-timeout 180` limita esa espera a tres minutos.
El argumento `postgres` inicia únicamente esa base y su dependencia `preparar-e`.
La preparación usa root para establecer propietarios, termina y luego PostgreSQL
se ejecuta mediante el entrypoint oficial que cambia al usuario postgres.

No inicia n8n, Nginx, pgAdmin ni Filebeat. Es una instancia para comprobar roles,
riesgos y secretos de E, no una demostración completa de las alertas del grupo.
No se publica el puerto 5432 en Windows.

### 3. Revisar estado

```powershell
docker compose -p nutrianimales-e -f compose.yaml -f compose.parte-e.windows.yaml ps -a
```

`ps -a` muestra también el contenedor de preparación ya terminado.
Lo esperado, cuando se ejecute realmente, es `preparar-e` con salida 0 y
`postgres` en ejecución y saludable. Este documento no afirma que ya haya sucedido.

### 4. Consultar versión y conexión administrativa local

```powershell
docker compose -p nutrianimales-e -f compose.yaml -f compose.parte-e.windows.yaml exec -T postgres psql -X -U postgres -d nutrianimales -v ON_ERROR_STOP=1 -c "SELECT current_database(), current_user, version();"
```

`exec` ejecuta un comando en el servicio iniciado; `-T` evita asignar terminal;
`psql` es el cliente de PostgreSQL; `-X` ignora configuraciones personales;
`-U` elige usuario y `-d` base; `ON_ERROR_STOP=1` detiene el cliente si falla el SQL;
`-c` ejecuta la consulta escrita. Solo muestra identidad y versión.
Esta consulta usa el socket local administrativo: no prueba contraseña ni TLS.
Las pruebas de autorización RBAC y login deben registrarse por separado.

### Si falla el arranque

```powershell
docker compose -p nutrianimales-e -f compose.yaml -f compose.parte-e.windows.yaml logs --tail 60 preparar-e postgres
```

`logs` consulta la salida de ambos servicios y `--tail 60` limita su extensión.
No ejecutar comandos que impriman `.env`, claves privadas o el modelo completo de Compose.
Los registros internos de consultas SQL pueden contener información sensible:
revisar cualquier archivo antes de adjuntarlo o subirlo al repositorio.

## Explicación del código agregado

Ambos archivos de código están comentados por instrucción o bloque.

| Código | Función y motivo |
|---|---|
| `network_mode: none` | La preparación funciona sin Internet y solo procesa archivos locales. |
| `entrypoint: bash -euo pipefail -c` | Usa Bash; detiene errores, variables inexistentes y fallos dentro de tuberías. |
| `sed 's/\r$$//'` en YAML | Elimina CRLF al ejecutar el script; `$$` entrega un `$` literal después de la interpolación Compose. |
| Montajes `/entrada/sql` y `/soporte` con `:ro` | Permiten leer los originales sin modificarlos desde el contenedor de preparación. |
| Volúmenes `e_pg_init`, `e_pg_tls`, `e_pg_logs` | Ofrecen permisos Linux reales dentro de Docker Desktop. El nombre de proyecto evita reutilizar volúmenes de otra instancia. |
| `depends_on` con `service_completed_successfully` | La base espera que la preparación termine correctamente. |
| `pg_isready -h 127.0.0.1` | Espera el servidor TCP final; el servidor temporal de initdb solo abre socket local. Es disponibilidad, no prueba de autorización. |
| `umask 077` | Crea inicialmente archivos privados; solo se abren de forma explícita los SQL y el certificado público. |
| `command -v`, `id`, `test -f` | Comprueban herramientas, cuenta del sistema y archivos requeridos antes de preparar la base. |
| `install -d -m 755` | Prepara directorios accesibles por PostgreSQL. |
| Bucle `.sqb` con `sed`, `basename` y `chmod 644` | Copia el SQL con finales LF; no cambia su contenido lógico ni su extensión. |
| `printf` del shebang y `chmod 755` | Hace ejecutable la copia del inicializador con el intérprete correcto. |
| Comprobación de certificado existente | Evita cambiar su identidad en cada reinicio y detecta un volumen TLS incompleto o certificado vencido. |
| `openssl req -x509 -nodes -newkey rsa:3072 -sha256 -days 365` | Genera un certificado local autofirmado con clave RSA 3072 y firma SHA-256, como el enfoque del equipo. La clave sin passphrase permite arranque desatendido y queda protegida con permisos Linux. |
| `-keyout`, `-out`, `-subj`, `-addext` | Definen archivos de clave/certificado, identidad y nombres SAN válidos para esta instancia. No sustituyen una CA de producción. |
| `chown postgres:postgres` y `chmod 600` | Asignan la clave al usuario real de la imagen y permiten leerla solo a su propietario. |
| `chmod 644` del certificado | El certificado público puede compartirse para validar la conexión; su clave privada queda restringida. |
| `bash -n` | Comprueba sintaxis sin ejecutar la inicialización SQL. |

## Límites y conservación de datos

El SQL de inicialización se ejecuta solo al crear una base vacía, como en la imagen
oficial. Cambiar el SQL después no migra una base existente. Este complemento no
borra volúmenes ni migra datos. Detener contenedores conserva el estado almacenado.
No usar `down -v` como paso rutinario, porque elimina los volúmenes de esta instancia.
Las pruebas de este entorno local deben identificarse como ejecutadas en la PC de E.

## Validación al preparar este paquete

Se revisó el código actual de A/B. Se comprobaron la sintaxis Bash, la combinación
real de Compose 2.39.1 con variables ficticias, la sustitución de montajes y la
equivalencia del SQL copiado con sus finales de línea normalizados.
El arranque real se ejecutó después en la computadora del integrante E y quedó
saludable. Las pruebas PostgreSQL 16.14 de roles, permisos, operaciones y login TLS
también se verificaron con sus salidas. Ver [RESULTADOS_E.md](../evidencias/RESULTADOS_E.md).

## Referencias oficiales

- [Combinar archivos Compose](https://docs.docker.com/reference/compose-file/merge/)
- [Volúmenes Docker](https://docs.docker.com/engine/storage/volumes/)
- [PostgreSQL 16: SSL y permisos de clave privada](https://www.postgresql.org/docs/16/ssl-tcp.html)
- [Imagen oficial PostgreSQL](https://hub.docker.com/_/postgres)
- [Entrypoint oficial](https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh)
