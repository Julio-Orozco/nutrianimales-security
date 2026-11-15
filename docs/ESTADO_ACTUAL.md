# Estado verificado de A y B

Actualizado el 14 de noviembre de 2026 (revisión 2) con el Docker Engine disponible en este entorno. Los datos del proyecto son ficticios.

## Comprobado en ejecución

- Los cinco contenedores definidos en el Compose quedan en ejecución en este entorno: PostgreSQL 16, n8n, Nginx, pgAdmin y Filebeat.
- n8n 2.30.8 escucha en 5678, `https://localhost:8443/` devuelve HTTP 200 con su interfaz y el WebSocket funciona por Nginx. Usa la cuenta dedicada `n8n_app` (dueña solo del esquema `n8n`) por TLS 1.3 verificado; sus migraciones crearon las tablas internas. La causa del 502 anterior y su corrección están en `docs/ENTREGA_REVISION2.md`.
- La base tiene 14 tablas: ocho empresariales y seis auxiliares. Los ocho conteos requeridos coinciden.
- Los siete parámetros de `pg_settings_baseline` coinciden con `pg_settings`.
- `agente_ia` pudo hacer SELECT por TLS verificado; INSERT, UPDATE y DELETE se rechazaron por `default_transaction_read_only`; no tiene grants de escritura.
- La auditoría registró un UPDATE y un DELETE reales sobre una fila ficticia, con la fila eliminada y su JSON anterior registrado.
- Los 20 triggers (cinco por cada una de las cuatro tablas críticas) y `fn_auditoria()` se encuentran en la base.
- Se generó un registro de consulta lenta de `pg_sleep` y se observó en `pg_stat_statements`.
- Nginx sirve HTTPS con headers de seguridad; pgAdmin se accede por el proxy, redirige al formulario y no publica su propio puerto.

Los comandos y resultados acotados se documentan en `evidencias/RESULTADOS_AB.md`. Ejecutar esos comandos en otra computadora es necesario para acreditar allí la instalación.

## Implementado, pero requiere validación en el equipo de entrega

- La red de Compose es un bridge aislado por proyecto con comunicación interna; puede tener salida a Internet y no se presenta como red Docker `internal`.
- El certificado Nginx es autofirmado para localhost; su confianza es local, no pública.
- Filebeat corre como UID no privilegiado, pero en este entorno no existe un archivo de log UFW funcional que pueda probarse: `/var/log/ufw.log` del host es un directorio vacío creado por Docker. La salida actual es consola; Logstash/Loki no están incluidos.
- No se generaron capturas de pantalla. La evidencia disponible son las salidas reales de comandos indicadas.

## Faltantes del material recibido

El checkout no contiene el PDF/Word original del informe, la guía/rúbrica oficial, los scripts `lab.py` y `host_agent.py`, ni los servicios `monitor`, Logstash y Loki. Tampoco contiene pruebas de aceptación externas. No se declaran completos Telegram, alertas, escenarios de otras partes ni backups. El PDF base debe adjuntarse para integrar estas secciones en su formato original.
