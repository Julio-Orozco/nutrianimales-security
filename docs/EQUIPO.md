# Trabajo entre cinco

Una computadora principal, otra preparada para contingencia. Un repositorio compartido privado; un responsable integra cambios. El equipo no necesita cinco conexiones remotas para cumplir el documento. Compartir pantalla sirve para observar, pero cada persona debe aportar y comprender su parte.

| Integrante | Responsabilidad | Entregable concreto | Dependencia |
|---|---|---|---|
| 1 | Infraestructura e integración | Arranque, TLS, redes, permisos, logs y hardening | Acordar nombres/puertos al inicio |
| 2 | BD y auditoría | SQL, datos, roles, denegaciones y triggers | Base lista para quienes hacen alertas |
| 3 | Monitoreo | R1–R5/H1–H5, agente Ubuntu y evidencia | Requiere stack y configuración estable |
| 4 | Bot/datos | D1–D7, Telegram/Groq y rotación | Requiere tablas y claves privadas propias |
| 5 | QA y documentación | Cinco ataques coordinados, matriz, informe, ZIP y ensayo | Cada responsable entrega sus capturas y explicación |

Prioridad: una cadena completa desde acción real hasta Telegram, luego completar las diecisiete. No trabajar hasta el domingo en piezas que nadie haya integrado. No dejar todas las capturas o todo el informe a una persona al final.

Hasta el lunes16: jueves base y conexión Telegram/Groq; viernes detectores integrados; sábado escenarios y evidencias; domingo informe, segunda instalación y ensayo; lunes solo correcciones pequeñas. Si ya existen avances, revisar y reutilizar únicamente lo comprobado.

Los cinco deben poder explicar: cuál fue el origen observado, qué permiso limita una acción, cómo se disparó su regla, qué evidencia la prueba y qué limitación conserva.
