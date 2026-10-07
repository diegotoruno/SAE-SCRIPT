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
    local dirty, signature, popup, data = false, nil, nil, {}
    local entries, metadata, orderedRows, rowsKey = {}, {}, {}, nil
    local renderScheduled = false
    panel.stats = {created = 0, updated = 0, modelsCreated = 0, rendered = 0, lastMs = 0}
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
    local optionsButton = button("Options", header, "Opciones", 238, 10, 105, 34)
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
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
    })

    make("UIPadding", "Padding", scroll, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) })
    local foot = text("Hint", root, "Toca una tarjeta para elegir especies; luego aplica los filtros.", 16, 658, 510, 24, C.muted, 11)
    local chooseSpecies = button("ChooseSpecies", filters, "Elegir especies ▾", 12, 119, 154, 27)
    selectionLabel.Position = UDim2.fromOffset(174, 121); selectionLabel.Size = UDim2.fromOffset(170, 18)
    local function save()
        access()
        local ok = writeJson(FILE, { open = panel.open, visual = visual, filtersOpen = filtersOpen,
            view = "map", onlyMatches = onlyMatches, sortBest = sortBest,
            x = root.Position.X.Offset, y = root.Position.Y.Offset })
        if not ok then panel.error = "No se pudo guardar la posición / vista"; warn("[EggPanel] " .. panel.error) end
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
    function panel.Open()
        access(); panel.open = true; root.Visible = true; launcher.Visible = false; signature = nil; fit(); save()
        if panel.Refresh then task.defer(function() if panel.alive and session.alive then panel.Refresh() end end) end
    end
    function panel.Close()
        access(); panel.open = false; root.Visible = false; launcher.Visible = true; closePopup()
        for _, entry in pairs(entries) do
            if entry.viewport then entry.viewport:Destroy(); entry.viewport = nil; entry.key = nil end
        end
        save()
    end
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
    function panel.SetSortBest(value)
        access(); sortBest = value == true; signature = nil; save()
    end
    function panel.SetOnlyMatches(value)
        access(); onlyMatches = value == true; signature = nil; save()
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
        for _, entry in pairs(entries) do entry.card:Destroy() end
        table.clear(entries); table.clear(metadata); orderedRows = {}; rowsKey = nil
        local empty = scroll:FindFirstChild("Empty"); if empty then empty:Destroy() end
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
        local color = type(rarity) == "table" and rarity.Color
        -- Secret usa gris casi negro en el juego; aclararlo conserva la legibilidad.
        if typeof(color) == "Color3" then return color:Lerp(C.white, 0.25) end
        return C.gold
    end
    local function detail(row)
        access(); closePopup()
        popup = make("Frame", "EggDetail", root, {Position = UDim2.fromOffset(14, 192), Size = UDim2.fromOffset(512, 310),
            BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 60})
        corner(popup); stroke(popup, C.cyan, 2)
        text("Title", popup, row.name, 14, 12, 438, 30, C.white, 21, true).ZIndex = 61
        local dismiss = button("Dismiss", popup, "×", 466, 10, 32, 28); dismiss.ZIndex = 62
        dismiss.Activated:Connect(function() access(); closePopup() end)
        local value = row.income and string.format("%.17g", row.income) .. "/s" or "No disponible"
        local content = row.reason .. "\n\nIngreso exacto: " .. value
            .. "\nMínimo guardado: " .. string.format("%.17g", search.config.minIncome) .. "/s"
            .. "\n" .. row.rarity .. " · " .. row.mutations .. "\nZona: " .. tostring(row.area or "No disponible")
        local body = text("Explanation", popup, content, 14, 55, 478, 230, C.white, 15)
        body.TextWrapped = true; body.TextTruncate = Enum.TextTruncate.None; body.TextYAlignment = Enum.TextYAlignment.Top; body.ZIndex = 61
    end
    local function createCard(row)
        local entry = {row = row}
        local card = make("TextButton", "Card_" .. row.uid, scroll, {Size = UDim2.new(1, -12, 0, 104),
            BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", AutoButtonColor = true})
        entry.card = card; corner(card, 7); entry.border = stroke(card)
        entry.box = make("Frame", "Visual", card, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(88, 88), BackgroundColor3 = C.input, BorderSizePixel = 0})
        corner(entry.box)
        entry.image = make("ImageLabel", "EggImage", entry.box, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
        entry.name = text("Name", card, "", 108, 8, 326, 23, C.white, 19, true)
        entry.name.Size = UDim2.new(1, -166, 0, 23)
        entry.income = text("Income", card, "", 108, 32, 314, 20, C.green, 17, true)
        entry.weight = text("SizeWeight", card, "", 108, 54, 312, 18, C.cyan, 13, true)
        entry.mutations = text("MutationsArea", card, "", 108, 77, 310, 17, C.muted, 11)
        entry.badge = text("Selected", card, "", 450, 8, 36, 32, C.muted, 28, true); entry.badge.TextXAlignment = Enum.TextXAlignment.Center
        entry.match = text("Match", card, "", 430, 47, 60, 20, C.gold, 12, true)
        local more = button("Detail", card, "Detalle", 430, 75, 60, 20); more.TextSize = 10
        more.Activated:Connect(function() access(); detail(entry.row) end)
        card.Activated:Connect(function() access(); if search.modules.assets.Directory[entry.row.category] then panel.SelectCategory(entry.row.category) end end)
        panel.stats.created += 1
        return entry
    end
    local function updateCard(entry, row, index)
        access(); entry.row = row
        entry.card.LayoutOrder = index; entry.card.Position = UDim2.fromOffset(2, (index - 1) * 112 + 2)
        local selected = selection[row.category] == true
        local key = row.key .. tostring(row.match) .. row.reason .. row.mutations
            .. tostring(row.weight) .. tostring(row.eggIcon) .. visual .. tostring(selected)
        if entry.key == key and (visual ~= "models" or entry.viewport or not data.assetModels) then return end
        entry.key = key; panel.stats.updated += 1
        entry.card.Name = "Card_" .. row.uid
        entry.card.BackgroundColor3 = selected and Color3.fromRGB(41, 57, 44) or C.card
        entry.border.Color = row.match and C.green or selected and C.cyan or C.border; entry.border.Thickness = row.match and 2 or 1
        entry.name.Text = row.name; entry.name.TextColor3 = rarityColor(row.catalog and row.catalog.Rarity)
        entry.income.Text = (row.income and number(row.income) or "?") .. "/s"
        entry.weight.Text = string.format("x%.2f  ·  %s", row.scale or 1, row.weight)
        entry.mutations.Text = row.rarity .. " · " .. row.mutations .. (row.area and " · " .. tostring(row.area) or "")
        entry.badge.Text = selected and "✓" or "+"; entry.badge.TextColor3 = selected and C.cyan or C.muted
        entry.match.Text = row.match and "CUMPLE" or "FUERA"; entry.match.TextColor3 = row.match and C.green or C.gold
        local catalog = row.catalog or {}
        entry.image.Image = (visual == "pets" and catalog.Icon or row.eggIcon or (catalog.Egg and catalog.Egg.Icon)) or ""
        entry.image.Visible = true
        local modelKey = visual .. row.category .. tostring(row.scale) .. tostring(data.assetModels)
        if entry.modelKey ~= modelKey then
            if entry.viewport then entry.viewport:Destroy(); entry.viewport = nil end
            entry.modelKey = modelKey
        end
        if visual == "models" and data.assetModels and not entry.viewport then
            local ok, err = pcall(function()
                local original = data.assetModels.GetAssetModelIfReplicated(row.category)
                if not original then return end
                access()
                local viewport = make("ViewportFrame", "AssetViewport", entry.box, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                    Ambient = Color3.fromRGB(210, 210, 230), LightColor = C.white, LightDirection = Vector3.new(-1, -1, -1)})
                entry.viewport = viewport
                local world = make("WorldModel", "PreviewWorld", viewport)
                local rig = original:Clone()
                for _, child in ipairs(rig:GetDescendants()) do
                    if child:IsA("LuaSourceContainer") or child:IsA("Sound") then child:Destroy()
                    elseif child:IsA("BasePart") then child.Anchored = true; child.CanCollide = false end
                end
                rig.Parent = world; rig:PivotTo(CFrame.new())
                local bounds, size = rig:GetBoundingBox(); local distance = math.max(0.1, size.X, size.Y, size.Z) * 1.8
                local camera = make("Camera", "PreviewCamera", viewport, {FieldOfView = 35,
                    CFrame = CFrame.lookAt(bounds.Position + Vector3.new(distance * 0.8, distance * 0.45, distance), bounds.Position)})
                viewport.CurrentCamera = camera; panel.stats.modelsCreated += 1
            end)
            access()
            if not ok then if entry.viewport then entry.viewport:Destroy(); entry.viewport = nil end; warn("[EggPanel] Modelo: " .. tostring(err)) end
        end
        access(); entry.image.Visible = entry.viewport == nil
    end
    local function buildCards()
        if not panel.open or not panel.alive then return end
        local started = os.clock()
        local snapshot = search.MapSnapshot()
        local modules = search.modules
        local rows, active, fingerprints = {}, {}, {tostring(sortBest), tostring(onlyMatches), search.RecordKey(search.config)}
        for _, item in ipairs(snapshot.rows or {}) do
            active[item.uid] = true
            if not onlyMatches or item.match then
                local row = metadata[item.uid]
                if not row or row.key ~= item.key or row.labelModule ~= data.mutations then
                    local egg, catalog = item.egg, item.catalog
                    local rarity = catalog and catalog.Rarity
                    local rarityId = type(rarity) == "table" and rarity._id or rarity
                    local rank = modules.rarities.Rarities[rarityId]
                    local weightOk, weight = pcall(modules.records.WeightLabel, egg)
                    local iconOk, icon = pcall(modules.records.EggIcon, egg)
                    local labels, seen = {}, {}
                    local function mutation(id)
                        if not id or seen[id] then return end; seen[id] = true
                        local ok, label = pcall(function() return data.mutations and data.mutations.LabelOf(id) or id end)
                        table.insert(labels, ok and tostring(label) or tostring(id))
                    end
                    mutation(egg.BaseMutation); for _, id in ipairs(egg.Mutations or {}) do mutation(id) end
                    row = {uid = item.uid, key = item.key, category = tostring(egg.AssetCategory or "Desconocida"), catalog = catalog,
                        name = tostring(catalog and catalog.DisplayName or egg.AssetCategory or "Desconocida"), rarity = tostring(rarityId or "Desconocida"),
                        rarityRank = rank and rank.Rank or 0, income = item.income, scale = egg.AssetScale,
                        weight = weightOk and weight or "peso no disponible", eggIcon = iconOk and icon or nil,
                        mutations = #labels > 0 and table.concat(labels, " + ") or "Sin mutaciones", area = egg.AreaId, labelModule = data.mutations}
                    metadata[item.uid] = row
                end
                row.income, row.match, row.reason = item.income, item.match, item.reason
                table.insert(rows, row); table.insert(fingerprints, row.uid .. row.key .. tostring(row.income) .. tostring(row.match))
            end
        end
        for id in pairs(metadata) do if not active[id] then metadata[id] = nil end end
        local key = table.concat(fingerprints, "|")
        if key ~= rowsKey then
            table.sort(rows, function(a,b)
                if sortBest and a.rarityRank ~= b.rarityRank then return a.rarityRank > b.rarityRank end
                if sortBest and (a.income or 0) ~= (b.income or 0) then return (a.income or 0) > (b.income or 0) end
                if a.category ~= b.category then return a.category < b.category end
                return a.uid < b.uid
            end)
            orderedRows, rowsKey = rows, key
        end
        access(); panel.cards = #orderedRows
        scroll.CanvasSize = UDim2.fromOffset(0, math.max(0, #orderedRows * 112 + 4))
        local first = math.max(1, math.floor(scroll.CanvasPosition.Y / math.max(0.1, scale.Scale) / 112) - 1)
        local last = math.min(#orderedRows, first + math.ceil(scroll.AbsoluteSize.Y / math.max(0.1, scale.Scale) / 112) + 3)
        local visible = {}
        for index = first, last do
            local row = orderedRows[index]; visible[row.uid] = true
            local entry = entries[row.uid]
            if not entry then entry = createCard(row); entries[row.uid] = entry end
            updateCard(entry, row, index)
        end
        local rendered = 0
        for id, entry in pairs(entries) do
            if not visible[id] then entry.card:Destroy(); entries[id] = nil else rendered += 1 end
        end
        panel.stats.rendered = rendered
        local empty = scroll:FindFirstChild("Empty")
        if #orderedRows == 0 then
            if not empty then empty = text("Empty", scroll, "", 0, 0, 494, 130, C.muted, 16); empty.TextWrapped = true; empty.TextXAlignment = Enum.TextXAlignment.Center end
            empty.Text = not snapshot.info.ready and (snapshot.info.reason or "Esperando datos del mapa")
                or onlyMatches and "Ningún huevo actual cumple los filtros guardados.\nEsperando la próxima renovación." or "No hay spawns disponibles en el mapa."
        elseif empty then empty:Destroy() end
        panel.stats.lastMs = (os.clock() - started) * 1000
    end
    local function scheduleRender()
        if renderScheduled or not panel.open then return end
        renderScheduled = true
        task.defer(function()
            renderScheduled = false
            if panel.alive and session.alive then
                local ok, err = pcall(buildCards); if not ok then panel.error = tostring(err); warn("[EggPanel] " .. tostring(err)) end
            end
        end)
    end
    panel.Refresh = buildCards
    connect(scroll:GetPropertyChangedSignal("CanvasPosition"), scheduleRender)
    function panel.LoadPreset(name)
        local config = api.LoadPreset(name)
        access(); setDraft(config); markDirty(); closePopup()
        return config
    end
    function panel.SavePreset(name)
        access()
        local minimum = search.ParseMinimum(income.Text)
        assert(minimum, "Mínimo inválido: usa 500k, 25m o 7.5b")
        return api.SavePreset(name, {rarity = draft.rarity, minIncome = minimum, mutation = draft.mutation,
            nameContains = nameBox.Text, categories = selectionList()})
    end
    function panel.OpenOptions()
        access(); closePopup()
        popup = make("Frame", "FinderOptions", root, {Position = UDim2.fromOffset(14, 124), Size = UDim2.fromOffset(512, 524),
            BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 60})
        corner(popup); stroke(popup, C.cyan, 2)
        text("Title", popup, "Presets y alertas", 12, 8, 438, 30, C.white, 21, true).ZIndex = 61
        local dismiss = button("Dismiss", popup, "×", 466, 8, 32, 28); dismiss.ZIndex = 62
        dismiss.Activated:Connect(function() access(); closePopup() end)
        local message = text("Message", popup, "Cargar un preset deja cambios pendientes de aplicar.", 12, 45, 486, 34, C.muted, 12)
        message.TextWrapped = true; message.ZIndex = 61
        local name = make("TextBox", "PresetName", popup, {Position = UDim2.fromOffset(12, 86), Size = UDim2.fromOffset(300, 32),
            Text = "", PlaceholderText = "Nombre del preset", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium,
            TextSize = 14, TextColor3 = C.white, BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 62})
        corner(name)
        local savePreset = button("SavePreset", popup, "Guardar filtros", 324, 86, 174, 32, C.green); savePreset.ZIndex = 62
        local list = make("ScrollingFrame", "Presets", popup, {Position = UDim2.fromOffset(12, 130), Size = UDim2.fromOffset(486, 240),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BackgroundTransparency = 1,
            ScrollBarThickness = 4, BorderSizePixel = 0, ZIndex = 61})
        make("UIListLayout", "Layout", list, {Padding = UDim.new(0, 6)})
        local function result(callback)
            local ok, err = pcall(callback); access()
            if not ok and popup then message.Text = tostring(err); message.TextColor3 = C.red end
            return ok
        end
        for index, preset in ipairs(api.Presets()) do
            local row = make("Frame", "Preset_" .. index, list, {Size = UDim2.new(1, -6, 0, 46), BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 62})
            text("Name", row, preset.name, 8, 5, 280, 18, C.white, 14).ZIndex = 63
            local minimum = tonumber(preset.config.minIncome)
            local summary = minimum and minimum > 0 and minimum < math.huge and search.FormatMinimum(minimum) or "inválido"
            text("Summary", row, tostring(preset.config.rarity or "Sin rareza") .. " · ≥ " .. summary .. "/s", 8, 24, 280, 16, C.muted, 11).ZIndex = 63
            local load = button("Load", row, "Cargar", 290, 8, 82, 30); load.ZIndex = 63
            local delete = button("Delete", row, "Borrar", 380, 8, 86, 30); delete.ZIndex = 63
            load.Activated:Connect(function() access(); result(function() panel.LoadPreset(preset.name) end) end)
            delete.Activated:Connect(function() access(); if result(function() api.DeletePreset(preset.name) end) then panel.OpenOptions() end end)
        end
        if #api.Presets() == 0 then text("Empty", list, "Todavía no hay presets. Guarda los filtros de arriba.", 4, 10, 470, 40, C.muted, 13).ZIndex = 62 end
        savePreset.Activated:Connect(function() access(); if result(function() panel.SavePreset(name.Text) end) then panel.OpenOptions() end end)
        local settings = api.Alerts()
        local notification = button("Notification", popup, "Notificación: " .. (settings.notification and "ON" or "OFF"), 12, 390, 234, 34); notification.ZIndex = 62
        local sound = button("Sound", popup, "Sonido: " .. (settings.sound and "ON" or "OFF"), 258, 390, 240, 34); sound.ZIndex = 62
        notification.Activated:Connect(function() access(); if result(function() api.ConfigureAlerts({notification = not settings.notification}) end) then panel.OpenOptions() end end)
        sound.Activated:Connect(function() access(); if result(function() api.ConfigureAlerts({sound = not settings.sound}) end) then panel.OpenOptions() end end)
        local test = button("TestAlert", popup, "Probar alerta", 12, 436, 486, 34); test.ZIndex = 62
        test.Activated:Connect(function() access(); result(api.TestAlert) end)
        text("AlertHint", popup, "Las alertas se emiten al encontrar un objetivo; AUTO se detiene.", 12, 482, 486, 30, C.muted, 11).ZIndex = 61
    end
    connect(optionsButton.Activated, panel.OpenOptions)
    function panel.GetStatus()
        access(); return { open = panel.open, view = "map", onlyMatches = onlyMatches, cards = panel.cards, dirty = dirty, error = panel.error,
            selected = selectionList(), visual = visual, sortBest = sortBest, position = {x = root.AbsolutePosition.X, y = root.AbsolutePosition.Y},
            size = {x = root.AbsoluteSize.X, y = root.AbsoluteSize.Y}, scale = scale.Scale,
            stats = table.clone(panel.stats), resources = {mutations = data.mutations ~= nil, models = data.assetModels ~= nil} }
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
    connect(UIS.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.LeftAlt then
            if panel.open then panel.Close() else panel.Open() end
        end
    end)
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
        local nextResourceRetry = 0
        while panel.alive and session.alive do
            if os.clock() >= nextResourceRetry and (not data.mutations or not data.assetModels) then
                nextResourceRetry = os.clock() + 5
                local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
                local modules = shared and shared:FindFirstChild("Modules")
                for key, name in pairs({mutations = "Mutations", assetModels = "AssetModels"}) do
                    if not data[key] then
                        local source = modules and modules:FindFirstChild(name)
                        if source then local ok, value = pcall(require, source); if ok then data[key] = value end end
                    end
                end
            end
            local updated, problem = pcall(function()
            if not panel.open then return end
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
            foot.Text = "Alt izquierdo: abrir/cerrar · CUMPLE usa los filtros guardados."
            local cycle = status.cycle
            local info = status.lastScan and status.lastScan.info or {}
            tabMap.Text = string.format("Mapa · %d", info.count or 0)
            local titles = { wait = "Esperando huevos nuevos", hop = "Buscando otro servidor", loading = "Esperando renovación / datos", match = "Objetivo encontrado", stopped = "Búsqueda detenida" }
            stateTitle.Text = titles[status.mode] or "Escaneando mapa"
            stateTitle.TextColor3 = status.mode == "match" and C.green or C.white
            stateDetail.Text = string.format("%s · ≥ %s/s · %d en mapa · %d de esa rareza", status.config.rarity, number(status.config.minIncome), info.count or 0, info.rarityCount or 0)
            if status.mode == "loading" and info.reason then stateDetail.Text = info.reason end
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
