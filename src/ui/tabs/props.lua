-- ============================================================
-- Universal Camera Pro v11 · ui/props
-- Pestaña Props: trae objetos del Studio al juego de manera local
-- (solo tú los ves) y muévelos, rótalos y escalalos.
-- Sin lógica de runtime: solo UI que llama a props/45_props.lua.
-- ============================================================
local UCam = _G.UCam

function UCam.build_props(Window)
    local PropsTab = Window:CreateTab("🪑 Props", "package")

    PropsTab:CreateSection("Props locales (solo tú los ves)")
    PropsTab:CreateParagraph({
        Title   = "Como usar",
        Content = "1) Pega el ID de un asset (mesh/modelo de Roblox, ej: 1290033) y colócalo.\n2) Selecciónalo en la lista y usa Mover con cámara para arrastrarlo con tu cámara libre (rueda del mouse = acercar/alejar).\n3) Rota, escala y ajusta colisión. Los props se guardan en tu config y reaparecen la próxima sesión en este mismo juego.",
    })

    PropsTab:CreateSection("Colocar nuevo prop")
    local assetInput = ""
    PropsTab:CreateInput({
        Name                = "ID del asset",
        PlaceholderText     = "Ej: 1290033 (también vale rbxassetid://...)",
        RemoveTextAfterFocusLost = false,
        Callback            = function(value) assetInput = value or "" end,
    })
    PropsTab:CreateButton({
        Name     = "📍 Colocar frente a la cámara",
        Callback = function()
            local ok, msg = UCam.spawnProp(assetInput)
            if not ok then
                UCam.notify("Props", msg, 5, { important = true })
            end
        end,
    })
    PropsTab:CreateButton({
        Name     = "🎯 Colocar donde miro (raycast)",
        Callback = function()
            local ok, msg = UCam.spawnProp(assetInput)
            if ok then
                -- el spawn ya selecciona el nuevo prop; colocarlo con raycast
                UCam.placePropWhereLooking()
            else
                UCam.notify("Props", msg, 5, { important = true })
            end
        end,
    })
    PropsTab:CreateToggle({
        Name         = "Apoyar sobre el suelo al colocar (snap)",
        CurrentValue = UCam.Props.SnapToGround,
        Callback     = function(v) UCam.Props.SnapToGround = v end,
    })
    PropsTab:CreateToggle({
        Name         = "Nuevos props con colisión",
        CurrentValue = UCam.Props.CanCollide,
        Callback     = function(v) UCam.Props.CanCollide = v end,
    })

    PropsTab:CreateSection("Prop seleccionado")
    local propDropdown
    propDropdown = PropsTab:CreateDropdown({
        Name            = "Props colocados",
        Options         = UCam.getPropsList(),
        CurrentOption   = { "(ninguno)" },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value then return end
            local index = tonumber(value:match("^(%d+)")) or 0
            UCam.selectProp(index)
        end,
    })
    PropsTab:CreateButton({
        Name     = "🔄 Refrescar lista",
        Callback = function()
            pcall(function()
                local current = UCam.Props.Selected
                local items = UCam.getPropsList()
                propDropdown:Refresh(items)
                if items[current + 1] then propDropdown:Set({ items[current + 1] }) end
            end)
        end,
    })

    PropsTab:CreateToggle({
        Name         = "🖐 Mover con cámara (arrastrar)",
        CurrentValue = UCam.Props.MoveMode,
        Callback     = function(v)
            if v and UCam.Props.Selected == 0 then
                UCam.notify("Props", "Selecciona un prop primero.", 4)
                return
            end
            UCam.attachPropToCamera(v)
        end,
    })
    PropsTab:CreateSlider({
        Name         = "Distancia de arrastre",
        Range        = { 2, 100 },
        Increment    = 1,
        Suffix       = "st",
        CurrentValue = UCam.Props.MoveDistance,
        Callback     = function(v) UCam.Props.MoveDistance = v end,
    })
    PropsTab:CreateButton({
        Name     = "🎯 Colocar donde miro",
        Callback = function() UCam.placePropWhereLooking() end,
    })
    PropsTab:CreateButton({
        Name     = "⬇ Apoyar en el suelo",
        Callback = function()
            if not UCam.snapPropToGround() then
                UCam.notify("Props", "No hay suelo debajo del prop.", 3)
            end
        end,
    })

    PropsTab:CreateSection("Rotación")
    PropsTab:CreateButton({
        Name     = "↺ Girar -15° (yaw)",
        Callback = function() UCam.rotateProp("yaw", -15) end,
    })
    PropsTab:CreateButton({
        Name     = "↻ Girar +15° (yaw)",
        Callback = function() UCam.rotateProp("yaw", 15) end,
    })
    PropsTab:CreateButton({
        Name     = "↺ Pitch -15°",
        Callback = function() UCam.rotateProp("pitch", -15) end,
    })
    PropsTab:CreateButton({
        Name     = "↻ Pitch +15°",
        Callback = function() UCam.rotateProp("pitch", 15) end,
    })
    PropsTab:CreateButton({
        Name     = "↺ Roll -15°",
        Callback = function() UCam.rotateProp("roll", -15) end,
    })
    PropsTab:CreateButton({
        Name     = "↻ Roll +15°",
        Callback = function() UCam.rotateProp("roll", 15) end,
    })

    PropsTab:CreateSection("Escala y colisión")
    PropsTab:CreateSlider({
        Name         = "Escala",
        Range        = { 0.1, 20 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = 1,
        Callback     = function(v) UCam.setPropScale(v) end,
    })
    PropsTab:CreateToggle({
        Name         = "Colisión del prop seleccionado",
        CurrentValue = UCam.Props.CanCollide,
        Callback     = function(v) UCam.setPropCanCollide(v) end,
    })

    PropsTab:CreateSection("Eliminar")
    PropsTab:CreateButton({
        Name     = "🗑 Eliminar prop seleccionado",
        Callback = function()
            if UCam.Props.Selected == 0 then
                UCam.notify("Props", "Nada seleccionado.", 3)
                return
            end
            UCam.deleteProp(UCam.Props.Selected)
            pcall(function() propDropdown:Refresh(UCam.getPropsList()) end)
        end,
    })
    PropsTab:CreateButton({
        Name     = "🧹 Eliminar TODOS los props",
        Callback = function()
            UCam.clearProps()
            pcall(function() propDropdown:Refresh(UCam.getPropsList()) end)
        end,
    })

    PropsTab:CreateParagraph({
        Title   = "¿Dónde encuentro IDs?",
        Content = "En Roblox Studio o en la web de Roblox, el ID está en la URL del mesh/modelo (roblox.com/library/ID). También sirven los MeshPart de tus propias creaciones si son públicos.",
    })

    -- Mantener la lista al día cuando se reconstruye la UI
    UCam.trackConnection(UCam.Players.PlayerAdded:Connect(function()
        task.defer(function()
            pcall(function() propDropdown:Refresh(UCam.getPropsList()) end)
        end)
    end), "ui.props.playerAdded")
end
