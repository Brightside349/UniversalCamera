-- ============================================================
-- Universal Camera Pro v12.4 · ui/clones
-- Pestaña Clones: copias locales de un jugador (solo las ves tú)
-- para grabar tomas con más gente que el límite de la partida.
-- Sin lógica de runtime: solo UI que llama a actors/36_clones.lua.
-- ============================================================
local UCam = _G.UCam
local C = UCam.Clones

local function playerOptions()
    local options = { "Yo (" .. UCam.player.Name .. ")" }
    for _, player in ipairs(UCam.Players:GetPlayers()) do
        if player ~= UCam.player then
            options[#options + 1] = player.Name
        end
    end
    return options
end

local function resolvePlayer(value)
    if not value then return UCam.player end
    if value == ("Yo (" .. UCam.player.Name .. ")") then return UCam.player end
    local player = UCam.Players:FindFirstChild(value)
    return player or UCam.player
end

function UCam.build_clones(Window)
    local ClonesTab = Window:CreateTab("👥 Clones", "users")

    ClonesTab:CreateSection("Clones locales (solo tú los ves)")
    ClonesTab:CreateParagraph({
        Title   = "Cómo usar",
        Content = "Clona a cualquier jugador todas las veces que quieras, aunque la partida tenga un límite de 8 jugadores. Los clones existen solo en tu cliente: nadie más los ve y no se envían al servidor, así que no rompen el límite.\n\nCada clon copia el movimiento, los saltos y cualquier emote del original en tiempo real. Elige 'Seguir movimiento' para que se desplacen contigo o 'Fijar en el sitio' para que hagan la pose quietos, ideal para multitudes.",
    })

    ClonesTab:CreateSection("Clonar jugador")
    local playerDropdown
    playerDropdown = ClonesTab:CreateDropdown({
        Name            = "Jugador a clonar",
        Options         = playerOptions(),
        CurrentOption   = { playerOptions()[1] },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value then
                C.SourcePlayer = resolvePlayer(value)
            end
        end,
    })
    ClonesTab:CreateButton({
        Name     = "🔄 Refrescar jugadores",
        Callback = function()
            pcall(function() playerDropdown:Refresh(playerOptions()) end)
        end,
    })

    ClonesTab:CreateSlider({
        Name         = "Cantidad por clonación",
        Range        = { 1, 30 },
        Increment    = 1,
        Suffix       = "clones",
        CurrentValue = C.Count,
        Callback     = function(v) C.Count = math.floor(v) end,
    })
    ClonesTab:CreateDropdown({
        Name          = "Formación inicial",
        Options       = C.Layouts,
        CurrentOption = { C.Layout },
        MultipleOptions = false,
        Callback      = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value then C.Layout = value end
        end,
    })
    ClonesTab:CreateSlider({
        Name         = "Separación de la formación",
        Range        = { 1, 20 },
        Increment    = 0.5,
        Suffix       = " studs",
        CurrentValue = C.Spacing,
        Callback     = function(v) C.Spacing = v end,
    })
    ClonesTab:CreateDropdown({
        Name          = "Seguimiento",
        Options       = C.Modes,
        CurrentOption = { C.Mode },
        MultipleOptions = false,
        Callback      = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value then UCam.setClonesMode(value) end
        end,
    })
    local refreshCloneDropdown
    ClonesTab:CreateButton({
        Name     = "👥 Clonar jugador",
        Callback = function()
            local placed, err = UCam.spawnClones({ player = C.SourcePlayer })
            if placed == 0 then
                UCam.notify("Clones", err or "No se pudo clonar.", 5, { important = true })
            elseif refreshCloneDropdown then
                refreshCloneDropdown()
            end
        end,
    })

    ClonesTab:CreateSection("Clon seleccionado")
    local clonesDropdown
    clonesDropdown = ClonesTab:CreateDropdown({
        Name            = "Clones colocados",
        Options         = UCam.getClonesList(),
        CurrentOption   = { "(ninguno)" },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value then return end
            local index = tonumber(value:match("^(%d+)")) or 0
            UCam.selectClone(index)
        end,
    })

    refreshCloneDropdown = function()
        pcall(function()
            local items = UCam.getClonesList()
            clonesDropdown:Refresh(items)
            local selected = C.Selected
            if items[selected + 1] then
                clonesDropdown:Set({ items[selected + 1] })
            end
        end)
    end

    ClonesTab:CreateButton({
        Name     = "🔄 Refrescar lista",
        Callback = refreshCloneDropdown,
    })

    ClonesTab:CreateToggle({
        Name         = "🖱 Colocar con clic en el mapa",
        CurrentValue = C.PlaceWithCursor,
        Callback     = function(v) UCam.setClonesPlacement(v) end,
    })
    ClonesTab:CreateToggle({
        Name         = "Apoyar sobre el suelo al colocar (snap)",
        CurrentValue = C.SnapToGround,
        Callback     = function(v) C.SnapToGround = v and true or false end,
    })
    ClonesTab:CreateButton({
        Name     = "🎯 Colocar donde miro (cámara)",
        Callback = function() UCam.placeSelectedCloneWhereLooking() end,
    })
    ClonesTab:CreateButton({
        Name     = "⬇ Apoyar en el suelo",
        Callback = function() UCam.snapSelectedCloneToGround() end,
    })
    ClonesTab:CreateButton({
        Name     = "↺ Girar -15°",
        Callback = function() UCam.rotateSelectedClone(-15) end,
    })
    ClonesTab:CreateButton({
        Name     = "↻ Girar +15°",
        Callback = function() UCam.rotateSelectedClone(15) end,
    })
    ClonesTab:CreateToggle({
        Name         = "Mostrar números sobre los clones",
        CurrentValue = C.ShowLabels,
        Callback     = function(v) UCam.setCloneLabels(v) end,
    })

    ClonesTab:CreateSection("Mantenimiento")
    ClonesTab:CreateButton({
        Name     = "🔄 Actualizar apariencia de los clones",
        Callback = function() UCam.refreshClones() end,
    })
    ClonesTab:CreateButton({
        Name     = "🗑 Eliminar clon seleccionado",
        Callback = function()
            if C.Selected == 0 then
                UCam.notify("Clones", "Nada seleccionado.", 3)
                return
            end
            UCam.deleteClone(C.Selected)
            refreshCloneDropdown()
        end,
    })
    ClonesTab:CreateButton({
        Name     = "🧹 Eliminar TODOS los clones",
        Callback = function()
            UCam.clearClones(false)
            refreshCloneDropdown()
        end,
    })

    ClonesTab:CreateParagraph({
        Title   = "Consejos para la toma",
        Content = "• Los clones no bloquean la cámara ni tus raycasts: puedes colocar a uno encima de otro sin que estorben.\n• Si el juego va lento, baja la cantidad o usa 'Fijar en el sitio' (solo actualiza la pose, no el desplazamiento).\n• Al respawnear el jugador original, sus clones se reconstruyen solos en la misma posición.\n• Todo se borra al recargar el script o al pulsar 'Eliminar TODOS'.",
    })

    -- Mantener la lista de jugadores al día.
    UCam.trackConnection(UCam.Players.PlayerAdded:Connect(function()
        task.defer(function() pcall(function() playerDropdown:Refresh(playerOptions()) end) end)
    end), "ui.clones.playerAdded")
    UCam.trackConnection(UCam.Players.PlayerRemoving:Connect(function()
        task.defer(function() pcall(function() playerDropdown:Refresh(playerOptions()) end) end)
    end), "ui.clones.playerRemoving")

end
