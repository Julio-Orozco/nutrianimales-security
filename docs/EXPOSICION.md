# Exposición de 15 minutos

Guion propuesto, no evidencia de ensayo. Las demos de monitor, Telegram, ataques, backups y scripts referenciados no son ejecutables con el checkout actual; sustituirlas por resultados reales solo después de recibir esos componentes y probarlos.

## Demostración A/B comprobada

1. **Puertos y servicios:** `docker compose ps`. Explicar que solo Nginx publica `127.0.0.1:8080/8443`; PostgreSQL y pgAdmin no tienen puerto host.
2. **Usuarios:** `docker compose exec -T n8n id`, repetir con `nginx`, `pgadmin` y `filebeat`; para el servidor: `docker compose exec -T postgres sh -c 'ps -eo uid,user,args | grep "[p]ostgres" | head -n 1'`. Explicar los UID efectivos.
3. **HTTPS:** `curl --fail --cacert infra/certs/server.crt -I https://localhost:8443/auditoria.html`. Señalar los cuatro headers. El certificado es autofirmado; el navegador puede advertir hasta confiar en él.
4. **Base y baseline:** ejecutar los conteos de `docs/COMANDOS.md` y comparar `pg_settings_baseline` con `pg_settings`. Explicar que se compararon siete parámetros.
5. **UPDATE/DELETE:** `docker compose exec -T postgres psql -X -U postgres -d nutrianimales < db/demo-audit.sql`. Mostrar el antes/después, el usuario y el DELETE con valor posterior nulo; explicar que se borra solamente la fila de prueba.
6. **Limitación honesta:** en esta sesión pgAdmin abre por el proxy, pero n8n devuelve 502, Filebeat no tiene una fuente UFW real y no se probaron Telegram/alertas. Mostrar solo lo que esté disponible al repetir la demo.

| Tiempo | Responsable | Qué mostrar y explicar |
|---|---|---|
| 0:00–2:30 | 1 | Problema NutriAnimales, arquitectura, solo Nginx publicado y TLS. Explicar redes Docker privadas y acceso local |
| 2:30–5:00 | 2 | Roles, acceso gerente denegado y UPDATE con antes/después. No atribuir current_user del definer al usuario original |
| 5:00–8:00 | 3 | Flujos n8n y una alerta de hardening real, preferiblemente GRANT/H3 con reversión. Mostrar que otras reglas ya tienen evidencias |
| 8:00–11:00 | 4 | Bot autorizado, mensaje SQL bloqueado y revocación/recuperación Groq con tiempos ensayados |
| 11:00–15:00 | 5 | Resumen de cinco ataques, mediciones, backup/restauración y límites. Mostrar tabla de resultados reales |

## Frases útiles

«La empresa es ficticia y los datos se generaron para repetir las pruebas sin usar información personal.»

«n8n agenda cada detector; el monitor consulta estadísticas/logs reales y conserva la alerta antes de enviarla. Esto permite distinguir detectar, enviar y responder.»

«La IA no ejecuta SQL libre. Solo resume reportes cuya consulta y permisos ya están definidos.»

«D7 indica posible exfiltración por volumen, no prueba la intención de la persona. La revisión del contexto es parte de la respuesta.»

«La copia se restauró en otra base y consultamos los datos; no afirmamos haber recuperado toda la infraestructura si solo ensayamos la BD.»

## Preparación de la demo

Probar Internet, credenciales, modelo Groq y chats autorizados. Descargar/construir imágenes antes de clase. Ensayar revocación con una clave exclusiva y no mostrarla en proyección. Mantener la terminal del agente UFW activa. Tener capturas propias por si falla la red; eso no sustituye silenciosamente la demo en vivo exigida. Medir el ensayo completo, no asumir que cabe en quince minutos.
