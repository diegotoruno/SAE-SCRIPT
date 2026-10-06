-- ============================================================================
--  CHILLI + SERVER HOP  -  script unificado y portable
-- ----------------------------------------------------------------------------
--  INSTALACION EN OTRO PC:
--    1. Copia este fichero a la carpeta autoexec de tu executor
--       (Potassium: %LOCALAPPDATA%\Potassium\autoexec\).
--    2. Activa autoexec en el executor. Es imprescindible: el script debe
--       re-ejecutarse en cada servidor al que llegas para medir el ping real
--       y continuar el arranque de Chilli.
--    3. Opcional: para limitar Chilli a una cuenta concreta, copia tambien
--       chilli_client.json al workspace del executor.
--
--  PORTABILIDAD: no hay rutas absolutas. readfile/writefile/isfile usan el
--  workspace del executor, que se crea solo en cada PC. Ficheros de estado:
--    server_hop_button_state.json / _visited.json / _pool.json / _ui.json
--    chilli_timing.txt
--
--  Orden: primero arranca Chilli (con su arranque temprano) y en paralelo se
--  monta el boton de Server Hop, que mide el ping real al llegar.
--
--  AUTO busca spawns Divine >= 7B/s en el mapa; se detiene al encontrar match.
--  Filtros persistentes: chilli_egg_search_config.json; API: ChilliEggSearch.
--  AUTO: sin Divine espera la renovacion en este servidor; con Divine que no
--  cumpla el minimo hace hop y vuelve a escanear al entrar. Durante el reset
--  espera el snapshot nuevo y repite la decision. Con match se queda y apaga
--  AUTO. El boton principal sigue siendo un salto manual. El estado se guarda en
--  server_hop_button_ui.json, asi que sobrevive a los saltos.
-- ============================================================================

local function cargarChilli()
-- Cargador de Chilli Hub (optimizado).
--
-- Cambios respecto al original, medidos en este equipo:
--   * ANTES: esperaba a ciegas 8 s ("los datos llegan unos segundos despues del
--     teletransporte") y DESPUES pedia el script por HTTP (306 + 85 ms) y lo
--     arrancaba. Medido: los datos (Assets.Directory, Rarity, Mutations) ya
--     estan listos en el mismo instante en que aparece el Character, asi que
--     esos 8 s no esperaban a nada.
--   * AHORA: el script se descarga EN PARALELO mientras la experiencia carga, y
--     en lugar de dormir 8 s se comprueba que los datos esten de verdad, con
--     8 s como tope de seguridad. En el caso normal el arranque empieza en
--     cuanto hay personaje.
--
-- Se mantiene TODO lo demas igual: watchdog del auto-test, aplazamiento si el
-- auto-test del Server Hopper esta activo, filtro de cuenta, guardas de doble
-- carga y reintentos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ======================================================== MEDICION
-- Deja la linea de tiempo del arranque en chilli_timing.txt. Es un fichero
-- minusculo y sirve para comprobar que sigue siendo rapido.
local T0 = os.clock()
local marcas = {}
local function marca(nombre)
    marcas[#marcas + 1] = string.format("%s=%.0fms", nombre, (os.clock() - T0) * 1000)
    pcall(function() writefile("chilli_timing.txt", table.concat(marcas, "  ")) end)
end
local uiVisible = false
local function vigilarUi()
    task.spawn(function()
        for _ = 1, 3000 do
            local ok, gui = pcall(function()
                for _, c in ipairs(gethui():GetChildren()) do
                    if c:IsA("ScreenGui") and string.find(c.Name, "Chilli", 1, true) then return c.Name end
                end
            end)
            if ok and gui then
                uiVisible = true
                local env = getgenv and getgenv() or _G
                env.__CHILLI_UI_JOB = game.JobId
                marca("UI_" .. tostring(gui))
                return
            end
            task.wait(0.05)
        end
    end)
end
marca("inicio")

-- =========================================================== PREFETCH
-- Se lanza ya, en paralelo con la carga de la experiencia: cuando lleguemos al
-- punto de cargar el hub, la descarga (unos 0,4 s) ya estara hecha.
local DISPATCHER_URL = "https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua"
local prefetch = { listo = false, fuente = nil, error = nil, ms = 0 }

local function descargar()
    local t0 = os.clock()
    local ok, src = pcall(game.HttpGet, game, DISPATCHER_URL)
    if not ok or type(src) ~= "string" or src == "" then
        prefetch.error = "dispatcher: " .. tostring(src)
        prefetch.ms = (os.clock() - t0) * 1000
        return
    end
    -- El dispatcher devuelve el loader de Luarmor que corresponde a este juego.
    local url = string.match(src, "https://api%.luarmor%.net[^\"]+")
    if url then
        local ok2, src2 = pcall(game.HttpGet, game, url)
        if ok2 and type(src2) == "string" and src2 ~= "" then
            src = src2
        else
            prefetch.error = "luarmor: " .. tostring(src2)
        end
    end
    prefetch.fuente = src
    prefetch.listo = true
    prefetch.ms = (os.clock() - t0) * 1000
end

task.spawn(function() pcall(descargar) end)

-- ======================================= watchdog del auto-test (igual)
do
    local HttpService = game:GetService("HttpService")
    local canTouchState = type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"

    if canTouchState then
        local STATE_FILE = "steal_an_egg_scout_state.json"
        local STALE_SECONDS = 180

        local readOk, state = pcall(function()
            if not isfile(STATE_FILE) then
                return nil
            end
            return HttpService:JSONDecode(readfile(STATE_FILE))
        end)

        if readOk and type(state) == "table" and state.active == true then
            local lastSeen = tonumber(state.lastScoutAt) or 0
            local age = os.time() - lastSeen

            if lastSeen > 0 and age > STALE_SECONDS then
                state.active = false
                pcall(function()
                    writefile(STATE_FILE, HttpService:JSONEncode(state))
                end)
                warn(string.format(
                    "[AutoTestWatchdog] Auto-test sin actividad durante %d s; se desactiva para no bloquear el escaneo.",
                    age
                ))
            end
        end
    end
end

-- ====================== aplazamiento si el auto-test esta activo (igual)
do
    local HttpService = game:GetService("HttpService")
    local STATE_FILE = "steal_an_egg_scout_state.json"
    local canReadState = type(isfile) == "function" and type(readfile) == "function"

    if canReadState then
        local function autoTestActive()
            local ok, state = pcall(function()
                if not isfile(STATE_FILE) then
                    return nil
                end
                return HttpService:JSONDecode(readfile(STATE_FILE))
            end)
            return ok and type(state) == "table" and state.active == true
        end

        if autoTestActive() then
            print("[ChilliLoader] Auto-test de Server Hopper activo: se aplaza la carga del hub para no competir con el scout.")

            local deadline = os.time() + 300
            while os.time() < deadline and autoTestActive() do
                task.wait(2)
            end

            if autoTestActive() then
                warn("[ChilliLoader] El auto-test sigue activo tras 300 s; se carga el hub igualmente.")
            else
                print("[ChilliLoader] Auto-test finalizado: se carga el hub ahora.")
            end
        end
    end
end

-- ================= EXPERIMENTO: arranque temprano del hub ==================
-- Se lanza el chunk en cuanto la fuente esta descargada, sin esperar a que la
-- experiencia termine de cargar, para solapar los ~5 s de Luarmor con la carga
-- de Roblox. Si el chunk falla, el flujo normal de abajo lo relanza; si sigue
-- vivo, no se lanza una segunda copia. Deja marcas en chilli_timing.txt para
-- poder medirlo.
local early = {
    started = false,
    finished = false,
    runOk = false,
    runError = nil,
}

task.spawn(function()
    local waitUntil = os.clock() + 8
    while not prefetch.listo and prefetch.error == nil and os.clock() < waitUntil do
        task.wait(0.05)
    end
    if not prefetch.listo then
        return
    end

    local earlyPlayer = Players.LocalPlayer
    while not earlyPlayer do
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        earlyPlayer = Players.LocalPlayer
    end

    -- Mismo filtro de cuenta que el flujo normal, sin prints.
    local cuentaOk = true
    pcall(function()
        local HttpService = game:GetService("HttpService")
        local cfg = {}
        if type(isfile) == "function" and type(readfile) == "function"
            and isfile("chilli_client.json") then
            cfg = HttpService:JSONDecode(readfile("chilli_client.json")) or {}
        end
        local wantName = tostring(cfg.onlyForUserName or "")
        local wantId = tonumber(cfg.onlyForUserId) or 0
        local nameOk = (wantName == "") or (earlyPlayer.Name == wantName)
        local idOk = (wantId == 0) or (earlyPlayer.UserId == wantId)
        cuentaOk = nameOk and idOk
    end)
    if not cuentaOk then
        return
    end

    local earlyEnv = getgenv and getgenv() or _G
    if earlyEnv.__CHILLI_LOADED_JOB_ID == game.JobId
        or earlyEnv.__CHILLI_LOADING_JOB_ID == game.JobId then
        return
    end
    earlyEnv.__CHILLI_LOADING_JOB_ID = game.JobId

    local chunk = loadstring(prefetch.fuente)
    if not chunk then
        earlyEnv.__CHILLI_LOADING_JOB_ID = nil
        return
    end

    early.started = true
    vigilarUi()
    marca("lanzado_temprano")
    task.spawn(function()
        early.runOk, early.runError = pcall(chunk)
        early.finished = true
    end)
end)
-- ==========================================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end
marca("cargado")

local player = Players.LocalPlayer
while not player do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end
marca("jugador")

player:WaitForChild("PlayerGui", 30)
if not player.Character then
    player.CharacterAdded:Wait()
end
marca("personaje")

-- =================== FILTRO DE CUENTA (en que cliente vive Chilli) ==========
do
    local HttpService = game:GetService("HttpService")
    local cfg = {}
    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function"
            and isfile("chilli_client.json") then
            cfg = HttpService:JSONDecode(readfile("chilli_client.json")) or {}
        end
    end)
    local wantName = tostring(cfg.onlyForUserName or "")
    local wantId = tonumber(cfg.onlyForUserId) or 0
    local nameOk = (wantName == "") or (player.Name == wantName)
    local idOk = (wantId == 0) or (player.UserId == wantId)
    if not (nameOk and idOk) then
        print(string.format(
            "[ChilliLoader] Chilli DESACTIVADO en esta cuenta (%s); solo se carga en %s.",
            player.Name, wantName ~= "" and wantName or ("userId " .. tostring(wantId))))
        return
    end
    print(string.format("[ChilliLoader] Chilli activo en esta cuenta (%s).", player.Name))
end
-- ==========================================================================

local environment = getgenv and getgenv() or _G
local currentJobId = game.JobId

if environment.__CHILLI_LOADED_JOB_ID == currentJobId then
    print("[ChilliLoader] Ya esta cargado en este servidor.")
    return
end

if environment.__CHILLI_LOADING_JOB_ID == currentJobId and not early.started then
    warn("[ChilliLoader] Ya hay una carga en curso.")
    return
end

environment.__CHILLI_LOADING_JOB_ID = currentJobId

-- ===================== espera por DATO, no por reloj (era task.wait(8)) =====
-- Los datos del menu (Assets.Directory, Rarity, Mutations) estan disponibles en
-- cuanto aparece el personaje, asi que en el caso normal esto no espera nada.
-- Si algo tardara, hay un tope de 8 s: nunca se espera mas que antes.
local function datosListos()
    local ok, assets = pcall(function() return require(ReplicatedStorage.Data.Assets) end)
    if ok and type(assets) == "table" and type(assets.Directory) == "table" and next(assets.Directory) ~= nil then
        return true
    end
    return false
end

do
    local t0 = os.clock()
    local esperado = false
    while (os.clock() - t0) < 8 do
        if datosListos() then
            esperado = true
            break
        end
        task.wait(0.1)
    end
    local msDatos = math.floor((os.clock() - t0) * 1000)
    marca("datos")
    -- La fuente ya deberia estar descargada; si no, se espera aqui (decia 8 s).
    local t1 = os.clock()
    while not prefetch.listo and prefetch.error == nil and (os.clock() - t1) < 8 do
        task.wait(0.05)
    end
    marca("script")
    print(string.format("[ChilliLoader] datos=%s en %d ms | script=%s en %d ms",
        esperado and "listos" or "sin confirmar", msDatos,
        prefetch.listo and "descargado" or "pendiente", math.floor(prefetch.ms)))
end
-- ==========================================================================

local MAX_ATTEMPTS = 3
local RETRY_DELAYS = { 8, 12 }

local lastError = "error desconocido"
for attempt = 1, MAX_ATTEMPTS do
    local source = nil
    if attempt == 1 then
        -- lo normal: lo que ya se descargo en paralelo
        if prefetch.listo then
            source = prefetch.fuente
        elseif prefetch.error then
            lastError = prefetch.error
        end
    end
    if source == nil then
        local httpOk, src = pcall(game.HttpGet, game, DISPATCHER_URL)
        if httpOk and type(src) == "string" and src ~= "" then
            local url = string.match(src, "https://api%.luarmor%.net[^\"]+")
            if url then
                local ok2, src2 = pcall(game.HttpGet, game, url)
                if ok2 and type(src2) == "string" and src2 ~= "" then src = src2 end
            end
            source = src
        elseif not httpOk then
            lastError = "fallo HTTP: " .. tostring(src)
        else
            lastError = "el servidor devolvio una respuesta vacia"
        end
    end

    if source == nil then
        -- sin fuente: se reintenta abajo
    else
        local chunk, compileError = loadstring(source)
        if not chunk then
            lastError = "fallo al compilar: " .. tostring(compileError)
        else
            -- Si el intento temprano sigue vivo, darle un margen para su UI
            -- antes de lanzar una segunda copia del hub.
            if early.started and not early.finished and not uiVisible then
                local waitUntil = os.clock() + 6
                while not uiVisible and not early.finished and os.clock() < waitUntil do
                    task.wait(0.1)
                end
            end

            if uiVisible or (early.started and not early.finished) then
                environment.__CHILLI_LOADED_JOB_ID = currentJobId
                environment.__CHILLI_LOADING_JOB_ID = nil
                print(string.format(
                    "[ChilliLoader] Cargado correctamente (intento %d/%d, %s).",
                    attempt,
                    MAX_ATTEMPTS,
                    early.started and "arranque temprano" or "flujo normal"
                ))
                return
            end

            if early.started and early.finished and not early.runOk and type(warn) == "function" then
                warn("[ChilliLoader] Arranque temprano fallo: " .. tostring(early.runError))
            end

            local finished = false
            local runOk = false
            local runError = nil

            vigilarUi()
            marca("lanzado")
            task.spawn(function()
                runOk, runError = pcall(chunk)
                finished = true
            end)

            -- Algunos loaders mantienen vivo su hilo aunque la UI ya se haya
            -- creado. Solo necesitamos detectar los errores del inicio; con la
            -- UI detectada ya no hace falta esperar los 12 s completos.
            for _ = 1, 120 do
                if finished or uiVisible then
                    break
                end
                task.wait(0.1)
            end

            if not finished or runOk or uiVisible then
                environment.__CHILLI_LOADED_JOB_ID = currentJobId
                environment.__CHILLI_LOADING_JOB_ID = nil
                print(string.format("[ChilliLoader] Cargado correctamente (intento %d/%d).", attempt, MAX_ATTEMPTS))
                return
            end
            lastError = tostring(runError)
        end
    end

    if attempt < MAX_ATTEMPTS then
        local delaySeconds = RETRY_DELAYS[attempt] or 12
        warn(string.format(
            "[ChilliLoader] Intento %d/%d fallido: %s. Reintentando en %ds...",
            attempt,
            MAX_ATTEMPTS,
            lastError,
            delaySeconds
        ))
        task.wait(delaySeconds)
    end
end

environment.__CHILLI_LOADING_JOB_ID = nil
warn("[ChilliLoader] No se pudo cargar despues de 3 intentos: " .. lastError)

end

local function montarHopper()
-- ============================================================================
--  SERVER HOP  -  un clic: intenta entrar en UN servidor y se para
-- ----------------------------------------------------------------------------
--  Pulsas el boton UNA vez. El script consulta la lista publica, elige
--  candidatos de 7 plazas y lanza el teleport. Si la API falla (respuesta vacia,
--  JSON invalido, HTTP...) o Roblox rechaza el teleport, NO se rinde: espera y
--  vuelve a intentarlo hasta conseguir entrar. En cuanto entra, la busqueda
--  termina: al llegar mide jugadores y ping reales y los muestra (<=2 jugadores
--  y <=120 ms = si). Aunque salga no, se queda ahi: puede que el servidor te
--  guste igualmente. Si no te gusta, vuelve a pulsar y arranca otro intento
--  (el actual y los visitados en la ultima hora se descartan).
--
--  Rapidez: un pool de candidatos (7 plazas, sin visitados) se refresca solo
--  en segundo plano cada 45 s. El clic no consulta nada: usa el pool y sale al
--  instante; solo si el pool no sirve se consulta la lista en vivo.
--
--  Seguridad anti-rebote: solo se lanza un teleport nuevo si el anterior fue
--  rechazado explicitamente (GameFull, throttle...) o si ya cambiaste de
--  JobId. Si no hay senal alguna en ~1 min, se para y se pide otro clic en vez
--  de pisar un teleport que podria estar en camino.
--
--  Reglas que NO se tocan:
--    * servidores de 7 plazas; se descarta el actual y los visitados en 1 h
--    * candidatos ordenados por el ping ANUNCIADO descendente, porque ese campo
--      de la API esta invertido respecto al ping real (mas alto = mejor
--      conexion medida). Comprobado: anunciado 2092 ms -> 64 ms reales;
--      anunciado 4-22 ms -> 81-307 ms reales.
--    * al llegar se mide de verdad: jugadores reales y ping real (10 s de
--      asentamiento + mediana de 8 muestras, para no confundir el arranque ni
--      los picos con la conexion real)
--    * no se usa queue_on_teleport (duplica instancias y corrompe el estado)
--
--  Vive en autoexec a proposito: asi se re-ejecuta en cada servidor al que
--  llegas, y eso es justo lo que permite medir el ping real tras el salto.
-- ============================================================================

do
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Stats = game:GetService("Stats")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")

    -- Potassium restaura las capabilities de UI al fijar la identidad en el
    -- hilo que toca CoreGui. Los callbacks creados con task.spawn la necesitan.
    local function uiAccess()
        if type(setthreadidentity) == "function" then setthreadidentity(8) end
    end

    local PLACE_ID = 107778070777162
    local EXPECTED_CAPACITY = 7
    local IDEAL_PING = 120
    local IDEAL_PLAYERS = 2
    local STATE_FILE = "server_hop_button_state.json"
    local VISITED_FILE = "server_hop_button_visited.json"
    local SCOUT_STATE_FILE = "steal_an_egg_scout_state.json"
    local UI_FILE = "server_hop_button_ui.json"
    local POOL_FILE = "server_hop_button_pool.json"
    local VISITED_MAX_AGE = 60 * 60
    local POOL_REFRESH_SECONDS = 45   -- cada cuanto se refresca el pool
    local POOL_SIZE = 8               -- candidatos guardados en el pool
    local POOL_MAX_AGE = 180          -- pool mas viejo que esto se ignora
    local PING_SETTLE_SECONDS = 10
    local PING_SAMPLE_INTERVAL = 1
    local PING_SAMPLE_COUNT = 8
    local ARRIVE_STABILIZE_SECONDS = 4
    local RETRY_DELAY_SECONDS = 15   -- espera entre reintentos del salto
    local HTTP_RETRIES = 2           -- intentos por consulta de la lista
    local TELEPORT_CONFIRM_SECONDS = 25  -- margen para que arranque el teleport
    local TELEPORT_HARD_WAIT_SECONDS = 35 -- espera extra si no hay senal alguna
    local PENDING_FRESH_SECONDS = 60      -- un pending mas viejo se puede pisar
    local MIN_API_INTERVAL = 2.0          -- pausa entre consultas a la API
    local API_429_COOLDOWN_SECONDS = 30   -- castigo tras un HTTP 429
    local lastApiRequestAt = -math.huge
    local apiCooldownUntil = 0
    local AUTO_POLL_SECONDS = 0.5

    local COLORS = {
        border = Color3.fromRGB(28, 14, 20),
        redTop = Color3.fromRGB(247, 120, 118),
        redMid = Color3.fromRGB(231, 62, 66),
        redBottom = Color3.fromRGB(184, 18, 24),
        text = Color3.fromRGB(255, 255, 255),
        textShadow = Color3.fromRGB(58, 12, 24),
        textStroke = Color3.fromRGB(34, 10, 22),
        muted = Color3.fromRGB(214, 196, 200),
        green = Color3.fromRGB(88, 226, 150),
        amber = Color3.fromRGB(255, 196, 92),
    }

    -- ---------------------------------------------------------------- utilidades
    local function storageOk()
        return type(isfile) == "function"
            and type(readfile) == "function"
            and type(writefile) == "function"
    end

    local function readJson(path, fallback)
        if not storageOk() then
            return fallback
        end
        local ok, value = pcall(function()
            if not isfile(path) then
                return nil
            end
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(value) == "table" then
            return value
        end
        return fallback
    end

    local function writeJson(path, value)
        if not storageOk() then
            return false
        end
        local ok = pcall(function()
            writefile(path, HttpService:JSONEncode(value))
        end)
        return ok
    end

    local function notify(title, text, duration)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration or 6,
            })
        end)
    end

    local function medianOf(values)
        if #values == 0 then
            return nil
        end
        local sorted = {}
        for index = 1, #values do
            sorted[index] = values[index]
        end
        table.sort(sorted)
        return math.floor(sorted[math.ceil(#sorted / 2)] + 0.5)
    end

    local function readPingValue()
        local ok, value = pcall(function()
            local network = Stats.Network and Stats.Network.ServerStatsItem
            local item = network and network["Data Ping"]
            return item and item:GetValue() or nil
        end)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
        return nil
    end

    -- Igual que en el hopper: se descarta el arranque y se decide con la mediana.
    local function measurePing()
        local series = {}
        local settleUntil = os.clock() + PING_SETTLE_SECONDS
        while os.clock() < settleUntil do
            readPingValue()
            task.wait(PING_SAMPLE_INTERVAL)
        end
        for _ = 1, PING_SAMPLE_COUNT do
            local value = readPingValue()
            if value then
                table.insert(series, math.floor(value + 0.5))
            end
            task.wait(PING_SAMPLE_INTERVAL)
        end
        return medianOf(series), series
    end

    -- Consulta la lista publica con el mismo criterio de errores del
    -- server_hopper de referencia: distingue HTTP no-200, respuesta vacia y
    -- JSON invalido, y reintenta un par de veces antes de devolver el motivo.
    local function fetchServers()
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
            PLACE_ID
        )
        local requestFunction = type(request) == "function" and request or nil
        local lastError = "respuesta desconocida"

        for attempt = 1, HTTP_RETRIES do
            -- Espaciado minimo entre consultas y castigo si Roblox ya respondio
            -- 429, para no encadenar mas limites.
            local nowClock = os.clock()
            if nowClock < apiCooldownUntil then
                task.wait(apiCooldownUntil - nowClock)
            end
            local elapsed = os.clock() - lastApiRequestAt
            if elapsed < MIN_API_INTERVAL then
                task.wait(MIN_API_INTERVAL - elapsed)
            end
            lastApiRequestAt = os.clock()

            local statusCode = nil
            local ok, raw = pcall(function()
                if requestFunction then
                    local response = requestFunction({
                        Url = url,
                        Method = "GET",
                        Headers = { ["Accept"] = "application/json" },
                    })
                    if type(response) == "string" then
                        return response
                    end
                    if type(response) == "table" then
                        statusCode = tonumber(
                            response.StatusCode or response.Status or response.status_code
                        )
                        return response.Body or response.body or ""
                    end
                    return nil
                end
                return game:HttpGet(url)
            end)

            if not ok then
                lastError = "fallo HTTP: " .. tostring(raw)
            elseif statusCode and statusCode ~= 200 then
                lastError = "Roblox respondio HTTP " .. tostring(statusCode)
                if statusCode == 429 then
                    apiCooldownUntil = os.clock() + API_429_COOLDOWN_SECONDS
                end
            elseif type(raw) ~= "string" or raw == "" then
                lastError = "Roblox devolvio una respuesta vacia"
            else
                -- Algunos clientes agregan un BOM UTF-8; JSONDecode no siempre
                -- lo tolera.
                raw = raw:gsub("^\239\187\191", "")
                local decodeOk, decoded = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if decodeOk and type(decoded) == "table" and type(decoded.data) == "table" then
                    return decoded.data
                end
                lastError = "JSON invalido: " .. tostring(decoded)
            end

            print(string.format(
                "[ServerHopButton] Consulta %d/%d fallida: %s",
                attempt,
                HTTP_RETRIES,
                lastError
            ))
            if attempt < HTTP_RETRIES then
                task.wait(statusCode == 429 and 5 or 1.5)
            end
        end

        return nil, lastError
    end

    local function autoTestRunning()
        local state = readJson(SCOUT_STATE_FILE, nil)
        return type(state) == "table" and state.active == true
    end

    -- ---------------------------------------------------------------- arranque
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local player = Players.LocalPlayer
    while not player do
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end

    -- Servidor en el que nacio esta ejecucion del script. En cuanto game.JobId
    -- deje de coincidir, estamos en otro servidor y NINGUN camino de esta
    -- instancia debe lanzar otro teleport (evita el doble salto observado).
    local sessionStartJobId = game.JobId

    local playerGui = player:WaitForChild("PlayerGui", 30)
    if not playerGui then
        playerGui = player:FindFirstChildOfClass("PlayerGui")
    end

    -- ---------------------------------------------------------------- la UI
    local function guiParent()
        if type(gethui) == "function" then
            local ok, result = pcall(gethui)
            if ok and result then
                return result
            end
        end
        local ok = pcall(function()
            return CoreGui.Name
        end)
        if ok then
            return CoreGui
        end
        return playerGui
    end

    local parent = guiParent()
    if not parent then
        return
    end

    local hopperEnvironment = getgenv and getgenv() or _G
    local oldSession = hopperEnvironment.__CHILLI_HOPPER_SESSION
    if oldSession and type(oldSession.Destroy) == "function" then oldSession.Destroy() end
    local session = { alive = true, autoGeneration = 0 }
    hopperEnvironment.__CHILLI_HOPPER_SESSION = session
    local previous = parent:FindFirstChild("ServerHopButton")
    if previous then
        previous:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ServerHopButton"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 500
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parent
    screenGui.Destroying:Connect(function()
        session.alive = false
        if session.DisposeSearch then session.DisposeSearch() end
        if session.DisposePanel then session.DisposePanel() end
    end)
    function session.Destroy()
        session.alive = false
        session.autoGeneration += 1
        if session.DisposeSearch then session.DisposeSearch() end
        if session.DisposePanel then session.DisposePanel() end
        if screenGui.Parent then screenGui:Destroy() end
    end

    -- Estado de la ventana: si esta plegada y donde la dejaste. Se recuerda
    -- tambien entre saltos, porque vive en un archivo, no en memoria.
    local uiState = readJson(UI_FILE, {})
    local collapsed = (uiState.collapsed == true)
    local autoEnabled = (uiState.auto == true)
    local EXPANDED_SIZE = Vector2.new(340, 96)
    local COLLAPSED_SIZE = Vector2.new(210, 42)
    local savedPosition = UDim2.new(0.5, 0, 0, 26)
    if type(uiState.pos) == "table" then
        local pos = uiState.pos
        if type(pos.sx) == "number" and type(pos.xo) == "number"
            and type(pos.sy) == "number" and type(pos.yo) == "number" then
            savedPosition = UDim2.new(pos.sx, pos.xo, pos.sy, pos.yo)
        end
    end

    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.AnchorPoint = Vector2.new(0.5, 0)
    holder.Position = savedPosition
    holder.Size = UDim2.fromOffset(
        collapsed and COLLAPSED_SIZE.X or EXPANDED_SIZE.X,
        collapsed and COLLAPSED_SIZE.Y or EXPANDED_SIZE.Y
    )
    holder.BackgroundColor3 = COLORS.border
    holder.BorderSizePixel = 0
    holder.Active = true
    holder.Parent = screenGui

    local holderCorner = Instance.new("UICorner")
    holderCorner.CornerRadius = UDim.new(0, 15)
    holderCorner.Parent = holder

    local button = Instance.new("TextButton")
    button.Name = "ServerHop"
    button.AutoButtonColor = false
    button.Text = ""
    button.Size = UDim2.new(1, -6, 0, collapsed and 36 or 80)
    button.Position = UDim2.fromOffset(3, 3)
    button.BackgroundColor3 = COLORS.redMid
    button.Parent = holder

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 12)
    buttonCorner.Parent = button

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.redTop),
        ColorSequenceKeypoint.new(0.45, COLORS.redMid),
        ColorSequenceKeypoint.new(1, COLORS.redBottom),
    })
    gradient.Parent = button

    local topShine = Instance.new("Frame")
    topShine.Name = "Shine"
    topShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    topShine.BackgroundTransparency = 0.82
    topShine.BorderSizePixel = 0
    topShine.Size = UDim2.new(1, -15, 0, 16)
    topShine.Position = UDim2.fromOffset(8, 5)
    topShine.ZIndex = 2
    topShine.Parent = button

    local shineCorner = Instance.new("UICorner")
    shineCorner.CornerRadius = UDim.new(1, 0)
    shineCorner.Parent = topShine

    local TITLE_FONT = Enum.Font.GothamBlack
    do
        local ok, font = pcall(function()
            return Enum.Font.FredokaOne
        end)
        if ok and font then
            TITLE_FONT = font
        end
    end

    local function makeText(name, color, zIndex)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = TITLE_FONT
        label.Text = "Server Hop"
        label.TextSize = 34
        label.TextColor3 = color
        label.TextStrokeTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = zIndex
        label.Parent = button
        return label
    end

    -- El trazo nativo del texto es fino (TextStrokeSize no existe en esta version
    -- de Roblox), asi que el contorno grueso de la captura se hace con copias
    -- desplazadas alrededor, siempre por debajo del texto blanco.
    local OUTLINE_OFFSETS = {
        Vector2.new(-2, 0), Vector2.new(2, 0), Vector2.new(0, -2), Vector2.new(0, 2),
        Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1),
    }

    local outlineLabels = {}
    for index, offset in ipairs(OUTLINE_OFFSETS) do
        local outline = makeText("Outline" .. tostring(index), COLORS.textStroke, 3)
        outline.Position = UDim2.fromOffset(offset.X, offset.Y)
        table.insert(outlineLabels, outline)
    end

    local mainLabel = makeText("Label", COLORS.text, 4)
    mainLabel.TextStrokeTransparency = 0
    mainLabel.TextStrokeColor3 = COLORS.textStroke

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, -10, 0, 16)
    statusLabel.Position = UDim2.fromOffset(5, 78)
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.Text = ""
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = COLORS.muted
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = holder

    local function setLabel(text)
        if not session.alive then return end
        uiAccess()
        mainLabel.Text = text
        for _, outline in ipairs(outlineLabels) do
            outline.Text = text
        end
    end

    local function setStatus(text, color)
        if not session.alive then return end
        uiAccess()
        statusLabel.Text = text
        statusLabel.TextColor3 = color or COLORS.muted
    end

    local busy = false

    local function setBusy(value)
        if not session.alive then return end
        uiAccess()
        busy = value
        local target = value and 0.55 or 0
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundTransparency = target,
        }):Play()
    end

    -- ------------------------------------------------- estado de la ventana
    local ARROW_DOWN = "\226\150\188"   -- triangulo abajo
    local ARROW_UP = "\226\150\178"     -- triangulo arriba
    local DRAG_THRESHOLD = 6

    local dragging = false
    local pendingDrag = false
    local dragStart = nil
    local startPosition = nil
    local lastDragAt = -math.huge

    local function saveUi()
        uiAccess()
        local state = readJson(UI_FILE, {})
        state.collapsed = collapsed
        state.auto = autoEnabled
        state.pos = {
            sx = holder.Position.X.Scale,
            xo = holder.Position.X.Offset,
            sy = holder.Position.Y.Scale,
            yo = holder.Position.Y.Offset,
        }
        writeJson(UI_FILE, state)
    end

    local function draggedRecently()
        return (os.clock() - lastDragAt) < 0.25
    end

    -- Chip de plegar/desplegar, en la esquina superior derecha del boton.
    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.AutoButtonColor = false
    toggle.AnchorPoint = Vector2.new(1, 0)
    toggle.Position = UDim2.new(1, -7, 0, 7)
    toggle.Size = UDim2.fromOffset(24, 22)
    toggle.BackgroundColor3 = COLORS.border
    toggle.BackgroundTransparency = 0.12
    toggle.Text = ""
    toggle.ZIndex = 6
    toggle.Parent = button

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 7)
    toggleCorner.Parent = toggle

    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "Arrow"
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Size = UDim2.fromScale(1, 1)
    toggleLabel.Font = Enum.Font.GothamBold
    toggleLabel.Text = ARROW_DOWN
    toggleLabel.TextSize = 13
    toggleLabel.TextColor3 = COLORS.text
    toggleLabel.ZIndex = 7
    toggleLabel.Parent = toggle

    -- Chip AUTO: enciende/apaga el encadenado automatico. Se guarda en
    -- server_hop_button_ui.json para que siga encendido entre saltos.
    local autoChip = Instance.new("TextButton")
    autoChip.Name = "AutoChip"
    autoChip.AutoButtonColor = false
    autoChip.Position = UDim2.new(0, 7, 0, 7)
    autoChip.Size = UDim2.fromOffset(46, 22)
    autoChip.BackgroundColor3 = COLORS.border
    autoChip.BackgroundTransparency = 0.35
    autoChip.Text = ""
    autoChip.ZIndex = 6
    autoChip.Parent = button

    local autoCorner = Instance.new("UICorner")
    autoCorner.CornerRadius = UDim.new(0, 7)
    autoCorner.Parent = autoChip

    local autoLabel = Instance.new("TextLabel")
    autoLabel.Name = "AutoLabel"
    autoLabel.BackgroundTransparency = 1
    autoLabel.Size = UDim2.fromScale(1, 1)
    autoLabel.Font = Enum.Font.GothamBold
    autoLabel.Text = "AUTO"
    autoLabel.TextSize = 11
    autoLabel.TextColor3 = COLORS.muted
    autoLabel.ZIndex = 7
    autoLabel.Parent = autoChip

    local function updateAutoChip()
        uiAccess()
        if autoEnabled then
            autoChip.BackgroundColor3 = COLORS.green
            autoChip.BackgroundTransparency = 0.1
            autoLabel.TextColor3 = Color3.fromRGB(12, 40, 24)
        else
            autoChip.BackgroundColor3 = COLORS.border
            autoChip.BackgroundTransparency = 0.35
            autoLabel.TextColor3 = COLORS.muted
        end
    end

    local function applyCollapsed(value, instant)
        collapsed = value
        local size = value and COLLAPSED_SIZE or EXPANDED_SIZE
        local buttonHeight = value and 36 or 80
        local textSize = value and 17 or 34
        local tween = instant
            and TweenInfo.new(0)
            or TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        TweenService:Create(holder, tween, { Size = UDim2.fromOffset(size.X, size.Y) }):Play()
        TweenService:Create(button, tween, { Size = UDim2.new(1, -6, 0, buttonHeight) }):Play()
        mainLabel.TextSize = textSize
        for _, outline in ipairs(outlineLabels) do
            outline.TextSize = textSize
        end
        statusLabel.Visible = not value
        toggleLabel.Text = value and ARROW_UP or ARROW_DOWN
    end

    -- Arrastrar: desde cualquier punto, con umbral para no confundir un clic
    -- normal con un arrastre, y guardando la posicion al soltar.
    holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            pendingDrag = true
            dragging = false
            dragStart = input.Position
            startPosition = holder.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not pendingDrag or not dragStart then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        if not dragging and delta.Magnitude < DRAG_THRESHOLD then
            return
        end

        dragging = true
        lastDragAt = os.clock()
        holder.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                saveUi()
            end
            pendingDrag = false
            dragging = false
        end
    end)

    toggle.MouseButton1Click:Connect(function()
        if draggedRecently() then
            return
        end
        applyCollapsed(not collapsed)
        saveUi()
    end)

    applyCollapsed(collapsed, true)

    local eggSearch = createMapEggSearch(readJson, writeJson)
    session.DisposeSearch = eggSearch.Dispose
    session.hopAllowed = false
    session.searchMode = "loading"
    local setAuto
    local function canContinueHop(automatic, generation)
        return session.alive and game.JobId == sessionStartJobId
            and (not automatic or (autoEnabled and session.hopAllowed
                and generation == session.autoGeneration))
    end
    local function setSearchMode(mode)
        local allowed = mode == "hop"
        if session.hopAllowed and not allowed then session.autoGeneration += 1 end
        session.hopAllowed, session.searchMode = allowed, mode
    end
    local function waitForHop(seconds, automatic, generation)
        local deadline = os.clock() + seconds
        while os.clock() < deadline and canContinueHop(automatic, generation) do
            task.wait(math.min(0.25, math.max(0, deadline - os.clock())))
        end
    end
    local function finishEggMatch(match)
        setAuto(false)
        session.searchMode = "match"
        match.jobId, match.placeId, match.at = game.JobId, game.PlaceId, os.time()
        writeJson("chilli_egg_search_match.json", match)
        setBusy(false)
        setLabel("MATCH")
        setStatus(string.format("%s · %.2fB/s · %s", match.name,
            match.income / 1000000000, match.area or "mapa"), COLORS.green)
        notify("Egg " .. eggSearch.config.rarity .. " encontrado", string.format(
            "%s · %.2fB/s · %s. Objetivo encontrado; Chilli puede continuar.",
            match.name, match.income / 1000000000, match.area or "mapa"), 15)
        print("[EggSearch] MATCH " .. HttpService:JSONEncode(match))
    end
    local function verifyMapBeforeHop()
        local match, info = eggSearch.Scan()
        if match then finishEggMatch(match); return false end
        local mode = eggSearch.Decide(match, info)
        setSearchMode(mode)
        return mode == "hop"
    end
    hopperEnvironment.ChilliEggSearch = {
        Configure = function(filters) return eggSearch.Configure(filters) end,
        Scan = function() return eggSearch.Scan() end,
        CycleStatus = function() return eggSearch.CycleStatus() end,
        Start = function()
            assert(session.alive, "Esta sesion ya termino")
            setAuto(true)
        end,
        Stop = function() if session.alive then setAuto(false) end end,
        GetStatus = function()
            return { active = autoEnabled and session.alive, jobId = game.JobId,
                mode = session.searchMode, cycle = eggSearch.CycleStatus(),
                config = table.clone(eggSearch.config), lastScan = eggSearch.lastScan }
        end,
    }

    local filterPanel = mountEggFilterPanel({ search = eggSearch,
        api = hopperEnvironment.ChilliEggSearch, session = session, screenGui = screenGui,
        readJson = readJson, writeJson = writeJson })
    session.DisposePanel = filterPanel.Destroy

    -- ---------------------------------------------------------------- el salto
    local function pickCandidates()
        local servers, fetchError = fetchServers()
        if not servers then
            return nil, fetchError
        end

        local visited = readJson(VISITED_FILE, {})
        local now = os.time()
        local pool = {}

        for _, server in ipairs(servers) do
            local id = server.id
            local capacity = tonumber(server.maxPlayers) or 0
            if id and id ~= game.JobId and capacity == EXPECTED_CAPACITY then
                local seenAt = tonumber(visited[id]) or 0
                if now - seenAt > VISITED_MAX_AGE then
                    table.insert(pool, {
                        id = id,
                        ping = tonumber(server.ping) or -1,
                        fps = tonumber(server.fps) or 0,
                    })
                end
            end
        end

        if #pool == 0 then
            return nil, "no quedan servidores nuevos (se probaron todos hace poco)"
        end

        -- Primero los servidores con fps sano (los moribundos suelen fallar con
        -- GameEnded / Unknown exception); dentro de ellos, el ping anunciado
        -- descendente (el ping de la API esta invertido: mas alto = mejor ping
        -- real medido).
        table.sort(pool, function(a, b)
            local aHealthy = (a.fps or 0) >= 50
            local bHealthy = (b.fps or 0) >= 50
            if aHealthy ~= bHealthy then
                return aHealthy
            end
            if a.ping ~= b.ping then
                return a.ping > b.ping
            end
            return a.id < b.id
        end)

        return pool
    end

    -- Guarda los mejores candidatos del momento para que el clic no tenga que
    -- consultar nada. Se refresca en segundo plano cada POOL_REFRESH_SECONDS.
    local function savePool(pool)
        if not pool or #pool == 0 then
            return
        end
        local trimmed = {}
        for index = 1, math.min(#pool, POOL_SIZE) do
            trimmed[index] = pool[index]
        end
        writeJson(POOL_FILE, {
            updatedAt = os.time(),
            servers = trimmed,
        })
    end

    -- Lee el pool guardado (sin HTTP) y filtra lo que ya no sirve: visitados
    -- en la ultima hora y el servidor actual. Si el pool es viejo, se ignora.
    local function loadPool()
        local data = readJson(POOL_FILE, nil)
        if type(data) ~= "table" or type(data.servers) ~= "table" then
            return nil
        end
        if os.time() - (tonumber(data.updatedAt) or 0) > POOL_MAX_AGE then
            return nil
        end

        local visited = readJson(VISITED_FILE, {})
        local now = os.time()
        local pool = {}
        for _, server in ipairs(data.servers) do
            local id = type(server) == "table" and server.id or nil
            if type(id) == "string" and id ~= game.JobId then
                local seenAt = tonumber(visited[id]) or 0
                if now - seenAt > VISITED_MAX_AGE then
                    table.insert(pool, {
                        id = id,
                        ping = tonumber(server.ping) or -1,
                        fps = tonumber(server.fps) or 0,
                    })
                end
            end
        end
        return pool
    end

    local function markVisited(jobId)
        local visited = readJson(VISITED_FILE, {})
        visited[jobId] = os.time()
        writeJson(VISITED_FILE, visited)
    end

    -- Intenta el salto hasta ENTRAR en un servidor. Devuelve true solo cuando
    -- game.JobId cambia (el teleport arranco). Primero usa el pool precargado
    -- (sin consultar nada, para que el clic salga ya); solo si no hay pool util
    -- se consulta la lista en vivo. Al entrar NO se encadena: reportArrival mide
    -- y se para, aunque el servidor no sea optimo.
    local function hopUntilEntered(automatic, generation)
        local failedRounds = 0
        while canContinueHop(automatic, generation) do
            -- Si el JobId ya cambio, estamos en otro servidor: ni un teleport
            -- mas desde esta instancia, aunque la espera anterior se agotara.
            if game.JobId ~= sessionStartJobId then
                return true
            end

            -- Pool precargado: cero consultas en el clic.
            local pool = loadPool()
            local pickError = nil
            if not pool or #pool == 0 then
                pool, pickError = pickCandidates()
                if pool then
                    savePool(pool)
                end
            end

            if pool and #pool > 0 then
                local tries = math.min(#pool, 3)
                for index = 1, tries do
                    if game.JobId ~= sessionStartJobId then
                        return true
                    end

                    if not canContinueHop(automatic, generation) then setBusy(false); return false end
                    if automatic and not verifyMapBeforeHop() then return false end
                    local candidate = pool[index]
                    setLabel("Saltando...")
                    setStatus(string.format(
                        "entrando (api %s ms)...",
                        tostring(candidate.ping)
                    ), COLORS.muted)
                    print(string.format(
                        "[ServerHopButton] Teleport intento %d -> %s",
                        index,
                        candidate.id
                    ))

                    -- El estado se escribe ANTES de saltar: el script se
                    -- re-ejecuta en el destino y necesita saber que hay que
                    -- medir al llegar.
                    writeJson(STATE_FILE, {
                        pending = true,
                        auto = autoEnabled,
                        target = candidate.id,
                        apiPing = candidate.ping,
                        requestedAt = os.time(),
                    })

                    local failed = false
                    local failReason = nil
                    local connection = nil
                    pcall(function()
                        connection = TeleportService.TeleportInitFailed:Connect(function(_, result, message)
                            failed = true
                            failReason = tostring(result) .. " / " .. tostring(message)
                        end)
                    end)

                    local startJobId = game.JobId
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(PLACE_ID, candidate.id, player)
                    end)

                    -- Fase 1: margen normal para que el teleport arranque.
                    local firstDeadline = os.clock() + TELEPORT_CONFIRM_SECONDS
                    while os.clock() < firstDeadline and not failed and game.JobId == startJobId do
                        task.wait(0.25)
                    end

                    local movedToNewServer = game.JobId ~= startJobId

                    if failed or movedToNewServer then
                        if connection then
                            pcall(function()
                                connection:Disconnect()
                            end)
                        end

                        if movedToNewServer then
                            markVisited(candidate.id)
                            return true
                        end

                        -- Fallo explicito de Roblox (GameFull, GameEnded...):
                        -- se marca visitado para no volver a elegirlo y se
                        -- prueba otro con una pausa mas larga (menos throttling).
                        markVisited(candidate.id)
                        writeJson(STATE_FILE, { pending = false })
                        print(string.format(
                            "[ServerHopButton] Candidato no disponible (%s); probando otro",
                            tostring(failReason or "sin motivo")
                        ))
                        setStatus("rechazado; probando otro candidato...", COLORS.amber)
                        task.wait(1.5)
                    else
                        -- Fase 2: sin senal ni de exito ni de fallo. NO se lanza
                        -- otro teleport encima; se espera de largo por si el
                        -- arranque simplemente esta tardando.
                        setStatus("esperando confirmacion del teleport...", COLORS.muted)
                        local hardDeadline = firstDeadline + TELEPORT_HARD_WAIT_SECONDS
                        while os.clock() < hardDeadline and not failed and game.JobId == startJobId do
                            task.wait(0.5)
                        end

                        if connection then
                            pcall(function()
                                connection:Disconnect()
                            end)
                        end

                        if game.JobId ~= startJobId then
                            markVisited(candidate.id)
                            return true
                        end

                        if failed then
                            markVisited(candidate.id)
                            writeJson(STATE_FILE, { pending = false })
                            print(string.format(
                                "[ServerHopButton] Candidato no disponible (%s); probando otro",
                                tostring(failReason or "sin motivo")
                            ))
                            setStatus("rechazado; probando otro candidato...", COLORS.amber)
                            task.wait(1.5)
                        else
                            -- Ni exito ni fallo tras ~60 s: mejor parar que pisar
                            -- un teleport que podria estar en camino.
                            writeJson(STATE_FILE, { pending = false })
                            setBusy(false)
                            setLabel("Server Hop")
                            setStatus("sin confirmar; pulsa otra vez", COLORS.amber)
                            notify("Server Hop", "El teleport no se confirmo. Pulsa otra vez.", 6)
                            return false
                        end
                    end
                end

                setStatus("Roblox no confirmo los candidatos; reintentando...", COLORS.amber)
            else
                setStatus(string.format(
                    "sin candidatos (%s); reintentando en %d s...",
                    tostring(pickError),
                    RETRY_DELAY_SECONDS
                ), COLORS.amber)
            end

            -- Backoff: si una ronda entera falla, se espera el doble para no
            -- castigar al servicio de teleport (Unknown exception en cadena).
            failedRounds = failedRounds + 1
            local roundWait = RETRY_DELAY_SECONDS
            if failedRounds > 1 then
                roundWait = RETRY_DELAY_SECONDS * 2
            end
            waitForHop(roundWait, automatic, generation)
        end
        if session.alive then setBusy(false) end
        return false
    end

    -- Ningun error debe cortar el salto ni quedarse en silencio: se pinta el
    -- motivo en la pastilla y se reintenta.
    local function runHopLoop(automatic, generation)
        while canContinueHop(automatic, generation) do
            local ok, err = pcall(hopUntilEntered, automatic, generation)
            if ok then
                return
            end
            -- Si ya cambiamos de servidor, ni un reintento mas desde aqui.
            if game.JobId ~= sessionStartJobId then
                return
            end
            if not canContinueHop(automatic, generation) then return end
            setStatus("error: " .. tostring(err) .. " · reintentando...", COLORS.amber)
            waitForHop(RETRY_DELAY_SECONDS, automatic, generation)
        end
    end

    -- El busy se reserva de forma sincrona en el manejador del clic para que un
    -- doble clic no lance dos bucles a la vez.
    local function beginHop(automatic)
        automatic = automatic == true
        local generation = session.autoGeneration
        if not canContinueHop(automatic, generation) then return end
        if automatic and not verifyMapBeforeHop() then return end
        setBusy(true)

        if game.PlaceId ~= PLACE_ID then
            setBusy(false)
            setStatus("no estas en Steal An Egg", COLORS.amber)
            notify("Server Hop", "Este boton solo funciona dentro de Steal An Egg.", 6)
            return
        end

        if autoTestRunning() then
            setBusy(false)
            setStatus("auto-test en curso; espera", COLORS.amber)
            notify("Server Hop", "Hay un auto-test activo. Espera a que termine.", 6)
            return
        end

        local existing = readJson(STATE_FILE, nil)
        -- Solo bloquea si hay un salto realmente en vuelo (el destino no es el
        -- servidor actual). Si estas en el destino midiendo, puedes volver a
        -- pulsar al momento para descartarlo y saltar a otro.
        local inFlight = type(existing) == "table"
            and existing.pending == true
            and existing.target ~= game.JobId
            and (os.time() - (tonumber(existing.requestedAt) or 0)) < PENDING_FRESH_SECONDS
        if inFlight then
            setBusy(false)
            setStatus("ya hay un salto en curso", COLORS.muted)
            return
        end

        markVisited(game.JobId)
        setLabel("Buscando...")
        setStatus("buscando servidor...", COLORS.muted)
        runHopLoop(automatic, generation)
    end

    -- Chilli esta listo cuando su cargador lo marca en el entorno o cuando su
    -- UI aparece en gethui (las dos senales valen).
    local function chilliReady()
        local env = getgenv and getgenv() or _G
        if env.__CHILLI_UI_JOB == game.JobId then
            return true
        end
        local ok, found = pcall(function()
            if type(gethui) ~= "function" then
                return false
            end
            for _, child in ipairs(gethui():GetChildren()) do
                if child:IsA("ScreenGui") and string.find(child.Name, "Chilli", 1, true) then
                    return true
                end
            end
            return false
        end)
        return ok and found
    end

    -- AUTO aplica la misma decision al entrar y en cada renovacion del mapa.
    local autoWatcherStarted = false
    local function startAutoHopWatcher()
        if autoWatcherStarted then return end
        autoWatcherStarted = true
        task.spawn(function()
            local lastMode, lastRevision, lastPeriod
            while autoEnabled and session.alive and game.JobId == sessionStartJobId do
                if game.PlaceId ~= PLACE_ID then
                    setSearchMode("loading")
                else
                    local match, info = eggSearch.Scan()
                    local cycle = eggSearch.CycleStatus()
                    local mode = eggSearch.Decide(match, info)
                    setSearchMode(mode)
                    if match then
                        finishEggMatch(match)
                        break
                    end
                    local revision = cycle and cycle.fieldRevision
                    local period = cycle and cycle.periodIndex
                    if mode ~= lastMode or revision ~= lastRevision or period ~= lastPeriod then
                        print(string.format("[EggSearch] mode=%s | spawns=%d | rareza=%d | ciclo=%s | job=%s",
                            mode, info.count or 0, info.rarityCount or 0, tostring(period), game.JobId))
                        lastMode, lastRevision, lastPeriod = mode, revision, period
                    end
                    local state = readJson(STATE_FILE, nil)
                    local inFlight = type(state) == "table" and state.pending == true
                        and state.target ~= game.JobId
                        and os.time() - (tonumber(state.requestedAt) or 0) < PENDING_FRESH_SECONDS
                    if not busy and not inFlight then
                        if mode == "loading" then
                            setLabel("Escaneando")
                            setStatus(info.reason or "esperando datos del mapa...", COLORS.amber)
                        elseif mode == "wait" then
                            local remaining = cycle and math.ceil(cycle.secondsUntilReset)
                            setLabel(remaining and string.format("EGG · %d:%02d",
                                math.floor(remaining / 60), remaining % 60) or "Egg Search")
                            setStatus(cycle and not cycle.running
                                and "sin " .. eggSearch.config.rarity .. " · ciclo pausado" or "sin " .. eggSearch.config.rarity .. " · esperando renovacion", COLORS.muted)
                        else
                            setStatus(string.format("%d %s; ninguno cumple · buscando servidor",
                                info.rarityCount, eggSearch.config.rarity), COLORS.green)
                            -- El vigilante sigue escaneando durante reintentos o renovaciones.
                            setBusy(true)
                            task.spawn(function()
                                local ok, err = pcall(beginHop, true)
                                if session.alive and game.JobId == sessionStartJobId then
                                    setBusy(false)
                                    if not ok then warn("[EggSearch] Hop: " .. tostring(err)) end
                                end
                            end)
                        end
                    end
                end
                task.wait(AUTO_POLL_SECONDS)
            end
            autoWatcherStarted = false
            if autoEnabled and session.alive and game.JobId == sessionStartJobId then startAutoHopWatcher() end
        end)
    end
    setAuto = function(value)
        autoEnabled = value and true or false
        session.autoGeneration += 1
        setSearchMode(autoEnabled and "loading" or "stopped")
        saveUi()
        updateAutoChip()
        if autoEnabled then
            setStatus(eggSearch.Summary() .. " · revisando mapa...", COLORS.green)
            startAutoHopWatcher()
        else
            setLabel("Server Hop")
            setStatus("busqueda apagada · salto manual disponible", COLORS.muted)
        end
    end

    autoChip.MouseButton1Click:Connect(function()
        if draggedRecently() then
            return
        end
        setAuto(not autoEnabled)
    end)

    button.MouseButton1Click:Connect(function()
        if draggedRecently() or busy then
            return
        end

        -- Reserva sincrona contra el doble clic: un clic = un solo bucle.
        setBusy(true)

        task.spawn(function()
            local ok, err = pcall(beginHop)
            if not ok then
                setBusy(false)
                setLabel("Server Hop")
                setStatus("error: " .. tostring(err), COLORS.amber)
                notify("Server Hop", "Error iniciando el salto: " .. tostring(err), 8)
            end
        end)
    end)

    -- -------------------------------------------------- informe al llegar
    local function reportArrival()
        local state = readJson(STATE_FILE, nil)
        if type(state) ~= "table" or state.pending ~= true then
            -- Solo se restaura el ultimo resultado conocido.
            local last = readJson(STATE_FILE, nil)
            if type(last) == "table" and type(last.lastPing) == "number" then
                local ok = last.lastPlayers <= IDEAL_PLAYERS and last.lastPing <= IDEAL_PING
                setStatus(string.format(
                    "ultimo: %d/7 · %d ms %s",
                    last.lastPlayers,
                    last.lastPing,
                    ok and "✓" or "✗"
                ), ok and COLORS.green or COLORS.amber)
            end
            return
        end

        if os.time() - (tonumber(state.requestedAt) or 0) > 240 then
            writeJson(STATE_FILE, { pending = false })
            setStatus("salto caducado", COLORS.muted)
            return
        end

        -- Llegada de una busqueda AUTO: se cierra el estado de teleport y se
        -- vuelve a decidir con el snapshot de este servidor.
        if state.auto == true and autoEnabled then
            markVisited(game.JobId)
            if state.target and state.target ~= game.JobId then markVisited(state.target) end
            writeJson(STATE_FILE, {
                pending = false,
                auto = true,
                lastTarget = state.target,
                at = os.time(),
            })
            setBusy(false)
            setLabel("Server Hop")
            setStatus("AUTO ON · revisando huevos del mapa", COLORS.green)
            return
        end

        -- Se guarda a que salto pertenece esta medicion: si mientras medimos
        -- pulsas otra vez, el estado cambia y este resultado se descarta.
        local capturedTarget = state.target
        local capturedAt = state.requestedAt

        setLabel("Midiendo...")
        setStatus("estabilizando la conexion...", COLORS.muted)

        task.wait(ARRIVE_STABILIZE_SECONDS)

        local players = #Players:GetPlayers()
        setStatus("midiendo ping real...", COLORS.muted)

        local ping = measurePing()
        local good = type(ping) == "number" and ping <= IDEAL_PING and players <= IDEAL_PLAYERS

        -- Si el estado ya no es el mismo salto (el usuario pulso otra vez
        -- mientras mediamos), este resultado se descarta sin tocar la UI.
        local current = readJson(STATE_FILE, nil)
        if type(current) ~= "table"
            or current.pending ~= true
            or current.target ~= capturedTarget
            or current.requestedAt ~= capturedAt then
            return
        end

        -- El hilo que lanzo el salto puede morir durante la pantalla de carga y
        -- no llegar a marcar el visitado. Al llegar se cierra aqui, con el
        -- destino intentado y con el servidor actual, para no repetirlos.
        local visited = readJson(VISITED_FILE, {})
        local now = os.time()
        if type(state.target) == "string" and state.target ~= "" then
            visited[state.target] = now
        end
        if game.JobId ~= "" then
            visited[game.JobId] = now
        end
        writeJson(VISITED_FILE, visited)

        writeJson(STATE_FILE, {
            pending = false,
            lastPlayers = players,
            lastPing = ping,
            target = state.target,
            at = os.time(),
        })

        setBusy(false)
        setLabel("Server Hop")
        setStatus(string.format(
            "%d/7 · %s ms %s",
            players,
            type(ping) == "number" and tostring(ping) or "N/D",
            good and "✓" or "✗"
        ), good and COLORS.green or COLORS.amber)

        notify(
            good and "Servidor bueno" or "Servidor justo",
            string.format(
                "%d/7 jugadores · %s ms reales%s",
                players,
                type(ping) == "number" and tostring(ping) or "N/D",
                good and "" or ". Pulsa otra vez si no te convence."
            ),
            8
        )
    end

    task.spawn(function()
        local state = readJson(STATE_FILE, nil)
        if type(state) == "table" and state.pending == true then
            local ok, err = pcall(reportArrival)
            if not ok then
                setBusy(false)
                setLabel("Server Hop")
                setStatus("error al medir: " .. tostring(err), COLORS.amber)
                notify("Server Hop", "Error midiendo al llegar: " .. tostring(err), 8)
            end
        else
            if autoEnabled then
                setStatus("AUTO ON · revisando huevos del mapa", COLORS.green)
            else
                setStatus("1 clic = salto · AUTO = buscar Divine", COLORS.muted)
            end
        end
    end)

    -- Pool precargado: se refresca solo en segundo plano para que al pulsar el
    -- boton no haya que consultar nada. El primer refresco espera a que Chilli
    -- este montado (su arranque por Luarmor usa la red nada mas entrar) para no
    -- competir con el; despues va cada POOL_REFRESH_SECONDS. No refresca
    -- mientras hay un salto en curso.
    task.spawn(function()
        local function chilliUiReady()
            local ok, ready = pcall(function()
                if type(gethui) ~= "function" then
                    return false
                end
                for _, child in ipairs(gethui():GetChildren()) do
                    if child:IsA("ScreenGui") and string.find(child.Name, "Chilli", 1, true) then
                        return true
                    end
                end
                return false
            end)
            return ok and ready
        end

        local waitUntil = os.clock() + 20
        while os.clock() < waitUntil and not chilliUiReady() do
            task.wait(0.5)
        end

        while session.alive and game.JobId == sessionStartJobId do
            if game.PlaceId == PLACE_ID and not busy then
                local ok, err = pcall(function()
                    local pool = pickCandidates()
                    if pool then
                        savePool(pool)
                        print(string.format(
                            "[ServerHopButton] Pool refrescado: %d candidatos",
                            #pool
                        ))
                    end
                end)
                if not ok and type(warn) == "function" then
                    warn("[ServerHopButton] Pool no refrescado: " .. tostring(err))
                end
            end
            task.wait(POOL_REFRESH_SECONDS)
        end
    end)

    updateAutoChip()
    if autoEnabled then
        startAutoHopWatcher()
    end

    print(string.format(
        "[ServerHopButton] UI lista | job=%s | autoexec ok",
        game.JobId
    ))
end

end


-- ============================================================== ARRANQUE ===
-- Chilli y el boton van en funciones separadas para que los "return" de uno
-- no corten el otro. Chilli arranca en paralelo; el boton se monta despues.
task.spawn(function()
    local ok, err = pcall(cargarChilli)
    if not ok and type(warn) == "function" then
        warn("[ChilliHopper] Error cargando Chilli: " .. tostring(err))
    end
end)

local ok, err = pcall(montarHopper)
if not ok and type(warn) == "function" then
    warn("[ChilliHopper] Error montando el boton: " .. tostring(err))
end
