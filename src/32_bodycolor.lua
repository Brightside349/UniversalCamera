-- ============================================================
-- Universal Camera Pro v7 · 32_bodycolor
-- Sistema Avanzado de Coloreo de Cuerpo: coloreo por partes,
-- transparencia por partes, materiales por partes, presets,
-- aplicación a otros jugadores (local).
--
-- Dependencias: 00_config, 10_utils
-- Exposes (UCam.*):
--   initBodyColor, applyBodyColorToPart, applyPreset,
--   applyBodyColorToPlayer, restoreBodyColor, restorePlayerBodyColor,
--   updateBodyColor, stopBodyColor
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- PART NAME MAPPING
-- ============================================================
local PART_MAP = {
    ["Cabeza"]      = "Head",
    ["Torso"]       = {"Torso", "UpperTorso", "LowerTorso"}, -- R15 compatibility
    ["Brazo Izq."]  = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"},
    ["Brazo Der."]  = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"},
    ["Pierna Izq."] = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    ["Pierna Der."] = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"},
}

-- ============================================================
-- PRESET DEFINITIONS
-- ============================================================
local PRESETS = {
    ["Robot"] = {
        Material = "Metal",
        Color = Color3.fromRGB(180, 180, 190),
        AllParts = true,
    },
    ["Fantasma"] = {
        Material = "Glass",
        Color = Color3.fromRGB(240, 240, 255),
        Transparency = 0.7,
        AllParts = true,
    },
    ["Demonio"] = {
        Material = "Neon",
        Color = Color3.fromRGB(180, 0, 0),
        AllParts = true,
    },
    ["Dorado"] = {
        Material = "Marble",
        Color = Color3.fromRGB(255, 215, 0),
        AllParts = true,
    },
    ["Invisible"] = {
        Transparency = 1.0,
        AllParts = true,
    },
    ["Glitch"] = {
        -- Applied procedurally in applyPreset
        RandomColors = true,
        RandomTransparency = true,
        AllParts = true,
    },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function snapshotCharacterAppearance(character)
    local snapshot = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            snapshot[part] = {
                Color = part.Color,
                Material = part.Material,
                Transparency = part.Transparency,
            }
        end
    end
    return snapshot
end

local function restoreCharacterAppearance(snapshot)
    for part, data in pairs(snapshot) do
        if part and part.Parent then
            pcall(function()
                part.Color = data.Color
                part.Material = data.Material
                part.Transparency = data.Transparency
            end)
        end
    end
end

local function getPartsForSelection(character, selection)
    local parts = {}
    
    if selection == "Todo" then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                table.insert(parts, part)
            end
        end
    elseif selection == "Accesorios" then
        for _, accessory in ipairs(character:GetChildren()) do
            if accessory:IsA("Accessory") then
                local handle = accessory:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    table.insert(parts, handle)
                end
            end
        end
    else
        -- Specific body part
        local partNames = PART_MAP[selection]
        if partNames then
            if type(partNames) == "string" then
                partNames = {partNames}
            end
            for _, partName in ipairs(partNames) do
                local part = character:FindFirstChild(partName)
                if part and part:IsA("BasePart") then
                    table.insert(parts, part)
                end
            end
        end
    end
    
    return parts
end

-- ============================================================
-- APPLY COLOR/MATERIAL/TRANSPARENCY TO PART
-- ============================================================
function UCam.applyBodyColorToPart(partSelection, color, material, transparency)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    -- Snapshot if first time
    if not UCam.BodyColor._originals[UCam.character] then
        UCam.BodyColor._originals[UCam.character] = snapshotCharacterAppearance(UCam.character)
    end
    
    local parts = getPartsForSelection(UCam.character, partSelection)
    
    for _, part in ipairs(parts) do
        pcall(function()
            if color then
                part.Color = color
            end
            if material then
                local enumMat = Enum.Material[material]
                if enumMat then
                    part.Material = enumMat
                end
            end
            if transparency then
                part.Transparency = transparency
            end
        end)
    end
    
    -- Store current config
    local key = partSelection
    if partSelection == "Todo" then
        for k, _ in pairs(UCam.BodyColor.Parts) do
            if color then UCam.BodyColor.Parts[k].Color = color end
            if material then UCam.BodyColor.Parts[k].Material = material end
            if transparency then UCam.BodyColor.Parts[k].Transparency = transparency end
        end
        if color then UCam.BodyColor.Accessories.Color = color end
        if material then UCam.BodyColor.Accessories.Material = material end
        if transparency then UCam.BodyColor.Accessories.Transparency = transparency end
    elseif partSelection == "Accesorios" then
        if color then UCam.BodyColor.Accessories.Color = color end
        if material then UCam.BodyColor.Accessories.Material = material end
        if transparency then UCam.BodyColor.Accessories.Transparency = transparency end
    else
        -- Map display name to internal key
        local internalMap = {
            ["Cabeza"] = "Head",
            ["Torso"] = "Torso",
            ["Brazo Izq."] = "LeftArm",
            ["Brazo Der."] = "RightArm",
            ["Pierna Izq."] = "LeftLeg",
            ["Pierna Der."] = "RightLeg",
        }
        local internalKey = internalMap[partSelection]
        if internalKey and UCam.BodyColor.Parts[internalKey] then
            if color then UCam.BodyColor.Parts[internalKey].Color = color end
            if material then UCam.BodyColor.Parts[internalKey].Material = material end
            if transparency then UCam.BodyColor.Parts[internalKey].Transparency = transparency end
        end
    end
end

-- ============================================================
-- APPLY PRESET
-- ============================================================
function UCam.applyPreset(presetName)
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    local preset = PRESETS[presetName]
    if not preset then
        -- Check custom presets
        preset = UCam.BodyColor.Presets[presetName]
        if not preset then return end
    end
    
    -- Snapshot if first time
    if not UCam.BodyColor._originals[UCam.character] then
        UCam.BodyColor._originals[UCam.character] = snapshotCharacterAppearance(UCam.character)
    end
    
    if presetName == "Glitch" then
        -- Random colors and transparency for each part
        for _, part in ipairs(UCam.character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                pcall(function()
                    part.Color = Color3.fromRGB(
                        math.random(0, 255),
                        math.random(0, 255),
                        math.random(0, 255)
                    )
                    part.Transparency = math.random(0, 100) / 100
                end)
            end
        end
    elseif preset.Parts then
        -- v8.1 FIX: los presets CUSTOM tienen formato { Parts = {...},
        -- Accessories = {...} } y NO tienen AllParts → antes no aplicaban nada.
        for k, v in pairs(preset.Parts) do
            local part = UCam.character:FindFirstChild(k, true)
            if part and part:IsA("BasePart") then
                pcall(function()
                    if v.Color then part.Color = v.Color end
                    if v.Material then
                        local enumMat = Enum.Material[v.Material]
                        if enumMat then part.Material = enumMat end
                    end
                    if v.Transparency ~= nil then part.Transparency = v.Transparency end
                end)
            end
        end
        -- Aplicar accesorios guardados
        if preset.Accessories then
            for _, acc in ipairs(UCam.character:GetChildren()) do
                if acc:IsA("Accessory") then
                    local handle = acc:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        pcall(function()
                            if preset.Accessories.Color then handle.Color = preset.Accessories.Color end
                            if preset.Accessories.Material then
                                local em = Enum.Material[preset.Accessories.Material]
                                if em then handle.Material = em end
                            end
                            if preset.Accessories.Transparency ~= nil then
                                handle.Transparency = preset.Accessories.Transparency
                            end
                        end)
                    end
                end
            end
        end
    else
        local parts = {}
        if preset.AllParts then
            for _, part in ipairs(UCam.character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    table.insert(parts, part)
                end
            end
        end
        
        for _, part in ipairs(parts) do
            pcall(function()
                if preset.Color then
                    part.Color = preset.Color
                end
                if preset.Material then
                    local enumMat = Enum.Material[preset.Material]
                    if enumMat then
                        part.Material = enumMat
                    end
                end
                if preset.Transparency then
                    part.Transparency = preset.Transparency
                end
            end)
        end
    end
end

-- ============================================================
-- RAINBOW BY PART (animated)
-- ============================================================
local rainbowTick = 0
function UCam.updateRainbowBodyColor(dt)
    if not UCam.BodyColor.RainbowEnabled then return end
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    rainbowTick = rainbowTick + dt * (UCam.BodyColor.RainbowSpeed or 1.0)
    
    local parts = getPartsForSelection(UCam.character, UCam.BodyColor.RainbowPart or "Todo")
    
    for i, part in ipairs(parts) do
        local hue = ((rainbowTick * 60 + i * 30) % 360) / 360
        local color = Color3.fromHSV(hue, 1, 1)
        pcall(function()
            part.Color = color
        end)
    end
end

-- ============================================================
-- APPLY TO OTHER PLAYER (LOCAL)
-- ============================================================
function UCam.applyBodyColorToPlayer(player, partSelection, color, material, transparency)
    if not player or not player.Character then return end
    local character = player.Character
    
    -- Snapshot if first time
    if not UCam.BodyColor._playerTargets[player] then
        UCam.BodyColor._playerTargets[player] = {
            originalAppearance = snapshotCharacterAppearance(character),
            character = character,
        }
    end
    
    local parts = getPartsForSelection(character, partSelection)
    
    for _, part in ipairs(parts) do
        pcall(function()
            if color then part.Color = color end
            if material then
                local enumMat = Enum.Material[material]
                if enumMat then part.Material = enumMat end
            end
            if transparency then part.Transparency = transparency end
        end)
    end
end

function UCam.applyPresetToPlayer(player, presetName)
    if not player or not player.Character then return end
    local character = player.Character
    
    local preset = PRESETS[presetName] or UCam.BodyColor.Presets[presetName]
    if not preset then return end
    
    -- Snapshot if first time
    if not UCam.BodyColor._playerTargets[player] then
        UCam.BodyColor._playerTargets[player] = {
            originalAppearance = snapshotCharacterAppearance(character),
            character = character,
        }
    end
    
    if presetName == "Glitch" then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                pcall(function()
                    part.Color = Color3.fromRGB(
                        math.random(0, 255),
                        math.random(0, 255),
                        math.random(0, 255)
                    )
                    part.Transparency = math.random(0, 100) / 100
                end)
            end
        end
    elseif preset.Parts then
        -- v8.1 FIX: presets custom (formato Parts/Accessories) en otros jugadores
        for k, v in pairs(preset.Parts) do
            local part = character:FindFirstChild(k, true)
            if part and part:IsA("BasePart") then
                pcall(function()
                    if v.Color then part.Color = v.Color end
                    if v.Material then
                        local em = Enum.Material[v.Material]
                        if em then part.Material = em end
                    end
                    if v.Transparency ~= nil then part.Transparency = v.Transparency end
                end)
            end
        end
        if preset.Accessories then
            for _, acc in ipairs(character:GetChildren()) do
                if acc:IsA("Accessory") then
                    local handle = acc:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        pcall(function()
                            if preset.Accessories.Color then handle.Color = preset.Accessories.Color end
                            if preset.Accessories.Material then
                                local em = Enum.Material[preset.Accessories.Material]
                                if em then handle.Material = em end
                            end
                            if preset.Accessories.Transparency ~= nil then
                                handle.Transparency = preset.Accessories.Transparency
                            end
                        end)
                    end
                end
            end
        end
    else
        local parts = {}
        if preset.AllParts then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    table.insert(parts, part)
                end
            end
        end
        
        for _, part in ipairs(parts) do
            pcall(function()
                if preset.Color then part.Color = preset.Color end
                if preset.Material then
                    local enumMat = Enum.Material[preset.Material]
                    if enumMat then part.Material = enumMat end
                end
                if preset.Transparency then part.Transparency = preset.Transparency end
            end)
        end
    end
end

-- ============================================================
-- RESTORE
-- ============================================================
function UCam.restoreBodyColor()
    UCam.refreshCharacterRefs()
    if not UCam.character then return end
    
    if UCam.BodyColor._originals[UCam.character] then
        restoreCharacterAppearance(UCam.BodyColor._originals[UCam.character])
        UCam.BodyColor._originals[UCam.character] = nil
    end
    
    -- Reset config
    for k, _ in pairs(UCam.BodyColor.Parts) do
        UCam.BodyColor.Parts[k].Color = nil
        UCam.BodyColor.Parts[k].Material = nil
        UCam.BodyColor.Parts[k].Transparency = 0
    end
    UCam.BodyColor.Accessories.Color = nil
    UCam.BodyColor.Accessories.Material = nil
    UCam.BodyColor.Accessories.Transparency = 0
end

function UCam.restorePlayerBodyColor(player)
    if not player then return end
    
    if UCam.BodyColor._playerTargets[player] then
        restoreCharacterAppearance(UCam.BodyColor._playerTargets[player].originalAppearance)
        UCam.BodyColor._playerTargets[player] = nil
    end
end

function UCam.restoreAllPlayerBodyColors()
    for player, data in pairs(UCam.BodyColor._playerTargets) do
        if player and player.Character then
            restoreCharacterAppearance(data.originalAppearance)
        end
    end
    table.clear(UCam.BodyColor._playerTargets)
end

-- ============================================================
-- SAVE/LOAD CUSTOM PRESETS
-- ============================================================
function UCam.saveBodyColorPreset(name)
    UCam.refreshCharacterRefs()
    if not UCam.character then return false end
    
    local preset = {
        Parts = {},
        Accessories = {},
    }
    
    -- Save current configuration
    for k, v in pairs(UCam.BodyColor.Parts) do
        preset.Parts[k] = {
            Color = v.Color,
            Material = v.Material,
            Transparency = v.Transparency,
        }
    end
    
    preset.Accessories = {
        Color = UCam.BodyColor.Accessories.Color,
        Material = UCam.BodyColor.Accessories.Material,
        Transparency = UCam.BodyColor.Accessories.Transparency,
    }
    
    UCam.BodyColor.Presets[name] = preset
    return true
end

function UCam.loadBodyColorPreset(name)
    local preset = UCam.BodyColor.Presets[name]
    if not preset then return false end
    
    -- Apply saved configuration
    for k, v in pairs(preset.Parts) do
        if UCam.BodyColor.Parts[k] then
            UCam.BodyColor.Parts[k].Color = v.Color
            UCam.BodyColor.Parts[k].Material = v.Material
            UCam.BodyColor.Parts[k].Transparency = v.Transparency
        end
    end
    
    UCam.BodyColor.Accessories.Color = preset.Accessories.Color
    UCam.BodyColor.Accessories.Material = preset.Accessories.Material
    UCam.BodyColor.Accessories.Transparency = preset.Accessories.Transparency
    
    return true
end

-- ============================================================
-- UPDATE / INIT / STOP
-- ============================================================
function UCam.updateBodyColor(dt)
    UCam.updateRainbowBodyColor(dt)
end

function UCam.initBodyColor()
    if UCam.BodyColor._connHeartbeat then return end
    UCam.BodyColor._connHeartbeat = UCam.RunService.Heartbeat:Connect(function(dt)
        UCam.updateBodyColor(dt)
    end)
end

function UCam.stopBodyColor()
    if UCam.BodyColor._connHeartbeat then
        UCam.BodyColor._connHeartbeat:Disconnect()
        UCam.BodyColor._connHeartbeat = nil
    end
    
    UCam.restoreBodyColor()
    UCam.restoreAllPlayerBodyColors()
    UCam.BodyColor.RainbowEnabled = false
end
