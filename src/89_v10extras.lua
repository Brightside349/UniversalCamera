-- ============================================================
-- Universal Camera Pro v10 - extras locales
--
-- Integraciones pequeñas que conectan funciones ya existentes:
--   Capture/Clean Shot, guías de composición, recovery y metadata
--   de escenas. No crea un sistema externo de proyectos ni reemplaza
--   Replay, Director o la persistencia actual.
--
-- Dependencias: 00_config, 05_persistence, 10_utils, 20_filters,
--               50_spectate, 55_replay, 60_director, 70_camcore,
--               80_ui, 85_plugins, 88_v9extras.
-- Expone (UCam.*):
--   prepareCapture, restoreCapture, getCaptureStatus,
--   setGuidesEnabled, setGuidesType, setGuideOpacity, destroyGuides,
--   recoverSession, renameScene, setSceneDescription.
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- CAPTURE / CLEAN SHOT
-- ============================================================
local function detectScreenshotSupport()
    for _, name in ipairs({ "screenshot", "takeScreenshot", "getscreenshot" }) do
        if type(rawget(_G, name)) == "function" then
            return true
        end
    end
    return false
end

local function hideRayfieldGuis(capture)
    capture._hiddenGuis = capture._hiddenGuis or {}
    local parents = {}
    local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and coreGui then table.insert(parents, coreGui) end
    if UCam.player then
        local playerGui = UCam.player:FindFirstChildOfClass("PlayerGui")
        if playerGui then table.insert(parents, playerGui) end
    end
    for _, parent in ipairs(parents) do
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ScreenGui") and (child.Name == "Rayfield" or child.Name:find("Rayfield")) then
                if child.Enabled then
                    table.insert(capture._hiddenGuis, { gui = child, enabled = child.Enabled })
                    child.Enabled = false
                end
            end
        end
    end
end

local function restoreRayfieldGuis(capture)
    for _, entry in ipairs(capture._hiddenGuis or {}) do
        local gui = entry.gui or entry
        local enabled = entry.enabled
        if gui and gui.Parent then
            pcall(function() gui.Enabled = enabled == nil and true or enabled end)
        end
    end
    table.clear(capture._hiddenGuis or {})
end

UCam.Capture = UCam.Capture or {}
UCam.Capture.ScreenshotAvailable = detectScreenshotSupport()

function UCam.prepareCapture()
    local capture = UCam.Capture
    if capture.Prepared then return true end
    capture._previousCleanShot = UCam.CleanShot and UCam.CleanShot.Enabled or false
    capture.ScreenshotAvailable = detectScreenshotSupport()
    hideRayfieldGuis(capture)
    if UCam.setCleanShot then UCam.setCleanShot(true) end
    capture.Prepared = true
    if UCam.emit then
        UCam.emit("capturePrepared", {
            screenshotAvailable = capture.ScreenshotAvailable,
        })
    end
    return true
end

function UCam.restoreCapture()
    local capture = UCam.Capture
    if UCam.setCleanShot then
        UCam.setCleanShot(capture._previousCleanShot == true)
    end
    restoreRayfieldGuis(capture)
    capture.Prepared = false
    capture._previousCleanShot = nil
    return true
end

function UCam.getCaptureStatus()
    UCam.Capture.ScreenshotAvailable = detectScreenshotSupport()
    return {
        prepared = UCam.Capture.Prepared == true,
        screenshotAvailable = UCam.Capture.ScreenshotAvailable == true,
        message = UCam.Capture.ScreenshotAvailable
            and "Entorno preparado para screenshot."
            or "Toma limpia preparada; usa el grabador o screenshot del sistema.",
    }
end

-- Escape siempre devuelve la interfaz si se ha preparado una toma y el
-- usuario ya no puede ver el botón de restaurar porque Rayfield está oculto.
if UCam.UserInputService and UCam.trackConnection then
    UCam.trackConnection(UCam.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Escape and UCam.Capture.Prepared then
            UCam.restoreCapture()
        end
    end), "V10:CaptureEscape")
end

-- ============================================================
-- GUIAS DE COMPOSICION
-- ============================================================
local function overlayParent()
    local gethui = rawget(_G, "gethui")
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local playerGui = UCam.player and UCam.player:FindFirstChildOfClass("PlayerGui")
    if playerGui then return playerGui end
    local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
    return ok and coreGui or nil
end

local function addGuideLine(gui, name, size, position, opacity)
    local line = Instance.new("Frame")
    line.Name = name
    line.AnchorPoint = Vector2.new(0, 0)
    line.Size = size
    line.Position = position
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BackgroundTransparency = 1 - UCam.clamp(tonumber(opacity) or 0.65, 0, 1)
    line.BorderSizePixel = 0
    line.ZIndex = 10
    line.Parent = gui
end

local function buildGuides()
    UCam.destroyGuides()
    local parent = overlayParent()
    if not parent then return false end

    local gui = Instance.new("ScreenGui")
    gui.Name = "UCam_V10_CompositionGuides"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100000
    gui.Parent = parent
    UCam.Guides.Gui = gui
    UCam.trackInstance(gui, "V10:CompositionGuides")

    local opacity = UCam.Guides.Opacity or 0.65
    local kind = UCam.Guides.Type or "Thirds"
    if kind == "Center" then
        addGuideLine(gui, "CenterVertical", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(0.5, 0), opacity)
        addGuideLine(gui, "CenterHorizontal", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 0.5), opacity)
    elseif kind == "Safe" then
        addGuideLine(gui, "SafeLeft", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(0.1, 0), opacity)
        addGuideLine(gui, "SafeRight", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(0.9, 0), opacity)
        addGuideLine(gui, "SafeTop", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 0.1), opacity)
        addGuideLine(gui, "SafeBottom", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 0.9), opacity)
    elseif kind == "Vertical" then
        -- Marco de seguridad aproximado para Shorts/Reels dentro del viewport.
        addGuideLine(gui, "VerticalLeft", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(0.22, 0), opacity)
        addGuideLine(gui, "VerticalRight", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(0.78, 0), opacity)
        addGuideLine(gui, "VerticalTop", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 0.1), opacity)
        addGuideLine(gui, "VerticalBottom", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 0.9), opacity)
    else
        addGuideLine(gui, "ThirdVerticalA", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(1 / 3, 0), opacity)
        addGuideLine(gui, "ThirdVerticalB", UDim2.fromOffset(1, 0) + UDim2.fromScale(0, 1), UDim2.fromScale(2 / 3, 0), opacity)
        addGuideLine(gui, "ThirdHorizontalA", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 1 / 3), opacity)
        addGuideLine(gui, "ThirdHorizontalB", UDim2.fromOffset(0, 1) + UDim2.fromScale(1, 0), UDim2.fromScale(0, 2 / 3), opacity)
    end
    return true
end

function UCam.destroyGuides()
    local gui = UCam.Guides and UCam.Guides.Gui
    if gui then
        if UCam.untrackInstance then UCam.untrackInstance(gui) end
        pcall(function() gui:Destroy() end)
    end
    if UCam.Guides then UCam.Guides.Gui = nil end
end

function UCam.setGuidesEnabled(enabled)
    UCam.Guides.Enabled = enabled == true
    if UCam.scheduleSave then UCam.scheduleSave() end
    if UCam.Guides.Enabled then
        return buildGuides()
    end
    UCam.destroyGuides()
    return true
end

function UCam.setGuidesType(kind)
    local valid = { Thirds = true, Center = true, Safe = true, Vertical = true }
    if not valid[kind] then return false end
    UCam.Guides.Type = kind
    if UCam.scheduleSave then UCam.scheduleSave() end
    if UCam.Guides.Enabled then buildGuides() end
    return true
end

function UCam.setGuideOpacity(value)
    UCam.Guides.Opacity = UCam.clamp(tonumber(value) or 0.65, 0.1, 1)
    if UCam.scheduleSave then UCam.scheduleSave() end
    if UCam.Guides.Enabled then buildGuides() end
    return UCam.Guides.Opacity
end

-- ============================================================
-- METADATA DE ESCENAS, SIN CREAR UNA NUEVA JERARQUIA
-- ============================================================
function UCam.renameScene(slot, name, description)
    if not UCam.Scenes or not UCam.Scenes.Slots then return false end
    slot = UCam.clamp(math.floor(tonumber(slot) or 1), 1, UCam.Scenes.MaxSlots or 5)
    local scene = UCam.Scenes.Slots[slot]
    if not scene then return false end
    if name == nil then
        name = scene.Name or ("Escena " .. slot)
    else
        name = tostring(name):gsub("[%c]", " "):sub(1, 60)
        if name == "" then name = "Escena " .. slot end
    end
    scene.Name = name
    if description ~= nil then
        scene.Description = tostring(description):gsub("[%c]", " "):sub(1, 180)
    end
    if UCam.scheduleSave then UCam.scheduleSave() end
    return true
end

function UCam.setSceneDescription(slot, description)
    return UCam.renameScene(slot, nil, description)
end

-- ============================================================
-- RECOVERY V10: apaga features activas sin destruir la instancia UCam.
-- Unload sigue siendo la descarga completa; recovery permite continuar.
-- ============================================================
function UCam.recoverSession()
    local function call(name, ...)
        if type(UCam[name]) == "function" then
            pcall(UCam[name], ...)
        end
    end

    if UCam.Replay and UCam.Replay.Recording then call("stopRecording") end
    if UCam.Replay and UCam.Replay.Playing then call("stopPlayback") end
    if UCam.Director and UCam.Director.Active then call("directorTogglePlay", false) end
    if UCam.Spectate and UCam.Spectate.Active then call("stopSpectate") end
    call("forceRestoreCamera")
    call("stopFun")
    call("stopAdvPoses")
    call("stopBodyColor")
    call("stopPlayerMod")
    call("restoreAllPlayers")
    call("destroyGreenScreen")
    call("destroyLetterbox")
    call("destroyVignetteGui")
    call("destroyCustomSky")
    call("clearPathVisualizer")
    call("setHudHidden", false)
    call("setCharacterHidden", false)

    if UCam.LightingTweaks then
        UCam.LightingTweaks.Enabled = false
        call("applyLightingTweaks")
    end
    if UCam.Guides then UCam.setGuidesEnabled(false) end
    if UCam.Capture then UCam.restoreCapture() end
    if UCam.stopPerformance then pcall(UCam.stopPerformance) end
    if UCam.stopAllPlugins then pcall(UCam.stopAllPlugins) end

    UCam.notify("Universal Camera", "Sesión restaurada. La instancia sigue activa.", 4, { important = true })
    return true
end
