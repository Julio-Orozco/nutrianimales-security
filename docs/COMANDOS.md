# Comandos: qué hacen, para qué y por qué esta opción

Contexto común: terminal de Ubuntu, carpeta raíz del repositorio. `python3` evita depender de un alias ambiguo `python`. No se necesita instalar paquetes Python en el host para el arranque básico; Docker instala las dependencias del servicio. Los pasos de desarrollo sí usan un entorno virtual.

## Operación habitual

| Comando | Qué hace / para qué | Por qué esta opción y qué revisar |
|---|---|---|
| `python3 scripts/lab.py prepare` | Crea secretos, directorios y TLS local | Aleatoriedad criptográfica; no comparte claves de ejemplo ni sobrescribe una instalación |
| `python3 scripts/lab.py up` | Construye y arranca con espera de salud | `--build` incorpora cambios, `-d` libera terminal, `--wait` no confunde «creado» con «disponible» |
| `python3 scripts/lab.py configure` | Pide configuración oculta | `getpass` evita mostrar tokens en terminal o en el historial |
| `python3 scripts/lab.py telegram-chats` | Muestra IDs de chats que escribieron al bot | Consulta la API real sin imprimir el token ni los mensajes |
| `python3 scripts/lab.py configure --live` | Valida datos mínimos y pone DRY_RUN=false | La salida de prueba no se confunde con una alerta real enviada |
| `docker compose up -d --no-deps --force-recreate monitor` | Aplica el nuevo .env a monitor | Recrear actualiza el entorno; `--no-deps` evita reiniciar la BD |
| `python3 scripts/lab.py n8n-import` | Crea credencial, importa y activa flujos | API oficial; conserva JSON sin secretos e IDs privados para reanudar lo ya registrado |
| `python3 scripts/lab.py status` | Muestra servicios y estado del monitor | Incluye modo seco y antigüedad del agente UFW |
| `python3 scripts/lab.py check all` | Ejecuta las 17 evaluaciones actuales | Un HTTP 503 significa falta de fuente, no control aprobado |
| `python3 scripts/lab.py check D6 --notify` | Evalúa D6 y solicita notificación si hay hallazgo nuevo | Reutiliza la misma bandeja; en modo seco no contacta Telegram |
| `python3 scripts/lab.py backup` | Crea una copia adicional ahora | No espera al ciclo automático; valida el catálogo del dump antes de marcar ok |
| `python3 scripts/lab.py restore-test` | Verifica hash y restaura en una base temporal | Comprueba restauración efectiva sin sobrescribir negocio; elimina solo esa base de prueba |
| `python3 scripts/lab.py sql-demo audit` | UPDATE de una fila y consulta antes/después | Demuestra el trigger con datos reales ficticios; cambia lote 1 a «revision» |
| `python3 scripts/lab.py sql-demo roles` | Lista roles y atributos | Complementarlo con pruebas permission denied; el listado no demuestra por sí solo acceso restringido |
| `python3 scripts/lab.py sql-demo baseline` | Consulta referencia de configuración | Permite explicar R5/H5 al profesor |
| `python3 scripts/lab.py sql-demo events` | Consulta eventos de seguridad recientes | Acredita bloqueos/autenticaciones y errores reales de IA |
| `python3 scripts/lab.py groq-probe` | Hace una llamada real a Groq | Sirve para comparar clave vigente, revocada y reemplazada; no usa respuesta simulada |
| `python3 scripts/lab.py retry-alerts` | Reintenta hasta diez alertas pendientes/fallidas | Recuperación manual tras agotar los tres reintentos del nodo; no reenvía las ya enviadas |
| `docker compose ps` | Lista estado y mapeos de puertos | Debe verse publicación solo en Nginx; EXPOSE interno no es publicación |
| `docker compose exec -T nginx nginx -t` | Verifica sintaxis de Nginx | `-T` desactiva TTY para una salida reproducible; no confundir con `nginx -T`, que imprime configuración |
| `curl --fail --cacert .runtime/certs/ca.crt -I https://localhost:8443/auditoria.html` | Verifica TLS y cabeceras con HEAD | `--cacert` confía solo en nuestra CA; se evita `-k`, que ocultaría fallos de validación |
| `docker compose logs --tail 100 monitor` | Revisa los últimos logs del servicio | Acota la salida; no imprimir .env ni tokens para diagnosticar |
| `docker compose stop` | Detiene preservando contenedores y datos | Útil para terminar una sesión sin borrar persistencia |
| `docker compose down` | Retira contenedores/redes, conserva volúmenes | No se incluye `-v`: ese modificador borraría datos persistentes |

## Ubuntu y UFW

Estos comandos cambian el **Ubuntu dedicado al laboratorio**. Si se administra por SSH, autorizar primero el puerto administrativo que se use realmente. En una VM manejada por consola no es necesario abrir un acceso remoto adicional.

| Comando | Qué hace / para qué | Por qué |
|---|---|---|
| `sudo apt update` | Actualiza el índice de paquetes Ubuntu | Permite instalar desde el estado actual del repositorio oficial |
| `sudo apt install -y python3 openssl git ufw rsyslog` | Instala utilidades de host y registros | Son herramientas del laboratorio; no reemplaza la instalación oficial de Docker/Compose |
| `sudo ufw default deny incoming` | Niega entrada por defecto | Solo se abren excepciones justificadas |
| `sudo ufw default allow outgoing` | Permite conexiones salientes | Telegram/Groq requieren salida; no implica permitir entrada a PostgreSQL |
| `sudo ufw allow 22/tcp` | Autoriza SSH administrativo si se usa puerto 22 | Condicional: adaptar al puerto real o no ejecutar si no se usa SSH remoto |
| `sudo ufw logging low` | Activa logs básicos de tráfico UFW | Reduce ruido respecto de un nivel detallado; un cambio de regla no equivale a un paquete bloqueado |
| `sudo ufw enable` | Activa las reglas anteriores | Hacerlo desde consola del laboratorio o tras autorizar el acceso administrativo |
| `sudo ufw status verbose` | Comprueba políticas y reglas | Es evidencia del estado, no de que los puertos Docker estén protegidos por UFW |
| `sudo python3 scripts/host_agent.py` | Observa UFW cada 30 s y envía hashes por HTTPS local | Solo este observador necesita root; monitor/n8n no reciben privilegios del host |
| `sudo python3 scripts/host_agent.py --once` | Envía una observación | Diagnóstico puntual; no mantiene H1 actualizado por más de 90 s |
| `sudo ufw allow 5432/tcp` | Modifica una regla para A3/H1 | Ensayo real de cambio de configuración; no publica por sí solo PostgreSQL |
| `sudo ufw delete allow 5432/tcp` | Retira esa regla después del ensayo | Revierte la excepción, siempre comprobando que corresponde al laboratorio |

## Desarrollo, herramientas y CI

| Comando | Qué hace / para qué | Por qué |
|---|---|---|
| `python3 -m venv .venv` | Crea un entorno Python local | Separa dependencias del sistema Ubuntu |
| `.venv/bin/python -m pip install -r requirements-dev.txt` | Instala dependencias directas versionadas y pruebas | El ejecutable explicita el entorno; no necesita activarlo con source |
| `.venv/bin/python -m pytest tests -q` | Ejecuta pruebas unitarias y de contratos | `-q` reduce ruido; no acredita conexiones externas ni arranque Docker |
| `.venv/bin/python scripts/generate_workflows.py` | Regenera los 18 JSON | Una sola definición evita divergencias; los JSON existentes permiten arrancar sin este paso |
| `.venv/bin/python scripts/explain_sources.py` | Regenera la guía HTML con fuentes y explicaciones | Mantiene números de línea consistentes después de editar |
| `python3 scripts/package.py` | Empaqueta fuentes que Git sigue y agrega hashes | Excluye datos privados y rechaza claves/secretos conocidos del entorno. Ejecutar después de git add; el ZIP queda fuera del repositorio |
| `docker compose config --quiet` | Valida Compose e interpolación | Detecta estructura inválida antes de crear servicios; no prueba que las imágenes arranquen |
| `docker compose --profile qa run --rm tester pgbench` | Ejecuta una carga de lectura de 20 s | No usa pgbench -i, que crearía tablas ajenas al modelo; no pretende ser un benchmark de producción |
| `docker compose --profile qa run --rm tester pgbadger` | Analiza CSV PostgreSQL reales | Produce `.runtime/reports/pgbadger.html`; no utiliza logs inventados |
| `docker compose -f compose.yaml -f compose.logging.yaml up -d --build` | Integra Filebeat, Logstash y Loki | El segundo archivo es una extensión explícita; Logstash adapta Beats al protocolo Loki |
| `docker compose -f compose.yaml -f compose.logging.yaml logs --tail 100 logstash filebeat loki` | Revisa la cadena de registros | Detectar errores antes de declarar que la integración funciona |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -v ON_ERROR_STOP=1 < tests/sql-invariants.sql` | Ejecuta invariantes en laboratorio nuevo | Falla ante error y revierte sus cambios de prueba; no ejecutar en producción |

## Qué ejecutan internamente los scripts

Acceso opcional desde Windows al Ubuntu de la VM: `ssh -N -L 8443:127.0.0.1:8443 -L 8080:127.0.0.1:8080 USUARIO_UBUNTU@IP_VM`. Sustituir usuario/IP por los reales del laboratorio. `-N` mantiene solo el túnel, y cada `-L` reenvía un puerto local al loopback de Ubuntu. Mantener esa terminal abierta y visitar localhost en Windows. No abre PostgreSQL ni requiere redirección en el router. Se necesita SSH administrativo de la VM configurado, independiente de ssh-lab:2222. Alternativa más simple: navegador dentro de Ubuntu Desktop.

`openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 365`: crea la CA local; RSA 2048 prioriza compatibilidad del laboratorio, SHA-256 firma y `-nodes` permite arranque sin pedir una frase. **La protección de la clave está en permisos 600 y directorio privado**, no en cifrado de archivo. El certificado de servidor se firma por 30 días y lleva SAN; un CN solo no basta para validar nombres modernos.

`psql -v ON_ERROR_STOP=1 -v nombre=valor`: detiene errores y enlaza literales con `:'nombre'`; se evita concatenar contraseñas sin escape. La sesión desactiva logs de instrucciones al crear los usuarios. `pg_dump --format=custom --no-owner --no-privileges`: archivo restaurable y portable; **no conserva por sí solo las cuentas/ACL del clúster**. `pg_restore --list` valida catálogo, mientras `restore-test` efectúa la restauración. `sha256sum` detecta cambios en los bytes, pero no autentica contra un atacante que pueda cambiar también el manifiesto.

`sshpass` usa exclusivamente una contraseña **falsa** para veinte intentos limitados contra `ssh-lab:2222`. `ssh-keyscan` recoge la clave del servicio interno y luego se exige esa clave; no es verificación fuera de banda resistente a un atacante que ya controle esa red. `SET statement_timeout` se amplía solo en la sesión QA que mantiene conexiones para R2/H4, no para el bot.

`SET SESSION AUTHORIZATION`, `SET ROLE`, `GRANT`, `REVOKE`, `ALTER SYSTEM`, `pg_reload_conf()` y las sentencias de cada escenario se explican en [CODIGO](CODIGO.md) y [ESCENARIOS](ESCENARIOS.md). Los comandos Git/GitHub se explican individualmente en [PUBLICAR_GITHUB](PUBLICAR_GITHUB.md). Las opciones de archivos de configuración y cada línea de las fuentes se pueden consultar en la guía HTML.
