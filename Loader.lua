-- ============================================================
-- Universal Camera PRO · Loader
-- By Cocoa Feliz · v6 modular
--
-- ESTE es el unico script que pegas en el juego.
-- Descarga cada parte desde GitHub raw y la ejecuta inyectando el
-- namespace compartido UCam (tabla global + upvalue).
-- ============================================================

-- ============================================================
-- CONFIG: repo de GitHub para cargar las partes modularizadas
-- ============================================================
local BASE = "https://raw.githubusercontent.com/Brightside349/UniversalCamera/main/src/"

-- (Opcional) mirror de jsdelivr como fallback si GitHub esta caido
local FALLBACK_BASE = "https://cdn.jsdelivr.net/gh/Brightside349/UniversalCamera@main/src/"

-- ============================================================
-- Namespace compartido entre TODAS las partes
-- ============================================================
local UCam = {}
_G.UCam = UCam

-- ============================================================
-- Cache opcional: si esta parte ya se descargo en esta sesion,
-- la re-ejecuta desde cache (ahorra HTTP en el mismo script).
-- ============================================================
local cache = {}

-- ============================================================
-- Carga una parte desde GitHub (o fallback) y la ejecuta.
-- Devuelve true si se cargo OK, false si fallo.
-- ============================================================
local function loadPart(name)
    local sources = { BASE .. name, FALLBACK_BASE .. name }

    local src
    for _, url in ipairs(sources) do
        if cache[url] then
            src = cache[url]
            break
        end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and body ~= "" then
            src = body
            cache[url] = body
            break
        end
    end

    if not src then
        warn(("[UCam] No se pudo descargar %s de ninguna URL."):format(name))
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

-- ============================================================
-- Orden estricto de carga.
-- Cada parte solo puede usar UCam.* de las anteriores.
-- ============================================================
local ORDER = {
    -- 0. Config + estado + servicios + Rayfield
    "00_config.lua",
    -- 1. Utilidades de camara, personaje, path visualizer, croma
    "10_utils.lua",
    -- 2. Filtros built-in/custom, bloom, DOF, sunrays, vignette, letterbox
    "20_filters.lua",
    -- 3. Modulo Fun (montar, noclip, escala, poses, trail, disco, etc.)
    "30_fun.lua",
    -- 4. Bullet Time universal
    "40_slowmo.lua",
    -- 5. Espectador (9 modos + navegacion Q/E)
    "50_spectate.lua",
    -- 6. Director (waypoints + reproduccion)
    "60_director.lua",
    -- 7. Nucleo de camara (toggleFreeCam, CrashZoom, Shake, updateCamera, input)
    "70_camcore.lua",
    -- 8. Orquestador de la UI (solo arma la Window y delega)
    "80_ui.lua",
    -- 9. Sub-builders de cada pestana (registran UCam.build_xxx)
    "ui/inicio.lua",
    "ui/camaras.lua",
    "ui/espectador.lua",
    "ui/slowmo.lua",
    "ui/cinematic.lua",
    "ui/filters.lua",
    "ui/light.lua",
    "ui/estudio.lua",
    "ui/gimbal.lua",
    "ui/fun.lua",
    "ui/config.lua",
    "ui/info.lua",
    -- 10. Init: llama a buildUI() y notifica "Listo"
    "90_init.lua",
}

-- ============================================================
-- Carga. Si fallan 2 seguidas, aborta.
-- ============================================================
local failed    = 0
local loaded    = 0
local failedList = {}

for _, part in ipairs(ORDER) do
    if loadPart(part) then
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

if #failedList == 0 then
    print(("[UCam] Universal Camera Pro v6 cargado OK (%d partes)."):format(loaded))
else
    warn(("[UCam] Carga completada con %d errores. Fallaron: %s"):format(
        #failedList, table.concat(failedList, ", ")
    ))
end
