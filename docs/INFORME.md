# Secciones A y B — NutriAnimales S.A.

Texto actualizado para integrar en el informe escrito. El PDF/Word original no está en el espacio de trabajo, por lo que se conservan aquí las secciones solicitadas sin alterar el documento completo del equipo. Los resultados descritos corresponden a la ejecución Docker registrada el 14 de noviembre de 2026; `evidencias/RESULTADOS_AB.md` contiene comandos y resultados verificables. No sustituir el informe original ni presentar esta fecha como una prueba en otra computadora.

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

Los cinco contenedores aparecen en `docker compose ps`. El proceso servidor PostgreSQL opera con el usuario `postgres`; n8n, Nginx, pgAdmin y Filebeat usan UID no privilegiado. Los únicos puertos publicados son `127.0.0.1:8080` y `127.0.0.1:8443`, ambos de Nginx. pgAdmin se comunica por la red de Compose y el proxy usa el puerto interno 80. En esta ejecución n8n no abrió el puerto 5678 y Nginx devolvió 502 en su ruta; no se reporta su interfaz como funcional.

Estos resultados describen la instancia comprobada; deben repetirse en la computadora de exposición. La existencia de un servicio en Compose no demuestra que componentes ausentes —por ejemplo, monitor, Logstash o Loki— estén desplegados.

### A.4 Configuración de seguridad del entorno

PostgreSQL escucha en el puerto 5432 solo dentro de la red de contenedores. Las reglas de host exigen TLS y SCRAM-SHA-256; el resto de conexiones de red se rechaza. La conexión de agente_ia se probó con `sslmode=verify-full` y devolvió TLS 1.3. El certificado de laboratorio es autofirmado y contiene SAN para `postgres` y los nombres locales correspondientes. El certificado Nginx contiene SAN para `localhost` y `127.0.0.1`; la confianza externa no se presume.

Nginx responde con X-Frame-Options, Strict-Transport-Security, X-Content-Type-Options y Content-Security-Policy. Filebeat se configura como usuario no-root; la lectura de UFW depende de que Ubuntu tenga un archivo de log accesible al grupo autorizado. En esta instancia no se comprobó una fuente UFW real, y la configuración actual envía los eventos de Filebeat a consola, no a Loki.

La evidencia de los 12 controles, con su comando, estado y limitaciones, se encuentra en `docs/CUMPLIMIENTO.md`. La verificación de consultas lentas produjo un registro de `pg_sleep` con duración superior a un segundo, y `pg_stat_statements` mostró la consulta.

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

### B.5 Configuración de referencia

`pg_settings_baseline` contiene siete parámetros: SSL, cifrado de contraseñas, `work_mem`, máximo de conexiones, bibliotecas precargadas, duración mínima de consulta lenta y registro de conexiones. La consulta de comparación mostró coincidencia entre el valor esperado y el valor efectivo en las siete filas. Esta tabla es una referencia de configuración; una diferencia futura debe investigarse y no presentarse automáticamente como ataque.

## Limitaciones de la evidencia entregada

No se recibieron el PDF/Word del informe actual ni la guía oficial del profesor, por lo que no se pudo editar el documento original ni contrastar literalmente la rúbrica. No se incluyen capturas de pantalla; se conservan salidas auténticas de comandos. El checkout tampoco incluye el servicio de monitoreo, el agente UFW, la canalización Logstash/Loki ni scripts de integración mencionados en documentación previa. Esos requisitos deben marcarse pendientes hasta contar con los archivos y repetir las pruebas correspondientes.
