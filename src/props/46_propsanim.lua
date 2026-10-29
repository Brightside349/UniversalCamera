-- ============================================================
-- Universal Camera Pro v12.5 · props/46_propsanim
-- Animador de props por keyframes: como una línea de tiempo de video.
--
-- - Cada keyframe guarda la CFrame de los props capturados en un
--   tiempo concreto.
-- - "Todos" captura el conjunto; "Prop seleccionado" captura solo uno,
--   de modo que cada prop puede tener su propio ritmo y duración.
-- - La reproducción interpola por prop entre sus keyframes, así se
--   puede animar en conjunto o de forma independiente.
--
-- Dependencias: props/45_props.lua (get/setPropCFrame).
-- ============================================================
local UCam = _G.UCam
local A = UCam.PropAnim

-- ============================================================
-- HELPERS
-- ============================================================

local function sortedKeys()
    table.sort(A.Keyframes, function(a, b) return (a.t or 0) < (b.t or 0) end)
    return A.Keyframes
end

local function targetsForScope()
    local list = {}
    if A.Scope == "Todos" then
        for i = 1, #UCam.Props.Items do list[#list + 1] = i end
    else
        local sel = UCam.Props.Selected
        if sel and sel > 0 then list[1] = sel end
    end
    return list
end

local function stopConnection()
    if A._conn then
        pcall(function() A._conn:Disconnect() end)
        A._conn = nil
    end
end

-- ============================================================
-- CAPTURA DE KEYFRAMES
-- ============================================================

--- Guarda un keyframe en el tiempo indicado (o en el playhead).
function UCam.propAnimCapture(time)
    local targets = targetsForScope()
    if #targets == 0 then
        return false, "No hay props para animar (o no hay prop seleccionado)."
    end

    local poses = {}
    for _, index in ipairs(targets) do
        local cf = UCam.getPropCFrame(index)
        if cf then poses[index] = cf end
    end
    if next(poses) == nil then
        return false, "No se pudo leer la posición de los props."
    end

    local t = tonumber(time) or A.Playhead or 0
    t = UCam.clamp(t, 0, A.Duration or 6)

    table.insert(A.Keyframes, { t = t, poses = poses })
    sortedKeys()
    A.Playhead = t
    return true, ("Keyframe en %.2fs (%d prop%s)."):format(
        t, #targets, #targets == 1 and "" or "s")
end

--- Elimina el último keyframe guardado.
function UCam.propAnimRemoveLast()
    if #A.Keyframes == 0 then return false, "No hay keyframes." end
    table.remove(A.Keyframes)
    return true, "Último keyframe eliminado."
end

--- Borra la línea de tiempo completa.
function UCam.propAnimClear()
    UCam.propAnimStop()
    table.clear(A.Keyframes)
    A.Playhead = 0
    return true, "Línea de tiempo vacía."
end

--- Lista legible de keyframes (para el botón de diagnóstico).
function UCam.propAnimList()
    local lines = {}
    for i, k in ipairs(sortedKeys()) do
        local n = 0
        for _ in pairs(k.poses) do n = n + 1 end
        lines[i] = string.format("%02d · %.2fs · %d prop%s", i, k.t or 0, n, n == 1 and "" or "s")
    end
    return lines
end

-- ============================================================
-- REPRODUCCIÓN
-- ============================================================

--- Aplica el estado de la animación en un tiempo concreto (scrub).
function UCam.propAnimApplyAt(time)
    if #A.Keyframes == 0 then return end
    local t = UCam.clamp(tonumber(time) or 0, 0, A.Duration or 6)
    local easeFn = UCam.getEasingFn and UCam.getEasingFn(A.Easing) or nil

    for propIndex = 1, #UCam.Props.Items do
        local prev, nxt
        for _, k in ipairs(A.Keyframes) do
            local pose = k.poses[propIndex]
            if pose then
                if k.t <= t then
                    prev = k
                elseif not nxt then
                    nxt = k
                end
            end
        end

        if prev then
            local pose = prev.poses[propIndex]
            if nxt then
                local span = (nxt.t or 0) - (prev.t or 0)
                local alpha = span > 0 and ((t - prev.t) / span) or 0
                alpha = UCam.clamp(alpha, 0, 1)
                local eased = easeFn and easeFn(alpha) or alpha
                pose = pose:Lerp(nxt.poses[propIndex], eased)
            end
            UCam.setPropCFrame(propIndex, pose, false)
        end
    end
end

--- Previsualiza un tiempo sin reproducir.
function UCam.propAnimPreview(time)
    A.Playhead = UCam.clamp(tonumber(time) or 0, 0, A.Duration or 6)
    UCam.propAnimApplyAt(A.Playhead)
end

--- Reproduce la línea de tiempo (loop opcional).
function UCam.propAnimPlay()
    if #A.Keyframes < 2 then
        return false, "Necesitas al menos 2 keyframes."
    end
    stopConnection()
    A.Playing = true
    A.StartTime = os.clock()
    A.Playhead = 0

    A._conn = UCam.RunService.Heartbeat:Connect(function()
        if not A.Playing then return end
        local elapsed = os.clock() - A.StartTime
        local duration = math.max(A.Duration or 6, 0.1)

        if elapsed >= duration then
            if A.Loop then
                A.StartTime = os.clock()
                elapsed = 0
            else
                UCam.propAnimApplyAt(duration)
                A.Playhead = duration
                UCam.propAnimStop(true)
                return
            end
        end

        A.Playhead = elapsed
        UCam.propAnimApplyAt(elapsed)
    end)

    UCam.trackConnection(A._conn, "PropAnim:play")
    return true, "Reproduciendo animación."
end

--- Detiene la reproducción (conserva la pose actual).
function UCam.propAnimStop(silent)
    stopConnection()
    A.Playing = false
    if not silent then A.Playhead = 0 end
    return true
end

--- Detiene y devuelve todos los props a su pose del primer keyframe.
function UCam.propAnimReset()
    UCam.propAnimStop()
    if #A.Keyframes > 0 then
        local first = sortedKeys()[1]
        for propIndex, pose in pairs(first.poses) do
            UCam.setPropCFrame(propIndex, pose, true)
        end
    end
    A.Playhead = 0
    return true, "Props devueltos al inicio."
end
