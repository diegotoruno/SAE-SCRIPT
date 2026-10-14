-- Server list, Best Ping connection and the preloaded pool of the Server Hop.
-- The connection state (order, transport, credential generation) lives here;
-- the account form and the runtime only reach it through these methods.
local function createServerPool(context)
    local HttpService = game:GetService("HttpService")
    local support, readJson, writeJson = context.support, context.readJson, context.writeJson
    local recentVisited, sessionStartJobId = context.recentVisited, context.sessionStartJobId
    local PLACE_ID = context.placeId
    local VISITED_FILE, VISITED_MAX_AGE = context.visitedFile, context.visitedMaxAge
    local EXPECTED_CAPACITY = 7
    local POOL_FILE = "server_hop_button_pool.json"
    local SERVER_SELECTION_POLICY = "occupancy-groups-v2"
    local CONNECTION_FILE = "server_hop_button_connection.json"
    local DEVICE_GATE_FILE = "sae_best_ping_device_gate.json"
    local NATIVE_REQUEST_FILE = "sae_best_ping_request.json"
    local NATIVE_RESPONSE_FILE = "sae_best_ping_response.json"
    local POOL_REFRESH_SECONDS = 45   -- cada cuanto se refresca el pool
    local POOL_SIZE = 8               -- candidatos guardados en el pool
    local BALANCED_RESERVE_SIZE = 24  -- 1/7 first; 2/7 ready when the quick primary reserve is empty
    local POOL_MAX_AGE = 180          -- pool mas viejo que esto se ignora
    local HTTP_RETRIES = 2           -- intentos por consulta de la lista
    local MIN_API_INTERVAL = 2.0          -- pausa entre consultas a la API
    local API_429_COOLDOWN_SECONDS = 30   -- castigo tras un HTTP 429

    -- The session table is created after the pool; read it when it is used.
    local function current() return context.session() end
    local pool = {}
    local connectionConfig = readJson(CONNECTION_FILE, {})
    local serverOrder = connectionConfig.mode == "BestLatency" and "BestLatency" or "LegacyPing"
    local nativeStatus = nil
    local nativeRequestBusy = false
    local deviceCookie = support.DeviceCookie({
        read = function(path) return readfile(path) end,
        write = function(path, raw) writefile(path, raw) end,
        decode = function(raw) return HttpService:JSONDecode(raw) end,
        encode = function(value) return HttpService:JSONEncode(value) end,
        erase = function(path)
            if type(isfile) == "function" and not isfile(path) then return end
            -- Overwrite first; deletion is optional on mobile executors.
            writefile(path, "")
            assert(readfile(path) == "")
            if type(delfile) == "function" then delfile(path) end
        end,
    }, context.userId)
    if connectionConfig.transport == "DeviceCookie" then deviceCookie.Restore() end
    local credentialGeneration, deviceFatal = 0, nil
    local deviceNative

    -- Consulta la lista publica con el mismo criterio de errores del
    -- server_hopper de referencia: distingue HTTP no-200, respuesta vacia y
    -- JSON invalido, y reintenta un par de veces antes de devolver el motivo.
    local apiEnvironment = getgenv and getgenv() or _G
    local apiGate = apiEnvironment.__EGG_API_GATE
    if type(apiGate) ~= "table" then apiGate = {last = -math.huge, cooldown = 0}; apiEnvironment.__EGG_API_GATE = apiGate end
    local deviceGate = apiEnvironment.__EGG_DEVICE_API_GATE
    if type(deviceGate) ~= "table" then
        local savedGate = readJson(DEVICE_GATE_FILE, {})
        local last = tonumber(savedGate.last) or 0
        local cooldown = tonumber(savedGate.cooldown) or 0
        deviceGate = {last = math.min(last, os.time()), cooldown = math.min(cooldown, os.time() + 60)}
        apiEnvironment.__EGG_DEVICE_API_GATE = deviceGate
    end
    local function executorRequest()
        if type(request) == "function" then return request end
        if type(http_request) == "function" then return http_request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        return nil
    end
    local deviceTransport = support.DeviceRequest({now = os.time, clock = os.clock, wait = task.wait, spawn = task.spawn,
        persist = function(last, cooldown)
            writefile(DEVICE_GATE_FILE, HttpService:JSONEncode({last = last, cooldown = cooldown}))
        end}, deviceGate)
    local function deviceFetch(orderBy, cursor, candidate, progress, continuing)
        local generation = credentialGeneration
        if deviceFatal and not candidate then return nil, deviceFatal end
        local secret = candidate or deviceCookie.Read()
        if not secret then return nil, "Abre Cuenta / Best Ping y pega tu cookie." end
        local send = executorRequest()
        if not send then return nil, "Tu executor no ofrece request con headers." end
        local result, reason, status = deviceTransport.Run(function()
            return support.CookiePage({send = send,
                decode = function(raw) return HttpService:JSONDecode(raw) end,
                encode = function(value) return HttpService:UrlEncode(value) end}, orderBy, cursor, secret)
        end, function()
            local session = current()
            return session.alive and generation == credentialGeneration and (candidate ~= nil or not session.accountConnecting)
                and (not continuing or continuing())
        end, progress)
        secret = nil
        if ((status == 400 and not cursor) or status == 401 or status == 403 or status == 302)
            and generation == credentialGeneration then deviceFatal = reason end
        return result, reason, status
    end
    local reportNativeProgress, saveNativePool
    local DEVICE_STREAM_FILE = "server_hop_button_native_" .. tostring(context.userId) .. ".json"
    local function publishNativeProgress(state)
        nativeStatus = state
        if reportNativeProgress then reportNativeProgress(state) end
    end
    local function resetDeviceNative(seed, clear)
        if clear then writeJson(DEVICE_STREAM_FILE, {}) end
        deviceNative = support.DeviceNative({now = os.time,
            reservePolicy = "Balanced",
            save = function(state) writeJson(DEVICE_STREAM_FILE, state) end,
            progress = publishNativeProgress,
            publish = function(value) if saveNativePool and current().alive then saveNativePool(value) end end,
            fetch = function(orderBy, cursor, continuing)
                return deviceFetch(orderBy, cursor, nil, function(waitState)
                    local state = support.Copy(nativeStatus or {})
                    state.wait = waitState; publishNativeProgress(state)
                end, continuing)
            end,
            alive = function() local session = current(); return session and session.alive and not session.accountConnecting end})
        if seed then deviceNative.Seed(seed)
        else deviceNative.Restore(readJson(DEVICE_STREAM_FILE, {})) end
    end
    resetDeviceNative()
    local function fetchServers(cursor)
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
            PLACE_ID
        )
        if cursor then url ..= "&cursor=" .. HttpService:UrlEncode(cursor) end
        local requestFunction = type(request) == "function" and request or nil
        local lastError = "respuesta desconocida"
        local session = current()

        for attempt = 1, HTTP_RETRIES do
            -- Espaciado minimo entre consultas y castigo si Roblox ya respondio
            -- 429, para no encadenar mas limites.
            local lockDeadline = os.clock() + 35
            local reserved = false
            while session.alive and os.clock() < lockDeadline do
                local now = os.clock()
                local delay = math.max(apiGate.cooldown - now, MIN_API_INTERVAL - (now - apiGate.last))
                if not apiGate.busy and delay <= 0 then
                    apiGate.busy = true; apiGate.last = now; reserved = true; break
                end
                task.wait(math.min(0.25, math.max(0.05, delay)))
            end
            if not session.alive then return nil, "sesion terminada" end
            if not reserved then return nil, "consulta anterior / cooldown sigue pendiente" end

            local statusCode = nil
            local completed, ok, raw = false, false, nil
            task.spawn(function()
            ok, raw = pcall(function()
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

            if statusCode == 429 then apiGate.cooldown = os.clock() + API_429_COOLDOWN_SECONDS end
            completed = true; apiGate.busy = false
            end)
            local responseDeadline = os.clock() + 30
            while not completed and session.alive and os.clock() < responseDeadline do task.wait(0.1) end
            if not session.alive then return nil, "sesion terminada" end
            if not completed then return nil, "la consulta HTTP excedio 30 s" end
            if not ok then
                lastError = "fallo HTTP: " .. tostring(raw)
            elseif statusCode and statusCode ~= 200 then
                lastError = "Roblox respondio HTTP " .. tostring(statusCode)
                if statusCode == 429 then
                    apiGate.cooldown = math.max(apiGate.cooldown, os.clock() + API_429_COOLDOWN_SECONDS)
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
                    return decoded
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

    -- ---------------------------------------------------------------- el pool
    local function pickCandidates(continuing, wanted)
        local session = current()
        local visited = recentVisited.Get(os.time())
        local now = os.time()
        if serverOrder == "BestLatency" then
            if connectionConfig.transport == "DeviceCookie" then
                if session.accountConnecting then return nil, "conectando la cuenta; espera la comprobacion" end
                if nativeRequestBusy then return nil, "consulta Best Ping en curso" end
                nativeRequestBusy = true
                local generation = credentialGeneration
                local ok, pool, reason = pcall(deviceNative.Pick, game.JobId, visited, continuing, wanted)
                nativeRequestBusy = false
                if not session.alive or generation ~= credentialGeneration then return nil, "conexion cancelada" end
                if not ok then pool, reason = nil, "No se pudo leer Best Ping en este dispositivo." end
                nativeStatus = nativeStatus or {}
                nativeStatus.state, nativeStatus.error, nativeStatus.wait = pool and "ready" or "waiting", reason, nil
                if pool then nativeStatus.occupancy = pool[1].playing end
                return pool, reason
            end
            if nativeRequestBusy then return nil, "consulta Best Ping en curso" end
            nativeRequestBusy = true
            local excluded = {game.JobId}
            for id in pairs(visited) do table.insert(excluded, id) end
            local requestId = HttpService:GenerateGUID(false)
            local ok = pcall(function()
                writefile(NATIVE_REQUEST_FILE, HttpService:JSONEncode({placeId = PLACE_ID,
                    requestId = requestId, requestedAt = now, excluded = excluded}))
            end)
            if not ok then nativeRequestBusy = false; return nil, "no se pudo solicitar Best Ping al PC" end
            local deadline = os.clock() + 3
            repeat
                local decoded, data = pcall(function()
                    return HttpService:JSONDecode(readfile(NATIVE_RESPONSE_FILE))
                end)
                if decoded and type(data) == "table" and data.requestId == requestId then
                    local pool, reason = support.NativePool(data, requestId, os.time(), game.JobId, visited)
                    nativeStatus = {state = data.state, pages = data.pages, complete = data.complete,
                        occupancy = data.occupancy, error = reason}
                    nativeRequestBusy = false
                    return pool, reason
                end
                task.wait(0.1)
            until not session.alive or game.JobId ~= sessionStartJobId or os.clock() >= deadline
            nativeRequestBusy = false
            return nil, "esperando proceso Best Ping del PC"
        end
        local servers, fetchError = support.Pages(fetchServers, function(server)
            return type(server.id) == "string" and server.id ~= game.JobId
                and tonumber(server.maxPlayers) == EXPECTED_CAPACITY
                and tonumber(server.playing) ~= nil and tonumber(server.playing) >= 1
                and tonumber(server.playing) < EXPECTED_CAPACITY
                and tonumber(server.playing) == math.floor(tonumber(server.playing))
                and now - (tonumber(visited[server.id]) or 0) > VISITED_MAX_AGE
        end, function() return session.alive and game.JobId == sessionStartJobId end, POOL_SIZE, 5)
        if not servers then return nil, fetchError end
        -- fetchServers uses Occupancy Asc: the earliest eligible records prove
        -- the lowest available group, even when later pages remain unread.
        local pool = support.OccupancyGroup(servers, "LegacyPing", true)

        if #pool == 0 then
            return nil, "no quedan servidores nuevos (se probaron todos hace poco)"
        end

        -- Ocupacion 1 -> 2 -> ... -> 6 antes de FPS/ping. BestLatency sigue en pruebas:
        -- la peticion v2 sin sesion web devuelve Guest users are not allowed.
        return pool
    end

    -- Guarda los mejores candidatos del momento para que el clic no tenga que
    -- consultar nada. Se refresca en segundo plano cada POOL_REFRESH_SECONDS.
    local function savePool(pool)
        if not pool or #pool == 0 then
            return
        end
        local balanced = serverOrder == "BestLatency" and connectionConfig.transport == "DeviceCookie"
        local group = balanced and support.BalancedReserve(pool, os.time(), game.JobId,
            recentVisited.Get(os.time()), BALANCED_RESERVE_SIZE)
            or support.OccupancyGroup(pool, serverOrder, true)
        if #group == 0 then return end
        local trimmed = {}
        for index = 1, math.min(#group, balanced and BALANCED_RESERVE_SIZE or POOL_SIZE) do
            trimmed[index] = group[index]
        end
        writeJson(POOL_FILE, {
            selectionPolicy = SERVER_SELECTION_POLICY,
            orderBy = serverOrder,
            transport = connectionConfig.transport or "LocalBridge",
            owner = context.userId,
            reservePolicy = balanced and "balanced-1-2-v1" or nil,
            occupancy = group[1].playing,
            updatedAt = os.time(),
            servers = trimmed,
        })
    end
    saveNativePool = savePool

    -- Lee el pool guardado (sin HTTP) y filtra lo que ya no sirve: visitados
    -- en la ultima hora y el servidor actual. Si el pool es viejo, se ignora.
    local function loadPool()
        local data = readJson(POOL_FILE, nil)
        if type(data) ~= "table" or type(data.servers) ~= "table" then
            return nil
        end
        if data.selectionPolicy ~= SERVER_SELECTION_POLICY then return nil end
        if data.orderBy ~= serverOrder then return nil end
        if serverOrder == "BestLatency" then
            if data.owner ~= context.userId then return nil end
            if connectionConfig.transport == "DeviceCookie" and (deviceFatal or not deviceCookie.Status().configured) then return nil end
            return support.PreloadedNativePool(data, os.time(), game.JobId,
                recentVisited.Get(os.time()),
                connectionConfig.transport or "LocalBridge", connectionConfig.transport == "DeviceCookie")
        end
        local occupancy = tonumber(data.occupancy)
        if not occupancy or occupancy < 1 or occupancy >= EXPECTED_CAPACITY
            or occupancy ~= math.floor(occupancy) then return nil end
        -- Before another hop in groups 2..6, query again: a lower-occupancy
        -- server may have become available since this cache was created.
        if occupancy > 1 then return nil end
        if os.time() - (tonumber(data.updatedAt) or 0) > POOL_MAX_AGE then
            return nil
        end

        local visited = readJson(VISITED_FILE, {})
        local now = os.time()
        local pool = {}
        for _, server in ipairs(data.servers) do
            local id = type(server) == "table" and server.id or nil
            if type(server) ~= "table" or tonumber(server.playing) ~= occupancy then return nil end
            if type(id) == "string" and id ~= game.JobId then
                local seenAt = tonumber(visited[id]) or 0
                if now - seenAt > VISITED_MAX_AGE then
                    table.insert(pool, {
                        id = id,
                        playing = tonumber(server.playing),
                        ping = tonumber(server.ping) or -1,
                        fps = tonumber(server.fps) or 0,
                    })
                end
            end
        end
        return support.RankServers(pool, "LegacyPing")
    end

    local function reserveStatus()
        local pool = loadPool()
        local primary, backup = 0, 0
        for _, row in ipairs(pool or {}) do
            if row.playing == 1 then primary += 1 elseif row.playing == 2 then backup += 1 end
        end
        return {count = pool and #pool or 0, occupancy = pool and pool[1].playing or nil,
            primary = primary, backup = backup, capacity = connectionConfig.transport == "DeviceCookie" and BALANCED_RESERVE_SIZE or POOL_SIZE}
    end

    pool.Pick = pickCandidates
    pool.Save = savePool
    pool.Load = loadPool
    function pool.Order() return serverOrder end
    function pool.Connection() return connectionConfig end
    function pool.OnProgress(callback) reportNativeProgress = callback end
    function pool.Status()
        return {orderBy = serverOrder, transport = connectionConfig.transport or "LocalBridge",
            credential = deviceCookie.Status(), request = deviceTransport.State(), native = support.Copy(nativeStatus),
            reserve = reserveStatus()}
    end
    -- A saved device reserve is usable at once, without another query.
    function pool.RestoreReserve()
        if connectionConfig.transport == "DeviceCookie" then
            local restored = deviceNative.Reserve(game.JobId,
                recentVisited.Get(os.time()))
            if restored then savePool(restored) end
        end
    end

    -- Account form: the cookie itself never leaves this closure.
    pool.ExecutorRequest = executorRequest
    function pool.CredentialStatus() return deviceCookie.Status() end
    function pool.TransportState() return deviceTransport.State() end
    function pool.Generation() return credentialGeneration end
    function pool.CancelCredential() credentialGeneration += 1 end
    function pool.Verify(candidate, progress) return deviceFetch("BestLatency", nil, candidate, progress) end
    function pool.Remember(candidate, persist)
        local ok, reason = deviceCookie.Set(candidate, persist)
        if ok then
            connectionConfig = {mode = "BestLatency", transport = "DeviceCookie"}
            ok = writeJson(CONNECTION_FILE, connectionConfig)
            if not ok then reason = "No se pudo guardar el modo de conexion. Reintenta." end
        end
        return ok, reason
    end
    function pool.Connected(page)
        credentialGeneration += 1; deviceFatal = nil; serverOrder = "BestLatency"
        writeJson(POOL_FILE, {servers = {}}); resetDeviceNative(page, true)
    end
    function pool.MarkConnected() nativeStatus = {state = "connected"} end
    function pool.Forget()
        local removed = deviceCookie.Forget()
        deviceFatal = nil; writeJson(POOL_FILE, {servers = {}}); resetDeviceNative(nil, true)
        -- Leave the selected transport enabled: an absent cookie waits;
        -- it must not silently resume legacy or the owner's PC bridge.
        connectionConfig = {mode = "BestLatency", transport = "DeviceCookie"}
        serverOrder = "BestLatency"; writeJson(CONNECTION_FILE, connectionConfig)
        return removed
    end
    function pool.Destroy() credentialGeneration += 1; deviceCookie.Destroy() end

    -- Pool precargado: se refresca solo en segundo plano para que al pulsar el
    -- boton no haya que consultar nada; despues va cada POOL_REFRESH_SECONDS. No
    -- refresca mientras hay un salto en curso.
    function pool.StartRefresher(isBusy)
        task.spawn(function()
            local session = current()
            while session.alive and game.JobId == sessionStartJobId do
                if game.PlaceId == PLACE_ID and not isBusy() then
                    local ok, err = pcall(function()
                        local balanced = serverOrder == "BestLatency" and connectionConfig.transport == "DeviceCookie"
                        if balanced then
                            local visited = recentVisited.Get(os.time())
                            if not deviceNative.NeedsRefill(game.JobId, visited) then return end
                        elseif serverOrder == "BestLatency" then
                            local reserve = loadPool()
                            if reserve and #reserve >= POOL_SIZE then return end
                        end
                        local pool = pickCandidates(function()
                            return session.alive and not isBusy() and game.JobId == sessionStartJobId
                        end, balanced and BALANCED_RESERVE_SIZE or POOL_SIZE)
                        if pool and session.alive and game.JobId == sessionStartJobId then
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
                task.wait(serverOrder == "BestLatency" and 5 or POOL_REFRESH_SECONDS)
            end
        end)
    end
    return pool
end
return createServerPool
