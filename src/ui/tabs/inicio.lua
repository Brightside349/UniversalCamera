-- ============================================================
-- Universal Camera Pro v12.5 · ui/inicio
-- Pestaña Inicio: camara libre, HUD unificado y visibilidad del personaje.
--
-- v12.5: se elimino "Recuperacion V10" (recuperar/diagnostico) y
-- "Acciones rapidas" (captura, teletransporte y reset global), ademas del
-- dump de debug. El HUD tiene un unico comportamiento automatico (se
-- oculta al activar la camara libre) y un toggle manual.
-- ============================================================
local UCam = _G.UCam

function UCam.build_inicio(Window)
    local InicioTab = Window:CreateTab("🎬 Inicio", "home")

    InicioTab:CreateSection("Cámara Libre")
    InicioTab:CreateButton({
        Name     = "Activar / Desactivar Cámara",
        Callback = UCam.toggleFreeCam,
    })

    InicioTab:CreateToggle({
        Name         = "Ocultar HUD",
        CurrentValue = UCam.Hud.ManualHidden,
        Callback     = function(v) UCam.setHudManual(v) end,
    })

    InicioTab:CreateParagraph({
        Title   = "HUD automático",
        Content = "El HUD del juego se oculta solo al activar la cámara libre y vuelve al desactivarla. El toggle de arriba sirve para ocultarlo a mano sin usar la cámara libre.",
    })

    InicioTab:CreateToggle({
        Name         = "Ocultar Mi Personaje",
        CurrentValue = UCam.Hud.CharacterHidden,
        Callback     = UCam.setCharacterHidden,
    })

    InicioTab:CreateSection("Notificaciones")
    InicioTab:CreateButton({
        Name     = "🔔 Silenciar / restaurar notificaciones",
        Callback = function()
            local ncfg = UCam.Config.Notifications
            if ncfg.Mode ~= "silent" then
                ncfg._lastMode = ncfg.Mode
                ncfg.Mode = "silent"
            else
                ncfg.Mode = ncfg._lastMode or "all"
            end
        end,
    })
end
