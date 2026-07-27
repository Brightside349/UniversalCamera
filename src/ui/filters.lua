-- ============================================================
-- Universal Camera Pro v6 · ui/filters
-- Pestaña Filtros: 30 built-in + editor custom + presets.
-- Registra los dropdowns en UCam.UIRefs.FilterDropdown y
-- UCam.UIRefs.CustomFilterDropdown.
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

    FilterTab:CreateSection("Selector rapido (30 built-in + custom)")
    UCam.UIRefs.FilterDropdown = FilterTab:CreateDropdown({
        Name = "Filtro activo",
        Options = listAllFilterNames(),
        CurrentOption = { UCam.Filters[UCam.currentFilterIndex].Name },
        MultipleOptions = false,
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if type(value) ~= "string" or value == "" then return end
            UCam.applyFilterByName(value)
            UCam.notify("Filtro", "Aplicado: " .. value)
        end,
    })

    FilterTab:CreateSection("Filtros built-in (botones)")
    for _, f in ipairs(UCam.Filters) do
        FilterTab:CreateButton({
            Name = ">> " .. f.Name,
            Callback = function()
                UCam.applyFilterByName(f.Name)
                pcall(function() UCam.UIRefs.FilterDropdown:Set({ f.Name }) end)
                UCam.notify("Filtro", "Aplicado: " .. f.Name)
            end,
        })
    end

    FilterTab:CreateSection("Editor de filtro custom")

    FilterTab:CreateSlider({
        Name = "Brillo",
        Range = { -0.5, 0.5 },
        Increment = 0.01,
        Suffix = "",
        CurrentValue = UCam.customEditing.Brightness,
        Callback = function(v)
            UCam.customEditing.Brightness = v
            UCam.applyCustomEditingLive()
        end,
    })
    FilterTab:CreateSlider({
        Name = "Contraste",
        Range = { -1, 1 },
        Increment = 0.01,
        Suffix = "",
        CurrentValue = UCam.customEditing.Contrast,
        Callback = function(v)
            UCam.customEditing.Contrast = v
            UCam.applyCustomEditingLive()
        end,
    })
    FilterTab:CreateSlider({
        Name = "Saturacion",
        Range = { -1, 1 },
        Increment = 0.01,
        Suffix = "",
        CurrentValue = UCam.customEditing.Saturation,
        Callback = function(v)
            UCam.customEditing.Saturation = v
            UCam.applyCustomEditingLive()
        end,
    })
    FilterTab:CreateSlider({
        Name = "Tinte - Rojo",
        Range = { 0, 255 },
        Increment = 1,
        Suffix = "",
        CurrentValue = UCam.customEditing.R,
        Callback = function(v)
            UCam.customEditing.R = math.floor(v)
            UCam.applyCustomEditingLive()
        end,
    })
    FilterTab:CreateSlider({
        Name = "Tinte - Verde",
        Range = { 0, 255 },
        Increment = 1,
        Suffix = "",
        CurrentValue = UCam.customEditing.G,
        Callback = function(v)
            UCam.customEditing.G = math.floor(v)
            UCam.applyCustomEditingLive()
        end,
    })
    FilterTab:CreateSlider({
        Name = "Tinte - Azul",
        Range = { 0, 255 },
        Increment = 1,
        Suffix = "",
        CurrentValue = UCam.customEditing.B,
        Callback = function(v)
            UCam.customEditing.B = math.floor(v)
            UCam.applyCustomEditingLive()
        end,
    })

    FilterTab:CreateSection("Acciones del filtro custom")
    FilterTab:CreateInput({
        Name                     = "Nombre para guardar filtro custom",
        PlaceholderText          = "ej: MiLookNeon",
        RemoveTextAfterFocusLost = true,
        Flag                     = "customNameInput",
        Callback                 = function() end,
    })

    FilterTab:CreateButton({
        Name = "Guardar filtro custom (con nombre actual)",
        Callback = function()
            pcall(function()
                local flag = UCam.Rayfield.Flags["customNameInput"]
                local rawName = flag and flag.CurrentValue or flag and flag.Value or ""
                local name = tostring(rawName or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if name == "" then
                    UCam.notify("Filtros", "Escribe un nombre valido en la caja de texto.")
                    return
                end
                for _, f in ipairs(UCam.Filters) do if f.Name == name then
                        UCam.notify("Filtros", "Nombre ya existe en built-in."); return
                    end end
                for i, f in ipairs(UCam.CustomFilters) do if f.Name == name then
                        table.remove(UCam.CustomFilters, i); break
                    end end

                if #UCam.CustomFilters >= UCam.MAX_CUSTOM_FILTERS then
                    table.remove(UCam.CustomFilters, 1)
                end

                table.insert(UCam.CustomFilters, {
                    Name       = name,
                    Brightness = UCam.customEditing.Brightness,
                    Contrast   = UCam.customEditing.Contrast,
                    Saturation = UCam.customEditing.Saturation,
                    TintColor  = Color3.fromRGB(UCam.customEditing.R, UCam.customEditing.G, UCam.customEditing.B),
                })

                pcall(function() UCam.UIRefs.FilterDropdown:Refresh(listAllFilterNames()) end)
                if UCam.UIRefs.CustomFilterDropdown then
                    local cfNames = {}
                    for _, f in ipairs(UCam.CustomFilters) do table.insert(cfNames, f.Name) end
                    pcall(function() UCam.UIRefs.CustomFilterDropdown:Refresh(cfNames) end)
                end

                UCam.notify("Filtros", "Filtro guardado: " .. name .. " (" .. #UCam.CustomFilters .. "/" .. UCam.MAX_CUSTOM_FILTERS ..
                ")")
            end)
        end,
    })

    FilterTab:CreateButton({
        Name = "Restablecer editor (volver a neutro)",
        Callback = function()
            UCam.customEditing.Brightness                          = 0
            UCam.customEditing.Contrast                            = 0
            UCam.customEditing.Saturation                          = 0
            UCam.customEditing.R, UCam.customEditing.G, UCam.customEditing.B = 255, 255, 255
            UCam.applyCustomEditingLive()
            UCam.notify("Filtros", "Editor restablecido a neutro.")
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

    FilterTab:CreateSection("Mis filtros custom guardados")
    local customNameList = {}
    if #UCam.CustomFilters > 0 then
        for _, f in ipairs(UCam.CustomFilters) do table.insert(customNameList, f.Name) end
    else
        table.insert(customNameList, "(Aun no hay filtros custom)")
    end

    -- FIX v6 (B3): el dropdown custom ahora tiene un Flag REAL
    -- ("UCamCustomFilterDD") para que "Eliminar filtro custom seleccionado"
    -- lea el filtro elegido en vez de caer siempre al ultimo de la lista.
    UCam.UIRefs.CustomFilterDropdown = FilterTab:CreateDropdown({
        Name = "Filtros custom guardados",
        Options = customNameList,
        CurrentOption = { customNameList[1] },
        MultipleOptions = false,
        Flag = "UCamCustomFilterDD",
        Callback = function(options)
            local v = UCam.resolveDropdownValue(options)
            if type(v) ~= "string" or v == "" or v == "(Aun no hay filtros custom)" then return end
            UCam.applyFilterByName(v)
            pcall(function() UCam.UIRefs.FilterDropdown:Set({ v }) end)
            UCam.notify("Filtros custom", "Aplicado: " .. v)
        end,
    })

    FilterTab:CreateButton({
        Name = "Eliminar filtro custom seleccionado",
        Callback = function()
            if #UCam.CustomFilters == 0 then
                UCam.notify("Filtros custom", "No hay filtros custom para eliminar.")
                return
            end
            local current
            pcall(function()
                local f = UCam.Rayfield.Flags["UCamCustomFilterDD"]
                local val = f and (f.CurrentValue or f.Value)
                if type(val) == "table" then
                    current = val[1]
                elseif type(val) == "string" then
                    current = val
                end
            end)
            if not current or current == "" or current == "(Aun no hay filtros custom)" then
                current = UCam.CustomFilters[#UCam.CustomFilters] and UCam.CustomFilters[#UCam.CustomFilters].Name
            end
            for i, f in ipairs(UCam.CustomFilters) do
                if f.Name == current then
                    table.remove(UCam.CustomFilters, i)
                    UCam.notify("Filtros custom", "Eliminado: " .. current)
                    local cfNames = {}
                    for _, x in ipairs(UCam.CustomFilters) do table.insert(cfNames, x.Name) end
                    if #cfNames == 0 then table.insert(cfNames, "(Aun no hay filtros custom)") end
                    pcall(function() UCam.UIRefs.CustomFilterDropdown:Refresh(cfNames) end)
                    pcall(function() UCam.UIRefs.FilterDropdown:Refresh(listAllFilterNames()) end)
                    return
                end
            end
            UCam.notify("Filtros custom", "No se encontro el filtro.")
        end,
    })

    FilterTab:CreateButton({
        Name = "Borrar TODOS los filtros custom",
        Callback = function()
            table.clear(UCam.CustomFilters)
            local cfNames = { "(Aun no hay filtros custom)" }
            pcall(function() UCam.UIRefs.CustomFilterDropdown:Refresh(cfNames) end)
            pcall(function() UCam.UIRefs.FilterDropdown:Refresh(listAllFilterNames()) end)
            UCam.notify("Filtros custom", "Todos los filtros custom fueron eliminados.")
        end,
    })

    -- ===== v7: Expansion Filtros (transiciones, combinación, temporal, chromatic) =====
    local function builtinNames()
        local n = {}
        for _, f in ipairs(UCam.Filters) do table.insert(n, f.Name) end
        return n
    end

    FilterTab:CreateSection("v7 - Transiciones y Mezcla")
    FilterTab:CreateToggle({
        Name = "Transición suave al cambiar de filtro",
        CurrentValue = UCam.FilterTransition.Enabled,
        Callback = function(v) UCam.FilterTransition.Enabled = v end,
    })
    FilterTab:CreateSlider({
        Name = "Velocidad de transición",
        Range = { 1, 20 },
        Increment = 0.5,
        Suffix = "x",
        CurrentValue = UCam.FilterTransition.Speed,
        Callback = function(v) UCam.FilterTransition.Speed = v end,
    })
    FilterTab:CreateToggle({
        Name = "Combinar dos filtros (mezcla)",
        CurrentValue = UCam.FilterCombine.Enabled,
        Callback = function(v)
            UCam.FilterCombine.Enabled = v
            UCam.applyFilter(UCam.currentFilterIndex, true)
        end,
    })
    FilterTab:CreateDropdown({
        Name = "Filtro secundario a mezclar",
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
        Name = "Mezcla (0=filtro A, 1=filtro B)",
        Range = { 0, 1 },
        Increment = 0.05,
        CurrentValue = UCam.FilterCombine.Mix,
        Callback = function(v)
            UCam.FilterCombine.Mix = v
            if UCam.FilterCombine.Enabled then UCam.applyFilter(UCam.currentFilterIndex, true) end
        end,
    })

    FilterTab:CreateSection("v7 - Filtro Temporal (auto-desvanecer)")
    FilterTab:CreateDropdown({
        Name = "Filtro temporal a aplicar",
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
        Name = "Duración antes de desvanecer",
        Range = { 0.5, 30 },
        Increment = 0.5,
        Suffix = " s",
        CurrentValue = UCam.FilterTemporal.Duration,
        Callback = function(v) UCam.FilterTemporal.Duration = v end,
    })
    FilterTab:CreateButton({
        Name = "Aplicar filtro temporal (se desvanece solo)",
        Callback = function()
            UCam.FilterTemporal.Active = true
            UCam.applyFilter(UCam.FilterTemporal.Index, false)
            UCam.notify("Filtros", string.format("Filtro temporal activo, se desvanecerá en %.1fs.", UCam.FilterTemporal.Duration))
        end,
    })
    FilterTab:CreateButton({
        Name = "Cancelar filtro temporal",
        Callback = function()
            UCam.FilterTemporal.Active = false
            UCam.notify("Filtros", "Filtro temporal cancelado.")
        end,
    })

    FilterTab:CreateSection("v7 - Aberración Cromática (Chromatic)")
    FilterTab:CreateToggle({
        Name = "Activar aberración cromática (RGB split)",
        CurrentValue = UCam.ChromaticAberration.Enabled,
        Callback = function(v)
            UCam.ChromaticAberration.Enabled = v
            UCam.applyChromaticAberration()
            if not v then UCam.destroyChromaticGui() end
        end,
    })
    FilterTab:CreateSlider({
        Name = "Cantidad de desplazamiento",
        Range = { 0, 40 },
        Increment = 1,
        Suffix = " px",
        CurrentValue = UCam.ChromaticAberration.Amount,
        Callback = function(v) UCam.setChromaticAmount(v) end,
    })
end
