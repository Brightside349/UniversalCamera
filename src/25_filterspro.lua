-- ============================================================
-- Universal Camera Pro v8 · 25_filterspro
-- Filtros Pro: efectos visuales avanzados sobre las cámaras.
-- Se apoyan en ScreenGuis en PlayerGui (no en Illuminate/PostFX).
--
-- Efectos incluidos:
--   • Film Grain      — ruido animado estilo película
--   • Pixelify        — efecto 8-bit / pixel-art (shader falso)
--   • Scanlines       — líneas CRT / VHS
--   • Tilt-Shift      — desenfoque arriba/abajo (miniatura)
--   • Radial Blur     — desenfoque radial desde el centro
--   • Color Curves    — presets rápidos que ajustan el filtro activo
--
-- Dependencias: 00_config, 10_utils, 20_filters (para cambiar ColorCorrection)
-- Expone (UCam.*):
--   FiltersPro (tabla ya creada en 00_config), updateFiltersPro,
--   restoreFiltersPro, applyColorCurvePreset(name), stopFiltersPro
-- ============================================================
local UCam = _G.UCam

local Players = game:GetService("Players")

local F = UCam.FiltersPro
local _applyCurToCC  = nil          -- último preset aplicado (para revert)

-- ============================================================
-- GUIs: buscar el PlayerGui
-- ============================================================
local function getPlayerGui()
    return Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
end

-- ============================================================
-- EFECTO: FILM GRAIN (ImageLabel con ruido)
-- ============================================================
local function destroyFilmGrain()
    if F._grainGui and F._grainGui.Parent then
        pcall(function() F._grainGui:Destroy() end)
    end
    F._grainGui = nil
    if F._grainConn then
        -- v9 FIX (fuga de memoria): untrackConnection desconecta Y remueve la
        -- entrada del registry. Antes solo se desconectaba, dejando una entrada
        -- muerta en UCam._connections en cada toggle de Film Grain.
        UCam.untrackConnection(F._grainConn)
        F._grainConn = nil
    end
end

local function createFilmGrain()
    destroyFilmGrain()
    local pg = getPlayerGui()
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.Name              = "UCam_FilmGrain"
    sg.ResetOnSpawn      = false
    sg.DisplayOrder      = 998
    sg.IgnoreGuiInset    = true
    sg.Parent            = pg

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.new(1,1,1)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1,1)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    -- Creamos un grid de "píxeles" con transparencia aleatoria.
    -- Optimización: 20x20 = 400 frames; más fino que eso es muy caro.
    local cols = 24
    local rows = 14
    local cells = {}
    local cellW = 1 / cols
    local cellH = 1 / rows

    for x = 0, cols - 1 do
        for y = 0, rows - 1 do
            local cell = Instance.new("Frame")
            cell.BackgroundColor3 = Color3.new(0,0,0)
            cell.BackgroundTransparency = 1 - (F.FilmGrain.Amount or 0.4) * 0.35
            cell.BorderSizePixel = 0
            cell.Size = UDim2.new(cellW, 0, cellH, 0)
            cell.Position = UDim2.new(cellW * x, 0, cellH * y, 0)
            cell.Parent = frame
            cells[#cells+1] = cell
        end
    end

    F._grainGui = sg

    -- Animación: cada frame re-shuffle la transparencia
    local fps = math.clamp(F.FilmGrain.Speed or 24, 4, 60)
    local iv = 1 / fps
    local acc = 0
    F._grainConn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < iv then return end
            acc = 0
            local opposite = (math.random() > 0.5)
            for _, cell in ipairs(cells) do
                local base = (F.FilmGrain.Amount or 0.4) * 0.35
                local noise = (math.random() - 0.5) * 0.4
                cell.BackgroundTransparency = UCam.clamp(1 - (base + noise), 0.65, 1)
            end
        end),
        "FiltersPro:FilmGrain"
    )
end

-- ============================================================
-- EFECTO: PIXELIFY (cuadrícula estática que pixela la vista)
--   Truco: tiny ImageLabels en una malla; más barato es cambiar el
--   ViewportSize / render a menor resolución, pero eso no se puede
--   en cliente sin exploits. Aquí: "mosaico" grueso con pocos frames.
-- ============================================================
local function destroyPixelify()
    if F._pixelGui and F._pixelGui.Parent then
        pcall(function() F._pixelGui:Destroy() end)
    end
    F._pixelGui = nil
end

local function createPixelify()
    destroyPixelify()
    local pg = getPlayerGui()
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.Name              = "UCam_Pixelify"
    sg.ResetOnSpawn      = false
    sg.DisplayOrder      = 997
    sg.IgnoreGuiInset    = true
    sg.Parent            = pg

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.new(1,1,1)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1,1)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local block = math.clamp(F.Pixelify.BlockSize or 8, 2, 48)
    -- Cuadrado aprox. Roblox screen es 16:9, así que cols = block*aspect
    local sw, sh = UCam.camera and UCam.camera.ViewportSize.X or 1920,
                   UCam.camera and UCam.camera.ViewportSize.Y or 1080
    local aspect = sw / math.max(1, sh)
    local cols = math.max(1, math.floor(block * aspect))
    local rows = block

    for x = 0, cols - 1 do
        for y = 0, rows - 1 do
            local cell = Instance.new("Frame")
            cell.BackgroundColor3 = Color3.new(0,0,0)
            cell.BackgroundTransparency = 0.7
            cell.BorderSizePixel = 0
            cell.Size = UDim2.new(1/cols, 0, 1/rows, 0)
            cell.Position = UDim2.new((1/cols) * x, 0, (1/rows) * y, 0)
            cell.Parent = frame
        end
    end

    F._pixelGui = sg
end

-- ============================================================
-- EFECTO: SCANLINES (líneas negras horizontales, estilo CRT)
-- ============================================================
local function destroyScanlines()
    if F._scanlinesGui and F._scanlinesGui.Parent then
        pcall(function() F._scanlinesGui:Destroy() end)
    end
    F._scanlinesGui = nil
end

local function createScanlines()
    destroyScanlines()
    local pg = getPlayerGui()
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.Name              = "UCam_Scanlines"
    sg.ResetOnSpawn      = false
    sg.DisplayOrder      = 996
    sg.IgnoreGuiInset    = true
    sg.Parent            = pg

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.new(1,1,1)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1,1)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local density  = math.clamp(F.Scanlines.Density or 120, 8, 480)
    local opacity  = math.clamp(F.Scanlines.Opacity or 0.4, 0, 1)
    local lineH    = 1 / (density * 2)   -- 50% línea, 50% espacio

    for i = 0, density - 1 do
        local line = Instance.new("Frame")
        line.BackgroundColor3 = Color3.new(0,0,0)
        line.BackgroundTransparency = 1 - opacity
        line.BorderSizePixel = 0
        line.Size = UDim2.new(1, 0, lineH, 0)
        line.Position = UDim2.new(0, 0, (1/density) * i * 2, 0)  -- separadas
        line.Parent = frame
    end

    F._scanlinesGui = sg
end

-- ============================================================
-- EFECTO: TILT-SHIFT (miniatura: desenfoque arriba/abajo)
-- ============================================================
local function destroyTiltShift()
    if F._tiltshiftGui and F._tiltshiftGui.Parent then
        pcall(function() F._tiltshiftGui:Destroy() end)
    end
    F._tiltshiftGui = nil
end

local function createTiltShift()
    destroyTiltShift()
    local pg = getPlayerGui()
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.Name              = "UCam_TiltShift"
    sg.ResetOnSpawn      = false
    sg.DisplayOrder      = 995
    sg.IgnoreGuiInset    = true
    sg.Parent            = pg

    -- Banda superior desenfocada
    local topBlur = Instance.new("Frame")
    topBlur.BackgroundColor3 = Color3.new(0,0,0)
    topBlur.BackgroundTransparency = 0.5
    topBlur.BorderSizePixel = 0

    -- Gradiente para simular "blur": en realidad una sombra dura disimulada
    local grad1 = Instance.new("UIGradient")
    grad1.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1 - (F.TiltShift.Blur or 0.6) * 0.7),  -- borde externo casi opaco
        NumberSequenceKeypoint.new(1, 1),                                      -- interior transparente
    })
    grad1.Rotation = 90
    grad1.Parent = topBlur

    -- Banda inferior
    local botBlur = Instance.new("Frame")
    botBlur.BackgroundColor3 = Color3.new(0,0,0)
    botBlur.BackgroundTransparency = 0.5
    botBlur.BorderSizePixel = 0

    local grad2 = Instance.new("UIGradient")
    grad2.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),                                       -- interior transparente
        NumberSequenceKeypoint.new(1, 1 - (F.TiltShift.Blur or 0.6) * 0.7),
    })
    grad2.Rotation = 90
    grad2.Parent = botBlur

    -- Posicionar según FocusHeight: 0 = blur solo arriba, 1 = blur solo abajo
    local h = UCam.clamp(F.TiltShift.FocusHeight or 0.5, 0, 1)
    topBlur.Size     = UDim2.new(1, 0, h * 0.6, 0)
    topBlur.Position = UDim2.new(0, 0, 0, 0)
    botBlur.Size     = UDim2.new(1, 0, (1 - h) * 0.6, 0)
    botBlur.Position = UDim2.new(0, 0, 1 - (1 - h) * 0.6, 0)

    topBlur.Parent = sg
    botBlur.Parent = sg

    F._tiltshiftGui = sg
end

-- ============================================================
-- EFECTO: RADIAL BLUR (desenfoque en bordes, centro nítido)
-- ============================================================
local function destroyRadialBlur()
    if F._radialGui and F._radialGui.Parent then
        pcall(function() F._radialGui:Destroy() end)
    end
    F._radialGui = nil
end

local function createRadialBlur()
    destroyRadialBlur()
    local pg = getPlayerGui()
    if not pg then return end

    local sg = Instance.new("ScreenGui")
    sg.Name              = "UCam_RadialBlur"
    sg.ResetOnSpawn      = false
    sg.DisplayOrder      = 994
    sg.IgnoreGuiInset    = true
    sg.Parent            = pg

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.new(0,0,0)
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1,1)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    -- Un ImageLabel con una textura radial (decrece hacia centro).
    -- Usamos el UIGradient radial real: ImageLabel con imagen cuadrada blanca.
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = ""  -- sin imagen: usamos solo el gradiente
    img.Size = UDim2.fromScale(2, 2)         -- más grande que la pantalla
    img.Position = UDim2.fromScale(-0.5, -0.5)
    img.AnchorPoint = Vector2.new(0,0)
    img.BorderSizePixel = 0
    img.Parent = frame

    local grad = Instance.new("UIGradient")
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),                                     -- centro: transparente
        NumberSequenceKeypoint.new(0.7, 1 - (F.RadialBlur.Amount or 0.5) * 0.3),
        NumberSequenceKeypoint.new(1,   1 - (F.RadialBlur.Amount or 0.5) * 0.8), -- bordes: más oscuros
    })
    grad.Rotation = 0
    grad.Parent = img

    F._radialGui = sg
end

-- ============================================================
-- EFECTO: COLOR CURVES (presets rápidos sobre el ColorCorrection actual)
-- Modifica Brightness/Contrast/Saturation/TintColor del efecto existente.
-- ============================================================
local CURVE_PRESETS = {
    ["Neutral"]      = { Brightness = 0,     Contrast = 0,     Saturation = 0,    TintColor = Color3.new(1,1,1) },
    ["Filmic"]       = { Brightness = -0.02, Contrast = 0.15,  Saturation = -0.10, TintColor = Color3.new(0.92, 0.90, 0.88) },
    ["Retro"]        = { Brightness = 0.02,  Contrast = 0.05,  Saturation = -0.35, TintColor = Color3.fromRGB(245, 210, 170) },
    ["Neon Noir"]    = { Brightness = -0.05, Contrast = 0.25,  Saturation = 0.15, TintColor = Color3.fromRGB(180, 200, 255) },
    ["Pastel Dream"] = { Brightness = 0.06,  Contrast = -0.05, Saturation = 0.45, TintColor = Color3.fromRGB(255, 220, 240) },
    ["Golden Hour"]  = { Brightness = 0.05,  Contrast = 0.18,  Saturation = 0.20, TintColor = Color3.fromRGB(255, 215, 140) },
    ["Cool Breeze"]  = { Brightness = 0.02,  Contrast = 0.10,  Saturation = 0.10, TintColor = Color3.fromRGB(200, 230, 255) },
    ["Moody"]        = { Brightness = -0.08, Contrast = 0.35,  Saturation = -0.40, TintColor = Color3.fromRGB(200, 210, 230) },
}

function UCam.applyColorCurvePreset(name)
    local p = CURVE_PRESETS[tostring(name or "Neutral")]
    if not p then
        UCam.notify("Filtros Pro", ("Preset de curvas no encontrado: %s"):format(tostring(name)))
        return false
    end
    _applyCurToCC = p
    local cc = UCam.getColorEffect and UCam.getColorEffect()
    if cc then
        pcall(function()
            cc.Brightness  = p.Brightness
            cc.Contrast    = p.Contrast
            cc.Saturation  = p.Saturation
            cc.TintColor   = p.TintColor
            cc.Enabled     = true
        end)
        F.ColorCurves.Preset = name
        F.ColorCurves.Enabled = true
        UCam.notify("Color Curves", ("Preset → %s"):format(name))
        return true
    end
    return false
end

local function restoreColorCurves()
    if not _applyCurToCC then return end
    -- Restaurar al filtro activo (deja el efecto como estaba en 20_filters)
    if UCam.applyFilter then
        pcall(UCam.applyFilter, UCam.currentFilterIndex)
    end
    _applyCurToCC = nil
    F.ColorCurves.Enabled = false
end

-- ============================================================
-- ORQUESTADOR: actualizar (crear/destruir GUIs según flags)
-- ============================================================
function UCam.updateFiltersPro()
    if not F.Enabled then
        UCam.stopFiltersPro(true)  -- keepPresets, no tocar ColorCorrection
        return
    end

    -- Film Grain
    if F.FilmGrain.Enabled and not (F._grainGui and F._grainGui.Parent) then
        createFilmGrain()
    elseif not F.FilmGrain.Enabled and F._grainGui and F._grainGui.Parent then
        destroyFilmGrain()
    end

    -- Pixelify
    if F.Pixelify.Enabled and not (F._pixelGui and F._pixelGui.Parent) then
        createPixelify()
    elseif not F.Pixelify.Enabled and F._pixelGui and F._pixelGui.Parent then
        destroyPixelify()
    end

    -- Scanlines
    if F.Scanlines.Enabled and not (F._scanlinesGui and F._scanlinesGui.Parent) then
        createScanlines()
    elseif not F.Scanlines.Enabled and F._scanlinesGui and F._scanlinesGui.Parent then
        destroyScanlines()
    end

    -- Tilt-Shift
    if F.TiltShift.Enabled and not (F._tiltshiftGui and F._tiltshiftGui.Parent) then
        createTiltShift()
    elseif not F.TiltShift.Enabled and F._tiltshiftGui and F._tiltshiftGui.Parent then
        destroyTiltShift()
    end

    -- Radial Blur
    if F.RadialBlur.Enabled and not (F._radialGui and F._radialGui.Parent) then
        createRadialBlur()
    elseif not F.RadialBlur.Enabled and F._radialGui and F._radialGui.Parent then
        destroyRadialBlur()
    end
end

-- Re-crear TODOS (cuando cambian parámetros)
function UCam.rebuildFiltersPro()
    if not F.Enabled then return end
    if F.FilmGrain.Enabled   then createFilmGrain() end
    if F.Pixelify.Enabled    then createPixelify()  end
    if F.Scanlines.Enabled   then createScanlines() end
    if F.TiltShift.Enabled   then createTiltShift() end
    if F.RadialBlur.Enabled  then createRadialBlur() end
end

-- ============================================================
-- STOP (Unload)
-- keepPresets=true → solo GUIs; false → también revertir ColorCorrection
-- ============================================================
function UCam.stopFiltersPro(keepPresets)
    destroyFilmGrain()
    destroyPixelify()
    destroyScanlines()
    destroyTiltShift()
    destroyRadialBlur()
    if not keepPresets then
        restoreColorCurves()
    end
end

-- Iniciar si fue persistido como Enabled
if F.Enabled then
    task.defer(function() UCam.updateFiltersPro() end)
end

print("[UCam] Filtros Pro listos.")
