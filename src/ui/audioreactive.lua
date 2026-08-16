-- ============================================================
-- Universal Camera Pro v8 · ui/audioreactive
-- Pestaña Audio Reactive: FOV/Shake/Flashes disparados por beats.
-- ============================================================
local UCam = _G.UCam

function UCam.build_audioreactive(Window)
    local Tab = Window:CreateTab("🔊 Audio Reactive", "volume-2")

    -- --------------------------------------------------------
    -- Info
    -- --------------------------------------------------------
    Tab:CreateSection("¿Cómo funciona?")
    Tab:CreateParagraph({
        Title   = "Beat detection",
        Content = "Detectamos los beats de cualquier Sound activo en el workspace a través de su PlaybackLoudness. Cada vez que el volumen sube bruscamente → dispara los efectos seleccionados abajo.",
    })

    -- --------------------------------------------------------
    -- Toggle maestro
    -- --------------------------------------------------------
    Tab:CreateSection("Activación")

    Tab:CreateToggle({
        Name         = "Audio Reactive",
        CurrentValue = UCam.AudioReactive.Enabled,
        Callback     = function(v)
            if v then UCam.startAudioReactive() else UCam.stopAudioReactive() end
        end,
    })

    Tab:CreateToggle({
        Name         = "Auto-detectar Sound (vs target fijo)",
        CurrentValue = UCam.AudioReactive.AutoDetect,
        Callback     = function(v)
            UCam.AudioReactive.AutoDetect = v
            if v then UCam.setAudioReactiveTarget(nil) end
        end,
    })

    -- --------------------------------------------------------
    -- Parámetros de detección
    -- --------------------------------------------------------
    Tab:CreateSection("Detección")

    Tab:CreateSlider({
        Name         = "Sensibilidad (umbral de loudness)",
        Range        = { 0.05, 1.0 },
        Increment    = 0.05,
        CurrentValue = UCam.AudioReactive.Sensitivity,
        Callback     = function(v) UCam.AudioReactive.Sensitivity = tonumber(v) or 0.35 end,
    })

    Tab:CreateSlider({
        Name         = "Cooldown entre beats (s)",
        Range        = { 0.05, 1.0 },
        Increment    = 0.05,
        Suffix       = "s",
        CurrentValue = UCam.AudioReactive.Cooldown,
        Callback     = function(v) UCam.AudioReactive.Cooldown = tonumber(v) or 0.25 end,
    })

    -- --------------------------------------------------------
    -- Efectos individuales
    -- --------------------------------------------------------
    Tab:CreateSection("Efectos en cada beat")

    Tab:CreateToggle({
        Name         = "FOV pulse (in-out rápido)",
        CurrentValue = UCam.AudioReactive.FovPulse,
        Callback     = function(v) UCam.AudioReactive.FovPulse = v end,
    })

    Tab:CreateSlider({
        Name         = "Intensidad del FOV pulse",
        Range        = { 2, 20 },
        Increment    = 1,
        Suffix       = "°",
        CurrentValue = UCam.AudioReactive.FovAmount,
        Callback     = function(v) UCam.AudioReactive.FovAmount = math.floor(v) end,
    })

    Tab:CreateToggle({
        Name         = "Shake en cada beat",
        CurrentValue = UCam.AudioReactive.ShakeOnBeat,
        Callback     = function(v) UCam.AudioReactive.ShakeOnBeat = v end,
    })

    Tab:CreateDropdown({
        Name            = "Patrón de shake",
        Options         = UCam.Shake.Patterns,
        CurrentOption   = { UCam.AudioReactive.ShakePattern },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then UCam.AudioReactive.ShakePattern = v end
        end,
    })

    Tab:CreateToggle({
        Name         = "Flash blanco rápido",
        CurrentValue = UCam.AudioReactive.FilterFlash,
        Callback     = function(v) UCam.AudioReactive.FilterFlash = v end,
    })

    -- --------------------------------------------------------
    -- Info / Debug
    -- --------------------------------------------------------
    Tab:CreateSection("Info")

    Tab:CreateButton({
        Name     = "ℹ️  Estado actual",
        Callback = function()
            local s = UCam.AudioReactive
            local enabled  = s.Enabled and "SÍ" or "NO"
            local target   = (s.TargetSound and s.TargetSound.Parent) and s.TargetSound:GetFullName() or "(auto)"
            local effs = {}
            if s.FovPulse    then effs[#effs+1] = "FOV" end
            if s.ShakeOnBeat then effs[#effs+1] = "Shake(" .. s.ShakePattern .. ")" end
            if s.FilterFlash then effs[#effs+1] = "Flash" end
            UCam.notify("Audio Reactive",
                ("Activo: %s\nTarget: %s\nEfectos: %s"):format(enabled, target, #effs > 0 and table.concat(effs, ", ") or "(ninguno)"), 6)
        end,
    })

    Tab:CreateParagraph({
        Title   = "Limitación",
        Content = "Roblox no expone espectro de frecuencia (FFT) a scripts. Estimamos 'beats' por picos de loudness. Para resultados óptimos, baja el cooldown si la música es muy rápida.",
    })
end
