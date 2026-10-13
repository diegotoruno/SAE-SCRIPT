-- Detector de spawns del mapa para Chilli + Server Hop.
-- Solo lee EggState.ReadFieldEggs: no inspecciona huevos de bases.
local function createMapEggSearch(readJson, writeJson)
    local CONFIG_FILE = "chilli_egg_search_config.json"
    local CYCLE_FILE = "chilli_egg_search_cycle.json"
    local BROKEN_FILE = "chilli_egg_search_broken.json"
    -- Roblox caches a module that errored while loading (for example when
    -- another autoexec script requires game modules before replication ends).
    -- The game, Chilli and this detector share that cache, so the server stays
    -- broken. AUTO leaves it, but stops after several broken servers in a row.
    local CACHED_MODULE_ERROR = "Requested module experienced an error while loading"
    local BROKEN_LIMIT, BROKEN_WINDOW_SECONDS = 3, 600
    local search = { ready = false, error = nil, lastScan = nil, fieldRevision = 0,
        stats = { scans = 0, analyses = 0, incomeReads = 0, cacheHits = 0, lastMs = 0 } }
    -- HasFieldSnapshot can become true before the initial replication finishes.
    -- Wait from the first usable read, then require unchanged Slot inputs in
    -- separate polls. This gate belongs to this session/cycle, never to disk.
    -- A snapshot proven complete (every official zone present, no spawn left
    -- from an earlier period) only needs the quiet window.
    local LOAD_SECONDS, QUIET_SECONDS = 10, 3
    local snapshotLoad
    local currentPeriod, currentUids, staleUids = nil, {}, {}
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
    -- Real field: the game delivers it in one batch (join or day start) with
    -- nests in all 13 zones; later claims may remove single records. Any
    -- missing/unknown zone or spawn left from the previous period keeps the
    -- full arrival wait.
    local function snapshotComplete(records, period)
        if period ~= currentPeriod then
            staleUids = period ~= nil and currentPeriod ~= nil and currentUids or {}
            currentPeriod, currentUids = period, {}
        end
        local areas = search.modules and search.modules.areas
        local complete = type(areas) == "table" and type(areas.Directory) == "table" and period ~= nil
        local present = {}
        for _, egg in pairs(records) do
            if egg.Uid ~= nil then
                currentUids[egg.Uid] = true
                if staleUids[egg.Uid] then complete = false end
            end
            local area = egg.AreaId
            if complete and (type(area) ~= "string" or not areas.Directory[area]) then complete = false end
            if complete then present[area] = true end
        end
        if not complete or next(areas.Directory) == nil then return false end
        for id in pairs(areas.Directory) do
            if not present[id] then return false end
        end
        return true
    end
    local function snapshotReady(records, directory, cycle)
        if not game:IsLoaded() then clearSnapshotLoad(); return false end
        local now = os.clock()
        local stamp = {period = cycle and cycle.periodIndex,
            reset = cycle and cycle.nextReset, seconds = cycle and cycle.periodSeconds,
            night = cycle and cycle.nightSeconds}
        if snapshotLoad and (snapshotLoad.modules ~= search.modules
            or not sameInputs(snapshotLoad.stamp, stamp)) then clearSnapshotLoad() end
        -- Runs on every read so mid-period respawns also count as stale later.
        local complete = snapshotComplete(records, stamp.period)
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
        snapshotLoad.ready = (complete or now - snapshotLoad.firstAt >= LOAD_SECONDS)
            and now - snapshotLoad.stableAt >= QUIET_SECONDS
        if snapshotLoad.ready then
            -- Diagnostic only: real settle times and which proof released the gate.
            search.stats.settleSeconds = snapshotLoad.stableAt - snapshotLoad.firstAt
            search.stats.readySeconds = now - snapshotLoad.firstAt
            search.stats.readyBy = complete and "complete" or "timer"
            local areas = search.modules and search.modules.areas
            if type(areas) == "table" and type(areas.Directory) == "table" then
                local present, seen, total = 0, {}, 0
                for _, egg in pairs(records) do
                    if type(egg.AreaId) == "string" and areas.Directory[egg.AreaId] and not seen[egg.AreaId] then
                        seen[egg.AreaId] = true; present += 1
                    end
                end
                for _ in pairs(areas.Directory) do total += 1 end
                search.stats.zonesPresent, search.stats.zonesTotal = present, total
            end
        end
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
    -- Each server anchors the same period a few milliseconds apart
    -- (Workspace.AreaEggCycleAnchorAt), so times saved in the origin server
    -- never equal the destination's exactly. The period index must match.
    local CLOCK_TOLERANCE_SECONDS = 1
    -- After a match AUTO waits for the capture. Real captures took 7 and 43 s
    -- (guard alerts in between); a claimed egg leaves the field in the same
    -- frame its owner's records get it, the grace covers replication order.
    local CAPTURE_TIMEOUT_SECONDS, CAPTURE_GRACE_SECONDS = 90, 3
    search.CAPTURE_TIMEOUT_SECONDS = CAPTURE_TIMEOUT_SECONDS
    local function near(a, b)
        return finite(a) and finite(b) and math.abs(a - b) <= CLOCK_TOLERANCE_SECONDS
    end
    local function validWindow(cycle)
        return cycleReady(cycle) and remembered.version == 2
            and remembered.rarity == string.lower(search.config.rarity)
            and sameInputs(remembered.zones, search.config.zones)
            and remembered.periodIndex == cycle.periodIndex and near(remembered.nextReset, cycle.nextReset)
            and remembered.periodSeconds == cycle.periodSeconds and remembered.nightSeconds == cycle.nightSeconds
            and finite(remembered.seenAt) and remembered.seenAt <= cycle.serverTime + CLOCK_TOLERANCE_SECONDS
            and remembered.seenAt >= cycle.nextReset - cycle.periodSeconds - CLOCK_TOLERANCE_SECONDS
            and near(remembered.untilTime, cycle.nextReset - cycle.nightSeconds)
    end
    local function saveWindow(value)
        local ok, saved = pcall(writeJson, CYCLE_FILE, value)
        if ok and saved then remembered = value; return true end
        return false
    end
    function search.SearchWindow()
        return copyInputs(remembered)
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
        -- Prefer ordinary decimal suffixes, preserving the exact threshold.
        for _, suffix in ipairs({ "q", "t", "b", "m", "k" }) do
            if value >= units[suffix] then
                for precision = 1, 17 do
                    local text = string.format("%." .. precision .. "g", value / units[suffix]) .. suffix
                    if not string.find(text, "[eE]") and search.ParseMinimum(text) == value then return text end
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
        local wanted = string.lower(value)
        for _, option in ipairs(options) do
            if string.lower(option.id) == wanted then return option.id end
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
        -- Evidence belongs to the selected rarity and exact zone set. Clear it
        -- before changing scope, even if the user switches back before a scan.
        if (string.lower(nextConfig.rarity) ~= string.lower(search.config.rarity)
            or not sameInputs(nextConfig.zones, search.config.zones)) and next(remembered) ~= nil then
            assert(saveWindow({}), "No se pudo cerrar la búsqueda de los filtros anteriores")
        end
        assert(writeJson(CONFIG_FILE, nextConfig), "No se pudieron guardar los filtros")
        search.config = nextConfig
        search.lastScan = nil
        local copy = table.clone(nextConfig); copy.zones = table.clone(nextConfig.zones); return copy
    end

    function search.Summary()
        return string.format("%s+ >= %s/s", search.config.rarity, search.FormatMinimum(search.config.minIncome))
    end

    -- Scan passes the rank table built once per snapshot instead of one per row.
    local function explain(egg, catalog, income, filters, ranks)
        if not catalog then return "Datos de especie no disponibles" end
        local rarityOk = matchesRarity(catalog.Rarity, filters.rarity, ranks)
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
    function search.Explain(egg, catalog, income, filters)
        local rarities = search.modules and search.modules.rarities.Rarities
        return explain(egg, catalog, income, filters or search.config, rarityRanks({}, rarities))
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
        for key, value in pairs(a) do
            -- Only nested tables recurse; primitives compare inline (NaN still differs).
            if type(value) == "table" then
                if not search.SameRecord(value, b[key]) then return false end
            elseif value ~= b[key] then return false end
        end
        for key in pairs(b) do if a[key] == nil then return false end end
        return true
    end

    -- Identity that survives a capture: the claimed egg gets a new Uid in its
    -- owner's records but keeps its species and color seed.
    local function eggKey(egg)
        if egg.AssetColorSeed == nil then return "uid:" .. tostring(egg.Uid) end
        return tostring(egg.AssetCategory) .. "#" .. tostring(egg.AssetColorSeed)
    end
    search.EggKey = eggKey
    local function localUserId()
        local ok, id = pcall(function() return game:GetService("Players").LocalPlayer.UserId end)
        return ok and id or nil
    end
    -- Only to follow the target after a match, never as search candidates:
    -- the field state of every record (Carried keeps CarrierUserId) and the
    -- eggs each owner holds. Owners are nil when they cannot be read.
    function search.CaptureInputs(records)
        local me = search.userId or localUserId()
        local field = {}
        for _, egg in pairs(records) do
            field[eggKey(egg)] = {state = egg.State,
                carriedByMe = egg.State == "Carried" and me ~= nil and egg.CarrierUserId == me}
        end
        local eggs = search.modules and search.modules.eggs
        local ok, owned = pcall(function() return eggs.ReadOwnedEggs() end)
        if not ok or type(owned) ~= "table" or me == nil then return field, nil, nil end
        local mine, others = {}, {}
        for _, entry in pairs(owned) do
            if type(entry) == "table" and type(entry.Records) == "table" then
                local set = entry.OwnerUserId == me and mine or others
                for _, egg in pairs(entry.Records) do set[eggKey(egg)] = true end
            end
        end
        return field, mine, others
    end

    -- Funcion pura: tambien permite verificar los filtros sin teleports.
    function search.Evaluate(records, directory, incomeFor, filters, rarities)
        filters = normalize(filters or search.config)
        rarities = rarities or (search.modules and search.modules.rarities.Rarities)
        local ranks = rarityRanks(directory, rarities)
        -- Same validation as canonicalRarity, without listing the whole catalog.
        local wanted, canonical = string.lower(filters.rarity), nil
        for _, catalog in pairs(directory) do
            local id = rarityId(catalog.Rarity)
            if type(id) == "string" and string.lower(id) == wanted then canonical = id; break end
        end
        filters.rarity = canonical or error("Rareza no disponible en el catalogo del juego: " .. filters.rarity)
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
                    -- An excluded-zone egg neither starts nor seeds a hunt.
                    -- Income/name/mutation remain quality filters within scope.
                    if zoneOk then info.rarityCount += 1 end
                    if nameOk and mutationOk and zoneOk then
                        info.eligible += 1
                        local incomeOk, income = pcall(incomeFor, egg)
                        if not incomeOk or type(income) ~= "number"
                            or income ~= income or income < 0 or income == math.huge then
                            info.errors += 1
                        elseif income >= filters.minIncome then
                            local position = egg.BoundsCFrame and egg.BoundsCFrame.Position
                            table.insert(found, {
                                uid = egg.Uid, key = eggKey(egg), category = egg.AssetCategory,
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

    local cachedFailures = 0
    function search.NoteLoadFailure(message)
        if search.broken then return end
        search.error = tostring(message)
        if not string.find(search.error, CACHED_MODULE_ERROR, 1, true) or not game:IsLoaded() then
            cachedFailures = 0; return
        end
        -- Two reads: one failure could still be the first, real load error.
        cachedFailures += 1
        if cachedFailures < 2 then return end
        local saved = readJson(BROKEN_FILE, {})
        if type(saved) ~= "table" then saved = {} end
        local now = os.time()
        local recent = type(saved.count) == "number" and type(saved.at) == "number"
            and now >= saved.at and now - saved.at < BROKEN_WINDOW_SECONDS
        local count = recent and saved.count or 0
        -- Re-executing in the same broken server does not count it twice.
        if saved.job ~= game.JobId or count == 0 then count += 1 end
        pcall(writeJson, BROKEN_FILE, {count = count, at = now, job = game.JobId})
        search.broken = {count = count, job = game.JobId}
        search.error = "el juego no cargó bien en este servidor (módulos del juego con error)"
    end
    function search.NoteLoadSuccess()
        cachedFailures, search.broken, search.error = 0, nil, nil
        local saved = readJson(BROKEN_FILE, {})
        if type(saved) == "table" and next(saved) ~= nil then pcall(writeJson, BROKEN_FILE, {}) end
    end

    -- This session's view of the tracked target: first time seen off the
    -- field, carried by this player, and when it was lost on the way.
    local absentSince, carrying, lostAt = {}, {}, {}
    -- La misma decision se usa al entrar, despues de un reset y antes de saltar.
    function search.Decide(match, info, cycle)
        info.tracked, info.capture, info.notCaptured = nil, nil, nil
        if search.disposed then info.reason = "sesión terminada"; return "loading" end
        if search.broken then
            -- No map data exists here: leave without touching the cycle memory.
            info.broken = true
            if search.broken.count > BROKEN_LIMIT then
                info.reason = "el juego no cargó bien en varios servidores seguidos; AUTO en espera"
                return "loading"
            end
            info.reason = "el juego no cargó bien en este servidor; buscando otro"
            return "hop"
        end
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
        local function newWindow()
            return {version = 2, rarity = string.lower(search.config.rarity), zones = table.clone(search.config.zones),
                periodIndex = cycle.periodIndex,
                nextReset = cycle.nextReset, periodSeconds = cycle.periodSeconds, nightSeconds = cycle.nightSeconds,
                untilTime = cycle.nextReset - cycle.nightSeconds, seenAt = cycle.serverTime}
        end
        -- After a match AUTO stays on and follows that egg in this server.
        -- Captured (now in this player's eggs): the cycle's hunt ends here and
        -- AUTO waits for the next night, when another one may appear. Taken
        -- by someone else, gone, or not captured in time: look elsewhere.
        local field, mine = info.field, info.mine
        local tracked = valid and type(remembered.matched) == "table"
            and remembered.matched.job == game.JobId and remembered.matched or nil
        if tracked and not tracked.captured and mine and mine[tracked.key] then
            local window = table.clone(remembered)
            window.matched = table.clone(tracked)
            window.matched.captured, window.matched.capturedAt = true, cycle.serverTime
            if not saveWindow(window) then info.reason = "no se pudo guardar la captura"; return "loading" end
            tracked = remembered.matched
        end
        if tracked and tracked.captured then
            info.tracked, info.capture, info.searchUntil = tracked, "capturado", remembered.untilTime
            return "wait"
        end
        if match and not (tracked and tracked.key == match.key) then
            -- The first target, or a better one, starts its own wait. A failed
            -- save never hides the match; the next poll retries it.
            local window = valid and table.clone(remembered) or newWindow()
            window.matched = {job = game.JobId, key = match.key, name = match.name, at = cycle.serverTime}
            if saveWindow(window) then valid = true end
            tracked = window.matched
        end
        local egg = tracked and field and field[tracked.key]
        if egg and egg.state == "Slot" and not (match and match.key == tracked.key) then
            tracked = nil -- still on the map but no longer a target (filters changed)
        end
        if tracked then
            info.tracked, info.searchUntil = tracked, valid and remembered.untilTime or nil
            local now = cycle.serverTime
            if egg and egg.carriedByMe then
                absentSince[tracked.key], carrying[tracked.key] = nil, true
                info.capture = "capturando"; return "match"
            end
            if carrying[tracked.key] and egg then
                -- Lost on the way (guard, dropped, taken) while the egg is
                -- still here: a new wait to pick it up again.
                carrying[tracked.key], lostAt[tracked.key] = nil, now
            end
            if not egg and field and mine then
                absentSince[tracked.key] = absentSince[tracked.key] or now
                if now - absentSince[tracked.key] < CAPTURE_GRACE_SECONDS then
                    info.capture = "comprobando"; return "match"
                end
                info.notCaptured = info.others and info.others[tracked.key] and "lo tomó otro jugador"
                    or "ya no está en el mapa"
                return valid and "hop" or "loading"
            end
            absentSince[tracked.key] = nil
            if now - math.max(tracked.at, lostAt[tracked.key] or tracked.at) >= CAPTURE_TIMEOUT_SECONDS then
                info.notCaptured = string.format("no se capturó en %d s", CAPTURE_TIMEOUT_SECONDS)
                return valid and "hop" or "loading"
            end
            -- Dropped/GuardCarried can still come back to its nest.
            info.capture = egg and egg.state == "Carried" and "lo lleva otro jugador"
                or egg and egg.state ~= "Slot" and "en disputa" or "esperando captura"
            return "match"
        end
        if match then return "match" end
        if (info.rarityCount or 0) > 0 and not valid then
            if not saveWindow(newWindow()) then info.reason = "no se pudo guardar la búsqueda para continuar al reconectar"; return "loading" end
            valid = true
        end
        info.continuingCycle = valid and (info.rarityCount or 0) == 0
        info.searchUntil = valid and remembered.untilTime or nil
        return valid and "hop" or "wait"
    end

    -- Hunt report: audit trail for each hunt started by an in-scope rarity
    -- egg. Records what was seen, how the snapshot was proven loaded before
    -- each decision, the fresh check before every teleport and the outcome.
    local REPORT_FILE = "chilli_egg_hunt_report.json"
    local REPORT_HUNTS, REPORT_VISITS, REPORT_CANDIDATES, REPORT_FAILURES, REPORT_MATCHES = 30, 120, 10, 10, 10
    local report = readJson(REPORT_FILE, {})
    -- Jobs this session already reported: a known job seen for the first
    -- time here means the server was loaded again (rejoin or re-execution).
    local reportedJobs = {}
    if type(report) ~= "table" or type(report.hunts) ~= "table" then report = {version = 1, hunts = {}} end
    local function saveReport()
        while #report.hunts > REPORT_HUNTS do table.remove(report.hunts, 1) end
        pcall(writeJson, REPORT_FILE, report)
    end
    local function openHunt()
        local hunt = report.hunts[#report.hunts]
        return hunt and not hunt.outcome and hunt or nil
    end
    local function closeHunt(hunt, outcome, at)
        hunt.outcome, hunt.endedAt = outcome, at
        print(string.format("[EggHunt] fin: %s | servidores=%d", outcome, hunt.servers or 0))
    end
    -- Eggs of the minimum rarity or higher in the selected zones, with the
    -- exact income and the reason they did or did not match.
    function search.HuntCandidates(rows, config)
        config = config or search.config
        local list = {}
        for _, row in ipairs(rows or {}) do
            local egg, catalog = row.egg, row.catalog
            local inZone = #config.zones == 0 or table.find(config.zones, egg.AreaId) ~= nil
            if catalog and inZone and search.RarityMatches(catalog.Rarity, config.rarity) then
                table.insert(list, {uid = row.uid, name = catalog.DisplayName or egg.AssetCategory,
                    category = egg.AssetCategory, rarity = rarityId(catalog.Rarity), income = row.income,
                    area = egg.AreaId, nest = egg.NestId, scale = egg.AssetScale,
                    mutations = table.clone(egg.Mutations or {}), baseMutation = egg.BaseMutation,
                    match = row.match == true, reason = row.reason})
            end
        end
        table.sort(list, function(a, b) return (a.income or -1) > (b.income or -1) end)
        return list
    end
    function search.ReportDecision(mode, match, info, rows, cycle, job, at)
        if not info or not info.ready or type(cycle) ~= "table" then return end
        local hunt = openHunt()
        local scope = {rarity = search.config.rarity, zones = table.clone(search.config.zones)}
        if hunt and (hunt.period ~= cycle.periodIndex or hunt.rarity ~= scope.rarity
            or not sameInputs(hunt.zones, scope.zones)) then
            closeHunt(hunt, hunt.period ~= cycle.periodIndex and "noche" or "filtros cambiados", at)
            hunt = nil; saveReport()
        end
        local candidates = search.HuntCandidates(rows)
        if not hunt then
            -- Waiting never starts a hunt (a capture already closed it). Hops
            -- with nothing here resume this cycle's hunt (AUTO turned off and
            -- on), so they are reported too.
            local resumed = #candidates == 0 and mode == "hop" and info.continuingCycle == true
            if mode == "wait" or (#candidates == 0 and not resumed) then return end
            hunt = {startedAt = at, period = cycle.periodIndex, rarity = scope.rarity, zones = scope.zones,
                minIncome = search.config.minIncome, first = candidates[1], resumed = resumed or nil,
                startJob = job, servers = 0, visits = {}}
            table.insert(report.hunts, hunt)
            if resumed then
                print(string.format("[EggHunt] reanudada: ya apareció en este ciclo | job=%s", job))
            else
                print(string.format("[EggHunt] inicio: %s (%s) %s/s en %s | job=%s", tostring(candidates[1].name),
                    tostring(candidates[1].rarity), tostring(candidates[1].income), tostring(candidates[1].area), job))
            end
        end
        local visit = hunt.visits[#hunt.visits]
        local reloaded = false
        if not visit or visit.job ~= job then
            if #hunt.visits >= REPORT_VISITS then table.remove(hunt.visits, 1) end
            visit = {job = job, at = at}
            table.insert(hunt.visits, visit)
            hunt.servers += 1
        elseif not reportedJobs[job] then
            visit.reloads, reloaded = (visit.reloads or 0) + 1, true
        end
        reportedJobs[job] = true
        local capture = info.notCaptured or info.capture
        if not reloaded and visit.mode == mode and visit.capture == capture and visit.candidateCount == #candidates
            and sameInputs(visit.candidates, table.move(candidates, 1, math.min(#candidates, REPORT_CANDIDATES), 1, {})) then
            return
        end
        local stats = search.stats
        visit.mode, visit.decidedAt, visit.capture = mode, at, capture
        visit.spawns, visit.rarityCount = info.count, info.rarityCount
        visit.continuingCycle = info.continuingCycle == true
        visit.load = {readyBy = stats.readyBy, readySeconds = stats.readySeconds, settleSeconds = stats.settleSeconds,
            zonesPresent = stats.zonesPresent, zonesTotal = stats.zonesTotal}
        -- The highest incomes are kept; a low minimum rarity can list dozens.
        visit.candidateCount = #candidates
        visit.candidates = table.move(candidates, 1, math.min(#candidates, REPORT_CANDIDATES), 1, {})
        -- Each target and what happened to it; the hunt goes on after one
        -- that was not captured and ends when one is.
        local tracked = info.tracked
        if tracked then
            hunt.matches = hunt.matches or {}
            local entry
            for _, item in ipairs(hunt.matches) do
                if item.job == job and item.key == tracked.key then entry = item end
            end
            if not entry and mode == "match" and match and match.key == tracked.key then
                entry = {key = tracked.key, job = job, at = at, name = match.name, rarity = match.rarity,
                    income = match.income, area = match.area, nest = match.nest, uid = match.uid, capture = "pendiente"}
                if #hunt.matches >= REPORT_MATCHES then table.remove(hunt.matches, 1) end
                table.insert(hunt.matches, entry)
                hunt.found = entry
            end
            if entry and info.capture == "capturado" then
                entry.capture, entry.captureSeconds = "capturado", at - entry.at
            elseif entry and info.notCaptured then
                entry.capture = info.notCaptured
            end
        end
        if info.capture == "capturado" then closeHunt(hunt, "capturado", at) end
        saveReport()
    end
    local function currentVisit(job)
        local hunt = openHunt()
        local visit = hunt and hunt.visits[#hunt.visits]
        return visit and visit.job == job and visit or nil
    end
    -- Listed occupancy of a destination and how old that listing was.
    local function serverListing(server, at)
        if type(server) ~= "table" then return nil, nil end
        local observedAt = tonumber(server.observedAt)
        return tonumber(server.playing), observedAt and math.max(0, at - observedAt) or nil
    end
    -- Fresh scan right before a teleport and the chosen destination.
    function search.ReportHopCheck(mode, info, rows, job, target, at, server)
        local visit = currentVisit(job)
        if not visit then return end
        local matches = 0
        for _, candidate in ipairs(search.HuntCandidates(rows)) do
            if candidate.match then matches += 1 end
        end
        local playing, listedAge = serverListing(server, at)
        visit.beforeHop = {at = at, mode = mode, ready = info and info.ready == true,
            spawns = info and info.count, rarityCount = info and info.rarityCount,
            matches = matches, target = target, playing = playing, listedAge = listedAge}
        saveReport()
    end
    -- A teleport Roblox rejected (GameFull...). A successful one ends the
    -- session, so it shows up as the next visit instead.
    function search.ReportHopFailure(job, target, reason, at, server)
        local visit = currentVisit(job)
        if not visit then return end
        visit.failedHops = visit.failedHops or {}
        if #visit.failedHops >= REPORT_FAILURES then table.remove(visit.failedHops, 1) end
        local playing, listedAge = serverListing(server, at)
        table.insert(visit.failedHops, {at = at, target = target, reason = tostring(reason),
            playing = playing, listedAge = listedAge})
        saveReport()
    end
    function search.ReportStopped(at)
        local hunt = openHunt()
        if hunt then closeHunt(hunt, "AUTO apagado", at); saveReport() end
    end
    function search.HuntReport()
        return copyInputs(report)
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
                search.NoteLoadSuccess()
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
                search.NoteLoadFailure(modules)
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
                row.reason = explain(row.egg, row.catalog, row.income, search.config, ranks)
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
            if best or (type(remembered.matched) == "table" and remembered.matched.job == game.JobId) then
                details.field, details.mine, details.others = search.CaptureInputs(snapshot.Records)
            end
            if not details.ready then
                clearSnapshotLoad()
            elseif not snapshotReady(snapshot.Records, modules.assets.Directory, snapshotCycle) then
                details.ready = false
                details.reason = "cargando huevos del servidor; esperando datos estables y completos"
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
