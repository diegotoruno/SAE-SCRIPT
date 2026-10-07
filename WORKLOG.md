# Estado del trabajo

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
