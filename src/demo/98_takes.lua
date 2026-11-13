-- ============================================================
-- Universal Camera Pro v13.7 · demo/98_takes
-- Tomas sobre un demo: cada pasada guarda SU recorrido de camara
-- (CFrame + FOV por muestra) y se reproduce encima del demo.
-- Asi el mismo material se filma desde varios angulos sin volver
-- a grabar a los actores, como la camara libre de un demo de L4D2.
--
-- La camara se cede por un solo punto: UCam.DemoCamera, invocado al
-- inicio de 70_camcore.updateCamera. Mientras hay una toma, devuelve
-- true y el nucleo no escribe la camara ese frame.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua,
--               camera/70_camcore.lua, demo/94_player.lua.
-- Expone (UCam.*):
--   demoTakeStart, demoTakeStopRecording, demoTakePlay,
--   demoTakeStop, demoTakeDelete, demoTakeOptions,
--   demoSequenceStart, demoSequenceStop, demoTakesSummary.
-- ============================================================
local UCam = _G.UCam
local D = UCam.Demo
local T = UCam.DemoTakes

local MAX_ROUTE_FRAMES = 4000
local IDENTITY = CFrame.new()

-- ============================================================
-- HELPERS
-- ============================================================

local function cfFrom(values)
    return CFrame.new(
        values[1], values[2], values[3],
        values[4], values[5], values[6],
        values[7], values[8], values[9],
        values[10], values[11], values[12]
    )
end

local function cfTo(values)
    return { values:GetComponents() }
end

local function currentTakes()
    return (D.Current and D.Current.takes) or T.Items or {}
end

local function ensureFreeCam()
    if UCam.freeCamEnabled then
        UCam.camMode = "Libre"
        return true
    end
    if UCam.toggleFreeCam then
        UCam.camMode = "Libre"
        local ok = pcall(UCam.toggleFreeCam)
        return ok and UCam.freeCamEnabled == true
    end
    return false
end

local function catmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    local pos = (
        p0.Position * (-t3 + 2 * t2 - t) +
        p1.Position * (3 * t3 - 5 * t2 + 2) +
        p2.Position * (-3 * t3 + 4 * t2 + t) +
        p3.Position * (t3 - t2)
    ) * 0.5
    local rot = p1:Lerp(p2, t)
    return CFrame.new(pos) * (rot - rot.Position)
end

--- Muestrea el recorrido de una toma en t segundos (0..duration).
local function sampleTake(take, t)
    local route = take.route
    local n = route and #route or 0
    if n == 0 then return nil, nil end
    if n == 1 then return cfFrom(route[1].cf), route[1].fov end

    local duration = math.max(tonumber(take.duration) or 0.001, 0.001)
    local f = (math.clamp(t, 0, duration) / duration) * (n - 1)
    local index = math.floor(f) + 1
    local alpha
    if index >= n then
        -- En t = duration hay que devolver el ULTIMO keyframe, no el
        -- penultimo con alpha 0.
        index = n - 1
        alpha = 1
    else
        alpha = f - math.floor(f)
    end

    local ease = (UCam.getEasingFn and UCam.getEasingFn(take.easing or T.Easing)) or function(v) return v end
    alpha = ease(alpha)

    local a, b = route[index], route[index + 1]
    local cfA, cfB = cfFrom(a.cf), cfFrom(b.cf)
    local cf
    if n >= 3 then
        local p0 = cfFrom(route[math.max(1, index - 1)].cf)
        local p3 = cfFrom(route[math.min(n, index + 2)].cf)
        cf = catmullRom(p0, cfA, cfB, p3, alpha)
    else
        cf = cfA:Lerp(cfB, alpha)
    end

    local fovA = tonumber(a.fov) or 70
    local fovB = tonumber(b.fov) or fovA
    return cf, fovA + (fovB - fovA) * alpha
end

local function applyCamera(cf, fov)
    UCam.camMode = "Libre"
    UCam.camCFrame = cf
    UCam.camera.CameraType = Enum.CameraType.Scriptable
    UCam.camera.CameraSubject = nil
    UCam.camera.CFrame = cf
    if fov then UCam.camera.FieldOfView = fov end
end

local function stopRecordConnection()
    if T._recordConn then
        UCam.untrackConnection(T._recordConn)
        T._recordConn = nil
    end
end

-- ============================================================
-- MODO RENDER (ocultar UI, letterbox, toma limpia)
-- ============================================================

local function applyRenderMode(on)
    if on and T._renderActive then return end
    if on then
        T._renderActive = true
        T._savedUI = true
        if T.HideUI ~= false and UCam.UI then
            if UCam.UI.isVisible then
                local ok, visible = pcall(UCam.UI.isVisible)
                if ok then T._savedUI = visible == true end
            end
            if UCam.UI.setVisible then pcall(UCam.UI.setVisible, false) end
        end
        T._savedLetterbox = UCam.Letterbox.Enabled == true
        if T.Letterbox then
            UCam.Letterbox.Enabled = true
            if UCam.applyLetterbox then pcall(UCam.applyLetterbox) end
        end
        if UCam.setCleanShot then pcall(UCam.setCleanShot, true) end
    else
        if not T._renderActive then return end
        T._renderActive = false
        if T.HideUI ~= false and UCam.UI and UCam.UI.setVisible then
            pcall(UCam.UI.setVisible, T._savedUI ~= false)
        end
        if T._savedLetterbox ~= true then
            UCam.Letterbox.Enabled = false
            if UCam.destroyLetterbox then pcall(UCam.destroyLetterbox) end
        else
            UCam.Letterbox.Enabled = true
            if UCam.applyLetterbox then pcall(UCam.applyLetterbox) end
        end
        if UCam.setCleanShot then pcall(UCam.setCleanShot, false) end
    end
end

-- ============================================================
-- GRABACION DE UNA TOMA
-- ============================================================

function UCam.demoTakeStart(name, duration)
    if T._recording then
        return false, "Ya se esta grabando una toma."
    end
    if not D.Current then
        return false, "Carga o graba un demo primero."
    end
    if UCam.demoSequenceStop then UCam.demoSequenceStop() end
    if UCam.demoTakeStop then UCam.demoTakeStop() end

    if not ensureFreeCam() then
        UCam.notify("Tomas", "Activa la camara libre para grabar la toma.", 4)
        return false
    end

    duration = math.clamp(tonumber(duration) or tonumber(T.Duration) or 6, 1, 60)
    T._recording = true
    T._elapsed = 0
    T._takeIn = math.clamp(D.Playhead or 0, 0, math.max(D.Duration or 0, 0))
    T._takeDuration = duration
    T._route = {
        { t = 0, cf = cfTo(UCam.camera.CFrame), fov = UCam.camera.FieldOfView },
    }
    T.Playing = false
    T.SequencePlaying = false

    -- El material se queda quieto y la toma lo scrubbea: asi la
    -- duracion de la toma manda y no se desincroniza con el demo.
    -- demoSeek reconstruye los fantasmas si se habia detenido el demo y
    -- oculta a los jugadores vivos para que no salgan en el plano.
    UCam.demoPause()
    UCam.demoSeek(T._takeIn)

    local function finish()
        if not T._recording then return end
        stopRecordConnection()
        T._recording = false

        local route = T._route
        if #route < 2 then
            UCam.notify("Tomas", "La toma quedo vacia; mueve la camara e intentalo otra vez.", 4)
            return
        end

        local take = {
            name = tostring(name or ""):gsub("[%c]", " "):sub(1, 40),
            tIn = T._takeIn,
            tOut = T._takeIn + T._takeDuration,
            duration = T._takeDuration,
            easing = T.Easing,
            route = route,
            createdAt = os.time(),
        }
        if take.name == "" then
            take.name = ("Toma %02d"):format(#currentTakes() + 1)
        end

        local takes = currentTakes()
        table.insert(takes, take)
        T.Items = takes
        T.Selected = #takes
        if UCam.refreshReplayTakes then pcall(UCam.refreshReplayTakes) end
        UCam.notify("Tomas",
            ("%s grabada: %.1fs desde %.1fs (%d muestras)."):format(
                take.name, take.duration, take.tIn, #route),
            5)
    end
    T._finishRecording = finish

    T._recordConn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function(dt)
            if not T._recording then return end
            T._elapsed = T._elapsed + math.clamp(tonumber(dt) or 0, 0, 0.5)
            -- epsilon: 0.05 * 10 en coma flotante da 0.499999...
            if T._elapsed + 1e-4 >= T._takeDuration then
                finish()
                return
            end
            UCam.demoApplyAt(T._takeIn + T._elapsed)
            if #T._route < MAX_ROUTE_FRAMES then
                T._route[#T._route + 1] = {
                    t = T._elapsed,
                    cf = cfTo(UCam.camera.CFrame),
                    fov = UCam.camera.FieldOfView,
                }
            end
        end),
        "DemoTakes:record"
    )

    UCam.notify("Tomas",
        ("Grabando pasada de camara (%.1fs). Vuela con la camara libre."):format(duration),
        4)
    return true
end

function UCam.demoTakeStopRecording()
    if not T._recording then return false end
    if T._finishRecording then
        T._finishRecording()
    else
        stopRecordConnection()
        T._recording = false
    end
    return true
end

-- ============================================================
-- REPRODUCCION DE TOMAS
-- ============================================================

local function clearCameraHook()
    UCam.DemoCamera = nil
end

function UCam.demoTakeStop()
    -- Tambien cancela una grabacion a medias: si se pide detener las
    -- tomas, no tiene sentido seguir muestreando la camara.
    if T._recording then
        stopRecordConnection()
        T._recording = false
        T._route = {}
        T._finishRecording = nil
    end
    T.Playing = false
    T._playingTake = nil
    clearCameraHook()
    -- Una toma individual tambien es un plano: oculta UI, letterbox y
    -- Clean Shot igual que la secuencia, y restaura al detenerla.
    if not T.SequencePlaying then applyRenderMode(false) end
end

function UCam.demoTakeOptions()
    local takes = currentTakes()
    local options = {}
    for i, take in ipairs(takes) do
        options[i] = ("%02d · %s (%.1fs)"):format(i, take.name or "Toma", take.duration or 0)
    end
    if #options == 0 then options[1] = "(sin tomas)" end
    return options
end

local function takeIndexFromKey(key)
    local takes = currentTakes()
    local index = tonumber(tostring(key or ""):match("^(%d+)"))
    if index and takes[index] then return index end
    for i, take in ipairs(takes) do
        if take.name == key then return i end
    end
    return nil
end

function UCam.demoTakePlay(key)
    if T._recording then
        return false, "Termina la toma que estas grabando."
    end
    local takes = currentTakes()
    local index = type(key) == "number" and key or takeIndexFromKey(key)
    if not index or not takes[index] then
        return false, "Selecciona una toma."
    end
    if not D.Current then return false, "No hay demo cargado." end
    if not ensureFreeCam() then
        return false, "Activa la camara libre."
    end

    if UCam.demoSequenceStop then UCam.demoSequenceStop() end
    UCam.demoPause()

    local take = takes[index]
    T.Selected = index
    T._playingTake = take
    T.Playing = true
    T._elapsed = 0
    applyRenderMode(true)
    UCam.demoSeek(take.tIn)

    clearCameraHook()
    UCam.DemoCamera = function(dt)
        if not T.Playing or T._playingTake ~= take then return false end
        T._elapsed = T._elapsed + math.clamp(tonumber(dt) or 0, 0, 0.5)
        local t = math.min(T._elapsed, take.duration)
        UCam.demoApplyAt(take.tIn + t)
        local cf, fov = sampleTake(take, t)
        if cf then applyCamera(cf, fov) end
        if T._elapsed + 1e-4 >= take.duration then
            T.Playing = false
            T._playingTake = nil
            clearCameraHook()
            applyRenderMode(false)
            UCam.demoPause()
        end
        return true
    end

    UCam.notify("Tomas", ("Reproduciendo %s sobre el demo."):format(take.name or "toma"), 4)
    return true
end

function UCam.demoTakeDelete(key)
    local takes = currentTakes()
    local index = type(key) == "number" and key or takeIndexFromKey(key)
    if not index or not takes[index] then return false, "Toma no valida." end
    if T.SequencePlaying then UCam.demoSequenceStop() end
    if T._playingTake == takes[index] then UCam.demoTakeStop() end
    table.remove(takes, index)
    T.Items = takes
    if T.Selected > #takes then T.Selected = #takes end
    UCam.notify("Tomas", "Toma eliminada.", 3)
    return true
end

-- ============================================================
-- SECUENCIA
-- ============================================================

function UCam.demoSequenceStop()
    if UCam.demoTakeStop then UCam.demoTakeStop() end
    T.SequencePlaying = false
    T.Playing = false
    T._playingTake = nil
    T._seqQueue = {}
    T._seqIndex = 0
    T._seqElapsed = 0
    clearCameraHook()
    applyRenderMode(false)
    UCam.demoPause()
end

function UCam.demoSequenceStart(startKey)
    if T._recording then
        return false, "Termina la toma que estas grabando."
    end
    local takes = currentTakes()
    if #takes == 0 then
        return false, "No hay tomas para la secuencia."
    end
    if not D.Current then return false, "No hay demo cargado." end
    if not ensureFreeCam() then
        return false, "Activa la camara libre."
    end

    if UCam.demoTakeStop then UCam.demoTakeStop() end
    UCam.demoPause()

    local startIndex = type(startKey) == "number" and startKey or takeIndexFromKey(startKey) or 1
    startIndex = math.clamp(startIndex, 1, #takes)

    local queue = {}
    for i = startIndex, #takes do queue[#queue + 1] = takes[i] end
    for i = 1, startIndex - 1 do queue[#queue + 1] = takes[i] end

    T._seqQueue = queue
    T._seqIndex = 1
    T._seqElapsed = 0
    T.SequencePlaying = true
    T.Playing = true
    applyRenderMode(true)
    UCam.demoSeek(queue[1].tIn)

    local function currentTake()
        return T._seqQueue[T._seqIndex]
    end

    clearCameraHook()
    UCam.DemoCamera = function(dt)
        if not T.SequencePlaying then return false end
        local take = currentTake()
        if not take then
            UCam.demoSequenceStop()
            return true
        end

        T._seqElapsed = T._seqElapsed + math.clamp(tonumber(dt) or 0, 0, 0.5)
        local t = math.min(T._seqElapsed, take.duration)
        UCam.demoApplyAt(take.tIn + t)
        local cf, fov = sampleTake(take, t)
        if cf then applyCamera(cf, fov) end

        if T._seqElapsed + 1e-4 >= take.duration then
            T._seqIndex = T._seqIndex + 1
            T._seqElapsed = 0
            if T._seqIndex > #T._seqQueue then
                UCam.demoSequenceStop()
                return true
            end
            local nextTake = currentTake()
            if nextTake then
                UCam.demoApplyAt(nextTake.tIn)
                local nextCF, nextFOV = sampleTake(nextTake, 0)
                if nextCF then applyCamera(nextCF, nextFOV) end
            end
        end
        return true
    end

    local total = 0
    for _, take in ipairs(queue) do total = total + (take.duration or 0) end
    UCam.notify("Tomas",
        ("Secuencia: %d tomas, %.1fs en total."):format(#queue, total),
        6)
    return true
end

function UCam.demoTakesSummary()
    local takes = currentTakes()
    if #takes == 0 then return "Sin tomas." end
    local lines = {}
    for i, take in ipairs(takes) do
        lines[i] = ("%02d · %s · %.1fs (demo %.1f-%.1fs)"):format(
            i, take.name or "Toma", take.duration or 0, take.tIn or 0, take.tOut or 0)
    end
    return table.concat(lines, "\n")
end
