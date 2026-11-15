# Dependencias y fuentes oficiales

Esta tabla conserva el diseño documentado; este checkout no incluye el servicio Python, los archivos `requirements*` ni los scripts que aparecen abajo. Las versiones reales de los servicios se definen en `compose.yaml`. No tomar esta tabla como manifiesto de dependencias instaladas ni como verificación de vulnerabilidades.

| Dependencia | Para qué | Por qué esta elección / alternativa |
|---|---|---|
| Python3.12 | Servicio y utilidades | Sintaxis estándar y herramientas disponibles en Ubuntu24.04; evitar paquetes de sistema globales al desarrollar |
| FastAPI | API con validación y autorización | Modelos tipados, rutas claras y cliente de pruebas; una API más pequeña podría usar stdlib, pero requeriría reimplementar validación |
| Uvicorn | Servidor ASGI | Ejecuta FastAPI sin servidor de desarrollo; una réplica única para el estado local |
| psycopg[binary]3 | PostgreSQL | Parámetros, transacciones y TLS. Binario simplifica instalación del laboratorio; no hace falta compilar libpq en la imagen |
| pglast | AST SQL PostgreSQL | Interpreta comentarios, literales y estructuras; una regex no es un parser ni una política suficiente |
| urllib/ssl stdlib | Telegram/Groq y administración local | Reduce dependencias y centraliza timeout/validación TLS |
| pytest/httpx | Pruebas | Mock explícito de proveedores solo en tests; la ejecución externa se prueba por separado |
| PyYAML | Inspección estática Compose | No reemplaza `docker compose config` ni levantar contenedores |
| PostgreSQL `16.14` | Servidor del stack | Etiqueta definida en Compose; no declara parche de producción |
| n8n `2.30.8` | Orquestación | Versión fijada en Compose (mismo digest que la imagen validada); actualizarla solo con respaldo, porque cada versión aplica migraciones al esquema `n8n` |
| Nginx `latest` | Reverse proxy TLS | Etiqueta mutable; valida configuración local con `nginx -t` |
| pgAdmin `latest` | Administración gráfica | Etiqueta mutable; UID efectivo de imagen 5050 |
| Filebeat `8.13.4` | Recolector configurado | Corre sin root, pero en este checkout emite a consola |
| Logstash/Loki | No incluidos | No hay `compose.logging.yaml` ni servicios de esa cadena en este checkout |

Fijar una etiqueta no prueba seguridad actual. Los paquetes apt se resuelven al construir sobre repositorios oficiales, por lo que la reproducción no es bit a bit. Antes de uso real: escaneo de imágenes, revisión de licencias, actualización de parches y pruebas de compatibilidad. No se afirma ausencia de vulnerabilidades ni certificación de producción.

## Documentación primaria consultada

- PostgreSQL16, pg_stat_statements y significado acumulado de rows/calls/tiempos: https://www.postgresql.org/docs/16/pgstatstatements.html
- PostgreSQL16, logs JSON/CSV: https://www.postgresql.org/docs/16/runtime-config-logging.html
- PostgreSQL16, triggers y transition tables: https://www.postgresql.org/docs/16/sql-createtrigger.html
- PostgreSQL16, SECURITY DEFINER y search_path: https://www.postgresql.org/docs/16/sql-createfunction.html
- PostgreSQL16, TLS: https://www.postgresql.org/docs/16/ssl-tcp.html
- n8n, Docker: https://docs.n8n.io/hosting/installation/docker/
- n8n, API y API key: https://docs.n8n.io/api/authentication/
- n8n, CLI y publicación de flujos: https://docs.n8n.io/hosting/cli-commands/
- n8n, disponibilidad del Viewer: https://docs.n8n.io/administer/manage-users-and-access/set-permissions-and-roles-rbac/see-available-roles/
- Telegram Bot API, getUpdates/offset y exclusión de webhook: https://core.telegram.org/bots/api
- Groq, API compatible OpenAI: https://console.groq.com/docs/openai
- Docker, restart y entorno: https://docs.docker.com/reference/cli/docker/compose/restart/
- Docker y UFW: https://docs.docker.com/engine/network/packet-filtering-firewalls/
- Loki, complemento Logstash: https://grafana.com/docs/loki/latest/send-data/logstash/
- Elastic, salida Filebeat a Logstash: https://www.elastic.co/docs/reference/beats/filebeat/logstash-output
- n8n, protección SSRF y excepción de hostname: https://docs.n8n.io/hosting/configuration/environment-variables/ssrf-protection/

La documentación de Grafana desaconseja el complemento Logstash para despliegues nuevos y recomienda Alloy. Aquí se conserva como extensión de compatibilidad con la combinación Filebeat/Loki exigida por la guía, no como preferencia técnica de producción.

La guía académica aportada por el usuario define el alcance. Las referencias explican decisiones técnicas; los resultados del laboratorio deben producirlos y documentarlos los integrantes.
