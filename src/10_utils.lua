-- ============================================================
-- Universal Camera Pro v6 · 10_utils
-- Utilidades de camara, personaje y visualizador de path.
--
-- Dependencias: 00_config
-- Expone (UCam.*):
--   refreshCharacterRefs, disableControls, enableControls,
--   disableCharacterCollision, restoreCharacterCollision,
--   freezeCharacter, unfreezeCharacter, holdCharacterPosition,
--   isDescendantOf, clamp, getEasingFn,
--   syncFreeLookFromCFrame, buildFreeCameraCFrame,
--   applyCameraRotation, getKeyboardDirection, moveCamera,
--   clearPathVisualizer, drawPathVisualizer,
--   destroyGreenScreen, getActiveSpawnPositions,
--   pickClearDirection, updateGreenScreen, applyLightingTweaks
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- REFRESCAR REFERENCIAS AL PERSONAJE
-- ============================================================
function UCam.refreshCharacterRefs()
    UCam.character = UCam.player.Character
    if UCam.character then
        UCam.humanoid = UCam.character:FindFirstChildOfClass("Humanoid")
        UCam.rootPart = UCam.character:FindFirstChild("HumanoidRootPart")
    else
        UCam.humanoid = nil
        UCam.rootPart = nil
    end
end
UCam.refreshCharacterRefs()

-- ============================================================
-- CONTROLES DEL PERSONAJE
-- ============================================================
function UCam.disableControls()
    if UCam.controls then
        pcall(function() UCam.controls:Disable() end)
    end
    if UCam.character then
        for _, s in ipairs(UCam.character:GetDescendants()) do
            if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
                s.Disabled = true
            end
        end
    end
end

function UCam.enableControls()
    if UCam.controls then
        pcall(function() UCam.controls:Enable() end)
    end
    if UCam.character then
        for _, s in ipairs(UCam.character:GetDescendants()) do
            if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
                s.Disabled = false
            end
        end
    end
end

-- ============================================================
-- COLISIONES
-- ============================================================
function UCam.disableCharacterCollision()
    table.clear(UCam.Saved.Collide)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if part:IsA("BasePart") then
            UCam.Saved.Collide[part] = part.CanCollide
            part.CanCollide = false
        end
    end
end

function UCam.restoreCharacterCollision()
    for part, state in pairs(UCam.Saved.Collide) do
        if part and part.Parent then
            part.CanCollide = state
        end
    end
    table.clear(UCam.Saved.Collide)
end

-- ============================================================
-- CONGELAR / DESCONGELAR PERSONAJE
-- ============================================================
local function zeroRootMotion()
    if not UCam.rootPart then return end
    pcall(function()
        UCam.rootPart.AssemblyLinearVelocity  = Vector3.zero
        UCam.rootPart.AssemblyAngularVelocity = Vector3.zero
    end)
end

function UCam.freezeCharacter()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.humanoid then return end
    UCam.Saved.RootAnchored  = UCam.rootPart.Anchored
    UCam.Saved.AutoRotate    = UCam.humanoid.AutoRotate
    UCam.Saved.RootCFrame    = UCam.rootPart.CFrame
    UCam.rootPart.Anchored   = true
    UCam.humanoid.AutoRotate = false
    zeroRootMotion()
    UCam.disableCharacterCollision()
    UCam.disableControls()
end

function UCam.unfreezeCharacter()
    UCam.refreshCharacterRefs()
    if UCam.rootPart then
        if UCam.Saved.RootCFrame then
            pcall(function() UCam.rootPart.CFrame = UCam.Saved.RootCFrame end)
        end
        zeroRootMotion()
        UCam.rootPart.Anchored = UCam.Saved.RootAnchored
    end
    if UCam.humanoid then
        UCam.humanoid.AutoRotate = UCam.Saved.AutoRotate
    end
    UCam.restoreCharacterCollision()
    task.delay(0.05, function() UCam.enableControls() end)
    UCam.Saved.RootCFrame   = nil
    UCam.Saved.RootAnchored = false
    UCam.Saved.AutoRotate   = true
end

function UCam.holdCharacterPosition()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.Saved.RootCFrame then return end
    -- v4.2: no pisar la posición si los efectos de diversion estan
    -- moviendo al personaje (montar sobre jugador, giro, etc.)
    if UCam.Fun.Mount.Enabled or UCam.Fun.BodySpin.Enabled then return end
    pcall(function()
        UCam.rootPart.CFrame = UCam.Saved.RootCFrame
        zeroRootMotion()
    end)
end

-- ============================================================
-- UTILIDADES GENERALES
-- ============================================================
function UCam.isDescendantOf(inst, target)
    if not inst or not target then return false end
    local p = inst.Parent
    while p do
        if p == target then return true end
        p = p.Parent
    end
    return false
end

function UCam.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function UCam.getEasingFn(name)
    if name == "Linear" then
        return function(t) return t end
    elseif name == "Sin" then
        return function(t) return 0.5 - 0.5 * math.cos(t * math.pi) end
    else
        return function(t) return t * t * (3 - 2 * t) end
    end
end

-- ============================================================
-- CAMARA: ROTACION Y MOVIMIENTO
-- ============================================================
function UCam.syncFreeLookFromCFrame(cf)
    local look  = cf.LookVector
    UCam.cameraPitch = UCam.clamp(math.asin(UCam.clamp(look.Y, -1, 1)), math.rad(-89), math.rad(89))
    UCam.cameraYaw   = math.atan2(-look.X, -look.Z)
end

function UCam.buildFreeCameraCFrame(position)
    return CFrame.new(position) * CFrame.fromOrientation(UCam.cameraPitch, UCam.cameraYaw, 0)
end

function UCam.applyCameraRotation(delta)
    local sens = UCam.MOUSE_SENSITIVITY * 0.005
    if UCam.camMode == "Orbita" or UCam.camMode == "Dron" or UCam.camMode == "Cenital" or UCam.camMode == "Vertigo" then
        UCam.Orbit.ManualYaw   = UCam.Orbit.ManualYaw - delta.X * sens
        UCam.Orbit.ManualPitch = UCam.clamp(UCam.Orbit.ManualPitch - delta.Y * sens, math.rad(-75), math.rad(75))
        return
    end
    if UCam.camMode == "Crane" or UCam.camMode == "Roll Axis" then
        UCam.Orbit.ManualYaw   = UCam.Orbit.ManualYaw - delta.X * sens
        UCam.Orbit.ManualPitch = UCam.clamp(UCam.Orbit.ManualPitch - delta.Y * sens, math.rad(-75), math.rad(75))
        return
    end
    UCam.cameraYaw   = UCam.cameraYaw - delta.X * sens
    UCam.cameraPitch = UCam.clamp(UCam.cameraPitch - delta.Y * sens, math.rad(-89), math.rad(89))
    if UCam.camCFrame then
        UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
    end
end

function UCam.getKeyboardDirection()
    if not UCam.camCFrame then return Vector3.new() end
    local direction = Vector3.new()
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += UCam.camCFrame.LookVector end
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= UCam.camCFrame.LookVector end
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= UCam.camCFrame.RightVector end
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += UCam.camCFrame.RightVector end
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.new(0, 1, 0) end
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.new(0, 1, 0) end
    return direction
end

function UCam.moveCamera(deltaTime)
    if UCam.camMode == "Tripode" or UCam.camMode == "Cenital" or UCam.camMode == "Lateral"
        or UCam.camMode == "Dron" or UCam.camMode == "Follow" or UCam.camMode == "CrashZoom"
        or UCam.camMode == "Director" or UCam.camMode == "Crane" or UCam.camMode == "Dolly Glide"
        or UCam.camMode == "Roll Axis" or UCam.camMode == "Vertigo" then
        UCam.currentVelocity = Vector3.new()
        return
    end
    local direction = UCam.getKeyboardDirection()
    if direction.Magnitude > 0 then direction = direction.Unit end
    local speed = UCam.currentSpeed
    if UCam.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UCam.UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
        speed = speed * UCam.SPRINT_MULTIPLIER
    end
    local desiredVelocity = direction * speed
    local alpha = UCam.clamp(deltaTime * UCam.MOVEMENT_SMOOTHING, 0, 1)
    UCam.currentVelocity = UCam.currentVelocity:Lerp(desiredVelocity, alpha)
    UCam.camCFrame = UCam.camCFrame + UCam.currentVelocity * deltaTime
end

-- ============================================================
-- VISUALIZADOR DE PATH (3D) del Director
-- ============================================================
function UCam.clearPathVisualizer()
    for _, part in ipairs(UCam.PathVisualizer.VisualParts) do
        pcall(function() part:Destroy() end)
    end
    table.clear(UCam.PathVisualizer.VisualParts)
end

function UCam.drawPathVisualizer()
    UCam.clearPathVisualizer()
    if not UCam.PathVisualizer.Enabled then return end

    local wps = UCam.Waypoint.List
    if #wps == 0 then return end

    for i, cf in ipairs(wps) do
        local sphere = Instance.new("Part")
        sphere.Name = "UCamWaypointVisual_" .. i
        sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.new(1.2, 1.2, 1.2)
        sphere.Color = Color3.fromRGB(0, 255, 255)
        sphere.Material = Enum.Material.Neon
        sphere.Anchored = true
        sphere.CanCollide = false
        sphere.CanQuery = false
        sphere.CanTouch = false
        sphere.CFrame = CFrame.new(cf.Position)
        sphere.Parent = UCam.camera
        table.insert(UCam.PathVisualizer.VisualParts, sphere)

        local bg = Instance.new("BillboardGui")
        bg.Size = UDim2.fromOffset(40, 40)
        bg.AlwaysOnTop = true
        bg.Parent = sphere

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(i)
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.SourceSansBold
        lbl.TextSize = 14
        lbl.Parent = bg
    end

    for i = 1, #wps - 1 do
        local posA = wps[i].Position
        local posB = wps[i + 1].Position
        local distance = (posA - posB).Magnitude

        local cylinder = Instance.new("Part")
        cylinder.Name = "UCamWaypointLine_" .. i
        cylinder.Shape = Enum.PartType.Cylinder
        cylinder.Size = Vector3.new(distance, 0.15, 0.15)
        cylinder.Color = Color3.fromRGB(0, 200, 255)
        cylinder.Material = Enum.Material.Neon
        cylinder.Anchored = true
        cylinder.CanCollide = false
        cylinder.CanQuery = false
        cylinder.CanTouch = false
        cylinder.CFrame = CFrame.lookAt(posA, posB) * CFrame.new(0, 0, -distance / 2) * CFrame.Angles(0, math.pi / 2, 0)
        cylinder.Parent = UCam.camera
        table.insert(UCam.PathVisualizer.VisualParts, cylinder)
    end
end

-- ============================================================
-- PANTALLA VERDE / CHROMA
-- ============================================================
function UCam.destroyGreenScreen()
    if UCam.GreenScreen.Part then
        pcall(function() UCam.GreenScreen.Part:Destroy() end)
        UCam.GreenScreen.Part = nil
    end
end

function UCam.getActiveSpawnPositions()
    local now = os.clock()
    if UCam.GreenScreen._spawnCache and (now - UCam.GreenScreen._spawnCacheAt) < 5 then
        return UCam.GreenScreen._spawnCache
    end
    local list = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") or d.Name == "SpawnLocation" then
            table.insert(list, d.Position)
        end
    end
    UCam.GreenScreen._spawnCache   = list
    UCam.GreenScreen._spawnCacheAt = now
    return list
end

function UCam.pickClearDirection(pivot, preferred)
    if not UCam.GreenScreen.AvoidSpawns then return preferred end
    local spawns = UCam.getActiveSpawnPositions()
    if #spawns == 0 then return preferred end

    local size = UCam.GreenScreen.Size
    local function wouldCover(dir)
        local center
        if dir == "Detras"   then center = pivot + Vector3.new(0, 0, -UCam.GreenScreen.Distance) end
        if dir == "Enfrente" then center = pivot + Vector3.new(0, 0,  UCam.GreenScreen.Distance) end
        if dir == "Arriba"   then center = pivot + Vector3.new(0,  UCam.GreenScreen.VerticalOffset + size.Y/2, 0) end
        if dir == "Abajo"    then center = pivot + Vector3.new(0, -UCam.GreenScreen.VerticalOffset - size.Y/2, 0) end
        for _, s in ipairs(spawns) do
            if (s - center).Magnitude < (math.max(size.X, size.Z) / 2) + 6 then
                return true
            end
        end
        return false
    end

    if not wouldCover(preferred) then return preferred end

    local fallbacks
    if preferred == "Detras" or preferred == "Enfrente" then
        fallbacks = { "Arriba", "Abajo", preferred == "Detras" and "Enfrente" or "Detras" }
    else
        fallbacks = { "Detras", "Enfrente" }
    end
    for _, alt in ipairs(fallbacks) do
        if not wouldCover(alt) then return alt end
    end
    return preferred
end

function UCam.updateGreenScreen()
    UCam.destroyGreenScreen()
    if not UCam.GreenScreen.Enabled then return end

    UCam.refreshCharacterRefs()
    local pivot = UCam.rootPart and UCam.rootPart.Position or Vector3.new(0, 0, 0)

    local vertical = UCam.pickClearDirection(pivot, UCam.GreenScreen.Vertical)
    UCam.GreenScreen.Position = pivot

    if vertical == "Arriba" then
        UCam.GreenScreen.Position = pivot + Vector3.new(0, UCam.GreenScreen.VerticalOffset + UCam.GreenScreen.Size.Y / 2, 0)
    elseif vertical == "Abajo" then
        UCam.GreenScreen.Position = pivot + Vector3.new(0, -(UCam.GreenScreen.VerticalOffset + UCam.GreenScreen.Size.Y / 2), 0)
    elseif vertical == "Enfrente" then
        UCam.GreenScreen.Position = pivot + Vector3.new(0, UCam.GreenScreen.Size.Y / 2 - 2, UCam.GreenScreen.Distance)
    else
        UCam.GreenScreen.Position = pivot + Vector3.new(0, UCam.GreenScreen.Size.Y / 2 - 2, -UCam.GreenScreen.Distance)
    end

    local part = Instance.new("Part")
    part.Name         = "UCam_GreenScreen"
    part.Anchored     = true
    part.CanCollide   = false
    part.CanQuery     = false
    part.CanTouch     = false
    part.Massless     = true
    part.CFrame       = CFrame.new(UCam.GreenScreen.Position)
    part.Size         = UCam.GreenScreen.Size
    part.Color        = UCam.GreenScreen.Color
    part.Material     = Enum.Material.Neon
    part.Transparency = UCam.GreenScreen.Transparency
    part.Parent       = workspace

    UCam.GreenScreen.Part = part
end

-- ============================================================
-- ILUMINACION / CLIMA (mezclador local)
-- ============================================================
function UCam.applyLightingTweaks()
    if not UCam.LightingTweaks.Enabled then
        pcall(function()
            UCam.Lighting.ClockTime            = UCam.OriginalLighting.ClockTime
            UCam.Lighting.ExposureCompensation = UCam.OriginalLighting.ExposureCompensation
            UCam.Lighting.FogColor             = UCam.OriginalLighting.FogColor
            UCam.Lighting.FogEnd               = UCam.OriginalLighting.FogEnd
            UCam.Lighting.OutdoorAmbient       = UCam.OriginalLighting.OutdoorAmbient
            UCam.Lighting.Ambient              = UCam.OriginalLighting.Ambient
            UCam.Lighting.Brightness           = UCam.OriginalLighting.Brightness
        end)
        return
    end

    pcall(function()
        UCam.Lighting.ClockTime            = UCam.LightingTweaks.ClockTime
        UCam.Lighting.ExposureCompensation = UCam.LightingTweaks.ExposureCompensation
        UCam.Lighting.FogColor             = UCam.LightingTweaks.FogColor
        UCam.Lighting.FogEnd               = UCam.LightingTweaks.FogEnd
        UCam.Lighting.OutdoorAmbient       = UCam.LightingTweaks.OutdoorAmbient
        UCam.Lighting.Ambient              = UCam.LightingTweaks.Ambient
        UCam.Lighting.Brightness           = UCam.LightingTweaks.Brightness
    end)
end
