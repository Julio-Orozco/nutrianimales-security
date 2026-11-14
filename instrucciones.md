# SOLICITUD: FINALIZAR PARTES A Y B DEL PROYECTO NUTRIANIMALES

Necesito que actúes como un ingeniero especializado en Docker, PostgreSQL, seguridad informática, hardening, auditoría de bases de datos y documentación técnica.

Estoy desarrollando un proyecto universitario para el curso **Seguridad de Sistemas Digitales (BCD 9220)**, llamado **Sistema de Monitoreo Proactivo, Seguridad y Hardening de Base de Datos para NutriAnimales S.A.**

Mi responsabilidad corresponde únicamente a:

- **Parte A:** Infraestructura, Docker Compose y Hardening (20%).
- **Parte B:** Base de datos, configuración de auditoría y triggers (15%).

Necesito que revises, corrijas y completes absolutamente todo lo que corresponda a estas dos partes, tomando como referencia los siguientes archivos adjuntos:

1. `nutrianimales-security-main(1).zip`: código fuente y configuración del proyecto.
2. `Primer Proyecto de Investigación III Cuatri 2026(1).pdf`: instrucciones oficiales y rúbrica del profesor.
3. `Proyecto_Seguridad_NutriAnimales.pdf`: informe escrito actual, con avances y evidencias.

**OBJETIVO PRINCIPAL**

Quiero que las partes A y B queden completamente funcionales, seguras, documentadas y listas para evaluación y exposición, cumpliendo todos los requisitos del profesor.

No quiero comenzar el proyecto desde cero ni repetir procedimientos que ya funcionan.

Primero identificá lo que está correctamente implementado, conservá esos avances y corregí exclusivamente lo que esté incompleto, incorrecto o sin comprobar.

## 1. REVISIÓN INICIAL OBLIGATORIA

Antes de modificar cualquier archivo:

1. Descomprimí y analizá completamente el proyecto.
2. Revisá todos los archivos relacionados con Docker, PostgreSQL, Nginx, n8n, Filebeat, scripts SQL, certificados, variables de entorno y README.
3. Compará el código con los requisitos oficiales del profesor.
4. Compará los resultados contra el informe escrito.
5. Clasificá los requisitos como:
   - Completado y verificado.
   - Implementado, pero sin evidencia.
   - Parcialmente implementado.
   - Pendiente.
   - Incorrecto y requiere corrección.
6. Identificá configuraciones contradictorias, dependencias inexistentes, errores de despliegue y archivos faltantes.
7. No supongás que algo funciona solamente porque aparece configurado.

Mostrá un diagnóstico breve y comenzá inmediatamente las correcciones.

## 2. PARTE A — INFRAESTRUCTURA Y HARDENING

Verificá y completá los 12 controles obligatorios:

### A1. Usuario no-root

- Verificar los usuarios efectivos de n8n y pgAdmin.
- Revisar la ejecución de Filebeat y los demás contenedores.
- Eliminar privilegios innecesarios, sin impedir el funcionamiento de los servicios.
- Demostrar el resultado mediante comandos.

### A2. Protección del archivo .env

- Confirmar permisos equivalentes a chmod 600.
- Comprobar que `.env` está excluido de Git.
- Verificar que `.env.example` no contenga secretos reales.
- No imprimir contraseñas ni tokens en los resultados.

### A3. Red Docker aislada

- Verificar la red `nutrianimales-net`.
- Confirmar que los contenedores se comunican correctamente.
- Evitar exposiciones de red innecesarias.

### A4. PostgreSQL sin puerto público

- Confirmar que PostgreSQL no publica el puerto 5432 al host.
- Verificar los puertos de todos los servicios.
- Revisar si pgAdmin debe restringirse o dejar de publicar su puerto 5050.

### A5. Autenticación SCRAM-SHA-256

- Verificar la configuración de PostgreSQL.
- Comprobar que la autenticación efectiva sea SCRAM-SHA-256.
- Revisar `pg_hba.conf` y evitar mecanismos inseguros.

### A6. SSL/TLS en PostgreSQL

- Verificar que PostgreSQL cargue correctamente su configuración personalizada.
- Comprobar que SSL esté activado.
- Corregir referencias a certificados inexistentes.
- Comprobar una conexión cifrada funcional.
- No desactivar SSL para solucionar errores.

### A7. Usuario agente_ia de solo lectura

- Verificar que pueda consultar los datos autorizados.
- Comprobar que INSERT, UPDATE y DELETE sean rechazados.
- Conservar evidencias de los permisos y denegaciones.

### A8. Headers de seguridad Nginx

Comprobar los headers exigidos por el profesor:

- X-Frame-Options.
- Strict-Transport-Security.
- X-Content-Type-Options.
- Content-Security-Policy.

Demostrar su presencia mediante una solicitud HTTPS.

### A9. Certificado HTTPS

- Verificar el certificado utilizado por Nginx.
- Comprobar que HTTPS funciona.
- Validar la correspondencia con el nombre o dirección configurados.
- Documentar si es autofirmado y las limitaciones de confianza del navegador.

### A10. Permisos restringidos

- Revisar los directorios y volúmenes del proyecto.
- Aplicar permisos restrictivos donde corresponda.
- Evitar cambios que impidan a los contenedores acceder a sus datos.

### A11. Logs de auditoría y rendimiento

- Verificar `log_min_duration_statement`.
- Confirmar el funcionamiento de `pg_stat_statements`.
- Demostrar que una consulta lenta se registra.
- Evitar introducir cambios incompatibles con los flujos de monitoreo de otros integrantes.

### A12. pg_settings_baseline

- Verificar su existencia y contenido.
- Comprobar que los valores esperados correspondan a la configuración segura aprobada.
- Comparar los parámetros reales contra el baseline.
- Corregir cualquier desviación que represente una configuración insegura.
- Mantener compatibilidad con la alerta H5.

**ENTREGABLE OBLIGATORIO DE LA PARTE A**

Prepará una tabla con los 12 controles, su estado final, archivos modificados, comando de verificación, resultado esperado y evidencia correspondiente.

La guía exige 12 evidencias de hardening. Si tenés acceso al entorno, ejecutá las verificaciones y guardá capturas reales. Si no podés ejecutarlas, prepará los comandos exactos y marcá la evidencia como pendiente; nunca inventés resultados.

## 3. PARTE B — BASE DE DATOS Y AUDITORÍA

Esta sección ya tiene avances importantes. No quiero que destruyás ni reconstruyás innecesariamente lo que funciona.

### B1. Estructura de la base de datos

- Revisar el esquema completo.
- Confirmar todas las tablas obligatorias.
- Validar claves primarias, foráneas y restricciones.
- Conservar las tablas adicionales que ya funcionan.
- Verificar que los scripts puedan reproducirse en una instalación nueva.

### B2. Datos de prueba

Comprobar los registros existentes:

| Tabla | Cantidad esperada en el proyecto actual |
|---|---:|
| plantas | 3 |
| productos | 50 |
| materias_primas | 100 |
| lotes_produccion | 500 |
| clientes | 1.500 |
| ventas | 1.500 |
| control_calidad | 300 |
| gastos | 200 |

Confirmar los conteos mediante consultas reales.

No duplicar los datos si ya están cargados.

### B3. Auditoría

- Verificar la tabla `auditoria_datos`.
- Verificar la función `fn_auditoria()`.
- Confirmar el almacenamiento del usuario, fecha, operación, tabla, fila afectada, valores anteriores y posteriores.
- Revisar los índices.
- Confirmar que la función no falla al recibir INSERT, UPDATE o DELETE.

### B4. Triggers obligatorios

Comprobar que funcionan los triggers de las cuatro tablas críticas:

- productos.
- lotes_produccion.
- ventas.
- clientes.

El proyecto ya contiene triggers adicionales por sentencia. Conservarlos si funcionan correctamente.

No recrear triggers que ya existen.

### B5. Demostración UPDATE

- Verificar la prueba existente.
- Comprobar que el valor anterior y posterior quedan registrados correctamente.
- Confirmar que la captura del informe corresponde a una ejecución real.

### B6. Demostración DELETE — PRIORIDAD ALTA

Esta es una de las evidencias que falta completar.

Necesito que:

1. Seleccionés un registro de prueba seguro.
2. Mostrés su estado antes de la eliminación.
3. Ejecutés un DELETE controlado.
4. Consultés `auditoria_datos`.
5. Demostrés que se registra correctamente:
   - Tabla afectada.
   - Operación DELETE.
   - Usuario.
   - Fecha.
   - Identificador del registro.
   - Valor anterior.
   - Valor posterior NULL.
6. Confirmés que el trigger funcionó.
7. Preparés la evidencia para el informe.

Utilizá una transacción o datos de prueba aislados para evitar pérdidas de información y alteraciones de registros importantes.

### B7. Baseline de configuración

- Comprobar los siete parámetros documentados.
- Validar que SSL esté activado.
- Confirmar el registro de conexiones y consultas lentas.
- Verificar que no existan diferencias injustificadas entre el baseline y la configuración actual.

**ENTREGABLE OBLIGATORIO DE LA PARTE B**

Necesito evidencia real de las tablas, conteos, función de auditoría, triggers, UPDATE, DELETE y baseline.

Incluí los resultados esperados y los resultados efectivamente obtenidos.

## 4. CORREGIR EL ZIP, COMPOSE Y README

En una revisión anterior se identificaron posibles inconsistencias:

- El README menciona `scripts/lab.py`, pero ese archivo no aparece en el ZIP revisado.
- Docker Compose referencia certificados de PostgreSQL cuya ubicación debe verificarse.
- El README describe servicios o configuraciones que no coinciden completamente con el Compose.
- pgAdmin publica el puerto 5050.
- Filebeat aparece ejecutándose como root.
- La carpeta de evidencias no contiene todas las capturas finales.

Comprobá cada hallazgo directamente en los archivos.

Corregí únicamente los problemas confirmados.

El objetivo es que una persona pueda descargar el proyecto, seguir las instrucciones del README y desplegarlo correctamente.

No inventés dependencias ni eliminés servicios que necesitan los demás integrantes.

No incluyás secretos reales, certificados privados de producción ni archivos sensibles en la entrega.

## 5. ACTUALIZACIÓN DEL INFORME ESCRITO

Tomá el PDF `Proyecto_Seguridad_NutriAnimales.pdf` como base.

Necesito que actualicés únicamente las secciones relacionadas con mis responsabilidades:

- A.1 Organización del entorno.
- A.2 Inicio de los servicios.
- A.3 Verificación del estado de los contenedores.
- A.4 Configuración de seguridad del entorno.
- B.1 Estructura de la base de datos.
- B.2 Preparación de datos de prueba.
- B.3 Registro de modificaciones.
- B.4 Configuración y verificación de triggers.
- B.5 Configuración de referencia.

Conservá las explicaciones correctas y las evidencias válidas.

Corregí afirmaciones desactualizadas o contradictorias.

Añadí la documentación de DELETE y las verificaciones faltantes de hardening.

Usá un lenguaje académico, claro, natural y acorde con el estilo del documento original.

No modifiqués las responsabilidades de los otros integrantes.

Entregá la versión actualizada en Word o PDF, si tenés capacidad para generar esos archivos. Si no, proporcioná las secciones completas listas para copiar al documento.

No presentés pruebas pendientes como pruebas exitosas.

## 6. PROTEGER EL TRABAJO DE LOS OTROS INTEGRANTES

El proyecto también incluye n8n, Telegram, alertas de rendimiento, hardening, alertas de datos, escenarios de ataque, RBAC y gestión de secretos.

No quiero que los cambios en A y B afecten negativamente estas funcionalidades.

Antes de modificar archivos compartidos:

- Revisá las dependencias.
- Conservá las interfaces y configuraciones necesarias.
- Evitá cambiar nombres de tablas, servicios y variables sin necesidad.
- No eliminés flujos existentes.
- Verificá que los cambios sean compatibles con la integración final.

Si encontrás errores que corresponden a C, D o E, reportalos por separado, pero no asumás esas responsabilidades ni las reimplementés sin necesidad.

## 7. FORMATO DE ENTREGA QUE NECESITO

Al finalizar, entregame:

1. **Proyecto corregido:** ZIP completo, organizado y listo para ejecutar.
2. **README actualizado:** instrucciones paso a paso desde cero.
3. **Informe actualizado:** secciones A y B corregidas.
4. **Evidencias:** capturas reales y comandos utilizados.
5. **Resumen de cambios:** qué archivos modificaste y por qué.
6. **Matriz de cumplimiento:** todos los requisitos A y B, con estado y evidencia.
7. **Guía para la exposición:** comandos y explicaciones sencillas para demostrar que las dos partes funcionan.
8. **Pendientes reales:** exclusivamente aquello que no se pudo ejecutar o verificar.

## 8. REGLAS IMPORTANTES

- No empecés desde cero.
- No repitás procedimientos ya completados correctamente.
- No borres datos ni configuraciones funcionales.
- No realicés operaciones destructivas sin un mecanismo seguro de recuperación.
- No cambies las responsabilidades de otros integrantes.
- No inventés capturas, resultados ni ejecuciones.
- No confundás código existente con funcionalidad comprobada.
- No dejés instrucciones genéricas como "revisar configuración" sin explicar exactamente qué revisar.
- No me entregués únicamente recomendaciones: **realizá las modificaciones directamente sobre los archivos cuando tu entorno lo permita**.
- Priorizá los requisitos obligatorios del profesor sobre mejoras opcionales.
- Conservá la estructura y los nombres del proyecto siempre que sea posible.
- Si algo no se puede verificar por limitaciones del entorno, indicalo claramente y proporcioná el comando exacto para verificarlo.
- No afirmés que está 100% terminado si queda alguna prueba obligatoria pendiente.

## 9. ORDEN DE EJECUCIÓN

Trabajá en este orden:

1. Analizar los tres archivos.
2. Detectar problemas reales y diferencias.
3. Corregir las inconsistencias de Docker Compose, scripts, certificados y README.
4. Comprobar los 12 controles de hardening.
5. Validar las tablas, datos y auditoría existentes.
6. Completar la demostración DELETE.
7. Ejecutar pruebas de integración y comprobar que los servicios siguen funcionando.
8. Actualizar el informe escrito.
9. Organizar evidencias.
10. Preparar el ZIP final y el resumen de cumplimiento.

**RESULTADO ESPERADO**

Quiero que mis partes A y B queden terminadas, con sus requisitos implementados, pruebas realizadas, evidencias documentadas y archivos finales consistentes.

Necesito que el trabajo esté alineado con la guía oficial, que sea reproducible, que no afecte a mis compañeros y que pueda demostrarlo durante la exposición.

Comenzá el análisis y realizá las correcciones disponibles de principio a fin, sin detenerte a pedir confirmaciones innecesarias. Si una limitación impide una prueba, continuá con las demás tareas y reportá claramente lo pendiente al finalizar.