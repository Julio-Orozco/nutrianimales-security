# Verificación de A y B

Fecha de ejecución: 14 de noviembre de 2026. Los resultados son de la instancia Docker de este entorno, no de la computadora de exposición. No se generaron capturas de pantalla.

## Resultados ejecutados

- Docker Engine 29.6.2 y Compose v5.3.1; `docker compose config --quiet` terminó correctamente.
- El Compose se recreó sin borrar volúmenes. PostgreSQL, n8n, Nginx, pgAdmin y Filebeat aparecen como procesos en ejecución. **Esto no equivale a que todos los endpoints estén disponibles:** pgAdmin funciona detrás de Nginx; n8n, aunque su contenedor queda en ejecución, no abre el puerto 5678 y el proxy devuelve 502. La causa no se pudo determinar en este checkout.
- Solo Nginx publica `127.0.0.1:8080` y `127.0.0.1:8443`. pgAdmin no publica 5050 y PostgreSQL no publica 5432.
- UID efectivos: PostgreSQL 999, n8n 1000, Nginx 1000, pgAdmin 5050 y Filebeat 1000 (grupo `adm` para la lectura opcional de logs).
- La red bridge creada contiene los cinco servicios y tiene salida (no es `internal`). HBA acepta `samenet` con TLS/SCRAM y rechaza el resto de conexiones host.
- `.env` tiene modo 600 y Git lo ignora. El archivo existía antes y no fue sobrescrito; sus valores no se muestran. `.env.example` quedó sin contraseñas predeterminadas. La preparación no rota credenciales de una instalación existente; coordinar cualquier rotación con PostgreSQL, pgAdmin y n8n antes de usarla fuera del laboratorio.
- HTTPS para `localhost` valida con `openssl verify`; SAN incluye `localhost` e `127.0.0.1`. La solicitud local devuelve los cuatro headers exigidos. El certificado es autofirmado; no tiene confianza pública.
- El navegador integrado rechazó el certificado autofirmado (`ERR_CERT_AUTHORITY_INVALID`), como corresponde antes de importar confianza local; por ello no se guardó una captura de navegador. `curl --cacert` sí validó la cadena y el nombre.
- pgAdmin abre por `/pgadmin/` a través de HTTPS y redirige al formulario; al seguir la redirección responde 200. No se publica al host.
- PostgreSQL muestra SSL `on`, cifrado de contraseñas `scram-sha-256` y log de duración mínima 1 s. La conexión de agente_ia pasó `sslmode=verify-full` con TLS 1.3.
- Baseline: siete parámetros comparados; las siete filas coinciden. Conteos: 3 plantas, 50 productos, 100 materias primas, 500 lotes, 1.500 clientes, 1.500 ventas, 300 controles de calidad y 200 gastos.
- Catálogo: 14 tablas, 14 PK, 5 FK, índices de auditoría por tabla/usuario/fecha, dos funciones de auditoría y veinte eventos de triggers sobre las cuatro tablas críticas.
- Inicialización desde cero probada en un contenedor PostgreSQL temporal sin red ni puertos publicados: 14 tablas, 20 triggers y siete parámetros de baseline; el contenedor se retiró automáticamente.
- agente_ia pudo SELECT sobre los productos y no tiene grants de escritura. INSERT, UPDATE y DELETE se rechazaron efectivamente como transacciones de solo lectura.
- `db/demo-audit.sql` ejecutó un INSERT/UPDATE/DELETE sobre una fila ficticia, eliminó la fila y dejó tres eventos de auditoría. El evento DELETE conservó `valor_antes` y `valor_nuevo IS NULL`.
- `SELECT pg_sleep(1.1)` quedó registrado con duración mayor a 1.000 ms y aparece en `pg_stat_statements`.
- Filebeat funciona sin root y sin errores recientes, pero no se verificó un archivo UFW del host; la salida configurada es consola, no Logstash/Loki.

Los comandos y salidas resumidas están en `evidencias/RESULTADOS_AB.md`. La matriz de los doce controles está en `docs/CUMPLIMIENTO.md`.

## Pendiente

- Diagnosticar por qué n8n no abre su puerto y por qué la tabla de n8n está vacía; no afirmar que el servicio de UI o sus flujos funcionen.
- Ejecutar la instalación en el equipo de exposición y guardar las capturas propias de los doce controles.
- Recibir la rúbrica oficial y el PDF/Word actual. No estaban en los archivos disponibles, por lo que `docs/INFORME.md` contiene secciones listas para integrar, no una edición del archivo original.
- El checkout carece de `scripts/lab.py`, `scripts/host_agent.py`, `app/`, `monitor`, `compose.logging.yaml`, Logstash, Loki y pruebas automatizadas. Alertas, Telegram/Groq, UFW, backups y escenarios que dependan de ellos no se han probado ni se declaran completos.
- Medir arranque desde una instalación limpia, con equipo e imágenes especificados.

## Repetición básica

Seguir `docs/COMANDOS.md`. No usar `curl -k`, editar salidas, mostrar credenciales, borrar el volumen de PostgreSQL ni tratar la presencia de un contenedor como evidencia de una aplicación funcional.
