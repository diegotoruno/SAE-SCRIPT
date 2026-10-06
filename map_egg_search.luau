-- Detector de spawns del mapa para Chilli + Server Hop.
-- Solo lee EggState.ReadFieldEggs: no inspecciona huevos de bases.
local function createMapEggSearch(readJson, writeJson)
    local CONFIG_FILE = "chilli_egg_search_config.json"
    local search = { ready = false, error = nil, lastScan = nil, fieldRevision = 0 }
    local connections = {}
    function search.Dispose()
        search.disposed = true
        for _, connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections)
    end
    local function normalize(config)
        assert(type(config) == "table", "Los filtros deben ser una tabla")
        local minimum = config.minIncome == nil and 7000000000 or tonumber(config.minIncome)
        assert(type(minimum) == "number" and minimum == minimum and minimum > 0 and minimum < math.huge,
            "minIncome debe ser un numero positivo y finito")
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

    function search.Configure(patch)
        local nextConfig = table.clone(search.config)
        for key, value in pairs(patch) do
            assert(nextConfig[key] ~= nil, "Filtro desconocido: " .. tostring(key))
            nextConfig[key] = value
        end
        nextConfig = normalize(nextConfig)
        assert(writeJson(CONFIG_FILE, nextConfig), "No se pudieron guardar los filtros")
        search.config = nextConfig
        return table.clone(nextConfig)
    end

    function search.Summary()
        return string.format("%s >= %.2fB/s", search.config.rarity,
            search.config.minIncome / 1000000000)
    end

    -- Funcion pura: tambien permite verificar los filtros sin teleports.
    function search.Evaluate(records, directory, incomeFor, filters)
        filters = normalize(filters or search.config)
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
                local tier = type(rarity) == "table" and rarity._id or rarity
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
                records = module(util, "EggRecords"), earnings = module(util, "AssetEarnings"),
                cycle = module(util, "AreaEggCycle"),
            }
        end)
        if search.disposed then return end
        if loaded then
            search.modules = modules
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
        else search.error = tostring(modules) end
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

    function search.Scan()
        if search.error then return nil, { ready = false, reason = search.error } end
        local modules = search.modules
        if not modules then return nil, { ready = false, reason = "cargando datos del mapa" } end
        local scanOk, match, info, all = pcall(function()
            if search.resetting or modules.cycle.IsNightPhase(workspace:GetServerTimeNow()) then
                return nil, { ready = false, reason = "renovando huevos; esperando snapshot nuevo" }
            end
            if not modules.eggs.HasFieldSnapshot() then
                return nil, { ready = false, reason = "esperando spawns del mapa" }
            end
            local snapshot = modules.eggs.ReadFieldEggs()
            assert(type(snapshot) == "table" and type(snapshot.Records) == "table",
                "Snapshot del mapa incompatible")
            local best, details, matches = search.Evaluate(snapshot.Records, modules.assets.Directory,
                function(egg)
                    local item = modules.records.ToAssetItemData(egg)
                    -- Generacion del egg al eclosionar: tamaño + mutaciones.
                    -- No incluye boosts temporales ni bonus del dueño anterior.
                    return modules.earnings.MutationOnlyRatePerSecond(item)
                end)
            details.ready = details.errors == 0
            if not details.ready then details.reason = "no se pudo verificar el ingreso de todos los eggs" end
            return best, details, matches
        end)
        if not scanOk then
            return nil, { ready = false, reason = tostring(match) }
        end
        search.ready = info.ready
        search.lastScan = { match = match, info = info, matches = all }
        return match, info, all
    end
    return search
end

return createMapEggSearch
