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

    -- ============================================================
    -- DEBUG TEMPORAL: volcado de estructura del personaje a consola.
    -- Diagnostica por que las poses no aplican en rigs custom (morphs):
    -- joints reales, partes, animator/tracks, scripts y estado de UCam.
    -- ============================================================
    InicioTab:CreateSection("Debug temporal (diagnostico poses)")
    InicioTab:CreateButton({
        Name     = "Volcar estructura del personaje a consola (F9)",
        Callback = function()
            local out = {}
            local function add(s) table.insert(out, s) end
            local char = UCam.player and UCam.player.Character
            if not char then
                print("[UCam-DEBUG] No hay personaje.")
                return
            end
            add("========== UCam DEBUG DUMP ==========")
            add("Character: " .. char.Name .. " | class=" .. char.ClassName
                .. " | parent=" .. (char.Parent and char.Parent.Name or "?"))
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local rigName = "?"
                pcall(function() rigName = hum.RigType.Name end)
                add(string.format(
                    "Humanoid: RigType=%s PlatformStand=%s AutoRotate=%s HipHeight=%s AutoScaling=%s",
                    rigName, tostring(hum.PlatformStand), tostring(hum.AutoRotate),
                    tostring(hum.HipHeight), tostring(hum.AutomaticScalingEnabled)))
                local animator = hum:FindFirstChildOfClass("Animator")
                add("Animator: " .. tostring(animator ~= nil))
                if animator then
                    local okT, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
                    if okT and tracks then
                        add("PlayingTracks: " .. #tracks)
                        for i, t in ipairs(tracks) do
                            if i > 10 then break end
                            local animId = "?"
                            pcall(function() animId = t.Animation.AnimationId end)
                            local prio = "?"
                            pcall(function() prio = t.Priority.Name end)
                            add(string.format("  track '%s' prio=%s anim=%s", t.Name, prio, animId))
                        end
                    end
                end
            else
                add("Humanoid: NONE")
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            add("HumanoidRootPart: " .. tostring(root ~= nil)
                .. (root and (" | anchored=" .. tostring(root.Anchored)) or ""))

            add("---- JOINTS ----")
            local jointCount = 0
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("JointInstance") or d:IsA("WeldConstraint")
                    or d.ClassName == "AnimationConstraint" then
                    jointCount = jointCount + 1
                    if jointCount <= 80 then
                        local p0 = "?"
                        local p1 = "?"
                        pcall(function() p0 = d.Part0.Name end)
                        pcall(function() p1 = d.Part1.Name end)
                        add(string.format("  %s '%s' parent=%s | %s -> %s",
                            d.ClassName, d.Name,
                            d.Parent and d.Parent.Name or "?", p0, p1))
                    end
                end
            end
            add("total joints: " .. jointCount)

            add("---- PARTS ----")
            local partCount, anchoredCount, invisible = 0, 0, 0
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    partCount = partCount + 1
                    if d.Anchored then anchoredCount = anchoredCount + 1 end
                    if d.Transparency >= 1 then invisible = invisible + 1 end
                    if partCount <= 80 then
                        add(string.format("  %s '%s' parent=%s anchored=%s transp=%.2f",
                            d.ClassName, d.Name,
                            d.Parent and d.Parent.Name or "?",
                            tostring(d.Anchored), d.Transparency))
                    end
                end
            end
            add(string.format("total parts: %d | anchored: %d | invisibles: %d",
                partCount, anchoredCount, invisible))

            add("---- SCRIPTS ----")
            local scriptCount = 0
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
                    scriptCount = scriptCount + 1
                    if scriptCount <= 25 then
                        local disabled = "?"
                        if d:IsA("Script") or d:IsA("LocalScript") then
                            disabled = tostring(d.Disabled)
                        end
                        add(string.format("  %s '%s' disabled=%s parent=%s",
                            d.ClassName, d.Name, disabled,
                            d.Parent and d.Parent.Name or "?"))
                    end
                end
            end
            add("total scripts: " .. scriptCount)

            add("---- UCAM POSES ----")
            if UCam.Poses then
                add("Current: " .. tostring(UCam.Poses.Current))
                local active = UCam.Poses._active
                if active then
                    local n = active.entries and #active.entries or 0
                    add("_active: char=" .. (active.character and active.character.Name or "?")
                        .. " | entries=" .. n)
                    for _, e in ipairs(active.entries or {}) do
                        local jn, jc, viaC0 = "?", "?", "false"
                        if e.joint then
                            jn = e.joint.Name
                            jc = e.joint.ClassName
                            viaC0 = tostring(e.c0 ~= nil)
                        end
                        add(string.format("  entry joint='%s' class=%s viaC0=%s", jn, jc, viaC0))
                    end
                else
                    add("_active: nil")
                end
            else
                add("UCam.Poses: nil")
            end
            add("========== FIN DUMP ==========")
            local text = table.concat(out, "\n")
            print(text)
            -- Consola externa del executor, si existe
            pcall(function()
                if rconsoleprint then rconsoleprint("\n" .. text .. "\n") end
            end)
            UCam.notify("Debug", "Dump impreso. Abre consola (F9) o la del executor.", 5)
        end,
    })
end
