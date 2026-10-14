-- ============================================================================
--  SERVER HOP + EGG FINDER  -  independiente de Chilli
-- ----------------------------------------------------------------------------
--  Este script ya NO carga Chilli Hub. Chilli se instala aparte en el autoexec
--  con su propia linea; este bundle solo monta el boton de Server Hop y el
--  buscador de huevos, y no espera ni depende de la UI de Chilli.
--
--  INSTALACION EN OTRO PC:
--    1. Carga este fichero desde el autoexec de tu executor. Es imprescindible:
--       el script debe re-ejecutarse en cada servidor al que llegas.
--
--  PORTABILIDAD: no hay rutas absolutas. readfile/writefile/isfile usan el
--  workspace del executor, que se crea solo en cada PC. Ficheros de estado:
--    server_hop_button_state.json / _visited.json / _pool.json / _ui.json
--
--  MODULOS: server_support (helpers testables), server_pool (lista, Best Ping
--  y pool), account_panel (cuenta), hop_button (tarjeta) y este runtime
--  (sesion, AUTO, saltos, llegada y API). build.py los integra.
--
--  AUTO busca spawns Divine >= 7B/s en el mapa; se detiene al encontrar match.
--  Filtros persistentes: chilli_egg_search_config.json; API: ChilliEggSearch.
--  AUTO: sin Divine espera la renovacion en este servidor; con Divine que no
--  cumpla el minimo hace hop y vuelve a escanear al entrar. Durante el reset
--  espera el snapshot nuevo y repite la decision. Con match se queda y apaga
--  AUTO. El boton principal sigue siendo un salto manual. El estado se guarda en
--  server_hop_button_ui.json, asi que sobrevive a los saltos.
-- ============================================================================

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
--  Reglas de seleccion y medicion:
--    * servidores de 7 plazas; se descarta el actual y los visitados en 1 h
--    * ocupacion ascendente 1/7 -> 2/7 -> ... -> 6/7; dentro de cada grupo
--      se conserva FPS sano y ping ANUNCIADO descendente como heuristica previa.
--      Las observaciones anteriores no prueban el ping de cada usuario.
--      BestLatency nativo de v2 requiere autenticacion y sigue en pruebas.
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
    local Stats = game:GetService("Stats")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")

    -- ---------------------------------------------------------------- arranque
    -- Antes de cualquier uso de LocalPlayer (cuenta, cookie, archivos por
    -- UserId): el autoexec puede ejecutar esto antes de que exista.
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    local player = Players.LocalPlayer
    while not player do
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        player = Players.LocalPlayer
    end

    -- Potassium restaura las capabilities de UI al fijar la identidad en el
    -- hilo que toca CoreGui. Los callbacks creados con task.spawn la necesitan.
    local function uiAccess()
        if type(setthreadidentity) == "function" then setthreadidentity(8) end
    end

    local PLACE_ID = 107778070777162
    local IDEAL_PING = 120
    local IDEAL_PLAYERS = 2
    local STATE_FILE = "server_hop_button_state.json"
    local VISITED_FILE = "server_hop_button_visited.json"
    local SCOUT_STATE_FILE = "steal_an_egg_scout_state.json"
    local UI_FILE = "server_hop_button_ui.json"
    local VISITED_MAX_AGE = 60 * 60
    local PING_SETTLE_SECONDS = 10
    local PING_SAMPLE_INTERVAL = 1
    local PING_SAMPLE_COUNT = 8
    local ARRIVE_STABILIZE_SECONDS = 4
    local RETRY_DELAY_SECONDS = 15   -- espera entre reintentos del salto
    local TELEPORT_CONFIRM_SECONDS = 25  -- margen para que arranque el teleport
    local TELEPORT_HARD_WAIT_SECONDS = 35 -- espera extra si no hay senal alguna
    local PENDING_FRESH_SECONDS = 60      -- espera inicial; unconfirmed requiere clic manual
    local AUTO_POLL_SECONDS = 0.5

    -- Misma paleta grafito/champan del Egg Finder; el rojo queda solo en la accion.
    local COLORS = {
        surface = Color3.fromRGB(20, 24, 30),
        raised = Color3.fromRGB(30, 36, 44),
        border = Color3.fromRGB(56, 65, 77),
        action = Color3.fromRGB(192, 57, 66),
        actionBorder = Color3.fromRGB(232, 120, 126),
        text = Color3.fromRGB(239, 243, 247),
        muted = Color3.fromRGB(170, 183, 197),
        gold = Color3.fromRGB(224, 197, 149),
        green = Color3.fromRGB(147, 215, 191),
        onGreen = Color3.fromRGB(15, 35, 29),
        amber = Color3.fromRGB(242, 190, 122),
    }

    -- ---------------------------------------------------------------- utilidades
    local session
    local support = createFinderSupport()
    local store = support.Store({read = function(path) return readfile(path) end,
        write = function(path, raw) writefile(path, raw) end,
        encode = function(value) return HttpService:JSONEncode(value) end,
        decode = function(raw) return HttpService:JSONDecode(raw) end})
    local function readJson(path, fallback) return store.Read(path, fallback) end
    -- Read-only pruned view; writers of VISITED_FILE must call Invalidate.
    local recentVisited = support.RecentVisited(function() return readJson(VISITED_FILE, {}) end, VISITED_MAX_AGE)
    local function writeJson(path, value)
        if session and not session.alive then return false end
        local ok = store.Write(path, value)
        if not ok then warn("[EggFinder] No se pudo guardar " .. path) end
        return ok
    end
    -- Plain text for people (the readable hunt report); failures stay silent.
    local function writeText(path, text)
        if session and not session.alive then return false end
        return (pcall(writefile, path, text))
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
            if session and not session.alive then return nil end
            task.wait(PING_SAMPLE_INTERVAL)
        end
        for _ = 1, PING_SAMPLE_COUNT do
            local value = readPingValue()
            if value then
                table.insert(series, math.floor(value + 0.5))
            end
            if session and not session.alive then return nil end
            task.wait(PING_SAMPLE_INTERVAL)
        end
        return medianOf(series), series
    end

    -- Servidor en el que nacio esta ejecucion del script. En cuanto game.JobId
    -- deje de coincidir, estamos en otro servidor y NINGUN camino de esta
    -- instancia debe lanzar otro teleport (evita el doble salto observado).
    local sessionStartJobId = game.JobId

    -- Lista de servidores, Best Ping y pool precargado (server_pool.luau).
    local serverPool = createServerPool({support = support, readJson = readJson, writeJson = writeJson,
        recentVisited = recentVisited, sessionStartJobId = sessionStartJobId, placeId = PLACE_ID,
        visitedFile = VISITED_FILE, visitedMaxAge = VISITED_MAX_AGE, userId = Players.LocalPlayer.UserId,
        session = function() return session end})

    local function autoTestRunning()
        local state = readJson(SCOUT_STATE_FILE, nil)
        return type(state) == "table" and state.active == true
    end

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
    -- A script rerun keeps this ID; a new client environment gets a new one.
    hopperEnvironment.__CHILLI_CONNECTION_ID = hopperEnvironment.__CHILLI_CONNECTION_ID or HttpService:GenerateGUID(false)
    local connectionId = hopperEnvironment.__CHILLI_CONNECTION_ID
    local oldSession = hopperEnvironment.__CHILLI_HOPPER_SESSION
    if oldSession and type(oldSession.Destroy) == "function" then oldSession.Destroy() end
    session = { alive = true, autoGeneration = 0, connections = {} }
    local function connect(signal, callback)
        local connection = signal:Connect(function(...)
            if not session.alive then return end
            uiAccess(); callback(...)
        end)
        table.insert(session.connections, connection)
        return connection
    end
    local function disconnectSession()
        for _, connection in ipairs(session.connections) do pcall(function() connection:Disconnect() end) end
        table.clear(session.connections)
    end
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
        disconnectSession()
        if session.DisposeSearch then session.DisposeSearch() end
        if session.DisposePanel then session.DisposePanel() end
        if session.attempt then session.attempt.Cancel() end
        serverPool.Destroy()
        if session.DisposeAccount then session.DisposeAccount() end
    end)
    function session.Destroy()
        session.alive = false
        session.autoGeneration += 1
        disconnectSession()
        if session.DisposeSearch then session.DisposeSearch() end
        if session.DisposePanel then session.DisposePanel() end
        if session.attempt then session.attempt.Cancel() end
        serverPool.Destroy()
        if session.DisposeAccount then session.DisposeAccount() end
        if session.alertSound then session.alertSound:Destroy() end
        if screenGui.Parent then screenGui:Destroy() end
    end

    local autoEnabled
    local card = mountHopButton({session = session, screenGui = screenGui, support = support, colors = COLORS,
        connect = connect, uiAccess = uiAccess, readJson = readJson, writeJson = writeJson, uiFile = UI_FILE,
        isAuto = function() return autoEnabled end})
    autoEnabled = card.savedAuto
    local button, autoChip = card.button, card.autoChip
    local setLabel, setStatus, saveUi = card.SetLabel, card.SetStatus, card.Save
    local updateAutoChip, draggedRecently = card.PaintAuto, card.DraggedRecently

    local busy = false
    serverPool.OnProgress(function(state)
        if session.alive and busy then setStatus(support.NativeProgressMessage(state), COLORS.muted) end
    end)

    local function setBusy(value)
        if not session.alive then return end
        busy = value
        card.SetBusy(value)
    end

    local eggSearch = createMapEggSearch(readJson, writeJson, writeText)
    session.DisposeSearch = eggSearch.Dispose
    session.hopAllowed = false
    session.searchMode = "loading"
    local setAuto
    local PREFERENCES_FILE = "chilli_egg_preferences.json"
    local preferences = readJson(PREFERENCES_FILE, {})
    preferences.presets = type(preferences.presets) == "table" and preferences.presets or {}
    preferences.alerts = type(preferences.alerts) == "table" and preferences.alerts or {}
    preferences.alerts = {notification = preferences.alerts.notification ~= false, sound = preferences.alerts.sound == true}
    local function savePreferences(nextValue)
        assert(writeJson(PREFERENCES_FILE, nextValue), "No se pudieron guardar presets / alertas")
        preferences = nextValue
    end
    local function matchAlert(title, message)
        if preferences.alerts.notification then notify(title, message, 15) end
        if preferences.alerts.sound then
            local ok, err = pcall(function()
                local sound = Instance.new("Sound")
                sound.Name = "EggFinderAlert"; sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"; sound.Volume = 0.5
                sound.Parent = game:GetService("SoundService")
                session.alertSound = sound
                sound:Play(); game:GetService("Debris"):AddItem(sound, 5)
            end)
            if not ok then warn("[EggSearch] Sonido: " .. tostring(err)) end
        end
    end
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
    -- AUTO stays on after a match and follows the capture of that egg. Each
    -- outcome is announced once per target.
    local function noteEggTarget(mode, match, info)
        local tracked = info.tracked
        local key = tracked and tracked.key
        if not key then return end
        if mode == "match" and match and match.key == key and session.alertedTarget ~= key then
            session.alertedTarget = key
            match.jobId, match.placeId, match.at = game.JobId, game.PlaceId, os.time()
            writeJson("chilli_egg_search_match.json", match)
            matchAlert("Egg " .. match.rarity .. " encontrado", string.format(
                "%s · %s/s · %s. AUTO espera la captura.",
                match.name, eggSearch.FormatMinimum(match.income), match.area or "mapa"))
            print("[EggSearch] MATCH " .. HttpService:JSONEncode(match))
        elseif info.capture == "capturado" and session.capturedTarget ~= key then
            session.capturedTarget = key
            if preferences.alerts.notification then
                notify("Egg capturado", tostring(tracked.name) .. ". Espero aquí el nuevo ciclo con AUTO.", 10)
            end
            print("[EggSearch] CAPTURADO " .. tostring(tracked.name) .. " | job=" .. game.JobId)
        elseif info.notCaptured and session.lostTarget ~= key then
            session.lostTarget = key
            if preferences.alerts.notification then
                notify("Egg no capturado", tostring(tracked.name) .. ": " .. info.notCaptured .. ". Busco otro servidor.", 10)
            end
            print("[EggSearch] NO CAPTURADO " .. tostring(tracked.name) .. ": " .. info.notCaptured)
        end
    end
    local function showEggTarget(match, info)
        local target = match or info.tracked or {}
        setLabel("Encontrado")
        setStatus(string.format("%s  ·  %s", tostring(target.name or "Objetivo"), info.capture == "capturando"
            and "capturando" or info.capture == "comprobando" and "comprobando la captura"
            or info.capture == "lo lleva otro jugador" and "lo lleva otro jugador"
            or info.capture == "en disputa" and "en disputa" or "esperando captura"), COLORS.green)
    end
    -- The report never blocks a decision: failures only lose a report entry.
    local function report(name, ...)
        local ok, err = pcall(eggSearch[name], ...)
        if not ok then warn("[EggHunt] " .. tostring(err)) end
    end
    local function verifyMapBeforeHop(server)
        local match, info, _, rows = eggSearch.Scan(true)
        local cycle = eggSearch.CycleStatus()
        local mode = eggSearch.Decide(match, info, cycle or false)
        if mode == "match" then report("ReportDecision", mode, match, info, rows, cycle, game.JobId, os.time()) end
        report("ReportHopCheck", mode, info, rows, game.JobId, server and server.id, os.time(), server)
        setSearchMode(mode)
        noteEggTarget(mode, match, info)
        if mode == "match" then setBusy(false); showEggTarget(match, info) end
        return mode == "hop"
    end
    hopperEnvironment.ChilliEggSearch = {
        Configure = function(filters) return eggSearch.Configure(filters) end,
        Scan = function(fresh)
            local match, info, matches = eggSearch.Scan(fresh)
            return support.Copy(match), support.Copy(info), support.Copy(matches)
        end,
        CycleStatus = function() return eggSearch.CycleStatus() end,
        HuntReport = function() return eggSearch.HuntReport() end,
        BestHistory = function(limit) return eggSearch.BestHistory(nil, limit) end,
        RarityOptions = function() return eggSearch.RarityOptions() end,
        ZoneOptions = function() return eggSearch.ZoneOptions() end,
        Presets = function()
            local list = {}
            for name, config in pairs(preferences.presets) do
                if type(name) == "string" and type(config) == "table" then table.insert(list, {name = name, config = support.Copy(config)}) end
            end
            table.sort(list, function(a,b) return a.name < b.name end); return list
        end,
        SavePreset = function(name, config)
            assert(type(name) == "string", "Escribe un nombre")
            name = name:match("^%s*(.-)%s*$")
            assert(#name > 0 and #name <= 60 and not name:find("[%c]"), "Nombre de preset inválido (máximo 60 bytes)")
            local nextValue = support.Copy(preferences)
            local count = 0; for _ in pairs(nextValue.presets) do count += 1 end
            assert(nextValue.presets[name] or count < 20, "Máximo 20 presets; borra uno para guardar otro")
            nextValue.presets[name] = eggSearch.Validate(config or eggSearch.config)
            savePreferences(nextValue); return name
        end,
        LoadPreset = function(name)
            assert(preferences.presets[name], "Preset desconocido")
            return eggSearch.Validate(support.Copy(preferences.presets[name]))
        end,
        DeletePreset = function(name)
            local nextValue = support.Copy(preferences); nextValue.presets[name] = nil; savePreferences(nextValue)
        end,
        Alerts = function() return support.Copy(preferences.alerts) end,
        ConfigureAlerts = function(patch)
            local nextValue = support.Copy(preferences)
            for key, value in pairs(patch) do
                assert((key == "notification" or key == "sound") and type(value) == "boolean", "Opción de alerta inválida")
                nextValue.alerts[key] = value
            end
            savePreferences(nextValue); return support.Copy(nextValue.alerts)
        end,
        TestAlert = function() matchAlert("Egg Finder", "Prueba de alerta: objetivo encontrado") end,
        Start = function()
            assert(session.alive, "Esta sesion ya termino")
            setAuto(true)
        end,
        Stop = function() if session.alive then setAuto(false) end end,
        GetStatus = function()
            return { active = autoEnabled and session.alive, jobId = game.JobId,
                serverConnection = serverPool.Status(),
                mode = session.searchMode, cycle = eggSearch.CycleStatus(),
                config = support.Copy(eggSearch.config), lastScan = eggSearch.lastScan and {
                    match = support.Copy(eggSearch.lastScan.match), info = support.Copy(eggSearch.lastScan.info),
                    matches = support.Copy(eggSearch.lastScan.matches), revision = eggSearch.lastScan.revision },
                stats = support.Copy(eggSearch.stats), teleport = session.attempt and session.attempt.state,
                searchWindow = eggSearch.SearchWindow() }
        end,
    }

    mountAccountPanel({session = session, screenGui = screenGui, support = support, colors = COLORS,
        connect = connect, uiAccess = uiAccess, pool = serverPool, api = hopperEnvironment.ChilliEggSearch,
        setAuto = function(value) return setAuto(value) end})

    local filterPanel = mountEggFilterPanel({ search = eggSearch,
        api = hopperEnvironment.ChilliEggSearch, session = session, screenGui = screenGui,
        readJson = readJson, writeJson = writeJson,
        scaling = { Drag = support.DragScale, Panel = support.PanelScale } })
    session.DisposePanel = filterPanel.Destroy

    -- ---------------------------------------------------------------- el salto
    serverPool.RestoreReserve()

    -- Several IDs share one verified write of the history file.
    local function markVisited(...)
        local now = os.time()
        local visited = support.PruneVisited(readJson(VISITED_FILE, {}), now, VISITED_MAX_AGE)
        for _, jobId in ipairs({...}) do visited[jobId] = now end
        writeJson(VISITED_FILE, visited)
        recentVisited.Invalidate()
    end
    hopperEnvironment.ChilliEggSearch.RefreshServers = function()
        assert(session.alive, "Esta sesion ya termino")
        local pool, reason = serverPool.Pick()
        if pool and session.alive then serverPool.Save(pool) end
        return support.Copy(pool), reason
    end

    -- Intenta el salto hasta ENTRAR en un servidor. Devuelve true solo cuando
    -- game.JobId cambia (el teleport arranco). Primero usa el pool precargado
    -- (sin consultar nada, para que el clic salga ya); solo si no hay pool util
    -- se consulta la lista en vivo. Al entrar NO se encadena: reportArrival mide
    -- y se para, aunque el servidor no sea optimo.
    local function hopUntilEntered(automatic, generation)
        local owner = session.hopWorker
        local failedRounds = 0
        while canContinueHop(automatic, generation) do
            -- Si el JobId ya cambio, estamos en otro servidor: ni un teleport
            -- mas desde esta instancia, aunque la espera anterior se agotara.
            if game.JobId ~= sessionStartJobId then
                return true
            end

            -- Pool precargado: cero consultas en el clic.
            local pool = serverPool.Load()
            local pickError = nil
            if not pool or #pool == 0 then
                pool, pickError = serverPool.Pick(function() return canContinueHop(automatic, generation) end)
                if not canContinueHop(automatic, generation) then return false end
                if pool then
                    serverPool.Save(pool)
                end
            end

            if pool and #pool > 0 then
                local tries = math.min(#pool, 3)
                for index = 1, tries do
                    if game.JobId ~= sessionStartJobId then
                        return true
                    end

                    if not canContinueHop(automatic, generation) then
                        if session.hopWorker == owner then setBusy(false) end
                        return false
                    end
                    if automatic and not verifyMapBeforeHop(pool[index]) then return false end
                    local candidate = pool[index]
                    setLabel("Saltando...")
                    setStatus(serverPool.Order() == "BestLatency"
                        and string.format("Entrando a un servidor de %d/7 (Best Ping)", candidate.playing)
                        or string.format("Entrando a un servidor de %s ms", tostring(candidate.ping)), COLORS.muted)
                    print(string.format(
                        "[ServerHopButton] Teleport intento %d -> %s",
                        index,
                        candidate.id
                    ))

                    local attempt = support.Attempt({
                        alive = function() return session.alive and (not automatic or autoEnabled) end,
                        save = function(state) return writeJson(STATE_FILE, state) end,
                        time = os.time, clock = os.clock, wait = task.wait,
                        job = function() return game.JobId end,
                        automatic = autoEnabled, id = HttpService:GenerateGUID(false),
                        connectionId = connectionId,
                        player = player, place = PLACE_ID,
                        timeout = TELEPORT_CONFIRM_SECONDS + TELEPORT_HARD_WAIT_SECONDS,
                        connect = function(callback) return TeleportService.TeleportInitFailed:Connect(callback) end,
                        send = function(target) TeleportService:TeleportToPlaceInstance(PLACE_ID, target, player) end,
                    })
                    session.attempt = attempt
                    local result, reason = attempt.Run(candidate.id)
                    if not session.alive or result == "cancelled" then return false end
                    if result == "moved" then markVisited(candidate.id); return true end
                    if result == "failed" then
                        -- Throttling is temporary; don't exclude that server for an hour.
                        if not string.find(string.lower(reason or ""), "flood", 1, true) then markVisited(candidate.id) end
                        setStatus("Servidor rechazado; probando otro", COLORS.amber)
                        print("[ServerHopButton] Teleport rechazado: " .. tostring(reason))
                        if automatic then report("ReportHopFailure", game.JobId, candidate.id, reason, os.time(), candidate) end
                        waitForHop(1.5, automatic, generation)
                    else
                        session.autoHopBlocked = true
                        setBusy(false); setLabel("Server Hop")
                        setStatus(result == "storage" and reason or "Salto sin confirmar. Pulsa Server Hop para reintentar.", COLORS.amber)
                        notify("Server Hop", result == "storage" and reason or "AUTO pausó los saltos: el teleport sigue sin confirmar.", 8)
                        return false
                    end
                end

                setStatus("Roblox no confirmó los servidores; reintentando", COLORS.amber)
            else
                setStatus(string.format(
                    "Sin servidores disponibles (%s). Reintento en %d s",
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
        if session.alive and session.hopWorker == owner then setBusy(false) end
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
            local pending = readJson(STATE_FILE, nil)
            if pending and pending.pending and pending.unconfirmed then
                session.autoHopBlocked = true
                setBusy(false); setStatus("Salto sin confirmar. Pulsa Server Hop para reintentar.", COLORS.amber)
                return
            end
            setStatus("Error: " .. tostring(err) .. ". Reintentando", COLORS.amber)
            waitForHop(RETRY_DELAY_SECONDS, automatic, generation)
        end
    end

    -- El busy se reserva de forma sincrona en el manejador del clic para que un
    -- doble clic no lance dos bucles a la vez.
    local function beginHop(automatic)
        automatic = automatic == true
        if not automatic then session.hopWorker = {} end
        local generation = session.autoGeneration
        if not canContinueHop(automatic, generation) then return end
        if automatic and not verifyMapBeforeHop() then return end
        setBusy(true)

        if game.PlaceId ~= PLACE_ID then
            setBusy(false)
            setStatus("Solo funciona dentro de Steal An Egg", COLORS.amber)
            notify("Server Hop", "Este boton solo funciona dentro de Steal An Egg.", 6)
            return
        end

        if autoTestRunning() then
            setBusy(false)
            setStatus("Auto-test en curso; espera a que termine", COLORS.amber)
            notify("Server Hop", "Hay un auto-test activo. Espera a que termine.", 6)
            return
        end

        local existing = readJson(STATE_FILE, nil)
        if automatic and not support.AutoHopAllowed(existing, game.JobId, os.time(), false,
            session.autoHopBlocked, PENDING_FRESH_SECONDS) then setBusy(false); return end
        if not automatic and existing and existing.unconfirmed then
            if not writeJson(STATE_FILE, {pending = false}) then setBusy(false); return end
            existing = nil; session.autoHopBlocked = false
        end
        -- Solo bloquea si hay un salto realmente en vuelo (el destino no es el
        -- servidor actual). Si estas en el destino midiendo, puedes volver a
        -- pulsar al momento para descartarlo y saltar a otro.
        local inFlight = type(existing) == "table"
            and existing.pending == true
            and existing.target ~= game.JobId
            and (os.time() - (tonumber(existing.requestedAt) or 0)) < PENDING_FRESH_SECONDS
        if inFlight then
            setBusy(false)
            setStatus("Ya hay un salto en curso", COLORS.muted)
            return
        end

        markVisited(game.JobId)
        setLabel("Buscando...")
        setStatus("Buscando un servidor", COLORS.muted)
        runHopLoop(automatic, generation)
    end

    hopperEnvironment.ChilliEggSearch.Hop = function()
        assert(session.alive, "Esta sesion ya termino")
        uiAccess()
        if busy then return false, "salto ocupado" end
        beginHop(false)
        return true
    end

    -- AUTO aplica la misma decision al entrar y en cada renovacion del mapa.
    local autoWatcherStarted = false
    local function startAutoHopWatcher()
        if autoWatcherStarted then return end
        autoWatcherStarted = true
        task.spawn(function()
            local lastMode, lastRevision, lastPeriod
            while autoEnabled and session.alive and game.JobId == sessionStartJobId do
                local watcherOk, watcherError = pcall(function()
                if game.PlaceId ~= PLACE_ID then
                    setSearchMode("loading")
                else
                    local match, info, _, rows = eggSearch.Scan()
                    local cycle = eggSearch.CycleStatus()
                    local mode = eggSearch.Decide(match, info, cycle or false)
                    report("ReportDecision", mode, match, info, rows, cycle, game.JobId, os.time())
                    setSearchMode(mode)
                    noteEggTarget(mode, match, info)
                    local revision = cycle and cycle.fieldRevision
                    local period = cycle and cycle.periodIndex
                    if mode ~= lastMode or revision ~= lastRevision or period ~= lastPeriod then
                        local stats = eggSearch.stats
                        print(string.format("[EggSearch] mode=%s | spawns=%d | rareza=%d | ciclo=%s | estable=%s/%s s (%s) | job=%s",
                            mode, info.count or 0, info.rarityCount or 0, tostring(period),
                            stats.settleSeconds and string.format("%.1f", stats.settleSeconds) or "-",
                            stats.readySeconds and string.format("%.1f", stats.readySeconds) or "-",
                            stats.readyBy or "-", game.JobId))
                        lastMode, lastRevision, lastPeriod = mode, revision, period
                    end
                    local state = readJson(STATE_FILE, nil)
                    if support.AutoHopAllowed(state, game.JobId, os.time(), busy,
                        session.autoHopBlocked, PENDING_FRESH_SECONDS) then
                        if mode == "loading" then
                            setLabel("Escaneando")
                            local reason = info.reason or "esperando datos del mapa"
                            setStatus(string.upper(string.sub(reason, 1, 1)) .. string.sub(reason, 2), COLORS.muted)
                        elseif mode == "wait" then
                            local remaining = cycle and math.ceil(cycle.secondsUntilReset)
                            local scope = #eggSearch.config.zones > 0 and " en tus zonas" or " en el mapa"
                            setLabel(remaining and string.format("Reset %d:%02d",
                                math.floor(remaining / 60), remaining % 60) or "Esperando")
                            setStatus((info.capture == "capturado"
                                and "Capturado: " .. tostring(info.tracked and info.tracked.name)
                                or "Sin " .. eggSearch.config.rarity .. "+" .. scope) .. (cycle and not cycle.running
                                and ". Ciclo en pausa" or ". Esperando la renovación"), info.capture == "capturado"
                                and COLORS.green or COLORS.muted)
                        elseif mode == "match" then
                            showEggTarget(match, info)
                        else
                            setStatus(info.broken
                                and "El juego no cargó bien en este servidor. Buscando otro"
                                or info.notCaptured
                                and "No se capturó (" .. info.notCaptured .. "). Buscando otro servidor"
                                or info.continuingCycle
                                and "Ya apareció en este ciclo, pero aquí no está. Buscando otro servidor"
                                or string.format("%d %s+ aquí, ninguno cumple los filtros. Buscando otro servidor",
                                    info.rarityCount, eggSearch.config.rarity), COLORS.green)
                            -- El vigilante sigue escaneando durante reintentos o renovaciones.
                            setBusy(true)
                            local hopGeneration = session.autoGeneration
                            local worker = {}; session.hopWorker = worker
                            task.spawn(function()
                                local ok, err = pcall(beginHop, true)
                                if session.alive and game.JobId == sessionStartJobId and session.hopWorker == worker then
                                    setBusy(false)
                                    if not ok then warn("[EggSearch] Hop: " .. tostring(err)) end
                                end
                            end)
                        end
                    end
                end
                end)
                if not watcherOk then warn("[EggSearch] Vigilante: " .. tostring(watcherError)) end
                task.wait(watcherOk and AUTO_POLL_SECONDS or 2)
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
            setStatus("Buscando " .. eggSearch.Summary() .. ". Revisando el mapa", COLORS.green)
            startAutoHopWatcher()
        else
            if session.attempt and session.attempt.state == "pending" then
                session.attempt.Cancel(); session.autoHopBlocked = true
            end
            report("ReportStopped", os.time())
            setBusy(false)
            setLabel("Server Hop")
            setStatus("AUTO apagado. Pulsa Server Hop para cambiar de servidor", COLORS.muted)
        end
    end

    connect(autoChip.MouseButton1Click, function()
        if draggedRecently() then
            return
        end
        setAuto(not autoEnabled)
    end)

    connect(button.MouseButton1Click, function()
        if draggedRecently() or busy then
            return
        end

        -- Reserva sincrona contra el doble clic: un clic = un solo bucle.
        setBusy(true)

        task.spawn(function()
            local ok, err = pcall(beginHop)
            if not ok and session.alive then
                setBusy(false)
                setLabel("Server Hop")
                setStatus("Error: " .. tostring(err), COLORS.amber)
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
                    "Último servidor: %d/7 jugadores  ·  %d ms",
                    last.lastPlayers,
                    last.lastPing
                ), ok and COLORS.green or COLORS.amber)
            end
            return
        end

        local disposition = support.TeleportDisposition(state, game.JobId, connectionId)
        if disposition == "blocked" then
            session.autoHopBlocked = true
            setStatus("El salto anterior no se confirmó. Pulsa Server Hop para reintentar.", COLORS.amber)
            return
        end
        if disposition == "reconnected" then
            while session.alive do
                local _, info = eggSearch.Scan(true)
                local cycle = eggSearch.CycleStatus()
                if (info.ready and cycle and cycle.running and not cycle.night) or eggSearch.broken then break end
                task.wait(0.5)
            end
            if not session.alive then return end
            local current = readJson(STATE_FILE, nil)
            if type(current) ~= "table" or current.pending ~= true or current.target ~= state.target
                or current.requestedAt ~= state.requestedAt or current.originConnection ~= state.originConnection then return end
            if not writeJson(STATE_FILE, {pending = false, reconnected = true, at = os.time()}) then
                setStatus("No se pudo cerrar el salto de la conexión anterior", COLORS.amber); return
            end
            session.autoHopBlocked = false
            setBusy(false); setLabel("Server Hop")
            setStatus("Reconectado. Revisando el mapa actual", COLORS.green)
            return
        end
        if os.time() - (tonumber(state.requestedAt) or 0) > 240 then
            writeJson(STATE_FILE, { pending = false })
            setStatus("El salto anterior caducó", COLORS.muted)
            return
        end

        -- Llegada de una busqueda AUTO: se cierra el estado de teleport y se
        -- vuelve a decidir con el snapshot de este servidor.
        if state.auto == true and autoEnabled then
            markVisited(game.JobId, state.target ~= game.JobId and state.target or nil)
            if not writeJson(STATE_FILE, {
                pending = false,
                auto = true,
                lastTarget = state.target,
                at = os.time(),
            }) then setStatus("No se pudo confirmar la llegada", COLORS.amber); return end
            setBusy(false)
            setLabel("Server Hop")
            setStatus("AUTO activo. Revisando el mapa", COLORS.green)
            return
        end

        -- Se guarda a que salto pertenece esta medicion: si mientras medimos
        -- pulsas otra vez, el estado cambia y este resultado se descarta.
        local capturedTarget = state.target
        local capturedAt = state.requestedAt

        setLabel("Midiendo...")
        setStatus("Estabilizando la conexión", COLORS.muted)

        task.wait(ARRIVE_STABILIZE_SECONDS)
        if not session.alive then return end

        local players = #Players:GetPlayers()
        setStatus("Midiendo el ping real", COLORS.muted)

        local ping = measurePing()
        if not session.alive then return end
        local good = type(ping) == "number" and ping <= IDEAL_PING and players <= IDEAL_PLAYERS

        -- Si el estado ya no es el mismo salto (el usuario pulso otra vez
        -- mientras mediamos), este resultado se descarta sin tocar la UI.
        local current = readJson(STATE_FILE, nil)
        if not session.alive or type(current) ~= "table"
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
        writeJson(VISITED_FILE, support.PruneVisited(visited, now, VISITED_MAX_AGE))
        recentVisited.Invalidate()

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
            "%s: %d/7 jugadores  ·  %s ms",
            good and "Servidor bueno" or "Servidor justo",
            players,
            type(ping) == "number" and tostring(ping) or "N/D"
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
                setStatus("Error al medir: " .. tostring(err), COLORS.amber)
                notify("Server Hop", "Error midiendo al llegar: " .. tostring(err), 8)
            end
        else
            if autoEnabled then
                setStatus("AUTO activo. Revisando el mapa", COLORS.green)
            else
                setStatus("Server Hop cambia de servidor. AUTO busca tu huevo", COLORS.muted)
            end
        end
    end)

    serverPool.StartRefresher(function() return busy end)

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
local ok, err = pcall(montarHopper)
if not ok and type(warn) == "function" then
    warn("[ChilliHopper] Error montando el boton: " .. tostring(err))
end
