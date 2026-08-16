-- ============================================================
-- Universal Camera Pro v8 · ui/macros
-- Pestaña Macros: grabar acciones de cámara con timing, guardar,
-- reproducir, exportar e importar.
-- ============================================================
local UCam = _G.UCam

function UCam.build_macros(Window)
    local Tab = Window:CreateTab("🎯 Macros", "zap")

    -- --------------------------------------------------------
    -- SECCIÓN: ¿Qué es un macro?
    -- --------------------------------------------------------
    Tab:CreateSection("¿Qué es un macro?")
    Tab:CreateParagraph({
        Title   = "Secuencia grabada",
        Content = "Un macro graba acciones discretas (toggle cámara, cambios de modo, FOV, shake, slow-mo, filtros...) con su tiempo exacto. Lo reproduces con precisión milimétrica cuando necesitas la misma secuencia repetidamente.",
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Grabación
    -- --------------------------------------------------------
    Tab:CreateSection("Grabación")

    local macroName = "Mi Macro"
    Tab:CreateInput({
        Name        = "Nombre del macro",
        PlaceholderText = "Ej: Intro, Impacto, Transición...",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) macroName = tostring(v or "Macro") end,
    })

    Tab:CreateButton({
        Name     = "⏺  Empezar grabación",
        Callback = function()
            UCam.startMacroRecording(macroName)
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Parar grabación",
        Callback = function()
            UCam.stopMacroRecording()
        end,
    })

    Tab:CreateButton({
        Name     = "ℹ️  Info de la grabación actual",
        Callback = function()
            local n = #UCam.Macros._actions
            if UCam.Macros.Recording then
                UCam.notify("Macros", ("Grabando '%s': %d acciones capturadas."):format(
                    UCam.Macros.RecordingName, n))
            else
                UCam.notify("Macros", ("No hay grabación activa. Buffer: %d acciones."):format(n))
            end
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Acciones grabables mediante botones (hook manual)
    -- --------------------------------------------------------
    Tab:CreateSection("Botones de acción directa")
    Tab:CreateParagraph({
        Title   = "¿Cómo usar?",
        Content = "Una vez grabando, pulsa estos botones para registrar la acción en el macro. Cada clic guarda la acción + timestamp.",
    })

    Tab:CreateButton({
        Name     = "🎬  Toggle cámara libre",
        Callback = function()
            if UCam.toggleFreeCam then
                UCam.toggleFreeCam()
                UCam.macroRecordAction("toggle_cam", "UCam.toggleFreeCam()", nil)
            end
        end,
    })

    local modeForMacro = "Libre"
    Tab:CreateDropdown({
        Name            = "Modo a aplicar (para guardar en macro)",
        Options         = UCam.CamModes,
        CurrentOption   = { "Libre" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then modeForMacro = v end
        end,
    })
    Tab:CreateButton({
        Name     = "📷  Cambiar modo de cámara (en macro)",
        Callback = function()
            UCam.camMode = modeForMacro
            -- v8.1 FIX: bypaseaba triggerTransition → el modo quedaba sin
            -- inicializar (CableCam sin A/B, SecurityCam sin anchor, etc.)
            if UCam.triggerTransition then UCam.triggerTransition() end
            UCam.macroRecordAction("set_mode", "UCam.camMode", modeForMacro)
            UCam.notify("Macro", ("Modo → %s"):format(modeForMacro))
        end,
    })

    local fovForMacro = 70
    Tab:CreateSlider({
        Name         = "FOV deseado (para macro)",
        Range        = { 1, 120 },
        Increment    = 1,
        CurrentValue = 70,
        Callback     = function(v) fovForMacro = math.floor(v) end,
    })
    Tab:CreateButton({
        Name     = "🔭  Aplicar FOV (en macro)",
        Callback = function()
            UCam.camera.FieldOfView = fovForMacro
            UCam.macroRecordAction("set_fov", "UCam.camera.FieldOfView", fovForMacro)
        end,
    })

    local shakeForMacro = "Impacto"
    Tab:CreateDropdown({
        Name            = "Shake (para macro)",
        Options         = UCam.Shake.Patterns,
        CurrentOption   = { "Impacto" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then shakeForMacro = v end
        end,
    })
    Tab:CreateButton({
        Name     = "📳  Lanzar Shake (en macro)",
        Callback = function()
            if UCam.triggerShake then UCam.triggerShake(shakeForMacro) end
            UCam.macroRecordAction("trigger_shake", "UCam.triggerShake()", shakeForMacro)
        end,
    })

    local slowForMacro = 30
    Tab:CreateSlider({
        Name         = "Slow-mo % (en macro)",
        Range        = { 1, 100 },
        Increment    = 1,
        CurrentValue = 30,
        Callback     = function(v) slowForMacro = math.floor(v) end,
    })
    Tab:CreateButton({
        Name     = "⏱️  Bullet Time (en macro)",
        Callback = function()
            if UCam.SlowMo then
                UCam.SlowMo.Intensity = math.clamp(slowForMacro, 1, 100)
                -- v8.1 FIX: se setea a pelo sin llamar toggleBulletTime()
                -- → nunca se activaba realmente. Ahora se llama el toggle.
                local active = slowForMacro < 100
                UCam.SlowMo.BulletTime = active
                if UCam.toggleBulletTime then UCam.toggleBulletTime(active) end
                UCam.macroRecordAction("set_slowmo", "UCam.SlowMo.Intensity", slowForMacro)
            end
        end,
    })

    local filterIdxMacro = 1
    Tab:CreateSlider({
        Name         = "Filtro #(1-30) (en macro)",
        Range        = { 1, 30 },
        Increment    = 1,
        CurrentValue = 1,
        Callback     = function(v) filterIdxMacro = math.floor(v) end,
    })
    Tab:CreateButton({
        Name     = "🎨  Aplicar filtro (en macro)",
        Callback = function()
            local idx = math.clamp(filterIdxMacro, 1, #UCam.Filters)
            UCam.currentFilterIndex = idx
            if UCam.applyFilter then pcall(UCam.applyFilter, idx) end
            UCam.macroRecordAction("set_filter", "UCam.currentFilterIndex", idx)
            UCam.notify("Macro", ("Filtro #%d aplicado."):format(idx))
        end,
    })

    -- Texto libre para path avanzado
    local freePath = "UCam.Orbit.Distance"
    local freeValue = "15"
    Tab:CreateInput({
        Name        = "Path UCam (ej. UCam.Orbit.Distance)",
        PlaceholderText = "UCam.Orbit.Distance",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) freePath = tostring(v or "") end,
    })
    Tab:CreateInput({
        Name        = "Valor (número / string / true|false)",
        PlaceholderText = "15",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) freeValue = tostring(v or "") end,
    })
    Tab:CreateButton({
        Name     = "🔧  Guardar acción libre en macro",
        Callback = function()
            -- parsear valor
            local val = tonumber(freeValue)
            if val == nil then
                if freeValue == "true" then val = true
                elseif freeValue == "false" then val = false
                else val = freeValue end
            end
            UCam.macroRecordAction("set_path", freePath, val)
            -- aplicar en vivo también
            local keys = {}
            for k in freePath:gmatch("[^.]+") do table.insert(keys, k) end
            local node = UCam
            for i = 1, #keys - 1 do
                node = node[keys[i]]
                if type(node) ~= "table" then
                    UCam.notify("Macro", "Path inválido: " .. freePath)
                    return
                end
            end
            node[keys[#keys]] = val
            UCam.notify("Macro", ("Guardado: %s = %s"):format(freePath, tostring(val)))
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Guardar / Cargar / Eliminar
    -- --------------------------------------------------------
    Tab:CreateSection("Macros guardados")

    local selectedMacro = ""
    local function refreshMacroList()
        local opts = {}
        for name, _ in pairs(UCam.Macros.SavedMacros) do
            opts[#opts+1] = name
        end
        if #opts == 0 then opts = { "(vacío)" } end
        return opts
    end

    local macroDropdown = Tab:CreateDropdown({
        Name            = "Macro",
        Options         = refreshMacroList(),
        CurrentOption   = { "(vacío)" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v and v ~= "(vacío)" then selectedMacro = v end
        end,
    })

    Tab:CreateButton({
        Name     = "💾  Guardar buffer actual como macro",
        Callback = function()
            if macroName == "" then
                UCam.notify("Macros", "Ponle un nombre arriba.")
                return
            end
            UCam.saveMacro(macroName)
            pcall(function() macroDropdown:Refresh(refreshMacroList()) end)
        end,
    })

    Tab:CreateButton({
        Name     = "📂  Cargar macro al buffer",
        Callback = function()
            if selectedMacro == "" then
                UCam.notify("Macros", "Selecciona un macro.")
                return
            end
            UCam.loadMacro(selectedMacro)
        end,
    })

    Tab:CreateButton({
        Name     = "▶  Reproducir macro",
        Callback = function()
            if selectedMacro == "" then
                UCam.notify("Macros", "Selecciona un macro.")
                return
            end
            UCam.playMacro(selectedMacro)
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Parar reproducción",
        Callback = function()
            UCam.stopMacroPlayback()
        end,
    })

    Tab:CreateSlider({
        Name         = "Velocidad de reproducción",
        Range        = { 0.1, 4 },
        Increment    = 0.05,
        Suffix       = "x",
        CurrentValue = 1.0,
        Callback     = function(v)
            UCam.Macros.PlaySpeed = tonumber(v) or 1.0
        end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Eliminar macro",
        Callback = function()
            if selectedMacro == "" then
                UCam.notify("Macros", "Selecciona un macro.")
                return
            end
            UCam.deleteMacro(selectedMacro)
            pcall(function() macroDropdown:Refresh(refreshMacroList()) end)
        end,
    })

    Tab:CreateInput({
        Name        = "Nuevo nombre (para renombrar)",
        PlaceholderText = "Ej: Intro Cinemático",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) macroName = tostring(v or macroName) end,
    })
    Tab:CreateButton({
        Name     = "✏️  Renombrar macro",
        Callback = function()
            if selectedMacro == "" or macroName == "" then
                UCam.notify("Macros", "Selecciona macro + nuevo nombre.")
                return
            end
            UCam.renameMacro(selectedMacro, macroName)
            pcall(function() macroDropdown:Refresh(refreshMacroList()) end)
        end,
    })

    Tab:CreateButton({
        Name     = "ℹ️  Listar macros",
        Callback = function()
            local lines = {}
            for name, m in pairs(UCam.Macros.SavedMacros) do
                lines[#lines+1] = ("%s — %d acciones"):format(name, #(m.actions or {}))
            end
            UCam.notify("Macros (" .. #lines .. ")",
                (#lines > 0) and table.concat(lines, "\n") or "Ninguno guardado.", 6)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Export / Import
    -- --------------------------------------------------------
    Tab:CreateSection("Exportar / Importar")

    Tab:CreateButton({
        Name     = "📤  Copiar macro al portapapeles (Base64)",
        Callback = function()
            if selectedMacro == "" then
                UCam.notify("Macros", "Selecciona un macro.")
                return
            end
            local b64, err = UCam.exportMacro(selectedMacro)
            if not b64 then
                UCam.notify("Macros", tostring(err))
                return
            end
            local ok = pcall(function() setclipboard(b64) end)
            if ok then
                UCam.notify("Macros", "Copiado (" .. #b64 .. " chars).")
            else
                print("[UCam Macro Export]\n" .. b64)
                UCam.notify("Macros", "Impreso en consola (setclipboard no disponible).")
            end
        end,
    })

    local importInput = ""
    Tab:CreateInput({
        Name        = "Pegar macro importado",
        PlaceholderText = "Base64...",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) importInput = tostring(v or "") end,
    })
    Tab:CreateButton({
        Name     = "📥  Importar macro",
        Callback = function()
            if importInput == "" then
                UCam.notify("Macros", "Pega un string primero.")
                return
            end
            local ok, err = UCam.importMacro(importInput)
            if ok then
                importInput = ""
                pcall(function() macroDropdown:Refresh(refreshMacroList()) end)
            else
                UCam.notify("Macros", "Import falló: " .. tostring(err))
            end
        end,
    })
end
