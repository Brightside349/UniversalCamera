-- ============================================================
-- Universal Camera Pro v13 · UI builder
-- Construye la ventana, tabs estáticos/dinámicos y autosave.
--
-- Dependencias: core/00_config.lua, core/05_persistence.lua,
--               ui/00_registry.lua y todos los ui/tabs/*.lua.
-- ============================================================
local UCam = _G.UCam

function UCam.buildUI()
    -- v13: la ventana, el tema y el fondo los arma ui/05_adapter.lua.
    local Window = UCam.UI and UCam.UI.createWindow and UCam.UI.createWindow()
    if not Window then
        warn("[UCam] UI no disponible: se cargan los modulos sin panel.")
        return
    end
    UCam._window = Window

    -- Refleja tema/fondo guardados en cuanto existe la ventana.
    if UCam.applyUISettings then
        pcall(UCam.applyUISettings)
    end

    for _, name in ipairs(UCam._uiBuilders) do
        local fn = UCam["build_" .. name]
        if type(fn) == "function" then
            local ok, err = pcall(fn, Window)
            if not ok then
                warn(("[UCam] Sub-builder '%s' falló: %s"):format(name, tostring(err)))
            end
        else
            warn(("[UCam] Sub-builder '%s' no registrado. Carga ui/tabs/%s.lua antes de ui/90_builder.lua."):format(name, name))
        end
    end

    for name, fn in pairs(UCam._dynamicTabBuilders) do
        if type(fn) == "function" then
            UCam._builtDynamicTabs[name] = true
            local ok, err = pcall(fn, Window)
            if not ok then
                warn(("[UCam] Tab dinámico '%s' falló: %s"):format(name, tostring(err)))
            end
        end
    end

    -- v11 FIX: el watcher antiguo comparaba un hash de tostring() de valores
    -- numéricos cada Heartbeat: con floats (3.0000001) disparaba saves falsos
    -- en bucle, y con valores estables nunca ahorraba nada real. El autosave
    -- real ya lo disparan los módulos (persistence: scheduleSave en cada
    -- mutación relevante, incluidos los props); aquí solo se garantiza un
    -- guardado tras construir la UI por si loadConfig cambió algo.
    if UCam.scheduleSave then
        UCam.scheduleSave()
    end
end
