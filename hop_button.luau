-- Tarjeta del boton Server Hop: AUTO, salto, plegado, estado, firma, arrastre
-- y asa de tamano. Solo dibuja; las decisiones de salto viven en el runtime.
local function mountHopButton(context)
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local session, screenGui, support, COLORS = context.session, context.screenGui, context.support, context.colors
    local connect, uiAccess, readJson, writeJson = context.connect, context.uiAccess, context.readJson, context.writeJson
    local UI_FILE = context.uiFile
    -- Estado de la ventana: si esta plegada y donde la dejaste. Se recuerda
    -- tambien entre saltos, porque vive en un archivo, no en memoria.
    local uiState = readJson(UI_FILE, {})
    local collapsed = (uiState.collapsed == true)
    local EXPANDED_SIZE = Vector2.new(320, 116)
    local COLLAPSED_SIZE = Vector2.new(232, 66)
    local savedPosition = UDim2.new(0.5, 0, 0, 26)
    if type(uiState.pos) == "table" then
        local pos = uiState.pos
        if type(pos.sx) == "number" and type(pos.xo) == "number"
            and type(pos.sy) == "number" and type(pos.yo) == "number" then
            savedPosition = UDim2.new(pos.sx, pos.xo, pos.sy, pos.yo)
        end
    end

    -- Tarjeta grafito: AUTO, accion principal y plegado comparten una fila;
    -- estado y firma tienen filas propias para que ningun texto se encime.
    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.AnchorPoint = Vector2.new(0.5, 0)
    holder.Position = savedPosition
    holder.Size = UDim2.fromOffset(
        collapsed and COLLAPSED_SIZE.X or EXPANDED_SIZE.X,
        collapsed and COLLAPSED_SIZE.Y or EXPANDED_SIZE.Y
    )
    holder.BackgroundColor3 = COLORS.surface
    holder.BorderSizePixel = 0
    holder.Active = true
    holder.Parent = screenGui

    -- Tamano elegido con el asa: escala toda la tarjeta, plegada o no.
    local function fitScaleLimit()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize
        if not viewport or viewport.X <= 0 or viewport.Y <= 0 then return nil end
        return math.min((viewport.X - 16) / EXPANDED_SIZE.X, (viewport.Y - 16) / EXPANDED_SIZE.Y)
    end
    local holderScale = Instance.new("UIScale")
    holderScale.Name = "UserScale"
    holderScale.Scale = support.HopperScale(uiState.scale, fitScaleLimit())
    holderScale.Parent = holder

    local function round(object, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = object
    end
    local function outline(object, color, transparency)
        local stroke = Instance.new("UIStroke")
        stroke.Name = "Border"
        stroke.Color = color
        stroke.Transparency = transparency or 0
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = object
        return stroke
    end
    local function label(name, parent, size, color, bold)
        local item = Instance.new("TextLabel")
        item.Name = name
        item.BackgroundTransparency = 1
        item.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
        item.Text = ""
        item.TextSize = size
        item.TextColor3 = color
        item.TextStrokeTransparency = 1
        item.TextTruncate = Enum.TextTruncate.AtEnd
        item.Parent = parent
        return item
    end
    -- Chevron de dos segmentos: no depende de glifos de la fuente.
    local function chevronSegments(parent)
        local segments = {}
        for index = 1, 2 do
            local segment = Instance.new("Frame")
            segment.Name = "Chevron" .. index
            segment.AnchorPoint = Vector2.new(0.5, 0.5)
            segment.Size = UDim2.fromOffset(7, 1.5)
            segment.BackgroundColor3 = COLORS.muted
            segment.BorderSizePixel = 0
            segment.Position = UDim2.new(0.5, index == 1 and -2.5 or 2.5, 0.5, 0)
            segment.Parent = parent
            segments[index] = segment
        end
        return segments
    end
    round(holder, 14)
    outline(holder, COLORS.border)

    local button = Instance.new("TextButton")
    button.Name = "ServerHop"
    button.AutoButtonColor = true
    button.Text = ""
    button.BackgroundColor3 = COLORS.action
    button.BorderSizePixel = 0
    button.Parent = holder
    round(button, 10)
    outline(button, COLORS.actionBorder, 0.55)

    local mainLabel = label("Label", button, 18, COLORS.text, true)
    mainLabel.Text = "Server Hop"
    mainLabel.Position = UDim2.fromOffset(8, 0)
    mainLabel.Size = UDim2.new(1, -16, 1, 0)

    local statusLabel = label("Status", holder, 11, COLORS.muted)
    statusLabel.Position = UDim2.fromOffset(14, 62)
    statusLabel.Size = UDim2.new(1, -28, 0, 30)
    statusLabel.TextWrapped = true

    -- La firma tiene su propia fila en ambas versiones; no tapa AUTO ni estado.
    local creditLabel = label("ByMistakeCredit", holder, 10, COLORS.gold)
    creditLabel.AnchorPoint = Vector2.new(0.5, 1)
    creditLabel.Position = UDim2.new(0.5, 0, 1, -6)
    creditLabel.Size = UDim2.new(1, -24, 0, 12)
    creditLabel.Text = "By Mistake"
    creditLabel.TextTransparency = 0.25
    creditLabel.Active = false
    creditLabel.Selectable = false

    local function setLabel(text)
        if not session.alive then return end
        uiAccess()
        mainLabel.Text = text
    end

    local function setStatus(text, color)
        if not session.alive then return end
        uiAccess()
        statusLabel.Text = text
        statusLabel.TextColor3 = color or COLORS.muted
    end

    -- The runtime owns the busy flag; the card only dims the action.
    local function setBusy(value)
        if not session.alive then return end
        uiAccess()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundTransparency = value and 0.5 or 0,
        }):Play()
    end

    -- ------------------------------------------------- estado de la ventana
    local DRAG_THRESHOLD = 6

    local dragging = false
    local pendingDrag = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil
    local lastDragAt = -math.huge
    local resizeInput, resizeStart, resizeScale, resizePosition = nil, nil, nil, nil

    local function saveUi()
        uiAccess()
        local state = readJson(UI_FILE, {})
        state.collapsed = collapsed
        state.auto = context.isAuto()
        state.scale = holderScale.Scale
        state.pos = {
            sx = holder.Position.X.Scale,
            xo = holder.Position.X.Offset,
            sy = holder.Position.Y.Scale,
            yo = holder.Position.Y.Offset,
        }
        writeJson(UI_FILE, state)
    end

    local function draggedRecently()
        return dragging or (os.clock() - lastDragAt) < 0.25
    end

    -- Plegar/desplegar, a la derecha del boton principal.
    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.AutoButtonColor = true
    toggle.AnchorPoint = Vector2.new(1, 0)
    toggle.BackgroundColor3 = COLORS.raised
    toggle.BorderSizePixel = 0
    toggle.Text = ""
    toggle.Parent = holder
    round(toggle, 10)
    outline(toggle, COLORS.border, 0.3)
    local toggleChevron = chevronSegments(toggle)

    -- Chip AUTO: enciende/apaga el encadenado automatico. Se guarda en
    -- server_hop_button_ui.json para que siga encendido entre saltos.
    local autoChip = Instance.new("TextButton")
    autoChip.Name = "AutoChip"
    autoChip.AutoButtonColor = false
    autoChip.BackgroundColor3 = COLORS.raised
    autoChip.BorderSizePixel = 0
    autoChip.Text = ""
    autoChip.Parent = holder
    round(autoChip, 10)
    local autoBorder = outline(autoChip, COLORS.border, 0.3)

    local autoLabel = label("AutoLabel", autoChip, 11, COLORS.muted, true)
    autoLabel.Size = UDim2.fromScale(1, 1)
    autoLabel.Text = "AUTO\nOFF"
    autoLabel.TextTruncate = Enum.TextTruncate.None

    local function updateAutoChip()
        uiAccess()
        local autoEnabled = context.isAuto()
        autoLabel.Text = autoEnabled and "AUTO\nON" or "AUTO\nOFF"
        autoChip.BackgroundColor3 = autoEnabled and COLORS.green or COLORS.raised
        autoLabel.TextColor3 = autoEnabled and COLORS.onGreen or COLORS.muted
        autoBorder.Color = autoEnabled and COLORS.green or COLORS.border
    end

    local function applyCollapsed(value, instant)
        collapsed = value
        local size = value and COLLAPSED_SIZE or EXPANDED_SIZE
        local pad = value and 8 or 10
        local row = value and 34 or 44
        local chip = value and 52 or 60
        local side = value and 28 or 32
        local tween = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local function place(object, properties)
            if instant then
                for key, target in pairs(properties) do object[key] = target end
            else
                TweenService:Create(object, tween, properties):Play()
            end
        end

        place(holder, { Size = UDim2.fromOffset(size.X, size.Y) })
        place(autoChip, { Position = UDim2.fromOffset(pad, pad), Size = UDim2.fromOffset(chip, row) })
        place(button, { Position = UDim2.fromOffset(pad + chip + 6, pad),
            Size = UDim2.new(1, -(2 * pad + chip + side + 12), 0, row) })
        place(toggle, { Position = UDim2.new(1, -pad, 0, pad), Size = UDim2.fromOffset(side, row) })
        mainLabel.TextSize = value and 14 or 18
        autoLabel.TextSize = value and 10 or 11
        statusLabel.Visible = not value
        -- Desplegado muestra "plegar" (chevron arriba); plegado, "desplegar".
        toggleChevron[1].Rotation = value and 45 or -45
        toggleChevron[2].Rotation = value and -45 or 45
    end

    -- Los eventos del marco no reciben necesariamente los de sus controles.
    -- Registrar toda la tarjeta, incluidos texto, AUTO y plegado.
    local function beginDrag(input)
        if pendingDrag or resizeInput then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            pendingDrag = true
            dragging = false
            dragInput = input
            dragStart = input.Position
            startPosition = holder.Position
        end
    end

    connect(holder.InputBegan, beginDrag)
    for _, surface in ipairs(holder:GetDescendants()) do
        if surface:IsA("GuiObject") then
            connect(surface.InputBegan, beginDrag)
        end
    end

    connect(UserInputService.InputChanged, function(input)
        if not pendingDrag or not dragStart then
            return
        end
        if dragInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= dragInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - dragStart
        if not dragging and delta.Magnitude < DRAG_THRESHOLD then
            return
        end

        dragging = true
        lastDragAt = os.clock()
        holder.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)

    local function finishDrag()
        if dragging then
            -- Tambien cubrir un arrastre que se mantuvo quieto antes de soltar.
            lastDragAt = os.clock()
            saveUi()
        end
        pendingDrag = false
        dragging = false
        dragInput, dragStart, startPosition = nil, nil, nil
    end

    connect(UserInputService.InputEnded, function(input)
        if not dragInput then return end
        if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1) then
            finishDrag()
        end
    end)
    connect(UserInputService.WindowFocusReleased, finishDrag)

    -- Asa de tamano en la esquina inferior derecha: tres trazos diagonales
    -- dentro del borde redondeado. Se crea despues de registrar el arrastre de
    -- la tarjeta, asi que tirar de ella redimensiona sin mover.
    local GRIP_TRACES = { {11, 5}, {16, 11}, {21, 17} } -- distancia a la esquina, largo
    local grip = Instance.new("TextButton")
    grip.Name = "ResizeGrip"
    grip.AutoButtonColor = false
    grip.AnchorPoint = Vector2.new(1, 1)
    grip.Position = UDim2.fromScale(1, 1)
    grip.Size = UDim2.fromOffset(24, 24)
    grip.BackgroundTransparency = 1
    grip.Text = ""
    grip.ZIndex = 3
    grip.Parent = holder
    local gripTraces = {}
    for index, trace in ipairs(GRIP_TRACES) do
        local line = Instance.new("Frame")
        line.Name = "Trace" .. index
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.new(1, -trace[1] / 2, 1, -trace[1] / 2)
        line.Size = UDim2.fromOffset(trace[2], 1.5)
        line.Rotation = -45
        line.BackgroundColor3 = COLORS.muted
        line.BackgroundTransparency = 0.4
        line.BorderSizePixel = 0
        line.ZIndex = 3
        line.Parent = grip
        gripTraces[index] = line
    end

    local gripHover = false
    local function paintGrip()
        uiAccess()
        local active = gripHover or resizeInput ~= nil
        local tween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, line in ipairs(gripTraces) do
            TweenService:Create(line, tween, {
                BackgroundColor3 = active and COLORS.gold or COLORS.muted,
                BackgroundTransparency = active and 0 or 0.4,
            }):Play()
        end
    end
    connect(grip.MouseEnter, function() gripHover = true; paintGrip() end)
    connect(grip.MouseLeave, function() gripHover = false; paintGrip() end)

    connect(grip.InputBegan, function(input)
        if resizeInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        -- El marco puede recibir el mismo toque: el asa nunca mueve la tarjeta.
        pendingDrag, dragging = false, false
        dragInput, dragStart, startPosition = nil, nil, nil
        resizeInput, resizeStart = input, input.Position
        resizeScale, resizePosition = holderScale.Scale, holder.Position
        paintGrip()
    end)

    connect(UserInputService.InputChanged, function(input)
        if not resizeInput then return end
        if resizeInput.UserInputType == Enum.UserInputType.Touch then
            if input ~= resizeInput then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local base = collapsed and COLLAPSED_SIZE or EXPANDED_SIZE
        local scale = support.ResizeHopperScale(resizeScale, base, input.Position - resizeStart, fitScaleLimit())
        holderScale.Scale = scale
        -- AnchorPoint centra la tarjeta en X: compensar para fijar el borde izquierdo.
        holder.Position = UDim2.new(
            resizePosition.X.Scale,
            resizePosition.X.Offset + base.X * (scale - resizeScale) / 2,
            resizePosition.Y.Scale,
            resizePosition.Y.Offset
        )
    end)

    local function finishResize()
        if not resizeInput then return end
        resizeInput, resizeStart, resizeScale, resizePosition = nil, nil, nil, nil
        lastDragAt = os.clock()
        paintGrip()
        saveUi()
    end

    connect(UserInputService.InputEnded, function(input)
        if not resizeInput then return end
        if input == resizeInput or (resizeInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1) then
            finishResize()
        end
    end)
    connect(UserInputService.WindowFocusReleased, finishResize)

    connect(toggle.MouseButton1Click, function()
        if draggedRecently() then
            return
        end
        applyCollapsed(not collapsed)
        saveUi()
    end)

    applyCollapsed(collapsed, true)

    return {
        button = button, autoChip = autoChip, savedAuto = uiState.auto == true,
        SetLabel = setLabel, SetStatus = setStatus, SetBusy = setBusy,
        PaintAuto = updateAutoChip, Save = saveUi, DraggedRecently = draggedRecently,
    }
end
return mountHopButton
