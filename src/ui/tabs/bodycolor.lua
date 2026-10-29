-- ============================================================
-- Universal Camera Pro v12.5 · ui/bodycolor
-- Pestaña Cuerpo: color, material y transparencia por partes, presets,
-- arcoíris y aplicación local a otros jugadores.
--
-- v12.5: se unificaron las acciones (un solo botón de aplicar por
-- bloque), los presets pasaron a un selector y se retiró la duplicación
-- de controles del módulo Mod Jugadores.
-- ============================================================
local UCam = _G.UCam
local B = UCam.BodyColor

function UCam.build_bodycolor(Window)
    local Tab = Window:CreateTab("🎨 Cuerpo", 4483362458)

    -- ============================================================
    -- MI PERSONAJE
    -- ============================================================
    Tab:CreateSection("Mi personaje")
    Tab:CreateParagraph({
        Title = "Control por partes",
        Content = "Elige una parte (o Todo), ajusta color, material y transparencia, y aplica. Los cambios son locales.",
    })
    Tab:CreateDropdown({
        Name = "Parte",
        Options = B.PartOptions,
        CurrentOption = { B.SelectedPart },
        MultipleOptions = false,
        Flag = "BodyPartSelection",
        Callback = function(opt)
            local part = UCam.resolveDropdownValue(opt)
            if part then B.SelectedPart = part end
        end,
    })
    local colorPicker = Tab:CreateColorPicker({
        Name = "Color",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "BodyPartColor",
        Callback = function() end,
    })
    local materialDropdown = Tab:CreateDropdown({
        Name = "Material",
        Options = { "Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField" },
        CurrentOption = { "Plastic" },
        MultipleOptions = false,
        Flag = "BodyPartMaterial",
        Callback = function() end,
    })
    local transparencySlider = Tab:CreateSlider({
        Name = "Transparencia", Range = { 0, 1 }, Increment = 0.05,
        CurrentValue = 0,
        Flag = "BodyPartTransparency",
        Callback = function() end,
    })

    local function selectedMaterial()
        return UCam.resolveDropdownValue(materialDropdown.CurrentOption) or "Plastic"
    end

    Tab:CreateButton({
        Name = "✅ Aplicar a la parte seleccionada",
        Callback = function()
            if not B.SelectedPart then
                UCam.notify("Cuerpo", "Selecciona una parte primero.", 3)
                return
            end
            UCam.applyBodyColorToPart(B.SelectedPart, colorPicker.Color, selectedMaterial(), transparencySlider.CurrentValue)
            UCam.notify("Cuerpo", "Aplicado a " .. B.SelectedPart)
        end,
    })
    Tab:CreateButton({
        Name = "✅ Aplicar a TODO el cuerpo",
        Callback = function()
            UCam.applyBodyColorToPart("Todo", colorPicker.Color, selectedMaterial(), transparencySlider.CurrentValue)
            UCam.notify("Cuerpo", "Aplicado a todo el cuerpo")
        end,
    })
    Tab:CreateButton({
        Name = "↩ Restaurar colores originales",
        Callback = function()
            UCam.restoreBodyColor()
            UCam.notify("Cuerpo", "Colores restaurados")
        end,
    })

    Tab:CreateSection("Color por código HEX")
    local lastHex = nil
    Tab:CreateInput({
        Name = "HEX (#RRGGBB)",
        PlaceholderText = "Ej: #FF5500",
        RemoveTextAfterFocusLost = false,
        Flag = "BodyPartHexColor",
        Callback = function(text)
            if text and text ~= "" then lastHex = text end
        end,
    })
    local function applyHex(targetAll)
        if not lastHex then
            UCam.notify("Cuerpo", "Escribe un HEX primero.", 3)
            return
        end
        local color = UCam.hexToColor(lastHex)
        if not color then
            UCam.notify("Cuerpo", "HEX inválido: " .. lastHex, 4)
            return
        end
        UCam.applyBodyColorToPart(targetAll and "Todo" or B.SelectedPart, color, nil, nil)
        UCam.notify("Cuerpo", string.format("HEX %s aplicado", lastHex))
    end
    Tab:CreateButton({
        Name = "Aplicar HEX a la parte",
        Callback = function() applyHex(false) end,
    })
    Tab:CreateButton({
        Name = "Aplicar HEX a todo el cuerpo",
        Callback = function() applyHex(true) end,
    })

    Tab:CreateSection("Presets de aspecto")
    Tab:CreateDropdown({
        Name = "Elegir y aplicar",
        Options = B.PresetOptions,
        CurrentOption = { B.PresetOptions[1] },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then
                UCam.applyPreset(v)
                UCam.notify("Cuerpo", "Preset aplicado: " .. v)
            end
        end,
    })

    Tab:CreateSection("Arcoíris animado")
    Tab:CreateToggle({
        Name = "Activar arcoíris",
        CurrentValue = B.RainbowEnabled,
        Flag = "BodyRainbowEnabled",
        Callback = function(v)
            B.RainbowEnabled = v
            if v then UCam.initBodyColor() end
        end,
    })
    Tab:CreateSlider({
        Name = "Velocidad", Range = { 0.1, 5 }, Increment = 0.1,
        CurrentValue = B.RainbowSpeed,
        Flag = "BodyRainbowSpeed",
        Callback = function(v) B.RainbowSpeed = v end,
    })
    Tab:CreateDropdown({
        Name = "Parte con arcoíris",
        Options = B.PartOptions,
        CurrentOption = { B.RainbowPart },
        MultipleOptions = false,
        Flag = "BodyRainbowPart",
        Callback = function(o)
            local part = UCam.resolveDropdownValue(o)
            if part then B.RainbowPart = part end
        end,
    })

    -- ============================================================
    -- OTROS JUGADORES
    -- ============================================================
    Tab:CreateSection("Otros jugadores (solo local)")
    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(UCam.Players:GetPlayers()) do
            if p ~= UCam.player then table.insert(names, p.Name) end
        end
        if #names == 0 then names[1] = "(Sin otros jugadores)" end
        return names
    end

    local targetDropdown = UCam.registerTargetPlayerDropdown(Tab:CreateDropdown({
        Name = "Jugador objetivo",
        Options = getPlayerNames(),
        CurrentOption = { "(Sin otros jugadores)" },
        MultipleOptions = false,
        Flag = "TargetPlayerBodyColor",
        Callback = function(opt)
            local name = UCam.resolveDropdownValue(opt)
            if not name or name == "(Sin otros jugadores)" then return end
            local target = UCam.Players:FindFirstChild(name)
            if target then UCam.setTargetPlayer(target) end
        end,
    }))
    Tab:CreateButton({
        Name = "🔄 Actualizar lista de jugadores",
        Callback = function()
            pcall(function() targetDropdown:Refresh(getPlayerNames()) end)
        end,
    })

    Tab:CreateDropdown({
        Name = "Parte del otro jugador",
        Options = B.PartOptions,
        CurrentOption = { B.TargetSelectedPart or "Todo" },
        MultipleOptions = false,
        Flag = "TargetPlayerBodyPart",
        Callback = function(opt)
            local part = UCam.resolveDropdownValue(opt)
            if part then B.TargetSelectedPart = part end
        end,
    })
    local targetColor = Tab:CreateColorPicker({
        Name = "Color para el jugador",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "TargetPlayerPartColor",
        Callback = function() end,
    })
    local targetMaterial = Tab:CreateDropdown({
        Name = "Material para el jugador",
        Options = { "Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField" },
        CurrentOption = { "Plastic" },
        MultipleOptions = false,
        Flag = "TargetPlayerMaterial",
        Callback = function() end,
    })
    Tab:CreateButton({
        Name = "🎨 Aplicar color y material al jugador",
        Callback = function()
            local target = B.TargetPlayer
            if not target then
                UCam.notify("Cuerpo", "Selecciona un jugador objetivo.", 3)
                return
            end
            local part = B.TargetSelectedPart or "Todo"
            local mat = UCam.resolveDropdownValue(targetMaterial.CurrentOption) or "Plastic"
            UCam.applyBodyColorToPlayer(target, part, targetColor.Color, mat, nil)
            UCam.notify("Cuerpo", string.format("%s → %s de %s", mat, part, target.Name))
        end,
    })

    local lastTargetHex = nil
    Tab:CreateInput({
        Name = "HEX para el jugador",
        PlaceholderText = "Ej: #00AAFF",
        RemoveTextAfterFocusLost = false,
        Flag = "TargetPlayerHexColor",
        Callback = function(text)
            if text and text ~= "" then lastTargetHex = text end
        end,
    })
    Tab:CreateButton({
        Name = "Aplicar HEX al jugador",
        Callback = function()
            local target = B.TargetPlayer
            if not target then
                UCam.notify("Cuerpo", "Selecciona un jugador objetivo.", 3)
                return
            end
            local color = lastTargetHex and UCam.hexToColor(lastTargetHex)
            if not color then
                UCam.notify("Cuerpo", "Escribe un HEX válido.", 3)
                return
            end
            UCam.applyBodyColorToPlayer(target, B.TargetSelectedPart or "Todo", color, nil, nil)
            UCam.notify("Cuerpo", "HEX aplicado a " .. target.Name)
        end,
    })

    local targetPreset = Tab:CreateDropdown({
        Name = "Preset para el jugador",
        Options = B.PresetOptions,
        CurrentOption = { B.PresetOptions[1] },
        MultipleOptions = false,
        Flag = "TargetPreset",
        Callback = function() end,
    })
    Tab:CreateButton({
        Name = "Aplicar preset al jugador",
        Callback = function()
            local target = B.TargetPlayer
            if not target then
                UCam.notify("Cuerpo", "Selecciona un jugador objetivo.", 3)
                return
            end
            local preset = UCam.resolveDropdownValue(targetPreset.CurrentOption)
            if preset then
                UCam.applyPresetToPlayer(target, preset)
                UCam.notify("Cuerpo", "Preset '" .. preset .. "' → " .. target.Name)
            end
        end,
    })
    Tab:CreateButton({
        Name = "Copiar mi aspecto al jugador",
        Callback = function()
            local target = B.TargetPlayer
            if not target then
                UCam.notify("Cuerpo", "Selecciona un jugador objetivo.", 3)
                return
            end
            local nameMap = {
                Head = "Cabeza", Torso = "Torso",
                LeftArm = "Brazo Izq.", RightArm = "Brazo Der.",
                LeftLeg = "Pierna Izq.", RightLeg = "Pierna Der.",
            }
            for partName, data in pairs(B.Parts) do
                if data.Color or data.Material or (data.Transparency or 0) ~= 0 then
                    UCam.applyBodyColorToPlayer(target, nameMap[partName] or partName,
                        data.Color, data.Material, data.Transparency)
                end
            end
            UCam.notify("Cuerpo", "Aspecto copiado a " .. target.Name)
        end,
    })
    Tab:CreateButton({
        Name = "↩ Restaurar jugador seleccionado",
        Callback = function()
            if B.TargetPlayer then
                UCam.restorePlayerBodyColor(B.TargetPlayer)
                UCam.notify("Cuerpo", "Restaurado: " .. B.TargetPlayer.Name)
            end
        end,
    })
    Tab:CreateButton({
        Name = "🧹 Restaurar TODOS los jugadores",
        Callback = function()
            UCam.restoreAllPlayerBodyColors()
            UCam.notify("Cuerpo", "Todos restaurados.")
        end,
    })

    -- ============================================================
    -- PRESETS PERSONALIZADOS
    -- ============================================================
    Tab:CreateSection("Presets personalizados")
    Tab:CreateInput({
        Name = "Nombre del preset",
        PlaceholderText = "Mi estilo",
        RemoveTextAfterFocusLost = false,
        Flag = "CustomPresetName",
        Callback = function() end,
    })
    Tab:CreateButton({
        Name = "💾 Guardar aspecto actual",
        Callback = function()
            local flag = UCam.Rayfield.Flags and UCam.Rayfield.Flags["CustomPresetName"]
            local name = flag and (flag.CurrentValue or flag.Value) or ""
            if not name or name == "" then
                UCam.notify("Cuerpo", "Escribe un nombre.", 3)
                return
            end
            if UCam.saveBodyColorPreset(name) then
                UCam.notify("Cuerpo", "Preset guardado: " .. name)
            else
                UCam.notify("Cuerpo", "No se pudo guardar.", 3)
            end
        end,
    })

    local savedNames = {}
    for presetName in pairs(B.Presets or {}) do table.insert(savedNames, presetName) end
    if #savedNames == 0 then savedNames[1] = "(Sin presets guardados)" end
    Tab:CreateDropdown({
        Name = "Preset guardado",
        Options = savedNames,
        CurrentOption = { savedNames[1] },
        MultipleOptions = false,
        Callback = function(o)
            local name = UCam.resolveDropdownValue(o)
            if not name or name == "(Sin presets guardados)" then return end
            if UCam.loadBodyColorPreset(name) then
                local nameMap = {
                    Head = "Cabeza", Torso = "Torso",
                    LeftArm = "Brazo Izq.", RightArm = "Brazo Der.",
                    LeftLeg = "Pierna Izq.", RightLeg = "Pierna Der.",
                }
                for partName, data in pairs(B.Parts) do
                    if data.Color or data.Material or (data.Transparency or 0) ~= 0 then
                        UCam.applyBodyColorToPart(nameMap[partName] or partName,
                            data.Color, data.Material, data.Transparency)
                    end
                end
                UCam.notify("Cuerpo", "Preset cargado: " .. name)
            end
        end,
    })

end
