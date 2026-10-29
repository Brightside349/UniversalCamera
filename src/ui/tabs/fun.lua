-- ============================================================
-- Universal Camera Pro v12.5 · ui/fun
-- Pestaña Diversión: montar, física, tamaño, giro, aspecto y efectos.
--
-- v12.5: se agruparon las opciones por tema, se reemplazaron los botones
-- de tamaño por un selector y se corrigió la restauración de color,
-- material y trail para que los toggles no queden desincronizados.
-- ============================================================
local UCam = _G.UCam

function UCam.build_fun(Window)
    local Tab = Window:CreateTab("😄 Diversión", "smile")
    local F = UCam.Fun

    local function stopIfIdle()
        if not UCam.funAnyActive() then UCam.stopFun() end
    end

    -- ============================================================
    -- MONTAR
    -- ============================================================
    Tab:CreateSection("Montar sobre un jugador")
    local mountDropdown
    local function getMountOptions()
        local opts = { "(Selecciona uno)" }
        for _, p in ipairs(UCam.Players:GetPlayers()) do
            if p ~= UCam.player then
                table.insert(opts, p.DisplayName .. " (@" .. p.Name .. ")")
            end
        end
        return opts
    end
    mountDropdown = Tab:CreateDropdown({
        Name = "Jugador",
        Options = getMountOptions(),
        CurrentOption = { "(Selecciona uno)" },
        MultipleOptions = false,
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value or value == "(Selecciona uno)" then
                F.Mount.Target = nil
                return
            end
            for _, p in ipairs(UCam.Players:GetPlayers()) do
                if p.DisplayName .. " (@" .. p.Name .. ")" == value then
                    F.Mount.Target = p
                    UCam.notify("Diversión", "Objetivo: " .. p.DisplayName)
                    return
                end
            end
        end,
    })
    Tab:CreateButton({
        Name = "🔄 Actualizar lista",
        Callback = function()
            pcall(function() mountDropdown:Refresh(getMountOptions()) end)
        end,
    })
    Tab:CreateDropdown({
        Name = "Punto de anclaje",
        Options = F.Mount.AnchorModes,
        CurrentOption = { F.Mount.Anchor },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then F.Mount.Anchor = v end
        end,
    })
    Tab:CreateSlider({
        Name = "Altura extra", Range = { -3, 6 }, Increment = 0.1, Suffix = "st",
        CurrentValue = F.Mount.HeightOffset,
        Callback = function(v) F.Mount.HeightOffset = v end,
    })
    Tab:CreateToggle({
        Name = "Seguir rotación del objetivo",
        CurrentValue = F.Mount.FollowRotation,
        Callback = function(v) F.Mount.FollowRotation = v end,
    })
    Tab:CreateToggle({
        Name = "Montar / Bajar",
        CurrentValue = false,
        Callback = function(v)
            if v and not F.Mount.Target then
                UCam.notify("Diversión", "Selecciona un jugador primero.")
                return
            end
            F.Mount.Enabled = v
            if v then
                UCam.startFun()
                UCam.notify("Diversión", "Montando sobre " .. (F.Mount.Target and F.Mount.Target.DisplayName or "?"))
            else
                if not UCam.funAnyActive() then UCam.stopFun() end
            end
        end,
    })

    -- ============================================================
    -- FÍSICA
    -- ============================================================
    Tab:CreateSection("Física")
    Tab:CreateToggle({
        Name = "Noclip (atravesar paredes)",
        CurrentValue = F.Noclip.Enabled,
        Callback = function(v)
            F.Noclip.Enabled = v
            if v then UCam.startFun() else stopIfIdle() end
        end,
    })
    Tab:CreateToggle({
        Name = "Gravedad personalizada",
        CurrentValue = F.Gravity.Enabled,
        Callback = function(v)
            F.Gravity.Enabled = v
            if v then UCam.startFun() else stopIfIdle() end
        end,
    })
    Tab:CreateDropdown({
        Name = "Modo de gravedad",
        Options = F.Gravity.Modes,
        CurrentOption = { F.Gravity.Mode },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then F.Gravity.Mode = v end
        end,
    })
    Tab:CreateSlider({
        Name = "Gravedad personalizada (st/s²)", Range = { 10, 500 }, Increment = 5, Suffix = " st/s²",
        CurrentValue = F.Gravity.Custom,
        Callback = function(v) F.Gravity.Custom = v end,
    })

    Tab:CreateSection("Velocidad y salto")
    Tab:CreateToggle({
        Name = "Super velocidad",
        CurrentValue = F.SpeedBoost.Enabled,
        Callback = function(v)
            F.SpeedBoost.Enabled = v
            if v then UCam.startFun() else stopIfIdle() end
        end,
    })
    Tab:CreateSlider({
        Name = "WalkSpeed", Range = { 16, 500 }, Increment = 1, Suffix = "st/s",
        CurrentValue = F.SpeedBoost.WalkSpeed,
        Callback = function(v) F.SpeedBoost.WalkSpeed = v end,
    })
    Tab:CreateToggle({
        Name = "Super salto",
        CurrentValue = F.SuperJump.Enabled,
        Callback = function(v)
            F.SuperJump.Enabled = v
            if v then UCam.startFun() else stopIfIdle() end
        end,
    })
    Tab:CreateSlider({
        Name = "Poder de salto", Range = { 50, 500 }, Increment = 5,
        CurrentValue = F.SuperJump.Power,
        Callback = function(v) F.SuperJump.Power = v end,
    })

    -- ============================================================
    -- TAMAÑO
    -- ============================================================
    Tab:CreateSection("Tamaño del personaje")
    Tab:CreateParagraph({
        Title = "Solo visual y local",
        Content = "El cambio lo ves únicamente tú. Se aplica a cuerpo, accesorios y articulaciones de forma proporcional.",
    })
    Tab:CreateToggle({
        Name = "Aplicar escala",
        CurrentValue = F.Scale.Enabled,
        Callback = function(v)
            F.Scale.Enabled = v
            if v then
                UCam.startFun()
                UCam.funApplyScale(F.Scale.Value)
            else
                UCam.funRestorePartVisuals()
                UCam.funClearPartSnapshots()
                F._currentScale = 1.0
                stopIfIdle()
            end
        end,
    })
    Tab:CreateSlider({
        Name = "Escala", Range = { 0.1, 10 }, Increment = 0.1, Suffix = "x",
        CurrentValue = F.Scale.Value,
        Callback = function(v)
            F.Scale.Value = v
            if F.Scale.Enabled then UCam.funApplyScale(v) end
        end,
    })
    Tab:CreateDropdown({
        Name = "Atajos de tamaño",
        Options = { "Diminuto (0.3x)", "Gigante (3x)", "Enorme (5x)", "Aleatorio (0.2x - 5x)", "Restaurar (1x)" },
        CurrentOption = { "Restaurar (1x)" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            if v == "Restaurar (1x)" then
                F.Scale.Enabled = false
                UCam.funRestorePartVisuals()
                UCam.funClearPartSnapshots()
                F._currentScale = 1.0
                stopIfIdle()
                UCam.notify("Diversión", "Tamaño restaurado.")
                return
            end
            local s
            if v:match("^Diminuto") then s = 0.3
            elseif v:match("^Gigante") then s = 3
            elseif v:match("^Enorme") then s = 5
            else s = math.random() * 4.8 + 0.2 end
            F.Scale.Value = s
            F.Scale.Enabled = true
            UCam.startFun()
            UCam.funApplyScale(s)
            UCam.notify("Diversión", string.format("Escala: %.2fx", s))
        end,
    })

    -- ============================================================
    -- GIRO
    -- ============================================================
    Tab:CreateSection("Giros")
    Tab:CreateToggle({
        Name = "Auto-girar cuerpo",
        CurrentValue = F.BodySpin.Enabled,
        Callback = function(v)
            F.BodySpin.Enabled = v
            if v then
                UCam.startFun()
                F._spinAngle = 0
            else
                stopIfIdle()
            end
        end,
    })
    Tab:CreateSlider({
        Name = "Velocidad", Range = { 30, 720 }, Increment = 10, Suffix = " deg/s",
        CurrentValue = F.BodySpin.Speed,
        Callback = function(v) F.BodySpin.Speed = v end,
    })
    Tab:CreateDropdown({
        Name = "Eje",
        Options = F.BodySpin.Axes,
        CurrentOption = { F.BodySpin.Axis },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then F.BodySpin.Axis = v end
        end,
    })

    -- ============================================================
    -- ASPECTO
    -- ============================================================
    Tab:CreateSection("Aspecto del cuerpo")
    Tab:CreateToggle({
        Name = "Arcoíris animado",
        CurrentValue = F.Rainbow.Enabled,
        Callback = function(v)
            F.Rainbow.Enabled = v
            if v then
                UCam.startFun()
            else
                for part, color in pairs(F._origBodyColors or {}) do
                    if part and part.Parent then
                        pcall(function() part.Color = color end)
                    end
                end
                stopIfIdle()
            end
        end,
    })
    Tab:CreateSlider({
        Name = "Velocidad del arcoíris", Range = { 0.2, 5 }, Increment = 0.1, Suffix = "x",
        CurrentValue = F.Rainbow.Speed,
        Callback = function(v) F.Rainbow.Speed = v end,
    })
    Tab:CreateDropdown({
        Name = "Material",
        Options = F.Material.Options,
        CurrentOption = { F.Material.Current },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then UCam.funApplyMaterial(v) end
        end,
    })
    Tab:CreateToggle({
        Name = "Brillo neón (Highlight)",
        CurrentValue = F.NeonGlow.Enabled,
        Callback = function(v)
            F.NeonGlow.Enabled = v
            if v then UCam.startFun() else UCam.funClearHighlight(); stopIfIdle() end
        end,
    })
    Tab:CreateSlider({
        Name = "Neón R", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.NeonGlow.Color.R * 255),
        Callback = function(v)
            F.NeonGlow.Color = Color3.fromRGB(math.floor(v),
                math.floor(F.NeonGlow.Color.G * 255), math.floor(F.NeonGlow.Color.B * 255))
        end,
    })
    Tab:CreateSlider({
        Name = "Neón G", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.NeonGlow.Color.G * 255),
        Callback = function(v)
            F.NeonGlow.Color = Color3.fromRGB(math.floor(F.NeonGlow.Color.R * 255),
                math.floor(v), math.floor(F.NeonGlow.Color.B * 255))
        end,
    })
    Tab:CreateSlider({
        Name = "Neón B", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.NeonGlow.Color.B * 255),
        Callback = function(v)
            F.NeonGlow.Color = Color3.fromRGB(math.floor(F.NeonGlow.Color.R * 255),
                math.floor(F.NeonGlow.Color.G * 255), math.floor(v))
        end,
    })

    -- ============================================================
    -- EFECTOS
    -- ============================================================
    Tab:CreateSection("Efectos visuales")
    Tab:CreateToggle({
        Name = "Invisibilidad (local)",
        CurrentValue = F.Invisibility.Enabled,
        Callback = function(v)
            UCam.funSetInvisibility(v)
            if not v then stopIfIdle() end
        end,
    })
    Tab:CreateToggle({
        Name = "Trail / estela",
        CurrentValue = F.Trail.Enabled,
        Callback = function(v)
            F.Trail.Enabled = v
            if v then
                UCam.startFun()
            else
                UCam.funClearTrail()
                stopIfIdle()
            end
        end,
    })
    Tab:CreateSlider({
        Name = "Trail - ancho", Range = { 0.2, 4 }, Increment = 0.1, Suffix = "st",
        CurrentValue = F.Trail.Width,
        Callback = function(v) F.Trail.Width = v end,
    })
    Tab:CreateSlider({
        Name = "Trail - duración", Range = { 0.3, 6 }, Increment = 0.1, Suffix = "s",
        CurrentValue = F.Trail.Duration,
        Callback = function(v) F.Trail.Duration = v end,
    })
    Tab:CreateSlider({
        Name = "Trail R", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.Trail.Color.R * 255),
        Callback = function(v)
            F.Trail.Color = Color3.fromRGB(math.floor(v),
                math.floor(F.Trail.Color.G * 255), math.floor(F.Trail.Color.B * 255))
        end,
    })
    Tab:CreateSlider({
        Name = "Trail G", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.Trail.Color.G * 255),
        Callback = function(v)
            F.Trail.Color = Color3.fromRGB(math.floor(F.Trail.Color.R * 255),
                math.floor(v), math.floor(F.Trail.Color.B * 255))
        end,
    })
    Tab:CreateSlider({
        Name = "Trail B", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.Trail.Color.B * 255),
        Callback = function(v)
            F.Trail.Color = Color3.fromRGB(math.floor(F.Trail.Color.R * 255),
                math.floor(F.Trail.Color.G * 255), math.floor(v))
        end,
    })
    Tab:CreateToggle({
        Name = "Disco floor (te sigue)",
        CurrentValue = F.Disco.Enabled,
        Callback = function(v)
            F.Disco.Enabled = v
            if v then
                UCam.startFun()
                UCam.funCreateDisco()
            else
                UCam.funDestroyDisco()
                stopIfIdle()
            end
        end,
    })
    Tab:CreateSlider({
        Name = "Disco - tamaño", Range = { 4, 40 }, Increment = 1, Suffix = "st",
        CurrentValue = F.Disco.Size,
        Callback = function(v) F.Disco.Size = v end,
    })
    Tab:CreateSlider({
        Name = "Disco R", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.Disco.Color.R * 255),
        Callback = function(v)
            F.Disco.Color = Color3.fromRGB(math.floor(v),
                math.floor(F.Disco.Color.G * 255), math.floor(F.Disco.Color.B * 255))
        end,
    })
    Tab:CreateSlider({
        Name = "Disco G", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.Disco.Color.G * 255),
        Callback = function(v)
            F.Disco.Color = Color3.fromRGB(math.floor(F.Disco.Color.R * 255),
                math.floor(v), math.floor(F.Disco.Color.B * 255))
        end,
    })
    Tab:CreateSlider({
        Name = "Disco B", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(F.Disco.Color.B * 255),
        Callback = function(v)
            F.Disco.Color = Color3.fromRGB(math.floor(F.Disco.Color.R * 255),
                math.floor(F.Disco.Color.G * 255), math.floor(v))
        end,
    })

    Tab:CreateSection("Restaurar")
    Tab:CreateButton({
        Name = "🧹 Desactivar TODO",
        Callback = function()
            UCam.stopFun()
            UCam.notify("Diversión", "Todo desactivado. Personaje restaurado.")
        end,
    })

    UCam.trackConnection(UCam.Players.PlayerAdded:Connect(function()
        task.defer(function()
            pcall(function() mountDropdown:Refresh(getMountOptions()) end)
        end)
    end), "ui.fun.playerAdded")
    UCam.trackConnection(UCam.Players.PlayerRemoving:Connect(function()
        task.defer(function()
            pcall(function() mountDropdown:Refresh(getMountOptions()) end)
            if F.Mount.Target and not F.Mount.Target.Parent then
                F.Mount.Target = nil
                F.Mount.Enabled = false
            end
        end)
    end), "ui.fun.playerRemoving")
end
