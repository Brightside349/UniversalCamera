-- ============================================================
-- Universal Camera Pro v6 · ui/slowmo
-- Pestaña Camara Lenta (Bullet Time): toggle + TODOS sus ajustes.
-- Registra el slider de intensidad en UCam.UISliders.
-- ============================================================
local UCam = _G.UCam

function UCam.build_slowmo(Window)
    local SlowMoTab = Window:CreateTab("⏱️ Cámara Lenta", "hourglass")
    local s = UCam.UISliders

    SlowMoTab:CreateSection("Control")
    SlowMoTab:CreateToggle({
        Name         = "Camara Lenta (Bullet Time)",
        CurrentValue = false,
        Callback     = UCam.toggleBulletTime,
    })

    SlowMoTab:CreateSection("Ajustes")
    s.slowMoIntensitySlider = SlowMoTab:CreateSlider({
        Name = "Intensidad (mayor = mas lento)",
        Range = { 0, 100 },
        Increment = 1,
        Suffix = "%",
        CurrentValue = UCam.SlowMo.Intensity,
        Callback = function(v) UCam.SlowMo.Intensity = v end,
    })
    SlowMoTab:CreateToggle({
        Name = "Modo Freeze (congelar todo)",
        CurrentValue = UCam.SlowMo.Freeze,
        Callback = function(v) UCam.SlowMo.Freeze = v end,
    })
    SlowMoTab:CreateDropdown({
        Name = "Alcance",
        Options = UCam.SlowMo.Scopes,
        CurrentOption = { UCam.SlowMo.Scope },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o); if v then UCam.SlowMo.Scope = v end
        end,
    })
    SlowMoTab:CreateToggle({
        Name = "Afectar mi personaje",
        CurrentValue = UCam.SlowMo.AffectsLocal,
        Callback = function(v) UCam.SlowMo.AffectsLocal = v end,
    })
    SlowMoTab:CreateToggle({
        Name = "Afectar otros jugadores",
        CurrentValue = UCam.SlowMo.AffectsOther,
        Callback = function(v) UCam.SlowMo.AffectsOther = v end,
    })
    SlowMoTab:CreateToggle({
        Name = "Afectar NPCs",
        CurrentValue = UCam.SlowMo.AffectsNPC,
        Callback = function(v) UCam.SlowMo.AffectsNPC = v end,
    })
    SlowMoTab:CreateToggle({
        Name = "Afectar objetos fisicos",
        CurrentValue = UCam.SlowMo.AffectsPhysics,
        Callback = function(v) UCam.SlowMo.AffectsPhysics = v end,
    })
end
