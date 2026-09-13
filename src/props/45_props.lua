-- ============================================================
-- Universal Camera Pro v11 · props/45_props
-- Props locales: trae objetos (meshes/modelos) al juego por su ID
-- de asset y colócalos donde quieras. SOLO TÚ los ves: las partes
-- se crean en el cliente y nunca se replican al servidor, igual
-- que la pantalla verde del Estudio.
--
-- Movimiento: mientras "Mover con cámara" está activo, el prop
-- seleccionado se ancla al freecam (a la distancia configurada) y
-- sigue tu mirada; al soltar queda anclado donde estaba. La rueda
-- del mouse acerca/aleja el prop durante el arrastre.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua
-- Expone (UCam.*):
--   Props (estado en 00_config),
--   spawnProp, deleteProp, clearProps, getPropsList,
--   selectProp, attachPropToCamera, placePropWhereLooking,
--   snapPropToGround, rotateProp, setPropScale, setPropCanCollide,
--   restorePropsFromData, spawnPropsFromData, clearPropsSelection
-- ============================================================
local UCam = _G.UCam

local MAX_RESTORE_FAILURES = 20

-- ============================================================
-- HELPERS INTERNOS
-- ============================================================

-- Normaliza cualquier entrada de ID (number, string, rbxassetid://...)
local function parseAssetId(value)
    if type(value) == "number" then return math.floor(value) end
    if type(value) ~= "string" then return nil end
    local id = value:match("%d+")
    if not id then return nil end
    return tonumber(id)
end

local function selectedItem()
    local P = UCam.Props
    return P.Items[P.Selected], P.Selected
end

local function propLabel(item, index)
    local name = (item and item.name and item.name ~= "") and item.name
        or ((item and item.assetId) and tostring(item.assetId) or "?")
    return string.format("%02d · %s", index, name)
end

local function notifyPropsSaved()
    if UCam.scheduleSave then UCam.scheduleSave() end
end

-- Aplica la escala uniforme al modelo/parte del prop
local function applyScale(item)
    if not (item and item.model and item.model.Parent) then return end
    local target = UCam.clamp(tonumber(item.scale) or 1, 0.05, 50)
    item.scale = target
    local ok = pcall(function()
        if item.model:IsA("Model") and item.model.ScaleTo then
            item.model:ScaleTo(target)
        elseif item.model:IsA("BasePart") then
            if item._baseSize == nil then
                item._baseSize = item.model.Size
            end
            item.model.Size = item._baseSize * target
        end
    end)
    if not ok then
        -- Algunos modelos no soportan ScaleTo: notificar una vez por prop
        if not item._scaleWarned then
            item._scaleWarned = true
            UCam.notify("Props", "Este asset no soporta escalado uniforme; prueba otro modelo.", 5)
        end
    end
end

-- Marca visual del prop seleccionado
local function refreshSelectionBox()
    local P = UCam.Props
    for i, item in ipairs(P.Items) do
        if item.box and item.box.Parent then
            pcall(function() item.box:Destroy() end)
            item.box = nil
        end
    end
    local item = selectedItem()
    if not (item and item.model and item.model.Parent) then return end
    pcall(function()
        local box = Instance.new("SelectionBox")
        box.Name = "UCam_PropSelection"
        box.Adornee = item.model
        box.LineThickness = 0.03
        box.Color3 = Color3.fromRGB(255, 170, 0)
        box.SurfaceTransparency = 1
        -- En workspace y no en la cámara: el objeto CurrentCamera se
        -- reemplaza al respawnear y la caja moriría con él.
        box.Parent = workspace
        UCam.trackInstance(box, "Props:SelectionBox")
        item.box = box
    end)
end

-- Reordena Items y ajusta índices tras borrar
local function refreshAfterDelete(removedIndex)
    local P = UCam.Props
    table.remove(P.Items, removedIndex)
    if P.Selected >= removedIndex then
        P.Selected = P.Selected - 1
    end
    if P.Selected < 1 and #P.Items > 0 then P.Selected = 1 end
    if P._attachedIndex == removedIndex then
        P._attachedIndex = 0
        P.MoveMode = false
    elseif P._attachedIndex > removedIndex then
        P._attachedIndex = P._attachedIndex - 1
    end
end

-- ============================================================
-- SPAWN
-- ============================================================

--- Descarga el asset por ID y lo coloca frente a la cámara.
-- @param assetIdValue number|string (acepta "rbxassetid://123")
-- @return ok boolean, message string
function UCam.spawnProp(assetIdValue, options)
    local P = UCam.Props
    options = options or {}

    local assetId = parseAssetId(assetIdValue)
    if not assetId then
        return false, "ID inválido. Usa el número del asset (ej: 1290033)."
    end
    if #P.Items >= P.MaxProps then
        return false, ("Tope de %d props alcanzado. Elimina alguno primero."):format(P.MaxProps)
    end

    local ok, results = pcall(function()
        return game:GetObjects("rbxassetid://" .. assetId)
    end)
    if not ok or type(results) ~= "table" or #results == 0 then
        return false, "No se pudo descargar el asset " .. assetId .. " (ID inexistente o no accesible desde tu entorno)."
    end

    -- Elegir el primer descendiente visual útil
    local model = results[1]
    if not model then
        return false, "El asset no contiene objetos colocables."
    end

    local item = {
        assetId   = assetId,
        name      = tostring(options.name or (model.Name ~= "" and model.Name or ("Prop " .. assetId))):gsub("[%c]", " "):sub(1, 60),
        model     = model,
        scale     = tonumber(options.scale) or 1,
        canCollide = options.canCollide ~= nil and options.canCollide == true or P.CanCollide,
    }

    -- Preparar el objeto para uso local
    pcall(function()
        model.Name = "UCam_Prop_" .. assetId
        local function prepare(obj)
            if obj:IsA("BasePart") then
                obj.Anchored = true
                obj.CanCollide = item.canCollide
                obj.CanQuery = true
                obj.CanTouch = false
                obj.Massless = true
            end
        end
        prepare(model)
        for _, desc in ipairs(model:GetDescendants()) do
            prepare(desc)
        end
        -- Scripts nunca deben correr (el cliente no los replicaría igual)
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("Script") or desc:IsA("LocalScript") then
                desc:Destroy()
            end
        end
    end)

    -- Posicionar frente a la cámara (o donde indiquen las options)
    local cf = options.cf
    if typeof(cf) ~= "CFrame" then
        local cam = workspace.CurrentCamera
        local camCF = cam and cam.CFrame or CFrame.new(0, 50, 0)
        local distance = UCam.clamp(P.MoveDistance or 12, 2, 500)
        cf = CFrame.new(camCF.Position + camCF.LookVector * distance)
    end
    pcall(function()
        if model:IsA("Model") then
            model:PivotTo(cf)
        elseif model:IsA("BasePart") then
            model.CFrame = cf
        end
        model.Parent = workspace
    end)
    item.cf = cf

    UCam.trackInstance(model, "Props:UCam_Prop_" .. assetId)
    table.insert(P.Items, item)
    P.Selected = #P.Items
    refreshSelectionBox()
    applyScale(item)
    notifyPropsSaved()

    if not options.silent then
        UCam.notify("Props", ("Prop #%d colocado: %s."):format(#P.Items, item.name), 4)
    end
    return true, propLabel(item, #P.Items)
end

--- Coloca N props desde la estructura persistida (loadConfig).
function UCam.spawnPropsFromData(dataList)
    if type(dataList) ~= "table" then return 0 end
    local placed, failures = 0, 0
    for _, data in ipairs(dataList) do
        if failures >= MAX_RESTORE_FAILURES then break end
        local ok, err = UCam.spawnProp(data.assetId, {
            cf = data.cf,
            scale = data.scale,
            canCollide = data.canCollide,
            name = data.name ~= "" and data.name or nil,
            silent = true,
        })
        if ok then
            placed = placed + 1
        else
            failures = failures + 1
            warn("[UCam] Prop restaurado falló (" .. tostring(data.assetId) .. "): " .. tostring(err))
        end
    end
    if placed > 0 then
        UCam.notify("Props", ("%d props locales restaurados de tu sesión anterior."):format(placed), 5)
    elseif failures > 0 then
        UCam.notify("Props", "No se pudieron restaurar los props guardados en este juego.", 5, { important = true })
    end
    return placed
end

--- Puente para 05_persistence: agrega props sin descargar assets de nuevo.
-- (No se usa hoy, pero permite restaurar sin red si el entorno cachea.)
function UCam.restorePropsFromData(dataList)
    return UCam.spawnPropsFromData(dataList)
end

-- ============================================================
-- SELECCIÓN / LISTADO
-- ============================================================

function UCam.selectProp(index)
    local P = UCam.Props
    index = math.floor(tonumber(index) or 0)
    if index < 0 or index > #P.Items then return false end
    P.Selected = index
    refreshSelectionBox()
    if P.MoveMode and index == 0 then
        P.MoveMode = false
        P._attachedIndex = 0
    end
    return true
end

function UCam.getPropsList()
    local P = UCam.Props
    local options = { "(ninguno)" }
    for i, item in ipairs(P.Items) do
        options[#options + 1] = propLabel(item, i)
    end
    return options
end

function UCam.clearPropsSelection()
    local P = UCam.Props
    P.Selected = 0
    P.MoveMode = false
    P._attachedIndex = 0
    refreshSelectionBox()
end

-- ============================================================
-- MOVER / COLOCAR
-- ============================================================

--- Activa/desactiva el arrastre del prop seleccionado con la cámara.
function UCam.attachPropToCamera(enabled)
    local P = UCam.Props
    local item, index = selectedItem()
    if enabled then
        if not item then
            UCam.notify("Props", "Selecciona un prop primero (o coloca uno nuevo).", 4)
            return false
        end
        P.MoveMode = true
        P._attachedIndex = index
        P.DragOffset = Vector3.new()
        UCam.notify("Props", ("Arrastrando '%s'. Rueda = acercar/alejar. Desactiva para soltar."):format(item.name), 4)
    else
        P.MoveMode = false
        P._attachedIndex = 0
        if item then
            -- Fijar la CFrame final en el registro para persistir bien
            pcall(function()
                if item.model:IsA("Model") then
                    item.cf = item.model:GetPivot()
                elseif item.model:IsA("BasePart") then
                    item.cf = item.model.CFrame
                end
            end)
        end
        notifyPropsSaved()
        UCam.notify("Props", "Prop soltado en su posición actual.", 3)
    end
    return true
end

--- Coloca el prop seleccionado donde mira la cámara (raycast al mundo).
function UCam.placePropWhereLooking()
    local item = selectedItem()
    if not item then
        UCam.notify("Props", "Selecciona un prop primero.", 4)
        return false
    end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local camCF = cam.CFrame
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = { UCam.character, UCam.camera }
    for _, it in ipairs(UCam.Props.Items) do
        if it.model then table.insert(exclude, it.model) end
    end
    params.FilterDescendantsInstances = exclude

    local result = workspace:Raycast(camCF.Position, camCF.LookVector * 1000, params)
    local hitCF
    if result and result.Instance then
        hitCF = CFrame.new(result.Position + result.Normal * 0.5) * (typeof(item.cf) == "CFrame" and item.cf.Rotation or CFrame.new())
    else
        -- Sin impacto: colocar a la distancia configurada frente a la cámara
        hitCF = CFrame.new(camCF.Position + camCF.LookVector * UCam.clamp(UCam.Props.MoveDistance, 2, 500))
    end
    pcall(function()
        if item.model:IsA("Model") then
            item.model:PivotTo(hitCF)
        elseif item.model:IsA("BasePart") then
            item.model.CFrame = hitCF
        end
        item.cf = hitCF
    end)
    if UCam.Props.SnapToGround then UCam.snapPropToGround() end
    notifyPropsSaved()
    return true
end

--- Apoya el prop sobre la primera superficie bajo él.
function UCam.snapPropToGround()
    local item = selectedItem()
    if not (item and item.model and item.model.Parent) then return false end
    local pivot
    pcall(function()
        pivot = item.model:IsA("Model") and item.model:GetPivot() or item.model.CFrame
    end)
    if not pivot then return false end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = { UCam.character, UCam.camera }
    for _, it in ipairs(UCam.Props.Items) do
        if it.model then table.insert(exclude, it.model) end
    end
    params.FilterDescendantsInstances = exclude

    local result = workspace:Raycast(pivot.Position + Vector3.new(0, 5, 0), Vector3.new(0, -1000, 0), params)
    if not result then return false end
    local heightOffset = 0
    pcall(function()
        if item.model:IsA("BasePart") then
            heightOffset = item.model.Size.Y / 2
        else
            local ok, bounds = pcall(function() return item.model:GetExtentsSize() end)
            if ok and bounds then heightOffset = bounds.Y / 2 end
        end
    end)
    local targetCF = CFrame.new(result.Position + Vector3.new(0, heightOffset + 0.05, 0)) * (pivot - pivot.Position)
    pcall(function()
        if item.model:IsA("Model") then
            item.model:PivotTo(targetCF)
        elseif item.model:IsA("BasePart") then
            item.model.CFrame = targetCF
        end
        item.cf = targetCF
    end)
    notifyPropsSaved()
    return true
end

--- Mueve el prop seleccionado un offset (frente/atrás según la cámara).
function UCam.nudgeProp(offset)
    local item = selectedItem()
    if not (item and item.model and item.model.Parent) then return false end
    pcall(function()
        if item.model:IsA("Model") then
            item.model:PivotTo(item.model:GetPivot() + offset)
        elseif item.model:IsA("BasePart") then
            item.model.CFrame = item.model.CFrame + offset
        end
        item.cf = item.model:IsA("Model") and item.model:GetPivot() or item.model.CFrame
    end)
    notifyPropsSaved()
    return true
end

-- ============================================================
-- ROTAR / ESCALAR / COLISIÓN
-- ============================================================

--- Rota el prop en el eje dado ("yaw", "pitch", "roll") el ángulo dado.
function UCam.rotateProp(axis, degrees)
    local item = selectedItem()
    if not (item and item.model and item.model.Parent) then return false end
    local rad = math.rad(tonumber(degrees) or 15)
    local rot
    if axis == "pitch" then
        rot = CFrame.Angles(rad, 0, 0)
    elseif axis == "roll" then
        rot = CFrame.Angles(0, 0, rad)
    else
        rot = CFrame.Angles(0, rad, 0)
    end
    pcall(function()
        if item.model:IsA("Model") then
            local pivot = item.model:GetPivot()
            -- Rotar en torno al pivot del modelo, sin desplazarlo
            item.model:PivotTo(CFrame.new(pivot.Position) * pivot.Rotation * rot)
        elseif item.model:IsA("BasePart") then
            item.model.CFrame = item.model.CFrame:ToWorldSpace(rot)
        end
        item.cf = item.model:IsA("Model") and item.model:GetPivot() or item.model.CFrame
    end)
    notifyPropsSaved()
    return true
end

function UCam.setPropScale(scale)
    local item = selectedItem()
    if not item then return false end
    item.scale = UCam.clamp(tonumber(scale) or 1, 0.05, 50)
    applyScale(item)
    notifyPropsSaved()
    return true
end

function UCam.setPropCanCollide(canCollide)
    local item = selectedItem()
    if not (item and item.model and item.model.Parent) then return false end
    item.canCollide = canCollide and true or false
    pcall(function()
        local function apply(obj)
            if obj:IsA("BasePart") then obj.CanCollide = item.canCollide end
        end
        apply(item.model)
        for _, desc in ipairs(item.model:GetDescendants()) do
            apply(desc)
        end
    end)
    notifyPropsSaved()
    return true
end

-- ============================================================
-- BORRAR
-- ============================================================

function UCam.deleteProp(index)
    local P = UCam.Props
    index = math.floor(tonumber(index) or P.Selected)
    local item = P.Items[index]
    if not item then return false end
    if item.box then
        UCam.untrackInstance(item.box)
        pcall(function() item.box:Destroy() end)
    end
    if item.model then
        UCam.untrackInstance(item.model)
        pcall(function() item.model:Destroy() end)
    end
    refreshAfterDelete(index)
    refreshSelectionBox()
    notifyPropsSaved()
    return true
end

function UCam.clearProps()
    local P = UCam.Props
    for i = #P.Items, 1, -1 do
        local item = P.Items[i]
        if item.box then
            UCam.untrackInstance(item.box)
            pcall(function() item.box:Destroy() end)
        end
        if item.model then
            UCam.untrackInstance(item.model)
            pcall(function() item.model:Destroy() end)
        end
    end
    table.clear(P.Items)
    P.Selected = 0
    P.MoveMode = false
    P._attachedIndex = 0
    refreshSelectionBox()
    notifyPropsSaved()
    UCam.notify("Props", "Todos los props eliminados.", 3)
    return true
end

-- ============================================================
-- RENDER LOOP: arrastre con la cámara + zoom con la rueda
-- ============================================================

local function updatePropsDrag()
    local P = UCam.Props
    if not P.MoveMode or P._attachedIndex == 0 then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local item = P.Items[P._attachedIndex]
    if not (item and item.model and item.model.Parent) then
        P.MoveMode = false
        P._attachedIndex = 0
        return
    end
    local camCF = cam.CFrame
    local distance = UCam.clamp((P.MoveDistance or 12) + P.DragOffset.X, 1, 500)
    local targetCF = CFrame.new(camCF.Position + camCF.LookVector * distance) * (item.cf and item.cf.Rotation or CFrame.new())
    pcall(function()
        if item.model:IsA("Model") then
            item.model:PivotTo(targetCF)
        elseif item.model:IsA("BasePart") then
            item.model.CFrame = targetCF
        end
        item.cf = targetCF
    end)
end

UCam.trackConnection(
    UCam.UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        local P = UCam.Props
        if not P.MoveMode or P._attachedIndex == 0 then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            local delta = input.Position.Z > 0 and -1 or 1
            P.DragOffset = Vector3.new(P.DragOffset.X + delta * 1.5, 0, 0)
        end
    end),
    "Props:Wheel"
)

UCam.trackConnection(
    UCam.RunService.RenderStepped:Connect(updatePropsDrag),
    "Props:Drag"
)
