-- ============================================================
-- Universal Camera Pro v8 · 75_audioreactive
-- Audio-reactive efectos: detecta el beat de un Sound y dispara
-- FOV pulse, Shake o Filter Flash en tiempo real.
--
-- Roblox no expone FFT de audio client-side, así que estimamos
-- la energía mediante la propiedad "PlaybackLoudness" del Sound
-- (disponible en modernas versiones) y detectamos "subidas
-- bruscas" como beats.
--
-- Dependencias: 00_config, 10_utils, 70_camcore (para shake/fov)
-- Expone (UCam.*):
--   startAudioReactive, stopAudioReactive, setAudioReactiveTarget,
--   stopAudio (para Unload)
-- ============================================================
local UCam = _G.UCam

local Workspace = game:GetService("Workspace")

-- ============================================================
-- ESTADO
-- ============================================================
local AR = UCam.AudioReactive
local _conn         = nil
local _targetSound  = nil     -- Sound instance
local _prevLoudness = 0
local _guiFlash     = nil     -- ScreenGui con overlay de flash
local _lastBeatAt   = 0
-- v8 FIX: throttle del auto-detect — GetDescendants() completo no debe
-- ejecutarse en CADA tick (el informe §8 lo marcaba como patrón detectable
-- y costoso). Re-escaneamos a 2Hz salvo que no haya target.
local _scanTimer   = 0
local _scanEvery   = 0.5      -- segundos entre escaneos

-- ============================================================
-- AUTO-DETECT: buscar el Sound más "fuerte" en workspace
-- ============================================================
local function findLoudestSound()
    local best, bestL = nil, 0
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Sound") and d.IsPlaying then
                local loud = tonumber(d.PlaybackLoudness) or 0
                if loud > bestL then
                    bestL = loud
                    best = d
                end
            end
        end
    end)
    return best, bestL
end

-- ============================================================
-- EFECTOS individualmente togglables
-- ============================================================

-- FOV pulse: subir brevemente +N grados en el beat
local function beatFovPulse()
    if not AR.FovPulse then return end
    if not UCam.camera then return end
    local orig = UCam.camera.FieldOfView
    UCam.camera.FieldOfView = UCam.clamp(orig - (AR.FovAmount or 6), UCam.MIN_FOV, UCam.MAX_FOV)
    task.delay(0.12, function()
        pcall(function()
            UCam.camera.FieldOfView = orig
        end)
    end)
end

-- Shake: disparar el patrón configurado
local function beatShake()
    if not AR.ShakeOnBeat then return end
    if not UCam.triggerShake then return end
    UCam.triggerShake(AR.ShakePattern or "Pulso")
end

-- Flash blanco rápido (overlay GUI)
local function ensureFlashGui()
    if _guiFlash and _guiFlash.Parent then return _guiFlash end
    local player = UCam.player
    local pg = player and player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local sg = Instance.new("ScreenGui")
    sg.Name = "UCam_AudioFlash"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.Parent = pg
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1, 1)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    _guiFlash = sg
    return sg
end

local function beatFlash()
    if not AR.FilterFlash then return end
    local sg = ensureFlashGui()
    if not sg then return end
    local frame = sg:FindFirstChildOfClass("Frame")
    if not frame then return end
    frame.BackgroundTransparency = 0.55
    task.delay(0.10, function()
        if frame and frame.Parent then
            frame.BackgroundTransparency = 1
        end
    end)
end

-- ============================================================
-- LOOP principal (Heartbeat)
-- ============================================================
local function tickAudioReactive(dt)
    if not AR.Enabled then return end

    -- Encontrar target (con throttle para no escanear workspace cada frame)
    local sound = _targetSound
    local previousTarget = _targetSound
    if AR.AutoDetect or not sound or not sound.Parent then
        _scanTimer = (_scanTimer or 0) + (dt or 0)
        if _scanTimer >= _scanEvery then
            _scanTimer = 0
            local found = findLoudestSound()
            sound = found
            _targetSound = found
        else
            -- Mantener el target anterior mientras tanto (si sigue válido)
            sound = (sound and sound.Parent) and sound or nil
        end
    end

    -- v8.1 FIX: si cambió el sonido objetivo (auto-detección), resetear
    -- _prevLoudness para no generar un "beat fantasma" por la diferencia
    -- de nivel entre un sonido y otro.
    if sound ~= previousTarget then
        _prevLoudness = nil
    end

    if not sound or not sound.Parent then return end

    local loud = tonumber(sound.PlaybackLoudness) or 0

    -- Detectar "beat": subida brusca respecto al frame anterior
    local delta = loud - (_prevLoudness or loud)
    _prevLoudness = loud

    local threshold = math.max(AR.Sensitivity or 0.35, 0.05) * 100       -- PlaybackLoudness es ~0..800+
    local cooldown = AR.Cooldown or 0.25
    local now = tick()

    if delta >= threshold and (now - _lastBeatAt) >= cooldown then
        _lastBeatAt = now
        beatFovPulse()
        beatShake()
        beatFlash()
    end
end

-- ============================================================
-- API
-- ============================================================
function UCam.setAudioReactiveTarget(sound)
    if sound and not sound:IsA("Sound") then
        UCam.notify("Audio Reactive", "El target debe ser una instancia Sound.")
        return false
    end
    _targetSound = sound
    AR.TargetSound = sound
    if sound then
        UCam.notify("Audio Reactive", ("Target → %s"):format(sound:GetFullName()))
        AR.AutoDetect = false
    else
        AR.AutoDetect = true
        UCam.notify("Audio Reactive", "Auto-detección activada.")
    end
    return true
end

function UCam.startAudioReactive()
    if AR.Enabled then return end
    AR.Enabled = true
    _prevLoudness = 0
    _lastBeatAt = 0

    _conn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(tickAudioReactive),
        "AudioReactive:Heartbeat"
    )

    UCam.notify("Audio Reactive", "Activado. Detectando beats…")
end

function UCam.stopAudioReactive()
    if not AR.Enabled then return end
    AR.Enabled = false
    if _conn then
        pcall(function() _conn:Disconnect() end)
        _conn = nil
    end
    -- Destruir GUI de flash
    if _guiFlash and _guiFlash.Parent then
        pcall(function() _guiFlash:Destroy() end)
    end
    _guiFlash = nil
    UCam.notify("Audio Reactive", "Detenido.")
end

-- ============================================================
-- STOP GLOBAL (para Unload)
-- ============================================================
function UCam.stopAudio()
    UCam.stopAudioReactive()
end

print("[UCam] Audio Reactive listo.")
