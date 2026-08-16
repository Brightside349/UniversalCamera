-- ============================================================
-- Universal Camera Pro v8 · ui/filterspro
-- Pestaña Filtros Pro: efectos visuales avanzados (grain, pixel,
-- scanlines, tilt-shift, radial blur, color curves).
-- ============================================================
local UCam = _G.UCam

function UCam.build_filterspro(Window)
    local Tab = Window:CreateTab("✨ Filtros Pro", "sparkles")
    local F = UCam.FiltersPro

    Tab:CreateSection("Master")

    Tab:CreateToggle({
        Name         = "Filtros Pro (activar efectos avanzados)",
        CurrentValue = F.Enabled,
        Callback     = function(v)
            F.Enabled = v
            UCam.updateFiltersPro()
            UCam.notify("Filtros Pro", v and "Activado." or "Desactivado (efectos removidos).")
        end,
    })

    Tab:CreateParagraph({
        Title   = "Nota",
        Content = "Activa el toggle maestro, luego cada efecto individual. Cada cambio de parámetro re-crea el GUI del efecto (inmediato).",
    })

    -- --------------------------------------------------------
    -- FILM GRAIN
    -- --------------------------------------------------------
    Tab:CreateSection("🎞️ Film Grain")

    Tab:CreateToggle({
        Name         = "Activar Film Grain",
        CurrentValue = F.FilmGrain.Enabled,
        Callback     = function(v)
            F.FilmGrain.Enabled = v
            UCam.updateFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Cantidad de ruido",
        Range        = { 0.05, 1.0 },
        Increment    = 0.05,
        CurrentValue = F.FilmGrain.Amount or 0.4,
        Callback     = function(v)
            F.FilmGrain.Amount = tonumber(v) or 0.4
            UCam.rebuildFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Velocidad de animación (fps)",
        Range        = { 4, 60 },
        Increment    = 4,
        Suffix       = " fps",
        CurrentValue = F.FilmGrain.Speed or 24,
        Callback     = function(v)
            F.FilmGrain.Speed = math.floor(v)
            UCam.rebuildFiltersPro()
        end,
    })

    -- --------------------------------------------------------
    -- PIXELIFY
    -- --------------------------------------------------------
    Tab:CreateSection("🕹️ Pixelify (8-bit)")

    Tab:CreateToggle({
        Name         = "Activar Pixelify",
        CurrentValue = F.Pixelify.Enabled,
        Callback     = function(v)
            F.Pixelify.Enabled = v
            UCam.updateFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Tamaño de bloque (filas)",
        Range        = { 2, 48 },
        Increment    = 1,
        Suffix       = " filas",
        CurrentValue = F.Pixelify.BlockSize or 8,
        Callback     = function(v)
            F.Pixelify.BlockSize = math.floor(v)
            UCam.rebuildFiltersPro()
        end,
    })

    -- --------------------------------------------------------
    -- SCANLINES
    -- --------------------------------------------------------
    Tab:CreateSection("📺 Scanlines (CRT/VHS)")

    Tab:CreateToggle({
        Name         = "Activar Scanlines",
        CurrentValue = F.Scanlines.Enabled,
        Callback     = function(v)
            F.Scanlines.Enabled = v
            UCam.updateFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Densidad de líneas",
        Range        = { 16, 480 },
        Increment    = 8,
        CurrentValue = F.Scanlines.Density or 120,
        Callback     = function(v)
            F.Scanlines.Density = math.floor(v)
            UCam.rebuildFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Opacidad de líneas",
        Range        = { 0.1, 1.0 },
        Increment    = 0.05,
        CurrentValue = F.Scanlines.Opacity or 0.4,
        Callback     = function(v)
            F.Scanlines.Opacity = tonumber(v) or 0.4
            UCam.rebuildFiltersPro()
        end,
    })

    -- --------------------------------------------------------
    -- TILT-SHIFT (miniatura)
    -- --------------------------------------------------------
    Tab:CreateSection("🏙️ Tilt-Shift (miniatura)")

    Tab:CreateToggle({
        Name         = "Activar Tilt-Shift",
        CurrentValue = F.TiltShift.Enabled,
        Callback     = function(v)
            F.TiltShift.Enabled = v
            UCam.updateFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Foco vertical (debajo → arriba)",
        Range        = { 0.0, 1.0 },
        Increment    = 0.05,
        CurrentValue = F.TiltShift.FocusHeight or 0.5,
        Callback     = function(v)
            F.TiltShift.FocusHeight = tonumber(v) or 0.5
            UCam.rebuildFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Intensidad de desenfoque",
        Range        = { 0.1, 1.0 },
        Increment    = 0.05,
        CurrentValue = F.TiltShift.Blur or 0.6,
        Callback     = function(v)
            F.TiltShift.Blur = tonumber(v) or 0.6
            UCam.rebuildFiltersPro()
        end,
    })

    -- --------------------------------------------------------
    -- RADIAL BLUR
    -- --------------------------------------------------------
    Tab:CreateSection("🌀 Radial Blur")

    Tab:CreateToggle({
        Name         = "Activar Radial Blur",
        CurrentValue = F.RadialBlur.Enabled,
        Callback     = function(v)
            F.RadialBlur.Enabled = v
            UCam.updateFiltersPro()
        end,
    })

    Tab:CreateSlider({
        Name         = "Intensidad",
        Range        = { 0.05, 1.0 },
        Increment    = 0.05,
        CurrentValue = F.RadialBlur.Amount or 0.5,
        Callback     = function(v)
            F.RadialBlur.Amount = tonumber(v) or 0.5
            UCam.rebuildFiltersPro()
        end,
    })

    -- --------------------------------------------------------
    -- COLOR CURVES (presets rápidos sobre el filtro ya activo)
    -- --------------------------------------------------------
    Tab:CreateSection("🌈 Color Curves (presets)")

    Tab:CreateDropdown({
        Name            = "Preset",
        Options         = F.ColorCurves.Presets,
        CurrentOption   = { F.ColorCurves.Preset or "Neutral" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then
                UCam.applyColorCurvePreset(v)
            end
        end,
    })

    Tab:CreateButton({
        Name     = "↩️  Restaurar curva por defecto",
        Callback = function()
            F.ColorCurves.Enabled = false
            pcall(function()
                UCam.applyColorCurvePreset("Neutral")
                F.ColorCurves.Preset = "Neutral"
            end)
            -- Re-aplicar el filtro elegido en la pestaña Filtros
            if UCam.applyFilter then
                pcall(UCam.applyFilter, UCam.currentFilterIndex)
            end
            UCam.notify("Color Curves", "Restaurado al filtro de la pestaña 🎨 Filtros.")
        end,
    })

    -- --------------------------------------------------------
    -- Acciones globales
    -- --------------------------------------------------------
    Tab:CreateSection("Otros")

    Tab:CreateButton({
        Name     = "🔄  Re-crear TODOS los efectos (si falta alguno)",
        Callback = function()
            UCam.rebuildFiltersPro()
            UCam.notify("Filtros Pro", "Efectos re-creados.")
        end,
    })

    Tab:CreateButton({
        Name     = "🧹  Detener TODO (quitar Guis + restaurar curva)",
        Callback = function()
            F.Enabled = false
            UCam.stopFiltersPro(false)
            UCam.notify("Filtros Pro", "Detenido.")
        end,
    })
end
