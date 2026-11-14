# Arquitectura y decisiones

| Componente | Función | Por qué se eligió | Límite |
|---|---|---|---|
| PostgreSQL 16 | Datos, roles, auditoría y baseline | Controles aplicados en la base; el proceso servidor corre como `postgres` | El superusuario puede alterar auditoría; no es almacenamiento inmutable externo |
| n8n | Contenedor presente en Compose | Los JSON de flujos están en el repositorio y no contienen secretos | En esta prueba no abrió 5678 (502 por Nginx); los flujos no se importan automáticamente y falta `monitor` |
| Nginx | Único punto web publicado | TLS y cabeceras en un lugar | CSP permite scripts inline por compatibilidad con n8n; mejorable con una política específica validada |
| pgAdmin | Administración gráfica | Se sirve detrás de Nginx por HTTPS | UID no privilegiado del Compose; no tiene puerto host propio |
| Filebeat | Lectura opcional de logs UFW | Se ejecuta como usuario no-root | Su salida configurada es consola; no hay servicio Logstash/Loki en este checkout |

## Redes y conexiones

Compose crea una red bridge por proyecto llamada `<proyecto>_nutrianimales-net`. La subred se asigna dinámicamente; la regla HBA usa `samenet` en vez de asumir un rango fijo. Los servicios pueden comunicarse entre sí y acceder a Internet cuando la aplicación lo requiere; no es una red marcada Docker `internal`. Solo Nginx publica puertos, ligados a loopback. `docker compose ps` puede mostrar `5432/tcp` por metadata de imagen sin publicar el puerto al host.

## Telegram y Groq

Este checkout no contiene el servicio `monitor` ni su integración de Telegram/Groq. Los flujos JSON y la documentación describen el diseño previsto; no están importados ni se presentan como funcionalidad probada. Tampoco se validaron credenciales externas.

La configuración actual contiene Filebeat, pero no Logstash ni Loki. No se debe presentar una canalización de logs integrada como funcional.

## Persistencia y reinicio

Volúmenes nombrados: datos PostgreSQL y datos n8n. Las claves, certificados y `.env` se mantienen en archivos locales ignorados por Git. No se incluye un servicio de backup en este checkout.

## Cambios respecto de la guía

Los flujos JSON describen propuestas de detectores, no acreditan alertas ejecutadas. Sin el servicio `monitor` ni el PDF de la rúbrica en el checkout, no es posible validar su extremo a extremo ni afirmar que coincide con los requisitos oficiales.
