-- ============================================================
-- Universal Camera Pro v6 · ui/light
-- Pestaña Iluminación / Clima: mezclador de hora del dia, exposicion,
-- niebla, ambiente y preajustes de hora.
-- ============================================================
local UCam = _G.UCam

function UCam.build_light(Window)
    local LightTab = Window:CreateTab("💡 Iluminación", "sun")

    LightTab:CreateSection("Mezclador de Iluminacion y Clima")
    LightTab:CreateParagraph({
        Title   = "Nota",
        Content = "Los cambios son locales (solo los ves tu). Al desactivar el modulo se restauran los valores originales de la iluminacion del juego.",
    })

    LightTab:CreateToggle({
        Name         = "Activar Mezclador",
        CurrentValue = UCam.LightingTweaks.Enabled,
        Callback     = function(v)
            UCam.LightingTweaks.Enabled = v
            UCam.applyLightingTweaks()
            if v then
                UCam.notify("Iluminacion", "Mezclador activado. Los cambios son solo locales.")
            else
                UCam.notify("Iluminacion", "Iluminacion original restaurada.")
            end
        end,
    })

    LightTab:CreateSection("Hora del dia")
    LightTab:CreateSlider({
        Name         = "Hora (ClockTime)",
        Range        = { 0, 24 },
        Increment    = 0.1,
        Suffix       = "h",
        CurrentValue = UCam.LightingTweaks.ClockTime,
        Callback     = function(v)
            UCam.LightingTweaks.ClockTime = v
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.ClockTime = v end)
            end
        end,
    })

    LightTab:CreateSection("Exposicion y Brillo")
    LightTab:CreateSlider({
        Name         = "Exposicion (ExposureCompensation)",
        Range        = { -4, 4 },
        Increment    = 0.1,
        Suffix       = " EV",
        CurrentValue = UCam.LightingTweaks.ExposureCompensation,
        Callback     = function(v)
            UCam.LightingTweaks.ExposureCompensation = v
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.ExposureCompensation = v end)
            end
        end,
    })
    LightTab:CreateSlider({
        Name         = "Brillo global (Brightness)",
        Range        = { 0, 10 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = UCam.LightingTweaks.Brightness,
        Callback     = function(v)
            UCam.LightingTweaks.Brightness = v
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.Brightness = v end)
            end
        end,
    })

    LightTab:CreateSection("Niebla (Fog)")
    LightTab:CreateSlider({
        Name         = "Distancia de niebla (FogEnd)",
        Range        = { 100, 100000 },
        Increment    = 100,
        Suffix       = "st",
        CurrentValue = UCam.LightingTweaks.FogEnd,
        Callback     = function(v)
            UCam.LightingTweaks.FogEnd = v
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.FogEnd = v end)
            end
        end,
    })
    LightTab:CreateSlider({
        Name         = "Niebla - Rojo",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = math.floor(UCam.LightingTweaks.FogColor.R * 255),
        Callback     = function(v)
            UCam.LightingTweaks.FogColor = Color3.fromRGB(
                math.floor(v),
                math.floor(UCam.LightingTweaks.FogColor.G * 255),
                math.floor(UCam.LightingTweaks.FogColor.B * 255)
            )
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.FogColor = UCam.LightingTweaks.FogColor end)
            end
        end,
    })
    LightTab:CreateSlider({
        Name         = "Niebla - Verde",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = math.floor(UCam.LightingTweaks.FogColor.G * 255),
        Callback     = function(v)
            UCam.LightingTweaks.FogColor = Color3.fromRGB(
                math.floor(UCam.LightingTweaks.FogColor.R * 255),
                math.floor(v),
                math.floor(UCam.LightingTweaks.FogColor.B * 255)
            )
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.FogColor = UCam.LightingTweaks.FogColor end)
            end
        end,
    })
    LightTab:CreateSlider({
        Name         = "Niebla - Azul",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = math.floor(UCam.LightingTweaks.FogColor.B * 255),
        Callback     = function(v)
            UCam.LightingTweaks.FogColor = Color3.fromRGB(
                math.floor(UCam.LightingTweaks.FogColor.R * 255),
                math.floor(UCam.LightingTweaks.FogColor.G * 255),
                math.floor(v)
            )
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.FogColor = UCam.LightingTweaks.FogColor end)
            end
        end,
    })

    LightTab:CreateSection("Luz ambiental")
    LightTab:CreateSlider({
        Name         = "Ambiente exterior - Rojo",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = math.floor(UCam.LightingTweaks.OutdoorAmbient.R * 255),
        Callback     = function(v)
            UCam.LightingTweaks.OutdoorAmbient = Color3.fromRGB(
                math.floor(v),
                math.floor(UCam.LightingTweaks.OutdoorAmbient.G * 255),
                math.floor(UCam.LightingTweaks.OutdoorAmbient.B * 255)
            )
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.OutdoorAmbient = UCam.LightingTweaks.OutdoorAmbient end)
            end
        end,
    })
    LightTab:CreateSlider({
        Name         = "Ambiente exterior - Verde",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = math.floor(UCam.LightingTweaks.OutdoorAmbient.G * 255),
        Callback     = function(v)
            UCam.LightingTweaks.OutdoorAmbient = Color3.fromRGB(
                math.floor(UCam.LightingTweaks.OutdoorAmbient.R * 255),
                math.floor(v),
                math.floor(UCam.LightingTweaks.OutdoorAmbient.B * 255)
            )
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.OutdoorAmbient = UCam.LightingTweaks.OutdoorAmbient end)
            end
        end,
    })
    LightTab:CreateSlider({
        Name         = "Ambiente exterior - Azul",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = math.floor(UCam.LightingTweaks.OutdoorAmbient.B * 255),
        Callback     = function(v)
            UCam.LightingTweaks.OutdoorAmbient = Color3.fromRGB(
                math.floor(UCam.LightingTweaks.OutdoorAmbient.R * 255),
                math.floor(UCam.LightingTweaks.OutdoorAmbient.G * 255),
                math.floor(v)
            )
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.OutdoorAmbient = UCam.LightingTweaks.OutdoorAmbient end)
            end
        end,
    })

    LightTab:CreateSection("Preajustes de hora")
    local timePresets = {
        { "Amanecer (6h)",       6   },
        { "Manana (9h)",         9   },
        { "Mediodia (12h)",      12  },
        { "Tarde (16h)",         16  },
        { "Atardecer (18h)",     18  },
        { "Noche (21h)",         21  },
        { "Medianoche (0h)",     0   },
        { "Madrugada (3h)",      3   },
    }
    for _, preset in ipairs(timePresets) do
        LightTab:CreateButton({
            Name     = preset[1],
            Callback = function()
                UCam.LightingTweaks.ClockTime = preset[2]
                if UCam.LightingTweaks.Enabled then
                    pcall(function() UCam.Lighting.ClockTime = preset[2] end)
                end
                UCam.notify("Iluminacion", "Hora ajustada: " .. preset[1])
            end,
        })
    end

    LightTab:CreateSection("Restaurar")
    LightTab:CreateButton({
        Name     = "Restaurar iluminacion original del juego",
        Callback = function()
            UCam.LightingTweaks.Enabled = false
            UCam.applyLightingTweaks()
            UCam.notify("Iluminacion", "Iluminacion original del juego restaurada.")
        end,
    })
end
