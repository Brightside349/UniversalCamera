-- ============================================================
-- Universal Camera Pro v8 · 30_fun
-- Modulo de Diversion (Fun) completo: montar, noclip, gravedad,
-- escala, poses, rainbow, neon, trail, disco, material, invisibilidad.
-- Se aplica localmente (no se envia al server).
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   funAnyActive, funSnapshotCharacter, funRestorePartVisuals,
--   funRestoreCharacterScale,
--   funRestoreHumanoid, funClearPartSnapshots, funEnsureHighlight,
--   funClearHighlight, funApplyScale, funUpdate, startFun, stopFun,
--   FunV6 = { clearTrail, updateTrail, destroyDisco, createDisco,
--             updateDisco, applyMaterial, updateInvisibility,
--             setInvisibility }
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- HELPERS BASICOS
-- ============================================================

-- v7: Cached arrays para evitar GetDescendants() cada frame
UCam.Fun._cachedBaseParts = {}
UCam.Fun._cachedMotor6Ds = {}
UCam.Fun._descendantAddedConn = nil
UCam.Fun._descendantRemovingConn = nil

-- v7: Construir cache de partes
local function rebuildCache()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    table.clear(UCam.Fun._cachedBaseParts)
    table.clear(UCam.Fun._cachedMotor6Ds)
    
    for _, descendant in ipairs(UCam.character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(UCam.Fun._cachedBaseParts, descendant)
        elseif descendant:IsA("Motor6D") then
            table.insert(UCam.Fun._cachedMotor6Ds, descendant)
        end
    end
end

-- v7: Setup listeners para mantener cache actualizado
local function setupCacheListeners()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    -- Limpiar listeners previos
    if UCam.Fun._descendantAddedConn then
        UCam.Fun._descendantAddedConn:Disconnect()
    end
    if UCam.Fun._descendantRemovingConn then
        UCam.Fun._descendantRemovingConn:Disconnect()
    end
    
    -- Agregar nuevos listeners
    UCam.Fun._descendantAddedConn = UCam.character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            table.insert(UCam.Fun._cachedBaseParts, descendant)
        elseif descendant:IsA("Motor6D") then
            table.insert(UCam.Fun._cachedMotor6Ds, descendant)
        end
    end)
    
    UCam.Fun._descendantRemovingConn = UCam.character.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            local idx = table.find(UCam.Fun._cachedBaseParts, descendant)
            if idx then
                table.remove(UCam.Fun._cachedBaseParts, idx)
            end
        elseif descendant:IsA("Motor6D") then
            local idx = table.find(UCam.Fun._cachedMotor6Ds, descendant)
            if idx then
                table.remove(UCam.Fun._cachedMotor6Ds, idx)
            end
        end
    end)
end

-- Captura tamaños / colores / materiales originales + valores de Humanoid.
-- Se llama la primera vez que se activa un efecto que los modifique.
-- v7: Ahora también construye el cache optimizado
function UCam.funSnapshotCharacter()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    -- v7: Construir cache de partes
    rebuildCache()
    setupCacheListeners()

    -- La escala anterior multiplicaba BasePart.Size individualmente. Eso
    -- agranda cada pieza, pero no sus joints/attachments, por lo que R6/R15
    -- termina deformado. Guardar la escala del Model permite usar ScaleTo()
    -- y conservar las proporciones completas del avatar.
    local modelScale = 1
    local scaleOk, currentModelScale = pcall(function()
        return UCam.character:GetScale()
    end)
    if scaleOk and type(currentModelScale) == "number" and currentModelScale > 0 then
        modelScale = currentModelScale
    end
    UCam.Fun._origModelScale = modelScale
    UCam.Fun._scaleUsingHumanoidValues = false
    UCam.Fun._scaleWarningShown = false
    table.clear(UCam.Fun._origHumanoidScales)
    if UCam.humanoid then
        for _, scaleName in ipairs({
            "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale",
        }) do
            local value = UCam.humanoid:FindFirstChild(scaleName)
            if value and value:IsA("NumberValue") then
                UCam.Fun._origHumanoidScales[scaleName] = value.Value
            end
        end
    end
    
    table.clear(UCam.Fun._origPartSizes)
    table.clear(UCam.Fun._origBodyColors)
    table.clear(UCam.Fun._origMaterials)
    table.clear(UCam.Fun._origParts)
    
    -- v7: Usar cache en vez de GetDescendants()
    for _, part in ipairs(UCam.Fun._cachedBaseParts) do
        UCam.Fun._origPartSizes[part]   = part.Size
        UCam.Fun._origBodyColors[part]  = part.Color
        UCam.Fun._origMaterials[part]   = part.Material
        table.insert(UCam.Fun._origParts, part)
    end
    
    if UCam.humanoid and UCam.Fun._savedWalkSpeed == nil then
        UCam.Fun._savedWalkSpeed  = UCam.humanoid.WalkSpeed
        UCam.Fun._savedJumpPower  = UCam.humanoid.JumpPower
        UCam.Fun._savedAutoRotate = UCam.humanoid.AutoRotate
    end
end

function UCam.funRestoreCharacterScale()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end

    -- ScaleTo restaura también joints, attachments, meshes y accesorios.
    -- Es importante hacerlo antes de limpiar los snapshots de partes.
    if UCam.Fun._origModelScale then
        pcall(function()
            UCam.character:ScaleTo(UCam.Fun._origModelScale)
        end)
    end

    -- Fallback para clientes/rigs donde Model:ScaleTo no está disponible.
    if UCam.Fun._scaleUsingHumanoidValues and UCam.humanoid then
        for scaleName, originalValue in pairs(UCam.Fun._origHumanoidScales) do
            local value = UCam.humanoid:FindFirstChild(scaleName)
            if value and value:IsA("NumberValue") then
                pcall(function() value.Value = originalValue end)
            end
        end
    end
end

function UCam.funRestorePartVisuals()
    -- Restaurar material/color no debe cancelar una escala que sigue activa.
    -- El botón de tamaño y stopFun desactivan Scale antes de llegar aquí.
    if not UCam.Fun.Scale.Enabled then
        UCam.funRestoreCharacterScale()
        for part, size in pairs(UCam.Fun._origPartSizes) do
            if part and part.Parent then
                pcall(function() part.Size = size end)
            end
        end
    end
    for part, color in pairs(UCam.Fun._origBodyColors) do
        if part and part.Parent then
            pcall(function() part.Color = color end)
        end
    end
    for part, mat in pairs(UCam.Fun._origMaterials) do
        if part and part.Parent then
            pcall(function() part.Material = mat end)
        end
    end
end

function UCam.funRestoreHumanoid()
    UCam.refreshCharacterRefs()
    if UCam.humanoid then
        if UCam.Fun._savedWalkSpeed ~= nil then
            pcall(function() UCam.humanoid.WalkSpeed = UCam.Fun._savedWalkSpeed end)
        end
        if UCam.Fun._savedJumpPower ~= nil then
            pcall(function() UCam.humanoid.JumpPower = UCam.Fun._savedJumpPower end)
        end
        if UCam.Fun._savedAutoRotate ~= nil then
            pcall(function() UCam.humanoid.AutoRotate = UCam.Fun._savedAutoRotate end)
        end
    end
    UCam.Fun._savedWalkSpeed  = nil
    UCam.Fun._savedJumpPower  = nil
    UCam.Fun._savedAutoRotate = nil
end

function UCam.funClearPartSnapshots()
    table.clear(UCam.Fun._origPartSizes)
    table.clear(UCam.Fun._origBodyColors)
    table.clear(UCam.Fun._origMaterials)
    table.clear(UCam.Fun._origParts)
    table.clear(UCam.Fun._origHumanoidScales)
    UCam.Fun._origModelScale = nil
    UCam.Fun._scaleUsingHumanoidValues = false
    UCam.Fun._scaleWarningShown = false
end

-- ============================================================
-- HIGHLIGHT (neon)
-- ============================================================
function UCam.funEnsureHighlight()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    if UCam.Fun._highlight and UCam.Fun._highlight.Parent then return end
    pcall(function()
        local hl              = Instance.new("Highlight")
        hl.Name               = "UCamFunGlow"
        hl.Adornee            = UCam.character
        hl.FillColor          = UCam.Fun.NeonGlow.Color
        hl.OutlineColor       = Color3.new(1, 1, 1)
        hl.FillTransparency   = 0.4
        hl.OutlineTransparency = 0.2
        hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent             = UCam.character
        UCam.Fun._highlight   = hl
    end)
end

function UCam.funClearHighlight()
    if UCam.Fun._highlight then
        pcall(function() UCam.Fun._highlight:Destroy() end)
        UCam.Fun._highlight = nil
    end
end

-- Escala uniforme: usa el Model completo para conservar proporciones, joints,
-- attachments, meshes y accesorios. El fallback usa los valores de escala R15.
function UCam.funApplyScale(scale)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    if not next(UCam.Fun._origPartSizes) then UCam.funSnapshotCharacter() end

    scale = tonumber(scale) or 1
    scale = math.max(0.1, math.min(scale, 10))
    local originalModelScale = UCam.Fun._origModelScale or 1
    local targetModelScale = originalModelScale * scale
    local scaledModel = false

    -- Model:ScaleTo escala el avatar como una unidad y evita el cuerpo
    -- estirado que provocaba escribir Size en cada BasePart.
    local scaleOk = pcall(function()
        UCam.character:ScaleTo(targetModelScale)
    end)
    if scaleOk then
        scaledModel = true
        UCam.Fun._scaleUsingHumanoidValues = false
    end

    -- Fallback para rigs/clientes sin ScaleTo: solo toca los NumberValues de
    -- escala de R15, multiplicando desde sus valores originales para no
    -- destruir proporciones personalizadas del avatar.
    if not scaledModel and UCam.humanoid then
        local changed = false
        for scaleName, originalValue in pairs(UCam.Fun._origHumanoidScales) do
            local value = UCam.humanoid:FindFirstChild(scaleName)
            if value and value:IsA("NumberValue") then
                local ok = pcall(function() value.Value = originalValue * scale end)
                if ok then changed = true end
            end
        end
        UCam.Fun._scaleUsingHumanoidValues = changed
    end

    UCam.Fun._currentScale = scale

    -- Si el cliente tampoco ofrece ScaleTo ni escalas R15, no aplicamos el
    -- antiguo fallback de BasePart.Size: deformaba el cuerpo y era peor que
    -- dejarlo en su tamaño original.
    if not scaledModel and not UCam.Fun._scaleUsingHumanoidValues
        and not UCam.Fun._scaleWarningShown then
        warn("[UCam] Este rig no expone una escala uniforme compatible.")
        UCam.Fun._scaleWarningShown = true
    end
end

-- ============================================================
-- PER-FRAME UPDATES
-- ============================================================
-- v7: Optimizado con cache
local function funUpdateNoclip()
    if not UCam.Fun.Noclip.Enabled then return end
    -- v8: refs cacheadas por eventos en 10_utils (no llamar refresh aquí)
    if not UCam.character then return end

    -- v7: Usar cache en vez de GetDescendants()
    for _, part in ipairs(UCam.Fun._cachedBaseParts) do
        pcall(function() part.CanCollide = false end)
    end
end

local function funUpdateMount(dt)
    if not UCam.Fun.Mount.Enabled or not UCam.Fun.Mount.Target then return end
    -- v8: refs cacheadas por eventos; no refrescar cada frame
    if not UCam.rootPart or not UCam.humanoid then return end
    local targetChar = UCam.Fun.Mount.Target.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    local targetHead = targetChar:FindFirstChild("Head")
    if not targetRoot then return end

    local baseCF
    if UCam.Fun.Mount.Anchor == "Cabeza" and targetHead then
        baseCF = targetHead.CFrame
    elseif UCam.Fun.Mount.Anchor == "Espalda" then
        baseCF = targetRoot.CFrame * CFrame.new(0, 2.5, 1.8)
    else
        baseCF = targetRoot.CFrame * CFrame.new(0, 3.2, 0)
    end

    local targetPos = baseCF.Position + Vector3.new(0, UCam.Fun.Mount.HeightOffset, 0)
    local targetCF
    if UCam.Fun.Mount.FollowRotation then
        targetCF = CFrame.new(targetPos, targetPos + baseCF.LookVector)
    else
        targetCF = CFrame.new(targetPos) * CFrame.Angles(0, math.atan2(-baseCF.LookVector.X, -baseCF.LookVector.Z), 0)
    end

    pcall(function()
        local alpha = UCam.clamp(dt * 15, 0, 1)
        UCam.rootPart.CFrame = UCam.rootPart.CFrame:Lerp(targetCF, alpha)
        UCam.rootPart.AssemblyLinearVelocity  = Vector3.zero
        UCam.rootPart.AssemblyAngularVelocity = Vector3.zero
        if UCam.humanoid then
            UCam.humanoid.AutoRotate = false
            UCam.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end)
end

local function funUpdateGravity(dt)
    if not UCam.Fun.Gravity.Enabled or UCam.Fun.Gravity.Mode == "Normal" then return end
    -- v8: refs cacheadas por eventos en 10_utils (no refresh aquí)
    if not UCam.rootPart then return end
    local mode = UCam.Fun.Gravity.Mode
    pcall(function()
        if mode == "Cero" then
            UCam.rootPart.AssemblyLinearVelocity = Vector3.new(
                UCam.rootPart.AssemblyLinearVelocity.X,
                0,
                UCam.rootPart.AssemblyLinearVelocity.Z
            )
        elseif mode == "Reversa" then
            UCam.rootPart.AssemblyLinearVelocity = UCam.rootPart.AssemblyLinearVelocity
                + Vector3.new(0, workspace.Gravity * 2 * dt, 0)
        elseif mode == "Luna" then
            if UCam.rootPart.AssemblyLinearVelocity.Y < 0 then
                UCam.rootPart.AssemblyLinearVelocity = UCam.rootPart.AssemblyLinearVelocity
                    * Vector3.new(1, 0.84, 1)
            end
        elseif mode == "Marte" then
            if UCam.rootPart.AssemblyLinearVelocity.Y < 0 then
                UCam.rootPart.AssemblyLinearVelocity = UCam.rootPart.AssemblyLinearVelocity
                    * Vector3.new(1, 0.62, 1)
            end
        elseif mode == "Pesada" then
            UCam.rootPart.AssemblyLinearVelocity = UCam.rootPart.AssemblyLinearVelocity
                + Vector3.new(0, -workspace.Gravity * 1.5 * dt, 0)
        elseif mode == "Custom" then
            UCam.rootPart.AssemblyLinearVelocity = UCam.rootPart.AssemblyLinearVelocity
                + Vector3.new(0, -UCam.Fun.Gravity.Custom * dt, 0)
        end
    end)
end

local function funUpdateBodySpin(dt)
    if not UCam.Fun.BodySpin.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return end
    UCam.Fun._spinAngle = UCam.Fun._spinAngle + math.rad(UCam.Fun.BodySpin.Speed) * dt
    local pos = UCam.rootPart.CFrame.Position
    local rot
    if UCam.Fun.BodySpin.Axis == "Vertical" then
        rot = CFrame.Angles(0, UCam.Fun._spinAngle, 0)
    elseif UCam.Fun.BodySpin.Axis == "Horizontal" then
        rot = CFrame.Angles(UCam.Fun._spinAngle, 0, 0)
    else
        rot = CFrame.Angles(UCam.Fun._spinAngle, UCam.Fun._spinAngle * 0.7, 0)
    end
    pcall(function()
        UCam.rootPart.CFrame = CFrame.new(pos) * rot
        UCam.rootPart.AssemblyLinearVelocity  = Vector3.zero
        UCam.rootPart.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- v7: Optimizado con cache
local function funUpdateRainbow(dt)
    if not UCam.Fun.Rainbow.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    UCam.Fun._rainbowTick = UCam.Fun._rainbowTick + dt * UCam.Fun.Rainbow.Speed
    -- FIX v4.2: Color3.fromHSV espera el hue normalizado 0-1, no 0-360
    local hueDegrees = (UCam.Fun._rainbowTick * 60) % 360
    local hue        = hueDegrees / 360
    local color = Color3.fromHSV(hue, 1, 1)
    
    -- v7: Usar cache en vez de GetDescendants()
    for _, part in ipairs(UCam.Fun._cachedBaseParts) do
        if part.Name ~= "HumanoidRootPart" then
            pcall(function() part.Color = color end)
        end
    end
end

local function funUpdateSpeed()
    if not UCam.Fun.SpeedBoost.Enabled then return end
    UCam.refreshCharacterRefs()
    if UCam.humanoid then
        pcall(function() UCam.humanoid.WalkSpeed = UCam.Fun.SpeedBoost.WalkSpeed end)
    end
end

local function funUpdateJump()
    if not UCam.Fun.SuperJump.Enabled then return end
    UCam.refreshCharacterRefs()
    if UCam.humanoid then
        pcall(function()
            UCam.humanoid.JumpPower   = UCam.Fun.SuperJump.Power
            UCam.humanoid.UseJumpPower = true
        end)
    end
end

-- ============================================================
-- v9: POSE FORZADA (T-Pose/Sentado/Flotando) ELIMINADA
-- Peleaba cada frame con el sistema avanzado de 33_poses (ambos escribían
-- Motor6D.Transform y PlatformStand con objetivos distintos). Las poses
-- viven ahora únicamente en la pestaña 🧍 Poses (33_poses.lua).
-- ============================================================

local function funUpdateNeonGlow()
    if UCam.Fun.NeonGlow.Enabled then
        UCam.funEnsureHighlight()
        if UCam.Fun._highlight then
            UCam.Fun._highlight.FillColor    = UCam.Fun.NeonGlow.Color
            UCam.Fun._highlight.OutlineColor = UCam.Fun.NeonGlow.Color
        end
    else
        UCam.funClearHighlight()
    end
end

-- ============================================================
-- EFECTOS VISUALES v6 (trail / disco / material / invisibilidad)
-- Se exponen bajo UCam.FunV6
-- ============================================================
UCam.FunV6 = {}

function UCam.FunV6.clearTrail()
    for _, entry in ipairs(UCam.Fun.Trail._parts) do
        if entry and entry.part then
            pcall(function() entry.part:Destroy() end)
        end
    end
    table.clear(UCam.Fun.Trail._parts)
    -- FIX (bug B2 del plan v6): resetear el timer real.
    UCam.Fun.Trail._timer = 0
end

function UCam.FunV6.updateTrail(dt)
    if not UCam.Fun.Trail.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return end

    UCam.Fun.Trail._timer = UCam.Fun.Trail._timer + dt
    local interval = 0.08
    if UCam.Fun.Trail._timer >= interval then
        UCam.Fun.Trail._timer = 0
        local p = Instance.new("Part")
        p.Name = "UCamTrail"
        p.Shape = Enum.PartType.Ball
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Massless = true
        p.Size = Vector3.new(UCam.Fun.Trail.Width, UCam.Fun.Trail.Width, UCam.Fun.Trail.Width)
        p.Color = UCam.Fun.Trail.Color
        p.Material = Enum.Material.Neon
        p.CFrame = UCam.rootPart.CFrame
        p.Parent = workspace
        table.insert(UCam.Fun.Trail._parts, { part = p, born = os.clock() })
    end

    local now = os.clock()
    for i = #UCam.Fun.Trail._parts, 1, -1 do
        local entry = UCam.Fun.Trail._parts[i]
        local age = now - entry.born
        if age >= UCam.Fun.Trail.Duration or not (entry.part and entry.part.Parent) then
            pcall(function() entry.part:Destroy() end)
            table.remove(UCam.Fun.Trail._parts, i)
        else
            local k = 1 - (age / math.max(UCam.Fun.Trail.Duration, 0.05))
            local s = math.max(UCam.Fun.Trail.Width * k, 0.05)
            entry.part.Size = Vector3.new(s, s, s)
            entry.part.Color = UCam.Fun.Trail.Color
        end
    end
end

function UCam.FunV6.destroyDisco()
    if UCam.Fun.Disco.Part then
        pcall(function() UCam.Fun.Disco.Part:Destroy() end)
        UCam.Fun.Disco.Part = nil
    end
end

function UCam.FunV6.createDisco()
    UCam.FunV6.destroyDisco()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.Fun.Disco.Enabled then return end
    local part = Instance.new("Part")
    part.Name = "UCamDisco"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.Size = Vector3.new(UCam.Fun.Disco.Size, 0.2, UCam.Fun.Disco.Size)
    part.Color = UCam.Fun.Disco.Color
    part.Material = Enum.Material.Neon
    part.CFrame = CFrame.new(UCam.rootPart.Position - Vector3.new(0, 3, 0))
    part.Parent = workspace
    UCam.Fun.Disco.Part = part
end

function UCam.FunV6.updateDisco()
    if not UCam.Fun.Disco.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return end
    if not (UCam.Fun.Disco.Part and UCam.Fun.Disco.Part.Parent) then
        UCam.FunV6.createDisco()
        return
    end
    pcall(function()
        UCam.Fun.Disco.Part.Size = Vector3.new(UCam.Fun.Disco.Size, 0.2, UCam.Fun.Disco.Size)
        UCam.Fun.Disco.Part.Color = UCam.Fun.Disco.Color
        UCam.Fun.Disco.Part.CFrame = CFrame.new(UCam.rootPart.Position - Vector3.new(0, 3, 0))
    end)
end

-- v7: Optimizado con cache
function UCam.FunV6.applyMaterial(name)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    local enumMat = Enum.Material[name]
    if not enumMat then return end
    if not next(UCam.Fun._origMaterials) then UCam.funSnapshotCharacter() end
    UCam.Fun.Material.Current = name
    
    -- v7: Usar cache en vez de GetDescendants()
    for _, part in ipairs(UCam.Fun._cachedBaseParts) do
        pcall(function() part.Material = enumMat end)
    end
end

-- v7: Optimizado con cache
function UCam.FunV6.updateInvisibility()
    if not UCam.Fun.Invisibility.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    -- v7: Usar cache en vez de GetDescendants()
    for _, part in ipairs(UCam.Fun._cachedBaseParts) do
        if part.Transparency < 1 then
            pcall(function() part.Transparency = 1 end)
        end
    end
    
    -- También manejar Decals (no están en cache de BaseParts)
    for _, descendant in ipairs(UCam.character:GetDescendants()) do
        if descendant:IsA("Decal") and descendant.Transparency < 1 then
            pcall(function() descendant.Transparency = 1 end)
        end
    end
end

-- ============================================================
-- UPDATE MAESTRO + START/STOP
-- v8: mantenemos el chequeo por if (compatibilidad) — cada función
-- ya tiene fast-return. Ahora los refreshCharacterRefs() redundantes
-- se eliminan donde las refs se actualizan en eventos.
-- ============================================================
local function funUpdateCore(dt)
    funUpdateNoclip()
    funUpdateRainbow(dt)
    funUpdateNeonGlow()
    funUpdateSpeed()
    funUpdateJump()
    -- v9: funUpdatePose eliminado (sistema de poses unificado en 33_poses)
    if UCam.updateAdvPoses then UCam.updateAdvPoses(dt) end
    funUpdateGravity(dt)
    UCam.FunV6.updateTrail(dt)
    UCam.FunV6.updateDisco()
    UCam.FunV6.updateInvisibility()
    funUpdateBodySpin(dt)
    funUpdateMount(dt)
end

local function startFun()
    if UCam.Fun._connHeartbeat then return end
    UCam.funSnapshotCharacter()
    -- El personaje puede reemplazarse al respawn mientras Fun sigue activo.
    -- Reconstruir cache y snapshots evita operar sobre partes destruidas.
    if UCam.Fun._characterAddedConn then
        UCam.Fun._characterAddedConn:Disconnect()
    end
    UCam.Fun._characterAddedConn = UCam.trackConnection(UCam.player.CharacterAdded:Connect(function()
        task.defer(function()
            if UCam.Fun._connHeartbeat then
                UCam.funSnapshotCharacter()
                if UCam.Fun.Scale.Enabled then
                    UCam.funApplyScale(UCam.Fun.Scale.Value)
                end
            end
        end)
    end), "fun-character-cache")
    UCam.Fun._connHeartbeat = UCam.RunService.Heartbeat:Connect(function(dt)
        UCam.funUpdate(dt)
    end)
end
UCam.startFun = startFun

function UCam.funAnyActive()
    return UCam.Fun.Mount.Enabled
        or UCam.Fun.Noclip.Enabled
        or (UCam.Fun.Gravity.Enabled and UCam.Fun.Gravity.Mode ~= "Normal")
        or UCam.Fun.SuperJump.Enabled
        or UCam.Fun.SpeedBoost.Enabled
        or UCam.Fun.Scale.Enabled
        or UCam.Fun.BodySpin.Enabled
        or UCam.Fun.Rainbow.Enabled
        or UCam.Fun.NeonGlow.Enabled
        or UCam.Fun.Trail.Enabled
        or UCam.Fun.Disco.Enabled
        or UCam.Fun.Invisibility.Enabled
        or UCam.Fun.Particles.Enabled
        or UCam.Fun.Fly.Enabled
end

local function stopFun()
    if UCam.Fun._connHeartbeat then
        UCam.Fun._connHeartbeat:Disconnect()
        UCam.Fun._connHeartbeat = nil
    end
    
    -- v7: Desconectar listeners de cache
    if UCam.Fun._descendantAddedConn then
        UCam.Fun._descendantAddedConn:Disconnect()
        UCam.Fun._descendantAddedConn = nil
    end
    if UCam.Fun._descendantRemovingConn then
        UCam.Fun._descendantRemovingConn:Disconnect()
        UCam.Fun._descendantRemovingConn = nil
    end
    if UCam.Fun._characterAddedConn then
        UCam.Fun._characterAddedConn:Disconnect()
        UCam.Fun._characterAddedConn = nil
    end
    
    -- v7: Limpiar cache
    table.clear(UCam.Fun._cachedBaseParts)
    table.clear(UCam.Fun._cachedMotor6Ds)
    
    -- v7: Limpiar nuevas features
    UCam.FunV7.disableParticles()
    UCam.FunV7.disableFly()

    -- v9: funUnfreezeControl eliminado junto al sistema Fun.Pose; la
    -- restauración de PlatformStand/Animate la hace 33_poses si aplica.
    UCam.Fun.Scale.Enabled = false
    UCam.funRestorePartVisuals()
    UCam.funRestoreHumanoid()
    UCam.funClearHighlight()
    UCam.funClearPartSnapshots()
    UCam.Fun.Mount.Enabled      = false
    UCam.Fun.Mount.Target       = nil
    UCam.Fun.Noclip.Enabled     = false
    UCam.Fun.Gravity.Enabled    = false
    UCam.Fun.Gravity.Mode       = "Normal"
    UCam.Fun.SuperJump.Enabled  = false
    UCam.Fun.SpeedBoost.Enabled = false
    UCam.Fun.Scale.Enabled      = false
    UCam.Fun.BodySpin.Enabled   = false
    UCam.Fun.Rainbow.Enabled    = false
    UCam.Fun.NeonGlow.Enabled   = false
    UCam.FunV6.clearTrail()
    UCam.FunV6.destroyDisco()
    for part, trans in pairs(UCam.Fun._origTransparency) do
        if part and part.Parent then
            pcall(function() part.Transparency = trans end)
        end
    end
    table.clear(UCam.Fun._origTransparency)
    UCam.Fun.Trail.Enabled        = false
    UCam.Fun.Disco.Enabled        = false
    UCam.Fun.Invisibility.Enabled = false
    UCam.Fun.Material.Current     = "Plastic"
    UCam.Fun._spinAngle         = 0
    UCam.Fun._rainbowTick       = 0
    UCam.Fun._currentScale      = 1.0
end
UCam.stopFun = stopFun

-- v6: setInvisibility DESPUES de stopFun porque la usa
function UCam.FunV6.setInvisibility(enabled)
    UCam.Fun.Invisibility.Enabled = enabled
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    if enabled then
        table.clear(UCam.Fun._origTransparency)
        for _, part in ipairs(UCam.character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                if UCam.Fun._origTransparency[part] == nil then
                    UCam.Fun._origTransparency[part] = part.Transparency
                end
                pcall(function() part.Transparency = 1 end)
            end
        end
        startFun()
    else
        for part, trans in pairs(UCam.Fun._origTransparency) do
            if part and part.Parent then
                pcall(function() part.Transparency = trans end)
            end
        end
        table.clear(UCam.Fun._origTransparency)
        if not UCam.funAnyActive() then stopFun() end
    end
end


-- ============================================================
-- v7: PARTÍCULAS (Auras de fuego, electricidad, hielo, etc.)
-- ============================================================
UCam.FunV7 = UCam.FunV7 or {}

function UCam.FunV7.createParticleEmitter(particleType)
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return nil end
    
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "UCamParticle_" .. particleType
    
    if particleType == "Fire" then
        emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
        emitter.Color = ColorSequence.new(UCam.Fun.Particles.Color)
        emitter.Size = NumberSequence.new(0.5, 1.5)
        emitter.Transparency = NumberSequence.new(0.3, 1)
        emitter.Lifetime = NumberRange.new(0.5, 1.5)
        emitter.Rate = 20 * UCam.Fun.Particles.Intensity
        emitter.Speed = NumberRange.new(3, 6)
        emitter.VelocitySpread = 30
        emitter.LightEmission = 1
    elseif particleType == "Electric" then
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
        emitter.Size = NumberSequence.new(0.1, 0.3)
        emitter.Transparency = NumberSequence.new(0, 1)
        emitter.Lifetime = NumberRange.new(0.2, 0.5)
        emitter.Rate = 40 * UCam.Fun.Particles.Intensity
        emitter.Speed = NumberRange.new(2, 8)
        emitter.VelocitySpread = 180
        emitter.LightEmission = 1
    elseif particleType == "Ice" then
        emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
        emitter.Size = NumberSequence.new(0.3, 0.8)
        emitter.Transparency = NumberSequence.new(0.2, 1)
        emitter.Lifetime = NumberRange.new(1, 2)
        emitter.Rate = 15 * UCam.Fun.Particles.Intensity
        emitter.Speed = NumberRange.new(1, 3)
        emitter.VelocitySpread = 20
        emitter.LightEmission = 0.5
    elseif particleType == "Smoke" then
        emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
        emitter.Size = NumberSequence.new(0.8, 2)
        emitter.Transparency = NumberSequence.new(0.5, 1)
        emitter.Lifetime = NumberRange.new(2, 4)
        emitter.Rate = 10 * UCam.Fun.Particles.Intensity
        emitter.Speed = NumberRange.new(1, 2)
        emitter.VelocitySpread = 10
    elseif particleType == "Sparkles" then
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(UCam.Fun.Particles.Color)
        emitter.Size = NumberSequence.new(0.2, 0.2)
        emitter.Transparency = NumberSequence.new(0, 1)
        emitter.Lifetime = NumberRange.new(0.5, 1.5)
        emitter.Rate = 30 * UCam.Fun.Particles.Intensity
        emitter.Speed = NumberRange.new(2, 5)
        emitter.VelocitySpread = 180
        emitter.LightEmission = 1
    end
    
    emitter.Parent = UCam.rootPart
    return emitter
end

function UCam.FunV7.enableParticles(particleType)
    UCam.FunV7.disableParticles()
    
    local emitter = UCam.FunV7.createParticleEmitter(particleType)
    if emitter then
        table.insert(UCam.Fun.Particles._emitters, emitter)
        UCam.Fun.Particles.Type = particleType
        UCam.Fun.Particles.Enabled = true
    end
end

function UCam.FunV7.disableParticles()
    for _, emitter in ipairs(UCam.Fun.Particles._emitters) do
        if emitter and emitter.Parent then
            emitter:Destroy()
        end
    end
    table.clear(UCam.Fun.Particles._emitters)
    UCam.Fun.Particles.Enabled = false
end

-- ============================================================
-- v7: TELEPORT
-- ============================================================
function UCam.FunV7.teleportToSpawn()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return false end
    
    -- Guardar posición actual
    UCam.Fun.Teleport.LastPosition = UCam.rootPart.CFrame
    
    -- Buscar spawn
    local spawnLocation = workspace:FindFirstChild("SpawnLocation") 
        or workspace:FindFirstChildOfClass("SpawnLocation")
    
    if spawnLocation then
        UCam.rootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 5, 0)
        return true
    end
    
    -- Fallback: teleport a 0,50,0
    UCam.rootPart.CFrame = CFrame.new(0, 50, 0)
    return true
end

function UCam.FunV7.teleportToCoordinates(x, y, z)
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return false end
    
    UCam.Fun.Teleport.LastPosition = UCam.rootPart.CFrame
    UCam.rootPart.CFrame = CFrame.new(x, y, z)
    return true
end

function UCam.FunV7.teleportToCameraTarget()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not workspace.CurrentCamera then return false end
    
    local camera = workspace.CurrentCamera
    local ray = Ray.new(camera.CFrame.Position, camera.CFrame.LookVector * 500)
    local hit, position = workspace:FindPartOnRay(ray, UCam.character)
    
    if hit then
        UCam.Fun.Teleport.LastPosition = UCam.rootPart.CFrame
        UCam.rootPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
        return true
    end
    
    return false
end

function UCam.FunV7.teleportBack()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.Fun.Teleport.LastPosition then return false end
    
    UCam.rootPart.CFrame = UCam.Fun.Teleport.LastPosition
    return true
end

-- ============================================================
-- v7: FLY (Volar con el personaje)
-- ============================================================
function UCam.FunV7.enableFly()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.humanoid then return false end
    
    -- Crear BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.Name = "UCamFlyVelocity"
    bv.MaxForce = Vector3.new(4000, 4000, 4000)
    bv.Velocity = Vector3.zero
    bv.Parent = UCam.rootPart
    UCam.Fun.Fly._bodyVelocity = bv
    
    -- Crear BodyGyro
    local bg = Instance.new("BodyGyro")
    bg.Name = "UCamFlyGyro"
    bg.MaxTorque = Vector3.new(4000, 4000, 4000)
    bg.CFrame = UCam.rootPart.CFrame
    bg.P = 9000
    bg.Parent = UCam.rootPart
    UCam.Fun.Fly._bodyGyro = bg
    
    UCam.Fun.Fly.Enabled = true
    UCam.startFun()
    
    return true
end

function UCam.FunV7.disableFly()
    if UCam.Fun.Fly._bodyVelocity then
        UCam.Fun.Fly._bodyVelocity:Destroy()
        UCam.Fun.Fly._bodyVelocity = nil
    end
    if UCam.Fun.Fly._bodyGyro then
        UCam.Fun.Fly._bodyGyro:Destroy()
        UCam.Fun.Fly._bodyGyro = nil
    end
    UCam.Fun.Fly.Enabled = false
end

local function funUpdateFly()
    if not UCam.Fun.Fly.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.Fun.Fly._bodyVelocity or not UCam.Fun.Fly._bodyGyro then return end
    
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    -- Dirección de movimiento basada en teclas (v7: usa keybinds personalizables)
    local moveVector = Vector3.zero

    if UCam.isKeybindDown("Forward") then
        moveVector = moveVector + camera.CFrame.LookVector
    end
    if UCam.isKeybindDown("Backward") then
        moveVector = moveVector - camera.CFrame.LookVector
    end
    if UCam.isKeybindDown("Left") then
        moveVector = moveVector - camera.CFrame.RightVector
    end
    if UCam.isKeybindDown("Right") then
        moveVector = moveVector + camera.CFrame.RightVector
    end
    if UCam.isKeybindDown("Up") then
        moveVector = moveVector + Vector3.new(0, 1, 0)
    end
    -- v8.1 FIX: antes usaba Sprint (LeftShift) para bajar; ahora Down (Ctrl)
    if UCam.isKeybindDown("Down") then
        moveVector = moveVector - Vector3.new(0, 1, 0)
    end

    if moveVector.Magnitude > 0 then
        moveVector = moveVector.Unit
    end
    
    UCam.Fun.Fly._bodyVelocity.Velocity = moveVector * UCam.Fun.Fly.Speed
    UCam.Fun.Fly._bodyGyro.CFrame = camera.CFrame
end

-- ============================================================
-- v7: TRAIL MEJORADO (tipos, rainbow, painting)
-- ============================================================
function UCam.FunV7.updateTrail(dt)
    if not UCam.Fun.Trail.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return end

    UCam.Fun.Trail._timer = UCam.Fun.Trail._timer + dt
    local interval = 0.08
    if UCam.Fun.Trail._timer >= interval then
        UCam.Fun.Trail._timer = 0
        
        local p = Instance.new("Part")
        p.Name = "UCamTrail"
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Massless = true
        
        -- Tipo de forma
        if UCam.Fun.Trail.Type == "Ball" then
            p.Shape = Enum.PartType.Ball
            p.Size = Vector3.new(UCam.Fun.Trail.Width, UCam.Fun.Trail.Width, UCam.Fun.Trail.Width)
        elseif UCam.Fun.Trail.Type == "Line" then
            p.Shape = Enum.PartType.Block
            p.Size = Vector3.new(0.2, 0.2, UCam.Fun.Trail.Width)
        elseif UCam.Fun.Trail.Type == "Star" then
            p.Shape = Enum.PartType.Ball
            p.Size = Vector3.new(UCam.Fun.Trail.Width * 0.7, UCam.Fun.Trail.Width * 0.7, UCam.Fun.Trail.Width * 0.7)
            -- Agregar mesh de estrella
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://1290033"
            mesh.Scale = Vector3.new(UCam.Fun.Trail.Width, UCam.Fun.Trail.Width, UCam.Fun.Trail.Width)
            mesh.Parent = p
        elseif UCam.Fun.Trail.Type == "Square" then
            p.Shape = Enum.PartType.Block
            p.Size = Vector3.new(UCam.Fun.Trail.Width, UCam.Fun.Trail.Width, UCam.Fun.Trail.Width)
        end
        
        -- Color (rainbow o fijo)
        if UCam.Fun.Trail.Rainbow then
            local hue = (os.clock() * 60 % 360) / 360
            p.Color = Color3.fromHSV(hue, 1, 1)
        else
            p.Color = UCam.Fun.Trail.Color
        end
        
        p.Material = Enum.Material.Neon
        p.CFrame = UCam.rootPart.CFrame
        p.Parent = workspace
        
        table.insert(UCam.Fun.Trail._parts, { part = p, born = os.clock() })
    end

    -- Limpiar partes viejas (solo si no está en modo painting)
    if not UCam.Fun.Trail.Painting then
        local now = os.clock()
        for i = #UCam.Fun.Trail._parts, 1, -1 do
            local entry = UCam.Fun.Trail._parts[i]
            local age = now - entry.born
            if age >= UCam.Fun.Trail.Duration or not (entry.part and entry.part.Parent) then
                pcall(function() entry.part:Destroy() end)
                table.remove(UCam.Fun.Trail._parts, i)
            else
                local k = 1 - (age / math.max(UCam.Fun.Trail.Duration, 0.05))
                local s = math.max(UCam.Fun.Trail.Width * k, 0.05)
                if UCam.Fun.Trail.Type == "Ball" then
                    entry.part.Size = Vector3.new(s, s, s)
                end
                
                -- Actualizar color si es rainbow
                if UCam.Fun.Trail.Rainbow then
                    local hue = ((now * 60 + i * 10) % 360) / 360
                    entry.part.Color = Color3.fromHSV(hue, 1, 1)
                else
                    entry.part.Color = UCam.Fun.Trail.Color
                end
            end
        end
    else
        -- v9 FIX (fuga de memoria): el modo painting dejaba acumular partes en
        -- workspace sin destruirlas nunca. Ahora se mantiene un tope (300) y se
        -- destruyen las más antiguas cuando se supera, además de limpiar las
        -- huérfanas (destruidas por otra vía).
        local MAX_PAINT_PARTS = 300
        local i = #UCam.Fun.Trail._parts
        while i >= 1 do
            local entry = UCam.Fun.Trail._parts[i]
            if not (entry.part and entry.part.Parent) then
                pcall(function() entry.part:Destroy() end)
                table.remove(UCam.Fun.Trail._parts, i)
            end
            i = i - 1
        end
        while #UCam.Fun.Trail._parts > MAX_PAINT_PARTS do
            local entry = table.remove(UCam.Fun.Trail._parts, 1)
            if entry and entry.part then
                pcall(function() entry.part:Destroy() end)
            end
        end
    end
end

-- ============================================================
-- v7: DISCO FLOOR MEJORADO (formas, luces animadas, espejo)
-- ============================================================
function UCam.FunV7.createDisco()
    UCam.FunV6.destroyDisco()
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.Fun.Disco.Enabled then return end
    
    local part = Instance.new("Part")
    part.Name = "UCamDisco"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.Size = Vector3.new(UCam.Fun.Disco.Size, 0.2, UCam.Fun.Disco.Size)
    part.Color = UCam.Fun.Disco.Color
    part.Material = UCam.Fun.Disco.Mirror and Enum.Material.Glass or Enum.Material.Neon
    part.CFrame = CFrame.new(UCam.rootPart.Position - Vector3.new(0, 3, 0))
    
    -- Forma
    if UCam.Fun.Disco.Shape == "Square" then
        part.Shape = Enum.PartType.Block
    elseif UCam.Fun.Disco.Shape == "Circle" then
        part.Shape = Enum.PartType.Cylinder
        part.Orientation = Vector3.new(0, 0, 90)
    elseif UCam.Fun.Disco.Shape == "Star" or UCam.Fun.Disco.Shape == "Hexagon" then
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        if UCam.Fun.Disco.Shape == "Star" then
            mesh.MeshId = "rbxassetid://1290033"
        else
            mesh.MeshId = "rbxassetid://1033714"
        end
        mesh.Scale = Vector3.new(UCam.Fun.Disco.Size, 1, UCam.Fun.Disco.Size)
        mesh.Parent = part
    end
    
    -- Reflectance si es espejo
    if UCam.Fun.Disco.Mirror then
        part.Reflectance = 0.8
    end
    
    part.Parent = workspace
    UCam.Fun.Disco.Part = part
end

local discoColorTick = 0
function UCam.FunV7.updateDisco(dt)
    if not UCam.Fun.Disco.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then return end
    if not (UCam.Fun.Disco.Part and UCam.Fun.Disco.Part.Parent) then
        UCam.FunV7.createDisco()
        return
    end
    
    pcall(function()
        UCam.Fun.Disco.Part.Size = Vector3.new(UCam.Fun.Disco.Size, 0.2, UCam.Fun.Disco.Size)
        UCam.Fun.Disco.Part.CFrame = CFrame.new(UCam.rootPart.Position - Vector3.new(0, 3, 0))
        
        -- Luces animadas
        if UCam.Fun.Disco.AnimatedLights then
            discoColorTick = discoColorTick + dt
            local hue = (discoColorTick * 60 % 360) / 360
            UCam.Fun.Disco.Part.Color = Color3.fromHSV(hue, 1, 1)
        else
            UCam.Fun.Disco.Part.Color = UCam.Fun.Disco.Color
        end
    end)
end

-- ============================================================
-- v7: ACTUALIZAR funUpdate para incluir nuevas features
-- ============================================================
-- Guardar la función original
local originalFunUpdate = funUpdateCore

function UCam.funUpdate(dt)
    -- Llamar a la original
    if originalFunUpdate then
        originalFunUpdate(dt)
    end
    
    -- v7: Nuevas features
    funUpdateFly()
    UCam.FunV7.updateTrail(dt)
    UCam.FunV7.updateDisco(dt)
end

-- Reemplazar clearTrail para usar la nueva
UCam.FunV6.clearTrail = function()
    for _, entry in ipairs(UCam.Fun.Trail._parts) do
        if entry and entry.part then
            pcall(function() entry.part:Destroy() end)
        end
    end
    table.clear(UCam.Fun.Trail._parts)
    UCam.Fun.Trail._timer = 0
end

-- Reemplazar updateTrail para usar la nueva
UCam.FunV6.updateTrail = UCam.FunV7.updateTrail

-- Reemplazar createDisco para usar la nueva
UCam.FunV6.createDisco = UCam.FunV7.createDisco

-- Reemplazar updateDisco para usar la nueva
UCam.FunV6.updateDisco = UCam.FunV7.updateDisco
