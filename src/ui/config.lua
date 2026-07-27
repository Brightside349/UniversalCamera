-- ============================================================
-- Universal Camera Pro v6 · ui/config
-- Pestaña Ajustes: solo keybinds (Restablecer se fue a Inicio).
-- ============================================================
local UCam = _G.UCam

function UCam.build_config(Window)
    local ConfigTab = Window:CreateTab("⚙️ Ajustes", "settings")

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
end
