-- ============================================================
-- Universal Camera Pro v10 · ui/creator
-- Acciones locales para creadores: captura preparada, guias,
-- escenas ampliadas y edicion basica de Replay.
-- ============================================================
local UCam = _G.UCam

function UCam.build_creator(Window)
    local Tab = Window:CreateTab("🎥 Creator", "video")

    Tab:CreateSection("Toma limpia")
    Tab:CreateParagraph({
        Title = "Preparar, no fingir exportación",
        Content = "Clean Shot silencia la UI y prepara la escena. Si tu entorno no ofrece screenshot, graba con OBS o la captura del sistema. Presiona Escape para restaurar la interfaz.",
    })

    Tab:CreateButton({
        Name = "🎬 Preparar toma / Clean Shot",
        Callback = function()
            UCam.prepareCapture()
            local status = UCam.getCaptureStatus()
            UCam.notify("Creator", status.message, 4, { important = true })
        end,
    })

    Tab:CreateButton({
        Name = "↩ Restaurar después de la toma",
        Callback = function()
            UCam.restoreCapture()
            UCam.notify("Creator", "Estado de captura restaurado.")
        end,
    })

    Tab:CreateButton({
        Name = "🛟 Recuperar sesión sin descargar UCam",
        Callback = function()
            UCam.recoverSession()
        end,
    })

    Tab:CreateSection("Guías de composición")
    Tab:CreateToggle({
        Name = "Mostrar guías en preview",
        CurrentValue = UCam.Guides.Enabled,
        Flag = "V10GuidesEnabled",
        Callback = function(value)
            UCam.setGuidesEnabled(value)
        end,
    })

    Tab:CreateDropdown({
        Name = "Tipo de guía",
        Options = { "Thirds", "Center", "Safe", "Vertical" },
        CurrentOption = { UCam.Guides.Type or "Thirds" },
        MultipleOptions = false,
        Flag = "V10GuidesType",
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value then UCam.setGuidesType(value) end
        end,
    })

    Tab:CreateSlider({
        Name = "Opacidad de guías",
        Range = { 0.1, 1 },
        Increment = 0.05,
        CurrentValue = UCam.Guides.Opacity or 0.65,
        Flag = "V10GuidesOpacity",
        Callback = function(value)
            UCam.setGuideOpacity(value)
        end,
    })

    Tab:CreateSection("Escenas locales")
    local selectedScene = 1
    local sceneName = ""
    local sceneDescription = ""

    Tab:CreateDropdown({
        Name = "Ranura de escena",
        Options = { "Escena 1", "Escena 2", "Escena 3", "Escena 4", "Escena 5" },
        CurrentOption = { "Escena 1" },
        MultipleOptions = false,
        Flag = "V10SceneSlot",
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            selectedScene = tonumber(value and value:match("%d+")) or 1
        end,
    })

    Tab:CreateInput({
        Name = "Nombre de escena",
        PlaceholderText = "Ej: Atardecer / Intro / Horror",
        RemoveTextAfterFocusLost = false,
        Flag = "V10SceneName",
        Callback = function(value) sceneName = value or "" end,
    })

    Tab:CreateInput({
        Name = "Descripción corta",
        PlaceholderText = "Qué quieres grabar aquí",
        RemoveTextAfterFocusLost = false,
        Flag = "V10SceneDescription",
        Callback = function(value) sceneDescription = value or "" end,
    })

    Tab:CreateButton({
        Name = "💾 Guardar escena actual",
        Callback = function()
            UCam.captureScene(selectedScene)
            if sceneName ~= "" or sceneDescription ~= "" then
                UCam.renameScene(selectedScene, sceneName, sceneDescription)
            end
            UCam.notify("Creator", "Escena guardada en la ranura " .. selectedScene .. ".")
        end,
    })

    Tab:CreateButton({
        Name = "📂 Aplicar escena",
        Callback = function()
            if UCam.applyScene(selectedScene) then
                UCam.notify("Creator", "Escena aplicada.", 3, { important = true })
            else
                UCam.notify("Creator", "La ranura está vacía.", 3, { important = true })
            end
        end,
    })

    Tab:CreateButton({
        Name = "✏️ Renombrar escena guardada",
        Callback = function()
            if UCam.renameScene(selectedScene, sceneName, sceneDescription) then
                UCam.notify("Creator", "Metadata de escena actualizada.")
            else
                UCam.notify("Creator", "Guarda la escena antes de renombrarla.", 3)
            end
        end,
    })

    Tab:CreateSection("Replay Pro")
    local markerLabel = "Marcador"
    Tab:CreateInput({
        Name = "Etiqueta del marcador",
        PlaceholderText = "Ej: entrada, golpe, cambio",
        RemoveTextAfterFocusLost = false,
        Flag = "V10MarkerLabel",
        Callback = function(value) markerLabel = value or "Marcador" end,
    })

    Tab:CreateButton({
        Name = "📍 Añadir marcador ahora",
        Callback = function()
            local ok, time = UCam.addReplayMarker(markerLabel)
            if ok then
                UCam.notify("Replay", string.format("Marcador añadido en %.2fs.", time))
            else
                UCam.notify("Replay", "No se pudo añadir el marcador.", 3)
            end
        end,
    })

    Tab:CreateKeybind({
        Name = "Tecla rápida para marcador",
        CurrentKeybind = "K",
        HoldToInteract = false,
        Flag = "V10ReplayMarkerKeybind",
        Callback = function()
            UCam.addReplayMarker(markerLabel)
        end,
    })

    Tab:CreateButton({
        Name = "↩ Quitar último marcador",
        Callback = function()
            if UCam.removeLastReplayMarker() then UCam.notify("Replay", "Último marcador eliminado.")
            else UCam.notify("Replay", "No hay marcadores.", 3) end
        end,
    })

    Tab:CreateButton({
        Name = "🧹 Limpiar marcadores",
        Callback = function()
            UCam.clearReplayMarkers()
            UCam.notify("Replay", "Marcadores limpiados.")
        end,
    })

    Tab:CreateButton({
        Name = "ℹ️ Ver marcadores",
        Callback = function()
            local lines = {}
            for i, marker in ipairs(UCam.getReplayMarkers()) do
                lines[i] = string.format("%d. %.2fs — %s", i, marker.time or 0, marker.label or "Marcador")
            end
            UCam.notify("Replay", #lines > 0 and table.concat(lines, "\n") or "No hay marcadores.", 8)
        end,
    })

    local trimStart = "0"
    local trimEnd = ""
    Tab:CreateInput({
        Name = "Inicio de recorte (segundos)",
        PlaceholderText = "0",
        RemoveTextAfterFocusLost = false,
        Flag = "V10TrimStart",
        Callback = function(value) trimStart = value or "0" end,
    })
    Tab:CreateInput({
        Name = "Final de recorte (segundos)",
        PlaceholderText = "vacío = final",
        RemoveTextAfterFocusLost = false,
        Flag = "V10TrimEnd",
        Callback = function(value) trimEnd = value or "" end,
    })

    Tab:CreateButton({
        Name = "✂️ Recortar Replay",
        Callback = function()
            local endValue = tonumber(trimEnd)
            if not endValue and UCam.Replay.Frames[#UCam.Replay.Frames] then
                endValue = UCam.Replay.Frames[#UCam.Replay.Frames].t
            end
            local ok, result = UCam.trimReplay(tonumber(trimStart) or 0, endValue)
            if ok then UCam.notify("Replay", result .. " frames después del recorte.")
            else UCam.notify("Replay", result or "No se pudo recortar.", 3) end
        end,
    })

    Tab:CreateButton({
        Name = "🔁 Invertir Replay",
        Callback = function()
            local ok, result = UCam.reverseReplay()
            if ok then UCam.notify("Replay", result .. " frames invertidos.")
            else UCam.notify("Replay", result or "No se pudo invertir.", 3) end
        end,
    })

    Tab:CreateParagraph({
        Title = "V10 local",
        Content = "Estas herramientas amplían Replay, Director, Scenes y UCam sin crear un backend ni cambiar el Loader principal.",
    })
end
