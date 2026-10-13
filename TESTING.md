# Pruebas y validacion

## 2026-10-12 - TP al huevo

Cuenta alterna (roblox_user_9492807460, WalkSpeed 18-19, Chilli descargado
en esa instancia para medir sin interferencia) y principal, sin hooks:
TP desde la base -> "Enter the gameplay area first" y luego derribado y
reaparicion; caminar o deslizar por la abertura y luego carry -> aceptado.
Saltos sueltos 10-90 studs se mantienen; 136 y 600 se revierten. Con carry
como prueba de confianza: 5x-30x WalkSpeed inmediato, 50x-80x tras ~1.7 s en
400-500 studs; 128x en 1600 studs -> "Movement is not currently trusted" y
reversion a los 8-10 s (las esperas de 1.5-2 s no bastan para saber).
Arnes generado del bloque del candidato: alterna base -> Titan Temple
(~4250 studs) en 19.1 s a 234 studs/s, 12 s sin reversion y carry de
verificacion aceptado (huevo soltado). Principal base -> Enchanted Forest
(~6200 studs) en 2.93 s y 2.73 s a 2500 studs/s, salida 0.2 s, sin
reversiones; despues Chilli movio el personaje (huevo no Eternal) y el viaje
termino sin pelear. Candidato completo cargado en la principal: AUTO activo,
`travel` enabled/idle, sin errores. Build y 213 regresiones (seis nuevas:
provisional antes de la barrera y sin provisional con insuficientes o
ausentes; velocidades, paso con tiron de frame, punto junto al nido y
reversion frente a movimiento ajeno). Un match real con robo de Chilli tras
el TP queda pendiente de que aparezca el objetivo.


Hops reales en la cuenta principal (variante de prueba fuera de Git que, sin
match, toma el mejor huevo de las zonas elegidas; registro en
`chilli_egg_travel_log.json` con marcas de tiempo y traza). Hallazgos por orden:
1) el compilador del executor rechazo el bundle por mas de 200 locales en un
ambito ("Out of local registers"), que el compilador oficial no detecto: el
bloque del viaje paso a su propio ambito y cada candidato se compila tambien
con `loadstring` en Potassium; 2) PathfindingService justo al llegar tardo
hasta ~7 s: salida recta por cruce aprendido (0.1 s; carry posterior
aceptado); 3) moverse durante la carga del mapa (1-7 FPS) termina devuelto al
punto de aparicion; 4) a ras de suelo, derribos junto a nidos (WalkSpeed 0);
5) a altura, 7 de 27 viajes atrapados junto a nidos de Cosmic y Cherry Blossom
(las areas de guardia cubren z -440..-288 en todo el pasillo). Con espera de
cliente listo, vuelo a altura y salida recta, 27 servidores: llegada en 17,
`moved` en 7 (todas por ese paso sobre Cosmic/Cherry Blossom), 1 reversion, 1
fallo y 1 huevo ya tomado; snapshot a +14.0-17.0 s del autoexec (mediana
14.8), personaje junto al huevo a +18.1-22.2 s (mediana 19.6), movimiento real
1.2-3.3 s (mediana 1.6) una vez listo el cliente. Match real visto en la
prueba: Skeleton Horse Eternal 15.42B/s en Light Dark, TP junto al nido en
0.32 s; la variante de prueba hizo hop a los 25 s sin captura de Chilli (fallo
de la prueba, corregido: la variante ya no salta con match ni Eternal+) y al
volver el servidor estaba lleno y el ciclo ya se habia renovado.


Carril de vuelo fuera de las areas de guardia (z < -440 o > -288) probado en
7 servidores: 6 terminaron `moved` porque junto a la salida el personaje fue
empujado contra x~555 (muros `LobbyBoundaries` que siguen fuera de la
abertura); se retiro y queda el vuelo directo a altura. Limitacion abierta:
pasar sobre Cosmic y Cherry Blossom puede dejar al personaje junto a sus
nidos; entonces el viaje termina sin pelear y queda Chilli. Build y 217
regresiones; candidato compilado con `loadstring` en Potassium.

Flujo real con el candidato de produccion (sin variante de prueba): filtro
del Egg Finder bajado temporalmente a Cosmic+ con minimo 1/s en las mismas
tres zonas. Match en el servidor actual (Astral Jackalope, Enchanted Forest):
TP junto al nido en 1.73 s. Tras un hop, match al llegar (Holy Peacock, Light
Dark) y TP junto al nido en 3.50 s. Filtro restaurado (Eternal >= 15B, tres
zonas). El robo de Chilli no se pudo provocar: sus filtros son Min Rarity
Eternal y Min Steal Value 797.34, y editar su archivo de configuracion no
sirve porque Chilli lo reescribe con lo que tiene en memoria; cambiarlo exige
su UI. El Skeleton Horse de 15.42B/s junto al que quedo el personaje no se
robo en 25 s; queda por comprobar si Min Steal Value lo excluye.

Robo de Chilli tras el TP (2026-10-13): la config de Chilli se escribio en
cada ingreso (antes de que cargue; editada mientras corre la reescribe) con
Min Rarity Cosmic y Min Steal Value minimo ("Common" no es opcion valida y
Chilli lo devolvio a Eternal); Egg Finder Cosmic+ temporal. Tras el TP
(3.5-3.9 s), Chilli robo y entrego huevos en dos llegadas (log "Area egg
claim" 06:00:39, 06:03:49 y 06:04:02), empezando unos 30 s despues del TP,
pero eligio otros huevos segun su Steal Priority (Highest Value) y no el
objetivo del TP. Otra llegada cayo en la noche. Filtro del Egg Finder y
config de Chilli restaurados y comprobados.

## 2026-10-12 - Captura tras un match

Evidencia real: match 22:55:59 UTC, AUTO de false a true 22:57:14 y 8 saltos
sin reporte. Log de Roblox: "Area egg claim" 7 s y 43 s despues de los dos
matches del dia, ambos huevos en `ReadOwnedEggs` del usuario con otro Uid y
la misma especie, semilla y escala. Senales observadas en vivo: Carried con
CarrierUserId, Dropped, GuardCarried y vuelta a Slot; entrega de otro jugador
con FieldGone y su registro (misma semilla) en el mismo frame, 11 s despues.
Build, siete compilaciones y 207 regresiones (tres nuevas, dos del PR
anterior reemplazadas; una existente ajustada: el match es observacion del
ciclo y un objetivo que sale del alcance sigue con hop): captura propia
guarda y espera hasta la noche (rejoin, insuficientes, sale de la base),
otro servidor hace hop, la noche repite; lo lleva otro -> espera, entregado a
otro -> 3 s de gracia y hop; Dropped/GuardCarried/Slot mantiene objetivo y
tiempo; 90 s -> hop; cargandolo sin limite y, perdido en el camino (guardia)
con el huevo aun ahi, otros 90 s y luego hop; objetivo mejor reinicia; duenos
ilegibles nunca lo dan por perdido; filtros subidos lo ignoran; guardado
fallido no oculta el match; reporte con matches/capture y cierre capturado.
Diez mutaciones fallan donde se espera. Potassium, instancia aislada en RAM
sobre datos reales (57 en campo, 4 propios, 80 de otros): Peacock real ->
match esperando captura; Skeleton Horse propio -> wait capturado (guardado);
Lamb de otro -> comprobando y a los 3.5 s hop "lo tomo otro jugador";
objetivo real de hace 100 s -> hop "no se capturo en 90 s". Bundle candidato
en la sesion del usuario: carga ok, AUTO activo en wait, filtros intactos.

## 2026-10-12 - Pool sin servidores que dejaron la lista

Build, siete compilaciones y 204 regresiones (dos nuevas): una pasada que
supera el rango+100 de un 1/7 sin listarlo lo quita, conserva el releido y el
que esta fuera de alcance, y el fin de lista quita el resto; el reporte
guarda intentos rechazados (10 max, ocupacion y antiguedad), destino con
`playing`/`listedAge` y `reloads` en otra sesion del mismo JobId sin contar
sondeos propios. Tres mutaciones fallan donde se espera.
Datos reales (registros sanitizados de 4 pasadas, sin consultas extra): el
rango cambia mediana 11, p90 147; 13/13 servidores 1-2/7 ausentes con margen
100 cerrados o con 3+ jugadores despues. Antes el pool ponia primero 1/7 de
147-162 s ya no listados. Candidato en la sesion del usuario: 16 lecturas
del stream sin filas que debieran salir, 739 retiradas, 20-30 opciones 1-2/7;
pool con 1/7 de 23 s y 2/7 de 8-38 s. Salto AUTO real con filtro temporal
imposible: beforeHop con playing=1 y listedAge=3, entro sin GameFull; se
restauraron filtros, memoria del ciclo y reporte desde copia al llegar.
GameFull provocado: con Auto Rejoin de Chilli apagado, 3/3 sin reentrada
(antes 3/4 reentraron al mismo servidor).

## 2026-10-12 - Reporte de busquedas

Build, siete compilaciones, 202 regresiones (cuatro nuevas) y diez Python
correctos. Nuevas: sin rareza en alcance no hay reporte; la busqueda sigue
entre sesiones (cada salto) con una visita por servidor, sin reescribir en
sondeos iguales, re-escaneo previo y destino, cierre por match con servidor
correcto; zonas excluidas no abren; cierre por noche y AUTO apagado; 30
busquedas maximo; diez candidatos por visita; loading no se registra. Tres
mutaciones fallan donde se espera. Potassium: instancia aislada con datos
reales genero una visita con readyBy=complete, 13/13 zonas, 65 spawns,
candidatos con ingreso exacto y motivo y beforeHop con destino. Bundle
candidato en la sesion del usuario: AUTO normal, sin avisos, reporte vacio
sin Eternal en sus zonas.

## 2026-10-12 - Memoria del ciclo entre servidores

Dos regresiones nuevas (198 en total, siete compilaciones y diez Python
correctos): una busqueda guardada con nextReset 300.001357 continua en un
destino con 300.000655 (hop, continuingCycle, memoria conservada) y termina
con el periodo siguiente; 1.5 s de diferencia sigue cerrando la memoria. La
comparacion exacta anterior hace fallar la primera. Potassium: anclas reales
14180c80 (AnchorAt ...494.001357) y dd27b2e6 (...094.000655), mismo periodo.
Instancia aislada con memoria en RAM sobre datos reales: memoria del otro
servidor -> mode=hop, continuingCycle=true, ventana conservada.

## 2026-10-12 - Chilli con espera al juego y arranque del hopper

Autoexec local de Chilli cambiado (autorizado por el usuario) a esperar
game.Loaded, el personaje y ReplicatedStorage.Shared; original en
backup_autoexec/chilli.luau.2026-10-12-antes-espera. 30 saltos, 27 llegadas
distintas: 0 servidores rotos (Assets carga, 0 "Shared is not a valid
member", 0 fallos del Kernel), Chilli presente en todas a ~7-11 s. Antes:
~7 rotos en ~45 llegadas. Una llegada sin hopper: "attempt to index nil
with 'UserId'" porque montarHopper leia LocalPlayer.UserId antes de su espera
de carga; la espera de Chilli adelanto el arranque del hopper. Corregido
moviendo la espera de juego y LocalPlayer al inicio. Build, siete
compilaciones, 193 regresiones y diez Python correctos.

## 2026-10-12 - Servidores con modulos rotos

Build, siete compilaciones, 193 regresiones Luau (tres nuevas) y diez Python
correctos. Nuevas: dos fallos cacheados tras la carga marcan roto, Decide hop
sin escribir la memoria del ciclo y Scan informa el motivo; errores
transitorios, previos a la carga o no consecutivos no marcan; la racha cuenta
servidores, ignora reejecucion en la misma JobId, espera con el cuarto, se
reinicia tras 600 s y al cargar bien. Tres mutaciones fallan donde se espera.

Potassium: LogService de un servidor roto muestra en el mismo instante
"Shared is not a valid member of ReplicatedStorage" en EggState, Guards,
Gears, LimitedEgg, ScrambleTradeIn y "UI/World is not a valid member"; el
Kernel del juego falla 7 s despues con modulos ya rotos. Copias de Areas y
Assets cargan bien tras la carga. Frecuencia: 5/17 llegadas en una tanda,
1/17 en otra. Bundle candidato ejecutado en dos servidores rotos reales con
AUTO: mode=hop a 2.1 s y teleport, racha 1 y 2, destino final sano.

## 2026-10-12 - Barrera rapida con snapshot completo

Build, compilacion de siete entradas, 190 regresiones Luau (ocho nuevas) y
diez Python correctos. Nuevas: campo completo listo a 3 s (no 2.99) con
readyBy=complete; cambio Slot reinicia la ventana; zona ausente, AreaId
desconocido o nulo esperan 10 s (readyBy=timer); registros retirados por
reclamos siguen completos; registros nocturnos de una zona no usan el atajo;
Uid del periodo anterior (lote entero o un superviviente) obliga a 10 s hasta
el siguiente lote nuevo; llegada con busqueda guardada salta a 3 s con
continuingCycle; match solo tras la ventana. Tres mutaciones temporales (sin
comprobacion de Uid viejos, sin atajo, conteo de zonas relajado) hacen fallar
la prueba prevista.

Potassium, cliente real, sin teleports, sin GUI ni entradas simuladas:
sonda pasiva de senales EggState durante tres resets. Al empezar la noche se
retiran los 65 registros; ~2 s despues del inicio del dia llega un solo
FieldRefreshed con 65 registros nuevos, 13 zonas x 5 nidos. Despues solo hay
cambios de juego (FieldShifted de jugadores, un FieldGone a mitad del dia
deja una zona con 4). Version publicada en el mismo servidor: estable=0.0/10.1,
8.0/11.0 y 7.1/10.1 s. Instancia aislada del detector candidato (config real
Eternal>=20b/tres zonas, escrituras en memoria, Dispose al terminar): lectura
inicial lista en 3.03 s y lote de reset listo en 3.04 s, ambos readyBy=complete.
A/B con saltos reales autorizado por el usuario (API Hop, sin clics
simulados): en cada llegada la sesion publicada carga por autoexec y en
paralelo una instancia aislada del candidato lee los mismos datos. Nueve
llegadas validas: candidato listo en 3.01-4.30 s (media 3.39, siempre
readyBy=complete), publicado 10.08-10.49 s (media 10.24). Misma decision
(wait) y mismos conteos en 9/9; ningun cambio de decision del candidato en
los 12 s posteriores (8/8 vigiladas). Linea de tiempo de una llegada: ~65
FieldShifted con HasFieldSnapshot=false a +0.5 s, un unico FieldRefreshed
con los 65 registros a +3.6 s y ningun cambio despues en 25 s.

Tres llegadas excluidas: el juego no cargo (modulos con error). Se atribuyo
primero a una sonda, pero el mensaje "Requested module experienced an error
while loading" ya indicaba un fallo anterior; ver la entrada de servidores
con modulos rotos. Las sondas igualmente esperan juego cargado.

## 2026-10-11 - Eficiencia del finder y del hopper

Build, compilacion de siete entradas, 182 regresiones Luau (seis nuevas) y diez
Python correctos. luau-analyze sobre los modulos editados da los mismos avisos
que main. Nuevas: razones de filas iguales a Explain y tras cambiar Rank,
rareza minima sin distinguir mayusculas, semantica de SameRecord (NaN, claves,
anidadas, userdata), diagnostico de estabilidad sin acortar la espera, memo de
visitados igual a PruneVisited con relectura solo en limites y .bak con bytes
previos sin recodificar. Dos mutaciones temporales (memo sin entradas futuras,
.bak recodificado) hacen fallar sus pruebas.

Benchmark local con CLI Luau 0.741 -O2, snapshot de 100 records/65 Slot,
150 especies y 15 rarezas; tiempos del CLI, no del cliente: AUTO 0.50 a
0.28 ms, panel 1.96 a 0.83 ms, Scan(true) 0.67 a 0.39 ms, Store.Write de 500
visitados 0.41 a 0.25 ms y consulta de visitados 0.37 ms a memo. Pendiente en
Potassium: montaje, AUTO con hop real, log `estable=`, panel abierto con AUTO y
GetStatus().stats.

## 2026-10-11 - UI sobria del boton y del panel

Build, compilacion de siete entradas, 176 regresiones Luau y diez Python
correctos. luau-analyze sobre los modulos editados solo reporta globals de
Roblox. Sin regresiones nuevas: no cambia ninguna decision del detector.
Geometria revisada por calculo (anchos de columnas, filas y textos), no en
pantalla. Pendiente en Potassium: montaje expandido/plegado, tween del plegado,
arrastre desde AUTO/plegado/estado, hojas con velo (tocar fuera cierra),
pestanas Todos/Cumplen con conteo, insignias de motivo, colores de rareza en
texto enriquecido, detalle, presets/alertas y LeftAlt. Validar clics a mano.
El usuario probo el preview publicado en la rama y aprobo abrir el PR, sin
detallar que puntos reviso.

## 2026-10-09 - By Mistake

Build/compilacion siete entradas/176 regresiones Luau y diez Python correctos.
Detector Impeccable sin hallazgos. Potassium monta la candidata con una GUI,
sesion anterioralive=false/conexiones0,Chilli reutilizado y config/AUTO activo/
JobId/panel cerrado iguales. Firma de pantalla visible; credito plegado210x60
cabe sin recorte. Layout expandido340x114 probado con el helper de las fuentes,
sin disparar conexiones ni inputs; credito visible/no solapa estado/texto cabe.
Capturas privadas de ambas vistas inspeccionadas; se eleva la marca de pantalla
para dejar libres timers. Posicion y plegado originales restaurados,sin guardar
preferencias de prueba. Primera sonda auxiliar omitio ARROW_UP/DOWN y fallo;
se corrigio/retiro y la comprobacion afectada paso. Sin pruebas nuevas del
detector porque no cambian decisiones. iPad real no comprobado en esta tarea.

## 2026-10-09 - Hop solo por presencia en zonas elegidas

Build y compilacion de siete entradas correctos;176 regresiones Luau y diez
pruebas Python pasan. Diez regresiones nuevas verifican Lava Dragon/Volcano
con el ingreso observado102014590 y con99b, cada una de las tres zonas,
mapa mixto, continuidad tras hop con el mismo alcance, cambios de zonas sin
scan intermedio, Todas, reordenacion/deduplicacion, copia de memoria,
migracion version1, memoria ajena/malformada y errores al cerrar la ventana.

Potassium ejecuta el detector exacto aislado con catalogos/rangos reales:
17 comprobaciones pasan. Volcano devuelve wait/rarityCount0; un record
controlado en zona elegida devuelve hop con19999999999 y match con20000000000.
Snapshot real65Slot coincide con conteo independiente de zonas:0rareza/0matches.
No se inyectan records en EggState ni se envia teleport; filtros/AUTO/JobId
del finder activo intactos. La prueba no demuestra un nuevo hop real.

Montaje del bundle candidato conserva config/AUTOapagado/JobId/apertura;
unaGUI/unpanel, sesion anterioralive=false/cero conexiones y Chilli reutilizado.
La barrera inicial vuelve a esperar un snapshot estable; autoexec sin cambios.
Publicacion pendiente: un hop con el cargador main vuelve a la version anterior.

## 2026-10-08 - Tarjetas con zona, rareza e ingreso combinados

166 regresiones Luau y compilacion de siete entradas pasan. Casos agregados:
Enchanted Forest/Eternal/10b rechaza Common99b, Eternal9999999999 alli y
Eternal99b enForest; acepta Eternal exacto y Divine superior. MapSnapshot
marca solo la interseccion y comparte sus resultados con el detector.

Potassium: 28 comprobaciones aisladas, catalogos/rangos oficiales y guardado
en memoria. Mapa muestra cinco spawns controlados con dos CUMPLE, sin checks
ni resaltado en los otros. Aplicar activa/persiste Solo filtro y deja solo dos;
si bajan del minimo, lista vacia. Trece checks de zonas conservados. Lectura
real65 Slot/cero coincidencias. No se insertan records en EggState, no se
simulan entradas/conexiones, no se activa AUTO ni se hacen teleports; filtros,
AUTO apagado y JobId reales intactos. Evidencia privada en
verification/zone-conjunction-smoke-report.json fuera de Git.

## 2026-10-08 - Minimo visible 10b corregido y cargado

Usuario reporta 10b mostrado como 1e+01b. FormatMinimum probaba primero
una cifra significativa con %g, que usa notacion cientifica para 10.
Ahora omite candidatos abreviados con exponentes y aumenta precision hasta
encontrar texto decimal que vuelve al mismo numero exacto al parsearlo.
10b/100b/500k/10m/10t/10q/1000q quedan en notacion decimal; el fallback
numerico para valores extremos permanece. No cambia ingreso ni deteccion.

Correccion en verification/zone-filter (la raiz antigua no contiene este
formateador). Build/compilacion y 164 regresiones correctas, incluidos
9999999999/10000000000/10000000001 y roundtrip exacto. Bundle 231438 bytes,
SHA256 48fcb711b15bed5729e41dfb0cd28b300f90d5bb70da912efeab244db4338e0a.

Potassium confirma antes 1e+01b y despues 10b, valor 10000000000 intacto.
Conservados Eternal, nombre/mutacion, cuenta guardada, AUTO apagado y JobId.
Una GUI/una EggFilterPanel, conexiones anteriores retiradas y Chilli
reutilizado. Panel abierto para probar; 13 zonas disponibles. El cliente
habia vuelto a la version publica tras cambiar de servidor: se recargo la
candidata con zonas y formato corregido. Autoexec intacto; main/stable sin
publicar. Evidencia privada: verification/minimum-format-live-report.json.

## 2026-10-08 - Candidata por zonas cargada en Roblox local

Usuario solicita cargarla para probar. Ejecutado el bundle de
verification/zone-filter, fuente 06536a8, 231406 bytes/SHA256
dd16a5af4846dca238354f8841afd79d4c584ac1dbf2e43c5538b0f15ac35123,
desde el workspace del executor. Version antigua retirada: alive=false y sus
30 conexiones desconectadas; una GUI/una EggFilterPanel, Chilli reutilizado.

Panel abierto en Elegir zonas: 13 opciones oficiales/13 filas con checks.
Filtros Eternal >=10B/s, mutacion/nombre, AUTO activo, visual pets y cuenta
configurada/recordada conservados; zonas sin restriccion inicial. Detector
listo en wait, panel sin error y mismo JobId. No se seleccionaron zonas ni
se forzo teleport. AUTO y los clicks de prueba quedan a cargo del usuario.

Autoexec intacto, SHA256
66cf4b731ee1277dd5f8fa1788c615d09a0de78b1f010d589a2231f21b01e11c.
Main/stable siguen sin publicar el filtro: al reconectar/saltar el cargador
habitual recupera la version publicada anterior. Archivo local de candidata
sae_zone_filter_dd16a5af.luau fuera de Git. Evidencia privada:
verification/zone-local-load-report.json. Prueba tactil/iPad pendiente.

## Filtro por zonas verificado (2026-10-08)

La candidata `verification/zone-filter`, rama `codex/filtro-zonas`, parte de
main `599f6c6` y conserva la reserva adaptativa/cuenta/teleports publicados.
Build y compilacion de las siete entradas pasan; 163 regresiones Luau y diez
Python correctas. La raiz anterior conserva sus cambios pendientes y pasa
72 regresiones; no distribuir su bundle antiguo en lugar de la candidata.

Casos nuevos: 13 opciones con orden/nombres oficiales, Forest frente a
Enchanted Forest con la misma especie, multiples zonas, ausencia de
restriccion, ingreso exacto/nombre/mutacion, Slot, zona ausente, persistencia y
copias aisladas, JSON/presets antiguos, IDs/listas invalidas, cache invalidada
por AreaId/configuracion/catalogo y Divine valido con minimo Eternal.

Potassium Windows: 34 comprobaciones aisladas con fuentes de la candidata y
modulos reales. Trece filas/checkboxes, nombres y orden reales, borrador vacio
rechazado, aplicar solo Enchanted Forest, check Forest apagado, restauracion
al remontar, Todas, limites a UIScale 0.7 y una GUI de prueba tras recarga.
Snapshot real de 64 Slot comparado con calculo independiente: cero candidatos
del filtro probado. Coincidencias controladas con especie/rango reales no se
inyectaron en EggState. Configuracion real Eternal >=10B/s, AUTO y JobId
intactos; cero teleports, UI/archivos de prueba retirados. Guardado y relectura
en archivo temporal del executor tambien comprobados; no se tocaron cookies
ni autoexec. Checks por API, sin clicks/teclado simulados.

No se ha observado un huevo real Eternal/Divine que cumpla ni probado el gesto
tactil/iPad. La seleccion vacia se puede corregir con Todas o eligiendo zonas.
Fuentes y evidencia privada en verification/; main/stable aun sin publicar.

## Reposicion adaptativa y salto de respaldo (2026-10-07)

Montaje adaptativo real reutiliza Chilli, destruye sesion anterior y conserva AUTO/cuenta/filtros. La pasada continua paginas6..10:8 opciones antes de continuar y21 al terminar el bloque; comprobacion pagina9 confirma15 vigentes/cero duplicados/cero vencidos. La reserva es un maximo24, no una cantidad garantizada si Roblox ofrece pocos candidatos.

149 regresiones Luau/diez Python y compilacion pasan. El caso de stock escaso ahora verifica continuidad pagina6, limite12/180s y vigencia individual. Tres casos nuevos prueban reserva24 encontrada en pagina6 tras Restore, stock suficiente que termina a5 paginas/75s e interrupcion larga que vuelve a cabeza. Hop real API hacia ace56edf-d55a-41ce-8cd1-086a03b9c6ea anunciado2/7: pendiente en21.8269ms sin HTTP previo adicional, llegada exacta/autoexec/cuenta/AUTO/Eternal>=7B intactos. Ocho muestras independientes de Data Ping: mediana56.3193ms, cuatro jugadores al medir. No garantiza ocupacion o ping futuros. Reserva anterior descendio a1..6 en prueba prolongada, justificando la extension adaptativa. Sin inputs GUI sinteticos.

## Balance cantidad/calidad (2026-10-07)

Build/compilacion146 regresiones Luau/diez Python. Doce casos nuevos cubren prioridad1/7->2/7, orden nativo/recencia, limite24/frescura1=180/2=90, politica/transporte, cold start sin espera global, Seed, refill por stock<16/60s desde cabeza, continuidad de filas1/7 anteriores de rango anterior mayor al de la pasada nueva, restore/migracion, errores/autenticacion, cancelacion y presupuesto maximo de5 paginas/75s sin perseguir candidatos de menor prioridad indefinidamente. Muestra real previa3/1 y190/2; montaje candidato en Potassium paso de0 listos a24 respaldos2/7, conservandoAUTO activo/Eternal>=7B/cookie/JobId, sesion anterior terminada y Chilli reutilizado. Reejecucion real recupero24, volvio a cabeza de lista y descarto una entrada2/7 de97s; controles/config/cookie intactos. Hop/publicacion se registran en WORKLOG al comprobarse. No entradas simuladas ni conexiones GUI disparadas. No se afirma ping numerico previo al ingreso ni deteccion de un huevo real que cumpla7B.

## Reserva rapida BestLatency (2026-10-07)

Build/compilacion y 134 regresiones Luau pasan; diez Python tambien. Nuevos casos alcanzan pagina16 despues de 180s sin reiniciar; verifican reserva sin HTTP/orden nativo/frescura individual/exclusiones, publicacion incremental hasta ocho, grupos mayores/transporte incorrecto rechazados, cursor recuperado tras llegada, Seed inicial, lista completa consumida, cancelacion/progreso y cursor400 renovado sin inferir agotamiento. Potassium reejecuto candidato conservando Eternal>=7B/s/AUTO apagado, cookie restaurada, Chilli reutilizado y sesion anterior destruida. HTTP200/progreso real de consulta observado; salto y cache real siguen pendientes al escribir esta seccion. No se simularon entradas ni dispararon conexiones.

## Publicacion compartida solicitada (2026-10-07)

Usuario confirma **CUENTA GUARDADA** en Delta/iPad y pide usar main/chilli_hopper.luau en todos los dispositivos. Ese feedback implica consulta aceptada/escritura/relectura terminadas en el flujo; no se inspecciona su cookie ni se declara comprobada la continuidad entre hops o Redirect=false. Codigo de la candidata aprobado por CI run 37601500836: compilacion, 125 regresiones Luau, diez tests Python y artefacto. Actualizacion de documentacion para integrar PR #10; antes de afirmar publicacion, exigir CI del head final y del merge y verificar stable/version.json/checksum contra el bundle aprobado. Sin editar stable manualmente.

## Confirmacion de guardado (2026-10-07)

Refinamiento de feedback: confirmacion visible tras guardado/relectura, aviso distinto para sesion temporal, estado en launcher y reapertura, etiquetas de comprobacion. No cambia decisiones del detector ni persistencia. Build/compilacion y las 125 regresiones existentes pasan; confirmar manualmente mensaje en Delta despues de una consulta aceptada. El SHA antiguo del usuario no recibe modificaciones; probar el cargador de rama actualizable.

## Pausa inicial de Guardar y usar AUTO (2026-10-07)

Usuario observa el mensaje de pausa en Delta al pulsar Guardar y usar AUTO. No hay evidencia de HTTP 429 ni de autenticacion aceptada. Regresion reproducible del codigo: espera de 35s incompatible con cooldown de 60s. Build/compilacion y 125 regresiones pasan (117 anteriores + ocho nuevas): cooldown completo/restaurado, intervalo distinguido de 429, reintento espaciado, request pendiente/timeout sin desbloqueo falso, excepciones/errores al iniciar sin secreto, cancelacion antes de enviar, busy legacy tras reejecucion y finalizacion tardia que no libera otra reserva. Tiempo/scheduler inyectados, sin dormir ni cookies/red/teleports.

Formulario ahora prioriza comprobacion sobre prefetch, muestra contador/motivo y conserva borrador oculto si falla con ventana abierta. Delta debe confirmar la nueva comprobacion inicial y continuidad; no se declara corregida una causa interna del executor ni autenticacion real. Si request nativo sigue colgado, el texto pide reiniciar Roblox en vez de atribuirlo al rate limit.

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
