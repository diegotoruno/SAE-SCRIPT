# Chilli Egg Finder

[![CI/CD](https://github.com/diegotoruno/SAE-SCRIPT/actions/workflows/ci.yml/badge.svg)](https://github.com/diegotoruno/SAE-SCRIPT/actions/workflows/ci.yml)

Panel de filtros y detector de huevos del mapa para Steal An Egg, integrado con un cargador de Chilli Hub y Server Hop.

Para continuar el desarrollo, abre `SAE-SCRIPT.code-workspace` en Visual Studio Code. Empieza por [DEVELOPMENT.md](DEVELOPMENT.md) y [CONTEXT.md](CONTEXT.md); [ARCHITECTURE.md](ARCHITECTURE.md), [DECISIONS.md](DECISIONS.md), [TESTING.md](TESTING.md) y [WORKLOG.md](WORKLOG.md) conservan el resto del contexto. [AGENTS.md](AGENTS.md) orienta a los asistentes que trabajen en este proyecto.

## Cargar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/diegotoruno/SAE-SCRIPT/main/chilli_hopper.luau"))()
```

Para continuar entre servidores, coloca esa linea en el autoexec de tu executor. No hace falta copiar el archivo completo ni instalar otros archivos de este repositorio.

El punto de entrada de `main` carga el script validado de la rama `stable`. Los cambios de desarrollo solo se publican en `stable` despues de pasar CI. Cada publicacion tiene un archivo `version.json`, checksum y una [release](https://github.com/diegotoruno/SAE-SCRIPT/releases) para recuperar versiones anteriores. Una sesion ya abierta sigue usando la version que cargo; los cambios se reciben al ejecutar el cargador de nuevo o al entrar en otro servidor.

## Desarrollo y CI/CD

El codigo mantenido esta en tres archivos:

- `map_egg_search.luau`: filtros, lecturas del mapa y decisiones del detector.
- `egg_filter_panel.luau`: panel, imagenes, modelos y controles.
- `hopper_runtime.luau`: arranque de Chilli y coordinacion del Server Hop.

`build.py` integra los tres en `dist/chilli_hopper.luau`. No edites el `chilli_hopper.luau` de la raiz ni la rama `stable`: son puntos de distribucion.

Para mejorar el script, crea una rama `codex/descripcion`, modifica los modulos y abre un pull request hacia `main`. GitHub Actions compila los modulos y el archivo integrado con Luau 0.741, ejecuta las pruebas de regresion y guarda el artefacto. Un pull request solo valida; un cambio aprobado en `main` valida y publica automaticamente en `stable`, con una release identificada por numero de ejecucion y commit. Si falla una prueba, `stable` conserva la version anterior. Una ejecucion antigua no reemplaza un commit nuevo de `main`.

Para comprobarlo localmente con Python 3.10 o posterior:

```sh
python build.py
python ci_tools.py
```

La primera comprobacion descarga el CLI oficial de Luau; la version y los SHA256 estan fijados en `ci_tools.py`. No necesita Roblox, Potassium, una cuenta ni claves. Las pruebas cubren el limite exacto de 7B, exclusiones de estados no disponibles, filtros, datos incompletos, persistencia y renovaciones durante los hops. CI no comprueba el aspecto del panel, los cambios de modulos del juego, teleports reales ni el codigo externo de Chilli. Esas partes se verifican con Potassium antes de aceptar cambios relacionados.

El workflow usa `GITHUB_TOKEN` del propio repositorio. La validacion solo tiene lectura; el job de publicacion tiene escritura de contenido para actualizar `stable` y crear releases. No requiere guardar un token personal.

Para volver a una version anterior, restaura el commit de los modulos en `main` y deja pasar CI, o utiliza temporalmente un cargador fijado al tag de una release:

```lua
-- Sustituye TAG por el tag completo que aparece en Releases.
loadstring(game:HttpGet("https://raw.githubusercontent.com/diegotoruno/SAE-SCRIPT/TAG/chilli_hopper.luau"))()
```

## Busqueda

La rareza seleccionada es un minimo inclusivo segun el Rank del juego: Eternal acepta Eternal, Divine y cualquier rango superior. El filtro inicial busca Divine o superior que generen al menos 7.000.000.000 por segundo. Ingreso, mutacion, nombre y especies exactas siguen aplicandose. Solo usa huevos disponibles en el mapa (`Slot`).

- Sin huevos de la rareza minima o superiores ni una observacion vigente en el ciclo, espera la siguiente renovacion en el servidor actual.
- Con huevos de la rareza minima o superiores que no cumplan los filtros, hace hop y vuelve a escanear al llegar; una observacion vigente permite continuar aunque falten en el destino.
- Con cualquier huevo que cumpla, se queda en el servidor y apaga AUTO. Chilli continua con su configuracion.
- Si se renuevan los huevos durante la busqueda, espera los nuevos datos y repite la decision.

El ingreso previsto incluye escala y mutaciones; excluye bonos personales y boosts temporales. Los filtros y el estado de AUTO se guardan en el workspace del executor.

## Panel

Estilo grafito con acento champan, tipografia Gotham y tarjetas con ingreso destacado; detalles en [DESIGN.md](DESIGN.md). Conserva la lista virtualizada y las opciones existentes.

**EGG FILTERS** abre el panel. **Alt izquierdo** alterna abrir/cerrar el panel, tambien cuando estas editando un filtro. La lista principal muestra exclusivamente huevos actuales del mapa, con imagen o modelo, ingreso, rareza, escala, peso, mutaciones y zona.

**Elegir especies** abre un catalogo separado con especies de la rareza minima y las superiores. **Aplicar filtros** guarda rareza minima, ingreso minimo por segundo, mutacion, nombre y especies elegidas. Una lista explicita de especies sigue restringiendo los candidatos; vacia acepta todas. El selector de rareza usa solo las rarezas con especies en el catalogo del juego, en orden de su rango real.

El minimo acepta `500k`, `25m`, `7b`, `7.5b`, `1t` o `1q`, tambien en mayusculas. Puedes usar coma decimal (`7,5b`). Sin sufijo, el valor son unidades por segundo: `7` significa 7/s. La configuracion anterior de 7B conserva su valor y aparece como `7b`; editar y volver a aplicar conserva el limite exacto.

**Solo filtro** muestra los spawns actuales que cumplen los filtros guardados. **Rareza ↓** muestra primero la mejor rareza usando el rango real del juego; dentro de cada rareza, primero el mayor ingreso. El boton alterna con **Nombre A–Z** y conserva la preferencia. Este orden se aplica a huevos, criaturas y modelos 3D. Puedes cambiar la vista visual, arrastrar el panel y plegar los filtros.

**Detalle** explica por que un huevo cumple o queda fuera y muestra el ingreso exacto, sin redondear. **Opciones** permite guardar, cargar y borrar presets, activar notificaciones o sonido y probar la alerta. Un preset cargado queda pendiente de **Aplicar filtros**; no inicia ni detiene AUTO. La lista crea solo tarjetas cercanas a la vista y reutiliza sus instancias.

Si un teleport queda sin confirmar, AUTO sigue revisando el mapa pero no envia otro salto. **Server Hop** permite reintentarlo manualmente. Los modulos que fallen al cargar se reintentan y los modelos ausentes usan imagen. Los archivos guardados conservan una copia `.bak` para recuperacion.

## API

```lua
local finder = getgenv().ChilliEggSearch
finder.Configure({
    rarity = "Divine",
    minIncome = "7b", -- tambien acepta 7000000000 como numero exacto
    nameContains = "",
    mutation = "",
    categories = {}, -- vacio acepta todas las especies
})
finder.Start()
-- finder.Stop()
-- finder.OpenPanel()
-- finder.GetStatus()
-- finder.RarityOptions() -- IDs, nombres y rangos reales del catalogo
```

## Chilli Hub

El script carga [Chilli Hub](https://github.com/tienkhanh1/spicy) desde su URL original. El panel de filtros, el detector y el Server Hop son añadidos y no modifican el codigo interno de Chilli. Los recursos visuales y los datos de huevos se obtienen de los modulos del juego en el cliente.
