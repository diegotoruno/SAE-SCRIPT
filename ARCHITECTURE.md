# Arquitectura

## Captura del objetivo tras un match (2026-10-12)

Identidad que sobrevive a la captura: `EggKey` = especie#`AssetColorSeed`
(el Uid cambia). `Evaluate` la agrega a cada coincidencia como `key`. Con un
match o un objetivo guardado en este JobId, `Scan` agrega
`CaptureInputs(records)`: `field[key] = {state, carriedByMe}` de todos los
registros del campo, y `mine`/`others` con las keys de `ReadOwnedEggs()`
(nil si no se pueden leer). Solo siguen al objetivo; los candidatos siguen
siendo `Slot`.

`Decide` guarda en la ventana del ciclo `matched = {job, key, name, at}` (la
vigente o una nueva; sin reescribir en sondeos; un guardado fallido no oculta
el match) y un objetivo mejor lo reemplaza. Para el objetivo de este JobId:
en `mine` -> guarda `captured` y devuelve `wait` (`info.capture =
"capturado"`, hasta la noche, aunque luego deje de estar); llevado por el
jugador -> `match` sin limite (si deja de llevarlo y el huevo sigue en el
campo, el plazo empieza de nuevo; `carrying`/`lostAt` por sesion); fuera del campo con duenos conocidos -> 3 s de
gracia y luego `hop` (`info.notCaptured` "lo tomo otro jugador" si esta en
`others`, si no "ya no esta en el mapa"); 90 s sin capturar
(`CAPTURE_TIMEOUT_SECONDS`) -> `hop`; si no, `match` ("esperando captura",
"lo lleva otro jugador" o "en disputa"). Un objetivo en `Slot` que ya no
coincide (filtros) se ignora. Otro JobId sigue el flujo normal del ciclo.

Runtime: el match ya no apaga AUTO; `noteEggTarget` avisa una vez por
objetivo (match, capturado, no capturado) y `showEggTarget` muestra el
estado; el vigilante sigue sondeando. El panel lee `searchWindow.matched`.
Reporte: la busqueda sigue abierta tras el match; `hunt.matches` (10 max)
guarda cada objetivo con `capture` (pendiente, capturado con
`captureSeconds`, o el motivo) y `hunt.found` el ultimo; cierra con
`capturado`. `visit.capture` registra el estado. `wait` no abre busquedas;
un `hop` con `continuingCycle` sin candidatos abre una `resumed`.

## Reserva sin servidores que dejaron la lista (2026-10-12)

Cada pasada Balanced reinicia en la cabeza BestLatency. Tras cada pagina,
`observe` borra las filas de pasadas anteriores cuyo `nativeRank` +
`support.RELIST_MARGIN` (100) ya quedo cubierto por el `rank` de la pasada
actual sin volver a listarlas, y todas las anteriores si la lista termino
(`complete`). La API excluye servidores llenos, asi que esa ausencia indica
lleno o cerrado. Un servidor aun abierto que se movio mas reaparece cuando la
pasada lo alcanza. El orden 1/7 antes de 2/7 y los TTL no cambian; la reserva
y `server_hop_button_pool.json` se publican ya filtrados.

Reporte: `ReportHopCheck(..., server)` guarda `playing` y `listedAge` del
destino; `ReportHopFailure` agrega a `visit.failedHops` (10 max) cada teleport
rechazado de AUTO; `visit.reloads` cuenta sesiones nuevas en el mismo JobId
(reentrada o reejecucion), detectadas con `reportedJobs` por sesion.

## Reporte de busquedas (2026-10-12)

`chilli_egg_hunt_report.json` (ultimas 30 busquedas, 120 visitas por busqueda,
10 candidatos por visita con `candidateCount`). `ReportDecision` lo llama el
vigilante AUTO tras cada `Decide` (pcall: nunca bloquea); abre una busqueda
solo si `HuntCandidates(rows)` (rareza minima+, zonas elegidas, ingreso exacto
y motivo de Explain) no esta vacio; una visita por JobId con `load`
(readyBy, readySeconds, settleSeconds, zonesPresent/zonesTotal) y solo escribe
si cambia la decision o los candidatos. `ReportHopCheck` guarda el Scan(true)
previo a cada teleport y su destino; cierre por match, `noche` (otro periodo),
`filtros cambiados` o `AUTO apagado`. API `ChilliEggSearch.HuntReport()`.

`chilli_egg_hunt_report.txt` es la copia legible para personas: se reescribe
junto al JSON en cada `saveReport` (pcall; un fallo de escritura no pierde el
JSON). `RenderHuntReport(data, now)` es puro: busqueda mas reciente primero,
cabecera con estado, filtro, primer huevo, mejor ingreso visto y coincidencias,
y una linea por servidor (hora, JobId corto, accion y destino, spawns, huevos
de la rareza, carga) con hasta 3 candidatos (ingreso, escala, mutacion y motivo).
La revision previa al salto solo aparece si aun veia coincidencias; los saltos
fallidos y las recargas se listan. `createMapEggSearch(readJson, writeJson,
writeText)`: el hopper pasa `writefile`; sin `writeText` no se genera el texto.

## Tolerancia de reloj en la memoria del ciclo (2026-10-12)

`validWindow` compara `periodIndex`, `periodSeconds` y `nightSeconds` exactos;
`nextReset`, `untilTime` y `seenAt` con `CLOCK_TOLERANCE_SECONDS = 1`, porque
el ancla del ciclo de cada servidor difiere en milisegundos. Un periodo
distinto o desplazamientos mayores a 1 s siguen cerrando la memoria.

## Servidor con modulos rotos (2026-10-12)

El cargador de modulos llama `NoteLoadFailure(err)`. Dos fallos seguidos con
"Requested module experienced an error while loading" y `game:IsLoaded()`
marcan `search.broken = {count, job}` y guardan
`chilli_egg_search_broken.json` (count, at, job). La misma JobId no suma; una
racha mas vieja de 600 s empieza en 1; `NoteLoadSuccess` la borra. `Decide`
devuelve `hop` con `info.broken` antes de mirar reloj o memoria (no la toca);
con count > 3 devuelve `loading` y AUTO espera. El vigilante muestra "El juego
no cargo bien en este servidor. Buscando otro"; la espera de reconexion no se
bloquea. Errores transitorios (WaitForChild) o previos a la carga no cuentan.

## Barrera con prueba de completitud (2026-10-12)

`snapshotReady` llama en cada lectura a `snapshotComplete(records, period)`:
completo si existe `modules.areas.Directory`, cada zona oficial tiene al menos
un registro (cualquier estado), todo AreaId es conocido y ningun Uid aparecio
en el periodo anterior de esta sesion. Los Uid se acumulan por `periodIndex`;
al cambiar de periodo el conjunto anterior pasa a `staleUids`. Listo =
3 s sin cambios Slot/revision y (completo o 10 s desde la primera lectura).
`stats.readyBy` indica `complete` o `timer`; el log AUTO lo muestra como
`estable=X/Y s (complete)`. Noche/reset/snapshot ausente siguen reiniciando
la barrera; no se exige igual numero de nidos porque un reclamo retira
registros durante el dia.

## Eficiencia sin cambios de decision (2026-10-11)

map_egg_search: Scan construye la tabla de rangos una vez por snapshot y la usa
en las razones de las filas (`explain` interno; `Explain` publico igual).
SameRecord compara primitivos en linea y solo recursa en tablas; NaN sigue
siendo distinto y las claves ausentes o tablas anidadas cambiadas tambien.
Evaluate valida la rareza minima recorriendo el catalogo sin construir una
lista. Al abrirse la barrera, `stats.settleSeconds` (primera lectura valida a
ultimo cambio) y `stats.readySeconds` registran la espera real; el log
`[EggSearch] mode=...` los muestra como `estable=X/Y s`. Solo diagnostico.

hopper_runtime: `support.RecentVisited` memoriza la vista PruneVisited de solo
lectura y la recalcula al reescribirse el historial (Invalidate), al vencer una
entrada conservada o al empezar una futura. pickCandidates, savePool, loadPool,
prefetch y la restauracion la usan sin modificarla; markVisited conserva su
copia propia, acepta varios IDs en una escritura y la llegada AUTO usa una sola.
Store.Write copia como .bak los bytes previos ya validados en vez de
decodificar y recodificar; un principal danado deja intacto el .bak existente.
El prefetch solo lee el pool en el modo que lo usa.

## Hopper sin cargador de Chilli (2026-10-11)

`hopper_runtime.luau` contiene `montarHopper` (el soporte testable, el pool,
el formulario de cuenta y la tarjeta del boton viven en sus propios modulos
desde 2026-10-14); el arranque es `pcall(montarHopper)`. No hay `cargarChilli`, ni lectura de
`chilli_client.json`/`steal_an_egg_scout_state.json` para diferir Chilli, ni
`__CHILLI_UI_JOB`/`__CHILLI_LOADED_JOB_ID`. El primer refresco del pool ya no
espera una ScreenGui "Chilli" en gethui. Chilli es una dependencia externa del
usuario y se instala con su propia linea de autoexec. Los nombres con prefijo
Chilli que permanecen (`ChilliEggSearch`, `__CHILLI_HOPPER_SESSION`,
`__CHILLI_CONNECTION_ID`, `chilli_egg_*.json`) pertenecen al finder.

## UI sobria del boton y del panel (2026-10-11)

hopper_runtime: Holder es una tarjeta grafito con AutoChip, ServerHop y Toggle
como hermanos en una fila; applyCollapsed coloca los tres y cambia el tamano
(instantaneo al montar, tween 0.22 s despues). ServerHop contiene solo Label;
se retiraron gradiente, Shine y las ocho copias Outline. Status es hijo de
Holder con dos lineas y recorte. Las superficies de arrastre no cambian.

egg_filter_panel: las hojas (Dropdown, ZonePicker, EggDetail, FinderOptions)
son un TextButton de velo hijo de EggFilterPanel con ese nombre y una Frame
Sheet activa dentro; `popup` apunta al velo y closePopup lo destruye. La barra
ListBar agrupa MapTab/CatalogTab/VisualMode/Sort; layout mueve la barra y la
lista. buildCards cuenta todos y coincidencias del snapshot para las pestanas.
`GetStatus().matches` expone ese conteo. API, persistencia y detector iguales.

## Firma y ciclo de vida (2026-10-09)

ByMistakeWatermark (etiqueta flotante del panel) se retiro el 2026-10-11 a
pedido del usuario. hopper_runtime crea ByMistakeCredit
en Holder,alineada abajo en su propia fila; expandido320x116/plegado232x66
(ver UI sobria 2026-10-11).
La firma forma parte de las superficies de arrastre existentes y no tiene
acciones propias. Destroy/reejecucion retiran ambos objetos con su sesion.

## Semantica de tarjetas y zonas (2026-10-08)

Solo ZonePicker contiene checks de seleccion. createCard abre detalle y no
modifica el borrador. updateCard usa exclusivamente row.match de MapSnapshot
para CUMPLE y el resaltado; pertenecer a una zona elegida no marca una tarjeta.
Apply confirma la configuracion completa y activa SetOnlyMatches(true), cuya
preferencia se guarda. La vista Mapa sigue ofreciendo todos los Slot con
CUMPLE/FUERA. No cambia Evaluate, los rangos inclusivos ni las decisiones
wait/hop/match. El estado wait menciona la rareza minima que se espera.

## Filtro por zonas (2026-10-08)

El selector **Elegir zonas** reemplaza el filtro por especies. Ofrece las 13
entradas actuales de `Data.Areas.Directory`, ordenadas por
`Areas.GetProgressionOrder(area)`, con checks independientes y acciones Todas y
Limpiar seleccion. La lista incluye zonas sin huevos presentes y no depende de
la rareza elegida. El ID interno `Light Dark` se muestra como Angels & Demons.

La configuracion usa `zones = {"Enchanted Forest"}` para buscar solo alli;
compara el `AreaId` exacto de cada spawn Slot, por lo que Forest queda excluido.
Varias zonas se combinan con OR; rareza minima inclusiva, ingreso exacto,
mutacion y nombre siguen siendo obligatorios. `zones = {}` significa todas las
zonas y muestra todos los checks activos. Limpiar todos los checks en el panel
deja un borrador vacio que bloquea Aplicar/AUTO/presets hasta elegir al menos
una zona o Todas; no convierte una seleccion vacia accidental en todas.

Los JSON/presets antiguos conservan rareza, ingreso, nombre y mutacion; se
ignora `categories` y se inicia sin restriccion de zona. Nuevos guardados usan
`zones`. Configure ya no acepta categories. Elegir otra rareza conserva zonas.
Un AreaId ausente con zonas restringidas, catalogo de zonas pendiente o zona
guardada retirada del juego produce loading. rarityCount cuenta la rareza
minima y superiores solo en las zonas elegidas; una zona excluida no inicia
hop ni guarda evidencia. Sin esa rareza en esas zonas ni evidencia vigente se espera.

## Reserva balanceada DeviceCookie (2026-10-07)

Reposicion adaptativa: cada Pick consulta como maximo5 paginas. Una pasada con menos16 opciones conserva cursor entre llamadas hasta12 paginas o180s; con stock>=16 termina al presupuesto normal5 paginas/75s.24 registros frescos de la pasada o fin de lista terminan antes. Tras interrupcion>=180s se vuelve a cabeza. Restore conserva pasadas parciales; TTL individual no se extiende por paginar. Los saltos siguen consumiendo inmediatamente cualquier reserva vigente.

BalancedReserve ordena1/7 antes de2/7, pasadas recientes antes de anteriores y rank nativo dentro de la pasada/ocupacion. Limite24, TTL1=180s/2=90s, deduplicacion/exclusion actual/visitados. DeviceNative NeedsRefill revisa umbral16 o respaldo>=60s; nuevo refill comienza en cabeza BestLatency conservando filas validas. Snapshot guarda pass/policy/estado de reposicion; migra datos de la politica anterior sin perder1/7 listo. Cold start acepta2/7 nativo sin consultar agotamiento global1/7 por autorizacion nueva. Grupos3..6 solo mediante prueba anterior. savePool/loadPool identifican balanced-1-2-v1/owner/transporte; antigua reserva1/7 compatible. GetStatus.reserve agrega primary/backup/capacity. Errores de autenticacion no devuelven cache como exito. Hop/AUTO consumen cache sin esperar refill. Cookie y detector no cambian.

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
| `server_support.luau` | Factory `createFinderSupport`: helpers puros del hopper (Store, paginas, pool nativo, cookie, transporte, intento de teleport, escalas). Las regresiones la cargan con `require`. |
| `server_pool.luau` | Factory `createServerPool`: lista publica, Best Ping (cookie del dispositivo o bridge del PC), pool precargado y su refresco. Guarda el estado de conexion; la cookie no sale de su closure. |
| `account_panel.luau` | `mountAccountPanel`: formulario Cuenta / Best Ping; usa solo los metodos del pool. |
| `hop_button.luau` | `mountHopButton`: tarjeta del boton Server Hop, plegado, arrastre, asa de tamano y `server_hop_button_ui.json`. Solo dibuja. |
| `hopper_runtime.luau` | Sesion, persistencia del salto, teleport, llegada, ciclo AUTO, alertas y API publica `ChilliEggSearch`. |
| `build.py` | Integra las factories en closures y anade el runtime; produce `dist/`. |
| `ci_tests.luau` | Regresiones del detector con snapshots simulados. |
| `ci_tools.py` | CLI oficial Luau fijado, SHA256 de descarga, compilacion y ejecucion de regresiones. |
| `best_ping_bridge.py` | Proceso local: BestLatency autenticado, prueba OccupancyAsc y entrega de registros sanitizados. |
| `start_best_ping.ps1` | Inicia el proceso oculto en Windows, sin duplicar el mismo proceso. |
| `test_best_ping_bridge.py` | Regresiones offline del intercambio, cursor, exclusiones y prueba de ocupacion. |
| `.github/workflows/ci.yml` | Validacion en PR/push/manual; despliegue a `stable` y Releases despues de CI. |
| `chilli_hopper.luau` | Puente publico de `main` hacia el bundle de `stable`; conserva la URL del usuario. |
| `loader.luau` | Linea corta usada por el executor; no requiere modulos locales. |
| `chilli_loader.luau` | Cargador opcional de Chilli, independiente del hopper: precarga y descomprime durante la carga del juego, arranca con el personaje completo. |

No se mantiene el bundle manualmente. `dist/` es generado y esta ignorado por Git. `stable` contiene el bundle, cargador, `chilli_loader.luau`, checksum y metadata de publicacion, sin las fuentes ni workflows.

## Detector

`Evaluate(records, directory, incomeFor, filters, rarities)` no usa Roblox directamente. La rareza es un minimo inclusivo: acepta el mismo ID o un Rank mayor o igual de Data.Rarity.Rarities. El quinto argumento es opcional; usa el registro ya cargado en search.modules o los metadatos Rank de Directory. Conserva validacion del ID seleccionado contra el catalogo. Rangos faltantes/no finitos para IDs diferentes producen datos pendientes. Recorre solo Slot y mantiene ingreso exacto, nombre literal, mutaciones y zonas exactas; devuelve mejor candidato, conteos y coincidencias. `count` abarca todos los Slot del mapa; `rarityCount` incluye los rangos que alcanzan el minimo dentro de las zonas elegidas, aun si fallan ingreso, nombre o mutacion. `RarityMatches` comparte esa regla con los controles de rareza y Explain.

`Decide(match, info, cycle)` devuelve `match`, `loading`, `hop` o `wait`. Ademas de la presencia local, conserva una observacion de la rareza seleccionada para continuar cuando falta en otro servidor. `Scan()` obtiene snapshot y calcula datos con los modulos reales, evitando noche y snapshots pendientes. Un fallo de datos espera; si el ciclo cambia durante el scan se descarta esa lectura.

`chilli_egg_search_cycle.json` guarda version2, rareza, zones normalizadas, periodIndex, nextReset, periodSeconds, nightSeconds, seenAt, untilTime y, `best` (key, name, category, rarity, income, area, nest, scale, mutations, baseMutation, job, at: mejor huevo del ciclo con rareza >= minima en las zonas elegidas, solo sube de ingreso) y, tras un match, `matched` (job, key, name, at, captured, capturedAt). `search.BestSeen(cycle)` devuelve una copia de `best` solo si la ventana es vigente. Al cerrar la ventana por expiracion, `chilli_egg_search_previous.json` (version2: `history`, lista de {rarity, zones, periodIndex, best}, mas reciente primero, un registro por ciclo y alcance, maximo 30; la version1 de un solo registro se lee como primer elemento) conserva el mejor. `search.BestHistory(cycle, limit)` devuelve {best, age, periodIndex} de los ciclos terminados con la misma rareza y zonas; una ventana vieja sin archivar se suma y, si es del mismo ciclo, gana el mejor ingreso. `search.BestPrevious(cycle)` es su primer elemento (copia, ciclos de antiguedad), sin limite de antiguedad. API: `ChilliEggSearch.BestHistory(limit)`. Cambiar rareza o zonas cierra la ventana sin archivarla. La ventana termina al empezar la noche siguiente (`nextReset - nightSeconds`). Cambio de rareza o conjunto de zonas cierra la memoria antes de aplicar la configuracion; si falla ese guardado, no aplica el nuevo filtro. Periodo/overrides distintos, datos futuros/corruptos o expiracion tambien la invalidan. La version1 global se descarta porque no demuestra presencia en las zonas actuales. Un reloj desconocido/pausado espera; cambiar minimo/nombre/mutacion conserva la observacion de la misma rareza y zonas. El guardado usa la persistencia verificada existente y no se repite en cada poll. `GetStatus().searchWindow` devuelve una copia profunda de lo guardado; su existencia no demuestra vigencia ni presencia actual.

La cache de analisis incorpora el ciclo para no trasladar decisiones entre periodos sin senal de renovacion. La informacion de scan incluye el reloj capturado antes de leer los records; Decide rechaza un snapshot del periodo anterior. El panel distingue busqueda vigente sin rareza local de espera inicial.

El runtime coordina AUTO, revisa otra vez antes del teleport y conserva estado entre servidores. Un teleport ya enviado no se puede retirar; la decision nueva se aplica antes del siguiente intento y al llegar al destino. La observacion del ciclo recuerda el minimo seleccionado aunque el spawn observado sea superior; no requiere migrar la configuracion ni la ventana persistida.

Antes de la primera decision de cada sesion/ciclo, Scan espera game:IsLoaded(), una lectura valida, 3s sin cambios de inputs Slot/catalogo ni revision y, ademas, snapshot completo (todas las zonas, sin Uid del periodo anterior) o minimo 10s desde esa lectura. Compara copias para detectar cambios en el mismo record. Hasta validar, ready=false y no devuelve candidato confirmado, aunque exista memoria de busqueda. Los analisis cacheados se mantienen separados: se clona info antes de aplicar la barrera. Tras validar no demora cada poll. Noche/reset, cambio de ciclo/overrides/modulos, snapshot ausente o error de datos reinician la barrera; Scan(true) no la evita. El tiempo de carga usa os.clock(), sin sustituir el reloj del ciclo del juego. La estabilidad es una precaucion y no una señal explicita de completitud si una replicacion parcial queda detenida durante toda la ventana.

## API publica

```lua
local finder = getgenv().ChilliEggSearch
finder.Configure({
    rarity = "Divine", minIncome = 7000000000,
    nameContains = "", mutation = "", zones = {"Enchanted Forest"},
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

`ResizeGrip` (esquina inferior derecha de Holder) se crea despues de registrar las superficies de arrastre y cancela cualquier arrastre pendiente: redimensiona sin mover. Cambia `UIScale` `UserScale` de Holder con `support.ResizeHopperScale` (eje dominante, 0.75-1.75, limite de pantalla segun el tamano expandido) y compensa X por el AnchorPoint centrado. La escala se guarda como `scale` en `server_hop_button_ui.json` al soltar o perder foco; `support.HopperScale` la restaura y descarta valores invalidos.

El Egg Finder recibe `context.scaling` (`support.DragScale`, `support.PanelScale`). Su `ResizeGrip` (ZIndex 5, bajo las hojas de ZIndex 50) guarda la escala elegida como `scale` en `chilli_egg_panel_ui.json`; `fit()` aplica `PanelScale(elegida, limite de pantalla)` a `ResponsiveScale` y reajusta la posicion. `GetStatus` expone `scale` efectiva y `userScale`.


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

El soporte del runtime es el modulo `server_support.luau`. `ci_tests.luau` lo carga con `require("./server_support")` para ejecutar casos de almacenamiento, paginacion y teleport con dependencias simuladas, sin ejecutar Roblox ni Chilli.

## Modulos del hopper (2026-10-14)

`montarHopper` crea la sesion y conecta los modulos en este orden:

1. `createServerPool` antes de la GUI: restaura la cookie del dispositivo y el cursor Best Ping. Recibe la sesion como funcion porque se crea despues.
2. `mountHopButton` monta la tarjeta. AUTO, `busy` y las decisiones siguen en el runtime; la tarjeta recibe `isAuto` y expone `SetLabel`, `SetStatus`, `SetBusy`, `PaintAuto`, `Save` y `DraggedRecently`.
3. `mountAccountPanel` despues de crear `ChilliEggSearch`: agrega `OpenServerAccount`, `CloseServerAccount` y `ServerAccountStatus`. Conecta, recuerda u olvida la cookie solo con `pool.Verify/Remember/Connected/Forget`.
4. `mountEggFilterPanel`, `pool.RestoreReserve()` y, al final, `pool.StartRefresher(isBusy)`.

`session.Destroy` llama a `pool.Destroy()`, que invalida la generacion de credencial y borra la cookie de memoria.

Los guardados verifican un temporal y el archivo final y conservan la version anterior valida en `.bak`. La lectura recupera esa copia si el principal es invalido y conserva una cache en memoria; sus consumidores reciben copias. No se promete rename atomico: se usan readfile/writefile del executor. Si no se puede guardar el estado pendiente, no se envia el teleport. El historial elimina entradas vencidas y limita a 500 las anteriores al nuevo registro.

Cada intento posee conexion de fallo, destino, jugador e ID. Un error inmediato se procesa sin esperar el timeout. Un intento sin confirmar conserva `pending/unconfirmed`; AUTO sigue observando el mapa pero no envia otro salto hasta una llegada confirmada o un clic manual en Server Hop. Reejecutar en el mismo servidor no equivale a llegar al destino. Stop/destruccion limpian conexiones; un teleport ya enviado no se puede retirar. Durante renovaciones se observa ese intento y antes del siguiente se repite la decision con datos nuevos.

Los intentos guardan tambien originConnection. El ID del entorno del cliente permanece durante reejecuciones y cambia al reiniciarse ese entorno. `TeleportDisposition` distingue llegada, reconexion al origen y reejecucion en la misma conexion. Tras reconectar al origen se espera snapshot/reloj antes de cerrar pending; el registro se vuelve a comprobar para no borrar un intento nuevo. Si no se demuestra la conexion nueva se mantiene el bloqueo. Se conserva AUTO y la ventana de busqueda, sin instalar una reconexion ni interceptar expulsiones.

La API agrega `Presets()`, `SavePreset(name, config)`, `LoadPreset(name)`, `DeletePreset(name)`, `Alerts()`, `ConfigureAlerts({notification, sound})` y `TestAlert()`. Los presets guardan filtros exactos, hasta 20 nombres. Cargar devuelve una configuracion validada sin aplicarla; el panel la deja pendiente de Aplicar. Las preferencias viven en `chilli_egg_preferences.json`; notificacion activa y sonido desactivado por defecto. Detalle muestra motivo de exclusion e ingreso sin abreviar.

Las consultas HTTP comparten una reserva entre sesiones, tienen espera acotada y descartan resultados de sesiones terminadas. Si el executor no puede cancelar un request que sigue vivo, la reserva se mantiene hasta que regrese para evitar consultas superpuestas. La busqueda recorre hasta cinco paginas; termina al conseguir al menos ocho candidatos, acabar el cursor o repetirlo.
