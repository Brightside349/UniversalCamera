-- ============================================================
-- Universal Camera Pro v7 · 60_director
-- Modo Director expandido: graba waypoints (CFrames + FOV + roll
-- + velocidad por segmento) y los reproduce con easing LINEAL /
-- Catmull-Rom / Bezier. El visualizador 3D (con flechas de dirección
-- opcional) vive en 10_utils.
--
-- Depende de: 00_config, 10_utils
-- Expone (UCam.*):
--   directorAddWaypoint, directorUndoWaypoint, directorClearWaypoints,
--   directorTogglePlay, updateDirector,
--   directorSerializeRoute, directorDeserializeRoute,
--   directorLoadRoute, directorSaveRoute,
--   directorGetWaypoint helpers internos.
--
-- Compatibilidad: la lista UCam.Waypoint.List puede contener CFrames
-- puros (antiguo) o tablas {cf=, fov=, roll=, speed=}. Las funciones
-- de acceso normalizan ambos formatos.
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- HELPERS DE ACCESO NORMALIZADO A WAYPOINTS
-- ============================================================

-- Devuelve el CFrame de un waypoint (sea CFrame puro o tabla)
local function wpCF(wp)
    if typeof(wp) == "CFrame" then return wp end
    if type(wp) == "table" then return wp.cf end
    return nil
end

-- Devuelve el FOV de un waypoint, o el global por defecto
local function wpFOV(wp)
    if typeof(wp) == "CFrame" then return UCam.Waypoint.FOV end
    if type(wp) == "table" then
        if wp.fov ~= nil then return wp.fov end
        return UCam.Waypoint.FOV
    end
    return UCam.Waypoint.FOV
end

-- Devuelve el roll (radianes) de un waypoint, o el global por defecto
local function wpRoll(wp)
    if typeof(wp) == "CFrame" then return UCam.Waypoint.Roll end
    if type(wp) == "table" then
        if wp.roll ~= nil then return wp.roll end
        return UCam.Waypoint.Roll
    end
    return UCam.Waypoint.Roll
end

-- Devuelve la velocidad relativa del segmento que parte de este waypoint
local function wpSpeed(wp)
    if type(wp) == "table" and wp.speed ~= nil then return wp.speed end
    return 1
end

UCam.directorGetWP = { cf = wpCF, fov = wpFOV, roll = wpRoll, speed = wpSpeed }

-- ============================================================
-- NORMALIZA LA LISTA: convierte cualquier CFrame puro en tabla
-- (se llama al agregar / deserializar para mantener consistencia)
-- ============================================================
local function normalizeList()
    for i, wp in ipairs(UCam.Waypoint.List) do
        if typeof(wp) == "CFrame" then
            UCam.Waypoint.List[i] = {
                cf    = wp,
                fov   = UCam.Waypoint.FOV,
                roll  = UCam.Waypoint.Roll,
                speed = 1,
            }
        end
    end
end

-- ============================================================
-- INTERPOLACIÓN DE CURVAS
-- ============================================================

-- Lerp entre dos CFrames (lineal) FIXME: pHl usar utils
local function lerpCF(a, b, t)
    return a:Lerp(b, t)
end

-- Catmull-Rom entre 4 CFrames. t ∈ [0,1] va de p1 a p2.
-- Posición usa Catmull-Rom clásico; rotación usa slerp (Lerp) p1→p2.
local function catmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    local pos = (
        p0.Position * (-t3 + 2*t2 - t) +
        p1.Position * (3*t3 - 5*t2 + 2) +
        p2.Position * (-3*t3 + 4*t2 + t) +
        p3.Position * (t3 - t2)
    ) * 0.5
    local rot = p1:Lerp(p2, t)
    return CFrame.new(pos) * (rot - rot.Position)
end

-- Bezier cuadrática entre p0 (control), p1 (control), p2 (destino).
-- Aquí usamos Bezier cúbica entre 4 puntos para simetría con Catmull-Rom.
local function bezier3(p0, p1, p2, p3, t)
    local u  = 1 - t
    local tt = t * t
    local uu = u * u
    local pos =
        p0.Position * (uu * u) +
        p1.Position * (3 * uu * t) +
        p2.Position * (3 * u * tt) +
        p3.Position * (tt * t)
    local rot = p1:Lerp(p2, t)
    return CFrame.new(pos) * (rot - rot.Position)
end

-- Lerp simple entre dos escalares
local function lerpNum(a, b, t)
    return a + (b - a) * t
end

-- ============================================================
-- MUESTREO DE LA RUTA SEGÚN MODO DE CURVA
-- Devuelve (cf, fov, roll) interpolados en la posición global t ∈ [0,1]
-- ============================================================
local function sampleRoute(t)
    local list = UCam.Waypoint.List
    local n = #list
    if n == 0 then return nil, 70, 0 end
    if n == 1 then return wpCF(list[1]), wpFOV(list[1]), wpRoll(list[1]) end

    t = UCam.clamp(t, 0, 1)
    local mode = UCam.Waypoint.CurveMode or "Linear"
    local segCount = n - 1
    local segF   = t * segCount
    local segIdx = UCam.clamp(math.floor(segF) + 1, 1, segCount)
    local localT = UCam.clamp(segF - math.floor(segF), 0, 1)

    local cfA = list[segIdx]
    local cfB = list[segIdx + 1]
    local cf, fov, roll

    if mode == "Catmull-Rom" or mode == "Bezier" then
        -- Necesitamos 4 puntos: anterior, A, B, siguiente (con clamping en los bordes)
        local cfPrev = list[math.max(1, segIdx - 1)]
        local cfNext = list[math.min(n, segIdx + 2)]
        local p0 = wpCF(cfPrev) or wpCF(cfA)
        local p1 = wpCF(cfA)
        local p2 = wpCF(cfB)
        local p3 = wpCF(cfNext) or wpCF(cfB)
        if mode == "Catmull-Rom" then
            cf = catmullRom(p0, p1, p2, p3, localT)
        else
            cf = bezier3(p0, p1, p2, p3, localT)
        end
    else
        -- Lineal
        local p1 = wpCF(cfA)
        local p2 = wpCF(cfB)
        cf = lerpCF(p1, p2, localT)
    end

    -- FOV y roll SIEMPRE interpolan linealmente entre A y B
    local fovA, fovB = wpFOV(cfA), wpFOV(cfB)
    local rollA, rollB = wpRoll(cfA), wpRoll(cfB)
    fov  = lerpNum(fovA,  fovB,  localT)
    roll = lerpNum(rollA, rollB, localT)

    return cf, fov, roll
end

-- ============================================================
-- API PÚBLICA DE WAYPOINTS
-- ============================================================

function UCam.directorAddWaypoint(cf)
    -- cf puede ser CFrame (llamada antigua) o ya venir normalizado
    local wp = {
        cf    = cf,
        fov   = UCam.Waypoint.Next.useFOV and UCam.Waypoint.Next.fov or UCam.Waypoint.FOV,
        roll  = UCam.Waypoint.UseRoll and (UCam.Waypoint.Next.roll) or UCam.Waypoint.Roll,
        speed = UCam.Waypoint.Next.speed or 1,
    }
    table.insert(UCam.Waypoint.List, wp)
    UCam.notify("Director",
        string.format("Waypoint #%d guardado (curva: %s).", #UCam.Waypoint.List, UCam.Waypoint.CurveMode))
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

-- ============================================================
-- UPDATE: reproduce la ruta frame a frame
-- ============================================================
function UCam.updateDirector(deltaTime)
    if not UCam.Director.Active then return end
    local n = #UCam.Waypoint.List
    if n < 2 then
        UCam.Director.Active = false
        UCam.notify("Director", "Necesitas al menos 2 waypoints.")
        return
    end

    -- Velocidad por segmento: el t global avanza según el speed del segmento actual.
    -- Calculamos en qué segmento estamos en base al tiempo para escalar deltaTime.
    local total = math.max(UCam.Waypoint.Duration, 0.5)
    local elapsed = os.clock() - UCam.Director.StartTime
    local t = elapsed / total

    if t >= 1 then
        if UCam.Waypoint.Loop then
            UCam.Director.StartTime = os.clock()
            t = 0
        else
            UCam.Director.Active = false
            local lastWP = UCam.Waypoint.List[n]
            UCam.camCFrame = wpCF(lastWP)
            UCam.camera.CFrame = UCam.camCFrame
            if UCam.Waypoint.UseFOV then UCam.camera.FieldOfView = wpFOV(lastWP) end
            UCam.notify("Director", "Reproduccion finalizada.")
            return
        end
    end

    local ease  = UCam.getEasingFn(UCam.Waypoint.Easing)
    local eased = ease(UCam.clamp(t, 0, 1))

    local cf, fov, roll = sampleRoute(eased)
    if cf then
        UCam.camCFrame = cf
        -- Aplicar roll del waypoint (Dutch angle por waypoint) si UseRoll está activo
        if UCam.Waypoint.UseRoll and roll and roll ~= 0 then
            UCam.camera.CFrame = UCam.camCFrame * CFrame.Angles(0, 0, roll)
        else
            UCam.camera.CFrame = UCam.camCFrame
        end

        if UCam.Waypoint.UseFOV then
            local startFov = UCam.Director.PlayStartFOV or UCam.Saved.FOV
            UCam.camera.FieldOfView = startFov + (fov - startFov) * eased
        end
    end
end

function UCam.directorTogglePlay(state)
    if state then
        if #UCam.Waypoint.List < 2 then
            UCam.Director.Active = false
            UCam.notify("Director", "Necesitas al menos 2 waypoints.")
            return
        end
        normalizeList()
        UCam.Director.Active       = true
        UCam.Director.StartTime    = os.clock()
        UCam.Director.PlayStartFOV = UCam.camera.FieldOfView
        UCam.notify("Director",
            string.format("Reproduciendo ruta (curva: %s)...", UCam.Waypoint.CurveMode))
    else
        UCam.Director.Active = false
        -- v8.1 FIX: pausar dejaba la cámara Scriptable congelada sin recuperación.
        -- Restaurar al modo normal si no hay freecam activo.
        if UCam.freeCamEnabled then
            UCam.camera.CameraType = Enum.CameraType.Scriptable
        else
            UCam.camera.CameraType = Enum.CameraType.Custom
            if UCam.humanoid then
                UCam.camera.CameraSubject = UCam.humanoid
            end
            UCam.camera.FieldOfView = UCam.Saved.FOV or UCam.DEFAULT_FOV
        end
        UCam.notify("Director", "Reproduccion detenida.")
    end
end

-- ============================================================
-- SERIALIZACIÓN / DESERIALIZACIÓN DE RUTAS (v7)
-- Formato: "version|curveMode|count;frame1;frame2;..."
-- cada frame = "x,y,z,lx,ly,lz,rx,ry,rz,fov,roll,speed"
-- ============================================================
local function cfTo9(cf)
    return cf.Position.X, cf.Position.Y, cf.Position.Z,
           cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z,
           cf.LookVector.X,  cf.LookVector.Y,  cf.LookVector.Z
end

local function nineToCF(px, py, pz, rx, ry, rz, lx, ly, lz)
    local pos   = Vector3.new(px, py, pz)
    local right = Vector3.new(rx, ry, rz)
    local look  = Vector3.new(lx, ly, lz)
    local up    = look:Cross(right)  -- ortogonaliza
    return CFrame.fromMatrix(pos, right, up, -look)
end

function UCam.directorSerializeRoute()
    local list = UCam.Waypoint.List
    if #list == 0 then return "" end
    local parts = {}
    table.insert(parts, "1")                               -- versión
    table.insert(parts, UCam.Waypoint.CurveMode or "Linear")
    table.insert(parts, tostring(#list))

    for _, wp in ipairs(list) do
        local cf = wpCF(wp)
        local px, py, pz, rx, ry, rz, lx, ly, lz = cfTo9(cf)
        table.insert(parts, string.format(
            "%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.1f,%.3f,%.2f",
            px, py, pz, rx, ry, rz, lx, ly, lz,
            wpFOV(wp), wpRoll(wp), wpSpeed(wp)
        ))
    end
    return table.concat(parts, ";")
end

function UCam.directorDeserializeRoute(str)
    if not str or str == "" then return false end
    local segs = {}
    for s in str:gmatch("[^;]+") do table.insert(segs, s) end
    if #segs < 4 then return false end  -- ver + curveMode + count + mínimo 1 frame

    local curveMode = segs[2]
    local count = tonumber(segs[3]) or 0
    if count < 2 then return false end

    local newList = {}
    for i = 1, count do
        local entry = segs[4 + i - 1]
        if entry then
            local v = {}
            for num in entry:gmatch("[^,]+") do table.insert(v, tonumber(num)) end
            if #v >= 9 then
                local cf = nineToCF(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9])
                table.insert(newList, {
                    cf    = cf,
                    fov   = #v >= 10 and v[10] or UCam.Waypoint.FOV,
                    roll  = #v >= 11 and v[11] or 0,
                    speed = #v >= 12 and v[12] or 1,
                })
            end
        end
    end

    if #newList < 2 then return false end
    table.clear(UCam.Waypoint.List)
    for _, w in ipairs(newList) do table.insert(UCam.Waypoint.List, w) end
    UCam.Waypoint.CurveMode = curveMode or UCam.Waypoint.CurveMode
    UCam.drawPathVisualizer()
    return true
end

-- Guardar/cargar rutas serializadas en slots (hasta 3)
local MAX_DIRECTOR_ROUTES = 3
function UCam.directorSaveRoute(slot)
    slot = UCam.clamp(math.floor(slot or 1), 1, MAX_DIRECTOR_ROUTES)
    if #UCam.Waypoint.List < 2 then
        UCam.notify("Director", "No hay ruta para guardar (mín 2 waypoints).")
        return false
    end
    UCam.Director.SavedRoutes[slot] = UCam.directorSerializeRoute()
    UCam.notify("Director", string.format("Ruta guardada en ranura %d (%d waypoints).",
        slot, #UCam.Waypoint.List))
    return true
end

function UCam.directorLoadRoute(slot)
    slot = UCam.clamp(math.floor(slot or 1), 1, MAX_DIRECTOR_ROUTES)
    local str = UCam.Director.SavedRoutes[slot]
    if not str or str == "" then
        UCam.notify("Director", string.format("Ranura %d vacía.", slot))
        return false
    end
    local ok = UCam.directorDeserializeRoute(str)
    if ok then
        UCam.notify("Director", string.format("Ruta %d cargada (%d waypoints, curva %s).",
            slot, #UCam.Waypoint.List, UCam.Waypoint.CurveMode))
    else
        UCam.notify("Director", string.format("Ranura %d: datos inválidos.", slot))
    end
    return ok
end
