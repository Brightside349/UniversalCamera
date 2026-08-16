-- ============================================================
-- Universal Camera Pro v8 · 85_plugins
-- Sistema de plugins real con metadata, DiscoveryEvent API y
-- carga automática desde la carpeta UniversalCamera/plugins/.
--
-- Un plugin es un archivo .lua que devuelve una tabla:
--   return {
--       name    = "Mi Plugin",
--       author  = "Su autor",
--       version = "1.0",
--       icon    = 4483362458,        -- opcional (para CreateTab)
--       build   = function(Window)   -- registra tabs/UI
--           ...
--       end,
--       start   = function(UCam) end,-- opcional, tras buildUI()
--       stop    = function(UCam) end,-- opcional, se llama en Unload
--   }
--
-- Dependencias: 00_config, 10_utils, 80_ui (registerTabBuilder)
-- Expone (UCam.*):
--   Plugins (lista), loadPluginsFromFolder, registerPlugin,
--   stopAllPlugins, loadDefaultPlugins
-- ============================================================
local UCam = _G.UCam

UCam.Plugins = { Loaded = {}, Disabled = {} }

local HAS_FS = UCam.HasFileSystem

-- ============================================================
-- HELPERS de sistema de archivos para plugins
-- ============================================================
local function getPluginsFolder()
    return "UniversalCamera/plugins"
end

local function ensurePluginsFolder()
    if not HAS_FS then return false end
    local ok = pcall(function()
        makefolder("UniversalCamera")
        makefolder(getPluginsFolder())
    end)
    return ok
end

-- ============================================================
-- VALIDAR un plugin contra su spec
-- ============================================================
local function validatePlugin(spec)
    if type(spec) ~= "table" then return false, "plugin no devuelve tabla" end
    if type(spec.build) ~= "function" and type(spec.start) ~= "function" then
        return false, "falta build() o start()"
    end
    if spec.name and type(spec.name) ~= "string" then return false, "name inválido" end
    return true
end

-- ============================================================
-- REGISTRAR UN PLUGIN (carga el .lua ya parseado)
-- ============================================================
function UCam.registerPlugin(spec, filename)
    local ok, err = validatePlugin(spec)
    if not ok then
        warn(("[UCam] Plugin inválido (%s): %s"):format(filename or "?", tostring(err)))
        return false
    end

    local name = spec.name or (filename or "plugin"):gsub("%.lua$", "")

    -- wrapper de build para respetar stop/start
    local function buildWrapper(Window)
        if type(spec.build) == "function" then
            local ok, bErr = pcall(spec.build, Window)
            if not ok then
                warn(("[UCam] Plugin '%s' build falló: %s"):format(name, tostring(bErr)))
            end
        end
    end

    local registeredName = "plugin_" .. name:gsub("%s", "_"):lower()
    UCam.registerTabBuilder(registeredName, buildWrapper)

    local entry = {
        name      = name,
        author    = spec.author  or "?",
        version   = spec.version or "1.0",
        icon      = spec.icon    or 4483362458,
        filename  = filename,
        stopFn    = spec.stop,
        startFn   = spec.start,
        registeredName = registeredName,
    }
    UCam.Plugins.Loaded[name] = entry

    -- start post-build (si está inicializado ya)
    if UCam.Initialized and entry.startFn then
        task.defer(function()
            pcall(entry.startFn, UCam)
        end)
    end

    print(("[UCam] Plugin '%s' v%s by %s registrado."):format(name, entry.version, entry.author))
    return true
end

-- ============================================================
-- CARGAR PLUGINS DESDE ARCHIVO
-- ============================================================
local function loadPluginFile(path)
    local okSrc, src = pcall(readfile, path)
    if not okSrc or not src then
        warn(("[UCam] Plugin: no se pudo leer %s"):format(path))
        return false
    end

    local fn, loadErr = loadstring(src, "@" .. path)
    if not fn then
        warn(("[UCam] Plugin %s: error de sintaxis: %s"):format(path, tostring(loadErr)))
        return false
    end

    -- Ejecutar el chunk. El plugin debe devolver una tabla (return { ... })
    local ok, spec = pcall(function()
        setfenv(fn, getfenv())
        return fn()
    end)
    if not ok then
        warn(("[UCam] Plugin %s: error al ejecutar: %s"):format(path, tostring(spec)))
        return false
    end

    -- Si no devuelve tabla, asumir que se registró él mismo (legacy)
    if type(spec) ~= "table" then
        print(("[UCam] Plugin %s ejecutado (sin metadata —format legacy)."):format(path))
        return true
    end

    return UCam.registerPlugin(spec, path:match("([^/\\]+)$") or path)
end

-- ============================================================
-- DESCUBRIR y cargar todos los plugins de la carpeta
-- ============================================================
function UCam.loadPluginsFromFolder()
    if not HAS_FS then
        print("[UCam] Persistencia: filesystem no disponible — plugins deshabilitados.")
        return 0
    end
    if not ensurePluginsFolder() then
        warn("[UCam] No se pudo crear la carpeta de plugins.")
        return 0
    end

    local folder = getPluginsFolder()
    local contents
    local okL = pcall(function() contents = listfiles(folder) end)
    if not okL or not contents then
        print("[UCam] No se encontraron plugins en " .. folder)
        return 0
    end

    local loaded = 0
    for _, path in ipairs(contents) do
        if path:match("%.lua$") or path:match("%.luau$") then
            local ok = loadPluginFile(path)
            if ok then loaded = loaded + 1 end
        end
    end

    if loaded > 0 then
        print(("[UCam] %d plugin(s) cargado(s) desde %s"):format(loaded, folder))
    end
    return loaded
end

-- ============================================================
-- PLUGINS POR DEFECTO (demo / ejemplo)
-- ============================================================
local function loadExamplePlugin()
    local example = {
        name    = "Demo Plugin",
        author  = "UCam",
        version = "1.0",
        icon    = 4483362458,
        build = function(Window)
            local DemoTab = Window:CreateTab("🧩 Demo", "puzzle")
            DemoTab:CreateParagraph({
                Title   = "Plugin de ejemplo",
                Content = "Esto está hecho con UCam.registerPlugin({...}). Crea tu propio .lua en UniversalCamera/plugins/ y pon 'return { name=..., build=function(Window)... end }' dentro.",
            })
            DemoTab:CreateButton({
                Name     = "Notificación demo",
                Callback = function()
                    UCam.notify("Demo Plugin", "El plugin funciona. Borra plugins/ si no lo quieres.")
                end,
            })
            DemoTab:CreateButton({
                Name     = "Ver plugins cargados",
                Callback = function()
                    local list = {}
                    for name, p in pairs(UCam.Plugins.Loaded) do
                        list[#list+1] = ("%s v%s (%s)"):format(name, p.version, p.author)
                    end
                    UCam.notify("Plugins", (#list > 0) and table.concat(list, "\n") or "Ninguno cargado.")
                end,
            })
        end,
        start = function(UC)
            UC.notify("Plugins", "Demo Plugin iniciado.")
        end,
        stop = function(UC)
            print("[UCam] Demo Plugin detenido.")
        end,
    }
    UCam.registerPlugin(example, "demo_plugin.lua")
end

-- ============================================================
-- DETENER TODOS LOS PLUGINS (llamado desde Unload)
-- ============================================================
function UCam.stopAllPlugins()
    for name, p in pairs(UCam.Plugins.Loaded) do
        if p.stopFn then
            local ok, err = pcall(p.stopFn, UCam)
            if not ok then
                warn(("[UCam] Plugin '%s' stop falló: %s"):format(name, tostring(err)))
            end
        end
    end
    table.clear(UCam.Plugins.Loaded)
end

-- ============================================================
-- ARRANQUE: cargar carpeta + demo si está vacía
-- v8 FIX: carga SÍNCRONA (no task.defer) para que los plugins se
-- registren ANTES de que 90_init llame a buildUI(). Con defer, el
-- registro ocurría tras buildUI() y sus pestañas nunca se creaban.
-- ============================================================
local loadedCount = UCam.loadPluginsFromFolder()
if loadedCount == 0 then
    loadExamplePlugin()
end

print("[UCam] Sistema de plugins listo.")
