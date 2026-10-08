# Estado del trabajo

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

## 2026-10-07 - Reposicion adaptativa tras prueba prolongada

- PR12 integrado en main6779ab6, CI37607861598 valido/publico build35. Bundle publico227568 bytes/SHA25634789849521776239ba49b4f66863ded6eb33fbc48c03441f5dc87a18e82baff identico a candidata; main sigue apuntando a stable.
- Hop real de respaldo2/7 a ace56edf-d55a-41ce-8cd1-086a03b9c6ea:21.83ms hasta pendiente, sin HTTP adicional antes del teleport, destino exacto. Autoexec restaura cuenta/AUTO/Eternal>=7B. Mediana56.32ms/ocho muestras, cuatro jugadores al medir.
- Prueba prolongada bajo de24 a1..6 por escasez en cabeza. Rama codex/reserva-adaptativa sobre main6779ab6 conserva cursor cuando stock<16 hasta12 paginas/180s; con suficiente stock termina a5/75s.149 regresiones/diez Python/compilacion correctos. Bundle228047 bytes/SHA2568c93990ce3fb66783640592f1b45b91dfebc7e3f8ce47e91d0e10b0812554e1e.
- Potassium monto esta extension en mismo JobId: antigua sesion alive=false, Chilli reutilizado, AUTO/cookie/Eternal>=7B intactos. Reposicion real continuo paginas6..10 en lugar de reiniciar5; reserva paso de8 a21 opciones2/7 vigentes, con15 en pagina9 y cero duplicados/vencidos en ese punto. Pasada deja de profundizar al recuperar suficiente stock. PR13/head8f25be8 paso CI37608780197; publicacion de la extension se registrara tras merge/CI.

## 2026-10-07 - Reserva balanceada para buscar mas huevos

- Usuario pide cantidad/calidad y autoriza2/7 cuando se agote reserva rapida1/7. Muestra real reciente3/1 frente190/2. Rama codex/reserva-balanceada sobre main dc891a5, worktree verification/balanced-reserve.
- Reserva24, prioridad1/7 y respaldo2/7 en orden nativo, TTL180/90 y refill<16 o respaldo60s desde cabeza BestLatency. No esperar ausencia global1/7; grupos3..6 con prueba anterior. Detector/ciclo/filtros/match intactos. Migracion/restauracion y cuentas separadas; politica persistida sin cookie.
- Build/146 regresiones Luau/diez Python correctos. Montaje real conserva cookie/Eternal>=7B/AUTO activo, sesion anterior destruida y Chilli reutilizado. De0 listos a24 respaldos2/7 desde observaciones ya obtenidas. Recarga recupero24 y refill desde cabeza; GetStatus descarta un respaldo2/7 de97s que aun existia en disco. Pasada limitada a5 paginas/75s para no seguir acumulando candidatos de menor prioridad. Hop/CI quedan por comprobar; resultados posteriores se agregaran.

## 2026-10-07 - Corregir recorrido Best Ping y precargar 1/7

- Reporte Buscar atascado con cuenta guardada. Cliente real seguia vivo con HTTP200/lista parcial; recorrido se reiniciaba a los180s. Usuario pide recuperar precarga para saltos rapidos.
- Rama codex/best-ping-paginacion sobre main f8c72d0. Cursor conserva recorrido con observaciones de180s, snapshot sanitizado por UserId, reutilizacion de comprobacion inicial y progreso. Reserva hasta ocho 1/7 persistida, consumo sin HTTP por Hop/AUTO incluso durante refill, exclusiones/frescura/transporte/cuenta y grupos mayores con prueba nueva.
- Build/134 regresiones Luau/diez Python correctos. Montaje real en Potassium: sesion anterior destruida, Chilli reutilizado, Eternal>=7B/s/cookie/AUTO apagado conservados. Sin inputs sinteticos. Cache y hop reales/publicacion pendientes de comprobacion posterior.

## 2026-10-07 - Distribucion comun solicitada

- Usuario reporta CUENTA GUARDADA en Delta/iPad y autoriza actualizar main/chilli_hopper.luau para todos. Conserva una sola version de distribucion con cookies/filtros locales; requiere cambiar previews antiguos a main una sola vez.
- Codigo 7658660 aprobado por CI 37601500836: compilacion/125 regresiones Luau/diez tests Python. Documentacion actualizada para uso comun, feedback real reportado y limites de evidencia. Se prepara PR #10 para integrar y publicar mediante CI, sin modificar stable directamente ni divulgar credenciales.

## 2026-10-07 - Guardado visible y preview actualizable

- Usuario pregunta como saber si se guardo y confirma cargador con SHA e0f669..., que no puede cambiar. Documentado preview de rama actualizable con sustitucion unica del cargador; no requiere cambiar cookie ya persistida.
- Formulario deja confirmacion de guardado verificado visible en vez de cerrarse, botones distinguen comprobacion, launcher indica GUARDADA/SOLO SESION y reapertura informa estado. API de estado agrega connecting/message sin secretos. AUTO y detector intactos.
- Build/compilacion y las 125 regresiones existentes pasan. Feedback real en Delta y autenticacion/paste/persistencia aun no confirmados; se conserva el preview y stable no cambia.

## 2026-10-07 - Espera al guardar cookie en Delta

- Usuario reporta pausa y confirma trigger Guardar y usar AUTO. Mensaje provenia del gate propio y no confirma 429. Hallado deadline 35s menor que cooldown 60s y perdida de borrador al fallar comprobacion.
- Implementado DeviceRequest testable con token/reserva, progreso distinguido entre intervalo/429/pendiente y manejo de excepciones. Cola hasta 95s; request nativo que excede 30s mantiene bloqueo hasta terminar, sin duplicados. Guardar suspende prefetch, reintenta una vez ante 429, conserva borrador oculto con formulario abierto y expone solo estado sanitizado.
- Build/compilacion y 125 regresiones correctos. Ocho casos nuevos prueban cooldown completo/intervalo/reintento/timeout/excepciones/cancelacion/legacy busy/finalizacion tardia. Auth de Delta pendiente, PR #10 mantiene borrador y stable no cambia.

## 2026-10-07 - Cookie local por usuario y formulario recuperable

- Usuario requiere opcion en Delta/iPad y Potassium, sin acceso del autor a cookies. Implementado transporte directo optativo DeviceCookie, validacion BestLatency antes de guardar, persistencia por UserId solo tras Guardar y usar AUTO, sesion sin guardado y borrar/desconectar. Archivo local sin cifrado explicitado en formulario; nunca API/logs/teleport/bridge/Git.
- Usuario senala que cerrar debe permitir recuperar. Launcher CUENTA / BEST PING independiente del marco plegable/arrastrable, segunda entrada en Opciones y API segura de abrir/cerrar/estado.
- Build/compilacion y 117 regresiones Luau pasan; diez tests Python pasan. UI aislada en Potassium con archivos ficticios/request bloqueado: reapertura doble desde identidad baja, limites de pantalla/escalas, opcion secundaria y limpieza de 30 conexiones correctos. AUTO/filtros/JobId reales conservados, sin teleports ni cookies reales. Captura no disponible por pipe nativo de Computer Use; paste/toques/auth/persistencia reales de Delta pendientes.
- Rama codex/cookie-local-dispositivo sobre la conexion anterior; la sesion/autoexec real de esta PC conserva el bridge previo. Se prepara preview generado por build.py para prueba del usuario; stable sigue anterior.

## 2026-10-07 - Conexion local Best Ping activa

- Usuario pidio conectar. Agregados proceso Python local, launcher oculto, intercambio JSON sanitizado, configuracion BestLatency y NativePool; no cookies en runtime/bundle. Mantiene cursor entre hops y confirma grupo minimo con OccupancyAsc antes de avanzar a 2..6. Modo nativo espera ante fallos, sin fallback.
- Build/compilacion y 108 regresiones Luau correctos; diez tests Python offline correctos, agregados a CI. Configuracion/API/distribucion documentadas en BEST_PING.md.
- Activado en Potassium/Windows con AUTO Eternal >=7B/s; autoexec local lee bundle validado y original queda respaldado. Reejecucion retira 23 conexiones/sesion anterior, no duplica Chilli.
- Un salto real llego a candidato 1/7 seleccionado por BestLatency; autoexec conserva conexion en destino y renueva pool excluyendo visitado. Mediana posterior 70.26 ms, tres jugadores al medir, pending=false. Configuracion/AUTO intactos. Error auxiliar de GUI corregido sin teleport previo ni inputs sinteticos; evidencia privada en verification/best-ping/connection-live-report.json del workspace principal.
- Stable sin publicar; activo solo en esta PC. Reiniciar proceso tras reiniciar Windows. Grupos 2..6 reales y otros dispositivos no probados.

## 2026-10-07 - Progresion 1/7 -> 2/7 -> ... -> 6/7

- Aclaracion del usuario aplicada en codex/best-ping-un-jugador: orden numerico de todas las ocupaciones antes del desempate, registros invalidos excluidos y pool de un solo grupo con politica occupancy-groups-v2. Agotar la cache vuelve a consultar; cada hop de grupos 2..6 revisa de nuevo si hay candidatos menores.
- Build/compilacion y 102 regresiones correctos. Probe privado: seis regresiones offline de paginacion/ocupacion, sin nuevas peticiones autenticadas.
- Helper exacto verificado aislado en Potassium con los 488 candidatos sanitizados de la consulta anterior: grupos 1..6 y BestLatency interno correctos, pool de tres con una persona, avance a dos bloqueado al agotarlos porque quedan paginas. Progresion 2..6 solo en simulacion completa. Filtros/AUTO/JobId conservados, cero teleports.
- Candidata sin cargar/publicar. BestLatency sigue sin conectar al runtime automatico; no afirmar que la version activa ya usa el orden nativo. Datos/evidencia privados en verification/best-ping del workspace principal.

## 2026-10-07 - Orden BestLatency real confirmado

- Probe privado con cookie actualizada: cinco paginas HTTP 200, 500 registros, 488 candidatos unicos, tres playing=1 primero (posiciones originales 22/210/259). Consultas espaciadas 15s, muestra incompleta porque quedan mas paginas.
- Helper exacto de candidata probado aislado en Potassium con todos esos candidatos: orden nativo preservado dentro de los grupos, prioridad de una persona correcta. Filtros/AUTO/JobId intactos, cero teleports y cookie solo en el probe de PC/endpoint Roblox, fuera de Git y del cliente.
- No cambian Luau/bundle ni las 97 regresiones existentes. Evidencia privada en verification/best-ping del workspace principal. Candidata sin activar/publicar; fuente nativa aun no conectada al runtime y falta salto real/medicion de ping/persistencia de pool.

## 2026-10-07 - Pruebas de Best Ping y prioridad de una persona

- Rama aislada `codex/best-ping-un-jugador` sobre main publicado `6c996a1`; conserva arrastre, UI, rareza minima y barrera de carga. Pool ordenado primero por playing=1, conteo persistido y cache antigua invalidada. BestLatency experimental conserva el orden de entrada; runtime sigue usando la heuristica legacy dentro de cada grupo.
- Build/compilacion y 97 regresiones correctas. Helper exacto ejecutado aislado con 200 servidores reales: 97 elegibles con una persona antes de 100 con seis; top 8 con una persona. Filtros/AUTO/JobId iguales; sin teleports ni carga del bundle.
- Endpoint nativo identificado en JS publico de Roblox, pero BestLatency devuelve HTTP 400/codigo 7/Guest users are not allowed desde request. Usuario confirma opcion en la aplicacion; no se verifico la llamada de esa interfaz. HttpRbxApiService bloqueado por executor; no se elude. Un 429 del primer muestreo se respeto y la repeticion paso.
- Evidencia privada en verification/best-ping del workspace principal. Candidata sin publicar ni activar. Pendientes autenticacion soportada, pool/UI en cliente y ping real de destino.

## 2026-10-07 - Confirmacion manual del arrastre en Windows

- Tras el reporte de que no se movia, el cliente tenia la version publicada anterior (seis conexiones): AUTO habia saltado y autoexec recargo stable, donde el arreglo aun no estaba publicado.
- Recargada la candidata en el servidor actual; el usuario confirmo que ya se mueve. Observacion pasiva de inputs reales desde plegado/texto y cambios de Position; filtros Eternal >=7B/s y AUTO conservados. Sin inputs sinteticos ni llamadas a conexiones.
- Preparado PR #9, rama codex/boton-rojo-movible. Publicacion por CI pendiente en este punto; autoexec conserva el cargador habitual. Evidencia privada en verification/movable-button-manual.json. iPad/tactil no probado.

## 2026-10-07 - Boton rojo movible

- Arrastre registrado en toda la superficie del hopper, incluidos texto, AUTO y plegado. Conserva umbral de 6px y guardado existente; sigue solo el toque inicial y bloquea clics durante el arrastre y 250ms despues de soltar, incluso si se mantuvo quieto. Perder foco termina el gesto; listeners retirados con la sesion.
- Cambio aplicado en esta carpeta sin sobrescribir pendientes anteriores y preparado sobre main `3407543` en `codex/boton-rojo-movible`, worktree `verification/movable-button`. Detector y panel publicados conservados. Build/compilacion y 61/92 regresiones pasan respectivamente.
- Potassium: candidata cargada, una GUI, seis conexiones anteriores desconectadas y 23 nuevas; listeners en boton/texto/chips/estado. Conservados Eternal >=7B/s, AUTO, posicion, plegado y preferencias; panel sin error, Chilli reutilizado. Reporte privado en `verification/movable-button-live.json`.
- El primer intento coincidió con una reconexion y fallo en el auxiliar antes de cargar la candidata (No active finder); se repitio durante loading y paso. Logs conservados. No se simularon gestos ni se dispararon conexiones; arrastre fisico y persistencia tras un gesto real pendientes de prueba manual. AUTO siguio sus hops naturales. Autoexec sin modificar; version publica aun anterior.


## 2026-10-07 - UI integrada sobre build 21

- Integrado el estilo pendiente del Egg Finder en `codex/ui-integrada`, worktree aislado `verification/ui-publish`, sobre main `ff8ea38`. Solo se modifica el panel y su documentacion; detector y runtime permanecen identicos a build 21, con rareza minima inclusiva y espera de carga.
- Conservados formatos exactos k/m/b/t/q, Alt, presets, alertas, orden, detalle, cache y virtualizacion. Tarjetas/canvas comparten altura de 116px y separacion de 8px. Color de rareza ajustado a contraste 4.5:1; callbacks restablecen identidad antes de CoreGui.
- Build y compilacion correctos; 92 regresiones pasan. Candidata final de 170351 bytes, SHA256 `27fed6f3dace4f99a5c7a9c48d9463b9ea0830a77f049ba6350da30481efa10b`.
- Potassium: revision visual del mapa, catalogo, presets/alertas y modelos al 80%; 15 comprobaciones de API/lifecycle y reejecucion final sin errores de panel. 65 Slot, seis tarjetas renderizadas; extremo de lista correcto y reutilizacion sin recrear tarjetas/modelos en snapshot identico.
- Restaurados filtros, AUTO, preferencias y archivos de UI/presets/alertas; retirada conexion temporal de escalado. Una GUI, sesion antigua detenida y cero conexiones anteriores; Chilli existente reutilizado segun log. El bundle final queda activo en Windows. Capturas y reporte privados en verification/, fuera de Git.
- Un auxiliar tuvo un error de identidad al editar un campo despues de GetStatus; se restauro identidad y se repitio correctamente. No se borraron logs ni se simularon inputs. La revision al 80% no equivale a una prueba en iPad; clics/gestos y Alt fisicos no se automatizaron. Pendiente PR/CI/CD y comprobacion de descarga publica.

## 2026-10-07 - Espera de carga antes de continuar el hop

- Scan exige juego cargado, lectura valida, minimo 10s desde esa lectura y 3s sin cambios Slot/catalogo/revision. La memoria guardada no evita la barrera; renovar, perder datos o fallar ingresos la reinicia. Conserva ingreso exacto, fuentes Slot, filtros y flujo del ciclo.
- Candidata previa a rareza minima: build/compilacion y 78 regresiones correctos (68 anteriores y diez nuevas de carga). Potassium verifico espera real de 10,1s, un hop y llegada por autoexec con 10,03s tras snapshot valido, match real que apaga AUTO y renovacion natural con espera adicional de 10,08s.
- Filtros Eternal >=7B/s, AUTO y preferencias conservados; autoexec de prueba retirado, original restaurado y pending=false. Sin nuevos errores del runtime/panel; fallo corregido de un auxiliar final descrito en TESTING.md. Prueba en Windows, no en iPad; no se observo Eternal/Divine >=7B real.
- Reconciliada en codex/espera-carga-hop sobre main `598073e58961552a5cd85d8f0c947f08305eb0d6`, despues del [PR #6 de rareza minima](https://github.com/diegotoruno/SAE-SCRIPT/pull/6) y su [build 19](https://github.com/diegotoruno/SAE-SCRIPT/releases/tag/build-19-598073e). Build/compilacion y 92 regresiones correctos (80 de la base y 12 de carga/integracion); SHA256 del bundle `c0fffa602f902d7933446343eb0cf531cd1715e3b6b15ca98b21364db3620c66`. Se conservaron ambos cambios en los conflictos de documentacion y tests. Los cambios anteriores pendientes en la carpeta principal se conservan fuera de esta publicacion; archivos del cliente y evidencia privada quedan fuera de Git.

## 2026-10-07 - Rareza minima inclusiva

- Integrado el fix sobre main/build 16, conservando parser exacto, opciones del catalogo, cache, panel virtualizado, Alt, presets, alertas y continuidad de ciclo. Seleccionar Eternal ahora admite Divine y cualquier rango mayor o igual segun Data.Rarity.Rarities/Rank; minimo y demas filtros siguen aplicandose a Slot.
- Selector de especies, Explain y cache de AUTO comparten la regla; huevos superiores se calculan con el panel cerrado y se vuelven a verificar antes del teleport. Notificacion muestra la rareza real del match. Se conserva la configuracion y formato de la memoria de busqueda.
- Build y compilacion correctos; 80 regresiones locales pasan (68 existentes y 12 nuevas). Detector final SHA256 `50629f3f2102212ba8f2f31f9095e22a2a9b446bbbd35776085a64412400b381` probado aislado con Potassium: 341 comprobaciones, escala real de 18 rarezas y comparacion de 65 Slot con ingresos reales. Configuracion, AUTO y JobId activos conservados; cero teleports.
- No habia un spawn real Eternal/Divine >=7B; casos de permanencia/hop controlados con catalogo real. Evidencia y limites en TESTING.md; referencias e informes privados excluidos de Git.

## 2026-10-06

- Consolidado el detector y panel con Chilli + hopper; filtro inicial Divine >=7B/s.
- Publicado el repositorio con autorizacion del usuario para hacerlo publico.
- Instalado y probado el cargador corto en Potassium; copia completa anterior conservada fuera del repo.
- Separadas fuentes en detector, panel y runtime sin cambiar codigo ejecutable en la extraccion.
- Build reproducible creado; compilacion de fuentes y bundle correcta con Luau 0.741.
- 18 regresiones locales correctas, incluyendo renovacion durante los hops.
- Primera ejecucion remota de CI/CD exitosa: [run 37543758600](https://github.com/diegotoruno/SAE-SCRIPT/actions/runs/37543758600), fuente `9d25921f0d955a87940ccc3b2d02319a806e4460`.
- Primera distribucion automatica creada en `stable` y [release build-1-9d25921](https://github.com/diegotoruno/SAE-SCRIPT/releases/tag/build-1-9d25921).
- Creado proyecto independiente `SAE-SCRIPT` para VS Code, entorno Python local, tareas Build/Verify y Markdown de contexto.

Las pruebas de UI, reset real y hop mencionadas en `TESTING.md` son evidencia previa. CI actual no puede comprobarlas. Tampoco se ha verificado un candidato real Divine >=7B.

## 2026-10-06 · Filtros reales y minimo abreviado

- Cambios preparados y verificados en `codex/filtros-reales-ingreso`; distribucion por CI/CD al integrarse en main.
- Rarezas derivadas de Assets.Directory y Data.Rarity.Rarities, ordenadas por Rank real. Observadas 10 opciones con especies, Common a Divine (1-10), coincidentes con las opciones visibles de Chilli. Se excluyen IDs auxiliares sin especies; no se fija una lista ni una escala numerica propia.
- Minimo acepta k/m/b/t/q, mayusculas, punto o coma decimal y unidades por segundo sin sufijo. El cliente usa Shared.Utils.Numbers.Parse con validacion previa. Persistencia numerica y campo editable conservan el limite exacto.
- Build y compilacion de todas las fuentes/bundle correctos; 26 regresiones pasan. `git diff --check` sin errores de whitespace.
- Bundle candidato ejecutado en Potassium: Chilli existente reutilizado y una sola GUI. Probados guardar/aplicar sufijos, lectura del JSON persistido, IDs invalidos, bloqueo de AUTO con minimo invalido y reaplicacion exacta de 6.999.999.999, 7.000.000.001 y 1.234.567.890,12345.
- Verificacion visible final con fuentes enviadas como UTF-8: etiquetas y mensaje de error caben; 65 tarjetas corresponden a los 65 Uids Slot de ese snapshot, sin errores del panel; cerrar/reabrir correcto. No son cantidades fijas del juego.
- Restaurados Divine >=7B/s, especies vacias, mutacion/nombre vacios y AUTO activo, como estaban antes de las pruebas. Posicion, visual y apertura conservados por la persistencia existente.
- No se forzo un teleport: el flujo de hop se conserva y sus regresiones pasan. El autoexec publico recibe este cambio al reejecutarse despues de su publicacion validada en stable.

## 2026-10-06 · Mejor rareza primero

- Cambiado el modo principal de tarjetas a Rank real descendente, con ingreso exacto descendente dentro de cada rareza. Aplica a huevos, criaturas y modelos; boton `Rareza ↓` con alternativa `Nombre A-Z` y persistencia existente `sortBest`.
- Build y compilacion de fuentes/bundle correctos; las 26 regresiones del detector pasan. No cambia su filtro ni sus decisiones de hop.
- Potassium verifico el orden de 65 tarjetas Slot de un snapshot real. Las primeras siete fueron Cosmic (Rank 7), seguidas por Mythic (Rank 6), con ingreso descendente dentro de cada grupo. Nombre, persistencia, cerrar/reabrir y una sola GUI correctos.
- Dejadas las criaturas en modo mejor rareza por solicitud del usuario; restaurados filtros Divine >=7B y AUTO activo. El resto de la configuracion visual se conserva.

## 2026-10-06 · Alt izquierdo para abrir/cerrar

- Agregado LeftAlt mediante UserInputService.InputBegan, usando Open/Close existentes y conexion registrada para su limpieza al destruir la sesion. Se muestra la ayuda del atajo en el pie del panel.
- Build y compilacion de fuentes/bundle correctos; 26 regresiones del detector pasan.
- Potassium verifico SendKeyEvent de LeftAlt: abrir/cerrar, persistencia, cerrar selector de especies, campo de minimo enfocado y ayuda sin recorte. RightAlt no alterna el panel.
- Al reejecutar, comprobadas destruccion de la instancia anterior y una alternancia por evento. Durante esta comprobacion tambien se recargo la version publica anterior; por eso la candidata debe distribuirse por CI/CD para conservar el atajo en las siguientes ejecuciones.
- Filtros conservados y AUTO activo al terminar la comprobacion; apertura cerrada como estaba.

## 2026-10-06 · Mejoras integrales del finder (validacion en curso)

- Implementados estados de teleport con persistencia previa, fallo inmediato, filtro de evento por jugador/destino y bloqueo automatico de intentos sin confirmar. Cancelacion de sesiones/conexiones y descarte de resultados antiguos; comprobacion fresca antes de cada intento.
- Detector comparte analisis por snapshot/configuracion e ingresos por UID; invalida durante renovacion y no calcula otras rarezas con el panel cerrado. Panel usa el mismo snapshot, conserva tarjetas visibles por UID y libera modelos al cerrar; recursos opcionales con reintentos.
- Agregados paginacion de servidores, reserva compartida para HTTP, timeout de observacion, persistencia verificada con backup/cache, historial acotado, Detalle con ingreso exacto/motivo, presets pendientes de aplicar y alertas configurables.
- Build y compilacion de fuentes/bundle correctos; 45 regresiones locales pasan, incluidas simulaciones de fallo/cancelacion/timeout/paginacion/backup y recuperacion de modulos. Diff sin errores de whitespace.
- Referencia previa del cliente: snapshot listo de 65 Slot, 30 llamadas Scan en 3,95 ms y 782 descendientes en EggCards. Son datos de esa sesion, no una garantia de FPS ni comparacion final; la primera medicion durante noche se descarto.
- Se cargo una candidata inicial, pero los saltos manuales del usuario interrumpieron la validacion del panel y restauraron la version publica anterior. A solicitud del usuario se espera antes de continuar las pruebas del cliente. Pendientes: suite real UI/persistencia/atajo/reejecucion, renovacion/teleport real, comparacion final, PR/CI y publicacion.

- Checkpoint de revision del coordinador: AutoHopAllowed compartido entre vigilante e inicio; 48 regresiones locales pasan. El PR #4 valida el codigo sin desplegarlo; su primera ejecucion CI 37555539630 paso. La validacion del cliente sigue esperando la indicacion del usuario.

## 2026-10-06 · Mejoras verificadas para publicacion

- Finalizada la validacion autorizada del cliente. Build y compilacion correctos, 50 regresiones y diff sin errores. CI de la candidata optimizada: [run 37556621519](https://github.com/diegotoruno/SAE-SCRIPT/actions/runs/37556621519). Integracion mediante [PR #4](https://github.com/diegotoruno/SAE-SCRIPT/pull/4); el workflow publica el artefacto aprobado en stable y Releases.
- Corregido el coste inicial de serializar cada record: comparacion de campos y versiones por UID, limitada a la rareza seleccionada cuando AUTO no necesita filas completas. Detecta modificaciones en el mismo objeto y cambios del catalogo. 30 Scan con Divine >=7B en un snapshot de 65 Slot: 2,96 ms frente a 3,95 ms de referencia; con siete Common seleccionados: 5,43 ms. Sin afirmaciones de FPS.
- Panel real: 65 filas Slot, siete tarjetas renderizadas y 106 descendientes frente a 782 de referencia. Orden, scroll final, UIScale 0,65, reutilizacion de tarjetas/modelos, liberacion al cerrar, Solo filtro y Detalle exacto pasan. Recursos opcionales fallando temporalmente en un panel aislado: imagenes disponibles y recuperacion de modelos por reintento.
- Presets pendientes de aplicar, numeros exactos, guardar/cargar/borrar, alerta/sonido cargado y persistencia tras recarga verificados. Alt izquierdo con foco/popup, Alt derecho y una alternancia por evento pasan; sesion anterior destruida, cero conexiones propias antiguas y una GUI.
- Coincidencia Common real: AUTO se apaga y se conserva el servidor. Renovacion real: loading durante noche, snapshot nuevo, revision 1 a 3, wait sin Divine y AUTO activo en el mismo servidor. Divine >=7B real no observado; limites exactos cubiertos por regresiones.
- Teleport real mediante Server Hop: llegada al destino elegido y carga automatica de la candidata fijada al commit, pending=false, snapshot listo, filtros/preset/alertas/UI conservados y una GUI. Restaurados Divine >=7B, AUTO activo, criaturas, mejor rareza primero, panel cerrado y alertas por defecto; borrados presets temporales.

## 2026-10-06 · Continuidad por ciclo integrada para CI/CD

- Portada la candidata de continuidad sobre main/build 14 en `codex/ciclo-persistente-ci`, conservando filtros reales, parser exacto, orden por rareza, Alt, virtualizacion, presets, alertas y soporte de teleport existentes. Los cambios anteriores de UI/editor pendientes en la carpeta Documents se conservan fuera de esta publicacion.
- La observacion de la rareza en Slot persiste antes del hop y permite continuar si falta en otro servidor. Vence al inicio de la noche siguiente segun reloj/overrides reales; no implica presencia actual ni usa bases/inventarios. Snapshot del periodo anterior o reset durante scan esperan otra lectura.
- Los intentos guardan ID de conexion. Una reconexion comprobada al origen espera snapshot/reloj y cierra el pending previo sin confundir reejecucion con llegada ni habilitar dos saltos. AUTO manualmente apagado se conserva. El soporte existente de timeout/cancelacion/fallos sigue probado.
- Build y compilacion Luau correctos; 68 regresiones locales pasan (50 existentes y 18 nuevas), diff sin errores. Pruebas de desconexion y huevo ausente offline; no se ejecutaron entradas simuladas, teleports ni nuevas pruebas activas del cliente. La evidencia BAC anterior limita las afirmaciones de estabilidad de aquellos smoke tests.
