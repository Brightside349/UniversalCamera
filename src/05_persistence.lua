-- ============================================================
-- Universal Camera Pro v8 · 05_persistence
-- Persistencia de configuracion via writefile/readfile + JSON.
-- Guarda el estado completo de UCam en un archivo JSON local
-- para que los ajustes sobrevivan entre sesiones.
--
-- Dependencias: 00_config
-- Expone (UCam.*):
--   Persistence (tabla con toda la logica), saveConfig, loadConfig,
--   scheduleSave, exportConfig, importConfig, resetConfig
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- DETECCION DE CAPACIDAD DE FILESYSTEM
-- ============================================================
local HAS_FS = (typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(makefolder) == "function")
UCam.HasFileSystem = HAS_FS

-- ============================================================
-- CONFIG
-- ============================================================
local FOLDER      = "UniversalCamera"
local FILE        = "config_v8.json"
local AUTOSAVE_DELAY = 3.0  -- segundos de debounce

local HttpService = game:GetService("HttpService")

-- ============================================================
-- SERIALIZADORES (tabla -> JSON-safe)
-- ============================================================
local function serColor3(c)   return { r = c.R, g = c.G, b = c.B } end
local function serVector3(v)  return { x = v.X, y = v.Y, z = v.Z } end
local function serCFrame(cf)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    return { x=x, y=y, z=z, r00=r00, r01=r01, r02=r02, r10=r10, r11=r11, r12=r12, r20=r20, r21=r21, r22=r22 }
end

-- ============================================================
-- DESERIALIZADORES (JSON-safe -> tabla)
-- ============================================================
local function desColor3(t)   return Color3.new(t.r, t.g, t.b) end
local function desVector3(t)  return Vector3.new(t.x, t.y, t.z) end
local function desCFrame(t)
    return CFrame.new(t.x, t.y, t.z, t.r00, t.r01, t.r02, t.r10, t.r11, t.r12, t.r20, t.r21, t.r22)
end

-- ============================================================
-- SCHEMA: qué campos persistir de cada tabla UCam.*
-- Formato: { campo = serializer_fn }
-- serializer_fn == nil  -> copiar raw (string/number/boolean/table simple)
-- ============================================================
local SCHEMA = {
    -- Cámara libre / modo
    camMode              = nil,
    currentSpeed         = nil,
    MOUSE_SENSITIVITY    = nil,
    SPRINT_MULTIPLIER    = nil,

    -- Modos de cámara (parametros)
    Orbit = {
        Distance = nil, Height = nil, Speed = nil,
    },
    Follow = {
        Distance = nil, Height = nil, SideOffset = nil,
    },
    Lateral = {
        Distance = nil, Height = nil,
    },
    CrashZoom = {
        EndFOV = nil, Duration = nil,
    },
    Vertigo = {
        MinDistance = nil, MaxDistance = nil, Speed = nil, BaseFOV = nil,
    },
    Crane = {
        Height = nil, MinHeight = nil, MaxHeight = nil, SpinSpeed = nil,
    },
    Dolly = {
        Distance = nil,
    },
    Handheld = {
        Intensity = nil, Frequency = nil, Roll = nil,
    },
    RollAxis = {
        Speed = nil, Direction = nil,
    },
    FPVDrone = { Inertia = nil, RollSpeed = nil, MaxRoll = nil },
    Snorricam = { Distance = nil, HeightOffset = nil },
    SecurityCam = { PanSpeed = nil, PanAngle = nil },

    -- Keybinds
    Keybinds = {
        Forward = nil, Backward = nil, Left = nil, Right = nil,
        Up = nil, Down = nil, Sprint = nil,
    },

    -- Cinematic
    Letterbox = { HeightRatio = nil },
    Bloom = { Intensity = nil, Size = nil, Threshold = nil },
    DOF = { FarIntensity = nil, FocusDistance = nil, InFocusRadius = nil },
    SunRays = { Intensity = nil, Spread = nil },
    Vignette = {
        Intensity = nil, Smoothness = nil,
        Color = desColor3,  -- v8.1 FIX: usar desColor3 para deserializar {r,g,b} → Color3
    },
    Shake = { Intensity = nil, Pattern = nil },
    FovPulse = { Amplitude = nil, Speed = nil },

    -- CamCore (smooth zoom, motion blur, etc.)
    CamCore = {
        SmoothZoom = nil, ZoomSpeed = nil,
        AutoExposure = nil, MotionBlur = nil, MBAmount = nil,
        ExposureRange = { min = nil, max = nil },
        -- SavedPositions NO va aquí: ver serializeCameraPositions
    },

    -- Auto-HUD
    AutoHUD = { Enabled = nil },
    LookAtLock = { HeightOffset = nil, Smoothing = nil },
    Guides = { Enabled = nil, Type = nil, Opacity = nil },
    Capture = { HideAfterSeconds = nil },

    -- Lighting
    LightingTweaks = {
        ClockTime = nil, ExposureCompensation = nil,
        FogColor = desColor3, FogStart = nil, FogEnd = nil,  -- v8.1 FIX
        OutdoorAmbient = desColor3, Ambient = desColor3,      -- v8.1 FIX
        Brightness = nil, ShadowsEnabled = nil, ShadowIntensity = nil,
        SkyboxAssetId = nil,
    },

    -- PathVisualizer
    PathVisualizer = { Enabled = nil },

    -- Filtros
    currentFilterIndex = nil,
    FilterTransition = { Enabled = nil, Speed = nil },
    FilterCombine = { Enabled = nil, IndexA = nil, IndexB = nil, Mix = nil },
    -- CustomFilters NO va aquí: se serializa con funciones especiales
    -- (un schema vacío {} haría que serializeValue devuelva {} siempre)

    -- Espectador
    Spectate = {
        Mode = nil, Smoothing = nil, Distance = nil, Height = nil,
        FOV = nil, UseCustomFOV = nil, HideSelf = nil,
        AntiClip = nil, AutoJump = nil, ZoomScroll = nil, OnlyFavorites = nil,
    },

    -- Editor de filtros custom (estado del editor)
    customEditing = {
        Brightness = nil, Contrast = nil, Saturation = nil,
        R = nil, G = nil, B = nil,
    },

    -- Fun module (parametros que el usuario ajusta)
    Fun = {
        Mount = { Anchor = nil, HeightOffset = nil, FollowRotation = nil },
        Gravity = { Mode = nil, Custom = nil },
        SuperJump = { Power = nil },
        SpeedBoost = { WalkSpeed = nil },
        BodySpin = { Speed = nil, Axis = nil },
        Rainbow = { Speed = nil },
        Trail = { Width = nil, Duration = nil, Color = desColor3, Type = nil, Rainbow = nil, Painting = nil },  -- v8.1 FIX
        Disco = { Size = nil, Color = desColor3, Shape = nil, AnimatedLights = nil, Mirror = nil },            -- v8.1 FIX
        Particles = { Type = nil, Intensity = nil, Color = desColor3 },                                       -- v8.1 FIX
        Fly = { Speed = nil },
    },

    -- Replay (SavedRoutes se serializa aparte — cada frame tiene CFrame)
    Replay = {
        MaxDuration = nil, PlaybackSpeed = nil, Loop = nil,
        Markers = nil,
    },

    -- v9: notificaciones (modo / duración / silencio en tomas)
    Config = {
        Notifications = { Mode = nil, Duration = nil, MuteOnCapture = nil },
    },

    -- v8: Perfiles (Slots se serializa aparte por su tamaño)
    Locale = nil,

    -- Poses / BodyColor / PlayerMod (presets custom del usuario)
    -- v8.1: CustomPoses y Presets se serializan con funciones especiales
    -- (contienen CFrames y Color3 que el deepCopy genérico descarta)
    Poses = {
        TransitionSpeed = nil,
    },
    BodyColor = {
        RainbowSpeed = nil, RainbowPart = nil,
    },
    PlayerMod = {},  -- vacío; la lista de targets es dinámica y no persiste

    -- Waypoint / Director
    Waypoint = {
        Duration = nil, Loop = nil, Easing = nil,
        UseFOV = nil, FOV = nil, UseRoll = nil, Roll = nil,
        CurveMode = nil, PreviewArrows = nil,
    },
    Director = {
        SavedRoutes = nil,
    },

    -- TimeControl
    -- v8.1: Módulos eliminados (SlowMo, TimeControl, Combos, Macros, AudioReactive, FiltersPro)
    -- Ya no se persisten
}

-- ============================================================
-- HELPERS de serialización / deserialización genérica
-- ============================================================
local function serializeValue(schemaEntry, value)
    if value == nil then return nil end
    if type(schemaEntry) == "function" then
        local ok, res = pcall(schemaEntry, value)
        return ok and res or nil
    elseif type(schemaEntry) == "table" then
        -- Array serializer (CFrame, Vector3, Color3)
        if schemaEntry[1] and type(schemaEntry[1]) == "function" then
            local out = {}
            for i, item in ipairs(value) do
                local ok, res = pcall(schemaEntry[1], item)
                out[i] = ok and res or nil
            end
            return out
        end
        -- Nested schema (table campos)
        if type(value) ~= "table" then return nil end
        local out = {}
        for k, subSchema in pairs(schemaEntry) do
            out[k] = serializeValue(subSchema, value[k])
        end
        return out
    else
        -- Raw copy (number, string, bool, plain table)
        local t = typeof(value)
        if t == "number" or t == "string" or t == "boolean" then
            return value
        elseif t == "table" then
            -- Deep copy de tablas simples
            local function deepCopy(tbl)
                local out = {}
                for k, v in pairs(tbl) do
                    local tv = type(v)
                    if tv == "number" or tv == "string" or tv == "boolean" then
                        out[k] = v
                    elseif tv == "table" then
                        out[k] = deepCopy(v)
                    end
                end
                return out
            end
            return deepCopy(value)
        end
        return nil
    end
end

local function deserializeValue(schemaEntry, savedValue)
    if savedValue == nil then return nil end
    if type(schemaEntry) == "function" then
        local ok, res = pcall(schemaEntry, savedValue)
        return ok and res or nil
    elseif type(schemaEntry) == "table" then
        -- Array deserializer
        if schemaEntry[1] and type(schemaEntry[1]) == "function" then
            local out = {}
            for i, item in ipairs(savedValue) do
                local ok, res = pcall(schemaEntry[1], item)
                out[i] = ok and res or nil
            end
            return out
        end
        if type(savedValue) ~= "table" then return nil end
        local out = {}
        for k, subSchema in pairs(schemaEntry) do
            out[k] = deserializeValue(subSchema, savedValue[k])
        end
        return out
    else
        return savedValue
    end
end

-- ============================================================
-- Serializadores especializados para CustomFilters
-- Cada filtro: { Name=string, Brightness/Contrast/Saturation=number,
--                TintColor=Color3 } — Color3 no es JSON-safe.
-- ============================================================
local function serializeCustomFilters(filters)
    if type(filters) ~= "table" then return nil end
    local out = {}
    for i, f in ipairs(filters) do
        if type(f) == "table" then
            local nf = {}
            for k, v in pairs(f) do
                local tv = typeof(v)
                if tv == "number" or tv == "string" or tv == "boolean" then
                    nf[k] = v
                elseif tv == "Color3" then
                    nf[k] = { r = v.R, g = v.G, b = v.B }
                end
            end
            out[i] = nf
        end
    end
    if next(out) == nil then return nil end
    return out
end

local function deserializeCustomFilters(saved)
    if type(saved) ~= "table" then return nil end
    local out = {}
    for i, f in ipairs(saved) do
        if type(f) == "table" then
            local nf = {}
            for k, v in pairs(f) do
                if k == "TintColor" and type(v) == "table" then
                    nf[k] = Color3.new(v.r or 1, v.g or 1, v.b or 1)
                else
                    nf[k] = v
                end
            end
            out[i] = nf
        end
    end
    if next(out) == nil then return nil end
    return out
end

-- ============================================================
-- Serializador especializado para Replay.SavedRoutes
-- Cada ruta: { frames = { {cf, fov, t}, ... }, savedAt, duration, count }
-- Cada CFrame -> tabla de 12 componentes para JSON.
-- ============================================================
local function serializeReplayRoutes(routes)
    if type(routes) ~= "table" then return nil end
    local out = {}
    for slot, route in pairs(routes) do
        if type(route) == "table" and type(route.frames) == "table" then
            local frames = {}
            for i, f in ipairs(route.frames) do
                if f and f.cf then
                    frames[i] = {
                        cf  = serCFrame(f.cf),
                        fov = f.fov,
                        t   = f.t,
                        roll = f.roll,
                    }
                end
            end
            out[tostring(slot)] = {
                frames   = frames,
                savedAt  = route.savedAt,
                duration = route.duration,
                count    = route.count,
                markers  = route.markers,
            }
        end
    end
    if next(out) == nil then return nil end
    return out
end

local function deserializeReplayRoutes(saved)
    if type(saved) ~= "table" then return nil end
    local out = {}
    for slot, route in pairs(saved) do
        local slotNum = tonumber(slot)
        if slotNum and type(route) == "table" and type(route.frames) == "table" then
            local frames = {}
            for i, f in ipairs(route.frames) do
                if f and f.cf then
                    frames[i] = {
                        cf  = desCFrame(f.cf),
                        fov = f.fov,
                        t   = f.t,
                        roll = f.roll,
                    }
                end
            end
            out[slotNum] = {
                frames   = frames,
                savedAt  = route.savedAt,
                duration = route.duration,
                count    = route.count,
                markers  = route.markers,
            }
        end
    end
    if next(out) == nil then return nil end
    return out
end

-- ============================================================
-- Serializador para CamCore.SavedPositions (diccionario slot->CFrame)
-- ============================================================
local function serializeCameraPositions(pos)
    if type(pos) ~= "table" then return nil end
    local out = {}
    for slot, cf in pairs(pos) do
        if typeof(cf) == "CFrame" then
            out[tostring(slot)] = serCFrame(cf)
        end
    end
    if next(out) == nil then return nil end
    return out
end

local function deserializeCameraPositions(saved)
    if type(saved) ~= "table" then return nil end
    local out = {}
    for slot, cfTable in pairs(saved) do
        local slotNum = tonumber(slot)
        if slotNum and type(cfTable) == "table" then
            local ok, cf = pcall(desCFrame, cfTable)
            if ok then out[slotNum] = cf end
        end
    end
    if next(out) == nil then return nil end
    return out
end

-- ============================================================
-- Serializador para Poses.CustomPoses (v8.1 FIX crítico #1)
-- Cada pose: { [Motor6D.Name] = CFrame } — los CFrames NO son
-- JSON-safe. El deepCopy genérico los descartaba → poses vacías.
-- ============================================================
local function serializeCustomPoses(poses)
    if type(poses) ~= "table" then return nil end
    local out = {}
    for name, joints in pairs(poses) do
        if type(joints) == "table" then
            local jt = {}
            for jointName, cf in pairs(joints) do
                if typeof(cf) == "CFrame" then
                    jt[jointName] = serCFrame(cf)
                end
            end
            out[name] = jt
        end
    end
    if next(out) == nil then return nil end
    return out
end

local function deserializeCustomPoses(saved)
    if type(saved) ~= "table" then return nil end
    local out = {}
    for name, joints in pairs(saved) do
        if type(joints) == "table" then
            local jt = {}
            for jointName, cfTable in pairs(joints) do
                if type(cfTable) == "table" then
                    local ok, cf = pcall(desCFrame, cfTable)
                    if ok then jt[jointName] = cf end
                end
            end
            out[name] = jt
        end
    end
    if next(out) == nil then return nil end
    return out
end

-- ============================================================
-- Serializador para BodyColor.Presets (v8.1 FIX crítico #2)
-- Cada preset: { Parts = {[k]={Color, Material, Transparency}},
--               Accessories = {...} } — Color(Color3) se pierde
-- y Material puede ser EnumItem → convertirlos a JSON-safe.
-- ============================================================
local function serializeBodyColorPresets(presets)
    if type(presets) ~= "table" then return nil end
    local function serValue(v)
        if type(v) ~= "table" then return nil end
        local out = {}
        if typeof(v.Color) == "Color3" then out.Color = serColor3(v.Color) end
        local m = v.Material
        if typeof(m) == "EnumItem" or type(m) == "string" then out.Material = tostring(m) end
        out.Transparency = v.Transparency
        return out
    end
    local out = {}
    for name, preset in pairs(presets) do
        if type(preset) == "table" then
            local p = {}
            if type(preset.Parts) == "table" then
                p.Parts = {}
                for k, v in pairs(preset.Parts) do p.Parts[k] = serValue(v) end
            end
            if type(preset.Accessories) == "table" then
                p.Accessories = serValue(preset.Accessories)
            end
            out[name] = p
        end
    end
    if next(out) == nil then return nil end
    return out
end

local function deserializeBodyColorPresets(saved)
    if type(saved) ~= "table" then return nil end
    local function desValue(v)
        if type(v) ~= "table" then return { Color = nil, Material = nil, Transparency = 0 } end
        local out = { Color = nil, Material = v.Material, Transparency = v.Transparency or 0 }
        if type(v.Color) == "table" then
            out.Color = Color3.new(v.Color.r or 1, v.Color.g or 1, v.Color.b or 1)
        end
        return out
    end
    local out = {}
    for name, preset in pairs(saved) do
        if type(preset) == "table" then
            local p = { Parts = {}, Accessories = {} }
            if type(preset.Parts) == "table" then
                for k, v in pairs(preset.Parts) do p.Parts[k] = desValue(v) end
            end
            if type(preset.Accessories) == "table" then
                p.Accessories = desValue(preset.Accessories)
            end
            out[name] = p
        end
    end
    if next(out) == nil then return nil end
    return out
end

-- ============================================================
-- Serializador para Keybinds (v8.1: EnumItem → string)
-- Si un keybind guarda un Enum.KeyCode en vez de un string,
-- convertir al nombre para que JSONEncode no explote.
-- ============================================================
local function serEnumOrString(v)
    local t = typeof(v)
    if t == "EnumItem" then return v.Name end
    return v
end

-- v8.1 FIX: Spectate.Favorites guarda instancias Player → JSON explota.
-- Se serializan como nombres de jugador (typeof, no type: las Instances son userdata).
local function serFavorites(favs)
    if type(favs) ~= "table" then return nil end
    local out = {}
    for _, p in ipairs(favs) do
        if typeof(p) == "Instance" then
            if p.Name then out[#out + 1] = p.Name end
        elseif type(p) == "string" then
            out[#out + 1] = p
        end
    end
    if next(out) == nil then return nil end
    return out
end

-- ============================================================
-- NÚCLEO: construir tabla JSON-safe desde UCam.* según SCHEMA
-- ============================================================
local function buildConfigTable()
    local cfg = {}
    for topKey, schemaEntry in pairs(SCHEMA) do
        local src = UCam[topKey]
        if src ~= nil then
            cfg[topKey] = serializeValue(schemaEntry, src)
        end
    end
    -- Replay routes: serialización especializada (CFrames dentro de frames)
    cfg._replayRoutes = serializeReplayRoutes(UCam.Replay and UCam.Replay.SavedRoutes)
    -- v8 FIX: filtros custom con TintColor Color3 → {r,g,b}
    cfg._customFilters = serializeCustomFilters(UCam.CustomFilters)
    -- Posiciones de cámara guardadas: serialización especializada (dict slot->CFrame)
    cfg._cameraPositions = serializeCameraPositions(UCam.CamCore and UCam.CamCore.SavedPositions)
    -- v8.1 FIX (crítico #1): poses custom (CFrames) fuera del deepCopy genérico
    cfg._customPoses = serializeCustomPoses(UCam.Poses and UCam.Poses.CustomPoses)
    -- v8.1 FIX (crítico #2): presets de BodyColor (Color3/EnumItem)
    cfg._bodyColorPresets = serializeBodyColorPresets(UCam.BodyColor and UCam.BodyColor.Presets)
    -- v8.1 FIX (riesgo #S.Keybinds): keybinds nunca deben contener EnumItem
    if UCam.Keybinds then
        local kb = {}
        for k, v in pairs(UCam.Keybinds) do kb[k] = serEnumOrString(v) end
        cfg.Keybinds = kb
    end
    -- v8.1 FIX: Spectate.Favorites guarda instancias Player (riesgo JSON).
    -- Persistir solo los nombres.
    if UCam.Spectate and type(UCam.Spectate.Favorites) == "table" then
        local names = serFavorites(UCam.Spectate.Favorites)
        if names then cfg.SpectateNames = names end
    end
    -- Director routes son strings → raw copy ya cubierto por SCHEMA
    return cfg
end

-- ============================================================
-- PATH del archivo
-- ============================================================
local function getSavePath()
    local placeId = tostring(game.PlaceId)
    return FOLDER .. "/" .. placeId .. "/" .. FILE
end

local function ensureFolder()
    if not HAS_FS then return false end
    local ok, err = pcall(function()
        makefolder(FOLDER)
        makefolder(FOLDER .. "/" .. tostring(game.PlaceId))
    end)
    return ok
end

-- ============================================================
-- API PÚBLICA
-- ============================================================
local saveTimer = nil

function UCam.saveConfig()
    if not HAS_FS then
        return false, "WriteFile no disponible"
    end
    if not ensureFolder() then
        return false, "No se pudo crear la carpeta"
    end

    local cfg = buildConfigTable()
    -- Campos extra no en SCHEMA pero que queremos persistir
    cfg._version = "10.0"
    cfg._savedAt = os.time()
    -- v8: perfiles slots + quick (copia directa; NO contienen CFrames anidados)
    if UCam.Profiles then
        cfg._profiles = {
            Slots      = UCam.Profiles.Slots      or {},
            QuickSlots = UCam.Profiles.QuickSlots or {},
        }
    end
    if UCam.Scenes then cfg._scenes = UCam.Scenes.Slots or {} end
    if UCam.UISettings then cfg._uiSettings = UCam.UISettings end
    if UCam.Gamepad then cfg._gamepad = { Enabled = UCam.Gamepad.Enabled } end

    local ok, json = pcall(function() return HttpService:JSONEncode(cfg) end)
    if not ok then
        return false, "JSONEncode falló: " .. tostring(json)
    end

    local path = getSavePath()
    local wOk, wErr = pcall(writefile, path, json)
    if not wOk then
        return false, "writefile falló: " .. tostring(wErr)
    end
    return true
end

function UCam.loadConfig()
    if not HAS_FS then return false, "FileSystem no disponible" end
    local path = getSavePath()
    local rOk, data = pcall(readfile, path)
    if not rOk or not data then
        return false, "No hay archivo de configuración"
    end

    local jOk, cfg = pcall(function() return HttpService:JSONDecode(data) end)
    if not jOk or type(cfg) ~= "table" then
        return false, "JSONDecode falló o datos corruptos"
    end

    -- Aplicar cada tabla del config a UCam.*
    for topKey, schemaEntry in pairs(SCHEMA) do
        local saved = cfg[topKey]
        if saved ~= nil then
            local restored = deserializeValue(schemaEntry, saved)
            if restored ~= nil then
                if type(restored) == "table" and UCam[topKey] and type(UCam[topKey]) == "table" then
                    -- Merge: copiar campos restaurados sobre el estado actual
                    local function deepMerge(dst, src)
                        for k, v in pairs(src) do
                            if type(v) == "table" and type(dst[k]) == "table" then
                                deepMerge(dst[k], v)
                            else
                                dst[k] = v
                            end
                        end
                    end
                    deepMerge(UCam[topKey], restored)
                else
                    UCam[topKey] = restored
                end
            end
        end
    end

    -- CustomFilters: reemplazar directamente (es una tabla de presets)
    if cfg.CustomFilters and type(cfg.CustomFilters) == "table" then
        UCam.CustomFilters = cfg.CustomFilters
    end
    -- v8 FIX: CustomFilters se serializan con funciones especiales
    -- (ver buildConfigTable) — los TintColor (Color3) se restauran
    -- desde su forma {r,g,b}.
    if cfg._customFilters then
        UCam.CustomFilters = deserializeCustomFilters(cfg._customFilters)
    end
    -- v8.1 FIX (crítico #1): poses custom se guardan con CFrames
    if cfg._customPoses then
        local poses = deserializeCustomPoses(cfg._customPoses)
        if poses and UCam.Poses then UCam.Poses.CustomPoses = poses end
    end
    -- v8.1 FIX (crítico #2): presets de BodyColor con Color3/EnumItem
    if cfg._bodyColorPresets then
        local presets = deserializeBodyColorPresets(cfg._bodyColorPresets)
        if presets and UCam.BodyColor then UCam.BodyColor.Presets = presets end
    end
    -- Rutas guardadas (Replay/Director): reemplazo directo, no merge
    if cfg._replayRoutes then
        local routes = deserializeReplayRoutes(cfg._replayRoutes)
        if routes then
            UCam.Replay.SavedRoutes = routes
        end
    end
    if cfg.Director and cfg.Director.SavedRoutes then
        UCam.Director.SavedRoutes = cfg.Director.SavedRoutes
    end
    -- Posiciones de cámara guardadas: reemplazo directo
    if cfg._cameraPositions then
        local pos = deserializeCameraPositions(cfg._cameraPositions)
        if pos then
            UCam.CamCore.SavedPositions = pos
        end
    end
    -- Poses/presets custom: reemplazo directo
    -- (Poses.CustomPoses y BodyColor.Presets se restauran vía _customPoses /
    --  _bodyColorPresets serializados, no por estas ramas del schema)

    -- v8 FIX: perfiles guardados en disco se restauran aquí también
    -- (antes solo se restauraban en importConfig, así que se perdían al reiniciar)
    if cfg._profiles and UCam.Profiles then
        UCam.Profiles.Slots      = cfg._profiles.Slots      or {}
        UCam.Profiles.QuickSlots = cfg._profiles.QuickSlots or {}
    end
    if cfg._scenes and UCam.Scenes then UCam.Scenes.Slots = cfg._scenes end
    if cfg._uiSettings and UCam.UISettings then
        for key, value in pairs(cfg._uiSettings) do UCam.UISettings[key] = value end
        if UCam.applyUISettings then UCam.applyUISettings() end
    end
    if cfg._gamepad and UCam.Gamepad then UCam.Gamepad.Enabled = cfg._gamepad.Enabled == true end
    -- v8.1 FIX: restaurar favoritos desde nombres resueltos a instancias Player
    if cfg.SpectateNames and type(cfg.SpectateNames) == "table" and UCam.Spectate then
        local favs = {}
        for _, name in ipairs(cfg.SpectateNames) do
            local p = UCam.Players:FindFirstChild(name)
            if p and p ~= UCam.player then table.insert(favs, p) end
        end
        UCam.Spectate.Favorites = favs
    end

    return true
end

-- ============================================================
-- AUTOSAVE con debounce
-- ============================================================
function UCam.scheduleSave()
    if saveTimer then task.cancel(saveTimer) end
    saveTimer = task.delay(AUTOSAVE_DELAY, function()
        saveTimer = nil
        pcall(UCam.saveConfig)
    end)
end

-- ============================================================
-- EXPORT / IMPORT (Base64 string para compartir)
-- ============================================================
function UCam.exportConfig()
    local cfg = buildConfigTable()
    local ok, json = pcall(function() return HttpService:JSONEncode(cfg) end)
    if not ok then return nil, "JSONEncode falló" end
    return HttpService:Base64Encode(json)
end

function UCam.importConfig(base64)
    local ok1, json = pcall(function() return HttpService:Base64Decode(base64) end)
    if not ok1 then return false, "Base64Decode falló" end
    local ok2, cfg = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok2 then return false, "JSONDecode falló" end

    for topKey, schemaEntry in pairs(SCHEMA) do
        local saved = cfg[topKey]
        if saved ~= nil then
            local restored = deserializeValue(schemaEntry, saved)
            if restored ~= nil then
                if type(restored) == "table" and type(UCam[topKey]) == "table" then
                    local function deepMerge(dst, src)
                        for k, v in pairs(src) do
                            if type(v) == "table" and type(dst[k]) == "table" then
                                deepMerge(dst[k], v)
                            else
                                dst[k] = v
                            end
                        end
                    end
                    deepMerge(UCam[topKey], restored)
                else
                    UCam[topKey] = restored
                end
            end
        end
    end

    if cfg.CustomFilters and type(cfg.CustomFilters) == "table" then
        UCam.CustomFilters = cfg.CustomFilters
    end
    -- v8 FIX: restaurar filtros custom desde el formato especial
    if cfg._customFilters then
        local restored = deserializeCustomFilters(cfg._customFilters)
        if restored then UCam.CustomFilters = restored end
    end
    -- v8.1 FIX (crítico #3): importConfig debe restaurar también
    -- rutas de Replay, posiciones de cámara, poses y presets de BodyColor.
    if cfg._replayRoutes then
        local routes = deserializeReplayRoutes(cfg._replayRoutes)
        if routes and UCam.Replay then UCam.Replay.SavedRoutes = routes end
    end
    if cfg.Director and cfg.Director.SavedRoutes and UCam.Director then
        UCam.Director.SavedRoutes = cfg.Director.SavedRoutes
    end
    if cfg._cameraPositions then
        local pos = deserializeCameraPositions(cfg._cameraPositions)
        if pos and UCam.CamCore then UCam.CamCore.SavedPositions = pos end
    end
    if cfg._customPoses then
        local poses = deserializeCustomPoses(cfg._customPoses)
        if poses and UCam.Poses then UCam.Poses.CustomPoses = poses end
    end
    if cfg._bodyColorPresets then
        local presets = deserializeBodyColorPresets(cfg._bodyColorPresets)
        if presets and UCam.BodyColor then UCam.BodyColor.Presets = presets end
    end
    -- v8: restaurar perfiles (copia directa; NO contienen CFrames anidados)
    if cfg._profiles and UCam.Profiles then
        UCam.Profiles.Slots      = cfg._profiles.Slots      or {}
        UCam.Profiles.QuickSlots = cfg._profiles.QuickSlots or {}
    end
    -- v8.1 FIX: restaurar favoritos desde nombres
    if cfg.SpectateNames and type(cfg.SpectateNames) == "table" and UCam.Spectate then
        local favs = {}
        for _, name in ipairs(cfg.SpectateNames) do
            local p = UCam.Players:FindFirstChild(name)
            if p and p ~= UCam.player then table.insert(favs, p) end
        end
        UCam.Spectate.Favorites = favs
    end

    return true
end

function UCam.resetConfig()
    UCam.DEFAULTS = UCam.DEFAULTS or {}
    -- Los defaults se aplican via ui/inicio.lua → botón Restablecer
    -- Aquí solo borramos el archivo persistido
    if HAS_FS then
        local dOk = pcall(function() delfile(getSavePath()) end)
        return dOk
    end
    return false
end

-- ============================================================
-- Auto-load al cargar este módulo (llamado desde 90_init)
-- ============================================================
function UCam.initPersistence()
    if not HAS_FS then
        warn("[UCam] Persistencia: writefile/readfile no disponibles. Config no persistirá.")
        return false
    end
    local ok, err = UCam.loadConfig()
    if ok then
        print("[UCam] Persistencia: configuración cargada desde disco.")
    elseif err ~= "No hay archivo de configuración" then
        warn("[UCam] Persistencia: error cargando config: " .. tostring(err))
    end
    return ok
end
