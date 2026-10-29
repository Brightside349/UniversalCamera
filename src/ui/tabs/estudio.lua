-- ============================================================
-- Universal Camera Pro v12.5 · ui/estudio
-- Pestaña Estudio: pantalla de croma local (solo tú la ves).
--
-- v12.5: se unificó el croma (color, tamaño, posición y acciones),
-- se agregó rotación y ajuste automático al encuadre de la cámara.
-- ============================================================
local UCam = _G.UCam

function UCam.build_estudio(Window)
    local Tab = Window:CreateTab("🟩 Estudio", "tv")
    local G = UCam.GreenScreen

    -- v12.5: normaliza el grosor de configuraciones antiguas (60st).
    if (G.Size.Z or 1) > 2 then
        G.Size = Vector3.new(G.Size.X, G.Size.Y, 1)
        if G.Enabled then pcall(UCam.updateGreenScreen) end
    end

    Tab:CreateSection("Pantalla de croma")
    Tab:CreateParagraph({
        Title = "Fondo uniforme para grabar",
        Content = "Crea un panel sólido detrás de tu personaje para hacer chroma key en edición. Solo lo ves tú y nunca se envía al servidor.",
    })
    Tab:CreateToggle({
        Name = "Activar pantalla",
        CurrentValue = G.Enabled,
        Callback = function(v)
            G.Enabled = v
            UCam.updateGreenScreen()
            UCam.notify("Estudio", v and "Pantalla creada." or "Pantalla eliminada.")
        end,
    })

    -- ------------------------------------------------------------
    -- COLOR
    -- ------------------------------------------------------------
    Tab:CreateSection("Color")
    local colorPresets = {
        ["Verde croma"]    = Color3.fromRGB(0, 255, 0),
        ["Azul croma"]     = Color3.fromRGB(0, 0, 255),
        ["Blanco estudio"] = Color3.fromRGB(255, 255, 255),
        ["Negro estudio"]  = Color3.fromRGB(0, 0, 0),
        ["Gris neutro"]    = Color3.fromRGB(128, 128, 128),
    }
    Tab:CreateDropdown({
        Name = "Preajuste",
        Options = { "Verde croma", "Azul croma", "Blanco estudio", "Negro estudio", "Gris neutro", "Personalizado" },
        CurrentOption = { "Verde croma" },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            local color = v and colorPresets[v]
            if color then
                G.Color = color
                if G.Enabled then UCam.updateGreenScreen() end
                UCam.notify("Estudio", "Color: " .. v)
            end
        end,
    })
    Tab:CreateSlider({
        Name = "Rojo", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(G.Color.R * 255),
        Callback = function(v)
            G.Color = Color3.fromRGB(math.floor(v), math.floor(G.Color.G * 255), math.floor(G.Color.B * 255))
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Verde", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(G.Color.G * 255),
        Callback = function(v)
            G.Color = Color3.fromRGB(math.floor(G.Color.R * 255), math.floor(v), math.floor(G.Color.B * 255))
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Azul", Range = { 0, 255 }, Increment = 1,
        CurrentValue = math.floor(G.Color.B * 255),
        Callback = function(v)
            G.Color = Color3.fromRGB(math.floor(G.Color.R * 255), math.floor(G.Color.G * 255), math.floor(v))
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateButton({
        Name = "Usar el color del cielo",
        Callback = function()
            G.Color = UCam.Lighting.OutdoorAmbient
            if G.Enabled then UCam.updateGreenScreen() end
            UCam.notify("Estudio", "Color tomado de la luz ambiental del juego.")
        end,
    })

    -- ------------------------------------------------------------
    -- TAMAÑO
    -- ------------------------------------------------------------
    Tab:CreateSection("Tamaño")
    Tab:CreateSlider({
        Name = "Ancho", Range = { 10, 300 }, Increment = 5, Suffix = "st",
        CurrentValue = G.Size.X,
        Callback = function(v)
            -- v12.5: el panel siempre es fino; el grosor viejo (60st) se
            -- veía como un bloque desde los lados.
            G.Size = Vector3.new(v, G.Size.Y, 1)
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Alto", Range = { 5, 200 }, Increment = 5, Suffix = "st",
        CurrentValue = G.Size.Y,
        Callback = function(v)
            G.Size = Vector3.new(G.Size.X, v, 1)
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Opacidad (0 = sólido)", Range = { 0, 0.95 }, Increment = 0.05,
        CurrentValue = G.Transparency,
        Callback = function(v)
            G.Transparency = v
            if G.Enabled and G.Part then
                pcall(function() G.Part.Transparency = v end)
            end
        end,
    })
    Tab:CreateButton({
        Name = "📐 Ajustar al encuadre de la cámara",
        Callback = function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local dist = math.max(G.Distance, 2)
            local halfV = math.rad(cam.FieldOfView * 0.5)
            local aspect = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
            local height = 2 * dist * math.tan(halfV) * 1.25
            local width = height * aspect * 1.25
            G.Size = Vector3.new(UCam.clamp(width, 10, 300), UCam.clamp(height, 5, 200), 1)
            G.AutoFit = true
            if G.Enabled then UCam.updateGreenScreen() end
            UCam.notify("Estudio", "Pantalla ajustada al encuadre.")
        end,
    })

    -- ------------------------------------------------------------
    -- POSICIÓN
    -- ------------------------------------------------------------
    Tab:CreateSection("Posición")
    Tab:CreateDropdown({
        Name = "Colocación",
        Options = G.VerticalModes,
        CurrentOption = { G.Vertical },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o) or "Detras"
            G.Vertical = v
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Distancia horizontal", Range = { 4, 80 }, Increment = 1, Suffix = "st",
        CurrentValue = G.Distance,
        Callback = function(v)
            G.Distance = v
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Separación vertical", Range = { 2, 80 }, Increment = 1, Suffix = "st",
        CurrentValue = G.VerticalOffset,
        Callback = function(v)
            G.VerticalOffset = v
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateSlider({
        Name = "Rotación", Range = { -180, 180 }, Increment = 5, Suffix = "°",
        CurrentValue = G.Rotation or 0,
        Callback = function(v)
            G.Rotation = v
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })
    Tab:CreateToggle({
        Name = "Evitar puntos de spawn",
        CurrentValue = G.AvoidSpawns,
        Callback = function(v)
            G.AvoidSpawns = v
            G._spawnCache = nil
            if G.Enabled then UCam.updateGreenScreen() end
        end,
    })

    -- ------------------------------------------------------------
    -- ACCIONES
    -- ------------------------------------------------------------
    Tab:CreateSection("Acciones")
    Tab:CreateButton({
        Name = "🔄 Recentrar en el personaje",
        Callback = function()
            if not G.Enabled then
                UCam.notify("Estudio", "Activa la pantalla primero.")
                return
            end
            UCam.updateGreenScreen()
            UCam.notify("Estudio", "Pantalla recolocada.")
        end,
    })
    Tab:CreateButton({
        Name = "🗑 Eliminar pantalla",
        Callback = function()
            G.Enabled = false
            UCam.destroyGreenScreen()
            UCam.notify("Estudio", "Pantalla eliminada.")
        end,
    })
end
