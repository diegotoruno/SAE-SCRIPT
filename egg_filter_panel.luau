-- Panel de filtros del detector. Recursos visuales y datos del propio juego.
local function mountEggFilterPanel(context)
    local search, api, session = context.search, context.api, context.session
    local readJson, writeJson = context.readJson, context.writeJson
    local UIS = game:GetService("UserInputService")
    local FILE = "chilli_egg_panel_ui.json"
    local saved = readJson(FILE, {})
    local panel = { alive = true, open = saved.open ~= false, view = "map", cards = 0 }
    local onlyMatches = saved.onlyMatches == true
    local connections = {}
    local C = {
        bg = Color3.fromRGB(25, 27, 36), card = Color3.fromRGB(40, 43, 55),
        input = Color3.fromRGB(20, 22, 30), border = Color3.fromRGB(83, 88, 110),
        white = Color3.fromRGB(247, 249, 255), muted = Color3.fromRGB(171, 180, 201),
        green = Color3.fromRGB(122, 255, 40), red = Color3.fromRGB(245, 54, 64),
        cyan = Color3.fromRGB(69, 201, 255), gold = Color3.fromRGB(255, 226, 80),
    }
    local function access() if type(setthreadidentity) == "function" then setthreadidentity(8) end end
    access()
    local function make(class, name, parent, properties)
        access()
        local object = Instance.new(class)
        object.Name = name
        for key, value in pairs(properties or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function corner(object, radius) make("UICorner", "Round", object, { CornerRadius = UDim.new(0, radius or 6) }) end
    local function stroke(object, color, thickness)
        return make("UIStroke", "Border", object, { Color = color or C.border, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    end
    local function text(name, parent, value, x, y, width, height, color, size, bold)
        return make("TextLabel", name, parent, {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            Text = value, TextColor3 = color or C.white, TextSize = size or 14,
            Font = bold and Enum.Font.FredokaOne or Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            TextStrokeColor3 = Color3.new(), TextStrokeTransparency = bold and 0.35 or 1,
        })
    end
    local function button(name, parent, value, x, y, width, height, color)
        local object = make("TextButton", name, parent, {
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = color or C.card, BorderSizePixel = 0, Text = value,
            TextSize = 15, Font = Enum.Font.FredokaOne, TextColor3 = C.white,
            TextStrokeTransparency = 0.35, TextStrokeColor3 = Color3.new(), AutoButtonColor = true,
        })
        corner(object); stroke(object)
        return object
    end
    local function connect(signal, callback)
        local c = signal:Connect(function(...) access(); callback(...) end)
        table.insert(connections, c)
        return c
    end
    local function number(value)
        if value >= 1e12 then return string.format("%.2fT", value / 1e12) end
        if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
        if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
        if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
        return string.format("%.0f", value)
    end
    local function cloneConfig(config)
        local copy = table.clone(config); copy.categories = table.clone(config.categories or {}); return copy
    end
    local draft = cloneConfig(search.config)
    local selection = {}; for _, id in ipairs(draft.categories) do selection[id] = true end
    local function selectionList()
        local list = {}; for id, selected in pairs(selection) do if selected then table.insert(list, id) end end
        table.sort(list); return list
    end
    local dirty, signature, popup, data = false, nil, nil, nil
    local function sameConfig(a, b)
        if a.rarity ~= b.rarity or a.minIncome ~= b.minIncome or a.mutation ~= b.mutation or a.nameContains ~= b.nameContains then return false end
        if #(a.categories or {}) ~= #(b.categories or {}) then return false end
        for i, id in ipairs(a.categories or {}) do if id ~= b.categories[i] then return false end end
        return true
    end
    local visual = saved.visual or "eggs"
    if visual ~= "eggs" and visual ~= "pets" and visual ~= "models" then visual = "eggs" end
    local sortBest, filtersOpen = saved.sortBest ~= false, saved.filtersOpen ~= false
    local root = make("Frame", "EggFilterPanel", context.screenGui, {
        Size = UDim2.fromOffset(540, 700), Position = UDim2.fromOffset(800, 70),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = panel.open, Active = true,
        ClipsDescendants = true, ZIndex = 10,
    })
    corner(root, 9); stroke(root, C.border, 2)
    local scale = make("UIScale", "ResponsiveScale", root, { Scale = 1 })
    local launcher = button("OpenEggFilters", context.screenGui, "EGG FILTERS", 0, 0, 150, 36, C.red)
    launcher.AnchorPoint = Vector2.new(1, 0); launcher.Position = UDim2.new(1, -18, 0, 18); launcher.ZIndex = 20
    launcher.Visible = not panel.open
    local header = make("Frame", "Header", root, { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.red, BorderSizePixel = 0, Active = true })
    make("UIGradient", "RedGradient", header, { Rotation = 0, Color = ColorSequence.new(C.red, Color3.fromRGB(165, 27, 50)) })
    text("Title", header, "Egg Finder", 16, 5, 220, 30, C.white, 28, true)
    text("Subtitle", header, "Solo huevos del mapa", 18, 34, 230, 15, C.white, 11)
    local auto = button("ToggleSearch", header, "AUTO", 353, 10, 134, 34, C.green)
    local minimize = button("Minimize", header, "−", 496, 10, 30, 34)
    local stateTitle = text("SearchState", root, "Conectando detector...", 16, 64, 355, 24, C.white, 19, true)
    local clock = text("ResetClock", root, "RESET --:--", 386, 64, 138, 24, C.cyan, 17, true)
    local stateDetail = text("SearchDetail", root, "Divine · mínimo 7B/s", 16, 91, 390, 18, C.muted, 12)
    local filterToggle = button("ToggleFilters", root, "Filtros −", 428, 93, 96, 24)
    local filters = make("Frame", "Filters", root, { Position = UDim2.fromOffset(14, 124), Size = UDim2.fromOffset(512, 168), BackgroundColor3 = C.card, BorderSizePixel = 0 })
    corner(filters); stroke(filters)
    text("RarityLabel", filters, "RAREZA", 12, 10, 135, 16, C.muted, 10)
    text("IncomeLabel", filters, "MÍNIMO /s · k m b t q", 170, 10, 130, 16, C.muted, 10)
    text("MutationLabel", filters, "MUTACIÓN", 306, 10, 184, 16, C.muted, 10)
    local rarityButton = button("Rarity", filters, draft.rarity .. " ▾", 12, 31, 144, 34)
    local income = make("TextBox", "MinimumIncome", filters, {
        Position = UDim2.fromOffset(170, 31), Size = UDim2.fromOffset(122, 34),
        BackgroundColor3 = C.input, BorderSizePixel = 0, Text = search.FormatMinimum(draft.minIncome),
        PlaceholderText = "Ej. 7b", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.green,
        ClearTextOnFocus = false,
    })
    corner(income); stroke(income)
    local mutationButton = button("Mutation", filters, draft.mutation == "" and "Todas ▾" or draft.mutation .. " ▾", 306, 31, 194, 34)
    local nameBox = make("TextBox", "NameFilter", filters, {
        Position = UDim2.fromOffset(12, 78), Size = UDim2.fromOffset(330, 32), BackgroundColor3 = C.input,
        BorderSizePixel = 0, Text = draft.nameContains, PlaceholderText = "Buscar / filtrar por nombre...",
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.white, PlaceholderColor3 = C.muted,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(nameBox); stroke(nameBox); make("UIPadding", "Padding", nameBox, { PaddingLeft = UDim.new(0, 10) })
    local clear = button("AllSpecies", filters, "Todas las especies", 354, 78, 146, 32)
    local selectionLabel = text("Selection", filters, "Todas las especies", 12, 121, 310, 18, C.cyan, 12)
    local changeLabel = text("Changes", filters, "Filtros guardados", 12, 142, 316, 14, C.muted, 10)
    local apply = button("ApplyFilters", filters, "Aplicar filtros", 354, 122, 146, 32, C.green)
    local tabMap = button("MapTab", root, "Mapa", 14, 304, 131, 30)
    local tabCatalog = button("CatalogTab", root, "Solo filtro: OFF", 153, 304, 126, 30)
    local visualButton = button("VisualMode", root, "Huevos", 288, 304, 108, 30)
    local sortButton = button("Sort", root, "Rareza ↓", 404, 304, 122, 30)
    local scroll = make("ScrollingFrame", "EggCards", root, {
        Position = UDim2.fromOffset(14, 344), Size = UDim2.fromOffset(512, 304), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.border,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    make("UIListLayout", "Layout", scroll, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    make("UIPadding", "Padding", scroll, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) })
    local foot = text("Hint", root, "Toca una tarjeta para elegir especies; luego aplica los filtros.", 16, 658, 510, 24, C.muted, 11)
    local chooseSpecies = button("ChooseSpecies", filters, "Elegir especies ▾", 12, 119, 154, 27)
    selectionLabel.Position = UDim2.fromOffset(174, 121); selectionLabel.Size = UDim2.fromOffset(170, 18)
    local function save()
        access()
        writeJson(FILE, { open = panel.open, visual = visual, filtersOpen = filtersOpen,
            view = "map", onlyMatches = onlyMatches, sortBest = sortBest,
            x = root.Position.X.Offset, y = root.Position.Y.Offset })
    end
    local function closePopup() if popup then popup:Destroy(); popup = nil end end
    local function layout()
        access()
        filters.Visible = filtersOpen; filterToggle.Text = filtersOpen and "Filtros −" or "Filtros +"
        local y = filtersOpen and 304 or 130
        for _, b in ipairs({tabCatalog, tabMap, visualButton, sortButton}) do b.Position = UDim2.fromOffset(b.Position.X.Offset, y) end
        scroll.Position = UDim2.fromOffset(14, y + 40); scroll.Size = UDim2.fromOffset(512, 608 - y)
        closePopup(); signature = nil
    end
    local initializedPosition = false
    local function fit()
        access()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = math.min(1, (viewport.X - 28) / 540, (viewport.Y - 28) / 700)
        local width, height = 540 * scale.Scale, 700 * scale.Scale
        if not initializedPosition then
            root.Position = UDim2.fromOffset(tonumber(saved.x) or viewport.X - width - 20, tonumber(saved.y) or math.max(14, (viewport.Y - height) / 2))
            initializedPosition = true
        end
        root.Position = UDim2.fromOffset(math.clamp(root.Position.X.Offset, 8, math.max(8, viewport.X - width - 8)),
            math.clamp(root.Position.Y.Offset, 8, math.max(8, viewport.Y - height - 8)))
    end
    function panel.Open() access(); panel.open = true; root.Visible = true; launcher.Visible = false; signature = nil; fit(); save() end
    function panel.Close() access(); panel.open = false; root.Visible = false; launcher.Visible = true; closePopup(); save() end
    local function markDirty()
        access()
        dirty = true; signature = nil
        local count = #selectionList()
        selectionLabel.Text = count == 0 and "Todas las especies" or string.format("%d especies seleccionadas", count)
        changeLabel.Text = "Cambios sin aplicar"; changeLabel.TextColor3 = C.gold
    end
    local function setDraft(config)
        local minimumText = search.FormatMinimum(config.minIncome)
        access()
        draft = cloneConfig(config); selection = {}; for _, id in ipairs(draft.categories) do selection[id] = true end
        income.Text = minimumText; nameBox.Text = draft.nameContains
        rarityButton.Text = draft.rarity .. " ▾"
        mutationButton.Text = draft.mutation == "" and "Todas ▾" or draft.mutation .. " ▾"
        local count = #draft.categories
        selectionLabel.Text = count == 0 and "Todas las especies" or string.format("%d especies seleccionadas", count)
        dirty = false; changeLabel.Text = "Filtros guardados"; changeLabel.TextColor3 = C.muted; signature = nil
    end
    function panel.Apply()
        access()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if not minimum then
            changeLabel.Text = "Mínimo inválido: usa 500k, 25m o 7.5b"; changeLabel.TextColor3 = C.red; return false
        end
        local patch = { rarity = draft.rarity, minIncome = minimum, mutation = draft.mutation,
            nameContains = nameBox.Text, categories = selectionList() }
        local ok, config = pcall(api.Configure, patch)
        access()
        if not ok then changeLabel.Text = tostring(config); changeLabel.TextColor3 = C.red; return false end
        setDraft(config); closePopup(); return true
    end
    function panel.SelectCategory(id)
        access(); assert(search.modules and search.modules.assets.Directory[id], "Especie desconocida")
        selection[id] = not selection[id]; markDirty()
    end
    function panel.SetView(view) access(); assert(view == "map", "El panel principal solo muestra el mapa"); panel.view = "map"; signature = nil; closePopup(); save() end
    function panel.SetVisual(mode)
        access(); assert(mode == "eggs" or mode == "pets" or mode == "models")
        visual = mode; signature = nil; save()
    end
    local function dropdown(anchor, options, select)
        if popup then closePopup(); return end
        popup = make("Frame", "Dropdown", root, { Position = UDim2.fromOffset(14, 192), Size = UDim2.fromOffset(512, 310), BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 60 })
        corner(popup); stroke(popup, C.cyan, 2)
        text("Prompt", popup, anchor == rarityButton and "Elige una rareza" or "Elige una mutación", 12, 5, 440, 24, C.white, 17, true).ZIndex = 61
        local dismiss = button("Dismiss", popup, "×", 466, 5, 32, 26); dismiss.ZIndex = 62
        dismiss.Activated:Connect(function() access(); closePopup() end)
        local list = make("ScrollingFrame", "Options", popup, { Position = UDim2.fromOffset(8, 36), Size = UDim2.fromOffset(496, 266), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ScrollBarThickness = 4, BorderSizePixel = 0, ZIndex = 61 })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 4) })
        for index, item in ipairs(options) do
            local b = button("Option_" .. index, list, item.label, 0, 0, 482, 30)
            b.ZIndex = 62; b.LayoutOrder = index
            b.Activated:Connect(function() access(); select(item.id); closePopup(); markDirty() end)
        end
    end
    local function cleanupCards()
        access()
        for _, child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    end
    local function speciesPicker()
        if popup then closePopup(); return end
        if not search.modules then return end
        popup = make("Frame", "SpeciesPicker", root, { Position = UDim2.fromOffset(14, 132), Size = UDim2.fromOffset(512, 508), BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 60 })
        corner(popup); stroke(popup, C.cyan, 2)
        text("Title", popup, "Elegir especies · catálogo", 12, 8, 438, 25, C.white, 21, true).ZIndex = 61
        text("Hint", popup, "Esto selecciona filtros; no representa huevos del mapa.", 12, 38, 486, 18, C.muted, 11).ZIndex = 61
        local done = button("Done", popup, "×", 466, 8, 32, 28); done.ZIndex = 62
        done.Activated:Connect(function() access(); closePopup() end)
        local list = make("ScrollingFrame", "Species", popup, { Position = UDim2.fromOffset(10, 65), Size = UDim2.fromOffset(492, 432), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ScrollBarThickness = 4, BorderSizePixel = 0, ZIndex = 61 })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
        local options = {}
        for id, catalog in pairs(search.modules.assets.Directory) do
            if catalog.Rarity._id == draft.rarity then table.insert(options, {id = id, catalog = catalog}) end
        end
        table.sort(options, function(a, b) return a.catalog.DisplayName < b.catalog.DisplayName end)
        for index, option in ipairs(options) do
            local b = button("Species_" .. option.id, list, "", 0, 0, 480, 64)
            b.ZIndex = 62; b.LayoutOrder = index
            make("ImageLabel", "EggIcon", b, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(56, 56), Image = option.catalog.Egg.Icon, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 63 })
            text("Name", b, option.catalog.DisplayName, 72, 7, 348, 25, C.gold, 18, true).ZIndex = 63
            text("BaseIncome", b, number(option.catalog.EarningRate) .. "/s base · x1.00", 72, 35, 348, 19, C.muted, 12).ZIndex = 63
            local check = text("Check", b, selection[option.id] and "✓" or "+", 436, 14, 32, 32, C.cyan, 28, true); check.ZIndex = 63
            b.BackgroundColor3 = selection[option.id] and Color3.fromRGB(41, 57, 44) or C.card
            b.Activated:Connect(function()
                access(); panel.SelectCategory(option.id); check.Text = selection[option.id] and "✓" or "+"
                b.BackgroundColor3 = selection[option.id] and Color3.fromRGB(41, 57, 44) or C.card
            end)
        end
    end
    panel.OpenSpecies = function() access(); speciesPicker() end
    local function rarityColor(rarity)
        local color = rarity and rarity.Color
        -- Secret usa gris casi negro en el juego; aclararlo conserva la legibilidad.
        if typeof(color) == "Color3" then return color:Lerp(C.white, 0.25) end
        return C.gold
    end
    local function buildCards()
        local modules = search.modules
        if not modules or not data then return end
        local rows, fingerprint = {}, { "map", visual, tostring(onlyMatches), tostring(sortBest), table.concat(selectionList(), ",") }
        access()
        local firstVisible = math.max(1, math.floor(scroll.CanvasPosition.Y / 112))
        local lastVisible = firstVisible + math.ceil(scroll.AbsoluteSize.Y / math.max(0.1, scale.Scale) / 112) + 2
        if visual == "models" then table.insert(fingerprint, tostring(firstVisible) .. ":" .. tostring(lastVisible)) end
        do
            local cycle = search.CycleStatus()
            if search.resetting or (cycle and cycle.night) or not modules.eggs.HasFieldSnapshot() then
                table.insert(fingerprint, "reset")
            else
                local matches = {}
                local _, _, all = search.Scan(); for _, m in ipairs(all or {}) do matches[m.uid] = true end
                for _, egg in pairs(modules.eggs.ReadFieldEggs().Records) do
                    local catalog = modules.assets.Directory[egg.AssetCategory]
                    if egg.State == "Slot" and catalog and (not onlyMatches or matches[egg.Uid]) then
                        local ok, rate = pcall(function() return modules.earnings.MutationOnlyRatePerSecond(modules.records.ToAssetItemData(egg)) end)
                        local weightOk, weight = pcall(modules.records.WeightLabel, egg)
                        local iconOk, icon = pcall(modules.records.EggIcon, egg)
                        local rarity = modules.rarities.Rarities[catalog.Rarity._id]
                        local labels = {}; for _, id in ipairs(egg.Mutations or {}) do table.insert(labels, data.mutations.LabelOf(id)) end
                        table.insert(rows, { uid = egg.Uid, category = egg.AssetCategory, catalog = catalog,
                            rarityRank = rarity and rarity.Rank or 0,
                            income = ok and rate or nil, scale = egg.AssetScale, weight = weightOk and weight or "peso no disponible",
                            mutations = #labels > 0 and table.concat(labels, " + ") or "Sin mutaciones",
                            area = egg.AreaId, match = matches[egg.Uid], eggIcon = iconOk and icon or nil })
                    end
                end
            end
        end
        table.sort(rows, function(a, b)
            if sortBest and a.rarityRank ~= b.rarityRank then return a.rarityRank > b.rarityRank end
            if sortBest and (a.income or 0) ~= (b.income or 0) then return (a.income or 0) > (b.income or 0) end
            if a.category ~= b.category then return a.category < b.category end
            return tostring(a.uid) < tostring(b.uid)
        end)
        for _, row in ipairs(rows) do table.insert(fingerprint, table.concat({row.uid or row.category, tostring(row.rarityRank), tostring(row.income), tostring(row.scale), row.mutations, tostring(row.match)}, ":")) end
        local key = table.concat(fingerprint, "|")
        if key == signature then return end
        signature = key; cleanupCards(); panel.cards = #rows
        if #rows == 0 then
            local cycle = search.CycleStatus()
            local message = onlyMatches and "Ningún huevo actual cumple los filtros guardados.\nEsperando la próxima renovación." or "No hay spawns disponibles en el mapa."
            if panel.view == "map" and (search.resetting or (cycle and cycle.night)) then message = "Renovando huevos...\nEsperando los nuevos spawns." end
            local empty = text("Empty", scroll, message, 0, 0, 494, 130, C.muted, 16)
            empty.TextWrapped = true; empty.TextXAlignment = Enum.TextXAlignment.Center
            return
        end
        for index, row in ipairs(rows) do
            local selected = selection[row.category] == true
            local card = make("TextButton", "Card_" .. (row.uid or row.category), scroll, {
                Size = UDim2.new(1, -2, 0, 104), BackgroundColor3 = selected and Color3.fromRGB(41, 57, 44) or C.card,
                BorderSizePixel = 0, Text = "", AutoButtonColor = true, LayoutOrder = index,
            })
            corner(card, 7); stroke(card, row.match and C.green or selected and C.cyan or C.border, row.match and 2 or 1)
            local box = make("Frame", "Visual", card, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(88, 88), BackgroundColor3 = C.input, BorderSizePixel = 0 })
            corner(box)
            local icon = visual == "pets" and row.catalog.Icon or row.eggIcon or row.catalog.Egg.Icon
            local image = make("ImageLabel", "EggImage", box, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = icon or "", ScaleType = Enum.ScaleType.Fit })
            if visual == "models" and index >= firstVisible and index <= lastVisible then
                local ok, model = pcall(function()
                    local originalModel = data.assetModels.GetAssetModelIfReplicated(row.category)
                    if not originalModel then return nil end
                    access()
                    local viewport = make("ViewportFrame", "AssetViewport", box, {
                        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                        Ambient = Color3.fromRGB(210, 210, 230), LightColor = C.white,
                        LightDirection = Vector3.new(-1, -1, -1),
                    })
                    local world = make("WorldModel", "PreviewWorld", viewport)
                    local rig = originalModel:Clone()
                    for _, child in ipairs(rig:GetDescendants()) do
                        if child:IsA("LuaSourceContainer") or child:IsA("Sound") then child:Destroy()
                        elseif child:IsA("BasePart") then child.Anchored = true; child.CanCollide = false end
                    end
                    rig.Parent = world; rig:PivotTo(CFrame.new())
                    local bounds, size = rig:GetBoundingBox()
                    local distance = math.max(0.1, size.X, size.Y, size.Z) * 1.8
                    local camera = make("Camera", "PreviewCamera", viewport, {
                        FieldOfView = 35, CFrame = CFrame.lookAt(bounds.Position + Vector3.new(distance * 0.8, distance * 0.45, distance), bounds.Position),
                    })
                    viewport.CurrentCamera = camera
                    return rig
                end)
                access()
                image.Visible = not (ok and model ~= nil)
            end
            local name = text("Name", card, row.catalog.DisplayName or row.category, 108, 8, 326, 23, rarityColor(row.catalog.Rarity), 19, true)
            name.Size = UDim2.new(1, -166, 0, 23)
            text("Income", card, (row.income and number(row.income) or "?") .. "/s", 108, 32, 314, 20, C.green, 17, true)
            text("SizeWeight", card, string.format("x%.2f  ·  %s", row.scale or 1, row.weight), 108, 54, 320, 18, C.cyan, 13, true)
            text("MutationsArea", card, row.catalog.Rarity._id .. " · " .. row.mutations .. (row.area and " · " .. row.area or ""), 108, 77, 355, 17, C.muted, 11)
            local badge = text("Selected", card, selected and "✓" or "+", 450, 8, 36, 32, selected and C.cyan or C.muted, 28, true)
            badge.TextXAlignment = Enum.TextXAlignment.Center
            if panel.view == "map" then text("Match", card, row.match and "CUMPLE" or "FUERA", 430, 47, 60, 20, row.match and C.green or C.gold, 12, true) end
            card.Activated:Connect(function() access(); panel.SelectCategory(row.category) end)
        end
    end
    function panel.GetStatus()
        access(); return { open = panel.open, view = "map", onlyMatches = onlyMatches, cards = panel.cards, dirty = dirty, error = panel.error,
            selected = selectionList(), visual = visual, position = {x = root.AbsolutePosition.X, y = root.AbsolutePosition.Y},
            size = {x = root.AbsoluteSize.X, y = root.AbsoluteSize.Y}, scale = scale.Scale }
    end
    function panel.Destroy()
        if not panel.alive then return end
        access(); panel.alive = false
        for _, c in ipairs(connections) do c:Disconnect() end
        table.clear(connections); cleanupCards(); root:Destroy(); launcher:Destroy()
    end
    connect(auto.Activated, function()
        panel.autoTouched = true
        if api.GetStatus().active then api.Stop()
        elseif not dirty or panel.Apply() then api.Start() end
    end)
    connect(minimize.Activated, panel.Close); connect(launcher.Activated, panel.Open)
    connect(filterToggle.Activated, function() filtersOpen = not filtersOpen; layout(); save() end)
    connect(apply.Activated, panel.Apply)
    connect(clear.Activated, function() selection = {}; markDirty() end)
    connect(income:GetPropertyChangedSignal("Text"), function()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if minimum ~= draft.minIncome then markDirty() end
    end)
    connect(nameBox:GetPropertyChangedSignal("Text"), function()
        if nameBox.Text ~= draft.nameContains then markDirty() end
    end)
    connect(chooseSpecies.Activated, function() panel.OpenSpecies() end)
    connect(tabCatalog.Activated, function() onlyMatches = not onlyMatches; signature = nil; save() end)
    connect(tabMap.Activated, function() onlyMatches = false; signature = nil; save() end)
    connect(sortButton.Activated, function() sortBest = not sortBest; sortButton.Text = sortBest and "Rareza ↓" or "Nombre A–Z"; signature = nil; save() end)
    connect(visualButton.Activated, function() panel.SetVisual(visual == "eggs" and "pets" or visual == "pets" and "models" or "eggs") end)
    connect(rarityButton.Activated, function()
        if not search.modules then return end
        local options = search.RarityOptions()
        dropdown(rarityButton, options, function(id) draft.rarity = id; rarityButton.Text = id .. " ▾"; selection = {} end)
    end)
    connect(mutationButton.Activated, function()
        if not data then return end
        local options = {}; for id in pairs(data.mutations.IdSet) do table.insert(options, { id = id, label = data.mutations.LabelOf(id) }) end
        table.sort(options, function(a, b) return a.label < b.label end)
        table.insert(options, 1, { id = "", label = "Todas las mutaciones" })
        dropdown(mutationButton, options, function(id) draft.mutation = id; mutationButton.Text = id == "" and "Todas ▾" or data.mutations.LabelOf(id) .. " ▾" end)
    end)
    local dragging, dragStart, original
    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, original = true, input.Position, root.Position
        end
    end)
    connect(UIS.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            root.Position = UDim2.fromOffset(original.X.Offset + delta.X, original.Y.Offset + delta.Y); fit()
        end
    end)
    connect(UIS.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragging = false; save() end
    end)
    layout(); fit(); setDraft(search.config)
    task.spawn(function()
        access()
        local ok, result = pcall(function()
            local R = game:GetService("ReplicatedStorage")
            return { mutations = require(R.Shared.Modules.Mutations), assetModels = require(R.Shared.Modules.AssetModels) }
        end)
        access()
        if ok then data = result else changeLabel.Text = "No cargaron recursos visuales"; warn("[EggPanel] " .. tostring(result)) end
        while panel.alive and session.alive do
            local updated, problem = pcall(function()
            access()
            local status = api.GetStatus()
            access()
            if not dirty and not sameConfig(draft, status.config) then setDraft(status.config) end
            auto.Text = status.active and "AUTO: ON" or "AUTO: OFF"
            auto.BackgroundColor3 = status.active and C.green or C.red
            visualButton.Text = visual == "eggs" and "Huevos" or visual == "pets" and "Criaturas" or "Modelos 3D"
            sortButton.Text = sortBest and "Rareza ↓" or "Nombre A–Z"
            tabCatalog.Text = onlyMatches and "Solo filtro: ON" or "Solo filtro: OFF"
            tabCatalog.BackgroundColor3 = onlyMatches and Color3.fromRGB(58, 74, 100) or C.card
            tabMap.BackgroundColor3 = not onlyMatches and Color3.fromRGB(58, 74, 100) or C.card
            foot.Text = "Spawns actuales del mapa · CUMPLE usa los filtros guardados."
            local cycle = status.cycle
            local info = status.lastScan and status.lastScan.info or {}
            tabMap.Text = string.format("Mapa · %d", info.count or 0)
            local titles = { wait = "Esperando huevos nuevos", hop = "Buscando otro servidor", loading = "Esperando renovación / datos", match = "Objetivo encontrado", stopped = "Búsqueda detenida" }
            stateTitle.Text = titles[status.mode] or "Escaneando mapa"
            stateTitle.TextColor3 = status.mode == "match" and C.green or C.white
            stateDetail.Text = string.format("%s · ≥ %s/s · %d en mapa · %d de esa rareza", status.config.rarity, number(status.config.minIncome), info.count or 0, info.rarityCount or 0)
            if cycle then
                local seconds = math.ceil(cycle.secondsUntilReset)
                clock.Text = cycle.night and "RENOVANDO" or string.format("RESET %d:%02d", math.floor(seconds / 60), seconds % 60)
                if not cycle.running then clock.Text = "CICLO PAUSADO" end
            end
            if panel.open then fit(); buildCards() end
            end)
            if not updated then
                if panel.error ~= tostring(problem) then warn("[EggPanel] " .. tostring(problem)) end
                panel.error = tostring(problem)
            else panel.error = nil end
            task.wait(1)
        end
    end)
    api.OpenPanel = panel.Open; api.ClosePanel = panel.Close; api.PanelStatus = panel.GetStatus
    api.Panel = panel
    print("[EggPanel] Panel de filtros listo")
    return panel
end

return mountEggFilterPanel
