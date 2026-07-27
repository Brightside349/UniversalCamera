-- ============================================================
-- Universal Camera Pro v7 · 35_playermod
-- Módulo Central de Modificación de Jugadores (LOCAL):
-- Hub unificado para aplicar poses, colores, escala, invisibilidad,
-- efectos y otras modificaciones a otros jugadores. Solo visible
-- localmente (no se envía al servidor).
--
-- Dependencias: 00_config, 10_utils, 33_poses, 32_bodycolor
-- Expone (UCam.*):
--   applyModToPlayer, applyModToAllPlayers, restorePlayer,
--   restoreAllPlayers, setPlayerScale, setPlayerInvisibility,
--   copyMyAspectToPlayer, updatePlayerMods, initPlayerMod,
--   stopPlayerMod
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- SNAPSHOT SYSTEM
-- ============================================================
local function snapshotPlayer(player)
    if not player or not player.Character then return nil end
    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    local snapshot = {
        character = character,
        appearance = {},
        joints = {},
        humanoidProps = {},
        scale = 1.0,
    }
    
    -- Snapshot appearance
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            snapshot.appearance[part] = {
                Color = part.Color,
                Material = part.Material,
                Transparency = part.Transparency,
                Size = part.Size,
            }
        end
    end
    
    -- Snapshot joints
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D") then
            snapshot.joints[joint] = joint.Transform
        end
    end
    
    -- Snapshot humanoid properties
    if humanoid then
        snapshot.humanoidProps = {
            WalkSpeed = humanoid.WalkSpeed,
            JumpPower = humanoid.JumpPower,
            AutoRotate = humanoid.AutoRotate,
        }
    end
    
    return snapshot
end

local function restorePlayerSnapshot(snapshot)
    if not snapshot or not snapshot.character or not snapshot.character.Parent then
        return
    end
    
    -- Restore appearance
    for part, data in pairs(snapshot.appearance) do
        if part and part.Parent then
            pcall(function()
                part.Color = data.Color
                part.Material = data.Material
                part.Transparency = data.Transparency
                part.Size = data.Size
            end)
        end
    end
    
    -- Restore joints
    for joint, transform in pairs(snapshot.joints) do
        if joint and joint.Parent then
            pcall(function()
                joint.Transform = transform
            end)
        end
    end
    
    -- Restore humanoid
    local humanoid = snapshot.character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid.WalkSpeed = snapshot.humanoidProps.WalkSpeed
            humanoid.JumpPower = snapshot.humanoidProps.JumpPower
            humanoid.AutoRotate = snapshot.humanoidProps.AutoRotate
            humanoid.PlatformStand = false
        end)
    end
    
    -- Re-enable animation scripts
    for _, s in ipairs(snapshot.character:GetDescendants()) do
        if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
            pcall(function() s.Disabled = false end)
        end
    end
end

-- ============================================================
-- APPLY MOD TO PLAYER
-- ============================================================
function UCam.applyModToPlayer(player, modConfig)
    if not player or not player.Character then return false end
    
    -- Create snapshot if first time
    if not UCam.PlayerMod._snapshots[player] then
        UCam.PlayerMod._snapshots[player] = snapshotPlayer(player)
    end
    
    -- Store mod configuration
    UCam.PlayerMod.Targets[player] = modConfig or {}
    
    -- Apply pose
    if modConfig.pose and modConfig.pose ~= "Normal" then
        if UCam.applyPoseToPlayer then
            UCam.applyPoseToPlayer(player, modConfig.pose)
        end
    end
    
    -- Apply color/material/transparency
    if modConfig.color or modConfig.material or modConfig.transparency then
        if UCam.applyBodyColorToPlayer then
            UCam.applyBodyColorToPlayer(
                player,
                "Todo",
                modConfig.color,
                modConfig.material,
                modConfig.transparency
            )
        end
    end
    
    -- Apply preset
    if modConfig.preset then
        if UCam.applyPresetToPlayer then
            UCam.applyPresetToPlayer(player, modConfig.preset)
        end
    end
    
    -- Apply scale
    if modConfig.scale and modConfig.scale ~= 1.0 then
        UCam.setPlayerScale(player, modConfig.scale)
    end
    
    -- Apply invisibility
    if modConfig.invisible then
        UCam.setPlayerInvisibility(player, true)
    end
    
    -- Apply effects
    if modConfig.effects then
        UCam.applyEffectsToPlayer(player, modConfig.effects)
    end
    
    return true
end

-- ============================================================
-- APPLY TO ALL PLAYERS
-- ============================================================
function UCam.applyModToAllPlayers(modConfig)
    local count = 0
    for _, player in ipairs(UCam.Players:GetPlayers()) do
        if player ~= UCam.player and player.Character then
            if UCam.applyModToPlayer(player, modConfig) then
                count = count + 1
            end
        end
    end
    return count
end

-- ============================================================
-- SCALE CONTROL
-- ============================================================
function UCam.setPlayerScale(player, scale)
    if not player or not player.Character then return end
    local character = player.Character
    
    -- Store snapshot if needed
    if not UCam.PlayerMod._snapshots[player] then
        UCam.PlayerMod._snapshots[player] = snapshotPlayer(player)
    end
    
    -- Apply scale to all parts
    local snapshot = UCam.PlayerMod._snapshots[player]
    for part, data in pairs(snapshot.appearance) do
        if part and part.Parent then
            pcall(function()
                part.Size = data.Size * scale
            end)
        end
    end
    
    -- Update stored scale
    if UCam.PlayerMod.Targets[player] then
        UCam.PlayerMod.Targets[player].scale = scale
    else
        UCam.PlayerMod.Targets[player] = { scale = scale }
    end
    
    -- Adjust position if scaling up
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart and scale > 1.0 then
        local origSize = snapshot.appearance[rootPart]
        if origSize then
            local extra = (origSize.Size.Y * (scale - 1)) * 0.5
            pcall(function()
                rootPart.CFrame = rootPart.CFrame + Vector3.new(0, extra, 0)
            end)
        end
    end
end

-- ============================================================
-- INVISIBILITY CONTROL
-- ============================================================
function UCam.setPlayerInvisibility(player, invisible)
    if not player or not player.Character then return end
    local character = player.Character
    
    -- Store snapshot if needed
    if not UCam.PlayerMod._snapshots[player] then
        UCam.PlayerMod._snapshots[player] = snapshotPlayer(player)
    end
    
    local targetTransparency = invisible and 1 or 0
    
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            pcall(function()
                if invisible then
                    part.Transparency = 1
                else
                    -- Restore from snapshot
                    local snapshot = UCam.PlayerMod._snapshots[player]
                    if snapshot and snapshot.appearance[part] then
                        part.Transparency = snapshot.appearance[part].Transparency
                    else
                        part.Transparency = 0
                    end
                end
            end)
        end
    end
    
    -- Update stored config
    if UCam.PlayerMod.Targets[player] then
        UCam.PlayerMod.Targets[player].invisible = invisible
    else
        UCam.PlayerMod.Targets[player] = { invisible = invisible }
    end
end

-- ============================================================
-- EFFECTS (Highlight, Trail, etc.)
-- ============================================================
function UCam.applyEffectsToPlayer(player, effects)
    if not player or not player.Character then return end
    local character = player.Character
    
    -- Apply Highlight/Glow
    if effects.glow then
        local existing = character:FindFirstChild("UCamPlayerGlow")
        if existing then existing:Destroy() end
        
        local hl = Instance.new("Highlight")
        hl.Name = "UCamPlayerGlow"
        hl.Adornee = character
        hl.FillColor = effects.glowColor or Color3.fromRGB(0, 255, 200)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 0.2
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = character
    else
        local existing = character:FindFirstChild("UCamPlayerGlow")
        if existing then existing:Destroy() end
    end
    
    -- Store effects config
    if UCam.PlayerMod.Targets[player] then
        UCam.PlayerMod.Targets[player].effects = effects
    else
        UCam.PlayerMod.Targets[player] = { effects = effects }
    end
end

-- ============================================================
-- COPY ASPECT
-- ============================================================
function UCam.copyMyAspectToPlayer(player)
    if not player or not player.Character then return false end
    
    UCam.refreshCharacterRefs()
    if not UCam.character then return false end
    
    local modConfig = {}
    
    -- Copy current pose
    if UCam.Poses and UCam.Poses.Current and UCam.Poses.Current ~= "Normal" then
        modConfig.pose = UCam.Poses.Current
    end
    
    -- Copy current body color settings
    if UCam.BodyColor and UCam.BodyColor.Parts then
        -- Get color from Head part if available
        local head = UCam.character:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            modConfig.color = head.Color
            modConfig.material = head.Material.Name
        end
    end
    
    -- Copy scale if different from 1
    if UCam.Fun and UCam.Fun._currentScale and UCam.Fun._currentScale ~= 1.0 then
        modConfig.scale = UCam.Fun._currentScale
    end
    
    -- Apply to target player
    return UCam.applyModToPlayer(player, modConfig)
end

-- ============================================================
-- RESTORE FUNCTIONS
-- ============================================================
function UCam.restorePlayer(player)
    if not player then return end
    
    local snapshot = UCam.PlayerMod._snapshots[player]
    if snapshot then
        restorePlayerSnapshot(snapshot)
        UCam.PlayerMod._snapshots[player] = nil
    end
    
    -- Clear target config
    UCam.PlayerMod.Targets[player] = nil
    
    -- Remove effects
    if player.Character then
        local glow = player.Character:FindFirstChild("UCamPlayerGlow")
        if glow then glow:Destroy() end
    end
end

function UCam.restoreAllPlayers()
    for player, snapshot in pairs(UCam.PlayerMod._snapshots) do
        if player and player:IsA("Player") then
            restorePlayerSnapshot(snapshot)
            
            -- Remove effects
            if player.Character then
                local glow = player.Character:FindFirstChild("UCamPlayerGlow")
                if glow then glow:Destroy() end
            end
        end
    end
    
    table.clear(UCam.PlayerMod._snapshots)
    table.clear(UCam.PlayerMod.Targets)
    table.clear(UCam.PlayerMod.SelectedPlayers)
end

-- ============================================================
-- MULTIPLE SELECTION
-- ============================================================
function UCam.togglePlayerSelection(player)
    if UCam.PlayerMod.SelectedPlayers[player] then
        UCam.PlayerMod.SelectedPlayers[player] = nil
    else
        UCam.PlayerMod.SelectedPlayers[player] = true
    end
end

function UCam.applyModToSelectedPlayers(modConfig)
    local count = 0
    for player, selected in pairs(UCam.PlayerMod.SelectedPlayers) do
        if selected and player and player.Character then
            if UCam.applyModToPlayer(player, modConfig) then
                count = count + 1
            end
        end
    end
    return count
end

-- ============================================================
-- UPDATE LOOP (maintain effects)
-- ============================================================
function UCam.updatePlayerMods(dt)
    -- Maintain any continuous effects here
    -- For now, most modifications are one-time or handled by other modules
end

-- ============================================================
-- INIT / STOP
-- ============================================================
function UCam.initPlayerMod()
    if UCam.PlayerMod._connHeartbeat then return end
    UCam.PlayerMod._connHeartbeat = UCam.RunService.Heartbeat:Connect(function(dt)
        UCam.updatePlayerMods(dt)
    end)
end

function UCam.stopPlayerMod()
    if UCam.PlayerMod._connHeartbeat then
        UCam.PlayerMod._connHeartbeat:Disconnect()
        UCam.PlayerMod._connHeartbeat = nil
    end
    
    UCam.restoreAllPlayers()
end

-- ============================================================
-- QUICK PRESETS FOR PLAYERS
-- ============================================================
UCam.PlayerModPresets = {
    ["Gigante"] = {
        scale = 3.0,
    },
    ["Diminuto"] = {
        scale = 0.3,
    },
    ["Fantasma"] = {
        preset = "Fantasma",
    },
    ["T-Pose"] = {
        pose = "T-Pose",
    },
    ["Invisible"] = {
        invisible = true,
    },
    ["Dorado"] = {
        preset = "Dorado",
    },
    ["Neon"] = {
        color = Color3.fromRGB(0, 255, 200),
        material = "Neon",
        effects = {
            glow = true,
            glowColor = Color3.fromRGB(0, 255, 200),
        },
    },
}

function UCam.applyPresetToPlayer(player, presetName)
    local preset = UCam.PlayerModPresets[presetName]
    if not preset then return false end
    return UCam.applyModToPlayer(player, preset)
end

function UCam.applyPresetToAllPlayers(presetName)
    local preset = UCam.PlayerModPresets[presetName]
    if not preset then return 0 end
    return UCam.applyModToAllPlayers(preset)
end
