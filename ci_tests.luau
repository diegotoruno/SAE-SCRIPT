-- Behavioral regression tests: no executor, network, Roblox account or teleports.
local factory = require("./map_egg_search")
local loadClock, gameLoaded = 0, true
setfenv(factory, setmetatable({task = {spawn = function() end},
    os = {clock = function() return loadClock end}, game = {IsLoaded = function() return gameLoaded end}},
    {__index = getfenv(factory)}) :: any)
local saved = {}
local search = factory(function() return {} end, function(key, value) saved[key] = value; return true end)
local passed = 0
local function test(name, callback)
    local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err))
    passed += 1
    print("PASS " .. name)
end
local catalog = {
    divine = {DisplayName = "Divine Alpha", Rarity = {_id = "Divine"}},
    other = {DisplayName = "Common Alpha", Rarity = "Common"},
    divine2 = {DisplayName = "Divine Beta", Rarity = "Divine"},
}
local rarities = {
    Common = {_id = "Common", DisplayName = "Common", Rank = 1},
    Divine = {_id = "Divine", DisplayName = "Divine", Rank = 10},
    Transcendent = {_id = "Transcendent", DisplayName = "Transcendent", Rank = 10},
}
search.modules = {assets = {Directory = catalog}, rarities = {Rarities = rarities}}
local function egg(uid, rate, category, state, mutations)
    return {Uid = uid, rate = rate, AssetCategory = category or "divine",
            State = state or "Slot", Mutations = mutations or {}, AreaId = "forest"}
end
local function evaluate(records, filters)
    local match, info, all = search.Evaluate(records, catalog, function(record) return record.rate end, filters)
    info.ready = info.errors == 0
    return match, info, all
end
local function decision(records)
    local match, info = evaluate(records)
    return search.Decide(match, info)
end
test("empty map waits", function() assert(decision({}) == "wait") end)
test("only Common waits", function() assert(decision({egg("a", 10e9, "other")}) == "wait") end)
test("Divine below 7B hops", function() assert(decision({egg("a", 6999999999)}) == "hop") end)
test("exact 7B stays", function() assert(decision({egg("a", 7e9)}) == "match") end)
test("best income wins", function()
    local best, _, all = evaluate({egg("a", 8e9), egg("b", 12e9)})
    assert(best.uid == "b" and #all == 2)
end)
test("bases and unavailable states never match", function()
    for _, state in ipairs({"Carried", "GuardCarried", "Dropped", "Claimed", "Base"}) do
        assert(decision({egg("a", 99e9, "divine", state)}) == "wait")
    end
end)
test("mutation filter accepts replicated base mutation", function()
    local record = egg("a", 7e9); record.BaseMutation = "Golden"
    assert(evaluate({record}, {mutation = "golden"}) ~= nil)
    assert(evaluate({record}, {mutation = "rainbow"}) == nil)
end)
test("name filter is literal and case insensitive", function()
    assert(evaluate({egg("a", 7e9)}, {nameContains = "ALPHA"}) ~= nil)
    assert(evaluate({egg("a", 7e9)}, {nameContains = ".*"}) == nil)
end)
test("species filter is exact", function()
    assert(evaluate({egg("a", 7e9)}, {categories = {"divine2"}}) == nil)
    assert(evaluate({egg("a", 7e9)}, {categories = {"divine"}}) ~= nil)
end)
test("invalid and unavailable income waits", function()
    for _, rate in ipairs({-1, math.huge, "7B"}) do
        assert(decision({egg("a", rate)}) == "loading")
    end
    assert(decision({egg("a", 0/0)}) == "loading")
end)
test("unknown catalog waits", function() assert(decision({egg("a", 7e9, "missing")}) == "loading") end)
test("bad minimum cannot alter saved configuration", function()
    for _, minimum in ipairs({0, -1, math.huge, "bad"}) do
        assert(not pcall(search.Configure, {minIncome = minimum}))
    end
    assert(search.config.minIncome == 7e9)
end)
test("minimum supports game suffixes and raw per-second values", function()
    for input, expected in pairs({["500k"] = 5e5, ["25M"] = 25e6, ["7b"] = 7e9,
        [" 7.5 B "] = 7.5e9, ["7,5b"] = 7.5e9, ["1t"] = 1e12,
        ["1Q"] = 1e15, ["7000000000"] = 7e9, ["7"] = 7, ["7e9"] = 7e9}) do
        assert(search.ParseMinimum(input) == expected, input)
    end
    assert(search.Configure({minIncome = "7b"}).minIncome == 7e9)
    assert(saved["chilli_egg_search_config.json"].minIncome == 7e9)
end)
test("malformed or overflowing minimum never saves", function()
    for _, input in ipairs({"", " ", "7bb", "7/s", "7..5b", "1,2,3m", "7b!", "-7b", "0k", "1e999b", "inf", "nan"}) do
        assert(search.ParseMinimum(input) == nil, input)
        assert(not pcall(search.Configure, {minIncome = input}), input)
    end
    assert(search.config.minIncome == 7e9)
end)
test("editing a formatted minimum preserves exact boundary", function()
    for _, minimum in ipairs({7e9, 6999999999, 7000000001, 500000, 25e6, 1.1e9, 1234567890.12345, 0.125, 1e15}) do
        assert(search.ParseMinimum(search.FormatMinimum(minimum)) == minimum)
    end
    assert(search.FormatMinimum(7e9) == "7b")
    assert(evaluate({egg("a", 6999999999)}, {minIncome = "7b"}) == nil)
    assert(evaluate({egg("a", 7e9)}, {minIncome = "7b"}) ~= nil)
    assert(evaluate({egg("a", 500000, "other")}, {rarity = "Common", minIncome = "500k"}) ~= nil)
end)
test("rarity options use only species catalog and real ranks", function()
    local options = search.RarityOptions()
    assert(#options == 2 and options[1].id == "Common" and options[2].id == "Divine")
    assert(options[2].rank == 10)
    local extended = table.clone(catalog)
    extended.new = {Rarity = "Transcendent"}
    local added = search.RarityOptions(extended, rarities)
    assert(#added == 3 and added[2].id == "Divine" and added[3].id == "Transcendent")
end)
test("rarity rejects unused aliases and numeric scales", function()
    for _, rarity in ipairs({"Transcendent", "Imaginary", "10", 10}) do
        assert(not pcall(search.Configure, {rarity = rarity}))
    end
    assert(search.Configure({rarity = "divine"}).rarity == "Divine")
    assert(evaluate({egg("a", 7e9, "other")}) == nil)
end)
test("configuration waits for game catalog", function()
    local pending = factory(function() return {} end, function() error("must not save") end)
    assert(not pcall(pending.Configure, {minIncome = "7b"}))
    assert(#pending.RarityOptions() == 0)
end)
test("saved numeric thresholds retain units on reload", function()
    local restored = factory(function() return {minIncome = 7e9} end, function() return true end)
    assert(restored.config.minIncome == 7e9 and restored.FormatMinimum(restored.config.minIncome) == "7b")
end)
test("configuration deduplicates and persists exact species", function()
    local config = search.Configure({categories = {"divine2", "divine", "divine2"}})
    assert(#config.categories == 2 and config.categories[1] == "divine")
    assert(saved["chilli_egg_search_config.json"].categories[2] == "divine2")
end)
-- Restore default selection; all subsequent scenarios use the actual Scan entrypoint.
assert(saved["chilli_egg_search_config.json"].categories[2] == "divine2")
search.Configure({categories = {}})
local records, night, hasSnapshot = {}, false, true
local rateCalls = 0
search.modules = {
    assets = {Directory = catalog},
    rarities = {Rarities = rarities},
    eggs = {HasFieldSnapshot = function() return hasSnapshot end,
            ReadFieldEggs = function() return {Records = records} end},
    records = {ToAssetItemData = function(record) return record end},
    earnings = {MutationOnlyRatePerSecond = function(record) rateCalls += 1; return record.rate end},
    cycle = {IsNightPhase = function() return night end},
}
setfenv(search.Scan, setmetatable({workspace = {GetServerTimeNow = function() return 100 end}},
    {__index = getfenv(search.Scan)}))
local function scanDecision()
    local match, info = search.Scan()
    if not info.ready and info.reason and string.find(info.reason, "datos estables", 1, true) then
        loadClock += 10
        match, info = search.Scan()
    end
    return search.Decide(match, info), info
end
test("night suppresses stale match and income reads", function()
    records = {egg("a", 8e9)}; night = true
    assert(scanDecision() == "loading" and rateCalls == 0)
    night = false
end)
test("reset in progress waits for fresh snapshot", function()
    search.resetting = true; assert(scanDecision() == "loading")
    search.resetting = false; hasSnapshot = false; assert(scanDecision() == "loading")
    hasSnapshot = true; records = {}; assert(scanDecision() == "wait")
end)
test("hop cycle repeats correctly across egg renewal", function()
    records = {egg("a", 6e9)}; assert(scanDecision() == "hop")
    night = true; assert(scanDecision() == "loading")
    night = false; records = {}; assert(scanDecision() == "wait")
    records = {egg("b", 5e9)}; assert(scanDecision() == "hop")
    records = {egg("c", 7e9)}; assert(scanDecision() == "match")
end)
test("malformed snapshot fails closed", function()
    search.modules.eggs.ReadFieldEggs = function() return {} end
    assert(scanDecision() == "loading")
end)
test("obsolete saved rarity waits rather than hopping", function()
    search.modules.eggs.ReadFieldEggs = function() return {Records = {egg("a", 6e9)}} end
    search.config.rarity = "RemovedRarity"
    assert(scanDecision() == "loading")
    search.config.rarity = "Divine"
end)
test("unwritable filters do not silently apply", function()
    local failed = factory(function() return {} end, function() return false end)
    failed.modules = {assets = {Directory = catalog}, rarities = {Rarities = rarities}}
    assert(not pcall(failed.Configure, {minIncome = 8e9}))
    assert(failed.config.minIncome == 7e9)
end)
local support = require("./.tools/runtime_support")()
test("same snapshot shares income reads; fresh hop scan recalculates", function()
    search.modules.eggs.ReadFieldEggs = function() return {Records = records} end
    records = {egg("cache", 8e9)}; rateCalls = 0
    assert(scanDecision() == "match"); local calls = rateCalls
    assert(scanDecision() == "match" and rateCalls == calls)
    assert(search.Scan(true).income == 8e9 and rateCalls == calls + 1)
    records[1].rate = 6e9; assert(scanDecision() == "hop" and rateCalls == calls + 2)
end)
test("base mutation and availability invalidate cached income", function()
    records = {egg("mutation", 8e9)}; search.Scan(); local calls = rateCalls
    records[1].BaseMutation = "Golden"; search.Scan(); assert(rateCalls == calls + 1)
    records[1].State = "Claimed"; assert(scanDecision() == "wait" and #search.lastScan.rows == 0)
end)
test("loading clears old matches and counts", function()
    records = {egg("stale", 8e9)}; assert(scanDecision() == "match")
    hasSnapshot = false; assert(scanDecision() == "loading")
    assert(search.lastScan.match == nil and #search.lastScan.rows == 0)
    hasSnapshot = true
end)
test("display explains exact boundary and base mutation", function()
    local record = egg("boundary", 6999999999)
    assert(search.Explain(record, catalog.divine, record.rate) == "Ingreso inferior al mínimo")
    record.BaseMutation = "Golden"
    assert(search.Explain(record, catalog.divine, 7e9, {rarity = "Divine", minIncome = 7e9,
        nameContains = "", mutation = "golden", categories = {}}) == "Cumple todos los filtros")
end)
test("preset validation cannot change live filters or accept removed species", function()
    local validated = search.Validate({rarity = "divine", minIncome = "8b", categories = {"divine"}})
    assert(validated.rarity == "Divine" and validated.minIncome == 8e9 and search.config.minIncome == 7e9)
    assert(not pcall(search.Validate, {categories = {"removed"}}))
end)
test("store verifies writes, copies values and recovers backup", function()
    local disk, encoded, serial = {}, {}, 0
    local io = {read = function(path) assert(disk[path]); return disk[path] end,
        write = function(path, raw) disk[path] = raw end,
        encode = function(value) serial += 1; local key = tostring(serial); encoded[key] = support.Copy(value); return key end,
        decode = function(raw) assert(encoded[raw]); return support.Copy(encoded[raw]) end}
    local store = support.Store(io)
    assert(store.Write("config", {value = 7})); assert(store.Write("config", {value = 8}))
    local copy = store.Read("config"); copy.value = 99; assert(store.Read("config").value == 8)
    disk.config = "broken"; assert(support.Store(io).Read("config").value == 7)
    io.write = function(path, raw) if path:find("tmp", 1, true) then error("disk full") end; disk[path] = raw end
    assert(not store.Write("config", {value = 9})); assert(store.Read("config").value == 8)
end)
test("visited history expires and stays bounded", function()
    local result = support.PruneVisited({expired = 1, recent = 95, newer = 99, future = 101, invalid = "bad"}, 100, 10, 1)
    assert(result.newer == 99 and result.expired == nil and result.recent == nil and result.future == nil)
end)
test("paging finds candidates beyond visited first page and deduplicates", function()
    local calls = 0
    local result = support.Pages(function(cursor)
        calls += 1
        if not cursor then return {data = {{id = "visited"}}, nextPageCursor = "second"} end
        assert(cursor == "second"); return {data = {{id = "new"}, {id = "new"}}, nextPageCursor = nil}
    end, function(server) return server.id ~= "visited" end, function() return true end, 8, 5)
    assert(calls == 2 and #result == 1 and result[1].id == "new")
end)
test("paging rejects results from cancelled sessions and repeated cursors", function()
    local alive = true
    assert(support.Pages(function() alive = false; return {data = {{id = "new"}}} end,
        function() return true end, function() return alive end, 8, 5) == nil)
    local calls = 0
    support.Pages(function() calls += 1; return {data = {}, nextPageCursor = "same"} end,
        function() return true end, function() return true end, 8, 5)
    assert(calls == 2)
end)
test("occupancy outranks healthier and higher legacy ping servers", function()
    local rows = {{id = "two", playing = 2, fps = 60, ping = 2000},
        {id = "one", playing = 1, fps = 20, ping = 1},
        {id = "empty", playing = 0, fps = 60, ping = 3000},
        {id = "unknown", fps = 60, ping = 4000}}
    local ranked = support.RankServers(rows, "LegacyPing")
    assert(ranked[1].id == "one" and rows[1].id == "two")
    assert(ranked[1].playing == 1 and rows[2].sourceRank == nil)
    assert(#ranked == 2 and ranked[2].id == "two")
end)
test("legacy order keeps FPS then advertised ping within one-player group", function()
    local rows = {{id = "slow", playing = 1, fps = 40, ping = 5000},
        {id = "healthy-low", playing = "1", fps = 60, ping = 10},
        {id = "healthy-high", playing = 1, fps = 55, ping = 2000},
        {id = "other", playing = 2, fps = 60, ping = 9999}}
    local ranked = support.RankServers(rows, "LegacyPing")
    assert(ranked[1].id == "healthy-high" and ranked[2].id == "healthy-low")
    assert(ranked[3].id == "slow" and ranked[4].id == "other")
end)
test("BestLatency preserves Roblox order inside occupancy groups", function()
    local rows = {{id = "other-first", playing = 2, fps = 60, ping = 1},
        {id = "one-first", playing = 1, fps = 10, ping = 1},
        {id = "one-second", playing = 1, fps = 60, ping = 9999},
        {id = "other-second", playing = 2, fps = 60, ping = 9999}}
    local ranked = support.RankServers(rows, "BestLatency")
    assert(ranked[1].id == "one-first" and ranked[2].id == "one-second")
    assert(ranked[3].id == "other-first" and ranked[4].id == "other-second")
end)
test("BestLatency works without ping and handles no one-player servers", function()
    local ranked = support.RankServers({{id = "b", playing = 3}, {id = "a", playing = 2}}, "BestLatency")
    assert(ranked[1].id == "a" and ranked[2].id == "b")
    assert(#support.RankServers({}, "BestLatency") == 0)
    assert(not pcall(support.RankServers, {}, "Asc"))
end)
test("cached candidates keep one-player priority after JSON-like roundtrip", function()
    local ranked = support.RankServers({{id = "two", playing = 2, fps = 60, ping = 9000},
        {id = "one", playing = 1, fps = 60, ping = 10}}, "LegacyPing")
    local cached = support.Copy(ranked)
    table.remove(cached, 1)
    assert(support.RankServers(cached, "LegacyPing")[1].id == "two")
    table.insert(cached, {id = "new-one", playing = 1, fps = 60, ping = 1})
    assert(support.RankServers(cached, "LegacyPing")[1].id == "new-one")
end)
test("BestLatency orders all six occupancies and preserves native ties", function()
    local rows = {{id = "six", playing = 6}, {id = "three-first", playing = 3},
        {id = "five", playing = 5}, {id = "two-first", playing = 2},
        {id = "four", playing = 4}, {id = "one", playing = 1},
        {id = "two-second", playing = 2}, {id = "three-second", playing = 3}}
    local ranked = support.RankServers(rows, "BestLatency")
    local expected = {"one", "two-first", "two-second", "three-first", "three-second", "four", "five", "six"}
    for i, id in ipairs(expected) do assert(ranked[i].id == id) end
end)
test("invalid occupancy cannot enter any hop group", function()
    local rows = {{id = "zero", playing = 0}, {id = "negative", playing = -1},
        {id = "full", playing = 7}, {id = "fraction", playing = 1.5},
        {id = "unknown"}, {id = "nan", playing = 0/0}, {id = "infinite", playing = math.huge}}
    assert(#support.RankServers(rows, "LegacyPing") == 0)
end)
test("native partial pages cannot advance to a higher occupancy", function()
    local rows = {{id = "three", playing = 3}, {id = "two", playing = 2}}
    local pool, reason = support.OccupancyGroup(rows, "BestLatency", false)
    assert(pool == nil and type(reason) == "string")
    pool = support.OccupancyGroup(rows, "BestLatency", true)
    assert(#pool == 1 and pool[1].id == "two")
    table.insert(rows, {id = "one", playing = 1})
    pool = support.OccupancyGroup(rows, "BestLatency", false)
    assert(#pool == 1 and pool[1].id == "one")
end)
test("short cache exhaustion re-queries remaining single-player servers before two", function()
    local all, visited = {}, {}
    for i = 1, 9 do table.insert(all, {id = "one-" .. i, playing = 1, fps = 60, ping = 100 - i}) end
    table.insert(all, {id = "two", playing = 2, fps = 60, ping = 9000})
    local calls = 0
    local function query()
        local rows = support.Pages(function()
            calls += 1; return {data = all}
        end, function(row) return not visited[row.id] end, function() return true end, 8, 5)
        return support.OccupancyGroup(rows, "LegacyPing", true)
    end
    local pool = query()
    for i = 1, 8 do visited[pool[i].id] = true end
    pool = query()
    assert(#pool == 1 and pool[1].id == "one-9")
    visited[pool[1].id] = true
    pool = query()
    assert(#pool == 1 and pool[1].id == "two" and calls == 3)
end)
test("visited ascending pages are scanned before entering the next group", function()
    local calls = 0
    local rows = support.Pages(function(cursor)
        calls += 1
        if not cursor then return {data = {{id = "visited-one", playing = 1}}, nextPageCursor = "next"} end
        return {data = {{id = "two", playing = 2}, {id = "three", playing = 3}}}
    end, function(row) return row.id ~= "visited-one" end, function() return true end, 8, 5)
    local pool = support.OccupancyGroup(rows, "LegacyPing", true)
    assert(calls == 2 and #pool == 1 and pool[1].id == "two")
end)
local function fakeAttempt(overrides)
    local clock, connected, disconnected, sent = 0, nil, 0, 0
    local states, alive, job = {}, true, "origin"
    local env = {alive = function() return alive end, clock = function() return clock end,
        time = function() return 100 end, job = function() return job end, player = "me", place = 1,
        id = "attempt", timeout = 1, automatic = true,
        save = function(state) table.insert(states, state); return true end,
        send = function() sent += 1 end,
        connect = function(callback) connected = callback; return {Disconnect = function() disconnected += 1 end} end,
        wait = function(seconds) clock += seconds end}
    for key, value in pairs(overrides or {}) do env[key] = value end
    return support.Attempt(env), {env = env, states = states, callback = function(...) connected(...) end,
        cancel = function() alive = false end, move = function() job = "destination" end,
        sent = function() return sent end, disconnected = function() return disconnected end}
end
local function nativeResponse(rows, complete)
    return {schema = 1, placeId = 107778070777162, orderBy = "BestLatency",
        requestId = "new-hop", updatedAt = 1000, scanStartedAt = 990,
        state = "ready", complete = complete, servers = rows}
end
local function nativeRow(id, playing, rank)
    return {id = id, playing = playing, maxPlayers = 7, nativeRank = rank, observedAt = 995}
end
test("native connection consumes authenticated order without legacy ping", function()
    local pool = support.NativePool(nativeResponse({nativeRow("first", 1, 20), nativeRow("second", 1, 80)}, false),
        "new-hop", 1000, "current", {})
    assert(#pool == 2 and pool[1].id == "first" and pool[2].id == "second")
end)
test("native connection rejects old hop wrong place and expired response", function()
    local data = nativeResponse({nativeRow("one", 1, 20)}, false)
    assert(support.NativePool(data, "other-hop", 1000, "current", {}) == nil)
    data.placeId = 123; assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
    data.placeId = 107778070777162
    assert(support.NativePool(data, "new-hop", 1011, "current", {}) == nil)
end)
test("native connection excludes current and visited candidates and waits on exhaustion", function()
    local data = nativeResponse({nativeRow("current", 1, 1), nativeRow("visited", 1, 2), nativeRow("new", 1, 3)}, false)
    local pool = support.NativePool(data, "new-hop", 1000, "current", {visited = 999})
    assert(#pool == 1 and pool[1].id == "new")
    assert(support.NativePool(data, "new-hop", 1000, "current", {visited = 999, new = 999}) == nil)
end)
test("native connection cannot advance with partial or stale completion proof", function()
    local data = nativeResponse({nativeRow("two", 2, 1)}, false)
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
    data.complete = true
    assert(support.NativePool(data, "new-hop", 1000, "current", {})[1].id == "two")
    data.scanStartedAt = 100
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
end)
test("native connection does not use errored stale or reordered server rows", function()
    local data = nativeResponse({nativeRow("one", 1, 2), nativeRow("other", 1, 1)}, false)
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
    data.servers = {nativeRow("one", 1, 2)}; data.servers[1].observedAt = 1
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
    data.servers[1].observedAt = 995; data.state = "error"; data.error = "authentication"
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
end)
test("ascending occupancy evidence permits higher groups with native partial pages", function()
    local data = nativeResponse({nativeRow("two", 2, 19)}, false)
    data.lowestOccupancy = 2; data.occupancyCheckedAt = 990
    assert(support.NativePool(data, "new-hop", 1000, "current", {})[1].id == "two")
    data.lowestOccupancy = 1
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
    data.lowestOccupancy = 2; data.occupancyCheckedAt = 900
    assert(support.NativePool(data, "new-hop", 1000, "current", {}) == nil)
end)
test("immediate teleport exception fails without waiting", function()
    local attempt, fake = fakeAttempt({send = function() error("immediate failure") end})
    local state, reason = attempt.Run("target")
    assert(state == "failed" and reason:find("immediate failure", 1, true))
    assert(fake.states[2].pending == false and fake.disconnected() == 1)
end)
test("unrelated teleport failures are ignored; timeout remains pending", function()
    local attempt, fake = fakeAttempt()
    fake.env.send = function()
        fake.callback("other", "failed", "wrong player", 1)
        fake.callback("me", "failed", "wrong target", 1, {ServerInstanceId = "other"})
        fake.callback("me", "failed", "wrong place", 2)
    end
    assert(attempt.Run("target") == "unconfirmed")
    local last = fake.states[#fake.states]; assert(last.pending and last.unconfirmed)
    assert(fake.disconnected() == 1)
end)
test("own teleport failure closes pending state", function()
    local attempt, fake = fakeAttempt()
    fake.env.send = function() fake.callback("me", "GameFull", "full", 1, {ServerInstanceId = "target"}) end
    assert(attempt.Run("target") == "failed" and fake.states[2].pending == false)
end)
test("cancellation cleans connection and cannot overwrite persisted pending", function()
    local attempt, fake = fakeAttempt()
    fake.env.wait = function() fake.cancel() end
    assert(attempt.Run("target") == "cancelled")
    assert(#fake.states == 1 and fake.states[1].pending and fake.states[1].unconfirmed and fake.disconnected() == 1)
end)
test("arrival ends attempt without another teleport", function()
    local attempt, fake = fakeAttempt()
    fake.env.wait = fake.move
    assert(attempt.Run("target") == "moved" and fake.sent() == 1 and fake.disconnected() == 1)
end)
test("failed persistence prevents sending teleport", function()
    local attempt, fake = fakeAttempt({save = function() return false end})
    assert(attempt.Run("target") == "storage" and fake.sent() == 0 and fake.disconnected() == 0)
end)
test("rerun cannot treat pending same-server teleport as arrival", function()
    local state = {pending = true, unconfirmed = true, origin = "origin", target = "destination"}
    assert(not support.Arrived(state, "origin") and support.Arrived(state, "destination"))
    assert(not support.Arrived({pending = true, target = "destination"}, "origin"))
end)
test("closed-panel AUTO avoids income calculations for unrelated rarities", function()
    records = {egg("common", 8e9, "other")}; local calls = rateCalls
    assert(scanDecision() == "wait" and rateCalls == calls)
    search.Scan(false, true); assert(rateCalls == calls + 1 and search.lastScan.rows[1].income == 8e9)
end)
test("AUTO and panel reuse filter analysis until snapshot or config changes", function()
    records = {egg("shared", 8e9)}; search.Scan()
    local analyses = search.stats.analyses
    search.Scan(false, true); search.Scan()
    assert(search.stats.analyses == analyses)
    records[1].rate = 6e9; search.Scan(); assert(search.stats.analyses == analyses + 1)
    search.Configure({minIncome = 5e9}); assert(scanDecision() == "match" and search.stats.analyses == analyses + 2)
    search.Configure({minIncome = 7e9})
end)
test("module initialization retries transient failure and disposes subscriptions", function()
    local scheduled, attempts, waits, disconnected = nil, 0, 0, 0
    local signal = {Connect = function() return {Disconnect = function() disconnected += 1 end} end}
    local parent = {}
    function parent:WaitForChild(name)
        if table.find({"Data", "Client", "Shared", "Utils", "Util"}, name) then return parent end
        return {name = name}
    end
    local oldEnv = getfenv(factory)
    setfenv(factory, setmetatable({game = {GetService = function() return parent end},
        task = {spawn = function(callback) scheduled = callback end, wait = function() waits += 1 end},
        require = function(source)
            if source.name == "Assets" then
                attempts += 1; if attempts == 1 then error("transient module failure") end
                return {Directory = catalog}
            elseif source.name == "EggState" then return {FieldRefreshed = signal, ResetCountdown = signal, RarityRevealed = signal}
            elseif source.name == "Rarity" then return {Rarities = rarities}
            else return {} end
        end}, {__index = oldEnv}))
    local retrying = factory(function() return {} end, function() return true end)
    setfenv(factory, oldEnv)
    scheduled()
    assert(attempts == 2 and waits == 1 and retrying.error == nil and retrying.modules)
    retrying.Dispose(); assert(disconnected == 3)
end)
test("AUTO cannot retry unconfirmed teleport when freshness expires", function()
    local attempt, fake = fakeAttempt()
    assert(attempt.Run("target") == "unconfirmed")
    local pending = fake.states[#fake.states]
    assert(not support.AutoHopAllowed(pending, "origin", 100, false, false, 60))
    assert(not support.AutoHopAllowed(pending, "origin", 10000, false, false, 60))
    assert(support.AutoHopAllowed({pending = false}, "origin", 10000, false, false, 60))
end)
test("AUTO respects worker reservation and explicit blocked state", function()
    assert(not support.AutoHopAllowed(nil, "origin", 100, true, false, 60))
    assert(not support.AutoHopAllowed(nil, "origin", 100, false, true, 60))
    assert(support.AutoHopAllowed(nil, "origin", 100, false, false, 60))
end)
test("legacy pending teleport waits until expiry or confirmed destination", function()
    local state = {pending = true, target = "destination", requestedAt = 100}
    assert(not support.AutoHopAllowed(state, "origin", 120, false, false, 60))
    assert(support.AutoHopAllowed(state, "origin", 160, false, false, 60))
    assert(support.AutoHopAllowed(state, "destination", 120, false, false, 60))
end)
test("record comparison detects in-place mutation without stringifying data", function()
    local a = {Uid = "copy", State = "Slot", Mutations = {"Golden"}, Bounds = {x = 1}}
    local snapshot = search.CopyRecord(a)
    assert(search.SameRecord(snapshot, a))
    a.Mutations[1] = "Rainbow"; assert(not search.SameRecord(snapshot, a))
    a.Mutations[1] = "Golden"; a.Bounds.x = 2; assert(not search.SameRecord(snapshot, a))
    a.Bounds.x = 1; a.NewField = 2; assert(not search.SameRecord(snapshot, a))
end)
test("catalog income and rarity changes invalidate analysis", function()
    records = {egg("catalog-change", 8e9)}; search.Scan()
    local before = search.stats.analyses
    catalog.divine.EarningRate = 123; search.Scan(); assert(search.stats.analyses == before + 1)
    catalog.divine.Rarity = {_id = "Common"}; assert(scanDecision() == "wait")
    catalog.divine.Rarity = {_id = "Divine"}; catalog.divine.EarningRate = nil
end)
local function cycleFactory(read, write)
    local finder = factory(read, write)
    finder.modules = {assets = {Directory = catalog}, rarities = {Rarities = rarities}}
    return finder
end
local function cycle(now, overrides)
    local index = math.floor(now / 300)
    local result = {running = true, night = now % 300 >= 290, serverTime = now,
        periodIndex = index, nextReset = (index + 1) * 300, periodSeconds = 300, nightSeconds = 10}
    for key, value in pairs(overrides or {}) do result[key] = value end
    return result
end
local function memoryStore()
    local files, writes, fail = {}, 0, false
    return files, function(key, fallback) return table.clone(files[key] or fallback) end,
        function(key, value)
            if fail then return false end
            writes += 1; files[key] = table.clone(value); return true
        end, function(value) fail = value end, function() return writes end
end
local function decideCycle(finder, input, at, filters)
    local match, info = finder.Evaluate(input, catalog, function(e) return e.rate end, filters)
    info.ready = info.errors == 0
    return finder.Decide(match, info, cycle(at)), info
end
test("observed rarity continues when stolen or missing in next server", function()
    local _, read, write, _, writes = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    local mode, info = decideCycle(finder, {}, 101)
    assert(mode == "hop" and info.rarityCount == 0 and info.continuingCycle and info.searchUntil == 290)
    for _, state in ipairs({"Carried", "Claimed", "Dropped", "Base"}) do
        assert(decideCycle(finder, {egg("a", 99e9, "divine", state)}, 102) == "hop")
    end
    assert(writes() == 1, "Polling must not rewrite the same window")
end)
test("absence alone cannot invent an active hunt", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 99e9, "divine", "Carried")}, 100) == "wait")
    assert(decideCycle(finder, {}, 101) == "wait" and next(finder.SearchWindow()) == nil)
end)
test("saved hunt resumes after disconnect with a fresh missing snapshot", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    local resumed = cycleFactory(read, write)
    assert(resumed.Decide(nil, {ready = false}, cycle(105)) == "loading")
    assert(decideCycle(resumed, {}, 106) == "hop")
    local copy = resumed.SearchWindow(); copy.rarity = "common"
    assert(resumed.SearchWindow().rarity == "divine")
end)
test("next night expires the hunt before the period index changes", function()
    local files, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    assert(decideCycle(finder, {}, 289.999) == "hop")
    assert(finder.Decide(nil, {ready = false}, cycle(290)) == "loading")
    assert(next(files["chilli_egg_search_cycle.json"]) == nil)
    assert(decideCycle(cycleFactory(read, write), {}, 301) == "wait")
end)
test("reset missed while disconnected cannot restore last night's rarity", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    local resumed = cycleFactory(read, write)
    assert(resumed.Decide(nil, {ready = false}, cycle(601)) == "loading")
    assert(decideCycle(resumed, {}, 602) == "wait")
    assert(decideCycle(resumed, {egg("new", 5e9)}, 603) == "hop")
    assert(resumed.SearchWindow().periodIndex == 2)
end)
test("fresh matching egg wins over continuation but missing data cannot match", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    assert(decideCycle(finder, {egg("new", 7e9)}, 101) == "match")
    assert(finder.Decide({income = 7e9}, {ready = false}, cycle(102)) == "loading")
    assert(finder.Decide({income = 7e9}, {ready = true}, cycle(290)) == "loading")
end)
test("changed rarity resets memory but income filters keep the current rarity hunt", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    finder.Configure({minIncome = 8e9, categories = {"divine2"}})
    assert(decideCycle(finder, {}, 101) == "hop")
    finder.Configure({rarity = "Common"})
    assert(decideCycle(finder, {}, 102) == "wait")
    finder.Configure({rarity = "Divine"})
    assert(decideCycle(finder, {}, 103) == "wait")
end)
test("unknown or paused clock preserves memory without allowing hop", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    assert(finder.Decide(nil, {ready = true}, false) == "loading")
    assert(finder.Decide(nil, {ready = true}, {}) == "loading")
    assert(finder.Decide(nil, {ready = true}, cycle(101, {running = false})) == "loading")
    assert(finder.SearchWindow().rarity == "divine" and decideCycle(finder, {}, 102) == "hop")
end)
test("clock overrides and future or corrupt saved windows cannot drive a hop", function()
    for _, patch in ipairs({{nextReset = 400}, {periodSeconds = 400}, {nightSeconds = 15}}) do
        local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
        assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
        assert(finder.Decide(nil, {ready = true, rarityCount = 0}, cycle(101, patch)) == "wait")
    end
    local files, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    files["chilli_egg_search_cycle.json"].seenAt = 200
    assert(decideCycle(cycleFactory(read, write), {}, 101) == "wait")
    files["chilli_egg_search_cycle.json"] = {version = 9, rarity = "divine"}
    assert(decideCycle(cycleFactory(read, write), {}, 102) == "wait")
end)
test("failed window persistence waits and retries instead of losing the hunt", function()
    local _, read, write, fail = memoryStore(); local finder = cycleFactory(read, write)
    fail(true); assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "loading")
    fail(false); assert(decideCycle(finder, {egg("a", 6e9)}, 101) == "hop")
    fail(true); assert(finder.Decide(nil, {ready = false}, cycle(290)) == "loading")
    assert(decideCycle(finder, {}, 301) == "loading")
    fail(false); assert(decideCycle(finder, {}, 302) == "wait")
end)
test("snapshot from previous cycle cannot match or seed the new cycle", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    local match, info = finder.Evaluate({egg("old", 8e9)}, catalog, function(e) return e.rate end)
    info.ready, info.cycle = true, cycle(100)
    assert(finder.Decide(match, info, cycle(301)) == "loading")
    assert(next(finder.SearchWindow()) == nil)
    info.rarityCount = 1
    assert(finder.Decide(nil, info, cycle(301)) == "loading")
    assert(decideCycle(finder, {}, 302) == "wait")
end)
test("cycle renewal during a scan discards the pre-reset match", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    local sample = 0
    finder.CycleStatus = function() sample += 1; return sample == 1 and cycle(289) or cycle(301) end
    finder.modules = {assets = {Directory = catalog}, rarities = {Rarities = rarities}, eggs = {HasFieldSnapshot = function() return true end,
        ReadFieldEggs = function() return {Records = {egg("old", 8e9)}} end},
        records = {ToAssetItemData = function(e) return e end},
        earnings = {MutationOnlyRatePerSecond = function(e) return e.rate end},
        cycle = {IsNightPhase = function() return false end}}
    setfenv(finder.Scan, setmetatable({workspace = {GetServerTimeNow = function() return 289 end}},
        {__index = getfenv(finder.Scan)}) :: any)
    local match, info = finder.Scan()
    assert(match == nil and not info.ready and finder.Decide(match, info, cycle(301)) == "loading")
    finder.modules.eggs.ReadFieldEggs = function() return {Records = {}} end
    match, info = finder.Scan()
    assert(not info.ready)
    loadClock += 10
    match, info = finder.Scan()
    assert(info.ready and finder.Decide(match, info, cycle(302)) == "wait")
end)
test("disposed detector cannot replace persisted cycle or filters", function()
    local _, read, write, _, writes = memoryStore(); local finder = cycleFactory(read, write)
    finder.Dispose()
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "loading")
    assert(not pcall(finder.Configure, {minIncome = 8e9}) and writes() == 0)
    local _, info = finder.Scan(); assert(not info.ready)
end)
test("new connection recovers origin but script rerun cannot clear pending", function()
    local state = {pending = true, unconfirmed = true, origin = "origin", target = "destination", originConnection = "A"}
    assert(support.TeleportDisposition(state, "origin", "A") == "blocked")
    assert(support.TeleportDisposition(state, "origin", "B") == "reconnected")
    assert(support.TeleportDisposition(state, "destination", "A") == "arrived")
    assert(support.TeleportDisposition({pending = true, target = "destination"}, "origin", "B") == "blocked")
end)
test("disconnect persists connection proof and hunt for the same cycle", function()
    local _, read, write = memoryStore(); local finder = cycleFactory(read, write)
    assert(decideCycle(finder, {egg("a", 6e9)}, 100) == "hop")
    local attempt, fake = fakeAttempt({connectionId = "A"})
    fake.env.wait = fake.cancel
    assert(attempt.Run("destination") == "cancelled" and fake.disconnected() == 1)
    local state = fake.states[1]
    assert(state.pending and state.originConnection == "A")
    assert(support.TeleportDisposition(state, "origin", "B") == "reconnected")
    assert(decideCycle(cycleFactory(read, write), {}, 101) == "hop")
    assert(decideCycle(cycleFactory(read, write), {}, 301) == "wait")
end)
test("timeout retains original connection identity and cannot auto retry", function()
    local attempt, fake = fakeAttempt({connectionId = "A"})
    assert(attempt.Run("destination") == "unconfirmed")
    local state = fake.states[#fake.states]
    assert(state.originConnection == "A" and support.TeleportDisposition(state, "origin", "A") == "blocked")
    assert(not support.AutoHopAllowed(state, "origin", 10000, false, false, 60))
end)
test("connection failure cannot retry if pending closure fails", function()
    local writes = 0
    local attempt, fake = fakeAttempt({connect = function() error("signal unavailable") end,
        save = function() writes += 1; return writes == 1 end})
    assert(attempt.Run("destination") == "storage" and fake.sent() == 0)
end)
test("cancellation during connection setup cannot send a stale teleport", function()
    local attempt, fake = fakeAttempt()
    fake.env.connect = function() attempt.Cancel(); return {Disconnect = function() end} end
    assert(attempt.Run("destination") == "cancelled" and fake.sent() == 0 and #fake.states == 1)
end)
local function minimumFixture(read, write)
    local definitions = {
        Common = {_id = "Common", Rank = 1}, Eternal = {_id = "Eternal", Rank = 9},
        Divine = {_id = "Divine", Rank = 10}, Titan = {_id = "Titan", Rank = 11},
        Limited = {_id = "Limited", Rank = 9},
    }
    local entries = {
        common = {DisplayName = "Common Alpha", Rarity = definitions.Common},
        eternal = {DisplayName = "Eternal Alpha", Rarity = definitions.Eternal},
        divine = {DisplayName = "Divine Alpha", Rarity = definitions.Divine},
        divine2 = {DisplayName = "Divine Beta", Rarity = "Divine"},
        titan = {DisplayName = "Titan Alpha", Rarity = definitions.Titan},
        limited = {DisplayName = "Limited Alpha", Rarity = definitions.Limited},
    }
    local finder = factory(read or function() return {} end, write or function() return true end)
    local state = {records = {}, reads = 0}
    finder.modules = {assets = {Directory = entries}, rarities = {Rarities = definitions},
        eggs = {HasFieldSnapshot = function() return true end,
            ReadFieldEggs = function() return {Records = state.records} end},
        records = {ToAssetItemData = function(e) return e end},
        earnings = {MutationOnlyRatePerSecond = function(e) state.reads += 1; return e.rate end},
        cycle = {IsNightPhase = function() return false end}}
    finder.Configure({rarity = "Eternal"})
    setfenv(finder.Scan, setmetatable({workspace = {GetServerTimeNow = function() return 100 end}},
        {__index = getfenv(finder.Scan)}))
    local function evaluateMinimum(input, patch, registry)
        local filters = table.clone(finder.config)
        for key, value in pairs(patch or {}) do filters[key] = value end
        local match, info, all = finder.Evaluate(input, entries, function(e) return e.rate end, filters, registry)
        info.ready = info.errors == 0
        return finder.Decide(match, info), match, info, all
    end
    return finder, state, evaluateMinimum, entries, definitions
end
test("Eternal accepts Divine at the exact income boundary", function()
    local _, _, evaluateMinimum = minimumFixture()
    local mode, match, info = evaluateMinimum({egg("d", 7e9)})
    assert(mode == "match" and match.rarity == "Divine" and info.rarityCount == 1)
    assert(evaluateMinimum({egg("d", 6999999999)}) == "hop")
end)
test("minimum includes exact higher and equal ranks and chooses best income", function()
    local _, _, evaluateMinimum = minimumFixture()
    local mode, match, info, all = evaluateMinimum({egg("e", 7e9, "eternal"),
        egg("d", 8e9), egg("t", 9e9, "titan"), egg("l", 7e9, "limited"), egg("c", 99e9, "common")})
    assert(mode == "match" and match.uid == "t" and #all == 4 and info.rarityCount == 4)
end)
test("minimum never considers lower rank income or starts a hop", function()
    local finder, _, _, entries, definitions = minimumFixture()
    local reads = 0
    local match, info = finder.Evaluate({egg("c", 99e9, "common")}, entries,
        function() reads += 1; return 99e9 end, nil, definitions)
    info.ready = info.errors == 0
    assert(reads == 0 and info.rarityCount == 0 and finder.Decide(match, info) == "wait")
end)
test("higher rank must still satisfy species name and mutation", function()
    local _, _, evaluateMinimum = minimumFixture()
    for _, patch in ipairs({{categories = {"eternal"}}, {nameContains = "Eternal"}, {mutation = "Golden"}}) do
        assert(evaluateMinimum({egg("d", 8e9)}, patch) == "hop")
    end
    assert(evaluateMinimum({egg("d", 8e9, "divine", "Slot", {"Golden"})},
        {categories = {"divine"}, nameContains = "Alpha", mutation = "Golden"}) == "match")
end)
test("unavailable higher eggs are never evidence or a candidate", function()
    local _, _, evaluateMinimum = minimumFixture()
    for _, state in ipairs({"Carried", "GuardCarried", "Dropped", "Claimed", "Base"}) do
        assert(evaluateMinimum({egg("d", 99e9, "divine", state)}) == "wait")
    end
end)
test("minimum handles case insensitive table and string rarity ids", function()
    local _, _, evaluateMinimum = minimumFixture()
    local mode, _, info, all = evaluateMinimum({egg("d", 8e9), egg("d2", 8e9, "divine2")}, {rarity = "eTeRnAl"})
    assert(mode == "match" and #all == 2 and info.rarityCount == 2)
end)
test("game rank metadata controls ordering and missing ranks wait", function()
    local _, _, evaluateMinimum = minimumFixture()
    assert(evaluateMinimum({egg("d", 8e9)}, nil, {Eternal = {Rank = 100}, Divine = {Rank = 50}}) == "wait")
    for _, registry in ipairs({{}, {Divine = {Rank = 10}},
        {Eternal = {Rank = math.huge}, Divine = {Rank = 10}},
        {Eternal = {Rank = 9}, Divine = {Rank = 0/0}}}) do
        assert(evaluateMinimum({egg("d", 8e9)}, nil, registry) == "loading")
    end
end)
test("species membership and map explanations use the same minimum", function()
    local finder, _, _, entries, definitions = minimumFixture()
    for _, id in ipairs({"Eternal", "Divine", "Titan", "Limited"}) do
        assert(finder.RarityMatches(id, "Eternal", definitions))
    end
    assert(finder.RarityMatches("Common", "Eternal", definitions) == false)
    assert(finder.Explain(egg("d", 7e9), entries.divine, 7e9) == "Cumple todos los filtros")
    assert(finder.Explain(egg("d", 6e9), entries.divine, 6e9) == "Ingreso inferior al mínimo")
    assert(finder.Explain(egg("c", 99e9, "common"), entries.common, 99e9) == "Rareza inferior al mínimo")
end)
test("AUTO calculates higher eggs with the panel closed and invalidates caches", function()
    local finder, state = minimumFixture()
    state.records = {egg("d", 7e9)}
    local match, info = finder.Scan()
    assert(not info.ready and match == nil)
    loadClock += 10
    match, info = finder.Scan()
    assert(info.ready and match.rarity == "Divine" and state.reads == 1)
    finder.Scan(); assert(state.reads == 1)
    state.records[1].rate = 6999999999
    match, info = finder.Scan()
    assert(finder.Decide(match, info) == "hop" and state.reads == 2)
    finder.modules.rarities.Rarities.Divine.Rank = 8
    match, info = finder.Scan()
    assert(finder.Decide(match, info) == "wait" and state.reads == 2)
end)
test("fresh hop verification recomputes the higher egg exact income", function()
    local finder, state = minimumFixture()
    state.records = {egg("d", 7e9)}
    local match, info = finder.Scan()
    assert(not info.ready and match == nil)
    loadClock += 10
    assert(finder.Scan().rarity == "Divine" and state.reads == 1)
    assert(finder.Scan(true).rarity == "Divine" and state.reads == 2)
end)
test("map snapshot includes higher matches and the correct reason", function()
    local finder, state = minimumFixture()
    state.records = {egg("d", 7e9), egg("c", 99e9, "common")}
    local snapshot = finder.MapSnapshot()
    assert(not snapshot.info.ready and snapshot.match == nil)
    loadClock += 10
    snapshot = finder.MapSnapshot()
    assert(snapshot.info.ready and snapshot.match.rarity == "Divine" and #snapshot.rows == 2)
    for _, row in ipairs(snapshot.rows) do
        if row.uid == "d" then assert(row.match and row.reason == "Cumple todos los filtros")
        else assert(not row.match and row.reason == "Rareza inferior al mínimo") end
    end
end)
test("higher observation persists the minimum hunt until the next night", function()
    local _, read, write = memoryStore(); local finder = minimumFixture(read, write)
    local function decideMinimumCycle(target, input, now)
        local match, info = target.Evaluate(input, target.modules.assets.Directory, function(e) return e.rate end)
        info.ready = info.errors == 0
        return target.Decide(match, info, cycle(now))
    end
    assert(decideMinimumCycle(finder, {egg("d", 6e9)}, 100) == "hop")
    assert(finder.SearchWindow().rarity == "eternal")
    local resumed = minimumFixture(read, write)
    assert(decideMinimumCycle(resumed, {}, 101) == "hop")
    assert(decideMinimumCycle(resumed, {egg("d", 7e9)}, 102) == "match")
    assert(decideMinimumCycle(resumed, {}, 290) == "loading")
    assert(decideMinimumCycle(resumed, {}, 301) == "wait")
end)
local function loadingFixture(read, write)
    local finder = factory(read or function() return {} end, write or function() return true end)
    local state = {records = {}, snapshot = true, now = 100, reads = 0, catalog = table.clone(catalog)}
    finder.CycleStatus = function() return cycle(state.now) end
    finder.modules = {
        assets = {Directory = state.catalog}, rarities = {Rarities = rarities},
        eggs = {HasFieldSnapshot = function() return state.snapshot end,
            ReadFieldEggs = function() state.reads += 1; return {Records = state.records} end},
        records = {ToAssetItemData = function(e) return e end},
        earnings = {MutationOnlyRatePerSecond = function(e) return e.rate end},
        cycle = {IsNightPhase = function() return cycle(state.now).night end},
    }
    setfenv(finder.Scan, setmetatable({workspace = {GetServerTimeNow = function() return state.now end}},
        {__index = getfenv(finder.Scan)}) :: any)
    local function scan()
        local match, info = finder.Scan()
        return finder.Decide(match, info, cycle(state.now)), info, match
    end
    return finder, state, scan
end
test("arrival with saved hunt cannot hop on an early empty snapshot", function()
    local _, read, write = memoryStore()
    assert(decideCycle(cycleFactory(read, write), {egg("origin", 6e9)}, 100) == "hop")
    local _, state, scan = loadingFixture(read, write)
    loadClock = 0
    assert(scan() == "loading")
    for _ = 1, 5 do assert(scan() == "loading") end
    loadClock = 9.99; assert(scan() == "loading")
    state.records = {egg("late", 8e9)}
    loadClock = 10; assert(scan() == "loading")
    loadClock = 12.99; assert(scan() == "loading")
    loadClock = 13
    local mode, _, match = scan()
    assert(mode == "match" and match.uid == "late")
end)
test("loaded game and first valid snapshot start the arrival wait", function()
    local _, state, scan = loadingFixture()
    loadClock, gameLoaded = 0, false
    assert(scan() == "loading" and state.reads == 0)
    loadClock, gameLoaded, state.snapshot = 50, true, false
    assert(scan() == "loading" and state.reads == 0)
    loadClock, state.snapshot, state.records = 100, true, {egg("low", 6e9)}
    assert(scan() == "loading")
    loadClock = 109.99; assert(scan() == "loading")
    loadClock = 110; assert(scan() == "hop")
end)
test("same-count replication and in-place changes restart the quiet window", function()
    local _, state, scan = loadingFixture()
    state.records = {egg("low", 6e9)}
    loadClock = 0; assert(scan() == "loading")
    loadClock = 9; state.records[1].Uid = "replacement"; assert(scan() == "loading")
    loadClock = 10; assert(scan() == "loading")
    loadClock = 11; state.records[1].rate = 8e9; assert(scan() == "loading")
    loadClock = 13.99; assert(scan() == "loading")
    loadClock = 14; assert(scan() == "match")
end)
test("continuous replication never becomes ready by timeout alone", function()
    local _, state, scan = loadingFixture()
    state.records = {egg("low", 6e9)}
    for second = 0, 30 do
        loadClock = second; state.records[1].AssetScale = second + 1
        assert(scan() == "loading")
    end
    loadClock = 33; assert(scan() == "hop")
end)
test("fresh repeated reads cannot skip the arrival gate", function()
    local finder, state, scan = loadingFixture()
    state.records = {egg("low", 6e9)}
    loadClock = 0; assert(scan() == "loading")
    for _ = 1, 10 do
        local match, info = finder.Scan(true)
        assert(finder.Decide(match, info, cycle(100)) == "loading")
    end
    loadClock = 10; assert(scan() == "hop")
    loadClock = 10.1; assert(scan() == "hop", "Established readiness must not restart on every scan")
end)
test("lost or malformed snapshot restarts arrival validation", function()
    local finder, state, scan = loadingFixture()
    state.records = {egg("low", 6e9)}
    loadClock = 0; assert(scan() == "loading")
    loadClock = 10; assert(scan() == "hop")
    state.snapshot = false; assert(scan() == "loading")
    state.snapshot = true; loadClock = 20; assert(scan() == "loading")
    loadClock = 30; assert(scan() == "hop")
    local read = finder.modules.eggs.ReadFieldEggs
    finder.modules.eggs.ReadFieldEggs = function() return {} end
    assert(scan() == "loading")
    finder.modules.eggs.ReadFieldEggs = read
    loadClock = 40; assert(scan() == "loading")
    loadClock = 50; assert(scan() == "hop")
end)
test("renewal missed between polls starts a new load gate", function()
    local _, state, scan = loadingFixture()
    state.records = {egg("low", 6e9)}
    loadClock = 0; assert(scan() == "loading")
    loadClock = 10; assert(scan() == "hop")
    state.now = 301; loadClock = 20; assert(scan() == "loading")
    loadClock = 29.99; assert(scan() == "loading")
    state.records = {}; loadClock = 30; assert(scan() == "loading")
    loadClock = 33; assert(scan() == "wait")
end)
test("field refresh during loading restarts quiet time without trusting the signal", function()
    local finder, state, scan = loadingFixture()
    state.records = {egg("low", 6e9)}
    loadClock = 0; assert(scan() == "loading")
    loadClock = 9; finder.fieldRevision += 1; assert(scan() == "loading")
    loadClock = 10; assert(scan() == "loading")
    loadClock = 12; assert(scan() == "hop")
end)
test("missing catalog or income cannot consume the load wait", function()
    local _, state, scan = loadingFixture()
    state.records = {egg("low", 6e9, "missing")}
    loadClock = 0; assert(scan() == "loading")
    loadClock = 20; state.records[1].AssetCategory = "divine"; assert(scan() == "loading")
    loadClock = 30; assert(scan() == "hop")
    state.records[1].rate = -1; assert(scan() == "loading")
    state.records[1].rate = 6e9; loadClock = 40; assert(scan() == "loading")
    loadClock = 50; assert(scan() == "hop")
end)
test("unavailable eggs are excluded from arrival stability inputs", function()
    local _, state, scan = loadingFixture()
    state.records = {egg("base", 99e9, "divine", "Base")}
    loadClock = 0; assert(scan() == "loading")
    state.records[1].rate = 100e9
    loadClock = 10; assert(scan() == "wait")
end)
test("inclusive rarity matching still waits for stable arrival data", function()
    local finder, state, scan = loadingFixture()
    finder.Configure({rarity = "Common"})
    state.records = {egg("higher", 8e9)}
    loadClock = 0; assert(scan() == "loading")
    loadClock = 9.99; assert(scan() == "loading")
    loadClock = 10
    local mode, info, match = scan()
    assert(mode == "match" and info.rarityCount == 1 and match.uid == "higher")
end)
test("higher rarity hunt cannot bypass the empty destination load wait", function()
    local _, read, write = memoryStore()
    local finder, origin, scanOrigin = loadingFixture(read, write)
    finder.Configure({rarity = "Common"})
    origin.records = {egg("higher-low", 6e9)}
    loadClock = 0; assert(scanOrigin() == "loading")
    loadClock = 10; assert(scanOrigin() == "hop")
    local _, destination, scanDestination = loadingFixture(read, write)
    assert(#destination.records == 0)
    loadClock = 20; assert(scanDestination() == "loading")
    loadClock = 29.99; assert(scanDestination() == "loading")
    loadClock = 30
    local mode, info = scanDestination()
    assert(mode == "hop" and info.continuingCycle and info.rarityCount == 0)
end)
test("cookie parser rejects headers multiple cookies controls and oversize input", function()
    assert(support.NormalizeCookie("  .ROBLOSECURITY=fake-secret;\n") == "fake-secret")
    for _, value in ipairs({"", "Cookie: .ROBLOSECURITY=fake", "a;b", "a\nb", "a b", string.rep("a", 16385)}) do
        assert(support.NormalizeCookie(value) == nil)
    end
end)
local function credentialFixture(owner, files)
    files = files or {}
    local io = {read = function(path) assert(files[path]); return files[path] end,
        write = function(path, raw) files[path] = raw end,
        erase = function(path) files[path] = nil end,
        encode = function(value) return tostring(value.owner) .. ":" .. value.cookie end,
        decode = function(raw) local id, cookie = raw:match("^(%d+):(.+)$"); return {owner = tonumber(id), cookie = cookie} end}
    return support.DeviceCookie(io, owner), files, io
end
test("device cookie survives hop only after explicit local save and is account scoped", function()
    local first, files = credentialFixture(101)
    assert(first.Set("fake-secret", true))
    local destination = credentialFixture(101, files)
    assert(destination.Restore() and destination.Read() == "fake-secret")
    local other = credentialFixture(202, files)
    assert(not other.Restore() and other.Read() == nil)
    local status = destination.Status()
    assert(status.configured and status.remembered and status.cookie == nil)
    assert(first.Set("session-secret", false) and not first.Status().remembered)
    destination = credentialFixture(101, files)
    assert(not destination.Restore())
    first.Destroy(); assert(first.Read() == nil)
end)
test("forget removes saved cookie and unwritable storage never pretends success", function()
    local device, files, io = credentialFixture(101)
    assert(device.Set("fake-secret", true)); assert(device.Forget())
    assert(next(files) == nil and device.Read() == nil)
    io.write = function() error("fake-secret") end
    local ok, reason = device.Set("fake-secret", true)
    assert(not ok and not reason:find("fake-secret", 1, true) and device.Read() == nil)
    io.erase = function() error("fake-secret") end
    assert(not device.Forget() and not device.Status().configured)
end)
test("authenticated cookie request is fixed to Roblox and occupancy carries no cookie", function()
    local calls = {}
    local env = {encode = function(value) return value end, decode = function() return {data = {}} end,
        send = function(options)
            table.insert(calls, {url = options.Url, cookie = options.Headers.Cookie, redirect = options.Redirect})
            return {StatusCode = 200, Body = "fixture"}
        end}
    assert(support.CookiePage(env, "BestLatency", nil, "fake-secret"))
    assert(calls[1].url:find("https://games.roblox.com/v2/games/107778070777162/servers/Public", 1, true) == 1)
    assert(calls[1].cookie == ".ROBLOSECURITY=fake-secret" and calls[1].redirect == false)
    assert(support.CookiePage(env, "OccupancyAsc", nil, "fake-secret"))
    assert(calls[2].cookie == nil)
    assert(not support.CookiePage(env, "https://another.example", nil, "fake-secret") and #calls == 2)
end)
test("cookie HTTP errors redirects and decoder failures never disclose credential", function()
    local env = {encode = function(v) return v end, decode = function() error("fake-secret") end,
        send = function() error("fake-secret") end}
    local function rejected()
        local page, reason = support.CookiePage(env, "BestLatency", nil, "fake-secret")
        assert(page == nil and not reason:find("fake-secret", 1, true))
    end
    rejected()
    for _, status in ipairs({200, 302, 400, 401, 403, 429, 500}) do
        env.send = function() return {StatusCode = status, Body = "fake-secret", Headers = {Cookie = "fake-secret"}} end
        rejected()
    end
    env.send = function() return {StatusCode = 200, Url = "https://another.example/", Body = "fixture"} end
    rejected()
end)
local function deviceNativeFixture(pages)
    local index, clock, active, calls = 0, 100, true, {}
    local native = support.DeviceNative({now = function() return clock end, alive = function() return active end,
        fetch = function(order, cursor)
            index += 1; table.insert(calls, {order = order, cursor = cursor})
            local entry = pages[index]
            if not entry then return nil, "fixture exhausted" end
            if entry.cancel then active = false end
            return entry.page, entry.error
        end})
    return native, calls, function(value) clock = value end
end
local function nativePage(rows, cursor)
    local result = {data = {}, nextPageCursor = cursor}
    for _, row in ipairs(rows) do table.insert(result.data, {id = row[1], playing = row[2], maxPlayers = 7}) end
    return result
end
test("device uses minimum occupancy proof and native order across consumed groups", function()
    local native, calls = deviceNativeFixture({
        {page = nativePage({{"one", 1}, {"two-a", 2}})},
        {page = nativePage({{"two-b", 2}, {"one", 1}, {"two-a", 2}}, "later")},
        {page = nativePage({{"one", 1}, {"two-a", 2}, {"two-b", 2}})},
    })
    local first = native.Pick("current", {})
    assert(#first == 1 and first[1].id == "one")
    local nextGroup = native.Pick("current", {one = 100})
    assert(#nextGroup == 2 and nextGroup[1].id == "two-b" and nextGroup[2].id == "two-a")
    assert(calls[1].order == "OccupancyAsc" and calls[2].order == "BestLatency" and calls[3].order == "OccupancyAsc")
end)
test("device partial latency page never overrides lower occupancy proof", function()
    local pages = {{page = nativePage({{"one", 1}, {"two", 2}})}}
    for i = 1, 5 do table.insert(pages, {page = nativePage({{"two", 2}}, "page" .. i)}) end
    local native = deviceNativeFixture(pages)
    assert(native.Pick("current", {}) == nil)
end)
test("device malformed proof repeated cursors cancellation and errors wait", function()
    for _, pages in ipairs({
        {{page = nativePage({{"two", 2}, {"one", 1}})}},
        {{error = "authentication"}},
        {{cancel = true, page = nativePage({{"one", 1}})}},
        {{page = nativePage({{"visited", 1}}, "same")}, {page = nativePage({{"visited", 1}}, "same")}},
        {{page = nativePage({{"one", 1}})}, {page = nativePage({{"two", 2}}, "same")}, {page = nativePage({{"two", 2}}, "same")}},
    }) do
        local native = deviceNativeFixture(pages)
        assert(native.Pick("current", {visited = 100}) == nil)
    end
end)
test("device expired catalogue cannot reuse servers from the previous arrival", function()
    local native, _, clock = deviceNativeFixture({
        {page = nativePage({{"one", 1}})}, {page = nativePage({{"one", 1}})},
        {page = nativePage({{"two", 2}})}, {page = nativePage({{"two", 2}})},
    })
    assert(native.Pick("current", {})[1].id == "one")
    clock(281)
    assert(native.Pick("current", {})[1].id == "two")
end)
local function requestFixture(shared, delay)
    local clock, live, queued = 100, true, {}
    local env = {now = function() return clock end, clock = function() return clock end,
        spawn = function(callback) table.insert(queued, {at = clock + (delay or 0), callback = callback}) end,
        wait = function(seconds)
            clock += seconds
            for index = #queued, 1, -1 do
                if queued[index].at <= clock then local work = table.remove(queued, index); work.callback() end
            end
        end}
    local transport = support.DeviceRequest(env, shared)
    return transport, env, function() return live end, function() live = false end
end
test("account validation waits through the full saved sixty second cooldown", function()
    local shared = {last = 100, cooldown = 160}
    local transport, env, alive = requestFixture(shared)
    local calls, updates = 0, {}
    local page = transport.Run(function()
        calls += 1; assert(env.now() >= 160); return {data = {}}, nil, 200
    end, alive, function(state) table.insert(updates, state) end)
    assert(page and calls == 1 and not shared.busy)
    assert(updates[1].kind == "rate_limit" and updates[1].seconds == 60)
    assert(env.now() >= 160 and env.now() < 161)
end)
test("normal spacing reports interval without inventing Roblox rate limiting", function()
    local shared = {last = 100, cooldown = 0}
    local transport, env, alive = requestFixture(shared)
    local state
    assert(transport.Run(function() assert(env.now() >= 115); return {data = {}}, nil, 200 end, alive,
        function(value) state = state or value end))
    assert(state.kind == "interval" and state.seconds == 15)
    assert(not support.DeviceWaitMessage(state):find("429", 1, true))
end)
test("429 retry waits sixty seconds and retains a single request reservation", function()
    local shared = {last = 0, cooldown = 0}
    local transport, env, alive = requestFixture(shared)
    local _, _, status = transport.Run(function() return nil, "rate limited", 429 end, alive)
    assert(status == 429 and shared.cooldown >= 160 and not shared.busy)
    local calls = 0
    local page = transport.Run(function() calls += 1; assert(env.now() >= shared.cooldown); return {data = {}}, nil, 200 end, alive)
    assert(page and calls == 1 and transport.State().lastHttpStatus == 200)
end)
test("pending native HTTP stays locked on timeout until it actually finishes", function()
    local shared = {last = 0, cooldown = 0}
    local transport, env, alive = requestFixture(shared, 45)
    local calls = 0
    local function send() calls += 1; return {data = {}}, nil, 200 end
    local page, reason = transport.Run(send, alive)
    assert(not page and shared.busy and calls == 0 and reason:find("executor", 1, true))
    page, reason = transport.Run(send, alive)
    assert(not page and calls == 0 and shared.busy and not reason:find("Roblox respondio HTTP 429", 1, true))
    env.wait(15)
    assert(calls == 1 and not shared.busy)
end)
test("executor exception and spawn failure release reservation without secret errors", function()
    local shared = {last = 0, cooldown = 0}
    local transport, env, alive = requestFixture(shared)
    local page, reason = transport.Run(function() error("fake-secret") end, alive)
    assert(not page and not shared.busy and not reason:find("fake-secret", 1, true))
    shared.last = 0
    env.spawn = function() error("fake-secret") end
    page, reason = transport.Run(function() return {} end, alive)
    assert(not page and not shared.busy and not reason:find("fake-secret", 1, true))
end)
test("cancelled initial validation during cooldown sends no credential", function()
    local shared = {last = 100, cooldown = 160}
    local transport, _, alive, cancel = requestFixture(shared)
    local calls = 0
    local page = transport.Run(function() calls += 1; return {} end, alive, function() cancel() end)
    assert(not page and calls == 0 and not shared.busy)
end)
test("legacy pending request on rerun waits but never clears another reservation", function()
    local shared = {last = 100, cooldown = 0, busy = true}
    local transport, _, alive = requestFixture(shared)
    local calls = 0
    local page, reason = transport.Run(function() calls += 1; return {} end, alive)
    assert(not page and shared.busy == true and calls == 0 and reason:find("executor", 1, true))
end)
test("completion cannot unlock an unrelated newer reservation", function()
    local shared = {last = 0, cooldown = 0}
    local transport, _, alive = requestFixture(shared)
    local replacement = {started = 110}
    assert(transport.Run(function() shared.busy = replacement; return {data = {}}, nil, 200 end, alive))
    assert(shared.busy == replacement)
end)
print(string.format("%d regression tests passed", passed))
