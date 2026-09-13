-- ============================================================
-- Universal Camera Pro v11 · UI builder
-- Construye la ventana, tabs estáticos/dinámicos y autosave.
--
-- Dependencias: core/00_config.lua, core/05_persistence.lua,
--               ui/00_registry.lua y todos los ui/tabs/*.lua.
-- ============================================================
local UCam = _G.UCam

function UCam.buildUI()
    local Window = UCam.Rayfield:CreateWindow({
        Name = "Universal Camera Pro v11 By Cocoa Feliz",
        LoadingTitle = "Universal Camera Pro v11",
        LoadingSubtitle = "Cargando herramientas locales + Props...",
        Icon = 4483362458,
        ToggleUIKeybind = Enum.KeyCode.Delete,
        DisableRayfieldPrompts = true,
        ConfigurationSaving = { Enabled = false },
    })
    UCam._window = Window

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
