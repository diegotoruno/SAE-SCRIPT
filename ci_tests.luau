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
    assert(finder.Scan().rarity == "Divine" and state.reads == 1)
    assert(finder.Scan(true).rarity == "Divine" and state.reads == 2)
end)
test("map snapshot includes higher matches and the correct reason", function()
    local finder, state = minimumFixture()
    state.records = {egg("d", 7e9), egg("c", 99e9, "common")}
    local snapshot = finder.MapSnapshot()
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
print(string.format("%d regression tests passed", passed))
