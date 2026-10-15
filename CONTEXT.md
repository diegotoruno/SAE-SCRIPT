# Contexto del proyecto

## Tarjeta flotante minima con la vineta de fondo (2026-10-15)

La vineta de los ojos arriba (completa o en franja) no le gusto al usuario;
eligio llevarla de fondo tenue de la tarjeta. Despues pidio quitar el plegado
y dejar solo el boton de AUTO y el contador: la tarjeta pierde el estado y la
firma By Mistake. El asa de tamano se conserva porque es la unica forma de
cambiar su tamano.

## Tarjeta flotante Server Hop con estetica de manga (2026-10-15)

El usuario conserva el diseno de Mistake Hub y pidio un diseno nuevo y
distinto para la tarjeta flotante del boton Server Hop, con estetica de
anime. Eligio panel de manga, paleta propia fija (no sigue el tema del hub) y
animaciones sutiles. Tras comparar con una version Gojo (vacio azul noche y
aro Six Eyes), se quedo con el panel de manga pero en tonos de Gojo.

## Estilo macOS del primer rediseno sobre el hub actual (2026-10-15)

El usuario prefirio el lenguaje visual del primer rediseno (vidrio
translucido con sombra, barra lateral a toda la altura con semaforo, filas
agrupadas con lineas finas, desplegables con doble chevron, segmentados,
interruptores y hojas con X circular) y pidio conservar exactamente las
opciones del hub de `main`. Tambien pidio: su imagen como icono del hub (en
lugar de la M), un boton minimizado con mejor aspecto y quitar del pie de la
barra lateral el estado de AUTO, su modo y la firma, dejando solo el TikTok.

## Mistake Hub con estilo macOS y temas (2026-10-15)

El usuario pidio redisenar el menu de Mistake Hub como una aplicacion nativa de
macOS (Finder y Ajustes del Sistema: barra lateral clara, acento azul,
SF Symbols, foco de teclado) y despues un modo oscuro completo con selector
Claro / Oscuro / Sistema, guardado y sin destello al cargar. Un primer intento
partio de un `main` local desactualizado (sin el hub, la calculadora ni el
boton M) y perdio opciones; el usuario confirmo que `main` actual tiene todas
las opciones correctas y pidio exactamente las mismas, dentro y fuera de los
menus: solo cambia la UI. Se rehizo sobre `main` 7fb7a44: mismas secciones,
textos, acciones y piezas flotantes (acceso rapido y boton M); el selector de
tema va en Ajustes > Apariencia. Roblox no expone la apariencia del sistema,
asi que Sistema sigue la hora local del dispositivo.

## Mistake Hub (2026-10-14)

Con la calculadora, el usuario pidio un hub llamado "Mistake Hub" que reuna
todas las opciones sin botones flotantes, con un diseno limpio y filtros
claros, inspirado en Chilli Hub. Aclaro que el unico elemento flotante sera el
acceso rapido de Server Hop, con una opcion para mostrarlo u ocultarlo. Se
inspecciono en solo lectura la GUI de Chilli (ventana central con barra de
titulo, pestanas laterales, secciones con interruptores, asa de tamano) y se
uso esa estructura con la paleta grafito/champan. Secciones: Egg Finder,
Filtros (con presets), Calculadora, Server Hop (con la cuenta de Best Ping) y
Ajustes. Se retiran los lanzadores flotantes "Egg Finder" y "Cuenta y Best
Ping". Detector, filtros guardados, AUTO, ciclo, teleports y API no cambian.

## Calculadora de ingreso (2026-10-14)

El usuario pidio una calculadora en el Egg Finder, tomando como ejemplo
eggipedia.com/calculator: cuanto da una mascota segun su peso y las
mutaciones que se le apliquen. Medido en el juego: las mutaciones se suman
(Golden + Rainbow = x5, Golden + Rainbow + Silver + Nitro = x6.95), una
repetida cuenta dos veces y el peso es `peso base x escala^3` en las 227
especies. La calculadora usa `AssetEarnings.MutationOnlyRatePerSecond` y
`EggRecords.WeightKgForScale` del juego, igual que el detector; no copia
tablas de la web. Solo informativa: no cambia filtros, Cumplen, hop ni match.
Sin el pase x2 ni boosts temporales (no verificados en el juego).

## Destino fallido al volver al origen (2026-10-14)

El usuario pidio evitar repetir servidores. Tras la noche cada servidor tiene
huevos nuevos, asi que repetir entre ciclos es valido (se descarto excluir
24 h, PR #39 cerrado). La repeticion real fue en un test de saltos manuales:
`4da6f5e2` cargo dos veces seguidas porque Roblox devolvio el cliente al
origen en vez del destino. El hopper ya lo reconocia como reconexion, pero no
marcaba el destino; ahora lo marca como visitado para no reintentarlo.

## Historial de mejores por ciclo (2026-10-14)

El usuario eligio, de las opciones visuales, un historial de los mejores
huevos de los ultimos 5 ciclos en vez de solo el ultimo, para calibrar el
ingreso minimo segun lo que aparece. `chilli_egg_search_previous.json` pasa a
version2 con una lista (un registro por ciclo y alcance, maximo 30); el panel
la muestra desde el detalle del huevo fijado en Cumplen. Solo informativo:
no cambia Cumplen, hop, match ni el aviso fijado actual.

## Cargador rapido de Chilli (2026-10-13)

El usuario ve la carga de Chilli como el mayor cuello de botella para robar
el huevo y pide que cargue lo mas rapido posible y sin errores. Medido en
Potassium: el dispatcher de Chilli ya no usa Luarmor para Steal An Egg; baja
un script Luraph de ~817 KB de Chilli-Hub-Script/StealAnEgg (lo actualizan
varias veces al dia) en serie despues de la carga, y ~1 s se va en
descomprimirlo. `chilli_loader.luau` adelanta ambas cosas a la carga del juego
y arranca Chilli con juego, Shared y personaje completos. Archivo propio,
publicado en `stable` por CI; el hopper sigue sin cargar Chilli. El usuario
pidio publicarlo para el iPad y los conocidos; Delta pendiente de probar.

## Tras un match, comprobar la captura (2026-10-12)

Reporte real: Skeleton Horse Eternal de 59.2B/s en el cuarto servidor; AUTO
se apago con el match, el huevo paso a la base del jugador 7 s despues y al
encender AUTO otra vez la observacion del ciclo hizo 8 saltos hasta la
noche. El usuario pide que, al encontrar uno, se compruebe si Chilli lo
capturo: capturado, esperar en ese servidor el nuevo ciclo con AUTO activo
(puede aparecer otro Eternal); no capturado, buscar otro servidor.

Observado en datos del juego: mientras alguien lo lleva el huevo sigue en el
campo con `State=Carried` y `CarrierUserId`; puede pasar a `Dropped` y
`GuardCarried` y volver a `Slot`. Al entregarlo sale del campo y aparece en
`ReadOwnedEggs()` del dueno con otro Uid, misma especie y `AssetColorSeed`.
Los dos matches del dia estan en la base del usuario (capturas a 7 y 43 s).

## Pool sin servidores que ya se llenaron (2026-10-12)

Primer reporte real (Eternal, 11 servidores): 4 de 15 teleports dieron
GameFull aunque la lista los daba con 1-2 jugadores, y 3 terminaron
reentrando al mismo servidor (~20 s cada uno). La reentrada era el "Auto
Rejoin When Disconnect" de Chilli: con la opcion apagada, 3 GameFull
provocados no reentraron. El usuario pide subir la certeza del pool para
evitar el error. Observado: el pool ponia primero 1/7 vistos hace 147-162 s
que la pasada mas reciente ya no listaba; los 1-2/7 cambian en menos de un
minuto. El reporte agrega intentos rechazados, ocupacion/antiguedad del
destino y recargas del mismo servidor para medirlo en busquedas reales.

## Reporte de busquedas (2026-10-12)

El usuario pide un reporte sencillo para revisar despues si el finder funciona
y si carga bien los datos antes de saltar, sin perder un huevo que cumpla.
Solo se crea al ver la rareza minima o superior en las zonas elegidas: primer
huevo, servidor, cada servidor visitado con prueba de carga, candidatos con
motivo, re-escaneo antes del teleport y resultado (match, noche, AUTO apagado).

## Memoria del ciclo entre servidores (2026-10-12)

Reporte del usuario: aparecio un Pegasus, AUTO salto y en el destino ya lo
habian tomado; AUTO quedo en wait en vez de seguir saltando hasta la noche o
una coincidencia. Causa: cada servidor ancla el mismo periodo con milisegundos
distintos (Workspace.AreaEggCycleAnchorAt; nextReset 1791796794.001357 frente
a .000655 con el mismo periodIndex) y la memoria exigia nextReset/untilTime
exactos, asi que se borraba al llegar. Ahora exige el mismo periodIndex,
periodo y noche, y tolera hasta 1 s en los tiempos.

## Salir de servidores donde el juego no cargo (2026-10-12)

Barrera rapida publicada en build58 (PR22, main cdf7411). El usuario reporta
servidores donde el juego no carga y pide una solucion del lado del hopper
para todos los usuarios. Causa observada en LogService: al llegar, un script
del autoexec (por el patron, Chilli cargado sin esperar) hace require de casi
todos los modulos antes de que replique ReplicatedStorage.Shared; Roblox
guarda ese fallo y el juego, Chilli y el detector quedan rotos en ese servidor.
Elegida la opcion de recuperacion: con AUTO, el detector marca el servidor como
roto y salta; tras mas de 3 seguidos en 10 min AUTO espera. La linea de Chilli
con espera al juego queda como recomendacion no aplicada.

## Barrera rapida con snapshot completo (2026-10-12)

El usuario pide ahorrar espera en cada servidor sin perder certeza sobre los
huevos escaneados. Medicion pasiva en Potassium: el campo llega en un solo
lote (al unirse y ~2 s despues de empezar el dia) con 65 registros, 5 nidos en
cada una de las 13 zonas y todos los Uid nuevos; despues solo hay cambios de
juego (huevos cargados/retirados). Los 10 s fijos eran tiempo muerto. Ahora,
si la lectura cubre todas las zonas oficiales y ningun Uid viene del periodo
anterior, basta la ventana de 3 s sin cambios; si no, se mantiene 10 s + 3 s.

## Eficiencia del finder y del hopper (2026-10-11)

El usuario pide revisar el hopper y el Egg Finder para hacerlos mas
eficientes; aclara que el hopper funciona bien y encuentra buenos servidores.
Se optimiza sin cambiar decisiones: deteccion, filtros, barrera de carga,
seleccion de servidores, reserva, reintentos y teleports quedan iguales. La
barrera de 10 s + 3 s domina el tiempo por servidor; solo se agrega una
medicion para calibrarla con datos reales antes de decidir si se acorta.

## Sin firma flotante (2026-10-11)

Tras publicar la UI sobria, el usuario ve la etiqueta By Mistake de la esquina
inferior derecha como un texto flotante y elige quitarla. La firma queda solo
al pie de la tarjeta del boton Server Hop, expandida y plegada. Reemplaza la
etiqueta de pantalla pedida el 2026-10-09.

## UI sencilla y elegante (2026-10-11)

El usuario pide mejorar toda la UI del boton y del panel del Egg Finder con un
estilo sencillo pero elegante, sin textos sobrepuestos y con mensajes y
filtros claros. El boton pasa a una tarjeta grafito con AUTO, Server Hop rojo
plano y plegado en una fila, estado en su propia zona de dos lineas y firma al
pie: el estado anterior pisaba el borde inferior del boton y no se recortaba.
El panel ordena filtros en columnas con etiqueta propia, resume los filtros
guardados, muestra Todos/Cumplen con conteo, motivo corto en cada tarjeta y
hojas modales con velo. Los mensajes del boton y del panel se reescriben en
frases completas. Detector, filtros, AUTO, ciclo, teleports y API no cambian.

## Mejor huevo del ciclo (2026-10-13)

El usuario pidio un recordatorio permanente del mejor huevo visto en el ciclo,
de la rareza minima seleccionada o superior, visible en la seccion Cumplen con
un mensaje explicito. Es el de mayor ingreso exacto entre los spawns Slot de
las zonas seleccionadas con rareza >= la minima, aunque no llegue al ingreso
minimo ni coincida con nombre/mutacion (esos filtros deciden la coincidencia,
no el recordatorio). Se guarda en la ventana version2 (`best`), asi que viaja
entre servidores, solo mejora y termina con la noche o al cambiar rareza o
zonas. Solo AUTO lo registra (Decide); no cambia ninguna decision de hop/match.
En Cumplen aparece fijado arriba con el aviso MEJOR DEL CICLO y donde esta:
en este servidor, ya no esta aqui u otro servidor. Mientras el ciclo actual no
tenga ninguno, se muestra apagado el ultimo visto en un ciclo ya terminado
(`ULTIMO DEL CICLO ANTERIOR` o `ULTIMO VISTO HACE N CICLOS · ya no existe`),
sin limite de ciclos: el usuario quiere que se quede hasta que aparezca otro
del alcance (la primera version solo conservaba un ciclo y el Skeleton Horse
se perdio). Solo informativo: mismo alcance de rareza y zonas, nunca cuenta en
Cumplen N ni decide hop/match, y lo reemplaza cualquier mejor del ciclo nuevo.

## Chilli separado del hopper (2026-10-11)

El usuario observa que la carga de Chilli incluida en el hopper a veces no
obtiene la version mas reciente y pide separar por completo la logica del
boton de la carga de Chilli. Decide sacar el cargador del repositorio:
`cargarChilli` (prefetch, arranque temprano, reintentos, filtro
`chilli_client.json`, aplazamiento por auto-test, `chilli_timing.txt` y
guardas `__CHILLI_LOADED/LOADING_JOB_ID`) se elimina de `hopper_runtime.luau`.
El hopper tampoco espera la UI de Chilli antes de precargar el pool. Chilli se
carga desde el autoexec con su linea original, que siempre pide su version
actual. Se conservan nombres historicos como `ChilliEggSearch`, archivos
`chilli_egg_*` y `__CHILLI_HOPPER_SESSION`: son API y persistencia del finder.
Detector, filtros, AUTO, Best Ping y cuenta no cambian.

## Firma visual By Mistake (2026-10-09)

El usuario pide una marca visual y tambien en el boton rojo expandido/plegado.
By Mistake aparece en una etiqueta pasiva grafito/champan cerca de la esquina
inferior derecha,sobre los timers del juego,y permanece con el panel cerrado.
El boton rojo incorpora una fila propia de18px:340x114 expandido,210x60 plegado.
No cambia filtros,AUTO,ciclo,teleports ni el codigo externo de Chilli.

## Hop limitado a las zonas elegidas (2026-10-09)

El usuario aclara que un Lava Dragon de Volcano no debe causar hop cuando
solo elige Titan Temple, Light Dark y Enchanted Forest. La presencia que
inicia la busqueda y su memoria se limitan ahora a las zonas seleccionadas.
Sin rareza minima en esas zonas ni evidencia vigente del mismo conjunto,
esperar; con un huevo de esas zonas insuficiente, hop; con coincidencia, quedarse.
La memoria version2 guarda zones; cambiar rareza o zonas la cierra, y la
evidencia global antigua se descarta. Cambiar ingreso/nombre/mutacion conserva
la observacion de la misma rareza y zonas hasta la siguiente noche.

## Coincidencias combinadas en el panel (2026-10-08)

Los checks pertenecen solo a las 13 zonas. Las tarjetas del mapa no seleccionan
pets ni alternan zonas al tocarlas: abren el detalle. Solo se resaltan como
CUMPLE cuando el detector confirma TODOS los filtros guardados: zona exacta,
rareza minima inclusiva, ingreso exacto, nombre y mutacion. Aplicar filtros
activa y persiste Solo filtro para mostrar unicamente esas coincidencias;
Mapa conserva la vista completa con FUERA para los descartados.

Ejemplo Eternal + Enchanted Forest + 10b: un Common de99b en esa zona, un
Eternal de9999999999/s alli o un Eternal de99b deForest quedan fuera.
Eternal de10000000000/s y Divine o superior que cumpla todo son validos.
Esperando Eternal+ indica ausencia de esa rareza, no una coincidencia.
Se mantiene el flujo acordado de esperar renovacion cuando no hay rareza ni
observacion vigente, hacer hop ante insuficientes y quedarse solo con match.

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

## Reposicion adaptativa de reserva (2026-10-07)

La prueba prolongada de build35 encontro pocas opciones en las primeras cinco paginas: reserva bajo de24 a1. Se amplia la pasada cuando hay menos16 destinos vigentes: continua el cursor nativo hasta12 paginas/180s, con maximo5 consultas por llamada. Con stock suficiente termina al presupuesto normal5 paginas/75s; con24 opciones nuevas o fin de lista termina antes. Frescura individual180/90s y prioridad1/7->2/7 siguen obligatorias.149 regresiones/diez Python pasan. Hop real de respaldo2/7 eligio destino en21.83ms sin HTTP adicional y llego al JobId exacto, conservandoAUTO/cuenta/Eternal>=7B; mediana56.32ms en ocho muestras y cuatro jugadores al medir. La ocupacion anunciada no es garantia al llegar.

## Balance para revisar mas servidores (2026-10-07)

Usuario prioriza encontrar el huevo con sus caracteristicas y pide balance cantidad/calidad. Autoriza expresamente 2/7 con buen ping cuando se agote la reserva rapida1/7, reemplazando la exigencia de probar ausencia global de1/7 antes de usar2/7 en DeviceCookie. Muestra real previa:3 candidatos1/7 y190 de2/7 recientes; ampliar solo1/7 no cubre cantidad. Reserva hasta24 con prioridad1/7, respaldo2/7 BestLatency, frescura1=180s/2=90s, refill al bajar de16 o respaldo>=60s desde primeras paginas. El limite inicial5 paginas/75s se reemplaza por la reposicion adaptativa anterior. Grupos3..6 mantienen prueba anterior cuando faltan1/2; bridge/legacy siguen reglas previas. Detector/filtros/ciclo/match intactos. Montaje y recarga reales preservanAUTO/Eternal>=7B/cookie y alcanzan24 respaldos desde cero destinos rapidos. Ver WORKLOG para publicacion/hop.

## Best Ping atascado y precarga rapida (2026-10-07)

Usuario confirma cuenta guardada en PC, pero Buscar queda en buscando Best Ping. Lectura real: DeviceCookie, HTTP200, lista parcial, cliente/snapshot vivos; no se observa crash de Roblox. Recorrido reiniciaba a los 180s, limitando paginas alcanzables. Usuario pide reserva de servidores 1/7 con buen ping para buscar rapidamente. Corregido cursor persistente/sanitizado, vencimiento individual de registros y reserva hasta ocho 1/7 que Hop/AUTO consumen sin HTTP. Progreso pagina/filas/contador mientras no hay reserva. Respeta orden BestLatency, grupos 2..6 solo con prueba nueva, cookie/config/AUTO y detector existentes. Build/134 regresiones/diez Python pasan; montaje real conserva AUTO apagado/filtros y reutiliza Chilli. Continuidad/hop real y publicacion se registran en WORKLOG al verificarse.

## Unificar distribucion en main/stable (2026-10-07)

Usuario confirma CUENTA GUARDADA en Delta/iPad y solicita publicar para que todos usen exclusivamente main/chilli_hopper.luau. Se prepara integracion de PR #10 y publicacion mediante CI; stable no se edita manualmente. CI del codigo 7658660 paso compilacion, 125 regresiones Luau y diez tests Python (run 37601500836). La confirmacion reportada indica validacion inicial/escritura/relectura completadas; no demuestra aun continuidad DeviceCookie entre hops ni Redirect=false. PC e iPad usan el mismo cargador de main en autoexec, conservando cookies/filtros locales. Previews y SHA antiguos requieren sustitucion unica por main. Los siguientes apartados describen las pruebas previas y sus limites en ese momento.

## Confirmacion de guardado y cargador actualizable (2026-10-07)

Usuario no distingue si Guardar funciono y pide actualizar el enlace que ya pego. Confirma que usa el SHA e0f669...: es inmutable y necesita una sustitucion unica por la rama preview, sin reemplazar la cookie local. Formulario ahora conserva confirmacion explicita tras escritura/relectura, muestra comprobacion en botones y refleja GUARDADA/SOLO SESION en launcher; reapertura/restauracion comunica estado. No cambia detector ni stable. Autenticacion Delta sigue pendiente.

## Pausa al guardar en Delta (2026-10-07)

Usuario confirma que "Best Ping en pausa; espera el limite de Roblox" aparece al pulsar Guardar y usar AUTO. Ese texto propio no demuestra HTTP 429. Corregido deadline 35s que era menor al cooldown 60s; DeviceRequest da progreso/contador y distingue intervalo, 429 y native request pendiente, con excepciones sanitizadas y reserva hasta terminacion real. Guardar tiene prioridad sobre prefetch, reintenta una vez ante 429 y conserva borrador oculto si falla mientras ventana abierta. Build/125 regresiones pasan. Auth real de Delta sigue sin confirmacion; conservar preview y PR #10 en borrador.

## Cookie propia por dispositivo (2026-10-07)

Rama codex/cookie-local-dispositivo, sobre la conexion Best Ping previa. Usuario requiere pegar la cookie dentro del script en Delta/iPad; conocidos usan Potassium. Nuevo formulario con launcher fijo CUENTA / BEST PING y acceso desde Opciones; cerrar no impide reabrir. Guardado local opcional sin cifrado por UserId para sobrevivir hops, sin PC/proxy ni credenciales en API/logs/Git. Alternativa de sesion sola y borrado/desconexion. Build/117 regresiones y diez tests Python pasan. Montaje/cierre/reapertura/limpieza comprobados aislados en Potassium con almacenamiento simulado; no autenticar desde Delta ni declarar soporte de redirects probado. Ver BEST_PING.md. Version activa/autoexec de esta PC sigue usando el bridge anterior; no se ha sustituido stable.

## Pruebas de seleccion de servidores (2026-10-07)

Estado actual: el usuario pidio hacer la conexion. BestLatency ya esta conectado/activado en esta PC mediante best_ping_bridge.py y el intercambio de JSON sanitizados en el workspace de Potassium. La cookie permanece en el TXT privado del PC; el runtime solo recibe registros. El autoexec local de prueba lee el bundle validado para conservar la conexion entre hops; original respaldado, stable sin publicar. Un hop real llego al candidato anunciado 1/7, con mediana posterior de 70.26 ms y tres jugadores al medir. AUTO/Eternal >=7B/s intactos; conexion y renovacion de pool confirmadas en el destino.

El proceso guarda el cursor BestLatency entre hops. Para habilitar ocupaciones 2..6 sin recorrer toda la lista nativa, OccupancyAsc comprueba el primer grupo no visitado, con prueba vigente ligada al conjunto de exclusiones. Respuestas vencidas/parciales sin esa prueba y errores esperan; no hay fallback silencioso. Inicio del proceso documentado en BEST_PING.md; tras reiniciar Windows debe iniciarse otra vez. Las observaciones de los parrafos siguientes son historia previa a la conexion.

El usuario pidio probar Best Ping y aclaro el orden entre hops: agotar candidatos elegibles de 1/7 antes de pasar a 2/7, luego 3/7 y asi hasta 6/7. playing se refiere a ocupacion antes de entrar. Esta candidata aplica ocupacion ascendente antes de cualquier desempate y guarda un solo grupo en el pool; agotarlo requiere consultar de nuevo. Antes de usar grupos 2..6 se vuelve a consultar para detectar nuevos candidatos menores. Dentro de cada grupo el runtime aun conserva la heuristica anterior de FPS/ping anunciado. La consulta v2 sin autenticacion desde Potassium devuelve HTTP 400, codigo 7, Guest users are not allowed. Por solicitud del usuario, un probe privado de PC lee una cookie de su TXT .private fuera de Git y ya obtuvo BestLatency con HTTP 200. Esa fuente aun no se conecta al runtime; no incluir credenciales en el bundle ni transmitirlas al cliente. No se publico ni cargo el bundle candidato.

El helper experimental conserva BestLatency recibido de Roblox dentro de cada ocupacion. Se verifico aislado en Potassium con cinco paginas/500 registros y 488 candidatos unicos: orden 1..6 y desempates nativos correctos, pool de tres candidatos con una persona. Como quedan paginas, agotarlos no demuestra ausencia de otros con una persona; OccupancyGroup bloquea avanzar a 2..6 sin evidencia de que los grupos inferiores estan completos. La fuente v1 Occupancy Asc permite identificar el primer grupo elegible; una muestra parcial BestLatency no. No se probo el ping de destino ni un salto real. El conteo playing puede cambiar antes de llegar.

Fecha de consolidacion: 2026-10-06. Este documento resume los requisitos y las decisiones de la conversacion para continuar desde Visual Studio Code sin depender del historial del chat.

## Objetivo

El usuario quiere detectar huevos en **Steal An Egg** y automatizar una busqueda entre servidores. El juego inspeccionado usa PlaceId `107778070777162`. El resultado combina el cargador de Chilli Hub, el Server Hop ya existente, un detector propio y un panel propio de filtros.

El filtro inicial es **Divine con ingreso previsto minimo de 7.000.000.000 por segundo**. El usuario especifico que se busquen los huevos que aparecen libres en el mapa, excluyendo los de otras bases. Chilli continua con su configuracion cuando el detector encuentra un candidato; el detector no agrega una accion propia de recoger o robar.

## Flujo final acordado

La rareza seleccionada es un minimo inclusivo segun Data.Rarity.Rarities/Rank: Eternal acepta Eternal, Divine y cualquier rango superior (incluye otros IDs con el mismo Rank). El flujo siguiente se aplica a Divine o superior por defecto y a la rareza minima elegida o superior al configurar. Ingreso y demas filtros siguen siendo obligatorios; una observacion superior mantiene la busqueda del minimo seleccionado en el ciclo vigente.

1. Al entrar, esperar juego cargado y un snapshot valido del mapa. Antes de aceptar la primera decision, exigir 3 segundos sin cambios de inputs Slot/catalogo ni revision del campo y, ademas, un snapshot completo (todas las zonas oficiales presentes, ningun Uid del periodo anterior) o al menos 10 segundos desde esa lectura valida. Scans repetidos no acortan la espera. Repetirla al renovarse el ciclo o perderse los datos.
2. Sin Divine disponible ni observacion guardada de Divine en el ciclo vigente, quedarse en ese servidor y esperar la renovacion.
3. Al renovarse los huevos, esperar el snapshot nuevo y escanear otra vez. Si no hay Divine, seguir esperando.
4. Si hay Divine pero ninguno cumple el minimo y los demas filtros, hacer hop y escanear el servidor de destino.
5. Si cualquier Divine cumple, quedarse con AUTO activo, avisar y comprobar la captura (aclaracion 2026-10-12, reemplaza apagar AUTO). Capturado (aparece en los huevos del jugador): esperar en ese servidor el nuevo ciclo con AUTO. Lo entrega otro jugador, desaparece o no se captura en 90 s: hop para buscar otro. Mientras el jugador lo lleva no hay limite; si lo pierde en el camino y el huevo sigue en el mapa, otros 90 s para recogerlo (aclaracion 2026-10-12: no irse si el huevo sigue ahi). Chilli permanece activo con sus opciones actuales.
6. Si la noche se reinicia durante los hops, descartar la decision previa, esperar los nuevos datos y repetir el mismo ciclo. **El reset no detiene la busqueda por completo.**
7. Si se observo Divine disponible y se inicio la busqueda en ese ciclo, su ausencia en otro servidor por robo/recogida no termina la busqueda. Continuar los hops hasta match o hasta empezar la siguiente noche. La observacion no demuestra que el huevo siga disponible en otros servidores.
8. Persistir esa ventana antes de saltar. Tras una desconexion, recuperar la busqueda con AUTO activo y un reloj/snapshot valido del mismo ciclo. Un Stop manual se conserva; reejecutar en la misma conexion no confirma llegada.

Hubo requisitos anteriores de esperar siempre en el mismo servidor o detener todo al reset. El usuario los reemplazo por el flujo anterior; no deben reintroducirse.

La memoria de busqueda en `chilli_egg_search_cycle.json` vence al inicio de la noche siguiente, `NextResetTime(now) - NightLengthSeconds()`, usando los overrides del juego. Cambios de rareza/zonas/periodo/overrides invalidan esa ventana; minimo y demas filtros se vuelven a comprobar para cada spawn. El archivo es independiente del estado de teleport.

## Datos y significado de 7B

`EggState.ReadFieldEggs().Records` es la fuente de spawns. Solo `State == "Slot"` representa huevos disponibles en sus nidos. `Carried`, `GuardCarried`, `Dropped`, `Claimed`, bases e inventarios no forman parte de la busqueda.

El ingreso se obtiene con `EggRecords.ToAssetItemData(egg)` y `AssetEarnings.MutationOnlyRatePerSecond(item)`. Incluye especie, escala y mutaciones; excluye bonos personales, boosts temporales y bonificaciones del propietario anterior. Se compara el numero exacto con el minimo; una etiqueta redondeada a 7B puede no alcanzar 7.000.000.000.

El ciclo observado usa `Shared.Util.AreaEggCycle`: periodo de 300 segundos y noche de 10 segundos. Estos valores se leen del modulo y sus overrides replicados; no se fija un temporizador local de cinco minutos. Se consulta `Workspace:GetServerTimeNow()` y las senales `ResetCountdown`, `FieldRefreshed` y `RarityRevealed`. Durante la noche el mapa se vacia parcialmente; un snapshot completo puede publicarse unos segundos despues de la transicion. No tomar decisiones con esa vista incompleta.

## Panel y experiencia de usuario

La referencia visual fue el panel Steal de Chilli: tarjetas oscuras, imagen del elemento, rareza por color, ingreso y controles destacados. No se copiaron sus fuentes internas.

La implementacion final tiene lista principal **Mapa**, que muestra los spawns actuales de todas las rarezas, y un selector separado **Elegir zonas**, que contiene las zonas oficiales para configurar filtros. El catalogo no representa presencia real en el servidor. Un cambio anterior que mostraba el catalogo en la lista principal se corrigio a esta separacion.

Filtros: rareza minima inclusiva, minimo de ingreso por segundo, mutacion, nombre y varias zonas exactas. El selector incluye solo IDs de `Data.Rarity.Rarities` usados por especies de `Assets.Directory`, ordenados por el `Rank` real. En el cliente del 2026-10-06 son Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic, Secret, Eternal y Divine (rangos 1-10); no fijar esa lista ni una escala 0-7 en el codigo. Los otros IDs del modulo general no representan opciones disponibles del catalogo. El selector de zonas ofrece todas las zonas oficiales; una lista de zonas explicita sigue siendo una restriccion exacta.

El minimo acepta `k`, `m`, `b`, `t` y `q`, sin distinguir mayusculas, con decimal punto o coma: `500k`, `25m`, `7.5b`. Usa `Shared.Utils.Numbers.Parse` del juego tras validar el formato; un numero sin sufijo son unidades por segundo (`7` = 7/s). Los valores guardados y comparados siguen siendo numericos exactos; el campo abrevia solo si el texto conserva el mismo umbral al parsearlo. La configuracion previa de 7.000.000.000 sigue mostrando `7b`.

Lista vacia de zonas en configuracion acepta todas. `Solo filtro` limita los spawns visibles a coincidencias. La tarjeta muestra ingreso, escala, peso, mutaciones y zona, con imagen oficial del huevo, imagen de la criatura o modelo 3D replicado. El orden principal es mejor rareza primero (Rank descendente del juego), con ingreso descendente dentro de cada rareza; se conserva la alternativa de ordenar por nombre. Aplica a huevos, criaturas y modelos 3D. La preferencia existente `sortBest` ahora representa este orden por rareza.

Los cambios pendientes se aplican antes de encender AUTO. Un minimo invalido impide guardar e iniciar. El panel se arrastra, minimiza y reabre con `Egg Finder`; **Alt izquierdo** alterna abrir/cerrar el panel completo, incluyendo cuando hay un campo de texto enfocado. Alt derecho no lo alterna. Los controles de filtros se pueden plegar. Posicion, visual, orden y apertura se conservan en `chilli_egg_panel_ui.json`. Los modelos se crean solo para tarjetas visibles y usan imagen cuando falta el modelo.

## Integracion y distribucion

El panel incorpora el estilo grafito/champan documentado en `DESIGN.md`: cabecera sobria, Gotham sin contorno, estado y filtros separados, tarjetas con filas distintas para nombre, ingreso, peso y rareza/mutaciones. Mantiene formatos k/m/b/t/q, presets, alertas, detalle exacto, orden por rareza e ingreso, Alt izquierdo y virtualizacion. El estilo no cambia el detector ni el flujo AUTO.

Chilli se carga desde `https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua`, que redirige a un cargador protegido. Se mantuvo esa integracion y no se decodifico Chilli.

El usuario pidio GitHub para usar un cargador corto y autorizo expresamente hacer publico `diegotoruno/SAE-SCRIPT`. La linea instalada en autoexec conserva la URL de `main/chilli_hopper.luau`. Ese archivo sirve como puente hacia el bundle aprobado en `stable`. CI publica `stable` solo despues de compilacion y regresiones.

El usuario pidio CI/CD y despues un proyecto con todo el contexto en Markdown para trabajar desde VS Code. Este repositorio local es el proyecto nuevo; los archivos de trabajo anteriores, referencias y backups del directorio padre son historicos y no son la fuente activa de desarrollo.

## Herramientas y limitaciones

Potassium MCP permite listar clientes, ejecutar Luau, leer consola y editar tabs. El PID cambia y siempre debe obtenerse de `list_clients`. No fijarlo en el codigo ni en la documentacion de pruebas.

La cuenta de GitHub tiene sesion en el navegador. La credencial Git local probada devolvio 401; autenticar VS Code/Git con la cuenta antes del primer push. No guardar tokens en archivos del proyecto. Las publicaciones iniciales se realizaron mediante la interfaz de GitHub; CI usa el token automatico de Actions.

`UniversalSynSaveInstance` se reviso como referencia de inspeccion, pero no se ejecuto. No es dependencia de runtime ni de CI. Las referencias de modulos del juego se conservaron fuera del repo publico.

No se ha verificado un spawn real que cumpla Divine >=7B. El umbral, exclusiones y flujo se verificaron con snapshots simulados y con lecturas/renovaciones reales del cliente; ve `TESTING.md` para los limites de esa evidencia.

## Mejoras de rendimiento y estabilidad

El finder comparte analisis e ingresos por snapshot/UID y fuerza lectura/cálculo antes del teleport. La lista del mapa renderiza la ventana visible con margen, conserva tarjetas por UID y ofrece Detalle con ingreso exacto y motivo. Los recursos visuales opcionales y modulos tardios se reintentan.

Opciones agrega presets de filtros (cargar deja cambios pendientes) y notificacion/sonido configurables. Persistencia verificada con backup y cache, historial acotado y paginacion de servidores. Un salto sin confirmar pausa nuevos saltos de AUTO hasta llegar o reintentar manualmente; no confundir una reejecucion en el origen con una llegada. Se mantiene el flujo Divine/snapshot/Slot acordado.
