# Tres roles SQL y mínimo privilegio

Fuente de diseño: `db/sql/01-roles.sqb`, `05-access.sqb` y `06-n8n.sqb` de A/B,
commit `8ea8c12500aa7375ea11f57c406d7b11211c4190`.
Resultados locales E01–E04: [registro de evidencias](../evidencias/RESULTADOS_E.md).

Un grupo NOLOGIN reúne permisos; una cuenta LOGIN inicia sesión y hereda su grupo.
Son identidades PostgreSQL, independientes de usuarios de Windows, direcciones IP
y cuentas del panel n8n. No hacen falta tres computadoras para demostrar RBAC.

| Rol | Grupo y cuenta | Permitido por el SQL | No concedido |
|---|---|---|---|
| Gerente | `rol_gerente` → `gerente_db` | SELECT en `reporte_ventas`, `reporte_inventario`, `reporte_produccion`. | Leer auditoría, consultar directamente clientes o escribir datos. |
| TI | `rol_ti` → `ti_db` | SELECT en tablas/vistas `public` existentes; INSERT en `backups` y `alertas_auditoria`; uso de secuencias. | Borrar/modificar auditoría; administración global de usuarios. |
| Auditor | `rol_auditor` → `auditor_db` | SELECT en auditoría de datos/sentencias, eventos, respaldos, alertas y baseline; observación mediante `pg_monitor`. | Escribir en esas tablas o consultar los reportes empresariales no concedidos. |

Las tres cuentas existen sin superusuario, como se vio en la captura E01.
`postgres` se reserva al aprovisionamiento y a las comprobaciones administrativas.
El rol auditor permite ver evidencia que puede contener datos sensibles: no debe
interpretarse como ausencia de acceso a toda información empresarial.

## Cuentas técnicas adicionales

| Cuenta | Función y alcance |
|---|---|
| `agente_ia` | SELECT en ocho tablas empresariales y tres reportes. Tiene `default_transaction_read_only=on`, timeout de sentencia y bloqueo; la frontera de escritura la ponen también sus ACL. |
| `monitor_db` | Lectura y observación; INSERT/UPDATE en alertas; ejecución de funciones concretas de snapshot/eventos. No es la cuenta de tablas internas n8n. |
| `backup_db` | `pg_read_all_data` para exportar y permiso de registrar respaldos. No equivale a una copia ya creada o restaurada. |
| `n8n_app` | Dueño del esquema `n8n`; CONNECT y CREATE sobre la base por la inicialización de TypeORM. Sin acceso concedido a tablas/secuencias empresariales de `public`. |
| `audit_owner` | NOLOGIN, propietario de funciones de auditoría y con inserción en sus tablas. Permite registrar cambios sin dar escritura directa a las cuentas de negocio. |

Los `GRANT ... ON ALL TABLES` de este diseño se aplican a los objetos existentes.
Las tablas futuras requieren revisar permisos y repetir la matriz, no asumir que
heredan automáticamente los mismos privilegios.

## Tres niveles de comprobación

1. **E01:** consulta roles, membresías, objetos y configuración activa sin leer secretos.
2. **E02:** `has_table_privilege` muestra permisos efectivos, incluidos los heredados.
3. **E03:** `SET LOCAL ROLE` cambia la identidad de autorización dentro de una transacción y ejecuta acciones.

En E03, `session_user` sigue siendo `postgres` y `current_user` es la cuenta probada.
Esto comprueba autorización del motor, no la contraseña ni todos los ajustes de
una sesión recién iniciada. El `ROLLBACK` revierte la fila de ensayo de respaldos;
las secuencias y registros técnicos pueden reflejar el intento.

| Cuenta en E03 | Operación permitida | Operación que debe fallar |
|---|---|---|
| gerente_db | Contar grupos de `reporte_ventas`. | Leer `auditoria_datos`. |
| ti_db | Leer auditoría; insertar una fila de ensayo en `backups`. | DELETE sobre auditoría, con `WHERE false` para no seleccionar filas. |
| auditor_db | Leer auditoría. | DELETE sobre auditoría, también sin seleccionar filas. |
| agente_ia | Contar clientes ficticios. | INSERT sin filas en clientes. |

Los bloques `DO` solo capturan `insufficient_privilege`. Si se permite la operación
prohibida, lanzan `FALLO` y el cliente se detiene. Un error distinto también detiene
el ensayo. No se imprime PASS de forma incondicional.

## E04: autenticación real y canal TLS

El script `04_autenticacion_tls.sh` abre conexiones TCP a `postgres` como
`gerente_db`, `ti_db` y `auditor_db`, con las contraseñas que el Compose ya entregó
al contenedor. Exige `sslmode=verify-full`, usa el certificado local como raíz de
confianza y comprueba `session_user`, `current_user` y `pg_stat_ssl`.
Además hace un único intento con una contraseña incorrecta y distingue un rechazo
de autenticación de un fallo de red o certificado.

No publica puertos en el anfitrión y no simula otra computadora. Es una prueba TCP
local dentro de Docker. `verify-full` comprueba confianza y coincidencia del nombre
del servidor; el certificado sigue siendo autofirmado de laboratorio.

## Defensa breve

«No basta con tener tres usuarios. Comprobamos qué objetos puede usar cada uno,
probamos acciones con esa identidad y separamos esa autorización del login real.
El gerente recibe reportes, TI puede registrar operaciones de soporte y el auditor
consulta evidencia. Ninguno de esos tres usuarios puede borrar la auditoría.»

La última frase quedó comprobada para las operaciones ensayadas en E03, además
de la matriz efectiva E02. E04 comprobó las contraseñas y TLS en conexiones nuevas.
Esto no equivale a probar toda operación posible ni a impedir acciones de un
superusuario o del administrador del anfitrión.

Fuentes: [privilegios](https://www.postgresql.org/docs/16/ddl-priv.html),
[SET ROLE](https://www.postgresql.org/docs/16/sql-set-role.html),
[funciones de información](https://www.postgresql.org/docs/16/functions-info.html),
[SSL](https://www.postgresql.org/docs/16/libpq-ssl.html).
