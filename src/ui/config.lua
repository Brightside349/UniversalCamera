-- ============================================================
-- Universal Camera Pro v8 · ui/config
-- Pestaña Ajustes: keybinds, idioma (i18n) y gestión de plugins.
-- ============================================================
local UCam = _G.UCam

function UCam.build_config(Window)
    local T = UCam.T
    local ConfigTab = Window:CreateTab(T("tab_config"), "settings")

    ConfigTab:CreateSection("Teclas")
    ConfigTab:CreateKeybind({
        Name           = "Tecla Camara Libre",
        CurrentKeybind = "F",
        HoldToInteract = false,
        Callback       = function() UCam.toggleFreeCam() end,
    })
    ConfigTab:CreateKeybind({
        Name           = "Dejar de espectar",
        CurrentKeybind = "X",
        HoldToInteract = false,
        Callback       = function()
            if UCam.Spectate.Active then UCam.stopSpectate() end
        end,
    })
    ConfigTab:CreateKeybind({
        Name           = "Siguiente jugador",
        CurrentKeybind = "E",
        HoldToInteract = false,
        Callback       = function()
            if UCam.Spectate.Active then UCam.spectateNextPlayer() end
        end,
    })
    ConfigTab:CreateKeybind({
        Name           = "Anterior jugador",
        CurrentKeybind = "Q",
        HoldToInteract = false,
        Callback       = function()
            if UCam.Spectate.Active then UCam.spectatePrevPlayer() end
        end,
    })
    ConfigTab:CreateKeybind({
        Name           = "Disparar Camera Shake",
        CurrentKeybind = "Z",
        HoldToInteract = false,
        Callback       = function() UCam.triggerShake(UCam.Shake.Pattern) end,
    })

    -- ===== v7: Teclas de MOVIMIENTO personalizables =====
    -- Cada keybind guarda la tecla elegida en UCam.Keybinds[action].
    -- Rayfield dispara el Callback al pulsar la tecla; aprovechamos para
    -- sincronizar el Flag con UCam.Keybinds.
    ConfigTab:CreateSection("v7 - Teclas de movimiento (personalizables)")

    local function makeMoveKeybind(action, label, defaultKey)
        ConfigTab:CreateKeybind({
            Name           = label,
            CurrentKeybind = defaultKey,
            HoldToInteract = false,
            Flag           = "UCamKeybind_" .. action,
            Callback       = function()
                -- Sincroniza la tecla elegida con UCam.Keybinds[action].
                -- Rayfield expone el valor en UCam.Rayfield.Flags[flag].CurrentKeybind.
                pcall(function()
                    local flag = UCam.Rayfield.Flags["UCamKeybind_" .. action]
                    local key = flag and (flag.CurrentKeybind or flag.Value)
                    if key then
                        UCam.Keybinds[action] = tostring(key)
                    end
                end)
            end,
        })
    end

    makeMoveKeybind("Forward",  "Avanzar",        UCam.Keybinds.Forward or "W")
    makeMoveKeybind("Backward", "Retroceder",      UCam.Keybinds.Backward or "S")
    makeMoveKeybind("Left",     "Mover izquierda", UCam.Keybinds.Left or "A")
    makeMoveKeybind("Right",    "Mover derecha",   UCam.Keybinds.Right or "D")
    makeMoveKeybind("Up",       "Subir",           UCam.Keybinds.Up or "Space")
    makeMoveKeybind("Down",     "Bajar",           UCam.Keybinds.Down or "LeftControl")
    makeMoveKeybind("Sprint",   "Sprint",          UCam.Keybinds.Sprint or "LeftShift")

    ConfigTab:CreateButton({
        Name = "Restablecer teclas por defecto (WASD)",
        Callback = function()
            UCam.Keybinds.Forward  = "W"
            UCam.Keybinds.Backward = "S"
            UCam.Keybinds.Left     = "A"
            UCam.Keybinds.Right    = "D"
            UCam.Keybinds.Up       = "Space"
            UCam.Keybinds.Down     = "LeftControl"
            UCam.Keybinds.Sprint   = "LeftShift"
            UCam.notify("Ajustes", "Teclas restablecidas. Recarga la UI para reflejarlas en los campos.")
        end,
    })

    -- ========================================================
    -- v8: IDIOMA (i18n)
    -- ========================================================
    ConfigTab:CreateSection("Idioma / Language / Idioma")

    local localeDisplay = {}
    local localeCodes   = UCam.getAvailableLocales()
    for _, code in ipairs(localeCodes) do
        localeDisplay[#localeDisplay+1] = ("%s (%s)"):format(
            UCam.getLocaleDisplayName(code), code)
    end

    ConfigTab:CreateDropdown({
        Name            = "Seleccionar idioma",
        Options         = localeDisplay,
        CurrentOption   = { ("%s (%s)"):format(UCam.getLocaleDisplayName(UCam.Locale), UCam.Locale) },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            -- el codigo está entre paréntesis al final: "Español (es)"
            local code = v:match("%(([%a]+)%)%s*$")
            if code then
                UCam.setLocale(code)
            end
        end,
    })

    ConfigTab:CreateParagraph({
        Title   = "Nota",
        Content = "El cambio de idioma se guarda automáticamente. Recarga el script (o reinicia) para que toda la UI se reconstruya en el nuevo idioma.",
    })

    -- ========================================================
    -- v8: PERFORMANCE MONITOR (debug)
    -- ========================================================
    ConfigTab:CreateSection("Performance (debug)")

    ConfigTab:CreateParagraph({
        Title   = "Monitor de Frame Budget",
        Content = "Mide el tiempo que tarda cada módulo (updateCamera, fun, replay, timeControl) por frame. Alerta si alguno supera 3ms. Los reportes van a la consola cada 5s.",
    })

    ConfigTab:CreateToggle({
        Name         = "Monitor de Performance",
        CurrentValue = UCam.Performance and UCam.Performance.Enabled or false,
        Callback     = function(v)
            UCam.togglePerformanceMonitor(v)
        end,
    })

    ConfigTab:CreateSlider({
        Name         = "Intervalo de reportes (segundos)",
        Range        = { 2, 30 },
        Increment    = 1,
        Suffix       = "s",
        CurrentValue = (UCam.Performance and UCam.Performance.ReportInterval) or 5,
        Callback     = function(v)
            if UCam.Performance then
                UCam.Performance.ReportInterval = tonumber(v) or 5
            end
        end,
    })

    ConfigTab:CreateSlider({
        Name         = "Umbral de alerta (ms)",
        Range        = { 0.5, 10 },
        Increment    = 0.5,
        Suffix       = "ms",
        CurrentValue = (UCam.Performance and UCam.Performance.AlertThreshold) or 1.5,
        Callback     = function(v)
            if UCam.Performance then
                UCam.Performance.AlertThreshold = tonumber(v) or 1.5
            end
        end,
    })

    ConfigTab:CreateButton({
        Name     = "ℹ️  Reporte actual",
        Callback = function()
            if UCam.Performance then
                UCam.notify("Performance", UCam.getPerfReport(), 8)
            end
        end,
    })

    ConfigTab:CreateButton({
        Name     = "🧹  Resetear tracker",
        Callback = function()
            UCam.resetPerfTracker()
            UCam.notify("Performance", "Tracker reiniciado.")
        end,
    })

    ConfigTab:CreateParagraph({
        Title   = "Uso",
        Content = "1. Activa el monitor\n2. Usa la UI normalmente\n3. Mira el reporte en consola\n4. Desactiva el monitor cuando no lo necesites",
    })

    -- ========================================================
    -- v8: PLUGINS
    -- ========================================================
    ConfigTab:CreateSection("Plugins")

    ConfigTab:CreateParagraph({
        Title   = "Sistema de plugins",
        Content = "Los plugins son archivos .lua en Universal Camera/plugins/. Cada archivo debe: return { name=..., author=..., build=function(Window) ... end }. Se cargan al iniciar automáticamente.",
    })

    ConfigTab:CreateButton({
        Name     = "🔄  Recargar plugins desde disco",
        Callback = function()
            -- Limpiar los actuales (solo los no-default para no perder UCam internos)
            UCam.stopAllPlugins()
            local n = UCam.loadPluginsFromFolder()
            if n > 0 then
                UCam.notify("Plugins", n .. " plugin(s) recargado(s). Recarga la UI para ver los cambios.")
            else
                UCam.notify("Plugins", "No se encontraron plugins en UniversalCamera/plugins/")
            end
        end,
    })

    ConfigTab:CreateButton({
        Name     = "ℹ️  Listar plugins cargados",
        Callback = function()
            local list = {}
            for name, p in pairs(UCam.Plugins.Loaded) do
                list[#list+1] = ("%s v%s — %s"):format(name, p.version or "?", p.author or "?")
            end
            if #list == 0 then
                UCam.notify("Plugins", "Ninguno cargado.")
            else
                UCam.notify("Plugins (" .. #list .. ")", table.concat(list, "\n"), 8)
            end
        end,
    })

    ConfigTab:CreateButton({
        Name     = "🗑️  Detener todos los plugins",
        Callback = function()
            UCam.stopAllPlugins()
            UCam.notify("Plugins", "Todos los plugins detenidos (limpiar UI requiere recargar).")
        end,
    })

    ConfigTab:CreateParagraph({
        Title   = "Crear un plugin",
        Content = "Ejemplo mínimo:\n\n" ..
                  "return {\n" ..
                  "  name='Mi Plugin', version='1.0',\n" ..
                  "  build=function(W) W:CreateTab('MiTab'):CreateButton({Name='Hola'}) end\n" ..
                  "}",
    })
end
