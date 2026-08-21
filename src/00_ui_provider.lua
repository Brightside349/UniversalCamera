-- ============================================================
-- Universal Camera Pro v11 · UI provider
-- WindUI es el proveedor principal; Rayfield queda como fallback.
-- Conserva el contrato CreateTab/CreateToggle/... de los builders actuales.
-- ============================================================
local UCam = _G.UCam or {}
_G.UCam = UCam

UCam.UIProvider = UCam.UIProvider or {
    Preferred = "WindUI",
    WindUIVersion = "1.6.66",
    FallbackEnabled = true,
}

local config = UCam.UIProvider
local provider = { Name = "Unavailable", Flags = {}, Library = nil, Window = nil, Error = nil }

local function fetch(url)
    local ok, source = pcall(function() return game:HttpGet(url) end)
    if not ok or type(source) ~= "string" or #source == 0 then return nil, tostring(source) end
    local loadOk, chunk = pcall(loadstring, source)
    if not loadOk or type(chunk) ~= "function" then return nil, tostring(chunk) end
    local runOk, library = pcall(chunk)
    if not runOk or not library then return nil, tostring(library) end
    return library
end

local function callMethod(object, names, ...)
    for _, name in ipairs(names) do
        local fn = object and object[name]
        if type(fn) == "function" then
            local ok, result = pcall(fn, object, ...)
            if ok then return true, result end
        end
    end
    return false
end

local function loadWindUI()
    local version = config.WindUIVersion or "1.6.66"
    return fetch(("https://github.com/Footagesus/WindUI/releases/download/%s/main.lua"):format(version))
end

local function loadRayfield()
    for _, url in ipairs({
        "https://sirius.menu/rayfield",
        "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    }) do
        local library = fetch(url)
        if library then return library end
    end
    return nil, "Rayfield fallback unavailable"
end

local function addFlag(flag, control)
    if flag and flag ~= "" then provider.Flags[flag] = control end
end

local function normalizeIcon(icon)
    if type(icon) == "number" then return "rbxassetid://" .. tostring(icon) end
    return icon
end

local function makeControl(raw, state)
    state._raw = raw
    state.Set = function(self, value)
        local ok = callMethod(raw, { "Set", "SetValue" }, value)
        if not ok then self._update(value) end
        return ok
    end
    state.SetValue = state.Set
    state.Refresh = function(self, values)
        local ok = callMethod(raw, { "Refresh", "SetValues" }, values)
        if not ok then self.Options = values end
        return ok
    end
    state.OnChanged = function(self, fn) return callMethod(raw, { "OnChanged" }, fn) end
    state._update = function(value)
        if state.Kind == "Dropdown" then
            state.CurrentOption = type(value) == "table" and value or { value }
            state.Value = value
        elseif state.Kind == "Keybind" then
            state.CurrentKeybind = value or state.CurrentKeybind
            state.Value = value or state.Value
        else
            state.CurrentValue = value
            state.Value = value
        end
    end
    return state
end

local function createWindTab(rawTab)
    local tab = {}
    function tab:CreateSection(title) return rawTab:Section({ Title = tostring(title or "") }) end
    function tab:CreateParagraph(options)
        options = options or {}
        return rawTab:Paragraph({ Title = options.Title or "", Desc = options.Content or options.Desc or "" })
    end
    function tab:CreateButton(options)
        options = options or {}
        return rawTab:Button({
            Title = options.Name or options.Title or "Button",
            Desc = options.Content or options.Description,
            Icon = normalizeIcon(options.Icon),
            Callback = options.Callback,
        })
    end
    function tab:CreateToggle(options)
        options = options or {}
        local state = makeControl(nil, { Kind = "Toggle", CurrentValue = options.CurrentValue == true, Value = options.CurrentValue == true })
        local raw = rawTab:Toggle({
            Title = options.Name or options.Title or "Toggle", Desc = options.Description,
            Flag = options.Flag, Value = options.CurrentValue == true,
            Callback = function(value)
                state._update(value == true)
                if options.Callback then options.Callback(value == true) end
            end,
        })
        state._raw = raw; addFlag(options.Flag, state); return state
    end
    function tab:CreateSlider(options)
        options = options or {}
        local range = options.Range or { 0, 1 }
        local state = makeControl(nil, { Kind = "Slider", CurrentValue = options.CurrentValue, Value = options.CurrentValue })
        local raw = rawTab:Slider({
            Title = options.Name or options.Title or "Slider", Desc = options.Description,
            Flag = options.Flag, Step = options.Increment or 1, Suffix = options.Suffix,
            Value = { Min = range[1], Max = range[2], Default = options.CurrentValue },
            Callback = function(value)
                state._update(value)
                if options.Callback then options.Callback(value) end
            end,
        })
        state._raw = raw; addFlag(options.Flag, state); return state
    end
    function tab:CreateDropdown(options)
        options = options or {}
        local selected = options.CurrentOption
        if type(selected) == "table" and not options.MultipleOptions then selected = selected[1] end
        local state = makeControl(nil, { Kind = "Dropdown", Options = options.Options or {}, CurrentOption = options.CurrentOption or {}, Value = selected })
        local raw = rawTab:Dropdown({
            Title = options.Name or options.Title or "Dropdown", Desc = options.Description,
            Flag = options.Flag, Values = options.Options or {}, Value = selected,
            Multi = options.MultipleOptions == true,
            Callback = function(value)
                state._update(value)
                if options.Callback then options.Callback(value) end
            end,
        })
        state._raw = raw; addFlag(options.Flag, state); return state
    end
    function tab:CreateInput(options)
        options = options or {}
        local state = makeControl(nil, { Kind = "Input", CurrentValue = options.CurrentValue or "", Value = options.CurrentValue or "" })
        local raw = rawTab:Input({
            Title = options.Name or options.Title or "Input", Desc = options.Description,
            Flag = options.Flag, Value = options.CurrentValue or "", Placeholder = options.PlaceholderText,
            Type = options.Type or "Input",
            Callback = function(value)
                state._update(value)
                if options.Callback then options.Callback(value) end
            end,
        })
        state._raw = raw; addFlag(options.Flag, state); return state
    end
    function tab:CreateColorPicker(options)
        options = options or {}
        local state = makeControl(nil, {
            Kind = "ColorPicker",
            CurrentValue = options.Color,
            Value = options.Color,
            Color = options.Color,
        })
        local raw = rawTab:Colorpicker({
            Title = options.Name or options.Title or "Color",
            Desc = options.Description,
            Flag = options.Flag,
            Default = options.Color,
            Callback = function(value)
                state._update(value)
                state.Color = value
                if options.Callback then options.Callback(value) end
            end,
        })
        state._raw = raw; addFlag(options.Flag, state); return state
    end
    function tab:CreateLabel(text)
        return rawTab:Paragraph({ Title = tostring(text or ""), Desc = "" })
    end
    function tab:CreateKeybind(options)
        options = options or {}
        local state = makeControl(nil, { Kind = "Keybind", CurrentKeybind = options.CurrentKeybind, Value = options.CurrentKeybind })
        local raw = rawTab:Keybind({
            Title = options.Name or options.Title or "Keybind", Desc = options.Description,
            Flag = options.Flag, Value = options.CurrentKeybind,
            Callback = function(value)
                state._update(value)
                if options.Callback then options.Callback(value) end
            end,
        })
        state._raw = raw
        pcall(function()
            raw:OnChanged(function(value) state._update(value) end)
        end)
        addFlag(options.Flag, state); return state
    end
    return tab
end

local function createWindWindow(library, options)
    local rawWindow = library:CreateWindow({
        Title = options.Name or options.Title or "Universal Camera Pro",
        Author = "Cocoa Feliz · Creator Tools", Icon = normalizeIcon(options.Icon),
        Folder = "UniversalCamera", Size = UDim2.fromOffset(620, 560),
        Theme = (UCam.UISettings and UCam.UISettings.Theme) or "Dark",
        NewElements = true, HideSearchBar = false,
        OpenButton = { Enabled = true, Draggable = true },
    })
    local window = {}
    function window:CreateTab(title, icon)
        return createWindTab(rawWindow:Tab({ Title = title, Icon = normalizeIcon(icon) }))
    end
    function window:CreateSection(title) return rawWindow:Section({ Title = tostring(title or "") }) end
    function window:SetToggleKey(key) return callMethod(rawWindow, { "SetToggleKey", "SetMinimizeKey" }, key) end
    function window:Destroy() return callMethod(rawWindow, { "Destroy" }) end
    window._raw = rawWindow
    callMethod(rawWindow, { "SetToggleKey", "SetMinimizeKey" }, options.ToggleUIKeybind)
    return window
end

local function createProvider()
    local library = config.Preferred == "WindUI" and loadWindUI() or nil
    if library then
        provider.Name, provider.Library = "WindUI", library
        provider.CreateWindow = function(_, options)
            provider.Window = createWindWindow(library, options or {})
            return provider.Window
        end
        provider.Notify = function(_, options) return library:Notify(options) end
        provider.Destroy = function() if provider.Window then provider.Window:Destroy() end end
        provider.SetTheme = function(_, theme) return callMethod(library, { "SetTheme", "ChangeTheme" }, theme) end
        return
    end
    if config.FallbackEnabled then
        local fallback, err = loadRayfield()
        if fallback then
            provider.Name, provider.Library = "Rayfield", fallback
            provider.Flags = fallback.Flags or provider.Flags
            provider.CreateWindow = function(_, options)
                provider.Window = fallback:CreateWindow(options or {})
                provider.Flags = fallback.Flags or provider.Flags
                return provider.Window
            end
            provider.Notify = function(_, options) return fallback:Notify(options) end
            provider.Destroy = function() pcall(function() fallback:Destroy() end) end
            provider.SetTheme = function(_, theme) return callMethod(fallback, { "SetTheme", "ChangeTheme" }, theme) end
            return
        end
        provider.Error = err
    end
end

createProvider()
config.Active = provider.Name
UCam.UI = provider
UCam.Rayfield = provider
if provider.Name == "Unavailable" then error("[Universal Camera] No se pudo cargar WindUI ni Rayfield: " .. tostring(provider.Error)) end
