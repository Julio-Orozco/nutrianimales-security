# Inventario y gestión de secretos

**Grupo 3 · NutriAnimales S.A. · Responsable de inventario: E.**
Este documento identifica credenciales, consumidores y responsables, sin registrar
valores. Corresponde al Compose de A/B `8ea8c12500aa7375ea11f57c406d7b11211c4190`;
los flujos finales de C/D deben confirmar sus credenciales nativas n8n.

## Inventario

| Nombre o material | Consumidor / finalidad | Custodia prevista | Responsable | Cambio y recuperación |
|---|---|---|---|---|
| `POSTGRES_PASSWORD` | Cuenta `postgres`; aprovisionamiento y administración. | `.env` privado y secreto almacenado por PostgreSQL. | A/B | Cambiar la contraseña del rol existente; actualizar configuración de administración. No usarla como credencial de flujos. |
| `GERENTE_PASSWORD` | Login `gerente_db`; reportes agregados. | `.env` privado; entregar solo al usuario autorizado si se usa login manual. | B/E | Revocar/cambiar al exponerla o retirar el acceso; comprobar un login nuevo y que el secreto anterior falle. |
| `TI_PASSWORD` | Login `ti_db`; soporte con permisos limitados. | Igual custodia privada, sin compartir entre roles. | B/E | Cambiar el rol y actualizar sus clientes autorizados. |
| `AUDITOR_PASSWORD` | Login `auditor_db`; lectura de evidencia. | Custodia privada y acceso asignado al auditor. | B/E | Retirar acceso o cambiar credencial cuando cambie el responsable o haya exposición. |
| `AGENTE_IA_PASSWORD` | Login `agente_ia`; consultas empresariales de lectura del bot. | `.env` y credencial Postgres de n8n del flujo correspondiente. | B/D | Cambiar en PostgreSQL y credencial n8n; probar consulta permitida y rechazo de escritura. |
| `MONITOR_PASSWORD` | Login `monitor_db`; consultas de monitoreo y funciones autorizadas. | `.env` y credencial Postgres n8n usada por C/D. | B/C/D | Actualizar rol y credenciales de consumidores; probar consulta y siguiente ejecución del flujo. |
| `BACKUP_PASSWORD` | Login `backup_db`; exportación y registro de respaldos. | `.env` y mecanismo privado del proceso de copia, si se implementa. | A/B | Actualizar cuenta y proceso; verificar un respaldo/restauración sin publicar su contenido. |
| `N8N_DB_PASSWORD` | `n8n_app`; tablas internas del esquema `n8n`. | `.env`; variable de conexión de n8n en Compose. | A/B | Cambiar contraseña en la BD existente, actualizar `.env` y recrear el consumidor n8n. |
| `N8N_ENCRYPTION_KEY` | Cifrado de credenciales persistidas por n8n; no es una contraseña de acceso. | `.env` y copia privada separada de recuperación. | A | Preservar con el respaldo de la instancia; rotar solo con el procedimiento compatible con la versión, comprobando que las credenciales sigan siendo utilizables. |
| `PGADMIN_DEFAULT_PASSWORD` | Aprovisionamiento inicial de la cuenta pgAdmin. | `.env` privado; cuenta persistida por la herramienta. | A | Cambiar desde la cuenta existente cuando ya fue inicializada; no asumir que editar la variable cambia esa cuenta. |
| `TELEGRAM_BOT_TOKEN` o credencial Telegram | Bot emisor/receptor de mensajes de alertas. | Credencial cifrada de n8n del flujo de C/D; variable opcional solo si existe un consumidor configurado. | C/D | Revocar en BotFather del bot propio, configurar reemplazo y probar envío/recepción. |
| `GROQ_API_KEY` o credencial Groq | Solicitudes al proveedor IA del flujo del bot. | Credencial cifrada de n8n o mecanismo aprobado por D; evitar ponerla en nodos/exportaciones JSON. | D/E | Revocar la clave usada en la demo, guardar rechazo real, crear otra y probar recuperación. |
| Claves privadas TLS Nginx/PostgreSQL | Identidad del servidor; no son certificados públicos. | En el despliegue A: archivos privados excluidos de Git. En E: clave PostgreSQL dentro del volumen Linux de Docker con modo 600. | A | Generar pareja nueva ante exposición y distribuir el certificado/CA de confianza a los clientes. |
| Contraseña de la cuenta propietaria n8n | Acceso humano al editor y a la administración de credenciales. | Gestor privado del responsable; no inventar una variable `N8N_PASSWORD` que este Compose no utiliza. | A | Gestionar desde la cuenta de n8n y probar nuevo acceso, siguiendo la versión instalada. |

`PGADMIN_DEFAULT_EMAIL` y `TELEGRAM_CHAT_ID` son identificadores; no sustituyen una
contraseña o token. El chat ID puede ser información interna y debe compartirse
solo cuando resulte necesario para la configuración.

## Estado real en la PC de E

- Se generaron diez valores aleatorios independientes, de 32 bytes cada uno,
  mediante el generador criptográfico de .NET. No se imprimieron en pantalla.
- Git confirmó que `.env` está excluido por `.gitignore` (captura E00).
- Telegram y Groq se dejaron vacíos porque las pruebas RBAC no los necesitan.
  Eso no acredita que el bot o la IA estén configurados en esta instancia.
- El preparador Windows generó la pareja TLS de esta instancia en un volumen
  Linux y aplica propietario `postgres` y permiso 600 a la clave. PostgreSQL
  arrancó. No se añadió material privado TLS al paquete de E.
- El archivo `.env` permanece en Windows: ignorarlo en Git no prueba una ACL
  NTFS restrictiva. No se reporta `chmod 600` sobre NTFS como ejecutado.
- E04 confirmó que gerente, TI y auditor pueden autenticarse con sus contraseñas
  actuales, usando TLS 1.3 y verificación del certificado/nombre. Un intento con
  clave incorrecta fue rechazado. Esto verificó autenticación; no rotó esas claves.

En Ubuntu del despliegue del grupo, A debe conservar la evidencia de `.env` con
permisos restrictivos. En Windows se aplican ACL del sistema de archivos; los
administradores del anfitrión y de Docker siguen teniendo poder sobre el entorno.
Este laboratorio usa variables de entorno: no se presenta como un gestor central
de secretos ni como aislamiento frente al administrador de la máquina.

## Exposición histórica de material TLS

En la revisión del antiguo `main` (`62f91ee`) se identificó una clave privada TLS
seguida por Git. La base A/B actual ya excluye los archivos privados y no sigue
esa clave. Son dos estados distintos: retirar el archivo actual no prueba que una
credencial publicada deje de servir. A debe confirmar que el despliegue del grupo
utiliza una pareja nueva y que los clientes confían en el certificado vigente.

La instancia de E generó su propia pareja local después del clon. No se copia
la clave histórica al informe, las evidencias ni el repositorio.

## Procedimiento de cambio de contraseña PostgreSQL existente

1. Identificar la cuenta y sus consumidores; programar el cambio sin tocar otras cuentas.
2. Abrir un cliente administrativo interactivo y usar `\password nombre_cuenta`
   con prompt oculto, o un mecanismo privado equivalente. No escribir la clave en
   una línea de terminal capturable.
3. Actualizar el secreto en la configuración local privada y en la credencial del
   consumidor. Para variables de entorno, recrear solo el servicio consumidor
   correspondiente; un reinicio no garantiza leer un `.env` cambiado.
4. Probar una conexión nueva con la clave nueva y una operación permitida.
   Confirmar que la clave anterior ya no permite un login nuevo. Las sesiones ya
   abiertas requieren tratamiento aparte si el motivo fue una exposición.
5. Registrar responsable, instante y resultado sin guardar ninguno de los valores.

Cambiar solo `.env` **no cambia** una contraseña de una base ya inicializada.
La inicialización del volumen no se repite como mecanismo de rotación.
Este procedimiento es documental: E no cambia contraseñas del equipo sin necesidad.

## Revocación Groq que debe aportar D

| Etapa | Evidencia válida sin secreto | Interpretación |
|---|---|---|
| Antes | Solicitud del flujo con respuesta real usando una clave propia del laboratorio. | El consumidor funcionaba. |
| Revocación | Acción en el proveedor identificada sin mostrar la clave. | Se invalidó la credencial utilizada. |
| Después | Nuevo intento con esa misma credencial y rechazo de autenticación del proveedor. | Un 401 puede acreditar rechazo; un 429 o error de modelo por sí solo no acredita revocación. |
| Recuperación | Credencial reemplazada en n8n y ejecución exitosa real. | El consumidor se recuperó sin reintroducir el secreto anterior. |

No se usan los antiguos comandos Python `lab.py`/`monitor`: no son la arquitectura
actual de este repo. E compila la evidencia que D ejecute y la vincula a ER3.
En el paquete actual esa demostración sigue pendiente de evidencia del responsable.

## Cierre ante exposición

Revocar o renovar el secreto efectivo, actualizar consumidores, probar funcionamiento
y rechazo del anterior, revisar accesos y retirar el material de publicaciones o
historial según corresponda. Borrar un archivo de un commit no sustituye revocar.
Registrar solo el tipo de secreto, responsable, fecha, motivo y resultado.

Para recuperación n8n, conservar de forma privada y conjunta datos/metadata,
credenciales cifradas y la clave necesaria para descifrarlas, además de roles,
configuración y certificados. Copiar al mismo disco no cubre la pérdida del anfitrión.

Referencias: [n8n: clave de cifrado](https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/),
[PostgreSQL: ALTER ROLE](https://www.postgresql.org/docs/16/sql-alterrole.html),
[psql y password](https://www.postgresql.org/docs/16/app-psql.html),
[imagen oficial PostgreSQL](https://hub.docker.com/_/postgres),
[SSL y clave privada](https://www.postgresql.org/docs/16/ssl-tcp.html).
