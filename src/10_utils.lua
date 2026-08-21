-- ============================================================
-- Universal Camera Pro v8 · 10_utils
-- Utilidades de camara, personaje y visualizador de path.
-- v8: registry central de conexiones/instancias para cleanup
-- seguro al recargar el script.
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
--   pickClearDirection, updateGreenScreen, applyLightingTweaks,
--   trackConnection, untrackConnection, cleanupConnections,   <- v8
--   trackInstance, untrackInstance, cleanupInstances          <- v8
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- v8: REGISTRY CENTRAL DE CONEXIONES E INSTANCIAS
-- Problema v7: BindToRenderStep, InputBegan, Heartbeat, etc. se
-- conectaban sin guardarse en variables; al recargar el script
-- se duplicaban los handlers causando fugas y comportamiento
-- inconsistente. Ahora TODO se registra en UCam._connections o
-- UCam._instances, y UCam.Unload() los limpia completamente.
-- ============================================================
UCam._connections = UCam._connections or {}
UCam._instances   = UCam._instances   or {}

--- Registra una conexion RBXScriptConnection para desconectarla luego.
-- @param conn RBXScriptConnection
-- @param tag string opcional para debugging
function UCam.trackConnection(conn, tag)
    if not conn then return end
    table.insert(UCam._connections, { conn = conn, tag = tag or "unknown" })
    return conn
end

--- Desconecta y remueve una conexion especifica del registry.
function UCam.untrackConnection(conn)
    for i = #UCam._connections, 1, -1 do
        local entry = UCam._connections[i]
        if entry.conn == conn then
            pcall(function() entry.conn:Disconnect() end)
            table.remove(UCam._connections, i)
            return true
        end
    end
    return false
end

--- Desconecta TODAS las conexiones registradas. Llamado desde Unload().
function UCam.cleanupConnections()
    local report = { total = #UCam._connections, failed = 0, failures = {} }
    -- Iterar en reversa para evitar problemas al remover
    for i = #UCam._connections, 1, -1 do
        local entry = UCam._connections[i]
        local ok, err = pcall(function() entry.conn:Disconnect() end)
        if not ok then
            report.failed = report.failed + 1
            table.insert(report.failures, { tag = entry.tag, error = tostring(err) })
        end
    end
    table.clear(UCam._connections)
    UCam.LastCleanupReport = UCam.LastCleanupReport or {}
    UCam.LastCleanupReport.connections = report
    return report
end

--- Registra una instancia (part, gui, etc.) para destruirla luego.
function UCam.trackInstance(obj, tag)
    if not obj then return end
    table.insert(UCam._instances, { obj = obj, tag = tag or "unknown" })
    return obj
end

--- Remueve una instancia del registry SIN destruirla (ya destruida o se quiere preservar).
function UCam.untrackInstance(obj)
    for i = #UCam._instances, 1, -1 do
        if UCam._instances[i].obj == obj then
            table.remove(UCam._instances, i)
            return true
        end
    end
    return false
end

--- Destruye TODAS las instancias registradas. Llamado desde Unload().
function UCam.cleanupInstances()
    local report = { total = #UCam._instances, failed = 0, failures = {} }
    for i = #UCam._instances, 1, -1 do
        local entry = UCam._instances[i]
        local ok, err = pcall(function() entry.obj:Destroy() end)
        if not ok then
            report.failed = report.failed + 1
            table.insert(report.failures, { tag = entry.tag, error = tostring(err) })
        end
    end
    table.clear(UCam._instances)
    UCam.LastCleanupReport = UCam.LastCleanupReport or {}
    UCam.LastCleanupReport.instances = report
    return report
end

function UCam.getCleanupReport()
    local report = UCam.LastCleanupReport or {}
    report.connections = report.connections or { total = #UCam._connections, failed = 0, failures = {} }
    report.instances = report.instances or { total = #UCam._instances, failed = 0, failures = {} }
    return report
end

-- ============================================================
-- REFRESCAR REFERENCIAS AL PERSONAJE
-- v8: Esta función YA NO debe llamarse cada frame. Se llama
-- una vez aquí y desde CharacterAdded / CharacterRemoving.
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

-- Registrar el listener central que mantiene refs actualizadas.
-- 70_camcore ya no necesita llamar refreshCharacterRefs() en cada modo.
UCam.trackConnection(UCam.player.CharacterAdded:Connect(function(char)
    UCam.character = char
    UCam.humanoid  = char:WaitForChild("Humanoid", 5)
    UCam.rootPart  = char:WaitForChild("HumanoidRootPart", 5)
end), "CharacterAdded")

UCam.trackConnection(UCam.player.CharacterRemoving:Connect(function()
    UCam.character = nil
    UCam.humanoid  = nil
    UCam.rootPart  = nil
end), "CharacterRemoving")

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
    -- No inventar un valor al limpiar el snapshot: el siguiente ciclo debe
    -- capturar el AutoRotate real del personaje actual.
    UCam.Saved.AutoRotate   = nil
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

-- v7: helper de interpación lineal compartido entre módulos
function UCam.lerpNum(a, b, t)
    t = UCam.clamp(t, 0, 1)
    return a + (b - a) * t
end

function UCam.getEasingFn(name)
    if name == "Linear" then
        return function(t) return t end
    elseif name == "Sin" then
        return function(t) return 0.5 - 0.5 * math.cos(t * math.pi) end
    elseif name == "Expo" then
        -- easeInOutExpo: arranque y frenada muy lentos, centro veloz
        return function(t)
            t = UCam.clamp(t, 0, 1)
            if t <= 0.5 then return 0.5 * 2 ^ (10 * (t - 1)) end
            return 0.5 * (2 - 2 ^ (-10 * (t - 0.5)))
        end
    elseif name == "Bounce" then
        -- easeOutBounce: rebote físico al final
        return function(t)
            t = UCam.clamp(t, 0, 1)
            local n1, d1 = 7.5625, 2.75
            if t < 1 / d1 then
                return n1 * t * t
            elseif t < 2 / d1 then
                t = t - 1.5 / d1
                return n1 * t * t + 0.75
            elseif t < 2.5 / d1 then
                t = t - 2.25 / d1
                return n1 * t * t + 0.9375
            else
                t = t - 2.625 / d1
                return n1 * t * t + 0.984375
            end
        end
    elseif name == "Elastic" then
        -- easeOutElastic: oscilación elástica con overshoot
        return function(t)
            t = UCam.clamp(t, 0, 1)
            if t == 0 or t == 1 then return t end
            local c4 = (2 * math.pi) / 3
            return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
        end
    elseif name == "Back" then
        -- easeOutBack: overshoot con retroceso suave
        return function(t)
            t = UCam.clamp(t, 0, 1)
            local c1, c3 = 1.70158, 2.70158
            local u = t - 1
            return 1 + c3 * u ^ 3 + c1 * u ^ 2
        end
    else
        -- Smooth (smoothstep por defecto, retrocompatibilidad)
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
        -- v7: usa teclas personalizables desde UCam.Keybinds
        if UCam.isKeybindDown("Forward")  then direction = direction + UCam.camCFrame.LookVector end
        if UCam.isKeybindDown("Backward") then direction = direction - UCam.camCFrame.LookVector end
        if UCam.isKeybindDown("Left")     then direction = direction - UCam.camCFrame.RightVector end
        if UCam.isKeybindDown("Right")    then direction = direction + UCam.camCFrame.RightVector end
        if UCam.isKeybindDown("Up")       then direction = direction + Vector3.new(0, 1, 0) end
        if UCam.isKeybindDown("Down")     then direction = direction - Vector3.new(0, 1, 0) end
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
    if UCam.isKeybindDown("Sprint")
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

    -- Normaliza cada waypoint a CFrame (soporta CFrame puro o tabla v7)
    local function wpCF(wp)
        if typeof(wp) == "CFrame" then return wp end
        if type(wp) == "table" then return wp.cf end
        return nil
    end

    for i, wp in ipairs(wps) do
        local cf = wpCF(wp)
        if cf then
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
    end

    for i = 1, #wps - 1 do
        local cfA = wpCF(wps[i])
        local cfB = wpCF(wps[i + 1])
        if cfA and cfB then
            local posA = cfA.Position
            local posB = cfB.Position
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

            -- v7: flechas de dirección opcionales (preview de la ruta)
            if UCam.Waypoint.PreviewArrows then
                local mid = (posA + posB) * 0.5
                local arrow = Instance.new("Part")
                arrow.Name = "UCamWaypointArrow_" .. i
                arrow.Shape = Enum.PartType.Ball
                arrow.Size = Vector3.new(0.6, 0.6, 0.6)
                arrow.Color = Color3.fromRGB(255, 170, 0)
                arrow.Material = Enum.Material.Neon
                arrow.Anchored = true
                arrow.CanCollide = false
                arrow.CanQuery = false
                arrow.CanTouch = false
                -- Orientar la flecha hacia posB usando el LookVector del segmento
                arrow.CFrame = CFrame.lookAt(mid, posB)
                arrow.Parent = UCam.camera
                table.insert(UCam.PathVisualizer.VisualParts, arrow)
            end
        end
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
            UCam.Lighting.FogStart             = UCam.OriginalLighting.FogStart
            UCam.Lighting.OutdoorAmbient       = UCam.OriginalLighting.OutdoorAmbient
            UCam.Lighting.Ambient              = UCam.OriginalLighting.Ambient
            UCam.Lighting.Brightness           = UCam.OriginalLighting.Brightness
            -- v7: restaurar sombras y skybox
            UCam.Lighting.GlobalShadows        = UCam.OriginalLighting.GlobalShadows
            pcall(function()
                if UCam.OriginalLighting.ShadowSoftness ~= nil then
                    UCam.Lighting.ShadowSoftness = UCam.OriginalLighting.ShadowSoftness
                end
            end)
            UCam.destroyCustomSky()
        end)
        return
    end

    pcall(function()
        UCam.Lighting.ClockTime            = UCam.LightingTweaks.ClockTime
        UCam.Lighting.ExposureCompensation = UCam.LightingTweaks.ExposureCompensation
        UCam.Lighting.FogColor             = UCam.LightingTweaks.FogColor
        UCam.Lighting.FogEnd               = UCam.LightingTweaks.FogEnd
        UCam.Lighting.FogStart             = UCam.LightingTweaks.FogStart or 0
        UCam.Lighting.OutdoorAmbient       = UCam.LightingTweaks.OutdoorAmbient
        UCam.Lighting.Ambient              = UCam.LightingTweaks.Ambient
        UCam.Lighting.Brightness           = UCam.LightingTweaks.Brightness
        -- v7/v8 FIX: GlobalShadows es BOOLEAN (asignar un número como
        -- ShadowIntensity triggeraba warnings y sanity-checks anti-cheat).
        -- El slider de intensidad se mapea a ShadowSoftness (0..1).
        if UCam.LightingTweaks.ShadowsEnabled ~= nil then
            UCam.Lighting.GlobalShadows = UCam.LightingTweaks.ShadowsEnabled
            pcall(function()
                if UCam.LightingTweaks.ShadowsEnabled
                    and UCam.LightingTweaks.ShadowIntensity ~= nil then
                    UCam.Lighting.ShadowSoftness = UCam.clamp(UCam.LightingTweaks.ShadowIntensity, 0, 1)
                end
            end)
        end
        -- v7: skybox override
        UCam.applyCustomSky()
    end)
end

-- ============================================================
-- v7: SKYBOX OVERRIDE (instancia un Sky con asset o lo destruye)
-- ============================================================
function UCam.destroyCustomSky()
    local sky = UCam.Lighting:FindFirstChild("UCam_SkyOverride")
    if sky then pcall(function() sky:Destroy() end) end
end

function UCam.applyCustomSky()
    UCam.destroyCustomSky()
    local assetId = UCam.LightingTweaks.SkyboxAssetId
    if not assetId or assetId == "" or assetId == 0 then return end

    local sky = Instance.new("Sky")
    sky.Name = "UCam_SkyOverride"
    -- Aplicar el mismo asset a las 6 caras (típico de skyboxes completos de RBX)
    local ok = pcall(function()
        sky.SkyboxBk = ("rbxassetid://%d"):format(assetId)
        sky.SkyboxDn = ("rbxassetid://%d"):format(assetId)
        sky.SkyboxFt = ("rbxassetid://%d"):format(assetId)
        sky.SkyboxLf = ("rbxassetid://%d"):format(assetId)
        sky.SkyboxRt = ("rbxassetid://%d"):format(assetId)
        sky.SkyboxUp = ("rbxassetid://%d"):format(assetId)
    end)
    if ok then sky.Parent = UCam.Lighting end
end

-- ============================================================
-- COLOR HELPER: HEX -> Color3
-- Acepta "#RRGGBB", "RRGGBB", "#RGB" o "RGB". Case-insensitive.
-- Devuelve Color3 o nil si el string no es válido.
-- ============================================================
function UCam.hexToColor(hex)
    if type(hex) ~= "string" then return nil end
    local s = hex:match("^#?(%x+)$")
    if not s then return nil end
    local r, g, b
    if #s == 6 then
        r = tonumber(s:sub(1, 2), 16)
        g = tonumber(s:sub(3, 4), 16)
        b = tonumber(s:sub(5, 6), 16)
    elseif #s == 3 then
        r = tonumber(s:sub(1, 1), 16) * 17
        g = tonumber(s:sub(2, 2), 16) * 17
        b = tonumber(s:sub(3, 3), 16) * 17
    else
        return nil
    end
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end
