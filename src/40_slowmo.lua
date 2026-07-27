-- ============================================================
-- Universal Camera Pro v6 · 40_slowmo
-- Bullet Time universal: ralentiza humanoides (WalkSpeed/JumpPower
-- locales) y objetos fisicos (CFrame-lerp con filtros que no rompen
-- joints). throttling por TickRate + batch rotativo para no lagear.
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   toggleBulletTime, startSlowMoTracking, stopSlowMoTracking,
--   rebuildSlowMoTargets, updateSlowMo, shouldTrackPart_V3
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- HUMANOS: scale walkSpeed / jumpPower / animSpeed
-- ============================================================
local function captureHumanoidIfNeeded(h)
    if not h or not h:IsA("Humanoid") then return end
    if UCam.SlowMo.Humanoids[h] then return end
    UCam.SlowMo.Humanoids[h] = {
        walkSpeed = h.WalkSpeed,
        jumpPower = h.JumpPower,
    }
end

local function applyHumanoidScale(h, scale)
    if not h or not UCam.SlowMo.Humanoids[h] then return end
    local data = UCam.SlowMo.Humanoids[h]
    if not data.walkSpeed then data.walkSpeed = h.WalkSpeed / math.max(scale, 0.01) end
    if not data.jumpPower then data.jumpPower = h.JumpPower / math.max(scale, 0.01) end
    if h.Parent and h.Health > 0 then
        pcall(function()
            h.WalkSpeed = data.walkSpeed * scale
            h.JumpPower = data.jumpPower * scale
            local animator = h:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:AdjustSpeed(scale)
                end
            end
        end)
    end
end

local function restoreHumanoid(h)
    if not h or not UCam.SlowMo.Humanoids[h] then return end
    local data = UCam.SlowMo.Humanoids[h]
    pcall(function()
        if data.walkSpeed then h.WalkSpeed = data.walkSpeed end
        if data.jumpPower then h.JumpPower = data.jumpPower end
        local animator = h:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:AdjustSpeed(1)
            end
        end
    end)
    UCam.SlowMo.Humanoids[h] = nil
end

local function restoreAllHumanoids()
    for h in pairs(UCam.SlowMo.Humanoids) do
        restoreHumanoid(h)
    end
end

-- ============================================================
-- FILTRO: que partes vale la pena animar en slow-mo
-- (no romper joints ni constraints)
-- ============================================================
function UCam.shouldTrackPart_V3(part)
    if not part:IsA("BasePart") then return false end
    if part.Anchored then return false end
    if part.Size.Magnitude < 0.05 then return false end
    if UCam.isDescendantOf(part, UCam.camera) then return false end
    local pg = UCam.player:FindFirstChild("PlayerGui")
    if pg and UCam.isDescendantOf(part, pg) then return false end

    local model = part:FindFirstAncestorOfClass("Model")
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")

    if humanoid then
        local characterOfHumanoid = humanoid.Parent
        if characterOfHumanoid and UCam.Players:GetPlayerFromCharacter(characterOfHumanoid) == UCam.player then
            if not UCam.SlowMo.AffectsLocal then return false end
        elseif characterOfHumanoid and UCam.Players:GetPlayerFromCharacter(characterOfHumanoid) then
            if not UCam.SlowMo.AffectsOther then return false end
        else
            if not UCam.SlowMo.AffectsNPC then return false end
        end

        if UCam.SlowMo.Scope == "Fisico" then return false end

        return true
    end

    if not UCam.SlowMo.AffectsPhysics then return false end
    if UCam.SlowMo.Scope == "Personajes" or UCam.SlowMo.Scope == "Jugadores" then return false end

    if UCam.SlowMo.Scope == "Fisico" then
        return true
    end

    -- En modo "Mundo", excluir modelos con constraints (preserva joints)
    if model then
        for _, c in ipairs(model:GetChildren()) do
            if c:IsA("Constraint") or c:IsA("Motor6D")
                or c:IsA("RodConstraint") or c:IsA("RopeConstraint")
                or c:IsA("SpringConstraint") or c:IsA("HingeConstraint")
                or c:IsA("BallSocketConstraint") or c:IsA("WeldConstraint") then
                return false
            end
        end
    end
    return true
end

-- Snapshot de las claves de Parts[]. Se reconstruye al activar.
local function refreshPartKeys()
    table.clear(UCam.SlowMo.PartKeys)
    for part in pairs(UCam.SlowMo.Parts) do
        table.insert(UCam.SlowMo.PartKeys, part)
    end
end

function UCam.rebuildSlowMoTargets()
    table.clear(UCam.SlowMo.Parts)
    table.clear(UCam.SlowMo.OriginalCF)
    table.clear(UCam.SlowMo.RealPositions)
    table.clear(UCam.SlowMo.LastSetCFrame)
    table.clear(UCam.SlowMo.PrevRealPositions)

    local radius = UCam.SlowMo.ProcessingRadius
    local camPos = (workspace.CurrentCamera and workspace.CurrentCamera.CFrame)
        and workspace.CurrentCamera.CFrame.Position or Vector3.zero
    local maxParts = math.max(50, UCam.SlowMo.MaxParts)

    -- Captura humanoides primero (rapido)
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") then
            captureHumanoidIfNeeded(d)
        end
    end

    local collected = {}
    local function maybeAdd(inst)
        if not UCam.shouldTrackPart_V3(inst) then return end
        if #collected >= maxParts then return end
        local pos
        pcall(function() pos = inst.Position end)
        if not pos then return end
        if (pos - camPos).Magnitude > radius then return end
        collected[#collected + 1] = inst
    end
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") then
            local model = inst:FindFirstAncestorOfClass("Model")
            if model and model:FindFirstChildOfClass("Humanoid") then
                maybeAdd(inst)
            end
        end
    end
    if #collected < maxParts then
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA("BasePart") then
                local model = inst:FindFirstAncestorOfClass("Model")
                local hasHum = model and model:FindFirstChildOfClass("Humanoid")
                if not hasHum then maybeAdd(inst) end
            end
        end
    end

    for _, inst in ipairs(collected) do
        UCam.SlowMo.Parts[inst]               = inst.CFrame
        UCam.SlowMo.OriginalCF[inst]          = inst.CFrame
        UCam.SlowMo.RealPositions[inst]       = inst.CFrame
        UCam.SlowMo.LastSetCFrame[inst]       = inst.CFrame
        UCam.SlowMo.PrevRealPositions[inst]   = inst.CFrame
    end
    refreshPartKeys()
end

function UCam.stopSlowMoTracking()
    table.clear(UCam.SlowMo.Parts)
    table.clear(UCam.SlowMo.OriginalCF)
    table.clear(UCam.SlowMo.RealPositions)
    table.clear(UCam.SlowMo.LastSetCFrame)
    table.clear(UCam.SlowMo.PrevRealPositions)
    table.clear(UCam.SlowMo.PartKeys)
    UCam.SlowMo.BatchIndex = 0
    UCam.SlowMo.TickAccum  = 0
    if UCam.SlowMo.DescendantConn then
        UCam.SlowMo.DescendantConn:Disconnect()
        UCam.SlowMo.DescendantConn = nil
    end
    if UCam.SlowMo.CharacterAdded then
        UCam.SlowMo.CharacterAdded:Disconnect()
        UCam.SlowMo.CharacterAdded = nil
    end
    restoreAllHumanoids()
    table.clear(UCam.SlowMo.Humanoids)
end

function UCam.startSlowMoTracking()
    UCam.rebuildSlowMoTargets()
    if UCam.SlowMo.DescendantConn then UCam.SlowMo.DescendantConn:Disconnect() end
    UCam.SlowMo.DescendantConn = workspace.DescendantAdded:Connect(function(inst)
        if not UCam.SlowMo.BulletTime then return end
        if inst:IsA("Humanoid") then
            captureHumanoidIfNeeded(inst)
        elseif UCam.shouldTrackPart_V3(inst) then
            if #UCam.SlowMo.PartKeys >= UCam.SlowMo.MaxParts then return end
            local camPos = (workspace.CurrentCamera and workspace.CurrentCamera.CFrame)
                and workspace.CurrentCamera.CFrame.Position or Vector3.zero
            local ok, pos = pcall(function() return inst.Position end)
            if ok and pos and (pos - camPos).Magnitude <= UCam.SlowMo.ProcessingRadius then
                UCam.SlowMo.Parts[inst]              = inst.CFrame
                UCam.SlowMo.OriginalCF[inst]         = inst.CFrame
                UCam.SlowMo.RealPositions[inst]      = inst.CFrame
                UCam.SlowMo.LastSetCFrame[inst]      = inst.CFrame
                UCam.SlowMo.PrevRealPositions[inst]  = inst.CFrame
                table.insert(UCam.SlowMo.PartKeys, inst)
            end
        end
    end)

    if UCam.SlowMo.CharacterAdded then UCam.SlowMo.CharacterAdded:Disconnect() end
    UCam.SlowMo.CharacterAdded = UCam.Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(char)
            if not UCam.SlowMo.BulletTime then return end
            task.defer(function()
                local h = char and char:FindFirstChildOfClass("Humanoid")
                if h then captureHumanoidIfNeeded(h) end
                if char then
                    for _, child in ipairs(char:GetDescendants()) do
                        if UCam.shouldTrackPart_V3(child) then
                            UCam.SlowMo.Parts[child]              = child.CFrame
                            UCam.SlowMo.OriginalCF[child]         = child.CFrame
                            UCam.SlowMo.RealPositions[child]      = child.CFrame
                            UCam.SlowMo.LastSetCFrame[child]      = child.CFrame
                            UCam.SlowMo.PrevRealPositions[child]  = child.CFrame
                        end
                    end
                    refreshPartKeys()
                end
            end)
        end)
    end)
    for _, plr in ipairs(UCam.Players:GetPlayers()) do
        if plr.Character then
            local h = plr.Character:FindFirstChildOfClass("Humanoid")
            if h then captureHumanoidIfNeeded(h) end
        end
    end
end

-- ============================================================
-- UPDATE: humanoides cada frame, fisicas throttled + batch
-- ============================================================
local function humanoidScale()
    if UCam.SlowMo.Freeze then return 0.05 end
    local t = UCam.clamp(UCam.SlowMo.Intensity, 0, 100) / 100
    return UCam.clamp(1 - t * 0.95, 0.05, 1)
end

local function slowLerpAlpha()
    if UCam.SlowMo.Freeze then return 0.0 end
    local t = UCam.clamp(UCam.SlowMo.Intensity, 0, 100) / 100
    return UCam.clamp(t, 0, 1)
end

local function isLocalPlayerHumanoid(h)
    local char = h.Parent
    return char and UCam.Players:GetPlayerFromCharacter(char) == UCam.player
end

local function isOtherPlayerHumanoid(h)
    local char = h.Parent
    if not char then return false end
    local p = UCam.Players:GetPlayerFromCharacter(char)
    return p ~= nil and p ~= UCam.player
end

function UCam.updateSlowMo(deltaTime)
    if not UCam.SlowMo.BulletTime then return end

    UCam.SlowMo.TickAccum = UCam.SlowMo.TickAccum + deltaTime
    local step = math.max(1, UCam.SlowMo.TickStep or 1)

    -- (A) Escala humanoides
    local scale = humanoidScale()
    local toRestore = {}
    if scale < 1 then
        for h in pairs(UCam.SlowMo.Humanoids) do
            local skip = false
            if isLocalPlayerHumanoid(h) and not UCam.SlowMo.AffectsLocal then skip = true end
            if isOtherPlayerHumanoid(h) and not UCam.SlowMo.AffectsOther then skip = true end
            if (not isLocalPlayerHumanoid(h) and not isOtherPlayerHumanoid(h)) and not UCam.SlowMo.AffectsNPC then skip = true end
            if UCam.SlowMo.Scope == "Fisico" then skip = true end
            if not skip then
                applyHumanoidScale(h, scale)
            else
                table.insert(toRestore, h)
            end
        end
    else
        for h in pairs(UCam.SlowMo.Humanoids) do
            table.insert(toRestore, h)
        end
    end
    for _, h in ipairs(toRestore) do
        restoreHumanoid(h)
    end

    if not UCam.SlowMo.AffectsPhysics and UCam.SlowMo.Scope ~= "Fisico" then
        return
    end

    -- (B) Throttle de la interpolacion fisica
    UCam.SlowMo.TickClock = UCam.SlowMo.TickClock + deltaTime
    local frameCounter = math.floor(UCam.SlowMo.TickClock / (1/60))
    if (frameCounter % step) ~= 0 then return end

    local keyCount = #UCam.SlowMo.PartKeys
    if keyCount == 0 then return end

    local batchSize = math.max(20, math.min(UCam.SlowMo.BatchSize, keyCount))
    local startIdx  = UCam.SlowMo.BatchIndex
    local endIdx    = math.min(startIdx + batchSize, keyCount)

    local speedFactor = 1 - (UCam.SlowMo.Intensity / 100)
    if UCam.SlowMo.Freeze then speedFactor = 0 end

    local dead = {}

    for i = startIdx + 1, endIdx do
        local part = UCam.SlowMo.PartKeys[i]
        if part and part.Parent then
            if not UCam.shouldTrackPart_V3(part) then
                dead[#dead + 1] = part
            else
                pcall(function()
                    local currentCF  = part.CFrame
                    local lastSetCF  = UCam.SlowMo.LastSetCFrame[part]
                    local realCF     = UCam.SlowMo.RealPositions[part] or currentCF

                    if not lastSetCF or (currentCF.Position - lastSetCF.Position).Magnitude > 0.005 then
                        realCF = currentCF
                    end

                    local prevRealCF   = UCam.SlowMo.PrevRealPositions[part] or realCF
                    local lastRendered = lastSetCF or realCF

                    local displacement        = prevRealCF:Inverse() * realCF
                    local scaledDisplacement  = CFrame.identity:Lerp(displacement, speedFactor)
                    local newRendered         = lastRendered * scaledDisplacement

                    if (realCF.Position - newRendered.Position).Magnitude > 250 then
                        newRendered = realCF
                    end

                    UCam.SlowMo.LastSetCFrame[part]     = newRendered
                    UCam.SlowMo.RealPositions[part]     = realCF
                    UCam.SlowMo.PrevRealPositions[part] = realCF

                    part.CFrame = newRendered
                end)
            end
        else
            dead[#dead + 1] = part
        end
    end

    -- v7: Optimización O(1) para remover partes muertas
    if #dead > 0 then
        for _, p in ipairs(dead) do
            UCam.SlowMo.Parts[p] = nil
            UCam.SlowMo.OriginalCF[p] = nil
            UCam.SlowMo.RealPositions[p] = nil
            UCam.SlowMo.LastSetCFrame[p] = nil
            UCam.SlowMo.PrevRealPositions[p] = nil
            
            -- v7: Swap-with-last O(1) removal en vez de table.remove O(n)
            for j = 1, #UCam.SlowMo.PartKeys do
                if UCam.SlowMo.PartKeys[j] == p then
                    -- Swap con el último elemento
                    UCam.SlowMo.PartKeys[j] = UCam.SlowMo.PartKeys[#UCam.SlowMo.PartKeys]
                    UCam.SlowMo.PartKeys[#UCam.SlowMo.PartKeys] = nil
                    break
                end
            end
        end
        if UCam.SlowMo.BatchIndex >= #UCam.SlowMo.PartKeys then
            UCam.SlowMo.BatchIndex = 0
        end
    end

    UCam.SlowMo.BatchIndex = endIdx
    if UCam.SlowMo.BatchIndex >= #UCam.SlowMo.PartKeys then
        UCam.SlowMo.BatchIndex = 0
        local camPos = (workspace.CurrentCamera and workspace.CurrentCamera.CFrame)
            and workspace.CurrentCamera.CFrame.Position or Vector3.zero
        if #UCam.SlowMo.PartKeys < UCam.SlowMo.MaxParts then
            for _, inst in ipairs(workspace:GetDescendants()) do
                if #UCam.SlowMo.PartKeys >= UCam.SlowMo.MaxParts then break end
                if inst:IsA("BasePart") and not UCam.SlowMo.Parts[inst] and UCam.shouldTrackPart_V3(inst) then
                    local ok, pos = pcall(function() return inst.Position end)
                    if ok and pos and (pos - camPos).Magnitude <= UCam.SlowMo.ProcessingRadius then
                        UCam.SlowMo.Parts[inst]              = inst.CFrame
                        UCam.SlowMo.OriginalCF[inst]         = inst.CFrame
                        UCam.SlowMo.RealPositions[inst]      = inst.CFrame
                        UCam.SlowMo.LastSetCFrame[inst]      = inst.CFrame
                        UCam.SlowMo.PrevRealPositions[inst]  = inst.CFrame
                        table.insert(UCam.SlowMo.PartKeys, inst)
                    end
                end
            end
        end
    end
end

-- ============================================================
-- TOGGLE PRINCIPAL
-- ============================================================
function UCam.toggleBulletTime(state)
    UCam.SlowMo.BulletTime = state
    if state then
        UCam.startSlowMoTracking()
        UCam.notify("Camara Lenta", "Activada (efecto universal).")
    else
        UCam.stopSlowMoTracking()
        UCam.notify("Camara Lenta", "Desactivada.")
    end
end
