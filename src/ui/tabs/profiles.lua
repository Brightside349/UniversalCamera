-- ============================================================
-- Universal Camera Pro v8 · ui/profiles
-- Pestaña Perfiles: guardar/cargar/aplicar/eliminar/renombrar
-- hasta 8 setups completos + 3 quick slots + export/import.
-- ============================================================
local UCam = _G.UCam

function UCam.build_profiles(Window)
    local Tab = Window:CreateTab("📁 Perfiles", "folder")

    -- --------------------------------------------------------
    -- SECCIÓN: Info
    -- --------------------------------------------------------
    Tab:CreateSection("¿Qué es un Perfil?")
    Tab:CreateParagraph({
        Title   = "Setup completo",
        Content = "Un perfil guarda TODO: modo de cámara, velocidad, filtros, iluminación, slow-mo, espectador, keybinds, etc. Guarda 8 perfiles distintos (ej. \"Cinemático\", \"Action\", \"TP Shoot\") y cámbialos al instante.",
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Slots
    -- --------------------------------------------------------
    Tab:CreateSection("Ranuras (1-8)")

    local selectedSlot = 1
    local slotDropdown = Tab:CreateDropdown({
        Name            = "Ranura seleccionada",
        Options         = { "1", "2", "3", "4", "5", "6", "7", "8" },
        CurrentOption   = { "1" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            selectedSlot = tonumber(v) or 1
        end,
    })

    -- Slider para acceso rápido sin dropdown
    Tab:CreateSlider({
        Name         = "Ranura (1-8)",
        Range        = { 1, 8 },
        Increment    = 1,
        CurrentValue = 1,
        Callback     = function(v)
            selectedSlot = math.floor(v)
            pcall(function() slotDropdown:Set({ tostring(selectedSlot) }) end)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Nombre
    -- --------------------------------------------------------
    Tab:CreateSection("Nombre del perfil")

    local nameInput = ""
    Tab:CreateInput({
        Name        = "Nombre (opcional)",
        PlaceholderText = "Ej: Cinemático, Acción, Slow-mo…",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v)
            nameInput = tostring(v or "")
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Acciones principales
    -- --------------------------------------------------------
    Tab:CreateSection("Acciones")

    Tab:CreateButton({
        Name     = "💾  Guardar (estado actual)",
        Callback = function()
            local customName = (nameInput ~= "") and nameInput or nil
            if UCam.saveProfile(selectedSlot, customName) then
                nameInput = ""
            end
        end,
    })

    Tab:CreateButton({
        Name     = "📂  Cargar / Aplicar",
        Callback = function()
            UCam.loadProfile(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "✏️  Renombrar",
        Callback = function()
            if nameInput == "" then
                UCam.notify("Perfiles", "Escribe un nombre en el campo de arriba primero.")
                return
            end
            UCam.renameProfile(selectedSlot, nameInput)
            nameInput = ""
        end,
    })

    Tab:CreateButton({
        Name     = "🗑️  Eliminar",
        Callback = function()
            UCam.deleteProfile(selectedSlot)
        end,
    })

    Tab:CreateButton({
        Name     = "ℹ️  Ver resumen de todas las ranuras",
        Callback = function()
            local text = select(1, UCam.listProfiles())
            UCam.notify("Perfiles guardados", text, 8)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Quick Slots (hotkeys rápidos)
    -- --------------------------------------------------------
    Tab:CreateSection("Quick slots (hotkeys)")

    Tab:CreateParagraph({
        Title   = "Acceso ultra-rápido",
        Content = "Asigna un perfil guardado a un quick slot, y luego aplícalo con un solo click sin entrar a esta pestaña.",
    })

    local selectedQuick = 1
    Tab:CreateDropdown({
        Name            = "Quick slot",
        Options         = { "Quick 1", "Quick 2", "Quick 3" },
        CurrentOption   = { "Quick 1" },
        MultipleOptions = false,
        Callback        = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            local map = { ["Quick 1"] = 1, ["Quick 2"] = 2, ["Quick 3"] = 3 }
            selectedQuick = map[v] or 1
        end,
    })

    -- v9 FIX (bug UI): el párrafo con Tag="quick_info" no era soportado por
    -- Rayfield y Tab.quickLabel nunca existía → el bloque quedaba siempre vacío.
    -- Ahora guardamos la referencia del párrafo y la actualizamos con :Set().
    local quickInfoParagraph = Tab:CreateParagraph({
        Title   = "Quick slots actuales",
        Content = "Aún no hay quick slots vinculados.",
    })

    local function refreshQuickInfo()
        local parts = {}
        for q = 1, 3 do
            local t = UCam.Profiles.QuickSlots[q]
            if t then
                local s = UCam.Profiles.Slots[t]
                parts[#parts+1] = ("Quick %d → ranura %d (%s)"):format(q, t, s and s._name or "?")
            else
                parts[#parts+1] = ("Quick %d → (vacío)"):format(q)
            end
        end
        local content = table.concat(parts, "  •  ")
        pcall(function()
            if quickInfoParagraph and quickInfoParagraph.Set then
                quickInfoParagraph:Set(content)
            end
        end)
        return content
    end

    Tab:CreateButton({
        Name     = "⚡  Vincular quick slot → ranura actual",
        Callback = function()
            UCam.quickSaveProfile(selectedQuick, selectedSlot)
            refreshQuickInfo()
        end,
    })

    Tab:CreateButton({
        Name     = "▶  Aplicar quick slot",
        Callback = function()
            UCam.quickLoadProfile(selectedQuick)
        end,
    })

    Tab:CreateButton({
        Name     = "🔄  Limpiar quick slot",
        Callback = function()
            UCam.Profiles.QuickSlots[selectedQuick] = nil
            UCam.notify("Perfiles", ("Quick slot %d limpiado."):format(selectedQuick))
            refreshQuickInfo()
            pcall(UCam.saveConfig)
        end,
    })

    Tab:CreateButton({
        Name     = "📋  Listar quick slots",
        Callback = function()
            UCam.notify("Quick slots", refreshQuickInfo(), 6)
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Exportar / Importar
    -- --------------------------------------------------------
    Tab:CreateSection("Exportar / Importar")

    Tab:CreateParagraph({
        Title   = "Compartir perfiles",
        Content = "Exporta un perfil a un string Base64. Cópialo y compártelo. Pega un string importado y elige en qué ranura guardarlo.",
    })

    Tab:CreateButton({
        Name     = "📤  Copiar perfil actual al portapapeles",
        Callback = function()
            local b64, msg = UCam.exportProfile(selectedSlot)
            if not b64 then
                UCam.notify("Perfiles", tostring(msg))
                return
            end
            local ok = pcall(function() setclipboard(b64) end)
            if ok then
                UCam.notify("Perfiles", "Perfil copiado (" .. #b64 .. " chars). " .. msg)
            else
                UCam.notify("Perfiles", "setclipboard no disponible. Ver consola.")
                print("[UCam Profile Export]\n" .. b64)
            end
        end,
    })

    local importInput = ""
    Tab:CreateInput({
        Name        = "Pegar perfil importado",
        PlaceholderText = "Pega Base64 aquí…",
        RemoveTextAfterFocusLost = false,
        Callback    = function(v)
            importInput = tostring(v or "")
        end,
    })

    Tab:CreateButton({
        Name     = "📥  Importar a ranura actual",
        Callback = function()
            if importInput == "" then
                UCam.notify("Perfiles", "Pega un string primero.")
                return
            end
            if UCam.importProfile(importInput, selectedSlot) then
                importInput = ""
            end
        end,
    })

    -- --------------------------------------------------------
    -- SECCIÓN: Acciones globales
    -- --------------------------------------------------------
    Tab:CreateSection("Otros")

    Tab:CreateButton({
        Name     = "💾  Forzar guardado en disco",
        Callback = function()
            if UCam.saveConfig then
                local ok, err = UCam.saveConfig()
                if ok then
                    UCam.notify("Perfiles", "Config + perfiles guardados a disco.")
                else
                    UCam.notify("Perfiles", "Error: " .. tostring(err))
                end
            else
                UCam.notify("Perfiles", "Sistema de persistencia no disponible.")
            end
        end,
    })
end
