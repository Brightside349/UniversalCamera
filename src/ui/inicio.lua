-- ============================================================
-- Universal Camera Pro v8 · ui/inicio
-- Pestaña Inicio: camara libre, ocultar HUD/personaje, auto-HUD,
-- captura de pantalla, teletransporte y "Restablecer todos los valores".
-- v8: migrado a i18n (UCam.T).
-- ============================================================
local UCam = _G.UCam

function UCam.build_inicio(Window)
    local T = UCam.T
    local InicioTab = Window:CreateTab(T("tab_inicio"), "home")
    InicioTab:CreateSection(T("inicio_section1"))

    InicioTab:CreateButton({
        Name     = T("inicio_toggle_cam"),
        Callback = UCam.toggleFreeCam,
    })

    InicioTab:CreateToggle({
        Name         = T("inicio_hide_hud"),
        CurrentValue = false,
        Callback     = UCam.setHudHidden,
    })

    InicioTab:CreateToggle({
        Name         = T("inicio_hide_char"),
        CurrentValue = false,
        Callback     = UCam.setCharacterHidden,
    })

    -- v6: auto-ocultar el HUD al activar la camara libre
    InicioTab:CreateToggle({
        Name         = T("inicio_auto_hud"),
        CurrentValue = UCam.AutoHUD.Enabled,
        Callback     = function(v)
            UCam.AutoHUD.Enabled = v
            UCam.notify("Inicio", v and "El HUD se ocultara solo al activar la camara."
                or "Auto-HUD desactivado.")
        end,
    })

    -- v9: botón rápido de modo de notificaciones (junto al HUD-toggle)
    InicioTab:CreateButton({
        Name     = "🔔 Notificaciones: silenciar / restaurar",
        Callback = function()
            local ncfg = UCam.Config.Notifications
            -- alternar rápido entre el modo anterior y silencio total
            if ncfg.Mode ~= "silent" then
                ncfg._lastMode = ncfg.Mode
                ncfg.Mode = "silent"
            else
                ncfg.Mode = ncfg._lastMode or "all"
            end
        end,
    })

    InicioTab:CreateToggle({
        Name         = "Modo Toma Limpia (sin UI ni notificaciones)",
        CurrentValue = UCam.CleanShot.Enabled,
        Flag         = "CleanShot",
        Callback     = function(v) UCam.setCleanShot(v) end,
    })

    InicioTab:CreateSection("Recuperación V10")
    InicioTab:CreateButton({
        Name = "🛟 Recuperar cámara y estado",
        Callback = function()
            if UCam.recoverSession then
                UCam.recoverSession()
            elseif UCam.forceRestoreCamera then
                UCam.forceRestoreCamera()
            end
        end,
    })

    InicioTab:CreateButton({
        Name = "🧹 Ver diagnóstico de limpieza",
        Callback = function()
            local report = UCam.getCleanupReport and UCam.getCleanupReport() or nil
            if report then
                UCam.notify("Diagnóstico", string.format(
                    "Conexiones: %d total / %d fallidas. Instancias: %d total / %d fallidas.",
                    report.connections.total, report.connections.failed,
                    report.instances.total, report.instances.failed), 6)
            end
        end,
    })

    InicioTab:CreateSection(T("inicio_quick"))

    InicioTab:CreateButton({
        Name     = T("inicio_screenshot"),
        Callback = function()
            if not UCam.freeCamEnabled and not UCam.Spectate.Active then
                UCam.notify("Info", "Activa la camara primero.")
                return
            end
            local guis = {}
            for _, parent in ipairs({game:GetService("CoreGui"), UCam.player:FindFirstChild("PlayerGui")}) do
                if parent then
                    for _, child in ipairs(parent:GetChildren()) do
                        local name = tostring(child.Name or "")
                        if child:IsA("ScreenGui") and (name == "Rayfield" or name:find("Rayfield") or name == "WindUI" or name:find("WindUI") or child:FindFirstChild("Main")) then
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
        Name     = T("inicio_tp_cam"),
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

    -- v8: "Restablecer todos los valores"
    InicioTab:CreateButton({
        Name     = T("inicio_reset_all"),
        Callback = function()
            UCam.currentSpeed                                      = UCam.DEFAULTS.currentSpeed
            UCam.MOVEMENT_SMOOTHING                                = UCam.DEFAULTS.movementSmoothing
            UCam.MOUSE_SENSITIVITY                                 = UCam.DEFAULTS.mouseSensitivity
            UCam.SPRINT_MULTIPLIER                                 = UCam.DEFAULTS.sprintMultiplier
            -- v8.1: slowMoIntensity eliminado
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
            UCam.Waypoint.UseFOV                                   = false
            UCam.Waypoint.UseRoll                                  = false
            UCam.Waypoint.Roll                                     = 0
            UCam.Waypoint.CurveMode                                = "Linear"
            UCam.Waypoint.PreviewArrows                            = false
            UCam.Waypoint.Next                                     = { useFOV = false, fov = 70, roll = 0, speed = 1, hold = 0, label = "", focusTarget = "" }
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

            -- v9 FIX (bug UI): sincronizar los toggles visuales de Rayfield con el
            -- estado reseteado. Antes la UI seguía mostrando los toggles en ON aunque
            -- el estado interno quedaba OFF (Vignette, Shake, FOV Pulse, etc.).
            local function syncToggle(flag, value)
                pcall(function()
                    local el = UCam.Rayfield.Flags and UCam.Rayfield.Flags[flag]
                    if el and el.Set then el:Set(value) end
                end)
            end
            syncToggle("CamVignette", false)
            syncToggle("CamShake", false)
            syncToggle("CamFovPulse", false)
            syncToggle("CamAutoFocusDOF", false)
            syncToggle("SpectateAutoCycle", false)

            UCam.applyFilter(UCam.currentFilterIndex)
            UCam.applyBloom()
            UCam.applyDOF()
            UCam.applySunRays()
            UCam.applyVignette()
            if UCam.Letterbox.Enabled then UCam.applyLetterbox() end

            local s = UCam.UISliders
            pcall(function() s.speedSlider:Set(UCam.currentSpeed) end)
            -- v8.1: slowMoIntensitySlider eliminado
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
