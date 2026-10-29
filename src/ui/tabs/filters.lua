-- ============================================================
-- Universal Camera Pro v12.5 · ui/filters
-- Pestaña Filtros: selector único, editor custom, colección guardada,
-- transiciones/mezcla y filtro temporal.
--
-- v12.5: se elimino la parrilla de botones de filtros built-in (el
-- selector ya los aplica) y se agruparon las opciones avanzadas.
-- ============================================================
local UCam = _G.UCam

function UCam.build_filters(Window)
    local FilterTab = Window:CreateTab("🎨 Filtros", "image")

    local function listAllFilterNames()
        local names = {}
        for _, f in ipairs(UCam.Filters) do table.insert(names, f.Name) end
        for _, f in ipairs(UCam.CustomFilters) do table.insert(names, f.Name) end
        return names
    end

    local function builtinNames()
        local n = {}
        for _, f in ipairs(UCam.Filters) do table.insert(n, f.Name) end
        return n
    end

    local function currentFilterName()
        local idx = UCam.currentFilterIndex or 1
        local f
        if idx < 0 then
            f = UCam.CustomFilters and UCam.CustomFilters[-idx]
        else
            f = UCam.Filters[idx]
        end
        return f and f.Name or (UCam.Filters[1] and UCam.Filters[1].Name or "Ninguno")
    end

    -- ============================================================
    -- SELECTOR
    -- ============================================================
    FilterTab:CreateSection("Filtro activo")
    UCam.UIRefs.FilterDropdown = FilterTab:CreateDropdown({
        Name = "Filtro",
        Options = listAllFilterNames(),
        CurrentOption = { currentFilterName() },
        MultipleOptions = false,
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if type(value) ~= "string" or value == "" then return end
            UCam.applyFilterByName(value)
            UCam.notify("Filtro", "Aplicado: " .. value)
        end,
    })
    FilterTab:CreateSlider({
        Name = "Intensidad del look",
        Range = { 0, 100 },
        Increment = 5,
        Suffix = "%",
        CurrentValue = (UCam.LookIntensity or 1) * 100,
        Callback = function(v) UCam.setLookIntensity((tonumber(v) or 100) / 100) end,
    })

    -- ============================================================
    -- EDITOR CUSTOM
    -- ============================================================
    FilterTab:CreateSection("Editor de filtro custom")
    FilterTab:CreateSlider({
        Name = "Brillo", Range = { -0.5, 0.5 }, Increment = 0.01,
        CurrentValue = UCam.customEditing.Brightness,
        Callback = function(v) UCam.customEditing.Brightness = v; UCam.applyCustomEditingLive() end,
    })
    FilterTab:CreateSlider({
        Name = "Contraste", Range = { -1, 1 }, Increment = 0.01,
        CurrentValue = UCam.customEditing.Contrast,
        Callback = function(v) UCam.customEditing.Contrast = v; UCam.applyCustomEditingLive() end,
    })
    FilterTab:CreateSlider({
        Name = "Saturación", Range = { -1, 1 }, Increment = 0.01,
        CurrentValue = UCam.customEditing.Saturation,
        Callback = function(v) UCam.customEditing.Saturation = v; UCam.applyCustomEditingLive() end,
    })
    FilterTab:CreateSlider({
        Name = "Tinte R", Range = { 0, 255 }, Increment = 1,
        CurrentValue = UCam.customEditing.R,
        Callback = function(v) UCam.customEditing.R = math.floor(v); UCam.applyCustomEditingLive() end,
    })
    FilterTab:CreateSlider({
        Name = "Tinte G", Range = { 0, 255 }, Increment = 1,
        CurrentValue = UCam.customEditing.G,
        Callback = function(v) UCam.customEditing.G = math.floor(v); UCam.applyCustomEditingLive() end,
    })
    FilterTab:CreateSlider({
        Name = "Tinte B", Range = { 0, 255 }, Increment = 1,
        CurrentValue = UCam.customEditing.B,
        Callback = function(v) UCam.customEditing.B = math.floor(v); UCam.applyCustomEditingLive() end,
    })
    FilterTab:CreateInput({
        Name = "Nombre del filtro custom",
        PlaceholderText = "ej: MiLookNeon",
        RemoveTextAfterFocusLost = true,
        Flag = "customNameInput",
        Callback = function() end,
    })

    local function refreshCustomLists()
        pcall(function() UCam.UIRefs.FilterDropdown:Refresh(listAllFilterNames()) end)
        local cfNames = {}
        for _, x in ipairs(UCam.CustomFilters) do table.insert(cfNames, x.Name) end
        if #cfNames == 0 then table.insert(cfNames, "(Aun no hay filtros custom)") end
        if UCam.UIRefs.CustomFilterDropdown then
            pcall(function() UCam.UIRefs.CustomFilterDropdown:Refresh(cfNames) end)
        end
    end

    FilterTab:CreateButton({
        Name = "💾 Guardar filtro custom",
        Callback = function()
            local flag = UCam.Rayfield.Flags and UCam.Rayfield.Flags["customNameInput"]
            local rawName = flag and (flag.CurrentValue or flag.Value) or ""
            local name = tostring(rawName or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then
                UCam.notify("Filtros", "Escribe un nombre válido.")
                return
            end
            for _, f in ipairs(UCam.Filters) do
                if f.Name == name then
                    UCam.notify("Filtros", "Ese nombre ya existe en built-in.")
                    return
                end
            end
            for i, f in ipairs(UCam.CustomFilters) do
                if f.Name == name then table.remove(UCam.CustomFilters, i); break end
            end
            if #UCam.CustomFilters >= UCam.MAX_CUSTOM_FILTERS then
                table.remove(UCam.CustomFilters, 1)
            end
            table.insert(UCam.CustomFilters, {
                Name = name,
                Brightness = UCam.customEditing.Brightness,
                Contrast   = UCam.customEditing.Contrast,
                Saturation = UCam.customEditing.Saturation,
                TintColor  = Color3.fromRGB(UCam.customEditing.R, UCam.customEditing.G, UCam.customEditing.B),
            })
            refreshCustomLists()
            UCam.notify("Filtros", "Filtro guardado: " .. name)
        end,
    })
    FilterTab:CreateButton({
        Name = "Restablecer editor (neutro)",
        Callback = function()
            UCam.customEditing.Brightness = 0
            UCam.customEditing.Contrast   = 0
            UCam.customEditing.Saturation = 0
            UCam.customEditing.R, UCam.customEditing.G, UCam.customEditing.B = 255, 255, 255
            UCam.applyCustomEditingLive()
        end,
    })
    FilterTab:CreateButton({
        Name = "Desactivar filtro actual",
        Callback = function()
            UCam.disableColorCorrection()
            UCam.customFilterLiveApplied = false
            pcall(function() UCam.UIRefs.FilterDropdown:Set({ UCam.Filters[1].Name }) end)
            UCam.notify("Filtros", "Filtro desactivado.")
        end,
    })

    -- ============================================================
    -- COLECCIÓN
    -- ============================================================
    FilterTab:CreateSection("Mis filtros guardados")
    local customNameList = {}
    for _, f in ipairs(UCam.CustomFilters) do table.insert(customNameList, f.Name) end
    if #customNameList == 0 then table.insert(customNameList, "(Aun no hay filtros custom)") end

    UCam.UIRefs.CustomFilterDropdown = FilterTab:CreateDropdown({
        Name = "Filtro guardado",
        Options = customNameList,
        CurrentOption = { customNameList[1] },
        MultipleOptions = false,
        Flag = "UCamCustomFilterDD",
        Callback = function(options)
            local v = UCam.resolveDropdownValue(options)
            if type(v) ~= "string" or v == "" or v == "(Aun no hay filtros custom)" then return end
            UCam.applyFilterByName(v)
            pcall(function() UCam.UIRefs.FilterDropdown:Set({ v }) end)
        end,
    })
    FilterTab:CreateButton({
        Name = "🗑 Eliminar filtro seleccionado",
        Callback = function()
            if #UCam.CustomFilters == 0 then
                UCam.notify("Filtros", "No hay filtros custom.")
                return
            end
            local current
            pcall(function()
                local f = UCam.Rayfield.Flags["UCamCustomFilterDD"]
                local val = f and (f.CurrentValue or f.Value)
                if type(val) == "table" then current = val[1]
                elseif type(val) == "string" then current = val end
            end)
            if not current or current == "(Aun no hay filtros custom)" then
                current = UCam.CustomFilters[#UCam.CustomFilters].Name
            end
            for i, f in ipairs(UCam.CustomFilters) do
                if f.Name == current then
                    table.remove(UCam.CustomFilters, i)
                    refreshCustomLists()
                    UCam.notify("Filtros", "Eliminado: " .. current)
                    return
                end
            end
        end,
    })
    FilterTab:CreateButton({
        Name = "🧹 Borrar todos los filtros custom",
        Callback = function()
            table.clear(UCam.CustomFilters)
            refreshCustomLists()
        end,
    })

    -- ============================================================
    -- TRANSICIONES Y MEZCLA
    -- ============================================================
    FilterTab:CreateSection("Transiciones y mezcla")
    FilterTab:CreateToggle({
        Name = "Transición suave al cambiar de filtro",
        CurrentValue = UCam.FilterTransition.Enabled,
        Callback = function(v) UCam.FilterTransition.Enabled = v end,
    })
    FilterTab:CreateSlider({
        Name = "Velocidad de transición", Range = { 1, 20 }, Increment = 0.5, Suffix = "x",
        CurrentValue = UCam.FilterTransition.Speed,
        Callback = function(v) UCam.FilterTransition.Speed = v end,
    })
    FilterTab:CreateToggle({
        Name = "Combinar dos filtros",
        CurrentValue = UCam.FilterCombine.Enabled,
        Callback = function(v)
            UCam.FilterCombine.Enabled = v
            UCam.applyFilter(UCam.currentFilterIndex, true)
        end,
    })
    FilterTab:CreateDropdown({
        Name = "Filtro secundario",
        Options = builtinNames(),
        CurrentOption = { UCam.Filters[UCam.FilterCombine.IndexB] and UCam.Filters[UCam.FilterCombine.IndexB].Name or UCam.Filters[1].Name },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            for i, f in ipairs(UCam.Filters) do
                if f.Name == v then UCam.FilterCombine.IndexB = i; break end
            end
            if UCam.FilterCombine.Enabled then UCam.applyFilter(UCam.currentFilterIndex, true) end
        end,
    })
    FilterTab:CreateSlider({
        Name = "Mezcla (0 = principal, 1 = secundario)",
        Range = { 0, 1 }, Increment = 0.05,
        CurrentValue = UCam.FilterCombine.Mix,
        Callback = function(v)
            UCam.FilterCombine.Mix = v
            if UCam.FilterCombine.Enabled then UCam.applyFilter(UCam.currentFilterIndex, true) end
        end,
    })

    -- ============================================================
    -- FILTRO TEMPORAL
    -- ============================================================
    FilterTab:CreateSection("Filtro temporal")
    FilterTab:CreateDropdown({
        Name = "Filtro a desvanecer",
        Options = builtinNames(),
        CurrentOption = { UCam.Filters[UCam.FilterTemporal.Index] and UCam.Filters[UCam.FilterTemporal.Index].Name or UCam.Filters[1].Name },
        MultipleOptions = false,
        Callback = function(o)
            local v = UCam.resolveDropdownValue(o)
            if not v then return end
            for i, f in ipairs(UCam.Filters) do
                if f.Name == v then UCam.FilterTemporal.Index = i; break end
            end
        end,
    })
    FilterTab:CreateSlider({
        Name = "Duración antes de desvanecer", Range = { 0.5, 30 }, Increment = 0.5, Suffix = " s",
        CurrentValue = UCam.FilterTemporal.Duration,
        Callback = function(v) UCam.FilterTemporal.Duration = v end,
    })
    FilterTab:CreateButton({
        Name = "▶ Aplicar filtro temporal",
        Callback = function()
            UCam.FilterTemporal.Active = true
            UCam.applyFilter(UCam.FilterTemporal.Index, false)
            UCam.notify("Filtros", string.format("Se desvanecerá en %.1fs.", UCam.FilterTemporal.Duration))
        end,
    })
    FilterTab:CreateButton({
        Name = "Cancelar filtro temporal",
        Callback = function()
            UCam.FilterTemporal.Active = false
            UCam.notify("Filtros", "Filtro temporal cancelado.")
        end,
    })
end
