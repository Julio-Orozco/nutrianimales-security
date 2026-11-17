# Explicación de comandos y código de E

Todos los comandos de Docker de este aporte apuntan al proyecto `nutrianimales-e`
y combinan `compose.yaml` con `compose.parte-e.windows.yaml`. Ejecutarlos desde la
raíz del clon. La selección explícita evita consultar accidentalmente otra instancia.

## Comandos ya usados

| Comando / fragmento | Qué hace y para qué | Por qué esa opción |
|---|---|---|
| `git --version` | Consulta versión de Git. | Verifica la herramienta antes de clonar. |
| `git clone --branch feature/integrantes-A_B URL DESTINO` | Copia el repositorio y parte de la rama A/B actualizada. | El `main` revisado inicialmente no tenía todos esos cambios; E necesita el mismo SQL actualizado del equipo. |
| `cd RUTA` | Cambia al clon de E. | Resuelve archivos y `.env` desde la raíz correcta. |
| `git switch -c feature/integrante5-riesgos-rbac` | Crea una rama propia desde el commit actual. | Mantiene el aporte separado y revisable. |
| `docker version` | Consulta cliente y motor Docker. | Que exista el comando no implica que el motor esté activo. |
| `wsl --list --verbose` | Enumera distribuciones y versión WSL. | Permitió confirmar Docker Desktop con WSL2; E no necesitó instalar Ubuntu. |
| `docker pull postgres:16.14` | Descarga la imagen exacta de PostgreSQL. | Coincide con el Compose del equipo. |
| `git check-ignore -v -- .env` | Muestra la regla que excluye ese archivo. | `-v` identifica archivo/línea/regla y `--` separa la ruta de las opciones; no lee valores. |
| `Expand-Archive -LiteralPath ZIP -DestinationPath $PWD.Path` | Extrae el complemento en el clon actual. | `-LiteralPath` evita interpretar comodines y el destino es el directorio de trabajo real. |
| `Test-Path .\compose.parte-e.windows.yaml` | Comprueba existencia del archivo. | Una respuesta `True` verifica que se extrajo donde corresponde. |

## Generación de `.env` ejecutada por E

| Bloque | Función / motivo |
|---|---|
| `& { ... }` | Ejecuta un bloque con variables locales de trabajo. |
| `Test-Path .env` y `throw` si existe | Evita reemplazar credenciales existentes por accidente. |
| `RandomNumberGenerator.Create()` | Usa aleatoriedad criptográfica del sistema. |
| `foreach` sobre diez nombres | Genera un valor independiente para cada consumidor. |
| `New-Object byte[] 32` y `GetBytes` | Obtiene 32 bytes aleatorios por secreto, no una palabra reutilizada. |
| `BitConverter...Replace...ToLowerInvariant` | Representa los bytes como 64 caracteres hexadecimales, cómodos para `.env` sin comillas especiales. |
| Correo de prueba y campos Telegram/Groq vacíos | Completa configuración no necesaria para RBAC sin inventar tokens. |
| `WriteAllLines` con UTF-8 sin BOM | Guarda variables sin imprimir su contenido; evita un BOM en el primer nombre. |
| `Dispose()` | Libera el generador. |
| `Write-Host` del mensaje de finalización | Confirma creación sin mostrar secretos. |

Ese bloque no asignó permisos NTFS ni cambió contraseñas de una base ya existente.
En este caso precedió a la inicialización de la nueva base de E.

## Docker Compose

Prefijo utilizado por el ejecutor:

```text
docker compose -p nutrianimales-e -f compose.yaml -f compose.parte-e.windows.yaml
```

| Opción / subcomando | Función y motivo |
|---|---|
| `-p nutrianimales-e` | Identifica la red y los volúmenes de esta instancia local. |
| Primer `-f` | Lee el proyecto original del grupo. |
| Segundo `-f` | Aplica las sustituciones específicas de Windows. |
| `config --quiet` | Valida sin imprimir el modelo con secretos interpolados. |
| `up -d --wait --wait-timeout 180 postgres` | Inicia la base y su preparación, en segundo plano, esperando salud hasta 180 segundos. |
| `ps -a` | Muestra también el preparador ya terminado. |
| `exec -T postgres ...` | Ejecuta en la base activa sin asignar TTY; apropiado para archivos y captura de salida. |
| `cp ORIGEN postgres:DESTINO` | Transfiere un archivo de prueba al contenedor. No toca el SQL original de inicialización. |
| `logs --tail 60 preparar-e postgres` | Acota registros de diagnóstico de arranque. Revisar antes de compartir; no son prueba RBAC por sí solos. |

La explicación de cada montaje, dependencia y permiso del complemento está en
[windows/LEEME.md](../windows/LEEME.md). La base sigue usando los archivos de
configuración de A/B y no publica su puerto en Windows.

## Ejecutor PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\parte-e\Ejecutar-E.ps1 -Paso Pruebas
```

| Bloque / instrucción | Función y motivo |
|---|---|
| `-NoProfile` | Evita funciones/alias particulares del perfil del usuario. |
| `-ExecutionPolicy Bypass` | Permite este script local en el proceso iniciado; no eleva privilegios ni cambia la política permanente. |
| `-File` y `-Paso` | Seleccionan archivo y prueba; `ValidateSet` limita el nombre a cinco opciones conocidas. |
| `$ErrorActionPreference='Stop'` | Detiene errores de archivos y operaciones PowerShell. Los comandos nativos se comprueban con su código. |
| `$PSScriptRoot`, `Split-Path`, `Join-Path`, `Test-Path` | Calculan rutas desde el propio script y validan los archivos necesarios. |
| `Get-Command docker` | Detecta si la herramienta está disponible antes de ejecutar. |
| `New-Item -Force` | Crea carpetas si faltan sin vaciar las existentes. |
| `Get-Date` y `DateTimeOffset` | Identifican la ejecución e incluyen zona horaria real de la computadora. |
| `Set-Content` | Crea el encabezado de evidencia; no copia `.env`. |
| `Invoke-DockerE`, `@composeE`, `@ArgumentosE` | Pasa cada argumento como elemento separado, conservando rutas con espacios. |
| `2>&1` | Captura también NOTICE y errores nativos; psql envía allí las denegaciones esperadas. |
| Preferencia `Continue` temporal | Evita que una NOTICE se convierta en terminación de PowerShell 5.1; la salida sigue guardada y el código de error manda. |
| `$LASTEXITCODE`, comprobación y `throw` | Un fallo de Docker/Bash/psql interrumpe el paso y señala su archivo de evidencia. |
| `ForEach-Object ... ToString()` | Convierte salida nativa en texto legible para consola y archivo. |
| `Tee-Object -Append` | Muestra y conserva el mismo resultado. |
| Tabla fija de archivos y `Todos` | Ejecuta exclusivamente las pruebas incluidas, en orden. |
| `ReadAllText`, normalización LF y `WriteAllText` | Prepara una copia reproducible del código en `.runtime`, aunque el checkout use CRLF. |
| `Get-FileHash -Algorithm SHA256` | Identifica el archivo realmente transferido; no calcula hashes de contraseñas. |
| `Push-Location` y `finally { Pop-Location }` | Resuelven Compose desde la raíz y restauran después el directorio de la terminal. |

## Cliente psql

| Fragmento | Función y motivo |
|---|---|
| `-X` | Omite `psqlrc`; hace reproducible la sesión. |
| `-U postgres` | Usa administración solo para catálogos y SET ROLE; no afirma que esa cuenta tenga mínimo privilegio. |
| `-d nutrianimales` | Selecciona la base del equipo. |
| `-v ON_ERROR_STOP=1` / `\set ON_ERROR_STOP on` | Detiene errores SQL no controlados; evita continuar y declarar éxito después de un fallo. |
| `-f ARCHIVO` | Ejecuta exactamente el archivo de prueba copiado. |
| `-c CONSULTA` | Ejecuta las consultas cortas utilizadas en las capturas iniciales. |
| `-P pager=off` / `\pset pager off` | Evita que un paginador bloquee una ejecución capturada. |
| `-w` | En autenticación automatizada no permite un prompt interactivo oculto que dejaría esperando el script. |
| `-qAt` | Reduce ruido y entrega filas sin encabezados, con campos separados, para validar identidad/TLS. |

## SQL E01 y E02

| Instrucción o conjunto | Función y motivo |
|---|---|
| `\echo` | Etiqueta inicio/fin de cada paso; no representa un resultado de la prueba. |
| `current_database`, `current_user`, `version`, `clock_timestamp` | Identifican base, ejecutor, motor e instante real. |
| `unnest(ARRAY[...])` | Convierte una lista fija de objetos/cuentas en filas consultables. |
| `to_regclass` | Detecta presencia de objetos sin crearlos. |
| `pg_roles` y sus flags | Distingue NOLOGIN/LOGIN y privilegios administrativos sin leer hashes de contraseñas. |
| `pg_auth_members` y JOIN a `pg_roles` | Muestran qué grupo hereda cada cuenta. |
| `pg_namespace` / `pg_get_userbyid` | Verifican propietarios de esquemas `public` y `n8n`. |
| `pg_trigger`, filtro `NOT tgisinternal` y nombre | Localizan los cuatro triggers por fila del proyecto. |
| `pg_settings` y `pg_hba_file_rules` | Consultan parámetros/reglas actuales, sin leer claves privadas ni valores de `.env`. |
| `has_table_privilege` | Evalúa un privilegio efectivo de una cuenta sobre un objeto; incluye herencia. |
| `CROSS JOIN` | Compara cada una de cuatro cuentas con cada uno de cinco objetos en la matriz completa. |
| `has_database_privilege` / `has_schema_privilege` | Revisa CONNECT, USAGE y CREATE, además de permisos sobre tablas. |
| `ORDER BY` | Mantiene un orden fácil de comparar entre ejecuciones. |

## SQL E03

| Instrucción o bloque | Función y motivo |
|---|---|
| `BEGIN` | Agrupa las operaciones de ensayo en una transacción. |
| `SET LOCAL ROLE cuenta` | Cambia la identidad efectiva de autorización dentro de esa transacción. |
| `SELECT session_user, current_user` | Hace visible la diferencia entre operador original y rol probado. |
| `SELECT count(*)` sobre reportes/auditoría/clientes | Ejecuta una lectura permitida sin mostrar filas con correos u otros valores empresariales. |
| `INSERT INTO backups ... RETURNING` | Comprueba escritura permitida de TI, marcándola expresamente como ensayo sin respaldo real. |
| Bloque `DO` y `BEGIN ... EXCEPTION` interno | Permite comprobar una denegación sin abortar las demás pruebas esperadas. |
| `DELETE ... WHERE false` / `INSERT ... SELECT ... WHERE false` | Solicita el privilegio de escritura sin seleccionar filas que pudieran cambiar. |
| `RAISE EXCEPTION 'FALLO...'` | Si la acción prohibida se admite, convierte el resultado en error de la prueba. |
| `WHEN insufficient_privilege` | Captura solo la falta de privilegios, no cualquier error. |
| `RAISE NOTICE 'PASS...'` | Registra éxito únicamente después de una denegación del motor. |
| `RESET ROLE` | Regresa al operador administrativo antes de probar la siguiente cuenta. |
| `ROLLBACK` | Revierte filas del ensayo, incluida `backups`; no revierte secuencias ni elimina logs técnicos. |

## Bash E04: login y TLS

| Instrucción o bloque | Función y motivo |
|---|---|
| Shebang y `set -euo pipefail` | Indican Bash y detienen errores/variables inexistentes/tuberías fallidas. |
| `umask 077` | Crea el archivo temporal de error privado. |
| `PGHOST=postgres` / `PGDATABASE=nutrianimales` | Seleccionan una conexión TCP al servicio correcto, sin publicar 5432. |
| `PGSSLMODE=verify-full` / `PGSSLROOTCERT` | Exigen cifrado, confianza y nombre válido del servidor. |
| `PGCONNECT_TIMEOUT=5` | Evita esperas indefinidas si hay un problema de conexión. |
| `PGCLIENTENCODING=UTF8` / `LC_ALL=C` | Fijan codificación y mensajes del cliente para una captura consistente. |
| `test -r` | Verifica que el certificado público esté disponible. |
| Bucle de tres pares cuenta:variable | Revisa las tres cuentas usando una lista fija. |
| `${par%%:*}` / `${par#*:}` | Separan nombre de cuenta y nombre de variable del par. |
| `${!variable}` | Lee por nombre la variable ya presente dentro del contenedor; no la imprime. |
| `PGUSER=... PGPASSWORD=... psql` | Pasa la contraseña como entorno del proceso, sin incluirla en argumentos ni historial PowerShell. El administrador de la máquina sigue pudiendo acceder al entorno. |
| Consulta de `pg_stat_ssl` con `pg_backend_pid()` | Obtiene TLS de la propia conexión, junto con identidades reales de sesión/rol. |
| `IFS='|' read` y condición | Separa el resultado y exige cuenta correcta y SSL activo antes de emitir PASS. |
| `mktemp` y `trap ... EXIT` | Crean y retiran un archivo privado aun si hay fallo. |
| Intento único con clave incorrecta | Comprueba que se exige una credencial válida, sin intentar adivinar secretos. |
| `grep` de rechazo de autenticación | Distingue password incorrecto de un fallo de red/certificado; este último no cuenta como aprobado. |
| `printf` | Muestra identidad, protocolo y resultado; nunca el secreto. |

## Git para revisar y publicar E

Seguir [CHECKLIST_CIERRE_E.md](CHECKLIST_CIERRE_E.md) después de ejecutar las pruebas.
No se fusionan ramas de otros integrantes ni se modifica `main` como parte de este paso.
`git add -- RUTAS` limita lo que se prepara; `git diff --cached` revisa lo preparado;
`commit` crea la versión local y `push -u` publica la rama y fija su seguimiento.
