# Contexto del proyecto

Fecha de consolidacion: 2026-10-06. Este documento resume los requisitos y las decisiones de la conversacion para continuar desde Visual Studio Code sin depender del historial del chat.

## Objetivo

El usuario quiere detectar huevos en **Steal An Egg** y automatizar una busqueda entre servidores. El juego inspeccionado usa PlaceId `107778070777162`. El resultado combina el cargador de Chilli Hub, el Server Hop ya existente, un detector propio y un panel propio de filtros.

El filtro inicial es **Divine con ingreso previsto minimo de 7.000.000.000 por segundo**. El usuario especifico que se busquen los huevos que aparecen libres en el mapa, excluyendo los de otras bases. Chilli continua con su configuracion cuando el detector encuentra un candidato; el detector no agrega una accion propia de recoger o robar.

## Flujo final acordado

La rareza seleccionada es un minimo inclusivo segun Data.Rarity.Rarities/Rank: Eternal acepta Eternal, Divine y cualquier rango superior (incluye otros IDs con el mismo Rank). El flujo siguiente se aplica a Divine o superior por defecto y a la rareza minima elegida o superior al configurar. Ingreso y demas filtros siguen siendo obligatorios; una observacion superior mantiene la busqueda del minimo seleccionado en el ciclo vigente.

1. Al entrar, leer un snapshot valido del mapa.
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

La implementacion final tiene lista principal **Mapa**, que muestra los spawns actuales de todas las rarezas, y un selector separado **Elegir especies**, que contiene el catalogo para configurar filtros. El catalogo no representa presencia real en el servidor. Un cambio anterior que mostraba el catalogo en la lista principal se corrigio a esta separacion.

Filtros: rareza minima inclusiva, minimo de ingreso por segundo, mutacion, nombre y varias especies exactas. El selector incluye solo IDs de `Data.Rarity.Rarities` usados por especies de `Assets.Directory`, ordenados por el `Rank` real. En el cliente del 2026-10-06 son Common, Uncommon, Rare, Epic, Legendary, Mythic, Cosmic, Secret, Eternal y Divine (rangos 1-10); no fijar esa lista ni una escala 0-7 en el codigo. Los otros IDs del modulo general no representan opciones disponibles del catalogo. El selector de especies ofrece la rareza minima y las superiores; una lista de especies explicita sigue siendo una restriccion exacta.

El minimo acepta `k`, `m`, `b`, `t` y `q`, sin distinguir mayusculas, con decimal punto o coma: `500k`, `25m`, `7.5b`. Usa `Shared.Utils.Numbers.Parse` del juego tras validar el formato; un numero sin sufijo son unidades por segundo (`7` = 7/s). Los valores guardados y comparados siguen siendo numericos exactos; el campo abrevia solo si el texto conserva el mismo umbral al parsearlo. La configuracion previa de 7.000.000.000 sigue mostrando `7b`.

Lista vacia de especies acepta todas. `Solo filtro` limita los spawns visibles a coincidencias. La tarjeta muestra ingreso, escala, peso, mutaciones y zona, con imagen oficial del huevo, imagen de la criatura o modelo 3D replicado. El orden principal es mejor rareza primero (Rank descendente del juego), con ingreso descendente dentro de cada rareza; se conserva la alternativa de ordenar por nombre. Aplica a huevos, criaturas y modelos 3D. La preferencia existente `sortBest` ahora representa este orden por rareza.

Los cambios pendientes se aplican antes de encender AUTO. Un minimo invalido impide guardar e iniciar. El panel se arrastra, minimiza y reabre con `EGG FILTERS`; **Alt izquierdo** alterna abrir/cerrar el panel completo, incluyendo cuando hay un campo de texto enfocado. Alt derecho no lo alterna. Los controles de filtros se pueden plegar. Posicion, visual, orden y apertura se conservan en `chilli_egg_panel_ui.json`. Los modelos se crean solo para tarjetas visibles y usan imagen cuando falta el modelo.

## Integracion y distribucion

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
