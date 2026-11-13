-- ============================================================
-- Universal Camera Pro v11 · UI registry
-- Registra builders estáticos, tabs dinámicos de plugins y referencias
-- de controles compartidas. La ventana se construye en 90_builder.lua.
--
-- Dependencias: core/00_config.lua.
-- Expone: registerTabBuilder, unregisterTabBuilder, _uiBuilders,
--         _dynamicTabBuilders y UISliders.
-- ============================================================
local UCam = _G.UCam

-- v13: el orden agrupa las pestañas en secciones de la barra lateral
-- (Camara / Escena / Personajes / Creacion / Sistema). El adaptador crea
-- una Window:Section cada vez que cambia el bloque, asi que el orden aqui
-- define el layout: no reordenar sin ajustar SECTION_INFO en ui/05_adapter.
UCam._uiBuilders = {
    "inicio",
    "camaras",
    "espectador",
    "cinematic",
    "gimbal",
    "filters",
    "light",
    "estudio",
    "clones",
    "bodycolor",
    "props",
    "propsanim",
    "replay",
    "fun",
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

-- v11: solo el dropdown de modo se comparte entre tabs (los 12 sliders
-- restantes nunca se registraban ni se leían — eliminados).
UCam.UISliders = {
    modeDropdown = nil,
}

-- ============================================================
-- GRUPOS DE UI CONDICIONALES (v13)
-- Las pestañas Cámaras y Espectador muestran solo el panel de su modo.
-- Antes se escarbaba la GUI de Rayfield (Main → Elements → pestaña);
-- ahora el adaptador registra los elementos creados entre begin() y
-- finish() y alterna la visibilidad de su ElementFrame.
-- ============================================================
function UCam.createUIGroup(tabName)
    local ui = UCam.UI
    if ui and ui.createGroup then
        return ui.createGroup(tabName)
    end
    -- Sin UI (WindUI no cargó): grupo inerte para no romper los builders.
    return {
        begin = function() end,
        finish = function() end,
        setVisible = function() end,
    }
end
