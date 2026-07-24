-- ============================================================
-- Universal Camera Pro v6 · ui/inicio
-- Pestaña Inicio: camara libre, ocultar HUD/personaje, auto-HUD,
-- captura de pantalla, teletransporte y "Restablecer todos los valores".
-- ============================================================
local UCam = _G.UCam

function UCam.build_inicio(Window)
    local InicioTab = Window:CreateTab("🎬 Inicio", "home")
    InicioTab:CreateSection("Camara Libre")

    InicioTab:CreateButton({
        Name     = "Activar / Desactivar Camara",
        Callback = UCam.toggleFreeCam,
    })

    InicioTab:CreateToggle({
        Name         = "Ocultar HUD",
        CurrentValue = false,
        Callback     = UCam.setHudHidden,
    })

    InicioTab:CreateToggle({
        Name         = "Ocultar Mi Personaje",
        CurrentValue = false,
        Callback     = UCam.setCharacterHidden,
    })

    -- v6: auto-ocultar el HUD al activar la camara libre
    InicioTab:CreateToggle({
        Name         = "Auto-ocultar HUD con camara libre (NUEVO v6)",
        CurrentValue = UCam.AutoHUD.Enabled,
        Callback     = function(v)
            UCam.AutoHUD.Enabled = v
            UCam.notify("Inicio", v and "El HUD se ocultara solo al activar la camara."
                or "Auto-HUD desactivado.")
        end,
    })

    InicioTab:CreateSection("Acciones rapidas")

    InicioTab:CreateButton({
        Name     = "Captura de pantalla (ocultar UI 3s)",
        Callback = function()
            if not UCam.freeCamEnabled and not UCam.Spectate.Active then
                UCam.notify("Info", "Activa la camara primero.")
                return
            end
            local guis = {}
            for _, parent in ipairs({game:GetService("CoreGui"), UCam.player:FindFirstChild("PlayerGui")}) do
                if parent then
                    for _, child in ipairs(parent:GetChildren()) do
                        if child:IsA("ScreenGui") and (child.Name == "Rayfield" or child.Name:find("Rayfield") or child:FindFirstChild("Main")) then
                            table.insert(guis, child)
                            child.Enabled = false
                        end
                    end
                end
            end
            task.delay(3, function()
                for _, gui in ipairs(guis) do
                    gui.Enabled = true
                end
                UCam.notify("Universal Camera", "UI restaurada.")
            end)
        end,
    })

    InicioTab:CreateButton({
        Name     = "Teletransportar camara al personaje",
        Callback = function()
            if not UCam.freeCamEnabled then
                UCam.notify("Info", "Activa la camara libre primero.")
                return
            end
            UCam.refreshCharacterRefs()
            if UCam.rootPart then
                UCam.camCFrame = CFrame.new(UCam.rootPart.Position + Vector3.new(0, 5, 10))
                    * CFrame.fromOrientation(UCam.cameraPitch, UCam.cameraYaw, 0)
                UCam.syncFreeLookFromCFrame(UCam.camCFrame)
                UCam.notify("Camara", "Teletransportada al personaje.")
            end
        end,
    })

    -- v6: "Restablecer todos los valores" movido aqui desde Ajustes
    InicioTab:CreateButton({
        Name     = "Restablecer todos los valores",
        Callback = function()
            UCam.currentSpeed                                      = UCam.DEFAULTS.currentSpeed
            UCam.MOVEMENT_SMOOTHING                                = UCam.DEFAULTS.movementSmoothing
            UCam.MOUSE_SENSITIVITY                                 = UCam.DEFAULTS.mouseSensitivity
            UCam.SPRINT_MULTIPLIER                                 = UCam.DEFAULTS.sprintMultiplier
            UCam.SlowMo.Intensity                                  = UCam.DEFAULTS.slowMoIntensity
            UCam.camMode                                           = UCam.DEFAULTS.camMode
            UCam.currentFilterIndex                                = UCam.DEFAULTS.filterIndex
            UCam.Orbit.Distance                                    = UCam.DEFAULTS.orbitDistance
            UCam.Orbit.Height                                      = UCam.DEFAULTS.orbitHeight
            UCam.Orbit.Speed                                       = UCam.DEFAULTS.orbitSpeed
            UCam.dutchRoll                                         = math.rad(UCam.DEFAULTS.dutchRoll)
            UCam.Letterbox.HeightRatio                             = UCam.DEFAULTS.letterboxHeightRatio
            UCam.Bloom.Intensity                                   = UCam.DEFAULTS.bloomIntensity
            UCam.DOF.FocusDistance                                 = UCam.DEFAULTS.dofFocusDistance
            UCam.SunRays.Intensity                                 = UCam.DEFAULTS.sunraysIntensity
            UCam.Follow.Distance                                   = UCam.DEFAULTS.followDistance
            UCam.Follow.Height                                     = UCam.DEFAULTS.followHeight
            UCam.Follow.SideOffset                                 = UCam.DEFAULTS.followSideOffset
            UCam.Lateral.Distance                                  = UCam.DEFAULTS.lateralDistance
            UCam.Lateral.Height                                    = UCam.DEFAULTS.lateralHeight
            UCam.CrashZoom.EndFOV                                  = UCam.DEFAULTS.crashZoomEndFOV
            UCam.CrashZoom.Duration                                = UCam.DEFAULTS.crashZoomDuration
            UCam.Waypoint.Duration                                 = UCam.DEFAULTS.waypointDuration
            UCam.Waypoint.Easing                                   = UCam.DEFAULTS.waypointEasing
            UCam.Waypoint.FOV                                      = UCam.DEFAULTS.waypointFOV
            UCam.Crane.Height                                      = UCam.DEFAULTS.craneHeight
            UCam.Crane.SpinSpeed                                   = UCam.DEFAULTS.craneSpinSpeed
            UCam.Dolly.Distance                                    = UCam.DEFAULTS.dollyDistance
            UCam.Handheld.Intensity                                = UCam.DEFAULTS.handheldIntensity
            UCam.Handheld.Frequency                                = UCam.DEFAULTS.handheldFrequency
            UCam.Handheld.Roll                                     = UCam.DEFAULTS.handheldRoll
            UCam.RollAxis.Speed                                    = UCam.DEFAULTS.rollAxisSpeed
            UCam.Vignette.Intensity                                = UCam.DEFAULTS.vignetteIntensity
            UCam.Vignette.Smoothness                               = UCam.DEFAULTS.vignetteSmoothness
            UCam.Shake.Intensity                                   = UCam.DEFAULTS.shakeIntensity
            UCam.FovPulse.Amplitude                                = UCam.DEFAULTS.fovPulseAmplitude
            UCam.FovPulse.Speed                                    = UCam.DEFAULTS.fovPulseSpeed
            UCam.Vertigo.MinDistance                               = UCam.DEFAULTS.vertigoMinDistance
            UCam.Vertigo.MaxDistance                               = UCam.DEFAULTS.vertigoMaxDistance
            UCam.Vertigo.Speed                                     = UCam.DEFAULTS.vertigoSpeed
            UCam.Vertigo.BaseFOV                                   = UCam.DEFAULTS.vertigoBaseFOV
            UCam.Vertigo.Phase                                     = 0
            UCam.customEditing.Brightness                          = 0
            UCam.customEditing.Contrast                            = 0
            UCam.customEditing.Saturation                          = 0
            UCam.customEditing.R, UCam.customEditing.G, UCam.customEditing.B = 255, 255, 255
            UCam.Shake.Enabled                                     = false
            UCam.FovPulse.Enabled                                  = false
            UCam.Vignette.Enabled                                  = false
            UCam.AutoFocusDOF.Enabled                              = false
            UCam.AutoCycle.Enabled                                 = false
            UCam.destroyVignetteGui()

            UCam.applyFilter(UCam.currentFilterIndex)
            UCam.applyBloom()
            UCam.applyDOF()
            UCam.applySunRays()
            UCam.applyVignette()
            if UCam.Letterbox.Enabled then UCam.applyLetterbox() end

            local s = UCam.UISliders
            pcall(function() s.speedSlider:Set(UCam.currentSpeed) end)
            pcall(function() s.slowMoIntensitySlider:Set(UCam.SlowMo.Intensity) end)
            pcall(function() s.smoothSlider:Set(UCam.MOVEMENT_SMOOTHING) end)
            pcall(function() s.sensSlider:Set(UCam.MOUSE_SENSITIVITY) end)
            pcall(function() s.sprintSlider:Set(UCam.SPRINT_MULTIPLIER) end)
            pcall(function() s.orbitDistSlider:Set(UCam.Orbit.Distance) end)
            pcall(function() s.orbitHeightSlider:Set(UCam.Orbit.Height) end)
            pcall(function() s.orbitSpeedSlider:Set(UCam.Orbit.Speed) end)
            pcall(function() s.fovSlider:Set(UCam.DEFAULTS.defaultFov) end)
            pcall(function() s.modeDropdown:Set({ UCam.camMode }) end)
            pcall(function() s.vertigoMinSlider:Set(UCam.Vertigo.MinDistance) end)
            pcall(function() s.vertigoMaxSlider:Set(UCam.Vertigo.MaxDistance) end)
            pcall(function() s.vertigoSpeedSlider:Set(UCam.Vertigo.Speed) end)
            pcall(function() s.vertigoFovSlider:Set(UCam.Vertigo.BaseFOV) end)
            pcall(function() UCam.UIRefs.FilterDropdown:Set({ UCam.Filters[UCam.currentFilterIndex].Name }) end)

            if UCam.freeCamEnabled then UCam.camera.FieldOfView = UCam.DEFAULTS.defaultFov end
            UCam.notify("Configuracion", "Valores restablecidos.", 4)
        end,
    })
end
