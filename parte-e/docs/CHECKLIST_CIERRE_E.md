# Cierre de la parte E

## Estado después de revisar las evidencias locales E01–E04

- [x] Clon de la rama A/B actualizada y rama propia de E creada.
- [x] `.env` generado sin mostrar valores; exclusión Git comprobada.
- [x] Adaptación Windows agregada; configuración Compose validada.
- [x] PostgreSQL 16.14 iniciado y saludable.
- [x] Grupos/cuentas sin superusuario comprobados en E01.
- [x] Matriz efectiva de tres cuentas comprobada en E02.
- [x] Cinco riesgos elaborados con responsables, controles y residual estimado.
- [x] Inventario de secretos y tratamiento de exposición documentados.
- [x] Aporte al informe y guion personal preparados con alcance explícito.
- [x] E03 ejecutado: acciones permitidas y cuatro rechazos correctos; ROLLBACK final.
- [x] E04 ejecutado: tres logins TCP/TLS y rechazo por contraseña incorrecta.
- [x] Diagnóstico completo/membresías guardado mediante `Diagnostico`.
- [x] RESULTADOS_E y APORTE_INFORME_E actualizados con esas salidas reales.
- [ ] Archivos revisados, commit creado y rama remota publicada.

## Coordinación de la entrega conjunta

- [ ] A confirma tratamiento de la clave histórica y evidencia de secretos del despliegue del grupo.
- [ ] Evidencias A/B/C/D integradas al informe final y ensayo de exposición coordinado.

E no está al 100% por existir documentación: se cierran los puntos con pruebas y
entrega real. Tampoco se debe bloquear el aporte local de E esperando usar la PC
de otro integrante; se identifica cada entorno y se compila la evidencia del grupo.

## Revisión antes de agregar archivos

```powershell
git branch --show-current
git status --short
git check-ignore -v -- .env
git diff --check
```

La rama debe ser `feature/integrante5-riesgos-rbac`. La exclusión de `.env` ya fue
comprobada; repetirla antes de publicar mantiene visible ese control. `diff --check`
detecta problemas de espacios en archivos modificados, no fugas de secretos.
Revisar los textos/capturas nuevos y no incorporar volcados, claves ni credenciales.

## Agregar únicamente el aporte de E

```powershell
git add -- compose.parte-e.windows.yaml parte-e ABRIR_GUIA_PARTE_E.html
git diff --cached --check
git diff --cached --stat
git diff --cached --name-only
```

`--` separa rutas de opciones y la lista limita lo preparado a este aporte.
`--cached` revisa el área que entrará al commit; `--stat` resume tamaño/cambios;
`--name-only` enumera archivos. Antes del commit, confirmar que los resultados y
documentos ya reflejan las pruebas efectivamente realizadas.

## Crear commit y publicar la rama

```powershell
git commit -m "feat(E): documentar riesgos, RBAC y secretos con evidencias"
git push -u origin feature/integrante5-riesgos-rbac
```

`commit` guarda la versión local; `push` la publica en la rama indicada y `-u`
establece seguimiento. Si Git solicita identidad, configurar el nombre/correo
propios del integrante; no copiar la identidad de Julio. Si GitHub rechaza permisos,
resolver el acceso o publicar en un fork propio y solicitar integración sin forzar
el remoto. No utilizar `--force`.

## Verificación posterior

```powershell
git status --short --branch
git log -1 --oneline
git ls-remote --heads origin feature/integrante5-riesgos-rbac
```

Comparar el commit publicado con el local y revisar la rama en GitHub. Un mensaje
de commit local no acredita que se haya subido. Coordinar que A/B se integre en
`main` antes de evaluar el diff final de E contra `main`; E partió de ese trabajo.

No borrar volúmenes para preparar el commit. Los datos y claves privadas viven
fuera del árbol de archivos que se añade a Git.
