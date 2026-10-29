-- ============================================================
-- Universal Camera Pro v12.5 · ui/camaras
-- Pestaña Cámaras: un solo selector de modo y solo los parametros del
-- modo elegido (los paneles se muestran/ocultan, no se duplican).
--
-- v12.5: se unificaron los 18 modos en paneles por familia, se agrego el
-- modo "Personalizada" (armado por el usuario), se quitaron los botones
-- repetidos y las posiciones guardadas pasaron a un selector.
-- ============================================================
local UCam = _G.UCam

local TAB_NAME = "🎥 Cámaras"

function UCam.build_camaras(Window)
    local CamTab = Window:CreateTab(TAB_NAME, "camera")
    local s = UCam.UISliders

    -- ------------------------------------------------------------
    -- Helper: crea un panel condicional dentro de esta pestaña.
    -- begin() marca lo ya existente, finish() captura lo nuevo.
    -- ------------------------------------------------------------
    local panels = {}
    local function panel(name)
        local g = UCam.createUIGroup(TAB_NAME)
        g.begin()
        panels[name] = g
        return g
    end

    -- ============================================================
    -- SELECTOR DE MODO (siempre visible)
    -- ============================================================
    CamTab:CreateSection("Modo de cámara (19 modos)")

    local function resetModeState(value)
        if value == "Orbita" or value == "Cenital" or value == "Lateral" or value == "Dron"
            or value == "Crane" or value == "Roll Axis" or value == "Vertigo" then
            UCam.refreshCharacterRefs()
            UCam.Orbit.ManualYaw   = 0
            UCam.Orbit.ManualPitch = 0
            UCam.Orbit.Angle       = 0
            if value == "Vertigo" then UCam.Vertigo.Phase = 0 end
        elseif value == "Personalizada" then
            UCam.CustomCam.Angle = 0
            UCam.Orbit.ManualYaw = 0
            UCam.Orbit.ManualPitch = 0
        elseif UCam.camCFrame and value ~= "Director" and value ~= "Dolly Glide" then
            UCam.syncFreeLookFromCFrame(UCam.camera.CFrame)
            UCam.camCFrame = UCam.buildFreeCameraCFrame(UCam.camCFrame.Position)
        end

        if value == "Dolly Glide" then
            UCam.refreshCharacterRefs()
            UCam.Dolly.Center = (UCam.rootPart and UCam.rootPart.Position) or UCam.camera.CFrame.Position
        elseif value == "FPV Dron" then
            UCam.FPVDrone._prevYaw = UCam.cameraYaw
        elseif value == "Cable Cam" then
            if not UCam.CableCam.PointA and UCam.camCFrame then
                UCam.CableCam.PointA = UCam.camCFrame
                UCam.CableCam.PointB = UCam.camCFrame * CFrame.new(0, 0, -40)
                UCam.CableCam.Progress = 0
            end
        elseif value == "Security Cam" then
            UCam.SecurityCam.Anchor = (UCam.camCFrame and UCam.camCFrame.Position) or Vector3.new(0, 30, 0)
            UCam.SecurityCam.Phase = 0
        end

        if value == "Handheld" then
            UCam.Handheld.Enabled = true
            UCam.Shake.Enabled = true
        else
            UCam.Handheld.Enabled = false
        end
    end

    local function applyPanels(mode)
        for _, g in pairs(panels) do g.setVisible(false) end
        local show = {}
        if mode == "Orbita" or mode == "Cenital" or mode == "Dron" or mode == "Crane" then
            show.commonOrbit = true
        end
        if mode == "Dron" then show.dron = true end
        if mode == "Crane" then show.crane = true end
        if mode == "Lateral" then show.lateral = true end
        if mode == "Follow" then show.follow = true end
        if mode == "Dolly Glide" then show.dolly = true end
        if mode == "Handheld" or mode == "FPV Dron" then show.handheld = true end
        if mode == "Roll Axis" then show.rollaxis = true end
        if mode == "CrashZoom" then show.crash = true end
        if mode == "Vertigo" then show.vertigo = true end
        if mode == "FPV Dron" then show.fpv = true end
        if mode == "Snorricam" then show.snorri = true end
        if mode == "Cable Cam" then show.cable = true end
        if mode == "Security Cam" then show.security = true end
        if mode == "Personalizada" then show.custom = true end
        if mode == "Director" then show.director = true end
        for key in pairs(show) do
            if panels[key] then panels[key].setVisible(true) end
        end
    end

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
            resetModeState(value)
            applyPanels(value)

            if value ~= "Personalizada" and UCam.CustomCam.UseFOV and UCam.freeCamEnabled then
                UCam.camera.FieldOfView = UCam.DEFAULT_FOV
            end

            UCam.notify("Modo", "Cambiado a: " .. value)
        end,
    })

    CamTab:CreateParagraph({
        Title   = "Opciones por modo",
        Content = "Solo verás los controles del modo elegido. El movimiento, el lente y las posiciones guardadas siguen disponibles siempre.",
    })

    -- ============================================================
    -- MOVIMIENTO (siempre visible)
    -- ============================================================
    CamTab:CreateSection("Movimiento")
    CamTab:CreateSlider({
        Name         = "Velocidad",
        Range        = { UCam.SLIDER_MIN_SPEED, UCam.SLIDER_MAX_SPEED },
        Increment    = 1,
        Suffix       = "st/s",
        CurrentValue = UCam.currentSpeed,
        Callback     = function(v) UCam.currentSpeed = v end,
    })
    CamTab:CreateSlider({
        Name         = "Multiplicador sprint (Shift)",
        Range        = { 1, 5 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = UCam.SPRINT_MULTIPLIER,
        Callback     = function(v) UCam.SPRINT_MULTIPLIER = v end,
    })
    CamTab:CreateSlider({
        Name         = "Suavizado de movimiento",
        Range        = { 1, 20 },
        Increment    = 1,
        CurrentValue = UCam.MOVEMENT_SMOOTHING,
        Callback     = function(v) UCam.MOVEMENT_SMOOTHING = v end,
    })

    -- ============================================================
    -- PANELES POR MODO
    -- ============================================================
    local g = panel("commonOrbit")
    CamTab:CreateSection("Órbita / cenital / dron / grúa")
    CamTab:CreateSlider({
        Name = "Distancia", Range = { 5, 80 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Orbit.Distance,
        Callback = function(v) UCam.Orbit.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Altura", Range = { -10, 40 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Orbit.Height,
        Callback = function(v) UCam.Orbit.Height = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de giro", Range = { 0, 3 }, Increment = 0.1, Suffix = "x",
        CurrentValue = UCam.Orbit.Speed,
        Callback = function(v) UCam.Orbit.Speed = v end,
    })
    g.finish()

    local dron = panel("dron")
    CamTab:CreateSection("Dron: trayectoria")
    CamTab:CreateDropdown({
        Name = "Trayectoria",
        Options = UCam.DronePath.Modes,
        CurrentOption = { UCam.DronePath.Mode },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.DronePath.Mode = v end
        end,
    })
    CamTab:CreateSlider({
        Name = "Oscilación vertical (bobbing)", Range = { 0, 5 }, Increment = 0.1, Suffix = "st",
        CurrentValue = UCam.DronePath.BobAmount,
        Callback = function(v) UCam.DronePath.BobAmount = v end,
    })
    dron.finish()

    local crane = panel("crane")
    CamTab:CreateSection("Grúa: altura y giro")
    CamTab:CreateSlider({
        Name = "Altura de la grúa", Range = { UCam.Crane.MinHeight, UCam.Crane.MaxHeight }, Increment = 0.5, Suffix = "st",
        CurrentValue = UCam.Crane.Height,
        Callback = function(v) UCam.Crane.Height = v end,
    })
    CamTab:CreateToggle({
        Name = "Giro automático", CurrentValue = UCam.Crane.AutoSpin,
        Callback = function(v) UCam.Crane.AutoSpin = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de giro", Range = { 0, 1.5 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.Crane.SpinSpeed,
        Callback = function(v) UCam.Crane.SpinSpeed = v end,
    })
    crane.finish()

    local lateral = panel("lateral")
    CamTab:CreateSection("Lateral (side-scroller)")
    CamTab:CreateSlider({
        Name = "Distancia lateral", Range = { 4, 40 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Lateral.Distance,
        Callback = function(v) UCam.Lateral.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Altura lateral", Range = { -5, 20 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Lateral.Height,
        Callback = function(v) UCam.Lateral.Height = v end,
    })
    CamTab:CreateDropdown({
        Name = "Lado",
        Options = { "Derecha", "Izquierda" },
        CurrentOption = { UCam.Lateral.Side == 1 and "Derecha" or "Izquierda" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then UCam.Lateral.Side = (v == "Derecha") and 1 or -1 end
        end,
    })
    lateral.finish()

    local follow = panel("follow")
    CamTab:CreateSection("Follow (chase cam)")
    CamTab:CreateSlider({
        Name = "Distancia al objetivo", Range = { 3, 25 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Follow.Distance,
        Callback = function(v) UCam.Follow.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Altura", Range = { -3, 15 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Follow.Height,
        Callback = function(v) UCam.Follow.Height = v end,
    })
    CamTab:CreateSlider({
        Name = "Offset lateral (hombro)", Range = { -3, 3 }, Increment = 0.5, Suffix = "st",
        CurrentValue = UCam.Follow.SideOffset,
        Callback = function(v) UCam.Follow.SideOffset = v end,
    })
    follow.finish()

    local dolly = panel("dolly")
    CamTab:CreateSection("Dolly Glide (carril)")
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
        Name = "Distancia del carril", Range = { 5, 80 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Dolly.Distance,
        Callback = function(v) UCam.Dolly.Distance = v end,
    })
    CamTab:CreateToggle({
        Name = "Auto-reverse (ida y vuelta)", CurrentValue = UCam.Dolly.AutoReverse,
        Callback = function(v) UCam.Dolly.AutoReverse = v end,
    })
    dolly.finish()

    local handheld = panel("handheld")
    CamTab:CreateSection("Cámara en mano")
    CamTab:CreateSlider({
        Name = "Intensidad", Range = { 0.1, 5 }, Increment = 0.1, Suffix = "x",
        CurrentValue = UCam.Handheld.Intensity,
        Callback = function(v) UCam.Handheld.Intensity = v end,
    })
    CamTab:CreateSlider({
        Name = "Frecuencia", Range = { 0.2, 6 }, Increment = 0.1, Suffix = "Hz",
        CurrentValue = UCam.Handheld.Frequency,
        Callback = function(v) UCam.Handheld.Frequency = v end,
    })
    CamTab:CreateSlider({
        Name = "Balanceo (roll)", Range = { 0, 2 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.Handheld.Roll,
        Callback = function(v) UCam.Handheld.Roll = v end,
    })
    handheld.finish()

    local rollaxis = panel("rollaxis")
    CamTab:CreateSection("Roll Axis (barrel roll)")
    CamTab:CreateToggle({
        Name = "Rotación automática", CurrentValue = UCam.RollAxis.Auto,
        Callback = function(v) UCam.RollAxis.Auto = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad", Range = { 0, 360 }, Increment = 5, Suffix = " deg/s",
        CurrentValue = UCam.RollAxis.Speed,
        Callback = function(v) UCam.RollAxis.Speed = v end,
    })
    CamTab:CreateDropdown({
        Name = "Dirección",
        Options = { "Derecha", "Izquierda" },
        CurrentOption = { UCam.RollAxis.Direction == 1 and "Derecha" or "Izquierda" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then UCam.RollAxis.Direction = (v == "Derecha") and 1 or -1 end
        end,
    })
    rollaxis.finish()

    local crash = panel("crash")
    CamTab:CreateSection("Crash Zoom")
    CamTab:CreateButton({
        Name = "Disparar Crash Zoom",
        Callback = function()
            if not UCam.freeCamEnabled then
                UCam.notify("Crash Zoom", "Activa la cámara libre primero.")
                return
            end
            UCam.startCrashZoom()
        end,
    })
    CamTab:CreateSlider({
        Name = "FOV final", Range = { 5, 110 }, Increment = 1, Suffix = " grados",
        CurrentValue = UCam.CrashZoom.EndFOV,
        Callback = function(v) UCam.CrashZoom.EndFOV = v end,
    })
    CamTab:CreateSlider({
        Name = "Duración", Range = { 0.3, 4 }, Increment = 0.1, Suffix = "s",
        CurrentValue = UCam.CrashZoom.Duration,
        Callback = function(v) UCam.CrashZoom.Duration = v end,
    })
    crash.finish()

    local vertigo = panel("vertigo")
    CamTab:CreateSection("Vértigo / Dolly Zoom")
    CamTab:CreateParagraph({
        Title = "Efecto Hitchcock",
        Content = "La cámara se acerca y se aleja mientras el FOV compensa para que el personaje mantenga su tamaño y el fondo se deforme.",
    })
    CamTab:CreateSlider({
        Name = "Distancia mínima", Range = { 3, 20 }, Increment = 0.5, Suffix = "st",
        CurrentValue = UCam.Vertigo.MinDistance,
        Callback = function(v) UCam.Vertigo.MinDistance = v end,
    })
    CamTab:CreateSlider({
        Name = "Distancia máxima", Range = { 10, 80 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Vertigo.MaxDistance,
        Callback = function(v) UCam.Vertigo.MaxDistance = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de oscilación", Range = { 0.1, 3 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.Vertigo.Speed,
        Callback = function(v) UCam.Vertigo.Speed = v end,
    })
    CamTab:CreateSlider({
        Name = "FOV base", Range = { 20, 110 }, Increment = 1, Suffix = " grados",
        CurrentValue = UCam.Vertigo.BaseFOV,
        Callback = function(v) UCam.Vertigo.BaseFOV = v end,
    })
    vertigo.finish()

    local fpv = panel("fpv")
    CamTab:CreateSection("FPV Dron")
    CamTab:CreateSlider({
        Name = "Inercia (0=rígido)", Range = { 0, 0.95 }, Increment = 0.05,
        CurrentValue = UCam.FPVDrone.Inertia,
        Callback = function(v) UCam.FPVDrone.Inertia = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de roll", Range = { 0, 300 }, Increment = 10,
        CurrentValue = UCam.FPVDrone.RollSpeed,
        Callback = function(v) UCam.FPVDrone.RollSpeed = v end,
    })
    CamTab:CreateSlider({
        Name = "Roll máximo", Range = { 5, 90 }, Increment = 5, Suffix = " grados",
        CurrentValue = UCam.FPVDrone.MaxRoll,
        Callback = function(v) UCam.FPVDrone.MaxRoll = v end,
    })
    fpv.finish()

    local snorri = panel("snorri")
    CamTab:CreateSection("Snorricam")
    CamTab:CreateSlider({
        Name = "Distancia al personaje", Range = { 1.5, 10 }, Increment = 0.5, Suffix = "st",
        CurrentValue = UCam.Snorricam.Distance,
        Callback = function(v) UCam.Snorricam.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Offset de altura", Range = { -2, 4 }, Increment = 0.1, Suffix = "st",
        CurrentValue = UCam.Snorricam.HeightOffset,
        Callback = function(v) UCam.Snorricam.HeightOffset = v end,
    })
    snorri.finish()

    local cable = panel("cable")
    CamTab:CreateSection("Cable Cam")
    CamTab:CreateButton({
        Name = "Definir punto A (posición actual)",
        Callback = function()
            UCam.CableCam.PointA = UCam.camCFrame or UCam.camera.CFrame
            UCam.notify("Cable Cam", "Punto A fijado.")
        end,
    })
    CamTab:CreateButton({
        Name = "Definir punto B (posición actual)",
        Callback = function()
            UCam.CableCam.PointB = UCam.camCFrame or UCam.camera.CFrame
            UCam.notify("Cable Cam", "Punto B fijado.")
        end,
    })
    CamTab:CreateButton({
        Name = "Auto A/B (aquí y 40st al frente)",
        Callback = function()
            UCam.CableCam.PointA = UCam.camCFrame or UCam.camera.CFrame
            UCam.CableCam.PointB = UCam.CableCam.PointA * CFrame.new(0, 0, -40)
            UCam.CableCam.Progress = 0
            UCam.notify("Cable Cam", "A/B configurados.")
        end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de recorrido", Range = { 0.05, 3 }, Increment = 0.05,
        CurrentValue = UCam.CableCam.Speed,
        Callback = function(v) UCam.CableCam.Speed = v end,
    })
    cable.finish()

    local security = panel("security")
    CamTab:CreateSection("Security Cam")
    CamTab:CreateButton({
        Name = "Fijar anclaje en la posición actual",
        Callback = function()
            UCam.SecurityCam.Anchor = (UCam.camCFrame and UCam.camCFrame.Position) or UCam.camera.CFrame.Position
            UCam.notify("Security Cam", "Anclaje fijado.")
        end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad de paneo", Range = { 0.05, 2 }, Increment = 0.05,
        CurrentValue = UCam.SecurityCam.PanSpeed,
        Callback = function(v) UCam.SecurityCam.PanSpeed = v end,
    })
    CamTab:CreateSlider({
        Name = "Ángulo de paneo (±)", Range = { 10, 180 }, Increment = 5, Suffix = " grados",
        CurrentValue = UCam.SecurityCam.PanAngle,
        Callback = function(v) UCam.SecurityCam.PanAngle = v end,
    })
    security.finish()

    local custom = panel("custom")
    CamTab:CreateSection("Personalizada")
    CamTab:CreateParagraph({
        Title = "Tu propio modo",
        Content = "Define la órbita a tu gusto. Con «Control manual» puedes girar con clic derecho; sin él la cámara gira sola.",
    })
    local C = UCam.CustomCam
    CamTab:CreateSlider({
        Name = "Distancia", Range = { 2, 60 }, Increment = 1, Suffix = "st",
        CurrentValue = C.Distance,
        Callback = function(v) C.Distance = v end,
    })
    CamTab:CreateSlider({
        Name = "Altura", Range = { -10, 30 }, Increment = 1, Suffix = "st",
        CurrentValue = C.Height,
        Callback = function(v) C.Height = v end,
    })
    CamTab:CreateSlider({
        Name = "Giro automático (vueltas/s)", Range = { 0, 2 }, Increment = 0.05, Suffix = "x",
        CurrentValue = C.OrbitSpeed,
        Callback = function(v) C.OrbitSpeed = v end,
    })
    CamTab:CreateSlider({
        Name = "Inclinación (grados)", Range = { -45, 45 }, Increment = 1, Suffix = "°",
        CurrentValue = C.Tilt,
        Callback = function(v) C.Tilt = v end,
    })
    CamTab:CreateSlider({
        Name = "Balanceo / sway", Range = { 0, 5 }, Increment = 0.1, Suffix = "st",
        CurrentValue = C.Sway,
        Callback = function(v) C.Sway = v end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad del sway", Range = { 0.1, 3 }, Increment = 0.1, Suffix = "Hz",
        CurrentValue = C.SwaySpeed,
        Callback = function(v) C.SwaySpeed = v end,
    })
    CamTab:CreateSlider({
        Name = "Roll (inclinación de horizonte)", Range = { -45, 45 }, Increment = 1, Suffix = "°",
        CurrentValue = C.Roll,
        Callback = function(v) C.Roll = v end,
    })
    CamTab:CreateToggle({
        Name = "Control manual (clic derecho)", CurrentValue = C.Manual,
        Callback = function(v) C.Manual = v end,
    })
    CamTab:CreateToggle({
        Name = "Usar FOV propio", CurrentValue = C.UseFOV,
        Callback = function(v)
            C.UseFOV = v
            if not v then UCam.camera.FieldOfView = UCam.DEFAULT_FOV end
        end,
    })
    CamTab:CreateSlider({
        Name = "FOV del modo", Range = { UCam.MIN_FOV, UCam.MAX_FOV }, Increment = 1, Suffix = " grados",
        CurrentValue = C.FOV,
        Callback = function(v) C.FOV = v end,
    })
    custom.finish()

    local director = panel("director")
    CamTab:CreateSection("Director")
    CamTab:CreateParagraph({
        Title = "Ruta de waypoints",
        Content = "El modo Director reproduce la ruta guardada. Crea y edita waypoints en Cinematográfico → Director.",
    })
    director.finish()

    -- ============================================================
    -- LENTE (siempre visible)
    -- ============================================================
    CamTab:CreateSection("Lente")
    local fovSlider = CamTab:CreateSlider({
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
        Name = "Restablecer FOV",
        Callback = function()
            UCam.camera.FieldOfView = UCam.DEFAULT_FOV
            pcall(function() fovSlider:Set(UCam.DEFAULT_FOV) end)
        end,
    })
    CamTab:CreateSlider({
        Name = "Sensibilidad del mouse", Range = { 0.05, 1.5 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.MOUSE_SENSITIVITY,
        Callback = function(v) UCam.MOUSE_SENSITIVITY = v end,
    })
    CamTab:CreateSlider({
        Name = "Dutch angle (inclinación)", Range = { -45, 45 }, Increment = 1, Suffix = "°",
        CurrentValue = math.deg(UCam.dutchRoll),
        Callback = function(v) UCam.dutchRoll = math.rad(v) end,
    })
    CamTab:CreateToggle({
        Name = "Zoom suave (rueda)", CurrentValue = UCam.CamCore.SmoothZoom,
        Callback = function(v)
            UCam.CamCore.SmoothZoom = v
            if not v then UCam.CamCore.TargetFOV = nil end
        end,
    })
    CamTab:CreateSlider({
        Name = "Velocidad del zoom suave", Range = { 2, 30 }, Increment = 1,
        CurrentValue = UCam.CamCore.ZoomSpeed,
        Callback = function(v) UCam.CamCore.ZoomSpeed = v end,
    })
    CamTab:CreateToggle({
        Name = "Auto-exposure", CurrentValue = UCam.CamCore.AutoExposure,
        Callback = function(v) UCam.CamCore.AutoExposure = v end,
    })

    -- ============================================================
    -- POSICIONES GUARDADAS (selector único)
    -- ============================================================
    CamTab:CreateSection("Posiciones guardadas")
    local slotOptions = { "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5" }
    local selectedSlot = 1
    CamTab:CreateDropdown({
        Name = "Slot",
        Options = slotOptions,
        CurrentOption = { slotOptions[1] },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            selectedSlot = tonumber(v and v:match("%d+")) or 1
        end,
    })
    CamTab:CreateButton({
        Name = "💾 Guardar posición en el slot",
        Callback = function() UCam.saveCameraPosition(selectedSlot) end,
    })
    CamTab:CreateButton({
        Name = "📂 Cargar posición del slot",
        Callback = function() UCam.loadCameraPosition(selectedSlot) end,
    })

    -- Estado inicial: mostrar solo el panel del modo actual.
    applyPanels(UCam.camMode)
end
