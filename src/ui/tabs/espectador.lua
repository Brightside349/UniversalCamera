-- ============================================================
-- Universal Camera Pro v12.5 · ui/espectador
-- Pestaña Espectador: elegir jugador, navegar, auto-ciclo y estilo.
--
-- v12.5: se eliminaron favoritos y el "Director Espectador" (duplicaba
-- Cinematográfico). El encuadre solo aparece cuando el estilo lo usa y
-- las opciones avanzadas quedaron agrupadas.
-- ============================================================
local UCam = _G.UCam

local TAB_NAME = "👁️ Espectador"

function UCam.build_espectador(Window)
    local SpectateTab = Window:CreateTab(TAB_NAME, "users")

    local function getDropdownOptions()
        local labels = UCam.getPlayerLabels()
        if #labels == 0 then return { "(Sin otros jugadores)" } end
        table.insert(labels, 1, "(Selecciona uno)")
        return labels
    end

    local function refreshPlayerList()
        local dd = UCam.UIRefs.PlayerDropdown
        if dd then pcall(function() dd:Refresh(getDropdownOptions()) end) end
    end

    SpectateTab:CreateSection("Jugadores")
    UCam.UIRefs.PlayerDropdown = SpectateTab:CreateDropdown({
        Name            = "Espectar a",
        Options         = getDropdownOptions(),
        CurrentOption   = { "(Selecciona uno)" },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value or value == "(Sin otros jugadores)" or value == "(Selecciona uno)" then return end
            local target = UCam.findPlayerByLabel(value)
            if target then
                UCam.startSpectate(target)
            else
                UCam.notify("Espectador", "Jugador no encontrado. Actualiza la lista.")
            end
        end,
    })

    SpectateTab:CreateButton({
        Name     = "🔄 Actualizar lista",
        Callback = function()
            refreshPlayerList()
            UCam.notify("Espectador", "Lista actualizada (" .. #UCam.getPlayerLabels() .. " jugadores).")
        end,
    })
    SpectateTab:CreateButton({
        Name     = "Siguiente jugador (E)",
        Callback = UCam.spectateNextPlayer,
    })
    SpectateTab:CreateButton({
        Name     = "Anterior jugador (Q)",
        Callback = UCam.spectatePrevPlayer,
    })
    SpectateTab:CreateButton({
        Name     = "Dejar de espectar (X)",
        Callback = function()
            if UCam.Spectate.Active then
                UCam.stopSpectate()
                UCam.notify("Espectador", "Espectador desactivado.")
            else
                UCam.notify("Espectador", "No estás espectando a nadie.")
            end
        end,
    })

    SpectateTab:CreateSection("Auto-ciclo")
    SpectateTab:CreateToggle({
        Name         = "Activar auto-ciclo",
        CurrentValue = UCam.AutoCycle.Enabled,
        Flag         = "SpectateAutoCycle",
        Callback     = function(v) UCam.AutoCycle.Enabled = v end,
    })
    SpectateTab:CreateSlider({
        Name         = "Intervalo", Range = { 3, 30 }, Increment = 1, Suffix = "s",
        CurrentValue = UCam.AutoCycle.Interval,
        Callback     = function(v) UCam.AutoCycle.Interval = v end,
    })

    SpectateTab:CreateSection("Estilo de cámara")
    SpectateTab:CreateDropdown({
        Name = "Estilo",
        Options = UCam.Spectate.Modes,
        CurrentOption = { UCam.Spectate.Mode },
        MultipleOptions = false,
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value then return end
            UCam.Spectate.Mode  = value
            UCam.Spectate.Yaw   = 0
            UCam.Spectate.Pitch = 0
            if value == "Tercera persona" and UCam.Spectate.Active and UCam.Spectate.Target then
                local char = UCam.Spectate.Target.Character
                local hrp = char and UCam.getCharacterRoot(char)
                if hrp then
                    local look = hrp.CFrame.LookVector
                    UCam.Spectate.Yaw = math.atan2(-look.X, -look.Z)
                end
            end
            if UCam.SpectateFrame then
                UCam.SpectateFrame.setVisible(value ~= "Primera persona")
            end
        end,
    })

    -- Panel condicional: solo tiene sentido cuando el estilo se aleja del jugador.
    local framing = UCam.createUIGroup(TAB_NAME)
    framing.begin()
    SpectateTab:CreateSlider({
        Name = "Distancia", Range = { 4, 40 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Spectate.Distance,
        Callback = function(v) UCam.Spectate.Distance = v end,
    })
    SpectateTab:CreateSlider({
        Name = "Altura de cámara", Range = { -5, 20 }, Increment = 1, Suffix = "st",
        CurrentValue = UCam.Spectate.Height,
        Callback = function(v) UCam.Spectate.Height = v end,
    })
    SpectateTab:CreateSlider({
        Name = "Suavizado", Range = { 1, 25 }, Increment = 1,
        CurrentValue = UCam.Spectate.Smoothing,
        Callback = function(v) UCam.Spectate.Smoothing = v end,
    })
    framing.finish()
    UCam.SpectateFrame = framing

    SpectateTab:CreateSection("Lente y visibilidad")
    SpectateTab:CreateToggle({
        Name = "Usar FOV personalizado", CurrentValue = UCam.Spectate.UseCustomFOV,
        Callback = function(v) UCam.Spectate.UseCustomFOV = v end,
    })
    SpectateTab:CreateSlider({
        Name = "FOV", Range = { UCam.MIN_FOV, UCam.MAX_FOV }, Increment = 1, Suffix = " grados",
        CurrentValue = UCam.Spectate.FOV,
        Callback = function(v)
            UCam.Spectate.FOV = v
            if UCam.Spectate.Active and UCam.Spectate.UseCustomFOV then
                UCam.camera.FieldOfView = v
            end
        end,
    })
    SpectateTab:CreateToggle({
        Name = "Ocultar mi personaje al espectar", CurrentValue = UCam.Spectate.HideSelf,
        Callback = function(v) UCam.Spectate.HideSelf = v end,
    })

    SpectateTab:CreateSection("Avanzado")
    SpectateTab:CreateToggle({
        Name = "Anti-clip (evitar paredes)", CurrentValue = UCam.Spectate.AntiClip,
        Callback = function(v) UCam.Spectate.AntiClip = v end,
    })
    SpectateTab:CreateToggle({
        Name = "Zoom con la rueda", CurrentValue = UCam.Spectate.ZoomScroll,
        Callback = function(v) UCam.Spectate.ZoomScroll = v end,
    })
    SpectateTab:CreateToggle({
        Name = "Saltar solo si el objetivo cae", CurrentValue = UCam.Spectate.AutoJump,
        Callback = function(v) UCam.Spectate.AutoJump = v end,
    })

    framing.setVisible(UCam.Spectate.Mode ~= "Primera persona")

    -- Mantener la lista al día
    UCam.trackConnection(UCam.Players.PlayerAdded:Connect(function()
        task.defer(refreshPlayerList)
    end), "ui.spectate.playerAdded")
    UCam.trackConnection(UCam.Players.PlayerRemoving:Connect(function(p)
        task.defer(function()
            if UCam.Spectate.Active and UCam.Spectate.Target == p then
                UCam.notify("Espectador", p.DisplayName .. " salió del juego.")
                if UCam.Spectate.AutoJump then
                    UCam.spectateAutoJump()
                else
                    UCam.stopSpectate()
                end
            end
            refreshPlayerList()
        end)
    end), "ui.spectate.playerRemoving")
end
