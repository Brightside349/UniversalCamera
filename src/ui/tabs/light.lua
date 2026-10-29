-- ============================================================
-- Universal Camera Pro v12.5 · ui/light
-- Pestaña Iluminación / Clima: mezclador local, presets en dropdowns,
-- niebla, ambiente, sombras y skybox.
--
-- v12.5: los botones sueltos de hora, niebla y skybox se unificaron en
-- selectores para no llenar la pestaña de acciones repetidas.
-- ============================================================
local UCam = _G.UCam

function UCam.build_light(Window)
    local LightTab = Window:CreateTab("💡 Iluminación", "sun")
    local T = UCam.LightingTweaks

    LightTab:CreateSection("Mezclador de iluminación")
    LightTab:CreateParagraph({
        Title = "Solo local",
        Content = "Los cambios solo los ves tú. Al desactivar el mezclador se restaura la iluminación original del juego.",
    })
    LightTab:CreateToggle({
        Name = "Activar mezclador",
        CurrentValue = T.Enabled,
        Callback = function(v)
            T.Enabled = v
            UCam.applyLightingTweaks()
            UCam.notify("Iluminación", v and "Mezclador activado." or "Iluminación original restaurada.")
        end,
    })

    LightTab:CreateSection("Hora del día")
    LightTab:CreateSlider({
        Name = "Hora", Range = { 0, 24 }, Increment = 0.1, Suffix = "h",
        CurrentValue = T.ClockTime,
        Callback = function(v)
            T.ClockTime = v
            if T.Enabled then pcall(function() UCam.Lighting.ClockTime = v end) end
        end,
    })
    local timePresets = {
        ["Amanecer"] = 6, ["Mañana"] = 9, ["Mediodía"] = 12, ["Tarde"] = 16,
        ["Atardecer"] = 18, ["Noche"] = 21, ["Medianoche"] = 0, ["Madrugada"] = 3,
    }
    LightTab:CreateDropdown({
        Name = "Preajuste de hora",
        Options = { "Amanecer", "Mañana", "Mediodía", "Tarde", "Atardecer", "Noche", "Medianoche", "Madrugada" },
        CurrentOption = { "Mediodía" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            local hour = v and timePresets[v]
            if not hour then return end
            T.ClockTime = hour
            if T.Enabled then pcall(function() UCam.Lighting.ClockTime = hour end) end
            UCam.notify("Iluminación", "Hora: " .. v)
        end,
    })

    LightTab:CreateSection("Exposición y brillo")
    LightTab:CreateSlider({
        Name = "Exposición", Range = { -4, 4 }, Increment = 0.1, Suffix = " EV",
        CurrentValue = T.ExposureCompensation,
        Callback = function(v)
            T.ExposureCompensation = v
            if T.Enabled then pcall(function() UCam.Lighting.ExposureCompensation = v end) end
        end,
    })
    LightTab:CreateSlider({
        Name = "Brillo", Range = { 0, 10 }, Increment = 0.1, Suffix = "x",
        CurrentValue = T.Brightness,
        Callback = function(v)
            T.Brightness = v
            if T.Enabled then pcall(function() UCam.Lighting.Brightness = v end) end
        end,
    })

    LightTab:CreateSection("Niebla")
    LightTab:CreateSlider({
        Name = "Inicio (FogStart)", Range = { 0, 50000 }, Increment = 50, Suffix = "st",
        CurrentValue = T.FogStart or 0,
        Callback = function(v)
            T.FogStart = v
            if T.Enabled then pcall(function() UCam.Lighting.FogStart = v end) end
        end,
    })
    LightTab:CreateSlider({
        Name = "Fin (FogEnd)", Range = { 100, 100000 }, Increment = 100, Suffix = "st",
        CurrentValue = T.FogEnd,
        Callback = function(v)
            T.FogEnd = v
            if T.Enabled then pcall(function() UCam.Lighting.FogEnd = v end) end
        end,
    })
    local fogPresets = {
        { Name = "Sin niebla", Start = 0, End = 100000 },
        { Name = "Niebla fina", Start = 100, End = 30000 },
        { Name = "Niebla media", Start = 50, End = 8000 },
        { Name = "Niebla densa", Start = 0, End = 2000 },
    }
    local fogNames = {}
    for _, p in ipairs(fogPresets) do table.insert(fogNames, p.Name) end
    LightTab:CreateDropdown({
        Name = "Preajuste de niebla",
        Options = fogNames,
        CurrentOption = { "Sin niebla" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            for _, p in ipairs(fogPresets) do
                if p.Name == v then
                    T.FogStart, T.FogEnd = p.Start, p.End
                    if T.Enabled then UCam.applyLightingTweaks() end
                    UCam.notify("Iluminación", "Niebla: " .. p.Name)
                    return
                end
            end
        end,
    })
    LightTab:CreateSlider({
        Name = "Niebla R", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(T.FogColor.R * 255),
        Callback = function(v)
            T.FogColor = Color3.fromRGB(math.floor(v),
                math.floor(T.FogColor.G * 255), math.floor(T.FogColor.B * 255))
            if T.Enabled then pcall(function() UCam.Lighting.FogColor = T.FogColor end) end
        end,
    })
    LightTab:CreateSlider({
        Name = "Niebla G", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(T.FogColor.G * 255),
        Callback = function(v)
            T.FogColor = Color3.fromRGB(math.floor(T.FogColor.R * 255),
                math.floor(v), math.floor(T.FogColor.B * 255))
            if T.Enabled then pcall(function() UCam.Lighting.FogColor = T.FogColor end) end
        end,
    })
    LightTab:CreateSlider({
        Name = "Niebla B", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(T.FogColor.B * 255),
        Callback = function(v)
            T.FogColor = Color3.fromRGB(math.floor(T.FogColor.R * 255),
                math.floor(T.FogColor.G * 255), math.floor(v))
            if T.Enabled then pcall(function() UCam.Lighting.FogColor = T.FogColor end) end
        end,
    })

    LightTab:CreateSection("Luz ambiental")
    LightTab:CreateSlider({
        Name = "Ambiente R", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(T.OutdoorAmbient.R * 255),
        Callback = function(v)
            T.OutdoorAmbient = Color3.fromRGB(math.floor(v),
                math.floor(T.OutdoorAmbient.G * 255), math.floor(T.OutdoorAmbient.B * 255))
            if T.Enabled then pcall(function() UCam.Lighting.OutdoorAmbient = T.OutdoorAmbient end) end
        end,
    })
    LightTab:CreateSlider({
        Name = "Ambiente G", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(T.OutdoorAmbient.G * 255),
        Callback = function(v)
            T.OutdoorAmbient = Color3.fromRGB(math.floor(T.OutdoorAmbient.R * 255),
                math.floor(v), math.floor(T.OutdoorAmbient.B * 255))
            if T.Enabled then pcall(function() UCam.Lighting.OutdoorAmbient = T.OutdoorAmbient end) end
        end,
    })
    LightTab:CreateSlider({
        Name = "Ambiente B", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(T.OutdoorAmbient.B * 255),
        Callback = function(v)
            T.OutdoorAmbient = Color3.fromRGB(math.floor(T.OutdoorAmbient.R * 255),
                math.floor(T.OutdoorAmbient.G * 255), math.floor(v))
            if T.Enabled then pcall(function() UCam.Lighting.OutdoorAmbient = T.OutdoorAmbient end) end
        end,
    })

    LightTab:CreateSection("Sombras")
    LightTab:CreateToggle({
        Name = "Sombras globales",
        CurrentValue = T.ShadowsEnabled,
        Callback = function(v)
            T.ShadowsEnabled = v
            if T.Enabled then UCam.applyLightingTweaks() end
        end,
    })
    LightTab:CreateSlider({
        Name = "Suavidad de sombras", Range = { 0, 1 }, Increment = 0.05,
        CurrentValue = T.ShadowIntensity,
        Callback = function(v)
            T.ShadowIntensity = v
            if T.Enabled then UCam.applyLightingTweaks() end
        end,
    })

    LightTab:CreateSection("Presets de iluminación")
    local lightPresets = {
        { Name = "Atardecer Dorado", ClockTime = 17.5, Bright = 2.5, FogEnd = 6000, R = 255, G = 180, B = 90, Exp = -0.3, Shd = 0.5 },
        { Name = "Noche de Luna", ClockTime = 0.0, Bright = 0.8, FogEnd = 2000, R = 90, G = 110, B = 200, Exp = -1.2, Shd = 0.8 },
        { Name = "Mediodía Intenso", ClockTime = 12.0, Bright = 4.0, FogEnd = 100000, R = 230, G = 230, B = 230, Exp = 0.5, Shd = 0.7 },
        { Name = "Tormenta", ClockTime = 8.0, Bright = 0.6, FogEnd = 1200, R = 80, G = 80, B = 90, Exp = -1.5, Shd = 0.9 },
        { Name = "Neon City", ClockTime = 20.0, Bright = 1.2, FogEnd = 4000, R = 40, G = 20, B = 120, Exp = -0.5, Shd = 0.3 },
    }
    local presetNames = {}
    for _, p in ipairs(lightPresets) do table.insert(presetNames, p.Name) end
    LightTab:CreateDropdown({
        Name = "Preset",
        Options = presetNames,
        CurrentOption = { presetNames[1] },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            for _, p in ipairs(lightPresets) do
                if p.Name == v then
                    T.Enabled = true
                    T.ClockTime = p.ClockTime
                    T.Brightness = p.Bright
                    T.FogEnd = p.FogEnd
                    T.FogColor = Color3.fromRGB(p.R, p.G, p.B)
                    T.ExposureCompensation = p.Exp
                    T.ShadowsEnabled = true
                    T.ShadowIntensity = p.Shd
                    UCam.applyLightingTweaks()
                    UCam.notify("Iluminación", "Preset: " .. p.Name)
                    return
                end
            end
        end,
    })

    LightTab:CreateSection("Skybox")
    local skyboxPresets = {
        { Name = "Cielo estrellado", Asset = 159453299 },
        { Name = "Amanecer", Asset = 12062034 },
        { Name = "Despejado", Asset = 11454339 },
        { Name = "Espacio", Asset = 159453299 },
    }
    local skyNames = {}
    for _, s in ipairs(skyboxPresets) do table.insert(skyNames, s.Name) end
    LightTab:CreateDropdown({
        Name = "Skybox",
        Options = skyNames,
        CurrentOption = { skyNames[1] },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            for _, s in ipairs(skyboxPresets) do
                if s.Name == v then
                    T.Enabled = true
                    T.SkyboxAssetId = s.Asset
                    UCam.applyLightingTweaks()
                    UCam.notify("Iluminación", "Skybox: " .. s.Name)
                    return
                end
            end
        end,
    })
    LightTab:CreateInput({
        Name = "Asset ID del skybox",
        PlaceholderText = "ej: 12345678",
        RemoveTextAfterFocusLost = false,
        Flag = "UCamSkyboxAssetInput",
        Callback = function() end,
    })
    LightTab:CreateButton({
        Name = "Aplicar asset del campo",
        Callback = function()
            local flag = UCam.Rayfield.Flags and UCam.Rayfield.Flags["UCamSkyboxAssetInput"]
            local raw = flag and (flag.CurrentValue or flag.Value) or ""
            local id = tonumber(tostring(raw):gsub("%D", ""))
            if not id or id == 0 then
                UCam.notify("Iluminación", "Escribe un asset ID válido.")
                return
            end
            T.Enabled = true
            T.SkyboxAssetId = id
            UCam.applyLightingTweaks()
        end,
    })
    LightTab:CreateButton({
        Name = "Restaurar skybox original",
        Callback = function()
            T.SkyboxAssetId = nil
            UCam.destroyCustomSky()
            UCam.notify("Iluminación", "Skybox original restaurado.")
        end,
    })

    LightTab:CreateSection("Restaurar")
    LightTab:CreateButton({
        Name = "Restaurar iluminación original",
        Callback = function()
            T.Enabled = false
            UCam.applyLightingTweaks()
            UCam.notify("Iluminación", "Iluminación original del juego restaurada.")
        end,
    })
end
