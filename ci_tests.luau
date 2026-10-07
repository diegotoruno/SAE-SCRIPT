-- Behavioral regression tests: no executor, network, Roblox account or teleports.
local factory = require("./map_egg_search")
setfenv(factory, setmetatable({task = {spawn = function() end}}, {__index = getfenv(factory)}))
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
print(string.format("%d regression tests passed", passed))
