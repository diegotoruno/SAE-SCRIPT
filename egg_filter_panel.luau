-- Panel de filtros del detector. Recursos visuales y datos del propio juego.
local function mountEggFilterPanel(context)
    local search, api, session = context.search, context.api, context.session
    local readJson, writeJson = context.readJson, context.writeJson
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local FILE = "chilli_egg_panel_ui.json"
    local saved = readJson(FILE, {})
    -- Oculto solo se recuerda con teclado: sin Alt izquierdo (iPad) el hub no
    -- tendria forma de volver, asi que se muestra (plegado si se dejo asi). El
    -- primer arranque del hub (archivo sin tab) tambien lo muestra una vez.
    local panel: { [string]: any } = { alive = true, open = saved.open ~= false or saved.tab == nil or not UIS.KeyboardEnabled,
        view = "map", cards = 0, matches = 0 }
    local onlyMatches = saved.onlyMatches == true
    -- Ultima especie, peso y mutaciones de la calculadora.
    local calc = type(saved.calc) == "table" and saved.calc or {}
    calc = { category = type(calc.category) == "string" and calc.category or nil,
        weight = type(calc.weight) == "string" and calc.weight or "",
        mutations = type(calc.mutations) == "table" and calc.mutations or {},
        -- Escala exacta del huevo abierto, valida mientras el peso no cambie.
        scale = tonumber(calc.scale), scaleWeight = type(calc.scaleWeight) == "string" and calc.scaleWeight or nil }
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
    -- Mistake Hub: cabecera de 56, barra lateral de 172 y paginas de 548 x 472
    -- con margen de 20. Plegado queda solo la cabecera, de 340 de ancho.
    local HUB_WIDTH, HUB_HEIGHT, HEADER, SIDEBAR, MINI_WIDTH = 760, 560, 56, 172, 340
    local PAD = 20
    local CONTENT = HUB_WIDTH - SIDEBAR - 2 * PAD
    local PAGE_X, PAGE_Y = SIDEBAR + PAD, HEADER + 16
    local PAGE_H = HUB_HEIGHT - PAGE_Y - 16
    -- Las hojas modales ocupan el area de paginas, nunca mas alto.
    local SHEET_TOP, SHEET_SPACE = HEADER + 12, HUB_HEIGHT - HEADER - 24
    local ROW_HEIGHT, ROW_GAP = 100, 8
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
    local sortBest = saved.sortBest ~= false
    -- Secciones del hub, en el orden de la barra lateral.
    local TABS = {
        {id = "finder", label = "Egg Finder"}, {id = "filters", label = "Filtros"},
        {id = "calc", label = "Calculadora"}, {id = "hop", label = "Server Hop"},
        {id = "settings", label = "Ajustes"},
    }
    local tab = "finder"
    for _, item in ipairs(TABS) do if item.id == saved.tab then tab = item.id end end
    local minimized = saved.minimized == true
    local root = make("Frame", "MistakeHub", context.screenGui, {
        Size = UDim2.fromOffset(HUB_WIDTH, HUB_HEIGHT), Position = UDim2.fromOffset(80, 70),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = panel.open, Active = true,
        ClipsDescendants = true, ZIndex = 10,
    })
    corner(root, 14); stroke(root, C.border)
    local scale = make("UIScale", "ResponsiveScale", root, { Scale = 1 })

    -- Cabecera: marca a la izquierda, AUTO y plegar a la derecha. Arrastra el hub
    -- y, plegada, es lo unico que queda en pantalla.
    local header = make("Frame", "Header", root, { Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true })
    local logo = make("TextLabel", "Logo", header, { Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = C.gold, BorderSizePixel = 0, Text = "M", TextColor3 = C.onAccent, TextSize = 18,
        Font = Enum.Font.GothamBold, TextStrokeTransparency = 1 })
    corner(logo, 8)
    text("Title", header, "Mistake Hub", 58, 10, 120, 22, C.white, 17, true)
    text("Subtitle", header, "Steal An Egg", 58, 31, 120, 14, C.muted, 11)
    local minimize = button("Minimize", header, "", 0, 12, 32, 32)
    minimize.Position = UDim2.new(1, -48, 0, 12)
    line(minimize, "Minus", 16, 16, 12, 0, C.muted)
    local expandMark = line(minimize, "Plus", 16, 16, 12, 90, C.muted)
    local auto = button("ToggleSearch", header, "AUTO OFF", 0, 12, 100, 32)
    auto.Position = UDim2.new(1, -156, 0, 12); auto.Font = Enum.Font.GothamBold
    make("UIPadding", "DotSpace", auto, { PaddingLeft = UDim.new(0, 16) })
    local autoDot = make("Frame", "Dot", auto, { Position = UDim2.new(0, -2, 0.5, -4), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.muted, BorderSizePixel = 0 })
    corner(autoDot, 4)
    local divider = make("Frame", "HeaderDivider", root, { Position = UDim2.fromOffset(0, HEADER), Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.border, BackgroundTransparency = 0.3, BorderSizePixel = 0 })

    -- Barra lateral: una entrada por seccion; abajo el estado de AUTO y la firma.
    local sidebar = make("Frame", "Sidebar", root, { Position = UDim2.fromOffset(0, HEADER + 1),
        Size = UDim2.fromOffset(SIDEBAR, HUB_HEIGHT - HEADER - 1), BackgroundTransparency = 1, BorderSizePixel = 0 })
    make("Frame", "Edge", sidebar, { Position = UDim2.fromOffset(SIDEBAR - 1, 0), Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = C.border, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
    local tabButtons = {}
    for index, item in ipairs(TABS) do
        local b = make("TextButton", "Tab_" .. item.id, sidebar, { Position = UDim2.fromOffset(12, 16 + (index - 1) * 46),
            Size = UDim2.fromOffset(SIDEBAR - 24, 40), BackgroundColor3 = C.card, BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        corner(b, 8)
        local mark = make("Frame", "Indicator", b, { Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(3, 20),
            BackgroundColor3 = C.gold, BorderSizePixel = 0, Visible = false })
        corner(mark, 2)
        local label = text("Label", b, item.label, 16, 0, SIDEBAR - 64, 40, C.muted, 13, true)
        -- Punto champan: hay cambios de filtros sin aplicar.
        local dot = make("Frame", "Pending", b, { Position = UDim2.new(1, -18, 0.5, -4), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = C.gold, BorderSizePixel = 0, Visible = false })
        corner(dot, 4)
        tabButtons[item.id] = { button = b, mark = mark, label = label, dot = dot, hover = false }
    end
    local sideState = text("AutoState", sidebar, "AUTO apagado", 16, HUB_HEIGHT - HEADER - 90, SIDEBAR - 32, 16, C.muted, 11, true)
    local sideMode = paragraph("AutoMode", sidebar, "", 16, HUB_HEIGHT - HEADER - 72, SIDEBAR - 32, 28, C.muted, 10)
    local credit = text("ByMistakeCredit", sidebar, "By Mistake", 16, HUB_HEIGHT - HEADER - 34, SIDEBAR - 32, 14, C.gold, 11, true)
    credit.TextTransparency = 0.25

    -- Paginas: una por seccion, en el area a la derecha de la barra lateral.
    local pageArea = make("Frame", "Pages", root, { Position = UDim2.fromOffset(PAGE_X, PAGE_Y),
        Size = UDim2.fromOffset(CONTENT, PAGE_H), BackgroundTransparency = 1, BorderSizePixel = 0 })
    local pages = {}
    for _, item in ipairs(TABS) do
        pages[item.id] = make("Frame", "Page_" .. item.id, pageArea, { Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false })
    end
    local function heading(parent, title, detail, y)
        text("Heading", parent, title, 0, y, CONTENT, 20, C.white, 15, true)
        if detail then return paragraph("HeadingDetail", parent, detail, 0, y + 22, CONTENT, 28, C.muted, 11) end
    end
    local function listFrame(parent, y, height, x, width)
        local list = make("ScrollingFrame", "Options", parent, { Position = UDim2.fromOffset(x or 14, y), Size = UDim2.fromOffset(width or CONTENT - 28, height),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 })
        make("UIPadding", "Padding", list, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 2) })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
        return list
    end
    -- Fila con interruptor: toda la fila lo cambia; el estado se lee en el color.
    local function toggleRow(parent, name, title, detail, y, value, onToggle)
        local row = make("TextButton", name, parent, { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CONTENT, 52),
            BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", AutoButtonColor = true })
        corner(row, 10); stroke(row); interaction(row)
        text("Title", row, title, 14, 9, CONTENT - 96, 18, C.white, 14, true)
        text("Detail", row, detail, 14, 28, CONTENT - 96, 14, C.muted, 11)
        local track = make("Frame", "Switch", row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(44, 24), BackgroundColor3 = C.input, BorderSizePixel = 0 })
        corner(track, 12)
        local trackBorder = stroke(track)
        local knob = make("Frame", "Knob", track, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.muted, BorderSizePixel = 0 })
        corner(knob, 9)
        local function set(on)
            access()
            track.BackgroundColor3 = on and C.green or C.input
            trackBorder.Color = on and C.green or C.border
            knob.BackgroundColor3 = on and C.onSuccess or C.muted
            knob.Position = UDim2.new(0, on and 23 or 3, 0.5, 0)
        end
        set(value)
        row.Activated:Connect(function() access(); onToggle() end)
        return set, row
    end

    -- Egg Finder: estado de la busqueda, filtros guardados y huevos del mapa.
    local finderPage = pages.finder
    local statusCard = make("Frame", "Status", finderPage, { Size = UDim2.fromOffset(CONTENT, 60), BackgroundColor3 = C.card, BorderSizePixel = 0 })
    corner(statusCard, 10); stroke(statusCard).Transparency = 0.45
    local stateDot = make("Frame", "StateDot", statusCard, { Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.muted, BorderSizePixel = 0 })
    corner(stateDot, 4)
    local stateTitle = text("SearchState", statusCard, "Conectando detector...", 30, 9, CONTENT - 170, 22, C.white, 15, true)
    local stateDetail = text("SearchDetail", statusCard, "", 14, 33, CONTENT - 154, 18, C.muted, 11)
    local clockCaption = text("ResetCaption", statusCard, "Renovación", CONTENT - 124, 10, 110, 14, C.muted, 10)
    local clock = text("ResetClock", statusCard, "--:--", CONTENT - 124, 26, 110, 24, C.cyan, 18, true)
    clockCaption.TextXAlignment = Enum.TextXAlignment.Right; clock.TextXAlignment = Enum.TextXAlignment.Right
    local summaryBar = make("Frame", "FiltersBar", finderPage, { Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(CONTENT, 32), BackgroundTransparency = 1 })
    text("FiltersCaption", summaryBar, "Filtros", 0, 0, 52, 32, C.white, 13, true)
    local filterSummary = text("FiltersSummary", summaryBar, "", 56, 0, CONTENT - 196, 32, C.muted, 11)
    local editFilters = button("EditFilters", summaryBar, "Editar filtros", CONTENT - 128, 1, 128, 30)
    -- Barra de la lista: alcance segmentado, vista y orden.
    local toolbar = make("Frame", "ListBar", finderPage, { Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(CONTENT, 32), BackgroundTransparency = 1 })
    local toolWidth = (CONTENT - 24) / 4
    local tabMap = button("MapTab", toolbar, "Todos", 0, 0, toolWidth, 32)
    local tabCatalog = button("CatalogTab", toolbar, "Cumplen", toolWidth + 8, 0, toolWidth, 32)
    local visualButton = button("VisualMode", toolbar, "Ver: Huevos", 2 * (toolWidth + 8), 0, toolWidth, 32)
    local sortButton = button("Sort", toolbar, "Orden: Rareza", 3 * (toolWidth + 8), 0, toolWidth, 32)
    local scroll = make("ScrollingFrame", "EggCards", finderPage, {
        Position = UDim2.fromOffset(-2, 152), Size = UDim2.fromOffset(CONTENT + 4, PAGE_H - 152), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    make("UIPadding", "Padding", scroll, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 4) })

    -- Filtros: cada control con su etiqueta encima; abajo los presets.
    local filtersPage = pages.filters
    heading(filtersPage, "Filtros de búsqueda", "AUTO usa los filtros guardados. Los cambios esperan a que pulses Aplicar filtros.", 0)
    local third, half = math.floor((CONTENT - 16) / 3), (CONTENT - 8) / 2
    local filters = make("Frame", "Filters", filtersPage, { Position = UDim2.fromOffset(0, 50), Size = UDim2.fromOffset(CONTENT, 178), BackgroundTransparency = 1, BorderSizePixel = 0 })
    text("RarityLabel", filters, "Rareza mínima", 0, 0, third, 16, C.muted, 11)
    text("IncomeLabel", filters, "Ingreso mínimo /s", third + 8, 0, third, 16, C.muted, 11)
    text("MutationLabel", filters, "Mutación", 2 * (third + 8), 0, third, 16, C.muted, 11)
    local rarityButton = button("Rarity", filters, draft.rarity, 0, 20, third, 38)
    rarityButton.TextSize = 14; chevron(rarityButton)
    local income = field("MinimumIncome", filters, search.FormatMinimum(draft.minIncome), "Ej. 7b o 500m", third + 8, 20, third, 38)
    income.Font = Enum.Font.GothamBold; income.TextColor3 = C.gold
    local mutationButton = button("Mutation", filters, draft.mutation == "" and "Todas" or draft.mutation, 2 * (third + 8), 20, third, 38)
    mutationButton.TextSize = 14; chevron(mutationButton)
    text("ZonesLabel", filters, "Zonas", 0, 70, half, 16, C.muted, 11)
    text("NameLabel", filters, "Nombre contiene", half + 8, 70, half, 16, C.muted, 11)
    local chooseZones = button("ChooseZones", filters, "Todas las zonas", 0, 90, half, 38)
    chooseZones.TextSize = 14; chevron(chooseZones)
    local nameBox = field("NameFilter", filters, draft.nameContains, "Cualquier nombre", half + 8, 90, half, 38)
    local changeLabel = text("Changes", filters, "Filtros guardados", 0, 140, CONTENT - third - 16, 38, C.muted, 11)
    changeLabel.TextWrapped = true
    local apply = button("ApplyFilters", filters, "Aplicar filtros", CONTENT - third, 140, third, 38)
    primary(apply); apply.TextSize = 13
    make("Frame", "PresetsDivider", filtersPage, { Position = UDim2.fromOffset(0, 242), Size = UDim2.fromOffset(CONTENT, 1),
        BackgroundColor3 = C.border, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
    text("PresetsTitle", filtersPage, "Presets", 0, 256, CONTENT, 20, C.white, 15, true)
    local presetMessage = paragraph("PresetMessage", filtersPage, "", 0, 278, CONTENT, 16, C.muted, 11)
    local presetName = field("PresetName", filtersPage, "", "Nombre del preset", 0, 300, CONTENT - third - 8, 36)
    local savePreset = button("SavePreset", filtersPage, "Guardar actuales", CONTENT - third, 300, third, 36); primary(savePreset)
    local presetList = listFrame(filtersPage, 346, PAGE_H - 346, -2, CONTENT + 4)

    local function save()
        access()
        local ok = writeJson(FILE, { open = panel.open, minimized = minimized, tab = tab, visual = visual,
            view = "map", onlyMatches = onlyMatches, sortBest = sortBest, calc = calc,
            x = root.Position.X.Offset, y = root.Position.Y.Offset, scale = userScale })
        if not ok then panel.error = "No se pudo guardar la posición / vista"; warn("[EggPanel] " .. panel.error) end
    end
    local function closePopup() if popup then popup:Destroy(); popup = nil end end
    -- Hojas modales: el velo bloquea el hub, la hoja cubre el area de paginas y
    -- tocar el velo cierra solo la hoja.
    local function sheet(name, title, height)
        closePopup()
        height = math.min(height, SHEET_SPACE)
        local scrim = make("TextButton", name, root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim,
            BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 50 })
        corner(scrim, 14)
        local card = make("Frame", "Sheet", scrim, { Position = UDim2.fromOffset(PAGE_X, SHEET_TOP + math.floor((SHEET_SPACE - height) / 2)),
            Size = UDim2.fromOffset(CONTENT, height), BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, ZIndex = 51 })
        corner(card, 12); stroke(card)
        local heading = text("Title", card, title, 18, 16, CONTENT - 86, 24, C.white, 17, true)
        local dismiss = button("Dismiss", card, "", CONTENT - 50, 12, 32, 32); crossIcon(dismiss)
        scrim.Activated:Connect(function() access(); closePopup() end)
        dismiss.Activated:Connect(function() access(); closePopup() end)
        popup = scrim
        return card, heading
    end
    local initializedPosition = false
    local function fitLimit()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local viewport = camera.ViewportSize
        return math.min((viewport.X - 28) / HUB_WIDTH, (viewport.Y - 28) / HUB_HEIGHT)
    end
    local function fit()
        access()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        scale.Scale = scaling.Panel(userScale, fitLimit())
        local width = (minimized and MINI_WIDTH or HUB_WIDTH) * scale.Scale
        local height = (minimized and HEADER or HUB_HEIGHT) * scale.Scale
        if not initializedPosition then
            root.Position = UDim2.fromOffset(tonumber(saved.x) or (viewport.X - HUB_WIDTH * scale.Scale) / 2,
                tonumber(saved.y) or math.max(14, (viewport.Y - HUB_HEIGHT * scale.Scale) / 2))
            initializedPosition = true
        end
        root.Position = UDim2.fromOffset(math.clamp(root.Position.X.Offset, 8, math.max(8, viewport.X - width - 8)),
            math.clamp(root.Position.Y.Offset, 8, math.max(8, viewport.Y - height - 8)))
    end
    -- Las tarjetas solo se dibujan con el Egg Finder a la vista.
    local function finderVisible() return panel.open and not minimized and tab == "finder" end
    local function releaseModels()
        for _, entry in pairs(entries) do
            if entry.viewport then entry.viewport:Destroy(); entry.viewport = nil; entry.key = nil end
        end
    end
    local function paintTabs()
        access()
        for id, entry in pairs(tabButtons) do
            local selected = id == tab
            entry.button.BackgroundTransparency = selected and 0 or entry.hover and 0.5 or 1
            entry.mark.Visible = selected
            entry.label.TextColor3 = selected and C.white or C.muted
        end
    end
    local function applyMinimized()
        access()
        root.Size = minimized and UDim2.fromOffset(MINI_WIDTH, HEADER) or UDim2.fromOffset(HUB_WIDTH, HUB_HEIGHT)
        divider.Visible, sidebar.Visible, pageArea.Visible = not minimized, not minimized, not minimized
        local grip = root:FindFirstChild("ResizeGrip"); if grip then grip.Visible = not minimized end
        expandMark.Visible = minimized
        if minimized then closePopup(); releaseModels() end
    end
    local function refreshSoon()
        if panel.Refresh then task.defer(function() if panel.alive and session.alive then panel.Refresh() end end) end
    end
    -- Contenido que se vuelve a construir al entrar en su seccion.
    local renderers = {}
    function panel.Select(id)
        access(); assert(pages[id], "Sección desconocida")
        closePopup(); tab = id
        for key, page in pairs(pages) do page.Visible = key == id end
        if id ~= "finder" then releaseModels() end
        if minimized then minimized = false; applyMinimized(); fit() end
        paintTabs(); signature = nil; save()
        if renderers[id] then renderers[id]() end
        if id == "finder" then refreshSoon() end
    end
    function panel.Open()
        access(); panel.open = true; root.Visible = true
        if minimized then minimized = false; applyMinimized() end
        signature = nil; fit(); save(); refreshSoon()
    end
    function panel.Close()
        access(); panel.open = false; root.Visible = false; closePopup(); releaseModels(); save()
    end
    -- Plegado deja la cabecera con AUTO; desplegar vuelve a la misma seccion.
    function panel.SetMinimized(value)
        access(); minimized = value == true; applyMinimized(); signature = nil; fit(); save()
        if not minimized then refreshSoon() end
    end
    local function setMessage(value, color)
        access(); changeLabel.Text = value; changeLabel.TextColor3 = color or C.muted
    end
    local function markDirty()
        access()
        dirty = true; signature = nil
        chooseZones.Text = zonesText(selectionList(), allZones)
        tabButtons.filters.dot.Visible = true
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
        dirty = false; tabButtons.filters.dot.Visible = false
        setMessage("Filtros guardados."); signature = nil
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
        setMessage("Filtros aplicados. Egg Finder muestra solo los huevos que cumplen.", C.green)
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
        local card = sheet("Dropdown", kind == "rarity" and "Rareza mínima" or "Mutación", 452)
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
        local card = sheet("ZonePicker", "Zonas", 480)
        local counter = text("Hint", card, "", 18, 44, CONTENT - 36, 16, C.muted, 11)
        local selectAll = button("SelectAll", card, "Todas", 18, 72, 110, 32)
        local clearZones = button("ClearSelection", card, "Ninguna", 136, 72, 110, 32)
        local list = listFrame(card, 116, 296)
        text("Footer", card, "Se guardan al pulsar Aplicar filtros.", 18, 426, 300, 36, C.muted, 11)
        local done = button("Done", card, "Listo", CONTENT - 18 - 120, 426, 120, 36); primary(done)
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
    local function bestText(row)
        if row.best ~= "previous" then return BEST_TEXT[row.best] end
        if (row.age or 1) <= 1 then return "ÚLTIMO DEL CICLO ANTERIOR · ya no existe" end
        return string.format("ÚLTIMO VISTO HACE %d CICLOS · ya no existe", row.age)
    end
    -- The previous cycle's egg is information only: muted, never gold.
    local function bestColor(row) return row.best == "previous" and C.muted or C.gold end
    -- Best egg of this cycle and of the last ended ones, same rarity and zones,
    -- to see what really appears before choosing the minimum. Information only.
    local HISTORY_CYCLES = 5
    local function ageText(age)
        if age <= 0 then return "Ciclo que termina" end
        if age == 1 then return "Ciclo anterior" end
        return string.format("Hace %d ciclos", age)
    end
    local function bestHistory()
        access()
        local card = sheet("BestHistory", "Mejores de ciclos anteriores", 480)
        paragraph("Hint", card, string.format("El mejor huevo %s+ de cada ciclo en tus zonas, aunque no llegue al mínimo. "
            .. "Un ciclo sin ninguno no aparece.", search.config.rarity), 18, 44, CONTENT - 36, 32, C.muted, 11)
        local cycles = {}
        local current = search.BestSeen()
        if current then table.insert(cycles, {best = current, label = "Este ciclo"}) end
        for _, item in ipairs(search.BestHistory(nil, HISTORY_CYCLES)) do
            table.insert(cycles, {best = item.best, label = ageText(item.age)})
        end
        local list = listFrame(card, 84, 344)
        local minimum = search.config.minIncome
        for index, item in ipairs(cycles) do
            local best = item.best
            local catalog = search.modules and search.modules.assets.Directory[best.category]
            local labels, ids = {}, table.clone(best.mutations or {})
            if best.baseMutation then table.insert(ids, 1, best.baseMutation) end
            for _, id in ipairs(ids) do
                local ok, label = pcall(function() return data.mutations and data.mutations.LabelOf(id) or id end)
                label = ok and tostring(label) or tostring(id)
                if not table.find(labels, label) then table.insert(labels, label) end
            end
            local row = make("Frame", "Cycle_" .. index, list, {Size = UDim2.new(1, -2, 0, 58), LayoutOrder = index,
                BackgroundColor3 = C.card, BorderSizePixel = 0})
            corner(row); stroke(row, index == 1 and current and C.gold or C.border).Transparency = 0.45
            text("When", row, item.label, 14, 8, 0, 14, index == 1 and current and C.gold or C.muted, 10, true).Size = UDim2.new(1, -150, 0, 14)
            text("Name", row, tostring(best.name or best.category), 14, 22, 0, 18, C.white, 14, true).Size = UDim2.new(1, -150, 0, 18)
            local tags = text("Tags", row, "", 14, 40, 0, 14, C.muted, 10)
            tags.Size = UDim2.new(1, -150, 0, 14); tags.RichText = true
            tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s%s',
                hex(rarityColor(catalog and catalog.Rarity)), escape(best.rarity or "?"), escape(zoneName(best.area)),
                #labels > 0 and "  ·  " .. escape(table.concat(labels, " + ")) or "")
            local reaches = best.income >= minimum
            local income = text("Income", row, number(best.income) .. "/s", 0, 10, 124, 22, reaches and C.green or C.white, 16, true)
            income.Position = UDim2.new(1, -138, 0, 10); income.TextXAlignment = Enum.TextXAlignment.Right
            local verdict = text("Minimum", row, reaches and "llega al mínimo" or "bajo el mínimo", 0, 34, 124, 14, C.muted, 10)
            verdict.Position = UDim2.new(1, -138, 0, 34); verdict.TextXAlignment = Enum.TextXAlignment.Right
        end
        if #cycles == 0 then
            paragraph("Empty", list, "Todavía no hay ciclos con un huevo de tu rareza en tus zonas. Se registran con AUTO activo.",
                4, 12, CONTENT - 60, 40, C.muted, 12)
        end
        paragraph("Minimum", card, "Ingreso mínimo guardado: " .. search.FormatMinimum(minimum) .. "/s", 18, 436, CONTENT - 36, 32, C.muted, 11)
    end
    panel.OpenBestHistory = bestHistory
    local function detail(row)
        access()
        -- Filas de 36 y acciones en una sola fila: cabe en el area del hub.
        local factCount = row.best and 7 or 6
        local actionsY = 126 + factCount * 36 + 12
        local card = sheet("EggDetail", row.name, actionsY + 58)
        local tags = text("Tags", card, "", 18, 44, CONTENT - 36, 18, C.muted, 12)
        tags.RichText = true
        tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s', hex(rarityColor(row.catalog and row.catalog.Rarity)),
            escape(row.rarity), escape(zoneName(row.area)))
        local verdict = make("Frame", "Verdict", card, { Position = UDim2.fromOffset(18, 74), Size = UDim2.fromOffset(CONTENT - 36, 40),
            BackgroundColor3 = row.match and C.success or C.card, BorderSizePixel = 0 })
        corner(verdict); stroke(verdict, row.match and C.green or C.border)
        text("Text", verdict, row.best and bestText(row) or row.match and "Cumple todos los filtros"
            or "No cumple: " .. string.lower(row.reason),
            14, 0, CONTENT - 64, 40, row.best and bestColor(row) or row.match and C.green or C.white, 13, true)
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
            local y = 126 + (index - 1) * 36
            text("Label" .. index, card, fact[1], 18, y, 150, 36, C.muted, 12)
            text("Value" .. index, card, fact[2], 172, y, CONTENT - 190, 36, C.white, 13, true)
            if index < #facts then
                make("Frame", "Divider" .. index, card, { Position = UDim2.fromOffset(18, y + 35), Size = UDim2.fromOffset(CONTENT - 36, 1),
                    BackgroundColor3 = C.border, BackgroundTransparency = 0.5, BorderSizePixel = 0 })
            end
        end
        local actionWidth = row.best and (CONTENT - 44) / 2 or CONTENT - 36
        if row.best then
            local history = button("BestHistory", card, "Mejores de los últimos ciclos", 18, actionsY, actionWidth, 40)
            history.Activated:Connect(function() access(); bestHistory() end)
        end
        local calculate = button("Calculate", card, "Calcular con otras mutaciones", row.best and 26 + actionWidth or 18, actionsY, actionWidth, 40)
        calculate.Activated:Connect(function()
            access(); panel.OpenCalculator(row.category, row.scale, row.mutationIds)
        end)
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
            .. tostring(row.weight) .. tostring(row.eggIcon) .. visual .. tostring(row.best) .. tostring(row.age)
        if entry.key == key and (visual ~= "models" or entry.viewport or not data.assetModels) then return end
        entry.key = key; panel.stats.updated += 1
        entry.card.Name = "Card_" .. row.uid
        entry.card.BackgroundColor3 = row.match and C.success or C.card
        entry.border.Color = row.best == "previous" and C.border or row.best and C.gold or row.match and C.green or C.border
        entry.border.Thickness = (row.match or (row.best and row.best ~= "previous")) and 1.5 or 1
        entry.name.Text = row.name; entry.name.TextColor3 = C.white
        entry.income.Text = (row.income and number(row.income) or "?") .. "/s"
        entry.income.TextColor3 = row.match and C.green or row.best and bestColor(row) or C.white
        entry.weight.Text = row.best and bestText(row) or string.format("x%.2f  ·  %s", row.scale or 1, row.weight)
        entry.weight.TextColor3 = row.best and bestColor(row) or C.muted
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
        if not finderVisible() or not panel.alive then return end
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
            local ids = {}; for id in pairs(seen) do table.insert(ids, id) end; table.sort(ids)
            return {uid = uid, mutationIds = ids, key = key, category = tostring(egg.AssetCategory or "Desconocida"), catalog = catalog,
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
        -- Without a best egg in this cycle, the last one seen in an earlier
        -- cycle stays, muted, until a newer in-scope egg replaces it.
        local previousBest, previousAge
        if bestSeen == nil and onlyMatches then previousBest, previousAge = search.BestPrevious() end
        local shown = (bestSeen ~= nil and not bestHere) and bestSeen or previousBest
        local remembered = shown ~= nil and onlyMatches and modules.assets.Directory[shown.category] or nil
        if remembered then
            local uid = "best-seen"
            active[uid] = true
            local egg = {AssetCategory = shown.category, AssetScale = shown.scale, AreaId = shown.area,
                BaseMutation = shown.baseMutation, Mutations = shown.mutations}
            local row = metadata[uid]
            local key = (previousBest and "previous:" or "best:") .. shown.key
            if not row or row.key ~= key or row.labelModule ~= data.mutations then
                row = describe(uid, key, egg, remembered, shown.income)
                metadata[uid] = row
            end
            local ok, reason = pcall(search.Explain, egg, remembered, shown.income)
            row.income, row.match, row.reason = shown.income, false, ok and reason or "Datos de especie no disponibles"
            row.age = previousBest and previousAge or nil
            row.best = previousBest and "previous" or shown.job ~= game.JobId and "other"
                or snapshot.info.ready and "gone" or "seen"
            table.insert(rows, row); table.insert(fingerprints, row.uid .. row.key .. tostring(row.income) .. row.reason .. row.best .. tostring(row.age))
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
                empty = paragraph("Empty", scroll, "", 24, 40, CONTENT - 56, 90, C.muted, 13)
                empty.TextXAlignment = Enum.TextXAlignment.Center
            end
            empty.Text = not snapshot.info.ready and sentence(snapshot.info.reason or "esperando datos del mapa") .. "."
                or onlyMatches and "Ningún huevo del mapa cumple todos los filtros.\nPrueba con un ingreso menor, más zonas o pulsa Todos para ver el mapa completo."
                or "No hay huevos disponibles en el mapa ahora."
        elseif empty then empty:Destroy() end
        panel.stats.lastMs = (os.clock() - started) * 1000
    end
    local function scheduleRender()
        if renderScheduled or not finderVisible() then return end
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
    local function caption(parent, value, x, y, width) text("Section", parent, value, x, y, width, 16, C.muted, 11, true) end
    -- Presets de la pagina Filtros: guardar el formulario, cargarlo o borrarlo.
    local function presetResult(callback)
        local ok, err = pcall(callback); access()
        if not ok then presetMessage.Text = sentence(err); presetMessage.TextColor3 = C.red end
        return ok
    end
    local function renderPresets(notice)
        access()
        presetMessage.Text = notice or "Guarda los filtros del formulario. Al cargar uno, pulsa Aplicar filtros para usarlo."
        presetMessage.TextColor3 = notice and C.green or C.muted
        for _, child in ipairs(presetList:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        local presets = api.Presets()
        access()
        for index, preset in ipairs(presets) do
            local row = make("Frame", "Preset_" .. index, presetList, {Size = UDim2.new(1, -2, 0, 52), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = index})
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
            load.Activated:Connect(function() access(); presetResult(function() panel.LoadPreset(preset.name) end) end)
            delete.Activated:Connect(function()
                access(); if presetResult(function() api.DeletePreset(preset.name) end) then renderPresets("Preset borrado.") end
            end)
        end
        if #presets == 0 then paragraph("Empty", presetList, "Todavía no hay presets. Escribe un nombre y pulsa Guardar actuales.", 4, 12, CONTENT - 60, 40, C.muted, 12) end
    end
    renderers.filters = function() renderPresets() end
    connect(savePreset.Activated, function()
        if presetResult(function() panel.SavePreset(presetName.Text) end) then
            presetName.Text = ""; renderPresets("Preset guardado.")
        end
    end)
    -- Ajustes: alertas al encontrar un objetivo y como se muestra el hub.
    local settingsPage = pages.settings
    local function renderSettings(notice)
        access()
        for _, child in ipairs(settingsPage:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        heading(settingsPage, "Alertas", "Al encontrar un huevo que cumple, AUTO avisa y espera la captura.", 0)
        local settings = api.Alerts()
        access()
        local test = button("TestAlert", settingsPage, "Probar alerta", 0, 176, third, 36)
        local message = paragraph("Message", settingsPage, notice or "", third + 12, 176, CONTENT - third - 12, 36, C.green, 11)
        message.TextYAlignment = Enum.TextYAlignment.Center
        local function result(callback)
            local ok, err = pcall(callback); access()
            if not ok and message.Parent then message.Text = sentence(err); message.TextColor3 = C.red end
            return ok
        end
        toggleRow(settingsPage, "Notification", "Notificación", "Aviso de Roblox con el nombre, el ingreso y la zona.", 56, settings.notification, function()
            if result(function() api.ConfigureAlerts({notification = not settings.notification}) end) then renderSettings() end
        end)
        toggleRow(settingsPage, "Sound", "Sonido", "Un pitido corto junto al aviso.", 114, settings.sound, function()
            if result(function() api.ConfigureAlerts({sound = not settings.sound}) end) then renderSettings() end
        end)
        test.Activated:Connect(function()
            access(); if result(api.TestAlert) then message.Text = "Alerta de prueba enviada."; message.TextColor3 = C.green end
        end)
        make("Frame", "InterfaceDivider", settingsPage, { Position = UDim2.fromOffset(0, 228), Size = UDim2.fromOffset(CONTENT, 1),
            BackgroundColor3 = C.border, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
        heading(settingsPage, "Interfaz", nil, 242)
        local facts = {
            {"Mostrar u ocultar", "Alt izquierdo"},
            {"Plegar", "El botón de la cabecera deja solo la barra con AUTO"},
            {"Tamaño", "Arrastra la esquina inferior derecha"},
            {"Acceso rápido", "Se activa o desactiva en Server Hop"},
        }
        for index, fact in ipairs(facts) do
            local y = 270 + (index - 1) * 32
            text("Label" .. index, settingsPage, fact[1], 0, y, 150, 32, C.muted, 12)
            text("Value" .. index, settingsPage, fact[2], 160, y, CONTENT - 160, 32, C.white, 12, true)
            if index < #facts then
                make("Frame", "Divider" .. index, settingsPage, { Position = UDim2.fromOffset(0, y + 31), Size = UDim2.fromOffset(CONTENT, 1),
                    BackgroundColor3 = C.border, BackgroundTransparency = 0.5, BorderSizePixel = 0 })
            end
        end
        local reset = button("ResetLayout", settingsPage, "Restablecer tamaño y posición", 0, 410, half, 36)
        reset.Activated:Connect(function() access(); panel.ResetLayout() end)
    end
    renderers.settings = function() renderSettings() end
    function panel.ResetLayout()
        access(); userScale = scaling.Panel(nil); saved.x, saved.y = nil, nil; initializedPosition = false; fit(); save()
    end
    function panel.OpenOptions(notice)
        if not panel.open then panel.Open() end
        panel.Select("settings")
        if notice then renderSettings(notice) end
    end
    -- Calculadora: ingreso de una especie con el peso y las mutaciones que se
    -- elijan, con las funciones del juego. Solo informativa; no cambia filtros.
    local calcPage = pages.calc
    local function petLabel(category)
        local catalog = category and search.modules and search.modules.assets.Directory[category]
        return catalog and tostring(catalog.DisplayName or category) or nil
    end
    local function speciesPicker()
        access()
        local card = sheet("SpeciesPicker", "Especie", 480)
        local query = field("Search", card, "", "Buscar por nombre", 18, 48, CONTENT - 36, 36)
        local list = listFrame(card, 96, 370)
        local options = search.PetOptions()
        local rarities = search.modules and search.modules.rarities.Rarities or {}
        access()
        local function render()
            access()
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("GuiObject") then child:Destroy() end
            end
            local wanted = string.lower(query.Text)
            local shown = 0
            for index, option in ipairs(options) do
                if wanted == "" or string.find(string.lower(option.label), wanted, 1, true) then
                    shown += 1
                    local selected = option.id == calc.category
                    local b = button("Pet_" .. index, list, "", 0, 0, 0, 40)
                    b.Size = UDim2.new(1, -2, 0, 40); b.LayoutOrder = index
                    text("Label", b, option.label, 14, 0, 0, 40, C.white, 14, selected).Size = UDim2.new(1, -150, 1, 0)
                    local rarity = text("Rarity", b, tostring(option.rarity or "?"), 0, 0, 120, 40,
                        rarityColor(rarities[option.rarity], C.muted), 11, true)
                    rarity.Position = UDim2.new(1, -134, 0, 0); rarity.TextXAlignment = Enum.TextXAlignment.Right
                    if selected then paint(b, C.selected, C.white, C.green) end
                    b.Activated:Connect(function()
                        access(); calc.category = option.id; calc.scale, calc.scaleWeight = nil, nil; save(); panel.OpenCalculator()
                    end)
                end
            end
            if shown == 0 then paragraph("Empty", list, "Ninguna especie con ese nombre.", 4, 12, CONTENT - 60, 30, C.muted, 12) end
        end
        query:GetPropertyChangedSignal("Text"):Connect(render)
        render()
    end
    -- Dos columnas: especie, peso y mutaciones a la izquierda; resultado a la derecha.
    local function renderCalculator()
        access()
        for _, child in ipairs(calcPage:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        heading(calcPage, "Calculadora de ingreso", "Cuánto da una mascota según su peso y mutaciones, con las fórmulas del juego. "
            .. "Las mutaciones se suman: Golden + Rainbow = x5.", 0)
        if not search.modules then
            paragraph("Loading", calcPage, "Cargando los datos del juego... Vuelve a abrir la calculadora en unos segundos.", 0, 64, CONTENT, 30, C.muted, 12)
            return
        end
        local resultWidth = 202
        local left = CONTENT - resultWidth - 12
        text("SpeciesLabel", calcPage, "Especie", 0, 58, CONTENT - third - 8, 16, C.muted, 11)
        text("WeightLabel", calcPage, "Peso (kg)", CONTENT - third, 58, third, 16, C.muted, 11)
        local species = button("Species", calcPage, petLabel(calc.category) or "Elegir especie", 0, 78, CONTENT - third - 8, 38)
        species.TextSize = 14; chevron(species)
        local weight = field("Weight", calcPage, calc.weight, "Ej. 44,904", CONTENT - third, 78, third, 38)
        weight.Font = Enum.Font.GothamBold
        caption(calcPage, "MUTACIONES", 0, 134, 120)
        local clear = button("ClearMutations", calcPage, "Quitar todas", left - 110, 128, 110, 28)
        local grid = make("ScrollingFrame", "Mutations", calcPage, { Position = UDim2.fromOffset(0, 166), Size = UDim2.fromOffset(left, PAGE_H - 166),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            ScrollBarThickness = 3, ScrollBarImageColor3 = C.muted, BorderSizePixel = 0 })
        local cell = math.floor((left - 18) / 2)
        make("UIGridLayout", "Layout", grid, { CellSize = UDim2.fromOffset(cell, 34), CellPadding = UDim2.fromOffset(8, 8),
            SortOrder = Enum.SortOrder.LayoutOrder })
        local result = make("Frame", "Result", calcPage, { Position = UDim2.fromOffset(CONTENT - resultWidth, 128),
            Size = UDim2.fromOffset(resultWidth, PAGE_H - 128), BackgroundColor3 = C.card, BorderSizePixel = 0 })
        corner(result, 10); stroke(result).Transparency = 0.45
        local inner = resultWidth - 28
        text("IncomeCaption", result, "Ingreso por segundo", 14, 12, inner, 14, C.muted, 11)
        local income = text("Income", result, "--", 14, 28, inner, 32, C.gold, 24, true)
        local exact = paragraph("Exact", result, "", 14, 62, inner, 36, C.muted, 10)
        make("Frame", "ResultDivider", result, { Position = UDim2.fromOffset(14, 102), Size = UDim2.fromOffset(inner, 1),
            BackgroundColor3 = C.border, BackgroundTransparency = 0.5, BorderSizePixel = 0 })
        local rows = {}
        for index, label in ipairs({"Por minuto", "Por hora", "Por día", "Multiplicador", "Tamaño", "Sin mutaciones"}) do
            local y = 110 + (index - 1) * 26
            text("Label" .. index, result, label, 14, y, 92, 24, C.muted, 11)
            rows[index] = text("Value" .. index, result, "--", 106, y, inner - 92, 24, C.white, 12, true)
            rows[index].TextXAlignment = Enum.TextXAlignment.Right
        end
        local message = paragraph("Message", result, "", 14, 274, inner, 64, C.muted, 11)
        local chips, bonuses = {}, {}
        local function update()
            access()
            local selected = {}
            for _, id in ipairs(calc.mutations) do selected[id] = true end
            for id, chip in pairs(chips) do
                local on = selected[id] == true
                paint(chip, on and C.selected or C.card, on and C.green or C.white, on and C.green or C.border)
            end
            for _, value in ipairs(rows) do value.Text = "--" end
            income.Text = "--"; exact.Text = ""
            if not calc.category then message.Text = "Elige una especie para empezar."; message.TextColor3 = C.muted; return end
            if string.gsub(weight.Text, "%s", "") == "" then message.Text = "Escribe el peso en kg (el que muestra el huevo o la mascota)."; message.TextColor3 = C.muted; return end
            local exactScale = calc.scale and calc.scaleWeight == weight.Text
            local ok, value
            if exactScale then ok, value = pcall(search.CalculateAtScale, calc.category, calc.scale, calc.mutations)
            else ok, value = pcall(search.CalculateIncome, calc.category, weight.Text, calc.mutations) end
            access()
            if not ok then message.Text = sentence(tostring(value):gsub("^.-:%d+: ", "")); message.TextColor3 = C.red; return end
            income.Text = number(value.income) .. "/s"
            exact.Text = string.format("Exacto: %.17g/s  ·  %s kg", value.income, search.FormatWeight(value.weight))
            rows[1].Text = number(value.income * 60); rows[2].Text = number(value.income * 3600)
            rows[3].Text = number(value.income * 86400)
            rows[4].Text = value.multiplier and string.format("x%.2f", value.multiplier) or "--"
            rows[5].Text = string.format("x%.2f", value.scale); rows[6].Text = number(value.base) .. "/s"
            message.Text = #value.mutations == 0 and "Sin mutaciones. Toca las que quieras sumar."
                or "Ingreso del juego sin boosts temporales ni pases."
            message.TextColor3 = C.muted
        end
        -- Bono de cada mutacion para la especie elegida, medido con el juego.
        if calc.category then
            local okBase, base = pcall(search.IncomeAt, calc.category, 1, {})
            if okBase and base > 0 and data.mutations then
                for id in pairs(data.mutations.IdSet) do
                    local ok, value = pcall(search.IncomeAt, calc.category, 1, {id})
                    if ok then bonuses[id] = value / base - 1 end
                end
            end
            access()
        end
        if data.mutations then
            local options = {}
            for id in pairs(data.mutations.IdSet) do
                local ok, label = pcall(data.mutations.LabelOf, id)
                table.insert(options, { id = id, label = ok and tostring(label) or id })
            end
            access()
            table.sort(options, function(a, b) return a.label < b.label end)
            for index, option in ipairs(options) do
                local bonus = bonuses[option.id]
                local chip = button("Mutation_" .. option.id, grid, bonus and string.format("%s  +%s", option.label,
                    (string.format("%.2f", bonus):gsub("0+$", ""):gsub("%.$", ""))) or option.label, 0, 0, cell, 34)
                chip.LayoutOrder = index
                chips[option.id] = chip
                chip.Activated:Connect(function()
                    access()
                    local position = table.find(calc.mutations, option.id)
                    if position then table.remove(calc.mutations, position) else table.insert(calc.mutations, option.id) end
                    save(); update()
                end)
            end
        else
            paragraph("Loading", grid, "Cargando las mutaciones del juego...", 4, 8, left - 20, 30, C.muted, 12)
        end
        species.Activated:Connect(function() access(); speciesPicker() end)
        clear.Activated:Connect(function() access(); table.clear(calc.mutations); save(); update() end)
        weight:GetPropertyChangedSignal("Text"):Connect(function() access(); calc.weight = weight.Text; update() end)
        weight.Focused:Connect(function() access(); weight.Border.Color = C.gold; weight.Border.Thickness = 1.5 end)
        weight.FocusLost:Connect(function() access(); weight.Border.Color = C.border; weight.Border.Thickness = 1; save() end)
        update()
    end
    renderers.calc = renderCalculator
    function panel.OpenCalculator(category, scale, mutations)
        access()
        -- Desde el detalle de un huevo: su especie, su peso y sus mutaciones.
        if category ~= nil and search.modules then
            calc.category = category
            local ok, weight = pcall(search.WeightAt, category, scale or 1)
            access()
            calc.weight = ok and search.FormatWeight(weight) or ""
            calc.mutations = table.clone(mutations or {})
            calc.scale, calc.scaleWeight = ok and scale or nil, ok and calc.weight or nil
            save()
        end
        if not panel.open then panel.Open() end
        panel.Select("calc")
    end
    -- Secciones que construye el runtime (Server Hop) con los mismos componentes.
    function panel.Page(id) return pages[id] end
    function panel.OnSelect(id, render) renderers[id] = render end
    function panel.Tab() return tab end
    panel.ui = { colors = C, content = CONTENT, pageHeight = PAGE_H, column = third, make = make, corner = corner,
        stroke = stroke, text = text, paragraph = paragraph, button = button, field = field, primary = primary,
        paint = paint, heading = heading, toggleRow = toggleRow }
    function panel.GetStatus()
        access(); return { open = panel.open, minimized = minimized, tab = tab, view = "map", onlyMatches = onlyMatches,
            cards = panel.cards, matches = panel.matches, dirty = dirty, error = panel.error,
            selected = selectionList(), allZones = allZones, visual = visual, sortBest = sortBest, position = {x = root.AbsolutePosition.X, y = root.AbsolutePosition.Y},
            size = {x = root.AbsoluteSize.X, y = root.AbsoluteSize.Y}, scale = scale.Scale, userScale = userScale,
            stats = table.clone(panel.stats), resources = {mutations = data.mutations ~= nil, models = data.assetModels ~= nil} }
    end
    function panel.Destroy()
        if not panel.alive then return end
        access(); panel.alive = false
        for _, c in ipairs(connections) do c:Disconnect() end
        table.clear(connections); cleanupCards(); root:Destroy()
    end
    connect(auto.Activated, function()
        panel.autoTouched = true
        if api.GetStatus().active then api.Stop()
        elseif not dirty or panel.Apply() then api.Start() end
    end)
    connect(minimize.Activated, function() panel.SetMinimized(not minimized) end)
    for id, entry in pairs(tabButtons) do
        connect(entry.button.Activated, function() panel.Select(id) end)
        connect(entry.button.MouseEnter, function() if UIS.MouseEnabled then entry.hover = true; paintTabs() end end)
        connect(entry.button.MouseLeave, function() entry.hover = false; paintTabs() end)
    end
    connect(editFilters.Activated, function() panel.Select("filters") end)
    -- Alt izquierdo oculta o muestra el hub tal como estaba (plegado o no).
    connect(UIS.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.LeftAlt then
            if panel.open then panel.Close()
            else panel.open = true; root.Visible = true; signature = nil; fit(); save(); refreshSoon() end
        end
    end)
    connect(apply.Activated, panel.Apply)
    connect(income:GetPropertyChangedSignal("Text"), function()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if minimum ~= draft.minIncome then markDirty() end
    end)
    for _, input in ipairs({income, nameBox, presetName}) do
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
    -- Escala todo el hub con la esquina superior izquierda fija; las hojas
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
        local base = Vector2.new(HUB_WIDTH, HUB_HEIGHT)
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
    for key, page in pairs(pages) do page.Visible = key == tab end
    paintTabs(); applyMinimized(); fit(); setDraft(search.config)
    if renderers[tab] then renderers[tab]() end
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
            sideState.Text = status.active and "AUTO activo" or "AUTO apagado"
            sideState.TextColor3 = status.active and C.green or C.muted
            sideMode.Text = status.active and stateTitle.Text or "Enciende AUTO para buscar " .. config.rarity .. "+."
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
            fit(); if finderVisible() then buildCards() end
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
    print("[EggPanel] Mistake Hub listo")
    return panel
end

return mountEggFilterPanel
