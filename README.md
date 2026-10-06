# Chilli Egg Finder

Panel de filtros y detector de huevos del mapa para Steal An Egg, integrado con un cargador de Chilli Hub y Server Hop.

## Cargar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/diegotoruno/SAE-SCRIPT/main/chilli_hopper.luau"))()
```

Para continuar entre servidores, coloca esa linea en el autoexec de tu executor. No hace falta copiar el archivo completo ni instalar otros archivos de este repositorio.

## Busqueda

El filtro inicial busca Divine que generen al menos 7.000.000.000 por segundo. Solo usa huevos disponibles en el mapa (`Slot`).

- Sin Divine, espera la siguiente renovacion en el servidor actual.
- Con Divine que no cumpla los filtros, hace hop y vuelve a escanear al llegar.
- Con un Divine que cumpla, se queda en el servidor y apaga AUTO. Chilli continua con su configuracion.
- Si se renuevan los huevos durante la busqueda, espera los nuevos datos y repite la decision.

El ingreso previsto incluye escala y mutaciones; excluye bonos personales y boosts temporales. Los filtros y el estado de AUTO se guardan en el workspace del executor.

## Panel

**EGG FILTERS** abre el panel. La lista principal muestra exclusivamente huevos actuales del mapa, con imagen o modelo, ingreso, rareza, escala, peso, mutaciones y zona.

**Elegir especies** abre un catalogo separado para configurar filtros. **Aplicar filtros** guarda rareza, ingreso minimo en B/s, mutacion, nombre y especies elegidas. **Solo filtro** muestra los spawns actuales que cumplen los filtros guardados. Puedes ordenar por ingreso o nombre, cambiar la vista visual, arrastrar el panel y plegar los filtros.

## API

```lua
local finder = getgenv().ChilliEggSearch
finder.Configure({
    rarity = "Divine",
    minIncome = 7000000000,
    nameContains = "",
    mutation = "",
    categories = {}, -- vacio acepta todas las especies
})
finder.Start()
-- finder.Stop()
-- finder.OpenPanel()
-- finder.GetStatus()
```

## Chilli Hub

El script carga [Chilli Hub](https://github.com/tienkhanh1/spicy) desde su URL original. El panel de filtros, el detector y el Server Hop son añadidos y no modifican el codigo interno de Chilli. Los recursos visuales y los datos de huevos se obtienen de los modulos del juego en el cliente.
