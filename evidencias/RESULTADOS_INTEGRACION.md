# Resultados de la integración final — 16/11/2026

Entorno: computadora de Julio (Ubuntu en WSL2, Docker Compose), rama `integracion/demo-final`,
PostgreSQL 16.14, n8n 2.30.8, Nginx 1.31.3. Grupo de Telegram de alertas del equipo.
Tiempos medidos desde que se ejecuta el escenario hasta que la alerta queda `enviada` en
`alertas_auditoria` (el mensaje ya salió hacia Telegram).

## 17 alertas

| Alerta | Escenario (`scripts/demo.sh`) | Resultado | Tiempo |
|---|---|---|---|
| R1 | `r1` (pg_sleep 1,5 s) | Enviada | 7 s |
| R2 | `r2` (12 sesiones activas) | Enviada | 30 s |
| R3 | `r3` (ventana no laboral = hora actual, sesión de gerente_db) | Enviada | 29 s |
| R4 | `r4` (8 contraseñas incorrectas en PostgreSQL) | Enviada | 20 s |
| R4 | `a1` (20 intentos SSH, agente del host) | Enviada | 48 s |
| R5 | `r5` (ALTER SYSTEM work_mem) | Enviada | 18 s |
| H1 | cambio de reglas UFW (simulado sin root; con `sudo ufw allow 5432/tcp` es el mismo código) | Enviada | < 30 s |
| H2 | `h2` (línea agregada a pg_hba.conf) | Enviada | 31 s |
| H3 | `h3` / `a4` (GRANT INSERT a agente_ia) | Enviada | 27–28 s |
| H4 | `h4` (sesión desde red 10.99.0.0/24) | Enviada | 23 s |
| H5 | `h5` (password_encryption = md5) | Enviada | 33 s |
| D1 | `d1` (DELETE sin WHERE, 1 500 filas) | Enviada | 27–29 s |
| D2 | `d2` (+400 ventas) | Enviada | 27 s |
| D3 | sin backups registrados | Enviada al activar los flujos | — |
| D4 | `d4` (6 correos duplicados) | Enviada | 31–32 s |
| D5 | `d5` (bloqueo > 30 s) | Enviada | 40 s |
| D6 | `d6` (UPDATE sin WHERE, 200 filas) | Enviada | 28–29 s |
| D7 | `d7` / `a5` (SELECT * FROM clientes con agente_ia) | Enviada | 17–28 s |

Repetibilidad: después de `scripts/demo-preparar.sh` se repitieron R5, H3, D1, D4, D6 y D7 y todos
volvieron a alertar. Ninguna ejecución de n8n con error en las últimas 500.

## Ataques A1–A5

| Ataque | Detección | Evidencia en auditoría |
|---|---|---|
| A1 Fuerza bruta SSH | R4 (Fuente: SSH, 12 intentos, usuario `atacante`, IP 127.0.0.1) | `auditoria_datos` tabla `evento:ssh` |
| A2 SQL injection por Telegram | Filtro del flujo B0 (patrón `;`) — el texto no llega a SQL; `clientes` sigue con 1 500 filas | `auditoria_datos` tabla `evento:telegram`. Probado: filtro (7 textos, 3 bloqueados) y registro. Pendiente: envío real desde Telegram (requiere un usuario humano) |
| A3 Apertura de puerto | H1 (regla agregada `5432/tcp ALLOW IN`) | `auditoria_datos` tabla `evento:ufw` |
| A4 Escalada de privilegios | H3 (event trigger: ejecutor, sentencia, tablas con escritura) | `auditoria_datos` tabla `evento:postgresql` |
| A5 Exfiltración | D7 (1 500 filas por ejecución, usuario `agente_ia`) | `pg_stat_statements` |

## Hardening, RBAC y seguridad

- `sh scripts/capturas-ab.sh todo`: los 12 puntos verifican (no-root, `.env` 600, red `nutrianimales-net`,
  sin 5432, SCRAM, TLS 1.3, agente_ia solo lectura, headers, certificado, permisos 700/600, logs, baseline).
- `parte-e/sql/03_pruebas_rbac.sql`: 4/4 PASS.
- `bash scripts/pruebas-seguridad.sh`: 24/24 PASS.
- `sh scripts/test-init-ab.sh`: una base nueva desde cero inicializa todo, incluido `07-alertas.sqb`.
- Groq: la API key responde (`/models` HTTP 200) y el modelo `openai/gpt-oss-20b` resume un reporte.

## Problemas encontrados y corregidos en la integración

| Problema | Corrección |
|---|---|
| R4 no existía (solo la versión vieja que llamaba al servicio Python) | `eventos_log_pg()` lee el log JSON de PostgreSQL; el agente del host registra los fallos SSH |
| `registrar_evento()` fallaba con *permission denied* (usa `RETURNING`) | `GRANT SELECT ON eventos_seguridad TO audit_owner` |
| H4 asumía la red 172.18.0.0/16; aquí es 172.21.0.0/16 → falsos positivos | se usa todo el rango Docker 172.16.0.0/12 |
| H2 tenía hashes fijos de otra computadora | tabla `archivos_baseline` registrada en cada instalación |
| H3 solo veía el estado; no repetía alerta en una segunda demo | event trigger `trg_evento_grant` registra cada GRANT |
| Telegram en modo Markdown rompía mensajes con `_` | mensajes en HTML escapado |
| Una alerta fallida quedaba `pendiente` para siempre | reintento mientras esté pendiente + `Marcar enviada` |
| D1–D7 de la punta de la rama del integrante 4 eran la versión vieja | se recuperaron sus commits intermedios con Postgres + Telegram |
| B0 tenía el token de Telegram y la API key de Groq en los nodos | Groq por credencial cifrada; token insertado al importar desde `.env` |
| B0 no tenía filtro para A2 | filtro anti SQL injection + registro en auditoría |
| Exports con correos personales de integrantes | flujos regenerados sin bloque `shared` |
| `N8N_LOG_LEVEL=debug` | `info` (sección 9.2 del PDF) |
| Filebeat montaba `/var/log/ufw.log` inexistente (Docker creó un directorio) | se monta `/var/log` en solo lectura |
| La CLI de n8n no sobrescribe flujos existentes ni los activa | `n8n-configurar.sh` actualiza por API REST y publica |
| R1 enviaba una alerta por cada ejecución lenta | máximo 1 aviso por consulta cada 10 min |
| Al reiniciar `pg_stat_statements` las huellas se repetían y no alertaba | la huella incluye la fecha de reinicio de estadísticas |
