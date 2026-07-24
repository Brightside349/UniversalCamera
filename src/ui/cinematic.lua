-- ============================================================
-- Universal Camera Pro v6 · ui/cinematic
-- Pestaña Cinematografico: letterbox, vignette, camera shake, FOV pulse,
-- director (waypoints) y post-procesado (bloom, DOF, sun rays).
-- ============================================================
local UCam = _G.UCam

function UCam.build_cinematic(Window)
    local CinematicTab = Window:CreateTab("🎞️ Cinematográfico", "film")

    CinematicTab:CreateSection("Letterbox (barras 21:9)")
    CinematicTab:CreateToggle({
        Name = "Activar letterbox",
        CurrentValue = UCam.Letterbox.Enabled,
        Callback = function(v)
            UCam.Letterbox.Enabled = v
            if v then
                UCam.applyLetterbox()
            else
                UCam.destroyLetterbox()
            end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Altura de barras",
        Range = { 0.02, 0.35 },
        Increment = 0.01,
        CurrentValue = UCam.Letterbox.HeightRatio,
        Callback = function(v)
            UCam.Letterbox.HeightRatio = v
            if UCam.Letterbox.Enabled then UCam.applyLetterbox() end
        end,
    })

    CinematicTab:CreateSection("Vignette (viñeta de bordes)")
    CinematicTab:CreateToggle({
        Name = "Activar Vignette",
        CurrentValue = UCam.Vignette.Enabled,
        Callback = function(v)
            UCam.Vignette.Enabled = v
            UCam.applyVignette()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad",
        Range = { 0.05, 1 },
        Increment = 0.05,
        Suffix = "",
        CurrentValue = UCam.Vignette.Intensity,
        Callback = function(v)
            UCam.Vignette.Intensity = v
            if UCam.Vignette.Enabled then UCam.applyVignette() end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Suavidad del borde",
        Range = { 0.05, 0.95 },
        Increment = 0.05,
        Suffix = "",
        CurrentValue = UCam.Vignette.Smoothness,
        Callback = function(v)
            UCam.Vignette.Smoothness = v
            if UCam.Vignette.Enabled then UCam.applyVignette() end
        end,
    })

    CinematicTab:CreateSection("Camera Shake")
    CinematicTab:CreateToggle({
        Name = "Activar Camera Shake",
        CurrentValue = UCam.Shake.Enabled,
        Callback = function(v)
            UCam.Shake.Enabled = v
            if v then UCam.notify("Camera Shake", "Activado. Patron: " .. UCam.Shake.Pattern) end
        end,
    })
    CinematicTab:CreateDropdown({
        Name = "Patron",
        Options = UCam.Shake.Patterns,
        CurrentOption = { UCam.Shake.Pattern },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Shake.Pattern = v end
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad",
        Range = { 0.1, 5 },
        Increment = 0.1,
        Suffix = "x",
        CurrentValue = UCam.Shake.Intensity,
        Callback = function(v) UCam.Shake.Intensity = v end,
    })
    CinematicTab:CreateButton({
        Name = "Disparar Camera Shake (patron actual)",
        Callback = function()
            UCam.triggerShake(UCam.Shake.Pattern)
        end,
    })

    CinematicTab:CreateSection("Disparar shake one-shot")
    for _, pat in ipairs(UCam.Shake.Patterns) do
        CinematicTab:CreateButton({
            Name = "Disparar: " .. pat,
            Callback = function()
                UCam.triggerShake(pat)
            end,
        })
    end

    CinematicTab:CreateSection("FOV Pulse / Respiracion")
    CinematicTab:CreateToggle({
        Name = "Activar FOV Pulse",
        CurrentValue = UCam.FovPulse.Enabled,
        Callback = function(v) UCam.FovPulse.Enabled = v end,
    })
    CinematicTab:CreateSlider({
        Name = "Amplitud",
        Range = { 0.5, 15 },
        Increment = 0.5,
        Suffix = " grados",
        CurrentValue = UCam.FovPulse.Amplitude,
        Callback = function(v) UCam.FovPulse.Amplitude = v end,
    })
    CinematicTab:CreateSlider({
        Name = "Velocidad",
        Range = { 0.2, 5 },
        Increment = 0.1,
        Suffix = "Hz",
        CurrentValue = UCam.FovPulse.Speed,
        Callback = function(v) UCam.FovPulse.Speed = v end,
    })

    CinematicTab:CreateSection("Director - Waypoints")
    CinematicTab:CreateButton({
        Name = "Guardar waypoint (posicion actual)",
        Callback = function()
            if not UCam.freeCamEnabled then
                UCam.notify("Director", "Activa la camara libre primero.")
                return
            end
            UCam.directorAddWaypoint(UCam.camCFrame)
        end,
    })
    CinematicTab:CreateButton({
        Name = "Deshacer ultimo waypoint",
        Callback = UCam.directorUndoWaypoint,
    })
    CinematicTab:CreateButton({
        Name = "Limpiar todos los waypoints",
        Callback = UCam.directorClearWaypoints,
    })
    local directorToggle = CinematicTab:CreateToggle({
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
        Name = "Duracion total",
        Range = { 1, 60 },
        Increment = 0.5,
        Suffix = "s",
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
    CinematicTab:CreateToggle({
        Name = "Variar FOV durante la ruta",
        CurrentValue = UCam.Waypoint.UseFOV,
        Callback = function(v) UCam.Waypoint.UseFOV = v end,
    })
    CinematicTab:CreateSlider({
        Name = "FOV objetivo",
        Range = { UCam.MIN_FOV, UCam.MAX_FOV },
        Increment = 1,
        Suffix = " grados",
        CurrentValue = UCam.Waypoint.FOV,
        Callback = function(v) UCam.Waypoint.FOV = v end,
    })

    CinematicTab:CreateSection("Visualizador de Ruta 3D")
    CinematicTab:CreateToggle({
        Name         = "Mostrar ruta de waypoints en el mundo",
        CurrentValue = UCam.PathVisualizer.Enabled,
        Callback     = function(v)
            UCam.PathVisualizer.Enabled = v
            if v then
                UCam.drawPathVisualizer()
                UCam.notify("Visualizador", "Ruta visible. Los puntos se actualizan al guardar waypoints.")
            else
                UCam.clearPathVisualizer()
                UCam.notify("Visualizador", "Ruta oculta.")
            end
        end,
    })
    CinematicTab:CreateButton({
        Name     = "Redibujar ruta ahora",
        Callback = function()
            if UCam.PathVisualizer.Enabled then
                UCam.drawPathVisualizer()
                UCam.notify("Visualizador", string.format("Ruta redibujada (%d waypoints).", #UCam.Waypoint.List))
            else
                UCam.notify("Visualizador", "Activa el visualizador primero.")
            end
        end,
    })
    CinematicTab:CreateButton({
        Name     = "Limpiar objetos visuales",
        Callback = function()
            UCam.clearPathVisualizer()
            UCam.notify("Visualizador", "Objetos visuales eliminados.")
        end,
    })

    CinematicTab:CreateSection("Post-procesado: Bloom")
    CinematicTab:CreateToggle({
        Name = "Activar Bloom",
        CurrentValue = UCam.Bloom.Enabled,
        Callback = function(v)
            UCam.Bloom.Enabled = v; UCam.applyBloom()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad",
        Range = { 0, 3 },
        Increment = 0.05,
        Suffix = "x",
        CurrentValue = UCam.Bloom.Intensity,
        Callback = function(v) UCam.Bloom.Intensity = v; UCam.applyBloom() end,
    })
    CinematicTab:CreateSlider({
        Name = "Tamano",
        Range = { 1, 56 },
        Increment = 1,
        CurrentValue = UCam.Bloom.Size,
        Callback = function(v) UCam.Bloom.Size = v; UCam.applyBloom() end,
    })
    CinematicTab:CreateSlider({
        Name = "Umbral",
        Range = { 0, 2 },
        Increment = 0.05,
        CurrentValue = UCam.Bloom.Threshold,
        Callback = function(v) UCam.Bloom.Threshold = v; UCam.applyBloom() end,
    })

    CinematicTab:CreateSection("Post-procesado: Profundidad (DOF)")
    CinematicTab:CreateToggle({
        Name = "Activar DOF",
        CurrentValue = UCam.DOF.Enabled,
        Callback = function(v)
            UCam.DOF.Enabled = v; UCam.applyDOF()
        end,
    })
    CinematicTab:CreateToggle({
        Name = "Auto-Focus DOF (Sujeto)",
        CurrentValue = UCam.AutoFocusDOF.Enabled,
        Callback = function(v)
            UCam.AutoFocusDOF.Enabled = v
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Distancia de enfoque",
        Range = { 0.1, 200 },
        Increment = 0.5,
        Suffix = "st",
        CurrentValue = UCam.DOF.FocusDistance,
        Callback = function(v)
            UCam.DOF.FocusDistance = v; UCam.applyDOF()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Radio enfocado",
        Range = { 0, 50 },
        Increment = 0.5,
        Suffix = "st",
        CurrentValue = UCam.DOF.InFocusRadius,
        Callback = function(v)
            UCam.DOF.InFocusRadius = v; UCam.applyDOF()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad de fondo",
        Range = { 0, 1 },
        Increment = 0.05,
        Suffix = "x",
        CurrentValue = UCam.DOF.FarIntensity,
        Callback = function(v)
            UCam.DOF.FarIntensity = v; UCam.applyDOF()
        end,
    })

    CinematicTab:CreateSection("Post-procesado: Rayos de Sol")
    CinematicTab:CreateToggle({
        Name = "Activar Sun Rays",
        CurrentValue = UCam.SunRays.Enabled,
        Callback = function(v)
            UCam.SunRays.Enabled = v; UCam.applySunRays()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Intensidad",
        Range = { 0, 1 },
        Increment = 0.05,
        CurrentValue = UCam.SunRays.Intensity,
        Callback = function(v)
            UCam.SunRays.Intensity = v; UCam.applySunRays()
        end,
    })
    CinematicTab:CreateSlider({
        Name = "Spread",
        Range = { 0, 1 },
        Increment = 0.05,
        CurrentValue = UCam.SunRays.Spread,
        Callback = function(v)
            UCam.SunRays.Spread = v; UCam.applySunRays()
        end,
    })
end
