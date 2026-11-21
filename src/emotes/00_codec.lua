-- ============================================================
-- Universal Camera Pro v13.9 · emotes/00_codec
-- Convierte un baile empaquetado de UCam en un Animation que se
-- reproduce en TU cliente sin descargar ningun asset de Roblox.
--
-- Por que existe: desde 2025 las animaciones son assets
-- "Restricted". Solo cargan en experiencias a las que el dueno
-- del asset dio permiso, y ese permiso lo concede el dueno del
-- asset sobre una experiencia que puede editar. Un creador que
-- inyecta UCam en un juego ajeno no puede autorizar nada, y el
-- juego no puede autorizar su asset en nombre de otro.
--
-- Solucion: el baile viaja dentro del script.
--   base64 -> KeyframeSequence -> RegisterKeyframeSequence -> hash
-- Ese hash se usa como Animation.AnimationId y solo existe en
-- este cliente, asi que no hay asset, no hay serverplaceid y no
-- hay permiso que pedir. Nada se envia al servidor.
--
-- Formato del payload (little endian):
--   u8 version (1) | u8 fps | u16 poses | u16 frames
--   por pose: u16 parent (0xFFFF = raiz) | u8 flags (bit0 = tiene
--             posicion) | u8 largo | nombre utf8
--   por frame, por pose: i16 x3 = grados * QUANT
--             y si flags.bit0: i16 x3 = studs * 1000
--
-- Dependencias: UCam.BASE / UCam.FALLBACK_BASE (Loader).
-- ============================================================
local UCam = _G.UCam

local Codec = {}
UCam.EmoteCodec = Codec

local QUANT = 24          -- 1/24 de grado (error maximo 0.042°)
local POS_SCALE = 1000    -- milesimas de stud
local ROOT = 0xFFFF
local VERSION = 1
local FRAMES_PER_CHUNK = 24  -- frames construidos antes de ceder el frame

-- Cache: key del personaje -> { hash, sequence }
Codec._packs = {}
-- Cache del payload ya descargado, para no repetir la peticion al cambiar
-- de personaje o reintentar un baile.
Codec._sources = {}
-- Bailes en construccion y su progreso 0..1 (para la UI).
Codec._building = {}
Codec._progress = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INV = {}
for i = 1, #B64 do
    INV[string.byte(B64, i)] = i - 1
end

--- Decodifica base64 a string binario.
function Codec.base64Decode(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%s", "")
    local n = #text
    local bytes = table.create(math.floor(n * 3 / 4) + 3)

    local count = 0
    local i = 1
    while i <= n do
        local a = INV[text:byte(i)] or 0
        local b = INV[text:byte(i + 1)] or 0
        local cChar = text:byte(i + 2)
        local dChar = text:byte(i + 3)
        local c = cChar and INV[cChar]
        local d = dChar and INV[dChar]

        local value = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        count += 1
        bytes[count] = math.floor(value / 65536) % 256
        if c then
            count += 1
            bytes[count] = math.floor(value / 256) % 256
        end
        if d then
            count += 1
            bytes[count] = value % 256
        end
        i += 4
    end

    -- string.char no acepta miles de argumentos de golpe.
    local parts = {}
    for start = 1, count, 4000 do
        parts[#parts + 1] = string.char(table.unpack(bytes, start, math.min(start + 3999, count)))
    end
    return table.concat(parts)
end

--- Construye el KeyframeSequence a partir del payload ya decodificado.
-- Crea miles de Pose (poses x frames), así que se construye por tandas y
-- cede el frame: sin esto, el primer play congelaba el cliente ~1 s.
-- Puede hacer yield. @param onProgress opcional, funcion(peso 0..1)
-- @return KeyframeSequence | nil, error
function Codec.build(data, onProgress)
    if type(data) ~= "string" or #data < 8 then return nil, "payload vacio" end

    local ok, version, fps, poseCount, frameCount = pcall(string.unpack, "<BBI2I2", data, 1)
    if not ok or version ~= VERSION then
        return nil, "version de empaquetado no soportada"
    end
    if fps <= 0 or poseCount <= 0 or frameCount <= 0 then
        return nil, "cabecera invalida"
    end

    -- Cabecera: u8 + u8 + u16 + u16 = 6 bytes, asi que el primer registro
    -- empieza en la posicion 7 (string.unpack es 1-based).
    local pos = 7
    local poses = table.create(poseCount)
    for i = 1, poseCount do
        local parent, flags, nameLen, nextPos = string.unpack("<I2BB", data, pos)
        pos = nextPos
        local name = string.sub(data, pos, pos + nameLen - 1)
        pos = pos + nameLen
        poses[i] = {
            parent = parent,
            hasPos = bit32.band(flags, 1) == 1,
            name = name,
        }
    end

    local sequence = Instance.new("KeyframeSequence")
    sequence.Name = "UCamEmotePack"
    sequence.Loop = true

    for frame = 0, frameCount - 1 do
        local keyframe = Instance.new("Keyframe")
        keyframe.Time = frame / fps

        local created = table.create(poseCount)
        for i = 1, poseCount do
            local poseInfo = poses[i]
            local rx, ry, rz, nextPos = string.unpack("<i2i2i2", data, pos)

            local cf
            if poseInfo.hasPos then
                local px, py, pz, afterPos = string.unpack("<i2i2i2", data, nextPos)
                cf = CFrame.new(px / POS_SCALE, py / POS_SCALE, pz / POS_SCALE)
                    * CFrame.fromEulerAnglesXYZ(math.rad(rx / QUANT), math.rad(ry / QUANT), math.rad(rz / QUANT))
                pos = afterPos
            else
                cf = CFrame.fromEulerAnglesXYZ(math.rad(rx / QUANT), math.rad(ry / QUANT), math.rad(rz / QUANT))
                pos = nextPos
            end

            local pose = Instance.new("Pose")
            pose.Name = poseInfo.name
            pose.CFrame = cf
            pose.Weight = 1
            pose.EasingStyle = Enum.PoseEasingStyle.Linear
            created[i] = pose
        end

        -- El empaquetador guarda el padre antes que el hijo (pre-orden),
        -- asi que al llegar aqui el padre ya existe en este keyframe.
        for i = 1, poseCount do
            local parentIndex = poses[i].parent
            local parentPose = parentIndex ~= ROOT and created[parentIndex + 1] or nil
            created[i].Parent = parentPose or keyframe
        end

        keyframe.Parent = sequence

        if onProgress then
            onProgress((frame + 1) / frameCount)
        end
        if (frame + 1) % FRAMES_PER_CHUNK == 0 then
            task.wait()
        end
    end

    return sequence
end

--- Descarga (y cachea) un modulo de baile del repo.
function Codec.fetch(relPath)
    if Codec._sources and Codec._sources[relPath] then
        return Codec._sources[relPath]
    end

    local bases = { UCam.BASE, UCam.FALLBACK_BASE }
    for _ = 1, 2 do
        for _, base in ipairs(bases) do
            if base then
                local ok, body = pcall(function()
                    return game:HttpGet(base .. relPath)
                end)
                if ok and type(body) == "string" and #body > 32
                    and not body:find("404: Not Found", 1, true) then
                    local chunk, loadErr = loadstring(body, relPath)
                    if chunk then
                        local okRun, payload = pcall(chunk)
                        if okRun and type(payload) == "string" and #payload > 32 then
                            Codec._sources[relPath] = payload
                            return payload
                        end
                    else
                        warn(("[UCam] Baile %s no compila: %s"):format(relPath, tostring(loadErr)))
                    end
                end
            end
        end
    end
    return nil
end

--- Devuelve el hash local del baile, construyendolo la primera vez.
-- Puede hacer yield (descarga + construccion por tandas).
-- @return hash | nil, error
function Codec.hashFor(key, relPath)
    local cached = Codec._packs[key]
    if cached and cached.hash then
        return cached.hash
    end

    -- Como la construccion cede el frame, la tecla pulsada otra vez mientras
    -- se empaqueta espera al primer intento en vez de arrancar una segunda
    -- construccion del mismo baile.
    if Codec._building[key] then
        local deadline = os.clock() + 30
        while Codec._building[key] and os.clock() < deadline do
            task.wait(0.1)
        end
        local done = Codec._packs[key]
        if done and done.hash then
            return done.hash
        end
        return nil, "el baile se esta empaquetando ainda, vuelvelo a intentar"
    end
    Codec._building[key] = true

    local ok, result = pcall(function()
        local payload = Codec.fetch(relPath)
        if not payload then
            error(("no se pudo descargar %s"):format(tostring(relPath)), 0)
        end

        local data = Codec.base64Decode(payload)
        local sequence, buildErr = Codec.build(data, function(frac)
            Codec._progress[key] = frac
        end)
        if not sequence then
            error(buildErr, 0)
        end

        local provider = game:GetService("KeyframeSequenceProvider")
        local regOk, hash = pcall(function()
            return provider:RegisterKeyframeSequence(sequence)
        end)
        if not regOk or type(hash) ~= "string" or hash == "" then
            sequence:Destroy()
            error("RegisterKeyframeSequence fallo: " .. tostring(hash), 0)
        end

        Codec._packs[key] = { hash = hash, sequence = sequence }
        return hash
    end)

    Codec._building[key] = nil
    Codec._progress[key] = nil

    if not ok then
        return nil, result
    end
    return result
end

--- Suelta los empaquetados (al descargar UCam).
function Codec.release()
    for _, entry in pairs(Codec._packs) do
        if entry.sequence then
            pcall(function() entry.sequence:Destroy() end)
        end
    end
    Codec._packs = {}
    Codec._sources = {}
    -- Se sueltan aparte: si habia una construccion en vuelo, su marca quedaria
    -- y el siguiente intento esperaria 30 s en vez de reconstruir.
    Codec._building = {}
    Codec._progress = {}
end

--- Dice si el baile ya esta registrado (no hace falta descargar ni construir).
function Codec.isReady(key)
    local cached = Codec._packs[key]
    return cached ~= nil and cached.hash ~= nil
end

--- Cuantos bailes configurados estan ya empaquetados, para la UI.
function Codec.prepared()
    local prepared, total = 0, 0
    for key, dance in pairs((UCam.Emotes or {}).Dances or {}) do
        if dance.Pack then
            total += 1
            if Codec.isReady(key) then
                prepared += 1
            end
        end
    end
    return { prepared = prepared, total = total }
end
