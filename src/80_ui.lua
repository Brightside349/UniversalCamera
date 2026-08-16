-- ============================================================
-- Universal Camera Pro v8 · 80_ui
-- Orquestador de la UI: crea la Window de Rayfield y delega cada
-- pestaña al sub-builder correspondiente. Los sub-builders se
-- registran en UCam.build_xxx y se cargan desde src/ui/*.lua
-- ANTES de llamar a UCam.buildUI().
--
-- Dependencias: 00_config (para Rayfield) + todos los ui/*.lua cargados antes.
-- Expone (UCam.*):
--   buildUI()  -- arma la Window y llama a cada UCam.build_xxx
--   build_inicio, build_camaras, build_espectador,
--   build_cinematic, build_filters, build_light, build_estudio,
--   build_gimbal, build_fun, build_config, build_info
--
-- v8: al terminar de construir, conecta un autosave que persiste
-- la config en disco 3s despues del ultimo cambio de cualquier
-- flag de Rayfield (05_persistence.lua).
-- ============================================================
local UCam = _G.UCam

-- Tabla de sub-builders (v7: agregados bodycolor, poses, playermod, replay)
-- v8: profiles
-- v8.1: eliminados slowmo, timecontrol, combos, macros, audioreactive, filterspro
UCam._uiBuilders = {
    "inicio",
    "camaras",
    "espectador",
    "cinematic",
    "filters",
    "light",
    "estudio",
    "gimbal",
    "fun",
    "bodycolor",    -- v7: Coloreo avanzado por partes
    "poses",        -- v7: Sistema de poses avanzadas
    "playermod",    -- v7: Modificar otros jugadores
    "replay",       -- v7: Grabación y Replay de cámara
    "profiles",     -- v8: Perfiles completos
    "config",
    "info",
}

-- v7: Tabla de builders registrados dinámicamente (para plugins/extensiones)
UCam._dynamicTabBuilders = {}
-- v8 FIX: tabs dinámicos ya construidos (evita doble build cuando un plugin
-- se registra en caliente mientras buildUI() está iterando _dynamicTabBuilders).
UCam._builtDynamicTabs = {}

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

    -- v8 FIX: si la UI ya se construyó (plugin registrado tarde, p.ej. en
    -- caliente o desde un folder cargado después de buildUI), construir la
    -- pestaña INMEDIATAMENTE con la Window guardada. Antes quedaba huérfano
    -- en _dynamicTabBuilders y nunca se creaba.
    if UCam._window then
        task.defer(function()
            -- Guard 1: si buildUI() ya construyó esta tab (loop de abajo), no
            -- construirla dos veces (registro en caliente durante el propio loop).
            if UCam._builtDynamicTabs[name] then return end
            -- Guard 2: si Unload() destruyó la Window antes de que corra el defer
            -- (recarga en el mismo frame), no construir sobre una UI muerta.
            if not UCam._window then return end
            UCam._builtDynamicTabs[name] = true
            local ok, err = pcall(builderFunction, UCam._window)
            if not ok then
                warn(("[UCam] Tab dinámico tardío '%s' fallo: %s"):format(name, tostring(err)))
            end
        end)
    end
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
-- Inicio necesita leer/escribir (los crea la pestaña de Camaras).
-- Se forward-declaran para que Inicio ya los pueda usar.
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
    vertigoMinSlider      = nil,
    vertigoMaxSlider      = nil,
    vertigoSpeedSlider    = nil,
    vertigoFovSlider      = nil,
}

-- buildUI: arma la ventana y dispara los sub-builders en orden.
function UCam.buildUI()
    local Window = UCam.Rayfield:CreateWindow({
        Name                   = "Universal Camera Pro v8 By Cocoa Feliz",
        LoadingTitle           = "Universal Camera",
        LoadingSubtitle        = "Cargando interfaz v8...",
        Icon                   = 4483362458,
        ToggleUIKeybind        = Enum.KeyCode.Delete,
        DisableRayfieldPrompts = true,
        ConfigurationSaving    = { Enabled = false }, -- v8 usa su propio sistema (05_persistence)
    })
    -- v8 FIX: guardar la Window para que los tabs dinámicos registrados
    -- DESPUÉS de buildUI() puedan construirse (ver registerTabBuilder).
    UCam._window = Window

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
            -- v8 FIX: marcar como construida para que un task.defer pendiente
            -- (registro en caliente durante este loop) no la reconstruya.
            UCam._builtDynamicTabs[name] = true
            local ok, err = pcall(fn, Window)
            if not ok then
                warn(("[UCam] Tab dinámico '%s' fallo: %s"):format(name, tostring(err)))
            end
        end
    end

    -- v8: AUTOSAVE — detecta cambios en los valores persistibles y
    -- llama a scheduleSave() (debounce 3s dentro de 05_persistence).
    -- Un heartbeat barato comparando un hash de los campos clave.
    if UCam.scheduleSave and UCam.trackConnection then
        local function snapNow()
            local parts = {}
            parts[#parts+1] = tostring(UCam.camMode)
            parts[#parts+1] = tostring(UCam.currentSpeed)
            parts[#parts+1] = tostring(UCam.MOUSE_SENSITIVITY)
            parts[#parts+1] = tostring(UCam.currentFilterIndex)
            parts[#parts+1] = tostring(UCam.Orbit and UCam.Orbit.Distance)
            parts[#parts+1] = tostring(UCam.Follow and UCam.Follow.Distance)
            parts[#parts+1] = tostring(UCam.Bloom and UCam.Bloom.Intensity)
            parts[#parts+1] = tostring(UCam.DOF and UCam.DOF.FocusDistance)
            -- v8.1: SlowMo eliminado
            parts[#parts+1] = tostring(UCam.Spectate and UCam.Spectate.Mode)
            parts[#parts+1] = tostring(UCam.LightingTweaks and UCam.LightingTweaks.ClockTime)
            parts[#parts+1] = tostring(UCam.Keybinds and UCam.Keybinds.Forward)
            parts[#parts+1] = tostring(UCam.Keybinds and UCam.Keybinds.Sprint)
            return table.concat(parts, "|")
        end
        local lastHash = snapNow()
        UCam.trackConnection(
            UCam.RunService.Heartbeat:Connect(function()
                local h = snapNow()
                if h ~= lastHash then
                    lastHash = h
                    UCam.scheduleSave()
                end
            end),
            "Autosave:Watcher"
        )
    end
end
