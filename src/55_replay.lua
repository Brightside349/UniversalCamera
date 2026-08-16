-- ============================================================
-- Universal Camera Pro v8.1 · 55_replay REMASTERIZADO
-- Sistema de grabación y replay de cámara LIBRE.
-- 
-- CAMBIOS v8.1:
-- - Ya NO graba desde la cámara del jugador
-- - Solo funciona con FREE CAM activada (cámara Scriptable)
-- - Es una alternativa al Director sin waypoints manuales
-- - Graba el recorrido libre que hagas manualmente
-- - Al reproducir, repite ese recorrido de forma suave
-- - Eliminados: marcadores, speed ramps, compartir web (demasiado complejo)
-- - Simplificado: solo grabar, reproducir, guardar/cargar 3 rutas
--
-- Dependencias: 00_config, 10_utils, 70_camcore
-- Expone (UCam.*):
--   startRecording, stopRecording,
--   startPlayback, pausePlayback, stopPlayback,
--   seekReplay, setPlaybackSpeed,
--   saveCurrentRoute, loadRoute, deleteRoute,
--   serializeRoute, deserializeRoute,
--   updateReplay, stopReplay,
--   Replay.getFormattedTime
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- CONSTANTES
-- ============================================================
local RECORD_FPS      = 30          -- frames por segundo grabados
local MAX_ROUTES      = 3           -- rutas guardadas máximo
local FRAME_INTERVAL  = 1 / RECORD_FPS

-- ============================================================
-- ESTADO INTERNO
-- ============================================================
local _recordConn     = nil         -- conexión Heartbeat para grabar
local _playConn       = nil         -- conexión Heartbeat para reproducir
local _recordTimer    = 0           -- acumulador de tiempo entre frames
local _playHead       = 0           -- índice de frame actual en playback (float)

-- ============================================================
-- HELPERS
-- ============================================================

-- Formatea segundos como "MM:SS.f"
local function formatTime(secs)
    local m  = math.floor(secs / 60)
    local s  = math.floor(secs % 60)
    local f  = math.floor((secs - math.floor(secs)) * 10)
    return string.format("%02d:%02d.%d", m, s, f)
end

UCam.Replay.getFormattedTime = formatTime

-- Interpolación cúbica hermite (Catmull-Rom) entre cuatro CFrames
-- Devuelve el CFrame interpolado en t ∈ [0,1] entre p1 y p2
local function catmullRomCFrame(p0, p1, p2, p3, t)
    -- Posición Catmull-Rom
    local t2 = t * t
    local t3 = t2 * t
    local pos = (
        p0.Position * (-t3 + 2*t2 - t) +
        p1.Position * (3*t3 - 5*t2 + 2) +
        p2.Position * (-3*t3 + 4*t2 + t) +
        p3.Position * (t3 - t2)
    ) * 0.5

    -- Rotación: slerp simple entre p1 y p2 (quaternion)
    local rot = p1:Lerp(p2, t)

    return CFrame.new(pos) * (rot - rot.Position)
end

-- Slerp de FOV puro
local function lerpFOV(f1, f2, t)
    return f1 + (f2 - f1) * t
end

-- Obtiene el frame en una posición decimal del array (interpolando)
local function sampleFrames(frames, pos)
    local n = #frames
    if n == 0 then return nil, 70 end
    if n == 1 then return frames[1].cf, frames[1].fov end

    pos = math.clamp(pos, 1, n)
    local i  = math.floor(pos)
    local t  = pos - i

    if i >= n then return frames[n].cf, frames[n].fov end

    local i0 = math.max(1, i - 1)
    local i1 = i
    local i2 = math.min(n, i + 1)
    local i3 = math.min(n, i + 2)

    local cf = catmullRomCFrame(
        frames[i0].cf, frames[i1].cf,
        frames[i2].cf, frames[i3].cf, t
    )
    local fov = lerpFOV(frames[i1].fov, frames[i2].fov, t)

    return cf, fov
end

-- ============================================================
-- GRABACIÓN
-- ============================================================
function UCam.startRecording()
    -- v8.1: Verificar que la FREE CAM esté activa
    if not UCam.freeCamEnabled then
        UCam.notify("Replay", "Activa la Cámara Libre primero para grabar.", 4)
        return
    end
    
    if UCam.Replay.Recording then return end
    if UCam.Replay.Playing then
        UCam.stopPlayback()
    end

    -- Limpiar frames previos sin guardar
    table.clear(UCam.Replay.Frames)
    UCam.Replay.Recording      = true
    UCam.Replay._recordStartTime = tick()
    _recordTimer = 0

    _recordConn = UCam.RunService.Heartbeat:Connect(function(dt)
        if not UCam.Replay.Recording then return end
        
        -- v8.1: Si se desactiva la free cam durante grabación, detener
        if not UCam.freeCamEnabled then
            UCam.stopRecording()
            UCam.notify("Replay", "Grabación detenida: Free Cam desactivada.", 3)
            return
        end

        _recordTimer = _recordTimer + dt
        if _recordTimer < FRAME_INTERVAL then return end
        _recordTimer = _recordTimer - FRAME_INTERVAL

        -- Verificar límite de duración
        local elapsed = tick() - UCam.Replay._recordStartTime
        if elapsed > UCam.Replay.MaxDuration then
            UCam.stopRecording()
            return
        end

        -- Capturar CFrame + FOV de la cámara actual (libre)
        local cf  = UCam.camera.CFrame
        local fov = UCam.camera.FieldOfView
        table.insert(UCam.Replay.Frames, {
            cf  = cf,
            fov = fov,
            t   = elapsed,
        })
    end)

    UCam.notify("Replay", string.format("Grabando recorrido libre... (máx %ds)", UCam.Replay.MaxDuration))
end

function UCam.stopRecording()
    if not UCam.Replay.Recording then return end
    UCam.Replay.Recording = false

    if _recordConn then
        _recordConn:Disconnect()
        _recordConn = nil
    end

    local n = #UCam.Replay.Frames
    if n > 0 then
        local duration = UCam.Replay.Frames[n].t
        UCam.Replay.CurrentTime = 0
        UCam.notify("Replay",
            string.format("Grabación detenida: %d frames / %s",
                n, formatTime(duration)))
    else
        UCam.notify("Replay", "Grabación vacía.")
    end
end

-- ============================================================
-- REPRODUCCIÓN
-- ============================================================
function UCam.startPlayback()
    local frames = UCam.Replay.Frames
    if #frames < 2 then
        UCam.notify("Replay", "No hay grabación. Graba un recorrido primero.", 3)
        return
    end
    if UCam.Replay.Recording then
        UCam.stopRecording()
    end

    UCam.Replay.Playing = true
    UCam.Replay.Paused  = false
    _playHead = 1

    -- Entrar en modo cámara scriptable (igual que Director)
    UCam.camera.CameraType = Enum.CameraType.Scriptable

    _playConn = UCam.RunService.Heartbeat:Connect(function(dt)
        if not UCam.Replay.Playing or UCam.Replay.Paused then return end

        local frames = UCam.Replay.Frames
        local n      = #frames

        -- Avanzar playhead según velocidad y fps grabado
        _playHead = _playHead + (dt * RECORD_FPS * UCam.Replay.PlaybackSpeed)

        -- Actualizar CurrentTime para la UI (en segundos)
        UCam.Replay.CurrentTime = (_playHead - 1) / RECORD_FPS

        if _playHead > n then
            if UCam.Replay.Loop then
                _playHead = 1
                UCam.Replay.CurrentTime = 0
            else
                _playHead = n
                UCam.stopPlayback()
                return
            end
        end

        -- Samplear y aplicar
        local cf, fov = sampleFrames(frames, _playHead)
        if cf then
            UCam.camera.CFrame = cf
            UCam.camera.FieldOfView = fov
        end
    end)

    UCam.notify("Replay", "Reproduciendo recorrido...")
end

function UCam.pausePlayback()
    if not UCam.Replay.Playing then return end
    UCam.Replay.Paused = not UCam.Replay.Paused
    UCam.notify("Replay", UCam.Replay.Paused and "Pausa." or "Reproduciendo.")
end

function UCam.stopPlayback()
    UCam.Replay.Playing = false
    UCam.Replay.Paused  = false

    if _playConn then
        _playConn:Disconnect()
        _playConn = nil
    end

    -- Restaurar cámara al modo normal
    if UCam.freeCamEnabled then
        UCam.camera.CameraType = Enum.CameraType.Scriptable
    else
        UCam.camera.CameraType = Enum.CameraType.Custom
        if UCam.humanoid then
            UCam.camera.CameraSubject = UCam.humanoid
        end
        UCam.camera.FieldOfView = UCam.Saved.FOV or UCam.DEFAULT_FOV
    end

    UCam.Replay.CurrentTime = 0
    UCam.notify("Replay", "Reproducción detenida.")
end

-- Seek: saltar a un tiempo en segundos
function UCam.seekReplay(timeSecs)
    local frames = UCam.Replay.Frames
    local n = #frames
    if n < 2 then return end

    local totalDuration = frames[n].t
    timeSecs = math.clamp(timeSecs, 0, totalDuration)
    _playHead = 1 + (timeSecs * RECORD_FPS)
    _playHead = math.clamp(_playHead, 1, n)
    UCam.Replay.CurrentTime = timeSecs

    -- Aplicar el frame inmediatamente para que la UI lo refleje
    local cf, fov = sampleFrames(frames, _playHead)
    if cf then
        UCam.camera.CFrame = cf
        UCam.camera.FieldOfView = fov
    end
end

function UCam.setPlaybackSpeed(speed)
    UCam.Replay.PlaybackSpeed = math.clamp(speed, 0.1, 8)
end

-- ============================================================
-- RUTAS GUARDADAS (hasta MAX_ROUTES)
-- ============================================================
function UCam.saveCurrentRoute(slotIndex)
    slotIndex = math.clamp(math.floor(slotIndex or 1), 1, MAX_ROUTES)
    local frames = UCam.Replay.Frames
    if #frames < 2 then
        UCam.notify("Replay", "No hay grabación para guardar.", 3)
        return false
    end

    -- Deep-copy de frames (CFrames son value types en Lua, ok copiar directamente)
    local copy = {}
    for i, f in ipairs(frames) do
        copy[i] = { cf = f.cf, fov = f.fov, t = f.t }
    end

    UCam.Replay.SavedRoutes[slotIndex] = {
        frames   = copy,
        savedAt  = os.time(),
        duration = frames[#frames].t,
        count    = #frames,
    }

    UCam.notify("Replay",
        string.format("Ruta guardada en ranura %d (%d frames / %s)",
            slotIndex, #frames, formatTime(frames[#frames].t)))
    return true
end

function UCam.loadRoute(slotIndex)
    slotIndex = math.clamp(math.floor(slotIndex or 1), 1, MAX_ROUTES)
    local route = UCam.Replay.SavedRoutes[slotIndex]
    if not route then
        UCam.notify("Replay", string.format("Ranura %d vacía.", slotIndex), 3)
        return false
    end

    -- Copiar a frames de trabajo
    table.clear(UCam.Replay.Frames)
    for i, f in ipairs(route.frames) do
        UCam.Replay.Frames[i] = { cf = f.cf, fov = f.fov, t = f.t }
    end

    UCam.Replay.CurrentTime = 0
    UCam.notify("Replay",
        string.format("Ruta %d cargada: %d frames / %s",
            slotIndex, route.count, formatTime(route.duration)))
    return true
end

function UCam.deleteRoute(slotIndex)
    slotIndex = math.clamp(math.floor(slotIndex or 1), 1, MAX_ROUTES)
    if UCam.Replay.SavedRoutes[slotIndex] then
        UCam.Replay.SavedRoutes[slotIndex] = nil
        UCam.notify("Replay", string.format("Ranura %d eliminada.", slotIndex))
        return true
    end
    UCam.notify("Replay", string.format("Ranura %d ya estaba vacía.", slotIndex), 3)
    return false
end

-- ============================================================
-- SERIALIZACIÓN / DESERIALIZACIÓN
-- Formato compacto: cada frame = "x,y,z,lx,ly,lz,rx,ry,rz,fov,t"
-- separados por "|"
-- ============================================================

-- Convierte CFrame a 9 números (pos + look + right vectors)
local function cfToComponents(cf)
    local p  = cf.Position
    local lookVec = cf.LookVector
    local rightVec = cf.RightVector
    return p.X, p.Y, p.Z,
           lookVec.X, lookVec.Y, lookVec.Z,
           rightVec.X, rightVec.Y, rightVec.Z
end

local function componentsToCF(px, py, pz, lx, ly, lz, rx2, ry2, rz2)
    local pos    = Vector3.new(px, py, pz)
    local look   = Vector3.new(lx, ly, lz)
    local right  = Vector3.new(rx2, ry2, rz2)
    local up     = look:Cross(right)
    return CFrame.fromMatrix(pos, right, up, -look)
end

function UCam.serializeRoute(frames)
    frames = frames or UCam.Replay.Frames
    if #frames == 0 then return "" end

    -- Submuestrear si hay demasiados frames (máx 1800 para no saturar)
    local step = math.max(1, math.floor(#frames / 1800))
    local parts = {}

    for i = 1, #frames, step do
        local f = frames[i]
        local px, py, pz, lx, ly, lz, rx, ry, rz = cfToComponents(f.cf)
        table.insert(parts, string.format(
            "%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.1f,%.3f",
            px, py, pz, lx, ly, lz, rx, ry, rz, f.fov, f.t
        ))
    end

    return table.concat(parts, "|")
end

function UCam.deserializeRoute(str)
    if not str or str == "" then return nil end

    if type(str) ~= "string" then return nil end
    if #str > 1000000 then return nil, "string demasiado grande (>1MB)" end

    local MAX_FRAMES = 18000
    local frames = {}

    for entry in str:gmatch("[^|]+") do
        local vals = {}
        local valid = true

        for v in entry:gmatch("[^,]+") do
            local num = tonumber(v)
            if not num then
                valid = false; break
            end
            if math.abs(num) > 1e6 then
                valid = false; break
            end
            table.insert(vals, num)
        end

        if valid and #vals == 11 then
            local bad = false
            for _, v in ipairs(vals) do
                if v ~= v or math.abs(v) == math.huge then bad = true break end
            end
            if not bad then
                local cf = componentsToCF(
                    vals[1], vals[2], vals[3],
                    vals[4], vals[5], vals[6],
                    vals[7], vals[8], vals[9]
                )
                local fov = UCam.clamp(vals[10], 1, 120)
                local frameT = vals[11]
                local frame = { cf = cf, fov = fov, t = frameT }
                table.insert(frames, frame)

                if #frames >= MAX_FRAMES then break end
            end
        end
    end

    if #frames < 2 then return nil end
    return frames
end

-- ============================================================
-- STOP GENERAL
-- ============================================================
function UCam.stopReplay()
    UCam.stopRecording()
    UCam.stopPlayback()
    table.clear(UCam.Replay.Frames)
    UCam.Replay.CurrentTime = 0
end
