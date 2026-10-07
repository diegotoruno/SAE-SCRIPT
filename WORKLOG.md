# Estado del trabajo

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
