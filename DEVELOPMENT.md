# Abrir y trabajar en Visual Studio Code

Abre `SAE-SCRIPT.code-workspace`. La carpeta del proyecto contiene su propio `.git`, con `origin` apuntando a `https://github.com/diegotoruno/SAE-SCRIPT.git`. No abrir la carpeta padre como si fuera el mismo repositorio.

En esta PC ya se creo `.venv` con Python y el proyecto puede compilar sin instalar paquetes Python. En otra maquina con Python 3.10 o posterior:

```sh
python -m venv .venv
```

El workspace incluye las tareas **SAE: Build** y **SAE: Verify**. `Ctrl+Shift+B` ejecuta Verify, que primero construye el bundle y despues compila y corre regresiones. Las tareas usan el Python del entorno local; no dependen del alias de Python de Windows Store.

La extension Luau Language Server figura como recomendacion del workspace; no se instala automaticamente. Roblox/executor aporta globals que no existen en el CLI, por lo que diagnosticos de globals de un language server no equivalen a fallos reales de sintaxis.

## Mapa de contexto

- `CONTEXT.md`: requisitos actuales e historial relevante.
- `ARCHITECTURE.md`: archivos, datos, API, UI y distribucion.
- `DECISIONS.md`: razones y requisitos anteriores que ya no aplican.
- `TESTING.md`: comandos, pruebas reales y limites de lo comprobado.
- `WORKLOG.md`: estado del ultimo trabajo verificado.
- `AGENTS.md`: guia para un asistente que continue en este repositorio.

## Ciclo de cambios

```sh
git pull --ff-only
git switch -c codex/descripcion
# Editar modulos y ejecutar SAE: Verify.
git add ARCHIVOS_MODIFICADOS
git commit -m "Describe el cambio"
git push -u origin codex/descripcion
```

Abrir un pull request hacia `main`. Su CI compila y prueba; solo al entrar el cambio en `main` se publica automaticamente en `stable` y Releases. El cargador del executor recibe la nueva version al ejecutarse de nuevo o al llegar a otro servidor.

VS Code o Git deben autenticar la cuenta para hacer push. La sesion web de GitHub no autentica automaticamente Git local; la credencial local encontrada anteriormente devolvio 401. Usar el inicio de sesion normal de Git/VS Code, sin poner claves en fuentes o Markdown. El acceso de lectura y fetch del repo publico funciona.

## Archivos locales e historicos

`.venv/`, `.tools/`, `dist/` y archivos del executor estan ignorados. Las referencias y backups de la investigacion siguen en la carpeta padre y no se publican. El autoexec activo esta en `%LOCALAPPDATA%\Potassium\autoexec\chilli_hopper.luau`; contiene la linea de carga, no las fuentes del proyecto.

Guardar fuentes locales no publica cambios. No sustituir autoexec por un modulo suelto. Para probar un bundle candidato antes de publicarlo, generar `dist/chilli_hopper.luau` y ejecutarlo de forma controlada en Potassium.

Referencias de configuracion: [tareas de VS Code](https://code.visualstudio.com/docs/debugtest/tasks), [Luau Language Server](https://github.com/JohnnyMorganz/luau-lsp) y [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token).
