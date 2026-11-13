# Registro de evidencia real

Crear una carpeta privada por fecha en `evidencias/`, que Git ignora. No incluir tokens, contraseñas, clave privada TLS ni contenido íntegro de .env. Sí se puede mostrar su nombre/permisos. No editar resultados para simular aprobación.

| Evidencia | Qué capturar | Criterio |
|---|---|---|
| E01 | compose ps y puertos | Stack disponible, solo Nginx publicado |
| E02–E13 | Un punto de hardening por captura | Tabla CUMPLIMIENTO con comando y resultado legibles |
| E14 | Roles, prueba gerente denegado, agente denegado | Permisos efectivos, no solo nombres |
| E15 | UPDATE y auditoría antes/después | Usuario real y cuatro triggers activos |
| R1–R5 | Acción + ejecución n8n + Telegram real | Cada regla con fuente, umbral y hora |
| H1–H5 | Cambio real + snapshot/log + Telegram | Agente Ubuntu activo en H1; SHA distinto en H2 |
| D1–D7 | Acción + conteos/consulta + alerta | D6 >50 por sentencia, D7 >1000 filas nuevas |
| A1–A5 | Comando/mensaje, evento, tiempo y respuesta | No mezclar «detectó» con «bloqueó» |
| ROT-01–04 | Clave válida, revocada, nueva y recuperación | Códigos reales; ocultar valores |
| BKP-01 | Archivo, SHA y restore-test.json | Restauración real en base separada |
| PERF-01 | pgbench + pgBadger | Indicar equipo, tiempo y tipo de carga |
| LOG-01 | Filebeat/Logstash/Loki sin errores y evento consultable | No basta con ver contenedores «running» |
| DEMO-01 | Ensayo completo y tiempo de arranque | Declarar si imágenes ya estaban descargadas |

## Comandos de evidencia adicionales, explicados

| Comando | Qué hace / para qué / elección |
|---|---|
| `ls -l .env` | Muestra modo y propietario sin revelar contenido; debe ser 600 |
| `ls -ld .runtime/state .runtime/backups .runtime/private` | Revisa directorios privados; -d muestra el directorio, no su contenido |
| `docker compose exec -T n8n id` | UID efectivo del proceso de diagnóstico dentro de n8n; debe ser1000 |
| `docker compose exec -T pgadmin id` | UID efectivo de pgAdmin; debe ser5050, no se exige falsamente1000 |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -c 'SHOW ssl;'` | Valor efectivo servidor; debe seron. Complementar con una sesión TLS real |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -c 'SHOW password_encryption;'` | Cifrado de contraseñas nuevas; complementar con HBA/SCRAM real |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -c 'SELECT pid,ssl,version,cipher FROM pg_stat_ssl;'` | Observa cifrado por sesión; los sockets locales no son sesiones TLS |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -c '\d auditoria_datos'` | Estructura y campos de la tabla; \d es un metacomando psql, no SQL servidor |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -c 'SELECT * FROM pg_stat_statements LIMIT 5;'` | Confirma extensión visible y datos reales; LIMIT acota salida |
| `docker compose exec -T postgres psql -U postgres -d nutrianimales -c 'SELECT alerta,estado,fecha,enviada_en FROM alertas_auditoria ORDER BY fecha DESC LIMIT 20;'` | Distingue detección y envío; no llamar enviada a dry-run |

Para inspeccionar redes sin inventar el nombre, obtenerlo desde `docker compose ps`/`docker network ls`; Compose aplica el prefijo de proyecto. `docker network ls` enumera redes; `docker network inspect NOMBRE_REAL` muestra su configuración y miembros. El marcador NOMBRE_REAL debe sustituirse por el valor observado, no copiarse literalmente.

## Tabla de resultados para completar

| Regla/ataque | Acción/hora | Detección/hora | Telegram/hora | Duración | Respuesta/reversión | Archivo | Resultado |
|---|---|---|---|---|---|---|---|
| PENDIENTE | | | | | | | No ejecutado |

No usar logs de un CI ajeno como evidencia de ejecución propia en clase. Los resultados de verificación del repositorio se explican aparte en VERIFICACION.md.
