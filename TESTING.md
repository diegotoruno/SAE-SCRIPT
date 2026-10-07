# Pruebas y validacion

## Comprobacion local y CI

```powershell
.\.venv\Scripts\python.exe build.py
.\.venv\Scripts\python.exe ci_tools.py
```

Se compilan fuentes, punto de entrada, loader, tests y bundle integrado. El CLI oficial Luau 0.741 se descarga y verifica por SHA256. No se ejecuta el bundle de Roblox en el CLI; se ejecuta solo `ci_tests.luau` con un entorno controlado.

Las 26 regresiones cubren: mapa vacio, solo Common, Divine justo bajo 7B, limite exacto, mejor candidato, estados no disponibles, mutacion base, nombre literal, especies exactas, ingreso invalido, catalogo desconocido, minimo invalido, deduplicacion/persistencia, noche, snapshot pendiente, ciclo de renovacion entre hops, snapshot malformado y error al guardar. Los casos nuevos verifican sufijos k/m/b/t/q, numeros sin sufijo por segundo, formatos invalidos/overflow, edicion sin redondear el umbral, opciones de rareza derivadas del catalogo y sus rangos, rechazo de IDs auxiliares y rangos numericos, configuracion antes de cargar datos, compatibilidad de valores guardados y rarezas obsoletas que deben esperar.

Al cambiar una decision o filtro, ampliar las regresiones con el caso que fallo. No agregar tests que se limiten a comparar lineas de codigo.

## Smoke test real con Potassium

1. Obtener clientes actuales con `list_clients`; seleccionar el PID conectado.
2. Ejecutar el cargador y leer consola desde el cursor devuelto por `execute_script`.
3. Consultar `ChilliEggSearch.GetStatus()` y `PanelStatus()` sin cambiar filtros o AUTO. Verificar periodo, snapshot y ausencia de errores.
4. Comparar Uids de tarjetas con `ReadFieldEggs().Records` Slot. El catalogo solo aparece en el selector de especies.
5. Para cambios de UI, comprobar ingreso invalido, aplicar, cambios pendientes, selector multiple, minimizar/reabrir, dimensiones, imagen/modelo y persistencia.
   Para el minimo, verificar `500k`, `25M`, `7b`, `7.5b`, `7,5B`, `1t`, `1Q` y `7` (7/s), edicion/reaplicacion de 6.999.999.999 y 7.000.000.001, y bloqueo de AUTO con entrada invalida. Leer el JSON guardado para confirmar que persiste el numero, no el texto abreviado. Comprobar que cada opcion de rareza tenga especies en Assets.Directory y conserve su Rank real. Al enviar fuentes desde PowerShell, leerlas con `-Encoding UTF8`.
6. Para cambios de ciclo/hopper, observar una renovacion real y comprobar el flujo sin Divine. Verificar server hop y restauracion por autoexec cuando ese comportamiento sea parte del cambio.

Usar los helpers de identidad antes de tocar CoreGui. `gethui()` puede devolver una GUI anidada. Tras un cambio de servidor, volver a listar clientes y verificar la nueva sesion.

No forzar una reconfiguracion del usuario solo para mostrar un resultado. Guardar y restaurar configuracion si una prueba necesita modificarla. El teleport real puede interrumpir una comprobacion en curso.

## Evidencia previa y limites

Antes de CI se compilo el script completo en Potassium y se verificaron 11 escenarios del detector. Se observaron reloj y renovacion reales, un hop real y restauracion por autoexec en una version anterior del hopper. El mecanismo se conserva.

El panel se verifico contra 65 Uids del mapa en una captura del cliente, con selector separado de 18 especies Divine, recursos oficiales y seis modelos 3D visibles. Estos son resultados de esa sesion, no cantidades fijas del juego. Se comprobaron controles invalidos, seleccion multiple, persistencia y limites de layout.

El cargador publico anterior se descargo anonimamente, coincidio por hash con el archivo publicado y ejecuto Chilli, detector y panel con una sola GUI. No se ha visto un spawn real Divine >=7B durante estas verificaciones.

CI valida el codigo propio y las decisiones simuladas. No prueba el render de Roblox, modulos que cambien en el juego, ingresos reales de un huevo al eclosionar, teleports ni el codigo externo de Chilli.
