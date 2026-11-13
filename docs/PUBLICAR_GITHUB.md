# Crear el repositorio GitHub

El ZIP contiene un repositorio preparado, no credenciales ni un enlace remoto inventado. Publicarlo como **privado** por defecto. Compartirlo después con integrantes/profesor según sus cuentas reales. Los archivos secretos están ignorados, pero revisar siempre lo que se va a subir.

Ejecutar dentro de la carpeta raíz, con Git y GitHub CLI instalados. Si Git solicita identidad, configurar el nombre/correo propios del integrante; no se establece una identidad ajena en estos scripts.

| Comando | Qué hace y para qué | Por qué esa opción |
|---|---|---|
| `git init -b main` | Crea un historial local nuevo en main | No necesita copiar un historial de otro proyecto |
| `git status --short --ignored` | Muestra cambios e ignorados | Revisar que .env, runtime y evidencias estén ignorados antes de agregar |
| `git add .` | Prepara fuentes/documentación no ignoradas | Permite revisar el conjunto antes del commit; no usar -f sobre secretos |
| `git diff --cached --stat` | Resume lo preparado | Detectar archivos inesperados antes de publicar |
| `git diff --cached` | Muestra los cambios preparados | Revisión humana de que no hay tokens, datos privados o resultados inventados |
| `git commit -m "Implementar laboratorio NutriAnimales y documentación"` | Crea la primera versión local | Mensaje describe el cambio; requiere identidad Git propia configurada |
| `gh auth login` | Autoriza GitHub CLI en tu cuenta | Usar el flujo oficial; no pegar un token en un archivo del repositorio |
| `gh repo create nutrianimales-seguridad --private --source=. --remote=origin --push` | Crea el remoto privado y sube el commit actual | No hace público el código accidentalmente; source y remote hacen explícito qué se publica |
| `gh repo view --web` | Abre el repositorio recién vinculado | Obtener el enlace real y revisar la pestaña Actions |

La primera ejecución de Actions debe comprobarse. Un archivo CI incluido no es evidencia de que el CI haya pasado. Si falla, revisar el log, corregir y repetir antes de afirmar que el despliegue está verificado.

No usar `git push --force` para el primer envío ni borrar un repositorio existente con el mismo nombre. Si el nombre está ocupado, elegir uno distinto. Añadir colaboradores desde Settings con sus usuarios confirmados; este proyecto no envía invitaciones automáticamente.

Para cambios posteriores: `git add .` prepara, `git commit -m "Descripción concreta"` registra y `git push` envía al remoto ya configurado. Cada comando conserva su función anterior; revisar primero el diff.
