-- ============================================================
-- Universal Camera Pro v7 · ui/playermod
-- UI para el módulo de Modificación de Jugadores
-- ============================================================
local UCam = _G.UCam

function UCam.build_playermod(Window)
    local Tab = Window:CreateTab("👥 Mod Jugadores", 4483362458)
    
    -- ============================================================
    -- SECCIÓN: INTRODUCCIÓN
    -- ============================================================
    local SectionIntro = Tab:CreateSection("Modificar Otros Jugadores")
    
    Tab:CreateParagraph({
        Title = "Sistema de Modificación Local",
        Content = "Hub central para aplicar poses, colores, escala, efectos e invisibilidad a otros jugadores. TODAS las modificaciones son locales (solo tú las ves, no se envían al servidor)."
    })
    
    -- ============================================================
    -- SECCIÓN: SELECCIÓN DE JUGADOR
    -- ============================================================
    local SectionSelection = Tab:CreateSection("Seleccionar Jugador")
    
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
        Flag = "PlayerModTarget",
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
            UCam.notify("Mod Jugadores", "Lista actualizada")
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: POSES
    -- ============================================================
    local SectionPoses = Tab:CreateSection("Poses")
    
    local poseDropdown = Tab:CreateDropdown({
        Name = "Seleccionar Pose",
        Options = UCam.Poses.PosesList,
        CurrentOption = {"Normal"},
        Flag = "PlayerModPose",
        Callback = function(opt)
            -- Store selection
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Pose → Jugador Seleccionado",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                return
            end
            
            local pose = UCam.resolveDropdownValue(poseDropdown.CurrentOption)
            if pose then
                local config = { pose = pose }
                if UCam.applyModToPlayer(UCam.PlayerMod.TargetPlayer, config) then
                    UCam.initPlayerMod()
                    if UCam.initPoses then UCam.initPoses() end
                    UCam.notify("Mod Jugadores", "Pose '" .. pose .. "' aplicada a " .. UCam.PlayerMod.TargetPlayer.Name)
                end
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Pose → TODOS los Jugadores",
        Callback = function()
            local pose = UCam.resolveDropdownValue(poseDropdown.CurrentOption)
            if pose then
                local config = { pose = pose }
                local count = UCam.applyModToAllPlayers(config)
                if count > 0 then
                    UCam.initPlayerMod()
                    if UCam.initPoses then UCam.initPoses() end
                    UCam.notify("Mod Jugadores", "Pose aplicada a " .. count .. " jugadores")
                end
            end
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: COLORES Y ASPECTO
    -- ============================================================
    local SectionColors = Tab:CreateSection("Colores y Aspecto")
    
    local colorPicker = Tab:CreateColorPicker({
        Name = "Color del Jugador",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "PlayerModColor",
        Callback = function(color)
            -- Store selection
        end,
    })
    
    local materialDropdown = Tab:CreateDropdown({
        Name = "Material",
        Options = {"Plastic", "Neon", "Metal", "Glass", "Wood", "Marble", "ForceField"},
        CurrentOption = {"Plastic"},
        Flag = "PlayerModMaterial",
        Callback = function(opt)
            -- Store selection
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Color/Material → Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                return
            end
            
            local color = colorPicker.Color
            local material = UCam.resolveDropdownValue(materialDropdown.CurrentOption)
            
            local config = { color = color, material = material }
            if UCam.applyModToPlayer(UCam.PlayerMod.TargetPlayer, config) then
                UCam.initPlayerMod()
                UCam.notify("Mod Jugadores", "Aspecto aplicado a " .. UCam.PlayerMod.TargetPlayer.Name)
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Copiar Mi Aspecto → Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                return
            end
            
            if UCam.copyMyAspectToPlayer(UCam.PlayerMod.TargetPlayer) then
                UCam.initPlayerMod()
                UCam.notify("Mod Jugadores", "Tu aspecto copiado a " .. UCam.PlayerMod.TargetPlayer.Name)
            end
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: ESCALA
    -- ============================================================
    local SectionScale = Tab:CreateSection("Escala")
    
    local scaleSlider = Tab:CreateSlider({
        Name = "Escala del Jugador",
        Range = {0.1, 10},
        Increment = 0.1,
        CurrentValue = 1.0,
        Flag = "PlayerModScale",
        Callback = function(value)
            -- Store selection
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Escala → Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                return
            end
            
            local scale = scaleSlider.CurrentValue
            UCam.setPlayerScale(UCam.PlayerMod.TargetPlayer, scale)
            UCam.initPlayerMod()
            UCam.notify("Mod Jugadores", "Escala " .. scale .. "x aplicada a " .. UCam.PlayerMod.TargetPlayer.Name)
        end,
    })
    
    Tab:CreateButton({
        Name = "Diminuto (0.3x)",
        Callback = function()
            if UCam.PlayerMod.TargetPlayer then
                UCam.setPlayerScale(UCam.PlayerMod.TargetPlayer, 0.3)
                UCam.initPlayerMod()
                UCam.notify("Mod Jugadores", "Jugador reducido")
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Gigante (5x)",
        Callback = function()
            if UCam.PlayerMod.TargetPlayer then
                UCam.setPlayerScale(UCam.PlayerMod.TargetPlayer, 5.0)
                UCam.initPlayerMod()
                UCam.notify("Mod Jugadores", "Jugador agrandado")
            end
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: EFECTOS
    -- ============================================================
    local SectionEffects = Tab:CreateSection("Efectos")
    
    Tab:CreateButton({
        Name = "Invisibilidad → Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                return
            end
            
            UCam.setPlayerInvisibility(UCam.PlayerMod.TargetPlayer, true)
            UCam.initPlayerMod()
            UCam.notify("Mod Jugadores", UCam.PlayerMod.TargetPlayer.Name .. " ahora es invisible")
        end,
    })
    
    local glowColorPicker = Tab:CreateColorPicker({
        Name = "Color del Resplandor",
        Color = Color3.fromRGB(0, 255, 200),
        Flag = "PlayerModGlowColor",
        Callback = function(color)
            -- Store selection
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Resplandor → Jugador",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                return
            end
            
            local glowColor = glowColorPicker.Color
            local effects = { glow = true, glowColor = glowColor }
            UCam.applyEffectsToPlayer(UCam.PlayerMod.TargetPlayer, effects)
            UCam.initPlayerMod()
            UCam.notify("Mod Jugadores", "Resplandor aplicado a " .. UCam.PlayerMod.TargetPlayer.Name)
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: PRESETS RÁPIDOS
    -- ============================================================
    local SectionPresets = Tab:CreateSection("Presets Rápidos")
    
    Tab:CreateParagraph({
        Title = "Transformaciones Rápidas",
        Content = "Aplica configuraciones predefinidas con un clic."
    })
    
    local presetButtons = {
        { name = "Gigante", icon = "🗿" },
        { name = "Diminuto", icon = "🐜" },
        { name = "Fantasma", icon = "👻" },
        { name = "T-Pose", icon = "🤖" },
        { name = "Invisible", icon = "👁️" },
        { name = "Dorado", icon = "⭐" },
        { name = "Neon", icon = "✨" },
    }
    
    for _, preset in ipairs(presetButtons) do
        Tab:CreateButton({
            Name = preset.icon .. " " .. preset.name,
            Callback = function()
                if not UCam.PlayerMod.TargetPlayer then
                    UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
                    return
                end
                
                if UCam.applyPresetToPlayer(UCam.PlayerMod.TargetPlayer, preset.name) then
                    UCam.initPlayerMod()
                    if UCam.initPoses then UCam.initPoses() end
                    UCam.notify("Mod Jugadores", "Preset '" .. preset.name .. "' aplicado")
                end
            end,
        })
    end
    
    -- ============================================================
    -- SECCIÓN: GESTIÓN MÚLTIPLE
    -- ============================================================
    local SectionMultiple = Tab:CreateSection("Gestión Múltiple")
    
    Tab:CreateParagraph({
        Title = "Aplicar a Varios Jugadores",
        Content = "Aplica efectos a múltiples jugadores simultáneamente."
    })
    
    local selectedPresetDropdown = Tab:CreateDropdown({
        Name = "Preset para Todos",
        Options = {"Gigante", "Diminuto", "Fantasma", "T-Pose", "Invisible", "Dorado", "Neon"},
        CurrentOption = {"T-Pose"},
        Flag = "MultiPlayerPreset",
        Callback = function(opt)
            -- Store selection
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Preset → TODOS",
        Callback = function()
            local preset = UCam.resolveDropdownValue(selectedPresetDropdown.CurrentOption)
            if preset then
                local count = UCam.applyPresetToAllPlayers(preset)
                if count > 0 then
                    UCam.initPlayerMod()
                    if UCam.initPoses then UCam.initPoses() end
                    UCam.notify("Mod Jugadores", "Preset aplicado a " .. count .. " jugadores")
                end
            end
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: RESTAURAR
    -- ============================================================
    local SectionRestore = Tab:CreateSection("Restaurar")
    
    Tab:CreateButton({
        Name = "Restaurar Jugador Seleccionado",
        Callback = function()
            if UCam.PlayerMod.TargetPlayer then
                UCam.restorePlayer(UCam.PlayerMod.TargetPlayer)
                UCam.notify("Mod Jugadores", UCam.PlayerMod.TargetPlayer.Name .. " restaurado")
            else
                UCam.notify("Mod Jugadores", "Selecciona un jugador primero", 3)
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "⚠️ Restaurar TODOS los Jugadores",
        Callback = function()
            UCam.restoreAllPlayers()
            UCam.notify("Mod Jugadores", "Todos los jugadores restaurados")
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: INFO
    -- ============================================================
    local SectionInfo = Tab:CreateSection("Información")
    
    Tab:CreateParagraph({
        Title = "Características",
        Content = [[
✓ Aplicar 19+ poses a otros jugadores
✓ Cambiar colores y materiales
✓ Escalar jugadores (0.1x - 10x)
✓ Invisibilidad local
✓ Efectos de resplandor (Highlight)
✓ Copiar tu aspecto a otros
✓ 7 presets rápidos
✓ Aplicar a todos simultáneamente
✓ TODO es LOCAL (no se ve en el servidor)

Nota: Las modificaciones se pierden si el jugador respawnea.
        ]]
    })
end
