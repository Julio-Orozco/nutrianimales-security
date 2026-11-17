# Secretos, rotación y revocación

Todos los secretos viven en `.env` (permiso `600`, en `.gitignore`, nunca versionado). `.env.example`
solo tiene nombres de variables sin valores. Los que usa n8n se cargan en **credenciales cifradas** de
n8n (`N8N_ENCRYPTION_KEY`) con `bash scripts/n8n-configurar.sh`; no se pasan como variables de entorno
al contenedor de n8n y `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` impide leer `$env` desde los nodos.
`N8N_LOG_LEVEL=info`: los logs no registran variables (comprobado con `bash scripts/pruebas-seguridad.sh`).

## Inventario y política de rotación

| Secreto | Dónde vive | Rotación | Procedimiento |
|---|---|---|---|
| `GROQ_API_KEY` | `.env` + credencial n8n `Nutri Groq` | 90 días o si se filtra | console.groq.com → API Keys → Delete → crear nueva → `.env` → `bash scripts/n8n-configurar.sh --credenciales` → `docker compose restart n8n` |
| `TELEGRAM_BOT_TOKEN` | `.env` + credencial `Nutri Telegram bot` + nodo `getUpdates` de B0 (BD interna de n8n) | si se compromete | @BotFather → `/revoke` → nuevo token → `.env` → `bash scripts/n8n-configurar.sh` (completo: actualiza también B0) |
| `POSTGRES_PASSWORD` | `.env` | 6 meses | `ALTER USER postgres WITH PASSWORD '…';` → `.env` → `docker compose restart` |
| `AGENTE_IA_PASSWORD` | `.env` + credencial `Nutri Postgres agente_ia` | 6 meses o tras A5 | `ALTER USER agente_ia WITH PASSWORD '…';` → `.env` → `bash scripts/n8n-configurar.sh --credenciales` |
| `MONITOR_PASSWORD` | `.env` + credencial `Nutri Postgres monitor_db` + agente del host | 6 meses | `ALTER USER monitor_db …` → `.env` → `--credenciales` → reiniciar el agente |
| `N8N_DB_PASSWORD` | `.env` (cuenta `n8n_app`) | 6 meses | `ALTER USER n8n_app …` → `.env` → `docker compose up -d n8n` |
| `N8N_OWNER_PASSWORD` | `.env` + cuenta propietaria n8n | 90 días | cambiar en n8n (Settings → Personal) → `.env` |
| `N8N_ENCRYPTION_KEY` | `.env` + `n8n_data` | no rotar sin migración | cambiarla deja ilegibles las credenciales: exportar/reimportar |
| `GERENTE/TI/AUDITOR/BACKUP_PASSWORD` | `.env` | 6 meses | `ALTER USER … WITH PASSWORD` → `.env` |

Las sentencias `ALTER USER … PASSWORD` se ejecutan con `SET log_statement='none';` antes, para que la
contraseña no quede en el log de PostgreSQL.

## Reglas

- `.env` nunca se sube a GitHub; si un secreto se filtra en un commit, se **revoca** aunque el commit se revierta.
- Ningún nodo de n8n contiene la API key de Groq: el nodo HTTP usa la credencial `groqApi`.
- `.env.example` se entrega sin valores reales.

## Demostración obligatoria (revocación de la API key de Groq)

Ver la sección 7 de [GUIA_DEMO_EN_VIVO.md](GUIA_DEMO_EN_VIVO.md): con la key revocada, el bot responde
el error de autenticación de Groq; tras actualizar `.env` y ejecutar
`bash scripts/n8n-configurar.sh --credenciales`, vuelve a responder.
