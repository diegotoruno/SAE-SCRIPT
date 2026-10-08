# Contexto del proyecto

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
guardada retirada del juego produce loading. rarityCount sigue contando la
rareza minima y superiores en todo el mapa: un huevo de zona excluida es
insuficiente y permite hop; sin esa rareza ni evidencia vigente se espera.

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

1. Al entrar, esperar juego cargado y un snapshot valido del mapa. Antes de aceptar la primera decision, exigir al menos 10 segundos desde esa lectura valida y 3 segundos sin cambios de inputs Slot/catalogo ni revision del campo. Scans repetidos no acortan la espera. Repetirla al renovarse el ciclo o perderse los datos.
2. Sin Divine disponible ni observacion guardada de Divine en el ciclo vigente, quedarse en ese servidor y esperar la renovacion.
3. Al renovarse los huevos, esperar el snapshot nuevo y escanear otra vez. Si no hay Divine, seguir esperando.
4. Si hay Divine pero ninguno cumple el minimo y los demas filtros, hacer hop y escanear el servidor de destino.
5. Si cualquier Divine cumple, quedarse, apagar AUTO y mostrar la coincidencia. Chilli permanece activo con sus opciones actuales.
6. Si la noche se reinicia durante los hops, descartar la decision previa, esperar los nuevos datos y repetir el mismo ciclo. **El reset no detiene la busqueda por completo.**
7. Si se observo Divine disponible y se inicio la busqueda en ese ciclo, su ausencia en otro servidor por robo/recogida no termina la busqueda. Continuar los hops hasta match o hasta empezar la siguiente noche. La observacion no demuestra que el huevo siga disponible en otros servidores.
8. Persistir esa ventana antes de saltar. Tras una desconexion, recuperar la busqueda con AUTO activo y un reloj/snapshot valido del mismo ciclo. Un Stop manual se conserva; reejecutar en la misma conexion no confirma llegada.

Hubo requisitos anteriores de esperar siempre en el mismo servidor o detener todo al reset. El usuario los reemplazo por el flujo anterior; no deben reintroducirse.

La memoria de busqueda en `chilli_egg_search_cycle.json` vence al inicio de la noche siguiente, `NextResetTime(now) - NightLengthSeconds()`, usando los overrides del juego. Cambios de rareza/periodo/overrides invalidan esa ventana; minimo y demas filtros se vuelven a comprobar para cada spawn. El archivo es independiente del estado de teleport.

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

Los cambios pendientes se aplican antes de encender AUTO. Un minimo invalido impide guardar e iniciar. El panel se arrastra, minimiza y reabre con `EGG FILTERS`; **Alt izquierdo** alterna abrir/cerrar el panel completo, incluyendo cuando hay un campo de texto enfocado. Alt derecho no lo alterna. Los controles de filtros se pueden plegar. Posicion, visual, orden y apertura se conservan en `chilli_egg_panel_ui.json`. Los modelos se crean solo para tarjetas visibles y usan imagen cuando falta el modelo.

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
