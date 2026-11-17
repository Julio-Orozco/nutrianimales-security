# Aporte de E al informe final

**Proyecto:** seguridad de sistemas de NutriAnimales S.A. — Grupo 3.
**Fecha de pruebas locales:** 16 de noviembre de 2026.
**Código base:** A/B `8ea8c12500aa7375ea11f57c406d7b11211c4190`.
**Rama de aporte:** `feature/integrante5-riesgos-rbac`.

Este texto cubre riesgos, RBAC y secretos. El informe completo del grupo debe
incorporar las evidencias de infraestructura, triggers, alertas, ataques y rotación
que corresponden a A/B/C/D. No se presenta este aporte aislado como el informe
completo de 15–20 páginas solicitado en la guía.

## Análisis de riesgos

El análisis tomó como activos los datos ficticios de clientes, ventas, inventario
y producción, junto con la auditoría, las cuentas y los servicios que procesan esa
información. Se valoraron cinco amenazas con una escala de probabilidad e impacto
de 1 a 5 y se multiplicaron ambas puntuaciones. Esto permitió priorizar la exposición
de credenciales y los accesos o modificaciones indebidos, además de considerar la
pérdida del canal seguro y las lecturas masivas mediante cuentas legítimas.

| Amenaza | Inicial | Tratamiento principal |
|---|---|---|
| Acceso no autorizado a PostgreSQL | 15 — alto | TLS/SCRAM, puerto sin publicación y separación de cuentas/permisos. |
| Alteración o borrado sin trazabilidad | 15 — alto | Auditoría por fila/sentencia y protección de sus tablas. |
| Exposición de secretos | 20 — crítico | Custodia privada, exclusión de Git, revocación y actualización del consumidor. |
| Degradación de TLS/autenticación | 10 — medio | Configuración aprobada, baseline y verificación del cliente/monitoreo. |
| Lectura masiva con cuenta válida | 15 — alto | Reportes agregados, catálogo del bot, límites y observación de consultas. |

La matriz completa de [MATRIZ_RIESGOS_E.md](MATRIZ_RIESGOS_E.md) registra activos,
responsables, controles y estimaciones residuales. Estas cifras son una valoración
académica. No representan una reducción de riesgo medida automáticamente.
La ausencia de un puerto publicado no elimina el abuso de una credencial robada,
y una cuenta de lectura puede seguir siendo utilizada para extraer información.

## Control de acceso por roles

Se aprovechó el diseño de B, con tres grupos de permisos: `rol_gerente`, `rol_ti`
y `rol_auditor`. Cada uno se asigna a una cuenta LOGIN propia. El gerente consulta
tres reportes agregados; TI puede leer información y registrar respaldos/alertas;
el auditor consulta registros sin poder modificarlos. Las tres cuentas carecen de
superusuario. La administración de aprovisionamiento queda separada en `postgres`.

El 16 de noviembre se inició en la PC de E una instancia PostgreSQL 16.14 desde
el SQL de A/B. Docker informó el servicio saludable y las consultas confirmaron
la base `nutrianimales`, la existencia de grupos/cuentas y sus flags de login.
Luego se consultaron privilegios efectivos, que incluyen permisos heredados.

| Cuenta | Lee reporte de ventas | Lee auditoría | INSERT en registro de respaldos | DELETE de auditoría |
|---|---|---|---|---|
| gerente_db | Sí | No | No | No |
| ti_db | Sí | Sí | Sí | No |
| auditor_db | No | Sí | No | No |

Estos resultados están acreditados por las capturas E01/E02. Se preparó además
un ensayo E03 que ejecuta acciones permitidas y prohibidas bajo cada rol efectivo.
Utiliza una transacción y revierte la fila temporal de respaldo al terminar. Un
`PASS` solo se genera al recibir la denegación de privilegios correspondiente.
Si la operación prohibida se permite o aparece otro error, la prueba falla.

**Resultado E03 observado:** las lecturas permitidas funcionaron; TI insertó una
fila con estado `prueba_rbac_no_respaldo`; PostgreSQL rechazó la lectura de auditoría
del gerente, el DELETE de auditoría de TI y auditor y el INSERT de clientes del
agente. Se registraron cuatro `PASS` y un `ROLLBACK` final. La fila de ensayo quedó
revertida; no se creó un respaldo. El agente pudo contar 1500 clientes ficticios.

La autenticación se verifica por separado en E04, con conexiones TCP y contraseña
como las tres cuentas. El cliente exige TLS `verify-full` y se comprueba la identidad
de sesión y el canal en `pg_stat_ssl`. Se añade un intento con clave incorrecta.
**Resultado E04 observado:** gerente, TI y auditor iniciaron sesión con su propia
identidad y TLS 1.3; el cliente utilizó `verify-full`. La contraseña incorrecta fue
rechazada específicamente con `password authentication failed`. El uso de
`SET LOCAL ROLE` en E03 se documenta por separado de este login TCP real; ambos
se realizaron en la instancia local de E, sin simular otra máquina.

El diagnóstico del 16/11/2026 a las 14:20:37, zona -06:00 indicada por la base,
confirmó los once objetos consultados, las tres membresías correctas y cuatro
triggers por fila habilitados. También mostró `ssl=on`, cifrado de contraseñas
SCRAM-SHA-256, `pg_stat_statements` precargado y reglas HBA sin errores de análisis.
La regla de socket administrativo local para `postgres` usa `trust`; las demás
cuentas locales y los accesos `hostssl` permitidos utilizan SCRAM. No se afirma
que todas las conexiones locales exijan contraseña.

La salida original está en [Evidencias_Parte_E.txt](../evidencias/Evidencias_Parte_E.txt)
y las capturas E03/E04 en [RESULTADOS_E.md](../evidencias/RESULTADOS_E.md).
Los hashes de los tres archivos ejecutados coinciden con sus fuentes entregadas.

## Gestión de secretos

El inventario de E identifica consumidores, custodios y acciones de cambio de cada
secreto sin incluir su valor. Se distingue una contraseña de cuenta de la clave
que n8n utiliza para cifrar credenciales. Para las pruebas locales se generaron
diez valores independientes con un generador criptográfico y se verificó que
`.env` está excluido de Git. Telegram y Groq permanecieron vacíos en esta instancia
porque el ensayo RBAC no los necesita.

La preparación local de E generó su propia pareja TLS en un volumen Linux de Docker.
El repositorio actual de A/B excluye las claves privadas. La revisión histórica
había encontrado una clave seguida por Git en el `main` antiguo: su retirada no
acredita por sí sola la sustitución de una clave aún usada en otro despliegue.
A debe confirmar el tratamiento y la pareja vigente del entorno del grupo.

El procedimiento de rotación requiere cambiar el secreto donde realmente se valida,
actualizar el consumidor y comprobar funcionamiento con la nueva credencial y
rechazo de la anterior. Cambiar una variable `.env` no modifica una contraseña de
PostgreSQL ya inicializada. El reemplazo de la clave de cifrado n8n requiere un
procedimiento compatible con la versión y una recuperación comprobada.

La demostración Groq debe incorporar el funcionamiento inicial, la revocación real,
el rechazo del proveedor con la misma credencial y la recuperación con otra. Esa
evidencia corresponde a D. Un error por límite de uso o modelo inválido no acredita
la revocación. Esta versión no la declara ejecutada por E.

## Alcance y limitaciones

Las pruebas locales de E usan Docker Desktop desde Windows y el mismo SQL de A/B.
Para resolver permisos de clave privada y finales de línea se agregó un complemento
Compose, manteniendo los archivos originales. Se inició solo PostgreSQL y su
preparación: esto no certifica el despliegue completo del grupo ni las 17 alertas.

El informe final debe reunir pruebas del código integrado, indicando entorno,
fecha, comando, resultado y responsable. También debe distinguir un registro de
respaldo de una copia realmente exportada/restaurada. Los administradores de la
base o del anfitrión conservan capacidad de intervenir, por lo que esta auditoría
local no equivale a un registro externo inmutable.

## Integración del informe del equipo

| Apartado | Fuente de evidencia | Trabajo de E para compilar |
|---|---|---|
| Contexto, objetivos y arquitectura | Grupo y A | Unificar Grupo 3, empresa, servicios y alcance. |
| Doce controles de hardening | A | Integrar capturas y explicar qué control está probado. |
| Datos, cuatro triggers y auditoría | B | Relacionar cambio, usuario, antes/después y registro. |
| Riesgos, RBAC y secretos | E/B/A/D | Incluir esta matriz, resultados E y tratamiento real de secretos. |
| R1–R5 y H1–H5 | C | Tabla con fuente, umbral, ejecución y mensaje real. |
| D1–D7 y ataques A1–A5 | D | Vincular acción, detección, respuesta y restauración del estado. |
| Revocación Groq | D | Incorporar las cuatro etapas sin mostrar la clave. |
| Resultados, límites y conclusiones | Todos | Evitar declarar completos controles pendientes; identificar la versión presentada. |

## Referencias para el aporte

PostgreSQL Global Development Group. Documentación de PostgreSQL 16:
[privilegios](https://www.postgresql.org/docs/16/ddl-priv.html),
[SET ROLE](https://www.postgresql.org/docs/16/sql-set-role.html),
[funciones de información](https://www.postgresql.org/docs/16/functions-info.html) y
[SSL](https://www.postgresql.org/docs/16/libpq-ssl.html).

n8n. [Configuración de clave de cifrado](https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/).

Docker. [Combinación de archivos Compose](https://docs.docker.com/reference/compose-file/merge/).

Fuentes del caso: guía del proyecto aportada por el curso; SQL/Compose del
repositorio del grupo en el commit identificado; capturas reales del integrante E.
