-- ============================================================
-- Universal Camera Pro v6 · 60_director
-- Modo Director: graba waypoints (CFrames) y los reproduce con easing.
-- El visualizador 3D vive en 10_utils.
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   directorAddWaypoint, directorUndoWaypoint, directorClearWaypoints,
--   directorTogglePlay, updateDirector
-- ============================================================
local UCam = _G.UCam

function UCam.directorAddWaypoint(cf)
    table.insert(UCam.Waypoint.List, cf)
    UCam.notify("Director", string.format("Waypoint #%d guardado.", #UCam.Waypoint.List))
    UCam.drawPathVisualizer()
end

function UCam.directorUndoWaypoint()
    local n = #UCam.Waypoint.List
    if n == 0 then
        UCam.notify("Director", "No hay waypoints."); return
    end
    table.remove(UCam.Waypoint.List)
    UCam.notify("Director", string.format("Waypoint eliminado (%d restantes).", #UCam.Waypoint.List))
    UCam.drawPathVisualizer()
end

function UCam.directorClearWaypoints()
    table.clear(UCam.Waypoint.List)
    UCam.Director.Active = false
    UCam.notify("Director", "Waypoints limpiados.")
    UCam.drawPathVisualizer()
end

function UCam.updateDirector(deltaTime)
    if not UCam.Director.Active then return end
    local n = #UCam.Waypoint.List
    if n < 2 then
        UCam.Director.Active = false
        UCam.notify("Director", "Necesitas al menos 2 waypoints.")
        return
    end

    local elapsed = os.clock() - UCam.Director.StartTime
    local total   = math.max(UCam.Waypoint.Duration, 0.5)
    local t       = elapsed / total
    if t >= 1 then
        if UCam.Waypoint.Loop then
            UCam.Director.StartTime = os.clock()
            t = 0
        else
            UCam.Director.Active = false
            UCam.camCFrame = UCam.Waypoint.List[n]
            UCam.camera.CFrame = UCam.camCFrame
            if UCam.Waypoint.UseFOV then UCam.camera.FieldOfView = UCam.Waypoint.FOV end
            UCam.notify("Director", "Reproduccion finalizada.")
            return
        end
    end

    local ease     = UCam.getEasingFn(UCam.Waypoint.Easing)
    local eased    = ease(UCam.clamp(t, 0, 1))
    local segCount = n - 1
    local segF     = eased * segCount
    local segIdx   = UCam.clamp(math.floor(segF) + 1, 1, segCount)
    local localT   = UCam.clamp(segF - math.floor(segF), 0, 1)

    local cfA      = UCam.Waypoint.List[segIdx]
    local cfB      = UCam.Waypoint.List[segIdx + 1]
    if cfA and cfB then
        UCam.camCFrame = cfA:Lerp(cfB, localT)
    elseif cfA then
        UCam.camCFrame = cfA
    end

    UCam.camera.CFrame = UCam.camCFrame

    if UCam.Waypoint.UseFOV then
        local startFov = UCam.Director.PlayStartFOV or UCam.Saved.FOV
        UCam.camera.FieldOfView = startFov + (UCam.Waypoint.FOV - startFov) * eased
    end
end

function UCam.directorTogglePlay(state)
    if state then
        if #UCam.Waypoint.List < 2 then
            UCam.Director.Active = false
            UCam.notify("Director", "Necesitas al menos 2 waypoints.")
            return
        end
        UCam.Director.Active       = true
        UCam.Director.StartTime    = os.clock()
        UCam.Director.PlayStartFOV = UCam.camera.FieldOfView
        UCam.notify("Director", "Reproduciendo ruta...")
    else
        UCam.Director.Active = false
        UCam.notify("Director", "Reproduccion detenida.")
    end
end
