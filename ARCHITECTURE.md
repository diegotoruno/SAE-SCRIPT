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

`Evaluate(records, directory, incomeFor, filters, rarities)` no usa Roblox directamente. La rareza es un minimo inclusivo: acepta el mismo ID o un Rank mayor o igual de Data.Rarity.Rarities. El quinto argumento es opcional; usa el registro ya cargado en search.modules o los metadatos Rank de Directory. Conserva validacion del ID seleccionado contra el catalogo. Rangos faltantes/no finitos para IDs diferentes producen datos pendientes. Recorre solo Slot y mantiene ingreso exacto, nombre literal, mutaciones y especies exactas; devuelve mejor candidato, conteos y coincidencias. `rarityCount` incluye todos los rangos que alcanzan el minimo, aun si fallan otros filtros. `RarityMatches` comparte esa regla con el selector de especies y Explain.

`Decide(match, info, cycle)` devuelve `match`, `loading`, `hop` o `wait`. Ademas de la presencia local, conserva una observacion de la rareza seleccionada para continuar cuando falta en otro servidor. `Scan()` obtiene snapshot y calcula datos con los modulos reales, evitando noche y snapshots pendientes. Un fallo de datos espera; si el ciclo cambia durante el scan se descarta esa lectura.

`chilli_egg_search_cycle.json` guarda version, rareza, periodIndex, nextReset, periodSeconds, nightSeconds, seenAt y untilTime. La ventana termina al empezar la noche siguiente (`nextReset - nightSeconds`). Cambio de rareza, periodo u overrides, datos futuros/corruptos o expiracion invalidan esa memoria. Un reloj desconocido/pausado espera; cambiar minimo/especies conserva la observacion de la misma rareza. El guardado usa la persistencia verificada existente y no se repite en cada poll. `GetStatus().searchWindow` devuelve una copia de lo guardado; su existencia no demuestra vigencia ni presencia actual.

La cache de analisis incorpora el ciclo para no trasladar decisiones entre periodos sin senal de renovacion. La informacion de scan incluye el reloj capturado antes de leer los records; Decide rechaza un snapshot del periodo anterior. El panel distingue busqueda vigente sin rareza local de espera inicial.

El runtime coordina AUTO, revisa otra vez antes del teleport y conserva estado entre servidores. Un teleport ya enviado no se puede retirar; la decision nueva se aplica antes del siguiente intento y al llegar al destino. La observacion del ciclo recuerda el minimo seleccionado aunque el spawn observado sea superior; no requiere migrar la configuracion ni la ventana persistida.

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
finder.RarityOptions() -- {id, label, rank}: solo rarezas usadas por especies
finder.OpenPanel()
finder.ClosePanel()
finder.PanelStatus()
```

`GetStatus()` incluye config, modo, ciclo y ultimo scan. El estado persiste en archivos relativos del workspace del executor. No aplicar llamadas de ejemplo automaticamente al inspeccionar un cliente: `Configure` y `Start` cambian el estado del usuario.

`Configure` espera a que cargue el catalogo y valida la rareza por ID (sin distinguir mayusculas). Rechaza rangos numericos y rarezas del modulo general que ninguna especie usa. `minIncome` acepta un numero por segundo o texto como `"7b"`; se persiste como numero. El panel comparte `ParseMinimum` y `FormatMinimum` con el detector. En Roblox, el parser numerico es `Shared.Utils.Numbers.Parse`; CI usa el equivalente offline de los sufijos observados. La validacion previa impide que el parser permisivo del juego elimine puntuacion invalida y cambie el valor silenciosamente. Un ID guardado que deje de existir produce `loading` hasta corregir los filtros.

## UI y ciclo de vida

`ServerHopButton` contiene `EggFilterPanel`. En Potassium puede estar debajo de `gethui()`/`CoreGui.RobloxGui`, no directamente bajo CoreGui. Al comprobar duplicados, recorrer descendientes y deduplicar instancias entre roots.

Los helpers `uiAccess()`/`access()` elevan la identidad para CoreGui. Funciones de modulos del juego o llamadas entre scripts pueden reducir esa identidad; restablecerla inmediatamente antes de acceder a la GUI. Las comprobaciones de pruebas deben hacer lo mismo.

`getgenv().__CHILLI_HOPPER_SESSION.Destroy()` elimina la sesion anterior, conexiones, loops y panel al volver a ejecutar. El loader de Chilli evita cargarlo dos veces en el mismo servidor. Conservar estos contratos al cambiar la UI o el arranque.

El atajo LeftAlt del panel usa UserInputService.InputBegan y las mismas funciones Open/Close que los botones. Su conexion se registra con `connect` y se desconecta en Destroy para no duplicar alternancias al reejecutar. Respeta el helper de identidad y la persistencia existente; no aplica filtros ni cambia AUTO.

## CI/CD

La validacion genera el bundle y lo compila, junto con todas las fuentes y cargadores. Ejecuta las pruebas sin Roblox. El artefacto aprobado pasa al job de publicacion: se verifica su checksum y que el commit siga siendo el actual de `main`, luego se hace un push normal a `stable` y se crea una release `build-N-SHA`.

Las acciones y Luau se fijan por commit/version y checksum. El job de PR solo tiene lectura; el de publicacion requiere `contents: write` mediante `GITHUB_TOKEN`. Las ejecuciones obsoletas se cancelan por grupo de concurrencia. No se necesita token personal para CI.

Una actualizacion de Chilli o de los modulos del juego ocurre fuera de este repositorio. CI no la detecta por si sola; las pruebas reales con Potassium siguen siendo necesarias para esas dependencias.

## Rendimiento, recuperacion y opciones

AUTO calcula ingresos de la rareza minima y todos los rangos superiores, tambien con el panel cerrado. Sus firmas de cache incluyen esos spawns y los metadatos de Rank; los cambios de ingresos o elegibilidad invalidan el analisis. El resto de rarezas conserva la optimizacion de no calcular ingresos salvo que el panel los solicite.

`Scan(fresh)` conserva ingresos por UID y firma de los datos replicados. Comparte el analisis de filtros mientras no cambien records, revision, modulos o configuracion. AUTO no calcula ingresos de otras rarezas con el panel cerrado. `Scan(true)` antes de cada teleport fuerza el calculo exacto. `MapSnapshot()` proporciona al panel filas y coincidencias del mismo snapshot, con ingresos para las tarjetas. Noche y ausencia de snapshot invalidan las caches y el ultimo resultado visible.

El panel conserva metadatos por UID y crea solo las tarjetas de la ventana visible con margen. Actualiza instancias existentes; los modelos pertenecen a esas tarjetas y se destruyen al salir de la ventana o cerrar el panel. Mutaciones y modelos cargan por separado con reintentos; sus fallos no impiden usar imagenes. `PanelStatus().stats` y `GetStatus().stats` permiten observar creaciones, actualizaciones, analisis e ingresos calculados.

El soporte del runtime esta entre los marcadores `BEGIN/END TESTABLE SUPPORT` de `hopper_runtime.luau`. `ci_tools.py` extrae esas mismas funciones a `.tools/runtime_support.luau` para ejecutar casos de almacenamiento, paginacion y teleport con dependencias simuladas, sin ejecutar Roblox ni Chilli.

Los guardados verifican un temporal y el archivo final y conservan la version anterior valida en `.bak`. La lectura recupera esa copia si el principal es invalido y conserva una cache en memoria; sus consumidores reciben copias. No se promete rename atomico: se usan readfile/writefile del executor. Si no se puede guardar el estado pendiente, no se envia el teleport. El historial elimina entradas vencidas y limita a 500 las anteriores al nuevo registro.

Cada intento posee conexion de fallo, destino, jugador e ID. Un error inmediato se procesa sin esperar el timeout. Un intento sin confirmar conserva `pending/unconfirmed`; AUTO sigue observando el mapa pero no envia otro salto hasta una llegada confirmada o un clic manual en Server Hop. Reejecutar en el mismo servidor no equivale a llegar al destino. Stop/destruccion limpian conexiones; un teleport ya enviado no se puede retirar. Durante renovaciones se observa ese intento y antes del siguiente se repite la decision con datos nuevos.

Los intentos guardan tambien originConnection. El ID del entorno del cliente permanece durante reejecuciones y cambia al reiniciarse ese entorno. `TeleportDisposition` distingue llegada, reconexion al origen y reejecucion en la misma conexion. Tras reconectar al origen se espera snapshot/reloj antes de cerrar pending; el registro se vuelve a comprobar para no borrar un intento nuevo. Si no se demuestra la conexion nueva se mantiene el bloqueo. Se conserva AUTO y la ventana de busqueda, sin instalar una reconexion ni interceptar expulsiones.

La API agrega `Presets()`, `SavePreset(name, config)`, `LoadPreset(name)`, `DeletePreset(name)`, `Alerts()`, `ConfigureAlerts({notification, sound})` y `TestAlert()`. Los presets guardan filtros exactos, hasta 20 nombres. Cargar devuelve una configuracion validada sin aplicarla; el panel la deja pendiente de Aplicar. Las preferencias viven en `chilli_egg_preferences.json`; notificacion activa y sonido desactivado por defecto. Detalle muestra motivo de exclusion e ingreso sin abreviar.

Las consultas HTTP comparten una reserva entre sesiones, tienen espera acotada y descartan resultados de sesiones terminadas. Si el executor no puede cancelar un request que sigue vivo, la reserva se mantiene hasta que regrese para evitar consultas superpuestas. La busqueda recorre hasta cinco paginas; termina al conseguir al menos ocho candidatos, acabar el cursor o repetirlo.
