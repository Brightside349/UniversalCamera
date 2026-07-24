-- ============================================================
-- Universal Camera Pro v6 · 80_ui
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

-- Tabla de sub-builders (mismo orden que en PLAN §5)
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
    "config",
    "info",
}

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
        Name                   = "Universal Camera Pro v6 By Cocoa Feliz",
        LoadingTitle           = "Universal Camera",
        LoadingSubtitle        = "Cargando interfaz v6...",
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
end
