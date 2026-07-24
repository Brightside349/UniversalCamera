-- ============================================================
-- Universal Camera Pro v6 · ui/espectador
-- Pestaña Espectador: jugadores, auto-ciclo, 9 estilos de camara.
-- Registra el dropdown de jugadores en UCam.UIRefs.PlayerDropdown.
-- ============================================================
local UCam = _G.UCam

function UCam.build_espectador(Window)
    local SpectateTab = Window:CreateTab("👁️ Espectador", "users")
    SpectateTab:CreateSection("Jugadores")

    local function getDropdownOptions()
        local labels = UCam.getPlayerLabels()
        if #labels == 0 then return { "(Sin otros jugadores)" } end
        table.insert(labels, 1, "(Selecciona uno)")
        return labels
    end

    local function refreshPlayerList(dropdown)
        if not dropdown then return end
        pcall(function() dropdown:Refresh(getDropdownOptions()) end)
    end

    UCam.UIRefs.PlayerDropdown = SpectateTab:CreateDropdown({
        Name            = "Seleccionar jugador",
        Options         = getDropdownOptions(),
        CurrentOption   = { "(Selecciona uno)" },
        MultipleOptions = false,
        Callback        = function(options)
            local ok, err = pcall(function()
                local value = UCam.resolveDropdownValue(options)
                if not value then return end
                if value == "(Sin otros jugadores)" or value == "(Selecciona uno)" then return end
                local target = UCam.findPlayerByLabel(value)
                if target then
                    UCam.startSpectate(target)
                else
                    UCam.notify("Espectador", "Jugador no encontrado. Actualiza la lista.")
                end
            end)
            if not ok then warn("[Universal Camera] Espectador callback error: " .. tostring(err)) end
        end,
    })

    SpectateTab:CreateButton({
        Name     = "Actualizar lista",
        Callback = function()
            refreshPlayerList(UCam.UIRefs.PlayerDropdown)
            UCam.notify("Espectador", "Lista actualizada (" .. #UCam.getPlayerLabels() .. " jugadores).")
        end,
    })

    SpectateTab:CreateButton({
        Name     = "Dejar de espectar",
        Callback = function()
            if UCam.Spectate.Active then
                UCam.stopSpectate()
                UCam.notify("Espectador", "Espectador desactivado. Personaje restaurado.")
            else
                UCam.notify("Espectador", "No estas espectando a nadie.")
            end
        end,
    })

    SpectateTab:CreateButton({
        Name     = "Siguiente jugador (Keybind: E)",
        Callback = UCam.spectateNextPlayer,
    })

    SpectateTab:CreateButton({
        Name     = "Anterior jugador (Keybind: Q)",
        Callback = UCam.spectatePrevPlayer,
    })

    SpectateTab:CreateSection("Auto-ciclo")
    SpectateTab:CreateToggle({
        Name         = "Activar auto-ciclo",
        CurrentValue = UCam.AutoCycle.Enabled,
        Callback     = function(v) UCam.AutoCycle.Enabled = v end,
    })

    SpectateTab:CreateSlider({
        Name         = "Intervalo de auto-ciclo",
        Range        = { 3, 30 },
        Increment    = 1,
        Suffix       = "s",
        CurrentValue = UCam.AutoCycle.Interval,
        Callback     = function(v) UCam.AutoCycle.Interval = v end,
    })

    SpectateTab:CreateSection("Estilo de camara")
    SpectateTab:CreateDropdown({
        Name = "Estilo de camara (9 modos)",
        Options = UCam.Spectate.Modes,
        CurrentOption = { UCam.Spectate.Mode },
        MultipleOptions = false,
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value then
                UCam.Spectate.Mode  = value
                UCam.Spectate.Yaw   = 0
                UCam.Spectate.Pitch = 0
                if value == "Tercera persona" and UCam.Spectate.Active and UCam.Spectate.Target then
                    local char = UCam.Spectate.Target.Character
                    if char then
                        local hrp = UCam.getCharacterRoot(char)
                        if hrp then
                            local look = hrp.CFrame.LookVector
                            UCam.Spectate.Yaw = math.atan2(-look.X, -look.Z)
                        end
                    end
                end
            end
        end,
    })

    SpectateTab:CreateSlider({
        Name = "Suavizado",
        Range = { 1, 25 },
        Increment = 1,
        CurrentValue = UCam.Spectate.Smoothing,
        Callback = function(v) UCam.Spectate.Smoothing = v end,
    })

    SpectateTab:CreateSlider({
        Name = "Distancia (3ra / Cinematografico)",
        Range = { 4, 40 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Spectate.Distance,
        Callback = function(v) UCam.Spectate.Distance = v end,
    })

    SpectateTab:CreateSlider({
        Name = "Altura de camara",
        Range = { -5, 20 },
        Increment = 1,
        Suffix = "st",
        CurrentValue = UCam.Spectate.Height,
        Callback = function(v) UCam.Spectate.Height = v end,
    })

    SpectateTab:CreateSection("FOV y visibilidad")
    SpectateTab:CreateToggle({
        Name = "Usar FOV personalizado",
        CurrentValue = UCam.Spectate.UseCustomFOV,
        Callback = function(v) UCam.Spectate.UseCustomFOV = v end,
    })
    SpectateTab:CreateSlider({
        Name = "FOV espectador",
        Range = { UCam.MIN_FOV, UCam.MAX_FOV },
        Increment = 1,
        Suffix = " grados",
        CurrentValue = UCam.Spectate.FOV,
        Callback = function(v)
            UCam.Spectate.FOV = v
            if UCam.Spectate.Active and UCam.Spectate.UseCustomFOV then
                UCam.camera.FieldOfView = v
            end
        end,
    })
    SpectateTab:CreateToggle({
        Name = "Ocultar mi personaje al espectar",
        CurrentValue = UCam.Spectate.HideSelf,
        Callback = function(v) UCam.Spectate.HideSelf = v end,
    })

    UCam.Players.PlayerAdded:Connect(function()
        task.defer(function() refreshPlayerList(UCam.UIRefs.PlayerDropdown) end)
    end)
    UCam.Players.PlayerRemoving:Connect(function(p)
        task.defer(function()
            if UCam.Spectate.Active and UCam.Spectate.Target == p then
                UCam.notify("Espectador", p.DisplayName .. " salio del juego.")
                UCam.stopSpectate()
            end
            refreshPlayerList(UCam.UIRefs.PlayerDropdown)
        end)
    end)
end
