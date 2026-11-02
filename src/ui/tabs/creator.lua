-- ============================================================
-- Universal Camera Pro v12.5 · ui/creator
-- Acciones locales para creadores: captura preparada, biblioteca de
-- tomas, guias de composicion y escenas.
-- ============================================================
local UCam = _G.UCam

function UCam.build_creator(Window)
    local Tab = Window:CreateTab("🎥 Creator", "video")

    Tab:CreateSection("Toma limpia")
    Tab:CreateParagraph({
        Title = "Preparar, no fingir exportación",
        Content = "Clean Shot silencia la UI y prepara la escena. Si tu entorno no ofrece screenshot, graba con OBS o la captura del sistema. Presiona Escape para restaurar la interfaz.",
    })

    local captureCountdown = UCam.Capture.Countdown or 3
    local captureHideGuides = UCam.Capture.HideGuides ~= false
    Tab:CreateSlider({
        Name = "Cuenta atrás de captura",
        Range = { 0, 10 },
        Increment = 1,
        Suffix = " s",
        CurrentValue = captureCountdown,
        Callback = function(v)
            captureCountdown = v
            UCam.Capture.Countdown = v
        end,
    })
    Tab:CreateToggle({
        Name = "Ocultar guías durante la toma",
        CurrentValue = captureHideGuides,
        Callback = function(v)
            captureHideGuides = v
            UCam.Capture.HideGuides = v
        end,
    })

    Tab:CreateButton({
        Name = "🎬 Preparar toma / Clean Shot",
        Callback = function()
            UCam.prepareCapture({ countdown = captureCountdown, hideGuides = captureHideGuides })
            local status = UCam.getCaptureStatus()
            UCam.notify("Creator", status.message, 4, { important = true })
        end,
    })

    Tab:CreateSection("Biblioteca de tomas")
    Tab:CreateParagraph({
        Title = "Guardar variantes sin perder la ruta actual",
        Content = "La biblioteca conserva rutas de cámara locales. No reproduce eventos del mundo ni sincroniza props con otros jugadores.",
    })
    local shotName = ""
    local shotDescription = ""
    local selectedShot = "(Biblioteca vacía)"
    local shotLibraryDropdown = Tab:CreateDropdown({
        Name = "Toma guardada",
        Options = UCam.getShotLibraryOptions and UCam.getShotLibraryOptions() or { "(Biblioteca vacía)" },
        CurrentOption = { selectedShot },
        MultipleOptions = false,
        Callback = function(o) selectedShot = UCam.resolveDropdownValue(o) or selectedShot end,
    })
    Tab:CreateInput({
        Name = "Nombre de la toma",
        PlaceholderText = "Ej: Intro Neon",
        RemoveTextAfterFocusLost = false,
        Callback = function(v) shotName = v or "" end,
    })
    Tab:CreateInput({
        Name = "Descripción de la toma",
        PlaceholderText = "Uso o variante",
        RemoveTextAfterFocusLost = false,
        Callback = function(v) shotDescription = v or "" end,
    })
    Tab:CreateButton({
        Name = "Guardar ruta actual en biblioteca",
        Callback = function()
            local ok, result = UCam.saveShotToLibrary(shotName, shotDescription)
            if ok then
                pcall(function() shotLibraryDropdown:Refresh(UCam.getShotLibraryOptions()) end)
                UCam.notify("Creator", "Toma guardada en la biblioteca.")
            else
                UCam.notify("Creator", result or "No se pudo guardar la toma.", 3)
            end
        end,
    })
    Tab:CreateButton({
        Name = "Cargar toma seleccionada",
        Callback = function()
            local ok, result = UCam.loadShotFromLibrary(selectedShot)
            if ok then UCam.notify("Creator", "Toma cargada en el Director.")
            else UCam.notify("Creator", result or "No se pudo cargar la toma.", 3) end
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
        Options = { "Thirds", "Center", "Safe", "16:9", "9:16", "1:1", "4:5" },
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

    -- ========================================================
    -- v13.6: CAMARA LENTA LOCAL
    -- El juego carga sus animaciones en el Animator de cada rig (con
    -- Humanoid o con AnimationController), asi que bajar el Speed de los
    -- tracks que ya suenan alcanza: no se toca el servidor ni WalkSpeed.
    -- ========================================================
    Tab:CreateSection("Cámara lenta local")
    Tab:CreateParagraph({
        Title   = "Solo en tu cliente",
        Content = "Ralentiza las animaciones que se reproducen en tu PC (incluidas las del juego) sin tocar la física ni a los demás jugadores. En animaciones de caminar/correr puede notarse deslizamiento, porque la velocidad de movimiento no cambia.",
    })

    local slow = UCam.SlowMotion
    local slowToggle = Tab:CreateToggle({
        Name         = "Activar cámara lenta",
        CurrentValue = slow.Enabled,
        Flag         = "V136SlowMoEnabled",
        Callback     = function(value)
            if UCam.setSlowMotionEnabled then UCam.setSlowMotionEnabled(value) end
        end,
    })
    local slowSlider = Tab:CreateSlider({
        Name         = "Velocidad de las animaciones",
        Range        = { 0.1, 1 },
        Increment    = 0.05,
        Suffix       = "x",
        CurrentValue = slow.Scale,
        Flag         = "V136SlowMoScale",
        Callback     = function(value)
            if UCam.setSlowMotionScale then UCam.setSlowMotionScale(value) end
        end,
    })
    Tab:CreateDropdown({
        Name            = "Alcance",
        Options         = slow.Scopes,
        CurrentOption   = { slow.Scope },
        MultipleOptions = false,
        Flag            = "V136SlowMoScope",
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value and UCam.setSlowMotionScope then UCam.setSlowMotionScope(value) end
        end,
    })
    Tab:CreateButton({
        Name     = "Restaurar velocidad normal",
        Callback = function()
            if UCam.stopSlowMotion then UCam.stopSlowMotion() end
            pcall(function() slowToggle:Set(false) end)
            pcall(function() slowSlider:Set(1) end)
            local status = UCam.getSlowMotionStatus and UCam.getSlowMotionStatus()
            UCam.notify("Cámara lenta", ("Animaciones restauradas (%d en pantalla)."):format(status and status.tracks or 0), 4)
        end,
    })

    -- ========================================================
    -- v13.6: EXPORTAR SKIN A STUDIO
    -- Los rigs del juego son modelos con Motor6D y huesos (no R15), asi
    -- que se copia el personaje vivo: es el unico camino que conserva la
    -- skin aplicada, los accesorios y la jerarquia real de huesos.
    -- ========================================================
    Tab:CreateSection("Skin a Studio (.rbxmx)")
    Tab:CreateParagraph({
        Title   = "El rig tal como se ve",
        Content = "Copia el personaje elegido (partes, mallas, huesos, accesorios y colores) a UniversalCamera/skins/. Ábrelo en Studio y anímalo sin depender del juego; los scripts del personaje se excluyen. El archivo se nombra con el personaje y la skin del juego.",
    })

    local skinTargets = UCam.getSkinExportTargets and UCam.getSkinExportTargets()
        or { "(sin jugadores)" }
    local skinTarget = skinTargets[1]
    local skinName = ""
    local skinDropdown
    skinDropdown = Tab:CreateDropdown({
        Name            = "Personaje",
        Options         = skinTargets,
        CurrentOption   = { skinTarget },
        MultipleOptions = false,
        Callback        = function(options)
            skinTarget = UCam.resolveDropdownValue(options) or skinTarget
        end,
    })
    Tab:CreateInput({
        Name            = "Nombre del archivo (opcional)",
        PlaceholderText = "Automático: personaje, skin y fecha",
        RemoveTextAfterFocusLost = false,
        Callback        = function(value) skinName = value or "" end,
    })
    Tab:CreateButton({
        Name     = "Exportar skin seleccionada",
        Callback = function()
            if not UCam.exportPlayerSkin then
                UCam.notify("Skin", "El módulo de exportación no está cargado.", 4)
                return
            end
            local ok, result, stats = UCam.exportPlayerSkin(skinTarget, { name = skinName })
            if ok then
                UCam.notify("Skin", string.format(
                    "Guardado en %s · %d partes, %d joints, %d accesorios",
                    tostring(result),
                    stats and stats.parts or 0,
                    stats and stats.joints or 0,
                    stats and stats.accessories or 0
                ), 7, { important = true })
            else
                UCam.notify("Skin", tostring(result), 5)
            end
        end,
    })
    Tab:CreateButton({
        Name     = "Actualizar lista de jugadores",
        Callback = function()
            skinTargets = UCam.getSkinExportTargets()
            pcall(function() skinDropdown:Refresh(skinTargets) end)
            UCam.notify("Skin", "Lista actualizada.", 3)
        end,
    })

    Tab:CreateParagraph({
        Title = "V13.6 local",
        Content = "Cámara lenta y exportación de skin trabajan solo en tu cliente. La cámara del juego no se modifica: UCam se dibuja después de ella.",
    })
end
