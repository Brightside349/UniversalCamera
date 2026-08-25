-- ============================================================
-- Universal Camera PRO v10.5 · Loader
-- El unico script que se pega en el juego.
-- Descarga las partes desde GitHub raw y las ejecuta en orden.
-- ============================================================

local VERSION = "v10.5"
local BASE = ("https://raw.githubusercontent.com/Brightside349/UniversalCamera/%s/src/"):format(VERSION)
local FALLBACK_BASE = ("https://cdn.jsdelivr.net/gh/Brightside349/UniversalCamera@%s/src/"):format(VERSION)
local MAX_RETRIES = 3

if _G.UCam and type(_G.UCam.Unload) == "function" then
    local ok, err = pcall(_G.UCam.Unload)
    if ok then
        print("[UCam] Instancia previa descargada correctamente. Recargando...")
    else
        warn(("[UCam] Unload previo fallo: %s"):format(tostring(err)))
    end
end

local UCam = {}
_G.UCam = UCam

-- El orden es explicito: las carpetas organizan el dominio, pero no
-- sustituyen las dependencias de ejecucion de Luau.
local ORDER = {
    "core/00_config.lua",
    "core/05_persistence.lua",
    "core/06_i18n.lua",
    "core/10_utils.lua",
    "visuals/20_filters.lua",
    "actors/30_fun.lua",
    "actors/32_bodycolor.lua",
    "actors/33_poses.lua",
    "actors/35_playermod.lua",
    "camera/50_spectate.lua",
    "camera/60_director.lua",
    "camera/70_camcore.lua",
    "camera/55_replay.lua",
    "presets/57_profiles.lua",
    "ui/00_registry.lua",
    "runtime/85_performance.lua",
    "extensions/85_plugins.lua",
    "runtime/88_v9extras.lua",
    "runtime/89_v10extras.lua",
    "ui/tabs/inicio.lua",
    "ui/tabs/camaras.lua",
    "ui/tabs/espectador.lua",
    "ui/tabs/cinematic.lua",
    "ui/tabs/filters.lua",
    "ui/tabs/light.lua",
    "ui/tabs/estudio.lua",
    "ui/tabs/gimbal.lua",
    "ui/tabs/fun.lua",
    "ui/tabs/bodycolor.lua",
    "ui/tabs/poses.lua",
    "ui/tabs/playermod.lua",
    "ui/tabs/replay.lua",
    "ui/tabs/profiles.lua",
    "ui/tabs/config.lua",
    "ui/tabs/creator.lua",
    "ui/tabs/info.lua",
    "ui/90_builder.lua",
    "core/90_init.lua",
}

local sources = {}
local pending = #ORDER
local downloadDone = Instance.new("BindableEvent")

local function fetchPart(name)
    local urls = { BASE .. name, FALLBACK_BASE .. name }
    for attempt = 1, MAX_RETRIES do
        for _, url in ipairs(urls) do
            local ok, body = pcall(function()
                return game:HttpGet(url)
            end)
            if ok and type(body) == "string" and #body > 0 then
                sources[name] = body
                pending = pending - 1
                if pending <= 0 then downloadDone:Fire() end
                return
            end
        end
        if attempt < MAX_RETRIES then
            task.wait(0.5 * (2 ^ (attempt - 1)))
        end
    end
    warn(("[UCam] No se pudo descargar %s tras %d intentos."):format(name, MAX_RETRIES))
    pending = pending - 1
    if pending <= 0 then downloadDone:Fire() end
end

for _, part in ipairs(ORDER) do
    task.spawn(fetchPart, part)
end
downloadDone.Event:Wait()
downloadDone:Destroy()

local loaded = 0
local failedList = {}

local function execPart(name)
    local source = sources[name]
    if not source then return false end

    local fn, compileErr = loadstring(source, name)
    if not fn then
        warn(("[UCam] Error de sintaxis en %s: %s"):format(name, tostring(compileErr)))
        return false
    end

    local ok, runErr = pcall(function()
        setfenv(fn, getfenv())
        fn()
    end)
    if not ok then
        warn(("[UCam] Error ejecutando %s: %s"):format(name, tostring(runErr)))
        return false
    end
    return true
end

local consecutiveFailures = 0
for _, part in ipairs(ORDER) do
    if execPart(part) then
        loaded = loaded + 1
        consecutiveFailures = 0
    else
        consecutiveFailures = consecutiveFailures + 1
        table.insert(failedList, part)
        if consecutiveFailures >= 2 then
            warn("[UCam] Demasiados fallos seguidos, abortando carga.")
            break
        end
    end
end

table.clear(sources)

if #failedList == 0 then
    print(("[UCam] Universal Camera Pro v10.5 cargado OK (%d partes)."):format(loaded))
else
    warn(("[UCam] Carga completada con %d errores. Fallaron: %s"):format(
        #failedList,
        table.concat(failedList, ", ")
    ))
end
