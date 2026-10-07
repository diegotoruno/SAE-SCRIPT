-- Detector de spawns del mapa para Chilli + Server Hop.
-- Solo lee EggState.ReadFieldEggs: no inspecciona huevos de bases.
local function createMapEggSearch(readJson, writeJson)
    local CONFIG_FILE = "chilli_egg_search_config.json"
    local search = { ready = false, error = nil, lastScan = nil, fieldRevision = 0,
        stats = { scans = 0, analyses = 0, incomeReads = 0, cacheHits = 0, lastMs = 0 } }
    local incomeCache = {}
    local analysisKey, analysisResult
    local connections = {}
    function search.Dispose()
        search.disposed = true
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
        local categories, seen = {}, {}
        assert(config.categories == nil or type(config.categories) == "table", "categories debe ser una lista")
        for _, category in ipairs(config.categories or {}) do
            assert(type(category) == "string" and category ~= "", "Especie no valida")
            if not seen[category] then table.insert(categories, category); seen[category] = true end
        end
        table.sort(categories)
        return { rarity = rarity, minIncome = minimum,
            nameContains = name, mutation = mutation, categories = categories }
    end
    local ok, config = pcall(normalize, readJson(CONFIG_FILE, {}))
    search.config = ok and config or normalize({})

    function search.Validate(config)
        assert(search.modules, "Espera a que cargue el catálogo del juego")
        local result = normalize(config)
        result.rarity = canonicalRarity(result.rarity, search.RarityOptions())
        for _, id in ipairs(result.categories) do assert(search.modules.assets.Directory[id], "Especie desconocida: " .. id) end
        return result
    end

    function search.Configure(patch)
        assert(search.modules, "Espera a que cargue el catalogo del juego para aplicar filtros")
        local nextConfig = table.clone(search.config)
        for key, value in pairs(patch) do
            assert(nextConfig[key] ~= nil, "Filtro desconocido: " .. tostring(key))
            nextConfig[key] = value
        end
        nextConfig = normalize(nextConfig)
        nextConfig.rarity = canonicalRarity(nextConfig.rarity, search.RarityOptions())
        assert(writeJson(CONFIG_FILE, nextConfig), "No se pudieron guardar los filtros")
        search.config = nextConfig
        search.lastScan = nil
        local copy = table.clone(nextConfig); copy.categories = table.clone(nextConfig.categories); return copy
    end

    function search.Summary()
        return string.format("%s >= %s/s", search.config.rarity, search.FormatMinimum(search.config.minIncome))
    end

    function search.Explain(egg, catalog, income, filters)
        filters = filters or search.config
        if not catalog then return "Datos de especie no disponibles" end
        if string.lower(tostring(rarityId(catalog.Rarity))) ~= string.lower(filters.rarity) then return "Rareza distinta" end
        if #filters.categories > 0 and not table.find(filters.categories, egg.AssetCategory) then return "Especie excluida" end
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

    -- Funcion pura: tambien permite verificar los filtros sin teleports.
    function search.Evaluate(records, directory, incomeFor, filters)
        filters = normalize(filters or search.config)
        local available = {}
        for _, catalog in pairs(directory) do
            local id = rarityId(catalog.Rarity)
            if type(id) == "string" then table.insert(available, {id = id}) end
        end
        filters.rarity = canonicalRarity(filters.rarity, available)
        local found = {}
        local info = { count = 0, rarityCount = 0, eligible = 0, errors = 0 }
        local categorySet = {}
        for _, category in ipairs(filters.categories) do categorySet[category] = true end
        for _, egg in pairs(records) do
            -- Slot es un spawn disponible. Carried, GuardCarried, Dropped y
            -- Claimed no son huevos que hayan aparecido libres en el nido.
            if egg.State == "Slot" then
                info.count += 1
                local catalog = directory[egg.AssetCategory]
                local rarity = catalog and catalog.Rarity
                local tier = rarityId(rarity)
                if not catalog or type(tier) ~= "string" then
                    info.errors += 1
                elseif string.lower(tier) == string.lower(filters.rarity) then
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
                    local categoryOk = #filters.categories == 0 or categorySet[egg.AssetCategory]
                    if nameOk and mutationOk and categoryOk then
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
    function search.Decide(match, info)
        if match then return "match" end
        if not info.ready then return "loading" end
        return (info.rarityCount or 0) > 0 and "hop" or "wait"
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
                    assets = module(data, "Assets"), eggs = module(client, "EggState"),
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
                fieldRevision = search.fieldRevision,
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
            if search.resetting or modules.cycle.IsNightPhase(workspace:GetServerTimeNow()) then
                table.clear(incomeCache)
                analysisKey, analysisResult = nil, nil
                return nil, {ready = false, reason = "renovando huevos; esperando snapshot nuevo"}
            end
            if not modules.eggs.HasFieldSnapshot() then
                table.clear(incomeCache)
                analysisKey, analysisResult = nil, nil
                return nil, {ready = false, reason = "esperando spawns del mapa"}
            end
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
            for key, egg in pairs(snapshot.Records) do
                if egg.State == "Slot" then
                    local id = tostring(egg.Uid or key)
                    active[id] = true
                    local catalog = modules.assets.Directory[egg.AssetCategory]
                    local signature = search.RecordKey(egg) .. tostring(catalog)
                        .. tostring(catalog and catalog.EarningRate) .. tostring(catalog and rarityId(catalog.Rarity))
                    local cached = incomeCache[id]
                    if not cached or cached.key ~= signature or cached.modules ~= modules then
                        cached = {key = signature, modules = modules}
                        incomeCache[id] = cached
                    end
                    cachedByEgg[egg] = cached
                    if includeMapIncome then incomeFor(egg) end
                    table.insert(inputKeys, id .. ":" .. signature)
                    table.insert(mapRows, {uid = id, egg = egg, catalog = catalog,
                        income = cached.income, key = signature})
                end
            end
            for id in pairs(incomeCache) do if not active[id] then incomeCache[id] = nil end end
            table.sort(inputKeys)
            local key = tostring(modules) .. tostring(search.fieldRevision) .. search.RecordKey(search.config) .. table.concat(inputKeys, "|")
            local best, details, matches
            if not fresh and key == analysisKey and analysisResult and analysisResult.info.ready then
                best, details, matches = analysisResult.match, analysisResult.info, analysisResult.matches
            else
                search.stats.analyses += 1
                best, details, matches = search.Evaluate(snapshot.Records, modules.assets.Directory, incomeFor)
                details.ready = details.errors == 0
                analysisKey, analysisResult = key, {match = best, info = details, matches = matches}
            end
            local matching = {}; for _, candidate in ipairs(matches) do matching[tostring(candidate.uid)] = true end
            for _, row in ipairs(mapRows) do
                row.income = cachedByEgg[row.egg].income
                row.match = matching[row.uid] == true
                row.reason = search.Explain(row.egg, row.catalog, row.income)
            end
            if not details.ready then details.reason = "datos de especie o ingreso no disponibles; esperando recuperación" end
            return best, details, matches, mapRows
        end)
        if not scanOk then return publish(nil, {ready = false, reason = tostring(match)}) end
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
