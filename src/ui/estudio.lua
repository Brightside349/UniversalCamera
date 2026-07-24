-- ============================================================
-- Universal Camera Pro v6 · ui/estudio
-- Pestaña Estudio / Croma: pantalla verde con colocacion configurable.
-- ============================================================
local UCam = _G.UCam

function UCam.build_estudio(Window)
    local CromaTab = Window:CreateTab("🟩 Estudio", "tv")

    CromaTab:CreateSection("Pantalla Verde / Estudio de Croma")
    CromaTab:CreateParagraph({
        Title   = "Como usar",
        Content = "Genera un panel solido de color detras de tu personaje. Perfecto para grabaciones en las que necesitas un fondo uniforme para chroma key en edicion de video.",
    })

    CromaTab:CreateToggle({
        Name         = "Activar pantalla de croma",
        CurrentValue = UCam.GreenScreen.Enabled,
        Callback     = function(v)
            UCam.GreenScreen.Enabled = v
            UCam.updateGreenScreen()
            if v then
                UCam.notify("Estudio / Croma", "Pantalla creada detras del personaje.")
            else
                UCam.notify("Estudio / Croma", "Pantalla eliminada.")
            end
        end,
    })

    CromaTab:CreateSection("Color de fondo")
    CromaTab:CreateDropdown({
        Name            = "Preajuste de color",
        Options         = { "Verde Croma", "Azul Croma", "Blanco Estudio", "Negro Estudio", "Personalizado" },
        CurrentOption   = { "Verde Croma" },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value == "Verde Croma" then
                UCam.GreenScreen.Color = Color3.fromRGB(0, 255, 0)
            elseif value == "Azul Croma" then
                UCam.GreenScreen.Color = Color3.fromRGB(0, 0, 255)
            elseif value == "Blanco Estudio" then
                UCam.GreenScreen.Color = Color3.fromRGB(255, 255, 255)
            elseif value == "Negro Estudio" then
                UCam.GreenScreen.Color = Color3.fromRGB(0, 0, 0)
            end
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
            if value ~= "Personalizado" then
                UCam.notify("Estudio / Croma", "Color: " .. value)
            end
        end,
    })

    local cromaR, cromaG, cromaB = 0, 255, 0
    CromaTab:CreateSlider({
        Name         = "Rojo",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = cromaR,
        Callback     = function(v)
            cromaR = math.floor(v)
            UCam.GreenScreen.Color = Color3.fromRGB(cromaR, cromaG, cromaB)
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Verde",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = cromaG,
        Callback     = function(v)
            cromaG = math.floor(v)
            UCam.GreenScreen.Color = Color3.fromRGB(cromaR, cromaG, cromaB)
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Azul",
        Range        = { 0, 255 },
        Increment    = 1,
        CurrentValue = cromaB,
        Callback     = function(v)
            cromaB = math.floor(v)
            UCam.GreenScreen.Color = Color3.fromRGB(cromaR, cromaG, cromaB)
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })

    CromaTab:CreateSection("Tamano y opacidad")
    CromaTab:CreateSlider({
        Name         = "Ancho",
        Range        = { 10, 200 },
        Increment    = 5,
        Suffix       = "st",
        CurrentValue = UCam.GreenScreen.Size.X,
        Callback     = function(v)
            UCam.GreenScreen.Size = Vector3.new(v, UCam.GreenScreen.Size.Y, UCam.GreenScreen.Size.Z)
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Alto",
        Range        = { 5, 100 },
        Increment    = 5,
        Suffix       = "st",
        CurrentValue = UCam.GreenScreen.Size.Y,
        Callback     = function(v)
            UCam.GreenScreen.Size = Vector3.new(UCam.GreenScreen.Size.X, v, UCam.GreenScreen.Size.Z)
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Profundidad",
        Range        = { 1, 30 },
        Increment    = 1,
        Suffix       = "st",
        CurrentValue = UCam.GreenScreen.Size.Z,
        Callback     = function(v)
            UCam.GreenScreen.Size = Vector3.new(UCam.GreenScreen.Size.X, UCam.GreenScreen.Size.Y, v)
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Transparencia",
        Range        = { 0, 0.95 },
        Increment    = 0.05,
        Suffix       = "",
        CurrentValue = UCam.GreenScreen.Transparency,
        Callback     = function(v)
            UCam.GreenScreen.Transparency = v
            if UCam.GreenScreen.Enabled and UCam.GreenScreen.Part then
                pcall(function() UCam.GreenScreen.Part.Transparency = v end)
            end
        end,
    })

    CromaTab:CreateSection("Posicion de la pantalla")
    CromaTab:CreateDropdown({
        Name            = "Colocacion vertical",
        Options         = UCam.GreenScreen.VerticalModes,
        CurrentOption   = { UCam.GreenScreen.Vertical },
        MultipleOptions = false,
        Callback        = function(options)
            local value = UCam.resolveDropdownValue(options) or "Detras"
            UCam.GreenScreen.Vertical = value
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
            UCam.notify("Estudio / Croma", "Colocacion: " .. value)
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Distancia horizontal",
        Range        = { 4, 60 },
        Increment    = 1,
        Suffix       = "st",
        CurrentValue = UCam.GreenScreen.Distance,
        Callback     = function(v)
            UCam.GreenScreen.Distance = v
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateSlider({
        Name         = "Separacion vertical",
        Range        = { 2, 60 },
        Increment    = 1,
        Suffix       = "st",
        CurrentValue = UCam.GreenScreen.VerticalOffset,
        Callback     = function(v)
            UCam.GreenScreen.VerticalOffset = v
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
        end,
    })
    CromaTab:CreateToggle({
        Name         = "Evitar puntos de spawn",
        CurrentValue = UCam.GreenScreen.AvoidSpawns,
        Callback     = function(v)
            UCam.GreenScreen.AvoidSpawns = v
            UCam.GreenScreen._spawnCache = nil -- fuerza recache
            if UCam.GreenScreen.Enabled then UCam.updateGreenScreen() end
            UCam.notify("Estudio / Croma", v and "Pantalla esquivara los SpawnLocation." or "Evitar spawns desactivado.")
        end,
    })

    CromaTab:CreateSection("Acciones")
    CromaTab:CreateButton({
        Name     = "Mover croma al frente del personaje",
        Callback = function()
            if not UCam.GreenScreen.Enabled then
                UCam.notify("Estudio / Croma", "Activa la pantalla de croma primero.")
                return
            end
            UCam.updateGreenScreen()
            UCam.notify("Estudio / Croma", "Croma reposicionado al personaje.")
        end,
    })
    CromaTab:CreateButton({
        Name     = "Eliminar croma",
        Callback = function()
            UCam.GreenScreen.Enabled = false
            UCam.destroyGreenScreen()
            UCam.notify("Estudio / Croma", "Pantalla eliminada.")
        end,
    })
end
