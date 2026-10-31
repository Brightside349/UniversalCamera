-- ============================================================
-- Universal Camera Pro v13 · ui/05_adapter
-- Adaptador entre la API que ya usan las 16 pestañas (estilo
-- Rayfield: Window:CreateTab / Tab:CreateSlider / ...) y WindUI.
--
-- v13: las pestañas NO cambian. Este archivo traduce:
--   Name/CurrentValue/Flag/Range/Increment  ->  Title/Value/Flag/Value{Min,Max}/Step
--   CreateSection(texto)                    ->  Tab:Section({ Title=... })
--   Rayfield.Flags[nombre]                  ->  proxy del elemento (CurrentValue, ...)
--   createUIGroup + escaneo de la GUI       ->  visibilidad por ElementFrame
--
-- Dependencias: lib/00_windui.lua, core/00_config.lua.
-- Expone: UCam.UI (y UCam.Rayfield como alias de compatibilidad).
-- ============================================================
local UCam = _G.UCam

local UI = {
    Flags      = {},
    tabsByTitle = {},
    elements   = {},
    Kind       = "windui",
    Version    = UCam.WINDU_VERSION,
    themeName  = "UCam Pro",
}

UCam.UI = UI
-- Alias: el resto del script lee UCam.Rayfield.Flags[...]
UCam.Rayfield = UI

-- ============================================================
-- FONDO DE LA UI
-- ============================================================
-- WindUI redondea la transparencia a decimas, asi que el valor por
-- defecto es 0.5 (50% de opacidad) para que slider y render coincidan.
local BACKGROUND_ID = "rbxassetid://8741056068"
local BACKGROUND_TRANSPARENCY = 0.5

UI.background = {
    id           = BACKGROUND_ID,
    transparency = BACKGROUND_TRANSPARENCY,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function cleanTitle(title)
    local text = tostring(title or "")
    local stripped = text:gsub("^[^%w]+", "")
    stripped = stripped:gsub("^%s+", "")
    if stripped == "" then
        return text
    end
    return stripped
end
UI.cleanTitle = cleanTitle

local function iconOf(icon)
    if type(icon) == "number" then
        return "rbxassetid://" .. tostring(icon)
    end
    if type(icon) == "string" and icon ~= "" then
        if icon:match("^%d+$") then
            return "rbxassetid://" .. icon
        end
        if icon:find(":", 1, true) then
            return icon
        end
        return "lucide:" .. icon
    end
    return nil
end

local function themeCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

-- ============================================================
-- PROXIES DE ELEMENTO
-- Las pestañas usan :Set(), :Refresh() y campos como .CurrentValue,
-- .CurrentOption o .CurrentKeybind. Todo eso vive aqui.
-- ============================================================
local Proxy = {}

Proxy.__index = function(self, key)
    local direct = rawget(self, key)
    if direct ~= nil then
        return direct
    end
    if key == "CurrentValue" or key == "Value" or key == "CurrentOption"
        or key == "CurrentKeybind" or key == "Color" then
        return rawget(self, "_value")
    end
    return rawget(Proxy, key)
end

function Proxy:Set(value)
    if type(self._apply) == "function" then
        local ok, err = pcall(self._apply, value)
        if not ok then
            warn(("[UCam] UI:%s falló al aplicar un valor: %s"):format(tostring(self._kind), tostring(err)))
        end
    else
        self._value = value
    end
end

function Proxy:Refresh(value)
    self:Set(value)
end

function Proxy:setVisible(visible)
    self._visible = visible ~= false
    local frame = rawget(self, "_frame")
    if frame and frame.Parent ~= nil then
        pcall(function()
            frame.Visible = self._visible
        end)
    end
end

function Proxy:SetVisible(visible)
    self:setVisible(visible)
end

function Proxy:Destroy()
    local native = rawget(self, "_native")
    if native and type(native.Destroy) == "function" then
        pcall(function()
            native:Destroy()
        end)
    end
end

local function attach(spec, native, value, apply)
    local proxy = setmetatable({
        _kind    = spec.kind,
        _spec    = spec,
        _native  = native,
        _value   = value,
        _visible = true,
    }, Proxy)

    -- ElementFrame lo define WindUI en elements/Init.lua; Section lo expone
    -- directamente. Es lo que permite ocultar un panel entero sin reconstruir.
    proxy._frame = native and (native.ElementFrame or native.Frame or native.UIContainer)
    proxy._apply = apply

    if spec.Flag then
        UI.Flags[spec.Flag] = proxy
    end
    if UI._recording then
        table.insert(UI._recording._items, proxy)
    end
    table.insert(UI.elements, proxy)

    return proxy
end

-- ============================================================
-- CREACION
-- ============================================================
-- Los elementos se crean siempre en el Tab, nunca dentro del Section.
-- Un Section que contiene elementos se vuelve plegable y fija su altura al
-- construirse: como las 16 pestañas se construyen ocultas, mediria 0 y el
-- contenido quedaria colapsado. Como cabecera mantiene altura automatica.
local function createNative(tab, method, config)
    local container = tab._native
    local fn = container and container[method]
    if type(fn) ~= "function" then
        warn(("[UCam] WindUI no expone el elemento '%s'."):format(method))
        return nil
    end

    local ok, native = pcall(fn, container, config)
    if not ok then
        warn(("[UCam] WindUI %s falló: %s"):format(method, tostring(native)))
        return nil
    end
    return native
end

-- Ocultar/mostrar el elemento con :Set dispara el Callback del propio
-- elemento. Lo silenciamos un frame para que un Set programatico no
-- reentre en el callback del usuario (p. ej. resetear el FOV).
local function suppressFor(proxy)
    proxy._suppress = true
    task.delay(0, function()
        proxy._suppress = false
    end)
end

-- ============================================================
-- KEYBINDS
-- WindUI solo captura la tecla; la ejecucion corre por nuestra cuenta.
-- ============================================================
local keyConnections = {}

local function keyCodeOf(value)
    if typeof(value) == "EnumItem" then
        return value
    end
    if type(value) == "string" then
        local ok, code = pcall(function()
            return Enum.KeyCode[value]
        end)
        if ok then
            return code
        end
    end
    return nil
end

local function bindKey(proxy)
    local connection = UCam.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not proxy._key or input.KeyCode ~= proxy._key then return end
        if UCam.UserInputService:GetFocusedTextBox() then return end

        local callback = rawget(proxy, "_callback")
        if type(callback) ~= "function" then return end
        local ok, err = pcall(callback, proxy._key)
        if not ok then
            warn(("[UCam] Keybind '%s' falló: %s"):format(tostring(proxy._title), tostring(err)))
        end
    end)
    table.insert(keyConnections, connection)
    proxy._conn = connection
end

-- ============================================================
-- TAB PROXY
-- ============================================================
local TabProxy = {}
TabProxy.__index = TabProxy

function TabProxy:CreateSection(title)
    local native = createNative(self, "Section", {
        Title = tostring(title or "Sección"),
    })
    if not native then return nil end

    local proxy = attach({ kind = "Section" }, native, title, nil)
    proxy._frame = native.ElementFrame or proxy._frame
    return proxy
end

function TabProxy:CreateParagraph(spec)
    spec = spec or {}
    local native = createNative(self, "Paragraph", {
        Title = spec.Title,
        Desc  = spec.Content,
    })
    if not native then return nil end
    return attach({ kind = "Paragraph" }, native, nil, nil)
end

function TabProxy:CreateToggle(spec)
    spec = spec or {}
    local proxy
    local initial = spec.CurrentValue == true

    local native = createNative(self, "Toggle", {
        Title    = spec.Name,
        Desc     = spec.Desc,
        Icon     = iconOf(spec.Icon),
        Value    = initial,
        Flag     = spec.Flag,
        Callback = function(state)
            if proxy then proxy._value = state end
            if proxy and proxy._suppress then return end
            if type(spec.Callback) == "function" then spec.Callback(state == true) end
        end,
    })
    if not native then return nil end

    proxy = attach({ kind = "Toggle", Flag = spec.Flag }, native, initial, function(value)
        local flag = value == true
        proxy._value = flag
        suppressFor(proxy)
        if type(native.Set) == "function" then
            pcall(function() native:Set(flag) end)
        end
    end)
    return proxy
end

function TabProxy:CreateSlider(spec)
    spec = spec or {}
    local range = spec.Range or { 0, 100 }
    local minValue = tonumber(range[1]) or 0
    local maxValue = tonumber(range[2]) or 100
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end

    local step = tonumber(spec.Increment) or 1
    if step <= 0 then step = 1 end

    local initial = tonumber(spec.CurrentValue) or minValue
    initial = math.clamp(initial, minValue, maxValue)

    local proxy

    local native = createNative(self, "Slider", {
        Title = spec.Name,
        -- WindUI no tiene Suffix: la unidad viaja como descripcion corta.
        Desc  = spec.Desc or spec.Suffix,
        Step  = step,
        Value = { Min = minValue, Max = maxValue, Default = initial },
        Flag  = spec.Flag,
        Callback = function(value)
            if proxy then proxy._value = value end
            if proxy and proxy._suppress then return end
            if type(spec.Callback) == "function" then spec.Callback(value) end
        end,
    })
    if not native then return nil end

    proxy = attach({ kind = "Slider", Flag = spec.Flag }, native, initial, function(value)
        local numeric = tonumber(value)
        if not numeric then return end
        numeric = math.clamp(numeric, minValue, maxValue)
        proxy._value = numeric
        suppressFor(proxy)
        if type(native.Set) == "function" then
            pcall(function() native:Set(numeric) end)
        end
    end)
    return proxy
end

function TabProxy:CreateDropdown(spec)
    spec = spec or {}
    local multi = spec.MultipleOptions == true

    local values = {}
    for index, option in ipairs(spec.Options or {}) do
        values[index] = option
    end
    if #values == 0 then
        warn(("[UCam] Dropdown '%s' sin opciones."):format(tostring(spec.Name)))
        return nil
    end

    local initial = spec.CurrentOption
    if type(initial) == "table" then
        initial = multi and initial or initial[1]
    end
    if multi then
        if type(initial) ~= "table" then
            initial = initial and { initial } or { values[1] }
        end
    else
        if type(initial) ~= "string" and type(initial) ~= "number" then
            initial = values[1]
        end
    end

    local proxy

    local native = createNative(self, "Dropdown", {
        Title            = spec.Name,
        Desc             = spec.Desc,
        Values           = values,
        Value            = initial,
        Multi            = multi,
        AllowNone        = false,
        SearchBarEnabled = #values > 8,
        Flag             = spec.Flag,
        Callback         = function(option)
            if proxy then proxy._value = option end
            if proxy and proxy._suppress then return end
            if type(spec.Callback) == "function" then spec.Callback(option) end
        end,
    })
    if not native then return nil end

    proxy = attach({ kind = "Dropdown", Flag = spec.Flag }, native, initial, function(value)
        local target = value
        if multi then
            if type(target) ~= "table" then
                target = target and { target } or {}
            end
        elseif type(target) == "table" then
            target = target[1]
        end
        proxy._value = target
        suppressFor(proxy)
        if type(native.Select) == "function" then
            pcall(function() native:Select(target) end)
        end
    end)
    return proxy
end

function TabProxy:CreateButton(spec)
    spec = spec or {}
    local native = createNative(self, "Button", {
        Title    = spec.Name,
        Desc     = spec.Desc,
        Callback = function()
            if type(spec.Callback) == "function" then spec.Callback() end
        end,
    })
    if not native then return nil end
    return attach({ kind = "Button" }, native, nil, nil)
end

function TabProxy:CreateInput(spec)
    spec = spec or {}
    local proxy
    local initial = tostring(spec.CurrentValue or "")

    local native = createNative(self, "Input", {
        Title       = spec.Name,
        Desc        = spec.Desc,
        Value       = initial,
        Placeholder = spec.PlaceholderText or "",
        Type        = "Input",
        Flag        = spec.Flag,
        Callback    = function(text)
            if proxy then proxy._value = text end
            if proxy and proxy._suppress then return end
            if type(spec.Callback) == "function" then spec.Callback(tostring(text or "")) end
            -- Rayfield borraba el campo tras el callback (IDs de asset).
            if spec.RemoveTextAfterFocusLost and proxy and not proxy._suppress then
                task.defer(function()
                    if type(native.Set) == "function" then
                        pcall(function() native:Set("") end)
                    end
                    proxy._value = ""
                end)
            end
        end,
    })
    if not native then return nil end

    proxy = attach({ kind = "Input", Flag = spec.Flag }, native, initial, function(value)
        local text = tostring(value or "")
        proxy._value = text
        suppressFor(proxy)
        if type(native.Set) == "function" then
            pcall(function() native:Set(text) end)
        end
    end)
    return proxy
end

-- Las teclas de movimiento viven en UCam.Keybinds[action] y el Flag manda:
-- al reasignar una tecla hay que reflejarlo sin ejecutar la accion (que es
-- lo que haria el Callback de un keybind normal).
local function syncKeybindAction(flagName, code)
    -- typeof, no type: un EnumItem de Roblox es userdata para type().
    if not flagName or typeof(code) ~= "EnumItem" then return end
    local action = flagName:match("^UCamKeybind_(.+)$")
    if not action then return end
    local keybinds = UCam.Keybinds
    if keybinds and keybinds[action] ~= nil then
        keybinds[action] = code.Name
    end
end

function TabProxy:CreateKeybind(spec)
    spec = spec or {}
    local proxy
    local initial = tostring(spec.CurrentKeybind or "F")

    local native = createNative(self, "Keybind", {
        Title    = spec.Name,
        Desc     = spec.Desc,
        Value    = initial,
        Flag     = spec.Flag,
        Callback = function(value)
            local code = keyCodeOf(value)
            if code and proxy then
                proxy._key = code
                proxy._value = code.Name
                syncKeybindAction(spec.Flag, code)
                if type(proxy._onChange) == "function" then
                    pcall(proxy._onChange, code)
                end
            end
        end,
    })
    if not native then return nil end

    proxy = attach({ kind = "Keybind", Flag = spec.Flag }, native, initial, function(value)
        local code = keyCodeOf(value)
        if not code then return end
        proxy._key = code
        proxy._value = code.Name
        syncKeybindAction(spec.Flag, code)
    end)
    proxy._key = keyCodeOf(initial) or Enum.KeyCode.F
    proxy._value = proxy._key.Name
    proxy._title = spec.Name
    proxy._callback = spec.Callback
    proxy._hold = spec.HoldToInteract == true
    bindKey(proxy)
    return proxy
end

function TabProxy:CreateColorPicker(spec)
    spec = spec or {}
    local proxy
    local initial = spec.Color or Color3.fromRGB(255, 255, 255)

    local native = createNative(self, "Colorpicker", {
        Title    = spec.Name,
        Desc     = spec.Desc,
        Default  = initial,
        Flag     = spec.Flag,
        Callback = function(color)
            if proxy then proxy._value = color end
            if proxy and proxy._suppress then return end
            if type(spec.Callback) == "function" then spec.Callback(color) end
        end,
    })
    if not native then return nil end

    proxy = attach({ kind = "Colorpicker", Flag = spec.Flag }, native, initial, function(value)
        if typeof(value) ~= "Color3" then return end
        proxy._value = value
        suppressFor(proxy)
        if type(native.Set) == "function" then
            pcall(function() native:Set(value) end)
        end
    end)
    return proxy
end

-- ============================================================
-- SECCIONES DE LA BARRA LATERAL
-- Agrupa 16 pestañas en 5 bloques para que la ventana respire.
-- ============================================================
local SECTION_INFO = {
    ["Cámara"] = {
        Icon = "lucide:clapperboard",
        Tabs = { Inicio = true, ["Cámaras"] = true, Espectador = true, ["Cinematográfico"] = true, Gimbal = true },
    },
    ["Escena"] = {
        Icon = "lucide:sparkles",
        Tabs = { Filtros = true, ["Iluminación"] = true, Estudio = true },
    },
    ["Personajes"] = {
        Icon = "lucide:users",
        Tabs = { Clones = true, Cuerpo = true },
    },
    ["Creación"] = {
        Icon = "lucide:wand-sparkles",
        Tabs = { Props = true, Animador = true, ["Diversión"] = true },
    },
    ["Sistema"] = {
        Icon = "lucide:settings-2",
        Tabs = { Ajustes = true, Creator = true, Info = true },
    },
}
local SECTION_ORDER = { "Cámara", "Escena", "Personajes", "Creación", "Sistema" }

local function sectionFor(tabName)
    for _, sectionName in ipairs(SECTION_ORDER) do
        local info = SECTION_INFO[sectionName]
        if info.Tabs[tabName] then
            return sectionName
        end
    end
    return "Extras"
end

-- ============================================================
-- TEMAS
-- ============================================================
local THEME_ALIASES = {
    Dark     = "UCam Pro",
    Light    = "Claro",
    Aqua     = "Aqua",
    Amethyst = "Amatista",
}

local function installThemes(lib)
    if UI._themesInstalled then return end

    local gradient = lib.Gradient
    local glow
    if type(gradient) == "function" then
        glow = gradient({
            ["0"]   = { Color = Color3.fromHex("#00E6C3"), Transparency = 0 },
            ["100"] = { Color = Color3.fromHex("#00B4FF"), Transparency = 0 },
        }, { Rotation = 0 })
    end

    local themes = lib:GetThemes() or {}
    local dark = themeCopy(themes["Dark"])
    local light = themeCopy(themes["Light"])

    local pro = themeCopy(dark)
    pro.Name = "UCam Pro"
    pro.Accent = Color3.fromHex("#141821")
    pro.Background = Color3.fromHex("#0b0d12")
    pro.Dialog = Color3.fromHex("#11141b")
    pro.Outline = Color3.fromHex("#2a3140")
    pro.Text = Color3.fromHex("#eef2f8")
    pro.Placeholder = Color3.fromHex("#7c8798")
    pro.Button = Color3.fromHex("#1d2230")
    pro.Icon = Color3.fromHex("#93a4bb")
    pro.Toggle = Color3.fromHex("#00E6C3")
    pro.Checkbox = Color3.fromHex("#00B4FF")
    pro.Slider = Color3.fromHex("#00B4FF")
    pro.Primary = glow or Color3.fromHex("#00E6C3")
    pro.ElementBackground = Color3.fromHex("#161a22")
    pro.ElementBackgroundTransparency = 0.15
    pro.PanelBackground = Color3.fromHex("#0f1218")
    pro.PanelBackgroundTransparency = 0.4
    lib:AddTheme(pro)

    local clear = themeCopy(light)
    clear.Name = "Claro"
    clear.Background = Color3.fromHex("#f6f7fb")
    clear.Dialog = Color3.fromHex("#ffffff")
    clear.Text = Color3.fromHex("#11141b")
    clear.Placeholder = Color3.fromHex("#6b7280")
    clear.Toggle = Color3.fromHex("#00a88f")
    clear.Slider = Color3.fromHex("#0d8bff")
    clear.Checkbox = Color3.fromHex("#0d8bff")
    clear.Primary = Color3.fromHex("#0d8bff")
    clear.ElementBackground = Color3.fromHex("#ffffff")
    clear.ElementBackgroundTransparency = 0
    lib:AddTheme(clear)

    local aqua = themeCopy(dark)
    aqua.Name = "Aqua"
    aqua.Background = Color3.fromHex("#04141a")
    aqua.Dialog = Color3.fromHex("#06202a")
    aqua.Accent = Color3.fromHex("#082b34")
    aqua.Text = Color3.fromHex("#dcfbf6")
    aqua.Placeholder = Color3.fromHex("#6ea9a4")
    aqua.Icon = Color3.fromHex("#7fd8cd")
    aqua.Toggle = Color3.fromHex("#00E6C3")
    aqua.Checkbox = Color3.fromHex("#22d3ee")
    aqua.Slider = Color3.fromHex("#22d3ee")
    aqua.Primary = glow or Color3.fromHex("#00E6C3")
    aqua.ElementBackground = Color3.fromHex("#0a2630")
    aqua.ElementBackgroundTransparency = 0.15
    lib:AddTheme(aqua)

    local amethyst = themeCopy(dark)
    amethyst.Name = "Amatista"
    amethyst.Background = Color3.fromHex("#0d0a16")
    amethyst.Dialog = Color3.fromHex("#161022")
    amethyst.Accent = Color3.fromHex("#1b1430")
    amethyst.Text = Color3.fromHex("#f1ecff")
    amethyst.Placeholder = Color3.fromHex("#9b8fc0")
    amethyst.Icon = Color3.fromHex("#b9a9ff")
    amethyst.Toggle = Color3.fromHex("#a855f7")
    amethyst.Checkbox = Color3.fromHex("#8b5cf6")
    amethyst.Slider = Color3.fromHex("#8b5cf6")
    amethyst.Primary = Color3.fromHex("#a855f7")
    amethyst.ElementBackground = Color3.fromHex("#181228")
    amethyst.ElementBackgroundTransparency = 0.15
    lib:AddTheme(amethyst)

    UI._themesInstalled = true
end

function UI.setTheme(name)
    local lib = UCam.WindUI
    if not lib then return end
    local theme = THEME_ALIASES[name] or name or "UCam Pro"
    local ok = pcall(function()
        lib:SetTheme(theme)
    end)
    if not ok then
        pcall(function() lib:SetTheme("Dark") end)
        UI.themeName = "Dark"
        return
    end
    UI.themeName = theme
end

function UI.setBackground(enabled, opacityPercent)
    local window = UI.window
    if not window then return end

    local opacity = tonumber(opacityPercent) or 50
    opacity = math.clamp(opacity, 0, 100)

    pcall(function()
        if type(window.SetBackgroundImage) == "function" then
            window:SetBackgroundImage(enabled and BACKGROUND_ID or "")
        end
        if type(window.SetBackgroundImageTransparency) == "function" then
            window:SetBackgroundImageTransparency(1 - (opacity / 100))
        end
    end)
end

function UI.setCompact(enabled)
    UI.compact = enabled == true
    if UI.window and type(UI.window.SetIconSize) == "function" then
        pcall(function()
            UI.window:SetIconSize(UI.compact and 16 or 20)
        end)
    end
end

-- ============================================================
-- VENTANA
-- ============================================================
function UI.isReady()
    return UCam.WindUI ~= nil
end

function UI.createWindow()
    local lib = UCam.WindUI
    if not lib then
        warn("[UCam] Sin WindUI: la UI no se construye. Motivo: " .. tostring(UCam.UI_LIB_ERROR))
        return nil
    end

    installThemes(lib)

    local ok, window = pcall(function()
        return lib:CreateWindow({
            Title                       = "Universal Camera Pro v13",
            Icon                        = "lucide:clapperboard",
            Author                      = "by Cocoa Feliz",
            Folder                      = "UniversalCameraPro",
            Size                        = UDim2.fromOffset(620, 490),
            MinSize                     = Vector2.new(520, 360),
            MaxSize                     = Vector2.new(940, 620),
            ToggleKey                   = Enum.KeyCode.Delete,
            Transparent                 = false,
            Theme                       = UI.themeName,
            Resizable                   = true,
            SideBarWidth                = 178,
            Background                  = BACKGROUND_ID,
            BackgroundImageTransparency = BACKGROUND_TRANSPARENCY,
            HideSearchBar               = false,
            ScrollBarEnabled            = true,
            OpenButton                  = {
                Title       = "Universal Camera",
                Icon        = "lucide:clapperboard",
                OnlyMobile  = true,
                Enabled     = true,
                Draggable   = true,
                CornerRadius = UDim.new(0, 16),
            },
        })
    end)

    if not ok or not window then
        warn("[UCam] WindUI CreateWindow falló: " .. tostring(window))
        return nil
    end

    UI.window = window
    UI._sectionName = nil

    function window:CreateTab(title, icon)
        return UI.makeTab(self, title, icon)
    end

    return window
end

function UI.makeTab(window, title, icon)
    local name = cleanTitle(title)
    local sectionName = sectionFor(name)

    if UI._sectionName ~= sectionName then
        local info = SECTION_INFO[sectionName] or { Icon = "lucide:box" }
        pcall(function()
            window:Section({ Title = sectionName, Icon = info.Icon, Opened = true })
        end)
        UI._sectionName = sectionName
    end

    local ok, native = pcall(function()
        return window:Tab({ Title = name, Icon = iconOf(icon) })
    end)
    if not ok or not native then
        warn(("[UCam] No se pudo crear la pestaña '%s': %s"):format(name, tostring(native)))
        return nil
    end

    local tab = setmetatable({ _native = native, _name = name, _section = nil }, TabProxy)
    UI.tabsByTitle[name] = tab
    return tab
end

-- ============================================================
-- GRUPOS CONDICIONALES
-- Sustituye el escaneo de Main/Elements/<pestaña> de Rayfield por la
-- visibilidad del ElementFrame de cada elemento creado entre begin/finish.
-- ============================================================
function UI.createGroup(tabName)
    local group = {
        _items   = {},
        _visible = true,
        _tabName = tabName,
    }

    function group.begin()
        UI._recording = group
    end

    function group.finish()
        UI._recording = nil
        group.setVisible(group._visible)
    end

    function group.setVisible(visible)
        group._visible = visible ~= false
        for _, proxy in ipairs(group._items) do
            if type(proxy.setVisible) == "function" then
                proxy:setVisible(group._visible)
            end
        end
    end

    return group
end

-- ============================================================
-- NOTIFICACIONES Y CIERRE
-- ============================================================
function UI.notify(opts)
    local lib = UCam.WindUI
    if not lib then return end
    opts = opts or {}
    pcall(function()
        lib:Notify({
            Title    = opts.Title or "Universal Camera",
            Content  = opts.Content,
            Duration = opts.Duration or 3,
            Icon     = iconOf(opts.Icon) or "lucide:video",
        })
    end)
end

-- Ocultar toda la UI (Clean Shot / captura) sin cerrar la ventana.
function UI.setVisible(visible)
    local lib = UCam.WindUI
    if not lib then return end
    for _, key in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
        local gui = lib[key]
        if gui then
            pcall(function()
                gui.Enabled = visible ~= false
            end)
        end
    end
end

function UI.destroy()
    for _, connection in ipairs(keyConnections) do
        pcall(function() connection:Disconnect() end)
    end
    keyConnections = {}

    local lib = UCam.WindUI
    if not lib then return end

    for _, key in ipairs({ "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }) do
        local gui = lib[key]
        if gui then
            pcall(function() gui:Destroy() end)
        end
    end
    if lib.Window and type(lib.Window.Destroy) == "function" then
        pcall(function() lib.Window:Destroy() end)
    end

    -- Restos de la UI anterior (v12 y anteriores usaban Rayfield).
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local old = coreGui:FindFirstChild("Rayfield")
        if old then old:Destroy() end
    end)

    UI.window = nil
    UI._sectionName = nil
    UI._recording = nil
end

-- 90_init llama UCam.Rayfield:Destroy() por compatibilidad con v12.
UI.Destroy = UI.destroy
