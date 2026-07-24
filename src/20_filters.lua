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
-- VIGNETTE (overlay GUI con esquinas oscuras) — v3
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

    local frame                  = Instance.new("Frame")
    frame.Name                   = "VignetteFrame"
    frame.BackgroundColor3       = Color3.new(0, 0, 0)
    frame.BorderSizePixel        = 0
    frame.Size                   = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.Parent                 = gui

    local grad                   = Instance.new("UIGradient")
    grad.Transparency            = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 1 - UCam.Vignette.Intensity),
        NumberSequenceKeypoint.new(1, 0),
    })
    grad.Rotation                = 0
    grad.Parent                  = frame

    UCam.Vignette.Gui            = gui
    UCam.Vignette.Gui.grad       = grad
    UCam.Vignette.Gui.frame      = frame
    return gui
end

function UCam.applyVignette()
    if UCam.Vignette.Enabled then
        local g = UCam.ensureVignetteGui()
        if not g then return end
        local transp             = UCam.clamp(1 - UCam.Vignette.Intensity, 0, 1)
        g.Enabled                = true
        g.grad.Transparency      = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(UCam.clamp(1 - UCam.Vignette.Smoothness, 0.05, 0.95), transp),
            NumberSequenceKeypoint.new(1, 0),
        })
        g.frame.BackgroundColor3 = UCam.Vignette.Color
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
