-- ============================================================
-- Universal Camera Pro v8 · 55_replay
-- Sistema de grabación y replay de cámara: graba CFrame + FOV
-- cada frame, reproduce con scrubbing, velocidad variable, loop,
-- hasta 3 rutas, marcadores con eventos, ramps de velocidad y
-- compartir web (hasta 3 servicios).
--
-- Dependencias: 00_config, 10_utils, 70_camcore
-- Expone (UCam.*):
--   startRecording, stopRecording,
--   startPlayback, pausePlayback, stopPlayback,
--   seekReplay, setPlaybackSpeed,
--   saveCurrentRoute, loadRoute, deleteRoute,
--   serializeRoute, deserializeRoute,
--   updateReplay, stopReplay,
--   Replay.getFormattedTime,
--   addMarker, removeMarker, clearMarkers, _fireMarker,      <- v8
--   addSpeedRamp, clearSpeedRamps, getPlaybackSpeedAt,       <- v8
--   shareRoute,                                               <- v8
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

-- v8 FIX: forward declaration — checkMarkers se usa dentro de
-- startPlayback() (definido antes). Sin esto la llamada resuelve
-- a un global nil y el playback revienta en cada frame.
local checkMarkers

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

        _recordTimer = _recordTimer + dt
        if _recordTimer < FRAME_INTERVAL then return end
        _recordTimer = _recordTimer - FRAME_INTERVAL

        -- Verificar límite de duración
        local elapsed = tick() - UCam.Replay._recordStartTime
        if elapsed > UCam.Replay.MaxDuration then
            UCam.stopRecording()
            return
        end

        -- Capturar CFrame + FOV de la cámara actual
        local cf  = UCam.camera.CFrame
        local fov = UCam.camera.FieldOfView
        table.insert(UCam.Replay.Frames, {
            cf  = cf,
            fov = fov,
            t   = elapsed,
        })
    end)

    UCam.notify("Replay", string.format("Grabando... (máx %ds)", UCam.Replay.MaxDuration))
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
        UCam.notify("Replay", "No hay grabación. Graba primero.")
        return
    end
    if UCam.Replay.Recording then
        UCam.stopRecording()
    end

    UCam.Replay.Playing = true
    UCam.Replay.Paused  = false
    _playHead = 1

    -- v8: resetear flags de marcadores para la nueva reproducción
    UCam.Replay._markersFiredIdx = {}
    for _, m in ipairs(UCam.Replay.Markers) do m.fired = false end

    -- Entrar en modo cámara scriptable
    UCam.camera.CameraType = Enum.CameraType.Scriptable

    _playConn = UCam.RunService.Heartbeat:Connect(function(dt)
        if not UCam.Replay.Playing or UCam.Replay.Paused then return end

        -- v8: calcular tiempo real para marcadores + rampas
        local prevTime = UCam.Replay.CurrentTime
        local frames = UCam.Replay.Frames
        local n      = #frames

        -- v8: velocidad efectiva — ramp si activo, si no el valor global
        local effSpeed = UCam.Replay.PlaybackSpeed
        if UCam.Replay.SpeedRampEnabled then
            local rampTotal = frames[n] and frames[n].t or 0
            local curT = math.min(prevTime, rampTotal)
            local rampSpeed = UCam.getPlaybackSpeedAt(curT)
            if rampSpeed then effSpeed = rampSpeed end
        end

        -- Avanzar playhead según velocidad y fps grabado
        _playHead = _playHead + (dt * RECORD_FPS * effSpeed)

        -- Actualizar CurrentTime para la UI (en segundos)
        UCam.Replay.CurrentTime = (_playHead - 1) / RECORD_FPS

        -- v8: disparar marcadores cruzados este frame
        checkMarkers(prevTime, UCam.Replay.CurrentTime)

        if _playHead > n then
            if UCam.Replay.Loop then
                _playHead = 1
                UCam.Replay.CurrentTime = 0
                -- Resetear flags de marcadores al loopear
                for _, m in ipairs(UCam.Replay.Markers) do m.fired = false end
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

    UCam.notify("Replay", "Reproduciendo grabación...")
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
-- v8: MARCADORES con eventos
-- Un marcador dispara una acción al cruzarlo (shake, slow, fov...).
-- ============================================================
function UCam.addMarker(timeSecs, label, action, value)
    label  = tostring(label or "Marker")
    action = tostring(action or "none")  -- "shake","slow","fov","speed","none"
    value  = value          -- significats depende del action
    timeSecs = math.max(0, tonumber(timeSecs) or 0)
    table.insert(UCam.Replay.Markers, {
        t = timeSecs, label = label, action = action, val = value, fired = false,
    })
    -- Mantener ordenados por tiempo para búsqueda eficiente
    table.sort(UCam.Replay.Markers, function(a, b) return a.t < b.t end)
    UCam.notify("Replay", ("Marcador '%s' agregado en %s"):format(
        label, formatTime(timeSecs)))
    return true
end

function UCam.removeMarker(index)
    if UCam.Replay.Markers[index] then
        local m = table.remove(UCam.Replay.Markers, index)
        UCam.notify("Replay", ("Marcador '%s' eliminado."):format(m.label))
        return true
    end
    return false
end

function UCam.clearMarkers()
    UCam.Replay.Markers = {}
    UCam.notify("Replay", "Todos los marcadores eliminados.")
end

-- Dispara la acción de un marcador (llamado al cruzarlo durante playback)
local function fireMarkerAction(m)
    if not m then return end
    local v = m.val

    if m.action == "shake" then
        if UCam.triggerShake then
            UCam.triggerShake(type(v) == "string" and v or "Impacto")
            UCam.notify("Replay", ("[%s] Shake: %s"):format(m.label, tostring(v or "Impacto")))
        end
    elseif m.action == "slow" then
        -- v un multiplicador temporal (0.1..1)
        local factor = math.clamp(tonumber(v) or 0.3, 0.05, 1)
        if UCam.toggleBulletTime then
            UCam.toggleBulletTime(true)
            UCam.SlowMo.Intensity = math.floor(factor * 100)
            UCam.notify("Replay", ("[%s] Slow-mo: %.0f%%"):format(m.label, factor * 100))
        end
    elseif m.action == "fov" then
        -- v = pulso de FOV (grados)
        local kick = tonumber(v) or 10
        local orig = UCam.camera.FieldOfView
        UCam.camera.FieldOfView = UCam.clamp(orig + kick, UCam.MIN_FOV, UCam.MAX_FOV)
        task.delay(0.15, function()
            pcall(function() UCam.camera.FieldOfView = orig end)
        end)
        UCam.notify("Replay", ("[%s] FOV pulse %+d°"):format(m.label, kick))
    elseif m.action == "speed" then
        -- v = velocidad absoluta a aplicar desde este punto
        UCam.setPlaybackSpeed(tonumber(v) or 1)
        UCam.notify("Replay", ("[%s] Velocidad → %.2fx"):format(m.label, tonumber(v) or 1))
    end
end

-- Revisar marcadores y disparar los que cruzamos este frame
checkMarkers = function(prevTime, curTime)
    if not UCam.Replay.ShowMarkerHUD then return end
    for _, m in ipairs(UCam.Replay.Markers) do
        if prevTime < m.t and curTime >= m.t and not m.fired then
            m.fired = true
            fireMarkerAction(m)
        end
    end
end

-- ============================================================
-- v8: SPEED RAMPS keyframados
-- Tabla ordenada {t, speed}; interpola linealmente entre puntos.
-- ============================================================
function UCam.addSpeedRamp(timeSecs, speed)
    timeSecs = math.max(0, tonumber(timeSecs) or 0)
    speed    = math.clamp(tonumber(speed) or 1, 0.05, 8)
    table.insert(UCam.Replay.SpeedRamps, { t = timeSecs, speed = speed })
    table.sort(UCam.Replay.SpeedRamps, function(a, b) return a.t < b.t end)
    UCam.Replay.SpeedRampEnabled = true
    UCam.notify("Replay", ("Ramp de velocidad: %s → %.2fx"):format(
        formatTime(timeSecs), speed))
    return true
end

function UCam.clearSpeedRamps()
    UCam.Replay.SpeedRamps = {}
    UCam.Replay.SpeedRampEnabled = false
    UCam.notify("Replay", "Speed ramps eliminados.")
end

-- Interpola la velocidad en un instante t (0 si no hay ramps)
function UCam.getPlaybackSpeedAt(t)
    local ramps = UCam.Replay.SpeedRamps
    if #ramps == 0 then return nil end

    -- Antes del primer punto: usar su velocidad
    if t <= ramps[1].t then return ramps[1].speed end
    -- Después del último: usar su velocidad
    if t >= ramps[#ramps].t then return ramps[#ramps].speed end

    -- Buscar intervalo [ramps[i], ramps[i+1]] que contiene t
    for i = 1, #ramps - 1 do
        if t >= ramps[i].t and t <= ramps[i+1].t then
            local a, b = ramps[i], ramps[i+1]
            local span = b.t - a.t
            if span < 1e-6 then return b.speed end
            local frac = (t - a.t) / span
            return a.speed + (b.speed - a.speed) * frac
        end
    end
    return nil
end

-- ============================================================
-- v8: COMPARTIR RUTA (pegar en el navegador / apps nativas)
-- v8.1 FIX (crítico #6): la firma de HttpGet usada no existe.
-- Ahora usa request/http_request estándar con fallback a HttpGet.
-- ============================================================
local function httpPost(url, body)
    local HttpService = UCam.HttpService or game:GetService("HttpService")
    -- Preferir request() (Synapse/Solara/Micup/Fluxus moderno)
    if typeof(request) == "function" then
        local ok, res = pcall(request, {
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
            Body = body,
        })
        if ok and res then return res.StatusCode, res.Body end
    end
    -- Fallback: HttpService:PostAsync
    local ok, res = pcall(function()
        return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationUrlEncoded)
    end)
    if ok then return 200, res end
    return nil, nil
end

function UCam.shareRoute()
    if #UCam.Replay.Frames < 2 then
        UCam.notify("Replay", "No hay grabación activa para compartir.")
        return nil, "sin grabación"
    end

    local str = UCam.serializeRoute()
    if str == "" then return nil, "error serializando" end

    -- Servicios que NO requieren API key
    local services = {
        { name = "hastebin.rs",  url = "https://hastebin.rs/documents", body = str,
          parser = function(r) return r and ("https://hastebin.rs/" .. (r:match('"key"%s*:%s*"([^"]+)"') or "")) end },
    }

    for _, svc in ipairs(services) do
        local code, res = httpPost(svc.url, svc.body)
        if code and res then
            local url = svc.parser(res)
            if url and url ~= "" then
                UCam.notify("Replay", "Ruta subida a " .. svc.name .. ":\n" .. url)
                return url
            end
        end
    end

    -- Fallback: copiar a portapapeles
    local okC = pcall(function() setclipboard(str) end)
    if okC then
        UCam.notify("Replay", "Los servicios web no respondieron. String copiado al portapapeles.")
    else
        UCam.notify("Replay", "No se pudo compartir. String impreso en consola.")
        print("[UCam Replay]\n" .. str)
    end
    return nil
end

-- ============================================================
-- RUTAS GUARDADAS (hasta MAX_ROUTES)
-- ============================================================
function UCam.saveCurrentRoute(slotIndex)
    slotIndex = math.clamp(math.floor(slotIndex or 1), 1, MAX_ROUTES)
    local frames = UCam.Replay.Frames
    if #frames < 2 then
        UCam.notify("Replay", "No hay grabación para guardar.")
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
        -- v8: guardar marcadores y ramps junto con la ruta
        markers  = UCam.Replay.Markers,
        ramps    = UCam.Replay.SpeedRamps,
        rampEnabled = UCam.Replay.SpeedRampEnabled,
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
        UCam.notify("Replay", string.format("Ranura %d vacía.", slotIndex))
        return false
    end

    -- Copiar a frames de trabajo
    table.clear(UCam.Replay.Frames)
    for i, f in ipairs(route.frames) do
        UCam.Replay.Frames[i] = { cf = f.cf, fov = f.fov, t = f.t }
    end

    -- v8: restaurar marcadores y ramps almacenados con la ruta
    if route.markers then
        UCam.Replay.Markers = {}
        for _, m in ipairs(route.markers) do
            table.insert(UCam.Replay.Markers, { t=m.t, label=m.label, action=m.action, val=m.val, fired=false })
        end
    end
    if route.ramps then
        UCam.Replay.SpeedRamps = {}
        for _, r in ipairs(route.ramps) do
            table.insert(UCam.Replay.SpeedRamps, { t=r.t, speed=r.speed })
        end
        UCam.Replay.SpeedRampEnabled = route.rampEnabled or (#UCam.Replay.SpeedRamps > 0)
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
    UCam.notify("Replay", string.format("Ranura %d ya estaba vacía.", slotIndex))
    return false
end

-- ============================================================
-- SERIALIZACIÓN / DESERIALIZACIÓN
-- Formato compacto: cada frame = "x,y,z,rx,ry,rz,rw,fov"
-- separados por "|", todo comprimido en Base64 simple
-- ============================================================

-- Convierte CFrame a 7 números (pos + quaternion)
local function cfToComponents(cf)
    local p  = cf.Position
    -- Roblox CFrame a quaternion via LookVector + RightVector + UpVector matrix
    -- Usamos los 9 componentes de la matriz de rotación
    local rx, ry, rz,
          ux, uy, uz,
          bx, by, bz = cf:GetComponents()
    -- GetComponents devuelve: x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22
    -- Formato simplificado: solo posición + ángulos euler (suficiente para replay)
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
    -- v8.1 FIX: up = look:Cross(right) coincide con 60_director.nineToCF.
    -- Antes era "right:Cross(look) * -1", que daba el up invertido y
    -- provocaba un roll de 180° al compartir rutas entre Replay y Director.
    local up     = look:Cross(right)
    return CFrame.fromMatrix(pos, right, up, -look)
end

function UCam.serializeRoute(frames)
    frames = frames or UCam.Replay.Frames
    if #frames == 0 then return "" end

    -- Submuestrear si hay demasiados frames (máx 1800 para no saturar portapapeles)
    local step = math.max(1, math.floor(#frames / 1800))
    local parts = {}

    for i = 1, #frames, step do
        local f = frames[i]
        local px, py, pz, lx, ly, lz, rx, ry, rz = cfToComponents(f.cf)
        -- v8.1 FIX: incluir el timestamp real del frame submuestreado para
        -- poder compensar el roundtrip de duración en deserializeRoute.
        table.insert(parts, string.format(
            "%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.1f,%.3f",
            px, py, pz, lx, ly, lz, rx, ry, rz, f.fov, f.t or ((i - 1) * FRAME_INTERVAL)
        ))
    end

    return table.concat(parts, "|")
end

function UCam.deserializeRoute(str)
    if not str or str == "" then return nil end

    -- v8: validación dura de seguridad frente a strings maliciosos o gigantes
    if type(str) ~= "string" then return nil end
    if #str > 1000000 then return nil, "string demasiado grande (>1MB)" end

    -- Limitar número de frames para no explotar memoria (60fps × 5min = 18000)
    local MAX_FRAMES = 18000

    local frames = {}
    local t = 0
    local lastIndex = 0

    for entry in str:gmatch("[^|]+") do
        local vals = {}
        local valid = true

        -- Parsear cada valor, con límites numéricos
        for v in entry:gmatch("[^,]+") do
            local num = tonumber(v)
            if not num then
                valid = false; break
            end
            -- Rango razonable para posiciones/vectores (mundo de Roblox ±100k studs)
            if math.abs(num) > 1e6 then
                valid = false; break
            end
            table.insert(vals, num)
        end

        if valid and (#vals == 10 or #vals == 11) then
            -- Verificar que el quaternion/vectores no sean NaN o Inf
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
                -- FOV razonable
                local fov = UCam.clamp(vals[10], 1, 120)
                -- v8.1 FIX: compensar el submuestreo de duración. Ahora cada
                -- frame grabado lleva su timestamp real (11º valor). Si está
                -- presente usarlo; si no (formato viejo) interpolar.
                local frameT
                if #vals == 11 then
                    frameT = vals[11]
                end
                local cf_out = cf
                local frame = { cf = cf_out, fov = fov, t = frameT or t }
                table.insert(frames, frame)
                if not frameT then
                    t = t + FRAME_INTERVAL
                else
                    -- Mantener t para las siguientes entradas sin timestamp
                    t = frameT + FRAME_INTERVAL
                end

                -- Límite de frames
                if #frames >= MAX_FRAMES then break end
            end
        end
        lastIndex = lastIndex + 1
        -- Seguridad extra: no procesar más de MAX_FRAMES×2 entradas
        if lastIndex >= MAX_FRAMES * 2 then break end
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
