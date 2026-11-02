-- ============================================================
-- Universal Camera Pro v13.6 · visuals/25_slowmo
-- Camara lenta local: reduce la velocidad de las animaciones que
-- se reproducen en este cliente.
--
-- No es un time-scale del juego: el servidor, la fisica y los demas
-- jugadores siguen a velocidad normal. Tampoco toca WalkSpeed ni
-- JumpPower, asi que en animaciones de caminar/correr puede notarse
-- el deslizamiento. Sirve para revisar emotes y preparar tomas.
--
-- IMPORTANTE: el Animate del juego llama AdjustSpeed en CADA Heartbeat
-- para las animaciones de caminar/correr. Por eso la escala se aplica en
-- PreRender (despues de todos los Heartbeat y antes de dibujar): si se
-- aplicara en Heartbeat, el juego la pisaria en el mismo frame y solo se
-- veria un parpadeo. El Animator es el mismo, no se modifica el juego.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua.
-- Expone (UCam.*):
--   SlowMotion (estado en 00_config),
--   setSlowMotionEnabled, setSlowMotionScale, setSlowMotionScope,
--   getSlowMotionStatus, stopSlowMotion
-- ============================================================
local UCam = _G.UCam
local S = UCam.SlowMotion

-- Registro de Animators del workspace. Es una tabla debil: si un
-- personaje se destruye, no lo retenemos en memoria.
local animators = setmetatable({}, { __mode = "k" })

local function addAnimator(inst)
    if inst and inst:IsA("Animator") then
        animators[inst] = true
    end
end

-- El juego carga animaciones tanto en rigs con Humanoid como en rigs
-- con AnimationController (AnimationSerivce.RegisterAnimation soporta
-- ambos), y en personajes con huesos el Animator vive en el Humanoid.
-- Se busca por clase, sin asumir la jerarquia.
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

local function localAnimator()
    return animatorOf(UCam.player and UCam.player.Character)
end

local function eachTrack(animator, fn)
    local ok, tracks = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok or type(tracks) ~= "table" then return end
    for _, track in ipairs(tracks) do
        fn(track)
    end
end

--- Aplica la escala a las animaciones de un Animator.
-- Guarda la velocidad original de cada track la primera vez que lo ve,
-- para poder restaurarla al desactivar o al cambiar de alcance.
local function applyTo(animator, scale)
    local count = 0
    eachTrack(animator, function(track)
        local base = S._baseSpeed[track]
        if base == nil then
            base = tonumber(track.Speed) or 1
            S._baseSpeed[track] = base
        end

        local target = base * scale
        if math.abs((tonumber(track.Speed) or 1) - target) > 0.001 then
            pcall(function()
                track:AdjustSpeed(target)
            end)
        end
        count = count + 1
    end)
    return count
end

local function restoreAll()
    for track, base in pairs(S._baseSpeed) do
        pcall(function()
            track:AdjustSpeed(base)
        end)
    end
    table.clear(S._baseSpeed)
    S._applied = 0
end

local function apply()
    if not S.Enabled then return end

    local scale = math.clamp(tonumber(S.Scale) or 0.5, 0.1, 1)
    local count = 0

    if S.Scope == S.Scopes[2] then
        local animator = localAnimator()
        if animator then
            count = applyTo(animator, scale)
        end
    else
        local seen = {}
        for animator in pairs(animators) do
            if animator.Parent then
                seen[animator] = true
                count = count + applyTo(animator, scale)
            else
                animators[animator] = nil
            end
        end

        -- Por si el Animator local todavia no estaba registrado. Se evita
        -- contarlo dos veces cuando ya vino del registro.
        local localOne = localAnimator()
        if localOne and not seen[localOne] then
            count = count + applyTo(localOne, scale)
        end
    end

    S._applied = count
end

-- ============================================================
-- API
-- ============================================================
function UCam.setSlowMotionEnabled(enabled)
    S.Enabled = enabled == true
    if S.Enabled then
        apply()
    else
        restoreAll()
    end
    return S.Enabled
end

function UCam.setSlowMotionScale(scale)
    S.Scale = math.clamp(tonumber(scale) or 0.5, 0.1, 1)
    if S.Enabled then
        apply()
    end
    return S.Scale
end

function UCam.setSlowMotionScope(scope)
    if scope == S.Scopes[2] then
        S.Scope = S.Scopes[2]
    else
        S.Scope = S.Scopes[1]
    end

    if S.Enabled then
        -- Al cambiar de alcance se devuelven todas las animaciones a su
        -- velocidad original antes de aplicar el nuevo conjunto.
        restoreAll()
        apply()
    end
    return S.Scope
end

function UCam.getSlowMotionStatus()
    return {
        enabled = S.Enabled,
        scale   = S.Scale,
        scope   = S.Scope,
        tracks  = S._applied or 0,
    }
end

function UCam.stopSlowMotion()
    S.Enabled = false
    S._timer = 0
    restoreAll()
end

-- ============================================================
-- REGISTRO Y LOOP
-- ============================================================
UCam.trackConnection(
    workspace.DescendantAdded:Connect(addAnimator),
    "SlowMotion:AnimatorAdded"
)

-- PreRender corre despues de Heartbeat (donde el Animate del juego ajusta
-- la velocidad de walk/run) y antes de dibujar: nuestro valor es el que se
-- ve. Solo hace trabajo real mientras la camara lenta esta activada, y por
-- track solo escribe si la velocidad actual no coincide con la objetivo.
UCam.trackConnection(
    UCam.RunService.PreRender:Connect(function()
        if not S.Enabled then return end
        apply()
    end),
    "SlowMotion:PreRender"
)

-- El barrido inicial se difiere para no sumar trabajo al arranque.
task.defer(function()
    pcall(function()
        for _, desc in ipairs(workspace:GetDescendants()) do
            addAnimator(desc)
        end
    end)
end)
