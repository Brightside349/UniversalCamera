-- Universal Camera Pro v9 - extras
-- Gamepad, escenas, keyframes, tema compacto, eventos y timelapse.
local UCam = _G.UCam

UCam.Events = UCam.Events or {}
function UCam.on(eventName, callback)
    if type(callback) ~= "function" then return function() end end
    UCam.Events[eventName] = UCam.Events[eventName] or {}
    table.insert(UCam.Events[eventName], callback)
    return function()
        for i = #UCam.Events[eventName], 1, -1 do
            if UCam.Events[eventName][i] == callback then
                table.remove(UCam.Events[eventName], i)
                break
            end
        end
    end
end

function UCam.emit(eventName, payload)
    for _, callback in ipairs(UCam.Events[eventName] or {}) do
        task.defer(function() pcall(callback, payload, UCam) end)
    end
end

-- Gamepad: stick izquierdo mueve y stick derecho rota la cámara.
UCam.Gamepad = { Enabled = false, MoveSpeed = 1, LookSpeed = 2.5, FOVSpeed = 35 }
local function updateGamepad(dt)
    if not UCam.Gamepad.Enabled or not UCam.freeCamEnabled then return end
    local ok, state = pcall(function()
        return UCam.UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
    end)
    if not ok or not state then return end
    local move, look, lt, rt = Vector2.zero, Vector2.zero, 0, 0
    for _, input in ipairs(state) do
        if input.KeyCode == Enum.KeyCode.Thumbstick1 then move = input.Position end
        if input.KeyCode == Enum.KeyCode.Thumbstick2 then look = input.Position end
        if input.KeyCode == Enum.KeyCode.ButtonL2 then lt = input.Position.Z end
        if input.KeyCode == Enum.KeyCode.ButtonR2 then rt = input.Position.Z end
    end
    if not UCam.camCFrame then return end
    local dead = 0.12
    local function dz(v) return math.abs(v) < dead and 0 or v end
    move = Vector2.new(dz(move.X), dz(move.Y))
    look = Vector2.new(dz(look.X), dz(look.Y))
    local cf = UCam.camCFrame
    local velocity = (cf.RightVector * move.X - cf.LookVector * move.Y)
        * UCam.currentSpeed * UCam.Gamepad.MoveSpeed * dt
    UCam.camCFrame = cf + velocity
    UCam.cameraYaw = UCam.cameraYaw - look.X * UCam.Gamepad.LookSpeed * dt
    UCam.cameraPitch = UCam.clamp(
        UCam.cameraPitch - look.Y * UCam.Gamepad.LookSpeed * dt,
        -math.rad(89), math.rad(89)
    )
    UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
    UCam.camera.CFrame = UCam.camCFrame
    if lt > 0.05 or rt > 0.05 then
        UCam.camera.FieldOfView = UCam.clamp(
            UCam.camera.FieldOfView + (lt - rt) * UCam.Gamepad.FOVSpeed * dt,
            UCam.MIN_FOV, UCam.MAX_FOV
        )
    end
end
function UCam.toggleGamepad(enabled)
    UCam.Gamepad.Enabled = enabled and true or false
    UCam.emit("onToggle", { name = "Gamepad", value = UCam.Gamepad.Enabled })
end

-- Escenas: presets rápidos de cámara, filtro e iluminación.
UCam.Scenes = UCam.Scenes or { Slots = {}, MaxSlots = 5 }
UCam.Scenes.MaxSlots = UCam.Scenes.MaxSlots or 5
local function sceneLighting()
    local l = UCam.LightingTweaks
    return {
        ClockTime = l.ClockTime, ExposureCompensation = l.ExposureCompensation,
        FogStart = l.FogStart, FogEnd = l.FogEnd, Brightness = l.Brightness,
        ShadowsEnabled = l.ShadowsEnabled, SkyboxAssetId = l.SkyboxAssetId,
    }
end
function UCam.captureScene(slot)
    slot = UCam.clamp(math.floor(slot or 1), 1, UCam.Scenes.MaxSlots)
    local previous = UCam.Scenes.Slots[slot]
    UCam.Scenes.Slots[slot] = {
        Name = previous and previous.Name or ("Escena " .. slot),
        Description = previous and previous.Description or "",
        FilterIndex = UCam.currentFilterIndex,
        CamMode = UCam.camMode,
        FOV = UCam.camera.FieldOfView,
        Roll = UCam.dutchRoll,
        Letterbox = {
            Enabled = UCam.Letterbox.Enabled,
            HeightRatio = UCam.Letterbox.HeightRatio,
        },
        Bloom = {
            Enabled = UCam.Bloom.Enabled,
            Intensity = UCam.Bloom.Intensity,
            Size = UCam.Bloom.Size,
            Threshold = UCam.Bloom.Threshold,
        },
        DOF = {
            Enabled = UCam.DOF.Enabled,
            FarIntensity = UCam.DOF.FarIntensity,
            FocusDistance = UCam.DOF.FocusDistance,
            InFocusRadius = UCam.DOF.InFocusRadius,
        },
        SunRays = {
            Enabled = UCam.SunRays.Enabled,
            Intensity = UCam.SunRays.Intensity,
            Spread = UCam.SunRays.Spread,
        },
        Vignette = {
            Enabled = UCam.Vignette.Enabled,
            Intensity = UCam.Vignette.Intensity,
            Smoothness = UCam.Vignette.Smoothness,
        },
        Lighting = sceneLighting(),
        SavedAt = os.time(),
    }
    UCam.emit("sceneSaved", { slot = slot })
    if UCam.scheduleSave then UCam.scheduleSave() end
    return true
end
function UCam.applyScene(slot)
    slot = UCam.clamp(math.floor(slot or 1), 1, UCam.Scenes.MaxSlots)
    local scene = UCam.Scenes.Slots[slot]
    if not scene then return false end
    if scene.FilterIndex then UCam.applyFilter(scene.FilterIndex, true) end
    if scene.CamMode and scene.CamMode ~= UCam.camMode then
        if UCam.triggerTransition then UCam.triggerTransition() end
        UCam.camMode = scene.CamMode
    end
    if scene.FOV then UCam.camera.FieldOfView = UCam.clamp(scene.FOV, UCam.MIN_FOV, UCam.MAX_FOV) end
    if scene.Roll ~= nil then UCam.dutchRoll = tonumber(scene.Roll) or 0 end
    if scene.Letterbox then
        UCam.Letterbox.Enabled = scene.Letterbox.Enabled == true
        UCam.Letterbox.HeightRatio = tonumber(scene.Letterbox.HeightRatio) or UCam.Letterbox.HeightRatio
        if UCam.applyLetterbox then pcall(UCam.applyLetterbox) end
    end
    if scene.Bloom then
        for key, value in pairs(scene.Bloom) do UCam.Bloom[key] = value end
        if UCam.applyBloom then pcall(UCam.applyBloom) end
    end
    if scene.DOF then
        for key, value in pairs(scene.DOF) do UCam.DOF[key] = value end
        if UCam.applyDOF then pcall(UCam.applyDOF) end
    end
    if scene.SunRays then
        for key, value in pairs(scene.SunRays) do UCam.SunRays[key] = value end
        if UCam.applySunRays then pcall(UCam.applySunRays) end
    end
    if scene.Vignette then
        for key, value in pairs(scene.Vignette) do UCam.Vignette[key] = value end
        if UCam.applyVignette then pcall(UCam.applyVignette) end
    end
    if scene.Lighting then
        for key, value in pairs(scene.Lighting) do UCam.LightingTweaks[key] = value end
        if UCam.applyLightingTweaks then pcall(UCam.applyLightingTweaks) end
    end
    UCam.emit("sceneApplied", { slot = slot })
    return true
end

-- Exportación de keyframes legible y sin servidor.
function UCam.exportReplayKeyframes()
    local route = UCam.serializeRoute and UCam.serializeRoute() or ""
    if route == "" then return nil, "no hay frames" end
    return "UCAM_KEYFRAMES_V1\n" .. route
end
function UCam.importReplayKeyframes(textValue)
    if type(textValue) ~= "string" then return false, "texto inválido" end
    textValue = textValue:gsub("^UCAM_KEYFRAMES_V1\n?", "")
    local frames = UCam.deserializeRoute(textValue)
    if not frames then return false, "keyframes inválidos" end
    table.clear(UCam.Replay.Frames)
    for i, frame in ipairs(frames) do UCam.Replay.Frames[i] = frame end
    UCam.Replay.CurrentTime = 0
    if UCam.Replay.Markers then table.clear(UCam.Replay.Markers) end
    return true, #frames
end

UCam.UISettings = { Theme = "Dark", Compact = false }
function UCam.applyUISettings()
    local rf = UCam.Rayfield
    if not rf then return end
    pcall(function()
        if rf.SetTheme then rf:SetTheme(UCam.UISettings.Theme) end
        if rf.ChangeTheme then rf:ChangeTheme(UCam.UISettings.Theme) end
    end)
end

-- Timelapse reutiliza el motor de Replay, sin crear otro formato de ruta.
UCam.Timelapse = { Active = false, Interval = 2, Elapsed = 0 }
function UCam.startTimelapse()
    if not UCam.freeCamEnabled then return false, "activa la cámara libre" end
    table.clear(UCam.Replay.Frames)
    UCam.Timelapse.Active, UCam.Timelapse.Elapsed = true, 0
    return true
end
function UCam.stopTimelapse()
    UCam.Timelapse.Active = false
    return #UCam.Replay.Frames
end
function UCam.toggleTimelapse(enabled)
    if enabled then return UCam.startTimelapse() end
    return true, UCam.stopTimelapse()
end
local function updateTimelapse(dt)
    if not UCam.Timelapse.Active or not UCam.freeCamEnabled then return end
    UCam.Timelapse.Elapsed = UCam.Timelapse.Elapsed + dt
    if UCam.Timelapse.Elapsed < UCam.Timelapse.Interval then return end
    UCam.Timelapse.Elapsed = 0
    local previous = UCam.Replay.Frames[#UCam.Replay.Frames]
    local now = #UCam.Replay.Frames * UCam.Timelapse.Interval
    if not previous or (UCam.camera.CFrame.Position - previous.cf.Position).Magnitude > 0.001 then
        table.insert(UCam.Replay.Frames, { cf = UCam.camera.CFrame, fov = UCam.camera.FieldOfView, t = now })
    end
end

UCam.trackConnection(UCam.RunService.RenderStepped:Connect(function(dt)
    updateGamepad(dt)
    updateTimelapse(dt)
end), "v9.extras")
