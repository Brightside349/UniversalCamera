-- ============================================================
-- Universal Camera Pro v7 · 90_init
-- Paso final: llama a UCam.buildUI(), notifica que arrancó,
-- declara UCam.Initialized = true y define UCam.Unload().
-- ============================================================
local UCam = _G.UCam

if type(UCam.buildUI) ~= "function" then
    warn("[UCam] buildUI() no registrado. 80_ui.lua probablemente no se cargo.")
    return
end

function UCam.Unload()
    pcall(function()
        -- Stop all active modules
        if UCam.stopFun then UCam.stopFun() end
        if UCam.stopAdvPoses then UCam.stopAdvPoses() end
        if UCam.stopBodyColor then UCam.stopBodyColor() end
        if UCam.stopPlayerMod then UCam.stopPlayerMod() end
        if UCam.restoreAllPlayers then UCam.restoreAllPlayers() end
        if UCam.stopTimeControl then UCam.stopTimeControl() end
        if UCam.stopReplay then UCam.stopReplay() end
        if UCam.destroyGreenScreen then UCam.destroyGreenScreen() end
        if UCam.destroyLetterbox then UCam.destroyLetterbox() end
        if UCam.destroyVignetteGui then UCam.destroyVignetteGui() end
        if UCam.destroyChromaticGui then UCam.destroyChromaticGui() end
        if UCam.destroyPiP then UCam.destroyPiP() end
        if UCam.stopSpectate then UCam.stopSpectate() end
        if UCam.freeCamEnabled and UCam.toggleFreeCam then UCam.toggleFreeCam() end
        if UCam.Spectate and UCam.Spectate.Active and UCam.stopSpectate then UCam.stopSpectate() end
        
        -- Disconnect heartbeat connections
        if UCam.Fun._connHeartbeat then
            UCam.Fun._connHeartbeat:Disconnect()
            UCam.Fun._connHeartbeat = nil
        end
        if UCam.Poses._connHeartbeat then
            UCam.Poses._connHeartbeat:Disconnect()
            UCam.Poses._connHeartbeat = nil
        end
        if UCam.BodyColor._connHeartbeat then
            UCam.BodyColor._connHeartbeat:Disconnect()
            UCam.BodyColor._connHeartbeat = nil
        end
        if UCam.PlayerMod._connHeartbeat then
            UCam.PlayerMod._connHeartbeat:Disconnect()
            UCam.PlayerMod._connHeartbeat = nil
        end
        -- Disconnect v7 ViewportSize resize listener (letterbox + radial vignette)
        if UCam._viewportResizeConn then
            UCam._viewportResizeConn:Disconnect()
            UCam._viewportResizeConn = nil
        end
    end)
    UCam.Initialized = false
    UCam.notify("Universal Camera Pro v7", "Script descargado y limpiado completamente.")
end

local ok, err = pcall(function()
    UCam.buildUI()
end)

if ok then
    UCam.Initialized = true
    UCam.notify(
        "Universal Camera Pro v7 By Cocoa Feliz",
        "v7 Cargado: 19+ Poses Avanzadas • Coloreo por Partes • Mod Jugadores Local • Control de Tiempo • Replay de Cámara • 5 Nuevas Pestañas. Presiona Delete para UI."
    )
    print("[UCam] Universal Camera Pro v7 cargado OK. Nuevos módulos: Poses, BodyColor, PlayerMod, TimeControl, Replay.")
else
    warn("[UCam] Error al construir la UI: " .. tostring(err))
end
