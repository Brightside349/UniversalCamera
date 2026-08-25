-- ============================================================
-- Universal Camera Pro v7 · ui/bodycolor
-- UI para el módulo de Coloreo de Cuerpo Avanzado
-- ============================================================
local UCam = _G.UCam

function UCam.build_bodycolor(Window)
    local Tab = Window:CreateTab("🎨 Cuerpo", 4483362458)
    
    -- ============================================================
    -- SECCIÓN: COLOREO POR PARTES
    -- ============================================================
    local SectionParts = Tab:CreateSection("Coloreo por Partes")
    
    Tab:CreateParagraph({
        Title = "Sistema Avanzado de Coloreo",
        Content = "Controla color, material y transparencia de cada parte del cuerpo individualmente."
    })
    
    local partDropdown = Tab:CreateDropdown({
        Name = "Seleccionar Parte",
        Options = UCam.BodyColor.PartOptions,
        CurrentOption = {UCam.BodyColor.SelectedPart},
        Flag = "BodyPartSelection",
        Callback = function(opt)
            local part = UCam.resolveDropdownValue(opt)
            if part then
                UCam.BodyColor.SelectedPart = part
            end
        end,
    })
    
    local colorPicker = Tab:CreateColorPicker({
        Name = "Color de Parte",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "BodyPartColor",
        Callback = function(color)
            -- v8.1: No notificar aquí, solo guardar el color seleccionado.
            -- El usuario aplicará con el botón "Aplicar a Todo el Cuerpo"
        end,
    })

    -- v7: Campo de código HEX para uno mismo.
    -- El callback se dispara al perder foco/Enter: aplica a la parte seleccionada.
    -- Guardamos el último texto en lastBodyHex para que el botón "TODO el cuerpo" lo reutilice.
    local lastBodyHex = nil
    Tab:CreateInput({
        Name = "Color por código HEX (#RRGGBB)",
        PlaceholderText = "Ej: #FF5500 → aplica a la parte",
        RemoveTextAfterFocusLost = false,
        Flag = "BodyPartHexColor",
        Callback = function(text)
            if not text or text == "" then return end
            lastBodyHex = text
            local color = UCam.hexToColor(text)
            if not color then
                UCam.notify("Coloreo", "Código inválido. Usa #RRGGBB (ej. #3366FF)", 4)
                return
            end
            local part = UCam.BodyColor.SelectedPart
            if not part then return end
            UCam.applyBodyColorToPart(part, color, nil, nil)
            UCam.notify("Coloreo", string.format("HEX %s → %s", text, part))
        end,
    })

    Tab:CreateButton({
        Name = "Aplicar HEX a TODO el cuerpo",
        Callback = function()
            if not lastBodyHex or lastBodyHex == "" then
                UCam.notify("Coloreo", "Primero escribe un código HEX arriba", 3)
                return
            end
            local color = UCam.hexToColor(lastBodyHex)
            if not color then
                UCam.notify("Coloreo", "Código inválido: " .. lastBodyHex, 4)
                return
            end
            UCam.applyBodyColorToPart("Todo", color, nil, nil)
            UCam.notify("Coloreo", string.format("HEX %s → todo el cuerpo", lastBodyHex))
        end,
    })

    local materialDropdown = Tab:CreateDropdown({
        Name = "Material de Parte",
        Options = {"Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField"},
        CurrentOption = {"Plastic"},
        Flag = "BodyPartMaterial",
        Callback = function(opt)
            -- v8.1: No notificar aquí, solo guardar la selección.
            -- El usuario aplicará con el botón "Aplicar a Todo el Cuerpo"
        end,
    })
    
    local transparencySlider = Tab:CreateSlider({
        Name = "Transparencia",
        Range = {0, 1},
        Increment = 0.05,
        CurrentValue = 0,
        Flag = "BodyPartTransparency",
        Callback = function(value)
            -- v8.1: No aplicar automáticamente para evitar spam.
            -- El usuario aplicará con el botón "Aplicar a Todo el Cuerpo"
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar a Parte Seleccionada",
        Callback = function()
            local part = UCam.BodyColor.SelectedPart
            if not part then
                UCam.notify("Coloreo", "Selecciona una parte primero", 3)
                return
            end
            local color = colorPicker.Color
            local material = UCam.resolveDropdownValue(materialDropdown.CurrentOption)
            local transparency = transparencySlider.CurrentValue
            
            UCam.applyBodyColorToPart(part, color, material, transparency)
            UCam.notify("Coloreo", "Configuración aplicada a " .. part)
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar a Todo el Cuerpo",
        Callback = function()
            local color = colorPicker.Color
            local material = UCam.resolveDropdownValue(materialDropdown.CurrentOption)
            local transparency = transparencySlider.CurrentValue
            
            UCam.applyBodyColorToPart("Todo", color, material, transparency)
            UCam.notify("Coloreo", "Configuración aplicada a todo el cuerpo")
        end,
    })
    
    Tab:CreateButton({
        Name = "Restaurar Colores Originales",
        Callback = function()
            UCam.restoreBodyColor()
            UCam.notify("Coloreo", "Colores restaurados")
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: PRESETS
    -- ============================================================
    local SectionPresets = Tab:CreateSection("Presets de Aspecto")
    
    Tab:CreateParagraph({
        Title = "Presets Predefinidos",
        Content = "Transformaciones completas del aspecto de tu personaje."
    })
    
    -- v9 FIX (bug UI): antes se iteraba un hash con pairs() → los botones salían
    -- en orden aleatorio en cada carga. Ahora es un array ordenado con ipairs().
    local presetButtons = {
        { name = "Robot",     label = "🤖 Robot (Metal plateado)" },
        { name = "Fantasma",  label = "👻 Fantasma (Transparente)" },
        { name = "Demonio",   label = "😈 Demonio (Neon rojo)" },
        { name = "Dorado",    label = "⭐ Dorado (Mármol dorado)" },
        { name = "Invisible", label = "👁️ Invisible Total" },
        { name = "Glitch",    label = "⚡ Glitch (Colores aleatorios)" },
    }

    for _, preset in ipairs(presetButtons) do
        Tab:CreateButton({
            Name = preset.label,
            Callback = function()
                UCam.applyPreset(preset.name)
                UCam.notify("Coloreo", "Preset aplicado: " .. preset.name)
            end,
        })
    end
    
    -- ============================================================
    -- SECCIÓN: RAINBOW (ARCOÍRIS ANIMADO)
    -- ============================================================
    local SectionRainbow = Tab:CreateSection("Arcoíris Animado")
    
    local rainbowToggle = Tab:CreateToggle({
        Name = "Activar Arcoíris",
        CurrentValue = false,
        Flag = "BodyRainbowEnabled",
        Callback = function(enabled)
            UCam.BodyColor.RainbowEnabled = enabled
            if enabled then
                UCam.initBodyColor()
                UCam.notify("Coloreo", "Arcoíris activado")
            else
                UCam.notify("Coloreo", "Arcoíris desactivado")
            end
        end,
    })
    
    Tab:CreateSlider({
        Name = "Velocidad Arcoíris",
        Range = {0.1, 5.0},
        Increment = 0.1,
        CurrentValue = 1.0,
        Flag = "BodyRainbowSpeed",
        Callback = function(value)
            UCam.BodyColor.RainbowSpeed = value
        end,
    })
    
    Tab:CreateDropdown({
        Name = "Parte con Arcoíris",
        Options = UCam.BodyColor.PartOptions,
        CurrentOption = {"Todo"},
        Flag = "BodyRainbowPart",
        Callback = function(opt)
            local part = UCam.resolveDropdownValue(opt)
            if part then
                UCam.BodyColor.RainbowPart = part
            end
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: APLICAR A OTROS JUGADORES
    -- ============================================================
    local SectionPlayers = Tab:CreateSection("Aplicar a Otros Jugadores (Local)")
    
    Tab:CreateParagraph({
        Title = "Modificar Jugadores",
        Content = "Aplica colores, materiales y presets a otros jugadores. Solo visible para ti."
    })
    
    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(UCam.Players:GetPlayers()) do
            if p ~= UCam.player then
                table.insert(names, p.Name)
            end
        end
        return names
    end
    
    local targetPlayerDropdown = UCam.registerTargetPlayerDropdown(Tab:CreateDropdown({
        Name = "Jugador Objetivo",
        Options = getPlayerNames(),
        CurrentOption = {""},
        Flag = "TargetPlayerBodyColor",
        Callback = function(opt)
            local playerName = UCam.resolveDropdownValue(opt)
            if playerName then
                local targetPlayer = UCam.Players:FindFirstChild(playerName)
                if targetPlayer then
                    UCam.setTargetPlayer(targetPlayer)
                end
            end
        end,
    }))
    
    Tab:CreateButton({
        Name = "🔄 Actualizar Lista de Jugadores",
        Callback = function()
            targetPlayerDropdown:Refresh(getPlayerNames())
            UCam.notify("Coloreo", "Lista actualizada")
        end,
    })

    -- v7: COLOREO POR PARTES A OTRO JUGADOR (incluye HEX)
    local targetPartDropdown = Tab:CreateDropdown({
        Name = "Parte a colorear (otro jugador)",
        Options = UCam.BodyColor.PartOptions,
        CurrentOption = {"Todo"},
        Flag = "TargetPlayerBodyPart",
        Callback = function(opt)
            local part = UCam.resolveDropdownValue(opt)
            if part then
                UCam.BodyColor.TargetSelectedPart = part
            end
        end,
    })
    UCam.BodyColor.TargetSelectedPart = UCam.BodyColor.TargetSelectedPart or "Todo"

    local targetColorPicker = Tab:CreateColorPicker({
        Name = "Color del otro jugador (parte)",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "TargetPlayerPartColor",
        Callback = function(color)
            -- v8.1: Solo guarda; se aplica con el botón para evitar spam
        end,
    })

    local lastTargetHex = nil
    Tab:CreateInput({
        Name = "HEX para el otro jugador (#RRGGBB)",
        PlaceholderText = "Ej: #00AAFF",
        RemoveTextAfterFocusLost = false,
        Flag = "TargetPlayerHexColor",
        Callback = function(text)
            if not text or text == "" then return end
            lastTargetHex = text
        end,
    })

    Tab:CreateButton({
        Name = "🎨 Aplicar Color → Parte del Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Coloreo", "Selecciona un jugador objetivo primero", 3)
                return
            end
            local part = UCam.BodyColor.TargetSelectedPart or "Todo"
            local color = targetColorPicker.Color
            UCam.applyBodyColorToPlayer(UCam.PlayerMod.TargetPlayer, part, color, nil, nil)
            UCam.notify("Coloreo", string.format("Color aplicado a %s → %s", part, UCam.PlayerMod.TargetPlayer.Name))
        end,
    })

    Tab:CreateButton({
        Name = "🎨 Aplicar HEX → Parte del Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Coloreo", "Selecciona un jugador objetivo primero", 3)
                return
            end
            if not lastTargetHex or lastTargetHex == "" then
                UCam.notify("Coloreo", "Escribe un código HEX arriba primero", 3)
                return
            end
            local color = UCam.hexToColor(lastTargetHex)
            if not color then
                UCam.notify("Coloreo", "Código HEX inválido: " .. lastTargetHex, 4)
                return
            end
            local part = UCam.BodyColor.TargetSelectedPart or "Todo"
            UCam.applyBodyColorToPlayer(UCam.PlayerMod.TargetPlayer, part, color, nil, nil)
            UCam.notify("Coloreo", string.format("HEX %s → %s de %s", lastTargetHex, part, UCam.PlayerMod.TargetPlayer.Name))
        end,
    })

    local targetMaterialDropdown = Tab:CreateDropdown({
        Name = "Material del otro jugador",
        Options = {"Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField"},
        CurrentOption = {"Plastic"},
        Flag = "TargetPlayerMaterial",
        Callback = function(opt)
            -- solo guarda
        end,
    })

    Tab:CreateButton({
        Name = "Aplicar Material → Parte del Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Coloreo", "Selecciona un jugador objetivo primero", 3)
                return
            end
            local part = UCam.BodyColor.TargetSelectedPart or "Todo"
            local material = UCam.resolveDropdownValue(targetMaterialDropdown.CurrentOption) or "Plastic"
            UCam.applyBodyColorToPlayer(UCam.PlayerMod.TargetPlayer, part, nil, material, nil)
            UCam.notify("Coloreo", string.format("Material %s → %s de %s", material, part, UCam.PlayerMod.TargetPlayer.Name))
        end,
    })

    Tab:CreateButton({
        Name = "Restaurar Jugador Seleccionado (colores)",
        Callback = function()
            if UCam.PlayerMod.TargetPlayer then
                UCam.restorePlayerBodyColor(UCam.PlayerMod.TargetPlayer)
                UCam.notify("Coloreo", "Colores restaurados de " .. UCam.PlayerMod.TargetPlayer.Name)
            else
                UCam.notify("Coloreo", "Selecciona un jugador primero", 3)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Copiar Mi Aspecto → Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Coloreo", "Selecciona un jugador objetivo", 3)
                return
            end
            
            -- Copy current body color configuration to target player
            for partName, data in pairs(UCam.BodyColor.Parts) do
                if data.Color or data.Material or data.Transparency ~= 0 then
                    local displayName = partName
                    -- Map internal name to display name
                    local nameMap = {
                        Head = "Cabeza",
                        Torso = "Torso",
                        LeftArm = "Brazo Izq.",
                        RightArm = "Brazo Der.",
                        LeftLeg = "Pierna Izq.",
                        RightLeg = "Pierna Der.",
                    }
                    displayName = nameMap[partName] or partName
                    
                    UCam.applyBodyColorToPlayer(
                        UCam.PlayerMod.TargetPlayer,
                        displayName,
                        data.Color,
                        data.Material,
                        data.Transparency
                    )
                end
            end
            
            UCam.notify("Coloreo", "Aspecto copiado a " .. UCam.PlayerMod.TargetPlayer.Name)
        end,
    })
    
    local targetPresetDropdown = Tab:CreateDropdown({
        Name = "Preset a Aplicar",
        Options = {"Robot", "Fantasma", "Demonio", "Dorado", "Invisible", "Glitch"},
        CurrentOption = {"Robot"},
        Flag = "TargetPreset",
        Callback = function(opt)
            -- Just store selection
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Preset a Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Coloreo", "Selecciona un jugador objetivo", 3)
                return
            end
            
            local preset = UCam.resolveDropdownValue(targetPresetDropdown.CurrentOption)
            if preset then
                UCam.applyPresetToPlayer(UCam.PlayerMod.TargetPlayer, preset)
                UCam.notify("Coloreo", "Preset '" .. preset .. "' aplicado a " .. UCam.PlayerMod.TargetPlayer.Name)
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Restaurar TODOS los Jugadores",
        Callback = function()
            UCam.restoreAllPlayerBodyColors()
            UCam.notify("Coloreo", "Todos los jugadores restaurados")
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: PRESETS PERSONALIZADOS
    -- ============================================================
    local SectionCustomPresets = Tab:CreateSection("Presets Personalizados")
    
    Tab:CreateParagraph({
        Title = "Guardar Configuraciones",
        Content = "Guarda tu configuración actual de colores y materiales como preset reutilizable."
    })
    
    local customPresetName = Tab:CreateInput({
        Name = "Nombre del Preset",
        PlaceholderText = "Mi Estilo Único",
        RemoveTextAfterFocusLost = false,
        Flag = "CustomPresetName",
        Callback = function(text)
            -- Store name
        end,
    })
    
    Tab:CreateButton({
        Name = "💾 Guardar Preset Actual",
        Callback = function()
            -- v9 FIX (bug UI): leer el valor vía UCam.Rayfield.Flags. El objeto
            -- del Input no expone .CurrentValue → antes siempre "Escribe un nombre".
            local flag = UCam.Rayfield.Flags and UCam.Rayfield.Flags["CustomPresetName"]
            local name = flag and (flag.CurrentValue or flag.Value) or ""
            if not name or name == "" then
                UCam.notify("Coloreo", "Escribe un nombre para el preset", 3)
                return
            end
            
            if UCam.saveBodyColorPreset(name) then
                UCam.notify("Coloreo", "Preset guardado: " .. name)
            else
                UCam.notify("Coloreo", "Error al guardar preset", 3)
            end
        end,
    })
    
    -- List saved presets
    if next(UCam.BodyColor.Presets) then
        Tab:CreateLabel("Presets Guardados:")
        for presetName, _ in pairs(UCam.BodyColor.Presets) do
            Tab:CreateButton({
                Name = "📌 " .. presetName,
                Callback = function()
                    if UCam.loadBodyColorPreset(presetName) then
                        -- Reapply loaded configuration
                        for partName, data in pairs(UCam.BodyColor.Parts) do
                            local displayName = partName
                            local nameMap = {
                                Head = "Cabeza",
                                Torso = "Torso",
                                LeftArm = "Brazo Izq.",
                                RightArm = "Brazo Der.",
                                LeftLeg = "Pierna Izq.",
                                RightLeg = "Pierna Der.",
                            }
                            displayName = nameMap[partName] or partName
                            
                            if data.Color or data.Material or data.Transparency ~= 0 then
                                UCam.applyBodyColorToPart(
                                    displayName,
                                    data.Color,
                                    data.Material,
                                    data.Transparency
                                )
                            end
                        end
                        UCam.notify("Coloreo", "Preset cargado: " .. presetName)
                    end
                end,
            })
        end
    end
    
    -- ============================================================
    -- SECCIÓN: INFO
    -- ============================================================
    local SectionInfo = Tab:CreateSection("Información")
    
    Tab:CreateParagraph({
        Title = "Características",
        Content = [[
• Coloreo independiente por parte del cuerpo
• Control de transparencia por parte (0-100%)
• Materiales por parte (10 opciones)
• Color por código HEX (#RRGGBB) además del selector
• 6 presets predefinidos de transformación
• Efecto arcoíris animado configurable
• Coloreo por PARTES a otros jugadores (cabeza azul, etc.)
• Color HEX directo a otros jugadores
• Aplicación local a otros jugadores
• Guardar/cargar presets personalizados
        ]]
    })
end
