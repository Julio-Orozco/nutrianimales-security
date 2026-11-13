# Arquitectura y decisiones

| Componente | Función | Por qué se eligió | Límite |
|---|---|---|---|
| PostgreSQL 16 | Datos, roles y auditoría | Coincide con el curso; controles efectivos en la BD | El superusuario puede alterar auditoría; no es almacenamiento inmutable externo |
| n8n | Agenda y orquesta 17 detectores + bot | Flujos visuales individuales y JSON sin secretos | La agenda sondea cada 15/30 s; no garantiza instantaneidad |
| Monitor Python | Interpreta SQL, logs, snapshots y entregas | n8n no necesita root, socket Docker ni acceso arbitrario al host | Es una aplicación propia que debe probarse y mantenerse |
| Nginx | Único punto web publicado | TLS y cabeceras en un lugar | CSP permite scripts inline por compatibilidad con n8n; mejorable con una política específica validada |
| Agente Ubuntu | Observa UFW como root en el host de laboratorio | Docker Desktop no proporciona evidencia de UFW del Windows anfitrión | Requiere sesión/proceso activo; H1 marca fuente ausente si se detiene |
| ssh-lab | Objetivo A1 en puerto 2222 interno | Evita atacar el acceso administrativo real | Permite contraseña deliberadamente; no representa el hardening SSH de producción |
| Backup | pg_dump periódico y restauración ensayable | Una copia solo se considera recuperable después de probarla | No respalda n8n, CA, .env ni archivos del servidor |
| pgAdmin | Administración gráfica | Herramienta solicitada por la guía | Cuenta diferente a los roles del panel n8n |

## Redes y conexiones

`datos` = 172.30.40.0/24, interna. PostgreSQL tiene 172.30.40.2. `prueba_externa` = 172.30.99.0/24, interna y separada, para H4. PostgreSQL escucha también allí para permitir un ensayo autenticado desde fuera del CIDR autorizado por el detector. **Es una red de prueba, no Internet.** El HBA permite ambos orígenes con TLS/SCRAM; H4 denuncia el segundo. Esto es una concesión explícita del laboratorio; en producción se bloquearía ese origen también en HBA/red.

`salida` permite conexiones externas de monitor y n8n. Solo Nginx publica puertos, ligados a loopback. Un servicio puede mostrar `5432/tcp` en `docker compose ps` por su metadata EXPOSE sin que exista un mapeo al host. Verificar la ausencia de `HOST:PUERTO->5432`, no únicamente la palabra 5432.

## Telegram y Groq

El flujo B0 invoca `/bot/poll`. Monitor consulta `getUpdates` y conserva el offset; no se configura webhook ni se necesita túnel. Solo un proceso debe consumir ese bot. Si hay webhook, se informa el conflicto y no se elimina automáticamente.

El bot acepta tres reportes predefinidos. Para `/ia ventas`, obtiene el mismo reporte permitido y pide a Groq un resumen de agregados. No envía filas de clientes ni ejecuta SQL generado por el modelo. La autorización está antes de la IA. La cuenta SQL solo tiene SELECT y timeout; el catálogo no es la única barrera.

n8n activa protección SSRF y permite por nombre únicamente el servicio interno monitor como excepción a redes privadas; no se deshabilita toda la protección para llegar al detector. No sustituye la separación de redes y permisos.

Filebeat/Logstash/Loki se incluye para reproducir la combinación de la guía. Grafana desaconseja el complemento Logstash para nuevos despliegues y recomienda Alloy. Por eso esta extensión no se presenta como la mejor arquitectura de producción: si el docente acepta reemplazar Filebeat, una ruta Alloy→Loki sería más sencilla y tendría menos componentes. No ocultar esa diferencia ni invertir todo el tiempo de integración en una extensión sin probar primero las alertas centrales.

## Persistencia y reinicio

Volúmenes nombrados: datos PostgreSQL, metadata/credenciales n8n y pgAdmin. `.runtime`: certificados, backups, estado y logs del laboratorio. El estado conserva offsets y baselines para que un reinicio no «apruebe» una modificación sospechosa. Un reset de pg_stat_statements inicia una nueva referencia, sin interpretar diferencias negativas como actividad maliciosa.

La bandeja registra la detección antes del envío. Una entrega fallida no se presenta como enviada. Un cooldown de cinco minutos por código reduce ruido, pero puede agrupar incidentes diferentes ocurridos dentro del mismo período; no es un SIEM de producción. Existe una ventana de duplicación si Telegram acepta un envío y la conexión cae antes de que se guarde el resultado: ninguna transacción SQL hace atómica una API externa.

## Cambios respecto de la guía

R4 observa PostgreSQL y SSH como fuentes distintas. H1 usa hashes de reglas además de logs: UFW no garantiza que cada cambio administrativo produzca un evento de tráfico. H2 usa SHA-256, no MD5. H3 observa ACL efectivas, no solo atributos globales de pg_roles. H4 compara CIDR real, no un prefijo `172`. D1/D6 cuentan cada sentencia mediante triggers y analizan su AST. D7 calcula diferencias de estadísticas y distingue una ejecución de un volumen acumulado. Se generan 1.500 clientes para superar el umbral. Estos ajustes se documentan, no se ocultan como si fueran el ejemplo literal.
