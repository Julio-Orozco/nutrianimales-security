# Matriz de cinco riesgos — NutriAnimales S.A.

Responsable de elaboración y seguimiento: integrante E. Fecha: 16/11/2026.
Alcance: datos ficticios de clientes, ventas, inventario y producción; PostgreSQL,
n8n, credenciales, auditoría y continuidad del laboratorio del grupo.

Probabilidad e impacto se valoran de **1 a 5**; riesgo = **P × I**.
Según los intervalos de la guía: 1–8 bajo, 9–14 medio, 15–19 alto, 20–25 crítico.
No se etiqueta todo como «alto». Las valoraciones son estimaciones académicas,
no estadísticas de una empresa real. C: confidencialidad; I: integridad;
D: disponibilidad.

El riesgo inicial supone ausencia de los controles propuestos. El residual es una
estimación condicionada a que esos controles operen; no debe presentarse como
riesgo residual medido solo por estar escrito en un YAML.

| ID y amenaza | Activo / consecuencia | CIA | P | I | Inicial | Controles y vínculo con el proyecto | Residual estimado | Responsable / respuesta |
|---|---|---|---:|---:|---|---|---|---|
| ER1. Acceso no autorizado a PostgreSQL | Clientes, ventas y cuentas; lectura o cambios desde una identidad indebida. | C/I | 3 | 5 | 15 — alto | Puerto 5432 sin publicación; HBA con TLS/SCRAM; cuentas separadas y mínimo privilegio; revisión de sesiones H4. | 2×5=10 — medio, si autenticación y ACL se verifican. | A/B/E; identificar sesión, revocar credencial y revisar permisos. |
| ER2. Alteración o borrado de datos sin trazabilidad | Productos, lotes, clientes y ventas; decisiones incorrectas o pérdida de evidencia. | I | 3 | 5 | 15 — alto | Cuatro triggers por fila y auditoría por sentencia; funciones con propietario dedicado; denegación de DELETE de auditoría; seguimiento D6. | 2×5=10 — medio: un superusuario sigue pudiendo alterar el sistema. | B/D/E; preservar registros, identificar operación/usuario y recuperar desde una copia verificada si corresponde. |
| ER3. Exposición de contraseñas, tokens o claves privadas | Cuentas PostgreSQL, Telegram/Groq, cifrado n8n y TLS; suplantación o acceso indebido. | C/I | 4 | 5 | 20 — crítico | Generación aleatoria; `.env` fuera de Git; credenciales n8n y custodia privada; permisos del sistema; revocación y renovación tras exposición. | 2×5=10 — medio: el historial Git, copias, administradores y capturas requieren atención. | E/A/D; revocar el secreto real, actualizar consumidor y probar recuperación. |
| ER4. Degradación de TLS o configuración de autenticación | Canal de datos y servicios; exposición del tráfico o pérdida de conexión del monitoreo. | C/I/D | 2 | 5 | 10 — medio | `ssl=on`, reglas de rechazo sin TLS, baseline, clientes con verificación del certificado; alertas H2/H5 y supervisión de disponibilidad. | 1×5=5 — bajo solo si se detectan tanto el cambio como la pérdida del canal de monitoreo. | A/C/E; aislar cambio, restaurar configuración aprobada y verificar conexión/certificado. |
| ER5. Lectura masiva mediante una cuenta legítima | Datos de clientes/ventas y recursos de la base; extracción o sobrecarga mediante SELECT permitido. | C/D | 3 | 5 | 15 — alto | Reportes agregados del gerente; catálogo acotado del bot; límites/timeout del agente; revisión de consultas y D7. | 2×5=10 — medio: el agente conserva SELECT directo en tablas empresariales. | C/D/B/E; revisar identidad y consulta, limitar acceso/vistas y preservar evidencia sin divulgar datos. |

## Evidencia y estado de los controles

| Riesgo | Revisado en el código de A/B | Observado en la PC de E | Evidencia adicional del grupo |
|---|---|---|---|
| ER1 | Compose sin 5432 publicado; HBA `hostssl ... scram-sha-256`; tres grupos/cuentas. | E01/E02 y membresías correctas; E03 obtuvo los rechazos previstos; E04 autenticó tres cuentas y rechazó una clave incorrecta. | H4 y despliegue final a cargo de A/C. |
| ER2 | `04-audit.sqb` define cuatro triggers por fila y ocho por sentencia; ACL protege la auditoría. | E01 confirmó cuatro triggers por fila habilitados; E02/E03 comprobaron la protección de auditoría en las operaciones ensayadas. | B/D aportan UPDATE/DELETE empresarial, registro y detección D6. |
| ER3 | `.gitignore` excluye `.env` y claves actuales; configuración separa contraseñas de cuentas y clave n8n. | E00 confirma `.env` ignorado; el archivo se generó sin imprimir valores. | Confirmar custodia/permisos del despliegue del grupo y secuencia real de revocación Groq de D. |
| ER4 | TLS, HBA y baseline están definidos. | E01 mostró TLS/SCRAM activos y HBA sin errores; E04 verificó tres logins con TLS 1.3 y `verify-full`. | C demuestra H2/H5 y A confirma el canal del despliegue final. |
| ER5 | Agente con SELECT y timeout; gerente limitado a tres vistas agregadas. | E02 confirma acceso a reporte y separación respecto a auditoría. | C/D demuestran catálogo del bot y alerta D7 con consulta real. |

## Prioridad y tratamiento

1. Cerrar ER3 primero: un token o clave expuesto invalida confiar únicamente en el
   `.gitignore`. Una clave conocida debe reemplazarse y su consumidor actualizarse.
2. Conservar los rechazos reales E03/E04 de ER1/ER2 y reunir las pruebas del DBA
   sobre modificaciones empresariales y auditoría.
3. Verificar ER4/ER5 con las evidencias de C/D en la versión integrada del grupo.
4. Revisar estas valoraciones cuando cambien permisos, servicios, secretos o ramas.

Los volúmenes locales sobreviven a recrear un contenedor, pero están en la misma
máquina. Para continuidad hacen falta una copia externa privada y una restauración
probada. Insertar una fila en la tabla `backups` no acredita ninguna de esas acciones.

Fuentes del control: Compose y SQL de A/B en `8ea8c12500aa7375ea11f57c406d7b11211c4190`;
requisitos y umbrales de la guía del curso; resultados reales en
[RESULTADOS_E.md](../evidencias/RESULTADOS_E.md).
