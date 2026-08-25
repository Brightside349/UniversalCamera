-- ============================================================
-- Universal Camera Pro v6 · ui/gimbal
-- Pestaña Gimbal / LookAt Lock: bloquea el objetivo de la camara.
-- ============================================================
local UCam = _G.UCam

function UCam.build_gimbal(Window)
    local LookAtTab = Window:CreateTab("🎯 Gimbal", "crosshair")

    LookAtTab:CreateSection("Bloqueo de Objetivo (LookAt Lock)")
    LookAtTab:CreateParagraph({
        Title   = "Como usar",
        Content = "Elige un jugador del dropdown, activa el bloqueo y la camara apuntara hacia el automaticamente. Funciona en modos Libre, Handheld y Crane. Mueve la camara con WASD y el lente seguira al objetivo.",
    })

    local lookAtPlayerDropdown
    local function getLookAtPlayerOptions()
        local opts = { "(Ninguno)" }
        for _, p in ipairs(UCam.Players:GetPlayers()) do
            table.insert(opts, p.DisplayName .. " (@" .. p.Name .. ")")
        end
        return opts
    end

    lookAtPlayerDropdown = LookAtTab:CreateDropdown({
        Name            = "Objetivo a seguir",
        Options         = getLookAtPlayerOptions(),
        CurrentOption   = { "(Ninguno)" },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value or value == "(Ninguno)" then
                UCam.LookAtLock.Target = nil
                UCam.notify("Gimbal", "Objetivo liberado.")
                return
            end
            for _, p in ipairs(UCam.Players:GetPlayers()) do
                if p.DisplayName .. " (@" .. p.Name .. ")" == value then
                    UCam.LookAtLock.Target = p
                    UCam.notify("Gimbal", "Objetivo: " .. p.DisplayName)
                    return
                end
            end
        end,
    })

    LookAtTab:CreateButton({
        Name     = "Actualizar lista de jugadores",
        Callback = function()
            pcall(function() lookAtPlayerDropdown:Refresh(getLookAtPlayerOptions()) end)
            UCam.notify("Gimbal", "Lista actualizada.")
        end,
    })

    LookAtTab:CreateToggle({
        Name         = "Activar Bloqueo de Objetivo",
        CurrentValue = UCam.LookAtLock.Enabled,
        Callback     = function(v)
            UCam.LookAtLock.Enabled = v
            if v and not UCam.LookAtLock.Target then
                UCam.notify("Gimbal", "Selecciona un objetivo primero.")
            elseif v then
                UCam.notify("Gimbal", "Bloqueo activado -> " .. (UCam.LookAtLock.Target.DisplayName or "?"))
            else
                UCam.notify("Gimbal", "Bloqueo desactivado.")
            end
        end,
    })

    LookAtTab:CreateSlider({
        Name         = "Suavidad del gimbal",
        Range        = { 0, 25 },
        Increment    = 0.5,
        Suffix       = "x",
        CurrentValue = UCam.LookAtLock.Smoothing,
        Callback     = function(v) UCam.LookAtLock.Smoothing = v end,
    })

    LookAtTab:CreateSlider({
        Name         = "Offset de altura del objetivo",
        Range        = { -3, 5 },
        Increment    = 0.1,
        Suffix       = "st",
        CurrentValue = UCam.LookAtLock.HeightOffset,
        Callback     = function(v) UCam.LookAtLock.HeightOffset = v end,
    })

    LookAtTab:CreateButton({
        Name     = "Liberar objetivo (apagar gimbal)",
        Callback = function()
            UCam.LookAtLock.Enabled = false
            UCam.LookAtLock.Target  = nil
            pcall(function() lookAtPlayerDropdown:Set({ "(Ninguno)" }) end)
            UCam.notify("Gimbal", "Bloqueo liberado.")
        end,
    })
end
