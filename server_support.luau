-- Dependency injection keeps storage, paging and teleport failures testable without Roblox.
local function createFinderSupport()
    local support = {}
    function support.Copy(value)
        if type(value) ~= "table" then return value end
        local copy = {}; for key, item in pairs(value) do copy[key] = support.Copy(item) end
        return copy
    end
    function support.Store(io)
        local cache = {}
        local store = {}
        local function read(path)
            local ok, value = pcall(function() return io.decode(io.read(path)) end)
            return ok and type(value) == "table" and value or nil
        end
        -- Bytes of a file that decodes to a table, reused as the backup as-is.
        local function readValidRaw(path)
            local ok, raw = pcall(function()
                local raw = io.read(path)
                return type(io.decode(raw)) == "table" and raw or nil
            end)
            return ok and raw or nil
        end
        function store.Read(path, fallback)
            if cache[path] == nil then cache[path] = read(path) or read(path .. ".bak") or false end
            return support.Copy(cache[path] ~= false and cache[path] or fallback)
        end
        function store.Write(path, value)
            local ok = pcall(function()
                local raw = io.encode(value)
                -- A damaged main file keeps the existing valid backup untouched.
                local previous = readValidRaw(path)
                if previous then io.write(path .. ".bak", previous) end
                io.write(path .. ".tmp", raw)
                assert(io.read(path .. ".tmp") == raw, "No se verifico el archivo temporal")
                io.write(path, raw)
                assert(io.read(path) == raw, "No se verifico el archivo guardado")
            end)
            if ok then cache[path] = support.Copy(value) end
            return ok
        end
        return store
    end
    function support.PruneVisited(visited, now, maxAge, limit)
        local entries = {}
        for id, at in pairs(visited) do
            if type(id) == "string" and type(at) == "number" and at <= now and now - at < maxAge then
                table.insert(entries, {id = id, at = at})
            end
        end
        table.sort(entries, function(a,b) if a.at ~= b.at then return a.at > b.at end; return a.id < b.id end)
        local result = {}; for i = 1, math.min(#entries, limit or 500) do result[entries[i].id] = entries[i].at end
        return result
    end
    -- Shared read-only PruneVisited view. It only changes when the file is
    -- rewritten (Invalidate), a kept entry ages out or a future entry starts.
    function support.RecentVisited(read, maxAge, limit)
        local memo = {}
        local value, builtAt, refreshAt
        function memo.Get(now)
            if value == nil or now < builtAt or now >= refreshAt then
                local raw = read()
                value, builtAt, refreshAt = support.PruneVisited(raw, now, maxAge, limit), now, math.huge
                for id, at in pairs(raw) do
                    if type(id) == "string" and type(at) == "number" then
                        if at > now then refreshAt = math.min(refreshAt, at)
                        elseif now - at < maxAge then refreshAt = math.min(refreshAt, at + maxAge) end
                    end
                end
            end
            return value
        end
        function memo.Invalidate() value = nil end
        return memo
    end
    function support.Arrived(state, job)
        return type(state) == "table" and state.pending == true
            and (state.target == job or (type(state.origin) == "string" and state.origin ~= job))
    end
    function support.TeleportDisposition(state, job, connectionId)
        if type(state) ~= "table" or state.pending ~= true then return "none" end
        if support.Arrived(state, job) then return "arrived" end
        if state.origin == job and type(state.originConnection) == "string"
            and type(connectionId) == "string" and state.originConnection ~= connectionId then return "reconnected" end
        return "blocked"
    end
    function support.AutoHopAllowed(state, job, now, busy, blocked, freshSeconds)
        if busy or blocked then return false end
        if type(state) ~= "table" or state.pending ~= true then return true end
        if state.unconfirmed == true then return false end
        return state.target == job or now - (tonumber(state.requestedAt) or 0) >= freshSeconds
    end
    function support.Pages(fetch, accept, alive, wanted, maxPages)
        local result, seen, cursors, cursor = {}, {}, {}, nil
        for _ = 1, maxPages or 5 do
            if not alive() then return nil, "sesion terminada" end
            local page, err = fetch(cursor)
            if not alive() then return nil, "sesion terminada" end
            if not page then return #result > 0 and result or nil, err end
            for _, server in ipairs(page.data) do
                if not seen[server.id] and accept(server) then seen[server.id] = true; table.insert(result, server) end
            end
            cursor = page.nextPageCursor
            if #result >= wanted or type(cursor) ~= "string" or cursor == "" or cursors[cursor] then break end
            cursors[cursor] = true
        end
        return result
    end
    -- BestLatency is an order supplied by Roblox v2, not the legacy ping field.
    -- Keep that order within each occupancy group; never infer it from ping/fps.
    function support.RankServers(servers, orderBy)
        assert(orderBy == "BestLatency" or orderBy == "LegacyPing", "orden de servidores desconocido")
        local pool = {}
        for index, server in ipairs(servers) do
            local playing = tonumber(server.playing)
            if type(server.id) == "string" and playing and playing >= 1 and playing <= 6
                and playing == math.floor(playing) then
                table.insert(pool, {id = server.id, playing = playing,
                    ping = tonumber(server.ping) or -1, fps = tonumber(server.fps) or 0,
                    sourceRank = index, observedAt = tonumber(server.observedAt),
                    nativeRank = tonumber(server.nativeRank), pass = tonumber(server.pass)})
            end
        end
        table.sort(pool, function(a, b)
            if a.playing ~= b.playing then return a.playing < b.playing end
            if orderBy == "BestLatency" then return a.sourceRank < b.sourceRank end
            local aHealthy, bHealthy = a.fps >= 50, b.fps >= 50
            if aHealthy ~= bHealthy then return aHealthy end
            if a.ping ~= b.ping then return a.ping > b.ping end
            return a.id < b.id
        end)
        return pool
    end
    -- Cache only one occupancy group. Exhausting a short cache requires a new
    -- ascending-occupancy query, not advancing to a larger cached group.
    function support.OccupancyGroup(servers, orderBy, lowerGroupsComplete)
        local ranked = support.RankServers(servers, orderBy)
        if #ranked == 0 then return {}, nil end
        local playing = ranked[1].playing
        if playing > 1 and not lowerGroupsComplete then
            return nil, "lista incompleta; no se confirmo el agotamiento de ocupaciones menores"
        end
        local group = {}
        for _, server in ipairs(ranked) do
            if server.playing ~= playing then break end
            table.insert(group, server)
        end
        return group, playing
    end
    function support.NativePool(data, requestId, now, current, visited)
        if type(data) ~= "table" or data.schema ~= 1 or data.placeId ~= 107778070777162
            or data.orderBy ~= "BestLatency" or data.requestId ~= requestId then
            return nil, "esperando conexion Best Ping del PC"
        end
        local age = now - (tonumber(data.updatedAt) or 0)
        if age < -5 or age > 10 then return nil, "respuesta Best Ping vencida" end
        if data.state ~= "ready" then
            return nil, data.state == "error" and ("Best Ping: " .. tostring(data.error))
                or "Best Ping: buscando candidatos de menor ocupacion"
        end
        if type(data.servers) ~= "table" then return nil, "lista Best Ping invalida" end
        local accepted, previousRank = {}, 0
        for _, row in ipairs(data.servers) do
            if type(row) ~= "table" then return nil, "servidor Best Ping invalido" end
            local playing = tonumber(row.playing)
            if type(row.id) ~= "string" or not playing or playing < 1 or playing > 6
                or playing ~= math.floor(playing) then return nil, "ocupacion Best Ping invalida" end
            local rank, at = tonumber(row.nativeRank), tonumber(row.observedAt)
            if not rank or rank ~= rank or rank == math.huge or rank <= previousRank
                or not at or now - at < -5 or now - at > 180
                or tonumber(row.maxPlayers) ~= 7 then return nil, "datos Best Ping vencidos o invalidos" end
            previousRank = rank
            local seenAt = tonumber(visited[row.id])
            if row.id ~= current and (not seenAt or now - seenAt > 3600) then
                table.insert(accepted, row)
            end
        end
        local scanAge = now - (tonumber(data.scanStartedAt) or 0)
        local complete = data.complete == true and scanAge >= -5 and scanAge <= 180
        local proofAge = now - (tonumber(data.occupancyCheckedAt) or 0)
        local lowest = tonumber(data.lowestOccupancy)
        local verified = lowest and lowest >= 1 and lowest <= 6 and lowest == math.floor(lowest)
            and proofAge >= -5 and proofAge <= 90
        if verified then
            for _, row in ipairs(accepted) do
                if tonumber(row.playing) ~= lowest then return nil, "ocupacion Best Ping no corresponde a la consulta vigente" end
            end
        end
        local group, reason = support.OccupancyGroup(accepted, "BestLatency", complete or verified)
        if not group then return nil, reason end
        if #group == 0 then return nil, "Best Ping: renovando candidatos agotados" end
        return group
    end
    function support.NormalizeCookie(value)
        if type(value) ~= "string" then return nil end
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        local prefix = ".ROBLOSECURITY="
        if value:sub(1, #prefix) == prefix then value = value:sub(#prefix + 1):gsub(";$", "") end
        if #value == 0 or #value > 16384 or value:find("[^!-~]") or value:find(";", 1, true) then return nil end
        return value
    end
    -- Kept outside general JSON storage: no backups, telemetry or public API.
    function support.DeviceCookie(io, owner)
        local credential, remembered = nil, false
        local path = "sae_account_cookie_" .. tostring(owner) .. ".json"
        local device = {}
        function device.Restore()
            credential, remembered = nil, false
            local ok, saved = pcall(function() return io.decode(io.read(path)) end)
            if ok and type(saved) == "table" and saved.owner == owner then
                credential = support.NormalizeCookie(saved.cookie)
                remembered = credential ~= nil
            end
            return credential ~= nil
        end
        function device.Set(value, persist)
            local normalized = support.NormalizeCookie(value)
            if not normalized then return false, "Pega solo el valor de .ROBLOSECURITY." end
            local ok = pcall(function()
                if persist then
                    local raw = io.encode({owner = owner, cookie = normalized})
                    io.write(path, raw)
                    assert(io.read(path) == raw)
                else
                    -- Session-only must also remove any previous saved credential.
                    io.erase(path)
                end
            end)
            if not ok then return false, "No se pudo guardar o borrar la cookie local. Revisa tu executor." end
            credential, remembered = normalized, persist == true
            return true
        end
        function device.Read() return credential end
        function device.Status() return {configured = credential ~= nil, remembered = remembered} end
        function device.Forget()
            local ok = pcall(io.erase, path)
            credential, remembered = nil, false
            return ok
        end
        function device.Destroy() credential = nil end
        return device
    end
    function support.CookiePage(env, orderBy, cursor, secret)
        if orderBy ~= "BestLatency" and orderBy ~= "OccupancyAsc" then return nil, "orden invalido" end
        local url = "https://games.roblox.com/v2/games/107778070777162/servers/Public?orderBy=" .. orderBy
            .. "&sortOrder=" .. (orderBy == "BestLatency" and "Desc" or "Asc") .. "&excludeFullGames=true&limit=100"
        if cursor then url ..= "&cursor=" .. env.encode(cursor) end
        local headers = {Accept = "application/json"}
        if orderBy == "BestLatency" then
            secret = support.NormalizeCookie(secret)
            if not secret then return nil, "cookie ausente" end
            headers.Cookie = ".ROBLOSECURITY=" .. secret
        end
        local ok, response = pcall(env.send, {Url = url, Method = "GET", Headers = headers, Redirect = false})
        headers.Cookie = nil
        if not ok or type(response) ~= "table" then return nil, "El executor no pudo consultar Roblox con headers." end
        local status = tonumber(response.StatusCode or response.Status or response.status_code)
        local finalUrl = response.Url or response.URL
        if (type(finalUrl) == "string" and finalUrl:sub(1, #"https://games.roblox.com/") ~= "https://games.roblox.com/")
            or (status and status >= 300 and status < 400) then
            return nil, "Redireccion rechazada; conexion detenida.", 302
        end
        if status == 200 then
            local decoded, body = pcall(env.decode, response.Body or response.body or "")
            if decoded and type(body) == "table" and type(body.data) == "table" then
                return {data = body.data, nextPageCursor = body.nextPageCursor}, nil, status
            end
            return nil, "Roblox devolvio una lista invalida.", status
        end
        if status == 429 then return nil, "Roblox limito las consultas; espera 60 segundos.", status end
        if status == 400 or status == 401 or status == 403 then
            return nil, "Roblox no acepto la cookie o la consulta. Vuelve a conectar.", status
        end
        return nil, "No se pudo consultar Roblox. Revisa tu conexion.", status
    end
    function support.DeviceRequest(env, shared)
        local transport = {}
        local function waiting()
            local now = env.now()
            if shared.busy then
                local at = type(shared.busy) == "table" and shared.busy.started or nil
                shared.pendingSince = shared.pendingSince or env.clock()
                local elapsed = math.max(0, env.clock() - (at or shared.pendingSince))
                return {kind = "pending", seconds = math.floor(elapsed)}
            end
            shared.pendingSince = nil
            if now < (shared.cooldown or 0) then
                return {kind = "rate_limit", seconds = math.ceil(shared.cooldown - now)}
            end
            if now < (shared.last or 0) + 15 then
                return {kind = "interval", seconds = math.ceil(shared.last + 15 - now)}
            end
            return {kind = "ready", seconds = 0}
        end
        function transport.State()
            local state = waiting()
            state.lastHttpStatus = shared.lastHttpStatus
            return state
        end
        function transport.Run(send, alive, progress)
            -- A previous request plus a real 60s cooldown may exceed 35s.
            local deadline = env.clock() + 95
            while alive() do
                local state = waiting()
                if state.kind == "ready" then break end
                if progress then pcall(progress, state) end
                if state.kind == "pending" and state.seconds >= 30 then
                    return nil, "El executor no termino la consulta anterior. Reinicia Roblox y ejecuta de nuevo.", nil
                end
                if env.clock() >= deadline then return nil, "La cola de consultas sigue ocupada. Reintenta cuando termine." end
                env.wait(0.2)
            end
            if not alive() then return nil, "conexion cancelada" end
            local token = {started = env.clock()}
            shared.busy, shared.last = token, env.now()
            if env.persist then pcall(env.persist, shared.last, shared.cooldown or 0) end
            local done, page, reason, status = false, nil, nil, nil
            local spawned = pcall(env.spawn, function()
                local ok
                ok, page, reason, status = pcall(send)
                if not ok then
                    page, reason, status = nil, "El executor no pudo completar la consulta a Roblox.", nil
                end
                if status == 429 then shared.cooldown = env.now() + 60 end
                shared.lastHttpStatus = status
                if env.persist then pcall(env.persist, shared.last, shared.cooldown or 0) end
                -- A late completion releases only its own reservation.
                if shared.busy == token then shared.busy = false; shared.pendingSince = nil end
                done = true
            end)
            if not spawned then
                if shared.busy == token then shared.busy = false end
                return nil, "No se pudo iniciar la consulta en el executor."
            end
            deadline = env.clock() + 30
            while alive() and not done and env.clock() < deadline do
                if progress then pcall(progress, {kind = "request", seconds = math.floor(env.clock() - token.started)}) end
                env.wait(0.1)
            end
            if not alive() then return nil, "conexion cancelada" end
            if not done then
                -- Never unlock a native request that may still be running.
                return nil, "El executor no termino la consulta. Reinicia Roblox si sigue pendiente."
            end
            return page, reason, status
        end
        return transport
    end
    function support.DeviceWaitMessage(state)
        if state.kind == "rate_limit" then return string.format("Roblox respondio HTTP 429. Reintento en %d s...", state.seconds) end
        if state.kind == "interval" then return string.format("Espaciando consultas. Continua en %d s...", state.seconds) end
        if state.kind == "pending" then return string.format("Esperando la consulta anterior del executor (%d s)...", state.seconds) end
        if state.kind == "request" then return string.format("Consultando Roblox (%d s)...", state.seconds) end
        return "Comprobando la conexion con Roblox..."
    end
    function support.NativeProgressMessage(state)
        local text = state.policy == "Balanced" and string.format("Best Ping: reserva 1-2/7, pagina %d (%d servidores revisados)", state.page or 1, state.servers or 0)
            or state.phase == "occupancy" and string.format("Best Ping: revisando ocupacion, pagina %d", state.page or 1)
            or string.format("Best Ping: %d/7, pagina %d (%d servidores revisados)", state.occupancy or 1, state.page or 1, state.servers or 0)
        if state.wait then text ..= " | " .. support.DeviceWaitMessage(state.wait) end
        return text
    end
    -- Escala de la tarjeta del hopper: limitada, redondeada a centesimas y, si
    -- se conoce, sin superar lo que cabe en la pantalla.
    local HOPPER_MIN_SCALE, HOPPER_MAX_SCALE = 0.75, 1.75
    function support.HopperScale(value, fitLimit)
        local upper = math.clamp(tonumber(fitLimit) or HOPPER_MAX_SCALE, HOPPER_MIN_SCALE, HOPPER_MAX_SCALE)
        if type(value) ~= "number" or value ~= value then return math.min(1, upper) end
        return math.floor(math.clamp(value, HOPPER_MIN_SCALE, upper) * 100 + 0.5) / 100
    end
    -- El asa inferior derecha sigue al puntero: manda el eje que mas cambia,
    -- asi un arrastre solo horizontal o solo vertical tambien redimensiona.
    function support.DragScale(startScale, base, delta)
        local byWidth = (base.X * startScale + delta.X) / base.X
        local byHeight = (base.Y * startScale + delta.Y) / base.Y
        return math.abs(byWidth - startScale) >= math.abs(byHeight - startScale) and byWidth or byHeight
    end
    function support.ResizeHopperScale(startScale, base, delta, fitLimit)
        return support.HopperScale(support.DragScale(startScale, base, delta), fitLimit)
    end
    -- El panel es grande: aqui la pantalla manda sobre el minimo elegido.
    local PANEL_MIN_SCALE, PANEL_MAX_SCALE = 0.6, 1.5
    function support.PanelScale(value, fitLimit)
        local upper = math.max(0.1, math.min(PANEL_MAX_SCALE, tonumber(fitLimit) or PANEL_MAX_SCALE))
        if type(value) ~= "number" or value ~= value then value = 1 end
        local rounded = math.floor(math.clamp(value, math.min(PANEL_MIN_SCALE, upper), upper) * 100 + 0.5) / 100
        return math.max(0.1, math.min(upper, rounded))
    end
    -- A fresh one-player reserve is already the minimum eligible occupancy.
    -- Larger groups still require a new OccupancyAsc proof before a hop.
    function support.BalancedReserve(servers, now, current, visited, limit)
        local accepted, seen = {}, {}
        for index, row in ipairs(servers) do
            if type(row) == "table" and type(row.id) == "string" and not seen[row.id]
                and (row.playing == 1 or row.playing == 2) and type(row.observedAt) == "number" then
                local age = now - row.observedAt
                if age >= 0 and age <= (row.playing == 1 and 180 or 90) and row.id ~= current and not visited[row.id] then
                    local copy = support.Copy(row)
                    copy.nativeRank = tonumber(row.nativeRank) or tonumber(row.sourceRank) or index
                    copy.pass = tonumber(row.pass) or 0
                    if copy.nativeRank ~= copy.nativeRank or math.abs(copy.nativeRank) == math.huge then copy.nativeRank = index end
                    if copy.pass ~= copy.pass or math.abs(copy.pass) == math.huge then copy.pass = 0 end
                    seen[row.id] = true; table.insert(accepted, copy)
                end
            end
        end
        -- Keep native order in each observation pass; favor the refreshed head
        -- over older fallback records of the same occupancy.
        table.sort(accepted, function(a,b)
            if a.pass ~= b.pass then return a.pass > b.pass end
            if a.nativeRank ~= b.nativeRank then return a.nativeRank < b.nativeRank end
            return a.id < b.id
        end)
        local ranked = support.RankServers(accepted, "BestLatency")
        local pool = {}; for i = 1, math.min(#ranked, limit or 24) do pool[i] = ranked[i] end
        return #pool > 0 and pool or nil
    end
    function support.PreloadedNativePool(data, now, current, visited, transport, balanced)
        if type(data) ~= "table" or data.orderBy ~= "BestLatency" or data.transport ~= transport
            or type(data.servers) ~= "table" then return nil end
        if balanced and data.reservePolicy == "balanced-1-2-v1" then
            return support.BalancedReserve(data.servers, now, current, visited, 24)
        end
        if data.occupancy ~= 1 then return nil end
        local pool, seen = {}, {}
        for _, row in ipairs(data.servers) do
            if type(row) ~= "table" or row.playing ~= 1 or type(row.id) ~= "string" then return nil end
            local age = now - (tonumber(row.observedAt) or 0)
            if age >= 0 and age <= 180 and row.id ~= current and not visited[row.id] and not seen[row.id] then
                seen[row.id] = true; table.insert(pool, row)
            end
        end
        return #pool > 0 and support.RankServers(pool, "BestLatency") or nil
    end
    -- A Balanced pass that listed this many places past a server's earlier
    -- rank without listing it again is evidence the server left the open
    -- list. Real passes 2026-10-12: all 13 such 1-2/7 servers had closed or
    -- came back with 3+ players; a still-open one rarely moves this far and
    -- is listed again when the pass reaches it.
    support.RELIST_MARGIN = 100
    -- Native v2 paging on the user's device. A partial latency stream never
    -- establishes exhaustion of lower occupancy groups.
    function support.DeviceNative(env)
        local rows, cursors, cursor, rank, pages, complete = {}, {}, nil, 0, 0, false
        local pass, balancedInProgress, needsRefresh = 0, false, env.reservePolicy == "Balanced"
        local native = {}
        local function resetStream()
            rows, cursors, cursor, rank, pages, complete = {}, {}, nil, 0, 0, false
            pass, balancedInProgress, needsRefresh = 0, false, env.reservePolicy == "Balanced"
        end
        local function saveStream()
            local now = env.now()
            for id, row in pairs(rows) do
                if now - row.observedAt > 180 or now < row.observedAt then rows[id] = nil end
            end
            if env.save then pcall(env.save, {schema = 1, updatedAt = now, rows = support.Copy(rows),
                cursors = support.Copy(cursors), cursor = cursor, rank = rank, pages = pages, complete = complete,
                reservePolicy = env.reservePolicy, pass = pass, balancedInProgress = balancedInProgress}) end
        end
        function native.Restore(value)
            if type(value) ~= "table" or value.schema ~= 1 or type(value.rows) ~= "table" or type(value.cursors) ~= "table"
                or type(value.updatedAt) ~= "number" or value.updatedAt ~= value.updatedAt
                or env.now() - value.updatedAt < 0 or env.now() - value.updatedAt > 180
                or type(value.rank) ~= "number" or value.rank < 0 or value.rank > 200000 or value.rank ~= math.floor(value.rank)
                or type(value.pages) ~= "number" or value.pages < 0 or value.pages > 2000 or value.pages ~= math.floor(value.pages)
                or type(value.complete) ~= "boolean" or (value.cursor ~= nil and (type(value.cursor) ~= "string" or #value.cursor > 4096))
                then return false end
            local count = 0
            for id, row in pairs(value.rows) do
                count += 1
                if count > 2000 or type(id) ~= "string" or #id > 128 or type(row) ~= "table" or row.id ~= id
                    or type(row.playing) ~= "number" or row.playing < 1 or row.playing > 6 or row.playing ~= math.floor(row.playing)
                    or type(row.nativeRank) ~= "number" or row.nativeRank < 1
                    or row.nativeRank > (env.reservePolicy == "Balanced" and 200000 or value.rank)
                    or row.nativeRank ~= math.floor(row.nativeRank) or type(row.observedAt) ~= "number"
                    or row.observedAt ~= row.observedAt or row.observedAt > env.now() then return false end
            end
            count = 0
            for key, seen in pairs(value.cursors) do
                count += 1
                if count > 2000 or type(key) ~= "string" or #key > 4096 or seen ~= true then return false end
            end
            if value.cursor and not value.cursors[value.cursor] then return false end
            rows, cursors, cursor, rank, pages, complete = support.Copy(value.rows), support.Copy(value.cursors), value.cursor,
                value.rank, value.pages, value.complete
            if env.reservePolicy == "Balanced" then
                local validPass = type(value.pass) == "number" and value.pass >= 0 and value.pass < math.huge
                    and value.pass == math.floor(value.pass)
                if value.reservePolicy == "Balanced" and validPass then
                    pass, balancedInProgress, needsRefresh = value.pass, value.balancedInProgress == true, false
                    for _, row in pairs(rows) do
                        if row.pass ~= nil and (type(row.pass) ~= "number" or row.pass ~= row.pass
                            or row.pass < 0 or row.pass > pass or row.pass ~= math.floor(row.pass)) then
                            resetStream(); return false
                        end
                    end
                else
                    -- Migrate usable observations, then refresh from the head.
                    for _, row in pairs(rows) do row.pass = 0 end
                    needsRefresh = true
                end
            end
            return true
        end
        local function observe(page)
            pages += 1
            for _, row in ipairs(page.data) do
                rank += 1
                if type(row) == "table" and type(row.id) == "string" and row.maxPlayers == 7
                    and type(row.playing) == "number" and row.playing == math.floor(row.playing)
                    and row.playing >= 1 and row.playing <= 6 then
                    rows[row.id] = {id = row.id, playing = row.playing,
                        nativeRank = env.reservePolicy == "Balanced" and rank or (rows[row.id] and rows[row.id].nativeRank or rank),
                        observedAt = env.now(), pass = env.reservePolicy == "Balanced" and pass or nil}
                end
            end
            cursor = page.nextPageCursor
            if cursor == nil or cursor == "" then cursor = nil; complete = true
            elseif type(cursor) ~= "string" or cursors[cursor] then
                resetStream(); saveStream(); return false
            else cursors[cursor] = true end
            -- Balanced passes restart at the native head, so an older row this
            -- pass should already have listed again is no longer joinable.
            if env.reservePolicy == "Balanced" then
                for id, row in pairs(rows) do
                    if row.pass ~= pass and (complete or row.nativeRank + support.RELIST_MARGIN <= rank) then
                        rows[id] = nil
                    end
                end
            end
            saveStream()
            return true
        end
        function native.Seed(page)
            resetStream()
            if env.reservePolicy == "Balanced" then pass = env.now(); balancedInProgress, needsRefresh = true, false end
            if type(page) ~= "table" or type(page.data) ~= "table" or not observe(page) then return false end
            if env.reservePolicy == "Balanced" then
                local pool = native.Reserve("", {})
                if pool and env.publish then pcall(env.publish, pool) end
                if pool and #pool >= 24 then balancedInProgress = false; saveStream() end
                return true
            end
            local ones = {}
            for _, row in pairs(rows) do if row.playing == 1 then table.insert(ones, row) end end
            table.sort(ones, function(a,b) return a.nativeRank < b.nativeRank end)
            if #ones > 0 and env.publish then pcall(env.publish, support.RankServers(ones, "BestLatency")) end
            return true
        end
        function native.Reserve(current, visited, limit)
            local servers = {}; for _, row in pairs(rows) do table.insert(servers, row) end
            return support.BalancedReserve(servers, env.now(), current, visited, limit or 24)
        end
        function native.NeedsRefill(current, visited)
            if needsRefresh then return true end
            local pool = native.Reserve(current, visited)
            if not pool or #pool < 16 then return true end
            local now = env.now()
            for _, row in ipairs(pool) do
                if row.playing == 2 and now - row.observedAt >= 60 then return true end
            end
            return false
        end
        function native.Pick(current, visited, continuing, wanted)
            wanted = wanted or 1
            local function alive() return env.alive() and (not continuing or continuing()) end
            if not alive() then return nil, "busqueda cancelada" end
            local now = env.now()
            -- Expire individual observations without restarting an unfinished
            -- cursor. At 15s/request a valid candidate may be many minutes away.
            for id, row in pairs(rows) do
                if now - row.observedAt > 180 or now < row.observedAt then rows[id] = nil end
            end
            if env.reservePolicy == "Balanced" then
                local cached = native.Reserve(current, visited)
                -- A manual/AUTO hop consumes ready candidates immediately.
                if cached and (wanted == 1 or not native.NeedsRefill(current, visited)) then return cached end
                if not balancedInProgress or complete or needsRefresh or pages >= 12 or env.now() - pass >= 180 then
                    cursors, cursor, rank, pages, complete = {}, nil, 0, 0, false
                    pass = math.max(env.now(), pass + 1)
                    balancedInProgress, needsRefresh = true, false
                end
                for _ = 1, 5 do
                    if env.progress then pcall(env.progress, {state = "searching", policy = "Balanced", phase = "latency",
                        page = pages + 1, pages = pages, servers = rank}) end
                    local page, err, status = env.fetch("BestLatency", cursor, alive)
                    if not alive() then return nil, "busqueda cancelada" end
                    if not page and status == 400 and cursor then
                        balancedInProgress, needsRefresh = false, true
                        return native.Reserve(current, visited), "cursor Best Ping vencido; renovando lista"
                    end
                    if not page and (status == 400 or status == 401 or status == 403 or status == 302) then
                        return nil, err or "Roblox no acepto la conexion"
                    end
                    if not page or type(page.data) ~= "table" then return native.Reserve(current, visited), err or "respuesta Best Ping invalida" end
                    if not observe(page) then return nil, "cursor Best Ping invalido; se renovara la lista" end
                    local found = native.Reserve(current, visited)
                    if found and env.publish then pcall(env.publish, found) end
                    local fresh = 0
                    for _, row in ipairs(native.Reserve(current, visited, math.huge) or {}) do if row.pass == pass then fresh += 1 end end
                    -- Stop near the native head when stock is sufficient. A
                    -- sparse reserve may continue deeper, within a hard bound;
                    -- observations still expire independently while paging.
                    local enough = found and #found >= 16
                    local normalBudget = pages >= 5 or env.now() - pass >= 75
                    local hardBudget = pages >= 12 or env.now() - pass >= 180
                    if fresh >= wanted or complete or (enough and normalBudget) or hardBudget then
                        balancedInProgress = false; saveStream(); break
                    end
                end
                local found = native.Reserve(current, visited)
                if found then return found end
                -- Preserve the established 3..6 fallback: only the existing
                -- fresh occupancy proof may advance beyond the quick reserve.
            end
            local function eligible(row)
                return row.id ~= current and not visited[row.id]
            end
            local lowest, proofAt, proofCursor, proofSeen, previous = nil, nil, nil, {}, 0
            local function progress(phase, page)
                if env.progress then pcall(env.progress, {state = "searching", phase = phase, page = page,
                    pages = pages, servers = rank, occupancy = lowest}) end
            end
            local function group()
                if not lowest or (lowest > 1 and env.now() - proofAt > 90) then return nil end
                local accepted = {}
                for _, row in pairs(rows) do
                    if row.playing == lowest and eligible(row) and env.now() - row.observedAt <= 180 then table.insert(accepted, row) end
                end
                table.sort(accepted, function(a, b) return a.nativeRank < b.nativeRank end)
                return #accepted > 0 and support.RankServers(accepted, "BestLatency") or nil
            end
            -- Known fresh 1/7 rows need no occupancy query. During prefetch,
            -- keep paging past a short group until the reserve is filled.
            lowest, proofAt = 1, now
            local cached = group()
            if cached and #cached >= wanted then return cached end
            if not cached then
                lowest, proofAt = nil, nil
                for proofPage = 1, 5 do
                    progress("occupancy", proofPage)
                    local page, err = env.fetch("OccupancyAsc", proofCursor, alive)
                    if not alive() then return nil, "busqueda cancelada" end
                    if not page or type(page.data) ~= "table" then return nil, err or "respuesta de ocupacion invalida" end
                    for _, row in ipairs(page.data) do
                        local count = type(row) == "table" and row.playing
                        if type(count) ~= "number" or count ~= math.floor(count) or count < previous or count > 7 then
                            return nil, "orden de ocupacion invalido"
                        end
                        previous = count
                        if not lowest and count >= 1 and count <= 6 and row.maxPlayers == 7
                            and type(row.id) == "string" and eligible(row) then lowest = count end
                    end
                    if lowest then proofAt = env.now(); break end
                    proofCursor = page.nextPageCursor
                    if proofCursor == nil or proofCursor == "" then return nil, "no hay servidores disponibles" end
                    if type(proofCursor) ~= "string" or proofSeen[proofCursor] then return nil, "cursor de ocupacion invalido" end
                    proofSeen[proofCursor] = true
                end
                if not lowest then return nil, "lista parcial; revisando ocupaciones menores" end
            end
            cached = group()
            if cached and (#cached >= wanted or lowest > 1 or complete) then return cached end
            -- Once exhausted, start a new stream if its cached group is gone.
            if complete then resetStream() end
            for _ = 1, 5 do
                progress("latency", pages + 1)
                local page, err, status = env.fetch("BestLatency", cursor, alive)
                if not alive() then return nil, "busqueda cancelada" end
                if not page and status == 400 and cursor then
                    resetStream(); saveStream(); return nil, "cursor Best Ping vencido; renovando lista"
                end
                if not page or type(page.data) ~= "table" then return nil, err or "respuesta Best Ping invalida" end
                if not observe(page) then return nil, "cursor Best Ping invalido; se renovara la lista" end
                progress("latency", pages)
                local found = group()
                if found then
                    if env.publish then pcall(env.publish, found) end
                    if #found >= wanted or lowest > 1 then return found end
                end
                if complete then break end
            end
            local found = group()
            if found then return found end
            return nil, string.format("lista parcial: %d paginas revisadas; continuando Best Ping en %d/7", pages, lowest)
        end
        return native
    end
    function support.Attempt(env)
        local attempt = { state = "idle", connection = nil }
        local function disconnect()
            if attempt.connection then pcall(function() attempt.connection:Disconnect() end); attempt.connection = nil end
        end
        function attempt.Cancel()
            attempt.cancelled = true; disconnect()
        end
        function attempt.Run(target)
            if not env.alive() then return "cancelled" end
            if not env.save({pending = true, unconfirmed = true, target = target, requestedAt = env.time(), auto = env.automatic,
                attemptId = env.id, origin = env.job(), originConnection = env.connectionId}) then return "storage", "No se pudo guardar el salto" end
            attempt.state = "pending"
            local failed, reason = false, nil
            local connected, connection = pcall(env.connect, function(player, result, message, place, options)
                if player ~= env.player or (place and place ~= env.place) then return end
                if options and options.ServerInstanceId and options.ServerInstanceId ~= "" and options.ServerInstanceId ~= target then return end
                failed, reason = true, tostring(result) .. " / " .. tostring(message)
            end)
            if not connected then
                if not env.save({pending = false}) then return "storage", "No se pudo cerrar el salto" end
                return "failed", tostring(connection)
            end
            attempt.connection = connection
            if not env.alive() or attempt.cancelled then disconnect(); attempt.state = "cancelled"; return "cancelled" end
            local startJob = env.job()
            local ok, err = pcall(env.send, target)
            if not ok then failed, reason = true, tostring(err) end
            local deadline = env.clock() + env.timeout
            while not failed and env.job() == startJob and env.clock() < deadline
                and env.alive() and not attempt.cancelled do env.wait(0.25) end
            disconnect()
            if not env.alive() or attempt.cancelled then
                attempt.state = "cancelled" -- A sent teleport cannot be withdrawn. Leave pending on disk.
                return "cancelled"
            end
            if env.job() ~= startJob then attempt.state = "moved"; return "moved" end
            if failed then
                if not env.save({pending = false, attemptId = env.id}) then return "storage", "No se pudo cerrar el salto" end
                attempt.state = "failed"; return "failed", reason
            end
            env.save({pending = true, unconfirmed = true, target = target, requestedAt = env.time(),
                attemptId = env.id, auto = env.automatic, origin = startJob, originConnection = env.connectionId})
            attempt.state = "unconfirmed"
            return "unconfirmed"
        end
        return attempt
    end
    return support
end
return createFinderSupport
