-- Panel de filtros del detector. Recursos visuales y datos del propio juego.
local function mountEggFilterPanel(context)
    local search, api, session = context.search, context.api, context.session
    local readJson, writeJson = context.readJson, context.writeJson
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local FILE = "chilli_egg_panel_ui.json"
    local saved = readJson(FILE, {})
    local panel: { [string]: any } = { alive = true, open = saved.open ~= false, view = "map", cards = 0 }
    local onlyMatches = saved.onlyMatches == true
    local connections = {}
    -- Paleta compartida: acento para acciones, colores semanticos para estados.
    local C = {
        bg = Color3.fromRGB(20, 24, 30), card = Color3.fromRGB(30, 36, 44),
        input = Color3.fromRGB(16, 20, 26), border = Color3.fromRGB(56, 65, 77),
        white = Color3.fromRGB(239, 243, 247), muted = Color3.fromRGB(170, 183, 197),
        green = Color3.fromRGB(147, 215, 191), red = Color3.fromRGB(240, 152, 159),
        cyan = Color3.fromRGB(174, 206, 229), gold = Color3.fromRGB(224, 197, 149),
        selected = Color3.fromRGB(38, 53, 53), success = Color3.fromRGB(28, 46, 43),
        onAccent = Color3.fromRGB(35, 29, 20), onSuccess = Color3.fromRGB(15, 35, 29),
    }
    local PANEL_WIDTH, PANEL_HEIGHT, ROW_HEIGHT, ROW_GAP = 540, 700, 116, 8
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
    local function corner(object, radius) make("UICorner", "Round", object, { CornerRadius = UDim.new(0, radius or 8) }) end
    local function stroke(object, color, thickness)
        return make("UIStroke", "Border", object, { Color = color or C.border, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    end
    local function text(name, parent, value, x, y, width, height, color, size, bold)
        return make("TextLabel", name, parent, {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            Text = value, TextColor3 = color or C.white, TextSize = size or 14,
            Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            TextStrokeTransparency = 1,
        })
    end
    -- Solo se anima la respuesta al puntero; listas, ingresos y reloj son inmediatos.
    -- Estas conexiones pertenecen al objeto, se retiran al destruir tarjetas/popups.
    local function interaction(object)
        local border = object:FindFirstChild("Border")
        local tween
        local function feedback(transparency, animate)
            if not panel.alive or not session.alive then return end
            access()
            if tween then tween:Cancel(); tween = nil end
            if animate then
                tween = TweenService:Create(border, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = transparency })
                tween:Play()
            else border.Transparency = transparency end
        end
        border.Transparency = 0.45
        object.MouseEnter:Connect(function() if UIS.MouseEnabled then feedback(0, true) end end)
        object.MouseLeave:Connect(function() feedback(0.45, true) end)
        object.SelectionGained:Connect(function() feedback(0, false) end)
        object.SelectionLost:Connect(function() feedback(0.45, false) end)
        object.Destroying:Connect(function() access(); if tween then tween:Cancel(); tween = nil end end)
    end
    local function button(name, parent, value, x, y, width, height, color)
        local object = make("TextButton", name, parent, {
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = color or C.card, BorderSizePixel = 0, Text = value,
            TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = C.white,
            TextStrokeTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = true,
        })
        corner(object); stroke(object); interaction(object)
        return object
    end
    local function paint(object, background, foreground, borderColor)
        access()
        object.BackgroundColor3 = background
        object.TextColor3 = foreground or C.white
        object.Border.Color = borderColor or C.border
    end
    -- Geometria nativa: evita depender de glifos que faltan en algunas fuentes.
    local function line(parent, name, x, y, width, rotation, color, zIndex)
        return make("Frame", name, parent, { AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, 1.5),
            Rotation = rotation or 0, BackgroundColor3 = color or C.muted,
            BorderSizePixel = 0, ZIndex = zIndex or parent.ZIndex })
    end
    local function selectionIcon(parent, selected, x, y, zIndex, boxed)
        local mark = make("Frame", "SelectionMark", parent, { Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ZIndex = zIndex or parent.ZIndex })
        if boxed then mark.BackgroundTransparency = 0; mark.BackgroundColor3 = C.input; corner(mark, 4); stroke(mark) end
        local short = line(mark, "Short", 8, 12, 6, 0, C.muted, mark.ZIndex)
        local long = line(mark, "Long", 12, 12, 12, 90, C.muted, mark.ZIndex)
        local function update(value)
            access()
            short.Position = UDim2.fromOffset(value and 8 or 12, value and 13 or 12)
            short.Size = UDim2.fromOffset(value and 6 or 12, 1.5); short.Rotation = value and 45 or 0
            long.Position = UDim2.fromOffset(value and 14 or 12, value and 11 or 12)
            long.Rotation = value and -45 or 90
            short.BackgroundColor3 = value and C.green or C.muted
            long.BackgroundColor3 = short.BackgroundColor3
            if boxed then
                short.Visible = value == true; long.Visible = value == true
                mark.Border.Color = value and C.green or C.muted
            end
        end
        update(selected)
        return update
    end
    local function chevron(object)
        for index, rotation in ipairs({45, -45}) do
            local segment = line(object, "Chevron" .. index, 0, 0, 6, rotation, C.muted)
            segment.Position = UDim2.new(1, index == 1 and -18 or -14, 0.5, 0)
        end
        make("UIPadding", "ChevronSpace", object, { PaddingRight = UDim.new(0, 20), PaddingLeft = UDim.new(0, 4) })
    end
    local function connect(signal, callback)
        local c = signal:Connect(function(...)
            if not panel.alive or not session.alive then return end
            access(); callback(...)
        end)
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
        local copy = table.clone(config); copy.zones = table.clone(config.zones or {}); return copy
    end
    local draft = cloneConfig(search.config)
    local selection = {}; for _, id in ipairs(draft.zones) do selection[id] = true end
    local allZones = #draft.zones == 0
    local function selectionList()
        if allZones then return {} end
        local list = {}; for id, selected in pairs(selection) do if selected then table.insert(list, id) end end
        table.sort(list); return list
    end
    local dirty, signature, popup, data = false, nil, nil, {}
    local entries, metadata, orderedRows, rowsKey = {}, {}, {}, nil
    local renderScheduled = false
    panel.stats = {created = 0, updated = 0, modelsCreated = 0, rendered = 0, lastMs = 0}
    local function sameConfig(a, b)
        if a.rarity ~= b.rarity or a.minIncome ~= b.minIncome or a.mutation ~= b.mutation or a.nameContains ~= b.nameContains then return false end
        if #(a.zones or {}) ~= #(b.zones or {}) then return false end
        for i, id in ipairs(a.zones or {}) do if id ~= b.zones[i] then return false end end
        return true
    end
    local visual = saved.visual or "eggs"
    if visual ~= "eggs" and visual ~= "pets" and visual ~= "models" then visual = "eggs" end
    local sortBest, filtersOpen = saved.sortBest ~= false, saved.filtersOpen ~= false
    local root = make("Frame", "EggFilterPanel", context.screenGui, {
        Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT), Position = UDim2.fromOffset(800, 70),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = panel.open, Active = true,
        ClipsDescendants = true, ZIndex = 10,
    })
    corner(root, 14); stroke(root, C.border)
    local scale = make("UIScale", "ResponsiveScale", root, { Scale = 1 })
    local launcher = button("OpenEggFilters", context.screenGui, "EGG FILTERS", 0, 0, 150, 38, C.card)
    paint(launcher, C.card, C.gold)
    launcher.AnchorPoint = Vector2.new(1, 0); launcher.Position = UDim2.new(1, -18, 0, 18); launcher.ZIndex = 20
    launcher.Visible = not panel.open
    local header = make("Frame", "Header", root, { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true })
    text("Title", header, "Egg Finder", 22, 14, 220, 30, C.white, 24, true)
    text("Subtitle", header, "Solo huevos del mapa", 23, 45, 230, 16, C.muted, 11)
    make("Frame", "HeaderDivider", root, { Position = UDim2.fromOffset(22, 72), Size = UDim2.new(1, -44, 0, 1), BackgroundColor3 = C.border, BorderSizePixel = 0 })
    local optionsButton = button("Options", header, "Opciones", 260, 20, 88, 34)
    local auto = button("ToggleSearch", header, "AUTO", 360, 20, 106, 34, C.card)
    local minimize = button("Minimize", header, "", 478, 20, 38, 34)
    line(minimize, "Minus", 19, 17, 12, 0, C.muted)
    local stateDot = make("Frame", "StateDot", root, { Position = UDim2.fromOffset(22, 97), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = C.muted, BorderSizePixel = 0 })
    corner(stateDot, 3)
    local stateTitle = text("SearchState", root, "Conectando detector...", 36, 86, 330, 26, C.white, 15, true)
    local clock = text("ResetClock", root, "RESET --:--", 376, 86, 140, 26, C.cyan, 12, true)
    clock.TextXAlignment = Enum.TextXAlignment.Right
    local stateDetail = text("SearchDetail", root, "Divine+ · mínimo 7B/s", 22, 119, 390, 18, C.muted, 11)
    local filterToggle = button("ToggleFilters", root, "Filtros −", 430, 117, 86, 28)
    local filters = make("Frame", "Filters", root, { Position = UDim2.fromOffset(22, 162), Size = UDim2.fromOffset(494, 182), BackgroundTransparency = 1, BorderSizePixel = 0 })
    text("RarityLabel", filters, "RAREZA MÍNIMA", 0, 2, 135, 18, C.muted, 10)
    text("IncomeLabel", filters, "MÍNIMO /s · k m b t q", 158, 2, 120, 18, C.muted, 10)
    text("MutationLabel", filters, "MUTACIÓN", 294, 2, 200, 18, C.muted, 10)
    local rarityButton = button("Rarity", filters, draft.rarity, 0, 28, 144, 36)
    chevron(rarityButton)
    local income = make("TextBox", "MinimumIncome", filters, {
        Position = UDim2.fromOffset(158, 28), Size = UDim2.fromOffset(122, 36),
        BackgroundColor3 = C.input, BorderSizePixel = 0, Text = search.FormatMinimum(draft.minIncome),
        PlaceholderText = "Ej. 7b", PlaceholderColor3 = C.muted, Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = C.gold,
        ClearTextOnFocus = false,
    })
    corner(income); stroke(income)
    local mutationButton = button("Mutation", filters, draft.mutation == "" and "Todas" or draft.mutation, 294, 28, 200, 36)
    chevron(mutationButton)
    local nameBox = make("TextBox", "NameFilter", filters, {
        Position = UDim2.fromOffset(0, 78), Size = UDim2.fromOffset(322, 34), BackgroundColor3 = C.input,
        BorderSizePixel = 0, Text = draft.nameContains, PlaceholderText = "Buscar / filtrar por nombre...",
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.white, PlaceholderColor3 = C.muted,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(nameBox); stroke(nameBox); make("UIPadding", "Padding", nameBox, { PaddingLeft = UDim.new(0, 10) })
    local clear = button("AllZones", filters, "Todas las zonas", 336, 78, 158, 34)
    local selectionLabel = text("Selection", filters, "Todas las zonas", 160, 133, 165, 18, C.muted, 10)
    local changeLabel = text("Changes", filters, "Filtros guardados", 0, 165, 494, 17, C.muted, 10)
    local apply = button("ApplyFilters", filters, "Aplicar filtros", 336, 126, 158, 34, C.gold)
    paint(apply, C.gold, C.onAccent, C.gold)
    local tabMap = button("MapTab", root, "Mapa", 22, 364, 102, 32)
    local tabCatalog = button("CatalogTab", root, "Solo filtro: OFF", 132, 364, 136, 32)
    local visualButton = button("VisualMode", root, "Huevos", 276, 364, 108, 32)
    local sortButton = button("Sort", root, "Rareza ↓", 392, 364, 124, 32)
    local scroll = make("ScrollingFrame", "EggCards", root, {
        Position = UDim2.fromOffset(20, 408), Size = UDim2.fromOffset(498, 248), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    make("UIPadding", "Padding", scroll, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) })
    local foot = text("Hint", root, "Elige una o varias zonas; luego aplica los filtros.", 22, 668, 494, 16, C.muted, 10)
    local chooseZones = button("ChooseZones", filters, "Elegir zonas", 0, 126, 148, 34)
    chooseZones.TextSize = 11
    chevron(chooseZones)
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
        local y = filtersOpen and 364 or 162
        for _, b in ipairs({tabCatalog, tabMap, visualButton, sortButton}) do b.Position = UDim2.fromOffset(b.Position.X.Offset, y) end
        scroll.Position = UDim2.fromOffset(20, y + 44); scroll.Size = UDim2.fromOffset(498, 612 - y)
        closePopup(); signature = nil
    end
    local initializedPosition = false
    local function fit()
        access()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = math.max(0.1, math.min(1, (viewport.X - 28) / PANEL_WIDTH, (viewport.Y - 28) / PANEL_HEIGHT))
        local width, height = PANEL_WIDTH * scale.Scale, PANEL_HEIGHT * scale.Scale
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
        selectionLabel.Text = allZones and "Todas las zonas" or string.format("%d zonas seleccionadas", count)
        changeLabel.Text = "Cambios sin aplicar"; changeLabel.TextColor3 = C.gold
    end
    local function setDraft(config)
        local minimumText = search.FormatMinimum(config.minIncome)
        access()
        draft = cloneConfig(config); selection = {}; for _, id in ipairs(draft.zones) do selection[id] = true end
        allZones = #draft.zones == 0
        income.Text = minimumText; nameBox.Text = draft.nameContains
        rarityButton.Text = draft.rarity
        mutationButton.Text = draft.mutation == "" and "Todas" or draft.mutation
        local count = #draft.zones
        selectionLabel.Text = allZones and "Todas las zonas" or string.format("%d zonas seleccionadas", count)
        dirty = false; changeLabel.Text = "Filtros guardados"; changeLabel.TextColor3 = C.muted; signature = nil
    end
    function panel.Apply()
        access()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if not minimum then
            changeLabel.Text = "Mínimo inválido: usa 500k, 25m o 7.5b"; changeLabel.TextColor3 = C.red; return false
        end
        if not allZones and #selectionList() == 0 then
            changeLabel.Text = "Selecciona al menos una zona o pulsa Todas las zonas"; changeLabel.TextColor3 = C.red
            return false
        end
        local patch = { rarity = draft.rarity, minIncome = minimum, mutation = draft.mutation,
            nameContains = nameBox.Text, zones = selectionList() }
        local ok, config = pcall(api.Configure, patch)
        access()
        if not ok then changeLabel.Text = tostring(config); changeLabel.TextColor3 = C.red; return false end
        setDraft(config); closePopup(); panel.SetOnlyMatches(true); return true
    end
    function panel.SelectZone(id)
        local options = search.ZoneOptions()
        local known = false
        for _, option in ipairs(options) do if option.id == id then known = true end end
        access(); assert(known, "Zona desconocida")
        if allZones then
            selection = {}; for _, option in ipairs(options) do selection[option.id] = true end
            allZones = false
        end
        selection[id] = not selection[id]; markDirty()
    end
    function panel.SelectAllZones() access(); selection = {}; allZones = true; markDirty() end
    function panel.ClearZones() access(); selection = {}; allZones = false; markDirty() end
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
        popup = make("Frame", "Dropdown", root, { Position = UDim2.fromOffset(22, 232), Size = UDim2.fromOffset(494, 310), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 60 })
        corner(popup, 12); stroke(popup, C.border)
        text("Prompt", popup, anchor == rarityButton and "Elige una rareza mínima" or "Elige una mutación", 16, 12, 350, 24, C.white, 16, true).ZIndex = 61
        local dismiss = button("Dismiss", popup, "Cerrar", 398, 10, 80, 30); dismiss.ZIndex = 62
        dismiss.Activated:Connect(function() access(); closePopup() end)
        local list = make("ScrollingFrame", "Options", popup, { Position = UDim2.fromOffset(16, 52), Size = UDim2.fromOffset(462, 242), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0, ZIndex = 61 })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 6) })
        for index, item in ipairs(options) do
            local b = button("Option_" .. index, list, item.label, 0, 0, 454, 36)
            b.ZIndex = 62; b.LayoutOrder = index
            local current = anchor == rarityButton and draft.rarity or draft.mutation
            if item.id == current then paint(b, C.selected, C.green, C.green) end
            b.Activated:Connect(function() access(); select(item.id); closePopup(); markDirty() end)
        end
    end
    local function cleanupCards()
        access()
        for _, entry in pairs(entries) do entry.card:Destroy() end
        table.clear(entries); table.clear(metadata); orderedRows = {}; rowsKey = nil
        local empty = scroll:FindFirstChild("Empty"); if empty then empty:Destroy() end
    end
    local function zonePicker()
        if popup then closePopup(); return end
        local options = search.ZoneOptions()
        access()
        if #options == 0 then
            changeLabel.Text = "Esperando las zonas del juego..."; changeLabel.TextColor3 = C.muted
            return
        end
        popup = make("Frame", "ZonePicker", root, { Position = UDim2.fromOffset(22, 150), Size = UDim2.fromOffset(494, 506), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 60 })
        corner(popup, 12); stroke(popup, C.border)
        text("Title", popup, "Elegir zonas", 16, 12, 364, 25, C.white, 18, true).ZIndex = 61
        text("Hint", popup, string.format("%d zonas · aplica junto con la rareza y el mínimo.", #options), 16, 45, 462, 18, C.muted, 11).ZIndex = 61
        local done = button("Done", popup, "Cerrar", 398, 10, 80, 34); done.ZIndex = 62
        done.Activated:Connect(function() access(); closePopup() end)
        local selectAll = button("SelectAll", popup, "Todas", 16, 74, 100, 32); selectAll.ZIndex = 62
        local clearZones = button("ClearSelection", popup, "Limpiar selección", 126, 74, 150, 32); clearZones.ZIndex = 62
        local list = make("ScrollingFrame", "Zones", popup, { Position = UDim2.fromOffset(16, 118), Size = UDim2.fromOffset(462, 370), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ScrollBarThickness = 4, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0, ZIndex = 61 })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
        local checks = {}
        local function refreshChecks()
            access()
            for id, entry in pairs(checks) do
                local selected = allZones or selection[id] == true
                entry.check(selected)
                paint(entry.button, selected and C.selected or C.card, C.white, selected and C.green or C.border)
            end
        end
        for index, option in ipairs(options) do
            local b = button("Zone_" .. option.id, list, "", 0, 0, 450, 44)
            b.ZIndex = 62; b.LayoutOrder = index
            text("Name", b, option.label, 12, 9, 382, 26, C.white, 14, true).ZIndex = 63
            checks[option.id] = {button = b, check = selectionIcon(b, false, 414, 10, 63, true)}
            b.Activated:Connect(function()
                access(); panel.SelectZone(option.id); refreshChecks()
            end)
        end
        selectAll.Activated:Connect(function() access(); panel.SelectAllZones(); refreshChecks() end)
        clearZones.Activated:Connect(function() access(); panel.ClearZones(); refreshChecks() end)
        refreshChecks()
    end
    panel.OpenZones = function() access(); zonePicker() end
    local function luminance(color)
        local function linear(component)
            return component <= 0.04045 and component / 12.92 or ((component + 0.055) / 1.055) ^ 2.4
        end
        return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
    end
    local function rarityColor(rarity)
        local color = type(rarity) == "table" and rarity.Color
        if typeof(color) ~= "Color3" then return C.gold end
        -- Preservar el tono oficial; Secret y colores oscuros necesitan mas contraste.
        local background = math.max(luminance(C.card), luminance(C.selected), luminance(C.success))
        color = color:Lerp(C.white, 0.25)
        for _ = 1, 10 do
            if (luminance(color) + 0.05) / (background + 0.05) >= 4.5 then break end
            color = color:Lerp(C.white, 0.15)
        end
        return color
    end
    local function detail(row)
        access(); closePopup()
        popup = make("Frame", "EggDetail", root, {Position = UDim2.fromOffset(14, 192), Size = UDim2.fromOffset(512, 310),
            BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 60})
        corner(popup, 12); stroke(popup, C.border)
        text("Title", popup, row.name, 16, 12, 384, 30, C.white, 18, true).ZIndex = 61
        local dismiss = button("Dismiss", popup, "Cerrar", 416, 10, 80, 30); dismiss.ZIndex = 62
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
        local card = make("TextButton", "Card_" .. row.uid, scroll, {Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
            BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", AutoButtonColor = true})
        entry.card = card; corner(card, 12); entry.border = stroke(card); interaction(card)
        entry.box = make("Frame", "Visual", card, {Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(88, 88), BackgroundTransparency = 1, BorderSizePixel = 0})
        entry.image = make("ImageLabel", "EggImage", entry.box, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
        entry.name = text("Name", card, "", 110, 10, 326, 22, C.white, 15, true)
        entry.name.Size = UDim2.new(1, -156, 0, 22)
        entry.income = text("Income", card, "", 110, 36, 270, 24, C.white, 20, true)
        entry.weight = text("SizeWeight", card, "", 110, 64, 270, 18, C.muted, 11)
        entry.rarity = text("Rarity", card, "", 110, 88, 88, 16, C.gold, 10, true)
        entry.mutations = text("MutationsArea", card, "", 202, 88, 274, 16, C.muted, 10)
        entry.mutations.Size = UDim2.new(1, -216, 0, 16)
        entry.match = text("Match", card, "", 0, 40, 76, 20, C.muted, 10, true)
        entry.match.Position = UDim2.new(1, -86, 0, 40); entry.match.TextXAlignment = Enum.TextXAlignment.Right
        local more = button("Detail", card, "Detalle", 0, 64, 76, 20)
        more.Position = UDim2.new(1, -86, 0, 64); more.TextSize = 10
        more.Activated:Connect(function() access(); detail(entry.row) end)
        card.Activated:Connect(function() access(); detail(entry.row) end)
        panel.stats.created += 1
        return entry
    end
    local function updateCard(entry, row, index)
        access(); entry.row = row
        entry.card.LayoutOrder = index; entry.card.Position = UDim2.fromOffset(2, (index - 1) * (ROW_HEIGHT + ROW_GAP) + 2)
        local key = row.key .. tostring(row.match) .. row.reason .. row.mutations
            .. tostring(row.weight) .. tostring(row.eggIcon) .. visual
        if entry.key == key and (visual ~= "models" or entry.viewport or not data.assetModels) then return end
        entry.key = key; panel.stats.updated += 1
        entry.card.Name = "Card_" .. row.uid
        entry.card.BackgroundColor3 = row.match and C.success or C.card
        entry.border.Color = row.match and C.green or C.border; entry.border.Thickness = row.match and 2 or 1
        entry.name.Text = row.name; entry.name.TextColor3 = C.white
        entry.rarity.Text = row.rarity; entry.rarity.TextColor3 = rarityColor(row.catalog and row.catalog.Rarity)
        entry.income.Text = (row.income and number(row.income) or "?") .. "/s"
        entry.income.TextColor3 = row.match and C.green or C.white
        entry.weight.Text = string.format("x%.2f  ·  %s", row.scale or 1, row.weight)
        entry.mutations.Text = row.mutations .. (row.area and " · " .. tostring(row.area) or "")
        entry.match.Text = row.match and "CUMPLE" or "FUERA"; entry.match.TextColor3 = row.match and C.green or C.muted
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
        scroll.CanvasSize = UDim2.fromOffset(0, math.max(0, #orderedRows * (ROW_HEIGHT + ROW_GAP) + 4))
        local first = math.max(1, math.floor(scroll.CanvasPosition.Y / math.max(0.1, scale.Scale) / (ROW_HEIGHT + ROW_GAP)) - 1)
        local last = math.min(#orderedRows, first + math.ceil(scroll.AbsoluteSize.Y / math.max(0.1, scale.Scale) / (ROW_HEIGHT + ROW_GAP)) + 3)
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
                or onlyMatches and "Ningún huevo disponible cumple zona, rareza y mínimo." or "No hay spawns disponibles en el mapa."
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
        assert(allZones or #selectionList() > 0, "Selecciona al menos una zona")
        return api.SavePreset(name, {rarity = draft.rarity, minIncome = minimum, mutation = draft.mutation,
            nameContains = nameBox.Text, zones = selectionList()})
    end
    function panel.OpenOptions()
        access(); closePopup()
        popup = make("Frame", "FinderOptions", root, {Position = UDim2.fromOffset(14, 124), Size = UDim2.fromOffset(512, 524),
            BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 60})
        corner(popup, 12); stroke(popup, C.border)
        text("Title", popup, "Presets y alertas", 16, 8, 384, 30, C.white, 18, true).ZIndex = 61
        local dismiss = button("Dismiss", popup, "Cerrar", 416, 8, 80, 30); dismiss.ZIndex = 62
        dismiss.Activated:Connect(function() access(); closePopup() end)
        local message = text("Message", popup, "Cargar un preset deja cambios pendientes de aplicar.", 12, 45, 486, 34, C.muted, 12)
        message.TextWrapped = true; message.ZIndex = 61
        local name = make("TextBox", "PresetName", popup, {Position = UDim2.fromOffset(12, 86), Size = UDim2.fromOffset(300, 32),
            Text = "", PlaceholderText = "Nombre del preset", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium,
            TextSize = 14, TextColor3 = C.white, BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 62})
        corner(name)
        local savePreset = button("SavePreset", popup, "Guardar filtros", 324, 86, 174, 32, C.gold); savePreset.ZIndex = 62
        paint(savePreset, C.gold, C.onAccent, C.gold)
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
            text("Summary", row, tostring(preset.config.rarity or "Sin rareza") .. "+ · ≥ " .. summary .. "/s", 8, 24, 280, 16, C.muted, 11).ZIndex = 63
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
        local test = button("TestAlert", popup, "Probar alerta", 12, 436, 234, 44); test.ZIndex = 62
        test.Activated:Connect(function() access(); result(api.TestAlert) end)
        if type(api.OpenServerAccount) == "function" then
            local account = button("ServerAccount", popup, "Cuenta / Best Ping", 258, 436, 240, 44); account.ZIndex = 62
            account.Activated:Connect(function() access(); closePopup(); api.OpenServerAccount() end)
        end
        text("AlertHint", popup, "Las alertas se emiten al encontrar un objetivo; AUTO se detiene.", 12, 482, 486, 30, C.muted, 11).ZIndex = 61
    end
    connect(optionsButton.Activated, panel.OpenOptions)
    function panel.GetStatus()
        access(); return { open = panel.open, view = "map", onlyMatches = onlyMatches, cards = panel.cards, dirty = dirty, error = panel.error,
            selected = selectionList(), allZones = allZones, visual = visual, sortBest = sortBest, position = {x = root.AbsolutePosition.X, y = root.AbsolutePosition.Y},
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
    connect(clear.Activated, function() selection = {}; allZones = true; markDirty(); closePopup() end)
    connect(income:GetPropertyChangedSignal("Text"), function()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if minimum ~= draft.minIncome then markDirty() end
    end)
    for _, field in ipairs({income, nameBox}) do
        connect(field.Focused, function() field.Border.Color = C.gold; field.Border.Thickness = 1.5 end)
        connect(field.FocusLost, function() field.Border.Color = C.border; field.Border.Thickness = 1 end)
    end
    connect(nameBox:GetPropertyChangedSignal("Text"), function()
        if nameBox.Text ~= draft.nameContains then markDirty() end
    end)
    connect(chooseZones.Activated, function() panel.OpenZones() end)
    connect(tabCatalog.Activated, function() onlyMatches = not onlyMatches; signature = nil; save() end)
    connect(tabMap.Activated, function() onlyMatches = false; signature = nil; save() end)
    connect(sortButton.Activated, function() sortBest = not sortBest; sortButton.Text = sortBest and "Rareza ↓" or "Nombre A–Z"; signature = nil; save() end)
    connect(visualButton.Activated, function() panel.SetVisual(visual == "eggs" and "pets" or visual == "pets" and "models" or "eggs") end)
    connect(rarityButton.Activated, function()
        if not search.modules then return end
        local options = search.RarityOptions()
        dropdown(rarityButton, options, function(id) draft.rarity = id; rarityButton.Text = id end)
    end)
    connect(mutationButton.Activated, function()
        if not data then return end
        local options = {}; for id in pairs(data.mutations.IdSet) do table.insert(options, { id = id, label = data.mutations.LabelOf(id) }) end
        table.sort(options, function(a, b) return a.label < b.label end)
        table.insert(options, 1, { id = "", label = "Todas las mutaciones" })
        dropdown(mutationButton, options, function(id)
            draft.mutation = id
            local label = id == "" and "Todas" or data.mutations.LabelOf(id)
            access(); mutationButton.Text = label
        end)
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
            paint(auto, status.active and C.green or C.card, status.active and C.onSuccess or C.muted, status.active and C.green or C.border)
            visualButton.Text = visual == "eggs" and "Huevos" or visual == "pets" and "Criaturas" or "Modelos 3D"
            sortButton.Text = sortBest and "Rareza ↓" or "Nombre A–Z"
            tabCatalog.Text = onlyMatches and "Solo filtro: ON" or "Solo filtro: OFF"
            paint(tabCatalog, onlyMatches and C.selected or C.card, onlyMatches and C.green or C.muted, onlyMatches and C.green or C.border)
            paint(tabMap, not onlyMatches and C.selected or C.card, not onlyMatches and C.green or C.muted, not onlyMatches and C.green or C.border)
            foot.Text = dirty and "Cambios sin aplicar · AUTO usa los filtros guardados."
                or "Alt izquierdo: abrir/cerrar · CUMPLE exige zona, rareza e ingreso."
            local cycle = status.cycle
            local info = status.lastScan and status.lastScan.info or {}
            tabMap.Text = string.format("Mapa · %d", info.count or 0)
            local scope = #status.config.zones > 0 and "tus zonas" or "el mapa"
            local titles = { wait = "Esperando " .. status.config.rarity .. "+ en " .. scope, hop = "Buscando otro servidor", loading = "Esperando renovación / datos", match = "Objetivo encontrado", stopped = "Búsqueda detenida" }
            stateTitle.Text = titles[status.mode] or "Escaneando mapa"
            stateTitle.TextColor3 = status.mode == "match" and C.green or C.white
            stateDot.BackgroundColor3 = status.mode == "match" and C.green or status.mode == "hop" and C.gold or status.active and C.cyan or C.muted
            stateDetail.Text = string.format("%s+ · ≥ %s/s · mapa %d · en %s %d", status.config.rarity, number(status.config.minIncome), info.count or 0, scope, info.rarityCount or 0)
            if status.mode == "hop" and info.continuingCycle then
                stateDetail.Text = status.config.rarity .. "+ observado en " .. scope .. " · no está aquí; sigo buscando"
            end
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
