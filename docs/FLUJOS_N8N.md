# Flujos n8n — estado final integrado

Los 18 JSON de `n8n/workflows/` (17 alertas + bot B0) se importan y publican con
`bash scripts/n8n-configurar.sh`. No hay servicio Python: cada alerta es un flujo n8n que consulta
PostgreSQL con la cuenta `monitor_db` (lectura + `pg_monitor`) y notifica por Telegram.

## Forma de cada flujo de alerta

```text
[Cada 30 segundos] ─┐
                    ├─> [Detectar XX: SQL] ─> [¿Hay hallazgo?] ─> [Registrar alerta XX] ─> [¿Alerta nueva?] ─> [Enviar alerta XX: Telegram] ─> [Marcar enviada XX]
[Prueba manual] ────┘
```

- **Detectar**: consulta SQL que devuelve una fila por hallazgo con una `huella` (identificador del
  hallazgo) y un `texto` con el detalle para Telegram.
- **Registrar**: `INSERT … ON CONFLICT (huella)` en `alertas_auditoria` con parámetros `$1/$2`
  (sin concatenar texto en SQL). Si la huella ya fue enviada no se repite; si quedó pendiente porque
  Telegram falló, se reintenta.
- **Telegram**: formato estándar del PDF en HTML escapado (el modo Markdown por defecto rompía los
  mensajes con `_`, p. ej. `alertas_auditoria`).
- **Marcar enviada**: deja constancia de la entrega (`estado='enviada'`, `enviada_en`).

H1 es distinto: el **agente del host** (`scripts/agente-host.sh`) inserta la alerta pendiente y el
flujo solo la envía y la marca.

## Fuente de cada alerta

| Alerta | Fuente | Umbral |
|---|---|---|
| R1 | `pg_stat_statements.mean_exec_time` | > 1000 ms (máx. 1 aviso por consulta cada 10 min) |
| R2 | `pg_stat_activity` (state = active) | > 10 |
| R3 | `pg_stat_activity` + `parametros_alerta` | conexión entre 23:00 y 06:00 (hora CR) |
| R4 | log JSON de PostgreSQL (`eventos_log_pg()`) + SSH de `auth.log` (agente del host) | > 5 fallos en 10 min |
| R5 | `pg_settings` vs `pg_settings_baseline` | cualquier diferencia |
| H1 | hash de `ufw status` + `user.rules` (agente del host) | hash distinto |
| H2 | SHA-256 de `postgresql.conf`, `pg_hba.conf`, `postgresql.auto.conf` vs `archivos_baseline` | hash distinto |
| H3 | event trigger `trg_evento_grant` + `security_snapshot()` (privilegios y roles de `agente_ia`) | GRANT detectado |
| H4 | `pg_stat_activity.client_addr` + rechazos de `pg_hba.conf` en el log | IP fuera de 172.16.0.0/12 |
| H5 | `ssl`, `password_encryption` vs baseline + reglas md5 en `pg_hba_file_rules` | ssl=off o md5 |
| D1 | `auditoria_sentencias` (trigger por sentencia) + `pg_stat_statements` | > 100 filas |
| D2 | INSERT en `auditoria_datos` (30 min) vs `pg_stat_user_tables` | > 20 % |
| D3 | tabla `backups` (último `ok`) | > 24 h |
| D4 | `GROUP BY correo HAVING count(*)` en `clientes` | > 5 |
| D5 | `pg_stat_activity.wait_event_type='Lock'` | > 30 s |
| D6 | `auditoria_sentencias` + `pg_stat_statements` | > 50 filas |
| D7 | `pg_stat_statements` (SELECT en clientes/ventas, filas por ejecución) | > 1000 |

## Bot B0 (gerencia)

Polling a `getUpdates` cada 10 s → valida que el chat esté autorizado → **filtro anti SQL injection**
(`;`, `--`, comillas, `DROP`, `DELETE`, `UNION`, `SELECT`, …) → si se bloquea, registra el intento con
`registrar_evento()` (queda en `eventos_seguridad` y `auditoria_datos`) y responde "bloqueado" →
si no, ejecuta una consulta **fija** sobre las vistas `reporte_*` con `agente_ia` (solo lectura) y
resume con Groq (credencial cifrada `Nutri Groq`). Si Groq falla, responde con el error y los datos.

Limitación conocida: `getUpdates` requiere el token en la URL, así que ese nodo guarda el token dentro
de la base interna de n8n (esquema `n8n`, solo accesible para `n8n_app`). El JSON del repositorio usa el
marcador `__TELEGRAM_BOT_TOKEN__` y el script lo reemplaza desde `.env` al importar.

## Origen de cada parte

- R1–R3, R5, H2–H5: consultas del integrante 3 (rama `feature/integrante3-monitoreo`), corregidas
  (H4 asumía la red 172.18.0.0/16; H2 tenía hashes fijos de otra computadora).
- H1: lógica de hash UFW de `check-h1-ufw.sh` (integrante 3), integrada en el agente del host.
- D1–D7 y B0: consultas y bot del integrante 4 (rama `feature/integrante4-datos-ataques`; la punta de
  esa rama había vuelto a la versión antigua, se recuperaron los commits intermedios), corregidas.
- R4, filtro de A2, envío HTML, reintentos y marcado de entrega: integración final.

## Regenerar o modificar

Se puede editar un flujo en la interfaz de n8n, exportarlo y reemplazar el JSON. Antes de guardarlo en
el repositorio, devolver los marcadores (`__CRED_MONITOR__`, `__CRED_AGENTE__`, `__CRED_TELEGRAM__`,
`__CRED_GROQ__`, `__TELEGRAM_CHAT_ID__`, `__TELEGRAM_BOT_TOKEN__`, `__TELEGRAM_CHATS_PERMITIDOS__`) y
quitar datos personales del bloque `shared`. Luego `bash scripts/n8n-configurar.sh`.
