-- ============================================================
-- Universal Camera Pro v13.8 · ui/emotes
-- Pestaña Emotes: baile local del personaje equipado.
--
-- Todo el estado vive en UCam.Emotes (core/00_config) y la logica en
-- actors/37_emotes. Aqui solo hay controles: nada de runtime.
-- ============================================================
local UCam = _G.UCam
local E = UCam.Emotes

function UCam.build_emotes(Window)
    local Tab = Window:CreateTab("🕺 Emotes", "music")

    -- ============================================================
    -- BAILE LOCAL
    -- ============================================================
    Tab:CreateSection("Baile local (solo tú lo ves)")
    Tab:CreateParagraph({
        Title = "Cómo funciona",
        Content = "Carga el baile del personaje que tengas equipado en tu propio Animator: no se envía nada al servidor y los demás jugadores no lo ven. El baile viaja empaquetado dentro de UCam y se registra en tu cliente, así que funciona en cualquier juego sin depender del permiso de ningún asset. Se corta al morir, al cambiar de personaje y, si lo dejas activo, al moverte o saltar.",
    })

    Tab:CreateToggle({
        Name = "Activar tecla de baile",
        CurrentValue = E.Enabled,
        Flag = "UCamEmoteEnabled",
        Callback = function(value) E.Enabled = value end,
    })

    local keybind = Tab:CreateKeybind({
        Name = "Tecla de baile",
        CurrentKeybind = E.Key or "G",
        HoldToInteract = false,
        Flag = "UCamEmoteKey",
        Callback = function(code)
            -- bindKey entrega el EnumItem de la tecla configurada.
            if typeof(code) == "EnumItem" then
                E.Key = code.Name
            end
            if not E.Enabled then return end
            local _, msg = UCam.toggleEmote()
            UCam.notify("Emotes", msg, 3)
        end,
    })

    Tab:CreateToggle({
        Name = "Bailar al equipar el personaje",
        CurrentValue = E.AutoPlay,
        Flag = "UCamEmoteAutoPlay",
        Callback = function(value)
            E.AutoPlay = value
            if value then
                local status = UCam.playEmote()
                if status == false then
                    UCam.notify("Emotes", "Se reproducirá cuando el personaje tenga baile configurado.", 4)
                end
            end
        end,
    })

    -- ============================================================
    -- COMPORTAMIENTO
    -- ============================================================
    Tab:CreateSection("Comportamiento")
    Tab:CreateToggle({
        Name = "Repetir en bucle",
        CurrentValue = E.Loop,
        Flag = "UCamEmoteLoop",
        Callback = function(value)
            E.Loop = value
            if E._track then
                E._track.Looped = value
            end
        end,
    })
    Tab:CreateToggle({
        Name = "Cortar al moverme o saltar",
        CurrentValue = E.CancelOnMove,
        Flag = "UCamEmoteCancelOnMove",
        Callback = function(value) E.CancelOnMove = value end,
    })
    Tab:CreateDropdown({
        Name = "Prioridad de la animación",
        Options = E.Priorities,
        CurrentOption = { E.Priority },
        MultipleOptions = false,
        Flag = "UCamEmotePriority",
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if value then
                E.Priority = value
                if E._track then
                    pcall(function()
                        E._track.Priority = Enum.AnimationPriority[value]
                    end)
                end
            end
        end,
    })

    -- ============================================================
    -- REPRODUCCIÓN
    -- ============================================================
    Tab:CreateSection("Reproducción")
    Tab:CreateButton({
        Name = "▶ Bailar ahora",
        Callback = function()
            local ok, msg = UCam.playEmote()
            UCam.notify("Emotes", msg, ok and 3 or 5, { important = not ok })
        end,
    })
    Tab:CreateButton({
        Name = "⏹ Detener baile",
        Callback = function()
            local wasPlaying = UCam.stopEmote()
            UCam.notify("Emotes", wasPlaying and "Baile detenido." or "No había ningún baile activo.", 3)
        end,
    })
    Tab:CreateButton({
        Name = "ℹ️ Ver estado",
        Callback = function()
            local status = UCam.getEmoteStatus()
            local ready = UCam.EmoteCodec.prepared()
            UCam.notify("Emotes", table.concat({
                ("Personaje: %s"):format(status.character or "no detectado"),
                ("Reproduciendo: %s"):format(status.playing and "sí" or "no"),
                ("Origen: %s"):format(status.source == "local" and "empaquetado (local)" or (status.source or "—")),
                ("Asset: %s"):format(status.animationId or "—"),
                ("Duración: %.2f s"):format(status.length or 0),
                ("Bucle: %s · Prioridad: %s"):format(status.loop and "sí" or "no", status.priority),
                ("Bailes empaquetados: %d/%d"):format(ready.prepared, ready.total),
            }, "\n"), 6)
        end,
    })
    Tab:CreateButton({
        Name = "📦 Preparar todos los bailes",
        Callback = function()
            -- El empaquetado solo ocurre una vez por sesión: se adelanta para
            -- que la tecla suene al primer pulsado en vez de esperar la descarga.
            if E._preparing then
                UCam.notify("Emotes", "Ya se están preparando los bailes.", 3)
                return
            end
            E._preparing = true
            task.spawn(function()
                local done = 0
                for key, dance in pairs(E.Dances) do
                    if dance.Pack and not UCam.EmoteCodec.isReady(key) then
                        local hash = UCam.EmoteCodec.hashFor(key, dance.Pack)
                        if hash then done += 1 end
                    elseif UCam.EmoteCodec.isReady(key) then
                        done += 1
                    end
                end
                E._preparing = false
                UCam.notify("Emotes", ("Bailes listos en tu cliente: %d."):format(done), 5)
            end)
        end,
    })
    Tab:CreateButton({
        Name = "🗑 Restablecer tecla a G",
        Callback = function()
            E.Key = "G"
            if keybind and type(keybind.Set) == "function" then
                pcall(function() keybind:Set("G") end)
            end
            UCam.notify("Emotes", "Tecla de baile restablecida a G.")
        end,
    })

    -- ============================================================
    -- PERSONAJES CONFIGURADOS
    -- ============================================================
    Tab:CreateSection("Personajes con baile")
    Tab:CreateParagraph({
        Title = "Bailes cargados",
        Content = "Amy, Sonic y Knuckles. El personaje se detecta por el atributo \"Character\" del modelo (el mismo que usa el Animate del juego); si el juego no lo marca, se acepta el nombre del modelo cuando coincide.",
    })
    Tab:CreateDropdown({
        Name = "Origen del baile",
        Options = { "Empaquetado (local)", "AssetId (requiere permiso)" },
        CurrentOption = { E.Source == "asset" and "AssetId (requiere permiso)" or "Empaquetado (local)" },
        MultipleOptions = false,
        Flag = "UCamEmoteSource",
        Callback = function(options)
            local value = UCam.resolveDropdownValue(options)
            if not value then return end
            E.Source = value:find("AssetId", 1, true) and "asset" or "local"
        end,
    })
    Tab:CreateButton({
        Name = "🔎 Ver bailes configurados",
        Callback = function()
            local lines = {}
            for name, dance in pairs(E.Dances) do
                table.insert(lines, ("%s → %s"):format(name, dance.Pack or dance.AnimationId or "—"))
            end
            table.sort(lines)
            UCam.notify("Emotes", #lines > 0 and table.concat(lines, "\n") or "Sin bailes configurados.", 6)
        end,
    })
end
