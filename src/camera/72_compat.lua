-- ============================================================
-- Universal Camera Pro v13.5 · camera/72_compat
-- Compatibilidad con juegos que ya controlan la camara por su cuenta.
--
--   1) FILTROS RESPAWN-SAFE
--      El script de camara de un juego suele limpiar Lighting al
--      spawnear (destruye ColorCorrectionEffect y apaga BlurEffect).
--      Aqui se vuelve a crear el efecto propio y a aplicar el look
--      activo despues de ese barrido.
--
--   2) FOV HANDSHAKE
--      Cuando UCam no manda, el FOV que escribe el juego se adopta
--      como base (Saved.FOV y DEFAULT_FOV) en vez de clavar los 70
--      por defecto. Asi "Restablecer FOV" y el respawn coinciden con
--      el encuadre real del juego.
--
--   3) ARBITRAJE DE CAMARA (SIN AVISOS AUTOMATICOS)
--      El script de camara del juego (StarterCharacterScripts.cam) pone
--      CameraType = Scriptable en CADA frame y escribe su CFrame antes
--      que nosotros. Contar eso como conflicto hacia saltar un aviso
--      cada 8 s mientras se usaba la camara libre, aunque no hubiera
--      nada roto: v13.6 elimina ese aviso. UCamRender/UCamEnforce
--      (70_camcore) corren en RenderPriority.Camera + 1 y Last, asi que
--      el encuadre de UCam siempre queda al final. El estado se puede
--      consultar a mano en Ajustes → Ver estado de compatibilidad.
--
-- Dependencias: core/00_config, core/10_utils, visuals/20_filters,
--               camera/70_camcore
-- Expone (UCam.Compat.*):
--   Enabled, AutoYield, UseRemote, ServerFOV, GameDriving,
--   reapplyLook, adoptServerFOV, handoffToGame, noteExternalWrite,
--   getStatus, findGameCameraScript
-- ============================================================
local UCam = _G.UCam
if not UCam then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Compat = UCam.Compat or {}
UCam.Compat = Compat

-- Sonido de estado: no se persiste (es de sesion). Si el juego se
-- porta bien, no hay nada que guardar.
Compat.Enabled     = true   -- reaplicar look tras el barrido del juego
Compat.AutoYield   = false  -- obsoleto desde v13.6: ya no hay aviso automatico
Compat.UseRemote   = false  -- leer el FOV por Remotes.DataUpdate (puede
                            -- disparar el anticheat: por defecto solo se
                            -- observa el FOV que escribe el juego)
Compat.ServerFOV   = nil
Compat.GameDriving = false
Compat.Detected    = nil

Compat._selfFovAt   = 0   -- ultima escritura de FOV hecha por UCam
Compat._hits        = 0   -- escrituras externas observadas (solo estado)

local REAPPLY_DELAYS   = { 0.25, 1.2 }
local SELF_FOV_GRACE   = 0.25

-- Rutas conocidas de scripts de camara de juegos que ya manejan su
-- propia camara. En partida Script.Source no es legible, asi que la
-- deteccion se hace por estructura y no por contenido.
local GAME_CAMERA_PATHS = {
    { "StarterPlayer", "StarterCharacterScripts", "cam" },
    { "ReplicatedStorage", "ClientAssets", "Characters", "Common", "cam" },
}

local EFFECT_NAMES = {}
if UCam.BLOOM_EFFECT_NAME then EFFECT_NAMES[UCam.BLOOM_EFFECT_NAME] = true end
if UCam.DOF_EFFECT_NAME then EFFECT_NAMES[UCam.DOF_EFFECT_NAME] = true end
if UCam.SUNRAYS_EFFECT_NAME then EFFECT_NAMES[UCam.SUNRAYS_EFFECT_NAME] = true end
EFFECT_NAMES["FreeCam_Filter"] = true

local function isControlling()
    return UCam.freeCamEnabled
        or (UCam.Spectate and UCam.Spectate.Active)
        or (UCam.Director and UCam.Director.Active)
end

-- ============================================================
-- UTILIDAD: quien escribe la camara ahora mismo
-- ============================================================
-- Devuelve el primer LocalScript/ModuleScript sospechoso de manejar la
-- camara, con su ruta. Sirve para el informe de estado, no para tocarlo.
local function findByPath(path)
    local node = game
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
        if not node then return nil end
    end
    return node
end

function Compat.findGameCameraScript()
    -- 1) Rutas conocidas: funciona en partida, sin leer Source.
    for _, path in ipairs(GAME_CAMERA_PATHS) do
        local found = findByPath(path)
        if found and found:IsA("LuaSourceContainer") then
            return found:GetFullName()
        end
    end

    -- 2) En Studio/plugins se puede leer Source: ultimo recurso para
    -- juegos con otra estructura.
    local starterPlayer = game:FindFirstChild("StarterPlayer")
    local characterScripts = starterPlayer
        and starterPlayer:FindFirstChild("StarterCharacterScripts")
    if not characterScripts then return nil end
    for _, child in ipairs(characterScripts:GetChildren()) do
        if child:IsA("LuaSourceContainer") then
            local ok, source = pcall(function()
                return child.Source
            end)
            if ok and type(source) == "string"
                and (source:find("CameraType", 1, true) or source:find("CurrentCamera", 1, true)) then
                return child:GetFullName()
            end
        end
    end
    return nil
end

-- ============================================================
-- 1) FILTROS RESPAWN-SAFE
-- ============================================================
-- Reaplica el look activo: recrea el ColorCorrection propio, el bloom,
-- el DOF y los sun rays, y vuelve a empujar el filtro seleccionado.
-- Todo con pcall: si algun efecto no existe en esta version del script,
-- la reaplicacion sigue con el resto.
function Compat.reapplyLook()
    if not Compat.Enabled then return end
    if not UCam.camera then return end

    Compat._selfFovAt = os.clock()

    pcall(function()
        if UCam.setupColorEffect then UCam.setupColorEffect() end
        if UCam.applyBloom then UCam.applyBloom() end
        if UCam.applyDOF then UCam.applyDOF() end
        if UCam.applySunRays then UCam.applySunRays() end

        if UCam.customFilterLiveApplied and UCam.applyCustomEditingLive then
            UCam.applyCustomEditingLive()
        elseif UCam.applyFilter then
            UCam.applyFilter(UCam.currentFilterIndex or 1, true)
        end
    end)

    -- El FOV solo se restaura si el usuario lo habia separado de la base
    -- del juego; si no, manda el valor del juego (FOV handshake).
    if not isControlling() and UCam.Saved then
        local savedFov = tonumber(UCam.Saved.FOV)
        local baseFov = tonumber(Compat.ServerFOV or UCam.DEFAULT_FOV)
        if savedFov and baseFov and math.abs(savedFov - baseFov) > 0.5 then
            pcall(function()
                UCam.camera.FieldOfView = UCam.clamp(savedFov, UCam.MIN_FOV, UCam.MAX_FOV)
            end)
        end
    end
    return true
end

-- El barrido del juego ocurre en el frame del spawn y a veces algo mas
-- tarde (cuando carga el personaje). Dos intentos cubren ambos casos.
local function scheduleReapply()
    for _, delay in ipairs(REAPPLY_DELAYS) do
        task.delay(delay, function()
            if UCam.Compat and UCam.Compat.reapplyLook then
                pcall(UCam.Compat.reapplyLook)
            end
        end)
    end
end

-- ============================================================
-- 2) FOV HANDSHAKE
-- ============================================================
function Compat.adoptServerFOV(value, source)
    value = tonumber(value)
    if not value or value < 5 or value > 120 then return end
    if Compat.ServerFOV == value then return end

    Compat.ServerFOV = value
    UCam.Saved = UCam.Saved or {}
    UCam.Saved.ServerFOV = value
    UCam.DEFAULT_FOV = value

    -- No se pisa el encuadre mientras el usuario manda la camara.
    if not isControlling() then
        UCam.Saved.FOV = value
    end

    Compat.Detected = Compat.Detected or {
        source = source or "observation",
        at = os.clock(),
    }
    return value
end

-- Lectura por RemoteFunction, desactivada por defecto: es la misma
-- llamada que hace el script del juego, pero disparar remotes desde un
-- executor puede levantar sospechas del anticheat.
function Compat.readServerFOV()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataUpdate = remotes and remotes:FindFirstChild("DataUpdate")
    if not dataUpdate or not dataUpdate:IsA("RemoteFunction") then return nil end

    local ok, result = pcall(function()
        return dataUpdate:InvokeServer("FetchData", { "setting" })
    end)
    if ok and type(result) == "table" and tonumber(result.FieldOfView) then
        return Compat.adoptServerFOV(result.FieldOfView, "DataUpdate")
    end
    return nil
end

-- ============================================================
-- 3) ARBITRAJE DE CAMARA
-- ============================================================
--- Registra que el juego toco la camara. NO avisa: en juegos como este
-- la camara propia escribe CameraType cada frame y el aviso se repetia
-- sin que nada estuviera roto. Solo alimenta el informe de estado.
function Compat.noteExternalWrite(reason)
    if not Compat.Enabled then return end

    Compat._hits = (Compat._hits or 0) + 1
    Compat.GameDriving = true
    Compat.Detected = Compat.Detected or { source = "game", reason = reason, at = os.clock() }
end

-- Devuelve el control al juego sin dejar la camara en un estado raro:
-- mismo camino que Unload (forceRestoreCamera) y FOV base del juego.
function Compat.handoffToGame(silent)
    if UCam.freeCamEnabled and UCam.forceRestoreCamera then
        pcall(UCam.forceRestoreCamera)
    end
    if UCam.Spectate and UCam.Spectate.Active and UCam.stopSpectate then
        pcall(UCam.stopSpectate)
    end
    if UCam.Director and UCam.Director.Active and UCam.directorTogglePlay then
        pcall(UCam.directorTogglePlay, false)
    end

    pcall(function()
        UCam.camera.CameraType = Enum.CameraType.Custom
        if UCam.humanoid then UCam.camera.CameraSubject = UCam.humanoid end
        if Compat.ServerFOV then
            UCam.camera.FieldOfView = UCam.clamp(Compat.ServerFOV, UCam.MIN_FOV, UCam.MAX_FOV)
        end
    end)

    Compat.GameDriving = true
    if not silent and UCam.notify then
        UCam.notify("Compatibilidad", "Control devuelto al juego. Activa la camara libre para recuperarlo.")
    end
    return true
end

function Compat.getStatus()
    return {
        enabled    = Compat.Enabled,
        autoYield  = Compat.AutoYield,
        useRemote  = Compat.UseRemote,
        serverFov  = Compat.ServerFOV,
        gameDriving = Compat.GameDriving,
        detected   = Compat.Detected,
        gameCamera = Compat.findGameCameraScript(),
    }
end

-- ============================================================
-- CONEXIONES (trackeadas para que Unload las suelte)
-- ============================================================
local function track(connection, tag)
    if UCam.trackConnection then
        return UCam.trackConnection(connection, tag)
    end
    return connection
end

-- Escrituras propias de FOV: se marcan para no confundirlas con las
-- del juego. Se envuelve la unica via oficial de cambio (v12.9).
local _origSetCameraFOV = UCam.setCameraFOV
if type(_origSetCameraFOV) == "function" and not Compat._fovWrapped then
    Compat._fovWrapped = true
    UCam.setCameraFOV = function(fov, instant)
        Compat._selfFovAt = os.clock()
        return _origSetCameraFOV(fov, instant)
    end
end

if UCam.camera then
    track(UCam.camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
        if not Compat.Enabled then return end
        if os.clock() - (Compat._selfFovAt or 0) < SELF_FOV_GRACE then return end

        -- Mientras UCam manda, el FOV es suyo: zoom con rueda, FOV Pulse,
        -- crash zoom y demas modos lo escriben cada frame. Eso no es un
        -- conflicto del juego, y contarlo hacia que el aviso saltara cada
        -- 8 s mientras se usaba la camara libre. Solo se adopta el FOV
        -- cuando el juego tiene el control.
        if isControlling() then return end
        Compat.adoptServerFOV(UCam.camera.FieldOfView, "observation")
    end), "Compat:FOV")

    track(UCam.camera:GetPropertyChangedSignal("CameraType"):Connect(function()
        if not Compat.Enabled then return end
        -- Sin UCam al mando, que el juego ponga Scriptable es lo normal:
        -- solo se anota para el informe de estado, sin notificar.
        if not isControlling() and UCam.camera.CameraType == Enum.CameraType.Scriptable then
            Compat.noteExternalWrite("CameraType")
        end
    end), "Compat:CameraType")
end

track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Compat._selfFovAt = 0
    scheduleReapply()
end), "Compat:CurrentCamera")

track(UCam.Lighting.ChildRemoved:Connect(function(child)
    if EFFECT_NAMES[child.Name] then
        task.defer(function()
            if UCam.Compat and UCam.Compat.reapplyLook then
                pcall(UCam.Compat.reapplyLook)
            end
        end)
    end
end), "Compat:LightingRemoved")

if UCam.player then
    track(UCam.player.CharacterAdded:Connect(scheduleReapply), "Compat:CharacterAdded")
end

-- Arranque: adoptar el FOV que el juego ya tiene puesto y reaplicar el
-- look una vez, por si el script de camara corrio antes que nosotros.
task.defer(function()
    if UCam.camera then
        local fov = UCam.camera.FieldOfView
        if fov and fov >= 5 then
            Compat.adoptServerFOV(fov, "startup")
        end
    end
    if Compat.UseRemote then
        pcall(Compat.readServerFOV)
    end
    scheduleReapply()
end)
