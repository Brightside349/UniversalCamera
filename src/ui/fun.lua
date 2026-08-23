-- ============================================================
-- Universal Camera Pro v6 · ui/fun
-- Pestaña Diversión: montar, fisicas, tamano, poses, aspecto y efectos
-- visuales (trail, disco, material, invisibilidad).
-- ============================================================
local UCam = _G.UCam

function UCam.build_fun(Window)
    local FunTab = Window:CreateTab("😄 Diversión", "smile")

    FunTab:CreateSection("Montar sobre jugador")
    FunTab:CreateParagraph({
        Title   = "Como usar",
        Content = "Elige un jugador, configura el anclaje (cabeza, espalda u hombros) y activa el toggle. Tu personaje se montara sobre el y seguira sus movimientos. Funciona incluso si estas en camara libre.",
    })

    local funMountDropdown
    local function getFunMountOptions()
        local opts = { "(Selecciona uno)" }
        for _, p in ipairs(UCam.Players:GetPlayers()) do
            if p ~= UCam.player then
                table.insert(opts, p.DisplayName .. " (@" .. p.Name .. ")")
            end
        end
        return opts
    end

    funMountDropdown = FunTab:CreateDropdown({
        Name            = "Jugador a montar",
        Options         = getFunMountOptions(),
        CurrentOption   = { "(Selecciona uno)" },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value or value == "(Selecciona uno)" then
                UCam.Fun.Mount.Target = nil
                return
            end
            for _, p in ipairs(UCam.Players:GetPlayers()) do
                if p.DisplayName .. " (@" .. p.Name .. ")" == value then
                    UCam.Fun.Mount.Target = p
                    UCam.notify("Diversion", "Objetivo: " .. p.DisplayName)
                    return
                end
            end
        end,
    })

    FunTab:CreateButton({
        Name     = "Actualizar lista de jugadores",
        Callback = function()
            pcall(function() funMountDropdown:Refresh(getFunMountOptions()) end)
            UCam.notify("Diversion", "Lista actualizada.")
        end,
    })

    FunTab:CreateDropdown({
        Name            = "Punto de anclaje",
        Options         = UCam.Fun.Mount.AnchorModes,
        CurrentOption   = { UCam.Fun.Mount.Anchor },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Fun.Mount.Anchor = v end
        end,
    })

    FunTab:CreateSlider({
        Name         = "Altura extra sobre el ancla",
        Range        = { -3, 6 },
        Increment    = 0.1,
        Suffix       = "st",
        CurrentValue = UCam.Fun.Mount.HeightOffset,
        Callback     = function(v) UCam.Fun.Mount.HeightOffset = v end,
    })

    FunTab:CreateToggle({
        Name         = "Seguir rotacion del objetivo",
        CurrentValue = UCam.Fun.Mount.FollowRotation,
        Callback     = function(v) UCam.Fun.Mount.FollowRotation = v end,
    })

    FunTab:CreateToggle({
        Name         = "Montar / Bajar",
        CurrentValue = false,
        Callback     = function(v)
            if v and not UCam.Fun.Mount.Target then
                UCam.notify("Diversion", "Selecciona un jugador primero.")
                return
            end
            UCam.Fun.Mount.Enabled = v
            if v then
                UCam.startFun()
                UCam.notify("Diversion", "Montando sobre " .. (UCam.Fun.Mount.Target and UCam.Fun.Mount.Target.DisplayName or "?"))
            else
                UCam.notify("Diversion", "Has bajado del jugador.")
                if not UCam.funAnyActive() then UCam.stopFun() end
            end
        end,
    })

    FunTab:CreateSection("Fisicas del personaje")
    FunTab:CreateParagraph({
        Title   = "Quitar fisicas al personaje",
        Content = "Noclip te permite atravesar paredes. Gravedad Cero te hace flotar. Gravedad Reversa te lanza hacia el cielo. Todo es local (no se envia al server).",
    })

    FunTab:CreateToggle({
        Name         = "Noclip (atravesar paredes)",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.Noclip.Enabled = v
            if v then UCam.startFun() end
            UCam.notify("Diversion", v and "Noclip activado" or "Noclip desactivado")
        end,
    })

    FunTab:CreateToggle({
        Name         = "Activar gravedad custom",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.Gravity.Enabled = v
            if v then UCam.startFun() end
            UCam.notify("Diversion", v and ("Gravedad: " .. UCam.Fun.Gravity.Mode) or "Gravedad restaurada")
        end,
    })

    FunTab:CreateDropdown({
        Name            = "Modo de gravedad",
        Options         = UCam.Fun.Gravity.Modes,
        CurrentOption   = { UCam.Fun.Gravity.Mode },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Fun.Gravity.Mode = v end
            if UCam.Fun.Gravity.Enabled then UCam.notify("Diversion", "Gravedad: " .. v) end
        end,
    })

    FunTab:CreateSlider({
        Name         = "Gravedad custom (studs/s^2)",
        Range        = { 10, 500 },
        Increment    = 5,
        Suffix       = " st/s2",
        CurrentValue = UCam.Fun.Gravity.Custom,
        Callback     = function(v) UCam.Fun.Gravity.Custom = v end,
    })

    FunTab:CreateSection("Velocidad y salto")
    FunTab:CreateToggle({
        Name         = "Super velocidad",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.SpeedBoost.Enabled = v
            if v then UCam.startFun() end
            UCam.notify("Diversion", v and ("WalkSpeed: " .. UCam.Fun.SpeedBoost.WalkSpeed) or "Velocidad restaurada")
        end,
    })

    FunTab:CreateSlider({
        Name         = "Walk Speed",
        Range        = { 16, 500 },
        Increment    = 1,
        Suffix       = "st/s",
        CurrentValue = UCam.Fun.SpeedBoost.WalkSpeed,
        Callback     = function(v) UCam.Fun.SpeedBoost.WalkSpeed = v end,
    })

    FunTab:CreateToggle({
        Name         = "Super salto",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.SuperJump.Enabled = v
            if v then UCam.startFun() end
            UCam.notify("Diversion", v and ("Salto: " .. UCam.Fun.SuperJump.Power) or "Salto normal")
        end,
    })

    FunTab:CreateSlider({
        Name         = "Poder de salto",
        Range        = { 50, 500 },
        Increment    = 5,
        Suffix       = "",
        CurrentValue = UCam.Fun.SuperJump.Power,
        Callback     = function(v) UCam.Fun.SuperJump.Power = v end,
    })

    FunTab:CreateSection("Tamano uniforme del personaje (1x = normal)")
    FunTab:CreateParagraph({
        Title   = "Escala proporcional",
        Content = "El personaje completo, sus accesorios y sus articulaciones se escalan juntos para evitar deformaciones.",
    })
    FunTab:CreateToggle({
        Name         = "Aplicar escala uniforme",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.Scale.Enabled = v
            if v then
                UCam.startFun()
                UCam.funApplyScale(UCam.Fun.Scale.Value)
            else
                UCam.funRestorePartVisuals()
                UCam.funClearPartSnapshots()
                UCam.Fun._currentScale = 1.0
                if not UCam.funAnyActive() then UCam.stopFun() end
            end
        end,
    })

    FunTab:CreateSlider({
        Name         = "Escala uniforme",
        Range        = { 0.1, 10 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = UCam.Fun.Scale.Value,
        Callback     = function(v)
            UCam.Fun.Scale.Value = v
            if UCam.Fun.Scale.Enabled then UCam.funApplyScale(v) end
        end,
    })

    FunTab:CreateButton({
        Name     = "Diminuto (0.3x)",
        Callback = function()
            UCam.Fun.Scale.Value = 0.3
            UCam.Fun.Scale.Enabled = true
            UCam.startFun()
            UCam.funApplyScale(0.3)
            UCam.notify("Diversion", "Tamano diminuto")
        end,
    })

    FunTab:CreateButton({
        Name     = "Gigante (3x)",
        Callback = function()
            UCam.Fun.Scale.Value = 3
            UCam.Fun.Scale.Enabled = true
            UCam.startFun()
            UCam.funApplyScale(3)
            UCam.notify("Diversion", "Tamano gigante")
        end,
    })

    FunTab:CreateButton({
        Name     = "Enorme (5x)",
        Callback = function()
            UCam.Fun.Scale.Value = 5
            UCam.Fun.Scale.Enabled = true
            UCam.startFun()
            UCam.funApplyScale(5)
            UCam.notify("Diversion", "Enorme!")
        end,
    })

    FunTab:CreateButton({
        Name     = "Aleatorio (0.2x - 5x)",
        Callback = function()
            local s = math.random() * 4.8 + 0.2
            UCam.Fun.Scale.Value = s
            UCam.Fun.Scale.Enabled = true
            UCam.startFun()
            UCam.funApplyScale(s)
            UCam.notify("Diversion", string.format("Escala aleatoria: %.2fx", s))
        end,
    })

    FunTab:CreateButton({
        Name     = "Restaurar tamano",
        Callback = function()
            UCam.Fun.Scale.Enabled = false
            UCam.funRestorePartVisuals()
            UCam.funClearPartSnapshots()
            UCam.Fun._currentScale = 1.0
            UCam.notify("Diversion", "Tamano restaurado")
        end,
    })

    FunTab:CreateSection("Giros y vueltas")
    FunTab:CreateToggle({
        Name         = "Auto-girar cuerpo",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.BodySpin.Enabled = v
            if v then
                UCam.startFun()
                UCam.Fun._spinAngle = 0
            end
            UCam.notify("Diversion", v and "Girando..." or "Detenido")
        end,
    })

    FunTab:CreateSlider({
        Name         = "Velocidad de giro",
        Range        = { 30, 720 },
        Increment    = 10,
        Suffix       = " deg/s",
        CurrentValue = UCam.Fun.BodySpin.Speed,
        Callback     = function(v) UCam.Fun.BodySpin.Speed = v end,
    })

    FunTab:CreateDropdown({
        Name            = "Eje de giro",
        Options         = UCam.Fun.BodySpin.Axes,
        CurrentOption   = { UCam.Fun.BodySpin.Axis },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.Fun.BodySpin.Axis = v end
        end,
    })

    -- v9: sección "Pose forzada" eliminada — unificada en la pestaña 🧍 Poses
    -- (33_poses.lua), que además incluye T-Pose/Sentado/Flotando avanzados.

    FunTab:CreateSection("Aspecto (arcoiris / neon / material)")
    FunTab:CreateToggle({
        Name         = "Color arcoiris en el cuerpo",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.Rainbow.Enabled = v
            if v then UCam.startFun() end
            if not v then
                for part, color in pairs(UCam.Fun._origBodyColors) do
                    if part and part.Parent then
                        pcall(function() part.Color = color end)
                    end
                end
            end
            if not UCam.funAnyActive() then UCam.stopFun() end
            UCam.notify("Diversion", v and "Arcoiris activado" or "Colores restaurados")
        end,
    })

    FunTab:CreateSlider({
        Name         = "Velocidad del arcoiris",
        Range        = { 0.2, 5 },
        Increment    = 0.1,
        Suffix       = "x",
        CurrentValue = UCam.Fun.Rainbow.Speed,
        Callback     = function(v) UCam.Fun.Rainbow.Speed = v end,
    })

    FunTab:CreateToggle({
        Name         = "Brillo neon (Highlight)",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.NeonGlow.Enabled = v
            if v then UCam.startFun() end
            if not v then UCam.funClearHighlight() end
            if not UCam.funAnyActive() then UCam.stopFun() end
            UCam.notify("Diversion", v and "Brillo neon activado" or "Brillo desactivado")
        end,
    })

    local glowR, glowG, glowB = 0, 255, 200
    FunTab:CreateSlider({
        Name         = "Neon - Rojo",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = glowR,
        Callback     = function(v)
            glowR = math.floor(v)
            UCam.Fun.NeonGlow.Color = Color3.fromRGB(glowR, glowG, glowB)
        end,
    })
    FunTab:CreateSlider({
        Name         = "Neon - Verde",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = glowG,
        Callback     = function(v)
            glowG = math.floor(v)
            UCam.Fun.NeonGlow.Color = Color3.fromRGB(glowR, glowG, glowB)
        end,
    })
    FunTab:CreateSlider({
        Name         = "Neon - Azul",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = glowB,
        Callback     = function(v)
            glowB = math.floor(v)
            UCam.Fun.NeonGlow.Color = Color3.fromRGB(glowR, glowG, glowB)
        end,
    })

    -- v6: Material movido aqui (estaba suelto al final sin agrupar)
    FunTab:CreateDropdown({
        Name            = "Material del cuerpo (NUEVO v6)",
        Options         = UCam.Fun.Material.Options,
        CurrentOption   = { UCam.Fun.Material.Current },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            UCam.FunV6.applyMaterial(v)
            UCam.notify("Diversion", "Material: " .. v)
        end,
    })
    FunTab:CreateButton({
        Name     = "Restaurar material original",
        Callback = function()
            UCam.funRestorePartVisuals()
            UCam.Fun.Material.Current = "Plastic"
            UCam.notify("Diversion", "Material restaurado.")
        end,
    })

    FunTab:CreateSection("Efectos visuales (v6)")
    FunTab:CreateToggle({
        Name         = "Invisibilidad (local)",
        CurrentValue = false,
        Callback     = function(v)
            UCam.FunV6.setInvisibility(v)
            UCam.notify("Diversion", v and "Eres invisible (solo local)." or "Visible de nuevo.")
        end,
    })

    FunTab:CreateToggle({
        Name         = "Trail / estela",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.Trail.Enabled = v
            if v then
                UCam.startFun()
            else
                UCam.FunV6.clearTrail()
                if not UCam.funAnyActive() then UCam.stopFun() end
            end
            UCam.notify("Diversion", v and "Trail activado" or "Trail desactivado")
        end,
    })
    FunTab:CreateSlider({
        Name         = "Trail - Ancho",
        Range        = { 0.2, 4 },
        Increment    = 0.1,
        Suffix       = "st",
        CurrentValue = UCam.Fun.Trail.Width,
        Callback     = function(v) UCam.Fun.Trail.Width = v end,
    })
    FunTab:CreateSlider({
        Name         = "Trail - Duracion",
        Range        = { 0.3, 6 },
        Increment    = 0.1,
        Suffix       = "s",
        CurrentValue = UCam.Fun.Trail.Duration,
        Callback     = function(v) UCam.Fun.Trail.Duration = v end,
    })
    local trailR, trailG, trailB = 0, 200, 255
    FunTab:CreateSlider({
        Name         = "Trail - Rojo",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = trailR,
        Callback     = function(v)
            trailR = math.floor(v)
            UCam.Fun.Trail.Color = Color3.fromRGB(trailR, trailG, trailB)
        end,
    })
    FunTab:CreateSlider({
        Name         = "Trail - Verde",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = trailG,
        Callback     = function(v)
            trailG = math.floor(v)
            UCam.Fun.Trail.Color = Color3.fromRGB(trailR, trailG, trailB)
        end,
    })
    FunTab:CreateSlider({
        Name         = "Trail - Azul",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = trailB,
        Callback     = function(v)
            trailB = math.floor(v)
            UCam.Fun.Trail.Color = Color3.fromRGB(trailR, trailG, trailB)
        end,
    })

    FunTab:CreateToggle({
        Name         = "Disco floor (te sigue)",
        CurrentValue = false,
        Callback     = function(v)
            UCam.Fun.Disco.Enabled = v
            if v then
                UCam.startFun()
                UCam.FunV6.createDisco()
            else
                UCam.FunV6.destroyDisco()
                if not UCam.funAnyActive() then UCam.stopFun() end
            end
            UCam.notify("Diversion", v and "Disco floor activado" or "Disco floor desactivado")
        end,
    })
    FunTab:CreateSlider({
        Name         = "Disco - Tamano",
        Range        = { 4, 40 },
        Increment    = 1,
        Suffix       = "st",
        CurrentValue = UCam.Fun.Disco.Size,
        Callback     = function(v) UCam.Fun.Disco.Size = v end,
    })
    local discoR, discoG, discoB = 255, 0, 200
    FunTab:CreateSlider({
        Name         = "Disco - Rojo",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = discoR,
        Callback     = function(v)
            discoR = math.floor(v)
            UCam.Fun.Disco.Color = Color3.fromRGB(discoR, discoG, discoB)
        end,
    })
    FunTab:CreateSlider({
        Name         = "Disco - Verde",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = discoG,
        Callback     = function(v)
            discoG = math.floor(v)
            UCam.Fun.Disco.Color = Color3.fromRGB(discoR, discoG, discoB)
        end,
    })
    FunTab:CreateSlider({
        Name         = "Disco - Azul",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = discoB,
        Callback     = function(v)
            discoB = math.floor(v)
            UCam.Fun.Disco.Color = Color3.fromRGB(discoR, discoG, discoB)
        end,
    })

    FunTab:CreateSection("Acciones globales")
    FunTab:CreateButton({
        Name     = "Desactivar TODO (restaurar)",
        Callback = function()
            UCam.stopFun()
            UCam.notify("Diversion", "Todos los efectos desactivados. Personaje restaurado.")
        end,
    })

    -- Refrescar el dropdown cuando entren o salgan jugadores
    UCam.trackConnection(UCam.Players.PlayerAdded:Connect(function()
        task.defer(function()
            if funMountDropdown then
                pcall(function() funMountDropdown:Refresh(getFunMountOptions()) end)
            end
        end)
    end), "ui.fun.playerAdded")
    UCam.trackConnection(UCam.Players.PlayerRemoving:Connect(function()
        task.defer(function()
            if funMountDropdown then
                pcall(function() funMountDropdown:Refresh(getFunMountOptions()) end)
            end
            if UCam.Fun.Mount.Target and not UCam.Fun.Mount.Target.Parent then
                UCam.Fun.Mount.Target = nil
                UCam.Fun.Mount.Enabled = false
            end
        end)
    end), "ui.fun.playerRemoving")
end
