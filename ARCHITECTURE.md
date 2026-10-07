# Arquitectura

## Reserva Best Ping y continuidad del recorrido (2026-10-07)

DeviceNative conserva el cursor hasta completar el stream, venciendo solo observaciones de 180s. Snapshot sanitizado por UserId recuperable durante 180s entre hops/reejecuciones; cuenta nueva o borrada limpia stream y reserva. Prefetch solicita ocho candidatos y publica los grupos utiles conforme llegan. loadPool acepta BestLatency solo para el grupo 1/7 fresco de la cuenta/transporte actuales, preservando orden nativo y excluyendo actual/visitados. Grupos mayores requieren nueva prueba OccupancyAsc. Hop/AUTO usan la reserva sin HTTP incluso durante reposicion de fondo. GetStatus.serverConnection.reserve muestra count/occupancy; native agrega progreso de paginas/filas/espera. Los limites HTTP compartidos permanecen activos. La comprobacion de cuenta alimenta el stream para evitar consultar dos veces la misma pagina inicial.

## Distribucion compartida

Delta y Potassium usan el mismo punto de entrada `main/chilli_hopper.luau`, que carga el bundle validado por CI de `stable`. No elegir un bundle distinto por dispositivo; transporte/configuracion/cookie son estado local. La funcion de cuenta se integra con el bridge anterior sin cambiar su configuracion existente. Los previews no son la distribucion de uso diario; sesiones ya ejecutadas reciben actualizaciones solo al recargar el cargador o llegar con autoexec.

## Cuenta del usuario en el dispositivo

`DeviceRequest` coordina reservas de peticiones con token compartido, intervalo 15s, cooldown 60s tras 429 y espera de cola hasta 95s. Una peticion nativa que excede 30s no libera la reserva hasta terminar; pcall asegura limpieza ante excepciones. `accountConnecting` detiene consultas de fondo y da prioridad a la validacion inicial. El formulario muestra progreso, reintenta una vez ante 429 y conserva borrador oculto si falla y sigue abierto. `serverConnection.request` permite diagnostico sanitizado; no confundir intervalo/pendiente con 429. Los callbacks de progreso restauran identidad antes de acceder a UI.

`hopper_runtime.luau` agrega helpers testables NormalizeCookie, DeviceCookie, CookiePage y DeviceNative. Transporte `DeviceCookie` consulta v2 desde el executor y conserva la prioridad 1..6/BestLatency con prueba OccupancyAsc. Sin cookie/ante rechazo espera, sin bridge/fallback. Cookie aislada en closure y archivo opcional `sae_account_cookie_<UserId>.json` sin cifrado ni backups; no usa Store. GetStatus solo expone booleanos de credencial; API OpenServerAccount/CloseServerAccount/ServerAccountStatus no entrega secretos. Esta ultima agrega connecting/message sanitizados. Launcher fijo fuera de Holder y acceso desde opciones del panel; confirma GUARDADA/SOLO SESION y formulario conserva feedback visible tras escritura/relectura. Callbacks restauran identidad y pertenecen a la sesion. DisposeAccount elimina borrador; Destroy limpia credencial en memoria y conexiones; el archivo recordado permanece hasta borrado explicito. Gate sanitizado guarda cooldown/ultima consulta entre hops, nunca credenciales. Mantener el cargador comun de main en autoexec.

## Seleccion de servidores en pruebas

Conexion actual: server_hop_button_connection.json con mode=BestLatency habilita best_ping_bridge.py en PC. El runtime escribe solicitudes con nonce/exclusiones, lee respuestas directamente del workspace, valida frescura/PlaceId/orden/ocupacion y usa support.NativePool para elegir. No lee cookies. Best Ping consume siempre una respuesta actual de la conexion, sin usar el pool persistido como prueba de agotamiento. El pool se guarda con orderBy para diagnostico y para invalidar caches incompatibles. Sin proceso o con error espera; LegacyPing es solo el modo no configurado.

El proceso mantiene el cursor nativo entre hops. Al no tener candidatos 1/7, una consulta OccupancyAsc sin cookie determina la ocupacion minima disponible entre IDs no visitados. Su prueba vence a los 90s y se invalida al cambiar exclusiones; las filas BestLatency vencen a los 180s. Todas las peticiones del proceso comparten intervalo de 15s y 429 espera 60s. No se siguen redirects, ni se escriben headers/raw/cookies. Respuestas atomicas; no hay listener de red. RefreshServers renueva sin teleport; Hop usa las guardas manuales existentes; GetStatus expone serverConnection. Ve BEST_PING.md. Los parrafos siguientes describen el prototipo anterior.

`support.RankServers(servers, orderBy)` copia registros con playing entero 1..6 y ordena todas las ocupaciones ascendentemente antes del desempate. El runtime usa `LegacyPing`: dentro de cada grupo conserva FPS >=50 y ping anunciado descendente. El modo experimental `BestLatency` conserva la posicion recibida de Roblox dentro de cada grupo, sin recalcularla con ping/FPS. Un probe privado de PC ya obtiene listas autenticadas de v2 y el helper se verifico aislado en Potassium con esos datos; esa fuente todavia no esta conectada al pool del runtime.

`support.OccupancyGroup` devuelve solo el grupo de menor ocupacion. Para avanzar a 2..6 exige evidencia de que no hay candidatos inferiores. v1 se pagina por Occupancy Asc; en una lista BestLatency parcial solo puede habilitar 1/7. El pool guarda playing, occupancy y selectionPolicy = "occupancy-groups-v2"; descarta caches antiguas o mezcladas. Al agotarse sus ocho candidatos consulta de nuevo, y cada hop en 2..6 vuelve a consultar para detectar ocupaciones inferiores nuevas. Excluye actual/visitados durante una hora, conserva capacidad 7, limites de paginas/cooldown y guardas de teleport. El numero anunciado es una observacion, no una reserva de ocupacion.

## Fuentes y build

| Archivo | Responsabilidad |
| --- | --- |
| `map_egg_search.luau` | Factory `createMapEggSearch`: configuracion, evaluacion pura, ciclo, snapshot y decisiones. |
| `egg_filter_panel.luau` | Factory `mountEggFilterPanel`: UI, catalogo, tarjetas del mapa y recursos visuales. |
| `hopper_runtime.luau` | Chilli, persistencia del hopper, pool de servidores, teleport, ciclo AUTO y API publica. |
| `build.py` | Integra las factories en closures y anade el runtime; produce `dist/`. |
| `ci_tests.luau` | Regresiones del detector con snapshots simulados. |
| `ci_tools.py` | CLI oficial Luau fijado, SHA256 de descarga, compilacion y ejecucion de regresiones. |
| `best_ping_bridge.py` | Proceso local: BestLatency autenticado, prueba OccupancyAsc y entrega de registros sanitizados. |
| `start_best_ping.ps1` | Inicia el proceso oculto en Windows, sin duplicar el mismo proceso. |
| `test_best_ping_bridge.py` | Regresiones offline del intercambio, cursor, exclusiones y prueba de ocupacion. |
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

Antes de la primera decision de cada sesion/ciclo, Scan espera game:IsLoaded(), una lectura valida, minimo 10s desde esa lectura y 3s sin cambios de inputs Slot/catalogo ni revision. Compara copias para detectar cambios en el mismo record. Hasta validar, ready=false y no devuelve candidato confirmado, aunque exista memoria de busqueda. Los analisis cacheados se mantienen separados: se clona info antes de aplicar la barrera. Tras validar no demora cada poll. Noche/reset, cambio de ciclo/overrides/modulos, snapshot ausente o error de datos reinician la barrera; Scan(true) no la evita. El tiempo de carga usa os.clock(), sin sustituir el reloj del ciclo del juego. La estabilidad es una precaucion y no una señal explicita de completitud si una replicacion parcial queda detenida durante toda la ventana.

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

El boton rojo se arrastra desde el marco y todos sus controles existentes (texto, AUTO y plegado), con raton o un solo toque activo. Un umbral de 6px distingue clic de arrastre; se bloquean acciones durante el gesto y los 250ms posteriores a soltar. La posicion se guarda en `server_hop_button_ui.json` al soltar o perder foco. Todos los listeners pertenecen a la sesion y se desconectan al destruirla.


Los helpers `uiAccess()`/`access()` elevan la identidad para CoreGui. Funciones de modulos del juego o llamadas entre scripts pueden reducir esa identidad; restablecerla inmediatamente antes de acceder a la GUI. Las comprobaciones de pruebas deben hacer lo mismo.

`getgenv().__CHILLI_HOPPER_SESSION.Destroy()` elimina la sesion anterior, conexiones, loops y panel al volver a ejecutar. El loader de Chilli evita cargarlo dos veces en el mismo servidor. Conservar estos contratos al cambiar la UI o el arranque.

El atajo LeftAlt del panel usa UserInputService.InputBegan y las mismas funciones Open/Close que los botones. Su conexion se registra con `connect` y se desconecta en Destroy para no duplicar alternancias al reejecutar. Respeta el helper de identidad y la persistencia existente; no aplica filtros ni cambia AUTO.

## Estilo del panel

El estilo del Egg Finder se documenta en `DESIGN.md`: paleta grafito/champan, Gotham, tarjetas de 116px y separacion de 8px. Canvas, posiciones y ventana virtual comparten esas constantes. La respuesta de borde dura 120ms y los tweens se cancelan al destruir el control; seleccion de teclado y datos se actualizan inmediatamente. Se conservan presets, alertas, Alt, detalle de ingreso exacto y reintentos de recursos visuales. El callback de mutaciones restaura identidad despues de LabelOf antes de acceder a CoreGui.

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
