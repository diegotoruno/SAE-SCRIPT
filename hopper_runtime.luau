-- BEGIN TESTABLE SUPPORT
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
    -- Roblox can send the client back to the origin instead of the target
    -- (test 2026-10-14: 4da6f5e2 loaded twice in a row). That target failed;
    -- returns it so it is not tried again.
    function support.FailedTarget(state, job)
        if type(state) ~= "table" or type(state.target) ~= "string" or state.target == "" then return nil end
        return state.target ~= job and state.target or nil
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
    -- Arrastre de ventanas: pasado el borde, cada pixel cuenta menos (0.55,
    -- la constante de iOS); dentro del borde sigue 1:1.
    function support.Rubberband(value, low, high, dimension)
        high = math.max(low, high)
        local over = value < low and low - value or value > high and value - high or 0
        if over == 0 then return value end
        local give = over * dimension * 0.55 / (dimension + 0.55 * over)
        return value < low and low - give or high + give
    end
    -- Un eje de un resorte criticamente amortiguado (sin rebote): devuelve la
    -- posicion y la velocidad tras dt, partiendo de los valores actuales.
    function support.SpringStep(position, velocity, target, dt, response)
        local omega = 2 * math.pi / response
        local offset = position - target
        local decay = math.exp(-omega * dt)
        local lead = velocity + omega * offset
        return target + (offset + lead * dt) * decay, (velocity - omega * lead * dt) * decay
    end
    -- Temas de Mistake Hub: los mismos tokens en claro y oscuro (RGB 0-255).
    -- Cambiar de tema reemplaza cada color por el del mismo token, asi que dos
    -- tokens que comparten valor en un tema lo comparten tambien en el otro.
    -- Los blancos casi puros (#FFFFFE, #FFFFFD) separan tokens que en oscuro difieren.
    support.THEMES = {
        light = {
            window = {250, 250, 249}, sidebar = {233, 234, 237}, raised = {255, 255, 255}, field = {255, 255, 255},
            control = {252, 252, 252}, controlHover = {240, 240, 243}, trackOff = {226, 226, 231}, fill = {120, 120, 128},
            separator = {60, 60, 67}, text = {29, 29, 31}, secondary = {99, 99, 104}, tertiary = {142, 142, 147},
            accent = {0, 122, 255}, accentStrong = {0, 110, 230}, accentText = {0, 100, 214}, selection = {219, 235, 255},
            onAccent = {255, 255, 254}, knob = {255, 255, 253},
            yellow = {255, 189, 46}, yellowEdge = {222, 161, 35}, yellowGlyph = {153, 87, 0},
            green = {26, 117, 52}, greenDot = {52, 199, 89}, successTint = {227, 245, 232},
            orange = {168, 74, 0}, orangeDot = {255, 149, 0}, orangeTint = {255, 242, 224},
            red = {196, 30, 40}, scrim = {0, 0, 0},
        },
        dark = {
            window = {30, 30, 32}, sidebar = {40, 40, 43}, raised = {44, 44, 47}, field = {44, 44, 47},
            control = {58, 58, 61}, controlHover = {70, 70, 74}, trackOff = {72, 72, 76}, fill = {128, 128, 136},
            separator = {229, 229, 234}, text = {245, 245, 247}, secondary = {164, 164, 170}, tertiary = {124, 124, 130},
            accent = {10, 132, 255}, accentStrong = {0, 98, 204}, accentText = {100, 172, 255}, selection = {28, 58, 96},
            onAccent = {255, 255, 254}, knob = {255, 255, 253},
            yellow = {255, 189, 46}, yellowEdge = {222, 161, 35}, yellowGlyph = {153, 87, 0},
            green = {74, 214, 120}, greenDot = {48, 209, 88}, successTint = {24, 52, 34},
            orange = {255, 170, 60}, orangeDot = {255, 159, 10}, orangeTint = {58, 42, 16},
            red = {255, 138, 130}, scrim = {0, 0, 0},
        },
    }
    -- Transparencia de los materiales de vidrio en cada tema: ventana y barra lateral.
    support.THEME_ALPHA = { light = { window = 0.04, sidebar = 0.12 }, dark = { window = 0.04, sidebar = 0.12 } }
    -- Tarjeta flotante de Server Hop: panel de manga en tonos de Gojo, igual
    -- con cualquier tema del hub. Papel blanco frio, tinta azul noche, trama
    -- lavanda, acento azul a violeta y sombra violeta.
    support.MANGA = {
        paper = {246, 248, 255}, ink = {14, 16, 36}, soft = {58, 62, 92}, dots = {150, 140, 210},
        blue = {37, 99, 235}, violet = {124, 58, 237}, shade = {76, 29, 149}, onBlue = {255, 255, 255},
        press = {205, 210, 230}, trackOff = {218, 220, 236}, alert = {176, 24, 40}, go = {20, 110, 56},
    }
    function support.ThemePreference(value)
        return (value == "light" or value == "dark" or value == "system") and value or "system"
    end
    -- Roblox no expone la apariencia del sistema operativo: "Sistema" sigue la
    -- hora local del dispositivo, como el modo automatico de macOS.
    function support.ResolveTheme(preference, hour)
        preference = support.ThemePreference(preference)
        if preference ~= "system" then return preference end
        hour = tonumber(hour) or 12
        return (hour >= 7 and hour < 19) and "light" or "dark"
    end
    local function themeKey(rgb) return rgb[1] * 65536 + rgb[2] * 256 + rgb[3] end
    -- Valor de cada color de un tema al pasar al otro; falla si es ambiguo.
    function support.ThemeRemap(from, to)
        local source, target, map = support.THEMES[from], support.THEMES[to], {}
        for token, rgb in pairs(source) do
            local key, wanted = themeKey(rgb), target[token]
            assert(wanted, "Falta el token " .. token .. " en " .. to)
            if map[key] then
                assert(themeKey(map[key]) == themeKey(wanted), "Color ambiguo entre temas: " .. token)
            end
            map[key] = wanted
        end
        return map, themeKey
    end
    -- Contraste WCAG entre dos colores RGB 0-255.
    function support.ThemeContrast(a, b)
        local function luminance(rgb)
            local total = 0
            for index, weight in ipairs({0.2126, 0.7152, 0.0722}) do
                local value = rgb[index] / 255
                total += weight * (value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4)
            end
            return total
        end
        local x, y = luminance(a), luminance(b)
        return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
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
-- END TESTABLE SUPPORT

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
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Stats = game:GetService("Stats")
    local StarterGui = game:GetService("StarterGui")
    local CoreGui = game:GetService("CoreGui")
    local GuiService = game:GetService("GuiService")
    local RunService = game:GetService("RunService")

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
    local EXPECTED_CAPACITY = 7
    local IDEAL_PING = 120
    local IDEAL_PLAYERS = 2
    local STATE_FILE = "server_hop_button_state.json"
    local VISITED_FILE = "server_hop_button_visited.json"
    local SCOUT_STATE_FILE = "steal_an_egg_scout_state.json"
    local UI_FILE = "server_hop_button_ui.json"
    local POOL_FILE = "server_hop_button_pool.json"
    local SERVER_SELECTION_POLICY = "occupancy-groups-v2"
    local CONNECTION_FILE = "server_hop_button_connection.json"
    local DEVICE_GATE_FILE = "sae_best_ping_device_gate.json"
    local NATIVE_REQUEST_FILE = "sae_best_ping_request.json"
    local NATIVE_RESPONSE_FILE = "sae_best_ping_response.json"
    local VISITED_MAX_AGE = 60 * 60
    local POOL_REFRESH_SECONDS = 45   -- cada cuanto se refresca el pool
    local POOL_SIZE = 8               -- candidatos guardados en el pool
    local BALANCED_RESERVE_SIZE = 24  -- 1/7 first; 2/7 ready when the quick primary reserve is empty
    local POOL_MAX_AGE = 180          -- pool mas viejo que esto se ignora
    local PING_SETTLE_SECONDS = 10
    local PING_SAMPLE_INTERVAL = 1
    local PING_SAMPLE_COUNT = 8
    local ARRIVE_STABILIZE_SECONDS = 4
    local RETRY_DELAY_SECONDS = 15   -- espera entre reintentos del salto
    local HTTP_RETRIES = 2           -- intentos por consulta de la lista
    local TELEPORT_CONFIRM_SECONDS = 25  -- margen para que arranque el teleport
    local TELEPORT_HARD_WAIT_SECONDS = 35 -- espera extra si no hay senal alguna
    local PENDING_FRESH_SECONDS = 60      -- espera inicial; unconfirmed requiere clic manual
    local MIN_API_INTERVAL = 2.0          -- pausa entre consultas a la API
    local API_429_COOLDOWN_SECONDS = 30   -- castigo tras un HTTP 429
    local AUTO_POLL_SECONDS = 0.5

    -- La tarjeta flotante usa los tokens del tema de Mistake Hub (hubTheme):
    -- se leen al usarlos, asi siempre son los del tema activo.
    local hubTheme
    local COLOR_TOKENS = { surface = "window", raised = "control", border = "separator", action = "accentStrong",
        actionText = "onAccent", text = "text", muted = "secondary", credit = "accentText", accent = "accent",
        green = "green", greenTint = "successTint", amber = "orange", tertiary = "tertiary" }
    local COLORS = setmetatable({}, { __index = function(_, name) return hubTheme.colors[COLOR_TOKENS[name] or name] end })
    local UI_FONT = "rbxasset://fonts/families/BuilderSans.json"

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
    local connectionConfig = readJson(CONNECTION_FILE, {})
    local serverOrder = connectionConfig.mode == "BestLatency" and "BestLatency" or "LegacyPing"
    local nativeStatus = nil
    local reserveStatus
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
    }, Players.LocalPlayer.UserId)
    if connectionConfig.transport == "DeviceCookie" then deviceCookie.Restore() end
    local credentialGeneration, deviceFatal = 0, nil
    local deviceNative
    local function writeJson(path, value)
        if session and not session.alive then return false end
        local ok = store.Write(path, value)
        if not ok then warn("[EggFinder] No se pudo guardar " .. path) end
        return ok
    end
    -- Tema de Mistake Hub: Claro, Oscuro o Sistema (hora local del dispositivo,
    -- porque Roblox no expone la apariencia del sistema). Se resuelve antes de
    -- crear la interfaz para que no haya destello del tema equivocado; los
    -- colores viven en hubTheme.colors y se actualizan en su sitio.
    hubTheme = { listeners = {}, roots = {} }
    do
        local function palette(name)
            local colors = {}
            for token, rgb in pairs(support.THEMES[name]) do colors[token] = Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
            return colors
        end
        function hubTheme.Hour()
            local ok, now = pcall(os.date, "*t")
            return ok and type(now) == "table" and now.hour or nil
        end
        hubTheme.preference = support.ThemePreference(readJson("chilli_egg_panel_ui.json", {}).theme)
        hubTheme.name = support.ResolveTheme(hubTheme.preference, hubTheme.Hour())
        hubTheme.colors = palette(hubTheme.name)
        hubTheme.alpha = table.clone(support.THEME_ALPHA[hubTheme.name])
        -- Cada color de la interfaz pasa al mismo token del tema nuevo. Las
        -- imagenes no se tocan: su color blanco es el de la imagen original.
        function hubTheme.Apply(name)
            if name == hubTheme.name or not support.THEMES[name] then return false end
            local map, key = support.ThemeRemap(hubTheme.name, name)
            local function swap(object, property)
                local color = object[property]
                local rgb = map[key({math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255)})]
                if rgb then object[property] = Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
            end
            uiAccess()
            for _, listener in ipairs(hubTheme.listeners) do if listener.before then pcall(listener.before) end end
            uiAccess()
            for _, root in ipairs(hubTheme.roots) do
                if root.Parent ~= nil or root.Name == "FocusRing" then
                    for _, object in ipairs({root, unpack(root:GetDescendants())}) do
                        -- La tarjeta flotante conserva su paleta de manga.
                        if hubTheme.fixed and (object == hubTheme.fixed or object:IsDescendantOf(hubTheme.fixed)) then continue end
                        if object:IsA("UIStroke") then swap(object, "Color")
                        elseif object:IsA("GuiObject") then
                            swap(object, "BackgroundColor3")
                            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then swap(object, "TextColor3") end
                            if object:IsA("TextBox") then swap(object, "PlaceholderColor3") end
                            if object:IsA("ScrollingFrame") then swap(object, "ScrollBarImageColor3") end
                        end
                    end
                end
            end
            for token, color in pairs(palette(name)) do hubTheme.colors[token] = color end
            hubTheme.name = name
            for property, value in pairs(support.THEME_ALPHA[name]) do hubTheme.alpha[property] = value end
            for _, listener in ipairs(hubTheme.listeners) do
                if listener.after then
                    local ok, err = pcall(listener.after)
                    if not ok then warn("[MistakeHub] Tema: " .. tostring(err)) end
                end
            end
            return true
        end
        -- Claro, Oscuro o Sistema; se guarda con las preferencias del hub.
        function hubTheme.Set(preference)
            hubTheme.preference = support.ThemePreference(preference)
            hubTheme.Apply(support.ResolveTheme(hubTheme.preference, hubTheme.Hour()))
            for _, listener in ipairs(hubTheme.listeners) do
                if listener.preference then pcall(listener.preference) end
            end
            return hubTheme.name
        end
        -- Imagenes publicadas junto al script en stable: el icono del hub y la
        -- vineta de la tarjeta flotante. Se guardan una vez en el workspace del
        -- executor y se cargan con getcustomasset (Roblox no lee archivos
        -- locales). Sin esas funciones, sin red o sin un JPEG valido: nil, y el
        -- hub usa la M y la tarjeta queda sin vineta.
        local function publishedImage(file)
            local ok, image = pcall(function()
                local custom = getcustomasset or getsynasset
                if type(custom) ~= "function" or type(writefile) ~= "function" then return nil end
                if not (type(isfile) == "function" and isfile(file)) then
                    local body = game:HttpGet("https://raw.githubusercontent.com/diegotoruno/SAE-SCRIPT/stable/" .. file)
                    if type(body) ~= "string" or #body < 1024 or string.sub(body, 1, 2) ~= "\255\216" then return nil end
                    writefile(file, body)
                end
                return custom(file)
            end)
            return ok and type(image) == "string" and image ~= "" and image or nil
        end
        hubTheme.icon = publishedImage("mistake_hub_icon.jpg")
        hubTheme.banner = publishedImage("mistake_hop_banner.jpg")
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
            return session.alive and generation == credentialGeneration and (candidate ~= nil or not session.accountConnecting)
                and (not continuing or continuing())
        end, progress)
        secret = nil
        if ((status == 400 and not cursor) or status == 401 or status == 403 or status == 302)
            and generation == credentialGeneration then deviceFatal = reason end
        return result, reason, status
    end
    local reportNativeProgress, saveNativePool
    local DEVICE_STREAM_FILE = "server_hop_button_native_" .. tostring(Players.LocalPlayer.UserId) .. ".json"
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
            publish = function(pool) if saveNativePool and session.alive then saveNativePool(pool) end end,
            fetch = function(orderBy, cursor, continuing)
                return deviceFetch(orderBy, cursor, nil, function(waitState)
                    local state = support.Copy(nativeStatus or {})
                    state.wait = waitState; publishNativeProgress(state)
                end, continuing)
            end,
            alive = function() return session and session.alive and not session.accountConnecting end})
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

    local function autoTestRunning()
        local state = readJson(SCOUT_STATE_FILE, nil)
        return type(state) == "table" and state.active == true
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
        if session.holderSpring then session.holderSpring:Disconnect(); session.holderSpring = nil end
        if session.DisposeSearch then session.DisposeSearch() end
        if session.DisposePanel then session.DisposePanel() end
        if session.attempt then session.attempt.Cancel() end
        credentialGeneration += 1; deviceCookie.Destroy()
        if session.DisposeAccount then session.DisposeAccount() end
    end)
    function session.Destroy()
        session.alive = false
        session.autoGeneration += 1
        disconnectSession()
        if session.holderSpring then session.holderSpring:Disconnect(); session.holderSpring = nil end
        if session.DisposeSearch then session.DisposeSearch() end
        if session.DisposePanel then session.DisposePanel() end
        if session.attempt then session.attempt.Cancel() end
        credentialGeneration += 1; deviceCookie.Destroy()
        if session.DisposeAccount then session.DisposeAccount() end
        if session.alertSound then session.alertSound:Destroy() end
        if screenGui.Parent then screenGui:Destroy() end
    end
    -- Con Sistema, el tema sigue la hora local: se revisa cada 30 s y el bucle
    -- termina con la sesion.
    table.insert(hubTheme.roots, screenGui)
    task.spawn(function()
        while session.alive do
            task.wait(30)
            if session.alive and hubTheme.preference == "system" then
                uiAccess(); hubTheme.Apply(support.ResolveTheme("system", hubTheme.Hour()))
            end
        end
    end)

    -- Estado de la ventana: si esta plegada y donde la dejaste. Se recuerda
    -- tambien entre saltos, porque vive en un archivo, no en memoria.
    local uiState = readJson(UI_FILE, {})
    local collapsed = (uiState.collapsed == true)
    local autoEnabled = (uiState.auto == true)
    -- Acceso rapido: la tarjeta flotante se puede ocultar desde el hub.
    local quickVisible = (uiState.quick ~= false)
    -- La franja de los ojos va arriba en ambos tamanos y suma su alto.
    local EXPANDED_SIZE = hubTheme.banner and Vector2.new(320, 156) or Vector2.new(320, 116)
    local COLLAPSED_SIZE = hubTheme.banner and Vector2.new(232, 96) or Vector2.new(232, 66)
    local savedPosition = UDim2.new(0.5, 0, 0, 26)
    if type(uiState.pos) == "table" then
        local pos = uiState.pos
        if type(pos.sx) == "number" and type(pos.xo) == "number"
            and type(pos.sy) == "number" and type(pos.yo) == "number" then
            savedPosition = UDim2.new(pos.sx, pos.xo, pos.sy, pos.yo)
        end
    end

    -- Panel de manga: papel, tinta gruesa y sombra solida desplazada, con su
    -- propia paleta (support.MANGA) que el tema del hub no cambia. AUTO, accion
    -- principal y plegado comparten una fila; estado y firma tienen filas
    -- propias para que ningun texto se encime.
    local ink = {}
    for token, rgb in pairs(support.MANGA) do ink[token] = Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
    pcall(function() ink.title = Font.fromEnum(Enum.Font.Bangers) end)
    ink.title = ink.title or Font.new(UI_FONT, Enum.FontWeight.Heavy)
    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.AnchorPoint = Vector2.new(0.5, 0)
    holder.Position = savedPosition
    holder.Size = UDim2.fromOffset(
        collapsed and COLLAPSED_SIZE.X or EXPANDED_SIZE.X,
        collapsed and COLLAPSED_SIZE.Y or EXPANDED_SIZE.Y
    )
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Active = true
    holder.Visible = quickVisible
    holder.Parent = screenGui
    hubTheme.fixed = holder

    -- Tamano elegido con el asa: escala toda la tarjeta, plegada o no.
    local function fitScaleLimit()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize
        if not viewport or viewport.X <= 0 or viewport.Y <= 0 then return nil end
        return math.min((viewport.X - 16) / EXPANDED_SIZE.X, (viewport.Y - 16) / EXPANDED_SIZE.Y)
    end
    local holderScale = Instance.new("UIScale")
    holderScale.Name = "UserScale"
    holderScale.Scale = support.HopperScale(uiState.scale, fitScaleLimit())
    holderScale.Parent = holder

    local function round(object, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = object
    end
    local function outline(object, color, transparency)
        local stroke = Instance.new("UIStroke")
        stroke.Name = "Border"
        stroke.Color = color
        stroke.Transparency = transparency or 0
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = object
        return stroke
    end
    local function label(name, parent, size, color, bold, font)
        local item = Instance.new("TextLabel")
        item.Name = name
        item.BackgroundTransparency = 1
        item.FontFace = font or Font.new(UI_FONT, bold and Enum.FontWeight.SemiBold or Enum.FontWeight.Regular)
        item.Text = ""
        item.TextSize = size
        item.TextColor3 = color
        item.TextStrokeTransparency = 1
        item.TextTruncate = Enum.TextTruncate.AtEnd
        item.Parent = parent
        return item
    end
    -- Chevron de dos segmentos: no depende de glifos de la fuente.
    local function chevronSegments(parent)
        local segments = {}
        for index = 1, 2 do
            local segment = Instance.new("Frame")
            segment.Name = "Chevron" .. index
            segment.AnchorPoint = Vector2.new(0.5, 0.5)
            segment.Size = UDim2.fromOffset(7, 1.5)
            segment.BackgroundColor3 = COLORS.muted
            segment.BorderSizePixel = 0
            segment.Position = UDim2.new(0.5, index == 1 and -2.5 or 2.5, 0.5, 0)
            segment.Parent = parent
            segments[index] = segment
        end
        return segments
    end
    -- Sombra solida de vineta: un bloque violeta desplazado abajo a la derecha.
    ink.shadow = Instance.new("Frame")
    ink.shadow.Name = "Shadow"
    ink.shadow.Position = UDim2.fromOffset(5, 5)
    ink.shadow.Size = UDim2.fromScale(1, 1)
    ink.shadow.BackgroundColor3 = ink.shade
    ink.shadow.BorderSizePixel = 0
    ink.shadow.Parent = holder
    round(ink.shadow, 4)
    local surface = Instance.new("Frame")
    surface.Name = "Surface"
    surface.Size = UDim2.fromScale(1, 1)
    surface.BackgroundColor3 = ink.paper
    surface.BorderSizePixel = 0
    surface.Parent = holder
    round(surface, 4)
    outline(surface, ink.ink).Thickness = 3
    -- Trama de puntos en la esquina inferior izquierda, como el tono de un manga.
    for row = 0, 2 do
        for column = 0, 5 - row * 2 do
            local dot = Instance.new("Frame")
            dot.Name = "Tone"
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Position = UDim2.new(0, 10 + column * 6 + (row % 2) * 3, 1, -8 - row * 5)
            dot.Size = UDim2.fromOffset(3 - row * 0.5, 3 - row * 0.5)
            dot.BackgroundColor3 = ink.dots
            dot.BackgroundTransparency = 0.35 + row * 0.15
            dot.BorderSizePixel = 0
            dot.Parent = surface
            round(dot, 2)
        end
    end

    -- Movimiento de la tarjeta: un tween por propiedad que parte del valor
    -- actual, cancela el anterior y se cancela al destruir su objeto.
    -- Con movimiento reducido, plegar y volver al borde son inmediatos.
    local reducedMotion = false
    pcall(function()
        reducedMotion = GuiService.ReducedMotionEnabled == true
        connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), function()
            reducedMotion = GuiService.ReducedMotionEnabled == true
        end)
    end)
    local cardTweens = {}
    local function cardTween(object, info, goals, done)
        uiAccess()
        local slot = cardTweens[object]
        if not slot then
            slot = {}; cardTweens[object] = slot
            object.Destroying:Connect(function()
                for _, tween in pairs(slot) do tween:Cancel() end
                cardTweens[object] = nil
            end)
        end
        local first
        for key, value in pairs(goals) do
            if slot[key] then slot[key]:Cancel() end
            local tween = TweenService:Create(object, info, { [key] = value })
            slot[key] = tween; first = first or tween
            tween:Play()
        end
        if done and first then
            first.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and session.alive then uiAccess(); done() end
            end)
        end
    end
    local function cardPlace(object, goals)
        uiAccess()
        local slot = cardTweens[object]
        for key, value in pairs(goals) do
            if slot and slot[key] then slot[key]:Cancel(); slot[key] = nil end
            object[key] = value
        end
    end

    -- Franja de los ojos (vineta de manga de unos 9:1) arriba de la tarjeta,
    -- abierta o plegada, con borde de tinta.
    if hubTheme.banner then
        ink.banner = Instance.new("ImageLabel")
        ink.banner.Name = "Banner"
        ink.banner.Position = UDim2.fromOffset(10, 10)
        ink.banner.Size = UDim2.new(1, -20, 0, 32)
        ink.banner.BackgroundColor3 = ink.paper
        ink.banner.BorderSizePixel = 0
        ink.banner.Image = hubTheme.banner
        ink.banner.ScaleType = Enum.ScaleType.Crop
        ink.banner.Parent = surface
        round(ink.banner, 3)
        outline(ink.banner, ink.ink).Thickness = 2
    end

    -- Boton de accion: vineta azul a violeta con borde de tinta y rotulo de onomatopeya.
    local button = Instance.new("TextButton")
    button.Name = "ServerHop"
    button.AutoButtonColor = false
    button.Text = ""
    button.BackgroundColor3 = ink.onBlue
    button.BorderSizePixel = 0
    button.ClipsDescendants = true
    button.Parent = surface
    round(button, 3)
    outline(button, ink.ink).Thickness = 2.5
    do
        local fill = Instance.new("UIGradient")
        fill.Color = ColorSequence.new(ink.blue, ink.violet)
        fill.Parent = button
    end

    -- Lineas de velocidad: quietas y tenues en reposo; corren mientras salta.
    -- Cada trazo se repite media capa despues para que el ciclo no tenga corte.
    ink.lines = Instance.new("Frame")
    ink.lines.Name = "SpeedLines"
    ink.lines.Size = UDim2.fromScale(2, 1)
    ink.lines.BackgroundTransparency = 1
    ink.lines.Parent = button
    for index, streak in ipairs({ {0.03, 0.22, 0.16}, {0.15, 0.44, 0.12}, {0.29, 0.7, 0.19}, {0.07, 0.84, 0.13}, {0.35, 0.3, 0.1} }) do
        for half = 0, 1 do
            local line = Instance.new("Frame")
            line.Name = "Line" .. index
            line.AnchorPoint = Vector2.new(0, 0.5)
            line.Position = UDim2.fromScale(streak[1] + half * 0.5, streak[2])
            line.Size = UDim2.new(streak[3], 0, 0, 2)
            line.BackgroundColor3 = ink.onBlue
            line.BackgroundTransparency = 0.72
            line.BorderSizePixel = 0
            line.Parent = ink.lines
        end
    end

    local mainLabel = label("Label", button, 21, ink.onBlue, true, ink.title)
    mainLabel.Text = "Server Hop"
    mainLabel.TextStrokeColor3 = ink.ink
    mainLabel.TextStrokeTransparency = 0
    mainLabel.ZIndex = 2
    mainLabel.Position = UDim2.fromOffset(8, 0)
    mainLabel.Size = UDim2.new(1, -16, 1, 0)

    -- Recuadro de narracion: el estado va en una caja con borde fino de tinta.
    local statusLabel = label("Status", surface, 11, ink.soft, true)
    statusLabel.Position = UDim2.fromOffset(12, hubTheme.banner and 102 or 62)
    statusLabel.Size = UDim2.new(1, -24, 0, 30)
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.BackgroundColor3 = ink.paper
    statusLabel.BackgroundTransparency = 0
    outline(statusLabel, ink.ink).Thickness = 1.5
    do
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = statusLabel
    end

    -- La firma del autor va abajo a la derecha, junto al asa, en ambas versiones.
    local creditLabel = label("ByMistakeCredit", surface, 13, ink.ink, true, ink.title)
    creditLabel.AnchorPoint = Vector2.new(1, 1)
    creditLabel.Position = UDim2.new(1, -26, 1, -3)
    creditLabel.Size = UDim2.fromOffset(110, 15)
    creditLabel.TextXAlignment = Enum.TextXAlignment.Right
    creditLabel.Text = "By Mistake"
    creditLabel.Active = false
    creditLabel.Selectable = false

    -- La seccion Server Hop del hub repite el texto, el estado y AUTO de la tarjeta.
    local hopView = {}
    local function setLabel(text)
        if not session.alive then return end
        uiAccess()
        mainLabel.Text = text
        if hopView.button then hopView.button.Text = text end
    end

    local function setStatus(text, color)
        if not session.alive then return end
        uiAccess()
        statusLabel.Text = text
        ink.status = color or COLORS.muted
        -- Sobre el papel: avisos en rojo tinta, exito en verde y el resto en azul gris.
        statusLabel.TextColor3 = color == COLORS.amber and ink.alert or color == COLORS.green and ink.go or ink.soft
        if hopView.status then hopView.status.Text = text; hopView.status.TextColor3 = color or COLORS.muted end
    end

    local busy = false
    reportNativeProgress = function(state)
        if session.alive and busy then setStatus(support.NativeProgressMessage(state), COLORS.muted) end
    end

    -- Mientras salta, las lineas de velocidad se aclaran y corren sin parar.
    function ink.run(active)
        if ink.flow then ink.flow:Cancel(); ink.flow = nil end
        ink.lines.Position = UDim2.fromScale(0, 0)
        for _, line in ipairs(ink.lines:GetChildren()) do line.BackgroundTransparency = active and 0.4 or 0.72 end
        if active and not reducedMotion then
            ink.flow = TweenService:Create(ink.lines, TweenInfo.new(0.45, Enum.EasingStyle.Linear,
                Enum.EasingDirection.Out, -1), { Position = UDim2.fromScale(-1, 0) })
            ink.flow:Play()
        end
    end

    local function setBusy(value)
        if not session.alive then return end
        uiAccess()
        busy = value
        cardTween(button, TweenInfo.new(0.15), { BackgroundTransparency = value and 0.15 or 0 })
        if hopView.button then cardTween(hopView.button, TweenInfo.new(0.15), { BackgroundTransparency = value and 0.5 or 0 }) end
        ink.run(value)
    end

    -- Pulsar atenua el degradado al instante y hunde el rotulo un pixel.
    connect(button:GetPropertyChangedSignal("GuiState"), function()
        local pressed = button.GuiState == Enum.GuiState.Press
        if pressed then cardPlace(button, { BackgroundColor3 = ink.press })
        else cardTween(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = ink.onBlue }) end
        mainLabel.Position = UDim2.fromOffset(pressed and 9 or 8, pressed and 1 or 0)
    end)

    -- ------------------------------------------------- estado de la ventana
    local DRAG_THRESHOLD = 6

    local dragging = false
    local pendingDrag = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil
    local lastDragAt = -math.huge
    local dragOrigin, dragSample, dragVelocity = nil, nil, Vector2.zero
    local resizeInput, resizeStart, resizeScale, resizePosition = nil, nil, nil, nil

    local function saveUi()
        uiAccess()
        local state = readJson(UI_FILE, {})
        state.collapsed = collapsed
        state.auto = autoEnabled
        state.quick = quickVisible
        state.scale = holderScale.Scale
        state.pos = {
            sx = holder.Position.X.Scale,
            xo = holder.Position.X.Offset,
            sy = holder.Position.Y.Scale,
            yo = holder.Position.Y.Offset,
        }
        writeJson(UI_FILE, state)
    end

    local function draggedRecently()
        return dragging or (os.clock() - lastDragAt) < 0.25
    end

    -- Plegar/desplegar, a la derecha del boton principal.
    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.AutoButtonColor = true
    toggle.AnchorPoint = Vector2.new(1, 0)
    toggle.BackgroundColor3 = ink.paper
    toggle.BorderSizePixel = 0
    toggle.Text = ""
    toggle.Parent = surface
    round(toggle, 3)
    outline(toggle, ink.ink).Thickness = 2
    local toggleChevron = chevronSegments(toggle)
    for _, segment in ipairs(toggleChevron) do segment.BackgroundColor3 = ink.ink; segment.Size = UDim2.fromOffset(8, 2) end

    -- AUTO: etiqueta e interruptor; enciende/apaga el encadenado automatico. Se
    -- guarda en server_hop_button_ui.json para que siga encendido entre saltos.
    local autoChip = Instance.new("TextButton")
    autoChip.Name = "AutoChip"
    autoChip.AutoButtonColor = false
    autoChip.BackgroundColor3 = ink.dots
    autoChip.BackgroundTransparency = 1
    autoChip.BorderSizePixel = 0
    autoChip.Text = ""
    autoChip.Parent = surface
    round(autoChip, 3)

    -- Pasar el raton da un fondo gris suave; pulsar, uno mas firme al instante.
    connect(autoChip:GetPropertyChangedSignal("GuiState"), function()
        local state = autoChip.GuiState
        if state == Enum.GuiState.Press then cardPlace(autoChip, { BackgroundTransparency = 0.82 })
        else cardTween(autoChip, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = (state == Enum.GuiState.Hover and UserInputService.MouseEnabled) and 0.9 or 1 }) end
    end)

    local autoLabel = label("AutoLabel", autoChip, 14, ink.soft, true, ink.title)
    autoLabel.Size = UDim2.new(1, 0, 0, 16)
    autoLabel.Text = "AUTO"
    autoLabel.TextTruncate = Enum.TextTruncate.None

    local autoTrack = Instance.new("Frame")
    autoTrack.Name = "Switch"
    autoTrack.AnchorPoint = Vector2.new(0.5, 1)
    autoTrack.Position = UDim2.new(0.5, 0, 1, -3)
    autoTrack.Size = UDim2.fromOffset(38, 20)
    autoTrack.BackgroundColor3 = ink.trackOff
    autoTrack.BorderSizePixel = 0
    autoTrack.Parent = autoChip
    round(autoTrack, 3)
    outline(autoTrack, ink.ink).Thickness = 2
    local autoKnob = Instance.new("Frame")
    autoKnob.Name = "Knob"
    autoKnob.AnchorPoint = Vector2.new(0, 0.5)
    autoKnob.Position = UDim2.new(0, 3, 0.5, 0)
    autoKnob.Size = UDim2.new(1, -6, 1, -6)
    autoKnob.BackgroundColor3 = ink.ink
    autoKnob.BorderSizePixel = 0
    autoKnob.Parent = autoTrack
    round(autoKnob, 2)
    Instance.new("UIAspectRatioConstraint", autoKnob).DominantAxis = Enum.DominantAxis.Height

    -- Interruptor: pista azul encendida, lavanda palida apagada; la perilla se desliza.
    local function updateAutoChip()
        uiAccess()
        local tween = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        autoLabel.TextColor3 = autoEnabled and ink.blue or ink.soft
        local track = { BackgroundColor3 = autoEnabled and ink.blue or ink.trackOff }
        local knob = { AnchorPoint = Vector2.new(autoEnabled and 1 or 0, 0.5),
            Position = autoEnabled and UDim2.new(1, -3, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }
        if reducedMotion then cardPlace(autoTrack, track); cardPlace(autoKnob, knob)
        else cardTween(autoTrack, tween, track); cardTween(autoKnob, tween, knob) end
        if hopView.setAuto then hopView.setAuto(autoEnabled) end
        if hopView.syncHub then hopView.syncHub(autoEnabled) end
    end

    local function applyCollapsed(value, instant)
        collapsed = value
        local size = value and COLLAPSED_SIZE or EXPANDED_SIZE
        local pad = value and 8 or 10
        local row = value and 34 or 44
        local chip = value and 52 or 60
        local side = value and 28 or 32
        instant = instant or reducedMotion
        local tween = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        local function place(object, properties, done)
            if instant then cardPlace(object, properties); if done then done() end
            else cardTween(object, tween, properties, done) end
        end

        -- El estado solo se ve con la tarjeta ya abierta: nunca sobresale.
        -- Con la franja de los ojos, la fila de controles va debajo de ella.
        local top = pad
        if ink.banner then
            local strip = value and 24 or 32
            place(ink.banner, { Position = UDim2.fromOffset(pad, pad), Size = UDim2.new(1, -2 * pad, 0, strip) })
            top = pad + strip + (value and 6 or 8)
        end
        if value then statusLabel.Visible = false end
        place(holder, { Size = UDim2.fromOffset(size.X, size.Y) }, function()
            if not collapsed then statusLabel.Visible = true end
        end)
        place(autoChip, { Position = UDim2.fromOffset(pad, top), Size = UDim2.fromOffset(chip, row) })
        place(button, { Position = UDim2.fromOffset(pad + chip + 6, top),
            Size = UDim2.new(1, -(2 * pad + chip + side + 12), 0, row) })
        place(toggle, { Position = UDim2.new(1, -pad, 0, top), Size = UDim2.fromOffset(side, row) })
        mainLabel.TextSize = value and 18 or 21
        autoLabel.TextSize = value and 12 or 14
        autoLabel.Size = UDim2.new(1, 0, 0, value and 13 or 16)
        autoTrack.Size = value and UDim2.fromOffset(32, 16) or UDim2.fromOffset(38, 20)
        -- Desplegado muestra "plegar" (chevron arriba); plegado, "desplegar".
        toggleChevron[1].Rotation = value and 45 or -45
        toggleChevron[2].Rotation = value and -45 or 45
    end

    -- Los eventos del marco no reciben necesariamente los de sus controles.
    -- Registrar toda la tarjeta, incluidos texto, AUTO y plegado.
    local function beginDrag(input)
        if pendingDrag or resizeInput then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            pendingDrag = true
            dragging = false
            dragInput = input
            dragStart = input.Position
            -- Agarrar la tarjeta mientras vuelve al borde la detiene ahi.
            if session.holderSpring then session.holderSpring:Disconnect(); session.holderSpring = nil end
            startPosition = holder.Position
            dragOrigin, dragSample, dragVelocity = holder.AbsolutePosition, nil, Vector2.zero
        end
    end

    connect(holder.InputBegan, beginDrag)
    for _, surface in ipairs(holder:GetDescendants()) do
        if surface:IsA("GuiObject") then
            connect(surface.InputBegan, beginDrag)
        end
    end

    connect(UserInputService.InputChanged, function(input)
        if not pendingDrag or not dragStart then
            return
        end
        if dragInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= dragInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - dragStart
        if not dragging and delta.Magnitude < DRAG_THRESHOLD then
            return
        end

        dragging = true
        lastDragAt = os.clock()
        -- 1:1 dentro de la pantalla; pasado el borde cada pixel cuenta menos.
        local offset = Vector2.new(delta.X, delta.Y)
        local camera = workspace.CurrentCamera
        if camera and dragOrigin then
            local viewport, size = camera.ViewportSize, holder.AbsoluteSize
            local raw = dragOrigin + offset
            offset = Vector2.new(support.Rubberband(raw.X, 8, viewport.X - size.X - 8, viewport.X),
                support.Rubberband(raw.Y, 8, viewport.Y - size.Y - 8, viewport.Y)) - dragOrigin
        end
        if dragSample and lastDragAt > dragSample.at then
            dragVelocity = dragVelocity:Lerp((offset - dragSample.point) / (lastDragAt - dragSample.at), 0.5)
        end
        dragSample = { at = lastDragAt, point = offset }
        holder.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + offset.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + offset.Y
        )
    end)

    -- Al soltar fuera de la pantalla, un resorte sin rebote la devuelve desde
    -- donde esta, con la velocidad del dedo. Dentro de la pantalla se queda.
    local function settleHolder(velocity)
        local camera = workspace.CurrentCamera
        if not camera then saveUi(); return end
        local viewport, size, at = camera.ViewportSize, holder.AbsoluteSize, holder.AbsolutePosition
        local correction = Vector2.new(math.clamp(at.X, 8, math.max(8, viewport.X - size.X - 8)),
            math.clamp(at.Y, 8, math.max(8, viewport.Y - size.Y - 8))) - at
        if correction.Magnitude < 0.5 then saveUi(); return end
        local base = holder.Position
        local position = Vector2.new(base.X.Offset, base.Y.Offset)
        local target = position + correction
        local function put(point) holder.Position = UDim2.new(base.X.Scale, point.X, base.Y.Scale, point.Y) end
        if reducedMotion then put(target); saveUi(); return end
        local speed = velocity.Magnitude > 3000 and velocity.Unit * 3000 or velocity
        session.holderSpring = RunService.RenderStepped:Connect(function(dt)
            if not session.alive then return end
            uiAccess()
            dt = math.min(dt, 1 / 20)
            local x, vx = support.SpringStep(position.X, speed.X, target.X, dt, 0.3)
            local y, vy = support.SpringStep(position.Y, speed.Y, target.Y, dt, 0.3)
            position, speed = Vector2.new(x, y), Vector2.new(vx, vy)
            if (position - target).Magnitude < 0.5 and speed.Magnitude < 5 then
                session.holderSpring:Disconnect(); session.holderSpring = nil
                put(target); saveUi(); return
            end
            put(position)
        end)
    end

    local function finishDrag()
        if dragging then
            -- Tambien cubrir un arrastre que se mantuvo quieto antes de soltar.
            local moving = dragSample and os.clock() - dragSample.at < 0.06
            lastDragAt = os.clock()
            settleHolder(moving and dragVelocity or Vector2.zero)
        end
        pendingDrag = false
        dragging = false
        dragInput, dragStart, startPosition = nil, nil, nil
    end

    connect(UserInputService.InputEnded, function(input)
        if not dragInput then return end
        if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1) then
            finishDrag()
        end
    end)
    connect(UserInputService.WindowFocusReleased, finishDrag)

    -- Asa de tamano en la esquina inferior derecha: tres trazos diagonales
    -- dentro del borde redondeado. Se crea despues de registrar el arrastre de
    -- la tarjeta, asi que tirar de ella redimensiona sin mover.
    local GRIP_TRACES = { {11, 5}, {16, 11}, {21, 17} } -- distancia a la esquina, largo
    local grip = Instance.new("TextButton")
    grip.Name = "ResizeGrip"
    grip.AutoButtonColor = false
    grip.AnchorPoint = Vector2.new(1, 1)
    grip.Position = UDim2.fromScale(1, 1)
    grip.Size = UDim2.fromOffset(24, 24)
    grip.BackgroundTransparency = 1
    grip.Text = ""
    grip.ZIndex = 3
    grip.Parent = surface
    local gripTraces = {}
    for index, trace in ipairs(GRIP_TRACES) do
        local line = Instance.new("Frame")
        line.Name = "Trace" .. index
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.new(1, -trace[1] / 2, 1, -trace[1] / 2)
        line.Size = UDim2.fromOffset(trace[2], 1.5)
        line.Rotation = -45
        line.BackgroundColor3 = ink.dots
        line.BackgroundTransparency = 0.4
        line.BorderSizePixel = 0
        line.ZIndex = 3
        line.Parent = grip
        gripTraces[index] = line
    end

    local gripHover = false
    local function paintGrip()
        uiAccess()
        local active = gripHover or resizeInput ~= nil
        local tween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, line in ipairs(gripTraces) do
            TweenService:Create(line, tween, {
                BackgroundColor3 = active and ink.blue or ink.dots,
                BackgroundTransparency = active and 0 or 0.4,
            }):Play()
        end
    end
    connect(grip.MouseEnter, function() gripHover = true; paintGrip() end)
    connect(grip.MouseLeave, function() gripHover = false; paintGrip() end)

    connect(grip.InputBegan, function(input)
        if resizeInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        -- El marco puede recibir el mismo toque: el asa nunca mueve la tarjeta.
        if session.holderSpring then session.holderSpring:Disconnect(); session.holderSpring = nil end
        pendingDrag, dragging = false, false
        dragInput, dragStart, startPosition = nil, nil, nil
        resizeInput, resizeStart = input, input.Position
        resizeScale, resizePosition = holderScale.Scale, holder.Position
        paintGrip()
    end)

    connect(UserInputService.InputChanged, function(input)
        if not resizeInput then return end
        if resizeInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= resizeInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local base = collapsed and COLLAPSED_SIZE or EXPANDED_SIZE
        local scale = support.ResizeHopperScale(resizeScale, base, input.Position - resizeStart, fitScaleLimit())
        holderScale.Scale = scale
        -- AnchorPoint centra la tarjeta en X: compensar para fijar el borde izquierdo.
        holder.Position = UDim2.new(
            resizePosition.X.Scale,
            resizePosition.X.Offset + base.X * (scale - resizeScale) / 2,
            resizePosition.Y.Scale,
            resizePosition.Y.Offset
        )
    end)

    local function finishResize()
        if not resizeInput then return end
        resizeInput, resizeStart, resizeScale, resizePosition = nil, nil, nil, nil
        lastDragAt = os.clock()
        paintGrip()
        saveUi()
    end

    connect(UserInputService.InputEnded, function(input)
        if not resizeInput then return end
        if input == resizeInput or (resizeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1) then
            finishResize()
        end
    end)
    connect(UserInputService.WindowFocusReleased, finishResize)

    connect(toggle.MouseButton1Click, function()
        if draggedRecently() then
            return
        end
        applyCollapsed(not collapsed)
        saveUi()
    end)

    applyCollapsed(collapsed, true)

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
                serverConnection = {orderBy = serverOrder, transport = connectionConfig.transport or "LocalBridge",
                    credential = deviceCookie.Status(), request = deviceTransport.State(), native = support.Copy(nativeStatus),
                    reserve = reserveStatus and reserveStatus() or {count = 0}},
                mode = session.searchMode, cycle = eggSearch.CycleStatus(),
                config = support.Copy(eggSearch.config), lastScan = eggSearch.lastScan and {
                    match = support.Copy(eggSearch.lastScan.match), info = support.Copy(eggSearch.lastScan.info),
                    matches = support.Copy(eggSearch.lastScan.matches), revision = eggSearch.lastScan.revision },
                stats = support.Copy(eggSearch.stats), teleport = session.attempt and session.attempt.state,
                searchWindow = eggSearch.SearchWindow() }
        end,
    }

    -- Mistake Hub: Egg Finder, filtros, calculadora, Server Hop y ajustes en una
    -- sola ventana. La tarjeta Server Hop es el unico acceso flotante.
    local filterPanel = mountEggFilterPanel({ search = eggSearch,
        api = hopperEnvironment.ChilliEggSearch, session = session, screenGui = screenGui,
        readJson = readJson, writeJson = writeJson, theme = hubTheme,
        scaling = { Drag = support.DragScale, Panel = support.PanelScale,
            Rubberband = support.Rubberband, Spring = support.SpringStep } })
    session.DisposePanel = filterPanel.Destroy
    local ui = filterPanel.ui
    hopView.syncHub = filterPanel.SyncAuto
    local hopPage = filterPanel.Page("hop")

    -- Seccion Server Hop: el mismo salto y AUTO que la tarjeta flotante y el
    -- interruptor que la muestra u oculta.
    local function setQuickVisible(value)
        quickVisible = value == true
        uiAccess(); holder.Visible = quickVisible
        if hopView.setQuick then hopView.setQuick(quickVisible) end
        saveUi()
    end
    do
        local C, width = ui.colors, ui.content
        uiAccess()
        ui.heading(hopPage, "Server Hop", "Cambia de servidor al momento o deja que AUTO salte hasta encontrar tu huevo.", 0)
        local card = ui.make("Frame", "HopStatus", hopPage, { Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(width, 68),
            BackgroundColor3 = C.raised, BorderSizePixel = 0 })
        ui.corner(card, 10); ui.stroke(card).Transparency = 0.8
        ui.text("Caption", card, "Estado", 16, 12, width - 220, 14, C.secondary, 11, "semi")
        hopView.status = ui.paragraph("Status", card, statusLabel.Text, 16, 28, width - 220, 30, ink.status or COLORS.muted, 12)
        hopView.button = ui.button("ServerHop", card, mainLabel.Text, width - 188, 12, 172, 44)
        ui.primary(hopView.button); hopView.button.TextSize = 15
        hopView.setAuto = ui.toggleRow(hopPage, "AutoSearch", "Búsqueda automática (AUTO)",
            "Salta de servidor hasta encontrar un huevo que cumpla tus filtros.", 136, autoEnabled, function()
                setAuto(not autoEnabled)
            end)
        hopView.setQuick = ui.toggleRow(hopPage, "QuickAccess", "Acceso rápido flotante",
            "Muestra la tarjeta Server Hop sobre el juego, fuera del hub.", 196, quickVisible, function()
                setQuickVisible(not quickVisible)
            end)
    end
    hopperEnvironment.ChilliEggSearch.QuickHop = function() return quickVisible end
    -- Tema del hub: "light", "dark" o "system" (hora local del dispositivo).
    hopperEnvironment.ChilliEggSearch.Theme = function()
        return { preference = hubTheme.preference, active = hubTheme.name }
    end
    hopperEnvironment.ChilliEggSearch.SetTheme = function(value)
        assert(session.alive, "Esta sesion ya termino")
        assert(value == "light" or value == "dark" or value == "system", "Usa light, dark o system")
        uiAccess(); return hubTheme.Set(value)
    end
    hopperEnvironment.ChilliEggSearch.SetQuickHop = function(value)
        assert(session.alive, "Esta sesion ya termino")
        assert(type(value) == "boolean", "Usa true o false")
        setQuickVisible(value); return quickVisible
    end

    -- Account entry stays in a local closure; never expose it in GetStatus,
    -- logs, Chilli configuration, teleport state, or companion requests.
    do
        local C, width, column = ui.colors, ui.content, ui.column
        uiAccess()
        ui.text("AccountTitle", hopPage, "Cuenta y Best Ping", 0, 272, width - 180, 20, C.text, 15, true)
        local badge = ui.text("AccountState", hopPage, "", width - 170, 272, 170, 20, C.secondary, 12, true)
        badge.TextXAlignment = Enum.TextXAlignment.Right
        ui.paragraph("Privacy", hopPage, "Con tu cookie, este dispositivo pide a Roblox los servidores con mejor ping. "
            .. "El autor del script no la recibe.", 0, 294, width, 28, C.secondary, 11)
        local input = ui.make("TextBox", "CookieInput", hopPage, { Position = UDim2.fromOffset(0, 326), Size = UDim2.fromOffset(width, 40),
            BackgroundColor3 = C.field, BorderSizePixel = 0, Text = "", PlaceholderText = "", ClearTextOnFocus = false,
            MultiLine = false, TextTransparency = 1, TextSize = 16, FontFace = ui.face("medium"), SelectionImageObject = ui.focusRing })
        ui.corner(input, 8); ui.stroke(input); ui.halo(input)
        local mask = ui.text("MaskedValue", input, "Toca aquí y pega la cookie completa", 14, 0, width - 28, 40, C.secondary, 13)
        ui.paragraph("StorageHelp", hopPage, "Guardar permite continuar entre saltos. Se guarda solo aquí, sin cifrado; "
            .. "otros scripts del executor podrían leerla.", 0, 372, width, 28, C.secondary, 11)
        local message = ui.paragraph("ConnectionMessage", hopPage, "", 0, 404, width, 28, C.secondary, 11)
        local save = ui.button("SaveAndAuto", hopPage, "Guardar y usar AUTO", 0, 436, column, 36); ui.primary(save)
        local once = ui.button("SessionOnly", hopPage, "Solo esta sesión", column + 8, 436, column, 36)
        local forget = ui.button("ForgetCookie", hopPage, "Borrar cookie", 2 * (column + 8), 436, column, 36)
        forget.TextColor3 = C.red
        local draft, updating, connecting = nil, false, false
        local function savedMessage(state)
            return state.remembered and "Cookie guardada en este dispositivo. AUTO puede usar Best Ping entre saltos."
                or "Cookie activa solo en esta sesión; no se guardó."
        end
        local function idleMessage()
            local state = deviceCookie.Status()
            return connecting and support.DeviceWaitMessage(deviceTransport.State())
                or state.configured and savedMessage(state)
                or "Pega tu cookie para conectar tu propia cuenta."
        end
        local function updateEntry()
            uiAccess()
            local state = deviceCookie.Status()
            badge.Text = connecting and "Comprobando..."
                or state.configured and (state.remembered and "Cuenta guardada" or "Solo esta sesión")
                or "Sin cuenta"
            badge.TextColor3 = connecting and C.orange or state.configured and C.green or C.secondary
        end
        -- The form counts as open while the hub shows the Server Hop section.
        local function formOpen()
            local state = filterPanel.GetStatus()
            return state.open and not state.minimized and state.tab == "hop"
        end
        local function show()
            if not session.alive then return end
            uiAccess(); filterPanel.Open(); filterPanel.Select("hop")
            uiAccess(); message.Text = idleMessage()
        end
        local function hide()
            uiAccess(); input:ReleaseFocus(); input.Text = ""; draft = nil
            mask.Text = "Toca aquí y pega la cookie completa"
        end
        filterPanel.OnSelect("hop", function()
            if not connecting then uiAccess(); message.Text = idleMessage() end
        end)
        connect(input:GetPropertyChangedSignal("Text"), function()
            if updating or input.Text == "" then return end
            draft = support.NormalizeCookie(input.Text)
            updating = true; input.Text = ""; updating = false
            mask.Text = draft and "Cookie recibida (oculta)" or "Pega solo la cookie completa"
        end)
        local function activate(persist)
            if connecting then return end
            if not draft then message.Text = "Pega la cookie completa antes de conectar."; return end
            if not executorRequest() then message.Text = "Este executor no ofrece request con headers."; return end
            local candidate = draft; draft = nil
            input:ReleaseFocus(); mask.Text = "Cookie recibida (oculta)"
            connecting = true; session.accountConnecting = true; save.Active = false; once.Active = false
            save.Text = "Comprobando..."; once.Text = "Espera..."; updateEntry()
            setAuto(false); uiAccess(); message.Text = "Comprobando la conexión con Roblox..."
            task.spawn(function()
                local generation = credentialGeneration
                local page, reason, status
                for attempt = 1, 2 do
                    page, reason, status = deviceFetch("BestLatency", nil, candidate, function(state)
                        if not session.alive or generation ~= credentialGeneration then return end
                        uiAccess(); message.Text = support.DeviceWaitMessage(state)
                    end)
                    if status ~= 429 or attempt == 2 then break end
                end
                if not session.alive or generation ~= credentialGeneration then candidate = nil; return end
                local ok = false
                if page then
                    uiAccess(); message.Text = persist and "Guardando y verificando el archivo local..." or "Activando solo en esta sesión..."
                    ok, reason = deviceCookie.Set(candidate, persist)
                    if ok then
                        connectionConfig = {mode = "BestLatency", transport = "DeviceCookie"}
                        ok = writeJson(CONNECTION_FILE, connectionConfig)
                        if not ok then reason = "No se pudo guardar el modo de conexion. Reintenta." end
                    end
                end
                -- Retain a failed attempt only while the form stays open,
                -- so an interval or cooldown never requires another paste.
                uiAccess()
                if not ok and formOpen() then draft = draft or candidate end
                candidate = nil; connecting = false; session.accountConnecting = false
                uiAccess(); save.Active = true; once.Active = true
                save.Text = "Guardar y usar AUTO"; once.Text = "Solo esta sesión"; updateEntry()
                if ok then
                    credentialGeneration += 1; deviceFatal = nil; serverOrder = "BestLatency"
                    writeJson(POOL_FILE, {servers = {}}); resetDeviceNative(page, true)
                    -- Confirm verified storage before starting AUTO, which may
                    -- change the map status or begin a later hop independently.
                    draft = nil; input.Text = ""; mask.Text = "Toca aquí para cambiar la cookie"
                    message.Text = savedMessage(deviceCookie.Status())
                    nativeStatus = {state = "connected"}; setAuto(true)
                else
                    message.Text = reason or "No se pudo conectar. Pega la cookie y reintenta."
                    mask.Text = draft and "Cookie recibida (oculta); puedes reintentar" or "Toca aquí y pega la cookie completa"
                end
            end)
        end
        connect(save.Activated, function() activate(true) end)
        connect(once.Activated, function() activate(false) end)
        connect(forget.Activated, function()
            credentialGeneration += 1; draft = nil; connecting = false; session.accountConnecting = false; setAuto(false)
            local removed = deviceCookie.Forget()
            deviceFatal = nil; writeJson(POOL_FILE, {servers = {}}); resetDeviceNative(nil, true)
            -- Leave the selected transport enabled: an absent cookie waits;
            -- it must not silently resume legacy or the owner's PC bridge.
            connectionConfig = {mode = "BestLatency", transport = "DeviceCookie"}
            serverOrder = "BestLatency"; writeJson(CONNECTION_FILE, connectionConfig)
            uiAccess(); input.Text = ""; mask.Text = "Toca aquí y pega la cookie completa"
            save.Active = true; once.Active = true
            save.Text = "Guardar y usar AUTO"; once.Text = "Solo esta sesión"; updateEntry()
            message.Text = removed and "Cookie borrada. AUTO apagado." or "AUTO apagado. No se pudo borrar el archivo local; revisa el executor."
        end)
        hopperEnvironment.ChilliEggSearch.OpenServerAccount = show
        hopperEnvironment.ChilliEggSearch.CloseServerAccount = hide
        hopperEnvironment.ChilliEggSearch.ServerAccountStatus = function()
            uiAccess()
            local state = deviceCookie.Status()
            return {open = formOpen(), launcherVisible = false, configured = state.configured, remembered = state.remembered,
                connecting = connecting, message = message.Text}
        end
        session.DisposeAccount = function() draft = nil; session.accountConnecting = false end
        updateEntry(); message.Text = idleMessage()
        if connectionConfig.transport ~= "LocalBridge" and not deviceCookie.Status().configured
            and connectionConfig.mode ~= "BestLatency" then show()
        elseif connectionConfig.transport == "DeviceCookie" and not deviceCookie.Status().configured then show() end
    end

    -- ---------------------------------------------------------------- el salto
    local function pickCandidates(continuing, wanted)
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
            owner = Players.LocalPlayer.UserId,
            reservePolicy = balanced and "balanced-1-2-v1" or nil,
            occupancy = group[1].playing,
            updatedAt = os.time(),
            servers = trimmed,
        })
    end
    saveNativePool = savePool
    if connectionConfig.transport == "DeviceCookie" then
        local restored = deviceNative.Reserve(game.JobId,
            recentVisited.Get(os.time()))
        if restored then savePool(restored) end
    end

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
            if data.owner ~= Players.LocalPlayer.UserId then return nil end
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

    -- Several IDs share one verified write of the history file.
    local function markVisited(...)
        local now = os.time()
        local visited = support.PruneVisited(readJson(VISITED_FILE, {}), now, VISITED_MAX_AGE)
        for _, jobId in ipairs({...}) do visited[jobId] = now end
        writeJson(VISITED_FILE, visited)
        recentVisited.Invalidate()
    end
    reserveStatus = function()
        local pool = loadPool()
        local primary, backup = 0, 0
        for _, row in ipairs(pool or {}) do
            if row.playing == 1 then primary += 1 elseif row.playing == 2 then backup += 1 end
        end
        return {count = pool and #pool or 0, occupancy = pool and pool[1].playing or nil,
            primary = primary, backup = backup, capacity = connectionConfig.transport == "DeviceCookie" and BALANCED_RESERVE_SIZE or POOL_SIZE}
    end
    hopperEnvironment.ChilliEggSearch.RefreshServers = function()
        assert(session.alive, "Esta sesion ya termino")
        local pool, reason = pickCandidates()
        if pool and session.alive then savePool(pool) end
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
            local pool = loadPool()
            local pickError = nil
            if not pool or #pool == 0 then
                pool, pickError = pickCandidates(function() return canContinueHop(automatic, generation) end)
                if not canContinueHop(automatic, generation) then return false end
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

                    if not canContinueHop(automatic, generation) then
                        if session.hopWorker == owner then setBusy(false) end
                        return false
                    end
                    if automatic and not verifyMapBeforeHop(pool[index]) then return false end
                    local candidate = pool[index]
                    setLabel("Saltando...")
                    setStatus(serverOrder == "BestLatency"
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

    -- La tarjeta flotante y la seccion Server Hop del hub lanzan el mismo salto.
    local function startManualHop()
        if busy then
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
    end
    connect(button.MouseButton1Click, function()
        if draggedRecently() then return end
        startManualHop()
    end)
    connect(hopView.button.Activated, startManualHop)

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
            local failedTarget = support.FailedTarget(state, game.JobId)
            if failedTarget then markVisited(failedTarget) end
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

    -- Pool precargado: se refresca solo en segundo plano para que al pulsar el
    -- boton no haya que consultar nada; despues va cada POOL_REFRESH_SECONDS. No
    -- refresca mientras hay un salto en curso.
    task.spawn(function()
        while session.alive and game.JobId == sessionStartJobId do
            if game.PlaceId == PLACE_ID and not busy then
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
                        return session.alive and not busy and game.JobId == sessionStartJobId
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
