-- ============================================================
-- Universal Camera Pro v13.7 · demo/92_recorder
-- Grabador de demos LOCAL. No guarda un demo del motor: guarda la
-- pose de cada rig (CFrame de la raiz + Transform de cada Motor6D)
-- y las CFrames de los props locales. Con eso se reconstruye la
-- escena en tu cliente y se puede filmar con camara libre.
--
-- Formato de un frame (float32 empaquetado, little endian):
--   t, raiz(12), joint1(12), joint2(12), ...
-- El tamano por frame es fijo, asi que el reproductor puede saltar
-- a cualquier muestra sin decodificar el resto.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua,
--               props/45_props.lua (getPropCFrame).
-- Expone (UCam.*):
--   demoStartRecording, demoStopRecording, demoCancelRecording,
--   demoAddMarker, demoTick, demoStatus, demoStatusText.
-- ============================================================
local UCam = _G.UCam
local D = UCam.Demo
local IDENTITY = CFrame.new()

-- ============================================================
-- HELPERS DE INSTANCIAS
-- ============================================================

--- Ruta relativa de una instancia dentro del modelo ("Hat/Handle").
local function relativePath(model, inst)
    local names = {}
    local node = inst
    while node and node ~= model do
        table.insert(names, 1, node.Name)
        node = node.Parent
    end
    return table.concat(names, "/")
end

local function isPartInside(char, part)
    if not part or type(part.IsA) ~= "function" then return false end
    return part:IsA("BasePart") and part:IsDescendantOf(char)
end

--- Raiz del rig: HumanoidRootPart, PrimaryPart o la primera BasePart.
local function findRoot(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then return root end
    if char.PrimaryPart and char.PrimaryPart:IsA("BasePart") then return char.PrimaryPart end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then return desc end
    end
    return nil
end

local function pushCF(values, cf)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    local n = #values
    values[n + 1]  = x
    values[n + 2]  = y
    values[n + 3]  = z
    values[n + 4]  = r00
    values[n + 5]  = r01
    values[n + 6]  = r02
    values[n + 7]  = r10
    values[n + 8]  = r11
    values[n + 9]  = r12
    values[n + 10] = r20
    values[n + 11] = r21
    values[n + 12] = r22
end

local function cfComponents(cf)
    return { cf:GetComponents() }
end

--- Parte del personaje a la que un accesorio/herramienta esta unido.
-- Primero mira un Weld/WeldConstraint del propio accesorio; si no,
-- sube por los padres hasta encontrar una BasePart del personaje.
local function attachmentParent(char, part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Weld") or child:IsA("WeldConstraint") then
            local other
            if child.Part0 == part then
                other = child.Part1
            elseif child.Part1 == part then
                other = child.Part0
            end
            if other and other ~= part and isPartInside(char, other) then
                return other
            end
        end
    end
    local node = part.Parent
    while node and node ~= char do
        if node:IsA("BasePart") then return node end
        node = node.Parent
    end
    return nil
end

-- ============================================================
-- DESCRIPTOR DEL RIG
-- Se toma UNA vez al empezar la pista. Describe como reconstruir
-- el rig si el personaje original ya no existe al reproducir.
-- ============================================================
local function buildRigDescriptor(char)
    local root = findRoot(char)
    if not root then return nil end

    local parts = {}
    local partByObj = {}
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local entry = {
                path = relativePath(char, desc),
                name = desc.Name,
                size = { desc.Size.X, desc.Size.Y, desc.Size.Z },
                color = { desc.Color.R, desc.Color.G, desc.Color.B },
                transparency = desc.Transparency,
                material = (desc.Material and desc.Material.Name) or "Plastic",
            }
            -- Shape solo existe en Part (no en MeshPart).
            local okShape, shapeName = pcall(function()
                return desc.Shape and desc.Shape.Name or nil
            end)
            if okShape and shapeName then entry.shape = shapeName end
            table.insert(parts, entry)
            partByObj[desc] = entry
        end
    end

    local joints = {}
    local jointRefs = {}
    local part1Paths = {}
    local motorByObj = {}
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Motor6D") then
            local p0, p1 = desc.Part0, desc.Part1
            if isPartInside(char, p0) and isPartInside(char, p1) then
                local entry = {
                    name = desc.Name,
                    part0 = relativePath(char, p0),
                    part1 = relativePath(char, p1),
                    c0 = cfComponents(desc.C0),
                    c1 = cfComponents(desc.C1),
                }
                table.insert(joints, entry)
                table.insert(jointRefs, desc)
                motorByObj[desc] = entry
                part1Paths[entry.part1] = true
            end
        end
    end

    -- Orden topologico: una parte solo se puede calcular cuando su
    -- Part0 ya tiene CFrame. Sin esto un antebrazo se evalua antes
    -- que el brazo y la pose sale desarmada.
    local rootPath = relativePath(char, root)
    local placed = { [rootPath] = true }
    local ordered, orderedRefs, pending = {}, {}, {}
    for i = 1, #joints do pending[#pending + 1] = i end
    local guard = 0
    while #pending > 0 and guard < #joints + 2 do
        guard = guard + 1
        local progressed = false
        for i = #pending, 1, -1 do
            local index = pending[i]
            local j = joints[index]
            if placed[j.part0] then
                ordered[#ordered + 1] = j
                orderedRefs[#orderedRefs + 1] = jointRefs[index]
                placed[j.part1] = true
                table.remove(pending, i)
                progressed = true
            end
        end
        if not progressed then break end
    end
    for _, index in ipairs(pending) do
        ordered[#ordered + 1] = joints[index]
        orderedRefs[#orderedRefs + 1] = jointRefs[index]
    end

    -- Partes sin joint (accesorios, herramientas, pelo): se guardan
    -- como un offset fijo respecto a su parte de apoyo.
    local statics = {}
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local path = relativePath(char, desc)
            if path ~= rootPath and not part1Paths[path] then
                local parent = attachmentParent(char, desc)
                if parent and parent ~= desc then
                    local offset = parent.CFrame:ToObjectSpace(desc.CFrame)
                    statics[#statics + 1] = {
                        path = path,
                        parent = relativePath(char, parent),
                        offset = cfComponents(offset),
                    }
                end
            end
        end
    end

    local rigType = "custom"
    if char:FindFirstChild("LowerTorso") then
        rigType = "R15"
    elseif char:FindFirstChild("Torso") then
        rigType = "R6"
    end

    return {
        rigType = rigType,
        rootPath = rootPath,
        rootPart = root,
        parts = parts,
        joints = ordered,
        jointRefs = orderedRefs,
        statics = statics,
    }
end

-- ============================================================
-- PISTAS
-- ============================================================

local function actorKey(player)
    if player == UCam.player then return "local" end
    local id = tonumber(player.UserId) or 0
    if id > 0 then return "p:" .. tostring(id) end
    return "n:" .. tostring(player.Name)
end

local function aliveTracks()
    local count = 0
    for _, track in ipairs(D._recordingDemo and D._recordingDemo.actors or {}) do
        local char = track.char
        local root = track.rootPart
        if char and char.Parent and root and root.Parent then
            count = count + 1
        end
    end
    return count
end

local function buildActorTrack(player, now)
    local char = player and player.Character
    if not (char and char.Parent) then return nil end
    local desc = buildRigDescriptor(char)
    if not desc then return nil end

    local jointCount = #desc.joints
    local fmt = "<" .. string.rep("f", 1 + 12 + 12 * jointCount)
    local track = {
        id          = actorKey(player),
        name        = player.Name,
        userId      = tonumber(player.UserId) or 0,
        rigType     = desc.rigType,
        rootPath    = desc.rootPath,
        parts       = desc.parts,
        joints      = desc.joints,
        statics     = desc.statics,
        t0          = now,
        times       = {},
        buffers     = {},
        frameCount  = 0,
        fmt         = fmt,
        frameBytes  = string.packsize(fmt),
        valueCount  = 1 + 12 + 12 * jointCount,
        chunk       = "",
        player      = player,
        char        = char,
        rootPart    = desc.rootPart,
        jointRefs   = desc.jointRefs,
        _values     = {},
    }
    return track
end

--- Devuelve la pista viva del jugador, creando una nueva si cambio de
-- personaje (respawn). Una pista nueva empieza en el tiempo actual, asi
-- que el reproductor la muestra solo desde ahi.
local function ensureActor(player, now)
    if not (player and player.Character and player.Character.Parent) then return nil end
    local key = actorKey(player)
    local existing = D._actorByKey[key]

    if existing and existing.char == player.Character then
        if existing.rootPart and existing.rootPart.Parent then
            return existing
        end
        return nil
    end

    if existing and existing.char and existing.char.Parent then
        -- El jugador sigue con el mismo personaje pero no se pudo leer
        -- la raiz: no conviene abrir otra pista que se solape.
        if existing.char == player.Character then return nil end
    end

    local demo = D._recordingDemo
    if not demo then return nil end

    local maxActors = math.max(1, tonumber(D.MaxActors) or 12)
    if aliveTracks() >= maxActors then
        if not D._warnedMaxActors then
            D._warnedMaxActors = true
            UCam.notify("Replay", ("Tope de %d actores grabados; el resto se ignora."):format(maxActors), 5)
        end
        return nil
    end

    local track = buildActorTrack(player, now)
    if not track then return nil end
    D._actorByKey[key] = track
    table.insert(demo.actors, track)
    return track
end

local function captureActor(track, t)
    local root = track.rootPart
    local char = track.char
    if not (root and root.Parent and char and char.Parent) then return false end

    local values = track._values
    table.clear(values)
    values[1] = t
    pushCF(values, root.CFrame)
    for i = 1, #track.jointRefs do
        local joint = track.jointRefs[i]
        local cf = IDENTITY
        if joint and joint.Parent then
            local ok, transform = pcall(function() return joint.Transform end)
            if ok and transform then cf = transform end
        end
        pushCF(values, cf)
    end

    local packed = string.pack(track.fmt, table.unpack(values, 1, track.valueCount))
    track.buffers[#track.buffers + 1] = packed
    track.times[#track.times + 1] = t
    track.frameCount = track.frameCount + 1
    return true
end

-- ============================================================
-- PROPS
-- ============================================================

local function buildPropTrack(demo, now)
    local items = {}
    for i, item in ipairs(UCam.Props.Items) do
        items[i] = {
            assetId    = item.assetId,
            name       = item.name,
            scale      = item.scale,
            canCollide = item.canCollide,
        }
    end
    if #items == 0 then return nil end

    -- Igual que los actores: el primer float de cada frame es el tiempo.
    -- Asi la pista de props puede buscarse por tiempo al cargar el archivo.
    local fmt = "<" .. string.rep("f", 1 + 12 * #items)
    demo.props = {
        items      = items,
        t0         = now,
        times      = {},
        buffers    = {},
        frameCount = 0,
        fmt        = fmt,
        frameBytes = string.packsize(fmt),
        valueCount = 1 + 12 * #items,
        chunk      = "",
        _values    = {},
    }
    return demo.props
end

local function captureProps(track, t)
    local values = track._values
    table.clear(values)
    values[1] = t
    local any = false
    for i = 1, #track.items do
        local cf = UCam.getPropCFrame and UCam.getPropCFrame(i) or nil
        if cf then
            any = true
            pushCF(values, cf)
        else
            pushCF(values, IDENTITY)
        end
    end
    if not any then return false end
    track.buffers[#track.buffers + 1] = string.pack(track.fmt, table.unpack(values, 1, track.valueCount))
    track.times[#track.times + 1] = t
    track.frameCount = track.frameCount + 1
    return true
end

-- ============================================================
-- MUESTREO
-- ============================================================

local function captureFrame(now)
    local demo = D._recordingDemo
    if not demo then return end

    -- Mi personaje
    if D.IncludeLocal then
        local track = ensureActor(UCam.player, now)
        if track then captureActor(track, now) end
    end

    -- Otros jugadores (incluye a los que entren durante la grabacion)
    if D.IncludeOthers then
        for _, player in ipairs(UCam.Players:GetPlayers()) do
            if player ~= UCam.player then
                local track = ensureActor(player, now)
                if track then captureActor(track, now) end
            end
        end
    end

    -- Props locales
    if D.IncludeProps then
        if not demo.props and #UCam.Props.Items > 0 then
            buildPropTrack(demo, now)
        end
        if demo.props then captureProps(demo.props, now) end
    end

    -- Un actor que perdio su personaje (salio o respawneo) deja de
    -- existir en el demo a partir de aqui. El reproductor lo oculta en
    -- vez de congelar su ultima pose hasta el final.
    for _, track in ipairs(demo.actors) do
        if not track.endedAt and (track.frameCount or 0) > 0 then
            local char, root = track.char, track.rootPart
            if not (char and char.Parent and root and root.Parent) then
                track.endedAt = now
            end
        end
    end

    demo.duration = now
end

--- Tick del grabador. Se expone para poder probarlo con dt sintetico.
function UCam.demoTick(dt)
    if not D.Recording then return end
    dt = tonumber(dt) or 0
    if dt < 0 then dt = 0 end
    -- Un cuelgue del hilo no debe generar miles de muestras de golpe.
    if dt > 0.5 then dt = 0.5 end

    D.Elapsed = (D.Elapsed or 0) + dt
    D._accum = (D._accum or 0) + dt

    local interval = 1 / math.max(tonumber(D.Rate) or 20, 1)
    local guard = 0
    while D._accum + 1e-6 >= interval and guard < 6 do
        D._accum = D._accum - interval
        guard = guard + 1
        captureFrame(D.Elapsed)
    end

    if D.Elapsed >= (tonumber(D.MaxDuration) or 180) then
        UCam.demoStopRecording(nil, true)
    end
end

-- ============================================================
-- API DE GRABACION
-- ============================================================

local function sanitizeText(text, limit)
    text = tostring(text or ""):gsub("[%c]", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text:sub(1, limit or 60)
end

local function finalizeTrack(track)
    if not track then return end
    track.chunk = table.concat(track.buffers)
    table.clear(track.buffers)
    track.buffers = nil
    track._values = nil
    track.jointRefs = nil
    track.char = nil
    track.rootPart = nil
    -- player se conserva para clonar el modelo en la misma sesion.
end

function UCam.demoStartRecording(opts)
    if D.Recording then
        return false, "Ya hay una grabacion en curso."
    end
    if UCam.DemoTakes and UCam.DemoTakes._recording then
        return false, "Termina la toma que estas grabando."
    end
    opts = type(opts) == "table" and opts or {}

    -- Limpia fantasmas, tomas y reproduccion de un demo anterior. Si el
    -- usuario pauso (D.Playing=false), los fantasmas seguian visibles y se
    -- quedaban huerfanos al empezar a grabar.
    UCam.demoStop()

    D.Rate = math.clamp(tonumber(opts.rate) or tonumber(D.Rate) or 20, 5, 60)
    D.MaxDuration = math.clamp(tonumber(opts.maxDuration) or tonumber(D.MaxDuration) or 180, 5, 600)
    D.Elapsed = 0
    D._accum = 0
    D._warnedMaxActors = false
    D._actors = {}
    D._actorByKey = {}

    local demo = {
        version   = 1,
        name      = sanitizeText(opts.name or ("Demo " .. os.date("%Y-%m-%d %H-%M")), 60),
        createdAt = os.time(),
        rate      = D.Rate,
        duration  = 0,
        actors    = {},
        props     = nil,
        markers   = {},
        takes     = {},
        settings  = {
            includeLocal  = D.IncludeLocal == true,
            includeOthers = D.IncludeOthers == true,
            includeProps  = D.IncludeProps == true,
        },
    }
    D._recordingDemo = demo

    if D.IncludeLocal then ensureActor(UCam.player, 0) end
    if D.IncludeOthers then
        for _, player in ipairs(UCam.Players:GetPlayers()) do
            if player ~= UCam.player then ensureActor(player, 0) end
        end
    end
    if D.IncludeProps and #UCam.Props.Items > 0 then
        buildPropTrack(demo, 0)
    end

    if #demo.actors == 0 then
        D._recordingDemo = nil
        return false, "No hay personajes que grabar. Espera a tener personaje."
    end

    -- Muestra inicial en t=0. Sin ella, abrir el demo en el segundo 0 no
    -- muestra nada: el primer frame aparece recien en 1/tasa.
    captureFrame(0)

    D.Recording = true
    D.Current = nil
    D.Duration = 0
    D.Playhead = 0

    if D._captureConn then
        UCam.untrackConnection(D._captureConn)
        D._captureConn = nil
    end
    D._captureConn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function(dt)
            UCam.demoTick(dt)
        end),
        "Demo:record"
    )

    UCam.notify("Replay",
        ("Grabando demo a %d Hz (max %ds). Actores: %d."):format(D.Rate, D.MaxDuration, #demo.actors),
        5)
    return true
end

--- Detiene y publica la grabacion. `auto` lo usa el tope de duracion.
function UCam.demoStopRecording(name, auto)
    if not D.Recording then return false, "No hay grabacion en curso." end
    D.Recording = false

    if D._captureConn then
        UCam.untrackConnection(D._captureConn)
        D._captureConn = nil
    end

    local demo = D._recordingDemo
    D._recordingDemo = nil
    if not demo then return false, "La grabacion estaba vacia." end

    local frames = 0
    for _, track in ipairs(demo.actors) do
        finalizeTrack(track)
        frames = frames + (track.frameCount or 0)
    end
    if demo.props then
        finalizeTrack(demo.props)
    end
    demo.duration = D.Elapsed
    D.Duration = demo.duration

    if frames == 0 then
        return false, "La grabacion no capturo ningun frame."
    end

    if name and tostring(name) ~= "" then
        demo.name = sanitizeText(name, 60)
    end

    D.Current = demo
    D.Playhead = 0
    D._ghosts = {}

    -- La lista de tomas de la UI apunta al demo actual.
    if UCam.DemoTakes then
        UCam.DemoTakes.Items = demo.takes
        UCam.DemoTakes.Selected = 0
    end

    local totalBytes = 0
    for _, track in ipairs(demo.actors) do totalBytes = totalBytes + #(track.chunk or "") end
    if demo.props then totalBytes = totalBytes + #(demo.props.chunk or "") end

    if not auto then
        UCam.notify("Replay",
            ("Demo detenido: %s · %d actores · %.1fs · %.1f MB."):format(
                demo.name, #demo.actors, demo.duration, totalBytes / 1048576),
            6)
    else
        UCam.notify("Replay",
            ("Tope de %ds alcanzado. Demo lista (%.1fs, %.1f MB)."):format(
                D.MaxDuration, demo.duration, totalBytes / 1048576),
            6)
    end

    if UCam.scheduleSave then UCam.scheduleSave() end
    return true, demo
end

function UCam.demoCancelRecording()
    if not D.Recording then return false end
    D.Recording = false
    if D._captureConn then
        UCam.untrackConnection(D._captureConn)
        D._captureConn = nil
    end
    D._recordingDemo = nil
    D.Elapsed = 0
    UCam.notify("Replay", "Grabacion descartada.", 3)
    return true
end

--- Marca un momento del demo (golpe, disparo, linea de dialogo...).
function UCam.demoAddMarker(label)
    local demo = D.Current or D._recordingDemo
    if not demo then
        UCam.notify("Replay", "No hay demo para marcar.", 3)
        return false
    end
    local text = sanitizeText(label, 40)
    if text == "" then text = ("Marca %d"):format(#demo.markers + 1) end
    local t = D.Recording and D.Elapsed or D.Playhead
    table.insert(demo.markers, { t = t, label = text })
    UCam.notify("Replay", ("Marca '%s' en %.2fs."):format(text, t), 3)
    return true
end

-- ============================================================
-- DIAGNOSTICO
-- ============================================================

function UCam.demoStatus()
    local demo = D.Current or D._recordingDemo
    local actors, frames, bytes = 0, 0, 0
    for _, track in ipairs(demo and demo.actors or {}) do
        actors = actors + 1
        frames = frames + (track.frameCount or 0)
        if track.chunk then bytes = bytes + #track.chunk end
    end
    if demo and demo.props then
        frames = frames + (demo.props.frameCount or 0)
        if demo.props.chunk then bytes = bytes + #demo.props.chunk end
    end
    return {
        recording = D.Recording == true,
        playing = D.Playing == true and D.Paused ~= true,
        paused = D.Paused == true,
        hasDemo = demo ~= nil,
        actors = actors,
        frames = frames,
        bytes = bytes,
        duration = (demo and demo.duration or 0),
        rate = (demo and demo.rate) or D.Rate,
        playhead = D.Playhead or 0,
        props = (demo and demo.props and #demo.props.items) or 0,
        markers = (demo and demo.markers and #demo.markers) or 0,
        takes = (demo and demo.takes and #demo.takes) or 0,
        fileSystem = UCam.HasFileSystem == true,
    }
end

function UCam.demoStatusText()
    local s = UCam.demoStatus()
    local lines = {
        ("Grabando: %s · Reproduciendo: %s"):format(s.recording and "si" or "no", s.playing and "si" or "no"),
        ("Demo: %s · actores %d · frames %d"):format(s.hasDemo and "cargado" or "ninguno", s.actors, s.frames),
        ("Duracion %.2fs · tasa %s Hz · props %d · marcas %d · tomas %d"):format(
            s.duration or 0, tostring(s.rate or "?"), s.props, s.markers, s.takes),
        ("Datos %.2f MB · archivos: %s"):format((s.bytes or 0) / 1048576, s.fileSystem and "disponibles" or "no disponibles"),
    }
    return table.concat(lines, "\n")
end
