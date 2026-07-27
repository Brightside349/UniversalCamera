-- ============================================================
-- Universal Camera Pro v6 · 20_filters
-- Color correction, filtros built-in/custom, bloom, DOF, sun rays,
-- vignette (overlay GUI) y letterbox (barras 21:9).
--
-- Dependencias: 00_config
-- Expone (UCam.*):
--   setupColorEffect, getColorEffect, applyColorCorrection,
--   disableColorCorrection, applyFilter, applyFilterByName,
--   applyCustomEditingLive, applyBloom, applyDOF, applySunRays,
--   ensureVignetteGui, applyVignette, ensureLetterboxGui,
--   applyLetterbox, destroyLetterbox, destroyVignetteGui
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- COLOR CORRECTION EFFECT (para filtros built-in y custom)
-- ============================================================
function UCam.setupColorEffect()
    local existing = UCam.camera:FindFirstChild("FreeCam_Filter")
    if existing then existing:Destroy() end
    local cc   = Instance.new("ColorCorrectionEffect")
    cc.Name    = "FreeCam_Filter"
    cc.Enabled = false
    cc.Parent  = UCam.camera
    return cc
end

function UCam.getColorEffect()
    return UCam.camera:FindFirstChild("FreeCam_Filter") or UCam.setupColorEffect()
end
UCam.setupColorEffect()

function UCam.applyColorCorrection(brightness, contrast, saturation, tint)
    local cc      = UCam.getColorEffect()
    cc.Brightness = brightness or 0
    cc.Contrast   = contrast or 0
    cc.Saturation = saturation or 0
    cc.TintColor  = tint or Color3.fromRGB(255, 255, 255)
    cc.Enabled    = true
end

function UCam.disableColorCorrection()
    local cc = UCam.getColorEffect()
    cc.Enabled = false
end

function UCam.applyFilter(index)
    index              = UCam.clamp(index or 1, 1, #UCam.Filters)
    UCam.currentFilterIndex = index
    local f            = UCam.Filters[index]
    UCam.applyColorCorrection(f.Brightness, f.Contrast, f.Saturation, f.TintColor)
    if index == 1 then UCam.disableColorCorrection() end
end

function UCam.applyFilterByName(name)
    for i, f in ipairs(UCam.Filters) do
        if f.Name == name then
            UCam.applyFilter(i)
            UCam.customFilterLiveApplied = false
            return i
        end
    end
    for i, f in ipairs(UCam.CustomFilters) do
        if f.Name == name then
            UCam.applyColorCorrection(f.Brightness, f.Contrast, f.Saturation, f.TintColor)
            UCam.currentFilterIndex = -i
            UCam.customFilterLiveApplied = false
            return -i
        end
    end
    return UCam.currentFilterIndex
end

function UCam.applyCustomEditingLive()
    UCam.applyColorCorrection(
        UCam.customEditing.Brightness,
        UCam.customEditing.Contrast,
        UCam.customEditing.Saturation,
        Color3.fromRGB(UCam.customEditing.R, UCam.customEditing.G, UCam.customEditing.B)
    )
    UCam.customFilterLiveApplied = true
end

UCam.applyFilter(UCam.currentFilterIndex)

-- ============================================================
-- POST-PROCESADO: BLOOM / DOF / SUN RAYS
-- ============================================================
function UCam.getOrCreateEffect(parent, name, className)
    local existing = parent:FindFirstChild(name)
    if existing then return existing end
    local inst = Instance.new(className)
    inst.Name = name
    inst.Parent = parent
    return inst
end

function UCam.applyBloom()
    local effect     = UCam.getOrCreateEffect(UCam.Lighting, UCam.BLOOM_EFFECT_NAME, "BloomEffect")
    effect.Enabled   = UCam.Bloom.Enabled
    effect.Intensity = UCam.Bloom.Intensity
    effect.Size      = UCam.Bloom.Size
    effect.Threshold = UCam.Bloom.Threshold
end

function UCam.applyDOF()
    local effect         = UCam.getOrCreateEffect(UCam.Lighting, UCam.DOF_EFFECT_NAME, "DepthOfFieldEffect")
    effect.Enabled       = UCam.DOF.Enabled
    effect.FarIntensity  = UCam.DOF.FarIntensity
    effect.FocusDistance = UCam.DOF.FocusDistance
    effect.InFocusRadius = UCam.DOF.InFocusRadius
    effect.NearIntensity = 0
end

function UCam.applySunRays()
    local effect     = UCam.getOrCreateEffect(UCam.Lighting, UCam.SUNRAYS_EFFECT_NAME, "SunRaysEffect")
    effect.Enabled   = UCam.SunRays.Enabled
    effect.Intensity = UCam.SunRays.Intensity
    effect.Spread    = UCam.SunRays.Spread
end

UCam.applyBloom()
UCam.applyDOF()
UCam.applySunRays()

-- ============================================================
-- VIGNETTE (overlay radial con degradado en los 4 bordes) — v7
-- En v3 usábamos un UIGradient lineal único (no era realmente radial).
-- v7 construye 4 frames de borde (Top/Bottom/Left/Right), cada uno con
-- su propio UIGradient apuntando hacia el centro, dando un oscurecido
-- radial real, simétrico e independiente de la resolución.
-- ============================================================
function UCam.ensureVignetteGui()
    if UCam.Vignette.Gui and UCam.Vignette.Gui.Parent then return UCam.Vignette.Gui end
    local playerGui = UCam.player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local gui                    = Instance.new("ScreenGui")
    gui.Name                     = "UCam_Vignette"
    gui.IgnoreGuiInset           = true
    gui.DisplayOrder             = 1000
    gui.ResetOnSpawn             = false
    gui.Parent                   = playerGui

    UCam.Vignette.Gui            = gui

    -- Borde radial: un Frame por cada lado, con gradient que va
    -- de "centro transparente" en el borde interior a "oscuro" en el borde exterior.
    local function makeEdge(name, size, pos, anchor, gradRotation)
        local edge = Instance.new("Frame")
        edge.Name             = name
        edge.BackgroundColor3 = UCam.Vignette.Color or Color3.new(0, 0, 0)
        edge.BorderSizePixel  = 0
        edge.AnchorPoint       = anchor
        edge.Position          = pos
        edge.Size              = size
        edge.Parent            = gui

        local grad = Instance.new("UIGradient")
        grad.Rotation = gradRotation
        grad.Parent = edge
        return edge, grad
    end

    -- Cada borde cubre toda su dimensión y un porcentaje de la opuesta.
    -- La altura/ancho de cada borde se calcula dinámicamente en applyVignette()
    -- para que el "radio" del viñeteo sea consistente entre resoluciones.
    local topEdge,    topGrad    = makeEdge("VTop",
        UDim2.new(1, 0, 0.5, 0),    UDim2.new(0, 0, 0, 0),       Vector2.new(0, 0),   90)
    local bottomEdge, bottomGrad = makeEdge("VBottom",
        UDim2.new(1, 0, 0.5, 0),    UDim2.new(0, 0, 1, 0),       Vector2.new(0, 1),   270)
    local leftEdge,   leftGrad   = makeEdge("VLeft",
        UDim2.new(0.5, 0, 1, 0),    UDim2.new(0, 0, 0, 0),       Vector2.new(0, 0),   0)
    local rightEdge,  rightGrad  = makeEdge("VRight",
        UDim2.new(0.5, 0, 1, 0),    UDim2.new(1, 0, 0, 0),       Vector2.new(1, 0),   180)

    UCam.Vignette._edges = { topEdge, bottomEdge, leftEdge, rightEdge }
    UCam.Vignette._grads = { topGrad, bottomGrad, leftGrad, rightGrad }
    return gui
end

function UCam.applyVignette()
    if UCam.Vignette.Enabled then
        local g = UCam.ensureVignetteGui()
        if not g then return end
        local intensity = UCam.clamp(UCam.Vignette.Intensity, 0, 1)
        local smooth    = UCam.clamp(UCam.Vignette.Smoothness, 0.05, 0.95)
        -- opacidad máxima en los bordes exteriores (0 = totalmente opaco, 1 = transparente)
        local outerTransp = 1 - intensity
        local centerTransp = 1
        -- punto donde empieza a oscurecer (más smooth = empieza más lejos del borde)
        local midKey = 1 - smooth

        local keys = NumberSequence.new({
            NumberSequenceKeypoint.new(0, outerTransp),    -- borde exterior: oscuro
            NumberSequenceKeypoint.new(midKey, 1),          -- hacia el centro: claro
            NumberSequenceKeypoint.new(1, 1),              -- límite interior: transparente
        })

        -- La "profundidad" de cada borde (cuánto se mete hacia el centro) da el radio.
        -- Usamos una fracción del viewport para mantenerlo consistente entre resoluciones.
        local vp = UCam.camera.ViewportSize
        local radial = UCam.clamp(smooth, 0.05, 0.95)
        local edges = UCam.Vignette._edges
        -- Top/Bottom: altura = radial * mitad de la pantalla
        edges[1].Size = UDim2.new(1, 0, radial * 0.5, 0)
        edges[2].Size = UDim2.new(1, 0, radial * 0.5, 0)
        -- Left/Right: ancho = radial * mitad de la pantalla (con aspect correction)
        local aspect = vp.X / math.max(vp.Y, 1)
        edges[3].Size = UDim2.new(radial * 0.5 * (aspect > 1 and 1 / aspect or 1), 0, 1, 0)
        edges[4].Size = UDim2.new(radial * 0.5 * (aspect > 1 and 1 / aspect or 1), 0, 1, 0)

        for _, grad in ipairs(UCam.Vignette._grads) do
            grad.Transparency = keys
        end
        for _, edge in ipairs(edges) do
            edge.BackgroundColor3 = UCam.Vignette.Color or Color3.new(0, 0, 0)
        end
        g.Enabled = true
    else
        if UCam.Vignette.Gui then UCam.Vignette.Gui.Enabled = false end
    end
end

UCam.applyVignette()

-- ============================================================
-- LETTERBOX (barras cinematograficas 21:9)
-- ============================================================
function UCam.ensureLetterboxGui()
    if UCam.Letterbox.Gui and UCam.Letterbox.Gui.Parent then return UCam.Letterbox.Gui end
    local playerGui = UCam.player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local gui          = Instance.new("ScreenGui")
    gui.Name           = "UCam_Letterbox"
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 998
    gui.ResetOnSpawn   = false
    gui.Enabled        = true
    gui.Parent         = playerGui

    local function makeBar(name, anchorY, posY)
        local bar                  = Instance.new("Frame")
        bar.Name                   = name
        bar.BackgroundColor3       = Color3.new(0, 0, 0)
        bar.BackgroundTransparency = 0
        bar.BorderSizePixel        = 0
        bar.AnchorPoint            = Vector2.new(0, anchorY)
        bar.Position               = UDim2.new(0, 0, posY, 0)
        bar.Size                   = UDim2.new(1, 0, 0.001, 0)
        bar.Parent                 = gui
        return bar
    end

    makeBar("Top", 0, 0)
    makeBar("Bottom", 1, 1)

    UCam.Letterbox.Gui = gui
    return gui
end

function UCam.applyLetterbox()
    if UCam.Letterbox.Enabled then
        local gui = UCam.ensureLetterboxGui()
        if gui then
            local camVP  = UCam.camera.ViewportSize
            local barPx  = camVP.Y * UCam.Letterbox.HeightRatio
            local top    = gui:FindFirstChild("Top")
            local bottom = gui:FindFirstChild("Bottom")
            if top then top.Size = UDim2.new(1, 0, 0, barPx) end
            if bottom then bottom.Size = UDim2.new(1, 0, 0, barPx) end
        end
    else
        if UCam.Letterbox.Gui then UCam.Letterbox.Gui.Enabled = false end
    end
end

-- v7: listener de resize del viewport para re-ajustar el letterbox y la
-- viñeta radial cuando el jugador cambia el tamaño de ventana / pantalla.
-- Sin esto, las barras y la viñeta quedan desalineadas al redimensionar.
UCam._viewportResizeConn = UCam.camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    pcall(function()
        if UCam.Letterbox.Enabled then UCam.applyLetterbox() end
        if UCam.Vignette.Enabled then UCam.applyVignette() end
    end)
end)

-- FIX v6 (B5): destroy centralizado de Letterbox/Vignette.
-- Antes el GUI se destruia en 3 sitios distintos (toggle, toggleFreeCam,
-- CharacterAdded) con codigo duplicado; ahora todos llaman aqui.
function UCam.destroyLetterbox()
    if UCam.Letterbox.Gui then
        pcall(function() UCam.Letterbox.Gui:Destroy() end)
        UCam.Letterbox.Gui = nil
    end
end

function UCam.destroyVignetteGui()
    if UCam.Vignette.Gui then
        pcall(function() UCam.Vignette.Gui:Destroy() end)
        UCam.Vignette.Gui = nil
    end
end

-- ============================================================
-- EXPANSIÓN FILTROS v7: transiciones, combinación, temporal, chromatic
-- ============================================================

-- Colores Help
local function lerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end
local function lerpNum(a, b, t) return a + (b - a) * t end

-- Mezcla dos filtros (tablas con B/C/S/TintColor) según mix [0..1]
local function blendFilters(fA, fB, mix)
    mix = UCam.clamp(mix, 0, 1)
    return {
        Brightness = lerpNum(fA.Brightness, fB.Brightness, mix),
        Contrast   = lerpNum(fA.Contrast,   fB.Contrast,   mix),
        Saturation = lerpNum(fA.Saturation, fB.Saturation, mix),
        TintColor  = lerpColor(fA.TintColor, fB.TintColor, mix),
    }
end

-- Estado chromatic aberration (overlay con dos imágenes desplazadas en R/B)
UCam.ChromaticAberration = UCam.ChromaticAberration or {
    Enabled  = false,
    Amount   = 4,        -- px de desplazamiento de cada canal
    Gui      = nil,
}

function UCam.destroyChromaticGui()
    if UCam.ChromaticAberration.Gui then
        pcall(function() UCam.ChromaticAberration.Gui:Destroy() end)
        UCam.ChromaticAberration.Gui = nil
    end
end

-- Crea/actualiza el overlay de chromatic aberration. Usamos dos frames
-- semi-transparentes tintados rojo y azul desplazados ±amount px, sobre
-- el centro de la pantalla, para simular RGB split.
function UCam.applyChromaticAberration()
    local ca = UCam.ChromaticAberration
    if not ca.Enabled then
        UCam.destroyChromaticGui()
        return
    end

    local playerGui = UCam.player:FindFirstChild("PlayerGui")
    if not playerGui then return end

    if not ca.Gui or not ca.Gui.Parent then
        local gui = Instance.new("ScreenGui")
        gui.Name = "UCam_Chromatic"
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 1001
        gui.ResetOnSpawn = false
        gui.Parent = playerGui

        for _, side in ipairs({ "Red", "Blue" }) do
            local f = Instance.new("Frame")
            f.Name = side
            f.Size = UDim2.fromScale(1, 1)
            f.BorderSizePixel = 0
            f.BackgroundTransparency = 0.5
            f.ZIndex = 12
            f.Parent = gui
        end
        ca.Gui = gui
    end

    local amt = ca.Amount or 4
    local red  = ca.Gui:FindFirstChild("Red")
    local blue = ca.Gui:FindFirstChild("Blue")
    if red then
        red.BackgroundColor3  = Color3.fromRGB(255, 0, 0)
        red.BackgroundTransparency = 0.92
        red.Position = UDim2.new(0, -amt, 0, 0)
    end
    if blue then
        blue.BackgroundColor3 = Color3.fromRGB(0, 80, 255)
        blue.BackgroundTransparency = 0.92
        blue.Position = UDim2.new(0, amt, 0, 0)
    end
end

-- Aplica inmediatamente un filtro sin transición (uso interno)
local function applyFilterInstant(f)
    UCam.applyColorCorrection(f.Brightness, f.Contrast, f.Saturation, f.TintColor)
end

-- Reescribe applyFilter: ahora soporta transición suave y combinación.
-- Mantenemos la firma applyFilter(index) para no romper la UI existente.
local _origApplyFilter = UCam.applyFilter
UCam.applyFilter = function(index, instant)
    index = UCam.clamp(index or 1, 1, #UCam.Filters)
    UCam.currentFilterIndex = index
    local target = UCam.Filters[index]

    -- Modo combinación: mezcla con un segundo filtro
    if UCam.FilterCombine.Enabled and UCam.FilterCombine.IndexB then
        local fB = UCam.Filters[UCam.clamp(UCam.FilterCombine.IndexB, 1, #UCam.Filters)]
        if fB then target = blendFilters(target, fB, UCam.FilterCombine.Mix) end
    end

    -- Filtro temporal: registra el inicio si está activo
    if UCam.FilterTemporal.Active then
        UCam.FilterTemporal.Index = index
        UCam.FilterTemporal.StartTime = os.clock()
    end

    if instant or not UCam.FilterTransition.Enabled then
        applyFilterInstant(target)
        UCam.FilterTransition.Active = false
    else
        -- Arrancar transición desde el estado actual del effect
        local cc = UCam.getColorEffect()
        UCam.FilterTransition.From = {
            Brightness = cc.Brightness, Contrast = cc.Contrast,
            Saturation = cc.Saturation, TintColor = cc.TintColor,
        }
        UCam.FilterTransition.To = {
            Brightness = target.Brightness, Contrast = target.Contrast,
            Saturation = target.Saturation, TintColor = target.TintColor,
        }
        UCam.FilterTransition.Elapsed = 0
        UCam.FilterTransition.Active = true
    end
end

-- Update de filtros (transición lerp + temporal auto-fade). Se llama desde
-- el loop de cámara (updateCamera) o un heartbeat dedicado.
function UCam.updateFilters(deltaTime)
    -- Chromatic aberration: el overlay es estático, solo (re)aplicar si hace falta
    if UCam.ChromaticAberration.Enabled and not UCam.ChromaticAberration.Gui then
        UCam.applyChromaticAberration()
    end

    if UCam.FilterTransition.Active then
        UCam.FilterTransition.Elapsed = UCam.FilterTransition.Elapsed + (deltaTime or 0)
        local t = UCam.clamp(UCam.FilterTransition.Elapsed * UCam.FilterTransition.Speed, 0, 1)
        local f = UCam.FilterTransition.From or {}
        local to = UCam.FilterTransition.To or {}
        UCam.applyColorCorrection(
            lerpNum(f.Brightness or 0, to.Brightness or 0, t),
            lerpNum(f.Contrast or 0,   to.Contrast or 0,   t),
            lerpNum(f.Saturation or 0, to.Saturation or 0, t),
            lerpColor(f.TintColor or Color3.new(1,1,1), to.TintColor or Color3.new(1,1,1), t)
        )
        if t >= 1 then UCam.FilterTransition.Active = false end
        return
    end

    -- Filtro temporal: desvanecer a Ninguno tras Duration segundos
    if UCam.FilterTemporal.Active then
        local elapsed = os.clock() - (UCam.FilterTemporal.StartTime or 0)
        if elapsed >= UCam.FilterTemporal.Duration then
            UCam.FilterTemporal.Active = false
            UCam.applyFilter(1, true)  -- volver a "Ninguno" sin transición
        end
    end
end

function UCam.setChromaticAmount(amount)
    UCam.ChromaticAberration.Amount = UCam.clamp(amount or 0, 0, 40)
    if UCam.ChromaticAberration.Gui then UCam.applyChromaticAberration() end
end
