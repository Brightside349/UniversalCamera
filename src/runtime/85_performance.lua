-- ============================================================
-- Universal Camera Pro v8 · 85_performance
-- Monitor de Frame Budget: mide el tiempo de cada módulo por frame
-- y alerta si alguno excede un umbral. Útil para debuggear lag
-- en servidores con muchos jugadores.
--
-- El tracker SOLO está activo cuando UCam.Performance.Enabled=true.
-- Su overhead es negligible (unos pocos os.clock() por frame).
--
-- Dependencias: 00_config, 70_camcore (se engancha a updateCamera)
-- Expone (UCam.*):
--   Performance (tabla), togglePerformanceMonitor, startPerfMonitor,
--   stopPerfMonitor, getPerfReport, printPerfReport, resetPerfTracker
-- ============================================================
local UCam = _G.UCam

UCam.Performance = UCam.Performance or {
    Enabled         = false,
    ReportInterval  = 5.0,        -- segundos entre reportes automáticos
    AlertThreshold  = 1.5,        -- ms por frame que dispara warning
    History         = {},
    MaxHistory      = 60,         -- últimas 60 entradas (5 minuto)
    _lastReportAt   = 0,
    _accum          = {},         -- acumulador por módulo
    _frameCount     = 0,
    _samples        = 0,
    _frameTimeTotal = 0,
    _frameTimeMax   = 0,
    _frameDeltas    = {},
    _frameTimes     = {},
    _lastAlertAt    = {},
}

-- ============================================================
-- COLECCIÓN DE MUESTRAS
-- ============================================================
-- Cada hook llama a UCam.perfRecord(moduleName, ms)
-- con el tiempo que tardo en ejecutarse.
-- ============================================================

-- Helper para medir con pcall
local function timecall(fn, ...)
    local t0 = os.clock()
    local ok, res = pcall(fn, ...)
    local dt = (os.clock() - t0) * 1000 -- ms
    return ok, res, dt
end

--- Registra una medición. Llamado por los módulos instrumentados.
function UCam.perfFrame(dt, elapsedMs)
    local P = UCam.Performance
    if not P.Enabled then return end
    P._frameCount = P._frameCount + 1
    P._frameTimeTotal = P._frameTimeTotal + (elapsedMs or 0)
    P._frameTimeMax = math.max(P._frameTimeMax, elapsedMs or 0)
    table.insert(P._frameDeltas, dt or 0)
    table.insert(P._frameTimes, elapsedMs or 0)
    if #P._frameDeltas > 600 then table.remove(P._frameDeltas, 1) end
    if #P._frameTimes > 600 then table.remove(P._frameTimes, 1) end
end

function UCam.perfRecord(moduleName, ms)
    local P = UCam.Performance
    if not P.Enabled then return end

    P._accum[moduleName] = (P._accum[moduleName] or 0) + ms
    P._samples = P._samples + 1

    -- Log inmediato si un módulo supera el umbral (+= 3 ms de una vez)
    if ms >= (P.AlertThreshold * 2) then
        warn(("[UCam Perf] %s tardó %.2f ms en un frame"):format(moduleName, ms))
    end
end

-- ============================================================
-- HOOK a los módulos críticos (updateCamera, funUpdate, replay, etc.)
-- ============================================================

local _origUpdateCamera = nil
local _origFunUpdate    = nil

-- Envuelve una función existente para medirla
local function hookFunction(parent, name, wrapper)
    local orig = parent[name]
    if type(orig) ~= "function" then return end
    parent["__perf_orig_" .. name] = orig
    parent[name] = wrapper(orig)
    return orig
end

-- Restaura la función original
local function unhookFunction(parent, name)
    local orig = parent["__perf_orig_" .. name]
    if orig then
        parent[name] = orig
        parent["__perf_orig_" .. name] = nil
    end
end

local function installHooks()
    -- updateCamera (núcleo del render)
    _origUpdateCamera = hookFunction(UCam, "updateCamera", function(orig)
        return function(dt)
            local t0 = os.clock()
            local ok, res = pcall(orig, dt)
            local elapsedMs = (os.clock() - t0) * 1000
            UCam.perfFrame(dt, elapsedMs)
            UCam.perfRecord("camcore.updateCamera", elapsedMs)
            if not ok then error(res) end
            return res
        end
    end)
    -- v9 FIX (fuga de memoria / hook inútil): 70_camcore registró el render
    -- step "UCamRender" con la referencia ORIGINAL de updateCamera. Reemplazar
    -- UCam.updateCamera aquí no afectaba al callback ya bindeado, así que el
    -- módulo principal jamás aparecía en el reporte. Re-bindeamos el step para
    -- que apunte a la versión hookeada; removeHooks lo restaura al original.
    UCam.RunService:UnbindFromRenderStep("UCamRender")
    UCam.RunService:BindToRenderStep("UCamRender", Enum.RenderPriority.Camera.Value + 1, UCam.updateCamera)

    -- funUpdate (módulo Fun)
    _origFunUpdate = hookFunction(UCam, "funUpdate", function(orig)
        return function(dt)
            local t0 = os.clock()
            local ok, res = pcall(orig, dt)
            UCam.perfRecord("fun.funUpdate", (os.clock() - t0) * 1000)
            if not ok then error(res) end
            return res
        end
    end)

    -- v8.1: updateTimeControl eliminado junto a su módulo
end

local function removeHooks()
    unhookFunction(UCam, "updateCamera")
    unhookFunction(UCam, "funUpdate")
    -- Restaurar el render step "UCamRender" a la función original de updateCamera
    -- (70_camcore lo vuelve a enlazar por su cuenta al recargar, pero en caliente
    -- hay que restaurar la referencia que instaló el profiler).
    UCam.RunService:UnbindFromRenderStep("UCamRender")
    UCam.RunService:BindToRenderStep("UCamRender", Enum.RenderPriority.Camera.Value + 1, UCam.updateCamera)
end

-- ============================================================
-- REPORTES
-- ============================================================

--- Devuelve un reporte agregado como string.
function UCam.getPerfReport()
    local P = UCam.Performance
    if P._frameCount == 0 then return "Sin datos todavía (activa el monitor)." end

    local frameTimes = {}
    for i, value in ipairs(P._frameTimes) do frameTimes[i] = value end
    table.sort(frameTimes)
    local p95 = frameTimes[math.max(1, math.ceil(#frameTimes * 0.95))] or 0
    if P._frames == 0 then return "Sin datos todavía (activa el monitor)." end

    local parts = {}
    parts[#parts+1] = ("Frames reales: %d | muestras de módulos: %d"):format(P._frameCount, P._samples)
    parts[#parts+1] = ("Tiempo medio de frame: %.3f ms | máximo: %.3f ms"):format(
        P._frameTimeTotal / P._frameCount, P._frameTimeMax)
    parts[#parts+1] = ("P95 de CPU Lua: %.3f ms"):format(p95)
    -- v8 FIX: contar módulos con un loop real (select(2, next()) devolvía
    -- el primer valor acumulado, no el número de módulos)
    local moduleCount = 0
    for _ in pairs(P._accum) do moduleCount = moduleCount + 1 end
    parts[#parts+1] = ("Módulos medidos: %d"):format(moduleCount)
    parts[#parts+1] = ""

    -- Tabla por módulo
    local entries = {}
    for module, totalMs in pairs(P._accum) do
        table.insert(entries, { name = module, total = totalMs, avg = totalMs / P._frameCount })
    end
    table.sort(entries, function(a, b) return a.total > b.total end)

    for i, e in ipairs(entries) do
        parts[#parts+1] = ("  %-40s total=%.2fms avg=%.4fms"):format(
            e.name, e.total, e.avg)
    end

    return table.concat(parts, "\n")
end

function UCam.printPerfReport()
    print("\n========== UCam Performance Report ==========")
    print(UCam.getPerfReport())
    print("============================================\n")
end

--- Resetea los acumuladores.
function UCam.resetPerfTracker()
    UCam.Performance._accum = {}
    UCam.Performance._frameCount = 0
    UCam.Performance._samples = 0
    UCam.Performance._frameTimeTotal = 0
    UCam.Performance._frameTimeMax = 0
    UCam.Performance._frameDeltas = {}
    UCam.Performance._frameTimes = {}
end

-- ============================================================
-- TOGGLE ON/OFF
-- ============================================================
function UCam.startPerfMonitor()
    local P = UCam.Performance
    if P.Enabled then return end
    P.Enabled        = true
    P._frameCount    = 0
    P._samples       = 0
    P._frameTimeTotal = 0
    P._frameTimeMax  = 0
    P._frameDeltas   = {}
    P._frameTimes    = {}
    P._accum         = {}
    P._lastReportAt  = tick()

    installHooks()

    -- Heartbeat de reportes automáticos
    P._conn = UCam.trackConnection(
        UCam.RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - P._lastReportAt >= P.ReportInterval then
                P._lastReportAt = now
                local report = UCam.getPerfReport()
                -- Log a consola — no notificar porque sobrecargaría la UI
                print("[UCam Perf]\n" .. report)
            end
        end),
        "Performance:Heartbeat"
    )

    UCam.notify("Performance", "Monitor ACTIVADO. Reportes en consola cada " .. P.ReportInterval .. "s.")
end

function UCam.stopPerfMonitor()
    local P = UCam.Performance
    if not P.Enabled then return end
    P.Enabled = false

    if P._conn then
        pcall(function() P._conn:Disconnect() end)
        P._conn = nil
    end

    removeHooks()
    UCam.notify("Performance", "Monitor detenido.")
end

function UCam.togglePerformanceMonitor(state)
    if state then
        UCam.startPerfMonitor()
    else
        UCam.stopPerfMonitor()
    end
end

-- ============================================================
-- STOP GLOBAL (para Unload)
-- ============================================================
function UCam.stopPerformance()
    UCam.stopPerfMonitor()
end

print("[UCam] Performance monitor listo (OFF por defecto — activarlo con UI).")
