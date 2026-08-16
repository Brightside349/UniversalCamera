-- ============================================================
-- Universal Camera Pro v7 · ui/replay
-- Pestaña Replay / Grabación: grabar sesión de cámara,
-- reproducir con scrubbing, velocidad variable, guardar hasta
-- 3 rutas y exportar/importar por string.
-- ============================================================
local UCam = _G.UCam

function UCam.build_replay(Window)
    local Tab = Window:CreateTab("🎬 Replay", "film")

    -- v8: índice del marcador seleccionado para eliminar (closure, no _G)
    local markerSelectedIdx = 1

    -- --------------------------------------------------------
    -- SECCIÓN: Grabación
    -- --------------------------------------------------------
    Tab:CreateSection("Grabación de cámara")
    Tab:CreateParagraph({
        Title   = "¿Cómo funciona?",
        Content = "Graba la posición y FOV de tu cámara a 30fps. Luego puedes reproducir, pausar, hacer scrubbing y guardar la ruta para usarla después. Funciona en cualquier modo de cámara.",
    })

    Tab:CreateDropdown({
        Name            = "Duración máxima",
        Options         = { "30s", "60s", "120s" },
        CurrentOption   = { "60s" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = { ["30s"] = 30, ["60s"] = 60, ["120s"] = 120 }
            UCam.Replay.MaxDuration = map[v] or 60
        end,
    })

    Tab:CreateButton({
        Name     = "⏺  Grabar",
        Callback = function()
            if UCam.Replay.Recording then
                UCam.notify("Replay", "Ya está grabando. Detén la grabación primero.")
                return
            end
            UCam.startRecording()
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener grabación",
        Callback = function()
            if not UCam.Replay.Recording then
                UCam.notify("Replay", "No hay grabación activa.")
                return
            end
            UCam.stopRecording()
        end,
    })

    -- Indicador de frames grabados (se actualiza con un label)
    Tab:CreateParagraph({
        Title   = "Estado de grabación",
        Content = "Usa los botones Grabar / Detener. Cuando detengas verás cuántos frames se capturaron y la duración total.",
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Reproducción
    -- --------------------------------------------------------
    Tab:CreateSection("Reproducción")

    Tab:CreateButton({
        Name     = "▶  Play",
        Callback = function()
            if UCam.Replay.Playing and not UCam.Replay.Paused then
                UCam.notify("Replay", "Ya está reproduciendo.")
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
                UCam.notify("Replay", "No hay reproducción activa.")
                return
            end
            UCam.pausePlayback()
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener reproducción",
        Callback = function()
            UCam.stopPlayback()
        end,
    })

    Tab:CreateToggle({
        Name         = "Loop (repetir en bucle)",
        CurrentValue = UCam.Replay.Loop,
        Callback     = function(v)
            UCam.Replay.Loop = v
            UCam.notify("Replay", v and "Loop activado." or "Loop desactivado.")
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Scrubbing / Timeline
    -- --------------------------------------------------------
    Tab:CreateSection("Timeline (scrubbing)")
    Tab:CreateParagraph({
        Title   = "Saltar a un punto",
        Content = "Mueve el slider para ir directamente a cualquier momento de la grabación. Funciona tanto en pausa como durante la reproducción.",
    })

    -- Slider de progreso: 0–120 segundos (se adapta a la duración real al usarlo)
    Tab:CreateSlider({
        Name         = "Posición en la grabación",
        Range        = { 0, 120 },
        Increment    = 0.5,
        Suffix       = "s",
        CurrentValue = 0,
        Callback     = function(v)
            if #UCam.Replay.Frames < 2 then
                UCam.notify("Replay", "No hay grabación cargada.")
                return
            end
            local maxT = UCam.Replay.Frames[#UCam.Replay.Frames].t
            local clamped = math.clamp(v, 0, maxT)
            UCam.seekReplay(clamped)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Velocidad de reproducción
    -- --------------------------------------------------------
    Tab:CreateSection("Velocidad de reproducción")

    Tab:CreateDropdown({
        Name            = "Velocidad",
        Options         = { "0.25x", "0.5x", "1x", "2x", "4x" },
        CurrentOption   = { "1x" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = {
                ["0.25x"] = 0.25,
                ["0.5x"]  = 0.5,
                ["1x"]    = 1.0,
                ["2x"]    = 2.0,
                ["4x"]    = 4.0,
            }
            local speed = map[v] or 1.0
            UCam.setPlaybackSpeed(speed)
            UCam.notify("Replay", "Velocidad: " .. v)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Rutas guardadas
    -- --------------------------------------------------------
    Tab:CreateSection("Rutas guardadas (hasta 3)")
    Tab:CreateParagraph({
        Title   = "Guardar y cargar rutas",
        Content = "Guarda la grabación actual en una ranura (1, 2 o 3) para no perderla. Carga una ranura para que la grabación activa sea esa ruta. Útil para comparar ángulos.",
    })

    -- Ranura seleccionada
    local selectedSlot = 1
    Tab:CreateDropdown({
        Name            = "Ranura activa",
        Options         = { "Ranura 1", "Ranura 2", "Ranura 3" },
        CurrentOption   = { "Ranura 1" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = { ["Ranura 1"] = 1, ["Ranura 2"] = 2, ["Ranura 3"] = 3 }
            selectedSlot = map[v] or 1
        end,
    })

    Tab:CreateButton({
        Name     = "💾  Guardar en ranura seleccionada",
        Callback = function()
            UCam.saveCurrentRoute(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "📂  Cargar ranura seleccionada",
        Callback = function()
            UCam.loadRoute(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Eliminar ranura seleccionada",
        Callback = function()
            UCam.deleteRoute(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "ℹ️  Ver info de ranuras",
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
            UCam.notify("Replay — Ranuras", table.concat(lines, "\n"))
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Exportar / Importar ruta
    -- --------------------------------------------------------
    Tab:CreateSection("Exportar / Importar ruta")
    Tab:CreateParagraph({
        Title   = "Compartir rutas de cámara",
        Content = "Serializa la grabación a un string compacto. Cópialo al portapapeles para compartir. Pega un string de otra persona en el campo de importación para cargar su ruta.",
    })

    Tab:CreateButton({
        Name     = "📋  Copiar ruta al portapapeles",
        Callback = function()
            if #UCam.Replay.Frames < 2 then
                UCam.notify("Replay", "No hay grabación activa para exportar.")
                return
            end
            local str = UCam.serializeRoute()
            if str == "" then
                UCam.notify("Replay", "Error al serializar la ruta.")
                return
            end
            -- Copiar al portapapeles usando setclipboard (ejecutor de exploits)
            local ok = pcall(function() setclipboard(str) end)
            if ok then
                UCam.notify("Replay",
                    string.format("Ruta copiada (%d chars). Pégala donde quieras.", #str))
            else
                UCam.notify("Replay",
                    "setclipboard no disponible en este ejecutor. String generado en consola.")
                print("[UCam Replay] Ruta serializada:\n" .. str)
            end
        end,
    })

    -- Input de importación
    local importStr = ""
    Tab:CreateInput({
        Name        = "Pegar ruta importada aquí",
        PlaceholderText = "Pega el string de la ruta...",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v)
            importStr = v or ""
        end,
    })

    Tab:CreateButton({
        Name     = "📥  Importar ruta pegada",
        Callback = function()
            if not importStr or importStr == "" then
                UCam.notify("Replay", "El campo de importación está vacío.")
                return
            end
            local frames = UCam.deserializeRoute(importStr)
            if not frames then
                UCam.notify("Replay", "String inválido o demasiado corto.")
                return
            end
            table.clear(UCam.Replay.Frames)
            for i, f in ipairs(frames) do
                UCam.Replay.Frames[i] = f
            end
            UCam.Replay.CurrentTime = 0
            UCam.notify("Replay",
                string.format("Ruta importada: %d frames / %s",
                    #frames,
                    UCam.Replay.getFormattedTime(frames[#frames].t)))
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Acciones globales
    -- --------------------------------------------------------
    Tab:CreateSection("Acciones globales")

    Tab:CreateButton({
        Name     = "🗑️  Limpiar grabación actual",
        Callback = function()
            if UCam.Replay.Recording or UCam.Replay.Playing then
                UCam.stopReplay()
            else
                table.clear(UCam.Replay.Frames)
                UCam.Replay.CurrentTime = 0
                UCam.notify("Replay", "Grabación actual eliminada.")
            end
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener TODO (replay)",
        Callback = function()
            UCam.stopReplay()
            UCam.notify("Replay", "Todo detenido y grabación limpiada.")
        end,
    })

    -- --------------------------------------------------------
    -- v8: MARCADORES con eventos
    -- --------------------------------------------------------
    Tab:CreateSection("Marcadores con eventos")
    Tab:CreateParagraph({
        Title   = "¿Qué son?",
        Content = "Un marcador dispara un evento cuando la reproducción lo cruza: shake de cámara, slow-mo, pulso de FOV, o un cambio drástico de velocidad. Útil para impactos y beats.",
    })

    local markerTime  = 0
    local markerLabel = "Hit"
    local markerAction = "shake"
    local markerValue = "Impacto"

    Tab:CreateSlider({
        Name         = "Tiempo del marcador (segundos)",
        Range        = { 0, 120 },
        Increment    = 0.1,
        Suffix       = "s",
        CurrentValue = 0,
        Callback     = function(v) markerTime = tonumber(v) or 0 end,
    })

    Tab:CreateInput({
        Name        = "Label (texto)",
        PlaceholderText = "Ej: Impacto, Beat 1, Grito…",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) markerLabel = tostring(v or "Marker") end,
    })

    Tab:CreateDropdown({
        Name            = "Acción al cruzar",
        Options         = { "shake", "slow", "fov", "speed", "none" },
        CurrentOption   = { "shake" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then markerAction = v end
        end,
    })

    Tab:CreateInput({
        Name        = "Valor de la acción",
        PlaceholderText = "shake=nombre | slow=0.3 | fov=+10 | speed=2.0",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) markerValue = tostring(v or "") end,
    })

    Tab:CreateButton({
        Name     = "➕  Agregar marcador",
        Callback = function()
            local val
            if markerAction == "shake" then
                val = (markerValue ~= "") and markerValue or "Impacto"
            else
                val = tonumber(markerValue) or nil
            end
            UCam.addMarker(markerTime, markerLabel, markerAction, val)
        end,
    })

    Tab:CreateSlider({
        Name         = "Borrar marcador (índice 1-N)",
        Range        = { 1, 20 },
        Increment    = 1,
        CurrentValue = 1,
        Callback     = function(v) markerSelectedIdx = math.floor(v) end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Borrar marcador seleccionado",
        Callback = function()
            UCam.removeMarker(markerSelectedIdx)
        end,
    })

    Tab:CreateButton({
        Name     = "🧹  Limpiar todos los marcadores",
        Callback = function()
            UCam.clearMarkers()
        end,
    })

    Tab:CreateToggle({
        Name         = "Notificar al cruzar marcadores",
        CurrentValue = UCam.Replay.ShowMarkerHUD,
        Callback     = function(v)
            UCam.Replay.ShowMarkerHUD = v
            UCam.notify("Replay", v and "Notificaciones de marcadores ON." or "Notificaciones de marcadores OFF.")
        end,
    })

    Tab:CreateButton({
        Name     = "📋  Listar marcadores",
        Callback = function()
            local ms = UCam.Replay.Markers
            if #ms == 0 then
                UCam.notify("Replay", "No hay marcadores.")
                return
            end
            local parts = {}
            for i, m in ipairs(ms) do
                parts[#parts+1] = string.format("%d) %s @ %s → %s",
                    i, m.label, UCam.Replay.getFormattedTime(m.t), m.action)
            end
            UCam.notify("Replay — Marcadores", table.concat(parts, "\n"), 8)
        end,
    })

    -- --------------------------------------------------------
    -- v8: SPEED RAMPS (velocidad variable dentro del playback)
    -- --------------------------------------------------------
    Tab:CreateSection("Speed ramps (veloc. variable)")
    Tab:CreateParagraph({
        Title   = "¿Qué son?",
        Content = "Define velocidades distintas en distintos momentos del replay. El playback interpola suavemente entre ellos: ej. lento durante el impacto, rápido en el travel.",
    })

    local rampTime  = 0
    local rampSpeed = 1.0

    Tab:CreateSlider({
        Name         = "Tiempo del punto de rampa (s)",
        Range        = { 0, 120 },
        Increment    = 0.1,
        Suffix       = "s",
        CurrentValue = 0,
        Callback     = function(v) rampTime = tonumber(v) or 0 end,
    })

    Tab:CreateSlider({
        Name         = "Velocidad en ese punto",
        Range        = { 0.1, 4 },
        Increment    = 0.05,
        Suffix       = "x",
        CurrentValue = 1.0,
        Callback     = function(v) rampSpeed = tonumber(v) or 1.0 end,
    })

    Tab:CreateButton({
        Name     = "➕  Agregar punto de rampa",
        Callback = function()
            UCam.addSpeedRamp(rampTime, rampSpeed)
        end,
    })

    Tab:CreateButton({
        Name     = "🧹  Limpiar todos los ramps",
        Callback = function()
            UCam.clearSpeedRamps()
        end,
    })

    Tab:CreateToggle({
        Name         = "Speed ramps activos",
        CurrentValue = UCam.Replay.SpeedRampEnabled,
        Callback     = function(v)
            UCam.Replay.SpeedRampEnabled = v
            UCam.notify("Replay", v and "Ramps activados." or "Ramps desactivados (usa velocidad global).")
        end,
    })

    Tab:CreateButton({
        Name     = "📋  Listar ramps",
        Callback = function()
            local rs = UCam.Replay.SpeedRamps
            if #rs == 0 then
                UCam.notify("Replay", "No hay ramps definidos.")
                return
            end
            local parts = {}
            for i, r in ipairs(rs) do
                parts[#parts+1] = string.format("%d) %s → %.2fx",
                    i, UCam.Replay.getFormattedTime(r.t), r.speed)
            end
            UCam.notify("Replay — Speed ramps", table.concat(parts, "\n"), 8)
        end,
    })

    -- --------------------------------------------------------
    -- v8: COMPARTIR RUTA (web / externo)
    -- --------------------------------------------------------
    Tab:CreateSection("Compartir ruta (web)")
    Tab:CreateParagraph({
        Title   = "Subir a internet",
        Content = "Serializa la ruta y la sube automáticamente a hastebin.rs (o pastebin si falla). Copia la URL resultante para compartirla.",
    })

    Tab:CreateButton({
        Name     = "🌐  Subir ruta y compartir URL",
        Callback = function()
            local url = UCam.shareRoute()
            if url then
                local ok = pcall(function() setclipboard(url) end)
                if ok then
                    UCam.notify("Replay", "URL copiada al portapapeles:\n" .. url)
                end
            end
        end,
    })
end
