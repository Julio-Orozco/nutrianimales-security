# Exposición de 15 minutos

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
