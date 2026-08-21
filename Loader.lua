-- ============================================================
-- Universal Camera PRO v10 · Loader
-- By Cocoa Feliz · v10 release
--
-- ESTE es el unico script que pegas en el juego.
-- Descarga cada parte desde GitHub raw y la ejecuta inyectando el
-- namespace compartido UCam (tabla global + upvalue).
--
-- v8:
--  - Auto-unload: si _G.UCam ya existe de una ejecucion previa,
--    llama UCam.Unload() antes de recargar (evita handlers duplicados).
--  - Retry con backoff exponencial (3 intentos por parte).
--  - Descarga paralela de todas las partes (task.spawn) y ejecucion
--    en orden — mucho mas rapido en conexiones lentas.
--  - Versionado: pin a un tag con VERSION para produccion.
-- ============================================================

-- ============================================================
-- CONFIG: repo de GitHub para cargar las partes modularizadas
-- ============================================================
local VERSION = "v11.0.2"  -- v11.02: sidebar Lucide y UI completamente oculta

local BASE = ("https://raw.githubusercontent.com/Brightside349/UniversalCamera/%s/src/"):format(VERSION)

-- (Opcional) mirror de jsdelivr como fallback si GitHub esta caido
local FALLBACK_BASE = ("https://cdn.jsdelivr.net/gh/Brightside349/UniversalCamera@%s/src/"):format(VERSION)

-- Reintentos por parte (con backoff exponencial: 0.5s, 1s, 2s)
local MAX_RETRIES = 3

-- ============================================================
-- v8: AUTO-UNLOAD de instancia previa
-- Si _G.UCam existe y tiene Unload(), lo llamamos para desconectar
-- handlers/instancias del script anterior antes de recargar.
-- ============================================================
if _G.UCam then
    if type(_G.UCam.Unload) == "function" then
        local ok, err = pcall(_G.UCam.Unload)
        if ok then
            print("[UCam] Instancia previa descargada correctamente. Recargando...")
        else
            warn(("[UCam] Unload previo fallo: %s (continuando de todas formas)"):format(tostring(err)))
        end
    else
        warn("[UCam] Instancia previa sin Unload() — puede haber handlers duplicados.")
    end
end

-- ============================================================
-- Namespace compartido entre TODAS las partes
-- ============================================================
local UCam = {}
_G.UCam = UCam

-- ============================================================
-- Orden estricto de carga.
-- Cada parte solo puede usar UCam.* de las anteriores.
-- ============================================================
local ORDER = {
    "00_ui_provider.lua", -- v11: WindUI + fallback Rayfield + compatibilidad
    -- 0. Config + estado + servicios + Rayfield
    "00_config.lua",
    -- 0.5 v8: Persistencia (write/read config JSON, export/import)
    "05_persistence.lua",
    -- 0.6 v8: i18n multi-idioma (es/en/pt, UCam.T)
    "06_i18n.lua",
    -- 1. Utilidades de camara, personaje, path visualizer, croma
    "10_utils.lua",
    -- 2. Filtros built-in/custom, bloom, DOF, sunrays, vignette, letterbox
    "20_filters.lua",
    -- 3. Modulo Fun (montar, noclip, escala, poses, trail, disco, etc.)
    "30_fun.lua",
    -- 3.1 v7: Coloreo de cuerpo por partes + presets + arcoíris
    "32_bodycolor.lua",
    -- 3.2 v7: Poses avanzadas (Motor6D) — base para playermod
    "33_poses.lua",
    -- 3.3 v7: Hub de modificación de otros jugadores (depende de 32/33)
    "35_playermod.lua",
    -- 5. Espectador (9 modos + navegacion Q/E)
    "50_spectate.lua",
    -- 6. Director (waypoints + reproduccion)
    "60_director.lua",
    -- 7. Nucleo de camara (toggleFreeCam, CrashZoom, Shake, updateCamera, input)
    "70_camcore.lua",
    -- 7.1 v8.1: Replay REMASTERIZADO — grabación de cámara libre sin waypoints
    "55_replay.lua",
    -- 7.2 v8: Perfiles completos (depende de 05_persistence)
    "57_profiles.lua",
    -- 8. Orquestador de la UI (solo arma la Window y delega)
    "80_ui.lua",
    -- 8.5 v8: Monitor de performance (opcional, debug)
    "85_performance.lua",
    -- 8.6 v8 FIX: Plugins ANTES de la UI — así sus tabs se construyen en
    -- buildUI() via _dynamicTabBuilders (antes se cargaban después de 90_init
    -- y sus pestañas nunca aparecían). Necesita registerTabBuilder (80_ui).
    "85_plugins.lua",
    "88_v9extras.lua",
    -- v10: integraciones locales (capture, guias, recovery, escenas)
    "89_v10extras.lua",
    -- 9. Sub-builders de cada pestana (registran UCam.build_xxx)
    "ui/inicio.lua",
    "ui/camaras.lua",
    "ui/espectador.lua",
    "ui/cinematic.lua",
    "ui/filters.lua",
    "ui/light.lua",
    "ui/estudio.lua",
    "ui/gimbal.lua",
    "ui/fun.lua",
    "ui/bodycolor.lua",    -- v7: pestaña 🎨 Cuerpo (colores por partes)
    "ui/poses.lua",        -- v7: pestaña 🧍 Poses
    "ui/playermod.lua",    -- v7: pestaña 👥 Mod Jugadores
    "ui/replay.lua",       -- v8.1: pestaña 🎬 Replay (REMASTERIZADO)
    "ui/profiles.lua",     -- v8: pestaña 📁 Perfiles
    "ui/config.lua",
    "ui/creator.lua",      -- v10: acciones rapidas para creadores
    "ui/info.lua",
    -- 10. Init: llama a buildUI() y notifica "Listo"
    "90_init.lua",
}

-- ============================================================
-- v8: DESCARGA PARALELA
-- Todas las partes se descargan a la vez (task.spawn) y se guardan
-- en sources[name]. La ejecucion sigue siendo secuencial y en orden.
-- ============================================================
local sources = {}   -- [name] = source string (o nil si fallo)
local pending = #ORDER
local downloadDone = Instance.new("BindableEvent")

local function fetchPart(name)
    local urls = { BASE .. name, FALLBACK_BASE .. name }
    for attempt = 1, MAX_RETRIES do
        for _, url in ipairs(urls) do
            local ok, body = pcall(function() return game:HttpGet(url) end)
            if ok and type(body) == "string" and #body > 0 then
                sources[name] = body
                pending = pending - 1
                if pending <= 0 then downloadDone:Fire() end
                return
            end
        end
        -- Backoff exponencial entre reintentos: 0.5s, 1s, 2s
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

-- ============================================================
-- EJECUCION EN ORDEN
-- ============================================================
local loaded     = 0
local failed     = 0
local failedList = {}

local function execPart(name)
    local src = sources[name]
    if not src then
        return false
    end

    local fn, err = loadstring(src, name)
    if not fn then
        warn(("[UCam] Error de sintaxis en %s: %s"):format(name, tostring(err)))
        return false
    end

    -- setfenv(getfenv()): hereda el entorno actual (servicios de Roblox)
    -- y deja UCam accesible porque vive en _G y como upvalue via la captura
    -- que cada parte hace al inicio con `local UCam = _G.UCam`.
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

for _, part in ipairs(ORDER) do
    if execPart(part) then
        loaded = loaded + 1
        failed = 0
    else
        failed = failed + 1
        table.insert(failedList, part)
        if failed >= 2 then
            warn("[UCam] Demasiados fallos seguidos, abortando carga.")
            break
        end
    end
end

-- Liberar memoria de las fuentes una vez ejecutadas
table.clear(sources)

if #failedList == 0 then
    print(("[UCam] Universal Camera Pro v10 cargado OK (%d partes)."):format(loaded))
else
    warn(("[UCam] Carga completada con %d errores. Fallaron: %s"):format(
        #failedList, table.concat(failedList, ", ")
    ))
end
