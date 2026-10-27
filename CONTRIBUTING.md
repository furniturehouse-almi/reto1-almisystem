# Cómo trabajar en este repositorio

## Reglas de oro
1. **Nada de secretos**: contraseñas, claves `.pem`, credenciales de AWS, `.env`, `terraform.tfstate`… nunca van al repo. Usa `.env.example` con valores vacíos.
2. **No se trabaja en `main`**: cada tarea va en su rama y entra por *pull request*.
3. **Cada uno en su carpeta** (`p1-…`, `p2-…`, `p3-…`, `p4-…`). En `laravel/` coordinad antes de tocar lo de otro.

## Flujo de trabajo
1. Coge una tarjeta del tablero Kanban (*Projects*) y muévela a **En curso**.
2. Crea una rama desde `main`: `pX/descripcion-corta` (ej. `p3/crud-muebles`, `p4/ci-terraform`).
   - Desde la web: botón de ramas → *View all branches* → *New branch*.
3. Sube tus cambios a esa rama (botón **Add file → Upload files** o editando en la web).
4. Abre un **Pull Request** hacia `main`, rellena la plantilla y enlaza la tarjeta (`Closes #12`).
5. Espera a que la CI salga en ✅ y a que **otra persona lo revise**.
6. Al fusionar, la tarjeta pasa sola a **Hecho**.

## Mensajes de commit
`[P4] Añade validación de Terraform a la CI` — parte entre corchetes + qué hace, en presente.

## Si se te escapa un secreto
Avisa al equipo **enseguida** y **cambia esa contraseña o clave**: borrar el fichero no basta, queda en el historial.
