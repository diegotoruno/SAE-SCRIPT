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
    -- Tokens del tema activo (claro u oscuro), compartidos con el runtime y
    -- actualizados en su sitio al cambiar de tema. El azul marca seleccion y
    -- acciones; verde, naranja y rojo solo comunican estados.
    local THEME = context.theme
    local C = THEME.colors
    -- Mistake Hub: cabecera de 56, barra lateral de 172 y paginas de 548 x 472
    -- con margen de 20. Minimizado queda el boton M de 56 x 56, aparte.
    local HUB_WIDTH, HUB_HEIGHT, HEADER, SIDEBAR, LAUNCHER = 760, 560, 56, 172, 56
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
        return make("UIStroke", "Border", object, { Color = color or C.separator, Transparency = 0.78,
            Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    end
    -- Estilo macOS: Builder Sans (la fuente de sistema de Roblox, de la familia
    -- de SF Pro e Inter), iconos de trazo fino y anillo de foco azul. En una
    -- tabla: la funcion del hub esta cerca del limite de 200 locales de Luau.
    local look = {}
    do
        local weights = { regular = Enum.FontWeight.Regular, medium = Enum.FontWeight.Medium,
            semibold = Enum.FontWeight.SemiBold, bold = Enum.FontWeight.Bold }
        function look.face(weight) return Font.new("rbxasset://fonts/families/BuilderSans.json", weights[weight] or weights.medium) end
        -- Teclado y mando: halo azul de 3 px alrededor del control seleccionado.
        look.ring = make("Frame", "FocusRing", nil, { BackgroundTransparency = 1, BorderSizePixel = 0 })
        corner(look.ring, 10)
        make("UIStroke", "Border", look.ring, { Color = C.accent, Thickness = 3, Transparency = 0.25 })
        table.insert(THEME.roots, look.ring)
        -- Campos: el borde pasa a un halo azul mientras se escribe.
        function look.halo(box)
            box.SelectionImageObject = look.ring
            box.Focused:Connect(function()
                if not panel.alive or not session.alive then return end
                access(); box.Border.Color = C.accent; box.Border.Transparency = 0.3; box.Border.Thickness = 2
            end)
            box.FocusLost:Connect(function()
                if not panel.alive or not session.alive then return end
                access(); box.Border.Color = C.separator; box.Border.Transparency = 0.78; box.Border.Thickness = 1
            end)
        end
        -- Iconos al estilo de SF Symbols en una caja de 16 px, con geometria nativa.
        local function segment(parent, x1, y1, x2, y2, color)
            local dx, dy = x2 - x1, y2 - y1
            corner(make("Frame", "Segment", parent, { AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2), Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1.5, 1.5),
                Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = color, BorderSizePixel = 0 }), 1)
        end
        local function dot(parent, x, y, size, color, hollow)
            local piece = make("Frame", "Dot", parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
                Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, BackgroundTransparency = hollow and 1 or 0, BorderSizePixel = 0 })
            corner(piece, math.ceil(size / 2))
            if hollow then make("UIStroke", "Line", piece, { Color = color, Thickness = 1.5 }) end
        end
        local shapes = {
            finder = function(f, c) dot(f, 6.8, 6.8, 8.5, c, true); segment(f, 10.3, 10.3, 13.6, 13.6, c) end,
            filters = function(f, c)
                segment(f, 2.5, 3.5, 13.5, 3.5, c); segment(f, 2.5, 3.5, 6.8, 8.6, c); segment(f, 13.5, 3.5, 9.2, 8.6, c)
                segment(f, 6.8, 8.6, 6.8, 13.5, c); segment(f, 9.2, 8.6, 9.2, 12.2, c); segment(f, 6.8, 13.5, 9.2, 12.2, c)
            end,
            calc = function(f, c)
                local body = make("Frame", "Body", f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(8, 8),
                    Size = UDim2.fromOffset(10.5, 13.5), BackgroundTransparency = 1, BorderSizePixel = 0 })
                corner(body, 2); make("UIStroke", "Line", body, { Color = c, Thickness = 1.5 })
                segment(f, 5.8, 5.2, 10.2, 5.2, c)
                for _, point in ipairs({ {6, 8.8}, {10, 8.8}, {6, 11.6}, {10, 11.6} }) do dot(f, point[1], point[2], 2, c) end
            end,
            hop = function(f, c)
                segment(f, 2.5, 5.5, 13.5, 5.5, c); segment(f, 10.5, 2.5, 13.5, 5.5, c); segment(f, 10.5, 8.5, 13.5, 5.5, c)
                segment(f, 13.5, 10.5, 2.5, 10.5, c); segment(f, 5.5, 7.5, 2.5, 10.5, c); segment(f, 5.5, 13.5, 2.5, 10.5, c)
            end,
            settings = function(f, c)
                for _, y in ipairs({4, 8, 12}) do segment(f, 2, y, 14, y, c) end
                dot(f, 10.5, 4, 4.5, c); dot(f, 5.5, 8, 4.5, c); dot(f, 9, 12, 4.5, c)
            end,
        }
        function look.icon(parent, kind, position, color)
            local frame = make("Frame", "Icon", parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
                Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, BorderSizePixel = 0 })
            shapes[kind](frame, color)
            return frame
        end
        function look.tint(frame, color)
            for _, piece in ipairs(frame:GetDescendants()) do
                if piece:IsA("UIStroke") then piece.Color = color
                elseif piece:IsA("Frame") and piece.BackgroundTransparency < 1 then piece.BackgroundColor3 = color end
            end
        end
    end
    -- Movimiento: solo feedback y contexto, nunca decoracion. Duraciones cortas;
    -- Quint Out para lo que se desplaza o cambia de tamano, Quad Out para color
    -- y bordes; las salidas reflejan la entrada con Quint In.
    local MOTION = {
        color = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        toggle = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        page = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        indicator = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        fold = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        sheetIn = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        sheetOut = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        -- El hub entero recorre mas que una hoja: un poco mas de tiempo para verse.
        hubIn = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        hubOut = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        fade = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    }
    -- Preferencias de accesibilidad de Roblox: movimiento reducido cambia
    -- desplazamientos y escalas por fundidos; menos transparencia oscurece el velo.
    -- Estado del movimiento en una tabla: la funcion del hub esta cerca del
    -- limite de 200 locales de Luau.
    local motion = { tweens = setmetatable({}, { __mode = "k" }) }
    function motion.preference(name, fallback)
        local ok, value = pcall(function() return game:GetService("GuiService")[name] end)
        if ok and value ~= nil then return value end
        return fallback
    end
    function motion.readPreferences()
        motion.reduced = motion.preference("ReducedMotionEnabled", false) == true
        motion.transparency = tonumber(motion.preference("PreferredTransparency", 1)) or 1
    end
    motion.readPreferences()
    -- Un tween por propiedad: parte del valor actual, cancela el anterior de la
    -- misma propiedad y se cancela al destruir su objeto.
    function motion.stop(object)
        local slot = motion.tweens[object]
        if not slot then return end
        motion.tweens[object] = nil
        for _, tween in pairs(slot) do tween:Cancel() end
    end
    local function animate(object, info, goals, done)
        access()
        local slot = motion.tweens[object]
        if not slot then
            slot = {}; motion.tweens[object] = slot
            object.Destroying:Connect(function() access(); motion.stop(object) end)
        end
        local first
        for key, value in pairs(goals) do
            if slot[key] then slot[key]:Cancel() end
            local tween = TweenService:Create(object, info, { [key] = value })
            slot[key] = tween; first = first or tween
            tween.Completed:Connect(function() if slot[key] == tween then slot[key] = nil end end)
            tween:Play()
        end
        if done and first then
            first.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and panel.alive and session.alive then access(); done() end
            end)
        end
    end
    -- Valor final inmediato: cancela lo que hubiera en curso en esas propiedades.
    local function place(object, goals)
        access()
        local slot = motion.tweens[object]
        for key, value in pairs(goals) do
            if slot and slot[key] then slot[key]:Cancel(); slot[key] = nil end
            object[key] = value
        end
    end
    function motion.moving(object, key) local slot = motion.tweens[object]; return slot ~= nil and slot[key] ~= nil end
    -- Tipografia: Bold para titulos y valores clave, SemiBold para etiquetas
    -- de navegacion y valores de filas, Medium para el resto.
    local function text(name, parent, value, x, y, width, height, color, size, bold)
        local label = make("TextLabel", name, parent, {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            Text = value, TextColor3 = color or C.text, TextSize = size or 14,
            FontFace = look.face(bold == true and "bold" or bold == "semi" and "semibold" or "medium"),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            TextStrokeTransparency = 1,
        })
        return label
    end
    -- Texto de varias lineas que se corta al final en lugar de salirse de su caja.
    local function paragraph(name, parent, value, x, y, width, height, color, size)
        local label = text(name, parent, value, x, y, width, height, color, size)
        label.TextWrapped = true; label.TextYAlignment = Enum.TextYAlignment.Top; label.LineHeight = 1.1
        return label
    end
    -- Respuesta al puntero: la pulsacion ilumina el borde al instante (y
    -- AutoButtonColor oscurece el fondo); pasar y soltar vuelven en 120 ms.
    -- GuiState cubre raton, toque y mando. Listas, ingresos y reloj no se animan.
    local function interaction(object)
        local border = object:FindFirstChild("Border")
        local selected = false
        local function feedback(instant)
            if not panel.alive or not session.alive then return end
            local state = object.GuiState
            local lit = selected or state == Enum.GuiState.Press or (state == Enum.GuiState.Hover and UIS.MouseEnabled)
            if instant or state == Enum.GuiState.Press then place(border, { Transparency = lit and 0.4 or 0.78 })
            else animate(border, MOTION.color, { Transparency = lit and 0.4 or 0.78 }) end
        end
        border.Transparency = 0.78
        object.SelectionImageObject = look.ring
        object:GetPropertyChangedSignal("GuiState"):Connect(function() feedback(false) end)
        object.SelectionGained:Connect(function() selected = true; feedback(true) end)
        object.SelectionLost:Connect(function() selected = false; feedback(true) end)
    end
    local function button(name, parent, value, x, y, width, height, color)
        local object = make("TextButton", name, parent, {
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = color or C.control, BorderSizePixel = 0, Text = value,
            TextSize = 13, FontFace = look.face("medium"), TextColor3 = C.text,
            TextStrokeTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = true,
        })
        corner(object); stroke(object); interaction(object)
        return object
    end
    local function paint(object, background, foreground, borderColor)
        access()
        object.BackgroundColor3 = background
        object.TextColor3 = foreground or C.text
        object.Border.Color = borderColor or C.separator
    end
    local function primary(object) paint(object, C.accentStrong, C.onAccent, C.accentStrong); object.FontFace = look.face("semibold") end
    local function field(name, parent, value, placeholder, x, y, width, height)
        local box = make("TextBox", name, parent, {
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = C.field, BorderSizePixel = 0, Text = value, PlaceholderText = placeholder,
            PlaceholderColor3 = C.secondary, FontFace = look.face("medium"), TextSize = 14, TextColor3 = C.text,
            ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        corner(box); stroke(box); make("UIPadding", "Padding", box, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
        look.halo(box)
        return box
    end
    -- Geometria nativa: evita depender de glifos que faltan en algunas fuentes.
    local function line(parent, name, x, y, width, rotation, color, zIndex)
        return make("Frame", name, parent, { AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, 1.5),
            Rotation = rotation or 0, BackgroundColor3 = color or C.secondary,
            BorderSizePixel = 0, ZIndex = zIndex or parent.ZIndex })
    end
    local function selectionIcon(parent, selected, x, y, zIndex, boxed)
        local mark = make("Frame", "SelectionMark", parent, { Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ZIndex = zIndex or parent.ZIndex })
        if boxed then mark.BackgroundTransparency = 0; mark.BackgroundColor3 = C.field; corner(mark, 6); stroke(mark) end
        local short = line(mark, "Short", 8, 12, 6, 0, C.secondary, mark.ZIndex)
        local long = line(mark, "Long", 12, 12, 12, 90, C.secondary, mark.ZIndex)
        local function update(value)
            access()
            short.Position = UDim2.fromOffset(value and 8 or 12, value and 13 or 12)
            short.Size = UDim2.fromOffset(value and 6 or 12, 1.5); short.Rotation = value and 45 or 0
            long.Position = UDim2.fromOffset(value and 14 or 12, value and 11 or 12)
            long.Rotation = value and -45 or 90
            short.BackgroundColor3 = value and (boxed and C.onAccent or C.accentText) or C.secondary
            long.BackgroundColor3 = short.BackgroundColor3
            if boxed then
                short.Visible = value == true; long.Visible = value == true
                mark.BackgroundColor3 = value and C.accent or C.field
                mark.Border.Color = value and C.accent or C.separator
                mark.Border.Transparency = value and 0 or 0.6
            end
        end
        update(selected)
        return update, mark
    end
    -- Selector desplegable: texto a la izquierda y chevron en su propio margen.
    local function chevron(object)
        for index, rotation in ipairs({45, -45}) do
            local segment = line(object, "Chevron" .. index, 0, 0, 6, rotation, C.secondary)
            -- Las posiciones son relativas al area con padding: el chevron vive en el margen.
            segment.Position = UDim2.new(1, index == 1 and 12 or 16, 0.5, 0)
        end
        object.TextXAlignment = Enum.TextXAlignment.Left
        make("UIPadding", "ChevronSpace", object, { PaddingRight = UDim.new(0, 30), PaddingLeft = UDim.new(0, 12) })
    end
    local function crossIcon(object)
        line(object, "Cross1", 16, 16, 12, 45, C.secondary); line(object, "Cross2", 16, 16, 12, -45, C.secondary)
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
        BackgroundColor3 = C.window, BackgroundTransparency = THEME.alpha.window, BorderSizePixel = 0,
        Visible = panel.open and not minimized, Active = true, ClipsDescendants = true, ZIndex = 10,
    })
    corner(root, 14); stroke(root)
    local scale = make("UIScale", "ResponsiveScale", root, { Scale = 1 })

    -- Cabecera: marca a la izquierda, AUTO y minimizar a la derecha. Arrastra el
    -- hub.
    local header = make("Frame", "Header", root, { Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true })
    local logo = make("TextLabel", "Logo", header, { Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "M", TextColor3 = C.onAccent, TextSize = 18,
        FontFace = look.face("bold"), TextStrokeTransparency = 1 })
    corner(logo, 8)
    text("Title", header, "Mistake Hub", 58, 10, 120, 22, C.text, 17, true)
    text("Subtitle", header, "Steal An Egg", 58, 31, 120, 14, C.secondary, 11)
    local minimize = button("Minimize", header, "", 0, 12, 32, 32)
    minimize.Position = UDim2.new(1, -48, 0, 12)
    line(minimize, "Minus", 16, 16, 12, 0, C.secondary)
    -- Minimizado, el hub se guarda y queda el boton M, independiente: tiene su
    -- propia posicion y se arrastra solo. Sin teclado (movil, iPad) no hay Alt
    -- izquierdo y es la forma de volver: tocarlo abre el hub en su sitio, en la
    -- misma seccion. El punto dice si AUTO esta activo.
    local mini = { button = make("TextButton", "MistakeLauncher", context.screenGui, { Size = UDim2.fromOffset(LAUNCHER, LAUNCHER),
        BackgroundColor3 = C.window, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, Active = true, ZIndex = 10,
        SelectionImageObject = look.ring }) }
    corner(mini.button, 14); stroke(mini.button)
    corner(make("TextLabel", "Logo", mini.button, { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "M", TextColor3 = C.onAccent, TextSize = 18,
        FontFace = look.face("bold"), TextStrokeTransparency = 1, ZIndex = 11 }), 8)
    mini.badge = make("Frame", "AutoBadge", mini.button, { Position = UDim2.fromOffset(38, 6), Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = C.tertiary, BorderSizePixel = 0, ZIndex = 12 })
    corner(mini.badge, 5); stroke(mini.badge, C.window, 2).Transparency = 0
    local auto = button("ToggleSearch", header, "AUTO OFF", 0, 12, 100, 32)
    auto.Position = UDim2.new(1, -156, 0, 12); auto.FontFace = look.face("semibold")
    make("UIPadding", "DotSpace", auto, { PaddingLeft = UDim.new(0, 16) })
    local autoDot = make("Frame", "Dot", auto, { Position = UDim2.new(0, -2, 0.5, -4), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.secondary, BorderSizePixel = 0 })
    corner(autoDot, 4)

    -- Barra lateral: superficie mas pesada que el contenido (tono de entrada)
    -- en lugar de lineas. Solo su esquina inferior izquierda sigue la del hub.
    local sidebar = make("Frame", "Sidebar", root, { Position = UDim2.fromOffset(0, HEADER),
        Size = UDim2.fromOffset(SIDEBAR, HUB_HEIGHT - HEADER), BackgroundColor3 = C.sidebar, BorderSizePixel = 0 })
    corner(sidebar, 14)
    make("Frame", "SquareTop", sidebar, { Size = UDim2.new(1, 0, 1, -14), BackgroundColor3 = C.sidebar, BorderSizePixel = 0, ZIndex = 0 })
    make("Frame", "SquareRight", sidebar, { Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = C.sidebar, BorderSizePixel = 0, ZIndex = 0 })
    -- Una sola capsula azul suave que se desliza a la pestana activa: dice de
    -- donde viene el cambio. Las pestanas solo marcan paso y pulsacion.
    local activeTab = make("Frame", "ActiveTab", sidebar, { Position = UDim2.fromOffset(12, 16), Size = UDim2.fromOffset(SIDEBAR - 24, 40),
        BackgroundColor3 = C.selection, BorderSizePixel = 0 })
    corner(activeTab, 8)
    local tabButtons = {}
    for index, item in ipairs(TABS) do
        local b = make("TextButton", "Tab_" .. item.id, sidebar, { Position = UDim2.fromOffset(12, 16 + (index - 1) * 46),
            Size = UDim2.fromOffset(SIDEBAR - 24, 40), BackgroundColor3 = C.controlHover, BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2, SelectionImageObject = look.ring })
        corner(b, 8)
        local glyph = look.icon(b, item.id, UDim2.fromOffset(22, 20), C.secondary)
        local label = text("Label", b, item.label, 40, 0, SIDEBAR - 88, 40, C.text, 13)
        -- Punto naranja: hay cambios de filtros sin aplicar.
        local dot = make("Frame", "Pending", b, { Position = UDim2.new(1, -18, 0.5, -4), Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = C.orangeDot, BorderSizePixel = 0, Visible = false })
        corner(dot, 4)
        tabButtons[item.id] = { button = b, label = label, icon = glyph, dot = dot, y = 16 + (index - 1) * 46, text = item.label }
    end
    local sideState = text("AutoState", sidebar, "AUTO apagado", 16, HUB_HEIGHT - HEADER - 194, SIDEBAR - 32, 16, C.secondary, 11, true)
    local sideMode = paragraph("AutoMode", sidebar, "", 16, HUB_HEIGHT - HEADER - 176, SIDEBAR - 32, 28, C.secondary, 11)
    -- Marca de agua: el TikTok del autor, con el enlace a la vista y un boton
    -- que dice lo que hizo. Copia con el portapapeles del executor (Roblox no
    -- lo expone); sin el, el enlace sigue escrito en la tarjeta.
    do
        local LINK = "https://www.tiktok.com/@mistakeontt"
        local card = make("Frame", "TikTok", sidebar, { Position = UDim2.fromOffset(12, HUB_HEIGHT - HEADER - 136),
            Size = UDim2.fromOffset(SIDEBAR - 24, 92), BackgroundColor3 = C.raised, BorderSizePixel = 0 })
        corner(card, 10); stroke(card)
        text("Label", card, "TIKTOK", 10, 10, SIDEBAR - 44, 12, C.secondary, 10, true)
        text("Link", card, "tiktok.com/@mistakeontt", 10, 24, SIDEBAR - 44, 16, C.text, 11)
        local copyLink = button("CopyLink", card, "Copiar enlace", 10, 50, SIDEBAR - 44, 32)
        primary(copyLink)
        local stamp = 0
        connect(copyLink.Activated, function()
            local copy = type(setclipboard) == "function" and setclipboard or type(toclipboard) == "function" and toclipboard or nil
            local copied = copy ~= nil and pcall(copy, LINK)
            access(); stamp += 1
            local mine = stamp
            copyLink.Text = copied and "Copiado" or "Sin portapapeles"
            if copied then paint(copyLink, C.successTint, C.green, C.green) end
            task.delay(1.6, function()
                if not panel.alive or not session.alive or stamp ~= mine then return end
                access(); copyLink.Text = "Copiar enlace"; primary(copyLink)
            end)
        end)
    end
    local credit = text("ByMistakeCredit", sidebar, "By Mistake", 16, HUB_HEIGHT - HEADER - 34, SIDEBAR - 32, 14, C.accentText, 11, true)
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
        text("Heading", parent, title, 0, y, CONTENT, 20, C.text, 15, true)
        if detail then return paragraph("HeadingDetail", parent, detail, 0, y + 22, CONTENT, 28, C.secondary, 11) end
    end
    local function listFrame(parent, y, height, x, width)
        local list = make("ScrollingFrame", "Options", parent, { Position = UDim2.fromOffset(x or 14, y), Size = UDim2.fromOffset(width or CONTENT - 28, height),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            ScrollBarThickness = 4, ScrollBarImageColor3 = C.tertiary, BorderSizePixel = 0 })
        make("UIPadding", "Padding", list, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 2) })
        make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
        return list
    end
    -- Fila con interruptor: toda la fila lo cambia; el estado se lee en el color.
    local function toggleRow(parent, name, title, detail, y, value, onToggle)
        local row = make("TextButton", name, parent, { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CONTENT, 52),
            BackgroundColor3 = C.raised, BorderSizePixel = 0, Text = "", AutoButtonColor = true })
        corner(row, 10); stroke(row); interaction(row)
        text("Title", row, title, 14, 9, CONTENT - 96, 18, C.text, 14, true)
        text("Detail", row, detail, 14, 28, CONTENT - 96, 14, C.secondary, 11)
        local track = make("Frame", "Switch", row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(44, 24), BackgroundColor3 = C.trackOff, BorderSizePixel = 0 })
        corner(track, 12)
        local knob = make("Frame", "Knob", track, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
            Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.knob, BorderSizePixel = 0 })
        corner(knob, 9); stroke(knob).Transparency = 0.85
        -- La perilla viaja y el carril cambia de color en el mismo frame; un
        -- toque a medio camino la devuelve desde donde esta.
        local function set(on, instant)
            local slide = { Position = UDim2.new(0, on and 23 or 3, 0.5, 0) }
            local colors = { { track, { BackgroundColor3 = on and C.accent or C.trackOff } } }
            if instant or motion.reduced then place(knob, slide) else animate(knob, MOTION.toggle, slide) end
            for _, item in ipairs(colors) do
                if instant then place(item[1], item[2]) else animate(item[1], motion.reduced and MOTION.fade or MOTION.toggle, item[2]) end
            end
        end
        set(value, true)
        row.Activated:Connect(function() access(); onToggle() end)
        return set, row
    end

    -- Egg Finder: estado de la busqueda, filtros guardados y huevos del mapa.
    local finderPage = pages.finder
    local statusCard = make("Frame", "Status", finderPage, { Size = UDim2.fromOffset(CONTENT, 60), BackgroundColor3 = C.raised, BorderSizePixel = 0 })
    corner(statusCard, 10); stroke(statusCard).Transparency = 0.8
    local stateDot = make("Frame", "StateDot", statusCard, { Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.secondary, BorderSizePixel = 0 })
    corner(stateDot, 4)
    local stateTitle = text("SearchState", statusCard, "Conectando detector...", 30, 9, CONTENT - 170, 22, C.text, 15, true)
    local stateDetail = text("SearchDetail", statusCard, "", 14, 33, CONTENT - 154, 18, C.secondary, 11)
    local clockCaption = text("ResetCaption", statusCard, "Renovación", CONTENT - 124, 10, 110, 14, C.secondary, 10)
    local clock = text("ResetClock", statusCard, "--:--", CONTENT - 124, 26, 110, 24, C.text, 18, true)
    clockCaption.TextXAlignment = Enum.TextXAlignment.Right; clock.TextXAlignment = Enum.TextXAlignment.Right
    local summaryBar = make("Frame", "FiltersBar", finderPage, { Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(CONTENT, 32), BackgroundTransparency = 1 })
    text("FiltersCaption", summaryBar, "Filtros", 0, 0, 52, 32, C.text, 13, true)
    local filterSummary = text("FiltersSummary", summaryBar, "", 56, 0, CONTENT - 196, 32, C.secondary, 11)
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
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.tertiary,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollingDirection = Enum.ScrollingDirection.Y,
    })
    make("UIPadding", "Padding", scroll, { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 4) })

    -- Filtros: cada control con su etiqueta encima; abajo los presets.
    local filtersPage = pages.filters
    heading(filtersPage, "Filtros de búsqueda", "AUTO usa los filtros guardados. Los cambios esperan a que pulses Aplicar filtros.", 0)
    local third, half = math.floor((CONTENT - 16) / 3), (CONTENT - 8) / 2
    local filters = make("Frame", "Filters", filtersPage, { Position = UDim2.fromOffset(0, 50), Size = UDim2.fromOffset(CONTENT, 178), BackgroundTransparency = 1, BorderSizePixel = 0 })
    text("RarityLabel", filters, "Rareza mínima", 0, 0, third, 16, C.secondary, 11)
    text("IncomeLabel", filters, "Ingreso mínimo /s", third + 8, 0, third, 16, C.secondary, 11)
    text("MutationLabel", filters, "Mutación", 2 * (third + 8), 0, third, 16, C.secondary, 11)
    local rarityButton = button("Rarity", filters, draft.rarity, 0, 20, third, 38)
    rarityButton.TextSize = 14; chevron(rarityButton)
    local income = field("MinimumIncome", filters, search.FormatMinimum(draft.minIncome), "Ej. 7b o 500m", third + 8, 20, third, 38)
    income.FontFace = look.face("semibold")
    local mutationButton = button("Mutation", filters, draft.mutation == "" and "Todas" or draft.mutation, 2 * (third + 8), 20, third, 38)
    mutationButton.TextSize = 14; chevron(mutationButton)
    text("ZonesLabel", filters, "Zonas", 0, 70, half, 16, C.secondary, 11)
    text("NameLabel", filters, "Nombre contiene", half + 8, 70, half, 16, C.secondary, 11)
    local chooseZones = button("ChooseZones", filters, "Todas las zonas", 0, 90, half, 38)
    chooseZones.TextSize = 14; chevron(chooseZones)
    local nameBox = field("NameFilter", filters, draft.nameContains, "Cualquier nombre", half + 8, 90, half, 38)
    local changeLabel = text("Changes", filters, "Filtros guardados", 0, 140, CONTENT - third - 16, 38, C.secondary, 11)
    changeLabel.TextWrapped = true
    local apply = button("ApplyFilters", filters, "Aplicar filtros", CONTENT - third, 140, third, 38)
    primary(apply); apply.TextSize = 13
    text("PresetsTitle", filtersPage, "Presets", 0, 256, CONTENT, 20, C.text, 15, true)
    local presetMessage = paragraph("PresetMessage", filtersPage, "", 0, 278, CONTENT, 16, C.secondary, 11)
    local presetName = field("PresetName", filtersPage, "", "Nombre del preset", 0, 300, CONTENT - third - 8, 36)
    local savePreset = button("SavePreset", filtersPage, "Guardar actuales", CONTENT - third, 300, third, 36); primary(savePreset)
    local presetList = listFrame(filtersPage, 346, PAGE_H - 346, -2, CONTENT + 4)

    local function save()
        access()
        -- Mientras el hub aparece o se va, su sitio es el de reposo.
        local spot = motion.rest or root.Position
        local ok = writeJson(FILE, { open = panel.open, minimized = minimized, tab = tab, visual = visual,
            view = "map", onlyMatches = onlyMatches, sortBest = sortBest, calc = calc, theme = THEME.preference,
            x = spot.X.Offset, y = spot.Y.Offset, scale = userScale,
            button = { x = mini.button.Position.X.Offset, y = mini.button.Position.Y.Offset } })
        if not ok then panel.error = "No se pudo guardar la posición / vista"; warn("[EggPanel] " .. panel.error) end
    end
    -- Guardar no va en la ruta de la pulsacion: se escribe al final del frame.
    local saveSoon
    do
        local scheduled = false
        function saveSoon()
            if scheduled then return end
            scheduled = true
            task.defer(function() scheduled = false; if panel.alive and session.alive then save() end end)
        end
    end
    -- Hojas modales: el velo bloquea el hub, la hoja cubre el area de paginas y
    -- tocar el velo o la X cierra solo la hoja. Entra desde su origen (el
    -- control o la tarjeta que la abrio) y sale por el mismo camino.
    local closePopup, sheet
    do
    local closing, popupOrigin, popupStart = nil, nil, nil
    local function scrimTransparency() return 0.1 + 0.25 * math.clamp(motion.transparency, 0, 1) end
    function motion.restyleScrim() if popup then place(popup, { BackgroundTransparency = scrimTransparency() }) end end
    local function sheetCenter(height) return Vector2.new(PAGE_X + CONTENT / 2, SHEET_TOP + math.floor((SHEET_SPACE - height) / 2) + height / 2) end
    -- Centro de un objeto en coordenadas del hub, sin la escala de pantalla.
    local function localCenter(object)
        if typeof(object) ~= "Instance" or not object:IsDescendantOf(root) or object.AbsoluteSize.X <= 0 then return nil end
        return (object.AbsolutePosition + object.AbsoluteSize / 2 - root.AbsolutePosition) / math.max(0.1, scale.Scale)
    end
    function closePopup(instant)
        access()
        if closing and instant then closing:Destroy(); closing = nil end
        if not popup then return end
        local scrim, card = popup, popup:FindFirstChild("Sheet")
        popup = nil
        if instant or not root.Visible then scrim:Destroy(); return end
        if closing then closing:Destroy() end
        -- La hoja que sale ya no bloquea: el hub responde mientras se va.
        closing = scrim; scrim.Interactable = false
        animate(scrim, motion.reduced and MOTION.fade or MOTION.sheetOut, { BackgroundTransparency = 1 }, function()
            if closing == scrim then closing = nil end
            scrim:Destroy()
        end)
        if not card then return end
        if motion.reduced then card.Visible = false; return end
        local back = (typeof(popupOrigin) == "Instance" and localCenter(popupOrigin)) or popupStart
        if back then animate(card, MOTION.sheetOut, { Position = UDim2.fromOffset(back.X, back.Y) }) end
        if typeof(popupOrigin) == "Instance" or popupOrigin == nil then animate(card.Zoom, MOTION.sheetOut, { Scale = 0.9 }) end
    end
    -- origin: el GuiObject que la abre, "push" (entra por la derecha sobre otra
    -- hoja) o "pop" (vuelve por la izquierda). Sin origen sube 12 px.
    function sheet(name, title, height, origin)
        access()
        -- Al reemplazar una hoja el velo sigue donde estaba, sin parpadeo.
        local carried = popup and popup.BackgroundTransparency or closing and closing.BackgroundTransparency
        if popup then popup:Destroy(); popup = nil end
        if closing then closing:Destroy(); closing = nil end
        height = math.min(height, SHEET_SPACE)
        local scrim = make("TextButton", name, root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.scrim,
            BackgroundTransparency = carried or 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 50 })
        corner(scrim, 14)
        local center = sheetCenter(height)
        local card = make("Frame", "Sheet", scrim, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y),
            Size = UDim2.fromOffset(CONTENT, height), BackgroundColor3 = C.window, BorderSizePixel = 0, Active = true, ZIndex = 51 })
        corner(card, 12); stroke(card)
        local zoom = make("UIScale", "Zoom", card, { Scale = 1 })
        local heading = text("Title", card, title, 18, 16, CONTENT - 86, 24, C.text, 17, true)
        local dismiss = button("Dismiss", card, "", CONTENT - 50, 12, 32, 32); crossIcon(dismiss)
        scrim.Activated:Connect(function() access(); closePopup() end)
        dismiss.Activated:Connect(function() access(); closePopup() end)
        popup = scrim
        local lateral = origin == "push" or origin == "pop"
        local start = origin == "push" and center + Vector2.new(24, 0) or origin == "pop" and center - Vector2.new(24, 0)
            or localCenter(origin) or center + Vector2.new(0, 12)
        popupOrigin, popupStart = origin, start
        if motion.reduced then
            animate(scrim, MOTION.fade, { BackgroundTransparency = scrimTransparency() })
        else
            animate(scrim, MOTION.sheetIn, { BackgroundTransparency = scrimTransparency() })
            card.Position = UDim2.fromOffset(start.X, start.Y); zoom.Scale = lateral and 1 or 0.9
            animate(card, MOTION.sheetIn, { Position = UDim2.fromOffset(center.X, center.Y) })
            animate(zoom, MOTION.sheetIn, { Scale = 1 })
        end
        return card, heading
    end
    end
    local initializedPosition = false
    local function fitLimit()
        local camera = workspace.CurrentCamera
        if not camera then return nil end
        local viewport = camera.ViewportSize
        return math.min((viewport.X - 28) / HUB_WIDTH, (viewport.Y - 28) / HUB_HEIGHT)
    end
    -- Limites de la esquina superior izquierda para el tamano final del hub.
    local function bounds(viewport)
        local base = motion.base or scale.Scale
        local width, height = HUB_WIDTH * base, HUB_HEIGHT * base
        return Vector2.new(8, 8), Vector2.new(math.max(8, viewport.X - width - 8), math.max(8, viewport.Y - height - 8))
    end
    local function fit(animated)
        access()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        -- Escala de reposo; mientras el hub crece o se encoge la lleva su tween.
        motion.base = scaling.Panel(userScale, fitLimit())
        if not motion.moving(scale, "Scale") then scale.Scale = motion.base end
        if not initializedPosition then
            root.Position = UDim2.fromOffset(tonumber(saved.x) or (viewport.X - HUB_WIDTH * motion.base) / 2,
                tonumber(saved.y) or math.max(14, (viewport.Y - HUB_HEIGHT * motion.base) / 2))
            -- El boton M empieza al borde izquierdo, a media altura.
            local spot = type(saved.button) == "table" and saved.button or {}
            mini.button.Position = UDim2.fromOffset(tonumber(spot.x) or 16, tonumber(spot.y) or math.floor((viewport.Y - LAUNCHER) / 2))
            initializedPosition = true
        end
        if not motion.spring and not (motion.dragging and motion.dragObject == mini.button) then
            local spot = mini.button.Position
            mini.button.Position = UDim2.fromOffset(math.clamp(spot.X.Offset, 8, math.max(8, viewport.X - LAUNCHER - 8)),
                math.clamp(spot.Y.Offset, 8, math.max(8, viewport.Y - LAUNCHER - 8)))
        end
        -- Arrastre, resorte y aparicion mueven el hub ellos mismos.
        if motion.dragging or motion.spring or motion.moving(root, "Position") then return end
        local low, high = bounds(viewport)
        local target = UDim2.fromOffset(math.clamp(root.Position.X.Offset, low.X, high.X), math.clamp(root.Position.Y.Offset, low.Y, high.Y))
        if target == root.Position then return end
        if animated and not motion.reduced then animate(root, MOTION.fold, { Position = target }) else root.Position = target end
    end
    -- Las tarjetas solo se dibujan con el Egg Finder a la vista.
    local function finderVisible() return panel.open and not minimized and tab == "finder" end
    local function releaseModels()
        for _, entry in pairs(entries) do
            if entry.viewport then entry.viewport:Destroy(); entry.viewport = nil; entry.key = nil end
        end
    end
    local function paintTab(id)
        local entry = tabButtons[id]
        local state = entry.button.GuiState
        -- Pulsar se ve al instante; la seleccion la lleva ActiveTab.
        local fill = state == Enum.GuiState.Press and 0.4 or id == tab and 1
            or (state == Enum.GuiState.Hover and UIS.MouseEnabled) and 0.55 or 1
        if state == Enum.GuiState.Press then place(entry.button, { BackgroundTransparency = fill })
        else animate(entry.button, MOTION.color, { BackgroundTransparency = fill }) end
    end
    local function paintTabs(animated)
        access()
        for id, entry in pairs(tabButtons) do
            paintTab(id)
            local color = { TextColor3 = id == tab and C.accentText or C.text }
            if animated then animate(entry.label, MOTION.color, color) else place(entry.label, color) end
            entry.label.FontFace = look.face(id == tab and "semibold" or "medium")
            look.tint(entry.icon, id == tab and C.accentText or C.secondary)
        end
        local goal = { Position = UDim2.fromOffset(12, tabButtons[tab].y) }
        if animated and not motion.reduced then animate(activeTab, MOTION.indicator, goal) else place(activeTab, goal) end
    end
    -- El hub aparece y se va en su propio sitio, no desde el boton M. Como las
    -- hojas, se expande desde el 85 % con el centro fijo y se va encogiendose
    -- por el mismo camino: escala y posicion comparten curva y tiempo, asi el
    -- centro no se mueve. Otro toque a mitad de camino lo invierte desde ahi.
    local HUB_ZOOM = 0.85
    local function applyMinimized(animated)
        access()
        local show = panel.open and not minimized
        mini.button.Visible = panel.open and minimized
        if not show then closePopup(true); releaseModels() end
        if motion.shown == show then return end
        motion.shown = show
        local rest, base = motion.rest or root.Position, motion.base or scale.Scale
        root.Interactable = show
        if not animated or motion.reduced then
            place(root, { Position = rest }); place(scale, { Scale = base }); motion.rest = nil; root.Visible = show
            return
        end
        motion.rest = rest
        local inset = (1 - HUB_ZOOM) * base / 2
        local small = UDim2.fromOffset(rest.X.Offset + HUB_WIDTH * inset, rest.Y.Offset + HUB_HEIGHT * inset)
        if show then
            if not root.Visible then root.Position = small; scale.Scale = HUB_ZOOM * base; root.Visible = true end
            animate(scale, MOTION.hubIn, { Scale = base })
            animate(root, MOTION.hubIn, { Position = rest }, function() motion.rest = nil; fit() end)
        else
            animate(scale, MOTION.hubOut, { Scale = HUB_ZOOM * base })
            animate(root, MOTION.hubOut, { Position = small }, function()
                root.Visible = false; place(root, { Position = rest }); place(scale, { Scale = motion.base or base }); motion.rest = nil
            end)
        end
    end
    local function refreshSoon()
        if panel.Refresh then task.defer(function() if panel.alive and session.alive then panel.Refresh() end end) end
    end
    -- Contenido que se vuelve a construir al entrar en su seccion.
    local renderers = {}
    function panel.Select(id)
        access(); assert(pages[id], "Sección desconocida")
        closePopup(true)
        local changed = id ~= tab
        tab = id
        for key, page in pairs(pages) do page.Visible = key == id end
        -- La pagina nueva sube 8 px: acompana al indicador sin cubrir el contenido.
        local settle = { Position = UDim2.fromOffset(0, 0) }
        if changed and not motion.reduced then pages[id].Position = UDim2.fromOffset(0, 8); animate(pages[id], MOTION.page, settle)
        else place(pages[id], settle) end
        if id ~= "finder" then releaseModels() end
        if minimized then minimized = false; applyMinimized(true); fit(true) end
        paintTabs(changed); signature = nil; saveSoon()
        if renderers[id] then renderers[id]() end
        if id == "finder" then refreshSoon() end
    end
    function panel.Open()
        access(); panel.open, minimized = true, false; applyMinimized(true)
        signature = nil; fit(true); save(); refreshSoon()
    end
    function panel.Close()
        access(); panel.open = false; applyMinimized(); save()
    end
    -- Minimizado queda el boton M; abrir vuelve a la misma seccion.
    function panel.SetMinimized(value)
        access(); minimized = value == true; applyMinimized(true); signature = nil; fit(true); saveSoon()
        if not minimized then refreshSoon() end
    end
    local function setMessage(value, color)
        access(); changeLabel.Text = value; changeLabel.TextColor3 = color or C.secondary
    end
    local function markDirty()
        access()
        dirty = true; signature = nil
        chooseZones.Text = zonesText(selectionList(), allZones)
        tabButtons.filters.dot.Visible = true
        setMessage("Cambios sin aplicar. AUTO sigue usando los filtros guardados.", C.orange)
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
    -- Controles que reflejan un estado: se repintan en la misma pulsacion,
    -- no en el siguiente ciclo de un segundo.
    local paintControls
    do
    local autoActive = false
    function paintControls(active)
        access()
        if active ~= nil then autoActive = active == true end
        auto.Text = autoActive and "AUTO ON" or "AUTO OFF"
        -- Activo es un estado: verde suave; apagado es neutro, nunca error.
        paint(auto, autoActive and C.successTint or C.control, autoActive and C.green or C.secondary, autoActive and C.green or C.separator)
        autoDot.BackgroundColor3 = autoActive and C.greenDot or C.tertiary
        mini.badge.BackgroundColor3 = autoActive and C.greenDot or C.tertiary
        sideState.Text = autoActive and "AUTO activo" or "AUTO apagado"
        sideState.TextColor3 = autoActive and C.green or C.secondary
        visualButton.Text = visual == "eggs" and "Ver: Huevos" or visual == "pets" and "Ver: Criaturas" or "Ver: Modelos 3D"
        sortButton.Text = sortBest and "Orden: Rareza" or "Orden: Nombre"
        paint(tabCatalog, onlyMatches and C.selection or C.control, onlyMatches and C.accentText or C.text, onlyMatches and C.accent or C.separator)
        paint(tabMap, not onlyMatches and C.selection or C.control, not onlyMatches and C.accentText or C.text, not onlyMatches and C.accent or C.separator)
        tabCatalog.FontFace = look.face(onlyMatches and "semibold" or "medium")
        tabMap.FontFace = look.face(onlyMatches and "medium" or "semibold")
    end
    end
    function panel.SetVisual(mode)
        access(); assert(mode == "eggs" or mode == "pets" or mode == "models")
        visual = mode; signature = nil; paintControls(); saveSoon(); refreshSoon()
    end
    function panel.SetSortBest(value)
        access(); sortBest = value == true; signature = nil; paintControls(); saveSoon(); refreshSoon()
    end
    function panel.SetOnlyMatches(value)
        access(); onlyMatches = value == true; signature = nil; paintControls(); saveSoon(); refreshSoon()
    end
    local function luminance(color)
        local function linear(component)
            return component <= 0.04045 and component / 12.92 or ((component + 0.055) / 1.055) ^ 2.4
        end
        return 0.2126 * linear(color.R) + 0.7152 * linear(color.G) + 0.0722 * linear(color.B)
    end
    local function rarityColor(rarity, fallback)
        local color = type(rarity) == "table" and rarity.Color
        if typeof(color) ~= "Color3" then return fallback or C.secondary end
        -- Preservar el tono oficial y acercarlo al texto del tema hasta 4.5:1
        -- sobre las superficies donde aparece (tarjeta, seleccion, coincidencia).
        local function worst(value)
            local minimum = math.huge
            for _, surface in ipairs({C.raised, C.control, C.selection, C.successTint, C.orangeTint}) do
                local a, b = luminance(value), luminance(surface)
                minimum = math.min(minimum, (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05))
            end
            return minimum
        end
        for _ = 1, 14 do
            if worst(color) >= 4.5 then break end
            color = color:Lerp(C.text, 0.15)
        end
        return color
    end
    local function dropdown(kind, options, current, select, origin)
        local card = sheet("Dropdown", kind == "rarity" and "Rareza mínima" or "Mutación", 452, origin)
        text("Hint", card, kind == "rarity" and "Incluye la rareza elegida y todas las superiores."
            or "Muestra solo huevos que tengan esta mutación.", 18, 44, CONTENT - 36, 16, C.secondary, 11)
        local list = listFrame(card, 72, 364)
        for index, item in ipairs(options) do
            local selected = item.id == current
            local b = button("Option_" .. index, list, "", 0, 0, 0, 40)
            b.Size = UDim2.new(1, -2, 0, 40); b.LayoutOrder = index
            local label = text("Label", b, item.label, 14, 0, 0, 40, item.color or C.text, 14, selected)
            label.Size = UDim2.new(1, -56, 1, 0)
            if selected then
                paint(b, C.selection, C.text, C.accent)
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
    local function zonePicker(origin)
        local options = search.ZoneOptions()
        access()
        if #options == 0 then setMessage("Esperando la lista de zonas del juego..."); return end
        local card = sheet("ZonePicker", "Zonas", 480, origin)
        local counter = text("Hint", card, "", 18, 44, CONTENT - 36, 16, C.secondary, 11)
        local selectAll = button("SelectAll", card, "Todas", 18, 72, 110, 32)
        local clearZones = button("ClearSelection", card, "Ninguna", 136, 72, 110, 32)
        local list = listFrame(card, 116, 296)
        text("Footer", card, "Se guardan al pulsar Aplicar filtros.", 18, 426, 300, 36, C.secondary, 11)
        local done = button("Done", card, "Listo", CONTENT - 18 - 120, 426, 120, 36); primary(done)
        done.Activated:Connect(function() access(); closePopup() end)
        local checks = {}
        local function refreshChecks()
            access()
            local count = #selectionList()
            counter.Text = allZones and "Todas las zonas: no se excluye ninguna."
                or string.format("%d de %d zonas seleccionadas", count, #options)
            counter.TextColor3 = (not allZones and count == 0) and C.red or C.secondary
            for id, entry in pairs(checks) do
                local selected = allZones or selection[id] == true
                entry.check(selected)
                paint(entry.button, selected and C.selection or C.control, C.text, selected and C.accent or C.separator)
            end
        end
        for index, option in ipairs(options) do
            local b = button("Zone_" .. option.id, list, "", 0, 0, 0, 44)
            b.Size = UDim2.new(1, -2, 0, 44); b.LayoutOrder = index
            text("Name", b, option.label, 14, 0, 0, 44, C.text, 14, true).Size = UDim2.new(1, -60, 1, 0)
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
    local detail
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
    local function bestColor(row) return row.best == "previous" and C.secondary or C.orange end
    -- Best egg of this cycle and of the last ended ones, same rarity and zones,
    -- to see what really appears before choosing the minimum. Information only.
    local HISTORY_CYCLES = 5
    local function ageText(age)
        if age <= 0 then return "Ciclo que termina" end
        if age == 1 then return "Ciclo anterior" end
        return string.format("Hace %d ciclos", age)
    end
    -- Desde el detalle entra por la derecha y "Detalle" vuelve por la izquierda.
    local function bestHistory(fromRow)
        access()
        local card, title = sheet("BestHistory", "Mejores de los últimos ciclos", 480, fromRow and "push" or nil)
        if fromRow then
            title.Size = UDim2.fromOffset(CONTENT - 86 - 112, 24)
            local back = button("Back", card, "Detalle", CONTENT - 50 - 112, 12, 104, 32)
            line(back, "Upper", 20, 13.5, 7, -45, C.secondary); line(back, "Lower", 20, 18.5, 7, 45, C.secondary)
            back.Activated:Connect(function() access(); detail(fromRow, "pop") end)
        end
        paragraph("Hint", card, string.format("El mejor huevo %s+ de cada ciclo en tus zonas, aunque no llegue al mínimo. "
            .. "Un ciclo sin ninguno no aparece.", search.config.rarity), 18, 44, CONTENT - 36, 32, C.secondary, 11)
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
                BackgroundColor3 = C.raised, BorderSizePixel = 0})
            corner(row); stroke(row, index == 1 and current and C.orange or C.separator).Transparency = index == 1 and current and 0.3 or 0.8
            text("When", row, item.label, 14, 8, 0, 14, index == 1 and current and C.orange or C.secondary, 10, true).Size = UDim2.new(1, -150, 0, 14)
            text("Name", row, tostring(best.name or best.category), 14, 22, 0, 18, C.text, 14, true).Size = UDim2.new(1, -150, 0, 18)
            local tags = text("Tags", row, "", 14, 40, 0, 14, C.secondary, 10)
            tags.Size = UDim2.new(1, -150, 0, 14); tags.RichText = true
            tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s%s',
                hex(rarityColor(catalog and catalog.Rarity)), escape(best.rarity or "?"), escape(zoneName(best.area)),
                #labels > 0 and "  ·  " .. escape(table.concat(labels, " + ")) or "")
            local reaches = best.income >= minimum
            local income = text("Income", row, number(best.income) .. "/s", 0, 10, 124, 22, reaches and C.green or C.text, 16, true)
            income.Position = UDim2.new(1, -138, 0, 10); income.TextXAlignment = Enum.TextXAlignment.Right
            local verdict = text("Minimum", row, reaches and "llega al mínimo" or "bajo el mínimo", 0, 34, 124, 14, C.secondary, 10)
            verdict.Position = UDim2.new(1, -138, 0, 34); verdict.TextXAlignment = Enum.TextXAlignment.Right
        end
        if #cycles == 0 then
            paragraph("Empty", list, "Todavía no hay ciclos con un huevo de tu rareza en tus zonas. Se registran con AUTO activo.",
                4, 12, CONTENT - 60, 40, C.secondary, 12)
        end
        paragraph("Minimum", card, "Ingreso mínimo guardado: " .. search.FormatMinimum(minimum) .. "/s", 18, 436, CONTENT - 36, 32, C.secondary, 11)
    end
    panel.OpenBestHistory = function() bestHistory() end
    -- origin: la tarjeta pulsada (la hoja nace de ella) o "pop" al volver del historial.
    function detail(row, origin)
        access()
        -- Filas de 36 y acciones en una sola fila: cabe en el area del hub.
        local factCount = row.best and 7 or 6
        local actionsY = 126 + factCount * 36 + 12
        local card = sheet("EggDetail", row.name, actionsY + 58, origin)
        local tags = text("Tags", card, "", 18, 44, CONTENT - 36, 18, C.secondary, 12)
        tags.RichText = true
        tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s', hex(rarityColor(row.catalog and row.catalog.Rarity)),
            escape(row.rarity), escape(zoneName(row.area)))
        local verdict = make("Frame", "Verdict", card, { Position = UDim2.fromOffset(18, 74), Size = UDim2.fromOffset(CONTENT - 36, 40),
            BackgroundColor3 = row.match and C.successTint or C.raised, BorderSizePixel = 0 })
        corner(verdict); stroke(verdict, row.match and C.green or C.separator).Transparency = row.match and 0.4 or 0.78
        text("Text", verdict, row.best and bestText(row) or row.match and "Cumple todos los filtros"
            or "No cumple: " .. string.lower(row.reason),
            14, 0, CONTENT - 64, 40, row.best and bestColor(row) or row.match and C.green or C.text, 13, true)
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
            -- Filas de 36 sin lineas: el alto y la alineacion bastan para leerlas.
            text("Label" .. index, card, fact[1], 18, y, 150, 36, C.secondary, 12)
            text("Value" .. index, card, fact[2], 172, y, CONTENT - 190, 36, C.text, 14, "semi")
        end
        local actionWidth = row.best and (CONTENT - 44) / 2 or CONTENT - 36
        if row.best then
            local history = button("BestHistory", card, "Mejores de los últimos ciclos", 18, actionsY, actionWidth, 40)
            history.Activated:Connect(function() access(); bestHistory(row) end)
        end
        local calculate = button("Calculate", card, "Calcular con otras mutaciones", row.best and 26 + actionWidth or 18, actionsY, actionWidth, 40)
        calculate.Activated:Connect(function()
            access(); panel.OpenCalculator(row.category, row.scale, row.mutationIds)
        end)
    end
    local function createCard(row)
        local entry = {row = row}
        local card = make("TextButton", "Card_" .. row.uid, scroll, {Size = UDim2.new(1, -2, 0, ROW_HEIGHT),
            BackgroundColor3 = C.raised, BorderSizePixel = 0, Text = "", AutoButtonColor = true})
        entry.card = card; corner(card, 10); entry.border = stroke(card); interaction(card)
        entry.box = make("Frame", "Visual", card, {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(76, 76), BackgroundTransparency = 1, BorderSizePixel = 0})
        entry.image = make("ImageLabel", "EggImage", entry.box, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit})
        entry.name = text("Name", card, "", 100, 10, 0, 20, C.text, 15, true)
        entry.name.Size = UDim2.new(1, -212, 0, 20)
        entry.income = text("Income", card, "", 100, 32, 0, 24, C.text, 20, true)
        entry.income.Size = UDim2.new(1, -212, 0, 24)
        entry.weight = text("SizeWeight", card, "", 100, 58, 0, 16, C.secondary, 11)
        entry.weight.Size = UDim2.new(1, -136, 0, 16)
        entry.tags = text("Tags", card, "", 100, 76, 0, 16, C.secondary, 11)
        entry.tags.Size = UDim2.new(1, -136, 0, 16); entry.tags.RichText = true
        entry.badge = make("Frame", "Badge", card, {Position = UDim2.new(1, -104, 0, 10), Size = UDim2.fromOffset(92, 22), BorderSizePixel = 0})
        corner(entry.badge, 11); entry.badgeBorder = stroke(entry.badge)
        entry.match = text("Match", entry.badge, "", 0, 0, 92, 22, C.secondary, 10, true)
        entry.match.TextXAlignment = Enum.TextXAlignment.Center
        local open = make("Frame", "Open", card, {Position = UDim2.new(1, -28, 0, 60), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1})
        line(open, "Upper", 8, 5, 7, 45, C.secondary); line(open, "Lower", 8, 10, 7, -45, C.secondary)
        card.Activated:Connect(function() access(); detail(entry.row, card) end)
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
        local marked = row.match or (row.best and row.best ~= "previous")
        entry.card.BackgroundColor3 = row.match and C.successTint or row.best and row.best ~= "previous" and C.orangeTint or C.raised
        entry.border.Color = row.best == "previous" and C.separator or row.best and C.orange or row.match and C.green or C.separator
        entry.border.Thickness = marked and 1.5 or 1
        entry.name.Text = row.name; entry.name.TextColor3 = C.text
        entry.income.Text = (row.income and number(row.income) or "?") .. "/s"
        entry.income.TextColor3 = row.match and C.green or row.best and bestColor(row) or C.text
        entry.weight.Text = row.best and bestText(row) or string.format("x%.2f  ·  %s", row.scale or 1, row.weight)
        entry.weight.TextColor3 = row.best and bestColor(row) or C.secondary
        entry.weight.FontFace = look.face(row.best and "bold" or "medium")
        entry.tags.Text = string.format('<font color="%s"><b>%s</b></font>  ·  %s  ·  %s',
            hex(rarityColor(row.catalog and row.catalog.Rarity)), escape(row.rarity), escape(row.mutations), escape(zoneName(row.area)))
        entry.match.Text = row.match and "Cumple" or (SHORT_REASONS[row.reason] or "Sin datos")
        entry.match.TextColor3 = row.match and C.green or C.secondary
        entry.badge.BackgroundColor3 = row.match and C.raised or C.field
        entry.badge.BackgroundTransparency = 0
        entry.badgeBorder.Color = row.match and C.green or C.separator
        entry.badgeBorder.Transparency = row.match and 0.3 or 0.78
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
                    Ambient = Color3.fromRGB(210, 210, 230), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -1)})
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
                empty = paragraph("Empty", scroll, "", 24, 40, CONTENT - 56, 90, C.secondary, 13)
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
        setMessage("Preset «" .. tostring(name) .. "» cargado. Pulsa Aplicar filtros para usarlo.", C.orange)
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
    -- Roblox no tiene tracking: los rotulos van en tipo oracion, no en mayusculas.
    local function caption(parent, value, x, y, width) text("Section", parent, value, x, y, width, 16, C.secondary, 11, "semi") end
    -- Presets de la pagina Filtros: guardar el formulario, cargarlo o borrarlo.
    local function presetResult(callback)
        local ok, err = pcall(callback); access()
        if not ok then presetMessage.Text = sentence(err); presetMessage.TextColor3 = C.red end
        return ok
    end
    local function renderPresets(notice)
        access()
        presetMessage.Text = notice or "Guarda los filtros del formulario. Al cargar uno, pulsa Aplicar filtros para usarlo."
        presetMessage.TextColor3 = notice and C.green or C.secondary
        for _, child in ipairs(presetList:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        local presets = api.Presets()
        access()
        for index, preset in ipairs(presets) do
            local row = make("Frame", "Preset_" .. index, presetList, {Size = UDim2.new(1, -2, 0, 52), BackgroundColor3 = C.raised, BorderSizePixel = 0, LayoutOrder = index})
            corner(row); stroke(row).Transparency = 0.8
            text("Name", row, preset.name, 14, 8, 0, 18, C.text, 14, true).Size = UDim2.new(1, -196, 0, 18)
            local minimum = tonumber(preset.config.minIncome)
            local summary = minimum and minimum > 0 and minimum < math.huge and search.FormatMinimum(minimum) .. "/s" or "ingreso inválido"
            local zones = type(preset.config.zones) == "table" and preset.config.zones or {}
            text("Summary", row, string.format("%s+  ·  desde %s  ·  %s", tostring(preset.config.rarity or "Sin rareza"), summary,
                zonesText(zones, #zones == 0)), 14, 28, 0, 16, C.secondary, 11).Size = UDim2.new(1, -196, 0, 16)
            local load = button("Load", row, "Cargar", 0, 10, 82, 32); load.Position = UDim2.new(1, -176, 0, 10)
            local delete = button("Delete", row, "Borrar", 0, 10, 82, 32); delete.Position = UDim2.new(1, -88, 0, 10)
            delete.TextColor3 = C.red
            load.Activated:Connect(function() access(); presetResult(function() panel.LoadPreset(preset.name) end) end)
            delete.Activated:Connect(function()
                access(); if presetResult(function() api.DeletePreset(preset.name) end) then renderPresets("Preset borrado.") end
            end)
        end
        if #presets == 0 then paragraph("Empty", presetList, "Todavía no hay presets. Escribe un nombre y pulsa Guardar actuales.", 4, 12, CONTENT - 60, 40, C.secondary, 12) end
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
        -- Apariencia: control segmentado Claro / Oscuro / Sistema dentro de su
        -- seccion. Cambia el hub y la tarjeta flotante al instante y se guarda.
        heading(settingsPage, "Apariencia", nil, 0)
        local track = make("Frame", "Theme", settingsPage, { Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(292, 32),
            BackgroundColor3 = C.window, BorderSizePixel = 0 })
        corner(track, 8); stroke(track)
        for index, choice in ipairs({ {id = "light", label = "Claro"}, {id = "dark", label = "Oscuro"}, {id = "system", label = "Sistema"} }) do
            local active = THEME.preference == choice.id
            local option = make("TextButton", "Theme_" .. choice.id, track, { Position = UDim2.fromOffset(2 + (index - 1) * 96, 2),
                Size = UDim2.fromOffset(96, 28), BackgroundColor3 = C.raised, BackgroundTransparency = active and 0 or 1,
                BorderSizePixel = 0, Text = choice.label, TextSize = 13, TextColor3 = active and C.text or C.secondary,
                FontFace = look.face(active and "semibold" or "medium"), AutoButtonColor = false, SelectionImageObject = look.ring })
            corner(option, 6)
            if active then stroke(option).Transparency = 0.85 end
            -- Pasar y pulsar dan un fondo suave a las opciones no elegidas.
            option:GetPropertyChangedSignal("GuiState"):Connect(function()
                if active or not panel.alive then return end
                local state = option.GuiState
                place(option, { BackgroundTransparency = state == Enum.GuiState.Press and 0.35
                    or (state == Enum.GuiState.Hover and UIS.MouseEnabled) and 0.6 or 1 })
            end)
            option.Activated:Connect(function() access(); THEME.Set(choice.id) end)
        end
        paragraph("ThemeHint", settingsPage, THEME.preference == "system"
            and "Sigue la hora de este dispositivo: claro de 7:00 a 19:00. Ahora " .. (THEME.name == "dark" and "oscuro." or "claro.")
            or "Se guarda en este dispositivo y se aplica al cargar.", 308, 28, CONTENT - 308, 32, C.secondary, 11)
        heading(settingsPage, "Alertas", "Al encontrar un huevo que cumple, AUTO avisa y espera la captura.", 78)
        local settings = api.Alerts()
        access()
        local test = button("TestAlert", settingsPage, "Probar alerta", 0, 252, third, 34)
        local message = paragraph("Message", settingsPage, notice or "", third + 12, 252, CONTENT - third - 12, 34, C.green, 11)
        message.TextYAlignment = Enum.TextYAlignment.Center
        local function result(callback)
            local ok, err = pcall(callback); access()
            if not ok and message.Parent then message.Text = sentence(err); message.TextColor3 = C.red end
            return ok
        end
        -- Cada interruptor se actualiza en su sitio para que se vea la perilla.
        local setNotification, setSound
        setNotification = toggleRow(settingsPage, "Notification", "Notificación", "Aviso de Roblox con el nombre, el ingreso y la zona.", 132, settings.notification, function()
            if result(function() settings = api.ConfigureAlerts({notification = not settings.notification}) end) then setNotification(settings.notification) end
        end)
        setSound = toggleRow(settingsPage, "Sound", "Sonido", "Un pitido corto junto al aviso.", 190, settings.sound, function()
            if result(function() settings = api.ConfigureAlerts({sound = not settings.sound}) end) then setSound(settings.sound) end
        end)
        test.Activated:Connect(function()
            access(); if result(api.TestAlert) then message.Text = "Alerta de prueba enviada."; message.TextColor3 = C.green end
        end)
        -- La accion de la seccion vive en su encabezado, alineada a la derecha.
        text("Heading", settingsPage, "Interfaz", 0, 304, CONTENT - 252, 20, C.text, 15, true)
        local facts = {
            {"Mostrar u ocultar", "Alt izquierdo"},
            {"Plegar", "El botón de la cabecera deja solo la barra con AUTO"},
            {"Tamaño", "Arrastra la esquina inferior derecha"},
            {"Acceso rápido", "Se activa o desactiva en Server Hop"},
        }
        for index, fact in ipairs(facts) do
            local y = 332 + (index - 1) * 28
            text("Label" .. index, settingsPage, fact[1], 0, y, 150, 28, C.secondary, 12)
            text("Value" .. index, settingsPage, fact[2], 160, y, CONTENT - 160, 28, C.text, 13)
        end
        local reset = button("ResetLayout", settingsPage, "Restablecer tamaño y posición", CONTENT - 240, 298, 240, 32)
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
    local function speciesPicker(origin)
        access()
        local card = sheet("SpeciesPicker", "Especie", 480, origin)
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
                    text("Label", b, option.label, 14, 0, 0, 40, C.text, 14, selected).Size = UDim2.new(1, -150, 1, 0)
                    local rarity = text("Rarity", b, tostring(option.rarity or "?"), 0, 0, 120, 40,
                        rarityColor(rarities[option.rarity], C.secondary), 11, true)
                    rarity.Position = UDim2.new(1, -134, 0, 0); rarity.TextXAlignment = Enum.TextXAlignment.Right
                    if selected then paint(b, C.selection, C.text, C.accent) end
                    b.Activated:Connect(function()
                        access(); calc.category = option.id; calc.scale, calc.scaleWeight = nil, nil; save(); panel.OpenCalculator()
                    end)
                end
            end
            if shown == 0 then paragraph("Empty", list, "Ninguna especie con ese nombre.", 4, 12, CONTENT - 60, 30, C.secondary, 12) end
        end
        query:GetPropertyChangedSignal("Text"):Connect(render)
        render()
    end
    local bonusCache = {}
    -- Dos columnas: especie, peso y mutaciones a la izquierda; resultado a la derecha.
    local function renderCalculator()
        access()
        for _, child in ipairs(calcPage:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end
        heading(calcPage, "Calculadora de ingreso", "Cuánto da una mascota según su peso y mutaciones, con las fórmulas del juego. "
            .. "Las mutaciones se suman: Golden + Rainbow = x5.", 0)
        if not search.modules then
            paragraph("Loading", calcPage, "Cargando los datos del juego... Vuelve a abrir la calculadora en unos segundos.", 0, 64, CONTENT, 30, C.secondary, 12)
            return
        end
        local resultWidth = 202
        local left = CONTENT - resultWidth - 12
        text("SpeciesLabel", calcPage, "Especie", 0, 58, CONTENT - third - 8, 16, C.secondary, 11)
        text("WeightLabel", calcPage, "Peso (kg)", CONTENT - third, 58, third, 16, C.secondary, 11)
        local species = button("Species", calcPage, petLabel(calc.category) or "Elegir especie", 0, 78, CONTENT - third - 8, 38)
        species.TextSize = 14; chevron(species)
        local weight = field("Weight", calcPage, calc.weight, "Ej. 44,904", CONTENT - third, 78, third, 38)
        weight.FontFace = look.face("semibold")
        caption(calcPage, "Mutaciones", 0, 134, 120)
        local clear = button("ClearMutations", calcPage, "Quitar todas", left - 110, 128, 110, 28)
        local grid = make("ScrollingFrame", "Mutations", calcPage, { Position = UDim2.fromOffset(0, 166), Size = UDim2.fromOffset(left, PAGE_H - 166),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            ScrollBarThickness = 4, ScrollBarImageColor3 = C.tertiary, BorderSizePixel = 0 })
        local cell = math.floor((left - 18) / 2)
        make("UIGridLayout", "Layout", grid, { CellSize = UDim2.fromOffset(cell, 34), CellPadding = UDim2.fromOffset(8, 8),
            SortOrder = Enum.SortOrder.LayoutOrder })
        local result = make("Frame", "Result", calcPage, { Position = UDim2.fromOffset(CONTENT - resultWidth, 128),
            Size = UDim2.fromOffset(resultWidth, PAGE_H - 128), BackgroundColor3 = C.raised, BorderSizePixel = 0 })
        corner(result, 10); stroke(result).Transparency = 0.8
        local inner = resultWidth - 28
        text("IncomeCaption", result, "Ingreso por segundo", 14, 12, inner, 14, C.secondary, 11)
        local income = text("Income", result, "--", 14, 28, inner, 32, C.accentText, 24, true)
        local exact = paragraph("Exact", result, "", 14, 62, inner, 36, C.secondary, 10)
        make("Frame", "ResultDivider", result, { Position = UDim2.fromOffset(14, 102), Size = UDim2.fromOffset(inner, 1),
            BackgroundColor3 = C.separator, BackgroundTransparency = 0.5, BorderSizePixel = 0 })
        local rows = {}
        for index, label in ipairs({"Por minuto", "Por hora", "Por día", "Multiplicador", "Tamaño", "Sin mutaciones"}) do
            local y = 110 + (index - 1) * 26
            text("Label" .. index, result, label, 14, y, 92, 24, C.secondary, 11)
            rows[index] = text("Value" .. index, result, "--", 106, y, inner - 92, 24, C.text, 12, "semi")
            rows[index].TextXAlignment = Enum.TextXAlignment.Right
        end
        local message = paragraph("Message", result, "", 14, 274, inner, 64, C.secondary, 11)
        local chips, bonuses = {}, {}
        local function update()
            access()
            local selected = {}
            for _, id in ipairs(calc.mutations) do selected[id] = true end
            for id, chip in pairs(chips) do
                local on = selected[id] == true
                paint(chip, on and C.selection or C.control, on and C.accentText or C.text, on and C.accent or C.separator)
            end
            for _, value in ipairs(rows) do value.Text = "--" end
            income.Text = "--"; exact.Text = ""
            if not calc.category then message.Text = "Elige una especie para empezar."; message.TextColor3 = C.secondary; return end
            if string.gsub(weight.Text, "%s", "") == "" then message.Text = "Escribe el peso en kg (el que muestra el huevo o la mascota)."; message.TextColor3 = C.secondary; return end
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
            message.TextColor3 = C.secondary
        end
        -- Bono de cada mutacion para la especie elegida, medido con el juego una
        -- vez por especie: volver a la seccion no repite el calculo.
        local bonusKey = calc.category and data.mutations and calc.category
        if bonusKey and bonusCache[bonusKey] then bonuses = bonusCache[bonusKey]
        elseif bonusKey then
            local okBase, base = pcall(search.IncomeAt, calc.category, 1, {})
            if okBase and base > 0 then
                for id in pairs(data.mutations.IdSet) do
                    local ok, value = pcall(search.IncomeAt, calc.category, 1, {id})
                    if ok then bonuses[id] = value / base - 1 end
                end
                bonusCache[bonusKey] = bonuses
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
            paragraph("Loading", grid, "Cargando las mutaciones del juego...", 4, 8, left - 20, 30, C.secondary, 12)
        end
        species.Activated:Connect(function() access(); speciesPicker(species) end)
        clear.Activated:Connect(function() access(); table.clear(calc.mutations); save(); update() end)
        weight:GetPropertyChangedSignal("Text"):Connect(function() access(); calc.weight = weight.Text; update() end)
        weight.FocusLost:Connect(function() access(); save() end)
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
    -- El runtime avisa al cambiar AUTO desde Server Hop o la tarjeta flotante.
    function panel.SyncAuto(active) if panel.alive then paintControls(active) end end
    panel.ui = { colors = C, content = CONTENT, pageHeight = PAGE_H, column = third, make = make, corner = corner,
        stroke = stroke, text = text, paragraph = paragraph, button = button, field = field, primary = primary,
        paint = paint, heading = heading, toggleRow = toggleRow, face = look.face, halo = look.halo, focusRing = look.ring }
    -- Cambio de tema: los colores ya cambiaron de token en su sitio; aqui se
    -- repinta lo que depende del estado y se reconstruye lo que mezcla colores
    -- calculados (rareza en las tarjetas, hojas abiertas, pagina actual).
    look.listener = {
        before = function()
            -- Un color en transito acabaria en el del tema anterior.
            for _, slot in pairs(motion.tweens) do
                for key, tween in pairs(slot) do
                    if key == "BackgroundColor3" or key == "TextColor3" or key == "Color" then tween:Cancel(); slot[key] = nil end
                end
            end
        end,
        after = function()
            access(); root.BackgroundTransparency = THEME.alpha.window
            closePopup(true); cleanupCards(); signature = nil
            paintTabs(); paintControls()
            if renderers[tab] then renderers[tab]() end
            refreshSoon()
        end,
        preference = function()
            access(); save()
            if tab == "settings" then renderSettings() end
        end,
    }
    table.insert(THEME.listeners, look.listener)
    function panel.GetStatus()
        access(); return { open = panel.open, minimized = minimized, tab = tab, view = "map", onlyMatches = onlyMatches,
            cards = panel.cards, matches = panel.matches, dirty = dirty, error = panel.error,
            selected = selectionList(), allZones = allZones, visual = visual, sortBest = sortBest, position = {x = root.AbsolutePosition.X, y = root.AbsolutePosition.Y},
            size = {x = root.AbsoluteSize.X, y = root.AbsoluteSize.Y}, scale = motion.base or scale.Scale, userScale = userScale,
            theme = THEME.name, themePreference = THEME.preference,
            stats = table.clone(panel.stats), resources = {mutations = data.mutations ~= nil, models = data.assetModels ~= nil} }
    end
    function panel.Destroy()
        if not panel.alive then return end
        access(); panel.alive = false
        if motion.spring then motion.spring:Disconnect(); motion.spring = nil end
        for _, c in ipairs(connections) do c:Disconnect() end
        table.clear(connections)
        for object in pairs(motion.tweens) do motion.stop(object) end
        cleanupCards(); mini.button:Destroy(); root:Destroy()
        local slot = table.find(THEME.listeners, look.listener)
        if slot then table.remove(THEME.listeners, slot) end
        slot = table.find(THEME.roots, look.ring)
        if slot then table.remove(THEME.roots, slot) end
        look.ring:Destroy()
    end
    connect(auto.Activated, function()
        panel.autoTouched = true
        if api.GetStatus().active then api.Stop()
        elseif not dirty or panel.Apply() then api.Start() end
        paintControls(api.GetStatus().active)
    end)
    connect(minimize.Activated, function() panel.SetMinimized(not minimized) end)
    -- Un toque abre; si el dedo recorrio mas de 10 px fue un arrastre.
    connect(mini.button.Activated, function()
        if minimized and (motion.dragTravel or 0) < 10 then panel.SetMinimized(false) end
    end)
    -- El borde se ilumina al pulsar (al instante) y al pasar el raton.
    connect(mini.button:GetPropertyChangedSignal("GuiState"), function()
        if not panel.alive or not minimized then return end
        access()
        local state = mini.button.GuiState
        local goal = { Color = (state == Enum.GuiState.Press or (state == Enum.GuiState.Hover and UIS.MouseEnabled)) and C.accent or C.separator }
        if state == Enum.GuiState.Press then place(mini.button.Border, goal) else animate(mini.button.Border, MOTION.color, goal) end
    end)
    for id, entry in pairs(tabButtons) do
        connect(entry.button.Activated, function() panel.Select(id) end)
        connect(entry.button:GetPropertyChangedSignal("GuiState"), function() paintTab(id) end)
    end
    -- Las preferencias de accesibilidad pueden cambiar con el hub abierto.
    pcall(function()
        local GuiService = game:GetService("GuiService")
        connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), motion.readPreferences)
        connect(GuiService:GetPropertyChangedSignal("PreferredTransparency"), function()
            motion.readPreferences(); motion.restyleScrim()
        end)
    end)
    connect(editFilters.Activated, function() panel.Select("filters") end)
    -- Alt izquierdo hace lo mismo que minimizar y tocar el boton M: el hub se
    -- va y queda el boton; con el boton, el hub vuelve a su sitio. Oculto
    -- (Close), lo abre.
    connect(UIS.InputBegan, function(input)
        if input.KeyCode ~= Enum.KeyCode.LeftAlt then return end
        if panel.open then panel.SetMinimized(not minimized) else panel.Open() end
    end)
    connect(apply.Activated, panel.Apply)
    connect(income:GetPropertyChangedSignal("Text"), function()
        local minimum = search.ParseMinimum(income.Text)
        access()
        if minimum ~= draft.minIncome then markDirty() end
    end)
    connect(nameBox:GetPropertyChangedSignal("Text"), function()
        if nameBox.Text ~= draft.nameContains then markDirty() end
    end)
    connect(chooseZones.Activated, function() zonePicker(chooseZones) end)
    connect(tabCatalog.Activated, function() panel.SetOnlyMatches(true) end)
    connect(tabMap.Activated, function() panel.SetOnlyMatches(false) end)
    connect(sortButton.Activated, function() panel.SetSortBest(not sortBest) end)
    connect(visualButton.Activated, function() panel.SetVisual(visual == "eggs" and "pets" or visual == "pets" and "models" or "eggs") end)
    connect(rarityButton.Activated, function()
        if not search.modules then setMessage("Cargando las rarezas del juego..."); return end
        local options = search.RarityOptions()
        local rarities = search.modules.rarities and search.modules.rarities.Rarities or {}
        for _, option in ipairs(options) do option.color = rarityColor(rarities[option.id], C.text) end
        dropdown("rarity", options, draft.rarity, function(id) draft.rarity = id; rarityButton.Text = id end, rarityButton)
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
        end, mutationButton)
    end)
    -- Arrastre 1:1 desde el punto de agarre. Fuera de la pantalla resiste cada
    -- vez mas y, al soltar, un resorte sin rebote lo devuelve desde donde esta
    -- con la velocidad del dedo. Agarrarlo en vuelo lo detiene ahi.
    function motion.stopSpring() if motion.spring then motion.spring:Disconnect(); motion.spring = nil end end
    do
    local dragInput, dragStart, original, dragSample, dragVelocity
    local stopSpring = motion.stopSpring
    -- Limites de la esquina superior izquierda de lo que se arrastra.
    local function limits(viewport)
        if motion.dragObject == root then return bounds(viewport) end
        return Vector2.new(8, 8), Vector2.new(math.max(8, viewport.X - LAUNCHER - 8), math.max(8, viewport.Y - LAUNCHER - 8))
    end
    local function settle(velocity)
        stopSpring()
        local camera = workspace.CurrentCamera
        if not camera then save(); return end
        local object = motion.dragObject
        local low, high = limits(camera.ViewportSize)
        local position = Vector2.new(object.Position.X.Offset, object.Position.Y.Offset)
        local target = Vector2.new(math.clamp(position.X, low.X, high.X), math.clamp(position.Y, low.Y, high.Y))
        if position == target then save(); return end
        if motion.reduced then object.Position = UDim2.fromOffset(target.X, target.Y); save(); return end
        local speed = velocity or Vector2.zero
        if speed.Magnitude > 3000 then speed = speed.Unit * 3000 end
        motion.spring = game:GetService("RunService").RenderStepped:Connect(function(dt)
            if not panel.alive or not session.alive then stopSpring(); return end
            access()
            dt = math.min(dt, 1 / 20)
            local x, vx = scaling.Spring(position.X, speed.X, target.X, dt, 0.3)
            local y, vy = scaling.Spring(position.Y, speed.Y, target.Y, dt, 0.3)
            position, speed = Vector2.new(x, y), Vector2.new(vx, vy)
            if (position - target).Magnitude < 0.5 and speed.Magnitude < 5 then
                stopSpring(); object.Position = UDim2.fromOffset(target.X, target.Y); save(); return
            end
            object.Position = UDim2.fromOffset(position.X, position.Y)
        end)
    end
    -- La cabecera arrastra el hub (no mientras se va); el boton M, a si mismo.
    local function beginDrag(object, input)
        if dragInput or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
        if object == root and not motion.shown then return end
        stopSpring(); place(object, { Position = object.Position })
        if object == root then motion.rest = nil end
        motion.dragging, motion.dragObject, dragInput, dragStart, original = true, object, input, input.Position, object.Position
        dragSample, dragVelocity, motion.dragTravel = nil, Vector2.zero, 0
    end
    connect(header.InputBegan, function(input) beginDrag(root, input) end)
    connect(mini.button.InputBegan, function(input) beginDrag(mini.button, input) end)
    connect(UIS.InputChanged, function(input)
        if not motion.dragging then return end
        if dragInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= dragInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local low, high = limits(viewport)
        local delta = input.Position - dragStart
        motion.dragTravel = math.max(motion.dragTravel or 0, Vector2.new(delta.X, delta.Y).Magnitude)
        local x = scaling.Rubberband(original.X.Offset + delta.X, low.X, high.X, viewport.X)
        local y = scaling.Rubberband(original.Y.Offset + delta.Y, low.Y, high.Y, viewport.Y)
        local now, point = os.clock(), Vector2.new(x, y)
        if dragSample and now > dragSample.at then
            dragVelocity = dragVelocity:Lerp((point - dragSample.point) / (now - dragSample.at), 0.5)
        end
        dragSample = { at = now, point = point }
        motion.dragObject.Position = UDim2.fromOffset(x, y)
    end)
    local function finishDrag()
        if not motion.dragging then return end
        motion.dragging, dragInput = false, nil
        -- Si el dedo se detuvo antes de soltar, no hay impulso que heredar.
        local velocity = dragSample and os.clock() - dragSample.at < 0.06 and dragVelocity or Vector2.zero
        settle(velocity)
    end
    connect(UIS.InputEnded, function(input)
        if motion.dragging and (input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1)) then finishDrag() end
    end)
    connect(UIS.WindowFocusReleased, finishDrag)
    end
    -- Asa de tamano: tres trazos diagonales dentro de la esquina redondeada.
    -- Escala todo el hub con la esquina superior izquierda fija; las hojas
    -- modales (ZIndex 50) la cubren mientras estan abiertas.
    do
    local grip = make("TextButton", "ResizeGrip", root, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5 })
    local gripTraces = {}
    for index, trace in ipairs({ {11, 5}, {16, 11}, {21, 17} }) do -- distancia a la esquina, largo
        local mark = line(grip, "Trace" .. index, 0, 0, trace[2], -45, C.tertiary, 5)
        mark.Position = UDim2.new(1, -trace[1] / 2, 1, -trace[1] / 2); mark.BackgroundTransparency = 0.4
        gripTraces[index] = mark
    end
    local gripHover, resizeInput, resizeStart, resizeScale = false, nil, nil, nil
    local function paintGrip()
        access()
        local active = gripHover or resizeInput ~= nil
        for _, mark in ipairs(gripTraces) do
            animate(mark, MOTION.color, { BackgroundColor3 = active and C.accent or C.tertiary, BackgroundTransparency = active and 0 or 0.4 })
        end
    end
    connect(grip.MouseEnter, function() gripHover = true; paintGrip() end)
    connect(grip.MouseLeave, function() gripHover = false; paintGrip() end)
    connect(grip.InputBegan, function(input)
        if resizeInput or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
        motion.dragging = false; motion.stopSpring()
        resizeInput, resizeStart, resizeScale = input, input.Position, motion.base or scale.Scale
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
    end
    for key, page in pairs(pages) do page.Visible = key == tab end
    paintTabs(); applyMinimized(); fit(); setDraft(search.config); paintControls()
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
            paintControls(status.active)
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
            stateTitle.TextColor3 = (status.mode == "match" or captured) and C.green or C.text
            stateDot.BackgroundColor3 = (status.mode == "match" or captured) and C.greenDot or status.mode == "hop" and C.orangeDot
                or status.active and C.accent or C.tertiary
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
