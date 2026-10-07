# Pruebas y validacion

## Cuenta propia y reapertura (2026-10-07)

Build/compilacion y 117 regresiones Luau pasan; diez tests Python del bridge siguen pasando. Nueve regresiones nuevas cubren formato de cookie, persistencia explicita por cuenta entre instancias, sesion sin guardado, borrado/fallo de disco, destino fijo Roblox/headers solo BestLatency, errores/redirecciones sin secreto, prioridad de ocupacion/orden nativo, lista parcial, cursor repetido/cancelacion y expiracion del catalogo.

Potassium monto el bundle candidato aislado en una GUI con nombre de prueba, getgenv y archivos simulados, request bloqueado y tareas propias suprimidas. Verificados entrada vacia/oculta, tamanos dentro del viewport a escalas 1 y 0.7, abrir desde identidad 2, cerrar/reabrir dos veces, launcher hijo del ScreenGui fuera de Holder, entrada en Opciones y desconexion de 30 listeners al destruir. Configuracion real Eternal >=7B/s, AUTO y JobId conservados. No se introdujo cookie real, ni se ejecutaron peticiones autenticadas/teleports/inputs sinteticos. Computer Use no conecto al pipe nativo; no se obtuvo captura visual. Esta prueba confirma montaje/API/geometria, no toques/paste/teclado iOS.

Prueba pendiente del usuario en Delta/iPad: cargar candidata y colocar esa misma linea en autoexec; cerrar/reabrir CUENTA / BEST PING; pegar cookie propia; Guardar y usar AUTO; observar consulta aceptada, decisiones usuales y reanudacion al llegar. No enviar cookie por chat ni leer campo/archivo con diagnosticos. Comprobar tambien Borrar cookie y desconectar y que no se retomen consultas. Redirect=false se solicita, pero el executor podria ignorarlo; no hay garantia de soporte en Delta. No publicar como soporte iPad confirmado antes de esa evidencia.

## Best Ping conectado y salto real (2026-10-07)

Build/compilacion y 108 regresiones Luau pasan; diez pruebas Python offline pasan y forman parte de CI. NativePool rechaza respuestas de otro hop/PlaceId, filas vencidas/reordenadas, errores y ocupaciones superiores sin prueba vigente. El proceso conserva cursor, deduplica, excluye visitados y determina el grupo minimo via OccupancyAsc sin requerir fin del stream BestLatency; pruebas cubren vencimiento/cambio de exclusiones/orden ascendente invalido.

Proceso local activo con cookie en TXT privado. Candidata instalada en workspace Potassium y autoexec local sustituido por lectura de ese bundle, original respaldado. Reejecucion: filtros Eternal >=7B/s y AUTO intactos, sesion anterior detenida y 23 conexiones retiradas; Chilli existente reutilizado.

RefreshServers recibio/persistio pool real orderBy=BestLatency, cuatro candidatos playing=1 y primer ID 01ab2d8f-2330-4047-b690-c12003ea206d. API Hop inicio teleport real y llego exactamente a ese JobId desde 452bc3ed-bc19-4eed-8672-65616180b403. Autoexec recargo BestLatency, pending=false, filtros/AUTO intactos, barrera de carga respetada y pool renovado excluyendo el destino. Medicion independiente despues de asentamiento: ocho muestras, mediana 70.2623 ms, tres jugadores al medir. No demuestra el minimo ping global ni ocupacion fija.

El primer auxiliar se detuvo antes del teleport porque contaba solo gethui; la unica GUI estaba en PlayerGui. Corregida comprobacion para contar todas las superficies sin duplicar parents, resultado una GUI. No se dispararon conexiones ni inputs sinteticos. No se borro consola. Pruebas finales del proceso/ocupacion agregadas despues del salto, bundle final recargado conservando estado y 23 conexiones retiradas.

Evidencia privada en verification/best-ping/connection-live-report.json del workspace principal, copias sanitizadas de los reportes de llegada y autoexec original en connection-backup. Best Ping esta activado solo en esta PC; no publicado. Progreso real a 2..6, Windows tras reinicio y otros dispositivos pendientes de prueba. El proceso se inicia otra vez al reiniciar Windows. Secciones siguientes son historial anterior a la conexion.

## Progresion por ocupacion entre hops (2026-10-07)

Aclaracion del usuario aplicada en candidata: ocupacion 1..6 antes de desempate; pool de un solo grupo y consulta nueva al agotarse. Cache de grupos 2..6 no se reutiliza sin consultar otra vez las ocupaciones menores. Build/compilacion y 102 regresiones pasan: cinco nuevas cubren todos los grupos, ocupacion invalida, bloqueo de avance con BestLatency parcial, agotamiento de ocho candidatos con un noveno de una persona pendiente y pagina inicial visitada antes de llegar al siguiente grupo.

Seis regresiones offline del probe cubren pagina parcial sin una persona, fin real, candidatos de una persona en pagina posterior/deduplicacion, cursor repetido, HTTP 429 y conteos invalidos. El reporte sanitizado indica complete/selectionReady/selectedOccupancy y no trata cursor repetido o error como fin.

Potassium ejecuto el helper exacto sobre los 488 candidatos sanitizados de la consulta previa: 3 con una persona, 97 con dos, 79 con tres, 62 con cuatro, 196 con cinco y 51 con seis. Todos los IDs coinciden con expectativa independiente agrupada 1..6 y orden nativo dentro de cada grupo. Pool parcial contiene solo los tres de una persona; retirarlos bloquea pasar a 2/7. Una simulacion marcada completa progresa 2..6. No es una comprobacion actual de disponibilidad ni un salto real. Filtros/AUTO/JobId intactos, cero teleports, sin cargar el bundle.

Evidencia privada: verification/best-ping/occupancy-result.json, occupancy-live-report.json, live-occupancy.luau y verify_occupancy.py del workspace principal. Fuente BestLatency aun no conectada al runtime; candidata sin activar/publicar, faltan persistencia de pool en cliente y ping tras salto real. Las secciones siguientes registran pruebas anteriores a esta correccion.

## BestLatency real autenticado (2026-10-07)

El probe privado de PC obtuvo HTTP 200 con la cookie del TXT .private, fuera de Git. Cinco paginas con 15s entre requests: 500 registros, 488 candidatos unicos, tres playing=1 en posiciones originales 22, 210, 259. El mismo RankServers(..., BestLatency) de la candidata se ejecuto aislado en Potassium con los 488 candidatos sanitizados: tres de una persona primero, orden nativo preservado dentro de los grupos y coincidencia con expectativa independiente en todos los IDs. Filtros/AUTO/JobId iguales, cero teleports, sin sustituir el finder ni enviar la cookie a Potassium.

Evidencia en verification/best-ping/authenticated-result.json, native-live-report.json y live-native-selection.luau del workspace principal. Todavia hay mas paginas; muestra limitada, no medicion de ping personal. Fuente nativa aun no conectada al runtime, que sigue usando LegacyPing. Bundle sin cargar/publicar, pool/persistencia y salto real pendientes. Esta prueba sustituye la limitacion de solo fixtures para el helper BestLatency; los fallos Guest/401 anteriores siguen siendo evidencia historica.

## Best Ping y una persona primero (2026-10-07)

Candidata aislada `codex/best-ping-un-jugador`, base main `6c996a1`: build/compilacion y 97 regresiones correctas, cinco nuevas sobre prioridad de una persona, desempates legacy, orden BestLatency sin usar FPS/ping, datos sin ping y conservacion de playing tras copiar la cache. BestLatency se prueba con fixtures, no con una respuesta nativa autenticada.

Se inspecciono el JavaScript publico ServerList de Roblox: la opcion usa `/v2/games/{placeId}/servers/Public` con `orderBy=BestLatency` y `sortOrder=Desc`. Potassium obtuvo HTTP 400/codigo 7/Guest users are not allowed para BestLatency y Recommended; OccupancyAsc respondio 200 con 100 registros playing=1. `game:HttpGet` devolvio vacio para BestLatency; HttpRbxApiService fue rechazado por el executor con dangerous call. No se intento eludir esa restriccion ni extraer credenciales. La opcion observada por el usuario esta en la aplicacion; no hay navegador conectado. No se comprobo la peticion de la interfaz nativa.

El mismo helper de la candidata se ejecuto aislado con listas v1 reales: 200 registros (100 con una persona y 100 con seis), 197 elegibles tras excluir actual/visitados, 97 con una persona antes de los otros 100. Top 8 solo playing=1. Filtros Eternal >=7B/s, AUTO y JobId conservados, cero teleports y sin reemplazar finder/GUI/autoexec. Primer muestreo recibio HTTP 429; se respeto el cooldown compartido y se repitio espaciando 15s. Evidencia privada en `verification/best-ping/report.json` del workspace principal y harness `live-selection.luau`.

Pendientes: lista BestLatency autenticada desde una via soportada, carga del bundle candidato y persistencia del pool en cliente, salto real y comparacion del ping medido tras llegada. El ping anunciado v1 no verifica el mejor ping personal. No se publico la candidata.

## Boton rojo movible (2026-10-07)

Build y compilacion de fuentes/bundle correctos: 61 regresiones en la carpeta de trabajo anterior y 92 en la candidata aislada sobre main `3407543`. No cambian decisiones del detector.

Potassium comprobo el montaje de la candidata: una GUI, seis conexiones anteriores desconectadas, 23 conexiones nuevas y listeners InputBegan en boton, texto, AUTO, plegado y estado. Filtros Eternal >=7B/s, AUTO activo, posicion, plegado y preferencias del panel conservados; panel sin error y Chilli existente reutilizado. Evidencia privada en `verification/movable-button-live.json`.

El usuario confirmo en Windows que ahora se mueve. Los listeners pasivos observaron MouseButton1 desde plegado/texto y cambios reales de Position; filtros Eternal >=7B/s y AUTO se conservaron. El reporte inicial del fallo tenia seis conexiones (version publica anterior), mientras la candidata tiene 23: el hop habia recargado el bundle sin publicar.

No se dispararon conexiones ni se simularon inputs. Siguen pendientes dedo/iPad, segundo dedo y todas las combinaciones de clic/arrastre mantenido. AUTO hizo hops naturales durante la prueba; el autoexec no se modifica. PR #9 prepara la publicacion del arreglo.


## UI integrada sobre build 21 (2026-10-07)

Build y compilacion de fuentes/bundle correctos; las 92 regresiones existentes pasan. No cambia la logica del detector/runtime. La candidata final mide 170351 bytes, SHA256 `27fed6f3dace4f99a5c7a9c48d9463b9ea0830a77f049ba6350da30481efa10b`.

Revisado visualmente en RobloxPlayerBeta/Windows mediante capturas: mapa, catalogo inclusivo, presets/alertas y modelos con UIScale 0.8 (432x560). Verificados mediante APIs del panel: rechazo de minimo invalido, conservacion exacta de 7b, seleccion/deseleccion, estado vacio de Solo filtro, guardar/cargar/aplicar/borrar preset temporal y cambiar/restaurar alertas. Se compararon 65 registros Slot con el conteo de tarjetas; el extremo de la lista solo contenia Slot y la lista mantuvo seis tarjetas renderizadas. Refresh repetido sobre el mismo snapshot no creo tarjetas ni modelos nuevos.

Scan/CycleStatus y APIs de abrir/cerrar/estado funcionan con identidad baja; reejecucion final conserva filtros, AUTO, visual, orden, Solo filtro y posicion, una GUI y ninguna conexion de la sesion original. Restauradas preferencias y archivos de la prueba, retirado el callback temporal de escalado. Un auxiliar recibio un error de identidad al editar un campo despues de GetStatus; se corrigio el auxiliar y se repitio, sin limpiar logs. No hubo errores propios de panel/runtime en esta pasada.

Las capturas/reportes se conservan en verification/ fuera de Git. Esta prueba confirma render y APIs en Windows; no automatiza clics, gestos o Alt fisicos, no equivale a una prueba de iPad y no induce teleports. La espera publicada en build 21 y la rareza inclusiva se conservan y siguen cubiertas por las regresiones.

## Espera de carga antes del hop (2026-10-07)

Doce regresiones adicionales usan un reloj inyectado: diez reproducen llegada con memoria y snapshot vacio temprano, huevos tardios, juego sin cargar, cambios con el mismo conteo o record, replicacion continua, scans frescos repetidos, perdida/error del snapshot, renovacion entre polls, revision del campo, catalogo/ingreso incompleto y exclusiones no Slot; dos verifican coincidencias superiores y continuidad de la rareza minima sin evitar la espera del destino. No duermen ni modifican un cliente real.

Potassium, cliente conectado de Windows: reejecucion con AUTO, primera decision a los 10,1s; salto automatico real con Common insuficiente despues de 10,1s; llegada con snapshot ausente y otros 10,03s desde la lectura valida (ready a 21,67s desde el autoexec), sin segundo salto. Coincidencia Common real con filtro temporal: AUTO se apago y se conservo el servidor. Renovacion natural: loading durante noche y snapshot pendiente, otros 10,08s tras los datos nuevos y wait en el mismo servidor.

Mapa/juego/scan/panel coinciden en 65 Slot en esa captura; una GUI, sesion anterior detenida y conexiones retiradas. API desde identidad 2 y panel sin errores. Restaurados filtros originales Eternal >=7B/s, AUTO y preferencias; autoexec original restaurado byte por byte, pending=false y monitores terminados. Una asercion auxiliar de apertura fallo al encontrar el panel cerrado durante la observacion; se corrigio a preferencias/estado del detector y paso, conservando logs. No se simularon inputs ni se forzaron kicks. La candidata de carga se probo sobre la base previa al cambio de rareza minima; iPad y Eternal/Divine >=7B real no verificados.

## Comprobacion local y CI

```powershell
.\.venv\Scripts\python.exe build.py
.\.venv\Scripts\python.exe ci_tools.py
```

Se compilan fuentes, punto de entrada, loader, tests y bundle integrado. El CLI oficial Luau 0.741 se descarga y verifica por SHA256. No se ejecuta el bundle de Roblox en el CLI; se ejecuta solo `ci_tests.luau` con un entorno controlado.

Las 92 regresiones incluyen los 68 casos anteriores del detector, filtros, caches, persistencia y soporte de teleport, 12 casos de rareza minima y 12 de carga/integracion. Se conservan sufijos y limites exactos, rarezas reales, Slot como unica fuente y rechazo de datos incompletos.

Los 18 casos adicionales prueban huevo robado/ausente tras observar la rareza, persistencia entre instancias, expiracion al inicio de noche y reset durante desconexion, cambios de filtros/rareza/overrides, reloj desconocido/pausado, memoria futura/corrupta, fallos al guardar, snapshots del periodo anterior y reset durante scan, sesiones destruidas, recuperacion por conexion nueva, timeout bloqueado, fallo de cierre de pending y cancelacion antes de enviar. Desconexiones/fallos se simulan con adapters offline; no se fuerzan expulsiones o fallos de red del cliente.

Al cambiar una decision o filtro, ampliar las regresiones con el caso que fallo. No agregar tests que se limiten a comparar lineas de codigo.

Los 12 casos de rareza minima cubren Eternal -> Divine en el limite exacto/insuficiente, mismo rango y superiores, exclusiones inferiores/no Slot, nombre/mutacion/especies, mayusculas e IDs mixtos, registro de Rank invalido o cambiado, selector y Explain, AUTO con el panel cerrado y cache invalidada, lectura fresca antes del hop, filas del mapa y continuidad de la observacion superior hasta la noche siguiente.

Validacion complementaria del 2026-10-07: build/compilacion y 80 regresiones locales correctas. Con Potassium se ejecuto el detector integrado sobre main como instancia aislada con startup desactivado y almacenamiento en memoria, SHA256 `50629f3f2102212ba8f2f31f9095e22a2a9b446bbbd35776085a64412400b381`. Pasaron 341 comprobaciones, incluidas las 324 combinaciones de las 18 rarezas reales. Eternal Rank 9, Divine Rank 10: Divine exacto 7B produjo match; 6.999.999.999 produjo hop. Se compararon 65 Slot reales e ingresos calculados por los modulos del juego; no habia Eternal/Divine ni candidatos >=7B en ese snapshot. Los casos Divine usaron registros/ingresos controlados con especies reales, sin inyectarlos en EggState. Filtros, AUTO y JobId del finder activo iguales antes/despues; cero teleports y sin sustituir el bundle activo. Esta evidencia no prueba render/clics del panel ni un spawn real Divine >=7B. Reportes privados fuera de Git.

## Smoke test real con Potassium

No usar entradas simuladas ni disparar conexiones de GUI en el cliente publico para pruebas: los logs nativos anteriores registraron expulsiones BAC despues de SendKeyEvent. La relacion temporal no demuestra por si sola la causa. Validar teclado/clics manualmente y revisar logs pasivamente; no interceptar kicks ni alterar anticheat. La continuidad por ciclo se verifica offline en esta publicacion, sin una nueva prueba de desconexion real ni carga automatizada en el cliente.

1. Obtener clientes actuales con `list_clients`; seleccionar el PID conectado.
2. Ejecutar el cargador y leer consola desde el cursor devuelto por `execute_script`.
3. Consultar `ChilliEggSearch.GetStatus()` y `PanelStatus()` sin cambiar filtros o AUTO. Verificar periodo, snapshot y ausencia de errores.
4. Comparar Uids de tarjetas con `ReadFieldEggs().Records` Slot. El catalogo solo aparece en el selector de especies.
5. Para cambios de UI, comprobar ingreso invalido, aplicar, cambios pendientes, selector multiple, minimizar/reabrir, dimensiones, imagen/modelo y persistencia.
   Para LeftAlt, comprobar cerrado -> abierto -> cerrado, Alt derecho sin efecto, cierre de popups y funcionamiento con un filtro enfocado. Reejecutar y verificar una sola GUI y una sola alternancia por pulsacion; conservar AUTO, filtros y la apertura anterior al terminar.
   Para el orden de tarjetas, comparar LayoutOrder con Rank descendente de Data.Rarity y el ingreso exacto descendente dentro de una misma rareza. Verificar Nombre A-Z como alternativa y que volver a Rareza y cerrar/reabrir conserve `sortBest = true`.
   Para el minimo, verificar `500k`, `25M`, `7b`, `7.5b`, `7,5B`, `1t`, `1Q` y `7` (7/s), edicion/reaplicacion de 6.999.999.999 y 7.000.000.001, y bloqueo de AUTO con entrada invalida. Leer el JSON guardado para confirmar que persiste el numero, no el texto abreviado. Comprobar que cada opcion de rareza tenga especies en Assets.Directory y conserve su Rank real. Al enviar fuentes desde PowerShell, leerlas con `-Encoding UTF8`.
6. Para cambios de ciclo/hopper, observar una renovacion real y comprobar el flujo sin Divine. Verificar server hop y restauracion por autoexec cuando ese comportamiento sea parte del cambio.

Usar los helpers de identidad antes de tocar CoreGui. `gethui()` puede devolver una GUI anidada. Tras un cambio de servidor, volver a listar clientes y verificar la nueva sesion.

No forzar una reconfiguracion del usuario solo para mostrar un resultado. Guardar y restaurar configuracion si una prueba necesita modificarla. El teleport real puede interrumpir una comprobacion en curso.

## Evidencia previa y limites

Antes de CI se compilo el script completo en Potassium y se verificaron 11 escenarios del detector. Se observaron reloj y renovacion reales, un hop real y restauracion por autoexec en una version anterior del hopper. El mecanismo se conserva.

El panel se verifico contra 65 Uids del mapa en una captura del cliente, con selector separado de 18 especies Divine, recursos oficiales y seis modelos 3D visibles. Estos son resultados de esa sesion, no cantidades fijas del juego. Se comprobaron controles invalidos, seleccion multiple, persistencia y limites de layout.

El cargador publico anterior se descargo anonimamente, coincidio por hash con el archivo publicado y ejecuto Chilli, detector y panel con una sola GUI. No se ha visto un spawn real Divine >=7B durante estas verificaciones.

CI valida el codigo propio y las decisiones simuladas. No prueba el render de Roblox, modulos que cambien en el juego, ingresos reales de un huevo al eclosionar, teleports ni el codigo externo de Chilli.

## Robustez, caches y opciones

CI agrega ingresos compartidos, recalculo fresco, invalidacion por mutacion/estado/renovacion, borrado de resultados viejos, motivos de exclusion, presets sin aplicar, recuperacion de backup, fallos de guardado, historial acotado, paginas/cursor repetido, resultados de sesiones canceladas, exception inmediata de teleport, fallos ajenos, timeout pendiente, cancelacion/conexion, llegada, persistencia obligatoria y reintento de modulos.

En Potassium verificar: total de filas igual a Uids Slot; instancias cercanas a la vista limitadas; mismas tarjetas tras un refresh sin cambios; scroll hasta el final y con UIScale menor que uno; orden de rareza/ingreso; Detalle exacto; modelos visibles sin recrearse al refrescar y destruidos al cerrar; recursos ausentes con imagen; presets guardar/cargar/borrar sin modificar filtros efectivos ni AUTO antes de aplicar; alertas y sonido de prueba; persistencia y una sola GUI/atajo/conexiones tras reejecutar.

Para hopper comprobar teleport real y restauracion por autoexec. Los fallos y timeouts se simulan con adapters para no forzar averias del cliente. Medir creaciones/caches y tiempos en snapshots listos; una medicion durante noche no sirve como referencia de rendimiento. Conservar y restaurar filtros, AUTO, visual, apertura y preferencias al terminar.

El coordinador AUTO usa AutoHopAllowed tanto al observar como al iniciar un salto. Las regresiones verifican que un timeout unconfirmed siga bloqueando nuevos saltos aunque pasen horas, que busy/bloqueo explicito se respeten y que la compatibilidad con pending anteriores conserve su espera inicial.

## Validacion de las mejoras del 2026-10-06

La candidata paso las 50 regresiones, incluidas modificaciones de records en el mismo objeto y cambios del catalogo. En Potassium se compararon 65 Uids Slot con el panel: 7 tarjetas renderizadas, 106 descendientes en EggCards, scroll inicial/medio/final y UIScale 0,65 correctos. Refresh conserva tarjetas y modelos; cerrar destruye los viewports. Se comprobaron orden por Rank/ingreso, Detalle exacto, Solo filtro e ingreso real usando los modulos del juego.

Presets guardar/cargar/aplicar/borrar, cambios pendientes, sonido cargado y preferencias persistidas pasaron. Una recarga con fuentes fijadas al commit conservo configuracion/preset/alertas, desconecto las conexiones antiguas y dejo una GUI. Alt izquierdo alterno una vez, incluso con un TextBox enfocado; Alt derecho no alterno y cerrar elimino el popup. Un panel aislado, con require de recursos opcionales fallando temporalmente, mostro 7 imagenes y recupero 7 modelos al reintentar; sus instancias y conexiones se limpiaron.

En un snapshot listo de 65 Slot, 30 Scan con los filtros originales Divine >=7B tardaron 2,96 ms, frente a 3,95 ms de la referencia anterior. La prueba con 7 Common seleccionados tardo 5,43 ms. Son observaciones de esta sesion y no garantias de FPS ni de coste para cualquier filtro. La referencia de 782 descendientes paso a 106 con la ventana virtual.

Una coincidencia real Common apago AUTO y conservo el servidor; se restauraron Divine >=7B y AUTO al terminar. La renovacion real paso de loading durante noche a un snapshot listo de 65 Slot, cero Divine y wait en el mismo JobId, con AUTO activo y revision de campo de 1 a 3. Los limites Divine justo bajo/igual a 7B se comprobaron con regresiones; no se observo un Divine real que cumpla.

El boton Server Hop envio un teleport real al candidato elegido. Autoexec cargo las mismas fuentes fijadas al commit de la candidata en el destino: JobId distinto, pending=false, snapshot listo de 65 Slot, cero Divine, wait y AUTO activo. Filtros Divine >=7B, preset temporal, alertas, criaturas, orden y panel cerrado persistieron, con una sola GUI. El preset temporal se borro y las alertas se restauraron. Los errores/timeouts y renovacion entre intentos se verifican por adapters en CI, sin inducir fallos reales del servicio de teleport.
