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
    _frames         = 0,
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
function UCam.perfRecord(moduleName, ms)
    local P = UCam.Performance
    if not P.Enabled then return end

    P._accum[moduleName] = (P._accum[moduleName] or 0) + ms
    P._frames = P._frames + 1

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
            UCam.perfRecord("camcore.updateCamera", (os.clock() - t0) * 1000)
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
    if P._frames == 0 then return "Sin datos todavía (activa el monitor)." end

    local parts = {}
    parts[#parts+1] = ("Frames analizados: %d"):format(P._frames)
    -- v8 FIX: contar módulos con un loop real (select(2, next()) devolvía
    -- el primer valor acumulado, no el número de módulos)
    local moduleCount = 0
    for _ in pairs(P._accum) do moduleCount = moduleCount + 1 end
    parts[#parts+1] = ("Módulos medidos: %d"):format(moduleCount)
    parts[#parts+1] = ""

    -- Tabla por módulo
    local entries = {}
    for module, totalMs in pairs(P._accum) do
        table.insert(entries, { name = module, total = totalMs, avg = totalMs / P._frames })
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
    UCam.Performance._frames = 0
end

-- ============================================================
-- TOGGLE ON/OFF
-- ============================================================
function UCam.startPerfMonitor()
    local P = UCam.Performance
    if P.Enabled then return end
    P.Enabled        = true
    P._frames        = 0
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
