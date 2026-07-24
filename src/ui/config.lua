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
end
