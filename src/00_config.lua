-- ============================================================
-- Universal Camera Pro v6 · 00_config
-- Servicios, Rayfield, notify y TODAS las tablas de estado.
-- Esta parte NO define logica; solo crea el namespace UCam y
-- expone lo que el resto de archivos necesita.
--
-- Dependencias: ninguna (es la primera parte).
-- Expone: UCam.Servicios, UCam.Rayfield, UCam.notify,
--         UCam.player, UCam.camera, UCam.controls,
--         UCam.Saved, UCam.Hud, UCam.CamModes, UCam.camMode,
--         UCam.Orbit, UCam.DronePath, UCam.Lateral, UCam.Follow,
--         UCam.CrashZoom, UCam.Vertigo, UCam.Crane, UCam.Dolly,
--         UCam.Handheld, UCam.RollAxis, UCam.Waypoint, UCam.Director,
--         UCam.SlowMo, UCam.Letterbox, UCam.Bloom, UCam.DOF,
--         UCam.SunRays, UCam.Vignette, UCam.Shake, UCam.FovPulse,
--         UCam.Spectate, UCam.CameraTransition, UCam.AutoFocusDOF,
--         UCam.AutoCycle, UCam.UIRefs, UCam.AutoHUD, UCam.LookAtLock,
--         UCam.GreenScreen, UCam.OriginalLighting, UCam.LightingTweaks,
--         UCam.PathVisualizer, UCam.Fun, UCam.Filters, UCam.CustomFilters,
--         UCam.customEditing, UCam.customFilterLiveApplied,
--         UCam.MAX_CUSTOM_FILTERS, UCam.BLOOM_EFFECT_NAME,
--         UCam.DOF_EFFECT_NAME, UCam.SUNRAYS_EFFECT_NAME,
--         UCam.DEFAULTS, UCam.triggerTransition,
--         UCam.MOUSE_SENSITIVITY, UCam.SLIDER_MIN_SPEED,
--         UCam.SLIDER_MAX_SPEED, UCam.currentSpeed,
--         UCam.MOVEMENT_SMOOTHING, UCam.SPRINT_MULTIPLIER,
--         UCam.MIN_FOV, UCam.MAX_FOV, UCam.DEFAULT_FOV,
--         UCam.freeCamEnabled, UCam.camCFrame, UCam.currentVelocity,
--         UCam.character, UCam.humanoid, UCam.rootPart,
--         UCam.cameraYaw, UCam.cameraPitch, UCam.rightMouseHeld,
--         UCam.dutchRoll, UCam.currentFilterIndex,
--         UCam.BLOOM_EFFECT_NAME, UCam.DOF_EFFECT_NAME,
--         UCam.SUNRAYS_EFFECT_NAME, UCam.resolveDropdownValue
-- ============================================================
local UCam = _G.UCam
if not UCam then
    UCam = {}
    _G.UCam = UCam
end

-- ============================================================
-- SERVICIOS
-- ============================================================
UCam.UserInputService = game:GetService("UserInputService")
UCam.RunService       = game:GetService("RunService")
UCam.Players          = game:GetService("Players")
UCam.StarterGui       = game:GetService("StarterGui")
UCam.Lighting         = game:GetService("Lighting")
UCam.TweenService     = game:GetService("TweenService")

-- ============================================================
-- RAYFIELD (con fallback a dos mirrors)
-- ============================================================
local Rayfield
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}) do
    local ok, lib = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and lib then
        Rayfield = lib; break
    end
end
if not Rayfield then error("[Universal Camera] No se pudo cargar Rayfield.") end
UCam.Rayfield = Rayfield

-- ============================================================
-- NOTIFY (wrapper de Rayfield:Notify)
-- ============================================================
function UCam.notify(title, content, duration)
    Rayfield:Notify({
        Title    = title,
        Content  = content,
        Duration = duration or 3,
        Image    = 4483362458,
    })
end
-- alias local
local notify = UCam.notify

-- ============================================================
-- VARIABLES GLOBALES (jugador / camara)
-- ============================================================
UCam.player = UCam.Players.LocalPlayer
UCam.camera = workspace.CurrentCamera

-- ============================================================
-- CONSTANTES DE MOVIMIENTO
-- ============================================================
UCam.MOUSE_SENSITIVITY  = 0.35
UCam.SLIDER_MIN_SPEED   = 10
UCam.SLIDER_MAX_SPEED   = 300
UCam.currentSpeed       = 50
UCam.MOVEMENT_SMOOTHING = 8
UCam.SPRINT_MULTIPLIER  = 2.5
UCam.MIN_FOV            = 1
UCam.MAX_FOV            = 120
UCam.DEFAULT_FOV        = 70

-- ============================================================
-- ESTADO DE CAMARA LIBRE
-- ============================================================
UCam.freeCamEnabled  = false
UCam.camCFrame       = nil
UCam.currentVelocity = Vector3.new()

-- Referencias al personaje (se actualizan con refreshCharacterRefs en 10_utils)
UCam.character = UCam.player.Character
UCam.humanoid  = nil
UCam.rootPart  = nil

-- ============================================================
-- TABLAS DE ESTADO
-- ============================================================
UCam.Saved = {
    AutoRotate = true,
    RootAnchored = false,
    FOV = UCam.DEFAULT_FOV,
    RootCFrame = nil,
    Collide = {},
    _hudHiddenBeforeFreeCam = false, -- v6: marca si el HUD lo oculto el Auto-HUD
}

UCam.Hud = {
    Hidden = false,
    CharacterHidden = false,
    Transparencies = {},
}

-- v6: 14 modos de camara
UCam.camMode = "Libre"
UCam.CamModes = {
    "Libre",
    "Orbita",
    "Tripode",
    "Cenital",
    "Lateral",
    "Dron",
    "Follow",
    "CrashZoom",
    "Director",
    "Crane",        -- v3 (plano de grua: sube/baja + rota)
    "Dolly Glide",  -- v3 (carril cinematico lateral / forward)
    "Handheld",     -- v3 (camara en mano con micro-sacudidas)
    "Roll Axis",    -- v3 (roll sobre el eje forward, tipo barrel roll)
    "Vertigo",      -- NUEVO v6 (dolly zoom / efecto Hitchcock)
}

-- Parametros de rotacion libres
UCam.cameraYaw      = 0
UCam.cameraPitch    = 0
UCam.rightMouseHeld = false

-- Dutch angle (inclinacion cinematografica)
UCam.dutchRoll = 0

UCam.currentFilterIndex = 1

-- Orbit / modos orbitales
UCam.Orbit = {
    Angle       = 0,
    Distance    = 15,
    Height      = 5,
    Speed       = 0.5,
    ManualYaw   = 0,
    ManualPitch = 0,
}

-- Dron
UCam.DronePath = {
    Mode      = "Circulo",
    Modes     = { "Circulo", "Figura 8" },
    BobAmount = 1.5,
}

-- Lateral
UCam.Lateral = {
    Distance = 12,
    Height   = 4,
    Side     = 1,
}

-- Follow
UCam.Follow = {
    Distance   = 8,
    Height     = 4,
    SideOffset = 0,
}

-- Crash Zoom
UCam.CrashZoom = {
    EndFOV    = 35,
    StartFOV  = nil,
    Duration  = 1.4,
    Playing   = false,
    StartCF   = nil,
    StartedAt = 0,
}

-- Vertigo / Dolly Zoom (Hitchcock) — v6
UCam.Vertigo = {
    MinDistance = 6,
    MaxDistance = 36,
    Speed       = 0.6,
    BaseFOV     = 70,
    Phase       = 0,
}

-- Crane (grua / jib) — v3
UCam.Crane = {
    Height     = 8,
    MinHeight  = -2,
    MaxHeight  = 40,
    AutoSpin   = false,
    SpinSpeed  = 0.2,
    Angle      = 0,
    TiltPitch  = 0,
}

-- Dolly Glide — v3
UCam.Dolly = {
    Axis        = "Lateral",
    AxisOptions = { "Lateral", "Forward", "Diagonal" },
    Distance    = 30,
    AutoReverse = false,
    Phase       = 0,
    Center      = nil,
}

-- Handheld — v3
UCam.Handheld = {
    Enabled   = false,
    Intensity = 1.2,
    Frequency = 1.4,
    Roll      = 0.6,
}

-- Roll Axis — v3
UCam.RollAxis = {
    Speed       = 60,
    Direction   = 1,
    Auto        = false,
    Accumulated = 0,
}

-- Director: waypoints
UCam.Waypoint = {
    List     = {},
    Duration = 6,
    Loop     = false,
    Easing   = "Smooth",
    Easings  = { "Linear", "Smooth", "Sin" },
    UseFOV   = false,
    FOV      = 70,
}
UCam.Director = {
    Active       = false,
    StartTime    = 0,
    PlayStartCF  = nil,
    PlayStartFOV = nil,
}

-- Slow-mo (bullet time) v3
UCam.SlowMo = {
    BulletTime        = false,
    Intensity         = 50,
    Freeze            = false,
    AffectsLocal      = true,
    AffectsNPC        = true,
    AffectsOther      = true,
    AffectsPhysics    = true,
    Scope             = "Mundo",
    Scopes            = { "Mundo", "Personajes", "Jugadores", "Fisico" },
    Parts             = {},
    OriginalCF        = {},
    Humanoids         = {},
    DescendantConn    = nil,
    CharacterAdded    = nil,
    LastRebuild       = 0,
    RebuildInterval   = 2,
    RealPositions     = {},
    LastSetCFrame     = {},
    PrevRealPositions = {},
    MaxParts          = 400,
    ProcessingRadius  = 250,
    BatchSize         = 120,
    TickStep          = 1,
    TickAccum         = 0,
    BatchIndex        = 0,
    PartKeys          = {},
    TickRate          = 30,
    TickClock         = 0,
}

-- Nombres de efectos post-procesado
UCam.BLOOM_EFFECT_NAME   = "UCamBloom"
UCam.DOF_EFFECT_NAME     = "UCamDOF"
UCam.SUNRAYS_EFFECT_NAME = "UCamSunRays"

-- Letterbox (cinematic)
UCam.Letterbox = {
    Enabled     = false,
    HeightRatio = 0.10,
    Gui         = nil,
}

UCam.Bloom = {
    Enabled   = false,
    Intensity = 0.7,
    Size      = 30,
    Threshold = 2,
}

UCam.DOF = {
    Enabled       = false,
    FarIntensity  = 0.2,
    FocusDistance = 20,
    InFocusRadius = 10,
}

UCam.SunRays = {
    Enabled   = false,
    Intensity = 0.3,
    Spread    = 0.5,
}

-- Vignette (viñeta) — v3
UCam.Vignette = {
    Enabled    = false,
    Gui        = nil,
    Intensity  = 0.6,
    Color      = Color3.fromRGB(0, 0, 0),
    Smoothness = 0.35,
}

-- Camera Shake (con patrones) — v3
UCam.Shake = {
    Enabled   = false,
    Pattern   = "Sutil",
    Patterns  = { "Sutil", "Terremoto", "Explosion", "Pulso", "Impacto" },
    Intensity = 1,
    BaseCF    = nil,
}

-- FOV Pulse (respiracion) — v3
UCam.FovPulse = {
    Enabled   = false,
    Amplitude = 3,
    Speed     = 1.2,
}

-- Espectador
UCam.Spectate = {
    Active       = false,
    Target       = nil,
    Mode         = "Primera persona",
    Modes        = {
        "Primera persona", "Tercera persona", "Cinematico", "Sobre hombro",
        "Dron aereo", "Contrapicado", "Dolly lateral", "Orbita dinamica", "Steadicam",
    },
    Smoothing    = 12,
    Distance     = 10,
    Height       = 3,
    FOV          = 70,
    UseCustomFOV = false,
    HideSelf     = true,
    Yaw          = 0,
    Pitch        = 0,
}

-- Transicion suave entre modos de camara — v3.1
UCam.CameraTransition = {
    Active   = false,
    FromCF   = nil,
    Duration = 0.6,
    Elapsed  = 0,
}

-- Auto-Focus DOF — v3.1
UCam.AutoFocusDOF = {
    Enabled = false,
}

-- Auto-ciclo de espectadores — v3.1
UCam.AutoCycle = {
    Enabled  = false,
    Interval = 8,
    Elapsed  = 0,
}

-- Referencias a controles UI que otros modulos leen/escriben
UCam.UIRefs = {
    PlayerDropdown       = nil,
    FilterDropdown       = nil,
    CustomFilterDropdown = nil,
}

-- v6: Auto-ocultar HUD al entrar en camara libre
UCam.AutoHUD = {
    Enabled = false,
}

-- Forward declaration de triggerTransition (lo asigna 70_camcore)
UCam.triggerTransition = nil

-- ============================================================
-- MÓDULOS v4
-- ============================================================
UCam.LookAtLock = {
    Enabled      = false,
    Target       = nil,
    Smoothing    = 10,
    HeightOffset = 1.5,
}

UCam.GreenScreen = {
    Enabled         = false,
    Color           = Color3.fromRGB(0, 255, 0),
    Transparency    = 0,
    Size            = Vector3.new(60, 40, 60),
    Part            = nil,
    Position        = nil,
    Vertical        = "Detras",
    VerticalModes   = { "Detras", "Arriba", "Abajo", "Enfrente" },
    Distance        = 15,
    VerticalOffset  = 12,
    AvoidSpawns     = true,
    _spawnCache     = nil,
    _spawnCacheAt   = 0,
}

UCam.OriginalLighting = {
    ClockTime            = UCam.Lighting.ClockTime,
    ExposureCompensation = UCam.Lighting.ExposureCompensation,
    FogColor             = UCam.Lighting.FogColor,
    FogEnd               = UCam.Lighting.FogEnd,
    OutdoorAmbient       = UCam.Lighting.OutdoorAmbient,
    Ambient              = UCam.Lighting.Ambient,
    Brightness           = UCam.Lighting.Brightness,
}

UCam.LightingTweaks = {
    Enabled              = false,
    ClockTime            = 14,
    ExposureCompensation = 0,
    FogColor             = Color3.fromRGB(192, 192, 192),
    FogEnd               = 100000,
    OutdoorAmbient       = Color3.fromRGB(128, 128, 128),
    Ambient              = Color3.fromRGB(128, 128, 128),
    Brightness           = 2,
}

UCam.PathVisualizer = {
    Enabled      = false,
    VisualParts  = {},
}

-- ============================================================
-- MODULO FUN (Diversion) — v4.2
-- ============================================================
UCam.Fun = {
    Mount = {
        Enabled        = false,
        Target         = nil,
        Anchor         = "Cabeza",
        AnchorModes    = { "Cabeza", "Espalda", "Hombros" },
        HeightOffset   = 0.0,
        FollowRotation = true,
    },
    Noclip = {
        Enabled = false,
    },
    Gravity = {
        Enabled = false,
        Mode    = "Normal",
        Modes   = { "Normal", "Cero", "Luna", "Marte", "Reversa", "Pesada", "Custom" },
        Custom  = 50,
    },
    SuperJump = {
        Enabled = false,
        Power   = 100,
    },
    SpeedBoost = {
        Enabled   = false,
        WalkSpeed = 100,
    },
    Scale = {
        Enabled = false,
        Value   = 1.0,
    },
    BodySpin = {
        Enabled = false,
        Speed   = 180,
        Axis    = "Vertical",
        Axes    = { "Vertical", "Horizontal", "Diagonal" },
    },
    Pose = {
        Mode       = "Normal",
        Modes      = { "Normal", "T-Pose", "Sentado", "Flotando" },
        FloatForce = 0.3,
        DampXZ     = 0.92,
    },
    Rainbow = {
        Enabled = false,
        Speed   = 1.0,
    },
    NeonGlow = {
        Enabled = false,
        Color   = Color3.fromRGB(0, 255, 200),
    },
    Trail = {
        Enabled  = false,
        Width    = 1.0,
        Duration = 1.5,
        Color    = Color3.fromRGB(0, 200, 255),
        _parts   = {},
        _timer   = 0,
    },
    Disco = {
        Enabled = false,
        Size    = 14,
        Color   = Color3.fromRGB(255, 0, 200),
        Part    = nil,
    },
    Material = {
        Current = "Plastic",
        Options = { "Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField" },
    },
    Invisibility = {
        Enabled = false,
    },
    _savedWalkSpeed   = nil,
    _savedJumpPower   = nil,
    _savedAutoRotate  = nil,
    _currentScale     = 1.0,
    _origPartSizes    = {},
    _origBodyColors   = {},
    _origMaterials    = {},
    _origParts        = {},
    _origTransparency = {},
    _highlight        = nil,
    _connHeartbeat    = nil,
    _spinAngle        = 0,
    _rainbowTick      = 0,
    _tposeSetupDone   = false,
}

-- ============================================================
-- FILTROS DE COLOR (30 built-in)
-- ============================================================
UCam.Filters = {
    { Name = "Ninguno",          Brightness = 0,     Contrast = 0,     Saturation = 0,     TintColor = Color3.fromRGB(255, 255, 255) },
    { Name = "Cinematico",       Brightness = -0.02, Contrast = 0.15,  Saturation = -0.1,  TintColor = Color3.fromRGB(230, 230, 255) },
    { Name = "Vibrante",         Brightness = 0.03,  Contrast = 0.1,   Saturation = 0.35,  TintColor = Color3.fromRGB(255, 250, 240) },
    { Name = "Drama B/N",        Brightness = 0,     Contrast = 0.3,   Saturation = -1,    TintColor = Color3.fromRGB(255, 255, 255) },
    { Name = "Noir",             Brightness = -0.05, Contrast = 0.25,  Saturation = -0.6,  TintColor = Color3.fromRGB(210, 215, 230) },
    { Name = "Atardecer",        Brightness = 0.02,  Contrast = 0.08,  Saturation = 0.15,  TintColor = Color3.fromRGB(255, 200, 150) },
    { Name = "Cyberpunk",        Brightness = 0,     Contrast = 0.2,   Saturation = 0.2,   TintColor = Color3.fromRGB(180, 200, 255) },
    { Name = "Vintage",          Brightness = -0.03, Contrast = 0.05,  Saturation = -0.3,  TintColor = Color3.fromRGB(235, 210, 170) },
    { Name = "Terror",           Brightness = -0.08, Contrast = 0.35,  Saturation = -0.4,  TintColor = Color3.fromRGB(180, 255, 180) },
    { Name = "Teal & Orange",    Brightness = 0.02,  Contrast = 0.25,  Saturation = 0.05,  TintColor = Color3.fromRGB(255, 210, 160) },
    { Name = "Sepia",            Brightness = 0.04,  Contrast = 0.10,  Saturation = -0.7,  TintColor = Color3.fromRGB(255, 210, 150) },
    { Name = "Bleach Bypass",    Brightness = 0.05,  Contrast = 0.30,  Saturation = -0.55, TintColor = Color3.fromRGB(245, 245, 235) },
    { Name = "Polaroid",         Brightness = 0.05,  Contrast = 0.05,  Saturation = -0.2,  TintColor = Color3.fromRGB(255, 235, 200) },
    { Name = "Dream",            Brightness = 0.08,  Contrast = -0.05, Saturation = 0.45,  TintColor = Color3.fromRGB(255, 220, 255) },
    { Name = "Lomo",             Brightness = -0.04, Contrast = 0.30,  Saturation = 0.45,  TintColor = Color3.fromRGB(255, 200, 180) },
    { Name = "Vaporwave",        Brightness = 0.03,  Contrast = 0.15,  Saturation = 0.55,  TintColor = Color3.fromRGB(255, 180, 255) },
    { Name = "Matrix",           Brightness = -0.05, Contrast = 0.25,  Saturation = -0.4,  TintColor = Color3.fromRGB(180, 255, 180) },
    -- ====== NUEVOS v3 (13) ======
    { Name = "Anaglifo 3D",      Brightness = 0.02,  Contrast = 0.20,  Saturation = 0.10,  TintColor = Color3.fromRGB(255, 80, 80) },
    { Name = "Camara Seguridad", Brightness = -0.05, Contrast = 0.18,  Saturation = -0.55, TintColor = Color3.fromRGB(200, 220, 210) },
    { Name = "Instagram",        Brightness = 0.04,  Contrast = 0.12,  Saturation = 0.30,  TintColor = Color3.fromRGB(255, 225, 200) },
    { Name = "Caricatura",       Brightness = 0.06,  Contrast = 0.45,  Saturation = 0.65,  TintColor = Color3.fromRGB(255, 250, 235) },
    { Name = "Glitch",           Brightness = -0.02, Contrast = 0.40,  Saturation = -0.20, TintColor = Color3.fromRGB(190, 220, 255) },
    { Name = "Comic Book",       Brightness = 0.02,  Contrast = 0.55,  Saturation = 0.50,  TintColor = Color3.fromRGB(255, 235, 200) },
    { Name = "Synthwave",        Brightness = 0.04,  Contrast = 0.20,  Saturation = 0.50,  TintColor = Color3.fromRGB(255, 150, 220) },
    { Name = "Wes Anderson",     Brightness = 0.06,  Contrast = 0.15,  Saturation = 0.30,  TintColor = Color3.fromRGB(255, 200, 150) },
    { Name = "Film 35mm",        Brightness = 0.00,  Contrast = 0.10,  Saturation = -0.15, TintColor = Color3.fromRGB(255, 220, 180) },
    { Name = "HDR+",             Brightness = 0.05,  Contrast = 0.30,  Saturation = 0.40,  TintColor = Color3.fromRGB(255, 245, 225) },
    { Name = "VHS",              Brightness = -0.04, Contrast = 0.10,  Saturation = -0.35, TintColor = Color3.fromRGB(220, 180, 210) },
    { Name = "Noir Frances",     Brightness = -0.06, Contrast = 0.35,  Saturation = -1,    TintColor = Color3.fromRGB(210, 230, 220) },
    { Name = "Bypass Cyan",      Brightness = 0.04,  Contrast = 0.25,  Saturation = -0.50, TintColor = Color3.fromRGB(180, 240, 255) },
}

-- ============================================================
-- FILTROS CUSTOM (v3) + estado del editor en vivo
-- ============================================================
UCam.CustomFilters = {}
UCam.MAX_CUSTOM_FILTERS = 12
UCam.customEditing = {
    Brightness = 0,
    Contrast   = 0,
    Saturation = 0,
    R          = 255,
    G          = 255,
    B          = 255,
}
UCam.customFilterLiveApplied = false

-- ============================================================
-- PlayerModule controls (para disableControls / enableControls)
-- ============================================================
local controls = nil
pcall(function()
    local PlayerModule = require(UCam.player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    controls = PlayerModule:GetControls()
end)
UCam.controls = controls

-- ============================================================
-- DEFAULTS (para el boton "Restablecer todos los valores")
-- ============================================================
UCam.DEFAULTS = {
    currentSpeed         = 50,
    movementSmoothing    = 8,
    mouseSensitivity     = 0.35,
    sprintMultiplier     = 2.5,
    slowMoIntensity      = 50,
    camMode              = "Libre",
    filterIndex          = 1,
    orbitDistance        = 15,
    orbitHeight          = 5,
    orbitSpeed           = 0.5,
    defaultFov           = UCam.DEFAULT_FOV,
    dutchRoll            = 0,
    letterboxHeightRatio = 0.10,
    bloomIntensity       = 0.7,
    dofFocusDistance     = 20,
    sunraysIntensity     = 0.3,
    followDistance       = 8,
    followHeight         = 4,
    followSideOffset     = 0,
    lateralDistance      = 12,
    lateralHeight        = 4,
    crashZoomEndFOV      = 35,
    crashZoomDuration    = 1.4,
    waypointDuration     = 6,
    waypointEasing       = "Smooth",
    waypointFOV          = 70,
    craneHeight          = 8,
    craneSpinSpeed       = 0.2,
    dollyDistance        = 30,
    handheldIntensity    = 1.2,
    handheldFrequency    = 1.4,
    handheldRoll         = 0.6,
    rollAxisSpeed        = 60,
    vignetteIntensity    = 0.6,
    vignetteSmoothness   = 0.35,
    shakeIntensity       = 1,
    fovPulseAmplitude    = 3,
    fovPulseSpeed        = 1.2,
    vertigoMinDistance   = 6,
    vertigoMaxDistance   = 36,
    vertigoSpeed         = 0.6,
    vertigoBaseFOV       = 70,
}

-- ============================================================
-- HELPER: resuelve el valor de un dropdown de Rayfield.
-- Robusto contra las variantes {Option}, {{...}}, y strings.
-- (lo usa casi todo el codigo de UI)
-- ============================================================
function UCam.resolveDropdownValue(options)
    if type(options) == "string" then
        return options
    elseif type(options) == "table" then
        local v = options[1] or options.Option or options.Value
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" then return v end
        for _, val in pairs(options) do
            if type(val) == "string" and val ~= "" then return val end
        end
    end
    return nil
end

notify("Universal Camera Pro v6 By Cocoa Feliz",
    "Cargando partes modulares...")
