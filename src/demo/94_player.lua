-- ============================================================
-- Universal Camera Pro v13.7 · demo/94_player
-- Reproduce un demo en tu cliente con rigs "fantasma".
--
-- - En la misma sesion clona el personaje real (fidelidad total).
-- - Si el personaje ya no existe (archivo abierto despues), arma un
--   rig de bloques con las tallas/colores guardados y lo articula
--   con los mismos Motor6D. Es una APROXIMACION: sin mallas ni
--   accesorios complejos, pero con la misma pose y movimiento.
--
-- El reproductor NO toca la camara: solo mueve actores y props.
-- Las tomas (98_takes) son las que piden la camara prestada.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua,
--               core/05_persistence.lua, props/45_props.lua.
-- Expone (UCam.*):
--   demoSetCurrent, demoAttachPlayers, demoBuildGhosts, demoPlay,
--   demoPause, demoStop, demoSeek, demoStep, demoApplyAt,
--   demoSetSpeed, demoSetLoop, demoSetHideLive, demoSummary.
-- ============================================================
local UCam = _G.UCam
local D = UCam.Demo
local IDENTITY = CFrame.new()

-- ============================================================
-- HELPERS DE CFrame / RUTAS
-- ============================================================

local function cfFrom(values)
    return CFrame.new(
        values[1], values[2], values[3],
        values[4], values[5], values[6],
        values[7], values[8], values[9],
        values[10], values[11], values[12]
    )
end

local function relativePath(model, inst)
    local names = {}
    local node = inst
    while node and node ~= model do
        table.insert(names, 1, node.Name)
        node = node.Parent
    end
    return table.concat(names, "/")
end

local function findByPath(model, path)
    if not model or not path then return nil end
    local node = model
    for part in string.gmatch(path, "[^/]+") do
        node = node:FindFirstChild(part)
        if not node then return nil end
    end
    return node
end

local function lastSegment(path)
    local tail = path:match("([^/]+)$")
    return tail or path
end

-- ============================================================
-- DECODIFICACION DE FRAMES
-- ============================================================

local function decodeActorFrame(track, index)
    local pos = (index - 1) * track.frameBytes + 1
    local values = table.pack(string.unpack(track.fmt, track.chunk, pos))
    local root = CFrame.new(
        values[2], values[3], values[4],
        values[5], values[6], values[7],
        values[8], values[9], values[10],
        values[11], values[12], values[13]
    )
    local jointCFs = {}
    local cursor = 14
    for i = 1, #track.joints do
        jointCFs[i] = CFrame.new(
            values[cursor], values[cursor + 1], values[cursor + 2],
            values[cursor + 3], values[cursor + 4], values[cursor + 5],
            values[cursor + 6], values[cursor + 7], values[cursor + 8],
            values[cursor + 9], values[cursor + 10], values[cursor + 11]
        )
        cursor = cursor + 12
    end
    return root, jointCFs
end

local function lerpPose(rootA, jointsA, rootB, jointsB, alpha)
    local root = rootA:Lerp(rootB, alpha)
    for i = 1, #jointsA do
        jointsA[i] = jointsA[i]:Lerp(jointsB[i] or jointsA[i], alpha)
    end
    return root, jointsA
end

--- Muestrea una pista en tiempo absoluto del demo. Devuelve nil si el
-- actor no existe en ese momento (aun no entro / ya salio).
local function sampleActorTrack(track, t)
    local times = track.times
    local n = #times
    if n == 0 then return nil end
    if t < times[1] - 1e-4 then return nil end
    -- El actor salio antes de terminar el demo: se oculta desde ese punto.
    if track.endedAt and t > track.endedAt + 1e-4 then return nil end
    -- En el ultimo frame (o justo antes de que el actor desaparezca) se
    -- mantiene su ultima pose en vez de parpadear a la nada.
    if t > times[n] + 1e-4 then return decodeActorFrame(track, n) end
    if n == 1 then return decodeActorFrame(track, 1) end

    local lo, hi = 1, n
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if times[mid] <= t then lo = mid else hi = mid - 1 end
    end
    local index = lo
    if index >= n then return decodeActorFrame(track, n) end

    local rootA, jointsA = decodeActorFrame(track, index)
    local rootB, jointsB = decodeActorFrame(track, index + 1)
    local span = times[index + 1] - times[index]
    local alpha = span > 0 and ((t - times[index]) / span) or 0
    return lerpPose(rootA, jointsA, rootB, jointsB, math.clamp(alpha, 0, 1))
end

local function decodePropFrame(track, index)
    local pos = (index - 1) * track.frameBytes + 1
    local values = table.pack(string.unpack(track.fmt, track.chunk, pos))
    local cfs = {}
    local cursor = 2
    for i = 1, #track.items do
        cfs[i] = CFrame.new(
            values[cursor], values[cursor + 1], values[cursor + 2],
            values[cursor + 3], values[cursor + 4], values[cursor + 5],
            values[cursor + 6], values[cursor + 7], values[cursor + 8],
            values[cursor + 9], values[cursor + 10], values[cursor + 11]
        )
        cursor = cursor + 12
    end
    return cfs
end

local function samplePropTrack(track, t)
    local times = track.times
    local n = #times
    if n == 0 then return nil end
    if t < times[1] - 1e-4 then return nil end
    if t > times[n] + 1e-4 then return decodePropFrame(track, n) end
    if n == 1 then return decodePropFrame(track, 1) end

    local lo, hi = 1, n
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if times[mid] <= t then lo = mid else hi = mid - 1 end
    end
    local index = lo
    if index >= n then return decodePropFrame(track, n) end

    local a = decodePropFrame(track, index)
    local b = decodePropFrame(track, index + 1)
    local span = times[index + 1] - times[index]
    local alpha = math.clamp(span > 0 and ((t - times[index]) / span) or 0, 0, 1)
    for i = 1, #a do
        a[i] = a[i]:Lerp(b[i] or a[i], alpha)
    end
    return a
end

-- ============================================================
-- CONSTRUCCION DE RIGS FANTASMA
-- ============================================================

local function prepareCloneModel(model, track)
    local doomed = {}
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.Anchored = true
            desc.CanCollide = false
            desc.CanQuery = false
            desc.CanTouch = false
            desc.Massless = true
        elseif desc:IsA("Script") or desc:IsA("LocalScript") then
            table.insert(doomed, desc)
        end
    end
    for _, desc in ipairs(doomed) do
        pcall(function() desc:Destroy() end)
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            humanoid.Enabled = false
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            humanoid.EvaluateStateMachine = false
        end)
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then pcall(function() animator:Destroy() end) end
    end

    local root = findByPath(model, track.rootPath) or model:FindFirstChild("HumanoidRootPart")
    if root then model.PrimaryPart = root end
end

local function buildJointList(track, parts)
    local joints = {}
    for index, jd in ipairs(track.joints or {}) do
        local p0 = parts[jd.part0]
        local p1 = parts[jd.part1]
        if p0 and p1 then
            joints[#joints + 1] = {
                -- Conserva el indice ORIGINAL: si el rig actual no tiene
                -- una parte, el frame sigue trayendo su transform en esa
                -- posicion y no se desplazan las demas articulaciones.
                index = index,
                part0 = jd.part0,
                part1 = jd.part1,
                c0 = cfFrom(jd.c0),
                c1Inv = cfFrom(jd.c1):Inverse(),
            }
        end
    end
    return joints
end

local function buildStatics(track, parts)
    local statics = {}
    for _, sd in ipairs(track.statics or {}) do
        if parts[sd.parent] and parts[sd.path] then
            statics[#statics + 1] = {
                part = sd.path,
                parent = sd.parent,
                offset = cfFrom(sd.offset),
            }
        end
    end
    return statics
end

local function ghostFromClone(track)
    local player = track.player
    local char = player and player.Character
    if not (char and char.Parent) then return nil end

    local ok, model = pcall(function() return char:Clone() end)
    if not ok or not model then return nil end
    model.Name = "UCam_DemoGhost"
    prepareCloneModel(model, track)

    local parts = {}
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            parts[relativePath(model, desc)] = desc
        end
    end
    local root = parts[track.rootPath]
    if not root then
        pcall(function() model:Destroy() end)
        return nil
    end

    local joints = buildJointList(track, parts)
    if #joints == 0 and #(track.joints or {}) > 0 then
        pcall(function() model:Destroy() end)
        return nil
    end

    return {
        model = model,
        root = root,
        parts = parts,
        joints = joints,
        statics = buildStatics(track, parts),
        track = track,
        kind = "clone",
        active = false,
        _computed = {},
        _bulkParts = {},
        _bulkCFrames = {},
    }
end

local function ghostFromProxy(track)
    local model = Instance.new("Model")
    model.Name = "UCam_DemoGhost"

    local parts = {}
    local root
    for _, pd in ipairs(track.parts or {}) do
        local part = Instance.new("Part")
        part.Name = pd.name or lastSegment(pd.path)
        part.Size = Vector3.new(pd.size[1], pd.size[2], pd.size[3])
        part.Color = Color3.new(pd.color[1], pd.color[2], pd.color[3])
        part.Transparency = tonumber(pd.transparency) or 0
        if pd.material and Enum.Material[pd.material] then
            part.Material = Enum.Material[pd.material]
        end
        if pd.shape and Enum.PartType and Enum.PartType[pd.shape] then
            part.Shape = Enum.PartType[pd.shape]
        end
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Massless = true
        part.CastShadow = true
        part.Parent = model
        parts[pd.path] = part
        if pd.path == track.rootPath then root = part end
    end

    if not root then
        pcall(function() model:Destroy() end)
        return nil
    end
    model.PrimaryPart = root
    model.Parent = nil

    return {
        model = model,
        root = root,
        parts = parts,
        joints = buildJointList(track, parts),
        statics = buildStatics(track, parts),
        track = track,
        kind = "proxy",
        active = false,
        _computed = {},
        _bulkParts = {},
        _bulkCFrames = {},
    }
end

local function destroyGhost(ghost)
    if not ghost then return end
    if ghost.model then
        UCam.untrackInstance(ghost.model)
        pcall(function() ghost.model:Destroy() end)
    end
end

--- Aplica una pose calculando toda la jerarquia en una tabla y moviendo
-- en un solo BulkMoveTo (o part a part si el cliente no lo soporta).
local function poseGhost(ghost, rootCF, jointCFs)
    local computed = ghost._computed
    table.clear(computed)
    computed[ghost.track.rootPath] = rootCF

    for _, joint in ipairs(ghost.joints) do
        local parentCF = computed[joint.part0]
        if parentCF then
            local transform = jointCFs[joint.index] or IDENTITY
            computed[joint.part1] = parentCF * joint.c0 * transform * joint.c1Inv
        end
    end

    for _, entry in ipairs(ghost.statics) do
        local parentCF = computed[entry.parent]
        if parentCF then
            computed[entry.part] = parentCF * entry.offset
        end
    end

    local bulkParts, bulkCFrames = ghost._bulkParts, ghost._bulkCFrames
    table.clear(bulkParts)
    table.clear(bulkCFrames)
    for path, cf in pairs(computed) do
        local part = ghost.parts[path]
        if part and part.Parent then
            bulkParts[#bulkParts + 1] = part
            bulkCFrames[#bulkCFrames + 1] = cf
        end
    end
    if #bulkParts == 0 then return end

    if ghost._bulkSupported == nil then
        ghost._bulkSupported = type(workspace.BulkMoveTo) == "function"
    end
    if ghost._bulkSupported then
        local ok = pcall(function()
            workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.DontFireCFrameChanged)
        end)
        if not ok then
            ghost._bulkSupported = false
            for i = 1, #bulkParts do
                pcall(function() bulkParts[i].CFrame = bulkCFrames[i] end)
            end
        end
    else
        for i = 1, #bulkParts do
            pcall(function() bulkParts[i].CFrame = bulkCFrames[i] end)
        end
    end
end

local function setGhostActive(ghost, active)
    if ghost.active == active then return end
    ghost.active = active
    if ghost.model then
        ghost.model.Parent = active and workspace or nil
    end
end

-- ============================================================
-- PERSONAJES VIVOS
-- ============================================================

local function restoreLiveCharacters()
    for _, entry in ipairs(D._hiddenParts or {}) do
        local part = entry.part
        if part and part.Parent then
            pcall(function() part.Transparency = entry.value end)
        end
    end
    table.clear(D._hiddenParts or {})

    for _, entry in ipairs(D._hiddenHumanoids or {}) do
        local humanoid = entry.humanoid
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.DisplayDistanceType = entry.value end)
        end
    end
    table.clear(D._hiddenHumanoids or {})
end

local function hideLiveCharacters()
    restoreLiveCharacters()
    local function hideModel(model)
        for _, desc in ipairs(model:GetDescendants()) do
            if desc:IsA("BasePart") then
                table.insert(D._hiddenParts, { part = desc, value = desc.Transparency })
                desc.Transparency = 1
            elseif desc:IsA("Decal") then
                table.insert(D._hiddenParts, { part = desc, value = desc.Transparency })
                desc.Transparency = 1
            end
        end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            table.insert(D._hiddenHumanoids, {
                humanoid = humanoid,
                value = humanoid.DisplayDistanceType,
            })
            pcall(function() humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        end
    end
    for _, player in ipairs(UCam.Players:GetPlayers()) do
        if player.Character then hideModel(player.Character) end
    end
end

-- ============================================================
-- API DE REPRODUCCION
-- ============================================================

function UCam.demoAttachPlayers(demo)
    if not demo then return end
    for _, track in ipairs(demo.actors or {}) do
        if track.id == "local" then
            track.player = UCam.player
        else
            local userId = tonumber(tostring(track.id or ""):match("^p:(%d+)$"))
            if userId and userId > 0 then
                for _, player in ipairs(UCam.Players:GetPlayers()) do
                    if tonumber(player.UserId) == userId then
                        track.player = player
                        break
                    end
                end
            end
        end
    end
end

function UCam.demoBuildGhosts()
    for _, ghost in ipairs(D._ghosts or {}) do destroyGhost(ghost) end
    D._ghosts = {}
    local demo = D.Current
    if not demo then return 0 end

    for _, track in ipairs(demo.actors or {}) do
        if (track.frameCount or 0) > 0 and #(track.parts or {}) > 0 then
            local ghost = ghostFromClone(track) or ghostFromProxy(track)
            if ghost then
                UCam.trackInstance(ghost.model, "Demo:ghost")
                table.insert(D._ghosts, ghost)
            end
        end
    end
    return #D._ghosts
end

function UCam.demoSetCurrent(demo)
    if not demo then return false end
    UCam.demoStop()
    D.Current = demo
    D.Duration = tonumber(demo.duration) or 0
    D.Playhead = 0
    D.Paused = false

    demo.takes = demo.takes or {}
    UCam.demoAttachPlayers(demo)
    local ghosts = UCam.demoBuildGhosts()
    if D.HideLive and ghosts > 0 then hideLiveCharacters() end

    if UCam.DemoTakes then
        UCam.DemoTakes.Items = demo.takes or {}
        UCam.DemoTakes.Selected = #UCam.DemoTakes.Items > 0 and 1 or 0
    end

    if ghosts == 0 then
        UCam.notify("Replay", "El demo no tiene actores reproducibles.", 5)
        return false
    end
    UCam.demoApplyAt(0)
    UCam.notify("Replay",
        ("Demo cargado: %d actores · %.1fs · %d tomas."):format(
            ghosts, D.Duration, #(demo.takes or {})),
        5)
    return true
end

--- Aplica el demo en un tiempo concreto. Es publica porque las tomas
-- necesitan scrubbear sin que el loop de reproduccion las pise.
function UCam.demoApplyAt(t)
    local demo = D.Current
    if not demo then return end
    t = math.clamp(tonumber(t) or 0, 0, math.max(D.Duration or 0, 0))
    D.Playhead = t

    for _, ghost in ipairs(D._ghosts or {}) do
        local root, jointCFs = sampleActorTrack(ghost.track, t)
        if root then
            setGhostActive(ghost, true)
            poseGhost(ghost, root, jointCFs)
        else
            setGhostActive(ghost, false)
        end
    end

    if demo.props then
        local cfs = samplePropTrack(demo.props, t)
        if cfs then
            for index, cf in ipairs(cfs) do
                if UCam.setPropCFrame then
                    pcall(UCam.setPropCFrame, index, cf, false)
                end
            end
        end
    end
end

local function ensureFreeCam()
    if UCam.freeCamEnabled then
        UCam.camMode = "Libre"
        return true
    end
    if UCam.toggleFreeCam then
        UCam.camMode = "Libre"
        local ok = pcall(UCam.toggleFreeCam)
        return ok and UCam.freeCamEnabled == true
    end
    return false
end

local function stopPlayConnection()
    if D._playConn then
        UCam.untrackConnection(D._playConn)
        D._playConn = nil
    end
end

function UCam.demoPlay()
    if UCam.DemoTakes and UCam.DemoTakes._recording then
        return false, "Termina la toma que estas grabando."
    end
    local demo = D.Current
    if not demo then
        UCam.notify("Replay", "Graba o carga un demo primero.", 4)
        return false
    end
    if D.Playing and not D.Paused then return true end

    if #(D._ghosts or {}) == 0 then UCam.demoBuildGhosts() end
    if #(D._ghosts or {}) == 0 then
        UCam.notify("Replay", "No se pudieron crear los actores del demo.", 5)
        return false
    end
    if not ensureFreeCam() then
        UCam.notify("Replay", "Activa la camara libre para ver el demo.", 4)
    end

    if D.HideLive then hideLiveCharacters() end

    D.Playing = true
    D.Paused = false
    if D.Playhead >= (D.Duration or 0) then D.Playhead = 0 end
    UCam.demoApplyAt(D.Playhead)

    stopPlayConnection()
    D._playConn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function(dt)
            if not D.Playing or D.Paused then return end
            D.Playhead = D.Playhead + (dt or 0) * (tonumber(D.Speed) or 1)
            if D.Duration > 0 and D.Playhead >= D.Duration then
                if D.Loop then
                    D.Playhead = D.Playhead % math.max(D.Duration, 0.001)
                else
                    D.Playhead = D.Duration
                    UCam.demoApplyAt(D.Playhead)
                    UCam.demoPause()
                    return
                end
            end
            UCam.demoApplyAt(D.Playhead)
        end),
        "Demo:play"
    )
    return true
end

function UCam.demoPause()
    stopPlayConnection()
    D.Playing = false
    D.Paused = true
end

function UCam.demoStop()
    -- Si hay una toma o secuencia reproduciendose, suelta tambien el hook
    -- de camara: si no, la camara queda secuestrada tras restaurar.
    if UCam.demoSequenceStop then UCam.demoSequenceStop() end
    stopPlayConnection()
    D.Playing = false
    D.Paused = false
    D.Playhead = 0
    for _, ghost in ipairs(D._ghosts or {}) do destroyGhost(ghost) end
    D._ghosts = {}
    restoreLiveCharacters()
end

function UCam.demoSeek(t)
    if not D.Current then return false end
    if #(D._ghosts or {}) == 0 then UCam.demoBuildGhosts() end
    if D.HideLive and #(D._ghosts or {}) > 0 then hideLiveCharacters() end
    local value = math.clamp(tonumber(t) or 0, 0, math.max(D.Duration or 0, 0))
    UCam.demoApplyAt(value)
    return true
end

--- Avanza N frames del demo (negativo = atras). Pausa la reproduccion.
function UCam.demoStep(frames)
    if not D.Current then return false end
    local rate = tonumber(D.Current.rate) or tonumber(D.Rate) or 20
    frames = tonumber(frames) or 1
    UCam.demoPause()
    UCam.demoSeek((D.Playhead or 0) + frames / math.max(rate, 1))
    return true
end

function UCam.demoSetSpeed(speed)
    D.Speed = math.clamp(tonumber(speed) or 1, 0.05, 8)
    return D.Speed
end

function UCam.demoSetLoop(loop)
    D.Loop = loop == true
    return D.Loop
end

function UCam.demoSetHideLive(hide)
    D.HideLive = hide == true
    if D.HideLive and D.Current and #(D._ghosts or {}) > 0 then
        hideLiveCharacters()
    elseif not D.HideLive then
        restoreLiveCharacters()
    end
    return D.HideLive
end

function UCam.demoSummary()
    local demo = D.Current
    if not demo then return "Sin demo." end
    local lines = {
        ("%s · %.1fs · %s Hz"):format(demo.name or "Demo", demo.duration or 0, tostring(demo.rate or "?")),
    }
    for _, track in ipairs(demo.actors or {}) do
        lines[#lines + 1] = ("- %s (%s, %d frames)"):format(
            track.name or track.id or "?", track.rigType or "?", track.frameCount or 0)
    end
    if #lines == 1 then lines[#lines + 1] = "- sin actores" end
    return table.concat(lines, "\n")
end
