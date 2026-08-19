-- ============================================================
-- Universal Camera Pro v8 · 70_camcore
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
-- v10: restauradas para el HUD del juego objetivo. Se aplican de forma
-- segura y guardan el estado original para poder restaurarlo al desactivar.

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
    local player = UCam.player
    local playerGui = player and player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    if hidden then
        for _, path in ipairs(customHudPaths) do
            local current = playerGui
            for part in string.gmatch(path, "[^%.]+") do
                current = current:FindFirstChild(part)
                if not current then break end
            end

            if current and current ~= playerGui then
                if UCam.Hud.CustomStates[current] == nil then
                    if current:IsA("GuiObject") then
                        UCam.Hud.CustomStates[current] = {
                            Kind = "Visible",
                            Value = current.Visible,
                        }
                    elseif current:IsA("LayerCollector") then
                        UCam.Hud.CustomStates[current] = {
                            Kind = "Enabled",
                            Value = current.Enabled,
                        }
                    end
                end
                if current:IsA("GuiObject") then
                    current.Visible = false
                elseif current:IsA("LayerCollector") then
                    current.Enabled = false
                end
            end
        end
    else
        for instance, state in pairs(UCam.Hud.CustomStates) do
            if instance and instance.Parent then
                if state.Kind == "Visible" and instance:IsA("GuiObject") then
                    instance.Visible = state.Value
                elseif state.Kind == "Enabled" and instance:IsA("LayerCollector") then
                    instance.Enabled = state.Value
                end
            end
        end
        UCam.Hud.CustomStates = {}
    end
end

function UCam.setHudHidden(hidden)
    UCam.Hud.Hidden = hidden
    pcall(function()
        UCam.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not hidden)
    end)
    pcall(function()
        setCustomHudHidden(hidden)
    end)
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
-- v8: Debounce para evitar double-toggle cuando se spamea la tecla
local _toggleDebounce = 0
local TOGGLE_DEBOUNCE_SECS = 0.18

-- v8.1 FIX: restauración forzada de la cámara/personaje SIN pasar por
-- el debounce de toggleFreeCam. Unload dentro del debounce dejaba la
-- cámara Scriptable y el personaje anclado (crítico informe).
function UCam.forceRestoreCamera()
    if UCam.freeCamEnabled then
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
        -- v8.1: SlowMo/BulletTime eliminado
        UCam.destroyLetterbox()
        UCam.destroyVignetteGui()
        UCam.freeCamEnabled = false
        -- Reiniciar debounce para evitar toggles fantasma tras Unload
        _toggleDebounce = 0
    end
end

function UCam.toggleFreeCam()
    -- v8: debounce — evita toggles accidentales por doble-pulsación
    local now = tick()
    if now - _toggleDebounce < TOGGLE_DEBOUNCE_SECS then return end
    _toggleDebounce = now

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
        -- v8.1: SlowMo/BulletTime eliminado
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
    -- v9: puede dispararse desde keybind/audio en ráfaga → solo notificar
    -- si el patrón cambia (evita spam de confirmación).
    if UCam.Shake.Pattern ~= UCam.Shake._lastNotifiedPattern then
        UCam.Shake._lastNotifiedPattern = UCam.Shake.Pattern
        UCam.notify("Camera Shake", "Patron: " .. UCam.Shake.Pattern)
    end
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
-- v8: throttle a 10 Hz — antes hacía un raycast de 500 studs
-- cada frame (60 raycasts/seg), ahora 6 raycasts/seg.
-- ============================================================
local AUTOFOCUS_INTERVAL = 0.1  -- segundos entre raycasts
local autoFocusAccum = 0

local function updateAutoFocus(deltaTime)
    if not UCam.DOF.Enabled or not UCam.AutoFocusDOF.Enabled then return end
    autoFocusAccum = autoFocusAccum + (deltaTime or 0)
    if autoFocusAccum < AUTOFOCUS_INTERVAL then return end
    autoFocusAccum = 0

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
            -- v8: refs cacheadas — rootPart puede ser nil si el char murió
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

function UCam.updateCamera(deltaTime)
    -- v7: updateReplay no necesita tick global
    -- porque usa su propio Heartbeat en startPlayback/startRecording.
    -- v8.1: updateTimeControl eliminado — ya no se tickea en cada frame.
    -- v7: transiciones de filtro / temporal
    if UCam.updateFilters then
        pcall(UCam.updateFilters, deltaTime)
    end

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
        updateAutoFocus(deltaTime)
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
        updateAutoFocus(deltaTime)
        return
    end

    -- v9 FIX: durante la reproducción de Replay el Heartbeat del replay
    -- controla la cámara; el freecam no debe pisarle el CFrame cada frame.
    if UCam.Replay and UCam.Replay.Playing then
        updateAutoFocus(deltaTime)
        return
    end

    if not UCam.freeCamEnabled or not UCam.camCFrame then return end

    if UCam.camMode == "Libre" then
        UCam.moveCamera(deltaTime)
        UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        UCam.holdCharacterPosition()
        UCam.camera.CFrame = UCam.applyDutchRoll(UCam.camCFrame)
    elseif UCam.camMode == "Orbita" then
        -- v8: refs cacheadas (mantenidas por CharacterAdded/Removing en 10_utils)
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
        local pivot = UCam.Saved.RootCFrame and UCam.Saved.RootCFrame.Position
            or (UCam.rootPart and UCam.rootPart.Position)
        if pivot then
            local vStep = UCam.currentSpeed * deltaTime * 0.4
            if UCam.isKeybindDown("Up") and not UCam.isKeybindDown("Sprint") then
                UCam.Crane.Height = UCam.clamp(UCam.Crane.Height + vStep, UCam.Crane.MinHeight, UCam.Crane.MaxHeight)
            end
            if UCam.isKeybindDown("Down") then
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
    elseif UCam.camMode == "FPV Dron" then
        -- v7: dron FPV con inercia y roll extremo al girar
        UCam.moveCamera(deltaTime)
        UCam.holdCharacterPosition()
        local pos = UCam.camCFrame.Position
        local newCF = UCam.buildFreeCameraCFrame(pos)
        -- Inercia: lerp entre la CFrame anterior y la nueva
        local inertia = UCam.clamp(UCam.FPVDrone.Inertia or 0.85, 0, 0.95)
        UCam.camCFrame = UCam.camCFrame:Lerp(newCF, 1 - inertia)
        -- Roll extremo proporcional a la velocidad de giro del yaw
        UCam.FPVDrone._prevYaw = UCam.FPVDrone._prevYaw or UCam.cameraYaw
        local yawDelta = UCam.cameraYaw - UCam.FPVDrone._prevYaw
        UCam.FPVDrone._prevYaw = UCam.cameraYaw
        local rollRad = math.rad(UCam.clamp(UCam.FPVDrone.MaxRoll or 45, 0, 90))
        local roll = UCam.clamp(-yawDelta * (UCam.FPVDrone.RollSpeed or 120), -rollRad, rollRad)
        UCam.camera.CFrame = UCam.camCFrame * CFrame.Angles(0, 0, roll + UCam.dutchRoll)
    elseif UCam.camMode == "Snorricam" then
        -- v8: refs cacheadas por eventos (10_utils), no reconsultar cada frame
        UCam.holdCharacterPosition()
        if UCam.rootPart then
            local dist = UCam.Snorricam.Distance or 3
            local hOff  = UCam.Snorricam.HeightOffset or 0.5
            -- Posicionar la cámara frente al personaje mirando hacia él
            local lookPos = UCam.rootPart.CFrame.Position + Vector3.new(0, 2 + hOff, 0)
            local camPos  = lookPos + UCam.rootPart.CFrame.LookVector * dist
            if UCam.camCFrame then
                UCam.camCFrame = UCam.camCFrame:Lerp(CFrame.lookAt(camPos, lookPos), UCam.clamp(deltaTime * 15, 0, 1))
            else
                UCam.camCFrame = CFrame.lookAt(camPos, lookPos)
            end
            UCam.camera.CFrame = UCam.camCFrame
        end
    elseif UCam.camMode == "Cable Cam" then
        -- v7: cámara que se mueve en línea recta entre dos puntos (PointA/PointB)
        UCam.holdCharacterPosition()
        local A = UCam.CableCam.PointA
        local B = UCam.CableCam.PointB
        if A and B then
            UCam.CableCam.Progress = UCam.CableCam.Progress + (UCam.CableCam.Speed or 0.5) * deltaTime
            if UCam.CableCam.Progress > 1 then
                UCam.CableCam.Progress = UCam.Waypoint.Loop and 0 or 1
            end
            local t = UCam.clamp(UCam.CableCam.Progress, 0, 1)
            local pos = A:Lerp(B, t)
            -- Mirar siempre hacia adelante a lo largo del cable
            local lookAt = A:Lerp(B, UCam.clamp(t + 0.01, 0, 1))
            UCam.camCFrame = CFrame.lookAt(pos.Position, lookAt.Position)
            UCam.camera.CFrame = UCam.camCFrame
        else
            -- Auto-configurar: A = posición actual, B = 40 studs hacia adelante
            UCam.CableCam.PointA = UCam.camCFrame or CFrame.new()
            UCam.CableCam.PointB = (UCam.CableCam.PointA or CFrame.new()) * CFrame.new(0, 0, -40)
        end
    elseif UCam.camMode == "Security Cam" then
        -- v7: cámara estática con paneo automático lento
        UCam.holdCharacterPosition()
        UCam.SecurityCam.Phase = UCam.SecurityCam.Phase + (UCam.SecurityCam.PanSpeed or 0.3) * deltaTime
        local anchor = UCam.SecurityCam.Anchor or (UCam.camCFrame and UCam.camCFrame.Position) or Vector3.new(0, 30, 0)
        local halfAngle = math.rad(UCam.SecurityCam.PanAngle or 60)
        local pan = math.sin(UCam.SecurityCam.Phase) * halfAngle
        local lookPos = anchor + CFrame.Angles(0, pan, 0).LookVector * 10
        UCam.camCFrame = CFrame.lookAt(anchor, lookPos)
        UCam.camera.CFrame = UCam.camCFrame
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

    -- v7: Smooth zoom (interpolar FOV hacia el target)
    if UCam.CamCore.SmoothZoom and UCam.CamCore.TargetFOV then
        local cur = UCam.camera.FieldOfView
        local alpha = UCam.clamp(deltaTime * (UCam.CamCore.ZoomSpeed or 10), 0, 1)
        UCam.camera.FieldOfView = UCam.clamp(UCam.lerpNum(cur, UCam.CamCore.TargetFOV, alpha), UCam.MIN_FOV, UCam.MAX_FOV)
        -- v9 FIX: el zoom cambia el FOV base; si no, el MotionBlur tira de
        -- vuelta al FOV obsoleto y ambos efectos pelean.
        if UCam.CamCore._mbBaseFOV then
            UCam.CamCore._mbBaseFOV = UCam.camera.FieldOfView
        end
        if math.abs(UCam.camera.FieldOfView - UCam.CamCore.TargetFOV) < 0.05 then
            UCam.CamCore.TargetFOV = nil
        end
    end

    -- v7: Auto-exposure — ajusta el brillo del ColorCorrection según la
    -- luminosidad promedio mirada (raycast hacia el centro de la pantalla).
    -- v8: throttle a 10 Hz — antes raycast de 200 studs cada frame (60/s).
    if UCam.CamCore.AutoExposure then
        UCam.CamCore._exposureAccum = (UCam.CamCore._exposureAccum or 0) + deltaTime
        if UCam.CamCore._exposureAccum >= 0.1 then
            UCam.CamCore._exposureAccum = 0
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { UCam.character, UCam.camera }
            local r = workspace:Raycast(UCam.camera.CFrame.Position, UCam.camera.CFrame.LookVector * 200, rayParams)
            if r and r.Instance and r.Instance:IsA("BasePart") then
                -- Heurística simple: partes oscuras (grises bajos) suben el brillo
                local c = r.Instance.Color
                local luminance = (c.R + c.G + c.B) / 3
                local target = UCam.clamp((0.5 - luminance) * 0.3, UCam.CamCore.ExposureRange.min, UCam.CamCore.ExposureRange.max)
                UCam.CamCore._exposureTarget = target
            end
        end
        -- Lerp suave hacia el target muestreado (cada frame es barato)
        if UCam.CamCore._exposureTarget then
            local cc = UCam.getColorEffect()
            cc.Brightness = UCam.lerpNum(cc.Brightness or 0, UCam.CamCore._exposureTarget, UCam.clamp(deltaTime * 3, 0, 1))
            cc.Enabled = true
        end
    end

    -- v7: Motion blur simulado — sobrescribe el FOV levemente o usa la viñeta
    -- existente como overlay. Aquí solo engrosamos la viñeta si MB está activo.
    -- (Implementación ligera: no crea GUIs extra para no competir con la viñeta.)
    -- v8.1 FIX: antes solo SUMABA FOV (subía monótonamente hasta MAX_FOV).
    -- Ahora guarda el FOV base y lerp de vuelta al FOV base cuando no hay giro.
    if UCam.CamCore.MotionBlur and not UCam.Spectate.Active then
        if UCam.CamCore._mbBaseFOV == nil then
            UCam.CamCore._mbBaseFOV = UCam.camera.FieldOfView
        end
        local delta = UCam.cameraYaw - (UCam.CamCore._prevYaw or UCam.cameraYaw)
        UCam.CamCore._prevYaw = UCam.cameraYaw
        if math.abs(delta) > 0.02 and UCam.CamCore.MBAmount > 0 then
            local tmp = UCam.CamCore._mbBaseFOV + math.abs(delta) * UCam.CamCore.MBAmount * 5
            UCam.camera.FieldOfView = UCam.clamp(tmp, UCam.MIN_FOV, UCam.MAX_FOV)
        else
            -- Restaurar suavemente al FOV base (lerp de vuelta)
            local cur = UCam.camera.FieldOfView
            local base = UCam.CamCore._mbBaseFOV
            if math.abs(cur - base) > 0.05 then
                UCam.camera.FieldOfView = UCam.lerpNum(cur, base, UCam.clamp(deltaTime * 6, 0, 1))
            end
        end
    else
        UCam.CamCore._mbBaseFOV = nil
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

    updateAutoFocus(deltaTime)
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
-- v8: todas las conexiones se trackean en UCam._connections
-- para que Unload() pueda limpiarlas (antes quedaban huérfanas
-- y recargar el script duplicaba handlers).
-- ============================================================
UCam.trackConnection({ Disconnect = function()
    UCam.RunService:UnbindFromRenderStep("UCamRender")
end }, "BindRender:UCamRender")
UCam.RunService:BindToRenderStep("UCamRender",  Enum.RenderPriority.Camera.Value + 1, UCam.updateCamera)

UCam.trackConnection({ Disconnect = function()
    UCam.RunService:UnbindFromRenderStep("UCamEnforce")
end }, "BindRender:UCamEnforce")
UCam.RunService:BindToRenderStep("UCamEnforce", Enum.RenderPriority.Last.Value,         UCam.enforceCameraState)

-- v8.1: SlowMo/BulletTime eliminado — el heartbeat dedicado ya no existe.

UCam.trackConnection(
    UCam.camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
        if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
        if UCam.camera.CameraSubject ~= nil then UCam.camera.CameraSubject = nil end
    end),
    "PropChange:CameraSubject"
)

UCam.trackConnection(
    UCam.camera:GetPropertyChangedSignal("CameraType"):Connect(function()
        if not (UCam.freeCamEnabled or UCam.Spectate.Active or UCam.Director.Active) then return end
        if UCam.camera.CameraType ~= Enum.CameraType.Scriptable then
            UCam.camera.CameraType = Enum.CameraType.Scriptable
        end
    end),
    "PropChange:CameraType"
)

UCam.trackConnection(
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
    end),
    "RenderStepped:Enforce"
)

-- ============================================================
-- v7: GUARDAR / CARGAR POSICIONES DE CÁMARA (5 slots)
-- ============================================================
function UCam.saveCameraPosition(slot)
    slot = UCam.clamp(math.floor(slot or 1), 1, 5)
    local cf = UCam.camCFrame or UCam.camera.CFrame
    UCam.CamCore.SavedPositions[slot] = cf
    UCam.notify("Cámara", string.format("Posición %d guardada.", slot))
end

function UCam.loadCameraPosition(slot)
    slot = UCam.clamp(math.floor(slot or 1), 1, 5)
    local cf = UCam.CamCore.SavedPositions[slot]
    if not cf then
        UCam.notify("Cámara", string.format("Slot %d vacío.", slot))
        return
    end
    if not UCam.freeCamEnabled then
        UCam.notify("Cámara", "Activa la cámara libre para saltar a la posición.")
        return
    end
    UCam.camCFrame = cf
    if UCam.triggerTransition then UCam.triggerTransition() end
    UCam.camera.CFrame = cf
    UCam.notify("Cámara", string.format("Saltado a posición %d.", slot))
end

-- ============================================================
-- INPUT: MouseButton2 (rotacion), MouseWheel (FOV)
-- v8: conexiones trackeadas en UCam._connections
-- ============================================================
UCam.trackConnection(
    UCam.UserInputService.InputBegan:Connect(function(input, gpe)
        -- v9 FIX (bug UI): ignorar el input si Rayfield ya lo procesó (click
        -- derecho sobre la UI de Rayfield ya no rota la cámara).
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
        local canRotate = UCam.freeCamEnabled
            or (UCam.Spectate.Active and UCam.Spectate.Mode ~= "Primera persona")
        if not canRotate then return end
        UCam.rightMouseHeld = true
        UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    end),
    "Input:MouseB2Began"
)

UCam.trackConnection(
    UCam.UserInputService.InputEnded:Connect(function(input, gpe)
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
        UCam.rightMouseHeld = false
        if UCam.freeCamEnabled or UCam.Spectate.Active then
            UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end),
    "Input:MouseB2Ended"
)

UCam.trackConnection(
    UCam.UserInputService.InputChanged:Connect(function(input, gpe)
        -- v9 FIX (bug UI): ignorar el input si Rayfield lo procesó (la rueda
        -- sobre la UI ya no cambia el FOV ni rota la cámara).
        if gpe then return end
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
            -- v9 FIX (conflicto de rueda): mientras se especta, la rueda
            -- controla la distancia (50_spectate); el FOV queda fuera para
            -- que no cambien las dos cosas a la vez.
            if UCam.Spectate.Active then return end
            local current = UCam.CamCore.TargetFOV or UCam.camera.FieldOfView
            local newFov = current - (input.Position.Z * 3)
            newFov = UCam.clamp(newFov, UCam.MIN_FOV, UCam.MAX_FOV)
            if UCam.CamCore.SmoothZoom then
                -- Smooth zoom: solo actualiza el target; el lerp ocurre en updateCamera
                UCam.CamCore.TargetFOV = newFov
            else
                UCam.camera.FieldOfView = newFov
                UCam.CamCore.TargetFOV = nil
            end
        end
    end),
    "Input:InputChanged"
)

-- ============================================================
-- RESPAWN: limpia todo al respawnear
-- v8: conexión trackeada para cleanup en Unload
-- ============================================================
UCam.trackConnection(
    UCam.player.CharacterAdded:Connect(function(newCharacter)
    if UCam.freeCamEnabled then
        UCam.freeCamEnabled     = false
        UCam.camera.CameraType  = Enum.CameraType.Custom
        UCam.camera.FieldOfView = UCam.Saved.FOV
        if UCam.Hud.Hidden then UCam.setHudHidden(false) end
        UCam.Saved._hudHiddenBeforeFreeCam = false
        if UCam.Hud.CharacterHidden then UCam.setCharacterHidden(false) end
        -- v8.1: SlowMo/BulletTime eliminado
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
    -- forceRestoreCamera ya restauró el snapshot real en unfreezeCharacter.
    UCam.Saved.AutoRotate               = nil
    UCam.Hud.CharacterHidden            = false
    UCam.Hud.Transparencies             = {}
    UCam.rightMouseHeld                 = false
    UCam.currentVelocity                = Vector3.new()
    UCam.UserInputService.MouseBehavior = Enum.MouseBehavior.Default

    -- v4.2: limpiar efectos de diversion al respawnear
    pcall(function() UCam.stopFun() end)

    -- v8 FIX: resetear modificaciones locales aplicadas a OTROS jugadores.
    -- Sin esto, _playerTargets / _snapshots seguían apuntando a personajes
    -- muertos tras el respawn (informe §4) y los efectos no se revertían.
    pcall(function()
        if UCam.restoreAllPlayerPoses then UCam.restoreAllPlayerPoses() end
        if UCam.restoreAllPlayerBodyColors then UCam.restoreAllPlayerBodyColors() end
        if UCam.restoreAllPlayers then UCam.restoreAllPlayers() end
    end)

    UCam.character                      = newCharacter
    UCam.humanoid                       = nil
    UCam.rootPart                       = nil

    task.defer(function()
        UCam.refreshCharacterRefs()
        if UCam.humanoid then UCam.camera.CameraSubject = UCam.humanoid end
        -- v8.1: rebuildSlowMoTargets eliminado
    end)
end),
    "CharacterAdded:Cleanup"
)
