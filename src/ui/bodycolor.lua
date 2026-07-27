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
            local part = UCam.BodyColor.SelectedPart
            if part then
                UCam.applyBodyColorToPart(part, color, nil, nil)
                UCam.notify("Coloreo", "Color aplicado a " .. part)
            end
        end,
    })
    
    local materialDropdown = Tab:CreateDropdown({
        Name = "Material de Parte",
        Options = {"Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField"},
        CurrentOption = {"Plastic"},
        Flag = "BodyPartMaterial",
        Callback = function(opt)
            local material = UCam.resolveDropdownValue(opt)
            local part = UCam.BodyColor.SelectedPart
            if material and part then
                UCam.applyBodyColorToPart(part, nil, material, nil)
                UCam.notify("Coloreo", "Material " .. material .. " aplicado a " .. part)
            end
        end,
    })
    
    local transparencySlider = Tab:CreateSlider({
        Name = "Transparencia",
        Range = {0, 1},
        Increment = 0.05,
        CurrentValue = 0,
        Flag = "BodyPartTransparency",
        Callback = function(value)
            local part = UCam.BodyColor.SelectedPart
            if part then
                UCam.applyBodyColorToPart(part, nil, nil, value)
            end
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
    
    local presetButtons = {
        ["Robot"] = "🤖 Robot (Metal plateado)",
        ["Fantasma"] = "👻 Fantasma (Transparente)",
        ["Demonio"] = "😈 Demonio (Neon rojo)",
        ["Dorado"] = "⭐ Dorado (Mármol dorado)",
        ["Invisible"] = "👁️ Invisible Total",
        ["Glitch"] = "⚡ Glitch (Colores aleatorios)",
    }
    
    for presetName, displayName in pairs(presetButtons) do
        Tab:CreateButton({
            Name = displayName,
            Callback = function()
                UCam.applyPreset(presetName)
                UCam.notify("Coloreo", "Preset aplicado: " .. presetName)
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
    
    local targetPlayerDropdown = Tab:CreateDropdown({
        Name = "Jugador Objetivo",
        Options = getPlayerNames(),
        CurrentOption = {""},
        Flag = "TargetPlayerBodyColor",
        Callback = function(opt)
            local playerName = UCam.resolveDropdownValue(opt)
            if playerName then
                local targetPlayer = UCam.Players:FindFirstChild(playerName)
                if targetPlayer then
                    UCam.PlayerMod.TargetPlayer = targetPlayer
                end
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "🔄 Actualizar Lista de Jugadores",
        Callback = function()
            targetPlayerDropdown:Refresh(getPlayerNames())
            UCam.notify("Coloreo", "Lista actualizada")
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
        Name = "Restaurar Jugador Seleccionado",
        Callback = function()
            if UCam.PlayerMod.TargetPlayer then
                UCam.restorePlayerBodyColor(UCam.PlayerMod.TargetPlayer)
                UCam.notify("Coloreo", "Aspecto restaurado para " .. UCam.PlayerMod.TargetPlayer.Name)
            else
                UCam.notify("Coloreo", "Selecciona un jugador primero", 3)
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
            local name = customPresetName.CurrentValue
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
• 6 presets predefinidos de transformación
• Efecto arcoíris animado configurable
• Aplicación local a otros jugadores
• Guardar/cargar presets personalizados
        ]]
    })
end
