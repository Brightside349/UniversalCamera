-- ============================================================
-- Universal Camera Pro v13.7 · ui/tabs/replay
-- Pestaña Replay: graba actores/props, reproduce el demo con
-- camara libre y guarda varias pasadas de camara (tomas).
--
-- Toda la logica vive en demo/*. Esta pestaña solo traduce clics a
-- llamadas de UCam y refresca listas; no guarda estado propio salvo
-- el nombre que se esta escribiendo.
-- ============================================================
local UCam = _G.UCam

local function statusNotify()
    UCam.notify("Replay", UCam.demoStatusText(), 7, { important = true })
end

local function refreshDemoDropdown()
    local dropdown = UCam.UIRefs.ReplayDemoDropdown
    if dropdown and dropdown.Refresh then
        pcall(function() dropdown:Refresh(UCam.demoLibraryOptions()) end)
    end
end

local function refreshTakeDropdown()
    local dropdown = UCam.UIRefs.ReplayTakeDropdown
    if dropdown and dropdown.Refresh then
        pcall(function() dropdown:Refresh(UCam.demoTakeOptions()) end)
    end
end

function UCam.build_replay(Window)
    local Tab = Window:CreateTab("🎬 Replay", "film")
    local D = UCam.Demo
    local T = UCam.DemoTakes
    -- El grabador de tomas avisa cuando termina solo (por duracion).
    UCam.refreshReplayTakes = refreshTakeDropdown

    local demoName = (D.Current and D.Current.name) or ""
    local selectedDemo = ""
    local selectedTake = ""
    local importText = ""

    -- ============================================================
    -- GRABACION
    -- ============================================================
    Tab:CreateSection("Demo local")

    Tab:CreateParagraph({
        Title = "Que graba",
        Content = "Guarda la pose de tu personaje y de los demas jugadores (raiz + cada articulacion) y las posiciones de tus props. No es un demo del motor: reproduce lo que viste, en tu cliente, y nadie mas lo ve.",
    })
    Tab:CreateParagraph({
        Title = "Como se usa",
        Content = "1) Graba el demo. 2) Reproduce y activa la camara libre. 3) Graba una pasada de camara como toma. Repite para cada angulo y reproduce la secuencia.",
    })

    Tab:CreateInput({
        Name = "Nombre del demo",
        PlaceholderText = "Demo de la partida",
        CurrentValue = demoName,
        Callback = function(text)
            demoName = tostring(text or "")
        end,
    })

    Tab:CreateButton({
        Name = "⏺ Grabar demo",
        Callback = function()
            local ok, err = UCam.demoStartRecording()
            if not ok then
                UCam.notify("Replay", tostring(err or "No se pudo grabar."), 5, { important = true })
            end
        end,
    })

    Tab:CreateButton({
        Name = "⏹ Detener y guardar",
        Callback = function()
            local ok, demoOrErr = UCam.demoStopRecording(demoName ~= "" and demoName or nil)
            if not ok then
                UCam.notify("Replay", tostring(demoOrErr or "Grabacion vacia."), 5, { important = true })
                return
            end
            refreshTakeDropdown()
            if UCam.HasFileSystem then
                local saved, fileOrErr = UCam.demoSaveAs(demoName ~= "" and demoName or nil)
                if not saved then
                    UCam.notify("Replay", tostring(fileOrErr or "No se pudo guardar."), 5, { important = true })
                end
                refreshDemoDropdown()
            else
                UCam.notify("Replay",
                    "Demo en memoria. Sin writefile: usa Exportar base64 en Biblioteca.",
                    6, { important = true })
            end
        end,
    })

    Tab:CreateButton({
        Name = "🗑 Descartar grabacion",
        Callback = function()
            UCam.demoCancelRecording()
        end,
    })

    Tab:CreateSlider({
        Name = "Duracion maxima",
        Range = { 15, 300 },
        Increment = 5,
        Suffix = " s",
        CurrentValue = D.MaxDuration,
        Callback = function(value)
            D.MaxDuration = math.clamp(tonumber(value) or 180, 5, 600)
        end,
    })

    Tab:CreateDropdown({
        Name = "Muestras por segundo",
        Options = { "20", "30", "60" },
        CurrentOption = { tostring(D.Rate) },
        MultipleOptions = false,
        Callback = function(option)
            local value = UCam.resolveDropdownValue(option)
            D.Rate = math.clamp(tonumber(value) or 20, 5, 60)
        end,
    })

    Tab:CreateToggle({
        Name = "Grabar mi personaje",
        CurrentValue = D.IncludeLocal,
        Callback = function(value) D.IncludeLocal = value == true end,
    })
    Tab:CreateToggle({
        Name = "Grabar otros jugadores",
        CurrentValue = D.IncludeOthers,
        Callback = function(value) D.IncludeOthers = value == true end,
    })
    Tab:CreateToggle({
        Name = "Grabar props locales",
        CurrentValue = D.IncludeProps,
        Callback = function(value) D.IncludeProps = value == true end,
    })

    Tab:CreateButton({
        Name = "🔖 Marcar momento",
        Callback = function()
            UCam.demoAddMarker(nil)
        end,
    })

    Tab:CreateButton({
        Name = "📊 Ver estado del demo",
        Callback = statusNotify,
    })

    -- ============================================================
    -- REPRODUCCION
    -- ============================================================
    Tab:CreateSection("Reproduccion")

    Tab:CreateButton({
        Name = "▶ Reproducir demo",
        Callback = function()
            local ok, err = UCam.demoPlay()
            if not ok then
                UCam.notify("Replay", tostring(err or "Graba o carga un demo primero."), 4)
            end
        end,
    })

    Tab:CreateButton({
        Name = "⏸ Pausa",
        Callback = function()
            UCam.demoPause()
        end,
    })

    Tab:CreateButton({
        Name = "⏹ Detener y restaurar",
        Callback = function()
            UCam.demoStop()
        end,
    })

    Tab:CreateButton({
        Name = "◀ Frame anterior",
        Callback = function() UCam.demoStep(-1) end,
    })
    Tab:CreateButton({
        Name = "Frame siguiente ▶",
        Callback = function() UCam.demoStep(1) end,
    })

    Tab:CreateSlider({
        Name = "Velocidad",
        Range = { 0.1, 4 },
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = D.Speed,
        Callback = function(value)
            UCam.demoSetSpeed(value)
        end,
    })

    -- Rango fijo: un slider construido al arrancar no puede crecer luego
    -- cuando se graba/carga un demo mas largo. demoSeek recorta al final.
    Tab:CreateSlider({
        Name = "Tiempo del demo",
        Range = { 0, 600 },
        Increment = 0.05,
        Suffix = " s",
        CurrentValue = 0,
        Callback = function(value)
            if D.Current then UCam.demoSeek(value) end
        end,
    })

    Tab:CreateToggle({
        Name = "Loop",
        CurrentValue = D.Loop,
        Callback = function(value) UCam.demoSetLoop(value) end,
    })
    Tab:CreateToggle({
        Name = "Ocultar jugadores vivos",
        CurrentValue = D.HideLive,
        Callback = function(value) UCam.demoSetHideLive(value) end,
    })

    Tab:CreateButton({
        Name = "👁 Ver actores del demo",
        Callback = function()
            UCam.notify("Replay", UCam.demoSummary(), 7, { important = true })
        end,
    })

    -- ============================================================
    -- BIBLIOTECA
    -- ============================================================
    Tab:CreateSection("Biblioteca de demos")

    UCam.UIRefs.ReplayDemoDropdown = Tab:CreateDropdown({
        Name = "Demos guardados",
        Options = UCam.demoLibraryOptions(),
        CurrentOption = { "(sin demos guardados)" },
        MultipleOptions = false,
        Callback = function(option)
            selectedDemo = UCam.resolveDropdownValue(option) or ""
        end,
    })

    Tab:CreateButton({
        Name = "💾 Guardar demo actual",
        Callback = function()
            local ok, fileOrErr = UCam.demoSaveAs(demoName ~= "" and demoName or nil)
            if not ok then
                UCam.notify("Replay", tostring(fileOrErr or "No se pudo guardar."), 5, { important = true })
            end
            refreshDemoDropdown()
        end,
    })

    Tab:CreateButton({
        Name = "📂 Cargar demo seleccionado",
        Callback = function()
            local ok, demoOrErr = UCam.demoLoadFile(selectedDemo)
            if not ok then
                UCam.notify("Replay", tostring(demoOrErr or "Selecciona un demo."), 5, { important = true })
                return
            end
            demoName = (D.Current and D.Current.name) or demoName
            refreshTakeDropdown()
        end,
    })

    Tab:CreateButton({
        Name = "🗑 Eliminar demo seleccionado",
        Callback = function()
            local ok, err = UCam.demoDeleteFile(selectedDemo)
            if not ok then
                UCam.notify("Replay", tostring(err or "No se pudo eliminar."), 4)
            end
            refreshDemoDropdown()
        end,
    })

    Tab:CreateButton({
        Name = "🔄 Refrescar lista",
        Callback = refreshDemoDropdown,
    })

    Tab:CreateButton({
        Name = "📤 Exportar demo a base64",
        Callback = function()
            local encoded, copiedOrErr = UCam.demoExportSelected()
            if not encoded then
                UCam.notify("Replay", tostring(copiedOrErr or "No hay demo cargado."), 5, { important = true })
                return
            end
            UCam.notify("Replay",
                copiedOrErr == true
                    and ("Demo exportado y copiado (%d KB)."):format(#encoded // 1024)
                    or ("Demo exportado (%d KB). Copia el texto del Input."):format(#encoded // 1024),
                6, { important = true })
        end,
    })

    Tab:CreateInput({
        Name = "Importar base64",
        PlaceholderText = "Pega aqui el texto exportado",
        CurrentValue = "",
        Callback = function(text)
            importText = tostring(text or "")
        end,
    })

    Tab:CreateButton({
        Name = "📥 Importar base64",
        Callback = function()
            if importText == "" then
                UCam.notify("Replay", "Pega primero el texto del demo.", 4)
                return
            end
            local ok, demoOrErr = UCam.demoImportBase64(importText)
            if not ok then
                UCam.notify("Replay", tostring(demoOrErr or "Base64 invalido."), 5, { important = true })
                return
            end
            refreshTakeDropdown()
        end,
    })

    -- ============================================================
    -- TOMAS
    -- ============================================================
    Tab:CreateSection("Tomas (planos)")

    Tab:CreateParagraph({
        Title = "Varias camaras, un solo demo",
        Content = "Una toma es una pasada de camara grabada sobre el demo. Puedes repetirla desde otro angulo sin volver a grabar a los actores. La secuencia reproduce todas las tomas en orden con la UI oculta.",
    })

    Tab:CreateSlider({
        Name = "Duracion de la toma",
        Range = { 1, 60 },
        Increment = 0.5,
        Suffix = " s",
        CurrentValue = T.Duration,
        Callback = function(value)
            T.Duration = math.clamp(tonumber(value) or 6, 1, 60)
        end,
    })

    Tab:CreateDropdown({
        Name = "Suavizado de la camara",
        Options = T.Easings,
        CurrentOption = { T.Easing },
        MultipleOptions = false,
        Callback = function(option)
            local value = UCam.resolveDropdownValue(option)
            if value then T.Easing = value end
        end,
    })

    UCam.UIRefs.ReplayTakeDropdown = Tab:CreateDropdown({
        Name = "Tomas del demo",
        Options = UCam.demoTakeOptions(),
        CurrentOption = { "(sin tomas)" },
        MultipleOptions = false,
        Callback = function(option)
            selectedTake = UCam.resolveDropdownValue(option) or ""
        end,
    })

    Tab:CreateButton({
        Name = "⏺ Grabar pasada de camara",
        Callback = function()
            local ok, err = UCam.demoTakeStart(nil, T.Duration)
            if not ok then
                UCam.notify("Tomas", tostring(err or "No se pudo empezar la toma."), 5, { important = true })
            end
        end,
    })

    Tab:CreateButton({
        Name = "⏹ Terminar pasada ahora",
        Callback = function()
            UCam.demoTakeStopRecording()
            refreshTakeDropdown()
        end,
    })

    Tab:CreateButton({
        Name = "▶ Reproducir toma seleccionada",
        Callback = function()
            local ok, err = UCam.demoTakePlay(selectedTake)
            if not ok then
                UCam.notify("Tomas", tostring(err or "Selecciona una toma."), 5, { important = true })
            end
        end,
    })

    Tab:CreateButton({
        Name = "🎬 Reproducir secuencia completa",
        Callback = function()
            local ok, err = UCam.demoSequenceStart(selectedTake)
            if not ok then
                UCam.notify("Tomas", tostring(err or "No hay tomas."), 5, { important = true })
            end
        end,
    })

    Tab:CreateButton({
        Name = "⏹ Detener tomas",
        Callback = function()
            UCam.demoSequenceStop()
            UCam.demoTakeStop()
        end,
    })

    Tab:CreateButton({
        Name = "🗑 Eliminar toma seleccionada",
        Callback = function()
            local ok, err = UCam.demoTakeDelete(selectedTake)
            if not ok then
                UCam.notify("Tomas", tostring(err or "Selecciona una toma."), 4)
            end
            refreshTakeDropdown()
        end,
    })

    Tab:CreateToggle({
        Name = "Ocultar UI en la secuencia",
        CurrentValue = T.HideUI,
        Callback = function(value) T.HideUI = value == true end,
    })
    Tab:CreateToggle({
        Name = "Letterbox en la secuencia",
        CurrentValue = T.Letterbox,
        Callback = function(value) T.Letterbox = value == true end,
    })

    Tab:CreateButton({
        Name = "📋 Ver tomas",
        Callback = function()
            UCam.notify("Tomas", UCam.demoTakesSummary(), 7, { important = true })
        end,
    })
end
