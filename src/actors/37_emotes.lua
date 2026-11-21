-- ============================================================
-- Universal Camera Pro v13.8 · actors/37_emotes
-- Baile local por personaje: carga la animacion en el Animator del
-- personaje y la reproduce SOLO en tu cliente.
--
-- Por que no usa el sistema de emotes del juego: el catalogo real
-- (ClientAssets.Cosmetics.Emotes.<team>.<char>) son modulos que
-- devuelven nil en cliente, y las animaciones por personaje
-- (scriptstuff.Animate.Emotes) estan vacias (rbxassetid://0).
-- Aqui el id vive en la tabla del cliente, igual que el juego
-- guarda "un id por personaje", pero sin remotes.
--
-- No interfiere con el gameplay: el track va en Action4 (por
-- encima de walk/run/idle del juego) y no se toca la camara, el
-- Humanoid ni el servidor.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua.
-- Expone (UCam.*):
--   Emotes (estado en 00_config),
--   playEmote, stopEmote, toggleEmote, getEmoteStatus,
--   attachEmoteCharacter
-- ============================================================
local UCam = _G.UCam
local E = UCam.Emotes

-- El juego usa rigs con Humanoid (y a veces AnimationController para
-- huesos sueltos). Se busca por clase, sin asumir la jerarquia: misma
-- regla que visuals/25_slowmo.
local function animatorOf(character)
    if not character then return nil end
    local animator = character:FindFirstChildOfClass("Animator")
    if animator then return animator end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then return animator end
    end
    local controller = character:FindFirstChildOfClass("AnimationController")
    if controller then
        return controller:FindFirstChildOfClass("Animator")
    end
    return nil
end

--- Nombre del personaje segun el juego.
-- El Animate del personaje lee Parent:GetAttribute("Character"), asi que
-- esa es la fuente. ASUMPTION: si el juego no marca el modelo, se acepta
-- el nombre del modelo solo cuando coincide con un baile configurado.
local function characterKey(character)
    if not character then return nil end
    local attr = character:GetAttribute("Character")
    if type(attr) == "string" and attr ~= "" then return attr end
    if E.Dances[character.Name] then return character.Name end
    return nil
end

local function priorityOf(name)
    local ok, item = pcall(function()
        return Enum.AnimationPriority[name]
    end)
    if ok and item then return item end
    return Enum.AnimationPriority.Action4
end

--- Suelta el track y la instancia Animation actuales.
-- Destruir la Animation es lo que impide que quede reproduciendose
-- cuando el personaje cambia de modelo o muere.
local function release()
    local track, anim = E._track, E._anim
    E._track, E._anim, E._character = nil, nil, nil
    if track then
        pcall(function() track:Stop(0.1) end)
        pcall(function() track:Destroy() end)
    end
    if anim then
        if UCam.untrackInstance then UCam.untrackInstance(anim) end
        pcall(function() anim:Destroy() end)
    end
end

--- Para el baile actual. Devuelve true si habia algo sonando.
function UCam.stopEmote()
    local wasPlaying = E._track ~= nil
    release()
    return wasPlaying
end

--- Reproduce el baile del personaje (o el de `keyOverride`).
-- @return ok: boolean, mensaje: string
function UCam.playEmote(keyOverride)
    local player = UCam.player
    local character = player and player.Character
    if not character or not character.Parent then
        return false, "Sin personaje todavía."
    end

    local key = keyOverride or characterKey(character)
    if not key then
        return false, "El personaje no está marcado con el atributo \"Character\"."
    end

    local dance = E.Dances[key]
    if not dance then
        return false, ("No hay baile configurado para %s."):format(tostring(key))
    end

    local animator = animatorOf(character)
    if not animator then
        return false, "El personaje todavía no tiene Animator."
    end

    release()

    -- v13.9: primero el baile empaquetado (funciona en cualquier juego,
    -- sin permiso de assets). Si no hay Pack o falla, se usa AnimationId,
    -- que solo funciona en experiencias autorizadas por el dueño del asset.
    local anim, source, packErr
    local packPath = (E.Source ~= "asset") and dance.Pack or nil
    if packPath then
        if not UCam.EmoteCodec.isReady(key) and UCam.notify then
            UCam.notify("Emotes", ("Empaquetando el baile de %s en tu cliente (solo la primera vez)…"):format(tostring(key)), 4)
        end

        local hash, err = UCam.EmoteCodec.hashFor(key, packPath)
        if hash then
            anim = Instance.new("Animation")
            anim.AnimationId = hash
            source = "local"
        else
            packErr = err
            warn(("[UCam] Baile empaquetado de %s fallo: %s"):format(tostring(key), tostring(err)))
        end
    end

    -- hashFor puede ceder el frame mientras se construye el baile: el
    -- personaje pudo morir o cambiarse en ese intervalo.
    if anim and (not character.Parent or animatorOf(character) ~= animator) then
        return false, "El personaje cambió mientras se empaquetaba el baile."
    end

    if not anim and dance.AnimationId and dance.AnimationId ~= "" then
        anim = Instance.new("Animation")
        anim.AnimationId = dance.AnimationId
        source = "asset"
    end

    if not anim then
        return false, ("No hay baile disponible para %s%s"):format(
            tostring(key), packErr and (" (" .. tostring(packErr) .. ")") or ""
        )
    end

    anim.Name = "UCamDance_" .. key

    local ok, track = pcall(function()
        return animator:LoadAnimation(anim)
    end)
    if not ok or not track then
        anim:Destroy()
        return false, ("%s no cargó."):format(anim.AnimationId)
    end

    track.Looped = E.Loop == true
    track.Priority = priorityOf(E.Priority)

    E._track, E._anim, E._character = track, anim, key
    E._source = source
    if UCam.trackInstance then
        UCam.trackInstance(anim, "Emotes:animation")
    end

    track:Play(0.15)

    -- Un track sin datos no lanza error: carga vacio (Length 0) y el baile
    -- simplemente no se ve. Se avisa una sola vez.
    task.delay(1, function()
        if E._track == track and track.Length == 0 then
            warn(("[UCam] El baile de %s no reporta duración (origen: %s)."):format(key, tostring(source)))
        end
    end)

    return true, ("%s: bailando%s."):format(key, source == "local" and " (empaquetado)" or "")
end

--- Reproduce si no habia nada, y para si ya estaba sonando.
function UCam.toggleEmote()
    if E._track then
        UCam.stopEmote()
        return false, "Baile detenido."
    end
    return UCam.playEmote()
end

--- Estado actual, para la pestaña y para depurar.
function UCam.getEmoteStatus()
    local track = E._track
    return {
        playing    = track ~= nil,
        character  = E._character,
        animationId = E._anim and E._anim.AnimationId or nil,
        source     = E._source,
        length     = track and track.Length or 0,
        priority   = E.Priority,
        loop       = E.Loop == true,
    }
end

--- Baila solo cuando el personaje equipado tiene baile configurado.
-- Espera al Animator porque el modelo se clona y el Animator aparece
-- un momento despues del CharacterAdded.
local function maybeAutoPlay(character)
    if not E.AutoPlay then return end
    local key = characterKey(character)
    if not key or not E.Dances[key] then return end

    task.spawn(function()
        local deadline = os.clock() + 5
        while character.Parent and os.clock() < deadline do
            if animatorOf(character) then break end
            task.wait(0.1)
        end
        -- Se comprobo otra vez: pudo cambiar de personaje o morir mientras
        -- se esperaba al Animator.
        if character ~= (UCam.player and UCam.player.Character) then return end
        if not E.AutoPlay or characterKey(character) ~= key then return end
        if not animatorOf(character) then return end
        UCam.playEmote(key)
    end)
end

local watchedCharacter = nil

--- Engancha el personaje actual (muerte, movimiento, cambio de personaje).
function UCam.attachEmoteCharacter(character)
    character = character or (UCam.player and UCam.player.Character)
    if not character then return false end
    if watchedCharacter == character then return true end

    watchedCharacter = character
    UCam.stopEmote()

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        UCam.trackConnection(humanoid.Died:Connect(function()
            if character == watchedCharacter then
                UCam.stopEmote()
            end
        end), "Emotes:Died")

        -- Caminar o saltar corta el baile (opcional). Se usa Running en vez
        -- de un loop por frame: el juego ya emite estos cambios.
        UCam.trackConnection(humanoid.Running:Connect(function(speed)
            if E.CancelOnMove and E._track and speed > 1 then
                UCam.stopEmote()
            end
        end), "Emotes:Running")

        UCam.trackConnection(humanoid.Jumping:Connect(function()
            if E.CancelOnMove and E._track then
                UCam.stopEmote()
            end
        end), "Emotes:Jumping")
    end

    -- El juego puede cambiar de personaje sin respawnear, cambiando el
    -- atributo "Character" (panel de seleccion). Se corta el baile viejo
    -- y, con AutoPlay, empieza el del nuevo.
    UCam.trackConnection(character:GetAttributeChangedSignal("Character"):Connect(function()
        UCam.stopEmote()
        maybeAutoPlay(character)
    end), "Emotes:CharacterAttribute")

    maybeAutoPlay(character)
    return true
end

-- ============================================================
-- CONEXIONES DEL JUGADOR LOCAL
-- ============================================================
UCam.trackConnection(UCam.player.CharacterAdded:Connect(function(character)
    task.defer(function()
        UCam.attachEmoteCharacter(character)
    end)
end), "Emotes:CharacterAdded")

UCam.trackConnection(UCam.player.CharacterRemoving:Connect(function()
    UCam.stopEmote()
end), "Emotes:CharacterRemoving")

-- Si el script se inyecta a mitad de ronda, el personaje ya existe.
task.defer(function()
    local character = UCam.player.Character
    if character then
        UCam.attachEmoteCharacter(character)
    end
end)
