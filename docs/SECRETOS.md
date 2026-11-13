# Secretos, rotación y recuperación

Los valores reales solo viven en `.env`, credenciales cifradas de n8n y runtime privado. No publicar .env, claves TLS, dumps, IDs internos con tokens, logs sensibles ni capturas de campos de credenciales. `.env.example` contiene nombres y valores vacíos/de ejemplo, nunca secretos válidos.

| Secreto | Consumidor | Rotación propuesta | Acción efectiva |
|---|---|---|---|
| Token Telegram | Monitor | Ante incidente | BotFather /revoke sobre bot propio; configurar nuevo token y recrear monitor |
| API key Groq | Monitor | 90 días o incidente | Revocar en proveedor, crear otra, configure y recrear monitor |
| Clave monitor API | n8n/host-agent/CLI | Incidente o cambio de equipo | Cambiar .env y actualizar credencial HTTP en n8n; recrear monitor y reiniciar agente |
| Clave auditor API | Panel de lectura | Incidente/cambio de auditor | Cambiar .env, recrear monitor y entregar nueva clave por canal privado |
| Contraseñas BD | Cada cuenta individual | 180 días o incidente | ALTER ROLE en la BD existente + actualizar configuración de consumidores. Cambiar solo .env no cambia una BD inicializada |
| N8N_ENCRYPTION_KEY | n8n | Recuperación planificada | Respaldar de forma privada; cambiarla sin migrar credenciales puede volverlas ilegibles |
| Clave del propietario n8n | n8n | Política de cuenta | Se administra desde n8n; no se simula con una antigua variable N8N_PASSWORD |
| Clave pgAdmin | pgAdmin | 90 días o incidente | Cambiar la cuenta existente desde la herramienta; variables de primer arranque no sustituyen esa operación |
| CA/key servidor | Nginx/PostgreSQL | Certificado servidor30d; incidente | Renovación planificada y distribución de CA si cambia. No borrar una CA vigente sin actualizar clientes |

## Demo obligatoria de revocación Groq

1. Con clave propia válida y modelo disponible, ejecutar `python3 scripts/lab.py groq-probe`. Guardar HTTP/resultado real sin mostrar la clave.
2. Desde la cuenta del integrante, revocar **esa clave del laboratorio** en Groq. No publicar ni «filtrar» el token en el repositorio para simular el incidente.
3. Repetir el mismo comando: debe aparecer un fallo real del proveedor, normalmente HTTP401. Un HTTP429 es límite de uso, no demuestra revocación; un HTTP400 puede ser modelo inválido. Registrar lo que ocurra realmente.
4. Crear una clave nueva y ejecutar `python3 scripts/lab.py configure`, ingresando únicamente el valor que cambia y conservando el resto.
5. Ejecutar `docker compose up -d --no-deps --force-recreate monitor`. Los flujos n8n siguen invocando el mismo servicio y credencial interna; no hace falta reiniciar la BD.
6. Repetir groq-probe y enviar `/ia ventas` al bot. Guardar recuperación real y evento API_OK. Si falta crédito/modelo o Internet, informarlo; no generar una respuesta de éxito falsa.

En esta arquitectura Groq vive en monitor, no en una variable accesible al nodo. Esto cumple el propósito de aislar el secreto y permite documentar exactamente qué consumidor se recrea. Si el profesor exige almacenar Groq directamente como credencial nativa n8n, adaptar ese punto explícitamente; no afirmar que ya está allí.

## Respaldo fuera del contenedor

Los dumps quedan en `.runtime/backups` del Ubuntu anfitrión. Eso resiste la eliminación de un contenedor, **pero no la pérdida de la misma máquina o disco**. Copiar un backup verificado a almacenamiento privado externo y ensayar su devolución. El proyecto no sube copias a servicios externos automáticamente.

Para recuperación completa también se necesita metadata/credenciales de n8n, encryption key, cuentas/roles/ACL, archivos de configuración y certificados. `restore-test` comprueba una base separada a partir del dump, no un desastre completo del servidor. Los conteos se reportan para revisión; un dump restaurable con datos eliminados sigue siendo restaurable, pero puede no cumplir las necesidades del negocio.
