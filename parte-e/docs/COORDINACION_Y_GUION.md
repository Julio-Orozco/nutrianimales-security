# Coordinación y guion personal

## Evidencia que E reúne del equipo

| Integrante | Entrega necesaria para cerrar el informe |
|---|---|
| A | Arquitectura y doce controles; TLS y permisos del despliegue real; tratamiento de clave histórica si se utilizó; arranque documentado. |
| B | Tablas/datos, cuatro triggers por fila, auditoría por sentencia, UPDATE/DELETE antes/después y roles definitivos. |
| C | R1–R5 y H1–H5: fuente/umbral, prueba y mensaje Telegram reales. |
| D | D1–D7, ataques A1–A5 y las cuatro etapas de revocación/recuperación Groq. |
| E | Cinco riesgos, inventario de secretos, E01–E04, documentación y compilación coherente con las evidencias. |

Cada archivo debe indicar acción/comando, entorno/versión, fecha, resultado,
significado y responsable. No hace falta usar la PC de Julio para producir E;
sí hace falta identificar qué se comprobó localmente y qué en el despliegue conjunto.

Texto opcional para copiar al chat del grupo; no se ha enviado:

> Estoy cerrando E en mi propia PC con el SQL de A/B y mi rama de riesgos/RBAC.
> Pásenme sus evidencias finales con acción, resultado, fecha y versión del código:
> A, hardening/TLS; B, tablas y triggers; C, R/H; D, D1–D7, ataques y revocación Groq.
> No envíen .env, tokens, claves privadas ni capturas de credenciales. Yo unifico
> riesgos, resultados, limitaciones y el informe. La entrega debe coincidir con la
> versión integrada que vamos a mostrar.

## Reparto sugerido de los 15 minutos

| Participación | Tiempo |
|---|---:|
| A: caso, arquitectura y hardening | 2:30 |
| B: datos, roles y triggers | 2:30 |
| C: monitoreo R/H | 3:00 |
| D: alertas de datos, ataques y revocación | 3:30 |
| E: riesgos, pruebas RBAC, secretos y cierre | 2:00 |
| Margen conjunto para transiciones o demora de demo | 1:30 |
| Total | 15:00 |

## Guion de E, aproximadamente dos minutos

«Mi parte fue revisar los riesgos, comprobar la separación de permisos y organizar
la gestión de secretos y la evidencia del informe.

Identificamos cinco amenazas: acceso no autorizado a la base, cambios sin
trazabilidad, exposición de credenciales, degradación de TLS y lecturas masivas
con cuentas válidas. Para priorizarlas usamos probabilidad por impacto. La
exposición de secretos quedó como riesgo crítico porque una credencial filtrada
puede dar acceso aunque la aplicación esté configurada correctamente.

Para RBAC aprovechamos los roles del equipo y los verificamos en PostgreSQL 16.14.
El gerente recibe reportes agregados; TI puede leer registros y registrar
respaldos o alertas; el auditor consulta evidencia. Las tres cuentas existen sin
superusuario. La matriz efectiva confirmó que ninguna tiene permiso para borrar
la auditoría. [Mostrar E01 y E02].

Después intentamos acciones con cada rol.
Las lecturas autorizadas funcionaron y las operaciones prohibidas fueron
rechazadas por PostgreSQL. El ensayo terminó con ROLLBACK para revertir la fila de
prueba; esa fila no representa un respaldo real. [Mostrar su salida].

Además comprobamos el login de las tres
cuentas con contraseña y TLS, y el rechazo de una contraseña incorrecta. Esa es
la diferencia entre verificar permisos y verificar autenticación.

En secretos, el inventario registra qué usa cada componente, quién lo custodia y
cómo se cambia, sin mostrar valores. Comprobamos que .env esté fuera de Git.
Si un secreto se publica, hay que revocarlo o reemplazarlo y actualizar su
consumidor; borrarlo del último commit no resuelve la exposición.

Finalmente, el informe relaciona cada riesgo con su control y su evidencia.
Las capturas de mi PC acreditan estas pruebas locales; las alertas y ataques se
documentan con las ejecuciones de los compañeros en la versión del grupo.»

E03/E04 ya están comprobadas en la PC de E y sus párrafos pueden exponerse como
resultados. Los corchetes solo indican qué evidencia mostrar; no se leen en voz
alta. No declarar la revocación Groq como propia si la realizó D.

## Respuestas breves a preguntas del profesor

| Pregunta | Respuesta |
|---|---|
| ¿Por qué tres roles si trabajan en una PC? | RBAC separa identidades y permisos; la IP y la máquina no definen el rol SQL. |
| ¿Por qué el gerente no ve auditoría? | Su necesidad es consultar reportes; no requiere los registros internos ni datos detallados. |
| ¿Por qué TI no es superusuario? | Las tareas normales de soporte no necesitan poder borrar evidencia ni administrar todas las cuentas. |
| ¿SET ROLE prueba la contraseña? | No. Cambia el usuario efectivo para autorización. El login con contraseña se prueba aparte. |
| ¿ROLLBACK revierte todo? | Revierte las filas de la transacción; secuencias, estadísticas y logs técnicos pueden reflejar la prueba. |
| ¿Una cuenta de solo lectura es inocua? | No. Puede extraer datos o consumir recursos; por eso importan vistas, límites y observación. |
| ¿.gitignore protege por completo un secreto? | Evita incorporaciones ordinarias futuras; no restringe por sí solo permisos del disco ni revoca lo ya publicado. |
| ¿Cambiar .env rota la contraseña PostgreSQL? | No en una base existente: hay que cambiar la contraseña del rol y actualizar el consumidor. |
| ¿Qué queda fuera del alcance? | Producción real, protección frente al administrador de la máquina y certificación de otro despliegue solo con estas capturas locales. |

## Pregunta interesante para el profesor

«Si un administrador de PostgreSQL todavía puede alterar la auditoría local,
¿qué arquitectura recomendaría para conservar evidencia confiable frente a una
cuenta administrativa comprometida, y cómo la evaluaríamos sin dar privilegios
excesivos al sistema que recoge los registros?»
