-- ============================================================
-- Universal Camera Pro v6 · 50_spectate
-- Modo espectador: 9 estilos de camara sobre el objetivo, auto-ciclo
-- y navegacion rapida Q/E.
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   startSpectate, stopSpectate, updateSpectateCamera,
--   spectateNextPlayer, spectatePrevPlayer,
--   getCharacterRoot, getCharacterHead
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- HELPERS DE PERSONAJE
-- ============================================================
function UCam.getCharacterRoot(char)
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    if char.PrimaryPart then return char.PrimaryPart end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("BasePart") then return v end
    end
    return nil
end

function UCam.getCharacterHead(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("BasePart") and v.Name:lower():find("head") then return v end
    end
    return nil
end

local function initSpectateYawFromCharacter(char)
    local hrp = UCam.getCharacterRoot(char)
    if not hrp then return end
    local look = hrp.CFrame.LookVector
    UCam.Spectate.Yaw = math.atan2(-look.X, -look.Z)
end

-- ============================================================
-- CALCULO DE CFrame segun el modo
-- ============================================================
local function computeSpectateCFrame(char)
    local hrp = UCam.getCharacterRoot(char)
    if not hrp then return nil end

    local head    = UCam.getCharacterHead(char)
    local rootPos = hrp.Position
    local rootCF  = hrp.CFrame

    if UCam.Spectate.Mode == "Primera persona" then
        if head then
            return head.CFrame * CFrame.new(0, 0.2, 0)
        else
            return rootCF * CFrame.new(0, 1.5, 0)
        end
    elseif UCam.Spectate.Mode == "Tercera persona" then
        local dist    = UCam.Spectate.Distance
        local h       = UCam.Spectate.Height
        local yaw     = UCam.Spectate.Yaw
        local pitch   = UCam.clamp(UCam.Spectate.Pitch, math.rad(-60), math.rad(60))

        local hDist   = dist * math.cos(pitch)
        local offsetX = hDist * math.sin(yaw)
        local offsetY = dist * math.sin(pitch) + h
        local offsetZ = hDist * math.cos(yaw)

        local camPos  = rootPos + Vector3.new(offsetX, offsetY, offsetZ)
        local lookAt  = rootPos + Vector3.new(0, 1.5, 0)

        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 0.5, 0.5)
        end

        return CFrame.lookAt(camPos, lookAt)
    elseif UCam.Spectate.Mode == "Cinematico" then
        local t      = os.clock() * 0.35
        local dist   = UCam.Spectate.Distance
        local h      = UCam.Spectate.Height
        local camPos = rootPos + Vector3.new(
            math.sin(t) * dist,
            h,
            math.cos(t) * dist
        )
        local lookAt = rootPos + Vector3.new(0, 1.5, 0)
        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 0.5, 0.5)
        end
        return CFrame.lookAt(camPos, lookAt)
    elseif UCam.Spectate.Mode == "Sobre hombro" then
        local rootYaw    = math.atan2(-rootCF.LookVector.X, -rootCF.LookVector.Z)
        local dist       = 4
        local camPos     = rootPos
            + Vector3.new(math.sin(rootYaw) * dist, 1.8, math.cos(rootYaw) * dist)
            + rootCF.RightVector * 1.5

        local lookTarget = rootPos + rootCF.LookVector * 10 + Vector3.new(0, 1.5, 0)

        if (camPos - lookTarget).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 0.5, 0.5)
        end
        return CFrame.lookAt(camPos, lookTarget)

    elseif UCam.Spectate.Mode == "Dron aereo" then
        local dist   = UCam.Spectate.Distance
        local h      = math.max(UCam.Spectate.Height, 8)
        local yaw    = UCam.Spectate.Yaw
        local bobY   = math.sin(os.clock() * 0.6) * 1.0
        local camPos = rootPos + Vector3.new(
            math.sin(yaw) * dist * 0.3,
            h + bobY,
            math.cos(yaw) * dist * 0.3
        )
        local lookAt = rootPos + Vector3.new(0, 1, 0)
        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 1, 0)
        end
        return CFrame.lookAt(camPos, lookAt)

    elseif UCam.Spectate.Mode == "Contrapicado" then
        local yaw    = UCam.Spectate.Yaw
        local dist   = UCam.Spectate.Distance * 0.5
        local camPos = rootPos + Vector3.new(
            math.sin(yaw) * dist,
            -0.5,
            math.cos(yaw) * dist
        )
        local lookAt = rootPos + Vector3.new(0, 2.5, 0)
        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, -0.5, 0.5)
        end
        return CFrame.lookAt(camPos, lookAt)

    elseif UCam.Spectate.Mode == "Dolly lateral" then
        local right    = rootCF.RightVector
        local forward  = rootCF.LookVector
        local dist     = UCam.Spectate.Distance
        local sway     = math.sin(os.clock() * 0.3) * 3
        local camPos   = rootPos
            + right * dist
            + Vector3.new(0, UCam.Spectate.Height, 0)
            + forward * sway
        local lookAt   = rootPos + Vector3.new(0, 1.5, 0) + forward * 4
        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 0.5, 0.5)
        end
        return CFrame.lookAt(camPos, lookAt)

    elseif UCam.Spectate.Mode == "Orbita dinamica" then
        local t       = os.clock() * 0.4
        local baseDst = UCam.Spectate.Distance
        local baseH   = UCam.Spectate.Height
        local dist    = baseDst + math.sin(t * 0.7) * baseDst * 0.3
        local h       = baseH + math.sin(t * 0.5) * baseH * 0.4
        local camPos  = rootPos + Vector3.new(
            math.sin(t) * dist,
            h,
            math.cos(t) * dist
        )
        local lookAt  = rootPos + Vector3.new(0, 1.5, 0)
        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 0.5, 0.5)
        end
        return CFrame.lookAt(camPos, lookAt)

    elseif UCam.Spectate.Mode == "Steadicam" then
        local back    = -rootCF.LookVector
        local dist    = UCam.Spectate.Distance
        local h       = UCam.Spectate.Height
        local camPos  = rootPos + back * dist + Vector3.new(0, h, 0)
        local lookAt  = rootPos + rootCF.LookVector * 5 + Vector3.new(0, 1.5, 0)
        if (camPos - lookAt).Magnitude < 0.5 then
            camPos = camPos + Vector3.new(0, 0.5, 0.5)
        end
        return CFrame.lookAt(camPos, lookAt)
    end

    return CFrame.lookAt(rootPos + Vector3.new(0, 8, 0), rootPos)
end
UCam.computeSpectateCFrame = computeSpectateCFrame

-- ============================================================
-- LISTA / BUSQUEDA DE JUGADORES
-- ============================================================
local function getPlayerLabels()
    local labels = {}
    for _, p in ipairs(UCam.Players:GetPlayers()) do
        if p ~= UCam.player then
            table.insert(labels, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    table.sort(labels)
    return labels
end
UCam.getPlayerLabels = getPlayerLabels

local function findPlayerByLabel(label)
    for _, p in ipairs(UCam.Players:GetPlayers()) do
        if p.DisplayName .. " (@" .. p.Name .. ")" == label then
            return p
        end
    end
end
UCam.findPlayerByLabel = findPlayerByLabel

-- ============================================================
-- START / STOP / UPDATE
-- ============================================================
function UCam.stopSpectate()
    if not UCam.Spectate.Active then return end
    UCam.Spectate.Active = false
    UCam.Spectate.Target = nil
    UCam.Spectate.Yaw    = 0
    UCam.Spectate.Pitch  = 0

    UCam.refreshCharacterRefs()
    pcall(function()
        UCam.camera.CameraType    = Enum.CameraType.Custom
        UCam.camera.CameraSubject = UCam.humanoid or UCam.player.Character
        UCam.camera.FieldOfView   = UCam.Saved.FOV
    end)

    if UCam.Hud.CharacterHidden then UCam.setCharacterHidden(false) end

    task.defer(function()
        if not UCam.UIRefs.PlayerDropdown then return end
        local labels = getPlayerLabels()
        if #labels == 0 then
            pcall(function() UCam.UIRefs.PlayerDropdown:Refresh({ "(Sin otros jugadores)" }) end)
        else
            table.insert(labels, 1, "(Selecciona uno)")
            pcall(function() UCam.UIRefs.PlayerDropdown:Refresh(labels) end)
        end
    end)
end

function UCam.startSpectate(targetPlayer)
    if not targetPlayer or targetPlayer == UCam.player then return end

    local char     = targetPlayer.Character
    local charRoot = char and UCam.getCharacterRoot(char)

    if not char or not charRoot then
        UCam.notify("Espectador", "Ese jugador no tiene personaje activo.")
        return
    end

    if UCam.freeCamEnabled then
        UCam.freeCamEnabled  = false
        UCam.currentVelocity = Vector3.new()
        UCam.refreshCharacterRefs()
        pcall(function()
            UCam.camera.CameraType    = Enum.CameraType.Custom
            UCam.camera.CameraSubject = UCam.humanoid
            UCam.camera.FieldOfView   = UCam.Saved.FOV
        end)
    end

    if UCam.Spectate.Active then
        UCam.Spectate.Target = targetPlayer
        UCam.Spectate.Yaw    = 0
        UCam.Spectate.Pitch  = 0
        if UCam.Spectate.Mode == "Tercera persona" then
            initSpectateYawFromCharacter(char)
        end
        local cf = computeSpectateCFrame(char)
        if cf then
            if UCam.triggerTransition then UCam.triggerTransition() end
            UCam.camCFrame = cf
            UCam.camera.CFrame = cf
        end
        UCam.notify("Espectador", "Cambiado a: " .. targetPlayer.DisplayName)
        return
    end

    UCam.Saved.FOV       = UCam.camera.FieldOfView
    UCam.Spectate.Active = true
    UCam.Spectate.Target = targetPlayer
    UCam.Spectate.Yaw    = 0
    UCam.Spectate.Pitch  = 0

    if UCam.Spectate.Mode == "Tercera persona" then
        initSpectateYawFromCharacter(char)
    end

    pcall(function()
        UCam.camera.CameraType    = Enum.CameraType.Scriptable
        UCam.camera.CameraSubject = nil
    end)

    if UCam.Spectate.HideSelf then UCam.setCharacterHidden(true) end
    if UCam.Spectate.UseCustomFOV then UCam.camera.FieldOfView = UCam.Spectate.FOV end

    local cf = computeSpectateCFrame(char)
    if not cf then
        cf = CFrame.new(charRoot.Position + Vector3.new(0, 6, 0), charRoot.Position)
    end

    if UCam.triggerTransition then UCam.triggerTransition() end
    UCam.camCFrame     = cf
    UCam.camera.CFrame = cf

    UCam.notify("Espectador", "Viendo a " .. targetPlayer.DisplayName)
end

-- ============================================================
-- NAVEGACION RAPIDA Q / E
-- ============================================================
local function getSpectablePlayers()
    local list = {}
    for _, p in ipairs(UCam.Players:GetPlayers()) do
        if p ~= UCam.player and p.Character and UCam.getCharacterRoot(p.Character) then
            table.insert(list, p)
        end
    end
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end

function UCam.spectateNextPlayer()
    local list = getSpectablePlayers()
    if #list == 0 then
        UCam.notify("Espectador", "No hay jugadores disponibles.")
        return
    end
    local currentIdx = 0
    if UCam.Spectate.Target then
        for i, p in ipairs(list) do
            if p == UCam.Spectate.Target then currentIdx = i; break end
        end
    end
    local nextIdx = (currentIdx % #list) + 1
    UCam.startSpectate(list[nextIdx])
end

function UCam.spectatePrevPlayer()
    local list = getSpectablePlayers()
    if #list == 0 then
        UCam.notify("Espectador", "No hay jugadores disponibles.")
        return
    end
    local currentIdx = 0
    if UCam.Spectate.Target then
        for i, p in ipairs(list) do
            if p == UCam.Spectate.Target then currentIdx = i; break end
        end
    end
    local prevIdx = currentIdx - 1
    if prevIdx < 1 then prevIdx = #list end
    UCam.startSpectate(list[prevIdx])
end

-- ============================================================
-- UPDATE: suaviza la camara segun el modo
-- ============================================================
function UCam.updateSpectateCamera(deltaTime)
    if not UCam.Spectate.Active or not UCam.Spectate.Target then return end

    if UCam.AutoCycle.Enabled then
        UCam.AutoCycle.Elapsed = UCam.AutoCycle.Elapsed + deltaTime
        if UCam.AutoCycle.Elapsed >= UCam.AutoCycle.Interval then
            UCam.AutoCycle.Elapsed = 0
            UCam.spectateNextPlayer()
            return
        end
    end

    local char     = UCam.Spectate.Target.Character
    local charRoot = char and UCam.getCharacterRoot(char)
    if not char or not charRoot then
        UCam.notify("Espectador", UCam.Spectate.Target.DisplayName .. " perdio su personaje.")
        UCam.stopSpectate()
        return
    end

    local targetCF = computeSpectateCFrame(char)
    if not targetCF then
        targetCF = CFrame.new(charRoot.Position + Vector3.new(0, 8, 0), charRoot.Position)
    end

    if UCam.Spectate.Mode == "Primera persona" then
        local fastAlpha = UCam.clamp(deltaTime * 30, 0, 1)
        UCam.camCFrame = UCam.camCFrame:Lerp(targetCF, fastAlpha)
    elseif UCam.Spectate.Mode == "Sobre hombro" then
        local fastAlpha = UCam.clamp(deltaTime * 22, 0, 1)
        UCam.camCFrame = UCam.camCFrame:Lerp(targetCF, fastAlpha)
    elseif UCam.Spectate.Mode == "Steadicam" then
        local slowAlpha = UCam.clamp(deltaTime * 4, 0, 1)
        UCam.camCFrame = UCam.camCFrame:Lerp(targetCF, slowAlpha)
    elseif UCam.Spectate.Mode == "Dolly lateral" then
        local medAlpha = UCam.clamp(deltaTime * 8, 0, 1)
        UCam.camCFrame = UCam.camCFrame:Lerp(targetCF, medAlpha)
    else
        local alpha = UCam.clamp(deltaTime * UCam.Spectate.Smoothing, 0, 1)
        UCam.camCFrame   = UCam.camCFrame:Lerp(targetCF, alpha)
    end

    UCam.camera.CFrame = UCam.camCFrame
    if UCam.Spectate.UseCustomFOV then UCam.camera.FieldOfView = UCam.Spectate.FOV end
end
