-- ============================================================
-- Universal Camera Pro v12.5 · ui/propsanim
-- Pestaña Animador: línea de tiempo de keyframes para los props.
--
-- Permite animar el conjunto de props a la vez o cada uno por separado
-- (alcance "Prop seleccionado"), con duración, easing, loop y atajo de
-- teclado para reproducir.
-- ============================================================
local UCam = _G.UCam

function UCam.build_propsanim(Window)
    local Tab = Window:CreateTab("🎬 Animador", "film")
    local A = UCam.PropAnim

    local function notifyKeyframes()
        local lines = UCam.propAnimList()
        if #lines == 0 then
            UCam.notify("Animador", "Todavía no hay keyframes.", 4)
        else
            UCam.notify("Animador", table.concat(lines, "\n"), 8)
        end
    end

    -- ============================================================
    -- LÍNEA DE TIEMPO
    -- ============================================================
    Tab:CreateSection("Línea de tiempo")
    Tab:CreateParagraph({
        Title = "Cómo funciona",
        Content = "Mueve los props a la pose que quieras, elige un tiempo y guarda un keyframe. Repite y reproduce: el Animador interpola igual que un editor de video. «Todos» anima el conjunto; «Prop seleccionado» permite que cada prop tenga su propio ritmo.",
    })
    Tab:CreateDropdown({
        Name = "Alcance del keyframe",
        Options = A.Scopes,
        CurrentOption = { A.Scope },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then A.Scope = v end
        end,
    })
    Tab:CreateSlider({
        Name = "Duración total", Range = { 0.5, 60 }, Increment = 0.5, Suffix = " s",
        CurrentValue = A.Duration,
        Callback = function(v)
            A.Duration = v
            A.Playhead = math.min(A.Playhead or 0, v)
        end,
    })
    Tab:CreateDropdown({
        Name = "Easing",
        Options = A.Easings,
        CurrentOption = { A.Easing },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then A.Easing = v end
        end,
    })
    Tab:CreateToggle({
        Name = "Loop (repetir)",
        CurrentValue = A.Loop,
        Callback = function(v) A.Loop = v end,
    })

    -- ============================================================
    -- KEYFRAMES
    -- ============================================================
    Tab:CreateSection("Keyframes")
    local timeSlider
    timeSlider = Tab:CreateSlider({
        Name = "Tiempo del keyframe", Range = { 0, 60 }, Increment = 0.1, Suffix = " s",
        CurrentValue = 0,
        Callback = function(v)
            A.Playhead = v
            -- Previsualiza al mover, sin iniciar la reproducción.
            if not A.Playing then UCam.propAnimPreview(v) end
        end,
    })

    Tab:CreateButton({
        Name = "＋ Guardar keyframe en este tiempo",
        Callback = function()
            local ok, msg = UCam.propAnimCapture(A.Playhead)
            UCam.notify("Animador", msg, ok and 3 or 5, { important = not ok })
        end,
    })
    Tab:CreateButton({
        Name = "↩ Quitar último keyframe",
        Callback = function()
            local ok, msg = UCam.propAnimRemoveLast()
            UCam.notify("Animador", msg, 3, { important = not ok })
        end,
    })
    Tab:CreateButton({
        Name = "ℹ️ Ver keyframes",
        Callback = notifyKeyframes,
    })
    Tab:CreateButton({
        Name = "🗑 Borrar línea de tiempo",
        Callback = function()
            UCam.propAnimClear()
            pcall(function() timeSlider:Set(0) end)
            UCam.notify("Animador", "Línea de tiempo vacía.")
        end,
    })

    -- ============================================================
    -- REPRODUCCIÓN
    -- ============================================================
    Tab:CreateSection("Reproducción")
    Tab:CreateButton({
        Name = "▶ Reproducir animación",
        Callback = function()
            local ok, msg = UCam.propAnimPlay()
            UCam.notify("Animador", msg, ok and 3 or 5, { important = not ok })
        end,
    })
    Tab:CreateButton({
        Name = "⏹ Detener",
        Callback = function() UCam.propAnimStop() end,
    })
    Tab:CreateButton({
        Name = "⏮ Volver al inicio",
        Callback = function()
            UCam.propAnimReset()
            pcall(function() timeSlider:Set(0) end)
        end,
    })
    Tab:CreateKeybind({
        Name = "Tecla para reproducir",
        CurrentKeybind = "P",
        HoldToInteract = false,
        Callback = function()
            local ok, msg = UCam.propAnimPlay()
            if not ok then UCam.notify("Animador", msg, 4, { important = true }) end
        end,
    })

    Tab:CreateParagraph({
        Title = "Consejo para multitudes",
        Content = "Duplica props en 🪑 Props, colócalos donde quieras y anima el conjunto. Para que cada uno se mueva a su propio tiempo, guarda keyframes con el alcance «Prop seleccionado».",
    })
end
