-- ============================================================
-- Universal Camera Pro v8 · 90_init
-- Paso final: carga la configuracion persistida, llama a
-- UCam.buildUI(), notifica que arranco, declara
-- UCam.Initialized = true y define UCam.Unload().
--
-- v8: Unload() ahora limpia TODO via el registry central
-- (conexiones + instancias trackeadas por trackConnection /
-- trackInstance en cada modulo) y guarda la config en disco.
-- ============================================================
local UCam = _G.UCam

if type(UCam.buildUI) ~= "function" then
    warn("[UCam] buildUI() no registrado. 80_ui.lua probablemente no se cargo.")
    return
end

-- ============================================================
-- UNLOAD: apaga modulos, restaura estado, desconecta TODO
-- ============================================================
function UCam.Unload()
    pcall(function()
        -- Guardar config antes de limpiar (v8)
        if UCam.saveConfig then pcall(UCam.saveConfig) end

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
        if UCam.destroyCustomSky then UCam.destroyCustomSky() end
        if UCam.clearPathVisualizer then UCam.clearPathVisualizer() end
        if UCam.stopSpectate then UCam.stopSpectate() end
        -- v8.1 FIX: restauración forzada que NO pasa por el debounce de
        -- toggleFreeCam (que podía dejar cámara Scriptable + personaje anclado).
        -- También cubre el caso de solo Director/Replay activos.
        if UCam.forceRestoreCamera then pcall(UCam.forceRestoreCamera) end
        if UCam.directorTogglePlay and UCam.Director and UCam.Director.Active then
            pcall(function() UCam.directorTogglePlay(false) end)
        end
        if UCam.stopPlayback then pcall(UCam.stopPlayback) end
        if UCam.Spectate and UCam.Spectate.Active and UCam.stopSpectate then UCam.stopSpectate() end
        -- v8: detener todos los plugins (llama a su stop() si lo tienen)
        if UCam.stopAllPlugins then UCam.stopAllPlugins() end
        -- v8 FIX: stopSlowMoTracking desconecta también las conexiones
        -- internas plr.CharacterAdded (_playerCharConns) que solo él conoce.
        -- Sin esto, recargar con Bullet Time activo seguía fugando conexiones.
        if UCam.stopSlowMoTracking then UCam.stopSlowMoTracking() end
        -- v8: detener los nuevos módulos de la Fase 3
        if UCam.stopCombos then UCam.stopCombos() end
        if UCam.stopMacros then UCam.stopMacros() end
        if UCam.stopAudio then UCam.stopAudio() end
        if UCam.stopFiltersPro then UCam.stopFiltersPro(false) end
        -- v8 fase 4: detener el monitor de performance
        if UCam.stopPerformance then UCam.stopPerformance() end

        -- Heartbeat connections de modulos con su propio loop
        if UCam.Fun._connHeartbeat then
            pcall(function() UCam.Fun._connHeartbeat:Disconnect() end)
            UCam.Fun._connHeartbeat = nil
        end
        if UCam.Poses._connHeartbeat then
            pcall(function() UCam.Poses._connHeartbeat:Disconnect() end)
            UCam.Poses._connHeartbeat = nil
        end
        if UCam.BodyColor._connHeartbeat then
            pcall(function() UCam.BodyColor._connHeartbeat:Disconnect() end)
            UCam.BodyColor._connHeartbeat = nil
        end
        if UCam.PlayerMod._connHeartbeat then
            pcall(function() UCam.PlayerMod._connHeartbeat:Disconnect() end)
            UCam.PlayerMod._connHeartbeat = nil
        end
        if UCam._viewportResizeConn then
            pcall(function() UCam._viewportResizeConn:Disconnect() end)
            UCam._viewportResizeConn = nil
        end
        if UCam.SlowMo.DescendantConn then
            pcall(function() UCam.SlowMo.DescendantConn:Disconnect() end)
            UCam.SlowMo.DescendantConn = nil
        end
        if UCam.SlowMo.CharacterAdded then
            pcall(function() UCam.SlowMo.CharacterAdded:Disconnect() end)
            UCam.SlowMo.CharacterAdded = nil
        end

        -- v8: limpieza TOTAL via registry central
        -- Desconecta BindToRenderStep, InputBegan/Ended/Changed,
        -- RenderStepped, Heartbeat slow-mo, GetPropertyChangedSignal,
        -- CharacterAdded, y cualquier otra conexion trackeada.
        if UCam.cleanupConnections then UCam.cleanupConnections() end
        -- Destruye instancias trackeadas (parts de visualizador, etc.)
        if UCam.cleanupInstances then UCam.cleanupInstances() end

        -- Destruir la UI de Rayfield por completo
        if UCam.Rayfield and UCam.Rayfield.Destroy then
            pcall(function() UCam.Rayfield:Destroy() end)
        end
        -- v8 FIX: soltar la referencia a la Window destruida
        UCam._window = nil

        -- Restaurar iluminacion del juego
        if UCam.applyLightingTweaks then
            UCam.LightingTweaks.Enabled = false
            pcall(UCam.applyLightingTweaks)
        end
    end)
    UCam.Initialized = false
end

-- ============================================================
-- v8: AUTO-LOAD de la config persistida antes de construir la UI
-- ============================================================
if UCam.initPersistence then
    pcall(UCam.initPersistence)
end

local ok, err = pcall(function()
    UCam.buildUI()
end)

if ok then
    UCam.Initialized = true
    -- v8: invocar start() de todos los plugins ya cargados
    if UCam.Plugins and UCam.Plugins.Loaded then
        for name, p in pairs(UCam.Plugins.Loaded) do
            if p.startFn then
                task.defer(function()
                    local ok, err = pcall(p.startFn, UCam)
                    if not ok then warn(("[UCam] Plugin '%s' start falló: %s"):format(name, tostring(err))) end
                end)
            end
        end
    end

    UCam.notify(
        "Universal Camera Pro v8 By Cocoa Feliz",
        "v8: Persistencia + Perfiles + Plugins + i18n + Replay 2.0 • Auto-limpieza. Presiona Delete para UI."
    )
    print("[UCam] Universal Camera Pro v8 cargado OK. Módulos nuevos: Persistencia, i18n, Perfiles, Replay 2.0, Plugins.")
else
    warn("[UCam] Error al construir la UI: " .. tostring(err))
end
