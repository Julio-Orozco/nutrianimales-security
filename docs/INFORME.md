# Secciones A y B — NutriAnimales S.A.

Texto actualizado para integrar en el informe escrito. El PDF/Word original no está en el espacio de trabajo, por lo que se conservan aquí las secciones solicitadas sin alterar el documento completo del equipo. Los resultados descritos corresponden a la ejecución Docker registrada el 14 de noviembre de 2026, incluida la revisión posterior que corrigió el arranque de n8n; `evidencias/RESULTADOS_AB.md` contiene comandos y resultados verificables. No sustituir el informe original ni presentar esta fecha como una prueba en otra computadora.

## A. Infraestructura y hardening

### A.1 Organización del entorno

La infraestructura se define en `compose.yaml` y usa una red bridge por proyecto denominada `<proyecto>_nutrianimales-net`. Los cinco servicios de este checkout son PostgreSQL 16, n8n, Nginx, pgAdmin y Filebeat. La subred la asigna Docker; por eso `pg_hba.conf` emplea `samenet` en vez de asumir una dirección fija. La red permite la comunicación entre contenedores, pero no se presenta como una red Docker `internal`.

Las credenciales no se escriben en el Compose ni en el repositorio. `scripts/prepare-ab.sh` genera un `.env` local con valores aleatorios si el archivo no existe y limita sus permisos a `600`. `.env.example` no proporciona contraseñas predeterminadas. Las claves TLS son locales, están excluidas de Git y se protegen con permisos restringidos.

### A.2 Inicio de los servicios

Desde Ubuntu/Linux, en la carpeta raíz del proyecto:

```bash
bash scripts/prepare-ab.sh
docker compose config --quiet
docker compose up -d --wait
docker compose ps
```

La configuración inicial de la base se ejecuta únicamente cuando el volumen PostgreSQL está vacío. Los reinicios conservan los datos. No se publica PostgreSQL ni pgAdmin directamente en el host; la interfaz web se entrega por Nginx.

### A.3 Verificación del estado de los contenedores

Los cinco contenedores aparecen en `docker compose ps`. El proceso servidor PostgreSQL opera con el usuario `postgres`; n8n, Nginx, pgAdmin y Filebeat usan UID no privilegiado. Los únicos puertos publicados son `127.0.0.1:8080` y `127.0.0.1:8443`, ambos de Nginx. pgAdmin se comunica por la red de Compose y el proxy usa el puerto interno 80. Tras la corrección descrita en la sección A.5, n8n 2.30.8 escucha en el puerto interno 5678 y Nginx entrega su interfaz en `https://localhost:8443/` con respuesta HTTP 200, incluido el canal WebSocket que usa el editor.

Estos resultados describen la instancia comprobada; deben repetirse en la computadora de exposición. La existencia de un servicio en Compose no demuestra que componentes ausentes —por ejemplo, monitor, Logstash o Loki— estén desplegados.

### A.4 Configuración de seguridad del entorno

PostgreSQL escucha en el puerto 5432 solo dentro de la red de contenedores. Las reglas de host exigen TLS y SCRAM-SHA-256; el resto de conexiones de red se rechaza. La conexión de agente_ia se probó con `sslmode=verify-full` y devolvió TLS 1.3. El certificado de laboratorio es autofirmado y contiene SAN para `postgres` y los nombres locales correspondientes. El certificado Nginx contiene SAN para `localhost` y `127.0.0.1`; la confianza externa no se presume.

Nginx responde con X-Frame-Options, Strict-Transport-Security, X-Content-Type-Options y Content-Security-Policy. Filebeat se configura como usuario no-root; la lectura de UFW depende de que Ubuntu tenga un archivo de log accesible al grupo autorizado. En esta instancia no se comprobó una fuente UFW real, y la configuración actual envía los eventos de Filebeat a consola, no a Loki.

La evidencia de los 12 controles, con su comando, estado y limitaciones, se encuentra en `docs/CUMPLIMIENTO.md`. La verificación de consultas lentas produjo un registro de `pg_sleep` con duración superior a un segundo, y `pg_stat_statements` mostró la consulta.

En cuanto a permisos de archivos y volúmenes, `.env` y las claves privadas tienen modo 600, el directorio de datos de PostgreSQL tiene modo 700 y ninguno de sus archivos es accesible para grupo u otros usuarios. Durante la revisión se detectó que los registros de PostgreSQL se generaban con modo 644, en un directorio con modo 755, y quedaban legibles para cualquier usuario del sistema anfitrión, a pesar de contener conexiones y sentencias DDL. Se corrigió `log_file_mode` a `0600` y el directorio pasó a 700. De la misma manera, el volumen de n8n pasó de 755 a 700; su archivo de configuración, que contiene la clave de cifrado, ya tenía modo 600. Los archivos de configuración y los certificados se montan en solo lectura.

### A.5 Problemas encontrados y soluciones aplicadas

**n8n respondía 502.** Los cinco contenedores figuraban en ejecución, pero Nginx devolvía 502 porque n8n no escuchaba en el puerto 5678. Los registros de PostgreSQL mostraron la causa: al conectarse, n8n (mediante TypeORM) ejecuta siempre `CREATE SCHEMA IF NOT EXISTS "n8n"`, y PostgreSQL exige el privilegio `CREATE` sobre la base de datos antes de comprobar si el esquema ya existe. La cuenta utilizada, `monitor_db`, no tenía ese privilegio y recibía `permission denied for database nutrianimales`. n8n no abortaba ante el error, por lo que quedaba bloqueado con una sesión inactiva, sin abrir el puerto. Los mensajes `Last session crashed` y `removeAllQueuedWorkflowActivations` eran consecuencias de ese arranque incompleto, no su causa.

Además, utilizar `monitor_db` para administrar tablas contradecía el principio de mínimo privilegio, porque se trata de una cuenta de monitoreo. Se creó la cuenta dedicada `n8n_app`, que es dueña únicamente del esquema `n8n` y tiene `CONNECT` y `CREATE` sobre la base. Este último privilegio es imprescindible para la sentencia de TypeORM y se documenta como riesgo residual: permite crear esquemas, pero no leer ni modificar objetos ajenos. `n8n_app` no es superusuario, no puede crear roles ni bases, tiene un límite de 20 conexiones y no tiene permisos sobre las tablas de negocio ni de auditoría. `monitor_db` dejó de tener privilegios sobre el esquema `n8n`. La conexión mantiene TLS con verificación de la CA (`DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true`); no se desactivó SSL ni se utilizó el superusuario.

El cambio se aplicó con `scripts/migrate-n8n-app.sh`. Antes de modificar la base, el script genera un respaldo verificable en `.runtime/`: un volcado completo de la base, los roles sin contraseñas y el volumen `n8n_data`. Después aplica `db/sql/06-n8n.sqb`, que es idempotente, y recrea solo el contenedor n8n. No se eliminaron volúmenes, datos ni credenciales. El volumen `n8n_data` conservaba su clave de cifrado, que coincide con `.env`, y el esquema `n8n` no contenía tablas, por lo que no existían flujos ni credenciales previos que migrar. Las migraciones de n8n crearon sus tablas internas y se registraron 204 migraciones. Para evitar actualizaciones involuntarias de esquema, la imagen se fijó en `n8nio/n8n:2.30.8`, cuyo digest coincide con el de la imagen ya validada.

El aviso `DB_POSTGRESDB_SSL_CA_FILE contains leading or trailing whitespace` se analizó por separado: el certificado es un PEM válido, emitido para `postgres`, vigente hasta 2027, y termina con el salto de línea estándar del formato. La conexión TLS 1.3 con verificación funciona, por lo que el aviso es informativo y no requirió modificar el certificado.

**Registros legibles por todos y verificación de consultas lentas.** Además del ajuste de permisos descrito en A.4, se comprobó que con `logging_collector=on` los registros no aparecen en `docker compose logs`, por lo que el comando de verificación se cambió para leer el archivo dentro del contenedor.

**Filebeat y UFW.** En el entorno WSL, `/var/log/ufw.log` no existe como archivo. Docker creó en su lugar un directorio vacío al montar la ruta, y Filebeat no tiene eventos que procesar. La solución requiere habilitar UFW y su registro en el sistema anfitrión, tarea que corresponde al integrante de monitoreo; aquí solo se documenta.

## B. Base de datos y auditoría

### B.1 Estructura de la base de datos

El esquema contiene 14 tablas: ocho tablas empresariales (`plantas`, `productos`, `materias_primas`, `lotes_produccion`, `clientes`, `ventas`, `control_calidad`, `gastos`) y seis tablas auxiliares para auditoría, eventos, backups, alertas y baseline. Las tablas principales tienen claves primarias; lotes, ventas y control de calidad tienen las claves foráneas que corresponden. Se incluyen tres vistas agregadas para reportes. La tabla de auditoría conserva índices por tabla, usuario y fecha.

Los scripts de inicialización se ejecutan por el mecanismo estándar de la imagen oficial de PostgreSQL, solo con un volumen vacío. La semilla usa identificadores deterministas y `ON CONFLICT DO NOTHING`, para facilitar su re-ejecución sin duplicar registros. El script de demostración está fuera de la carpeta de inicialización y no se ejecuta automáticamente.

### B.2 Preparación de datos de prueba

Las cantidades verificadas fueron: 3 plantas, 50 productos, 100 materias primas, 500 lotes de producción, 1.500 clientes, 1.500 ventas, 300 controles de calidad y 200 gastos. Los datos son ficticios; las direcciones de correo usan el dominio reservado `example.invalid`.

### B.3 Registro de modificaciones

`auditoria_datos` registra tabla, operación, usuario de sesión, fecha, IP cuando corresponde, identificador de fila, JSON anterior, JSON nuevo y transacción. `fn_auditoria()` es una función `SECURITY DEFINER` asignada a `audit_owner`, de modo que la aplicación no necesita permisos directos para insertar en la auditoría. Una función separada registra conteos de filas por sentencia en `auditoria_sentencias`.

### B.4 Configuración y verificación de triggers

Las cuatro tablas críticas —productos, lotes_produccion, ventas y clientes— tienen un trigger por fila para INSERT/UPDATE/DELETE y dos triggers por sentencia para UPDATE y DELETE. En total son 20 eventos de trigger. La auditoría se probó con una fila ficticia de clientes: el UPDATE almacenó los valores anterior y posterior; el DELETE registró la fila anterior y `valor_nuevo` nulo. La fila temporal se eliminó y el evento de auditoría permaneció.

La cuenta `agente_ia` pudo consultar productos usando una conexión TLS verificada. INSERT, UPDATE y DELETE se rechazaron por la configuración de solo lectura y no tiene grants de escritura en las tablas empresariales.

La revisión confirmó que la auditoría no altera los permisos de las cuentas: `auditor_db` puede leer la auditoría, pero no borrarla ni leer clientes; `ti_db` lee clientes y la auditoría sin poder modificarla; `agente_ia` no accede a la auditoría, y `n8n_app` no tiene acceso al esquema `public`. Tras la corrección de n8n, la demostración se repitió con una nueva fila ficticia (identificador 1504): se registraron INSERT, UPDATE con valores anterior y posterior, y DELETE con `valor_nuevo` nulo. El conteo de clientes se mantuvo en 1.500.

### B.5 Configuración de referencia

`pg_settings_baseline` contiene siete parámetros: SSL, cifrado de contraseñas, `work_mem`, máximo de conexiones, bibliotecas precargadas, duración mínima de consulta lenta y registro de conexiones. La consulta de comparación mostró coincidencia entre el valor esperado y el valor efectivo en las siete filas. Esta tabla es una referencia de configuración; una diferencia futura debe investigarse y no presentarse automáticamente como ataque.

### B.6 Inicialización limpia

`scripts/test-init-ab.sh` crea un contenedor PostgreSQL temporal, sin red ni puertos publicados, y ejecuta todos los scripts de `db/sql/`. En la revisión 2 produjo 14 tablas, 20 eventos de trigger, siete parámetros de baseline y el esquema `n8n` propiedad de `n8n_app`, sin permisos de esa cuenta sobre `public`. El contenedor temporal se eliminó al terminar.

## Limitaciones de la evidencia entregada

No se recibieron el PDF/Word del informe actual ni la guía oficial del profesor, por lo que no se pudo editar el documento original ni contrastar literalmente la rúbrica. No se incluyen capturas de pantalla; se conservan salidas auténticas de comandos. El checkout tampoco incluye el servicio de monitoreo, el agente UFW, la canalización Logstash/Loki ni scripts de integración mencionados en documentación previa. Esos requisitos deben marcarse pendientes hasta contar con los archivos y repetir las pruebas correspondientes. La interfaz de n8n funciona, pero los flujos no se importaron y Telegram, Groq y las 17 alertas no se probaron.
