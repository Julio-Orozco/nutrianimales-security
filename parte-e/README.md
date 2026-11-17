# Parte E — Riesgos, RBAC, secretos e informe

**Grupo 3 · NutriAnimales S.A. · 16 de noviembre de 2026.**

Se trabaja en `feature/integrante5-riesgos-rbac`, creada desde
`feature/integrantes-A_B` en el commit `8ea8c12500aa7375ea11f57c406d7b11211c4190`.
Se utiliza el nombre de empresa y base que ya tiene el repositorio.

## Lo comprobado hasta ahora

Las capturas reales del integrante E están en [evidencias](evidencias/RESULTADOS_E.md):

- `.env` está ignorado por Git.
- La instancia `nutrianimales-e` arrancó; PostgreSQL está `Healthy`.
- El motor reportó PostgreSQL **16.14**, base `nutrianimales`.
- Existen tres grupos NOLOGIN y tres cuentas LOGIN sin superusuario.
- La matriz consultada coincide con las lecturas y escrituras previstas.
- E03 ejecutó lecturas permitidas, el INSERT de ensayo de TI y cuatro rechazos
  por privilegios; terminó con `ROLLBACK`.
- E04 autenticó las tres cuentas por TCP con TLS 1.3 y `verify-full`; una clave
  incorrecta recibió rechazo de autenticación.
- El diagnóstico completo confirmó las membresías, once objetos consultados,
  cuatro triggers habilitados, TLS activo, SCRAM y reglas HBA sin errores.

El registro aportado está en [Evidencias_Parte_E.txt](evidencias/Evidencias_Parte_E.txt).
Los SHA-256 de los tres archivos ejecutados coinciden con el código de este paquete.
Las pruebas locales no certifican la instalación de Julio ni las alertas n8n de C/D.

## Cómo reproducir las pruebas desde PowerShell

Las pruebas ya constan en las evidencias; estos comandos quedan para reproducirlas
cuando sea necesario, desde la raíz del clon.

La base ya debe estar iniciada con los dos Compose y el proyecto `nutrianimales-e`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\parte-e\Ejecutar-E.ps1 -Paso Pruebas
```

Este paso intenta operaciones permitidas y prohibidas bajo los roles reales del
motor. Todo el ensayo SQL va dentro de una transacción que termina con `ROLLBACK`.
La fila temporal en `backups` no es un respaldo real. Su secuencia puede avanzar.

Después:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\parte-e\Ejecutar-E.ps1 -Paso Autenticacion
```

Este paso abre tres conexiones TCP con contraseña y TLS `verify-full`, e intenta
una clave deliberadamente incorrecta. Toma las claves del entorno del contenedor
y nunca las imprime. No necesita conocerlas, enviarlas por chat ni abrir 5432.

Para reunir todo el registro en un archivo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\parte-e\Ejecutar-E.ps1 -Paso Todos
```

`Todos` repite diagnóstico, permisos, operaciones y autenticación. Cada ejecución
guarda su salida real en `parte-e/evidencias/FECHA-Paso.txt` e identifica por SHA-256
el código transferido al contenedor. Si falla un comando, el proceso se detiene.

`-NoProfile` evita personalizaciones de la consola. `-ExecutionPolicy Bypass`
permite ejecutar este archivo local en ese nuevo proceso de PowerShell;
no modifica la política permanente ni otorga permisos administrativos.
`-File` indica el script y `-Paso` selecciona la comprobación.
La explicación de cada bloque está en [COMANDOS_Y_CODIGO.md](docs/COMANDOS_Y_CODIGO.md).

## Entregables para la rama

| Archivo | Para qué sirve |
|---|---|
| [MATRIZ_RIESGOS_E.md](docs/MATRIZ_RIESGOS_E.md) | Cinco amenazas con P×I, responsables, controles y riesgo residual estimado. |
| [MATRIZ_RBAC.md](docs/MATRIZ_RBAC.md) | Tres roles, cuentas, permisos y alcance de las pruebas. |
| [INVENTARIO_SECRETOS_E.md](docs/INVENTARIO_SECRETOS_E.md) | Nombres, consumidores, custodia y tratamiento de exposición; sin valores. |
| [APORTE_INFORME_E.md](docs/APORTE_INFORME_E.md) | Texto de E para integrar al informe del grupo. |
| [COORDINACION_Y_GUION.md](docs/COORDINACION_Y_GUION.md) | Evidencias que aporta cada compañero, reparto de tiempo y guion personal. |
| [CHECKLIST_CIERRE_E.md](docs/CHECKLIST_CIERRE_E.md) | Criterios para cerrar E y publicar la rama. |
| [HALLAZGOS_REPO.md](docs/HALLAZGOS_REPO.md) | Base realmente revisada, correcciones de A/B y limitaciones actuales. |
| [VALIDACION_DEL_PAQUETE.md](docs/VALIDACION_DEL_PAQUETE.md) | Verificación de preparación y límites de lo probado fuera de la PC de E. |

Los archivos se agregan al repositorio del grupo. No se reescriben sus SQL, flujos,
Compose original ni el `.env`. El complemento Windows ya usado se incluye igual
para que este aporte sea reproducible.
