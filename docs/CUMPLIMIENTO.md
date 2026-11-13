# Matriz de requisitos y evidencia pendiente

«Implementado» significa que hay código/configuración, no que el grupo haya ejecutado el ensayo. Marcar aprobado únicamente con evidencia de su propia instalación. Fecha de preparación: 12 de noviembre de 2026.

## Doce puntos de hardening

| # | Implementación | Cómo demostrarla | Estado de evidencia del grupo |
|---|---|---|---|
| 1 | n8n UID1000 y pgAdmin UID5050 | compose y proceso efectivo/UID. UID5050 es el usuario real de pgAdmin, no se fuerza 1000 sin considerar su imagen | Pendiente |
| 2 | .env generado 600, ignorado por Git | `ls -l .env`; no abrir su contenido en capturas | Pendiente |
| 3 | Red datos interna con CIDR definido | docker network inspect sobre el nombre real creado por Compose | Pendiente |
| 4 | PostgreSQL sin ports | compose ps + inspección de PortBindings | Pendiente |
| 5 | SCRAM en init, configuración y HBA | SHOW password_encryption; reglas HBA; conexión rechazada con clave falsa | Pendiente |
| 6 | TLS PostgreSQL con verify-full en clientes | SHOW ssl; pg_stat_ssl; configuración cliente y rechazo sin TLS | Pendiente |
| 7 | agente_ia SELECT, límites y READ ONLY | Conexión auténtica del agente: INSERT denegado; verificar ACL además del valor readonly | Pendiente |
| 8 | Cabeceras Nginx | curl HEAD con --cacert, sin -k | Pendiente |
| 9 | CA local y certificado SAN 30 días | Cadena verificada. Navegador solo confía después de importar CA | Pendiente |
| 10 | Datos PostgreSQL, n8n/pgAdmin y backups con permisos restringidos | Revisar directorios 700 y .env600. El inicializador de volúmenes es root breve, aplicaciones no | Pendiente |
| 11 | JSON/CSV, conexiones, duración y pg_stat_statements | Consulta lenta, vista de estadísticas y pgBadger real | Pendiente |
| 12 | pg_settings_baseline | SELECT baseline y ensayo R5/H5 | Pendiente |

Comandos de solo lectura adicionales están explicados en [EVIDENCIAS](EVIDENCIAS.md). No se confunde un listado de archivos con una prueba de que todos los permisos son correctos.

## Resto del alcance

| Requisito | Archivos/solución | Situación |
|---|---|---|
| Cinco riesgos CIA | RIESGOS.md | Matriz con productos y niveles consistentes |
| Tres roles SQL | db/sql/01-roles.sql y 05-access.sql | Implementado; pruebas SQL verifican permisos |
| Viewer de solo lectura en n8n | Función nativa de la edición correspondiente | **Pendiente de licencia o acuerdo docente. No cubierto por Community ni por un simple usuario adicional** |
| Alternativa de auditoría | /auditoria.html + clave auditor solo GET | Implementado. No se presenta como Viewer nativo |
| Triggers en cuatro tablas | db/sql/04-audit.sql | Implementado y probado parcialmente en PostgreSQL16 standalone |
| 17 alertas n8n/Telegram | app/checks.py + 17 JSON | Implementado; pruebas reales de despliegue y Telegram pendientes |
| Cinco ataques | scripts/lab.py, qa.py, ESCENARIOS.md | Automatizados o guiados según acción; ejecución del grupo pendiente |
| Rotación API key Groq | configure + groq-probe + SECRETOS.md | Procedimiento real; revocación requiere cuenta del integrante |
| Filebeat + Loki | compose.logging.yaml y Logstash puente | Configuración incluida; construir y comprobar perfil completo en su Ubuntu |
| pgbench/pgBadger | Perfil qa, comandos documentados | Herramientas incluidas; resultados deben medirse |
| Backups y restauración | backup.sh y restore-test | Código incluido; ensayo completo Docker pendiente |
| README para arrancar <5min | Arranque único con healthchecks | Objetivo de medición, no tiempo garantizado. Registrar caché, hardware y tiempo real |
| Informe15–20 páginas | INFORME.md | Estructura para completar; no un informe de resultados inexistentes |
| Exposición15min y cinco integrantes | EXPOSICION.md | Guion y reparto propuestos; ensayo pendiente |

## Decisiones que conviene validar con el profesor

1. ¿Se acepta auditor SQL + panel alternativo de solo lectura cuando no hay licencia Viewer nativa de n8n?
2. ¿R4 debe acreditar ambos logs, dado que A1 es SSH y el catálogo original menciona PostgreSQL?
3. ¿El objetivo de arranque de cinco minutos se mide con Docker y las imágenes ya instalados?
4. ¿Se acepta la cadena Filebeat → Logstash → Loki? Filebeat no dispone de salida Loki nativa.

Resolver estas preguntas no impide avanzar con el resto. No modificar el alcance ni marcarlo aprobado en nombre del profesor.
