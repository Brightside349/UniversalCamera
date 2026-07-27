-- ============================================================
-- Universal Camera Pro v7 · ui/timecontrol
-- Pestaña Control de Tiempo: Time Ramp, Frame-by-Frame,
-- Fast Forward, Audio Slow-Mo y VFX automáticos.
-- ============================================================
local UCam = _G.UCam

function UCam.build_timecontrol(Window)
    local Tab = Window:CreateTab("⏱️ Tiempo", "timer")

    -- --------------------------------------------------------
    -- SECCIÓN: Time Ramp
    -- --------------------------------------------------------
    Tab:CreateSection("Time Ramp (curva de velocidad)")
    Tab:CreateParagraph({
        Title   = "¿Qué es el Time Ramp?",
        Content = "En vez de un slow-mo fijo, el Time Ramp sube y baja la velocidad según una curva predefinida. 'Impacto' hace: rápido → lento → rápido. 'Matrix Bullet' cae al instante a 2% y luego rebota. 'Gradual' desacelera suavemente.",
    })

    Tab:CreateDropdown({
        Name            = "Preset de curva",
        Options         = UCam.TimeControl.RampPresets,
        CurrentOption   = { UCam.TimeControl.RampPreset },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then UCam.TimeControl.RampPreset = v end
        end,
    })

    Tab:CreateSlider({
        Name         = "Duración del Ramp",
        Range        = { 0.5, 10 },
        Increment    = 0.5,
        Suffix       = "s",
        CurrentValue = UCam.TimeControl.RampDuration,
        Callback     = function(v) UCam.TimeControl.RampDuration = v end,
    })

    Tab:CreateButton({
        Name     = "▶  Lanzar Time Ramp",
        Callback = function()
            UCam.startTimeRamp()
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener Time Ramp",
        Callback = function()
            UCam.stopTimeRamp()
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Frame by Frame
    -- --------------------------------------------------------
    Tab:CreateSection("Frame-by-Frame")
    Tab:CreateParagraph({
        Title   = "Modo cuadro a cuadro",
        Content = "Congela toda la simulación y avanza manualmente un cuadro a la vez. Ideal para capturar el momento exacto para un screenshot perfecto.",
    })

    Tab:CreateToggle({
        Name         = "Activar Frame-by-Frame",
        CurrentValue = UCam.TimeControl.FrameByFrame,
        Callback     = function(v)
            UCam.toggleFrameByFrame(v)
        end,
    })

    Tab:CreateButton({
        Name     = "⏭  Avanzar un frame (tecla N)",
        Callback = function()
            if not UCam.TimeControl.FrameByFrame then
                UCam.notify("Frame-by-Frame", "Activa el modo Frame-by-Frame primero.")
                return
            end
            UCam.advanceFrame()
        end,
    })

    Tab:CreateParagraph({
        Title   = "Tip de teclado",
        Content = "Con Frame-by-Frame activo: N = avanzar un frame. Funciona solo si lo mapeas manualmente desde Configuración → Keybinds (próximamente).",
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Fast Forward
    -- --------------------------------------------------------
    Tab:CreateSection("Fast Forward (aceleración)")
    Tab:CreateParagraph({
        Title   = "Acelerar animaciones",
        Content = "Multiplica la velocidad de las animaciones de tu personaje y los sonidos cercanos. No afecta la física del mundo, solo las animaciones locales.",
    })

    Tab:CreateDropdown({
        Name            = "Velocidad de Fast Forward",
        Options         = { "2x", "4x", "8x" },
        CurrentOption   = { "2x" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = { ["2x"] = 2, ["4x"] = 4, ["8x"] = 8 }
            UCam.TimeControl.FastForwardSpeed = map[v] or 2
        end,
    })

    Tab:CreateToggle({
        Name         = "Activar Fast Forward",
        CurrentValue = UCam.TimeControl.FastForward,
        Callback     = function(v)
            UCam.toggleFastForward(v)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Audio Slow-Mo
    -- --------------------------------------------------------
    Tab:CreateSection("Audio Slow-Mo")
    Tab:CreateParagraph({
        Title   = "Sincronizar audio con bullet time",
        Content = "Cuando Bullet Time (Cámara Lenta) esté activo, los sonidos cercanos bajarán su PlaybackSpeed proporcionalmente. Se actualiza cada segundo para no saturar.",
    })

    Tab:CreateToggle({
        Name         = "Audio Slow-Mo (sincronizado)",
        CurrentValue = UCam.TimeControl.AudioSlowMo,
        Callback     = function(v)
            UCam.TimeControl.AudioSlowMo = v
            if not v then UCam.restoreAudioSlowMo() end
            UCam.notify("Audio Slow-Mo", v and "Activado — sincronizado con Bullet Time." or "Desactivado.")
        end,
    })

    Tab:CreateButton({
        Name     = "Restaurar audio ahora",
        Callback = function()
            UCam.restoreAudioSlowMo()
            UCam.notify("Audio Slow-Mo", "Audio restaurado a velocidad normal.")
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: VFX automáticos
    -- --------------------------------------------------------
    Tab:CreateSection("VFX al activar Bullet Time")
    Tab:CreateParagraph({
        Title   = "Overlay cinematográfico",
        Content = "Aplica automáticamente un overlay azul-frío con gradiente radial al entrar en bullet time o Time Ramp. Simula una aberración cromática sutil.",
    })

    Tab:CreateToggle({
        Name         = "VFX automáticos al ralentizar",
        CurrentValue = UCam.TimeControl.VFXOnBulletTime,
        Callback     = function(v)
            UCam.TimeControl.VFXOnBulletTime = v
            if not v then UCam.removeBulletTimeVFX() end
            UCam.notify("VFX Bullet Time", v and "Overlay activo al próximo ramp/bullet time." or "Overlay desactivado.")
        end,
    })

    Tab:CreateButton({
        Name     = "Vista previa del overlay VFX",
        Callback = function()
            UCam.applyBulletTimeVFX()
            UCam.notify("VFX Bullet Time", "Vista previa activada. Desactívala con el botón de abajo.")
        end,
    })

    Tab:CreateButton({
        Name     = "Quitar overlay VFX",
        Callback = function()
            UCam.removeBulletTimeVFX()
            UCam.notify("VFX Bullet Time", "Overlay eliminado.")
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Acciones globales
    -- --------------------------------------------------------
    Tab:CreateSection("Acciones globales")

    Tab:CreateButton({
        Name     = "Detener TODO (restaurar tiempo)",
        Callback = function()
            UCam.stopTimeControl()
            UCam.notify("Control de Tiempo", "Todos los efectos de tiempo detenidos y restaurados.")
        end,
    })
end
