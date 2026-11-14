# Evidencias A y B

Guardar únicamente salidas obtenidas en el laboratorio real. No se generaron capturas de pantalla en esta sesión; `evidencias/RESULTADOS_AB.md` contiene comandos y resultados de consola reales, sin secretos. Para una exposición en otra máquina, repetir las pruebas y guardar sus propias capturas.

| Evidencia | Control / demostración | Comando o archivo | Qué acredita |
|---|---|---|---|
| A01 | Identidades de contenedores | `docker compose exec -T <servicio> id` | UID/GID del proceso del servicio; comprobar por separado el proceso PostgreSQL. |
| A02 | Protección de secretos | `stat -c '%a %n' .env`; `git check-ignore -v .env` | Modo 600 e ignorado por Git; no capturar el contenido del archivo. |
| A03 | Red y comunicación TLS | `docker network inspect <nombre-real>` y conexión `agente_ia` con `sslmode=verify-full` | Red de proyecto y comunicación cifrada/autenticada. |
| A04 | Puertos publicados | `docker compose ps` | Solo Nginx en loopback; no PostgreSQL ni pgAdmin directamente. |
| A05 | SCRAM/HBA | Consulta de `password_encryption` y `pg_hba_file_rules` | Autenticación efectiva y reglas activas. |
| A06 | TLS PostgreSQL | Consulta `pg_stat_ssl` desde la conexión de agente_ia | TLS real de la sesión, no solo el valor de `SHOW ssl`. |
| A07 | Solo lectura | SELECT y tres operaciones de escritura como agente_ia | SELECT exitoso; INSERT/UPDATE/DELETE denegados y cero grants de escritura. |
| A08 | Headers web | `curl --cacert ... -I https://localhost:8443/auditoria.html` | HTTPS y los cuatro headers exigidos. |
| A09 | Certificado web | `openssl verify` y `openssl x509 -ext subjectAltName` | Cadena autofirmada y coincidencia del nombre local. |
| A10 | Permisos | `stat` de `.env`, claves y directorios de volúmenes | Modos restrictivos y propietario efectivo de los datos. |
| A11 | Rendimiento y logs | `pg_sleep(1.1)`, logs PostgreSQL y `pg_stat_statements` | Consulta real >1.000 ms registrada y visible en estadísticas. |
| A12 | Baseline | Consulta join entre `pg_settings_baseline` y `pg_settings` | Siete parámetros y comparación individual. |
| B01 | Esquema y datos | `\dt`, consulta de conteos | Tablas y cantidades de semilla. |
| B02 | Triggers/función | Catálogo de `information_schema.triggers` y `\df` | Cuatro tablas, veinte eventos de triggers y funciones existentes. |
| B03 | UPDATE/DELETE | `docker compose exec -T postgres psql ... < db/demo-audit.sql` | Valores antes/después, usuario y DELETE con `valor_nuevo IS NULL`; fila de prueba eliminada. |

No usar `curl -k`, ocultar errores, editar imágenes para simular una captura ni marcar como exitoso un ensayo que no se ejecutó. No incluir `.env`, contraseñas, tokens, claves privadas ni información personal. El certificado público del laboratorio no es una credencial; su clave privada sí debe permanecer fuera de Git y del ZIP.
