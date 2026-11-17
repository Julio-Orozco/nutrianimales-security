# Código: qué hace, para qué y por qué

> **Documento heredado, no aplica.** Describe una versión anterior del proyecto basada en Python (`lab.py`, `app/`, servicio `monitor`). El proyecto **no usa Python** y estos comandos no se deben implementar. Se conserva solo como referencia de diseño de las reglas; para los flujos actuales ver [FLUJOS_N8N.md](FLUJOS_N8N.md).

Este documento describe una implementación prevista, pero el checkout recibido no contiene `app/`, `scripts/lab.py`, `requirements*` ni `GUIA_CODIGO.html`. Las funciones y comandos de abajo no deben citarse como disponibles o ejecutados hasta que el equipo agregue esos archivos y los pruebe.

## Aplicación

| Archivo / función | Qué hace y para qué | Por qué esta opción |
|---|---|---|
| app/db.py `connect` | Abre una conexión monitor o agente; toma PGHOST/PGSSLMODE/CA del entorno | Separa observación de consultas empresariales; verify-full valida CA y nombre, no solo cifra |
| `rows` / `execute` | Ejecutan SQL constante y parámetros separados dentro de un contexto de conexión | El contexto cierra y confirma/revierte; `%s` es un parámetro de psycopg, no interpolación Python |
| app/state.py `state` | Lee/modifica estado bajo RLock y escribe con temporal+fsync+replace | Evita offsets truncados y actualizaciones perdidas en este proceso. No es un mecanismo distribuido: ejecutar una sola réplica monitor |
| app/rules.py `CATALOG` | Define las 17 reglas, fuentes y umbrales | Una referencia legible para el generador de flujos y la API |
| `REPORTS` / `report_command` | Mapean tres comandos exactos a SQL revisado | El usuario no elige nombres de tabla ni construye SQL; se prefiere catálogo a una lista de palabras prohibidas |
| `outside` | Valida IP contra redes CIDR | Evita aceptar cualquier 172.x o confundir una IP privada con un origen autorizado |
| `off_hours` | Evalúa rangos que atraviesan medianoche | Compara hora local CR explícita; permite un rango de demo documentado sin inventar una hora real |
| `sql_tree` / `walk` / `no_where` | Interpretan AST con parser PostgreSQL y localizan UPDATE/DELETE sin WHERE | Los comentarios o cadenas que dicen WHERE no engañan al parser. Una sentencia compuesta se omite si la atribución es ambigua |
| `sensitive_select` | Verifica SELECT superior y tablas sensibles, incluso en joins | Evita disparar por la palabra clientes dentro de un literal o por un UPDATE con subconsulta |
| `delta` | Resta llamadas/filas/tiempo de dos observaciones | Los contadores de pg_stat_statements son acumulados; ante reset no se calculan cantidades negativas |
| app/logs.py `tail` | Lee nuevas líneas completas y recuerda inode/offset | Tolera truncado/rotación y deja una línea incompleta para el ciclo siguiente |
| `ingest` | Interpreta JSON PostgreSQL y Failed password SSH | Fuentes distintas para el problema SSH/PostgreSQL de la guía; no interpreta «connection refused» como contraseña incorrecta |
| `record` | Registra evento y espejo de auditoría con huella única | Releer una línea no debe crear duplicados normales. No permite UPDATE/DELETE de auditoría |
| app/checks.py `prime` | Conserva baseline e inicializa contadores/cursor | La semilla inicial no se interpreta como ataque. Un reinicio no acepta nuevos hashes silenciosamente |
| `statistics` / `changes` | Leen métricas y construyen ventanas nuevas | R1 informa promedio nuevo; D7 identifica si fue una o varias ejecuciones |
| `security` | Invoca una función SQL limitada | Monitor no recibe permiso genérico pg_read_server_files ni monta todo PGDATA |
| `evaluate` | Implementa las 17 ramas del catálogo | Ver explicación por regla en ESCENARIOS; fuentes ausentes se distinguen de ausencia de hallazgos |
| `run` | Valida código y serializa cambios de estado | No acepta SQL ni destinos arbitrarios desde la URL |
| app/alerts.py `enqueue` | Persiste hallazgo antes de notificar, con cooldown por código | Una falla de Telegram no borra la evidencia. El límite cinco minutos reduce ruido, a costa de agrupar incidentes |
| `notify` | Bloquea la fila, envía o registra fallo/dry-run y cuenta intentos | SELECT FOR UPDATE evita envíos simultáneos normales. No asegura exactly-once ante fallos entre dos sistemas |
| app/external.py `post_json` | HTTP JSON saliente con timeout y errores acotados | No imprime URL/token de Telegram; no oculta los códigos HTTP significativos |
| `telegram` | Encapsula métodos Bot API | Un solo lugar controla formato y validación `ok` |
| `groq_summary` | Envía reportes agregados y recibe resumen | La IA no decide autorización ni produce SQL ejecutable; modelo configurable para evitar atarse a una disponibilidad temporal |
| app/bot.py `answer` | Autoriza chat antes de acceder a reportes y registra bloqueos | Un grupo autorizado accede solo a reportes de gerente; no tiene comandos administrativos |
| `poll` | Consulta mensajes, responde y avanza offset | Sin webhook/túnel público. Si falla antes de persistir offset, un mensaje podría repetirse; no hay operaciones de escritura del usuario que duplicar |
| app/api.py `authorize` | Compara claves con compare_digest | Clave de auditor solo GET a tres recursos; no alcanza con ocultar botones en HTML |
| `lifespan` / `health` | Exigen claves, preparan baselines y prueban BD | Arranque incorrecto falla; health no debe «aprobar» una fuente que no fue consultada |
| rutas `checks`, `notify`, `host-audit` | Exponen operaciones tipadas y acotadas | UUID y modelos validan entradas; un estado inválido no se acepta como una alerta enviada |
| `catalog`, `events`, `status` | Lectura limitada para TI/auditor | No devuelven secretos del entorno |
| `bot_poll` / `groq_probe` | Integración n8n y ensayo de revocación | Respuestas reales de proveedor o error explícito; nunca un fallback que parezca recuperación |

## SQL

`01-roles.sql`: NOLOGIN crea grupos, LOGIN crea cuentas que reciben esos grupos. CONNECT y USAGE no conceden SELECT automáticamente. `REVOKE CREATE ... PUBLIC` impide crear objetos que alteren resolución de nombres. `pg_monitor` permite observar estadísticas; es más amplio que el gerente y se limita a TI monitor/auditor. El usuario de backup puede leer todo para pg_dump, pero no modificar negocio.

`02-schema.sql`: PK identifica filas; FK asegura referencias; CHECK impide cantidades/precios inválidos. Las identidades se ajustan después de una semilla con IDs explícitos. JSONB conserva antes/después sin crear una función diferente para cada tabla. timestamptz conserva instantes y permite mostrar distintas zonas. Las vistas de gerente agregan negocio sin exponer auditoría ni correos. Correo no es UNIQUE solo para demostrar D4; en un sistema real conviene prevenir duplicados mediante restricciones si el negocio lo permite.

`03-seed.sql`: generate_series produce datos ficticios deterministas, sin descargar información personal. Se usan 1.500 clientes y ventas por el umbral >1.000. ON CONFLICT DO NOTHING recupera filas ausentes, pero **no deshace cambios en filas existentes** ni es un sistema de migraciones.

`04-audit.sql`: el trigger de fila se dispara después de INSERT/UPDATE/DELETE. OLD/NEW se convierten a JSONB según operación; el usuario se toma de session_user, porque dentro de SECURITY DEFINER current_user sería el propietario de la función. Se registra también txid_current para relacionar cambios de una transacción. El propietario audit_owner es NOLOGIN y solo puede insertar auditoría. search_path fijo y nombres calificados reducen secuestros de objetos. El trigger de sentencia usa transition tables para contar cuántas filas afectó una operación completa; no confunde 200 operaciones de una fila con una de 200 filas.

`security_snapshot()` sigue siendo SECURITY DEFINER propiedad administrativa porque leer tres archivos de configuración requiere privilegios; su SQL es fijo, sin parámetros de ruta y sin leer certificados ni contraseñas. Devuelve hashes y ACL, no contenido. `sha256(bytea)` y gen_random_uuid son funciones nativas de PostgreSQL16; no se agrega pgcrypto innecesariamente.

`registrar_evento()` registra autenticaciones/bloqueos y un espejo en auditoria_datos con tabla `evento:fuente`. No se afirma que un SELECT dispare un trigger de fila. ON CONFLICT en la huella evita duplicar el mismo evento al releer. Las modificaciones de auditoría continúan prohibidas a las cuentas ordinarias. El superusuario no queda contenido por esta medida.

`05-access.sql`: concede lectura a vistas del gerente y tablas del agente, observación a TI/auditor y escritura únicamente a bandeja/registro de backup según necesidad. Los permisos deben probarse mediante denegaciones, no solo observando GRANT.

## Infraestructura

`compose.yaml`: define dependencias de salud, redes, volúmenes y variables obligatorias. `:?` detiene un arranque sin preparación. El inicializador permissions cambia solo propietarios de dos volúmenes nombrados y termina; no monta el disco del host ni el socket Docker. n8n/pgAdmin ejecutan sus UID propios. Las capacidades se retiran donde no son necesarias; PostgreSQL/sshd conservan las de su arranque. `read_only` es raíz de contenedor, no volumen de datos: estos siguen siendo escribibles donde corresponde. tmpfs permite temporales sin modificar la imagen.

Los Dockerfile fijan versiones principales/parches para reproducción. `--no-install-recommends` reduce paquetes secundarios; borrar índices apt reduce capas. Versionar una imagen no prueba que esté libre de vulnerabilidades: revisar actualizaciones y escanear antes de reutilizar fuera del laboratorio.

`postgres-entrypoint.sh` copia la clave a un directorio privado con dueño postgres antes de delegar al entrypoint oficial, que baja privilegios. `exec` conserva señales de Docker. `set -euo pipefail` detiene errores, variables ausentes y fallos en tuberías, en vez de continuar con un estado incompleto.

`postgresql.conf` carga pg_stat_statements antes de aceptar consultas, habilita TLS/SCRAM y logs JSON/CSV. El umbral1000 está en milisegundos. `pg_hba.conf` prioriza reglas: rechaza tráfico sin TLS y orígenes no listados. Solo postgres por socket local tiene trust; esto no es una contraseña remota desactivada.

`nginx.conf` usa puertos no privilegiados, TLS1.2/1.3, cabeceras, DNS Docker y soporte WebSocket para n8n. Temporales/pid están en /tmp, ya que la raíz es read-only. La redirección usa localhost:8443 porque el proyecto está ligado a loopback; si se cambia el modo de acceso, también debe revisarse este nombre, SAN, CSP y configuración de n8n.

`ssh-lab` es una excepción deliberada para A1. Solo usuarios prueba, sin root ni publicación de puerto. No se instala una puerta trasera administrativa en el host.

`compose.logging.yaml`: Filebeat lee copias reales, Logstash recibe Beats y un complemento lo transforma al formato Loki. La comunicación de esa cadena interna es HTTP/Beats sin TLS en esta variante académica; no se describe como cifrada. No se publican esos servicios. El log UFW necesita que Ubuntu/rsyslog lo genere; un snapshot de reglas no lo sustituye.

## Scripts y pruebas

`lab.py` centraliza operaciones con argumentos explícitos y sin shell=True. `prepare` es conservador con archivos privados existentes. `request` valida nuestra CA. `sql` solo accede al socket administrativo interno. `scenario` tiene destinos/SQL limitados al laboratorio y una barrera LAB_MODE. Esta barrera no es una autorización criptográfica: quien maneja Docker ya es administrador del laboratorio.

`host_agent.py` necesita root solo para leer UFW, no concede ejecución remota ni cambia reglas por instrucciones de n8n. El receptor valida hashes y autenticación. Debe mantenerse activo y supervisarse para una instalación prolongada.

`backup.sh` usa umask077, archivo parcial y renombrado después de éxito; el hash se calcula sobre el archivo final. Un fallo de dump termina el ciclo con estado fallido. `restore-test` verifica hash, crea una base separada, restaura con exit-on-error, consulta conteos y elimina esa base en finally. No elimina la base de negocio ni acredita restauración de todo el servidor.

`qa.py` acota destinos, número de intentos y duración de cargas. `generate_workflows.py` construye JSON determinista con UUID por nombre; cada nodo lleva notas visibles. Las pruebas cubren límites, autorización, parseo, ventanas, deduplicación y fallos. Las sustituciones de proveedor/DB existen solo en tests; no se usan para fabricar evidencia del curso.

## Por qué no ejecutar SQL libre de IA

Pedir al modelo «solo SELECT» no impide funciones con efectos secundarios, consultas excesivas ni acceso a tablas fuera de propósito. Este diseño combina comandos conocidos, SQL constante, cuenta sin escritura y timeouts. La IA solo redacta un resumen después de consultar vistas agregadas. La restricción se puede explicar y probar sin confiar en obediencia del modelo.
