-- ============================================================
-- Universal Camera Pro v6 · ui/camaras
-- Pestaña Camaras: los 14 modos y todos sus parametros agrupados.
-- Registra sliders en UCam.UISliders para que Inicio los pueda usar.
-- ============================================================
local UCam = _G.UCam

function UCam.build_camaras(Window)
    local CamTab = Window:CreateTab("🎥 Cámaras", "camera")
    local s = UCam.UISliders

    CamTab:CreateSection("Modo de camara (14 modos)")
    s.modeDropdown = CamTab:CreateDropdown({
        Name            = "Modo",
        Options         = UCam.CamModes,
        CurrentOption   = { UCam.camMode },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value then return end

            UCam.triggerTransition()

            UCam.camMode         = value
            UCam.currentVelocity = Vector3.new()

            if value == "Orbita" or value == "Cenital" or value == "Lateral" or value == "Dron"
                or value == "Crane" or value == "Roll Axis" or value == "Vertigo" then
                UCam.refreshCharacterRefs()
                UCam.Orbit.ManualYaw   = 0
                UCam.Orbit.ManualPitch = 0
                UCam.Orbit.Angle       = 0
                if value == "Vertigo" then UCam.Vertigo.Phase = 0 end
            elseif UCam.camCFrame and value ~= "Director" and value ~= "Dolly Glide" then
                UCam.syncFreeLookFromCFrame(UCam.camera.CFrame)
                UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
            end

            if value == "Dolly Glide" then
                UCam.refreshCharacterRefs()
                UCam.Dolly.Center = (UCam.rootPart and UCam.rootPart.Position) or UCam.camera.CFrame.Position
            end

            if value == "Handheld" then
                UCam.Handheld.Enabled = true
                UCam.Shake.Enabled = true
            else
                UCam.Handheld.Enabled = false
            end
            UCam.notify("Modo", "Cambiado a: " .. value)
        end,
    })

    CamTab:CreateSection("Movimiento libre (Libre / Handheld)")
    s.speedSlider = CamTab:CreateSlider({
        Name = "Velocidad",
        Range = { UCam.SLIDER_MIN_SPEED, UCam.SLIDER_MAX_SPEED },
        Increment = 1,
        Suffix = "st/s",
        CurrentValue = UCam.currentSpeed,
        Callback = function(v) UCam.currentSpeed = v end,
    })
    s.sprintSlider = CamTab:CreateSlider({
        Name = "Multiplicador sprint (Shift)",
        Range = { 1, 5 },
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = UCam.SPRINT_MULTIPLIER,
        Callback = function(v) UCam.SPRINT_MULTIPLIER = v end,
    })
    s.smoothSlider = CamTab:CreateSlider({
        Name = "Suavizado de movimiento",
        Range = { 1, 20 },
        Increment = 1,
        CurrentValue = UCam.MOVEMENT_SMOOTHING,
        Callback = function(v) UCam.MOVEMENT_SMOOTHING = v end,
    })

    CamTab:CreateSection("Comun (Orbita / Dron / Cenital / Crane)")
    s.orbitDistSlider = CamTab:CreateSlider({
        Name = "Distancia",
        Range = { 5, 80 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Orbit.Distance,
        Callback = function(v) UCam.Orbit.Distance = v end,
    })
    s.orbitHeightSlider = CamTab:CreateSlider({
        Name = "Altura",
        Range = { -10, 40 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Orbit.Height,
        Callback = function(v) UCam.Orbit.Height = v end,
    })
    s.orbitSpeedSlider = CamTab:CreateSlider({
        Name = "Velocidad",
        Range = { 0, 3 },
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = UCam.Orbit.Speed,
        Callback = function(v) UCam.Orbit.Speed = v end,
    })

    CamTab:CreateSection("Dron")
    CamTab:CreateDropdown({
        Name = "Trayectoria",
        Options = UCam.DronePath.Modes,
        CurrentOption = { UCam.DronePath.Mode },
        MultipleOptions = false,
        Callback = function(options)
            local v = UCam.resolveDropdownValue(options); if v then UCam.DronePath.Mode = v end
        end,
    })
    CamTab:CreateSlider({
        Name = "Bobbing (oscilacion vertical)",
        Range = { 0, 5 },
        Increment = 0.1,
        Suffix = "st",
        CurrentValue = UCam.DronePath.BobAmount,
        Callback = function(v) UCam.DronePath.BobAmount = v end,
    })

    CamTab:CreateSection("Lateral (side-scroller)")
    CamTab:CreateSlider({
        Name = "Distancia lateral",
        Range = { 4, 40 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Lateral.Distance,
        Callback = function(v) UCam.Lateral.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Altura lateral",
        Range = { -5, 20 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Lateral.Height,
        Callback = function(v) UCam.Lateral.Height = v end,
    })
    CamTab:CreateToggle({
        Name = "Lado (ON = derecha / OFF = izquierda)",
        CurrentValue = UCam.Lateral.Side == 1,
        Callback = function(v) UCam.Lateral.Side = v and 1 or -1 end,
    })

    CamTab:CreateSection("Follow (chase cam)")
    CamTab:CreateSlider({
        Name = "Distancia al objetivo",
        Range = { 3, 25 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Follow.Distance,
        Callback = function(v) UCam.Follow.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Altura sobre el suelo",
        Range = { -3, 15 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Follow.Height,
        Callback = function(v) UCam.Follow.Height = v end,
    })
    CamTab:CreateSlider({
        Name = "Offset lateral (hombro)",
        Range = { -3, 3 },
        Increment = 0.5,
        Suffix = "st",
        CurrentValue = UCam.Follow.SideOffset,
        Callback = function(v) UCam.Follow.SideOffset = v end,
    })

    CamTab:CreateSection("Crane / Jib")
    CamTab:CreateSlider({
        Name = "Altura de la grua",
        Range = { UCam.Crane.MinHeight, UCam.Crane.MaxHeight },
        Increment = 0.5,
        Suffix = "st",
        CurrentValue = UCam.Crane.Height,
        Callback = function(v) UCam.Crane.Height = v end,
    })
    CamTab:CreateToggle({
        Name = "Giro automatico de la cabeza",
        CurrentValue = UCam.Crane.AutoSpin,
        Callback = function(v) UCam.Crane.AutoSpin = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de giro (auto)",
        Range = { 0, 1.5 },
        Increment = 0.05,
        Suffix = "x",
        CurrentValue = UCam.Crane.SpinSpeed,
        Callback = function(v) UCam.Crane.SpinSpeed = v end,
    })

    CamTab:CreateSection("Dolly Glide (carril cinematico)")
    CamTab:CreateDropdown({
        Name = "Eje del carril",
        Options = UCam.Dolly.AxisOptions,
        CurrentOption = { UCam.Dolly.Axis },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Dolly.Axis = v end
        end,
    })
    CamTab:CreateSlider({
        Name = "Distancia del carril",
        Range = { 5, 80 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Dolly.Distance,
        Callback = function(v) UCam.Dolly.Distance = v end,
    })
    CamTab:CreateToggle({
        Name = "Auto-reverse (ida y vuelta)",
        CurrentValue = UCam.Dolly.AutoReverse,
        Callback = function(v) UCam.Dolly.AutoReverse = v end,
    })

    CamTab:CreateSection("Handheld (camara en mano)")
    CamTab:CreateSlider({
        Name = "Intensidad de sacudida",
        Range = { 0.1, 5 },
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = UCam.Handheld.Intensity,
        Callback = function(v) UCam.Handheld.Intensity = v end,
    })
    CamTab:CreateSlider({
        Name = "Frecuencia",
        Range = { 0.2, 6 },
        Increment = 0.1,
        Suffix = "Hz",
        CurrentValue = UCam.Handheld.Frequency,
        Callback = function(v) UCam.Handheld.Frequency = v end,
    })
    CamTab:CreateSlider({
        Name = "Balanceo (roll extra)",
        Range = { 0, 2 },
        Increment = 0.05,
        Suffix = "x",
        CurrentValue = UCam.Handheld.Roll,
        Callback = function(v) UCam.Handheld.Roll = v end,
    })

    CamTab:CreateSection("Roll Axis (barrel roll)")
    CamTab:CreateToggle({
        Name = "Rotacion automatica",
        CurrentValue = UCam.RollAxis.Auto,
        Callback = function(v) UCam.RollAxis.Auto = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de roll",
        Range = { 0, 360 },
        Increment = 5,
        Suffix = " deg/s",
        CurrentValue = UCam.RollAxis.Speed,
        Callback = function(v) UCam.RollAxis.Speed = v end,
    })
    CamTab:CreateDropdown({
        Name = "Direccion",
        Options = { "Derecha (+1)", "Izquierda (-1)" },
        CurrentOption = { UCam.RollAxis.Direction == 1 and "Derecha (+1)" or "Izquierda (-1)" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v == "Derecha (+1)" then
                UCam.RollAxis.Direction = 1
            elseif v == "Izquierda (-1)" then
                UCam.RollAxis.Direction = -1
            end
        end,
    })

    CamTab:CreateSection("Crash Zoom")
    CamTab:CreateButton({
        Name = "Disparar Crash Zoom (dolly-in dramatico)",
        Callback = function()
            if not UCam.freeCamEnabled then
                UCam.notify("Crash Zoom", "Activa la camara libre primero.")
                return
            end
            if UCam.camMode ~= "CrashZoom" then
                UCam.camMode = "CrashZoom"
                pcall(function() s.modeDropdown:Set({ "CrashZoom" }) end)
            end
            UCam.startCrashZoom()
        end,
    })
    CamTab:CreateSlider({
        Name = "FOV final (mas bajo = mas cerca)",
        Range = { 5, 110 },
        Increment = 1,
        Suffix = " grados",
        CurrentValue = UCam.CrashZoom.EndFOV,
        Callback = function(v) UCam.CrashZoom.EndFOV = v end,
    })
    CamTab:CreateSlider({
        Name = "Duracion",
        Range = { 0.3, 4 },
        Increment = 0.1,
        Suffix = "s",
        CurrentValue = UCam.CrashZoom.Duration,
        Callback = function(v) UCam.CrashZoom.Duration = v end,
    })

    -- v6: Vertigo / Dolly Zoom
    CamTab:CreateSection("Vertigo / Dolly Zoom (NUEVO v6)")
    CamTab:CreateParagraph({
        Title   = "Como usar",
        Content = "Selecciona el modo 'Vertigo' en el dropdown de Modo (con camara libre activa). La camara hace dolly in/out mientras el FOV se compensa para que tu personaje mantenga el mismo tamano: el fondo se deforma (efecto Hitchcock). Clic derecho + mouse para orbitar.",
    })
    s.vertigoMinSlider = CamTab:CreateSlider({
        Name = "Distancia minima (dolly in)",
        Range = { 3, 20 },
        Increment = 0.5,
        Suffix = "st",
        CurrentValue = UCam.Vertigo.MinDistance,
        Callback = function(v) UCam.Vertigo.MinDistance = v end,
    })
    s.vertigoMaxSlider = CamTab:CreateSlider({
        Name = "Distancia maxima (dolly out)",
        Range = { 10, 80 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Vertigo.MaxDistance,
        Callback = function(v) UCam.Vertigo.MaxDistance = v end,
    })
    s.vertigoSpeedSlider = CamTab:CreateSlider({
        Name = "Velocidad de oscilacion",
        Range = { 0.1, 3 },
        Increment = 0.05,
        Suffix = "x",
        CurrentValue = UCam.Vertigo.Speed,
        Callback = function(v) UCam.Vertigo.Speed = v end,
    })
    s.vertigoFovSlider = CamTab:CreateSlider({
        Name = "FOV base (a distancia media)",
        Range = { 20, 110 },
        Increment = 1,
        Suffix = " grados",
        CurrentValue = UCam.Vertigo.BaseFOV,
        Callback = function(v) UCam.Vertigo.BaseFOV = v end,
    })

    CamTab:CreateSection("Lente")
    s.fovSlider = CamTab:CreateSlider({
        Name = "FOV",
        Range = { UCam.MIN_FOV, UCam.MAX_FOV },
        Increment = 1,
        Suffix = " grados",
        CurrentValue = UCam.DEFAULT_FOV,
        Callback = function(v)
            if UCam.freeCamEnabled or UCam.Spectate.Active then
                UCam.camera.FieldOfView = v
            end
        end,
    })
    CamTab:CreateButton({
        Name = "Reset FOV (NUEVO v6)",
        Callback = function()
            UCam.camera.FieldOfView = UCam.DEFAULT_FOV
            pcall(function() s.fovSlider:Set(UCam.DEFAULT_FOV) end)
            UCam.notify("Lente", "FOV restablecido a " .. tostring(UCam.DEFAULT_FOV) .. " grados.")
        end,
    })
    s.sensSlider = CamTab:CreateSlider({
        Name = "Sensibilidad mouse",
        Range = { 0.05, 1.5 },
        Increment = 0.05,
        Suffix = "x",
        CurrentValue = UCam.MOUSE_SENSITIVITY,
        Callback = function(v) UCam.MOUSE_SENSITIVITY = v end,
    })

    CamTab:CreateSection("Dutch angle (inclinacion cinematografica)")
    CamTab:CreateSlider({
        Name = "Inclinacion",
        Range = { -45, 45 },
        Increment = 1,
        Suffix = " grados",
        CurrentValue = 0,
        Callback = function(v) UCam.dutchRoll = math.rad(v) end,
    })
end
