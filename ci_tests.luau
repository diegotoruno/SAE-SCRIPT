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
test("unwritable filters do not silently apply", function()
    local failed = factory(function() return {} end, function() return false end)
    assert(not pcall(failed.Configure, {minIncome = 8e9}))
    assert(failed.config.minIncome == 7e9)
end)
print(string.format("%d regression tests passed", passed))
