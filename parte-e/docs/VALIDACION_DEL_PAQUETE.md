# Validación y límites

## Evidencia real del integrante E

Las capturas aportadas el 16/11/2026 acreditan el arranque en Docker Desktop,
PostgreSQL **16.14**, los seis grupos/cuentas seleccionados y la matriz efectiva
de cuatro privilegios por cuenta. Se incluyen sin alterar en `parte-e/evidencias`.
La preparación de TLS del complemento Windows ya se utilizó en ese arranque.

El integrante ejecutó además E03 y E04 desde PowerShell. E03 obtuvo cuatro
denegaciones esperadas y terminó con ROLLBACK. E04 autenticó las tres cuentas con
TLS 1.3 y `verify-full`, y verificó rechazo de una clave incorrecta. El diagnóstico
completo confirmó las tres membresías, once objetos seleccionados, cuatro triggers
habilitados y los parámetros/reglas activos. El registro de consola original está
incluido como `evidencias/Evidencias_Parte_E.txt`.

Los SHA-256 de los tres archivos indicados en ese registro se compararon con sus
fuentes normalizadas a LF: los tres coinciden. No se fabricaron salidas ni se
incluyeron registros de otro entorno como si fueran los del integrante.

## Comprobaciones al preparar el código

- Sintaxis de los tres SQL comprobada con parser PostgreSQL.
- E03 ejecutado con el motor PostgreSQL **16.2** en modo monousuario sobre un
  esquema compatible previamente inicializado: cuatro denegaciones de privilegios,
  sin errores no controlados, y ninguna fila de ensayo persistida tras ROLLBACK.
- Sintaxis Bash de autenticación y preparación comprobada con `bash -n`.
- Combinación de ambos YAML validada con Docker Compose **2.39.1**, utilizando
  valores ficticios exclusivamente en la validación. Se comprobó la sustitución
  de los tres montajes y la conservación de los demás archivos/volúmenes.
- La normalización CRLF del preparador conserva el contenido lógico de los siete
  archivos de inicialización de A/B.
- El archivo ZIP se verifica antes de entregarse; contiene código, documentos,
  seis capturas y el texto de evidencia aportado. No incluye `.env` ni claves privadas.

La comprobación preparatoria del motor 16.2 es auxiliar. La evidencia del recorrido
PowerShell, psql, permisos y autenticación del proyecto procede de las ejecuciones
reales del integrante E en Windows con PostgreSQL 16.14. Esa evidencia, no el ensayo
auxiliar, fundamenta los resultados del informe.

## Interpretación de resultados

- E03 debe terminar sin `ERROR` no controlado y mostrar cuatro `PASS` por denegación,
  además del `ROLLBACK`. No basta con ver solo un mensaje de inicio o un PASS.
- E04 debe mostrar los tres logins con su identidad y protocolo TLS y un rechazo
  específico de contraseña incorrecta. Un fallo de red/certificado no cuenta.
- E01/E02 son consultas: su ejecución sin error no significa automáticamente que
  todos los permisos coincidan con el diseño; se comparan sus filas con la matriz.
- El ejecutor conserva stdout/stderr y se detiene si Docker/Bash/psql devuelve
  código distinto de cero. Revisar el registro, sin cambiarlo para aparentar éxito.

Los resultados de C/D, los servicios n8n/Nginx y la revocación Groq se incorporan
desde las ejecuciones que aporten sus responsables, con versión y entorno propios.
