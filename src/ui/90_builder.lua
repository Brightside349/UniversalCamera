-- ============================================================
-- Universal Camera Pro v10.5 · UI builder
-- Construye la ventana, tabs estáticos/dinámicos y autosave.
--
-- Dependencias: core/00_config.lua, core/05_persistence.lua,
--               ui/00_registry.lua y todos los ui/tabs/*.lua.
-- ============================================================
local UCam = _G.UCam

function UCam.buildUI()
    local Window = UCam.Rayfield:CreateWindow({
        Name = "Universal Camera Pro v10.5 By Cocoa Feliz",
        LoadingTitle = "Universal Camera Pro v10.5",
        LoadingSubtitle = "Cargando Creator tools locales...",
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
