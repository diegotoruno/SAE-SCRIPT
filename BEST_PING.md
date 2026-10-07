# Conexion local Best Ping

El hopper puede usar el orden nativo `BestLatency` de Roblox v2. Primero intenta candidatos no visitados con 1/7 personas antes de entrar; despues 2/7 y asi hasta 6/7. El orden BestLatency desempata dentro de cada ocupacion. La cuenta autenticada y la ubicacion del PC determinan la lista recibida; no garantiza un ping real concreto.

## Proceso de PC

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
