-- ============================================================
-- Universal Camera Pro v7 · 45_timecontrol
-- Control de Tiempo expandido: Time Ramp (curvas de velocidad),
-- Frame-by-Frame, Fast Forward local, Audio Slow-Mo y VFX
-- automáticos al activar bullet time.
--
-- Dependencias: 00_config, 10_utils, 40_slowmo
-- Expone (UCam.*):
--   startTimeRamp, stopTimeRamp, updateTimeControl,
--   toggleFrameByFrame, advanceFrame,
--   toggleFastForward, stopTimeControl,
--   applyAudioSlowMo, restoreAudioSlowMo,
--   applyBulletTimeVFX, removeBulletTimeVFX
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- CONSTANTES
-- ============================================================
-- Curvas de ramp: { {t_normalizado, velocidad_escala}, ... }
-- t=0 es inicio del ramp, t=1 es final.
local RAMP_CURVES = {
    ["Impacto"] = {
        { 0,    1.0  },  -- velocidad normal
        { 0.15, 2.5  },  -- aceleración rápida
        { 0.3,  0.05 },  -- bullet time profundo
        { 0.7,  0.05 },  -- mantenemos slow
        { 0.85, 2.0  },  -- salida rápida
        { 1,    1.0  },  -- de vuelta a normal
    },
    ["Gradual"] = {
        { 0,   1.0  },
        { 0.4, 0.5  },
        { 0.6, 0.08 },
        { 1,   0.08 },   -- se queda en slow (el usuario lo desactiva)
    },
    ["Matrix Bullet"] = {
        { 0,    1.0  },
        { 0.05, 0.02 },  -- caída instantánea
        { 0.5,  0.02 },  -- mantenemos extremo
        { 0.55, 0.3  },  -- salida parcial
        { 0.7,  1.2  },  -- rebote rápido
        { 1,    1.0  },
    },
}

-- VFX: ChromaticAberration overlay y viñeta de intensidad en bullet time
local _chromaGui  = nil
local _chromaFrame = nil

-- ============================================================
-- HELPERS
-- ============================================================
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Interpola en la curva piecewise
local function sampleCurve(curve, t)
    t = math.clamp(t, 0, 1)
    for i = 1, #curve - 1 do
        local p0 = curve[i]
        local p1 = curve[i + 1]
        if t >= p0[1] and t <= p1[1] then
            local span = p1[1] - p0[1]
            if span < 0.0001 then return p0[2] end
            local alpha = (t - p0[1]) / span
            return lerp(p0[2], p1[2], alpha)
        end
    end
    return curve[#curve][2]
end

-- ============================================================
-- TIME RAMP
-- ============================================================
function UCam.startTimeRamp()
    if UCam.TimeControl.RampEnabled then return end
    UCam.TimeControl.RampEnabled = true
    UCam.TimeControl.RampStartTime = tick()

    -- Aseguramos que SlowMo esté en tracking para que el ramp lo maneje
    if not UCam.SlowMo.BulletTime then
        UCam.SlowMo.BulletTime = true
        UCam.startSlowMoTracking()
    end

    if UCam.TimeControl.VFXOnBulletTime then
        UCam.applyBulletTimeVFX()
    end

    UCam.notify("Control de Tiempo", "Time Ramp activado: " .. UCam.TimeControl.RampPreset)
end

function UCam.stopTimeRamp()
    if not UCam.TimeControl.RampEnabled then return end
    UCam.TimeControl.RampEnabled = false

    -- Restaurar SlowMo a estado normal
    UCam.SlowMo.Intensity = 0
    UCam.SlowMo.BulletTime = false
    UCam.stopSlowMoTracking()

    UCam.removeBulletTimeVFX()
    UCam.notify("Control de Tiempo", "Time Ramp finalizado.")
end

-- ============================================================
-- FRAME BY FRAME
-- ============================================================
function UCam.toggleFrameByFrame(state)
    UCam.TimeControl.FrameByFrame = state

    if state then
        -- Congelar: Intensity = 100 + Freeze = true
        UCam.SlowMo.Intensity = 100
        UCam.SlowMo.Freeze = true
        if not UCam.SlowMo.BulletTime then
            UCam.SlowMo.BulletTime = true
            UCam.startSlowMoTracking()
        end
        UCam.notify("Frame-by-Frame", "Congelado. Usa 'Avanzar Frame' para continuar.")
    else
        UCam.SlowMo.Freeze = false
        UCam.SlowMo.Intensity = 0
        UCam.SlowMo.BulletTime = false
        UCam.stopSlowMoTracking()
        UCam.notify("Frame-by-Frame", "Desactivado. Reproducción normal.")
    end
end

-- Avanza la simulación un "frame" (un pequeño tick hacia adelante)
-- Se llama manualmente desde el botón de la UI
function UCam.advanceFrame()
    if not UCam.TimeControl.FrameByFrame then return end

    -- Temporalmente desactivar el freeze para un frame
    UCam.SlowMo.Freeze = false
    UCam.SlowMo.Intensity = 85   -- avance lento pero visible

    task.delay(1/30, function()
        -- Re-aplicar freeze después de un frame
        UCam.SlowMo.Freeze = true
        UCam.SlowMo.Intensity = 100
    end)

    UCam.notify("Frame-by-Frame", "Frame avanzado.")
end

-- ============================================================
-- FAST FORWARD
-- ============================================================
function UCam.toggleFastForward(state)
    UCam.TimeControl.FastForward = state

    if state then
        local speed = UCam.TimeControl.FastForwardSpeed
        -- Fast forward: escalar las animaciones del personaje local
        UCam.refreshCharacterRefs()
        if UCam.humanoid then
            local animator = UCam.humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    pcall(function() track:AdjustSpeed(speed) end)
                end
            end
        end

        -- Escalar sonidos cercanos
        if UCam.TimeControl.AudioSlowMo then
            UCam.applyAudioSlowMo(speed)
        end

        UCam.notify("Fast Forward", string.format("x%.1f activado.", speed))
    else
        -- Restaurar animaciones
        UCam.refreshCharacterRefs()
        if UCam.humanoid then
            local animator = UCam.humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    pcall(function() track:AdjustSpeed(1) end)
                end
            end
        end

        UCam.restoreAudioSlowMo()
        UCam.notify("Fast Forward", "Desactivado.")
    end
end

-- ============================================================
-- AUDIO SLOW-MO
-- ============================================================
function UCam.applyAudioSlowMo(speedScale)
    UCam.TimeControl._originalSounds = {}

    -- Buscar sonidos en el workspace cercanos al personaje
    UCam.refreshCharacterRefs()
    local searchRoot = UCam.rootPart
        and UCam.rootPart.Position
        or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
        or Vector3.zero

    for _, sound in ipairs(workspace:GetDescendants()) do
        if sound:IsA("Sound") and sound.Playing then
            local ok, pos = pcall(function()
                local p = sound.Parent
                if p and p:IsA("BasePart") then return p.Position end
                return nil
            end)
            if ok and pos then
                local dist = (pos - searchRoot).Magnitude
                if dist <= 150 then
                    UCam.TimeControl._originalSounds[sound] = sound.PlaybackSpeed
                    pcall(function() sound.PlaybackSpeed = sound.PlaybackSpeed * speedScale end)
                end
            elseif not pos then
                -- Sonido sin posición (música ambiental)
                UCam.TimeControl._originalSounds[sound] = sound.PlaybackSpeed
                pcall(function() sound.PlaybackSpeed = sound.PlaybackSpeed * speedScale end)
            end
        end
    end
end

function UCam.restoreAudioSlowMo()
    for sound, originalSpeed in pairs(UCam.TimeControl._originalSounds) do
        if sound and sound.Parent then
            pcall(function() sound.PlaybackSpeed = originalSpeed end)
        end
    end
    table.clear(UCam.TimeControl._originalSounds)
end

-- ============================================================
-- VFX (ChromaticAberration overlay + viñeta dinámica)
-- ============================================================
function UCam.applyBulletTimeVFX()
    -- Evitar duplicados
    UCam.removeBulletTimeVFX()

    local playerGui = UCam.player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end

    -- ScreenGui contenedor
    _chromaGui = Instance.new("ScreenGui")
    _chromaGui.Name = "UCamBulletTimeVFX"
    _chromaGui.ResetOnSpawn = false
    _chromaGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    _chromaGui.Parent = playerGui

    -- Frame de viñeta temporal intensa (azulada/fría para bullet time)
    _chromaFrame = Instance.new("Frame")
    _chromaFrame.Name = "ChromaOverlay"
    _chromaFrame.Size = UDim2.new(1, 0, 1, 0)
    _chromaFrame.Position = UDim2.new(0, 0, 0, 0)
    _chromaFrame.BackgroundTransparency = 0.75
    _chromaFrame.BackgroundColor3 = Color3.fromRGB(100, 120, 200) -- tono frío azul
    _chromaFrame.BorderSizePixel = 0
    _chromaFrame.ZIndex = 8
    _chromaFrame.Parent = _chromaGui

    -- UIGradient radial simulado con transparencia en bordes
    local grad = Instance.new("UIGradient")
    grad.Rotation = 0
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),   -- centro: transparente
        NumberSequenceKeypoint.new(0.6, 0.9),
        NumberSequenceKeypoint.new(1, 0.3), -- bordes: más visible
    })
    grad.Parent = _chromaFrame
end

function UCam.removeBulletTimeVFX()
    if _chromaGui and _chromaGui.Parent then
        _chromaGui:Destroy()
    end
    _chromaGui  = nil
    _chromaFrame = nil
end

-- ============================================================
-- UPDATE (llamado desde 70_camcore updateCamera cada frame)
-- ============================================================
function UCam.updateTimeControl(dt)
    -- Time Ramp update
    if UCam.TimeControl.RampEnabled then
        local elapsed = tick() - UCam.TimeControl.RampStartTime
        local duration = math.max(0.1, UCam.TimeControl.RampDuration)
        local t = math.clamp(elapsed / duration, 0, 1)

        local curve = RAMP_CURVES[UCam.TimeControl.RampPreset] or RAMP_CURVES["Impacto"]
        local speedScale = sampleCurve(curve, t)

        -- Mapear speedScale a Intensity (1.0 = normal = 0%, 0.0 = congelado = 100%)
        local intensity = math.clamp((1 - speedScale) * 100, 0, 100)
        UCam.SlowMo.Intensity = intensity

        -- Actualizar el overlay de VFX según intensidad
        if _chromaFrame then
            local alpha = math.clamp(intensity / 100, 0, 1)
            _chromaFrame.BackgroundTransparency = lerp(0.95, 0.65, alpha)
        end

        -- Auto-stop cuando el ramp termina (para "Impacto" y "Matrix Bullet")
        if t >= 1 then
            local lastPoint = curve[#curve]
            if lastPoint and math.abs(lastPoint[2] - 1.0) < 0.05 then
                -- La curva vuelve a velocidad normal: detener automáticamente
                UCam.stopTimeRamp()
            end
        end
    end

    -- Audio slow-mo sincronizado con SlowMo.Intensity cuando está activo bullet time
    if UCam.TimeControl.AudioSlowMo and UCam.SlowMo.BulletTime
        and not UCam.TimeControl.FastForward then
        -- Aplicar cada segundo para no saturar
        UCam.TimeControl._audioTimer = (UCam.TimeControl._audioTimer or 0) + dt
        if UCam.TimeControl._audioTimer >= 1.0 then
            UCam.TimeControl._audioTimer = 0
            local scale = 1 - (UCam.SlowMo.Intensity / 100) * 0.9
            scale = math.clamp(scale, 0.1, 1.0)
            UCam.applyAudioSlowMo(scale)
        end
    end
end

-- ============================================================
-- STOP GENERAL
-- ============================================================
function UCam.stopTimeControl()
    UCam.stopTimeRamp()

    if UCam.TimeControl.FrameByFrame then
        UCam.toggleFrameByFrame(false)
    end

    if UCam.TimeControl.FastForward then
        UCam.toggleFastForward(false)
    end

    UCam.restoreAudioSlowMo()
    UCam.removeBulletTimeVFX()
    UCam.TimeControl._audioTimer = 0
end
