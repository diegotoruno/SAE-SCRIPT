-- Formulario Cuenta / Best Ping. La cookie pasa del campo al pool en una sola
-- llamada; nunca se expone en GetStatus, logs, Chilli, el estado del teleport
-- ni en las solicitudes al companion.
local function mountAccountPanel(context)
    local session, screenGui, support, COLORS = context.session, context.screenGui, context.support, context.colors
    local connect, uiAccess, pool, api = context.connect, context.uiAccess, context.pool, context.api
    local setAuto = context.setAuto
    local surface = Color3.fromRGB(20, 24, 30)
    local fieldColor = Color3.fromRGB(30, 36, 44)
    local foreground = Color3.fromRGB(239, 243, 247)
    local secondary = Color3.fromRGB(170, 183, 197)
    local accent = Color3.fromRGB(224, 197, 149)
    local function rounded(object)
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = object
    end
    local function text(parentObject, name, content, y, height, size, color)
        local item = Instance.new("TextLabel")
        item.Name = name; item.BackgroundTransparency = 1; item.Text = content
        item.Position = UDim2.fromOffset(20, y); item.Size = UDim2.new(1, -40, 0, height)
        item.Font = Enum.Font.GothamMedium; item.TextSize = size; item.TextColor3 = color or foreground
        item.TextXAlignment = Enum.TextXAlignment.Left; item.TextYAlignment = Enum.TextYAlignment.Top
        item.TextWrapped = true; item.Parent = parentObject
        return item
    end
    local function action(parentObject, name, content, y, color)
        local item = Instance.new("TextButton")
        item.Name = name; item.Text = content; item.Position = UDim2.fromOffset(20, y)
        item.Size = UDim2.new(1, -40, 0, 44); item.BackgroundColor3 = color or fieldColor
        item.BorderSizePixel = 0; item.Font = Enum.Font.GothamBold; item.TextSize = 14
        item.TextColor3 = color and surface or foreground; item.Parent = parentObject; rounded(item)
        return item
    end
    local function outlined(object)
        local stroke = Instance.new("UIStroke"); stroke.Color = COLORS.border
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = object
    end
    local entry = action(screenGui, "ServerAccount", "Cuenta y Best Ping", 0)
    entry.AnchorPoint = Vector2.new(0, 1); entry.BackgroundColor3 = surface; entry.TextSize = 12
    entry.Position = UDim2.new(0, 18, 1, -18); entry.Size = UDim2.fromOffset(184, 36); entry.ZIndex = 90
    outlined(entry)
    local panel = Instance.new("Frame")
    panel.Name = "ServerAccountPanel"; panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5); panel.Size = UDim2.fromOffset(440, 462)
    panel.BackgroundColor3 = surface; panel.BorderSizePixel = 0; panel.Visible = false
    panel.ZIndex = 30; panel.Parent = screenGui; rounded(panel); outlined(panel)
    local scale = Instance.new("UIScale"); scale.Parent = panel
    text(panel, "Title", "Tu cuenta para Best Ping", 20, 30, 22)
    text(panel, "Privacy", "Este dispositivo consulta Roblox. El autor del script no recibe tu cookie.", 58, 40, 13, secondary)
    text(panel, "CookieLabel", ".ROBLOSECURITY", 112, 20, 13)
    local input = Instance.new("TextBox")
    input.Name = "CookieInput"; input.Position = UDim2.fromOffset(20, 138)
    input.Size = UDim2.new(1, -40, 0, 48); input.BackgroundColor3 = fieldColor
    input.BorderSizePixel = 0; input.Text = ""; input.PlaceholderText = ""
    input.ClearTextOnFocus = false; input.MultiLine = false; input.TextTransparency = 1
    input.TextSize = 16; input.Font = Enum.Font.GothamMedium; input.Parent = panel; rounded(input)
    local mask = text(input, "MaskedValue", "Toca aqui y pega la cookie completa", 14, 24, 13, secondary)
    mask.Position = UDim2.fromOffset(14, 14); mask.Size = UDim2.new(1, -28, 0, 24)
    text(panel, "StorageHelp", "Guardar permite continuar entre saltos. Se guarda solo aqui, sin cifrado; otros scripts del executor podrian leerla.", 198, 54, 13, secondary)
    local message = text(panel, "ConnectionMessage", "", 258, 40, 13, secondary)
    local save = action(panel, "SaveAndAuto", "Guardar y usar AUTO", 304, accent)
    local once = action(panel, "SessionOnly", "Solo esta sesion", 356)
    local forget = action(panel, "ForgetCookie", "Borrar cookie y desconectar", 408)
    local close = Instance.new("TextButton")
    close.Name = "Close"; close.Text = "Cerrar"; close.Font = Enum.Font.GothamMedium
    close.TextSize = 12; close.TextColor3 = secondary; close.BackgroundTransparency = 1
    close.Size = UDim2.fromOffset(64, 44); close.Position = UDim2.new(1, -74, 0, 5); close.Parent = panel
    local draft, updating, connecting = nil, false, false
    local function savedMessage(state)
        return state.remembered and "Cookie guardada en este dispositivo. Puedes cerrar esta ventana."
            or "Cookie activa solo en esta sesion; no se guardo."
    end
    local function updateEntry()
        uiAccess()
        local state = pool.CredentialStatus()
        entry.Text = connecting and "Cuenta: comprobando"
            or state.configured and (state.remembered and "Cuenta: guardada" or "Cuenta: solo esta sesión")
            or "Cuenta y Best Ping"
    end
    local function fit()
        uiAccess()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
        scale.Scale = math.min(1, (viewport.X - 32) / 440, (viewport.Y - 40) / 462)
    end
    local function show()
        if not session.alive then return end
        uiAccess(); fit(); panel.Visible = true; entry.Visible = false
        local state = pool.CredentialStatus()
        message.Text = connecting and support.DeviceWaitMessage(pool.TransportState())
            or state.configured and savedMessage(state)
            or "Pega tu cookie para conectar tu propia cuenta."
    end
    local function hide()
        uiAccess(); input:ReleaseFocus(); panel.Visible = false; entry.Visible = true; input.Text = ""; draft = nil
        mask.Text = "Toca aqui y pega la cookie completa"
    end
    connect(entry.Activated, show)
    connect(close.Activated, hide)
    connect(input:GetPropertyChangedSignal("Text"), function()
        if updating or input.Text == "" then return end
        draft = support.NormalizeCookie(input.Text)
        updating = true; input.Text = ""; updating = false
        mask.Text = draft and "Cookie recibida (oculta)" or "Pega solo la cookie completa"
    end)
    local camera = workspace.CurrentCamera
    if camera then connect(camera:GetPropertyChangedSignal("ViewportSize"), fit) end
    local function activate(persist)
        if connecting then return end
        if not draft then message.Text = "Pega la cookie completa antes de conectar."; return end
        if not pool.ExecutorRequest() then message.Text = "Este executor no ofrece request con headers."; return end
        local candidate = draft; draft = nil
        input:ReleaseFocus(); mask.Text = "Cookie recibida (oculta)"
        connecting = true; session.accountConnecting = true; save.Active = false; once.Active = false
        save.Text = "Comprobando con Roblox..."; once.Text = "Espera la comprobacion..."; updateEntry()
        setAuto(false); uiAccess(); message.Text = "Comprobando la conexion con Roblox..."
        task.spawn(function()
            local generation = pool.Generation()
            local page, reason, status
            for attempt = 1, 2 do
                page, reason, status = pool.Verify(candidate, function(state)
                    if not session.alive or generation ~= pool.Generation() then return end
                    uiAccess(); message.Text = support.DeviceWaitMessage(state)
                end)
                if status ~= 429 or attempt == 2 then break end
            end
            if not session.alive or generation ~= pool.Generation() then candidate = nil; return end
            local ok = false
            if page then
                uiAccess(); message.Text = persist and "Guardando y verificando el archivo local..." or "Activando solo en esta sesion..."
                ok, reason = pool.Remember(candidate, persist)
            end
            -- Retain a failed attempt only while the form stays open,
            -- so an interval or cooldown never requires another paste.
            uiAccess()
            if not ok and panel.Visible then draft = draft or candidate end
            candidate = nil; connecting = false; session.accountConnecting = false
            uiAccess(); save.Active = true; once.Active = true
            save.Text = "Guardar y usar AUTO"; once.Text = "Solo esta sesion"; updateEntry()
            if ok then
                pool.Connected(page)
                -- Confirm verified storage before starting AUTO, which may
                -- change the map status or begin a later hop independently.
                draft = nil; input.Text = ""; mask.Text = "Toca aqui para cambiar la cookie"
                message.Text = savedMessage(pool.CredentialStatus())
                pool.MarkConnected(); setAuto(true)
            else
                message.Text = reason or "No se pudo conectar. Pega la cookie y reintenta."
                mask.Text = draft and "Cookie recibida (oculta); puedes reintentar" or "Toca aqui y pega la cookie completa"
            end
        end)
    end
    connect(save.Activated, function() activate(true) end)
    connect(once.Activated, function() activate(false) end)
    connect(forget.Activated, function()
        pool.CancelCredential(); draft = nil; connecting = false; session.accountConnecting = false; setAuto(false)
        local removed = pool.Forget()
        uiAccess(); input.Text = ""; mask.Text = "Toca aqui y pega la cookie completa"
        save.Active = true; once.Active = true
        save.Text = "Guardar y usar AUTO"; once.Text = "Solo esta sesion"; updateEntry()
        message.Text = removed and "Cookie borrada. AUTO apagado." or "AUTO apagado. No se pudo borrar el archivo local; revisa el executor."
    end)
    api.OpenServerAccount = show
    api.CloseServerAccount = hide
    api.ServerAccountStatus = function()
        uiAccess()
        local state = pool.CredentialStatus()
        return {open = panel.Visible, launcherVisible = entry.Visible, configured = state.configured, remembered = state.remembered,
            connecting = connecting, message = message.Text}
    end
    session.DisposeAccount = function() draft = nil; session.accountConnecting = false end
    fit(); updateEntry()
    local connectionConfig = pool.Connection()
    if connectionConfig.transport ~= "LocalBridge" and not pool.CredentialStatus().configured
        and connectionConfig.mode ~= "BestLatency" then show()
    elseif connectionConfig.transport == "DeviceCookie" and not pool.CredentialStatus().configured then show() end
end
return mountAccountPanel
