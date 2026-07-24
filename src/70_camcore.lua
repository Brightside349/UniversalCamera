-- ============================================================
-- Universal Camera Pro v6 · 70_camcore
-- Nucleo de camara: toggleFreeCam, CrashZoom, Camera Shake (con
-- patrones), Dutch roll, FOV Pulse, updateCamera (per-frame, 14 modos),
-- enforceCameraState (3 capas), input handler y auto-apply filtros.
--
-- Dependencias: 00_config, 10_utils, 50_spectate, 60_director
-- Expone (UCam.*):
--   toggleFreeCam, startCrashZoom, updateCrashZoom, triggerShake,
--   updateCamera, enforceCameraState, triggerTransition,
--   applyDutchRoll, setHudHidden, setCharacterHidden
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- HUD HIDDEN (lo necesita toggleFreeCam y los toggles de Inicio)
-- ============================================================
local customHudPaths = {
    "GameUI.Menu.Settings.Ability.Bar",
    "GameUI.Menu.Settings.Game.SurvivorHP",
    "Main.Game.Teams.Teammate",
    "Round.Game.SurvivorHP",
    "Round.Game.Ability",
    "Round.Game.Time",
    "Round.Game.SurvivorHP.AmyCards",
    "Round.Game.Teams",
    "InGameUI",
}

local function setCustomHudHidden(hidden)
    local playerGui = UCam.player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    for _, path in ipairs(customHudPaths) do
        local current = playerGui
        local found = true
        for part in string.gmatch(path, "[^%.]+") do
            current = current:FindFirstChild(part)
            if not current then
                found = false; break
            end
        end
        if found and current then
            if current:IsA("GuiObject") then
                current.Visible = not hidden
            elseif current:IsA("LayerCollector") then
                current.Enabled = not hidden
            end
        end
    end
end

function UCam.setHudHidden(hidden)
    UCam.Hud.Hidden = hidden
    pcall(function()
        UCam.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not hidden)
    end)
    setCustomHudHidden(hidden)
end

function UCam.setCharacterHidden(hidden)
    UCam.Hud.CharacterHidden = hidden
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    if hidden then
        for _, part in ipairs(UCam.character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                if UCam.Hud.Transparencies[part] == nil then
                    UCam.Hud.Transparencies[part] = part.Transparency
                end
                pcall(function() part.Transparency = 1 end)
            end
        end
    else
        for part, trans in pairs(UCam.Hud.Transparencies) do
            if part and part.Parent then
                pcall(function() part.Transparency = trans end)
            end
        end
        UCam.Hud.Transparencies = {}
    end
end

-- ============================================================
-- TRIGGER TRANSITION (forward-declared en 00_config, asignado aqui)
-- FIX v4: NO usar `local function` aqui (sino upvalue capturado en
-- toggleFreeCam/startSpectate queda en nil).
-- ============================================================
UCam.triggerTransition = function()
    UCam.CameraTransition.FromCF = UCam.camera.CFrame
    UCam.CameraTransition.Active = true
    UCam.CameraTransition.Elapsed = 0
end

-- ============================================================
-- FREECAM: TOGGLE
-- ============================================================
function UCam.toggleFreeCam()
    if UCam.Spectate.Active then
        UCam.stopSpectate()
        return
    end

    UCam.freeCamEnabled = not UCam.freeCamEnabled

    if UCam.freeCamEnabled then
        UCam.triggerTransition()
        UCam.camCFrame = UCam.camera.CFrame
        UCam.syncFreeLookFromCFrame(UCam.camCFrame)
        UCam.currentVelocity                = Vector3.new()
        UCam.Saved.FOV                      = UCam.camera.FieldOfView
        UCam.camera.CameraSubject           = nil
        UCam.camera.CameraType              = Enum.CameraType.Scriptable
        UCam.camera.CFrame                  = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        UCam.rightMouseHeld                 = false
        UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UCam.freezeCharacter()
        -- NUEVO v6: Auto-HUD
        if UCam.AutoHUD.Enabled and not UCam.Hud.Hidden then
            UCam.Saved._hudHiddenBeforeFreeCam = true
            UCam.setHudHidden(true)
        end
        UCam.refreshCharacterRefs()
        if UCam.rootPart then UCam.Dolly.Center = UCam.rootPart.Position else UCam.Dolly.Center = UCam.camCFrame.Position end
        UCam.notify("Universal Camera", "Camara libre activada.")
    else
        UCam.refreshCharacterRefs()
        UCam.camera.CameraType = Enum.CameraType.Custom
        if UCam.humanoid then UCam.camera.CameraSubject = UCam.humanoid end
        UCam.camera.FieldOfView             = UCam.Saved.FOV
        UCam.rightMouseHeld                 = false
        UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UCam.unfreezeCharacter()
        if UCam.Hud.Hidden then UCam.setHudHidden(false) end
        UCam.Saved._hudHiddenBeforeFreeCam = false
        if UCam.Hud.CharacterHidden then UCam.setCharacterHidden(false) end
        if UCam.SlowMo.BulletTime then UCam.toggleBulletTime(false) end
        UCam.destroyLetterbox()
        UCam.destroyVignetteGui()
        UCam.notify("Universal Camera", "Camara libre desactivada.")
    end
end

-- ============================================================
-- CRASH ZOOM
-- ============================================================
function UCam.startCrashZoom()
    if not UCam.freeCamEnabled then
        UCam.notify("Crash Zoom", "Activa la camara libre primero.")
        return
    end
    if UCam.CrashZoom.Playing then
        UCam.notify("Crash Zoom", "Ya hay una animacion en curso.")
        return
    end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart then
        UCam.notify("Crash Zoom", "No hay personaje para apuntar.")
        return
    end

    UCam.CrashZoom.StartCF   = UCam.camCFrame
    UCam.CrashZoom.StartFOV  = UCam.camera.FieldOfView
    UCam.CrashZoom.Playing   = true
    UCam.CrashZoom.StartedAt = os.clock()

    UCam.notify("Crash Zoom", "Dolly-in iniciado.")
end

function UCam.updateCrashZoom()
    if not UCam.CrashZoom.Playing then return end
    UCam.refreshCharacterRefs()
    if not UCam.rootPart or not UCam.CrashZoom.StartCF then
        UCam.CrashZoom.Playing = false
        return
    end

    local elapsed      = os.clock() - UCam.CrashZoom.StartedAt
    local t            = UCam.clamp(elapsed / UCam.CrashZoom.Duration, 0, 1)
    local ease         = UCam.getEasingFn("Smooth")(t)

    local headPos      = UCam.rootPart.Position + Vector3.new(0, 1.5, 0)
    local startCF      = UCam.CrashZoom.StartCF
    local toPos        = headPos - startCF.LookVector * 4 + Vector3.new(0, 0.5, 0)
    local targetCF     = CFrame.lookAt(toPos, headPos)
    local fromCF       = startCF
    local blended      = fromCF:Lerp(targetCF, ease)
    UCam.camCFrame     = blended

    UCam.camera.CFrame      = UCam.camCFrame
    UCam.camera.FieldOfView = UCam.CrashZoom.StartFOV + (UCam.CrashZoom.EndFOV - UCam.CrashZoom.StartFOV) * ease

    if t >= 1 then
        UCam.CrashZoom.Playing = false
        UCam.notify("Crash Zoom", "Dolly-in completo. Mueve la camara para salir.")
    end
end

-- ============================================================
-- CAMERA SHAKE (con patrones)
-- ============================================================
local noise1, noise2, noise3 = 0, 0, 0

local function applyShakeToCF(baseCF, dt)
    if not UCam.Shake.Enabled then return baseCF, 0 end
    local amp = UCam.Shake.Intensity * 0.05

    local t = os.clock()
    if UCam.Shake.Pattern == "Sutil" then
        noise1 = noise1 + dt * 1.6
        noise2 = noise2 + dt * 2.1
        noise3 = noise3 + dt * 0.9
        local ox = math.sin(noise1 * 3.1) * amp * 0.4
        local oy = math.cos(noise2 * 2.4) * amp * 0.3
        local oz = math.sin(noise3 * 4.0) * amp * 0.2
        return baseCF * CFrame.new(ox, oy, oz), math.sin(noise2) * (UCam.Shake.Intensity * 0.005)
    elseif UCam.Shake.Pattern == "Terremoto" then
        noise1 = noise1 + dt * 6.0
        noise2 = noise2 + dt * 5.5
        noise3 = noise3 + dt * 4.0
        local ox = (math.noise(noise1, 0, 0)) * amp * 1.2
        local oy = (math.noise(0, noise2, 0)) * amp * 0.8
        local oz = (math.noise(0, 0, noise3)) * amp * 1.2
        return baseCF * CFrame.new(ox, oy, oz), (math.noise(noise1, noise2) * 0.04 * UCam.Shake.Intensity)
    elseif UCam.Shake.Pattern == "Explosion" then
        noise3 = noise3 + dt
        local decay = math.exp(-noise3 * 1.5)
        local ox = math.sin(noise3 * 22) * amp * 1.6 * decay
        local oy = math.cos(noise3 * 17) * amp * 1.2 * decay
        local oz = math.sin(noise3 * 25) * amp * 1.6 * decay
        if noise3 > 4 then
            UCam.Shake.Enabled = false
            noise3 = 0
            return baseCF, 0
        end
        return baseCF * CFrame.new(ox, oy, oz), decay * 0.03
    elseif UCam.Shake.Pattern == "Pulso" then
        noise1 = noise1 + dt * 3.0
        local pulse = (math.sin(noise1) + 1) * 0.5
        local ox = math.sin(noise1 * 2) * amp * pulse
        local oy = math.cos(noise1 * 1.5) * amp * pulse * 0.7
        local oz = math.sin(noise1 * 2.5) * amp * pulse
        return baseCF * CFrame.new(ox, oy, oz), pulse * 0.015 * UCam.Shake.Intensity
    elseif UCam.Shake.Pattern == "Impacto" then
        if noise3 == 0 then noise3 = 1 end
        local decay = math.exp(-noise3 * 3)
        local ox = (math.noise(noise1, 0, 0)) * amp * 2 * decay
        local oy = (math.noise(0, noise2, 0)) * amp * 1.6 * decay
        local oz = (math.noise(0, 0, noise1)) * amp * 2 * decay
        noise1 = noise1 + dt * 8
        noise2 = noise2 + dt * 7
        noise3 = noise3 + dt
        if noise3 > 1.5 then
            UCam.Shake.Enabled = false
            noise1, noise2, noise3 = 0, 0, 0
            return baseCF, 0
        end
        return baseCF * CFrame.new(ox, oy, oz), decay * 0.05
    end
    return baseCF, 0
end
UCam.applyShakeToCF = applyShakeToCF

-- Handheld shake
local handNoise1, handNoise2, handNoise3 = 0, 0, 0
local function applyHandheldShake(baseCF, dt)
    if not UCam.Handheld.Enabled then return baseCF, 0 end
    local amp = UCam.Handheld.Intensity * 0.03
    local freq = UCam.Handheld.Frequency

    handNoise1 = handNoise1 + dt * freq * 1.8
    handNoise2 = handNoise2 + dt * freq * 2.2
    handNoise3 = handNoise3 + dt * freq * 1.1

    local ox = math.sin(handNoise1 * 2.5) * amp * 0.5
    local oy = math.cos(handNoise2 * 2.0) * amp * 0.4
    local oz = math.sin(handNoise3 * 3.0) * amp * 0.3
    local roll = math.sin(handNoise2 * 0.8) * math.rad(UCam.Handheld.Roll * 1.2)

    return baseCF * CFrame.new(ox, oy, oz) * CFrame.Angles(0, 0, roll), math.sin(handNoise2) * (UCam.Handheld.Intensity * 0.002)
end

function UCam.triggerShake(pattern)
    UCam.Shake.Enabled = true
    UCam.Shake.Pattern = pattern or "Sutil"
    noise1, noise2, noise3 = 0, 0, 0
    UCam.notify("Camera Shake", "Patron: " .. UCam.Shake.Pattern)
end

-- ============================================================
-- DUTCH ROLL
-- ============================================================
function UCam.applyDutchRoll(cf)
    if UCam.dutchRoll == 0 then return cf end
    return cf * CFrame.Angles(0, 0, UCam.dutchRoll)
end

-- ============================================================
-- AUTO-FOCUS DOF
-- ============================================================
local function updateAutoFocus()
    if not UCam.DOF.Enabled or not UCam.AutoFocusDOF.Enabled then return end
    local targetPos
    if UCam.Spectate.Active and UCam.Spectate.Target and UCam.Spectate.Target.Character then
        local root = UCam.getCharacterRoot(UCam.Spectate.Target.Character)
        if root then targetPos = root.Position end
    elseif UCam.freeCamEnabled then
        if UCam.camMode == "Libre" or UCam.camMode == "Handheld" or UCam.camMode == "Roll Axis" then
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            raycastParams.FilterDescendantsInstances = {UCam.character or workspace, UCam.camera}
            local result = workspace:Raycast(UCam.camera.CFrame.Position, UCam.camera.CFrame.LookVector * 500, raycastParams)
            if result then
                UCam.DOF.FocusDistance = UCam.clamp((UCam.camera.CFrame.Position - result.Position).Magnitude, 1, 200)
                UCam.applyDOF()
                return
            end
        else
            UCam.refreshCharacterRefs()
            local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position or (UCam.rootPart and UCam.rootPart.Position)
            if pivot then targetPos = pivot end
        end
    end
    if targetPos then
        local dist = (UCam.camera.CFrame.Position - targetPos).Magnitude
        UCam.DOF.FocusDistance = UCam.clamp(dist, 1, 200)
        UCam.applyDOF()
    end
end
UCam.updateAutoFocus = updateAutoFocus

-- ============================================================
-- UPDATE CAMARA (núcleo de render) - 14 modos
-- ============================================================
local fovPulseT = 0

local function applyTransitionBlend()
    if not UCam.CameraTransition.Active then return end
    UCam.CameraTransition.Elapsed = UCam.CameraTransition.Elapsed + 0 -- (se incrementa en caller)
end

function UCam.updateCamera(deltaTime)
    if UCam.Spectate.Active then
        UCam.updateSpectateCamera(deltaTime)

        if UCam.CameraTransition.Active then
            UCam.CameraTransition.Elapsed = UCam.CameraTransition.Elapsed + deltaTime
            local t = UCam.clamp(UCam.CameraTransition.Elapsed / UCam.CameraTransition.Duration, 0, 1)
            local ease = UCam.getEasingFn("Smooth")(t)
            UCam.camCFrame = UCam.CameraTransition.FromCF:Lerp(UCam.camCFrame, ease)
            UCam.camera.CFrame = UCam.camCFrame
            if t >= 1 then
                UCam.CameraTransition.Active = false
            end
        end
        updateAutoFocus()
        return
    end

    if UCam.camMode == "Director" and UCam.Director.Active then
        UCam.updateDirector(deltaTime)

        if UCam.CameraTransition.Active then
            UCam.CameraTransition.Elapsed = UCam.CameraTransition.Elapsed + deltaTime
            local t = UCam.clamp(UCam.CameraTransition.Elapsed / UCam.CameraTransition.Duration, 0, 1)
            local ease = UCam.getEasingFn("Smooth")(t)
            UCam.camCFrame = UCam.CameraTransition.FromCF:Lerp(UCam.camCFrame, ease)
            UCam.camera.CFrame = UCam.camCFrame
            if t >= 1 then
                UCam.CameraTransition.Active = false
            end
        end
        updateAutoFocus()
        return
    end

    if not UCam.freeCamEnabled or not UCam.camCFrame then return end

    if UCam.camMode == "Libre" then
        UCam.moveCamera(deltaTime)
        UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        UCam.holdCharacterPosition()
        UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
    elseif UCam.camMode == "Orbita" then
        UCam.refreshCharacterRefs()
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            UCam.Orbit.Angle    = UCam.Orbit.Angle + (deltaTime * UCam.Orbit.Speed)
            local target   = pivot + Vector3.new(0, 2, 0)
            local totalYaw = UCam.Orbit.Angle + UCam.Orbit.ManualYaw
            local hDist    = UCam.Orbit.Distance * math.cos(UCam.Orbit.ManualPitch)
            local offset   = Vector3.new(
                math.sin(totalYaw) * hDist,
                UCam.Orbit.Height + math.sin(UCam.Orbit.ManualPitch) * UCam.Orbit.Distance,
                math.cos(totalYaw) * hDist
            )
            UCam.camCFrame      = CFrame.lookAt(target + offset, target)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    elseif UCam.camMode == "Tripode" then
        UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        UCam.holdCharacterPosition()
        UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
    elseif UCam.camMode == "Cenital" then
        UCam.refreshCharacterRefs()
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            UCam.Orbit.Angle  = UCam.Orbit.Angle + (deltaTime * UCam.Orbit.Speed)
            local yaw    = UCam.Orbit.Angle + UCam.Orbit.ManualYaw
            local dist   = UCam.Orbit.Distance
            local h      = UCam.Orbit.Height
            local offset = Vector3.new(
                math.sin(yaw) * dist,
                h,
                math.cos(yaw) * dist
            )
            UCam.camCFrame    = CFrame.lookAt(pivot + offset, pivot)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    elseif UCam.camMode == "Lateral" then
        UCam.refreshCharacterRefs()
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            local yaw     = UCam.Orbit.Angle + UCam.Orbit.ManualYaw
            local hrp     = UCam.rootPart
            local pivotCF = hrp and hrp.CFrame or CFrame.new(pivot)
            local right   = pivotCF.RightVector
            local forward = pivotCF.LookVector
            local camPos  = pivot
                + right * UCam.Lateral.Side * UCam.Lateral.Distance
                + Vector3.new(0, UCam.Lateral.Height, 0)
                + forward * (math.sin(yaw) * 2)
            local lookAt  = pivot + Vector3.new(0, 1.5, 0)
            UCam.camCFrame     = CFrame.lookAt(camPos, lookAt)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    elseif UCam.camMode == "Dron" then
        UCam.refreshCharacterRefs()
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            UCam.Orbit.Angle    = UCam.Orbit.Angle + (deltaTime * UCam.Orbit.Speed)
            local totalYaw = UCam.Orbit.Angle + UCam.Orbit.ManualYaw
            local bobY     = math.sin(os.clock() * 0.6) * UCam.DronePath.BobAmount
            local dist     = UCam.Orbit.Distance
            local target   = pivot + Vector3.new(0, 2 + bobY, 0)
            local offset
            if UCam.DronePath.Mode == "Figura 8" then
                local u = totalYaw
                local x = dist * math.cos(u)
                local z = dist * math.sin(u) * math.cos(u)
                local yPx = UCam.Orbit.Height + math.sin(UCam.Orbit.ManualPitch) * dist
                offset = Vector3.new(x, yPx, z)
            else
                local hDist = dist * math.cos(UCam.Orbit.ManualPitch)
                offset = Vector3.new(
                    math.sin(totalYaw) * hDist,
                    UCam.Orbit.Height + math.sin(UCam.Orbit.ManualPitch) * dist + bobY * 0.5,
                    math.cos(totalYaw) * hDist
                )
            end
            UCam.camCFrame = CFrame.lookAt(target + offset, target)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    elseif UCam.camMode == "Follow" then
        UCam.refreshCharacterRefs()
        local pivotCF = UCam.Saved.RootCFrame or (UCam.rootPart and UCam.rootPart.CFrame)
        if pivotCF then
            local back    = -pivotCF.LookVector
            local right   = pivotCF.RightVector
            local camPos  = pivotCF.Position
                + back * UCam.Follow.Distance
                + right * UCam.Follow.SideOffset
                + Vector3.new(0, UCam.Follow.Height, 0)
            local lookAt  = pivotCF.Position + pivotCF.LookVector * 8 + Vector3.new(0, 1.5, 0)
            UCam.camCFrame     = CFrame.lookAt(camPos, lookAt)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    elseif UCam.camMode == "CrashZoom" then
        UCam.updateCrashZoom()
    elseif UCam.camMode == "Vertigo" then
        UCam.refreshCharacterRefs()
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            UCam.Vertigo.Phase = UCam.Vertigo.Phase + deltaTime * UCam.Vertigo.Speed
            local osc    = (math.sin(UCam.Vertigo.Phase) + 1) * 0.5
            local dist   = UCam.Vertigo.MinDistance + (UCam.Vertigo.MaxDistance - UCam.Vertigo.MinDistance) * osc
            local target = pivot + Vector3.new(0, 2, 0)
            local pitch  = UCam.clamp(UCam.Orbit.ManualPitch, math.rad(-60), math.rad(60))
            local yaw    = UCam.Orbit.ManualYaw
            local hDist  = dist * math.cos(pitch)
            local offset = Vector3.new(
                math.sin(yaw) * hDist,
                dist * math.sin(pitch),
                math.cos(yaw) * hDist
            )
            UCam.camCFrame = CFrame.lookAt(target + offset, target)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
            local baseDist = (UCam.Vertigo.MinDistance + UCam.Vertigo.MaxDistance) * 0.5
            local baseTan  = math.tan(math.rad(UCam.clamp(UCam.Vertigo.BaseFOV, 10, 120)) * 0.5)
            local fov      = math.deg(2 * math.atan(baseTan * baseDist / math.max(dist, 0.5)))
            UCam.camera.FieldOfView = UCam.clamp(fov, UCam.MIN_FOV, UCam.MAX_FOV)
        end
    elseif UCam.camMode == "Crane" then
        UCam.refreshCharacterRefs()
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            local vStep = UCam.currentSpeed * deltaTime * 0.4
            if UCam.UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UCam.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                UCam.Crane.Height = UCam.clamp(UCam.Crane.Height + vStep, UCam.Crane.MinHeight, UCam.Crane.MaxHeight)
            end
            if UCam.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                UCam.Crane.Height = UCam.clamp(UCam.Crane.Height - vStep, UCam.Crane.MinHeight, UCam.Crane.MaxHeight)
            end
            UCam.Crane.Angle       = UCam.Crane.Angle + (UCam.Crane.AutoSpin and deltaTime * UCam.Crane.SpinSpeed or 0)
            local yaw         = UCam.Crane.Angle + UCam.Orbit.ManualYaw
            local dist        = UCam.Orbit.Distance
            local h           = UCam.Crane.Height
            local pitchOffset = math.sin(UCam.Orbit.ManualPitch) * 0.2
            local offset      = Vector3.new(
                math.sin(yaw) * dist,
                h,
                math.cos(yaw) * dist
            )
            local camPos      = pivot + offset
            local lookAt      = pivot + Vector3.new(0, 2 + pitchOffset, 0)
            UCam.camCFrame         = CFrame.lookAt(camPos, lookAt)
            UCam.holdCharacterPosition()
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    elseif UCam.camMode == "Dolly Glide" then
        UCam.refreshCharacterRefs()
        if not UCam.Dolly.Center then
            UCam.Dolly.Center = (UCam.rootPart and UCam.rootPart.Position) or UCam.camCFrame.Position
        end
        local t = os.clock() * 0.35
        if UCam.Dolly.AutoReverse then
            t = (math.sin(t * math.pi * 0.5) + 1) * 0.5
        end
        local phaseRad = t * math.pi * 2
        local dist     = UCam.Dolly.Distance
        local pivotCF  = (UCam.rootPart and UCam.rootPart.CFrame) or CFrame.new(UCam.Dolly.Center)
        local right    = pivotCF.RightVector
        local forward  = pivotCF.LookVector

        local offset
        if UCam.Dolly.Axis == "Lateral" then
            offset = right * math.sin(phaseRad) * dist
        elseif UCam.Dolly.Axis == "Forward" then
            offset = forward * math.sin(phaseRad) * dist + Vector3.new(0, math.sin(phaseRad * 0.5) * 2, 0)
        else
            offset = (right + forward) * math.sin(phaseRad) * dist * 0.7
                + Vector3.new(0, math.sin(phaseRad * 0.7) * 1.5, 0)
        end

        local camPos = UCam.Dolly.Center + Vector3.new(0, 4, 0) + offset
        local lookAt = UCam.Dolly.Center + Vector3.new(0, 2, 0)
        UCam.camCFrame    = CFrame.lookAt(camPos, lookAt)
        if UCam.Orbit.ManualYaw ~= 0 or UCam.Orbit.ManualPitch ~= 0 then
            UCam.camCFrame = UCam.camCFrame * CFrame.fromOrientation(-UCam.Orbit.ManualPitch, UCam.Orbit.ManualYaw, 0)
        end
        UCam.holdCharacterPosition()
        UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
    elseif UCam.camMode == "Handheld" then
        UCam.moveCamera(deltaTime)
        UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        UCam.holdCharacterPosition()
        local shakenCF, fovDelta = applyHandheldShake(UCam.camCFrame, deltaTime)
        UCam.camera.CFrame = UCam.applyDutchRoll(shakenCF)
        if fovDelta ~= 0 then
            UCam.camera.FieldOfView = UCam.clamp(UCam.camera.FieldOfView + fovDelta, UCam.MIN_FOV, UCam.MAX_FOV)
        end
    elseif UCam.camMode == "Roll Axis" then
        UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        UCam.holdCharacterPosition()
        if UCam.RollAxis.Auto then
            UCam.RollAxis.Accumulated = UCam.RollAxis.Accumulated + math.rad(UCam.RollAxis.Speed * UCam.RollAxis.Direction) * deltaTime
        else
            UCam.RollAxis.Accumulated = 0
        end
        local cf = UCam.camCFrame * CFrame.Angles(0, 0, UCam.RollAxis.Accumulated + UCam.dutchRoll)
        UCam.camera.CFrame = cf
    end

    -- EFECTOS GLOBALES
    if UCam.camMode ~= "Handheld" and UCam.Shake.Enabled then
        local shakenCF, fovDelta = applyShakeToCF(UCam.camera.CFrame, deltaTime)
        UCam.camera.CFrame = shakenCF
        if fovDelta ~= 0 then
            UCam.camera.FieldOfView = UCam.clamp(UCam.camera.FieldOfView + fovDelta, UCam.MIN_FOV, UCam.MAX_FOV)
        end
    end

    if UCam.FovPulse.Enabled then
        fovPulseT = fovPulseT + deltaTime
        local osc = math.sin(fovPulseT * UCam.FovPulse.Speed * math.pi) * UCam.FovPulse.Amplitude
        UCam.camera.FieldOfView = UCam.clamp(UCam.camera.FieldOfView + osc * deltaTime * 6, UCam.MIN_FOV, UCam.MAX_FOV)
    end

    if UCam.CameraTransition.Active then
        UCam.CameraTransition.Elapsed = UCam.CameraTransition.Elapsed + deltaTime
        local t = UCam.clamp(UCam.CameraTransition.Elapsed / UCam.CameraTransition.Duration, 0, 1)
        local ease = UCam.getEasingFn("Smooth")(t)
        UCam.camCFrame = UCam.CameraTransition.FromCF:Lerp(UCam.camCFrame, ease)
        UCam.camera.CFrame = UCam.camCFrame
        if t >= 1 then
            UCam.CameraTransition.Active = false
        end
    end

    -- LOOKAT LOCK (Gimbal) - v4
    if UCam.LookAtLock.Enabled and UCam.LookAtLock.Target and (UCam.camMode == "Libre" or UCam.camMode == "Handheld" or UCam.camMode == "Crane") then
        local targetPos
        local targetObj = UCam.LookAtLock.Target
        pcall(function()
            if targetObj:IsA("Model") then
                local root = UCam.getCharacterRoot(targetObj)
                if root then targetPos = root.Position + Vector3.new(0, UCam.LookAtLock.HeightOffset, 0) end
            elseif targetObj:IsA("BasePart") then
                targetPos = targetObj.Position
            elseif targetObj:IsA("Player") and targetObj.Character then
                local root = UCam.getCharacterRoot(targetObj.Character)
                if root then targetPos = root.Position + Vector3.new(0, UCam.LookAtLock.HeightOffset, 0) end
            end
        end)

        if targetPos then
            local targetCF = CFrame.lookAt(UCam.camCFrame.Position, targetPos)
            UCam.syncFreeLookFromCFrame(targetCF)
            if UCam.LookAtLock.Smoothing > 0 then
                local alpha = UCam.clamp(deltaTime * UCam.LookAtLock.Smoothing, 0, 1)
                UCam.camCFrame = UCam.camCFrame:Lerp(targetCF, alpha)
            else
                UCam.camCFrame = targetCF
            end
            UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
        end
    end

    updateAutoFocus()
end

-- ============================================================
-- ENFORCE CAMERA STATE (3 capas anti-jitter)
-- ============================================================
function UCam.enforceCameraState()
    if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
    if not UCam.camCFrame then return end
    pcall(function()
        if UCam.camera.CameraType ~= Enum.CameraType.Scriptable then
            UCam.camera.CameraType = Enum.CameraType.Scriptable
        end
        if UCam.camera.CameraSubject ~= nil then
            UCam.camera.CameraSubject = nil
        end
        UCam.camera.CFrame = UCam.camCFrame
    end)
end

-- ============================================================
-- BIND RENDER STEPS + ENFORCEMENT
-- ============================================================
UCam.RunService:BindToRenderStep("UCamRender",  Enum.RenderPriority.Camera.Value + 1, UCam.updateCamera)
UCam.RunService:BindToRenderStep("UCamEnforce", Enum.RenderPriority.Last.Value,         UCam.enforceCameraState)

-- Slow-mo corre en Heartbeat (no RenderStepped) para no chocar con el render.
do
    local lastTick = 0
    UCam.RunService.Heartbeat:Connect(function(dt)
        if not UCam.SlowMo.BulletTime then return end
        local interval = 1 / math.max(15, UCam.SlowMo.TickRate or 30)
        lastTick = lastTick + dt
        if lastTick < interval then return end
        while lastTick >= interval do lastTick = lastTick - interval end
        UCam.updateSlowMo(interval)
    end)
end

UCam.camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
    if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
    if UCam.camera.CameraSubject ~= nil then UCam.camera.CameraSubject = nil end
end)

UCam.camera:GetPropertyChangedSignal("CameraType"):Connect(function()
    if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
    if UCam.camera.CameraType ~= Enum.CameraType.Scriptable then
        UCam.camera.CameraType = Enum.CameraType.Scriptable
    end
end)

UCam.RunService.RenderStepped:Connect(function()
    if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
    task.defer(function()
        if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
        pcall(function()
            if UCam.camera.CameraType ~= Enum.CameraType.Scriptable then
                UCam.camera.CameraType = Enum.CameraType.Scriptable
            end
            if UCam.camera.CameraSubject ~= nil then UCam.camera.CameraSubject = nil end
            if UCam.camCFrame then UCam.camera.CFrame = UCam.camCFrame end
        end)
    end)
end)

-- ============================================================
-- INPUT: MouseButton2 (rotacion), MouseWheel (FOV)
-- ============================================================
UCam.UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
    local canRotate = UCam.freeCamEnabled
        or (UCam.Spectate.Active and UCam.Spectate.Mode ~= "Primera persona")
    if not canRotate then return end
    UCam.rightMouseHeld = true
    UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
end)

UCam.UserInputService.InputEnded:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
    UCam.rightMouseHeld = false
    if UCam.freeCamEnabled or UCam.Spectate.Active then
        UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end)

UCam.UserInputService.InputChanged:Connect(function(input)
    if not (UCam.freeCamEnabled or UCam.Spectate.Active) then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if UCam.rightMouseHeld then
            local sens = UCam.MOUSE_SENSITIVITY * 0.005
            if UCam.Spectate.Active then
                if UCam.Spectate.Mode ~= "Primera persona" then
                    UCam.Spectate.Yaw   = UCam.Spectate.Yaw - input.Delta.X * sens
                    UCam.Spectate.Pitch = UCam.clamp(
                        UCam.Spectate.Pitch - input.Delta.Y * sens,
                        math.rad(-60), math.rad(60)
                    )
                end
            else
                UCam.applyCameraRotation(input.Delta)
            end
        end
    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        local newFov = UCam.camera.FieldOfView - (input.Position.Z * 3)
        UCam.camera.FieldOfView = UCam.clamp(newFov, UCam.MIN_FOV, UCam.MAX_FOV)
    end
end)

-- ============================================================
-- RESPAWN: limpia todo al respawnear
-- ============================================================
UCam.player.CharacterAdded:Connect(function(newCharacter)
    if UCam.freeCamEnabled then
        UCam.freeCamEnabled     = false
        UCam.camera.CameraType  = Enum.CameraType.Custom
        UCam.camera.FieldOfView = UCam.Saved.FOV
        if UCam.Hud.Hidden then UCam.setHudHidden(false) end
        UCam.Saved._hudHiddenBeforeFreeCam = false
        if UCam.Hud.CharacterHidden then UCam.setCharacterHidden(false) end
        if UCam.SlowMo.BulletTime then UCam.toggleBulletTime(false) end
    end
    if UCam.Spectate.Active then
        UCam.Spectate.Active    = false
        UCam.Spectate.Target    = nil
        UCam.Spectate.Yaw       = 0
        UCam.Spectate.Pitch     = 0
        UCam.camera.CameraType  = Enum.CameraType.Custom
        UCam.camera.FieldOfView = UCam.Saved.FOV
        if UCam.Hud.CharacterHidden then UCam.setCharacterHidden(false) end
    end
    if UCam.Director.Active then
        UCam.Director.Active = false
    end

    UCam.Saved.RootCFrame               = nil
    UCam.Saved.RootAnchored             = false
    UCam.Saved.AutoRotate               = true
    UCam.Hud.CharacterHidden            = false
    UCam.Hud.Transparencies             = {}
    UCam.rightMouseHeld                 = false
    UCam.currentVelocity                = Vector3.new()
    UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- v4.2: limpiar efectos de diversion al respawnear
    pcall(function() UCam.stopFun() end)

    UCam.character                      = newCharacter
    UCam.humanoid                       = nil
    UCam.rootPart                       = nil

    task.defer(function()
        UCam.refreshCharacterRefs()
        if UCam.humanoid then UCam.camera.CameraSubject = UCam.humanoid end
        if UCam.SlowMo.BulletTime then UCam.rebuildSlowMoTargets() end
    end)
end)
