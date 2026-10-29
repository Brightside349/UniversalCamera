-- ============================================================
-- Universal Camera Pro v12.6 · actors/36_clones
-- Clones locales de un jugador: copias de su personaje que SOLO
-- existen en tu cliente (nadie más las ve) y que no cuentan para el
-- límite de jugadores de la partida. Sirven para grabar tomas con
-- muchos personajes sin invitar a nadie.
--
-- El clon copia las CFrames de las partes del original en cada frame,
-- así reproduce caminar, correr, saltar y cualquier emote sin enviar
-- nada al servidor. Dos modos:
--   "Seguir movimiento": el clon se desplaza igual que el original
--                        conservando la distancia con la que lo pusiste.
--   "Fijar en el sitio":  reproduce la pose/emote pero se queda donde
--                        lo colocaste (ideal para multitudes).
--
-- Dependencias: core/00_config.lua, core/10_utils.lua
-- Expone (UCam.*):
--   Clones (estado en 00_config),
--   spawnClones, deleteClone, clearClones, selectClone, getClonesList,
--   setClonesMode, setClonesPlacement, setCloneLabels,
--   placeSelectedCloneAtCursor, placeSelectedCloneWhereLooking,
--   snapSelectedCloneToGround, rotateSelectedClone,
--   rebuildClonesFor, refreshClones, stopClones
--
-- v12.7: diseño capturado. Cada clon guarda el modelo con el que se creó
-- (KeepDesign). Si el jugador cambia de personaje con el panel del juego,
-- el clon mantiene ese diseño y sigue copiando el movimiento del personaje
-- nuevo emparejando partes por rol de rig (R6/R15). Expone además
-- setClonesKeepDesign, recaptureCloneDesign, getCloneTargets y
-- getCloneByLabel (este último para pintar clones desde "Cuerpo").
-- ============================================================
local UCam = _G.UCam
local C = UCam.Clones

local MODE_FOLLOW = "Seguir movimiento"
local LAYOUT_GRID = "Cuadricula"
local LAYOUT_ROW  = "Fila"
local LAYOUT_RING = "Circulo"

-- ============================================================
-- HELPERS INTERNOS
-- ============================================================

--- Devuelve personaje/vida/raíz del jugador si están listos.
local function sourceCharacter(player)
    if not player or not player:IsA("Player") then return nil end
    local char = player.Character
    if not char or not char.Parent then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then return nil end
    return char, humanoid, root
end

local function selectedClone()
    local clone = C.Items[C.Selected]
    return clone, C.Selected
end

--- Ruta relativa de una instancia dentro del personaje ("Hat/Handle").
-- Empareja original y clon aunque haya varias piezas con el mismo nombre.
local function relativePath(model, inst)
    local names = {}
    local node = inst
    while node and node ~= model do
        table.insert(names, 1, node.Name)
        node = node.Parent
    end
    return table.concat(names, "/")
end

--- Empareja cada BasePart del original con su equivalente en el clon.
-- v12.6: indices por cubo en vez de table.remove(1), que era O(n) por
-- parte y se notaba al clonar 30 personajes de golpe.
local function buildPartPairs(char, clone)
    local buckets = {}
    for _, desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("BasePart") then
            local key = relativePath(clone, desc)
            local bucket = buckets[key]
            if bucket then
                bucket[#bucket + 1] = desc
            else
                buckets[key] = { desc }
            end
        end
    end

    local cursor = {}
    local pairs_ = {}
    local count = 0
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local key = relativePath(char, desc)
            local bucket = buckets[key]
            if bucket then
                local index = (cursor[key] or 0) + 1
                local match = bucket[index]
                if match then
                    cursor[key] = index
                    count = count + 1
                    pairs_[count] = { orig = desc, clone = match }
                end
            end
        end
    end
    return pairs_
end

-- ============================================================
-- v12.7: DISEÑO CAPTURADO Y CAMBIO DE PERSONAJE
-- Un clon se crea a partir del modelo del jugador en ese momento. Si el
-- juego permite cambiar de personaje (paneles de selección, private servers),
-- el clon puede seguir usando el diseño viejo y aun así copiar el movimiento
-- del personaje nuevo: las partes se emparejan por rol de rig (R6/R15) en
-- vez de por ruta exacta.
-- ============================================================

local function normalizeName(name)
    return (name:lower():gsub("[%s_%-]", ""))
end

--- Rol de rig de una parte. Los rigs R6 y R15 usan nombres distintos para
-- el mismo hueso, así que se agrupan por rol equivalente.
local RIG_ROLE = {
    humanoidrootpart = "root",
    head             = "head",
    torso            = "torso",
    uppertorso       = "torso",
    lowertorso       = "torso",
    leftarm          = "larm",
    leftupperarm     = "larm",
    leftlowerarm     = "larm_low",
    lefthand         = "larm_hand",
    rightarm         = "rarm",
    rightupperarm    = "rarm",
    rightlowerarm    = "rarm_low",
    righthand        = "rarm_hand",
    leftleg          = "lleg",
    leftupperleg     = "lleg",
    leftlowerleg     = "lleg_low",
    leftfoot         = "lleg_foot",
    rightleg         = "rleg",
    rightupperleg    = "rleg",
    rightlowerleg    = "rleg_low",
    rightfoot        = "rleg_foot",
}

--- Roles que se prueban, en orden, cuando el rol exacto no existe en el
-- personaje nuevo (por ejemplo clon R6 y original R15).
local ROLE_FALLBACK = {
    torso     = { "torso" },
    larm      = { "larm", "larm_low" },
    larm_low  = { "larm_low", "larm" },
    larm_hand = { "larm_hand", "larm_low", "larm" },
    rarm      = { "rarm", "rarm_low" },
    rarm_low  = { "rarm_low", "rarm" },
    rarm_hand = { "rarm_hand", "rarm_low", "rarm" },
    lleg      = { "lleg", "lleg_low" },
    lleg_low  = { "lleg_low", "lleg" },
    lleg_foot = { "lleg_foot", "lleg_low", "lleg" },
    rleg      = { "rleg", "rleg_low" },
    rleg_low  = { "rleg_low", "rleg" },
    rleg_foot = { "rleg_foot", "rleg_low", "rleg" },
}

--- Parte que sirve de apoyo rígido cuando no hay equivalente directo.
local ROLE_ANCHOR = {
    larm_low = "larm", larm_hand = "larm",
    rarm_low = "rarm", rarm_hand = "rarm",
    lleg_low = "lleg", lleg_foot = "lleg",
    rleg_low = "rleg", rleg_foot = "rleg",
}

--- Empareja las partes del MODELO DEL CLON (diseño que se conserva) con las
-- partes del personaje actual del jugador. Primero por ruta exacta, luego
-- por rol de rig y, si no hay equivalente, la parte se mueve rígida junto a
-- su parte de apoyo (así un antebrazo no se queda flotando).
local function buildDesignPairs(model, char)
    local byPath, byRole = {}, {}
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local path = relativePath(char, desc)
            if byPath[path] == nil then byPath[path] = desc end
            local role = RIG_ROLE[normalizeName(desc.Name)]
            if role then
                local list = byRole[role]
                if list then
                    list[#list + 1] = desc
                else
                    byRole[role] = { desc }
                end
            end
        end
    end

    local pairs_ = {}
    local anchorOf = {}
    local unmatched = {}
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            local role = RIG_ROLE[normalizeName(desc.Name)]
            local orig = byPath[relativePath(model, desc)]
            if not orig and role then
                local candidates = ROLE_FALLBACK[role] or { role }
                for _, candidate in ipairs(candidates) do
                    local list = byRole[candidate]
                    if list and #list > 0 then
                        orig = table.remove(list, 1)
                        break
                    end
                end
            end
            if orig then
                pairs_[#pairs_ + 1] = { orig = orig, clone = desc }
                if role and not anchorOf[role] then anchorOf[role] = pairs_[#pairs_] end
            else
                unmatched[#unmatched + 1] = { clone = desc, role = role }
            end
        end
    end

    for _, entry in ipairs(unmatched) do
        -- Solo se anclan partes de rig. Los accesorios y herramientas sin
        -- equivalente se dejan como están: sus soldaduras los siguen solas.
        -- El apoyo es la parte emparejada más cercana (antebrazo → brazo,
        -- pie → pierna) o la raíz.
        local anchor = nil
        if entry.role then
            anchor = anchorOf[ROLE_ANCHOR[entry.role] or "root"] or anchorOf.root
        end
        if anchor and anchor.clone and anchor.orig then
            local anchorPart = anchor.clone
            local ok, rel = pcall(function()
                return anchorPart.CFrame:ToObjectSpace(entry.clone.CFrame)
            end)
            if ok and rel then
                pairs_[#pairs_ + 1] = {
                    orig  = anchor.orig,
                    clone = entry.clone,
                    rel   = rel,
                }
            end
        end
    end

    return pairs_
end

--- Reengancha un clon al personaje actual de su jugador SIN tocar su modelo.
local function rebindDesign(clone, char, root)
    if not (clone and clone.model and clone.model.Parent and char and root) then return false end
    clone._lastRebind = char
    local newPairs = buildDesignPairs(clone.model, char)
    if #newPairs == 0 then return false end
    clone.pairs         = newPairs
    clone.sourceChar    = char
    clone.sourceRoot    = root
    clone.baseRoot      = (C.Mode == MODE_FOLLOW) and root.CFrame or nil
    clone._baseRootInv  = nil
    clone._baseRootCached = nil
    clone.lastRootPos   = root.Position
    clone._lastBase     = nil
    return true
end

--- Altura de la raíz sobre los pies, para apoyar el clon en el suelo.
local function computeFootOffset(char, root)
    local lowest = math.huge
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local bottom = desc.Position.Y - desc.Size.Y * 0.5
            if bottom < lowest then lowest = bottom end
        end
    end
    if lowest == math.huge then return root.Size.Y * 0.5 end
    return math.clamp(root.Position.Y - lowest, 0.5, 12)
end

--- Deja el modelo del clon listo: anclado, sin colisión ni scripts.
local function prepareCloneModel(model)
    local doomed = {}
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored = true
            desc.CanCollide = false
            desc.CanQuery = false
            desc.CanTouch = false
            desc.Massless = true
            -- v12.6: las sombras de 40 personajes son caras en el shadow map.
            desc.CastShadow = (C.CastShadows ~= false)
        elseif desc:IsA("Script") or desc:IsA("LocalScript") then
            table.insert(doomed, desc)
        end
    end
    for _, desc in ipairs(doomed) do
        pcall(function() desc:Destroy() end)
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.BreakJointsOnDeath = false
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoRotate = false
        -- v12.6: al copiar CFrames no necesitamos la maquina de estados,
        -- salud, nametag ni fisica del Humanoid. Apagarlo quita trabajo
        -- por personaje sin cambiar el aspecto del clon.
        if C.DisableHumanoid ~= false then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                humanoid.Enabled = false
                -- Evaluar la maquina de estados cuesta por personaje incluso
                -- con el Humanoid apagado; en clientes nuevos se puede cortar.
                humanoid.EvaluateStateMachine = false
            end)
            -- El Animator evalua pistas cada frame y nosotros ya escribimos
            -- los CFrames absolutos: sin animador no se pelea con el espejo.
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                pcall(function() animator:Destroy() end)
            end
        end
    end

    local root = model:FindFirstChild("HumanoidRootPart")
    if root then model.PrimaryPart = root end
end

--- Si tu personaje está oculto (Transparency = 1), los clones deben
-- seguir viéndose: recupera la transparencia real guardada por el HUD.
local function applyCloneTransparency(char, clone)
    local saved = UCam.Hud and UCam.Hud.Transparencies
    if not (UCam.Hud and UCam.Hud.CharacterHidden) then return end

    local map = {}
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Decal") then
            local value = desc.Transparency
            if saved and saved[desc] ~= nil then value = saved[desc] end
            map[relativePath(char, desc)] = value
        end
    end
    for _, desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("BasePart") or desc:IsA("Decal") then
            local value = map[relativePath(clone, desc)]
            if value ~= nil then desc.Transparency = value end
        end
    end
end

--- Etiqueta opcional con el número del clon (ayuda a ubicarlo).
local function applyLabel(clone)
    local root = clone.model and clone.model:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local old = root:FindFirstChild("UCamCloneTag")
    if old then old:Destroy() end
    if not C.ShowLabels then return end

    local gui = Instance.new("BillboardGui")
    gui.Name = "UCamCloneTag"
    gui.Size = UDim2.fromOffset(36, 20)
    gui.StudsOffset = Vector3.new(0, 2.4, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(255, 210, 90)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Text = string.format("%02d", clone.index or 0)
    label.Parent = gui
    gui.Parent = root
end

local function renumberClones()
    for i, clone in ipairs(C.Items) do
        clone.index = i
        applyLabel(clone)
    end
end

--- Parámetros de raycast que ignoran personajes y clones.
local function buildRaycastParams()
    local exclude = {}
    if UCam.character then table.insert(exclude, UCam.character) end
    for _, player in ipairs(UCam.Players:GetPlayers()) do
        if player.Character then table.insert(exclude, player.Character) end
    end
    for _, clone in ipairs(C.Items) do
        if clone.model then table.insert(exclude, clone.model) end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    params.IgnoreWater = true
    return params
end

--- Posición del cursor proyectada sobre el mapa (nil si mira al cielo).
local function cursorWorldPoint()
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    local origin, direction
    local playerMouse = UCam.player:GetMouse()
    if playerMouse and playerMouse.UnitRay then
        origin = playerMouse.UnitRay.Origin
        direction = playerMouse.UnitRay.Direction
    else
        local loc = UCam.UserInputService:GetMouseLocation()
        local ray = cam:ViewportPointToRay(loc.X, loc.Y)
        origin, direction = ray.Origin, ray.Direction
    end
    if not origin or not direction then return nil end

    local result = workspace:Raycast(origin, direction * 4000, buildRaycastParams())
    if not result then return nil end
    return result.Position
end

--- Punto del mapa donde mira el centro de la cámara.
local function cameraWorldPoint()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local result = workspace:Raycast(
        cam.CFrame.Position,
        cam.CFrame.LookVector * 4000,
        buildRaycastParams()
    )
    if not result then return nil end
    return result.Position
end

--- Suelo justo debajo de un punto (para snap vertical).
local function groundPointBelow(point, dropHeight)
    local result = workspace:Raycast(
        point + Vector3.new(0, 4, 0),
        Vector3.new(0, -(4 + (dropHeight or 500)), 0),
        buildRaycastParams()
    )
    if result then return result.Position end
    return nil
end

local function positionCloneAt(clone, worldPoint)
    if not (clone and worldPoint) then return false end
    local point = worldPoint
    if C.SnapToGround then
        local ground = groundPointBelow(worldPoint)
        if ground then point = ground end
    end
    local anchor = CFrame.new(point + Vector3.new(0, clone.footOffset + 0.05, 0))
        * clone.anchorCF.Rotation
    clone.anchorCF = anchor

    -- En modo "Seguir", fijar la referencia actual para que el clon
    -- aparezca justo donde acabas de hacer clic.
    if C.Mode == MODE_FOLLOW then
        local _, _, root = sourceCharacter(clone.source)
        clone.baseRoot = root and root.CFrame or nil
    end
    return true
end

-- ============================================================
-- CREACIÓN DE MODELOS
-- ============================================================

--- Crea el modelo clonado y lo posiciona en su anclaje.
local function instantiateClone(char, root, anchorCF, baseRoot, footOffset)
    local ok, model = pcall(function() return char:Clone() end)
    if not ok or not model then return nil end

    model.Name = "UCam_Clone"
    prepareCloneModel(model)
    applyCloneTransparency(char, model)

    local partPairs = buildPartPairs(char, model)
    if #partPairs == 0 then
        pcall(function() model:Destroy() end)
        return nil
    end

    local clone = {
        model      = model,
        pairs      = partPairs,
        sourceChar = char,
        sourceRoot = root,
        anchorCF   = anchorCF,
        baseRoot   = (C.Mode == MODE_FOLLOW) and (baseRoot or root.CFrame) or nil,
        footOffset = footOffset,
    }

    -- Posicionar antes de entrar al workspace: evita un frame en el
    -- sitio original con todos los clones amontonados.
    local base
    if C.Mode == MODE_FOLLOW and clone.baseRoot then
        base = anchorCF * clone.baseRoot:Inverse()
    else
        base = anchorCF * root.CFrame:Inverse()
    end
    for i = 1, #partPairs do
        partPairs[i].clone.CFrame = base * partPairs[i].orig.CFrame
    end

    model.Parent = workspace
    UCam.trackInstance(model, "Clones:model")
    return clone
end

--- Rehace el modelo de un clon (respawn o cambio de apariencia).
local function rebuildOne(clone, char, root)
    local ok, model = pcall(function() return char:Clone() end)
    if not ok or not model then return false end

    model.Name = "UCam_Clone"
    prepareCloneModel(model)
    applyCloneTransparency(char, model)

    local partPairs = buildPartPairs(char, model)
    if #partPairs == 0 then
        pcall(function() model:Destroy() end)
        return false
    end

    local oldModel = clone.model
    clone.model = model
    clone.pairs = partPairs
    clone.sourceChar = char
    clone.sourceRoot = root
    clone.footOffset = computeFootOffset(char, root)
    clone.baseRoot = (C.Mode == MODE_FOLLOW) and root.CFrame or nil
    -- v12.7: el modelo cambió, así que el espejo debe reescribir todo.
    clone._lastBase = nil
    clone._lastRebind = char
    clone._baseRootCached = nil
    clone._baseRootInv = nil

    local base
    if C.Mode == MODE_FOLLOW and clone.baseRoot then
        base = clone.anchorCF * clone.baseRoot:Inverse()
    else
        base = clone.anchorCF * root.CFrame:Inverse()
    end
    for i = 1, #partPairs do
        partPairs[i].clone.CFrame = base * partPairs[i].orig.CFrame
    end

    model.Parent = workspace
    UCam.trackInstance(model, "Clones:model")
    if oldModel then
        UCam.untrackInstance(oldModel)
        pcall(function() oldModel:Destroy() end)
    end
    applyLabel(clone)
    return true
end

--- Si el jugador respawnea, reconstruye sus clones en el mismo sitio.
local function ensureSourceTracking(player)
    if not player or C._charConns[player] then return end
    local conn = player.CharacterAdded:Connect(function(char)
        -- CharacterAdded llega antes de que el personaje termine de
        -- ensamblarse: esperar la raíz evita reconstruir dos veces.
        task.spawn(function()
            if char and char.Parent then
                char:WaitForChild("HumanoidRootPart", 5)
                task.wait()
            end
            if UCam.rebuildClonesFor then UCam.rebuildClonesFor(player) end
        end)
    end)
    C._charConns[player] = UCam.trackConnection(conn, "Clones:CharacterAdded")
end

local function releaseSourceTracking(player)
    for _, clone in ipairs(C.Items) do
        if clone.source == player then return end
    end
    local conn = C._charConns[player]
    if conn then
        UCam.untrackConnection(conn)
        C._charConns[player] = nil
    end
end

-- ============================================================
-- LOOP DE ESPEJO
-- ============================================================

--- Copia las poses a todos los clones.
-- Optimizaciones v12.6:
--   1) limite de tasa (UpdateHz): no hace falta copiar a 60 Hz.
--   2) LOD por distancia: los clones lejanos se actualizan 1 de cada N ticks.
--   3) solo se escribe la parte si su CFrame de origen o la base cambiaron.
--   4) una sola llamada a BulkMoveTo por tick en vez de cientos de escrituras.
local function updateClones(dt)
    if #C.Items == 0 then return end

    local rate = math.clamp(tonumber(C.UpdateHz) or 30, 10, 60)
    C._accum = (C._accum or 0) + (dt or 0)
    if C._accum + 1e-4 < (1 / rate) then return end
    C._accum = 0
    -- Solo para diagnostico: escrituras del ultimo tick (no cuesta nada).
    C._lastWrites = 0

    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position
    C._tick = (C._tick or 0) + 1

    -- BulkMoveTo mueve partes ancladas y sin colision en un solo lote.
    local useBulk = C._bulkSupported
    if useBulk == nil then
        useBulk = type(workspace.BulkMoveTo) == "function"
        C._bulkSupported = useBulk
    end

    local bulkParts, bulkCFrames
    if useBulk then
        bulkParts = C._bulkParts
        bulkCFrames = C._bulkCFrames
        if not bulkParts then
            bulkParts = {}
            bulkCFrames = {}
            C._bulkParts = bulkParts
            C._bulkCFrames = bulkCFrames
        else
            table.clear(bulkParts)
            table.clear(bulkCFrames)
        end
    end

    local follow = (C.Mode == MODE_FOLLOW)
    local invCache = C._invCache
    if not invCache then
        invCache = {}
        C._invCache = invCache
    else
        table.clear(invCache)
    end

    local farDistance = tonumber(C.FarDistance) or 0
    local farSkip = math.max(1, math.floor(tonumber(C.FarSkip) or 2))

    for _, clone in ipairs(C.Items) do
        local model = clone.model
        local player = clone.source
        local char = clone.sourceChar

        -- v12.7: el jugador cambió de personaje (panel de selección del juego).
        -- Si se conserva el diseño, el clon mantiene su modelo y solo cambia
        -- la fuente de movimiento. Si no, CharacterAdded lo reconstruye.
        if C.KeepDesign and player and char and player.Character ~= char
                and clone._lastRebind ~= player.Character then
            local newChar, _, newRoot = sourceCharacter(player)
            if newChar and newRoot then
                rebindDesign(clone, newChar, newRoot)
                char = clone.sourceChar
            else
                clone._lastRebind = player.Character
            end
        end

        local root = clone.sourceRoot
        if root and not root.Parent then root = nil end
        if not (char and char.Parent and root) then
            local c, _, r = sourceCharacter(player)
            if c and r then
                char, root = c, r
                clone.sourceChar = c
                clone.sourceRoot = r
            end
        end

        if model and model.Parent and char and char.Parent and root then
            clone.sourceRoot = root

            -- Si el original se teletransporta, reanclar la base.
            if follow then
                if clone.lastRootPos and (root.Position - clone.lastRootPos).Magnitude > 60 then
                    clone.baseRoot = root.CFrame
                end
                clone.lastRootPos = root.Position
            end

            -- LOD: lejos de la camara se actualiza menos a menudo.
            local far = camPos and farDistance > 0
                and (root.Position - camPos).Magnitude > farDistance
            if not (far and (C._tick % farSkip ~= 0)) then
                local base
                if follow and clone.baseRoot then
                    if clone._baseRootCached ~= clone.baseRoot or not clone._baseRootInv then
                        clone._baseRootCached = clone.baseRoot
                        clone._baseRootInv = clone.baseRoot:Inverse()
                    end
                    base = clone.anchorCF * clone._baseRootInv
                else
                    -- Cacheados por jugador: muchos clones comparten original.
                    -- Se reutiliza la tabla para no generar basura cada tick.
                    local key = clone.source
                    if key == nil then
                        -- Defensivo: un clon nunca puede quedar sin origen.
                        clone.source = clone.source or C.SourcePlayer
                        key = clone.source
                    end
                    local entry = key and invCache[key]
                    if not entry then
                        entry = {}
                        if key ~= nil then invCache[key] = entry end
                    end
                    local rootCF = root.CFrame
                    if entry.cf ~= rootCF then
                        entry.cf = rootCF
                        entry.inv = rootCF:Inverse()
                    end
                    base = clone.anchorCF * entry.inv
                end

                local baseChanged = (clone._lastBase ~= base)
                local pairs_ = clone.pairs
                local writes = 0
                for i = 1, #pairs_ do
                    local pair = pairs_[i]
                    local orig = pair.orig
                    if orig.Parent then
                        local origCF = orig.CFrame
                        if baseChanged or pair._lastOrig ~= origCF then
                            -- pair.rel: parte sin equivalente exacto en el modelo
                            -- nuevo; se mueve rígida junto a su parte de apoyo.
                            local target
                            if pair.rel then
                                target = base * origCF * pair.rel
                            else
                                target = base * origCF
                            end
                            if useBulk then
                                bulkParts[#bulkParts + 1] = pair.clone
                                bulkCFrames[#bulkCFrames + 1] = target
                            else
                                pair.clone.CFrame = target
                            end
                            pair._lastOrig = origCF
                            writes = writes + 1
                        end
                    end
                end
                clone._lastBase = base
                C._lastWrites = (C._lastWrites or 0) + writes
            end
        end
    end

    if useBulk and #bulkParts > 0 then
        local ok = pcall(function()
            workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.DontFireCFrameChanged)
        end)
        if not ok then
            -- Fallback defensivo: escribir una a una y no volver a intentarlo.
            C._bulkSupported = false
            for i = 1, #bulkParts do
                pcall(function() bulkParts[i].CFrame = bulkCFrames[i] end)
            end
        end
    end

    -- Media suavizada para el diagnostico (evita valores de 0 en un tick
    -- en el que todo estaba quieto).
    C._avgWrites = (C._avgWrites or 0) * 0.9 + (C._lastWrites or 0) * 0.1
end

local function ensureRenderLoop()
    if C._renderConn then return end
    C._renderConn = UCam.trackConnection(
        UCam.RunService.RenderStepped:Connect(updateClones),
        "Clones:Render"
    )
end

local function stopRenderLoop()
    if C._renderConn then
        UCam.untrackConnection(C._renderConn)
        C._renderConn = nil
    end
end

-- ============================================================
-- POSICIÓN INICIAL / FORMACIÓN
-- ============================================================

--- CF de raíz frente a la cámara (o sobre el primer suelo que mire).
local function defaultAnchor(sourceRoot, footOffset)
    local pos
    local point = cameraWorldPoint()
    if point then
        pos = point
    else
        local cam = workspace.CurrentCamera
        if cam then
            pos = cam.CFrame.Position + cam.CFrame.LookVector * 20
        else
            local char = UCam.character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            pos = root and (root.Position + Vector3.new(0, 0, -12)) or Vector3.new(0, 8, 0)
        end
    end
    if C.SnapToGround then
        local ground = groundPointBelow(pos)
        if ground then pos = ground end
    end
    return CFrame.new(pos + Vector3.new(0, footOffset + 0.05, 0)) * sourceRoot.CFrame.Rotation
end

--- Distribuye N anclajes alrededor del punto base.
local function formationAnchor(baseCF, index, count, layout, spacing)
    if layout == LAYOUT_ROW then
        local offset = (index - (count + 1) / 2) * spacing
        return baseCF * CFrame.new(offset, 0, 0)
    elseif layout == LAYOUT_RING then
        local radius = math.max(spacing, spacing * count / (2 * math.pi))
        local angle = ((index - 1) / count) * math.pi * 2
        return baseCF * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
    end
    -- Cuadricula
    local cols = math.max(1, math.ceil(math.sqrt(count)))
    local rows = math.max(1, math.ceil(count / cols))
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local x = (col - (cols - 1) / 2) * spacing
    local z = (row - (rows - 1) / 2) * spacing
    return baseCF * CFrame.new(x, 0, z)
end

-- ============================================================
-- API PÚBLICA
-- ============================================================

--- Clona a un jugador N veces de forma local.
-- @param opts table { player, count, layout, spacing, cf }
-- @return placed number, err string|nil
function UCam.spawnClones(opts)
    opts = opts or {}
    local player = opts.player or C.SourcePlayer or UCam.player
    if not player or not player:IsA("Player") or not player.Parent then
        player = UCam.player
    end

    local char, _, root = sourceCharacter(player)
    if not char then
        return 0, "Ese jugador todavía no tiene personaje. Inténtalo en un momento."
    end

    local remaining = C.MaxClones - #C.Items
    if remaining <= 0 then
        return 0, ("Tope de %d clones alcanzado. Elimina alguno primero."):format(C.MaxClones)
    end

    local count = math.floor(tonumber(opts.count) or C.Count or 6)
    count = math.clamp(count, 1, remaining)

    local layout = opts.layout or C.Layout or LAYOUT_GRID
    local spacing = math.clamp(tonumber(opts.spacing) or C.Spacing or 3.5, 1, 30)
    local footOffset = computeFootOffset(char, root)

    local baseCF = opts.cf
    if typeof(baseCF) ~= "CFrame" then
        baseCF = defaultAnchor(root, footOffset)
    end

    C.SourcePlayer = player
    local placed = 0
    for i = 1, count do
        local anchor = formationAnchor(baseCF, i, count, layout, spacing)
        local clone = instantiateClone(char, root, anchor, root.CFrame, footOffset)
        if clone then
            -- v12.6.1: faltaba fijar el jugador de origen. Sin esto la cache
            -- de inversas (y las etiquetas, el respawn y el borrado) recibian
            -- nil como clave y el loop de espejo fallaba cada frame.
            clone.source = player
            table.insert(C.Items, clone)
            ensureSourceTracking(player)
            placed = placed + 1
        end
    end

    if placed == 0 then
        return 0, "No se pudo clonar el personaje."
    end

    C.Selected = #C.Items
    renumberClones()
    ensureRenderLoop()

    if not opts.silent then
        UCam.notify("Clones", ("%d clones de %s colocados (%d en total). Usa 'Colocar con clic' para moverlos."):format(
            placed, player.Name, #C.Items), 5)
    end
    return placed
end

function UCam.getClonesList()
    local options = { "(ninguno)" }
    for i, clone in ipairs(C.Items) do
        local sourceName = clone.source and clone.source.Name or "?"
        options[#options + 1] = string.format("%02d · %s", i, sourceName)
    end
    return options
end

function UCam.selectClone(index)
    index = math.floor(tonumber(index) or 0)
    if index < 0 or index > #C.Items then return false end
    C.Selected = index
    return true
end

function UCam.deleteClone(index)
    index = math.floor(tonumber(index) or C.Selected)
    local clone = C.Items[index]
    if not clone then return false end

    if clone.model then
        UCam.untrackInstance(clone.model)
        pcall(function() clone.model:Destroy() end)
    end
    table.remove(C.Items, index)

    if C.Selected >= index then
        C.Selected = math.max(0, C.Selected - 1)
    end
    if C.Selected > #C.Items then C.Selected = #C.Items end

    renumberClones()
    releaseSourceTracking(clone.source)
    if #C.Items == 0 then stopRenderLoop() end
    return true
end

--- Borra todos los clones. `silent` evita la notificación (Unload).
function UCam.clearClones(silent)
    for i = #C.Items, 1, -1 do
        local clone = C.Items[i]
        if clone.model then
            UCam.untrackInstance(clone.model)
            pcall(function() clone.model:Destroy() end)
        end
    end
    table.clear(C.Items)
    C.Selected = 0

    for player, conn in pairs(C._charConns) do
        UCam.untrackConnection(conn)
        C._charConns[player] = nil
    end
    table.clear(C._charConns)
    stopRenderLoop()

    if not silent then
        UCam.notify("Clones", "Todos los clones eliminados.", 3)
    end
    return true
end

function UCam.setClonesMode(mode)
    if mode ~= MODE_FOLLOW and mode ~= "Fijar en el sitio" then return false end
    C.Mode = mode
    local follow = (mode == MODE_FOLLOW)
    for _, clone in ipairs(C.Items) do
        local _, _, root = sourceCharacter(clone.source)
        clone.baseRoot = follow and root and root.CFrame or nil
    end
    return true
end

function UCam.setClonesPlacement(enabled)
    C.PlaceWithCursor = enabled and true or false
    if C.PlaceWithCursor then
        if C.Selected == 0 then
            UCam.notify("Clones", "Modo colocar activo: selecciona un clon en la lista y haz clic en el mapa.", 5)
        else
            UCam.notify("Clones", "Haz clic en el mapa para mover el clon seleccionado.", 4)
        end
    end
    return true
end

function UCam.setCloneLabels(enabled)
    C.ShowLabels = enabled and true or false
    for _, clone in ipairs(C.Items) do
        applyLabel(clone)
    end
    return true
end

-- ============================================================
-- v12.6: AJUSTES DE RENDIMIENTO
-- ============================================================

--- Cambia la frecuencia del espejo (10-60 Hz).
function UCam.setCloneUpdateRate(hz)
    C.UpdateHz = math.clamp(tonumber(hz) or 30, 10, 60)
    C._accum = 0
    return true
end

--- Activa/desactiva las sombras de todos los clones.
function UCam.setCloneShadows(enabled)
    C.CastShadows = enabled ~= false
    for _, clone in ipairs(C.Items) do
        if clone.model then
            for _, desc in ipairs(clone.model:GetDescendants()) do
                if desc:IsA("BasePart") then desc.CastShadow = C.CastShadows end
            end
        end
    end
    return true
end

--- Apaga o reactiva el Humanoid de los clones ya creados.
function UCam.setCloneHumanoid(enabled)
    C.DisableHumanoid = enabled ~= false
    for _, clone in ipairs(C.Items) do
        if clone.model then
            local hum = clone.model:FindFirstChildOfClass("Humanoid")
            if hum then
                if C.DisableHumanoid then
                    pcall(function()
                        hum.Enabled = false
                        hum:ChangeState(Enum.HumanoidStateType.Physics)
                    end)
                else
                    pcall(function() hum.Enabled = true end)
                end
            end
        end
    end
    return true
end

--- Datos para mostrar el coste actual (clones activos y partes espejadas).
function UCam.getCloneStats()
    local active, parts = 0, 0
    for _, clone in ipairs(C.Items) do
        if clone.model and clone.model.Parent then
            active = active + 1
            parts = parts + #clone.pairs
        end
    end
    local hz = C.UpdateHz or 30
    local writesPerTick = C._avgWrites or C._lastWrites or 0
    return {
        clones = active,
        parts = parts,
        averageParts = active > 0 and math.floor(parts / active + 0.5) or 0,
        hz = hz,
        writesPerSecond = math.floor(writesPerTick * hz + 0.5),
        bulk = C._bulkSupported == true,
    }
end

function UCam.placeSelectedCloneAtCursor()
    local clone = selectedClone()
    if not clone then
        UCam.notify("Clones", "Selecciona un clon primero.", 4)
        return false
    end
    local point = cursorWorldPoint()
    if not point then
        UCam.notify("Clones", "El cursor no apunta al mapa. Apunta a una superficie.", 4)
        return false
    end
    return positionCloneAt(clone, point)
end

function UCam.placeSelectedCloneWhereLooking()
    local clone = selectedClone()
    if not clone then
        UCam.notify("Clones", "Selecciona un clon primero.", 4)
        return false
    end
    local point = cameraWorldPoint()
    if not point then
        UCam.notify("Clones", "La cámara no apunta al mapa.", 4)
        return false
    end
    return positionCloneAt(clone, point)
end

function UCam.snapSelectedCloneToGround()
    local clone = selectedClone()
    if not clone then return false end
    local ground = groundPointBelow(clone.anchorCF.Position, 2000)
    if not ground then
        UCam.notify("Clones", "No hay suelo debajo del clon.", 3)
        return false
    end
    clone.anchorCF = CFrame.new(ground + Vector3.new(0, clone.footOffset + 0.05, 0))
        * clone.anchorCF.Rotation
    if C.Mode == MODE_FOLLOW then
        local _, _, root = sourceCharacter(clone.source)
        clone.baseRoot = root and root.CFrame or nil
    end
    return true
end

function UCam.rotateSelectedClone(degrees)
    local clone = selectedClone()
    if not clone then
        UCam.notify("Clones", "Selecciona un clon primero.", 4)
        return false
    end
    local pos = clone.anchorCF.Position
    clone.anchorCF = CFrame.new(pos)
        * clone.anchorCF.Rotation
        * CFrame.Angles(0, math.rad(tonumber(degrees) or 15), 0)
    return true
end

--- Reconstruye todos los clones de un jugador (respawn/apariencia).
-- v12.7: con KeepDesign activo no se toca el modelo: el clon conserva el
-- diseño con el que se creó y solo se reengancha al personaje actual.
-- @param force true = recapturar siempre la apariencia (botón de la UI)
function UCam.rebuildClonesFor(player, force)
    local char, _, root = sourceCharacter(player)
    if not char then return 0 end
    local rebuilt = 0
    for _, clone in ipairs(C.Items) do
        if clone.source == player then
            local ok
            if C.KeepDesign and not force then
                ok = rebindDesign(clone, char, root)
            else
                ok = rebuildOne(clone, char, root)
            end
            if ok then rebuilt = rebuilt + 1 end
        end
    end
    return rebuilt
end

--- Rehace todos los clones con la apariencia actual de su original.
function UCam.refreshClones()
    local sources = {}
    for _, clone in ipairs(C.Items) do
        sources[clone.source] = true
    end
    local rebuilt = 0
    for player in pairs(sources) do
        rebuilt = rebuilt + UCam.rebuildClonesFor(player, true)
    end
    if rebuilt == 0 then
        UCam.notify("Clones", "No se pudo actualizar ningún clon.", 4)
    else
        UCam.notify("Clones", ("%d clones ahora usan la apariencia actual."):format(rebuilt), 4)
    end
    return rebuilt
end

-- ============================================================
-- v12.7: DISEÑO Y OBJETIVOS DE "CUERPO"
-- ============================================================

--- Activa/desactiva conservar el diseño capturado al cambiar de personaje.
function UCam.setClonesKeepDesign(enabled)
    C.KeepDesign = enabled ~= false
    if C.KeepDesign then
        for _, clone in ipairs(C.Items) do
            local char, _, root = sourceCharacter(clone.source)
            if char and char ~= clone.sourceChar then
                rebindDesign(clone, char, root)
            end
        end
    end
    return true
end

--- Recaptura la apariencia actual del original para el clon seleccionado.
function UCam.recaptureCloneDesign(index)
    index = math.floor(tonumber(index) or C.Selected)
    local clone = C.Items[index]
    if not clone then
        UCam.notify("Clones", "Selecciona un clon primero.", 4)
        return false
    end
    local char, _, root = sourceCharacter(clone.source)
    if not char then
        UCam.notify("Clones", "Ese jugador no tiene personaje ahora mismo.", 4)
        return false
    end
    local ok = rebuildOne(clone, char, root)
    if ok then
        UCam.notify("Clones", ("Clon %02d actualizado al diseño actual."):format(index), 4)
    end
    return ok
end

--- Lista de clones como objetivos de la pestaña Cuerpo.
function UCam.getCloneTargets()
    local list = {}
    for i, clone in ipairs(C.Items) do
        list[i] = {
            label = ("Clon %02d · %s"):format(i, clone.source and clone.source.Name or "?"),
            clone = clone,
        }
    end
    return list
end

function UCam.getCloneByLabel(label)
    if not label then return nil end
    for _, entry in ipairs(UCam.getCloneTargets()) do
        if entry.label == label then return entry.clone end
    end
    return nil
end

--- Apagado limpio: usado por Unload().
function UCam.stopClones()
    C.PlaceWithCursor = false
    UCam.clearClones(true)
end

-- ============================================================
-- COLOCAR CON CLIC IZQUIERDO
-- ============================================================
UCam.trackConnection(
    UCam.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not C.PlaceWithCursor then return end
        UCam.placeSelectedCloneAtCursor()
    end),
    "Clones:PlaceClick"
)
