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

UCam._uiBuilders = {
    "inicio",
    "camaras",
    "espectador",
    "cinematic",
    "filters",
    "light",
    "estudio",
    "gimbal",
    "props",
    "propsanim",
    "clones",
    "fun",
    "bodycolor",
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
-- GRUPOS DE UI CONDICIONALES (v12.5)
-- Rayfield crea cada elemento dentro de la pagina de su pestana
-- (Main.Elements.<nombre de la pestana>). Este helper captura los
-- elementos creados entre begin() y finish() para poder mostrar u
-- ocultar el panel completo sin reconstruir la pestana.
-- ============================================================
-- La libreria de Rayfield NO expone Main/Elements en su tabla publica:
-- son locales del modulo. La GUI se localiza por su estructura real
-- (ScreenGui → Main → Elements → pagina de la pestaña).
local function findPageInRoot(root, tabName)
    if not root then return nil end
    local ok, children = pcall(function() return root:GetChildren() end)
    if not ok or not children then return nil end
    for _, child in ipairs(children) do
        local main = child:FindFirstChild("Main")
        local elements = main and main:FindFirstChild("Elements")
        if elements then
            local page = elements:FindFirstChild(tabName)
            if page then return page end
        end
    end
    return nil
end

local function findRayfieldPage(tabName)
    local roots = {}
    pcall(function()
        local hui = gethui and gethui()
        if hui then table.insert(roots, hui) end
    end)
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        table.insert(roots, coreGui)
        local robloxGui = coreGui:FindFirstChild("RobloxGui")
        if robloxGui then table.insert(roots, robloxGui) end
    end)
    local playerGui = UCam.player and UCam.player:FindFirstChild("PlayerGui")
    if playerGui then table.insert(roots, playerGui) end

    for _, root in ipairs(roots) do
        local page = findPageInRoot(root, tabName)
        if page then return page end
    end
    return nil
end

function UCam.createUIGroup(tabName)
    local group = { _items = {}, _visible = true, _tabName = tabName }

    function group.begin()
        local page = findRayfieldPage(tabName)
        group._page = page
        group._seen = nil
        if not page then return end
        local seen = {}
        for _, child in ipairs(page:GetChildren()) do seen[child] = true end
        group._seen = seen
    end

    function group.finish()
        local page, seen = group._page, group._seen
        group._seen = nil
        if not (page and seen) then return end
        for _, child in ipairs(page:GetChildren()) do
            if not seen[child] then table.insert(group._items, child) end
        end
        group.setVisible(group._visible)
    end

    function group.setVisible(visible)
        group._visible = visible ~= false
        for _, inst in ipairs(group._items) do
            if inst and inst.Parent then
                pcall(function() inst.Visible = group._visible end)
            end
        end
    end

    return group
end
