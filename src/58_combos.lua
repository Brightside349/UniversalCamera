-- ============================================================
-- Universal Camera Pro v8 · 58_combos
-- Combos de cámara: secuencias automáticas de modos.
-- Ej. Orbita (4s) → CrashZoom (2s) → Slow-mo (1s) → ...
--
-- No usa KeyframeSequence (solo lógica Lua). Persistencia incluida.
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   Combos (estado), startCombo, stopCombo, addComboStep,
--   removeComboStep, clearComboSteps,
--   saveCombo, loadCombo, deleteCombo, listCombos,
--   exportCombo, importCombo, stopCombos
-- ============================================================
local UCam = _G.UCam
local HttpService = game:GetService("HttpService")

local MIN_STEP_DURATION = 0.1     -- seg
local MAX_STEP_DURATION = 300     -- 5 min por paso

-- ============================================================
-- HELPERS
-- ============================================================
local function isValidMode(m)
    for _, v in ipairs(UCam.CamModes) do
        if v == m then return true end
    end
    return false
end

local function resetComboPlayback()
    UCam.Combos.Playing     = false
    UCam.Combos.CurrentStep = 0
    UCam.Combos.StepStartAt = 0
    -- v8 FIX: NO borrar Steps aquí — detener la reproducción no debe
    -- destruir la secuencia. Solo clearComboSteps() la limpia.

    if UCam.Combos._conn then
        pcall(function() UCam.Combos._conn:Disconnect() end)
        UCam.Combos._conn = nil
    end
end

-- ============================================================
-- REPRODUCCIÓN
-- ============================================================
local function beginStep(idx, steps, startTime)
    UCam.Combos.CurrentStep = idx
    UCam.Combos.StepStartAt = startTime
    local step = steps[idx]

    if step.camMode and isValidMode(step.camMode) then
        UCam.camMode = step.camMode
        if UCam.CamModes and UCam.notify then
            UCam.notify("Combo", ("Step %d → modo '%s'"):format(idx, step.camMode))
        end
    end

    -- Extras opcionales
    if type(step.extra) == "table" then
        if step.extra.slowmo then
            UCam.SlowMo.BulletTime = true
            UCam.SlowMo.Intensity = math.clamp(tonumber(step.extra.slowmo) or 50, 1, 100)
        end
        if step.extra.fov then
            UCam.camera.FieldOfView = UCam.clamp(tonumber(step.extra.fov) or 70, 1, 120)
        end
        if step.extra.shake and UCam.triggerShake then
            UCam.triggerShake(step.extra.shake)
        end
        if step.extra.filter then
            UCam.currentFilterIndex = math.clamp(tonumber(step.extra.filter) or 1, 1, #UCam.Filters)
            if UCam.applyFilter then pcall(UCam.applyFilter, UCam.currentFilterIndex) end
        end
        if step.extra.notify then
            UCam.notify("Combo", tostring(step.extra.notify))
        end
    end
end

function UCam.startCombo()
    if UCam.Combos.Playing then return end
    if #UCam.Combos.Steps == 0 then
        UCam.notify("Combos", "No hay steps definidos. Añade algunos primero.")
        return false
    end

    UCam.Combos.Playing = true
    UCam.Combos.CurrentStep = 0
    UCam.Combos.StepStartAt = tick()

    -- Iniciar paso 1
    beginStep(1, UCam.Combos.Steps, UCam.Combos.StepStartAt)

    UCam.Combos._conn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function()
            if not UCam.Combos.Playing then return end

            local idx   = UCam.Combos.CurrentStep
            local steps = UCam.Combos.Steps
            local step  = steps[idx]
            if not step then
                if UCam.Combos.Loop then
                    UCam.Combos.CurrentStep = 0
                    UCam.Combos.StepStartAt = tick()
                    beginStep(1, steps, UCam.Combos.StepStartAt)
                    return
                else
                    UCam.stopCombo()
                    return
                end
            end

            local elapsed = tick() - UCam.Combos.StepStartAt
            if elapsed >= (step.duration or 1) then
                -- Siguiente paso
                local nextIdx = idx + 1
                if nextIdx > #steps then
                    if UCam.Combos.Loop then
                        UCam.Combos.CurrentStep = 0
                        UCam.Combos.StepStartAt = tick()
                        beginStep(1, steps, UCam.Combos.StepStartAt)
                    else
                        UCam.stopCombo()
                    end
                else
                    beginStep(nextIdx, steps, UCam.Combos.StepStartAt + (step.duration or 1))
                end
            end
        end),
        "Combos:Heartbeat"
    )

    UCam.notify("Combos", ("Reproduciendo combo (%d pasos)."):format(#UCam.Combos.Steps))
    return true
end

function UCam.stopCombo()
    if not UCam.Combos.Playing then return end
    resetComboPlayback()
    UCam.notify("Combos", "Combo detenido.")
end

-- ============================================================
-- EDITAR STEPS
-- ============================================================
function UCam.addComboStep(camMode, duration, extra)
    if not isValidMode(camMode) then
        UCam.notify("Combos", ("Modo inválido: %s"):format(tostring(camMode)))
        return false
    end
    local d = math.clamp(tonumber(duration) or 1, MIN_STEP_DURATION, MAX_STEP_DURATION)
    table.insert(UCam.Combos.Steps, {
        camMode  = camMode,
        duration = d,
        extra    = (type(extra) == "table") and extra or nil,
    })
    UCam.notify("Combos", ("Paso %d añadido: '%s' × %.2fs"):format(
        #UCam.Combos.Steps, camMode, d))
    return true
end

function UCam.removeComboStep(idx)
    if UCam.Combos.Playing then
        UCam.notify("Combos", "Detén el combo antes de editar.")
        return false
    end
    if not UCam.Combos.Steps[idx] then
        UCam.notify("Combos", ("Step %d no existe."):format(idx))
        return false
    end
    table.remove(UCam.Combos.Steps, idx)
    UCam.notify("Combos", ("Step %d eliminado. Quedan %d."):format(idx, #UCam.Combos.Steps))
    return true
end

function UCam.clearComboSteps()
    UCam.Combos.Steps = {}
    UCam.Combos.CurrentStep = 0
    UCam.Combos.StepStartAt = 0
    UCam.notify("Combos", "Steps eliminados.")
end

-- ============================================================
-- GUARDAR / CARGAR / ELIMINAR combos (por nombre)
-- ============================================================
function UCam.saveCombo(name)
    name = tostring(name or "Combo")
    if #UCam.Combos.Steps == 0 then
        UCam.notify("Combos", "No hay steps para guardar.")
        return false
    end
    -- Deep copy para que cambiar los steps no afecte al guardado
    local copy = {}
    for i, s in ipairs(UCam.Combos.Steps) do
        copy[i] = { camMode=s.camMode, duration=s.duration, extra=s.extra }
    end
    UCam.Combos.SavedCombos[name] = {
        steps   = copy,
        savedAt = os.time(),
    }
    UCam.notify("Combos", ("Combo '%s' guardado (%d pasos)."):format(name, #copy))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.loadCombo(name)
    local c = UCam.Combos.SavedCombos[name]
    if not c then
        UCam.notify("Combos", ("Combo '%s' no encontrado."):format(name))
        return false
    end
    UCam.stopCombo() -- asegurarse de que no esté reproduciendo
    table.clear(UCam.Combos.Steps)
    for i, s in ipairs(c.steps) do
        UCam.Combos.Steps[i] = { camMode=s.camMode, duration=s.duration, extra=s.extra }
    end
    UCam.notify("Combos", ("Combo '%s' cargado (%d pasos)."):format(name, #c.steps))
    return true
end

function UCam.deleteCombo(name)
    if not UCam.Combos.SavedCombos[name] then return false end
    UCam.Combos.SavedCombos[name] = nil
    UCam.notify("Combos", ("Combo '%s' eliminado."):format(name))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.listCombos()
    local lines = {}
    for name, c in pairs(UCam.Combos.SavedCombos) do
        lines[#lines+1] = ("%s (%d pasos)"):format(name, #(c.steps or {}))
    end
    return lines, #lines
end

-- ============================================================
-- EXPORT / IMPORT
-- ============================================================
function UCam.exportCombo(name)
    local c = UCam.Combos.SavedCombos[name]
    if not c then return nil, "Combo no encontrado." end
    local payload = {
        name    = name,
        steps   = c.steps,
        savedAt = c.savedAt,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return nil, "JSONEncode falló" end
    return HttpService:Base64Encode(json)
end

function UCam.importCombo(base64)
    local ok1, json = pcall(function() return HttpService:Base64Decode(base64) end)
    if not ok1 then return false, "Base64Decode falló" end
    local ok2, payload = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok2 or type(payload) ~= "table" then return false, "JSONDecode falló" end
    local name = tostring(payload.name or "Importado")
    local steps = payload.steps
    if type(steps) ~= "table" then return false, "Formato inválido" end

    -- Validar que cada step tenga camMode + duration
    for _, s in ipairs(steps) do
        if type(s.camMode) ~= "string" or not isValidMode(s.camMode) then
            return false, ("Step con camMode inválido: %s"):format(tostring(s.camMode))
        end
        if type(s.duration) ~= "number" or s.duration < MIN_STEP_DURATION then
            return false, "Duration inválida"
        end
    end

    UCam.Combos.SavedCombos[name] = {
        steps   = steps,
        savedAt = os.time(),
    }
    UCam.notify("Combos", ("Combo '%s' importado (%d pasos)."):format(name, #steps))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

-- ============================================================
-- STOP GLOBAL (para Unload)
-- ============================================================
function UCam.stopCombos()
    resetComboPlayback()
    UCam.Combos.Enabled = false
end

print("[UCam] Combos de cámara listos.")
