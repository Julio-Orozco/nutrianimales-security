# Registro de evidencias reales de E

Fecha: 16 de noviembre de 2026. Entorno: PC Windows del integrante E,
Docker Desktop con contenedores Linux. Proyecto Compose `nutrianimales-e`.
Base de código: `8ea8c12500aa7375ea11f57c406d7b11211c4190`, rama A/B;
trabajo propio en `feature/integrante5-riesgos-rbac`.

El usuario aportó [Evidencias_Parte_E.txt](Evidencias_Parte_E.txt), que conserva el
registro de consola desde el clon hasta el diagnóstico final. Se incluye tal como
se recibió, junto con seis capturas. No se reconstruyeron archivos nativos de logs
a partir de capturas. Los archivos individuales generados por el ejecutor siguen
en la carpeta de evidencias del clon local.

## Resultados observados en capturas

| Evidencia | Acción | Resultado observado | Qué demuestra |
|---|---|---|---|
| [E00_env_ignorado.png](E00_env_ignorado.png) | `git check-ignore -v -- .env` | `.gitignore:1:.env .env` | El archivo local está excluido del seguimiento ordinario de Git. No prueba permisos NTFS ni revocación de secretos anteriores. |
| [E00_arranque_postgresql.png](E00_arranque_postgresql.png) | `up -d --wait ... postgres` con ambos Compose | Preparación terminó; `nutrianimales_e_db` quedó `Healthy`. | Arranque real del PostgreSQL local de E. No acredita los demás servicios. |
| [E01_roles_y_version.png](E01_roles_y_version.png) | Consulta de base, versión y `pg_roles` | `nutrianimales`; `16.14 (Debian 16.14-1.pgdg13+1)`; seis filas de roles/cuentas. | Los tres grupos NOLOGIN y sus tres cuentas LOGIN existen, todos con `superusuario = f`. |
| [E02_matriz_permisos.png](E02_matriz_permisos.png) | Cuatro comprobaciones `has_table_privilege` por cuenta | Matriz de tres filas igual a la tabla siguiente. | Privilegios efectivos en objetos específicos. No prueba por sí sola un login ni una operación ejecutada bajo ese rol. |
| [E03_pruebas_rbac.png](E03_pruebas_rbac.png) | `Ejecutar-E.ps1 -Paso Pruebas` | Cuatro denegaciones esperadas, lecturas permitidas, INSERT de ensayo de TI y ROLLBACK final; sin error de ejecución. | PostgreSQL aplicó las restricciones durante operaciones reales bajo los roles probados. |
| [E04_autenticacion_tls.png](E04_autenticacion_tls.png) | `Ejecutar-E.ps1 -Paso Autenticacion` | Tres logins identificados con TLS 1.3 y `verify-full`; contraseña incorrecta rechazada. | Autenticación de esas cuentas y canal TLS en conexiones TCP nuevas dentro de Docker. |

| Cuenta | SELECT reporte_ventas | SELECT auditoria_datos | INSERT backups | DELETE auditoria_datos |
|---|---|---|---|---|
| gerente_db | t | f | f | f |
| ti_db | t | t | t | f |
| auditor_db | f | t | f | f |

## Operaciones y autenticación comprobadas

| Paso | Resultado observado | Estado |
|---|---|---|
| E03 — gerente | Cuenta 4 grupos del reporte; lectura de auditoría rechazada con `insufficient_privilege`. | Correcto. |
| E03 — TI | Lee auditoría vacía; INSERT de ensayo devuelve id 1 y estado `prueba_rbac_no_respaldo`; DELETE de auditoría rechazado. | Correcto. La fila se revierte al finalizar. |
| E03 — auditor | Lee auditoría vacía; DELETE rechazado. | Correcto. |
| E03 — agente IA | Cuenta 1500 clientes; INSERT rechazado. | Correcto. |
| E03 — final | Cuatro PASS y ROLLBACK; ejecutor finaliza sin error. | Correcto; no es un respaldo real. Las secuencias pueden haber avanzado. |
| E04 — gerente/TI/auditor | Cada conexión devuelve `session_user` y `current_user` iguales a la cuenta correspondiente, TLS 1.3 y `verify-full`. | Correcto para las tres cuentas. |
| E04 — clave incorrecta | Rechazo específico `password authentication failed`. | Correcto; no se confundió con un error de red o certificado. |

## Diagnóstico completo al final del archivo aportado

La base indicó `2026-11-16 14:20:37.572822-06`. La ejecución terminó sin error.

| Comprobación | Resultado observado |
|---|---|
| Motor y base | PostgreSQL 16.14, base `nutrianimales`; operador administrativo `postgres`. |
| Objetos seleccionados | Los 11 objetos consultados existen: tablas de negocio/soporte y tres reportes. Esto no es un conteo total del esquema. |
| Cuentas y grupos seleccionados | Nueve filas; todos sin superusuario, CREATEDB ni CREATEROLE. Los tres grupos son NOLOGIN. |
| Membresías | `gerente_db` → `rol_gerente`; `ti_db` → `rol_ti`; `auditor_db` → `rol_auditor`. |
| Esquemas | `public` pertenece a `pg_database_owner`; `n8n` pertenece a `n8n_app`. No se inició n8n en esta instancia. |
| Cuatro triggers por fila | Productos, lotes, clientes y ventas, todos con `tgenabled = O`. Esto acredita presencia/habilitación; la demostración empresarial antes/después la aporta B. |
| Parámetros activos | `log_connections=on`, `password_encryption=scram-sha-256`, `shared_preload_libraries=pg_stat_statements`, `ssl=on`. |
| Reglas HBA | Socket local de `postgres` con `trust`; otras cuentas locales con SCRAM; regla de red `hostssl` en `samenet` con SCRAM; reglas de rechazo IPv4/IPv6; ninguna fila con error. |

## Trazabilidad del código ejecutado

Los tres SHA-256 impresos por el ejecutor coinciden con los archivos fuente
normalizados a LF incluidos en el paquete:

| Archivo | SHA-256 observado y comparado |
|---|---|
| `03_pruebas_rbac.sql` | `07B87732C8F7AB77B0F81CC4BD5E69C8C72D445CE52B0C31886A1F0505F23D76` |
| `04_autenticacion_tls.sh` | `A1648015297F85758D7B7B702CDD8E38EC9AFDB8D19527F9B23520CCB3835E33` |
| `01_diagnostico.sql` | `6F2197D1D8F63E64E1A20158BABAD138B1A4504E92CD14667199F361CB73FACD` |

El registro de consola indica que se generaron estos archivos individuales en la PC:

- `20261116-141649-634-Pruebas.txt`.
- `20261116-141930-861-Autenticacion.txt`.
- `20261116-142036-917-Diagnostico.txt`.

## Alcance y siguiente cierre

Las verificaciones técnicas E01–E04 descritas aquí están comprobadas en la PC de E.
No acreditan las alertas R/H/D, los ataques del equipo, la revocación Groq, una
restauración de respaldos ni la instalación de otro integrante. La publicación
de la rama y la compilación final conjunta siguen pendientes de su evidencia.
