-- Detector de spawns del mapa para Chilli + Server Hop.
-- Solo lee EggState.ReadFieldEggs: no inspecciona huevos de bases.
local function createMapEggSearch(readJson, writeJson)
    local CONFIG_FILE = "chilli_egg_search_config.json"
    local CYCLE_FILE = "chilli_egg_search_cycle.json"
    local search = { ready = false, error = nil, lastScan = nil, fieldRevision = 0,
        stats = { scans = 0, analyses = 0, incomeReads = 0, cacheHits = 0, lastMs = 0 } }
    -- HasFieldSnapshot can become true before the initial replication finishes.
    -- Wait from the first usable read, then require unchanged Slot inputs in
    -- separate polls. This gate belongs to this session/cycle, never to disk.
    local LOAD_SECONDS, QUIET_SECONDS = 10, 3
    local snapshotLoad
    local function copyInputs(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for key, item in pairs(value) do copy[key] = copyInputs(item) end
        return copy
    end
    local function sameInputs(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for key, value in pairs(a) do if not sameInputs(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end
    local function clearSnapshotLoad()
        snapshotLoad = nil
    end
    local function snapshotReady(records, directory, cycle)
        if not game:IsLoaded() then clearSnapshotLoad(); return false end
        local now = os.clock()
        local stamp = {period = cycle and cycle.periodIndex,
            reset = cycle and cycle.nextReset, seconds = cycle and cycle.periodSeconds,
            night = cycle and cycle.nightSeconds}
        if snapshotLoad and (snapshotLoad.modules ~= search.modules
            or not sameInputs(snapshotLoad.stamp, stamp)) then clearSnapshotLoad() end
        if snapshotLoad and snapshotLoad.ready then return true end
        local inputs = {}
        for key, egg in pairs(records) do
            if egg.State == "Slot" then
                local catalog = directory[egg.AssetCategory]
                inputs[key] = {egg = copyInputs(egg), rarity = copyInputs(catalog and catalog.Rarity),
                    rate = catalog and catalog.EarningRate, name = catalog and catalog.DisplayName}
            end
        end
        if not snapshotLoad then
            snapshotLoad = {modules = search.modules, stamp = stamp, firstAt = now, stableAt = now,
                revision = search.fieldRevision, inputs = inputs}
        elseif snapshotLoad.revision ~= search.fieldRevision or not sameInputs(snapshotLoad.inputs, inputs) then
            snapshotLoad.stableAt, snapshotLoad.revision, snapshotLoad.inputs = now, search.fieldRevision, inputs
        end
        snapshotLoad.ready = now - snapshotLoad.firstAt >= LOAD_SECONDS
            and now - snapshotLoad.stableAt >= QUIET_SECONDS
        return snapshotLoad.ready
    end
    local remembered = readJson(CYCLE_FILE, {})
    if type(remembered) ~= "table" then remembered = {} end
    local function finite(value)
        return type(value) == "number" and value == value and math.abs(value) < math.huge
    end
    local function clockKnown(cycle)
        return type(cycle) == "table" and type(cycle.night) == "boolean"
            and finite(cycle.serverTime) and finite(cycle.periodIndex)
            and finite(cycle.nextReset) and finite(cycle.periodSeconds) and cycle.periodSeconds > 0
            and finite(cycle.nightSeconds) and cycle.nightSeconds >= 0
            and cycle.nightSeconds < cycle.periodSeconds
    end
    local function cycleReady(cycle)
        return clockKnown(cycle) and cycle.running == true and cycle.night == false
            and cycle.serverTime >= cycle.nextReset - cycle.periodSeconds
            and cycle.serverTime < cycle.nextReset - cycle.nightSeconds
    end
    local function validWindow(cycle)
        return cycleReady(cycle) and remembered.version == 1
            and remembered.rarity == string.lower(search.config.rarity)
            and remembered.periodIndex == cycle.periodIndex and remembered.nextReset == cycle.nextReset
            and remembered.periodSeconds == cycle.periodSeconds and remembered.nightSeconds == cycle.nightSeconds
            and finite(remembered.seenAt) and remembered.seenAt <= cycle.serverTime
            and remembered.seenAt >= cycle.nextReset - cycle.periodSeconds
            and remembered.untilTime == cycle.nextReset - cycle.nightSeconds
    end
    local function saveWindow(value)
        local ok, saved = pcall(writeJson, CYCLE_FILE, value)
        if ok and saved then remembered = value; return true end
        return false
    end
    function search.SearchWindow()
        return table.clone(remembered)
    end

    local incomeCache = {}
    local analysisKey, analysisResult
    local rowRevision = 0
    local connections = {}
    function search.Dispose()
        search.disposed = true
        clearSnapshotLoad()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end
    local units = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, q = 1e15 }
    function search.ParseMinimum(value)
        local minimum = value
        if type(value) == "string" then
            local input = string.lower(value):match("^%s*(.-)%s*$"):gsub(",", ".")
            local amount, suffix = input:match("^(.-)%s*([kmbtq])$")
            amount = amount or input
            -- Validate before calling the game's permissive parser: punctuation
            -- must not silently turn an invalid threshold into another number.
            local mantissa, exponent = amount:match("^(.-)[eE]([%+%-]?%d+)$")
            mantissa = mantissa or amount
            if not (mantissa:match("^%+?%d+%.?%d*$") or mantissa:match("^%+?%.%d+$")) then return nil end
            local normalized = mantissa .. (exponent and "e" .. exponent or "") .. (suffix or "")
            if search.modules and search.modules.numbers then
                local ok, result = pcall(search.modules.numbers.Parse, normalized)
                minimum = ok and result or nil
            else
                -- Offline equivalent for saved config and pure CI regressions.
                minimum = tonumber(amount)
                if minimum and suffix then minimum *= units[suffix] end
            end
        end
        if type(minimum) ~= "number" or minimum ~= minimum or minimum <= 0 or minimum >= math.huge then return nil end
        return minimum
    end
    function search.FormatMinimum(value)
        -- Only abbreviate when parsing the text restores the exact threshold.
        for _, suffix in ipairs({ "q", "t", "b", "m", "k" }) do
            if value >= units[suffix] then
                for precision = 1, 17 do
                    local text = string.format("%." .. precision .. "g", value / units[suffix]) .. suffix
                    if search.ParseMinimum(text) == value then return text end
                end
            end
        end
        return string.format("%.17g", value)
    end
    local function rarityId(rarity)
        return type(rarity) == "table" and rarity._id or rarity
    end
    local function rarityRanks(directory, rarities)
        local ranks = {}
        if rarities then
            for id, rarity in pairs(rarities) do
                if type(id) == "string" and type(rarity) == "table" and finite(rarity.Rank) then
                    ranks[string.lower(id)] = rarity.Rank
                end
            end
        else
            for _, catalog in pairs(directory) do
                local rarity = catalog.Rarity
                if type(rarity) == "table" and type(rarity._id) == "string" and finite(rarity.Rank) then
                    ranks[string.lower(rarity._id)] = rarity.Rank
                end
            end
        end
        return ranks
    end
    local function matchesRarity(rarity, minimum, ranks)
        local id = rarityId(rarity)
        if type(id) ~= "string" then return nil end
        id, minimum = string.lower(id), string.lower(minimum)
        if id == minimum then return true end
        if ranks[id] == nil or ranks[minimum] == nil then return nil end
        return ranks[id] >= ranks[minimum]
    end
    function search.RarityMatches(rarity, minimum, rarities)
        rarities = rarities or (search.modules and search.modules.rarities.Rarities)
        return matchesRarity(rarity, minimum, rarityRanks({}, rarities))
    end
    function search.RarityOptions(directory, rarities)
        if directory == nil then
            local modules = search.modules
            if not modules then return {} end
            directory, rarities = modules.assets.Directory, modules.rarities.Rarities
        end
        local options, seen = {}, {}
        for _, catalog in pairs(directory) do
            local id = rarityId(catalog.Rarity)
            local rarity = rarities[id]
            if type(id) == "string" and type(rarity) == "table"
                and type(rarity.Rank) == "number" and not seen[id] then
                seen[id] = true
                table.insert(options, { id = id, label = rarity.DisplayName or id, rank = rarity.Rank })
            end
        end
        table.sort(options, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.id < b.id
        end)
        return options
    end
    local function canonicalRarity(value, options)
        for _, option in ipairs(options) do
            if string.lower(option.id) == string.lower(value) then return option.id end
        end
        error("Rareza no disponible en el catalogo del juego: " .. value)
    end
    local function normalize(config)
        assert(type(config) == "table", "Los filtros deben ser una tabla")
        local minimum = search.ParseMinimum(config.minIncome == nil and 7000000000 or config.minIncome)
        assert(type(minimum) == "number" and minimum == minimum and minimum > 0 and minimum < math.huge,
            "Minimo invalido: usa 500k, 25m, 7b, 1t, 1q o un numero positivo")
        local rarity = config.rarity or "Divine"
        assert(type(rarity) == "string" and rarity ~= "", "rarity debe ser texto")
        local name = config.nameContains or ""
        local mutation = config.mutation or ""
        assert(type(name) == "string" and type(mutation) == "string",
            "nameContains y mutation deben ser texto")
        -- Retired categories from older saved configs/presets are ignored.
        local zones, seen = {}, {}
        assert(config.zones == nil or type(config.zones) == "table", "zones debe ser una lista")
        local zoneCount = 0
        for key in pairs(config.zones or {}) do
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #config.zones,
                "zones debe ser una lista continua")
            zoneCount += 1
        end
        assert(zoneCount == #(config.zones or {}), "zones debe ser una lista continua")
        for _, id in ipairs(config.zones or {}) do
            assert(type(id) == "string" and id ~= "", "Zona no valida")
            if not seen[id] then table.insert(zones, id); seen[id] = true end
        end
        table.sort(zones)
        return { rarity = rarity, minIncome = minimum,
            nameContains = name, mutation = mutation, zones = zones }
    end
    -- The whole official catalog is offered, regardless of local egg spawns.
    function search.ZoneOptions(areas)
        areas = areas or (search.modules and search.modules.areas)
        if not areas or type(areas.Directory) ~= "table" then return {} end
        local options = {}
        for id, area in pairs(areas.Directory) do
            if type(id) == "string" and type(area) == "table" then
                local rank = area.ProgressionOrder
                if type(areas.GetProgressionOrder) == "function" then
                    local ok, value = pcall(areas.GetProgressionOrder, area)
                    if ok and finite(value) then rank = value end
                end
                table.insert(options, {id = id, label = area.DisplayName or id,
                    rank = finite(rank) and rank or math.huge, icon = area.Icon})
            end
        end
        table.sort(options, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.id < b.id
        end)
        return options
    end
    local function validateZones(config)
        if #config.zones == 0 then return end
        local areas = search.modules and search.modules.areas
        assert(areas and type(areas.Directory) == "table", "Espera a que carguen las zonas del juego")
        for _, id in ipairs(config.zones) do
            assert(areas.Directory[id], "Zona desconocida: " .. id)
        end
    end

    local ok, config = pcall(normalize, readJson(CONFIG_FILE, {}))
    search.config = ok and config or normalize({})

    function search.Validate(config)
        assert(search.modules, "Espera a que cargue el catálogo del juego")
        local result = normalize(config)
        result.rarity = canonicalRarity(result.rarity, search.RarityOptions())
        validateZones(result)
        return result
    end

    function search.Configure(patch)
        assert(not search.disposed, "Esta sesión ya terminó")
        assert(search.modules, "Espera a que cargue el catalogo del juego para aplicar filtros")
        local nextConfig = table.clone(search.config)
        for key, value in pairs(patch) do
            assert(nextConfig[key] ~= nil, "Filtro desconocido: " .. tostring(key))
            nextConfig[key] = value
        end
        nextConfig = normalize(nextConfig)
        nextConfig.rarity = canonicalRarity(nextConfig.rarity, search.RarityOptions())
        validateZones(nextConfig)
        assert(writeJson(CONFIG_FILE, nextConfig), "No se pudieron guardar los filtros")
        search.config = nextConfig
        search.lastScan = nil
        local copy = table.clone(nextConfig); copy.zones = table.clone(nextConfig.zones); return copy
    end

    function search.Summary()
        return string.format("%s+ >= %s/s", search.config.rarity, search.FormatMinimum(search.config.minIncome))
    end

    function search.Explain(egg, catalog, income, filters)
        filters = filters or search.config
        if not catalog then return "Datos de especie no disponibles" end
        local rarityOk = search.RarityMatches(catalog.Rarity, filters.rarity)
        if rarityOk == nil then return "Datos de rareza no disponibles" end
        if not rarityOk then return "Rareza inferior al mínimo" end
        if #(filters.zones or {}) > 0 then
            if type(egg.AreaId) ~= "string" or egg.AreaId == "" then return "Zona no disponible" end
            if not table.find(filters.zones, egg.AreaId) then return "Zona excluida" end
        end
        local name = string.lower(catalog.DisplayName or egg.AssetCategory)
        local needle = string.lower(filters.nameContains)
        if needle ~= "" and not string.find(name, needle, 1, true)
            and not string.find(string.lower(egg.AssetCategory), needle, 1, true) then return "Nombre distinto" end
        if filters.mutation ~= "" then
            local found = string.lower(tostring(egg.BaseMutation)) == string.lower(filters.mutation)
            for _, id in ipairs(egg.Mutations or {}) do if string.lower(id) == string.lower(filters.mutation) then found = true end end
            if not found then return "Falta la mutación elegida" end
        end
        if type(income) ~= "number" or income ~= income or income < 0 or income == math.huge then return "Ingreso no disponible" end
        if income < filters.minIncome then return "Ingreso inferior al mínimo" end
        return "Cumple todos los filtros"
    end

    -- Stable signature includes every replicated input, including base mutation,
    -- bounds and area. It also detects changes not covered by FieldRefreshed.
    function search.RecordKey(value)
        if type(value) ~= "table" then return typeof and typeof(value) .. ":" .. tostring(value) or type(value) .. ":" .. tostring(value) end
        local keys = {}; for key in pairs(value) do table.insert(keys, key) end
        table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
        local parts = {}; for _, key in ipairs(keys) do table.insert(parts, tostring(key) .. "=" .. search.RecordKey(value[key])) end
        return "{" .. table.concat(parts, "|") .. "}"
    end
    function search.CopyRecord(value)
        if type(value) ~= "table" then return value end
        local result = {}; for key, item in pairs(value) do result[key] = search.CopyRecord(item) end
        return result
    end
    function search.SameRecord(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for key, value in pairs(a) do if not search.SameRecord(value, b[key]) then return false end end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end

    -- Funcion pura: tambien permite verificar los filtros sin teleports.
    function search.Evaluate(records, directory, incomeFor, filters, rarities)
        filters = normalize(filters or search.config)
        rarities = rarities or (search.modules and search.modules.rarities.Rarities)
        local ranks = rarityRanks(directory, rarities)
        local available = {}
        for _, catalog in pairs(directory) do
            local id = rarityId(catalog.Rarity)
            if type(id) == "string" then table.insert(available, {id = id}) end
        end
        filters.rarity = canonicalRarity(filters.rarity, available)
        local found = {}
        local info = { count = 0, rarityCount = 0, eligible = 0, errors = 0 }
        local zoneSet = {}
        for _, id in ipairs(filters.zones) do zoneSet[id] = true end
        for _, egg in pairs(records) do
            -- Slot es un spawn disponible. Carried, GuardCarried, Dropped y
            -- Claimed no son huevos que hayan aparecido libres en el nido.
            if egg.State == "Slot" then
                info.count += 1
                local catalog = directory[egg.AssetCategory]
                local rarity = catalog and catalog.Rarity
                local tier = rarityId(rarity)
                local rarityOk = matchesRarity(rarity, filters.rarity, ranks)
                if not catalog or rarityOk == nil then
                    info.errors += 1
                elseif rarityOk then
                    info.rarityCount += 1
                    local name = catalog.DisplayName or egg.AssetCategory
                    local nameOk = filters.nameContains == ""
                        or string.find(string.lower(name), string.lower(filters.nameContains), 1, true)
                        or string.find(string.lower(egg.AssetCategory), string.lower(filters.nameContains), 1, true)
                    local mutationOk = filters.mutation == ""
                    for _, mutation in ipairs(egg.Mutations or {}) do
                        if string.lower(mutation) == string.lower(filters.mutation) then
                            mutationOk = true
                        end
                    end
                    if egg.BaseMutation and string.lower(egg.BaseMutation) == string.lower(filters.mutation) then
                        mutationOk = true
                    end
                    local zoneKnown = type(egg.AreaId) == "string" and egg.AreaId ~= ""
                    local zoneOk = #filters.zones == 0 or (zoneKnown and zoneSet[egg.AreaId])
                    if #filters.zones > 0 and not zoneKnown then info.errors += 1 end
                    if nameOk and mutationOk and zoneOk then
                        info.eligible += 1
                        local incomeOk, income = pcall(incomeFor, egg)
                        if not incomeOk or type(income) ~= "number"
                            or income ~= income or income < 0 or income == math.huge then
                            info.errors += 1
                        elseif income >= filters.minIncome then
                            local position = egg.BoundsCFrame and egg.BoundsCFrame.Position
                            table.insert(found, {
                                uid = egg.Uid, category = egg.AssetCategory,
                                name = name, rarity = tier, income = income,
                                area = egg.AreaId, nest = egg.NestId, scale = egg.AssetScale,
                                mutations = table.clone(egg.Mutations or {}),
                                position = position and { x = position.X, y = position.Y, z = position.Z } or nil,
                            })
                        end
                    end
                end
            end
        end
        table.sort(found, function(a, b)
            if a.income ~= b.income then return a.income > b.income end
            return tostring(a.uid) < tostring(b.uid)
        end)
        return found[1], info, found
    end

    -- La misma decision se usa al entrar, despues de un reset y antes de saltar.
    function search.Decide(match, info, cycle)
        if search.disposed then info.reason = "sesión terminada"; return "loading" end
        cycle = cycle == nil and search.CycleStatus() or cycle
        -- Pure Evaluate callers without modules retain the local decision.
        -- Runtime passes false when its clock is unavailable and must wait.
        if cycle == nil and remembered.version == nil then
            if not info.ready then return "loading" end
            if match then return "match" end
            return (info.rarityCount or 0) > 0 and "hop" or "wait"
        end
        local valid = validWindow(cycle)
        if not valid and next(remembered) ~= nil then
            -- No clock means we cannot validate or expire the saved cycle yet.
            if not clockKnown(cycle) or cycle.running ~= true then return "loading" end
            if not saveWindow({}) then info.reason = "no se pudo cerrar la búsqueda del ciclo anterior"; return "loading" end
        end
        if not cycleReady(cycle) or not info.ready then return "loading" end
        if info.cycle and (not clockKnown(info.cycle) or info.cycle.periodIndex ~= cycle.periodIndex
            or info.cycle.nextReset ~= cycle.nextReset or info.cycle.nightSeconds ~= cycle.nightSeconds
            or info.cycle.periodSeconds ~= cycle.periodSeconds or info.cycle.night) then
            info.reason = "el snapshot pertenece al ciclo anterior; esperando lectura nueva"
            return "loading"
        end
        if match then return "match" end
        if (info.rarityCount or 0) > 0 and not valid then
            local window = {version = 1, rarity = string.lower(search.config.rarity), periodIndex = cycle.periodIndex,
                nextReset = cycle.nextReset, periodSeconds = cycle.periodSeconds, nightSeconds = cycle.nightSeconds,
                untilTime = cycle.nextReset - cycle.nightSeconds, seenAt = cycle.serverTime}
            if not saveWindow(window) then info.reason = "no se pudo guardar la búsqueda para continuar al reconectar"; return "loading" end
            valid = true
        end
        info.continuingCycle = valid and (info.rarityCount or 0) == 0
        info.searchUntil = valid and remembered.untilTime or nil
        return valid and "hop" or "wait"
    end

    -- Datos y reloj replicados por el juego; no se modifica el ciclo.
    task.spawn(function()
        local retryDelay = 2
        while not search.disposed and not search.modules do
            local loaded, modules = pcall(function()
                local replicated = game:GetService("ReplicatedStorage")
                local data = replicated:WaitForChild("Data", 30)
                local client = replicated:WaitForChild("Client", 30)
                local shared = replicated:WaitForChild("Shared", 30)
                assert(data and client and shared, "Faltan los modulos del juego")
                local util = shared:WaitForChild("Util", 30)
                assert(util, "No llego Shared.Util")
                local function module(parent, name)
                    local source = parent:WaitForChild(name, 30)
                    assert(source, "No llego " .. name)
                    return require(source)
                end
                return {
                    areas = module(data, "Areas"), assets = module(data, "Assets"), eggs = module(client, "EggState"),
                    rarities = module(data, "Rarity"), numbers = module(shared:WaitForChild("Utils", 30), "Numbers"),
                    records = module(util, "EggRecords"), earnings = module(util, "AssetEarnings"),
                    cycle = module(util, "AreaEggCycle"),
                }
            end)
            if search.disposed then return end
            if loaded then
                search.modules = modules
                search.error = nil
                -- Validate persisted IDs after the real catalog arrives. An obsolete
                -- selection waits for correction instead of making hop decisions.
                table.insert(connections, modules.eggs.FieldRefreshed:Connect(function()
                    search.fieldRevision += 1
                    if not modules.cycle.IsNightPhase(workspace:GetServerTimeNow()) then
                        search.resetting = false
                    end
                end))
                table.insert(connections, modules.eggs.ResetCountdown:Connect(function()
                    search.resetting = true
                    clearSnapshotLoad()
                end))
                table.insert(connections, modules.eggs.RarityRevealed:Connect(function()
                    search.resetting = false
                end))
            else
                search.error = tostring(modules)
                task.wait(retryDelay); retryDelay = math.min(15, retryDelay * 2)
            end
        end
    end)

    function search.CycleStatus()
        if not search.modules then return nil end
        local ok, status = pcall(function()
            local cycle = search.modules.cycle
            local now = workspace:GetServerTimeNow()
            return {
                running = cycle.IsRunning(), night = cycle.IsNightPhase(now),
                periodSeconds = cycle.ResetPeriodSeconds,
                nightSeconds = cycle.NightLengthSeconds(),
                periodIndex = cycle.PeriodIndexAt(now), nextReset = cycle.NextResetTime(now),
                secondsUntilReset = cycle.SecondsUntilReset(now),
                secondsUntilPhaseEnd = cycle.SecondsUntilPhaseEnd(now),
                fieldRevision = search.fieldRevision, serverTime = now,
            }
        end)
        return ok and status or nil
    end

    function search.Scan(fresh, includeMapIncome)
        local started = os.clock()
        search.stats.scans += 1
        local function publish(match, info, all, rows)
            search.ready = info.ready
            search.lastScan = { match = match, info = info, matches = all or {}, rows = rows or {},
                revision = search.fieldRevision, at = os.clock() }
            search.stats.lastMs = (os.clock() - started) * 1000
            return match, info, all, rows
        end
        if search.disposed then return publish(nil, {ready = false, reason = "sesión terminada"}) end
        if search.error then return publish(nil, {ready = false, reason = search.error}) end
        local modules = search.modules
        if not modules then return publish(nil, {ready = false, reason = "cargando datos del mapa"}) end
        local scanOk, match, info, all, rows = pcall(function()
            if not game:IsLoaded() then
                clearSnapshotLoad()
                return nil, {ready = false, reason = "esperando carga del juego"}
            end
            if search.resetting or modules.cycle.IsNightPhase(workspace:GetServerTimeNow()) then
                clearSnapshotLoad()
                table.clear(incomeCache)
                analysisKey, analysisResult = nil, nil
                return nil, {ready = false, reason = "renovando huevos; esperando snapshot nuevo"}
            end
            if not modules.eggs.HasFieldSnapshot() then
                clearSnapshotLoad()
                table.clear(incomeCache)
                analysisKey, analysisResult = nil, nil
                return nil, {ready = false, reason = "esperando spawns del mapa"}
            end
            validateZones(search.config)
            local snapshotCycle = search.CycleStatus()
            local snapshot = modules.eggs.ReadFieldEggs()
            assert(type(snapshot) == "table" and type(snapshot.Records) == "table", "Snapshot del mapa incompatible")
            local mapRows, active, cachedByEgg, inputKeys = {}, {}, {}, {}
            local function incomeFor(egg)
                local cached = cachedByEgg[egg]
                if fresh or cached.income == nil then
                    local ok, rate = pcall(function()
                        search.stats.incomeReads += 1
                        return modules.earnings.MutationOnlyRatePerSecond(modules.records.ToAssetItemData(egg))
                    end)
                    local valid = ok and type(rate) == "number" and rate == rate and rate >= 0 and rate < math.huge
                    cached.income = valid and rate or nil
                else search.stats.cacheHits += 1 end
                return cached.income
            end
            local count, unknown = 0, 0
            local ranks = rarityRanks(modules.assets.Directory, modules.rarities.Rarities)
            for key, egg in pairs(snapshot.Records) do
                if egg.State == "Slot" then
                    count += 1
                    local id = tostring(egg.Uid or key)
                    active[id] = true
                    local catalog = modules.assets.Directory[egg.AssetCategory]
                    local tier = catalog and rarityId(catalog.Rarity)
                    local rarityOk = matchesRarity(catalog and catalog.Rarity, search.config.rarity, ranks)
                    if rarityOk == nil then unknown += 1 end
                    local selected = rarityOk == true
                    -- AUTO needs full inputs of the minimum rarity and above. The
                    -- panel requests all rows explicitly; unrelated spawns
                    -- still contribute availability/error counts.
                    if includeMapIncome or selected then
                        local rarity = modules.rarities.Rarities[tier]
                        local catalogState = {rate = catalog and catalog.EarningRate, name = catalog and catalog.DisplayName,
                            icon = catalog and catalog.Icon, eggIcon = catalog and catalog.Egg and catalog.Egg.Icon,
                            tier = tier, rank = rarity and rarity.Rank, color = rarity and rarity.Color}
                        local cached = incomeCache[id]
                        if not cached or cached.modules ~= modules or cached.catalog ~= catalog
                            or not search.SameRecord(cached.record, egg) or not search.SameRecord(cached.catalogState, catalogState) then
                            rowRevision += 1
                            cached = {key = tostring(rowRevision), modules = modules, catalog = catalog,
                                record = search.CopyRecord(egg), catalogState = catalogState}
                            incomeCache[id] = cached
                        end
                        cachedByEgg[egg] = cached
                        if includeMapIncome then incomeFor(egg) end
                        if selected then table.insert(inputKeys, id .. ":" .. cached.key) end
                        table.insert(mapRows, {uid = id, egg = egg, catalog = catalog,
                            income = cached.income, key = cached.key})
                        end
                end
            end
            for id in pairs(incomeCache) do if not active[id] then incomeCache[id] = nil end end
            table.sort(inputKeys)
            local key = tostring(modules) .. tostring(search.fieldRevision) .. search.RecordKey(search.config)
                .. ":cycle:" .. tostring(snapshotCycle and snapshotCycle.periodIndex)
                .. ":" .. tostring(snapshotCycle and snapshotCycle.nextReset)
                .. ":" .. tostring(snapshotCycle and snapshotCycle.periodSeconds)
                .. ":" .. tostring(snapshotCycle and snapshotCycle.nightSeconds)
                .. ":" .. tostring(count) .. ":" .. tostring(unknown) .. "|" .. table.concat(inputKeys, "|")
            local best, details, matches
            if not fresh and key == analysisKey and analysisResult and analysisResult.info.ready then
                best, details, matches = analysisResult.match, analysisResult.info, analysisResult.matches
            else
                search.stats.analyses += 1
                best, details, matches = search.Evaluate(snapshot.Records, modules.assets.Directory, incomeFor,
                    search.config, modules.rarities.Rarities)
                details.ready = details.errors == 0
                analysisKey, analysisResult = key, {match = best, info = details, matches = matches}
            end
            local matching = {}; for _, candidate in ipairs(matches) do matching[tostring(candidate.uid)] = true end
            for _, row in ipairs(mapRows) do
                row.income = cachedByEgg[row.egg].income
                row.match = matching[row.uid] == true
                row.reason = search.Explain(row.egg, row.catalog, row.income)
            end
            if not details.ready then details.reason = "datos de especie, zona o ingreso no disponibles; esperando recuperación" end
            local afterCycle = search.CycleStatus()
            if afterCycle and (not snapshotCycle or snapshotCycle.periodIndex ~= afterCycle.periodIndex
                or snapshotCycle.nextReset ~= afterCycle.nextReset or snapshotCycle.periodSeconds ~= afterCycle.periodSeconds
                or snapshotCycle.nightSeconds ~= afterCycle.nightSeconds or afterCycle.night or search.resetting) then
                analysisKey, analysisResult = nil, nil
                clearSnapshotLoad()
                return nil, {ready = false, reason = "renovación durante el scan; esperando snapshot nuevo"}
            end
            details = table.clone(details)
            details.cycle = snapshotCycle
            if not details.ready then
                clearSnapshotLoad()
            elseif not snapshotReady(snapshot.Records, modules.assets.Directory, snapshotCycle) then
                details.ready = false
                details.reason = "cargando huevos del servidor; esperando datos estables (mínimo 10 s)"
                return nil, details, {}, mapRows
            end
            return best, details, matches, mapRows
        end)
        if not scanOk then clearSnapshotLoad(); return publish(nil, {ready = false, reason = tostring(match)}) end
        local result, details, matches, mapRows = publish(match, info, all, rows)
        search.lastScan.mapIncome = includeMapIncome == true
        return result, details, matches, mapRows
    end
    function search.MapSnapshot()
        local cycle = search.CycleStatus()
        if search.lastScan and os.clock() - search.lastScan.at < 0.6
            and search.lastScan.revision == search.fieldRevision and not search.resetting
            and not (cycle and cycle.night) and search.lastScan.mapIncome then return search.lastScan end
        search.Scan(false, true)
        search.lastScan.mapIncome = true
        return search.lastScan
    end
    return search
end

return createMapEggSearch
