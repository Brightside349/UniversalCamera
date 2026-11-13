-- ============================================================
-- Universal Camera Pro v13.7 · demo/96_file
-- Formato .ucamdemo: cabecera JSON + bloques binarios float32.
--
--   "UCDM" | version(I4) | headerLen(I4) | header JSON | chunks
--
-- La cabecera lleva nombre, duracion, descriptores de rig, props,
-- marcas y tomas. Cada pista es un bloque de frames de tamano fijo,
-- asi el reproductor salta a cualquier muestra sin decodificar todo.
--
-- Si el executor no expone writefile/readfile, el demo se puede
-- exportar como base64 al portapapeles y volver a importar.
--
-- Dependencias: core/00_config.lua, core/05_persistence.lua,
--               demo/92_recorder.lua, demo/94_player.lua.
-- Expone (UCam.*):
--   demoEncode, demoDecode, demoReadHeader,
--   demoBase64Encode, demoBase64Decode,
--   demoSaveAs, demoRefreshLibrary, demoLibraryOptions,
--   demoLoadFile, demoDeleteFile, demoExportSelected,
--   demoImportBase64, demoFolder.
-- ============================================================
local UCam = _G.UCam
local D = UCam.Demo

local HttpService = game:GetService("HttpService")
local MAGIC = "UCDM"
local VERSION = 1
local EXT = ".ucamdemo"
local FOLDER = "UniversalCamera"

-- ============================================================
-- BASE64 (sin depender de APIs del executor)
-- ============================================================
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_BYTES = {}
local B64_VALUE = {}
local B64_PAD = 61  -- "="
for i = 1, #B64_CHARS do
    local code = B64_CHARS:byte(i)
    B64_BYTES[i] = code
    B64_VALUE[code] = i - 1
end

-- Se empaquetan 64 caracteres por string.char: un demo de varios MB
-- no debe crear una entrada de tabla por byte.
local B64_BLOCK = 64

function UCam.demoBase64Encode(data)
    if type(data) ~= "string" then return "" end
    local out = {}
    local codes = {}
    local count = 0
    local byte = string.byte

    local function flush()
        if count == 0 then return end
        out[#out + 1] = string.char(table.unpack(codes, 1, count))
        count = 0
    end

    for i = 1, #data, 3 do
        local a, b, c = byte(data, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)

        count = count + 1
        codes[count] = B64_BYTES[math.floor(n / 262144) % 64 + 1]
        count = count + 1
        codes[count] = B64_BYTES[math.floor(n / 4096) % 64 + 1]
        count = count + 1
        codes[count] = b and B64_BYTES[math.floor(n / 64) % 64 + 1] or B64_PAD
        count = count + 1
        codes[count] = c and B64_BYTES[n % 64 + 1] or B64_PAD

        if count >= B64_BLOCK then flush() end
    end
    flush()
    return table.concat(out)
end

function UCam.demoBase64Decode(text)
    if type(text) ~= "string" then return nil, "Base64 vacio." end
    text = text:gsub("%s+", "")
    if text == "" then return nil, "Base64 vacio." end

    local out = {}
    local codes = {}
    local count = 0
    local buffer, bits = 0, 0
    local byte = string.byte

    local function flush()
        if count == 0 then return end
        out[#out + 1] = string.char(table.unpack(codes, 1, count))
        count = 0
    end

    for i = 1, #text do
        local code = byte(text, i)
        if code == B64_PAD then break end
        local value = B64_VALUE[code]
        if value == nil then return nil, "Caracter base64 invalido." end

        buffer = buffer * 64 + value
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            count = count + 1
            codes[count] = math.floor(buffer / (2 ^ bits)) % 256
            buffer = buffer % (2 ^ bits)
            if count >= B64_BLOCK then flush() end
        end
    end
    flush()
    return table.concat(out)
end

-- ============================================================
-- CODIFICACION
-- ============================================================

local function copyTable(source)
    if type(source) ~= "table" then return source end
    local out = {}
    for key, value in pairs(source) do
        out[key] = copyTable(value)
    end
    return out
end

local function headerFor(demo)
    local header = {
        version = VERSION,
        name = demo.name,
        createdAt = demo.createdAt,
        rate = demo.rate,
        duration = demo.duration,
        settings = copyTable(demo.settings),
        markers = copyTable(demo.markers or {}),
        takes = copyTable(demo.takes or {}),
        actors = {},
        props = nil,
    }
    for i, track in ipairs(demo.actors or {}) do
        -- "local" solo tiene sentido en la sesion que grabo. Al guardar
        -- se identifica por UserId para que otro cliente no clone SU
        -- personaje al abrir el archivo.
        local savedId = track.id
        local uid = tonumber(track.userId)
        if savedId == "local" and uid and uid > 0 then
            savedId = "p:" .. tostring(math.floor(uid))
        end
        header.actors[i] = {
            id = savedId,
            name = track.name,
            userId = track.userId,
            rigType = track.rigType,
            rootPath = track.rootPath,
            parts = track.parts,
            joints = track.joints,
            statics = track.statics,
            t0 = track.t0,
            endedAt = track.endedAt,
            frameCount = track.frameCount,
            frameBytes = track.frameBytes,
            byteLength = #(track.chunk or ""),
        }
    end
    if demo.props then
        header.props = {
            items = demo.props.items,
            t0 = demo.props.t0,
            frameCount = demo.props.frameCount,
            frameBytes = demo.props.frameBytes,
            byteLength = #(demo.props.chunk or ""),
        }
    end
    return header
end

function UCam.demoEncode(demo)
    if type(demo) ~= "table" then return nil, "Demo invalido." end
    local header = headerFor(demo)
    local ok, json = pcall(function()
        return HttpService:JSONEncode(header)
    end)
    if not ok or type(json) ~= "string" then
        return nil, "No se pudo serializar la cabecera: " .. tostring(json)
    end

    local out = {
        MAGIC,
        string.pack("<I4", VERSION),
        string.pack("<I4", #json),
        json,
    }
    for _, track in ipairs(demo.actors or {}) do
        out[#out + 1] = track.chunk or ""
    end
    if demo.props then out[#out + 1] = demo.props.chunk or "" end
    return table.concat(out)
end

local function extractTimes(track)
    local times = {}
    local fmt = "<f"
    for i = 1, (track.frameCount or 0) do
        local value = string.unpack(fmt, track.chunk, (i - 1) * track.frameBytes + 1)
        times[i] = value
    end
    return times
end

local function trackFromHeader(info, chunk)
    local jointCount = #(info.joints or {})
    local fmt = "<" .. string.rep("f", 1 + 12 + 12 * jointCount)
    local frameBytes = string.packsize(fmt)
    local expected = frameBytes * (info.frameCount or 0)
    if #chunk < expected then
        return nil, "Bloque de actor truncado."
    end
    local track = {
        id = info.id,
        name = info.name,
        userId = info.userId,
        rigType = info.rigType,
        rootPath = info.rootPath,
        parts = info.parts or {},
        joints = info.joints or {},
        statics = info.statics or {},
        t0 = info.t0 or 0,
        endedAt = info.endedAt,
        frameCount = info.frameCount or 0,
        frameBytes = frameBytes,
        fmt = fmt,
        chunk = chunk,
        player = nil,
    }
    track.times = extractTimes(track)
    return track
end

local function propTrackFromHeader(info, chunk)
    local count = #(info.items or {})
    local fmt = "<" .. string.rep("f", 1 + 12 * count)
    local frameBytes = string.packsize(fmt)
    if #chunk < frameBytes * (info.frameCount or 0) then
        return nil, "Bloque de props truncado."
    end
    local track = {
        items = info.items or {},
        t0 = info.t0 or 0,
        frameCount = info.frameCount or 0,
        frameBytes = frameBytes,
        fmt = fmt,
        chunk = chunk,
    }
    track.times = extractTimes(track)
    return track
end

function UCam.demoReadHeader(blob)
    if type(blob) ~= "string" or #blob < 12 then
        return nil, "Archivo demasiado corto."
    end
    if blob:sub(1, 4) ~= MAGIC then
        return nil, "No es un archivo .ucamdemo."
    end
    local version, pos = string.unpack("<I4", blob, 5)
    if version ~= VERSION then
        return nil, ("Version de demo no soportada (%s)."):format(tostring(version))
    end
    local headerLen
    headerLen, pos = string.unpack("<I4", blob, pos)
    if #blob < pos + headerLen - 1 then
        return nil, "Cabecera truncada."
    end
    local json = blob:sub(pos, pos + headerLen - 1)
    local ok, header = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(header) ~= "table" then
        return nil, "Cabecera JSON invalida."
    end
    return header
end

function UCam.demoDecode(blob)
    local header, err = UCam.demoReadHeader(blob)
    if not header then return nil, err end

    local headerLen = string.unpack("<I4", blob, 9)
    local pos = 13 + headerLen

    local demo = {
        version = VERSION,
        name = header.name,
        createdAt = header.createdAt,
        rate = header.rate,
        duration = header.duration,
        settings = header.settings or {},
        markers = header.markers or {},
        takes = header.takes or {},
        actors = {},
        props = nil,
    }

    for _, info in ipairs(header.actors or {}) do
        local length = tonumber(info.byteLength) or 0
        local chunk = blob:sub(pos, pos + length - 1)
        pos = pos + length
        local track, trackErr = trackFromHeader(info, chunk)
        if not track then return nil, trackErr end
        table.insert(demo.actors, track)
    end

    if header.props then
        local length = tonumber(header.props.byteLength) or 0
        local chunk = blob:sub(pos, pos + length - 1)
        pos = pos + length
        local track, trackErr = propTrackFromHeader(header.props, chunk)
        if not track then return nil, trackErr end
        demo.props = track
    end

    return demo
end

-- ============================================================
-- ARCHIVOS
-- ============================================================

function UCam.demoFolder()
    return FOLDER .. "/" .. tostring(game.PlaceId) .. "/demos"
end

local function ensureFolder()
    if UCam.HasFileSystem ~= true then return false end
    pcall(function()
        makefolder(FOLDER)
        makefolder(FOLDER .. "/" .. tostring(game.PlaceId))
        makefolder(UCam.demoFolder())
    end)
    return true
end

local function safeName(name)
    local text = tostring(name or ""):gsub("[^%w%-_ ]", ""):gsub("%s+", "_")
    text = text:sub(1, 48)
    if text == "" then text = "demo_" .. tostring(os.time()) end
    return text
end

local function fileNameOf(path)
    return tostring(path):match("([^/\\]+)$") or tostring(path)
end

local function readHeaderFromFile(path)
    if UCam.HasFileSystem ~= true then return nil end
    local ok, data = pcall(readfile, path)
    if not ok or type(data) ~= "string" then return nil end
    local header = UCam.demoReadHeader(data)
    return header, #data
end

function UCam.demoRefreshLibrary()
    D.Library = {}
    if UCam.HasFileSystem ~= true then return {} end
    local ok, files = pcall(listfiles, UCam.demoFolder())
    if not ok or type(files) ~= "table" then return {} end
    for _, path in ipairs(files) do
        if tostring(path):sub(-#EXT) == EXT then
            local header, size = readHeaderFromFile(path)
            if header then
                table.insert(D.Library, {
                    file = fileNameOf(path),
                    name = header.name or fileNameOf(path),
                    duration = tonumber(header.duration) or 0,
                    actors = #(header.actors or {}),
                    createdAt = tonumber(header.createdAt) or 0,
                    size = size or 0,
                })
            end
        end
    end
    table.sort(D.Library, function(a, b)
        return (a.createdAt or 0) > (b.createdAt or 0)
    end)
    return D.Library
end

function UCam.demoLibraryOptions()
    UCam.demoRefreshLibrary()
    local options = {}
    for i, entry in ipairs(D.Library) do
        options[i] = ("%02d · %s (%.1fs, %d act.)"):format(
            i, entry.name, entry.duration, entry.actors)
    end
    if #options == 0 then options[1] = "(sin demos guardados)" end
    return options
end

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        return ok
    end
    return false
end

function UCam.demoSaveAs(name)
    local demo = D.Current
    if not demo then return false, "No hay demo para guardar." end
    if name and tostring(name) ~= "" then
        demo.name = tostring(name):gsub("[%c]", " "):sub(1, 60)
    end

    local blob, err = UCam.demoEncode(demo)
    if not blob then return false, err end

    if UCam.HasFileSystem ~= true then
        local encoded = UCam.demoBase64Encode(blob)
        local copied = copyToClipboard(encoded)
        UCam.notify("Replay",
            copied
                and ("Sin writefile: demo copiado al portapapeles (%d KB base64)."):format(#encoded // 1024)
                or ("Sin writefile: exporta con el boton y guarda el texto (%d KB)."):format(#encoded // 1024),
            6, { important = true })
        D._lastExport = encoded
        return true, encoded, copied
    end

    if not ensureFolder() then return false, "No se pudo crear la carpeta de demos." end
    local file = safeName(demo.name)
    local path = UCam.demoFolder() .. "/" .. file .. EXT
    local ok, writeErr = pcall(writefile, path, blob)
    if not ok then
        return false, "writefile fallo: " .. tostring(writeErr)
    end

    D.Selected = file .. EXT
    UCam.demoRefreshLibrary()
    UCam.notify("Replay",
        ("Demo guardado: %s (%.1f MB)."):format(D.Selected, #blob / 1048576),
        5)
    return true, D.Selected
end

local function findLibraryEntry(key)
    if key == nil then return nil end
    -- La UI pasa etiquetas ("01 · nombre") y el codigo puede pasar indices.
    if type(key) == "number" then
        return D.Library[math.floor(key)]
    end
    if type(key) ~= "string" or key == "" then return nil end
    for _, entry in ipairs(D.Library) do
        if entry.file == key or entry.name == key then return entry end
    end
    local index = tonumber(key:match("^(%d+)"))
    if index then return D.Library[index] end
    -- Coincidencia por nombre de archivo sin extension
    for _, entry in ipairs(D.Library) do
        if entry.file:gsub("%.ucamdemo$", "") == key then return entry end
    end
    return nil
end

function UCam.demoLoadFile(key)
    if UCam.HasFileSystem ~= true then
        return false, "Sin acceso a archivos; usa Importar desde base64."
    end
    UCam.demoRefreshLibrary()
    local entry = findLibraryEntry(key)
    if entry then key = entry.file end
    local path = tostring(key or "")
    if path:sub(-#EXT) ~= EXT then
        return false, "Selecciona un demo guardado."
    end
    if not path:find("[/\\]") then
        path = UCam.demoFolder() .. "/" .. path
    end

    local ok, data = pcall(readfile, path)
    if not ok or type(data) ~= "string" then
        return false, "No se pudo leer el archivo."
    end
    local demo, err = UCam.demoDecode(data)
    if not demo then return false, err end

    D.Selected = fileNameOf(path)
    local loaded = UCam.demoSetCurrent(demo)
    if loaded then
        UCam.notify("Replay", ("Cargado %s (%.1fs)."):format(demo.name or D.Selected, demo.duration or 0), 5)
    end
    return loaded, demo
end

function UCam.demoDeleteFile(key)
    if UCam.HasFileSystem ~= true then return false, "Sin acceso a archivos." end
    UCam.demoRefreshLibrary()
    local entry = findLibraryEntry(key)
    local file = entry and entry.file or tostring(key or "")
    if file == "" or file:sub(-#EXT) ~= EXT then return false, "Demo no valido." end
    local path = file:find("[/\\]") and file or (UCam.demoFolder() .. "/" .. file)
    local ok = pcall(delfile, path)
    if ok then
        if D.Selected == file then D.Selected = "" end
        UCam.demoRefreshLibrary()
        UCam.notify("Replay", "Demo eliminado.", 3)
        return true
    end
    return false, "No se pudo eliminar."
end

function UCam.demoExportSelected()
    local demo = D.Current
    if not demo then return nil, "No hay demo cargado." end
    local blob, err = UCam.demoEncode(demo)
    if not blob then return nil, err end
    local encoded = UCam.demoBase64Encode(blob)
    D._lastExport = encoded
    local copied = copyToClipboard(encoded)
    return encoded, copied
end

function UCam.demoImportBase64(text, name)
    local blob, err = UCam.demoBase64Decode(text)
    if not blob then return false, err end
    local demo, decodeErr = UCam.demoDecode(blob)
    if not demo then return false, decodeErr end
    if name and tostring(name) ~= "" then
        demo.name = tostring(name):gsub("[%c]", " "):sub(1, 60)
    end
    local ok = UCam.demoSetCurrent(demo)
    if ok then
        UCam.notify("Replay", ("Demo importado: %s."):format(demo.name or "?"), 4)
    end
    return ok, demo
end
