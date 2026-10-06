# Pruebas y validacion

## Comprobacion local y CI

```powershell
.\.venv\Scripts\python.exe build.py
.\.venv\Scripts\python.exe ci_tools.py
```

Se compilan fuentes, punto de entrada, loader, tests y bundle integrado. El CLI oficial Luau 0.741 se descarga y verifica por SHA256. No se ejecuta el bundle de Roblox en el CLI; se ejecuta solo `ci_tests.luau` con un entorno controlado.

Las 18 regresiones cubren: mapa vacio, solo Common, Divine justo bajo 7B, limite exacto, mejor candidato, estados no disponibles, mutacion base, nombre literal, especies exactas, ingreso invalido, catalogo desconocido, minimo invalido, deduplicacion/persistencia, noche, snapshot pendiente, ciclo de renovacion entre hops, snapshot malformado y error al guardar.

Al cambiar una decision o filtro, ampliar las regresiones con el caso que fallo. No agregar tests que se limiten a comparar lineas de codigo.

## Smoke test real con Potassium

1. Obtener clientes actuales con `list_clients`; seleccionar el PID conectado.
2. Ejecutar el cargador y leer consola desde el cursor devuelto por `execute_script`.
3. Consultar `ChilliEggSearch.GetStatus()` y `PanelStatus()` sin cambiar filtros o AUTO. Verificar periodo, snapshot y ausencia de errores.
4. Comparar Uids de tarjetas con `ReadFieldEggs().Records` Slot. El catalogo solo aparece en el selector de especies.
5. Para cambios de UI, comprobar ingreso invalido, aplicar, cambios pendientes, selector multiple, minimizar/reabrir, dimensiones, imagen/modelo y persistencia.
6. Para cambios de ciclo/hopper, observar una renovacion real y comprobar el flujo sin Divine. Verificar server hop y restauracion por autoexec cuando ese comportamiento sea parte del cambio.

Usar los helpers de identidad antes de tocar CoreGui. `gethui()` puede devolver una GUI anidada. Tras un cambio de servidor, volver a listar clientes y verificar la nueva sesion.

No forzar una reconfiguracion del usuario solo para mostrar un resultado. Guardar y restaurar configuracion si una prueba necesita modificarla. El teleport real puede interrumpir una comprobacion en curso.

## Evidencia previa y limites

Antes de CI se compilo el script completo en Potassium y se verificaron 11 escenarios del detector. Se observaron reloj y renovacion reales, un hop real y restauracion por autoexec en una version anterior del hopper. El mecanismo se conserva.

El panel se verifico contra 65 Uids del mapa en una captura del cliente, con selector separado de 18 especies Divine, recursos oficiales y seis modelos 3D visibles. Estos son resultados de esa sesion, no cantidades fijas del juego. Se comprobaron controles invalidos, seleccion multiple, persistencia y limites de layout.

El cargador publico anterior se descargo anonimamente, coincidio por hash con el archivo publicado y ejecuto Chilli, detector y panel con una sola GUI. No se ha visto un spawn real Divine >=7B durante estas verificaciones.

CI valida el codigo propio y las decisiones simuladas. No prueba el render de Roblox, modulos que cambien en el juego, ingresos reales de un huevo al eclosionar, teleports ni el codigo externo de Chilli.
