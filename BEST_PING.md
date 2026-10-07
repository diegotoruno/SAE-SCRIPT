# Conexion local Best Ping

El hopper puede usar el orden nativo `BestLatency` de Roblox v2. Primero intenta candidatos no visitados con 1/7 personas antes de entrar; despues 2/7 y asi hasta 6/7. El orden BestLatency desempata dentro de cada ocupacion. La cuenta autenticada y la ubicacion del PC determinan la lista recibida; no garantiza un ping real concreto.

## Cuenta propia en Delta / Potassium

La candidata incluye un formulario dentro de Roblox. En un dispositivo nuevo se abre al cargar. Tras cerrarlo, el boton fijo **CUENTA / BEST PING** de la esquina inferior izquierda lo reabre, independiente del plegado y la posicion del hopper. Tambien esta en **Egg Filters > Opciones > Cuenta / Best Ping**.

Pega el valor completo de `.ROBLOSECURITY` en el campo oculto. **Guardar y usar AUTO** comprueba una consulta BestLatency, guarda la cookie solo en el workspace local del executor y activa AUTO con los filtros actuales. **Solo esta sesion** no conserva la cookie al reejecutar o cambiar de servidor; al llegar habra que pegarla otra vez. Las decisiones de huevos, rareza minima e ingresos exactos no cambian.

La cookie recordada vive en `sae_account_cookie_<UserId>.json`, separada por cuenta de Roblox. Es un archivo **sin cifrado**: otros scripts con acceso al executor pueden leerlo. No usar almacenamiento compartido entre personas. El codigo no transmite credenciales al autor, GitHub ni al proceso de su PC; declara peticiones autenticadas solo a `https://games.roblox.com`. El modo directo no necesita Python, PC ni proxy.

**Borrar cookie y desconectar** borra/sobrescribe ese archivo, limpia la credencial en memoria y apaga AUTO. Se mantiene el transporte seleccionado, esperando una nueva cookie; no pasa silenciosamente al bridge de otra PC ni al modo legacy. No revoca la sesion de Roblox. Una peticion o teleport ya enviado puede terminar.

El modo guardado es `{"mode":"BestLatency","transport":"DeviceCookie"}` en `server_hop_button_connection.json`; ese archivo no incluye la cookie. `GetStatus().serverConnection.credential` solo tiene `configured` y `remembered`. `OpenServerAccount()`, `CloseServerAccount()` y `ServerAccountStatus()` permiten abrir/cerrar/inspeccionar la ventana sin devolver secretos.

El executor debe ofrecer `request`, `http_request`, `syn.request` o `http.request` con headers y respuesta HTTP, ademas de archivos locales. Se solicita `Redirect=false` y se rechazan respuestas 3xx/destinos finales ajenos a games.roblox.com; **el respeto a ese parametro depende del executor y no se ha verificado en Delta**. No se usa HttpGet como sustituto de una consulta autenticada. Errores de autenticacion detienen las consultas hasta reconectar; 429 espera 60s, y todas las peticiones del modo directo se espacian 15s incluso entre llegadas.

Al conectar, el formulario muestra el contador y distingue el intervalo propio de 15s, HTTP 429 con espera de 60s y una consulta pendiente del executor. La comprobacion inicial tiene prioridad sobre consultas de fondo y reintenta una vez ante 429; conserva el valor oculto para reintentar mientras la ventana siga abierta. Una espera legitima de 60s no expira a los 35s. Si el executor no termina una peticion en 30s, se conserva el bloqueo para evitar peticiones duplicadas y se indica reiniciar Roblox si sigue pendiente. Reejecutar el script no libera por la fuerza una peticion nativa anterior. `GetStatus().serverConnection.request` expone solo kind/seconds/lastHttpStatus, sin secretos.

Para continuar entre hops, **la misma candidata debe estar en autoexec** del dispositivo. El cargador habitual de main/stable aun no incorpora esta funcion. Verificacion local: 117 regresiones Luau y diez pruebas Python; formulario montado/reabierto y limpiado en Potassium con almacenamiento simulado, sin cookies reales ni teleports. Autenticacion y persistencia real desde Delta/iPad pendientes de la prueba del usuario.

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

El proceso mantiene el cursor BestLatency en memoria entre hops y excluye los visitados de la ultima hora. Pausa al tener ocho candidatos de una persona; al consumirlos continua con paginas siguientes. Los registros vencen a los 180s. Cuando no quedan candidatos de una persona conocidos, consulta `OccupancyAsc` sin cookie para comprobar el primer grupo no visitado. La prueba de ocupacion vence a los 90s y se invalida cuando cambia el conjunto de exclusiones. Solo entonces puede seleccionar 2..6 de las paginas BestLatency consultadas. Una lista incompleta por si sola nunca demuestra que no quedan candidatos menores.

Consultas espaciadas al menos 15s en el proceso. HTTP 429 impone 60s; errores de autenticacion y redirects detienen requests hasta cambiar el TXT. Cursores repetidos/respuestas malformadas no prueban agotamiento. Con la conexion habilitada, el hopper espera ante falta de proceso, lista incompleta o error; no sustituye BestLatency por el ping anunciado de v1. La ocupacion puede cambiar antes de llegar.

## Verificacion y vuelta al cargador publicado

```powershell
python build.py
python ci_tools.py
python -m unittest test_best_ping_bridge.py
```

Para volver al cargador publicado, restaurar el autoexec original respaldado y detener el PID del proceso local despues de verificar que pertenece a `best_ping_bridge.py`. No eliminar el TXT del usuario. El modo nativo es optativo; quitar `mode: BestLatency` conserva el modo legacy en el bundle conectado, pero debe reejecutarse para leer ese cambio.
