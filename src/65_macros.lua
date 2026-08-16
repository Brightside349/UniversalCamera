-- ============================================================
-- Universal Camera Pro v8 · 65_macros
-- Grabación y reproducción de "macros": secuencias de acciones
-- discretas (cambios de configuración, toggles, FOV, shake, etc).
--
-- Útil para reproducir setups complejos con replicación exacta:
--   1. Grabar → ejecuta acciones con timestamps
--   2. Guardar → nómbralo para usarlo luego
--   3. Reproducir → aplica las acciones en su timing original
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   Macro (tabla), startMacroRecording, stopMacroRecording,
--   macroRecordAction, listMacros,
--   playMacro, stopMacroPlayback,
--   saveMacro, loadMacro, deleteMacro, renameMacro,
--   exportMacro, importMacro,
--   stopMacros
-- ============================================================
local UCam = _G.UCam

local HttpService = game:GetService("HttpService")

-- ============================================================
-- ESTADO
-- ============================================================
local recording = false
local recordStart = 0
local played = {
    conn   = nil,
    macro  = nil,
    paused = false,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function nowMs()
    return tick() * 1000
end

local function fmtTs(ms)
    return ("%d ms"):format(math.floor(ms))
end

-- ============================================================
-- GRABAR — acumula acciones con su timestamp relativo
-- ============================================================
function UCam.startMacroRecording(name)
    if recording then
        UCam.notify("Macros", "Ya hay una grabación activa.")
        return false
    end
    recording              = true
    UCam.Macros.Recording  = true
    UCam.Macros.RecordingName = tostring(name or "Macro") or "Macro"
    recordStart            = nowMs()
    UCam.Macros._actions = {}
    UCam.notify("Macros", ("Grabando macro '%s'. Ejecuta acciones."):format(UCam.Macros.RecordingName))
    return true
end

function UCam.stopMacroRecording()
    if not recording then
        UCam.notify("Macros", "No hay grabación en curso.")
        return false
    end
    recording = false
    UCam.Macros.Recording = false
    local n = #UCam.Macros._actions
    UCam.notify("Macros", ("Grabación '%s' detenida: %d acciones."):format(
        UCam.Macros.RecordingName, n))
    return true
end

--- Llamado desde cualquier módulo para registrar una acción.
-- kind: string tipo "toggle","setmode","fov","shake","filter","speed"
-- path: string identificador, ej "UCam.camMode" o "UCam.FovPulse.Enabled"
-- value: el valor aplicado (number|string|boolean)
function UCam.macroRecordAction(kind, path, value)
    if not recording then return end
    local dt = nowMs() - recordStart
    table.insert(UCam.Macros._actions, {
        t     = dt,
        kind  = kind,
        path  = path,
        value = value,
    })
end

-- ============================================================
-- GUARDAR / CARGAR / ELIMINAR / RENOMBRAR macros
-- ============================================================
function UCam.saveMacro(macroName)
    macroName = tostring(macroName or UCam.Macros.RecordingName or "Macro")
    if #UCam.Macros._actions == 0 then
        UCam.notify("Macros", "No hay acciones grabadas para guardar.")
        return false
    end
    UCam.Macros.SavedMacros[macroName] = {
        actions = UCam.Macros._actions,
        savedAt = os.time(),
    }
    UCam.notify("Macros", ("Macro '%s' guardado: %d acciones."):format(macroName, #UCam.Macros._actions))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.loadMacro(macroName)
    local m = UCam.Macros.SavedMacros[macroName]
    if not m then
        UCam.notify("Macros", ("Macro '%s' no encontrado."):format(macroName))
        return false
    end
    UCam.Macros._actions = m.actions
    UCam.Macros.RecordingName = macroName
    UCam.notify("Macros", ("Macro '%s' cargado: %d acciones."):format(macroName, #m.actions))
    return true
end

function UCam.deleteMacro(macroName)
    if not UCam.Macros.SavedMacros[macroName] then return false end
    UCam.Macros.SavedMacros[macroName] = nil
    UCam.notify("Macros", ("Macro '%s' eliminado."):format(macroName))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.renameMacro(oldName, newName)
    local m = UCam.Macros.SavedMacros[oldName]
    if not m then return false end
    UCam.Macros.SavedMacros[oldName] = nil
    UCam.Macros.SavedMacros[newName] = m
    UCam.notify("Macros", ("Macro renombrado a '%s'."):format(newName))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.listMacros()
    local list = {}
    for name, m in pairs(UCam.Macros.SavedMacros) do
        list[#list+1] = ("%s (%d acciones)"):format(name, #(m.actions or {}))
    end
    return list, #list
end

-- ============================================================
-- REPRODUCIR una macro (aplicar acciones en su timing original)
-- ============================================================
local function stopPlaybackInternal()
    if UCam.Macros._conn then
        pcall(function() UCam.Macros._conn:Disconnect() end)
        UCam.Macros._conn = nil
    end
    played.macro = nil
    played.paused = false
    UCam.Macros.Playing = false
    UCam.Macros.CurrentMacro = nil
    UCam.Macros._playhead  = 0
end

function UCam.stopMacroPlayback()
    if not UCam.Macros.Playing then return end
    stopPlaybackInternal()
    UCam.notify("Macros", "Reproducción detenida.")
end

function UCam.playMacro(macroName)
    local m = UCam.Macros.SavedMacros[macroName]
    if not m or #m.actions == 0 then
        UCam.notify("Macros", ("Macro '%s' no existe o está vacío."):format(macroName))
        return false
    end
    if UCam.Macros.Playing then
        UCam.notify("Macros", "Ya hay un macro reproduciéndose.")
        return false
    end

    played.macro = m.actions
    played.paused = false
    UCam.Macros.Playing = true
    UCam.Macros.CurrentMacro = macroName
    UCam.Macros._playhead   = 0
    UCam.Macros._startedAt  = tick()

    UCam.notify("Macros", ("Reproduciendo '%s'..."):format(macroName))

    UCam.Macros._conn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function(dt)
        if not UCam.Macros.Playing or played.paused then return end

        local speed   = UCam.Macros.PlaySpeed or 1.0
        -- v8.1 FIX: PlaySpeed invertido — ahora speed=2 reproduce el macro
        -- al DOBLE de velocidad (antes 1/speed lo ralentizaba).
        local elapsed = (tick() - UCam.Macros._startedAt) * 1000 * speed

        while UCam.Macros._playhead + 1 <= #played.macro do
            local action = played.macro[UCam.Macros._playhead + 1]
            if action.t > elapsed then break end
            UCam.Macros._playhead = UCam.Macros._playhead + 1

            pcall(function()
                local path  = tostring(action.path)
                local value = action.value
                local kind  = action.kind

                if kind == "toggle_cam" then
                    -- v8.1 FIX: la acción ahora respeta el valor grabado.
                    -- value guarda el estado objetivo (boolean) si se registró.
                    if value ~= nil and UCam.freeCamEnabled ~= value then
                        if UCam.toggleFreeCam then UCam.toggleFreeCam() end
                    elseif value == nil then
                        if UCam.toggleFreeCam then UCam.toggleFreeCam() end
                    end

                elseif kind == "toggle_hud" then
                    if UCam.setHudHidden then UCam.setHudHidden(value) end

                elseif kind == "set_mode" then
                    UCam.camMode = tostring(value or "Libre")
                    -- v8.1 FIX: init del modo vía triggerTransition (CableCam/SecurityCam/etc.)
                    if UCam.triggerTransition then UCam.triggerTransition() end

                elseif kind == "set_fov" then
                    if UCam.camera then UCam.camera.FieldOfView = UCam.clamp(tonumber(value) or 70, 1, 120) end
                    if UCam.CamCore then UCam.CamCore.TargetFOV = tonumber(value) or 70 end

                elseif kind == "trigger_shake" then
                    if UCam.triggerShake then UCam.triggerShake(tostring(value or "Impacto")) end

                elseif kind == "set_filter" then
                    local idx = tonumber(value)
                    if idx and UCam.Filters[idx] then
                        UCam.currentFilterIndex = idx
                        if UCam.applyFilter then pcall(UCam.applyFilter, idx) end
                    end

                elseif kind == "set_slowmo" then
                    if UCam.SlowMo then
                        UCam.SlowMo.Intensity = math.clamp(tonumber(value) or 50, 1, 100)
                        local active = (tonumber(value) or 50) < 100
                        UCam.SlowMo.BulletTime = active
                        -- v8.1 FIX: llamar al toggle real para activar/desactivar tracking
                        if UCam.toggleBulletTime then UCam.toggleBulletTime(active) end
                    end

                elseif kind == "set_path" then
                    -- path = "UCam.Orbit.Distance" style walk
                    local keys = {}
                    for k in path:gmatch("[^.]+") do table.insert(keys, k) end
                    local node = UCam
                    for i = 1, #keys - 1 do
                        node = node[keys[i]]
                        if type(node) ~= "table" then return end
                    end
                    local lastKey = keys[#keys]
                    node[lastKey] = value

                elseif kind == "notify" then
                    UCam.notify("Macro", tostring(value))
                else
                    -- kind desconocido: tratado como set_path si tiene "UCam."
                    if path:sub(1, 5) == "UCam." then
                        local keys = {}
                        for k in path:gmatch("[^.]+") do table.insert(keys, k) end
                        local node = UCam
                        for i = 1, #keys - 1 do
                            node = node[keys[i]]
                            if type(node) ~= "table" then return end
                        end
                        node[keys[#keys]] = value
                    end
                end
            end)
        end

        if UCam.Macros._playhead >= #played.macro then
            -- Macro terminado
            local durationMs = elapsed
            UCam.stopMacroPlayback()
            UCam.notify("Macros", ("'%s' terminado (%s)."):format(macroName, fmtTs(durationMs)))
        end
        end),
        "Macros:Playback"
    )

    return true
end

-- ============================================================
-- EXPORT / IMPORT (Base64)
-- ============================================================
function UCam.exportMacro(macroName)
    local m = UCam.Macros.SavedMacros[macroName]
    if not m then return nil, "Macro no encontrado." end
    local payload = {
        name    = macroName,
        actions = m.actions,
        savedAt = m.savedAt,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok then return nil, "JSONEncode falló" end
    return HttpService:Base64Encode(json)
end

function UCam.importMacro(base64)
    local ok1, json = pcall(function() return HttpService:Base64Decode(base64) end)
    if not ok1 then return false, "Base64Decode falló" end
    local ok2, payload = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok2 or type(payload) ~= "table" then return false, "JSONDecode falló" end
    local name = tostring(payload.name or "Importado")
    local actions = payload.actions or {}
    if type(actions) ~= "table" then return false, "Formato inválido" end
    UCam.Macros.SavedMacros[name] = { actions = actions, savedAt = os.time() }
    UCam.notify("Macros", ("Macro importado como '%s' (%d acciones)."):format(name, #actions))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

-- ============================================================
-- STOP GLOBAL (para Unload)
-- ============================================================
function UCam.stopMacros()
    if recording then
        recording = false
        UCam.Macros.Recording = false
    end
    stopPlaybackInternal()
    UCam.Macros._actions = {}
end

print("[UCam] Macros listos.")
