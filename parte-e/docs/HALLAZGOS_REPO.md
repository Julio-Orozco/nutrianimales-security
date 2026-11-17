# Revisión de la base usada por E

Revisión del 16/11/2026. Repositorio: `Julio-Orozco/nutrianimales-security`.
Base de E: rama `feature/integrantes-A_B`, commit
`8ea8c12500aa7375ea11f57c406d7b11211c4190`.

## Lo que ya existe y E aprovecha

- El Compose utiliza PostgreSQL 16.14 y la base `nutrianimales` sin publicar 5432.
- Los archivos `.sqb` son SQL del equipo; el inicializador `00-init.sh` los ejecuta
  explícitamente con psql. Su extensión no significa que falte el esquema.
- Se definen tres grupos de negocio, sus cuentas LOGIN, cuentas técnicas y ACL.
- El esquema tiene ocho tablas empresariales, seis de soporte y tres vistas de
  reportes, además de objetos de la extensión. No son solamente diez tablas.
- Existen cuatro triggers por fila para productos, clientes, ventas y lotes,
  además de ocho triggers por sentencia para UPDATE/DELETE.
- La función por fila registra `session_user`, usa `SECURITY DEFINER` con un
  `search_path` fijo y tiene un propietario NOLOGIN dedicado.
- La rama actual incorpora `06-n8n.sqb`: crea `n8n_app`, su esquema y los permisos
  que necesita TypeORM. No debe repetirse el hallazgo antiguo de que falta esa cuenta.
- HBA usa `samenet` y exige SCRAM sobre TLS para conexiones de red autorizadas.
- Nginx publica solo en loopback; los certificados y claves se generan localmente
  con la preparación de A/B. La clave histórica ya no está en el árbol de A/B.

## Qué agrega E

E no vuelve a implementar los roles de B. Verifica sus permisos efectivos y sus
rechazos, prepara el inventario/política de secretos, prioriza cinco riesgos y
organiza el informe. Para ejecutar en su PC Windows agrega un complemento Compose
que coloca init, TLS y logs en volúmenes Linux, sin reescribir los originales.
La nueva rama contiene estas pruebas, documentación y evidencias.

## Hechos comprobados en la PC de E

El arranque quedó saludable. El motor informó versión 16.14; los tres grupos y las
tres cuentas existen, sin superusuario. La matriz de cuatro privilegios por cuenta
coincidió con el diseño. Ver [RESULTADOS_E.md](../evidencias/RESULTADOS_E.md).
E03 se ejecutó y obtuvo cuatro denegaciones correctas, con ROLLBACK final.
E04 obtuvo tres logins reales con TLS 1.3 y verificó rechazo de clave incorrecta.
El diagnóstico completo confirmó las membresías y los once objetos consultados,
cuatro triggers por fila habilitados y configuración TLS/SCRAM activa.
La regla administrativa local de `postgres` usa `trust`, como indica el HBA;
la autenticación de otras cuentas y conexiones de red autorizadas utiliza SCRAM.

## Límites y pendientes de integración

| Punto | Evaluación y acción |
|---|---|
| Alertas R/H/D y bot | Las ramas de C/D se integran y prueban en el entorno del grupo; la instancia local de E solo inició PostgreSQL. Tener JSON no acredita alertas enviadas. |
| Documentación heredada | `docs/SECRETOS.md` del equipo conserva instrucciones antiguas de Python marcadas como no aplicables. Para el aporte actual usar este inventario de E y los flujos n8n finales. |
| Historia de la clave TLS | Retirada de Git en A/B no equivale a revocación o sustitución en un servidor ya desplegado. A confirma la pareja vigente del grupo; E tiene una nueva local. |
| Red de Docker | La red es un bridge dedicado; no tiene `internal: true`. No publicar 5432 reduce exposición, pero no impide accesos desde otros contenedores con credenciales válidas. |
| Imágenes y registros | PostgreSQL está fijado en 16.14; Nginx/pgAdmin usan `latest` y n8n tiene log de depuración en esta base. A debe valorar fijación de imágenes y reducción de logs para una entrega reproducible sin secretos. No se cambian dentro de E. |
| Credencial de lectura | `agente_ia` puede leer tablas empresariales completas. Los reportes y límites del bot no eliminan el riesgo de usar directamente esa cuenta fuera del bot. |
| Recuperación | Una tabla `backups` y volúmenes persistentes no acreditan dump, copia externa ni restauración. Solicitar evidencia del procedimiento realmente utilizado. |
| Revisión de código frente a ejecución | Las capturas de E pertenecen a su propia instancia. Identificar versión y entorno de las evidencias de los demás antes de compilar el informe final. |

El aporte de E debe revisarse contra `main` después de que A/B esté integrado.
Mientras tanto, su rama conserva el mismo ancestro A/B para evitar trabajar con el
`main` antiguo y perder los cambios que permitieron arrancar la base actual.
