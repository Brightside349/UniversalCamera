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

    -- ===== v7: Presets de iluminación cinematográficos =====
    LightTab:CreateSection("v7 - Presets de Iluminación")
    -- Cada preset: { nombre, ClockTime, Brightness, FogEnd, FogR, FogG, FogB, Exposure, ShadowIntensity, AmbientGray }
    local lightPresets = {
        { Name = "Atardecer Dorado", ClockTime = 17.5, Bright = 2.5, FogEnd = 6000,  R = 255, G = 180, B = 90,  Exp = -0.3, Shd = 0.5 },
        { Name = "Noche de Luna",    ClockTime = 0.0,  Bright = 0.8, FogEnd = 2000,  R = 90,  G = 110, B = 200, Exp = -1.2, Shd = 0.8 },
        { Name = "Mediodía Intenso", ClockTime = 12.0, Bright = 4.0, FogEnd = 100000, R = 230, G = 230, B = 230, Exp = 0.5,  Shd = 0.7 },
        { Name = "Tormenta",         ClockTime = 8.0,  Bright = 0.6, FogEnd = 1200,  R = 80,  G = 80,  B = 90,  Exp = -1.5, Shd = 0.9 },
        { Name = "Neon City",        ClockTime = 20.0, Bright = 1.2, FogEnd = 4000,  R = 40,  G = 20,  B = 120, Exp = -0.5, Shd = 0.3 },
    }
    local function applyLightPreset(p)
        UCam.LightingTweaks.Enabled          = true
        UCam.LightingTweaks.ClockTime        = p.ClockTime
        UCam.LightingTweaks.Brightness        = p.Bright
        UCam.LightingTweaks.FogEnd            = p.FogEnd
        UCam.LightingTweaks.FogColor          = Color3.fromRGB(p.R, p.G, p.B)
        UCam.LightingTweaks.ExposureCompensation = p.Exp
        UCam.LightingTweaks.ShadowsEnabled    = true
        UCam.LightingTweaks.ShadowIntensity   = p.Shd
        UCam.applyLightingTweaks()
        UCam.notify("Iluminación", "Preset aplicado: " .. p.Name)
    end
    for _, p in ipairs(lightPresets) do
        LightTab:CreateButton({
            Name     = p.Name,
            Callback = function() applyLightPreset(p) end,
        })
    end

    -- ===== v7: Sombras y niebla volumétrica =====
    LightTab:CreateSection("v7 - Sombras")
    LightTab:CreateToggle({
        Name         = "Activar sombras globales",
        CurrentValue  = UCam.LightingTweaks.ShadowsEnabled,
        Callback      = function(v)
            UCam.LightingTweaks.ShadowsEnabled = v
            if UCam.LightingTweaks.Enabled then UCam.applyLightingTweaks() end
        end,
    })
    LightTab:CreateSlider({
        Name          = "Intensidad de sombras",
        Range         = { 0, 1 },
        Increment     = 0.05,
        CurrentValue  = UCam.LightingTweaks.ShadowIntensity,
        Callback       = function(v)
            UCam.LightingTweaks.ShadowIntensity = v
            if UCam.LightingTweaks.Enabled then UCam.applyLightingTweaks() end
        end,
    })

    LightTab:CreateSection("v7 - Niebla volumétrica (FogStart)")
    LightTab:CreateSlider({
        Name         = "Inicio de niebla (FogStart)",
        Range        = { 0, 50000 },
        Increment    = 50,
        Suffix       = "st",
        CurrentValue = UCam.LightingTweaks.FogStart or 0,
        Callback      = function(v)
            UCam.LightingTweaks.FogStart = v
            if UCam.LightingTweaks.Enabled then
                pcall(function() UCam.Lighting.FogStart = v end)
            end
        end,
    })
    local fogPresets = {
        { Name = "Niebla fina",       FogStart = 100,  FogEnd = 30000 },
        { Name = "Niebla media",      FogStart = 50,   FogEnd = 8000  },
        { Name = "Niebla densa",      FogStart = 0,    FogEnd = 2000  },
        { Name = "Sin niebla",        FogStart = 0,    FogEnd = 100000 },
    }
    for _, fp in ipairs(fogPresets) do
        LightTab:CreateButton({
            Name     = "Niebla: " .. fp.Name,
            Callback = function()
                UCam.LightingTweaks.FogStart = fp.FogStart
                UCam.LightingTweaks.FogEnd   = fp.FogEnd
                if UCam.LightingTweaks.Enabled then UCam.applyLightingTweaks() end
                UCam.notify("Iluminación", "Niebla: " .. fp.Name)
            end,
        })
    end

    -- ===== v7: Skybox override =====
    LightTab:CreateSection("v7 - Skybox (override)")
    LightTab:CreateInput({
        Name                     = "Asset ID del skybox (6 caras)",
        PlaceholderText          = "ej: 12345678",
        RemoveTextAfterFocusLost = false,
        Flag                     = "UCamSkyboxAssetInput",
        Callback                 = function() end,
    })
    local skyboxPresets = {
        { Name = "Cielo estrellado", Asset = 159453299 },
        { Name = "Amanecer",          Asset = 12062034 },
        { Name = "Despejado",         Asset = 11454339 },
        { Name = "Espacio",           Asset = 159453299 },
    }
    local function applySkybox(assetId)
        UCam.LightingTweaks.Enabled = true
        UCam.LightingTweaks.SkyboxAssetId = assetId
        UCam.applyLightingTweaks()
        UCam.notify("Iluminación", "Skybox aplicado (asset " .. tostring(assetId) .. ")")
    end
    LightTab:CreateButton({
        Name     = "Aplicar asset del campo de texto",
        Callback = function()
            pcall(function()
                local flag = UCam.Rayfield.Flags["UCamSkyboxAssetInput"]
                local raw = flag and (flag.CurrentValue or flag.Value) or ""
                local id = tonumber(tostring(raw):gsub("%D", ""))
                if not id or id == 0 then
                    UCam.notify("Iluminación", "Escribe un asset ID válido.")
                    return
                end
                applySkybox(id)
            end)
        end,
    })
    for _, sp in ipairs(skyboxPresets) do
        LightTab:CreateButton({
            Name     = "Skybox: " .. sp.Name,
            Callback = function() applySkybox(sp.Asset) end,
        })
    end
    LightTab:CreateButton({
        Name     = "Restaurar skybox original del juego",
        Callback = function()
            UCam.LightingTweaks.SkyboxAssetId = nil
            UCam.destroyCustomSky()
            UCam.notify("Iluminación", "Skybox original restaurado.")
        end,
    })

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
