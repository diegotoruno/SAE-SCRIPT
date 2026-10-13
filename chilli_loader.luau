-- Chilli Hub para Steal An Egg: misma version que la linea original, antes.
--
-- 1. Mientras el juego carga, descarga el dispatcher de Chilli y el script de
--    este juego y deja hecha la descompresion Luraph (~1 s de CPU). Siempre
--    pide la version actual: no hay cache en disco.
-- 2. Ejecuta Chilli cuando el juego cargo, ReplicatedStorage.Shared existe y el
--    personaje tiene Humanoid y HumanoidRootPart. Antes, sus requires rompen
--    modulos del juego, y arrancar sin personaje completo hace mas probable su
--    error "Bound Humanoid must belong to the current character".
-- Si el atajo no aplica (otro formato o un fallo), ejecuta el dispatcher
-- original. No vuelve a cargar Chilli si ya esta en el servidor.
local DISPATCHER = "https://raw.githubusercontent.com/tienkhanh1/spicy/main/Chilli.lua"

local function chilliPresent()
    local ok, found = pcall(function()
        local root = gethui()
        return root:FindFirstChild("ChilliHubLoading") or root:FindFirstChild("ChilliLeftCenter")
    end)
    return ok and found ~= nil
end
if chilliPresent() then
    return
end

local function httpGet(url)
    for attempt = 1, 3 do
        local ok, body = pcall(game.HttpGet, game, url)
        if ok and type(body) == "string" and body ~= "" then
            return body
        end
        if attempt < 3 then task.wait(0.5) end
    end
    return nil
end

-- Mismo criterio que el dispatcher: GameId y, si no, PlaceId.
local function scriptUrl(dispatcher)
    local deadline = os.clock() + 15
    while game.GameId == 0 and game.PlaceId == 0 and os.clock() < deadline do
        task.wait()
    end
    for _, id in ipairs({ game.GameId, game.PlaceId }) do
        local name = string.match(dispatcher, "%[" .. tostring(id) .. "%]%s*=%s*([%a_][%w_]*)")
        local url = name and string.match(dispatcher, "local%s+" .. name .. '%s*=%s*"([^"]+)"')
        if url then return url end
    end
    return nil
end

-- Un script Luraph termina en "):u()(...)": u() descomprime y devuelve la
-- funcion principal, que todavia no toca el juego.
local function prepare(source)
    local cut, _, method = string.find(source, "%):([%a_][%w_]*)%(%)%(%.%.%.%);?%s*$")
    if cut then
        local outer = loadstring(string.sub(source, 1, cut - 1) .. "):" .. method .. "()")
        if outer then
            local ok, main = pcall(outer)
            if ok and type(main) == "function" then
                return main
            end
        end
    end
    return loadstring(source)
end

local prepared = { done = false, fn = nil }
task.spawn(function()
    local ok, err = pcall(function()
        local dispatcher = httpGet(DISPATCHER)
        local url = dispatcher and scriptUrl(dispatcher)
        local source = url and httpGet(url)
        if source then
            prepared.fn = prepare(source)
        end
    end)
    if not ok then warn("[ChilliLoader] Precarga fallida: " .. tostring(err)) end
    prepared.done = true
end)

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
while not player do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end
game:GetService("ReplicatedStorage"):WaitForChild("Shared", 30)

local deadline = os.clock() + 30
while os.clock() < deadline do
    local character = player.Character
    if character and character:FindFirstChildOfClass("Humanoid") and character:FindFirstChild("HumanoidRootPart") then
        break
    end
    task.wait()
end

deadline = os.clock() + 20
while not prepared.done and os.clock() < deadline do
    task.wait()
end
if chilliPresent() then
    return
end

local main = prepared.fn
if not main then
    local dispatcher = httpGet(DISPATCHER)
    main = dispatcher and loadstring(dispatcher)
end
if not main then
    warn("[ChilliLoader] No se pudo descargar Chilli.")
    return
end
local ok, err = pcall(main)
if not ok then
    warn("[ChilliLoader] Chilli fallo al iniciar: " .. tostring(err))
end
