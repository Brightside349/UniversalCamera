-- ============================================================
-- Universal Camera Pro v6 · 30_fun
-- Modulo de Diversion (Fun) completo: montar, noclip, gravedad,
-- escala, poses, rainbow, neon, trail, disco, material, invisibilidad.
-- Se aplica localmente (no se envia al server).
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   funAnyActive, funSnapshotCharacter, funRestorePartVisuals,
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

-- Captura tamaños / colores / materiales originales + valores de Humanoid.
-- Se llama la primera vez que se activa un efecto que los modifique.
function UCam.funSnapshotCharacter()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    table.clear(UCam.Fun._origPartSizes)
    table.clear(UCam.Fun._origBodyColors)
    table.clear(UCam.Fun._origMaterials)
    table.clear(UCam.Fun._origParts)
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if part:IsA("BasePart") then
            UCam.Fun._origPartSizes[part]   = part.Size
            UCam.Fun._origBodyColors[part]  = part.Color
            UCam.Fun._origMaterials[part]   = part.Material
            table.insert(UCam.Fun._origParts, part)
        end
    end
    if UCam.humanoid and UCam.Fun._savedWalkSpeed == nil then
        UCam.Fun._savedWalkSpeed  = UCam.humanoid.WalkSpeed
        UCam.Fun._savedJumpPower  = UCam.humanoid.JumpPower
        UCam.Fun._savedAutoRotate = UCam.humanoid.AutoRotate
    end
end

function UCam.funRestorePartVisuals()
    for part, size in pairs(UCam.Fun._origPartSizes) do
        if part and part.Parent then
            pcall(function() part.Size = size end)
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

-- Escala: multiplica el Size de cada parte. Persistente hasta que se desactive.
function UCam.funApplyScale(scale)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    if not next(UCam.Fun._origPartSizes) then UCam.funSnapshotCharacter() end
    for part, origSize in pairs(UCam.Fun._origPartSizes) do
        if part and part.Parent then
            pcall(function() part.Size = origSize * scale end)
        end
    end
    UCam.Fun._currentScale = scale
    if UCam.rootPart and scale > 1.0 then
        local origRootSize = UCam.Fun._origPartSizes[UCam.rootPart]
        if origRootSize then
            local extra = (origRootSize.Y * (scale - 1)) * 0.5
            pcall(function() UCam.rootPart.CFrame = UCam.rootPart.CFrame + Vector3.new(0, extra, 0) end)
        end
    end
end

-- ============================================================
-- PER-FRAME UPDATES
-- ============================================================
local function funUpdateNoclip()
    if not UCam.Fun.Noclip.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = false end)
        end
    end
end

local function funUpdateMount(dt)
    if not UCam.Fun.Mount.Enabled or not UCam.Fun.Mount.Target then return end
    UCam.refreshCharacterRefs()
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
    UCam.refreshCharacterRefs()
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

local function funUpdateRainbow(dt)
    if not UCam.Fun.Rainbow.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    UCam.Fun._rainbowTick = UCam.Fun._rainbowTick + dt * UCam.Fun.Rainbow.Speed
    -- FIX v4.2: Color3.fromHSV espera el hue normalizado 0-1, no 0-360
    local hueDegrees = (UCam.Fun._rainbowTick * 60) % 360
    local hue        = hueDegrees / 360
    local color = Color3.fromHSV(hue, 1, 1)
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
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
-- POSE FORZADA (T-Pose ragdoll / globo / sentado / flotando) — v4.3
-- FIX v4.3: usar PlatformStand en vez de ChangeState (que se revierte solo)
-- y forzar cada Motor6D a Transform identidad cada frame.
-- ============================================================
local function funApplyRestPose()
    if not UCam.character then return end
    for _, joint in ipairs(UCam.character:GetDescendants()) do
        if joint:IsA("Motor6D") then
            pcall(function() joint.Transform = CFrame.new() end)
        end
    end
end

local function funFreezeControl()
    if not UCam.character or not UCam.humanoid or not UCam.rootPart then return false end
    if UCam.Fun._tposeSetupDone then return true end

    -- 1. Apagar scripts de animacion
    for _, s in ipairs(UCam.character:GetDescendants()) do
        if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
            pcall(function() s.Disabled = true end)
        end
    end

    -- 2. Frenar animaciones en curso
    local animator = UCam.humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0) end)
        end
    end

    -- 3. PlatformStand = true: apaga WASD/auto-balance de forma persistente
    pcall(function()
        UCam.humanoid.PlatformStand = true
        UCam.humanoid.AutoRotate    = false
    end)

    -- 4. Desanclar el root
    pcall(function() UCam.rootPart.Anchored = false end)

    -- 5. Colision en todas las partes
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.CanCollide = true end)
        end
    end

    UCam.Fun._tposeSetupDone = true
    return true
end

local function funUnfreezeControl()
    if not UCam.Fun._tposeSetupDone then return end
    UCam.refreshCharacterRefs()
    if UCam.character then
        for _, s in ipairs(UCam.character:GetDescendants()) do
            if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
                pcall(function() s.Disabled = false end)
            end
        end
    end
    if UCam.humanoid then
        pcall(function()
            UCam.humanoid.PlatformStand = false
            UCam.humanoid.AutoRotate    = true
            UCam.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    UCam.Fun._tposeSetupDone = false
end

local function funUpdatePose(dt)
    if UCam.Fun.Pose.Mode == "Normal" then
        if UCam.Fun._tposeSetupDone then funUnfreezeControl() end
        return
    end
    UCam.refreshCharacterRefs()
    if not UCam.humanoid or not UCam.character or not UCam.rootPart then return end
    if not funFreezeControl() then return end

    if UCam.Fun.Pose.Mode == "T-Pose" then
        funApplyRestPose()
        pcall(function()
            local v          = UCam.rootPart.AssemblyLinearVelocity
            local floatForce = UCam.Fun.Pose.FloatForce or 0
            local dampXZ     = UCam.Fun.Pose.DampXZ or 0.92
            UCam.rootPart.AssemblyLinearVelocity = Vector3.new(
                v.X * dampXZ,
                floatForce,
                v.Z * dampXZ
            )
        end)
    elseif UCam.Fun.Pose.Mode == "Sentado" then
        pcall(function() UCam.humanoid.Sit = true end)
        pcall(function()
            local v = UCam.rootPart.AssemblyLinearVelocity
            UCam.rootPart.AssemblyLinearVelocity = Vector3.new(v.X * 0.85, v.Y, v.Z * 0.85)
        end)
    elseif UCam.Fun.Pose.Mode == "Flotando" then
        pcall(function()
            local v = UCam.rootPart.AssemblyLinearVelocity
            if v.Y < 1 then
                UCam.rootPart.AssemblyLinearVelocity = v + Vector3.new(0, 4 * dt, 0)
            end
        end)
    end
end

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

function UCam.FunV6.applyMaterial(name)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    local enumMat = Enum.Material[name]
    if not enumMat then return end
    if not next(UCam.Fun._origMaterials) then UCam.funSnapshotCharacter() end
    UCam.Fun.Material.Current = name
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.Material = enumMat end)
        end
    end
end

function UCam.FunV6.updateInvisibility()
    if not UCam.Fun.Invisibility.Enabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    for _, part in ipairs(UCam.character:GetDescendants()) do
        if (part:IsA("BasePart") or part:IsA("Decal")) and part.Transparency < 1 then
            pcall(function() part.Transparency = 1 end)
        end
    end
end

-- ============================================================
-- UPDATE MAESTRO + START/STOP
-- ============================================================
function UCam.funUpdate(dt)
    funUpdateNoclip()
    funUpdateRainbow(dt)
    funUpdateNeonGlow()
    funUpdateSpeed()
    funUpdateJump()
    funUpdatePose(dt)
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
        or UCam.Fun.Pose.Mode ~= "Normal"
end

local function stopFun()
    if UCam.Fun._connHeartbeat then
        UCam.Fun._connHeartbeat:Disconnect()
        UCam.Fun._connHeartbeat = nil
    end
    funUnfreezeControl()
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
    UCam.Fun.Pose.Mode          = "Normal"
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
