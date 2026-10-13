-- Panel de filtros del detector. Recursos visuales y datos del propio juego.
local function mountEggFilterPanel(context)
    local search, api, session = context.search, context.api, context.session
    local readJson, writeJson = context.readJson, context.writeJson
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local FILE = "chilli_egg_panel_ui.json"
    local saved = readJson(FILE, {})
    local panel: { [string]: any } = { alive = true, open = saved.open ~= false, view = "map", cards = 0, matches = 0 }
    local onlyMatches = saved.onlyMatches == true
    -- Tamano elegido con el asa; la pantalla puede reducirlo al mostrarlo.
    local scaling = context.scaling
    local userScale = scaling.Panel(tonumber(saved.scale))
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
        scrim = Color3.fromRGB(6, 8, 11),
    }
    -- Rejilla de 8 px: margen 22, contenido 496, columnas 160/244 con hueco 8.
    local PANEL_WIDTH, PANEL_HEIGHT, ROW_HEIGHT, ROW_GAP = 540, 700, 100, 8
    local PAD, CONTENT = 22, 496
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
    -- Texto de varias lineas que se corta al final en lugar de salirse de su caja.
    local function paragraph(name, parent, value, x, y, width, height, color, size)
        local label = text(name, parent, value, x, y, width, height, color, size)
        label.TextWrapped = true; label.TextYAlignment = Enum.TextYAlignment.Top
        return label
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
    local function primary(object) paint(object, C.gold, C.onAccent, C.gold); object.Font = Enum.Font.GothamBold end
    local function field(name, parent, value, placeholder, x, y, width, height)
        local box = make("TextBox", name, parent, {
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = C.input, BorderSizePixel = 0, Text = value, PlaceholderText = placeholder,
            PlaceholderColor3 = C.muted, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = C.white,
            ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        corner(box); stroke(box); make("UIPadding", "Padding", box, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
        return box
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
                mark.BackgroundColor3 = value and C.selected or C.input
                mark.Border.Color = value and C.green or C.muted
            end
        end
        update(selected)
        return update, mark
    end
    -- Selector desplegable: texto a la izquierda y chevron en su propio margen.
    local function chevron(object)
        for index, rotation in ipairs({45, -45}) do
            local segment = line(object, "Chevron" .. index, 0, 0, 6, rotation, C.muted)
            -- Las posiciones son relativas al area con padding: el chevron vive en el margen.
            segment.Position = UDim2.new(1, index == 1 and 12 or 16, 0.5, 0)
        end
        object.TextXAlignment = Enum.TextXAlignment.Left
        make("UIPadding", "ChevronSpace", object, { PaddingRight = UDim.new(0, 30), PaddingLeft = UDim.new(0, 12) })
    end
    local function crossIcon(object)
        line(object, "Cross1", 16, 16, 12, 45, C.muted); line(object, "Cross2", 16, 16, 12, -45, C.muted)
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
    local function sentence(value)
        value = tostring(value or "")
        return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
    end
    local function escape(value)
        return (tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
    end
    local function hex(color)
        return string.format("#%02X%02X%02X", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
    end
    local zoneLabels = {}
    local function zoneName(id)
        if id == nil then return "Zona desconocida" end
        if next(zoneLabels) == nil then
            for _, option in ipairs(search.ZoneOptions()) do zoneLabels[option.id] = option.label end
        end
        return tostring(zoneLabels[id] or id)
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
    local function zonesText(list, everything)
        if everything then return "Todas las zonas" end
        if #list == 0 then return "Ninguna zona" end
        if #list == 1 then return zoneName(list[1]) end
        return string.format("%d zonas", #list)
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
    local launcher = button("OpenEggFilters", context.screenGui, "Egg Finder", 0, 0, 128, 36, C.bg)
    paint(launcher, C.bg, C.gold); launcher.Font = Enum.Font.GothamBold; launcher.TextSize = 13
    launcher.AnchorPoint = Vector2.new(1, 0); launcher.Position = UDim2.new(1, -18, 0, 18); launcher.ZIndex = 20
    launcher.Visible = not panel.open

    -- Cabecera: titulo a la izquierda, acciones a la derecha en una sola fila.
    local header = make("Frame", "Header", root, { Size = UDim2.new(1, 0, 0, 68), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true })
    text("Title", header, "Egg Finder", PAD, 14, 240, 28, C.white, 22, true)
    text("Subtitle", header, "Huevos disponibles en el mapa", PAD, 41, 240, 16, C.muted, 11)
    local minimize = button("Minimize", header, "", PAD + CONTENT - 32, 18, 32, 32)
    line(minimize, "Minus", 16, 16, 12, 0, C.muted)
    local auto = button("ToggleSearch", header, "AUTO OFF", PAD + CONTENT - 32 - 8 - 100, 18, 100, 32)
    auto.Font = Enum.Font.GothamBold
    make("UIPadding", "DotSpace", auto, { PaddingLeft = UDim.new(0, 16) })
    local autoDot = make("Frame", "Dot", auto, { Position = UDim2.new(0, -2, 0.5, -4), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.muted, BorderSizePixel = 0 })
    corner(autoDot, 4)
    local optionsButton = button("Options", header, "Opciones", PAD + CONTENT - 32 - 8 - 100 - 8 - 92, 18, 92, 32)
    make("Frame", "HeaderDivider", root, { Position = UDim2.fromOffset(PAD, 68), Size = UDim2.fromOffset(CONTENT, 1), BackgroundColor3 = C.border, BackgroundTransparency = 0.3, BorderSizePixel = 0 })

    -- Estado de la busqueda: titulo, explicacion de una linea y reloj del ciclo.
    local statusCard = make("Frame", "Status", root, { Position = UDim2.fromOffset(PAD, 80), Size = UDim2.fromOffset(CONTENT, 60), BackgroundColor3 = C.card, BorderSizePixel = 0 })
    corner(statusCard, 10); stroke(statusCard).Transparency = 0.45
    local stateDot = make("Frame", "StateDot", statusCard, { Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.muted, BorderSizePixel = 0 })
    corner(stateDot, 4)
    local stateTitle = text("SearchState", statusCard, "Conectando detector...", 30, 9, 334, 22, C.white, 15, true)
    local stateDetail = text("SearchDetail", statusCard, "", 14, 33, 350, 18, C.muted, 11)
    local clockCaption = text("ResetCaption", statusCard, "Renovación", CONTENT - 14 - 110, 10, 110, 14, C.muted, 10)
    local clock = text("ResetClock", statusCard, "--:--", CONTENT - 14 - 110, 26, 110, 24, C.cyan, 18, true)
    clockCaption.TextXAlignment = Enum.TextXAlignment.Right; clock.TextXAlignment = Enum.TextXAlignment.Right

    -- Filtros: cada control tiene su etiqueta encima y su propio ancho de columna.
    text("FiltersTitle", root, "Filtros", PAD, 156, 60, 26, C.white, 14, true)
    local filterSummary = text("FiltersSummary", root, "", PAD + 64, 156, 340, 26, C.muted, 11)
    local filterToggle = button("ToggleFilters", root, "Ocultar", PAD + CONTENT - 84, 155, 84, 28)
    local filters = make("Frame", "Filters", root, { Position = UDim2.fromOffset(PAD, 192), Size = UDim2.fromOffset(CONTENT, 174), BackgroundTransparency = 1, BorderSizePixel = 0 })
    text("RarityLabel", filters, "Rareza mínima", 0, 0, 160, 16, C.muted, 11)
    text("IncomeLabel", filters, "Ingreso mínimo /s", 168, 0, 160, 16, C.muted, 11)
    text("MutationLabel", filters, "Mutación", 336, 0, 160, 16, C.muted, 11)
    local rarityButton = button("Rarity", filters, draft.rarity, 0, 20, 160, 38)
    rarityButton.TextSize = 14; chevron(rarityButton)
    local income = field("MinimumIncome", filters, search.FormatMinimum(draft.minIncome), "Ej. 7b o 500m", 168, 20, 160, 38)
    income.Font = Enum.Font.GothamBold; income.TextColor3 = C.gold
    local mutationButton = button("Mutation", filters, draft.mutation == "" and "Todas" or draft.mutation, 336, 20, 160, 38)
    mutationButton.TextSize = 14; chevron(mutationButton)
    text("ZonesLabel", filters, "Zonas", 0, 70, 244, 16, C.muted, 11)
    text("NameLabel", filters, "Nombre contiene", 252, 70, 244, 16, C.muted, 11)
    local chooseZones = button("ChooseZones", filters, "Todas las zonas", 0, 90, 244, 38)
    chooseZones.TextSize = 14; chevron(chooseZones)
    local nameBox = field("NameFilter", filters, draft.nameContains, "Cualquier nombre", 252, 90, 244, 38)
    local changeLabel = text("Changes", filters, "Filtros guardados", 0, 140, 324, 34, C.muted, 11)
    changeLabel.TextWrapped = true
    local apply = button("ApplyFilters", filters, "Aplicar filtros", 336, 138, 160, 38)
    primary(apply); apply.TextSize = 13

    -- Barra de la lista: alcance segmentado, vista y orden.
    local toolbar = make("Frame", "ListBar", root, { Position = UDim2.fromOffset(PAD, 382), Size = UDim2.fromOffset(CONTENT, 32), BackgroundTransparency = 1 })
    local tabMap = button("MapTab", toolbar, "Todos", 0, 0, 118, 32)
    local tabCatalog = button("CatalogTab", toolbar, "Cumplen", 126, 0, 118, 32)
    local visualButton = button("VisualMode", toolbar, "Ver: Huevos", 252, 0, 118, 32)
    local sortButton = button("Sort", toolbar, "Orden: Rareza", 378, 0, 118, 32)
    local scroll = make("ScrollingFrame", "EggCards", root, {
        Position = UDim2.fromOffset(20, 424), Size = UDim2.fromOffset(500, 240), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    make("UIPadding", "Padding", scroll, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 4) })
    local foot = text("Hint", root, "Alt izquierdo muestra u oculta el panel · toca una tarjeta para ver el detalle", PAD, 674, CONTENT, 14, C.muted, 10)
    foot.TextXAlignment = Enum.TextXAlignment.Center
    local function save()
        access()
        local ok = writeJson(FILE, { open = panel.open, visual = visual, filtersOpen = filtersOpen,
            view = "map", onlyMatches = onlyMatches, sortBest = sortBest,
            x = root.Position.X.Offset, y = root.Position.Y.Offset, scale = userScale })
        if not ok then panel.error = "No se pudo guardar la posición / vista"; warn("[EggPanel] " .. panel.error) end
    end
    local function closePopup() if popup then popup:Destroy(); popup = nil end end
    -- Hojas modales: el velo bloquea el panel y tocarlo cierra solo la hoja.
    local function sheet(name, title, y, height)
        closePopup()
        local scrim = make("TextButton", name, root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim,
            BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 50 })
        corner(scrim, 14)
        local card = make("Frame", "Sheet", scrim, { Position = UDim2.fromOffset(PAD, y), Size = UDim2.fromOffset(CONTENT, height),
            BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, ZIndex = 51 })
        corner(card, 12); stroke(card)
        local heading = text("Title", card, title, 18, 16, CONTENT - 86, 24, C.white, 17, true)
        local dismiss = button("Dismiss", card, "", CONTENT - 50, 12, 32, 32); crossIcon(dismiss)
        scrim.Activated:Connect(function() access(); closePopup() end)
        dismiss.Activated:Connect(function() access(); closePopup() end)
        popup = scrim
        return card, heading
    end
    local function listFrame(parent, y, height)
        local list = make("ScrollingFrame", "Options", parent, { Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(CONTENT - 28, height),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 })
        make("UIPadding", "Padding", list, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 2) })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
        return list
    end
    local function layout()
        access()
        filters.Visible = filtersOpen; filterToggle.Text = filtersOpen and "Ocultar" or "Mostrar"
        local y = filtersOpen and 382 or 192
        toolbar.Position = UDim2.fromOffset(PAD, y)
        scroll.Position = UDim2.fromOffset(20, y + 42); scroll.Size = UDim2.fromOffset(500, 664 - (y + 42))
        closePopup(); signature = nil
    end
    local initializedPosition = false
    local function fitLimit()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local viewport = camera.ViewportSize
        return math.min((viewport.X - 28) / PANEL_WIDTH, (viewport.Y - 28) / PANEL_HEIGHT)
    end
    local function fit()
        access()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = scaling.Panel(userScale, fitLimit())
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
    local function setMessage(value, color)
        access(); changeLabel.Text = value; changeLabel.TextColor3 = color or C.muted
    end
    local function markDirty()
        access()
        dirty = true; signature = nil
        chooseZones.Text = zonesText(selectionList(), allZones)
        setMessage("Cambios sin aplicar. AUTO sigue usando los filtros guardados.", C.gold)
    end
    local function setDraft(config)
        local minimumText = search.FormatMinimum(config.minIncome)
        access()
        draft = cloneConfig(config); selection = {}; for _, id in ipairs(draft.zones) do selection[id] = true end
        allZones = #draft.zones == 0
        income.Text = minimumText; nameBox.Text = draft.nameContains
        rarityButton.Text = draft.rarity
        local labelOk, label = pcall(function() return data.mutations and data.mutations.LabelOf(draft.mutation) end)
        access()
        mutationButton.Text = draft.mutation == "" and "Todas" or (labelOk and label and tostring(label) or draft.mutation)
        chooseZones.Text = zonesText(draft.zones, allZones)
        dirty = false; setMessage("Filtros guardados."); signature = nil
    end
    function panel.Apply()
        access()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if not minimum then
            setMessage("Ingreso mínimo inválido. Usa k, m, b, t o q: 500m, 7.5b.", C.red); return false
        end
        if not allZones and #selectionList() == 0 then
            setMessage("Elige al menos una zona, o marca Todas.", C.red)
            return false
        end
        local patch = { rarity = draft.rarity, minIncome = minimum, mutation = draft.mutation,
            nameContains = nameBox.Text, zones = selectionList() }
        local ok, config = pcall(api.Configure, patch)
        access()
        if not ok then setMessage(sentence(config), C.red); return false end
        setDraft(config); closePopup(); panel.SetOnlyMatches(true)
        setMessage("Filtros aplicados. La lista muestra solo los huevos que cumplen.", C.green)
        return true
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
    local function luminance(color)
        local function linear(component)
            return component <= 0.04045 and component / 12.92 or ((component + 0.055) / 1.055) ^ 2.4
        end
        return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
    end
    local function rarityColor(rarity, fallback)
        local color = type(rarity) == "table" and rarity.Color
        if typeof(color) ~= "Color3" then return fallback or C.gold end
        -- Preservar el tono oficial; Secret y colores oscuros necesitan mas contraste.
        local background = math.max(luminance(C.card), luminance(C.selected), luminance(C.success))
        color = color:Lerp(C.white, 0.25)
        for _ = 1, 10 do
            if (luminance(color) + 0.05) / (background + 0.05) >= 4.5 then break end
            color = color:Lerp(C.white, 0.15)
        end
        return color
    end
    local function dropdown(kind, options, current, select)
        local card = sheet("Dropdown", kind == "rarity" and "Rareza mínima" or "Mutación", 120, 452)
        text("Hint", card, kind == "rarity" and "Incluye la rareza elegida y todas las superiores."
            or "Muestra solo huevos que tengan esta mutación.", 18, 44, CONTENT - 36, 16, C.muted, 11)
        local list = listFrame(card, 72, 364)
        for index, item in ipairs(options) do
            local selected = item.id == current
            local b = button("Option_" .. index, list, "", 0, 0, 0, 40)
            b.Size = UDim2.new(1, -2, 0, 40); b.LayoutOrder = index
            local label = text("Label", b, item.label, 14, 0, 0, 40, item.color or C.white, 14, selected)
            label.Size = UDim2.new(1, -56, 1, 0)
            if selected then
                paint(b, C.selected, C.white, C.green)
                local _, mark = selectionIcon(b, true, 0, 0); mark.Position = UDim2.new(1, -38, 0.5, -12)
            end
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
        local options = search.ZoneOptions()
        access()
        if #options == 0 then setMessage("Esperando la lista de zonas del juego..."); return end
        local card = sheet("ZonePicker", "Zonas", 64, 580)
        local counter = text("Hint", card, "", 18, 44, CONTENT - 36, 16, C.muted, 11)
        local selectAll = button("SelectAll", card, "Todas", 18, 72, 110, 32)
        local clearZones = button("ClearSelection", card, "Ninguna", 136, 72, 110, 32)
        local list = listFrame(card, 116, 396)
        text("Footer", card, "Se guardan al pulsar Aplicar filtros.", 18, 528, 300, 36, C.muted, 11)
        local done = button("Done", card, "Listo", CONTENT - 18 - 120, 528, 120, 36); primary(done)
        done.Activated:Connect(function() access(); closePopup() end)
        local checks = {}
        local function refreshChecks()
            access()
            local count = #selectionList()
            counter.Text = allZones and "Todas las zonas: no se excluye ninguna."
                or string.format("%d de %d zonas seleccionadas", count, #options)
            counter.TextColor3 = (not allZones and count == 0) and C.red or C.muted
            for id, entry in pairs(checks) do
                local selected = allZones or selection[id] == true
                entry.check(selected)
                paint(entry.button, selected and C.selected or C.card, C.white, selected and C.green or C.border)
            end
        end
        for index, option in ipairs(options) do
            local b = button("Zone_" .. option.id, list, "", 0, 0, 0, 44)
            b.Size = UDim2.new(1, -2, 0, 44); b.LayoutOrder = index
            text("Name", b, option.label, 14, 0, 0, 44, C.white, 14, true).Size = UDim2.new(1, -60, 1, 0)
            local update, mark = selectionIcon(b, false, 0, 0, nil, true); mark.Position = UDim2.new(1, -38, 0.5, -12)
            checks[option.id] = {button = b, check = update}
            b.Activated:Connect(function()
                access(); panel.SelectZone(option.id); refreshChecks()
            end)
        end
        selectAll.Activated:Connect(function() access(); panel.SelectAllZones(); refreshChecks() end)
        clearZones.Activated:Connect(function() access(); panel.ClearZones(); refreshChecks() end)
        refreshChecks()
    end
    panel.OpenZones = function() access(); zonePicker() end
    -- Motivo corto para la insignia; el detalle conserva la frase completa.
    local SHORT_REASONS = {
        ["Cumple todos los filtros"] = "Cumple", ["Rareza inferior al mínimo"] = "Rareza baja",
        ["Zona excluida"] = "Otra zona", ["Nombre distinto"] = "Otro nombre",
        ["Falta la mutación elegida"] = "Sin mutación", ["Ingreso inferior al mínimo"] = "Ingreso bajo",
    }
    -- Best egg of the cycle: the explicit message says where it is now.
    local BEST_TEXT = {
        here = "MEJOR DEL CICLO · está en este servidor",
        gone = "MEJOR DEL CICLO · ya no está en este servidor",
        other = "MEJOR DEL CICLO · visto en otro servidor",
        seen = "MEJOR DEL CICLO · visto antes en este servidor",
    }
    local function detail(row)
        access()
        local card = sheet("EggDetail", row.name, 120, row.best and 442 or 400)
        local tags = text("Tags", card, "", 18, 44, CONTENT - 36, 18, C.muted, 12)
        tags.RichText = true
        tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s', hex(rarityColor(row.catalog and row.catalog.Rarity)),
            escape(row.rarity), escape(zoneName(row.area)))
        local verdict = make("Frame", "Verdict", card, { Position = UDim2.fromOffset(18, 74), Size = UDim2.fromOffset(CONTENT - 36, 40),
            BackgroundColor3 = row.match and C.success or C.card, BorderSizePixel = 0 })
        corner(verdict); stroke(verdict, row.match and C.green or C.border)
        text("Text", verdict, row.best and BEST_TEXT[row.best] or row.match and "Cumple todos los filtros"
            or "No cumple: " .. string.lower(row.reason),
            14, 0, CONTENT - 64, 40, row.best and C.gold or row.match and C.green or C.white, 13, true)
        local value = row.income and string.format("%.17g", row.income) .. "/s" or "No disponible"
        local facts = {
            {"Ingreso", row.income and number(row.income) .. "/s" or "No disponible"},
            {"Ingreso exacto", value},
            {"Mínimo guardado", search.FormatMinimum(search.config.minIncome) .. "/s"},
            {"Tamaño y peso", string.format("x%.2f  ·  %s", row.scale or 1, row.weight)},
            {"Mutaciones", row.mutations},
            {"Zona", zoneName(row.area)},
        }
        if row.best then table.insert(facts, {"Filtros", row.match and "Cumple todos los filtros" or row.reason}) end
        for index, fact in ipairs(facts) do
            local y = 126 + (index - 1) * 42
            text("Label" .. index, card, fact[1], 18, y, 150, 42, C.muted, 12)
            text("Value" .. index, card, fact[2], 172, y, CONTENT - 190, 42, C.white, 13, true)
            if index < #facts then
                make("Frame", "Divider" .. index, card, { Position = UDim2.fromOffset(18, y + 41), Size = UDim2.fromOffset(CONTENT - 36, 1),
                    BackgroundColor3 = C.border, BackgroundTransparency = 0.5, BorderSizePixel = 0 })
            end
        end
    end
    local function createCard(row)
        local entry = {row = row}
        local card = make("TextButton", "Card_" .. row.uid, scroll, {Size = UDim2.new(1, -2, 0, ROW_HEIGHT),
            BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", AutoButtonColor = true})
        entry.card = card; corner(card, 10); entry.border = stroke(card); interaction(card)
        entry.box = make("Frame", "Visual", card, {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1, BorderSizePixel = 0})
        entry.image = make("ImageLabel", "EggImage", entry.box, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
        entry.name = text("Name", card, "", 100, 10, 0, 20, C.white, 15, true)
        entry.name.Size = UDim2.new(1, -212, 0, 20)
        entry.income = text("Income", card, "", 100, 32, 0, 24, C.white, 20, true)
        entry.income.Size = UDim2.new(1, -212, 0, 24)
        entry.weight = text("SizeWeight", card, "", 100, 58, 0, 16, C.muted, 11)
        entry.weight.Size = UDim2.new(1, -136, 0, 16)
        entry.tags = text("Tags", card, "", 100, 76, 0, 16, C.muted, 11)
        entry.tags.Size = UDim2.new(1, -136, 0, 16); entry.tags.RichText = true
        entry.badge = make("Frame", "Badge", card, {Position = UDim2.new(1, -104, 0, 10), Size = UDim2.fromOffset(92, 22), BorderSizePixel = 0})
        corner(entry.badge, 11); entry.badgeBorder = stroke(entry.badge)
        entry.match = text("Match", entry.badge, "", 0, 0, 92, 22, C.muted, 10, true)
        entry.match.TextXAlignment = Enum.TextXAlignment.Center
        local open = make("Frame", "Open", card, {Position = UDim2.new(1, -28, 0, 60), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1})
        line(open, "Upper", 8, 5, 7, 45, C.muted); line(open, "Lower", 8, 10, 7, -45, C.muted)
        card.Activated:Connect(function() access(); detail(entry.row) end)
        panel.stats.created += 1
        return entry
    end
    local function updateCard(entry, row, index)
        access(); entry.row = row
        entry.card.LayoutOrder = index; entry.card.Position = UDim2.fromOffset(0, (index - 1) * (ROW_HEIGHT + ROW_GAP))
        local key = row.key .. tostring(row.match) .. row.reason .. row.mutations
            .. tostring(row.weight) .. tostring(row.eggIcon) .. visual .. tostring(row.best)
        if entry.key == key and (visual ~= "models" or entry.viewport or not data.assetModels) then return end
        entry.key = key; panel.stats.updated += 1
        entry.card.Name = "Card_" .. row.uid
        entry.card.BackgroundColor3 = row.match and C.success or C.card
        entry.border.Color = row.best and C.gold or row.match and C.green or C.border
        entry.border.Thickness = (row.match or row.best) and 1.5 or 1
        entry.name.Text = row.name; entry.name.TextColor3 = C.white
        entry.income.Text = (row.income and number(row.income) or "?") .. "/s"
        entry.income.TextColor3 = row.match and C.green or row.best and C.gold or C.white
        entry.weight.Text = row.best and BEST_TEXT[row.best] or string.format("x%.2f  ·  %s", row.scale or 1, row.weight)
        entry.weight.TextColor3 = row.best and C.gold or C.muted
        entry.weight.Font = row.best and Enum.Font.GothamBold or Enum.Font.GothamMedium
        entry.tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s  ·  %s',
            hex(rarityColor(row.catalog and row.catalog.Rarity)), escape(row.rarity), escape(row.mutations), escape(zoneName(row.area)))
        entry.match.Text = row.match and "Cumple" or (SHORT_REASONS[row.reason] or "Sin datos")
        entry.match.TextColor3 = row.match and C.onSuccess or C.muted
        entry.badge.BackgroundColor3 = row.match and C.green or C.input
        entry.badge.BackgroundTransparency = row.match and 0 or 0.2
        entry.badgeBorder.Color = row.match and C.green or C.border
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
        local total, matches = 0, 0
        local function describe(uid, key, egg, catalog, income)
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
            return {uid = uid, key = key, category = tostring(egg.AssetCategory or "Desconocida"), catalog = catalog,
                name = tostring(catalog and catalog.DisplayName or egg.AssetCategory or "Desconocida"), rarity = tostring(rarityId or "Desconocida"),
                rarityRank = rank and rank.Rank or 0, income = income, scale = egg.AssetScale,
                weight = weightOk and weight or "peso no disponible", eggIcon = iconOk and icon or nil,
                mutations = #labels > 0 and table.concat(labels, " + ") or "Sin mutaciones", area = egg.AreaId, labelModule = data.mutations}
        end
        -- Best in-scope egg of this cycle, kept by the detector across servers.
        local bestSeen = search.BestSeen()
        local bestHere = false
        for _, item in ipairs(snapshot.rows or {}) do
            active[item.uid] = true
            total += 1; if item.match then matches += 1 end
            local here = bestSeen ~= nil and bestSeen.job == game.JobId and search.EggKey(item.egg) == bestSeen.key
            if here then bestHere = true end
            if not onlyMatches or item.match or here then
                local row = metadata[item.uid]
                if not row or row.key ~= item.key or row.labelModule ~= data.mutations then
                    row = describe(item.uid, item.key, item.egg, item.catalog, item.income)
                    metadata[item.uid] = row
                end
                row.income, row.match, row.reason = item.income, item.match, item.reason
                row.best = here and "here" or nil
                table.insert(rows, row); table.insert(fingerprints, row.uid .. row.key .. tostring(row.income) .. tostring(row.match) .. tostring(row.best))
            end
        end
        -- The reminder joins "Cumplen" when the egg is not on this map anymore.
        local remembered = bestSeen ~= nil and onlyMatches and not bestHere
            and modules.assets.Directory[bestSeen.category] or nil
        if remembered then
            local uid = "best-seen"
            active[uid] = true
            local egg = {AssetCategory = bestSeen.category, AssetScale = bestSeen.scale, AreaId = bestSeen.area,
                BaseMutation = bestSeen.baseMutation, Mutations = bestSeen.mutations}
            local row = metadata[uid]
            local key = "best:" .. bestSeen.key
            if not row or row.key ~= key or row.labelModule ~= data.mutations then
                row = describe(uid, key, egg, remembered, bestSeen.income)
                metadata[uid] = row
            end
            local ok, reason = pcall(search.Explain, egg, remembered, bestSeen.income)
            row.income, row.match, row.reason = bestSeen.income, false, ok and reason or "Datos de especie no disponibles"
            row.best = bestSeen.job ~= game.JobId and "other" or snapshot.info.ready and "gone" or "seen"
            table.insert(rows, row); table.insert(fingerprints, row.uid .. row.key .. tostring(row.income) .. row.reason .. row.best)
        end
        for id in pairs(metadata) do if not active[id] then metadata[id] = nil end end
        local key = table.concat(fingerprints, "|")
        if key ~= rowsKey then
            table.sort(rows, function(a,b)
                -- The reminder is pinned first in "Cumplen".
                if onlyMatches and (a.best ~= nil) ~= (b.best ~= nil) then return a.best ~= nil end
                if sortBest and a.rarityRank ~= b.rarityRank then return a.rarityRank > b.rarityRank end
                if sortBest and (a.income or 0) ~= (b.income or 0) then return (a.income or 0) > (b.income or 0) end
                if a.category ~= b.category then return a.category < b.category end
                return a.uid < b.uid
            end)
            orderedRows, rowsKey = rows, key
        end
        access(); panel.cards = #orderedRows; panel.matches = matches
        tabMap.Text = string.format("Todos  %d", total); tabCatalog.Text = string.format("Cumplen  %d", matches)
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
            if not empty then
                empty = paragraph("Empty", scroll, "", 24, 40, 440, 90, C.muted, 13)
                empty.TextXAlignment = Enum.TextXAlignment.Center
            end
            empty.Text = not snapshot.info.ready and sentence(snapshot.info.reason or "esperando datos del mapa") .. "."
                or onlyMatches and "Ningún huevo del mapa cumple todos los filtros.\nPrueba con un ingreso menor, más zonas o pulsa Todos para ver el mapa completo."
                or "No hay huevos disponibles en el mapa ahora."
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
        setMessage("Preset «" .. tostring(name) .. "» cargado. Pulsa Aplicar filtros para usarlo.", C.gold)
        return config
    end
    function panel.SavePreset(name)
        access()
        local minimum = search.ParseMinimum(income.Text)
        assert(minimum, "Ingreso mínimo inválido; usa 500k, 25m o 7.5b")
        assert(allZones or #selectionList() > 0, "Elige al menos una zona")
        return api.SavePreset(name, {rarity = draft.rarity, minIncome = minimum, mutation = draft.mutation,
            nameContains = nameBox.Text, zones = selectionList()})
    end
    local function caption(parent, value, y) text("Section", parent, value, 18, y, CONTENT - 36, 16, C.muted, 11, true) end
    function panel.OpenOptions(notice)
        access()
        local card = sheet("FinderOptions", "Opciones", 60, 590)
        caption(card, "PRESETS", 54)
        local name = field("PresetName", card, "", "Nombre del preset", 18, 76, 296, 36)
        local savePreset = button("SavePreset", card, "Guardar actuales", 322, 76, 156, 36); primary(savePreset)
        local message = paragraph("Message", card, notice or "Guarda los filtros del formulario. Al cargar uno, pulsa Aplicar filtros para usarlo.",
            18, 120, CONTENT - 36, 30, C.muted, 11)
        local list = listFrame(card, 156, 214)
        local function result(callback)
            local ok, err = pcall(callback); access()
            if not ok and popup then message.Text = sentence(err); message.TextColor3 = C.red end
            return ok
        end
        local presets = api.Presets()
        for index, preset in ipairs(presets) do
            local row = make("Frame", "Preset_" .. index, list, {Size = UDim2.new(1, -2, 0, 52), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = index})
            corner(row); stroke(row).Transparency = 0.45
            text("Name", row, preset.name, 14, 8, 0, 18, C.white, 14, true).Size = UDim2.new(1, -196, 0, 18)
            local minimum = tonumber(preset.config.minIncome)
            local summary = minimum and minimum > 0 and minimum < math.huge and search.FormatMinimum(minimum) .. "/s" or "ingreso inválido"
            local zones = type(preset.config.zones) == "table" and preset.config.zones or {}
            text("Summary", row, string.format("%s+  ·  desde %s  ·  %s", tostring(preset.config.rarity or "Sin rareza"), summary,
                zonesText(zones, #zones == 0)), 14, 28, 0, 16, C.muted, 11).Size = UDim2.new(1, -196, 0, 16)
            local load = button("Load", row, "Cargar", 0, 10, 82, 32); load.Position = UDim2.new(1, -176, 0, 10)
            local delete = button("Delete", row, "Borrar", 0, 10, 82, 32); delete.Position = UDim2.new(1, -88, 0, 10)
            delete.TextColor3 = C.red
            load.Activated:Connect(function() access(); result(function() panel.LoadPreset(preset.name) end) end)
            delete.Activated:Connect(function() access(); if result(function() api.DeletePreset(preset.name) end) then panel.OpenOptions("Preset borrado.") end end)
        end
        if #presets == 0 then paragraph("Empty", list, "Todavía no hay presets. Escribe un nombre y pulsa Guardar actuales.", 4, 12, 440, 40, C.muted, 12) end
        savePreset.Activated:Connect(function() access(); if result(function() panel.SavePreset(name.Text) end) then panel.OpenOptions("Preset guardado.") end end)
        caption(card, "ALERTAS", 384)
        local settings = api.Alerts()
        local function toggle(nameValue, label, enabled, x)
            local b = button(nameValue, card, label .. (enabled and ": activada" or ": desactivada"), x, 406, 226, 38)
            if enabled then paint(b, C.selected, C.green, C.green) else paint(b, C.card, C.muted, C.border) end
            return b
        end
        local notification = toggle("Notification", "Notificación", settings.notification, 18)
        local sound = toggle("Sound", "Sonido", settings.sound, 252)
        notification.Activated:Connect(function() access(); if result(function() api.ConfigureAlerts({notification = not settings.notification}) end) then panel.OpenOptions() end end)
        sound.Activated:Connect(function() access(); if result(function() api.ConfigureAlerts({sound = not settings.sound}) end) then panel.OpenOptions() end end)
        local test = button("TestAlert", card, "Probar alerta", 18, 452, 226, 38)
        test.Activated:Connect(function() access(); result(api.TestAlert) end)
        paragraph("AlertHint", card, "Al encontrar un objetivo se avisa; AUTO espera la captura.", 252, 452, 226, 38, C.muted, 11).TextYAlignment = Enum.TextYAlignment.Center
        if type(api.OpenServerAccount) == "function" then
            caption(card, "SERVIDORES", 506)
            local account = button("ServerAccount", card, "Cuenta y Best Ping", 18, 528, CONTENT - 36, 40)
            account.Activated:Connect(function() access(); closePopup(); api.OpenServerAccount() end)
        end
    end
    connect(optionsButton.Activated, function() panel.OpenOptions() end)
    function panel.GetStatus()
        access(); return { open = panel.open, view = "map", onlyMatches = onlyMatches, cards = panel.cards, matches = panel.matches, dirty = dirty, error = panel.error,
            selected = selectionList(), allZones = allZones, visual = visual, sortBest = sortBest, position = {x = root.AbsolutePosition.X, y = root.AbsolutePosition.Y},
            size = {x = root.AbsoluteSize.X, y = root.AbsoluteSize.Y}, scale = scale.Scale, userScale = userScale,
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
    connect(income:GetPropertyChangedSignal("Text"), function()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if minimum ~= draft.minIncome then markDirty() end
    end)
    for _, input in ipairs({income, nameBox}) do
        connect(input.Focused, function() input.Border.Color = C.gold; input.Border.Transparency = 0; input.Border.Thickness = 1.5 end)
        connect(input.FocusLost, function() input.Border.Color = C.border; input.Border.Thickness = 1 end)
    end
    connect(nameBox:GetPropertyChangedSignal("Text"), function()
        if nameBox.Text ~= draft.nameContains then markDirty() end
    end)
    connect(chooseZones.Activated, function() panel.OpenZones() end)
    connect(tabCatalog.Activated, function() panel.SetOnlyMatches(true) end)
    connect(tabMap.Activated, function() panel.SetOnlyMatches(false) end)
    connect(sortButton.Activated, function() panel.SetSortBest(not sortBest) end)
    connect(visualButton.Activated, function() panel.SetVisual(visual == "eggs" and "pets" or visual == "pets" and "models" or "eggs") end)
    connect(rarityButton.Activated, function()
        if not search.modules then setMessage("Cargando las rarezas del juego..."); return end
        local options = search.RarityOptions()
        local rarities = search.modules.rarities and search.modules.rarities.Rarities or {}
        for _, option in ipairs(options) do option.color = rarityColor(rarities[option.id], C.white) end
        dropdown("rarity", options, draft.rarity, function(id) draft.rarity = id; rarityButton.Text = id end)
    end)
    connect(mutationButton.Activated, function()
        if not data.mutations then setMessage("Cargando las mutaciones del juego..."); return end
        local options = {}; for id in pairs(data.mutations.IdSet) do table.insert(options, { id = id, label = data.mutations.LabelOf(id) }) end
        table.sort(options, function(a, b) return a.label < b.label end)
        table.insert(options, 1, { id = "", label = "Todas las mutaciones" })
        dropdown("mutation", options, draft.mutation, function(id)
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
    -- Asa de tamano: tres trazos diagonales dentro de la esquina redondeada.
    -- Escala todo el panel con la esquina superior izquierda fija; las hojas
    -- modales (ZIndex 50) la cubren mientras estan abiertas.
    local grip = make("TextButton", "ResizeGrip", root, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })
    local gripTraces = {}
    for index, trace in ipairs({ {11, 5}, {16, 11}, {21, 17} }) do -- distancia a la esquina, largo
        local mark = line(grip, "Trace" .. index, 0, 0, trace[2], -45, C.muted, 5)
        mark.Position = UDim2.new(1, -trace[1] / 2, 1, -trace[1] / 2); mark.BackgroundTransparency = 0.4
        gripTraces[index] = mark
    end
    local gripHover, resizeInput, resizeStart, resizeScale = false, nil, nil, nil
    local function paintGrip()
        access()
        local active = gripHover or resizeInput ~= nil
        for _, mark in ipairs(gripTraces) do
            TweenService:Create(mark, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundColor3 = active and C.gold or C.muted, BackgroundTransparency = active and 0 or 0.4 }):Play()
        end
    end
    connect(grip.MouseEnter, function() gripHover = true; paintGrip() end)
    connect(grip.MouseLeave, function() gripHover = false; paintGrip() end)
    connect(grip.InputBegan, function(input)
        if resizeInput or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
        dragging = false
        resizeInput, resizeStart, resizeScale = input, input.Position, scale.Scale
        paintGrip()
    end)
    connect(UIS.InputChanged, function(input)
        if not resizeInput then return end
        if resizeInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= resizeInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local base = Vector2.new(PANEL_WIDTH, PANEL_HEIGHT)
        userScale = scaling.Panel(scaling.Drag(resizeScale, base, input.Position - resizeStart), fitLimit())
        fit()
    end)
    local function finishResize()
        if not resizeInput then return end
        resizeInput, resizeStart, resizeScale = nil, nil, nil
        paintGrip(); save()
    end
    connect(UIS.InputEnded, function(input)
        if resizeInput and (input == resizeInput or (resizeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)) then finishResize() end
    end)
    connect(UIS.WindowFocusReleased, finishResize)
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
            local config = status.config
            auto.Text = status.active and "AUTO ON" or "AUTO OFF"
            paint(auto, status.active and C.green or C.card, status.active and C.onSuccess or C.muted, status.active and C.green or C.border)
            autoDot.BackgroundColor3 = status.active and C.onSuccess or C.muted
            visualButton.Text = visual == "eggs" and "Ver: Huevos" or visual == "pets" and "Ver: Criaturas" or "Ver: Modelos 3D"
            sortButton.Text = sortBest and "Orden: Rareza" or "Orden: Nombre"
            paint(tabCatalog, onlyMatches and C.selected or C.card, onlyMatches and C.green or C.muted, onlyMatches and C.green or C.border)
            paint(tabMap, not onlyMatches and C.selected or C.card, not onlyMatches and C.green or C.muted, not onlyMatches and C.green or C.border)
            local summary = string.format("%s+  ·  desde %s/s", config.rarity, search.FormatMinimum(config.minIncome))
            filterSummary.Text = string.format("%s  ·  %s", summary, zonesText(config.zones, #config.zones == 0))
            local cycle = status.cycle
            local info = status.lastScan and status.lastScan.info or {}
            local scope = #config.zones > 0 and "tus zonas" or "el mapa"
            local titles = { wait = "Esperando " .. config.rarity .. "+", hop = "Buscando otro servidor", loading = "Leyendo el mapa",
                match = "Objetivo encontrado", stopped = "Búsqueda detenida" }
            -- The panel's own map scans replace lastScan, so the target of this
            -- server comes from the saved cycle.
            local window = status.searchWindow
            local target = window and type(window.matched) == "table" and window.matched.job == status.jobId
                and window.matched or nil
            local captured = target and target.captured == true
            if status.mode == "wait" and captured then titles.wait = "Capturado" end
            stateTitle.Text = titles[status.mode] or "Revisando el mapa"
            stateTitle.TextColor3 = (status.mode == "match" or captured) and C.green or C.white
            stateDot.BackgroundColor3 = (status.mode == "match" or captured) and C.green or status.mode == "hop" and C.gold or status.active and C.cyan or C.muted
            local details = {
                wait = captured and "AUTO sigue activo y espera aquí el nuevo ciclo."
                    or string.format("Ninguno en %s. Se revisa al renovarse.", scope),
                hop = target and not captured and "No se capturó; busco otro servidor."
                    or info.continuingCycle and "Ya apareció en este ciclo; aquí no está. Sigo buscando."
                    or string.format("%d %s+ en %s, ninguno cumple los filtros.", info.rarityCount or 0, config.rarity, scope),
                loading = sentence(info.reason or "esperando datos del mapa") .. ".",
                match = "AUTO sigue activo y espera la captura.",
                stopped = "Pulsa AUTO para buscar " .. summary .. ".",
            }
            stateDetail.Text = details[status.mode] or string.format("%d huevos en el mapa  ·  %d %s+ en %s", info.count or 0, info.rarityCount or 0, config.rarity, scope)
            if cycle then
                local seconds = math.max(0, math.ceil(cycle.secondsUntilReset))
                clockCaption.Text = "Renovación en"; clock.Text = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
                if cycle.night then clockCaption.Text = "Huevos"; clock.Text = "Renovando" end
                if not cycle.running then clockCaption.Text = "Ciclo"; clock.Text = "En pausa" end
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
