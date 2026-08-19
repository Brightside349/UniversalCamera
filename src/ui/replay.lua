-- ============================================================
-- Universal Camera Pro v8.1 · ui/replay REMASTERIZADO
-- Pestaña Replay / Grabación: grabar recorrido de cámara LIBRE,
-- reproducir con scrubbing, velocidad variable, guardar hasta
-- 3 rutas y exportar/importar por string.
--
-- v10: los marcadores y la edición básica viven en la pestaña Creator;
-- Replay conserva su flujo principal de grabar/reproducir.
-- ============================================================
local UCam = _G.UCam

function UCam.build_replay(Window)
    local Tab = Window:CreateTab("🎬 Replay", "film")

    -- --------------------------------------------------------
    -- SECCIÓN: Introducción
    -- --------------------------------------------------------
    Tab:CreateSection("Replay de Cámara Libre")
    Tab:CreateParagraph({
        Title   = "¿Qué es Replay?",
        Content = "Graba tu recorrido con la CÁMARA LIBRE activada. El sistema captura tu movimiento manual y lo puede reproducir después de forma suave, como una alternativa al modo Director pero sin waypoints.",
    })
    
    Tab:CreateParagraph({
        Title   = "⚠️ Importante",
        Content = "Debes tener la CÁMARA LIBRE activada para poder grabar. Si se desactiva durante la grabación, esta se detendrá automáticamente.",
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Grabación
    -- --------------------------------------------------------
    Tab:CreateSection("Grabación")

    Tab:CreateDropdown({
        Name            = "Duración máxima",
        Options         = { "30s", "60s", "120s", "180s" },
        CurrentOption   = { "60s" },
        MultipleOptions = false,
        Flag            = "ReplayMaxDuration",
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = { ["30s"] = 30, ["60s"] = 60, ["120s"] = 120, ["180s"] = 180 }
            UCam.Replay.MaxDuration = map[v] or 60
        end,
    })

    Tab:CreateButton({
        Name     = "⏺  Iniciar Grabación",
        Callback = function()
            if UCam.Replay.Recording then
                UCam.notify("Replay", "Ya está grabando. Detén la grabación primero.", 3)
                return
            end
            UCam.startRecording()
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener Grabación",
        Callback = function()
            if not UCam.Replay.Recording then
                UCam.notify("Replay", "No hay grabación activa.", 3)
                return
            end
            UCam.stopRecording()
        end,
    })

    Tab:CreateParagraph({
        Title   = "Estado",
        Content = "Cuando detengas la grabación verás cuántos frames se capturaron y la duración total del recorrido.",
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Reproducción
    -- --------------------------------------------------------
    Tab:CreateSection("Reproducción")

    Tab:CreateButton({
        Name     = "▶  Reproducir",
        Callback = function()
            if UCam.Replay.Playing and not UCam.Replay.Paused then
                UCam.notify("Replay", "Ya está reproduciendo.", 3)
                return
            end
            if UCam.Replay.Playing then
                -- Estaba en pausa, reanudar
                UCam.pausePlayback()
            else
                UCam.startPlayback()
            end
        end,
    })

    Tab:CreateButton({
        Name     = "⏸  Pausa / Reanudar",
        Callback = function()
            if not UCam.Replay.Playing then
                UCam.notify("Replay", "No hay reproducción activa.", 3)
                return
            end
            UCam.pausePlayback()
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener Reproducción",
        Callback = function()
            UCam.stopPlayback()
        end,
    })

    Tab:CreateToggle({
        Name         = "Loop (repetir en bucle)",
        CurrentValue = UCam.Replay.Loop,
        Flag         = "ReplayLoop",
        Callback     = function(v)
            UCam.Replay.Loop = v
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Timeline (Scrubbing)
    -- --------------------------------------------------------
    Tab:CreateSection("Timeline (Navegación)")
    Tab:CreateParagraph({
        Title   = "Scrubbing",
        Content = "Mueve el slider para saltar a cualquier momento de la grabación. Funciona tanto en pausa como durante la reproducción.",
    })

    Tab:CreateSlider({
        Name         = "Posición en el recorrido",
        Range        = { 0, 180 }, -- v9 FIX: cubre la duración máxima configurable (180s); el callback clampa al real
        Increment    = 0.5,
        Suffix       = "s",
        CurrentValue = 0,
        Flag         = "ReplaySeekPosition",
        Callback     = function(v)
            if #UCam.Replay.Frames < 2 then
                UCam.notify("Replay", "No hay grabación cargada.", 3, { important = true })
                return
            end
            local maxT = UCam.Replay.Frames[#UCam.Replay.Frames].t
            local clamped = math.clamp(v, 0, maxT)
            UCam.seekReplay(clamped)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Velocidad
    -- --------------------------------------------------------
    Tab:CreateSection("Velocidad de Reproducción")

    Tab:CreateDropdown({
        Name            = "Velocidad",
        Options         = { "0.25x", "0.5x", "0.75x", "1x", "1.5x", "2x", "4x" },
        CurrentOption   = { "1x" },
        MultipleOptions = false,
        Flag            = "ReplayPlaybackSpeed",
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = {
                ["0.25x"] = 0.25,
                ["0.5x"]  = 0.5,
                ["0.75x"] = 0.75,
                ["1x"]    = 1.0,
                ["1.5x"]  = 1.5,
                ["2x"]    = 2.0,
                ["4x"]    = 4.0,
            }
            local speed = map[v] or 1.0
            UCam.setPlaybackSpeed(speed)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Rutas Guardadas
    -- --------------------------------------------------------
    Tab:CreateSection("Rutas Guardadas")
    Tab:CreateParagraph({
        Title   = "Gestión de Rutas",
        Content = "Guarda tu grabación actual en una de las 3 ranuras disponibles. Carga una ranura para hacer ese recorrido la grabación activa.",
    })

    local selectedSlot = 1
    Tab:CreateDropdown({
        Name            = "Ranura",
        Options         = { "Ranura 1", "Ranura 2", "Ranura 3" },
        CurrentOption   = { "Ranura 1" },
        MultipleOptions = false,
        Flag            = "ReplaySelectedSlot",
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = { ["Ranura 1"] = 1, ["Ranura 2"] = 2, ["Ranura 3"] = 3 }
            selectedSlot = map[v] or 1
        end,
    })

    Tab:CreateButton({
        Name     = "💾  Guardar en Ranura",
        Callback = function()
            UCam.saveCurrentRoute(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "📂  Cargar Ranura",
        Callback = function()
            UCam.loadRoute(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Eliminar Ranura",
        Callback = function()
            UCam.deleteRoute(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "ℹ️  Ver Info de Ranuras",
        Callback = function()
            local lines = {}
            for i = 1, 3 do
                local r = UCam.Replay.SavedRoutes[i]
                if r then
                    table.insert(lines, string.format(
                        "Ranura %d: %d frames / %s",
                        i, r.count,
                        UCam.Replay.getFormattedTime(r.duration)
                    ))
                else
                    table.insert(lines, string.format("Ranura %d: vacía", i))
                end
            end
            UCam.notify("Replay — Ranuras", table.concat(lines, "\n"), 6)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Exportar / Importar
    -- --------------------------------------------------------
    Tab:CreateSection("Exportar / Importar")
    Tab:CreateParagraph({
        Title   = "Compartir Recorridos",
        Content = "Exporta tu recorrido a un string compacto para compartirlo. Importa un string de otra persona para cargar su ruta.",
    })

    Tab:CreateButton({
        Name     = "📋  Copiar Ruta al Portapapeles",
        Callback = function()
            if #UCam.Replay.Frames < 2 then
                UCam.notify("Replay", "No hay grabación activa para exportar.", 3)
                return
            end
            local str = UCam.serializeRoute()
            if str == "" then
                UCam.notify("Replay", "Error al serializar la ruta.", 3, { important = true })
                return
            end
            local ok = pcall(function() setclipboard(str) end)
            if ok then
                UCam.notify("Replay",
                    string.format("Ruta copiada (%d caracteres).", #str))
            else
                UCam.notify("Replay",
                    "setclipboard no disponible. String en consola.", 3)
                print("[UCam Replay] Ruta serializada:\n" .. str)
            end
        end,
    })

    Tab:CreateButton({
        Name = "📄 Exportar keyframes legibles",
        Callback = function()
            local textValue, err = UCam.exportReplayKeyframes()
            if not textValue then UCam.notify("Replay", err or "No hay frames.", 3); return end
            local ok = pcall(function() setclipboard(textValue) end)
            if ok then UCam.notify("Replay", "Keyframes copiados al portapapeles.")
            else print("[UCam Keyframes]\n" .. textValue); UCam.notify("Replay", "Exportados en consola.") end
        end,
    })

    local importStr = ""
    Tab:CreateInput({
        Name        = "Pegar String de Ruta",
        PlaceholderText = "Pega el string aquí...",
        RemoveTextAfterFocusLost = false,
        Flag        = "ReplayImportString",
        Callback    = function(v)
            importStr = v or ""
        end,
    })

    Tab:CreateButton({
        Name     = "📥  Importar Ruta",
        Callback = function()
            if not importStr or importStr == "" then
                UCam.notify("Replay", "El campo de importación está vacío.", 3, { important = true })
                return
            end
            local frames = UCam.deserializeRoute(importStr)
            if not frames then
                UCam.notify("Replay", "String inválido o demasiado corto.", 3, { important = true })
                return
            end
            table.clear(UCam.Replay.Frames)
            for i, f in ipairs(frames) do
                UCam.Replay.Frames[i] = f
            end
            UCam.Replay.CurrentTime = 0
            if UCam.clearReplayMarkers then UCam.clearReplayMarkers() end
            UCam.notify("Replay",
                string.format("Ruta importada: %d frames / %s",
                    #frames,
                    UCam.Replay.getFormattedTime(frames[#frames].t)))
        end,
    })

    Tab:CreateSection("Timelapse v9")
    Tab:CreateSlider({
        Name = "Intervalo de captura",
        Range = { 0.5, 10 }, Increment = 0.5, Suffix = "s",
        CurrentValue = UCam.Timelapse.Interval,
        Callback = function(v) UCam.Timelapse.Interval = tonumber(v) or 2 end,
    })
    Tab:CreateToggle({
        Name = "Capturar timelapse",
        CurrentValue = UCam.Timelapse.Active,
        Callback = function(v)
            local ok, err = UCam.toggleTimelapse(v)
            if not ok and v then UCam.notify("Timelapse", err or "No se pudo iniciar.", 3) end
        end,
    })
    Tab:CreateButton({
        Name = "Detener y reproducir timelapse",
        Callback = function()
            local count = UCam.stopTimelapse()
            if count >= 2 then UCam.startPlayback() else UCam.notify("Timelapse", "Captura insuficiente.", 3) end
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Acciones
    -- --------------------------------------------------------
    Tab:CreateSection("Acciones Globales")

    Tab:CreateButton({
        Name     = "🗑️  Limpiar Grabación Actual",
        Callback = function()
            if UCam.Replay.Recording or UCam.Replay.Playing then
                UCam.stopReplay()
            else
                table.clear(UCam.Replay.Frames)
                if UCam.clearReplayMarkers then UCam.clearReplayMarkers() end
                UCam.Replay.CurrentTime = 0
                UCam.notify("Replay", "Grabación actual eliminada.")
            end
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener TODO",
        Callback = function()
            UCam.stopReplay()
            UCam.notify("Replay", "Todo detenido y grabación limpiada.")
        end,
    })
    
    -- --------------------------------------------------------
    -- SECCIÓN: Info
    -- --------------------------------------------------------
    Tab:CreateSection("Información")
    Tab:CreateParagraph({
        Title   = "¿Cómo usar Replay?",
        Content = [[
1. Activa la CÁMARA LIBRE (F)
2. Presiona "Iniciar Grabación"
3. Muévete libremente por el escenario
4. Presiona "Detener Grabación"
5. Presiona "Reproducir" para ver tu recorrido
6. Guarda en una ranura para no perderlo

El Replay funciona como un Director sin waypoints: graba tu movimiento manual y lo reproduce suavemente.
        ]]
    })
end
