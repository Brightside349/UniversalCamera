-- ============================================================
-- Universal Camera Pro v12.5 · ui/props
-- Pestaña Props: trae objetos del Studio al juego de forma local.
--
-- v12.5: se quitaron los botones duplicados, se agruparon mover/rotar/
-- escalar y se agregó duplicar + empujar por ejes. La animación vive en
-- la pestaña 🎬 Animador.
-- ============================================================
local UCam = _G.UCam

function UCam.build_props(Window)
    local Tab = Window:CreateTab("🪑 Props", "package")
    local P = UCam.Props

    local propDropdown
    local function refreshList()
        pcall(function()
            local items = UCam.getPropsList()
            propDropdown:Refresh(items)
            if items[P.Selected + 1] then propDropdown:Set({ items[P.Selected + 1] }) end
        end)
    end

    -- ============================================================
    -- CREAR
    -- ============================================================
    Tab:CreateSection("Colocar un prop")
    Tab:CreateParagraph({
        Title = "Solo tú lo ves",
        Content = "Pega el ID de un asset de Roblox (mesh o modelo) y colócalo. Se crea en tu cliente y nunca se envía al servidor.",
    })
    local assetInput = ""
    Tab:CreateInput({
        Name = "ID del asset",
        PlaceholderText = "Ej: 1290033 (o rbxassetid://...)",
        RemoveTextAfterFocusLost = false,
        Callback = function(value) assetInput = value or "" end,
    })
    Tab:CreateButton({
        Name = "📍 Colocar frente a la cámara",
        Callback = function()
            local ok, msg = UCam.spawnProp(assetInput)
            if not ok then
                UCam.notify("Props", msg, 5, { important = true })
            else
                refreshList()
            end
        end,
    })
    Tab:CreateButton({
        Name = "🎯 Colocar donde miro",
        Callback = function()
            local ok, msg = UCam.spawnProp(assetInput)
            if not ok then
                UCam.notify("Props", msg, 5, { important = true })
                return
            end
            UCam.placePropWhereLooking()
            refreshList()
        end,
    })
    Tab:CreateToggle({
        Name = "Apoyar sobre el suelo (snap)",
        CurrentValue = P.SnapToGround,
        Callback = function(v) P.SnapToGround = v end,
    })
    Tab:CreateToggle({
        Name = "Nuevos props con colisión",
        CurrentValue = P.CanCollide,
        Callback = function(v) P.CanCollide = v end,
    })

    -- ============================================================
    -- SELECCIÓN
    -- ============================================================
    Tab:CreateSection("Prop seleccionado")
    propDropdown = Tab:CreateDropdown({
        Name = "Props colocados",
        Options = UCam.getPropsList(),
        CurrentOption = { "(ninguno)" },
        MultipleOptions = false,
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value then return end
            local index = tonumber(value:match("^(%d+)")) or 0
            UCam.selectProp(index)
        end,
    })
    Tab:CreateButton({
        Name = "🔄 Refrescar lista",
        Callback = refreshList,
    })

    -- ============================================================
    -- MOVER
    -- ============================================================
    Tab:CreateSection("Mover")
    Tab:CreateToggle({
        Name = "🖐 Mover con la cámara",
        CurrentValue = P.MoveMode,
        Callback = function(v)
            if v and P.Selected == 0 then
                UCam.notify("Props", "Selecciona un prop primero.", 4)
                return
            end
            UCam.attachPropToCamera(v)
        end,
    })
    Tab:CreateSlider({
        Name = "Distancia de arrastre", Range = { 2, 100 }, Increment = 1, Suffix = "st",
        CurrentValue = P.MoveDistance,
        Callback = function(v) P.MoveDistance = v end,
    })
    Tab:CreateButton({
        Name = "🎯 Colocar donde miro",
        Callback = function() UCam.placePropWhereLooking() end,
    })
    Tab:CreateButton({
        Name = "⬇ Apoyar en el suelo",
        Callback = function()
            if not UCam.snapPropToGround() then
                UCam.notify("Props", "No hay suelo debajo del prop.", 3)
            end
        end,
    })
    local nudgeStep = 2
    Tab:CreateSlider({
        Name = "Paso de empuje", Range = { 0.5, 10 }, Increment = 0.5, Suffix = "st",
        CurrentValue = nudgeStep,
        Callback = function(v) nudgeStep = v end,
    })
    Tab:CreateButton({
        Name = "← Izquierda",
        Callback = function() UCam.nudgeSelectedProp(Vector3.new(-nudgeStep, 0, 0)) end,
    })
    Tab:CreateButton({
        Name = "→ Derecha",
        Callback = function() UCam.nudgeSelectedProp(Vector3.new(nudgeStep, 0, 0)) end,
    })
    Tab:CreateButton({
        Name = "↑ Subir",
        Callback = function() UCam.nudgeSelectedProp(Vector3.new(0, nudgeStep, 0)) end,
    })
    Tab:CreateButton({
        Name = "↓ Bajar",
        Callback = function() UCam.nudgeSelectedProp(Vector3.new(0, -nudgeStep, 0)) end,
    })

    -- ============================================================
    -- ROTAR / ESCALAR
    -- ============================================================
    Tab:CreateSection("Rotar")
    local axis = "yaw"
    Tab:CreateDropdown({
        Name = "Eje",
        Options = { "Yaw (horizontal)", "Pitch (vertical)", "Roll (lateral)" },
        CurrentOption = { "Yaw (horizontal)" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v and v:match("^Pitch") then axis = "pitch"
            elseif v and v:match("^Roll") then axis = "roll"
            else axis = "yaw" end
        end,
    })
    local degrees = 15
    Tab:CreateSlider({
        Name = "Grados por giro", Range = { 1, 90 }, Increment = 1, Suffix = "°",
        CurrentValue = degrees,
        Callback = function(v) degrees = v end,
    })
    Tab:CreateButton({
        Name = "↺ Girar izquierda",
        Callback = function() UCam.rotateProp(axis, -degrees) end,
    })
    Tab:CreateButton({
        Name = "↻ Girar derecha",
        Callback = function() UCam.rotateProp(axis, degrees) end,
    })

    Tab:CreateSection("Escala y colisión")
    Tab:CreateSlider({
        Name = "Escala", Range = { 0.1, 20 }, Increment = 0.1, Suffix = "x",
        CurrentValue = 1,
        Callback = function(v) UCam.setPropScale(v) end,
    })
    Tab:CreateToggle({
        Name = "Colisión del prop seleccionado",
        CurrentValue = P.CanCollide,
        Callback = function(v) UCam.setPropCanCollide(v) end,
    })

    -- ============================================================
    -- COPIAR / BORRAR
    -- ============================================================
    Tab:CreateSection("Copiar y eliminar")
    Tab:CreateButton({
        Name = "⧉ Duplicar prop seleccionado",
        Callback = function()
            if UCam.duplicateProp() then refreshList() end
        end,
    })
    Tab:CreateButton({
        Name = "🗑 Eliminar prop seleccionado",
        Callback = function()
            if P.Selected == 0 then
                UCam.notify("Props", "Nada seleccionado.", 3)
                return
            end
            UCam.deleteProp(P.Selected)
            refreshList()
        end,
    })
    Tab:CreateButton({
        Name = "🧹 Eliminar TODOS los props",
        Callback = function()
            UCam.clearProps()
            refreshList()
        end,
    })

    Tab:CreateParagraph({
        Title = "¿Y para animarlos?",
        Content = "Usa la pestaña 🎬 Animador: guarda keyframes de uno o varios props, ajusta la duración y reproduce la línea de tiempo.",
    })

    UCam.trackConnection(UCam.Players.PlayerAdded:Connect(function()
        task.defer(refreshList)
    end), "ui.props.playerAdded")
end
