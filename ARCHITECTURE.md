# Arquitectura

## Fuentes y build

| Archivo | Responsabilidad |
| --- | --- |
| `map_egg_search.luau` | Factory `createMapEggSearch`: configuracion, evaluacion pura, ciclo, snapshot y decisiones. |
| `egg_filter_panel.luau` | Factory `mountEggFilterPanel`: UI, catalogo, tarjetas del mapa y recursos visuales. |
| `hopper_runtime.luau` | Chilli, persistencia del hopper, pool de servidores, teleport, ciclo AUTO y API publica. |
| `build.py` | Integra las factories en closures y anade el runtime; produce `dist/`. |
| `ci_tests.luau` | Regresiones del detector con snapshots simulados. |
| `ci_tools.py` | CLI oficial Luau fijado, SHA256 de descarga, compilacion y ejecucion de regresiones. |
| `.github/workflows/ci.yml` | Validacion en PR/push/manual; despliegue a `stable` y Releases despues de CI. |
| `chilli_hopper.luau` | Puente publico de `main` hacia el bundle de `stable`; conserva la URL del usuario. |
| `loader.luau` | Linea corta usada por el executor; no requiere modulos locales. |

No se mantiene el bundle manualmente. `dist/` es generado y esta ignorado por Git. `stable` contiene el bundle, cargador, checksum y metadata de publicacion, sin las fuentes ni workflows.

## Detector

`Evaluate(records, directory, incomeFor, filters)` no usa Roblox directamente. Normaliza filtros, recorre solo Slot, verifica rareza, nombre literal, mutaciones y categorias exactas, calcula ingresos y ordena coincidencias. Devuelve mejor candidato, conteos y todas las coincidencias.

`Decide(match, info)` devuelve `match`, `loading`, `hop` o `wait`. `Scan()` obtiene snapshot y calcula datos con los modulos reales, evitando la fase de noche y snapshots pendientes. Un fallo de datos espera en vez de saltar sin evidencia.

El runtime coordina AUTO, revisa otra vez antes del teleport y conserva estado entre servidores. Un teleport ya enviado no se puede retirar; la decision nueva se aplica antes del siguiente intento y al llegar al destino.

## API publica

```lua
local finder = getgenv().ChilliEggSearch
finder.Configure({
    rarity = "Divine", minIncome = 7000000000,
    nameContains = "", mutation = "", categories = {},
})
finder.Scan()
finder.Start()
finder.Stop()
finder.GetStatus()
finder.CycleStatus()
finder.OpenPanel()
finder.ClosePanel()
finder.PanelStatus()
```

`GetStatus()` incluye config, modo, ciclo y ultimo scan. El estado persiste en archivos relativos del workspace del executor. No aplicar llamadas de ejemplo automaticamente al inspeccionar un cliente: `Configure` y `Start` cambian el estado del usuario.

## UI y ciclo de vida

`ServerHopButton` contiene `EggFilterPanel`. En Potassium puede estar debajo de `gethui()`/`CoreGui.RobloxGui`, no directamente bajo CoreGui. Al comprobar duplicados, recorrer descendientes y deduplicar instancias entre roots.

Los helpers `uiAccess()`/`access()` elevan la identidad para CoreGui. Funciones de modulos del juego o llamadas entre scripts pueden reducir esa identidad; restablecerla inmediatamente antes de acceder a la GUI. Las comprobaciones de pruebas deben hacer lo mismo.

`getgenv().__CHILLI_HOPPER_SESSION.Destroy()` elimina la sesion anterior, conexiones, loops y panel al volver a ejecutar. El loader de Chilli evita cargarlo dos veces en el mismo servidor. Conservar estos contratos al cambiar la UI o el arranque.

## CI/CD

La validacion genera el bundle y lo compila, junto con todas las fuentes y cargadores. Ejecuta las pruebas sin Roblox. El artefacto aprobado pasa al job de publicacion: se verifica su checksum y que el commit siga siendo el actual de `main`, luego se hace un push normal a `stable` y se crea una release `build-N-SHA`.

Las acciones y Luau se fijan por commit/version y checksum. El job de PR solo tiene lectura; el de publicacion requiere `contents: write` mediante `GITHUB_TOKEN`. Las ejecuciones obsoletas se cancelan por grupo de concurrencia. No se necesita token personal para CI.

Una actualizacion de Chilli o de los modulos del juego ocurre fuera de este repositorio. CI no la detecta por si sola; las pruebas reales con Potassium siguen siendo necesarias para esas dependencias.
