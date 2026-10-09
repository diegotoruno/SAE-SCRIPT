# Guia para continuar el proyecto

Lee `CONTEXT.md`, `ARCHITECTURE.md`, `DECISIONS.md` y `TESTING.md` antes de cambiar comportamiento. `DEVELOPMENT.md` explica el proyecto de VS Code. `WORKLOG.md` registra el estado verificado.

- La rareza seleccionada es un minimo inclusivo segun Data.Rarity.Rarities/Rank: Eternal acepta Divine y superiores. Sin esa rareza o superior ni observacion vigente esperar; huevos insuficientes iniciar hops y recordar la observacion del ciclo; cualquiera que cumpla quedarse; al empezar la noche siguiente esperar snapshot nuevo y repetir.
- Presencia y evidencia se limitan a las zonas seleccionadas: una zona excluida no inicia hop. Memoria version2 ligada a rareza y conjunto exacto de zonas; cambiar cualquiera cierra la busqueda anterior. Ingreso/nombre/mutacion mantienen la observacion dentro de ese alcance.
- Validar teclado/clics manualmente. No simular entradas ni disparar conexiones de GUI durante pruebas en el cliente publico; hubo expulsiones BAC tras esas pruebas. No interceptar kicks ni modificar anticheat.
- Solo inspeccionar spawns disponibles del mapa: `EggState.ReadFieldEggs().Records` con `State == "Slot"`. No agregar huevos de bases o inventarios.
- Usar el ingreso exacto calculado por los modulos del juego. No comparar la etiqueta redondeada B/s.
- Editar `map_egg_search.luau`, `egg_filter_panel.luau` o `hopper_runtime.luau`. El archivo integrado sale de `build.py`; la raiz `chilli_hopper.luau` es el puente hacia `stable`.
- Ejecutar build y `ci_tools.py` para cambios de Luau. Agregar regresiones cuando cambie una decision del detector. Usar Potassium para UI, persistencia y teleports reales que CI no puede simular.
- Antes de acceder a CoreGui desde un callback, restablecer la identidad con los helpers de acceso existentes. Llamar funciones del juego puede cambiar la identidad del hilo.
- Limpiar la sesion anterior al reejecutar: GUI, conexiones y bucles. Conservar configuracion de usuario y no duplicar Chilli en el mismo servidor.
- Preferir ramas `codex/descripcion` y pull requests hacia `main`. Actualizar documentacion cuando cambien flujo, API, configuracion o distribucion.
- Mantener archivos del executor, credenciales, referencias de terceros y copias de seguridad fuera de Git. No editar directamente `stable`; la publica CI.

El codigo externo de Chilli se carga desde su URL original. No se dispone de sus fuentes internas protegidas; no atribuirle comportamientos que no se hayan observado.
