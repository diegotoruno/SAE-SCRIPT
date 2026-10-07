# Conexion local Best Ping

El hopper puede usar el orden nativo `BestLatency` de Roblox v2. Con cuenta propia, mantiene hasta 24 destinos rapidos: primero 1/7, despues 2/7 cuando se agota la reserva vigente de una persona. No espera demostrar que se agotaron todos los 1/7 del juego para usar el respaldo. El orden BestLatency desempata dentro de cada ocupacion y pasada de observacion. La cuenta autenticada y la ubicacion del dispositivo determinan la lista recibida; no garantiza un ping real concreto.

## Cuenta propia en Delta / Potassium

El script incluye un formulario dentro de Roblox. En un dispositivo nuevo se abre al cargar. Tras cerrarlo, el boton fijo **CUENTA / BEST PING** de la esquina inferior izquierda lo reabre, independiente del plegado y la posicion del hopper. Tambien esta en **Egg Filters > Opciones > Cuenta / Best Ping**.

Pega el valor completo de `.ROBLOSECURITY` en el campo oculto. **Guardar y usar AUTO** comprueba una consulta BestLatency, guarda la cookie solo en el workspace local del executor y activa AUTO con los filtros actuales. **Solo esta sesion** no conserva la cookie al reejecutar o cambiar de servidor; al llegar habra que pegarla otra vez. Las decisiones de huevos, rareza minima e ingresos exactos no cambian.

Pulsar Guardar no confirma por si solo el guardado. Mientras consulta Roblox, los botones muestran **Comprobando**. Tras escribir y releer el archivo correctamente, la ventana queda abierta con **Cookie guardada en este dispositivo**; al cerrarla el launcher dice **CUENTA · GUARDADA**. Reabrir conserva esa confirmacion; al reejecutar se muestra solo si la cookie se recupero del archivo. La opcion temporal confirma **Cookie activa solo en esta sesion; no se guardo**. El aviso de guardado es independiente de que AUTO encuentre una coincidencia y se apague.

La cookie recordada vive en `sae_account_cookie_<UserId>.json`, separada por cuenta de Roblox. Es un archivo **sin cifrado**: otros scripts con acceso al executor pueden leerlo. No usar almacenamiento compartido entre personas. El codigo no transmite credenciales al autor, GitHub ni al proceso de su PC; declara peticiones autenticadas solo a `https://games.roblox.com`. El modo directo no necesita Python, PC ni proxy.

**Borrar cookie y desconectar** borra/sobrescribe ese archivo, limpia la credencial en memoria y apaga AUTO. Se mantiene el transporte seleccionado, esperando una nueva cookie; no pasa silenciosamente al bridge de otra PC ni al modo legacy. No revoca la sesion de Roblox. Una peticion o teleport ya enviado puede terminar.

El modo guardado es `{"mode":"BestLatency","transport":"DeviceCookie"}` en `server_hop_button_connection.json`; ese archivo no incluye la cookie. `GetStatus().serverConnection.credential` solo tiene `configured` y `remembered`. `OpenServerAccount()`, `CloseServerAccount()` y `ServerAccountStatus()` permiten abrir/cerrar/inspeccionar la ventana sin devolver secretos.

`ServerAccountStatus()` tambien devuelve `connecting` y `message`, con el texto sanitizado de la ventana.

El executor debe ofrecer `request`, `http_request`, `syn.request` o `http.request` con headers y respuesta HTTP, ademas de archivos locales. Se solicita `Redirect=false` y se rechazan respuestas 3xx/destinos finales ajenos a games.roblox.com; **el respeto a ese parametro depende del executor y no se ha verificado en Delta**. No se usa HttpGet como sustituto de una consulta autenticada. Errores de autenticacion detienen las consultas hasta reconectar; 429 espera 60s, y todas las peticiones del modo directo se espacian 15s incluso entre llegadas.

Al conectar, el formulario muestra el contador y distingue el intervalo propio de 15s, HTTP 429 con espera de 60s y una consulta pendiente del executor. La comprobacion inicial tiene prioridad sobre consultas de fondo y reintenta una vez ante 429; conserva el valor oculto para reintentar mientras la ventana siga abierta. Una espera legitima de 60s no expira a los 35s. Si el executor no termina una peticion en 30s, se conserva el bloqueo para evitar peticiones duplicadas y se indica reiniciar Roblox si sigue pendiente. Reejecutar el script no libera por la fuerza una peticion nativa anterior. `GetStatus().serverConnection.request` expone solo kind/seconds/lastHttpStatus, sin secretos.

Para continuar entre hops, **el cargador comun debe estar en autoexec** del dispositivo:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/diegotoruno/SAE-SCRIPT/main/chilli_hopper.luau"))()
```

`main` apunta al bundle validado que CI publica en `stable`. Todos reciben esa version al ejecutar de nuevo; las sesiones ya abiertas conservan la que cargaron. Las cookies y configuraciones permanecen locales. Compilacion y 125 regresiones Luau, mas diez pruebas Python, correctas. Potassium comprobo montaje/reapertura/limpieza con almacenamiento simulado. El usuario confirma **CUENTA · GUARDADA** en Delta/iPad; eso indica comprobacion aceptada y escritura/relectura local terminadas. Continuidad real de DeviceCookie entre hops y respeto de Redirect=false siguen pendientes de evidencia.

Los previews anteriores eran pruebas y pueden quedar atrasados. Un cargador que apunta a un SHA como `e0f669...` queda fijado a esa version. Sustituir esos cargadores y el de `codex/cookie-ipad-preview` por `main` una sola vez para unificar la distribucion. La cookie local ya guardada se conserva al cambiar de cargador. Un script ya ejecutado no se actualiza automaticamente.

## Proceso de PC (alternativa existente)

`best_ping_bridge.py` usa solo Python 3.10+ y la biblioteca estandar. Lee el TXT privado autorizado y envia la cookie exclusivamente a games.roblox.com para BestLatency. Rechaza redirects. No transmite la cookie a RobloxPlayer, al bundle, a resultados ni a Git. No abre un puerto de red.

El proceso intercambia dos JSON en el workspace del executor: `sae_best_ping_request.json` (ID de solicitud, PlaceId, fecha, IDs actuales/visitados) y `sae_best_ping_response.json` (servidores, ocupacion, orden nativo, fechas y estado). Los archivos de respuesta se reemplazan de forma atomica. El runtime lee respuestas frescas directamente, sin la cache JSON general.

Desde la carpeta que contiene estas fuentes:

```powershell
.\start_best_ping.ps1 -CookieFile 'RUTA_PRIVADA\roblox_cookie.txt' -Python 'RUTA_PYTHON\pythonw.exe'
```

El workspace por defecto es `%LOCALAPPDATA%\Potassium\workspace`; se puede cambiar con `-Workspace`. El proceso arranca oculto y su PID queda en `sae_best_ping_bridge.pid`; el launcher evita iniciarlo otra vez si el mismo script sigue activo. Tiene que permanecer abierto en esta PC. Tras reiniciar Windows se debe iniciar otra vez; no se instala como servicio ni se configura inicio automatico de Windows. No se ha conectado a iPad u otro PC.

## Runtime y autoexec

Crear `server_hop_button_connection.json` en el workspace con:

```json
{"mode":"BestLatency"}
```

Construir `dist/chilli_hopper.luau` con `build.py` y ejecutar el bundle con el autoexec habitual. Esta instalacion local de pruebas usa el bundle validado `sae_best_ping_candidate.luau` y un autoexec que lee ese archivo para sobrevivir a los hops. El autoexec original se conserva en `verification/best-ping/connection-backup/autoexec.luau` del workspace principal. No se publico en stable.

`ChilliEggSearch.GetStatus().serverConnection` muestra modo/estado. `RefreshServers()` renueva el pool sin teleport; `Hop()` inicia un salto manual mediante las guardas existentes. No simular clics ni disparar conexiones de UI para probarlo.

## Paginacion y fallos

El transporte DeviceCookie precarga hasta 24 candidatos 1/7 y 2/7 en segundo plano, publicando opciones utiles sin esperar a llenar la reserva. El clic y AUTO consumen esa reserva local sin HTTP. Prioriza todos los 1/7 vigentes antes de cualquier 2/7; dentro de cada ocupacion mantiene orden BestLatency de la pasada mas reciente y luego registros anteriores aun validos. Descarta actual, visitados, duplicados y fechas futuras. Los 1/7 vencen a los 180s; los 2/7, mas abundantes y cambiantes, a los 90s. Owner/transporte/politica deben corresponder al pool guardado. Si no hay opciones 1/7 ni 2/7 utiles, grupos 3..6 mantienen la prueba nueva de ocupacion del flujo anterior.

El cursor y registros sanitizados se guardan en `server_hop_button_native_<UserId>.json`, sin cookie, para continuar una reposicion tras reejecucion/hop si el estado tiene menos de 180s. Los candidatos validos se conservan mientras se refresca desde las primeras paginas de BestLatency, sin perseguir miles de registros de menor prioridad para reunir mas 1/7. Un cursor rechazado/repetido renueva el recorrido; cambiar o borrar la cuenta limpia cursor y reserva. La primera pagina de comprobacion de cuenta se reutiliza. Mientras falta reserva, el boton informa pagina, registros revisados y espera de intervalo/429/request. `GetStatus().serverConnection.reserve` expone count/occupancy/primary/backup/capacity.

La precarga apunta a 24 y revisa necesidad cada 5s: repone al bajar de 16 opciones o al cumplir un respaldo 60s. Una reserva suficiente y reciente no emite nuevas consultas. Cada reposicion vuelve a las primeras paginas nativas, manteniendo candidatos anteriores utiles y dando prioridad a datos nuevos de la misma ocupacion. El limite de 24 deja margen de rechazos/ocupacion cambiante durante la ventana de huevos sin acumular listas ilimitadas que vencerian antes de usarse. Peticiones minimo 15s/cooldown 429 de 60s conservados. Los filtros/ciclo/barrera de carga del huevo no se relajan y encontrar un match sigue deteniendo AUTO. La lista anuncia ocupacion previa al ingreso; ni ocupacion al llegar ni ping minimo estan garantizados.

El proceso mantiene el cursor BestLatency en memoria entre hops y excluye los visitados de la ultima hora. Pausa al tener ocho candidatos de una persona; al consumirlos continua con paginas siguientes. Los registros vencen a los 180s. Cuando no quedan candidatos de una persona conocidos, consulta `OccupancyAsc` sin cookie para comprobar el primer grupo no visitado. La prueba de ocupacion vence a los 90s y se invalida cuando cambia el conjunto de exclusiones. Solo entonces puede seleccionar 2..6 de las paginas BestLatency consultadas. Una lista incompleta por si sola nunca demuestra que no quedan candidatos menores.

Consultas espaciadas al menos 15s en el proceso. HTTP 429 impone 60s; errores de autenticacion y redirects detienen requests hasta cambiar el TXT. Cursores repetidos/respuestas malformadas no prueban agotamiento. Con la conexion habilitada, el hopper espera ante falta de proceso, lista incompleta o error; no sustituye BestLatency por el ping anunciado de v1. La ocupacion puede cambiar antes de llegar.

## Verificacion y vuelta al cargador publicado

```powershell
python build.py
python ci_tools.py
python -m unittest test_best_ping_bridge.py
```

Para volver al cargador publicado, restaurar el autoexec original respaldado y detener el PID del proceso local despues de verificar que pertenece a `best_ping_bridge.py`. No eliminar el TXT del usuario. El modo nativo es optativo; quitar `mode: BestLatency` conserva el modo legacy en el bundle conectado, pero debe reejecutarse para leer ese cambio.
