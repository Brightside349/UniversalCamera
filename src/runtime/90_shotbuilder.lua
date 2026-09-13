-- ============================================================
-- Universal Camera Pro v12.2 · Shot Builder
-- Plantillas de toma que generan waypoints editables sobre el Director.
-- ============================================================
local UCam = _G.UCam

UCam.ShotBuilder = UCam.ShotBuilder or {
    Template = "Dolly In",
    TargetMode = "Propio",
    Duration = 5,
    ArcDegrees = 90,
    DistanceScale = 1.6,
    HeightOffset = 1.5,
}

local function targetPosition()
    local mode = UCam.ShotBuilder.TargetMode
    local targetPlayer
    if mode == "Espectado" and UCam.Spectate then
        targetPlayer = UCam.Spectate.Target
    elseif mode == "LookAt" and UCam.LookAtLock then
        targetPlayer = UCam.LookAtLock.Target
    elseif mode == "Propio" then
        targetPlayer = UCam.player
    end

    if targetPlayer and targetPlayer.Character and UCam.getCharacterRoot then
        local root = UCam.getCharacterRoot(targetPlayer.Character)
        if root then return root.Position + Vector3.new(0, UCam.ShotBuilder.HeightOffset, 0) end
    end

    local camera = UCam.camera
    if camera then return camera.CFrame.Position + camera.CFrame.LookVector * 20 end
    return nil
end

local function shotWaypoint(cf, label)
    return { cf = cf, fov = UCam.camera.FieldOfView, roll = 0, speed = 1, hold = 0, label = label }
end

local function rebuildRoute(points)
    if #points < 2 then return false end
    table.clear(UCam.Waypoint.List)
    for _, point in ipairs(points) do table.insert(UCam.Waypoint.List, point) end
    UCam.Waypoint.Duration = UCam.clamp(tonumber(UCam.ShotBuilder.Duration) or 5, 1, 60)
    UCam.Waypoint.Easing = "Smooth"
    UCam.Waypoint.CurveMode = "Linear"
    UCam.Director.Active = false
    if UCam.refreshWaypointDropdown then UCam.refreshWaypointDropdown() end
    if UCam.drawPathVisualizer then UCam.drawPathVisualizer() end
    return true
end

function UCam.buildShot(template)
    if template then UCam.ShotBuilder.Template = template end
    local camera = UCam.camera
    local target = targetPosition()
    if not camera or not target then
        UCam.notify("Shot Builder", "No se encontró un objetivo válido.", 3)
        return false
    end

    local start = camera.CFrame
    local startPos = start.Position
    local toTarget = target - startPos
    local distance = math.max(toTarget.Magnitude, 2)
    local direction = toTarget.Unit
    local right = start.RightVector
    local templateName = UCam.ShotBuilder.Template
    local finish

    if templateName == "Dolly Out" then
        local endPos = target - direction * distance * UCam.ShotBuilder.DistanceScale
        finish = CFrame.lookAt(endPos, target)
    elseif templateName == "Orbit" then
        local radians = math.rad(tonumber(UCam.ShotBuilder.ArcDegrees) or 90)
        local offset = startPos - target
        local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), radians):VectorToWorldSpace(offset)
        finish = CFrame.lookAt(target + rotated, target)
    elseif templateName == "Crane" then
        local endPos = startPos + Vector3.new(0, UCam.ShotBuilder.HeightOffset * 3, 0) + right * 2
        finish = CFrame.lookAt(endPos, target)
    elseif templateName == "Reveal" then
        local endPos = target - direction * math.max(distance * 0.55, 4)
        local revealStart = endPos + right * math.max(distance * 0.65, 5)
        start = CFrame.lookAt(revealStart, target)
        finish = CFrame.lookAt(endPos, target)
    else -- Dolly In
        local endPos = target - direction * math.max(distance * 0.45, 2)
        finish = CFrame.lookAt(endPos, target)
    end

    local ok = rebuildRoute({
        shotWaypoint(start, templateName .. " inicio"),
        shotWaypoint(finish, templateName .. " final"),
    })
    if ok then
        UCam.notify("Shot Builder", templateName .. " creada como ruta editable.", 4)
    end
    return ok
end

function UCam.getShotBuilderTargetModes()
    return { "Propio", "Espectado", "LookAt", "Punto actual" }
end
