-- ============================================================
-- Universal Camera Pro v13 · lib/00_windui
-- Carga la libreria de UI WindUI (MIT, Footagesus) una sola vez.
--
-- v13: se vendoriza la version 1.6.66 dentro del repo (lib/windui.lua)
-- para que la UI no dependa de que "latest" exista o cambie. Los
-- fallbacks oficiales quedan solo por si el archivo local no llega.
--
-- Dependencias: core/00_config.lua (UCam.BASE / UCam.FALLBACK_BASE).
-- Expone: UCam.WindUI, UCam.WINDU_VERSION, UCam.UI_LIB_ERROR.
-- ============================================================
local UCam = _G.UCam

UCam.WINDU_VERSION = "1.6.66"

local OVERRIDES = {
    "https://github.com/Footagesus/WindUI/releases/download/" .. UCam.WINDU_VERSION .. "/main.lua",
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
}

local function buildSources()
    local list = {}
    if UCam.BASE then
        table.insert(list, UCam.BASE .. "lib/windui.lua")
    end
    if UCam.FALLBACK_BASE then
        table.insert(list, UCam.FALLBACK_BASE .. "lib/windui.lua")
    end
    for _, url in ipairs(OVERRIDES) do
        table.insert(list, url)
    end
    return list
end

local function loadOne(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(body) ~= "string" or #body < 1024 then
        return nil
    end
    local chunk, err = loadstring(body, "windui")
    if not chunk then
        return nil, err
    end
    local ran, lib = pcall(chunk)
    if not ran or type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        return nil, ran and "sin CreateWindow" or tostring(lib)
    end
    return lib
end

local lib, lastError
for _, url in ipairs(buildSources()) do
    lib, lastError = loadOne(url)
    if lib then break end
end

if lib then
    UCam.WindUI = lib
    -- La UI se construye con la fuente intermedia de Roblox: no heredamos
    -- lanzamientos del ejecutor que rompen los iconos Lucide.
    pcall(function() lib.Language = lib.Language or "en" end)
else
    UCam.WindUI = nil
    UCam.UI_LIB_ERROR = tostring(lastError or "desconocido")
    warn("[UCam] WindUI no se pudo cargar: " .. UCam.UI_LIB_ERROR)
end
