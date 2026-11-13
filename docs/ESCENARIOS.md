# Escenarios y cinco ataques obligatorios

Ejecutar solo sobre esta instalación con datos ficticios y `LAB_MODE=true`. Capturar consola/SQL, detección, hora, Telegram y respuesta. Los comandos no son evidencia de haberlos ejecutado. `--undo` revierte la configuración indicada; **no borra el rastro de auditoría**.

## Método común

1. Verificar `status`, DRY_RUN=false para probar Telegram, n8n activado y agente UFW fresco.
2. Guardar estado inicial y hora UTC. Crear backup antes de modificaciones masivas.
3. Ejecutar el escenario de la tabla. Para conexiones/locks, dejar esa terminal abierta y observar desde otra.
4. Esperar el ciclo n8n o ejecutar `python3 scripts/lab.py check CODIGO --notify`, sustituyendo CODIGO por la regla. Este comando hace detección y, si hay hallazgo nuevo, solicita entrega. Si n8n ya consumió un evento incremental, puede no aparecer otra vez: consultar bandeja, ejecución n8n y tablas de auditoría.
5. Capturar Telegram real con fecha; `dry-run` no cumple ese paso. Medir tiempo desde la acción hasta la detección/recepción, no inventar «<5 minutos».
6. Ejecutar la reversión, comprobar permisos/configuración y conservar evidencias.

## Cinco ataques de la guía

| Ataque | Comando/acción | Qué ocurre realmente | Evidencia y respuesta |
|---|---|---|---|
| A1 SSH | `python3 scripts/lab.py scenario A1` | Cliente QA realiza veinte autenticaciones falsas contra ssh-lab:2222, no contra el PC | R4 fuente ssh, líneas Failed password y mensaje Telegram. Respuesta: detener cliente y revisar origen; no se promete un bloqueo automático que no está implementado |
| A2 inyección vía Telegram | `python3 scripts/lab.py scenario A2` muestra el texto que se debe enviar al bot real | `Lista datos; DROP TABLE clientes; --` queda fuera del catálogo. No se transforma en SQL | Respuesta de bloqueo en Telegram, eventos BLOCK y auditoría evento:telegram; comprobar que clientes sigue existiendo |
| A3 UFW | `python3 scripts/lab.py scenario A3`, ejecutar la instrucción indicada en Ubuntu | Cambia una regla del host. No publica automáticamente 5432 en Docker | H1, hashes anteriores/actuales y regla visible. `python3 scripts/lab.py scenario A3 --undo` muestra cómo retirarla |
| A4 privilegios | `python3 scripts/lab.py scenario A4` | GRANT INSERT real sobre tablas públicas a agente_ia; H3 observa ACL efectivas | Captura GRANT, hallazgo H3 y Telegram. `python3 scripts/lab.py scenario A4 --undo` revoca INSERT; comprobar otra vez H3 |
| A5 lectura masiva | `python3 scripts/lab.py scenario A5` | agente_ia lee los 1.500 clientes ficticios desde QA | D7 muestra delta de filas y llamadas, usuario y consulta. Posible exfiltración, no prueba de intención maliciosa. Respuesta: revisar sesión/uso autorizado y documentar decisión |

Una alerta detecta y notifica; **no bloquea automáticamente** todos los escenarios. La respuesta del equipo forma parte del ensayo. A2 sí bloquea antes de ejecutar. El SSH de laboratorio permite contraseña para reproducir A1; no se presenta como SSH de producción endurecido.

## Las 17 reglas, activación y reversión

| Regla | Activación | Razón y estado esperado | Reversión |
|---|---|---|---|
| R1 | `python3 scripts/lab.py scenario R1` | pg_sleep(1.3) crea una consulta real que supera 1000 ms; se evalúan ejecuciones nuevas | Sin cambio persistente |
| R2 | `python3 scripts/lab.py scenario R2` | Mantiene doce consultas activas 75 s; el límite es >10 | Terminar cliente/esperar finalización |
| R3 | `python3 scripts/lab.py scenario R3` | Mantiene conexión; alerta solo de 23 a 06 hora CR | Para demo diurna se puede cambiar explícitamente OFF_HOURS_START=0/OFF_HOURS_END=24 y recrear monitor; declarar y restaurar 23/6 después |
| R4 | `python3 scripts/lab.py scenario R4` o A1 | Seis rechazos reales PostgreSQL, o veinte SSH; cada fuente se cuenta por separado en 10 min | Detener cliente; no borrar auditoría |
| R5 | `python3 scripts/lab.py scenario R5` | ALTER SYSTEM work_mem=8MB y reload; distinto al baseline 4MB | `python3 scripts/lab.py scenario R5 --undo` |
| H1 | A3 con host_agent.py activo | Hash distinto o UFW inactivo; agente ausente produce HTTP503 | Retirar regla de prueba; mantener observador activo |
| H2 | `python3 scripts/lab.py scenario H2` | Añade un comentario al archivo real: cambia hash aunque no cambie el comportamiento | `python3 scripts/lab.py scenario H2 --undo` |
| H3 | A4 | Escritura o atributos administrativos efectivos del agente | Revocar GRANT mediante A4 --undo |
| H4 | `python3 scripts/lab.py scenario H4` | Cliente outsider en 172.30.99.0/24, fuera del CIDR autorizado | Finalizar cliente. Es otra red Docker privada, no una conexión de Internet |
| H5 | `python3 scripts/lab.py scenario H5` | Cambia password_encryption a md5 y recarga. No crea nuevas contraseñas en esa condición | `python3 scripts/lab.py scenario H5 --undo` restaura SCRAM por RESET |
| D1 | `python3 scripts/lab.py scenario D1` | Backup previo y DELETE sin WHERE de ventas ficticias; >100 filas reales | `python3 scripts/lab.py scenario D1 --undo` reintroduce filas faltantes de la semilla; no restaura arbitrariamente todas las modificaciones de negocio |
| D2 | Primero evaluar D2; luego `python3 scripts/lab.py scenario D2` | Agrega 400 ventas: 26.67% sobre las 1.500 iniciales, dentro de 30 min | `python3 scripts/lab.py scenario D2 --undo` borra solo ventas estado DEMO |
| D3 | `python3 scripts/lab.py scenario D3` | Crea backup, luego envejece sus registros a 25 h. El archivo no se borra | `python3 scripts/lab.py scenario D3 --undo` crea una copia nueva con fecha real |
| D4 | `python3 scripts/lab.py scenario D4` | Siete clientes ficticios comparten correo; supera >5 | `python3 scripts/lab.py scenario D4 --undo` elimina solo segmento DEMO |
| D5 | `python3 scripts/lab.py scenario D5` muestra dos comandos | Ejecutar lock1 y lock2 en terminales distintas; el segundo espera >30 s | Las transacciones terminan con ROLLBACK o al cerrar sus conexiones |
| D6 | `python3 scripts/lab.py scenario D6` | Backup previo; UPDATE sin WHERE de 500 lotes. Trigger registra cada fila y el total por sentencia | `python3 scripts/lab.py scenario D6 --undo` vuelve lotes de semilla a activo; no es restauración genérica de estados previos |
| D7 | A5 o `python3 scripts/lab.py scenario D7` | SELECT sensible con >1000 filas nuevas; distingue una consulta de varias acumuladas | No hay cambio de datos. Conservar contexto para evaluar si la lectura era legítima |

`ALTER SYSTEM` se ejecuta separado de `pg_reload_conf()`, porque no puede ir dentro de una transacción explícita. Las referencias de integridad se conservan tras reinicio: un auto.conf reescrito puede seguir siendo diferente aun después de restaurar valores efectivos. Revisar y aceptar un baseline nuevo solo mediante un cambio documentado; no borrar el estado para silenciar una alerta.

## Límites técnicos que deben explicarse

- D1/D6 analizan una sentencia a la vez. Llamadas SQL compuestas en un único mensaje se omiten cuando no puede atribuirse con certeza `current_query()`; la auditoría de filas sigue existiendo. «WHERE true» no es ausencia sintáctica de WHERE, aunque afecte a todas las filas.
- R1 informa promedio de las ejecuciones nuevas en una ventana; no asegura detectar cada ejecución lenta escondida por otras rápidas. Los logs de consultas lentas y pgBadger complementan el análisis.
- D2 observa una ventana de hasta 30 min desde sus muestras; un arranque reciente no tiene 30 min de historia. Cuenta filas exactas para evitar el retraso de estimaciones n_live_tup.
- D7 alerta de volumen sospechoso. Varias consultas pequeñas pueden superar el umbral acumulado; el mensaje lo indica. No se prueba intención ni transmisión a un atacante externo.
- Los triggers registran cambios confirmados; un ROLLBACK revierte también su auditoría transaccional. Los eventos de autenticación y bot se registran mediante una función separada.
- Con SSL efectivamente apagado, las conexiones verify-full fallan: monitor queda sin acceso y debe informarse indisponibilidad. El escenario H5 usa MD5 para demostrar el detector sin desactivar su propio canal TLS.
