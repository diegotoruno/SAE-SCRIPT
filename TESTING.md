# Pruebas y validacion

## Comprobacion local y CI

```powershell
.\.venv\Scripts\python.exe build.py
.\.venv\Scripts\python.exe ci_tools.py
```

Se compilan fuentes, punto de entrada, loader, tests y bundle integrado. El CLI oficial Luau 0.741 se descarga y verifica por SHA256. No se ejecuta el bundle de Roblox en el CLI; se ejecuta solo `ci_tests.luau` con un entorno controlado.

Las 50 regresiones cubren: mapa vacio, solo Common, Divine justo bajo 7B, limite exacto, mejor candidato, estados no disponibles, mutacion base, nombre literal, especies exactas, ingreso invalido, catalogo desconocido, minimo invalido, deduplicacion/persistencia, noche, snapshot pendiente, ciclo de renovacion entre hops, snapshot malformado y error al guardar. Los casos nuevos verifican sufijos k/m/b/t/q, numeros sin sufijo por segundo, formatos invalidos/overflow, edicion sin redondear el umbral, opciones de rareza derivadas del catalogo y sus rangos, rechazo de IDs auxiliares y rangos numericos, configuracion antes de cargar datos, compatibilidad de valores guardados y rarezas obsoletas que deben esperar.

Al cambiar una decision o filtro, ampliar las regresiones con el caso que fallo. No agregar tests que se limiten a comparar lineas de codigo.

## Smoke test real con Potassium

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
