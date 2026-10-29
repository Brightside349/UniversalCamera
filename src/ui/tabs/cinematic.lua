-- ============================================================
-- Universal Camera Pro v12.5 · ui/cinematic
-- Pestaña Cinematográfico: encuadre, cámara, Director y post-procesado.
--
-- v12.5: se unificaron los one-shots de shake en un solo botón, se
-- retiraron el editor por-waypoint, la exportación/importación de rutas
-- y los slots duplicados. Todo lo esencial del Director queda junto.
-- ============================================================
local UCam = _G.UCam

function UCam.build_cinematic(Window)
    local CinematicTab = Window:CreateTab("🎞️ Cinematográfico", "film")

    -- ============================================================
    -- ENCUADRE
    -- ============================================================
    CinematicTab:CreateSection("Encuadre")
    CinematicTab:CreateToggle({
        Name = "Letterbox (barras 21:9)",
        CurrentValue = UCam.Letterbox.Enabled,
        Callback = function(v)
            UCam.Letterbox.Enabled = v
            if v then UCam.applyLetterbox() else UCam.destroyLetterbox() end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Altura de las barras", Range = { 0.02, 0.35 }, Increment = 0.01,
        CurrentValue = UCam.Letterbox.HeightRatio,
        Callback = function(v)
            UCam.Letterbox.HeightRatio = v
            if UCam.Letterbox.Enabled then UCam.applyLetterbox() end
        end,
    })
    CinematicTab:CreateToggle({
        Name = "Vignette (viñeta)",
        CurrentValue = UCam.Vignette.Enabled,
        Flag = "CamVignette",
        Callback = function(v)
            UCam.Vignette.Enabled = v
            UCam.applyVignette()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad de la viñeta", Range = { 0.05, 1 }, Increment = 0.05,
        CurrentValue = UCam.Vignette.Intensity,
        Callback = function(v)
            UCam.Vignette.Intensity = v
            if UCam.Vignette.Enabled then UCam.applyVignette() end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Suavidad del borde", Range = { 0.05, 0.95 }, Increment = 0.05,
        CurrentValue = UCam.Vignette.Smoothness,
        Callback = function(v)
            UCam.Vignette.Smoothness = v
            if UCam.Vignette.Enabled then UCam.applyVignette() end
        end,
    })

    -- ============================================================
    -- CÁMARA
    -- ============================================================
    CinematicTab:CreateSection("Camera Shake")
    CinematicTab:CreateToggle({
        Name = "Activar Camera Shake",
        CurrentValue = UCam.Shake.Enabled,
        Flag = "CamShake",
        Callback = function(v) UCam.Shake.Enabled = v end,
    })
    CinematicTab:CreateDropdown({
        Name = "Patrón",
        Options = UCam.Shake.Patterns,
        CurrentOption = { UCam.Shake.Pattern },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Shake.Pattern = v end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad", Range = { 0.1, 5 }, Increment = 0.1, Suffix = "x",
        CurrentValue = UCam.Shake.Intensity,
        Callback = function(v) UCam.Shake.Intensity = v end,
    })
    CinematicTab:CreateButton({
        Name = "⚡ Disparar patrón actual",
        Callback = function() UCam.triggerShake(UCam.Shake.Pattern) end,
    })

    CinematicTab:CreateSection("FOV Pulse (respiración)")
    CinematicTab:CreateToggle({
        Name = "Activar FOV Pulse",
        CurrentValue = UCam.FovPulse.Enabled,
        Flag = "CamFovPulse",
        Callback = function(v) UCam.FovPulse.Enabled = v end,
    })
    CinematicTab:CreateSlider({
        Name = "Amplitud", Range = { 0.5, 15 }, Increment = 0.5, Suffix = " grados",
        CurrentValue = UCam.FovPulse.Amplitude,
        Callback = function(v) UCam.FovPulse.Amplitude = v end,
    })
    CinematicTab:CreateSlider({
        Name = "Velocidad", Range = { 0.2, 5 }, Increment = 0.1, Suffix = "Hz",
        CurrentValue = UCam.FovPulse.Speed,
        Callback = function(v) UCam.FovPulse.Speed = v end,
    })

    -- ============================================================
    -- DIRECTOR
    -- ============================================================
    CinematicTab:CreateSection("Director: waypoints")
    CinematicTab:CreateButton({
        Name = "📍 Guardar waypoint (posición actual)",
        Callback = function()
            if not UCam.freeCamEnabled then
                UCam.notify("Director", "Activa la cámara libre primero.")
                return
            end
            UCam.directorAddWaypoint(UCam.camCFrame)
        end,
    })
    CinematicTab:CreateButton({
        Name = "↩ Deshacer último waypoint",
        Callback = UCam.directorUndoWaypoint,
    })
    CinematicTab:CreateButton({
        Name = "🧹 Limpiar waypoints",
        Callback = UCam.directorClearWaypoints,
    })
    CinematicTab:CreateToggle({
        Name = "Reproducir / Detener ruta",
        CurrentValue = false,
        Callback = function(v) UCam.directorTogglePlay(v) end,
    })
    CinematicTab:CreateToggle({
        Name = "Loop (repetir ruta)",
        CurrentValue = UCam.Waypoint.Loop,
        Callback = function(v) UCam.Waypoint.Loop = v end,
    })
    CinematicTab:CreateSlider({
        Name = "Duración total", Range = { 1, 60 }, Increment = 0.5, Suffix = "s",
        CurrentValue = UCam.Waypoint.Duration,
        Callback = function(v) UCam.Waypoint.Duration = v end,
    })
    CinematicTab:CreateDropdown({
        Name = "Easing",
        Options = UCam.Waypoint.Easings,
        CurrentOption = { UCam.Waypoint.Easing },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Waypoint.Easing = v end
        end,
    })
    CinematicTab:CreateDropdown({
        Name = "Curva de la ruta",
        Options = UCam.Waypoint.CurveModes,
        CurrentOption = { UCam.Waypoint.CurveMode },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then
                UCam.Waypoint.CurveMode = v
                pcall(UCam.drawPathVisualizer)
            end
        end,
    })
    CinematicTab:CreateToggle({
        Name = "Variar FOV durante la ruta",
        CurrentValue = UCam.Waypoint.UseFOV,
        Callback = function(v) UCam.Waypoint.UseFOV = v end,
    })
    CinematicTab:CreateSlider({
        Name = "FOV objetivo", Range = { UCam.MIN_FOV, UCam.MAX_FOV }, Increment = 1, Suffix = " grados",
        CurrentValue = UCam.Waypoint.FOV,
        Callback = function(v)
            UCam.Waypoint.FOV = v
            UCam.Waypoint.Next.fov = v
        end,
    })
    CinematicTab:CreateToggle({
        Name = "Mostrar ruta 3D en el mundo",
        CurrentValue = UCam.PathVisualizer.Enabled,
        Callback = function(v)
            UCam.PathVisualizer.Enabled = v
            if v then
                pcall(UCam.drawPathVisualizer)
            else
                pcall(UCam.clearPathVisualizer)
            end
        end,
    })

    CinematicTab:CreateSection("Director: plantillas de toma")
    local shotTemplate = UCam.ShotBuilder and UCam.ShotBuilder.Template or "Dolly In"
    CinematicTab:CreateDropdown({
        Name = "Plantilla",
        Options = { "Dolly In", "Dolly Out", "Orbit", "Crane", "Reveal" },
        CurrentOption = { shotTemplate },
        MultipleOptions = false,
        Callback = function(o)
            shotTemplate = UCam.resolveDropdownValue(o) or shotTemplate
            if UCam.ShotBuilder then UCam.ShotBuilder.Template = shotTemplate end
        end,
    })
    CinematicTab:CreateDropdown({
        Name = "Objetivo",
        Options = UCam.getShotBuilderTargetModes and UCam.getShotBuilderTargetModes() or { "Propio", "Punto actual" },
        CurrentOption = { UCam.ShotBuilder and UCam.ShotBuilder.TargetMode or "Propio" },
        MultipleOptions = false,
        Callback = function(o)
            local value = UCam.resolveDropdownValue(o)
            if value and UCam.ShotBuilder then UCam.ShotBuilder.TargetMode = value end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Duración de la toma", Range = { 1, 30 }, Increment = 0.5, Suffix = " s",
        CurrentValue = UCam.ShotBuilder and UCam.ShotBuilder.Duration or 5,
        Callback = function(v) if UCam.ShotBuilder then UCam.ShotBuilder.Duration = v end end,
    })
    CinematicTab:CreateSlider({
        Name = "Arco de órbita", Range = { -180, 180 }, Increment = 5, Suffix = "°",
        CurrentValue = UCam.ShotBuilder and UCam.ShotBuilder.ArcDegrees or 90,
        Callback = function(v) if UCam.ShotBuilder then UCam.ShotBuilder.ArcDegrees = v end end,
    })
    CinematicTab:CreateButton({
        Name = "🎬 Crear toma editable",
        Callback = function()
            if UCam.buildShot then UCam.buildShot(shotTemplate) end
        end,
    })

    -- ============================================================
    -- POST-PROCESADO
    -- ============================================================
    CinematicTab:CreateSection("Post-procesado: Bloom")
    CinematicTab:CreateToggle({
        Name = "Activar Bloom", CurrentValue = UCam.Bloom.Enabled,
        Callback = function(v) UCam.Bloom.Enabled = v; UCam.applyBloom() end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad", Range = { 0, 3 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.Bloom.Intensity,
        Callback = function(v) UCam.Bloom.Intensity = v; UCam.applyBloom() end,
    })
    CinematicTab:CreateSlider({
        Name = "Tamaño", Range = { 1, 56 }, Increment = 1,
        CurrentValue = UCam.Bloom.Size,
        Callback = function(v) UCam.Bloom.Size = v; UCam.applyBloom() end,
    })
    CinematicTab:CreateSlider({
        Name = "Umbral", Range = { 0, 2 }, Increment = 0.05,
        CurrentValue = UCam.Bloom.Threshold,
        Callback = function(v) UCam.Bloom.Threshold = v; UCam.applyBloom() end,
    })

    CinematicTab:CreateSection("Post-procesado: Profundidad (DOF)")
    CinematicTab:CreateToggle({
        Name = "Activar DOF", CurrentValue = UCam.DOF.Enabled,
        Callback = function(v) UCam.DOF.Enabled = v; UCam.applyDOF() end,
    })
    CinematicTab:CreateToggle({
        Name = "Auto-Focus al sujeto", CurrentValue = UCam.AutoFocusDOF.Enabled,
        Flag = "CamAutoFocusDOF",
        Callback = function(v) UCam.AutoFocusDOF.Enabled = v end,
    })
    CinematicTab:CreateSlider({
        Name = "Distancia de enfoque", Range = { 0.1, 200 }, Increment = 0.5, Suffix = "st",
        CurrentValue = UCam.DOF.FocusDistance,
        Callback = function(v) UCam.DOF.FocusDistance = v; UCam.applyDOF() end,
    })
    CinematicTab:CreateSlider({
        Name = "Radio enfocado", Range = { 0, 50 }, Increment = 0.5, Suffix = "st",
        CurrentValue = UCam.DOF.InFocusRadius,
        Callback = function(v) UCam.DOF.InFocusRadius = v; UCam.applyDOF() end,
    })
    CinematicTab:CreateSlider({
        Name = "Desenfoque de fondo", Range = { 0, 1 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.DOF.FarIntensity,
        Callback = function(v) UCam.DOF.FarIntensity = v; UCam.applyDOF() end,
    })
    CinematicTab:CreateSlider({
        Name = "Desenfoque de primer plano", Range = { 0, 1 }, Increment = 0.05, Suffix = "x",
        CurrentValue = UCam.DOF.NearIntensity or 0,
        Callback = function(v) UCam.DOF.NearIntensity = v; UCam.applyDOF() end,
    })

    CinematicTab:CreateSection("Post-procesado: Rayos de sol")
    CinematicTab:CreateToggle({
        Name = "Activar Sun Rays", CurrentValue = UCam.SunRays.Enabled,
        Callback = function(v) UCam.SunRays.Enabled = v; UCam.applySunRays() end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad", Range = { 0, 1 }, Increment = 0.05,
        CurrentValue = UCam.SunRays.Intensity,
        Callback = function(v) UCam.SunRays.Intensity = v; UCam.applySunRays() end,
    })
    CinematicTab:CreateSlider({
        Name = "Spread", Range = { 0, 1 }, Increment = 0.05,
        CurrentValue = UCam.SunRays.Spread,
        Callback = function(v) UCam.SunRays.Spread = v; UCam.applySunRays() end,
    })
end
