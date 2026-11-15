# NutriAnimales S.A. — Seguridad de infraestructura y base de datos

Proyecto académico de Seguridad de Sistemas Digitales (BCD 9220). Los datos son ficticios. Este checkout contiene Docker Compose, PostgreSQL, Nginx, pgAdmin, Filebeat y 18 definiciones JSON de flujos n8n. El proyecto **no usa Python**: la detección y las alertas se construyen con nodos de n8n que consultan PostgreSQL. No contiene el stack Logstash/Loki ni el PDF/Word del informe; por tanto, esos componentes no se declaran desplegados ni comprobados.

## Requisitos

- Ubuntu/Linux con Docker Engine y Docker Compose v2.
- OpenSSL; `sudo` solo se requiere para asignar la clave TLS de PostgreSQL al UID/GID del usuario `postgres` de la imagen.
- Internet para descargar las imágenes la primera vez.

## Preparar y arrancar

Desde la raíz del repositorio:

```bash
bash scripts/prepare-ab.sh
docker compose config --quiet
docker compose up -d --wait
docker compose ps
```

El preparador crea `.env` con valores aleatorios solo si aún no existe, aplica modo `600` y prepara certificados locales con SAN. Nunca reemplaza el `.env` existente. No compartas `.env`, `infra/certs/server.key` ni `infra/postgres-tls/server.key`. Si la clave TLS de PostgreSQL no pertenece al UID/GID requerido, el preparador solicitará `sudo` para corregir su propietario.

La primera inicialización carga el esquema y datos ficticios desde `db/sql/`. PostgreSQL solo ejecuta esos archivos cuando su volumen de datos está vacío; reiniciar o recrear contenedores conserva la base.

### Actualizar una instalación existente (corrección del 502 de n8n)

Si la base ya estaba creada antes de esta revisión, n8n seguirá intentando usar `monitor_db` hasta aplicar la migración. Desde WSL, en la raíz del proyecto:

```bash
bash scripts/migrate-n8n-app.sh
```

El script agrega `N8N_DB_PASSWORD` a `.env` si falta (sin modificar las demás variables), crea un respaldo verificable en `.runtime/backup-<fecha>/` (dump de la base, roles sin contraseñas y volumen `n8n_data`), aplica `db/sql/06-n8n.sqb`, recrea solo el contenedor n8n y comprueba `healthz` y `https://localhost:8443/`. No ejecuta `down -v` ni borra volúmenes. El detalle del problema y la solución está en [docs/ENTREGA_REVISION2.md](docs/ENTREGA_REVISION2.md).

## Acceso y puertos

- n8n: <https://localhost:8443>. Verificado el 14/11/2026: `healthz` responde `ok`, la ruta raíz devuelve HTTP 200 con la interfaz de n8n y el WebSocket `/rest/push` se establece a través de Nginx. La primera visita muestra el formulario para crear la cuenta propietaria de n8n; esa cuenta la crea el equipo y no se guarda en el repositorio.
- pgAdmin, a través del proxy Nginx: <https://localhost:8443/pgadmin/>
- Redirección HTTP: `http://localhost:8080`
- Solo Nginx publica puertos, ligados a `127.0.0.1`. PostgreSQL, n8n, pgAdmin y Filebeat no publican puertos al host. pgAdmin no publica `5050`.
- El certificado es autofirmado para el laboratorio. Para una solicitud verificada desde terminal:

```bash
curl --fail --cacert infra/certs/server.crt -I https://localhost:8443/auditoria.html
```

El navegador mostrará una advertencia hasta que confíes explícitamente en el certificado local. No uses `curl -k` como prueba de confianza.

El correo inicial de pgAdmin es `ti@nutrianimales.test`; en una instalación nueva el preparador genera su contraseña. No reemplaza un `.env` preexistente. Desde pgAdmin, el servidor PostgreSQL usa el nombre DNS `postgres`, la base `nutrianimales` y credenciales definidas localmente.

## Verificaciones de A y B

```bash
docker compose exec -T n8n id
docker compose exec -T pgadmin id
docker compose exec -T filebeat id
stat -c '%a %n' .env infra/certs/server.key infra/postgres-tls/server.key
git check-ignore -v .env
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SHOW ssl; SHOW password_encryption; SHOW log_min_duration_statement;"
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT name,valor_esperado,setting,valor_esperado=setting AS coincide FROM pg_settings_baseline JOIN pg_settings USING(name) ORDER BY name;"
bash scripts/test-init-ab.sh
```

Para las capturas de los doce controles, cada control se ejecuta con una sola orden (`A1` … `A12`, `B1` … `B4`, `N8N`):

```bash
sh scripts/capturas-ab.sh A1
sh scripts/capturas-ab.sh todo   # todos los controles seguidos
```

Para comprobar los conteos de las ocho tablas obligatorias:

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales -c "SELECT 'plantas',count(*) FROM plantas UNION ALL SELECT 'productos',count(*) FROM productos UNION ALL SELECT 'materias_primas',count(*) FROM materias_primas UNION ALL SELECT 'lotes_produccion',count(*) FROM lotes_produccion UNION ALL SELECT 'clientes',count(*) FROM clientes UNION ALL SELECT 'ventas',count(*) FROM ventas UNION ALL SELECT 'control_calidad',count(*) FROM control_calidad UNION ALL SELECT 'gastos',count(*) FROM gastos;"
```

La demostración controlada registra INSERT, UPDATE y DELETE de una fila ficticia, elimina esa fila de prueba y conserva los eventos en auditoría:

```bash
docker compose exec -T postgres psql -X -U postgres -d nutrianimales < db/demo-audit.sql
```

La matriz de cumplimiento, los comandos de comprobación y los resultados de esta instalación están en [docs/CUMPLIMIENTO.md](docs/CUMPLIMIENTO.md), [docs/COMANDOS.md](docs/COMANDOS.md) y [evidencias/RESULTADOS_AB.md](evidencias/RESULTADOS_AB.md). La guía de captura distingue siempre configuración de prueba ejecutada.

## Alcance no incluido en este checkout

Los JSON de `n8n/workflows/` no se importan automáticamente y provienen de una versión anterior que llamaba a un servicio Python (`monitor`) que este proyecto no usa; los integrantes de monitoreo y bot deben adaptarlos o rehacerlos siguiendo [docs/FLUJOS_N8N.md](docs/FLUJOS_N8N.md). Tampoco se incluye una conexión Filebeat→Logstash→Loki ni el informe original adjunto. En este WSL, `/var/log/ufw.log` no es un archivo de log sino un directorio vacío creado por Docker al montar una ruta inexistente, por lo que Filebeat no recibe eventos UFW. No se debe afirmar que alertas, Telegram, monitor, ataques, backups o pruebas de otras partes están ejecutados. Para completar esas funciones se necesitan los archivos fuente y el documento oficial que no están en este espacio de trabajo.

## Detener sin borrar datos

```bash
docker compose stop
```

`docker compose down` elimina contenedores y red, pero conserva los volúmenes. No agregues `-v` salvo que quieras borrar deliberadamente la base y los datos persistidos.
