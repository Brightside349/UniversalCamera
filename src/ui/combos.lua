-- ============================================================
-- Universal Camera Pro v8 · ui/combos
-- Pestaña Combos: secuencias automáticas de modos de cámara.
-- ============================================================
local UCam = _G.UCam

function UCam.build_combos(Window)
    local Tab = Window:CreateTab("⚡ Combos", "layers")

    -- idx local para eliminar steps (closure, no _G)
    local comboRemoveIdx = 1

    -- --------------------------------------------------------
    -- ¿Qué es?
    -- --------------------------------------------------------
    Tab:CreateSection("¿Qué es un combo?")
    Tab:CreateParagraph({
        Title   = "Secuencias automáticas",
        Content = "Un combo encadena modos de cámara (Orbita → CrashZoom → Slow-mo, etc). Cada paso puede durar 0.1s - 5min, con extra opcionales (slow-mo, shake, filtro, notificación).",
    })

    -- --------------------------------------------------------
    -- AÑADIR PASOS
    -- --------------------------------------------------------
    Tab:CreateSection("Añadir pasos al combo actual")

    local stepMode     = "Orbita"
    local stepDuration = 4.0
    local stepExtraFOV = nil
    local stepExtraSlow = nil   -- slow-mo % (o nil)
    local stepExtraShake = nil  -- patrón
    local stepExtraNotify = nil

    Tab:CreateDropdown({
        Name            = "Modo de cámara",
        Options         = UCam.CamModes,
        CurrentOption   = { "Orbita" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v then stepMode = v end
        end,
    })

    Tab:CreateSlider({
        Name         = "Duración (segundos)",
        Range        = { 0.1, 60 },
        Increment    = 0.1,
        Suffix       = "s",
        CurrentValue = 4.0,
        Callback     = function(v) stepDuration = tonumber(v) or 4.0 end,
    })

    Tab:CreateSlider({
        Name         = "FOV (opcional, 0 = sin cambiar)",
        Range        = { 0, 120 },
        Increment    = 1,
        Suffix       = "°",
        CurrentValue = 0,
        Callback     = function(v)
            local vv = tonumber(v) or 0
            stepExtraFOV = (vv > 0) and vv or nil
        end,
    })

    Tab:CreateSlider({
        Name         = "Slow-mo % (opcional, 0 = sin cambiar)",
        Range        = { 0, 100 },
        Increment    = 1,
        Suffix       = "%",
        CurrentValue = 0,
        Callback     = function(v)
            local vv = tonumber(v) or 0
            stepExtraSlow = (vv > 0) and vv or nil
        end,
    })

    Tab:CreateDropdown({
        Name            = "Shake en el paso (opcional)",
        Options         = { "-- Sin shake --", "Sutil", "Terremoto", "Explosion", "Pulso", "Impacto" },
        CurrentOption   = { "-- Sin shake --" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v and not v:find("^%-%-") then
                stepExtraShake = v
            else
                stepExtraShake = nil
            end
        end,
    })

    Tab:CreateInput({
        Name        = "Notificación en el paso (opcional)",
        PlaceholderText = "Texto que aparecerá al entrar...",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v)
            local vv = tostring(v or "")
            stepExtraNotify = (vv ~= "") and vv or nil
        end,
    })

    Tab:CreateButton({
        Name     = "➕  Añadir paso",
        Callback = function()
            local extra = {}
            if stepExtraFOV     then extra.fov     = stepExtraFOV end
            if stepExtraSlow    then extra.slowmo  = stepExtraSlow end
            if stepExtraShake   then extra.shake   = stepExtraShake end
            if stepExtraNotify  then extra.notify  = stepExtraNotify end
            local usedExtra = (next(extra) ~= nil) and extra or nil

            UCam.addComboStep(stepMode, stepDuration, usedExtra)
        end,
    })

    -- --------------------------------------------------------
    -- VER / EDITAR PASOS
    -- --------------------------------------------------------
    Tab:CreateSection("Pasos actuales (en orden)")

    Tab:CreateButton({
        Name     = "ℹ️  Ver pasos",
        Callback = function()
            local parts = {}
            for i, s in ipairs(UCam.Combos.Steps) do
                local extra = ""
                local ex = s.extra or {}
                if ex.fov    then extra = extra .. " fov=" .. tostring(ex.fov) end
                if ex.slowmo then extra = extra .. " slow=" .. tostring(ex.slowmo) .. "%" end
                if ex.shake  then extra = extra .. " shake=" .. ex.shake end
                parts[#parts+1] = ("%d. %s × %.1fs%s"):format(i, s.camMode, s.duration, extra)
            end
            UCam.notify("Combos — Steps (" .. #UCam.Combos.Steps .. ")",
                (#parts > 0) and table.concat(parts, "\n") or "Ninguno añadido.", 8)
        end,
    })

    Tab:CreateSlider({
        Name         = "Eliminar paso (índice 1-N)",
        Range        = { 1, 20 },
        Increment    = 1,
        CurrentValue = 1,
        Callback     = function(v)
            comboRemoveIdx = math.floor(v)
        end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Eliminar paso seleccionado",
        Callback = function()
            UCam.removeComboStep(comboRemoveIdx)
        end,
    })

    Tab:CreateButton({
        Name     = "🧹  Limpiar TODOS los pasos",
        Callback = function()
            UCam.clearComboSteps()
        end,
    })

    -- --------------------------------------------------------
    -- REPRODUCIR
    -- --------------------------------------------------------
    Tab:CreateSection("Reproducción")

    Tab:CreateButton({
        Name     = "▶  Empezar combo",
        Callback = function()
            UCam.startCombo()
        end,
    })

    Tab:CreateButton({
        Name     = "⏹  Detener combo",
        Callback = function()
            UCam.stopCombo()
        end,
    })

    Tab:CreateToggle({
        Name         = "Loop (repetir al terminar)",
        CurrentValue = UCam.Combos.Loop,
        Callback     = function(v)
            UCam.Combos.Loop = v
            UCam.notify("Combos", v and "Loop activado." or "Loop desactivado.")
        end,
    })

    Tab:CreateParagraph({
        Title   = "Estado",
        Content = "El combo avanza automáticamente al siguiente paso cuando se cumple la duración del paso actual. Los extras (FOV/Slow-mo/Shake/Notificación) se aplican al entrar en cada paso.",
    })

    -- --------------------------------------------------------
    -- GUARDAR / CARGAR
    -- --------------------------------------------------------
    Tab:CreateSection("Guardar / Cargar")

    local comboName = "Mi Combo"
    Tab:CreateInput({
        Name        = "Nombre del combo",
        PlaceholderText = "Ej: Intro Cinemático",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) comboName = tostring(v or "Combo") end,
    })

    local selCombo = ""
    local function refreshComboList()
        local opts = {}
        for name, _ in pairs(UCam.Combos.SavedCombos) do opts[#opts+1] = name end
        if #opts == 0 then opts = { "(vacío)" } end
        return opts
    end
    local comboDd = Tab:CreateDropdown({
        Name            = "Combo a cargar",
        Options         = refreshComboList(),
        CurrentOption   = { "(vacío)" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if v and v ~= "(vacío)" then selCombo = v end
        end,
    })

    Tab:CreateButton({
        Name     = "💾  Guardar combo actual",
        Callback = function()
            if comboName == "" then
                UCam.notify("Combos", "Ponle un nombre.")
                return
            end
            UCam.saveCombo(comboName)
            pcall(function() comboDd:Refresh(refreshComboList()) end)
        end,
    })

    Tab:CreateButton({
        Name     = "📂  Cargar combo",
        Callback = function()
            if selCombo == "" then
                UCam.notify("Combos", "Selecciona uno.")
                return
            end
            UCam.loadCombo(selCombo)
        end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Eliminar combo",
        Callback = function()
            if selCombo == "" then
                UCam.notify("Combos", "Selecciona uno.")
                return
            end
            UCam.deleteCombo(selCombo)
            pcall(function() comboDd:Refresh(refreshComboList()) end)
        end,
    })

    Tab:CreateButton({
        Name     = "ℹ️  Listar combos guardados",
        Callback = function()
            local lines = select(1, UCam.listCombos())
            UCam.notify("Combos guardados",
                (#lines > 0) and table.concat(lines, "\n") or "Ninguno.", 6)
        end,
    })

    -- --------------------------------------------------------
    -- EXPORT / IMPORT
    -- --------------------------------------------------------
    Tab:CreateSection("Exportar / Importar")

    Tab:CreateButton({
        Name     = "📤  Copiar combo al portapapeles",
        Callback = function()
            if selCombo == "" then
                UCam.notify("Combos", "Selecciona uno.")
                return
            end
            local b64, err = UCam.exportCombo(selCombo)
            if not b64 then
                UCam.notify("Combos", tostring(err))
                return
            end
            local ok = pcall(function() setclipboard(b64) end)
            if ok then
                UCam.notify("Combos", "Copiado (" .. #b64 .. " chars).")
            else
                print("[UCam Combo Export]\n" .. b64)
                UCam.notify("Combos", "Impreso en consola.")
            end
        end,
    })

    local importStr = ""
    Tab:CreateInput({
        Name        = "Pegar combo importado",
        PlaceholderText = "Base64...",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v) importStr = tostring(v or "") end,
    })
    Tab:CreateButton({
        Name     = "📥  Importar combo",
        Callback = function()
            if importStr == "" then
                UCam.notify("Combos", "Pega un string.")
                return
            end
            local ok, err = UCam.importCombo(importStr)
            if ok then
                importStr = ""
                pcall(function() comboDd:Refresh(refreshComboList()) end)
            else
                UCam.notify("Combos", "Import falló: " .. tostring(err))
            end
        end,
    })
end
