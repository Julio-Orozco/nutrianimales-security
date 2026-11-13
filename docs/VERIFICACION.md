# Verificación de esta entrega

Fecha: 12 de noviembre de 2026. No contiene resultados de una instalación del grupo ni capturas inventadas.

## Comprobado durante la preparación

- **43 pruebas Python aprobadas**: límites de horario/CIDR, parser SQL, estadísticas acumuladas, autorización API/auditor, bloqueo de inyección antes de consultar BD, pérdida de credencial Groq, fuentes ausentes, crecimiento, permisos efectivos observados y estados de entrega/deduplicación. Dos avisos de dependencias de pruebas (pytest/Starlette-httpx), sin fallos.
- Compilación de archivos Python sin errores.
- Compose principal y extensión de logs validados por Docker Compose2.39.1 mediante `config --quiet`.
- `prepare` ejecutado y repetido sin sobrescribir los secretos. Certificado verificado con OpenSSL contra la CA y nombre postgres. Es material de verificación local excluido del ZIP.
- Esquema, datos, funciones de auditoría y grants ejecutados sobre **PostgreSQL16.2 real en modo standalone**, sin servidor de red. Se comprobó UPDATE antes/después, atribución al usuario de sesión, conteo de 500 filas por sentencia y denegaciones efectivas. También se invocó security_snapshot con rol monitor_db.
- Límite de esa prueba SQL: el paquete standalone no incluye pg_stat_statements; se omitió exclusivamente su CREATE EXTENSION en el arnés local, sin eliminarlo del proyecto. No se probó el recolector de métricas contra una extensión activa. Por ausencia de sesión autenticada de red, el arnés restableció explícitamente la identidad postgres en lugar del RESET de sesión usado en el test normal. El CI de integración mantiene el ensayo normal por psql.
- Etiquetas postgres16.11, Python3.12.12, Nginx1.28.0, pgAdmin9.10, Loki3.5.7 y n8n2.47.4 consultadas en registro; paquetes Python directos contrastados con PyPI. Existir no significa que la imagen se haya arrancado ni que esté libre de vulnerabilidades.
- Se incluyen 18 JSON n8n estructuralmente comprobados, sin tokens reales y con conexiones de nodos coherentes.

## Pendiente de ejecutar en su entorno

No hay daemon Docker utilizable en el entorno de preparación, por lo que **no se ejecutó el stack completo**, ni se ensayó su arranque, importación/publicación n8n, carga de pgAdmin, permisos efectivos de todas las imágenes, backup/restauración Docker ni cadena Filebeat/Logstash/Loki. Se proporciona un workflow de integración que debe ejecutarse y revisarse en GitHub o localmente.

Tampoco se usaron tokens del usuario: faltan la recepción/envío real Telegram, Groq y su revocación, cinco ataques completos, diecisiete capturas, medición de latencia, UFW del Ubuntu anfitrión y carga/rendimiento reales. La lógica y configuración incluidas no sustituyen esas evidencias. El Viewer nativo sigue sujeto a licencia/acuerdo docente.

## Cómo repetir la comprobación ordinaria

Instalar requirements-dev en un entorno virtual y ejecutar pytest como indica COMANDOS. Después levantar el laboratorio real y ejecutar tests/sql-invariants.sql a través de psql. Revisar Actions y corregir cualquier incompatibilidad del entorno antes de la exposición. No usar la existencia de ci.yml como prueba de un CI aprobado.
