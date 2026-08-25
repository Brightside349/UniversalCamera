-- ============================================================
-- Universal Camera Pro v10.5 · UI registry
-- Registra builders estáticos, tabs dinámicos de plugins y referencias
-- de controles compartidas. La ventana se construye en 90_builder.lua.
--
-- Dependencias: core/00_config.lua.
-- Expone: registerTabBuilder, unregisterTabBuilder, _uiBuilders,
--         _dynamicTabBuilders y UISliders.
-- ============================================================
local UCam = _G.UCam

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
    "bodycolor",
    "poses",
    "playermod",
    "replay",
    "profiles",
    "config",
    "creator",
    "info",
}

UCam._dynamicTabBuilders = {}
UCam._builtDynamicTabs = {}

function UCam.registerTabBuilder(name, builderFunction)
    if type(name) ~= "string" or name == "" then
        warn("[UCam] registerTabBuilder: 'name' debe ser un string no vacío")
        return false
    end
    if type(builderFunction) ~= "function" then
        warn("[UCam] registerTabBuilder: 'builderFunction' debe ser una función")
        return false
    end
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

    if UCam._window then
        task.defer(function()
            if UCam._builtDynamicTabs[name] or not UCam._window then return end
            UCam._builtDynamicTabs[name] = true
            local ok, err = pcall(builderFunction, UCam._window)
            if not ok then
                warn(("[UCam] Tab dinámico tardío '%s' falló: %s"):format(name, tostring(err)))
            end
        end)
    end
    return true
end

function UCam.unregisterTabBuilder(name)
    if UCam._dynamicTabBuilders[name] then
        UCam._dynamicTabBuilders[name] = nil
        print(("[UCam] Tab dinámico '%s' removido"):format(name))
        return true
    end
    return false
end

UCam.UISliders = {
    modeDropdown = nil,
    speedSlider = nil,
    sprintSlider = nil,
    smoothSlider = nil,
    fovSlider = nil,
    sensSlider = nil,
    orbitDistSlider = nil,
    orbitHeightSlider = nil,
    orbitSpeedSlider = nil,
    vertigoMinSlider = nil,
    vertigoMaxSlider = nil,
    vertigoSpeedSlider = nil,
    vertigoFovSlider = nil,
}
