-- ============================================================
-- Universal Camera Pro v7 · 80_ui
-- Orquestador de la UI: crea la Window de Rayfield y delega cada
-- pestaña al sub-builder correspondiente. Los sub-builders se
-- registran en UCam.build_xxx y se cargan desde src/ui/*.lua
-- ANTES de llamar a UCam.buildUI().
--
-- Dependencias: 00_config (para Rayfield) + todos los ui/*.lua cargados antes.
-- Expone (UCam.*):
--   buildUI()  -- arma la Window y llama a cada UCam.build_xxx
--   build_inicio, build_camaras, build_espectador, build_slowmo,
--   build_cinematic, build_filters, build_light, build_estudio,
--   build_gimbal, build_fun, build_config, build_info
-- ============================================================
local UCam = _G.UCam

-- Tabla de sub-builders (v7: agregados bodycolor, poses, playermod, timecontrol, replay)
UCam._uiBuilders = {
    "inicio",
    "camaras",
    "espectador",
    "slowmo",
    "cinematic",
    "filters",
    "light",
    "estudio",
    "gimbal",
    "fun",
    "bodycolor",    -- v7: Coloreo avanzado por partes
    "poses",        -- v7: Sistema de poses avanzadas
    "playermod",    -- v7: Modificar otros jugadores
    "timecontrol",  -- v7: Control de Tiempo (Time Ramp, Frame-by-Frame, Fast Forward)
    "replay",       -- v7: Grabación y Replay de cámara
    "config",
    "info",
}

-- v7: Tabla de builders registrados dinámicamente (para plugins/extensiones)
UCam._dynamicTabBuilders = {}

-- v7: API para registro dinámico de tabs
-- Permite que plugins externos agreguen pestañas personalizadas
-- Uso: UCam.registerTabBuilder("miTab", function(Window) ... end)
function UCam.registerTabBuilder(name, builderFunction)
    if type(name) ~= "string" or name == "" then
        warn("[UCam] registerTabBuilder: 'name' debe ser un string no vacío")
        return false
    end
    
    if type(builderFunction) ~= "function" then
        warn("[UCam] registerTabBuilder: 'builderFunction' debe ser una función")
        return false
    end
    
    -- Verificar que no exista ya
    for _, existingName in ipairs(UCam._uiBuilders) do
        if existingName == name then
            warn(("[UCam] registerTabBuilder: Tab '%s' ya existe en _uiBuilders"):format(name))
            return false
        end
    end
    
    if UCam._dynamicTabBuilders[name] then
        warn(("[UCam] registerTabBuilder: Tab dinámico '%s' ya registrado"):format(name))
        return false
    end
    
    UCam._dynamicTabBuilders[name] = builderFunction
    print(("[UCam] Tab dinámico '%s' registrado exitosamente"):format(name))
    return true
end

-- v7: Remover un tab dinámico registrado
function UCam.unregisterTabBuilder(name)
    if UCam._dynamicTabBuilders[name] then
        UCam._dynamicTabBuilders[name] = nil
        print(("[UCam] Tab dinámico '%s' removido"):format(name))
        return true
    end
    return false
end

-- Sliders/dropdowns que el boton "Restablecer todos los valores" de
-- Inicio necesita leer/escribir (los crean las pestañas de Camaras
-- y Slowmo). Se forward-declaran para que Inicio ya los pueda usar.
UCam.UISliders = {
    modeDropdown          = nil,
    speedSlider           = nil,
    sprintSlider          = nil,
    smoothSlider          = nil,
    fovSlider             = nil,
    sensSlider            = nil,
    orbitDistSlider       = nil,
    orbitHeightSlider     = nil,
    orbitSpeedSlider      = nil,
    slowMoIntensitySlider = nil,
    vertigoMinSlider      = nil,
    vertigoMaxSlider      = nil,
    vertigoSpeedSlider    = nil,
    vertigoFovSlider      = nil,
}

-- buildUI: arma la ventana y dispara los sub-builders en orden.
function UCam.buildUI()
    local Window = UCam.Rayfield:CreateWindow({
        Name                   = "Universal Camera Pro v7 By Cocoa Feliz",
        LoadingTitle           = "Universal Camera",
        LoadingSubtitle        = "Cargando interfaz v7...",
        Icon                   = 4483362458,
        ToggleUIKeybind        = Enum.KeyCode.Delete,
        DisableRayfieldPrompts = true,
        ConfigurationSaving    = { Enabled = false },
    })

    for _, name in ipairs(UCam._uiBuilders) do
        local fn = UCam["build_" .. name]
        if type(fn) == "function" then
            local ok, err = pcall(fn, Window)
            if not ok then
                warn(("[UCam] Sub-builder '%s' fallo: %s"):format(name, tostring(err)))
            end
        else
            warn(("[UCam] Sub-builder '%s' no registrado. Carga src/ui/%s.lua antes de 80_ui."):format(name, name))
        end
    end
    
    -- v7: Procesar tabs dinámicos registrados
    for name, fn in pairs(UCam._dynamicTabBuilders) do
        if type(fn) == "function" then
            local ok, err = pcall(fn, Window)
            if not ok then
                warn(("[UCam] Tab dinámico '%s' fallo: %s"):format(name, tostring(err)))
            end
        end
    end
end
