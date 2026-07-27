-- ============================================================
-- Universal Camera Pro v7 · ui/poses
-- UI para el módulo de Poses Avanzadas
-- ============================================================
local UCam = _G.UCam

function UCam.build_poses(Window)
    local Tab = Window:CreateTab("🧍 Poses", 4483362458)
    
    -- ============================================================
    -- SECCIÓN: GALERÍA DE POSES
    -- ============================================================
    local SectionGallery = Tab:CreateSection("Galería de Poses")
    
    Tab:CreateParagraph({
        Title = "Sistema de Poses Avanzadas",
        Content = "19+ poses predefinidas con transiciones suaves basadas en Motor6D. Aplica poses a tu personaje o a otros jugadores de forma local."
    })
    
    local poseDropdown = Tab:CreateDropdown({
        Name = "Seleccionar Pose",
        Options = UCam.Poses.PosesList,
        CurrentOption = {UCam.Poses.Current},
        Flag = "PoseSelection",
        Callback = function(opt)
            local poseName = UCam.resolveDropdownValue(opt)
            if poseName then
                UCam.applyPose(poseName)
                if poseName ~= "Normal" then
                    UCam.initPoses()
                    UCam.notify("Poses", "Pose aplicada: " .. poseName)
                else
                    UCam.notify("Poses", "Pose restaurada a Normal")
                end
            end
        end,
    })
    
    Tab:CreateSlider({
        Name = "Velocidad de Transición",
        Range = {0.05, 1.0},
        Increment = 0.05,
        CurrentValue = UCam.Poses.TransitionSpeed,
        Flag = "PoseTransitionSpeed",
        Callback = function(value)
            UCam.Poses.TransitionSpeed = value
        end,
    })
    
    Tab:CreateButton({
        Name = "Restaurar Pose Normal",
        Callback = function()
            UCam.applyPose("Normal")
            UCam.notify("Poses", "Pose restaurada a Normal")
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: APLICAR A OTROS JUGADORES
    -- ============================================================
    local SectionPlayers = Tab:CreateSection("Aplicar a Otros Jugadores (Local)")
    
    Tab:CreateParagraph({
        Title = "Mod Local de Jugadores",
        Content = "Las modificaciones solo son visibles para ti. No se envían al servidor."
    })
    
    -- Construir lista de jugadores
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
        Flag = "TargetPlayerPose",
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
    
    -- Refresh player list button
    Tab:CreateButton({
        Name = "🔄 Actualizar Lista de Jugadores",
        Callback = function()
            targetPlayerDropdown:Refresh(getPlayerNames())
            UCam.notify("Poses", "Lista de jugadores actualizada")
        end,
    })
    
    local targetPoseDropdown = Tab:CreateDropdown({
        Name = "Pose a Aplicar",
        Options = UCam.Poses.PosesList,
        CurrentOption = {"Normal"},
        Flag = "TargetPoseSelection",
        Callback = function(opt)
            -- Store selection but don't apply yet
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar Pose al Jugador Seleccionado",
        Callback = function()
            if not UCam.PlayerMod.TargetPlayer then
                UCam.notify("Poses", "Selecciona un jugador objetivo primero", 3)
                return
            end
            
            local poseName = UCam.resolveDropdownValue(targetPoseDropdown.CurrentOption)
            if poseName then
                UCam.applyPoseToPlayer(UCam.PlayerMod.TargetPlayer, poseName)
                UCam.initPoses()
                UCam.notify("Poses", "Pose '" .. poseName .. "' aplicada a " .. UCam.PlayerMod.TargetPlayer.Name)
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Aplicar a TODOS los Jugadores",
        Callback = function()
            local poseName = UCam.resolveDropdownValue(targetPoseDropdown.CurrentOption)
            if not poseName then return end
            
            local count = 0
            for _, player in ipairs(UCam.Players:GetPlayers()) do
                if player ~= UCam.player and player.Character then
                    UCam.applyPoseToPlayer(player, poseName)
                    count = count + 1
                end
            end
            
            if count > 0 then
                UCam.initPoses()
                UCam.notify("Poses", "Pose aplicada a " .. count .. " jugadores")
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Restaurar Jugador Seleccionado",
        Callback = function()
            if UCam.PlayerMod.TargetPlayer then
                UCam.applyPoseToPlayer(UCam.PlayerMod.TargetPlayer, "Normal")
                UCam.notify("Poses", "Pose restaurada para " .. UCam.PlayerMod.TargetPlayer.Name)
            else
                UCam.notify("Poses", "Selecciona un jugador primero", 3)
            end
        end,
    })
    
    Tab:CreateButton({
        Name = "Restaurar TODOS los Jugadores",
        Callback = function()
            UCam.restoreAllPlayerPoses()
            UCam.notify("Poses", "Todas las poses de jugadores restauradas")
        end,
    })
    
    -- ============================================================
    -- SECCIÓN: POSES CUSTOM
    -- ============================================================
    local SectionCustom = Tab:CreateSection("Poses Personalizadas")
    
    Tab:CreateParagraph({
        Title = "Guardar Poses",
        Content = "Aplica una pose, ajústala manualmente si es necesario, y guárdala como preset personalizado."
    })
    
    local customPoseName = Tab:CreateInput({
        Name = "Nombre de Pose Custom",
        PlaceholderText = "Mi Pose Épica",
        RemoveTextAfterFocusLost = false,
        Flag = "CustomPoseName",
        Callback = function(text)
            -- Store name
        end,
    })
    
    Tab:CreateButton({
        Name = "💾 Guardar Pose Actual",
        Callback = function()
            local name = customPoseName.CurrentValue
            if not name or name == "" then
                UCam.notify("Poses", "Escribe un nombre para la pose", 3)
                return
            end
            
            if UCam.savePoseSnapshot(name) then
                poseDropdown:Refresh(UCam.Poses.PosesList)
                targetPoseDropdown:Refresh(UCam.Poses.PosesList)
                UCam.notify("Poses", "Pose guardada: " .. name)
            else
                UCam.notify("Poses", "Error al guardar pose", 3)
            end
        end,
    })
    
    -- List saved custom poses
    if next(UCam.Poses.CustomPoses) then
        Tab:CreateLabel("Poses Guardadas:")
        for poseName, _ in pairs(UCam.Poses.CustomPoses) do
            Tab:CreateButton({
                Name = "📌 " .. poseName,
                Callback = function()
                    UCam.applyPose(poseName)
                    UCam.initPoses()
                    UCam.notify("Poses", "Cargada: " .. poseName)
                end,
            })
        end
    end
    
    -- ============================================================
    -- SECCIÓN: INFO
    -- ============================================================
    local SectionInfo = Tab:CreateSection("Información")
    
    Tab:CreateParagraph({
        Title = "Categorías de Poses",
        Content = [[
• Clásicas: T-Pose, A-Pose, Sentado, Flotando
• Expresivas: Dab, Superhero Landing, Victoria, Manos Arriba
• Relajadas: Meditando, Acostado, Recostado, Durmiendo
• Divertidas: Zombie Walk, Robot, Bailando
• Cinemáticas: Caída Dramática, Pose de Acción, Caminando
        ]]
    })
end
