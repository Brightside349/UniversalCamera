-- ============================================================
-- Universal Camera Pro v8 · 57_profiles
-- Perfiles completos: guarda/carga/aplica TODO el setup (cámara,
-- filtros, lighting, postprocesado, slow-mo, time control, fun).
-- 8 slots nombrables + 3 quick-slots con hotkeys.
-- Export/Import Base64 + persistencia en disco via 05_persistence.
--
-- Dependencias: 00_config, 05_persistence (opcional pero ideal)
-- Expone (UCam.*):
--   Profiles (tabla), saveProfile, loadProfile, deleteProfile,
--   renameProfile, quickSaveProfile, quickLoadProfile,
--   exportProfile, importProfile, listProfiles
-- ============================================================
local UCam = _G.UCam

local HttpService = game:GetService("HttpService")

-- ============================================================
-- ESTADO
-- ============================================================
UCam.Profiles = {
    Slots      = {},           -- { [1..8] = { name, data, savedAt } }
    QuickSlots = {},           -- { [1..3] = slotIndex1to8 }
    MaxSlots   = 8,
    MaxQuick   = 3,
}

local SCHEMA_PROFILE = {
    Persist   = true,
    DoSave    = true,
    HasFS     = UCam.HasFileSystem,
    SlotCount = 8,
    QuickCount = 3,
}

-- ============================================================
-- SNAPSHOT: captura TODO el estado relevante de UCam
-- ============================================================
local function captureState()
    local S = {}
    -- Cámara
    S.camMode              = UCam.camMode
    S.currentSpeed         = UCam.currentSpeed
    S.MOUSE_SENSITIVITY    = UCam.MOUSE_SENSITIVITY
    S.SPRINT_MULTIPLIER    = UCam.SPRINT_MULTIPLIER
    S.currentFilterIndex   = UCam.currentFilterIndex
    S.dutchRoll            = UCam.dutchRoll

    -- Modos de cámara
    S.Orbit    = { Distance=UCam.Orbit.Distance, Height=UCam.Orbit.Height, Speed=UCam.Orbit.Speed }
    S.Follow   = { Distance=UCam.Follow.Distance, Height=UCam.Follow.Height, SideOffset=UCam.Follow.SideOffset }
    S.Lateral  = { Distance=UCam.Lateral.Distance, Height=UCam.Lateral.Height }
    S.CrashZoom= { EndFOV=UCam.CrashZoom.EndFOV, Duration=UCam.CrashZoom.Duration }
    S.Vertigo  = { MinDistance=UCam.Vertigo.MinDistance, MaxDistance=UCam.Vertigo.MaxDistance,
                   Speed=UCam.Vertigo.Speed, BaseFOV=UCam.Vertigo.BaseFOV }
    S.Crane    = { Height=UCam.Crane.Height, MinHeight=UCam.Crane.MinHeight, MaxHeight=UCam.Crane.MaxHeight,
                   SpinSpeed=UCam.Crane.SpinSpeed }
    S.Dolly    = { Distance=UCam.Dolly.Distance }
    S.Handheld = { Intensity=UCam.Handheld.Intensity, Frequency=UCam.Handheld.Frequency, Roll=UCam.Handheld.Roll }
    S.RollAxis = { Speed=UCam.RollAxis.Speed, Direction=UCam.RollAxis.Direction }
    S.FPVDrone = { Inertia=UCam.FPVDrone.Inertia, RollSpeed=UCam.FPVDrone.RollSpeed, MaxRoll=UCam.FPVDrone.MaxRoll }
    S.Snorricam= { Distance=UCam.Snorricam.Distance, HeightOffset=UCam.Snorricam.HeightOffset }
    S.SecurityCam= { PanSpeed=UCam.SecurityCam.PanSpeed, PanAngle=UCam.SecurityCam.PanAngle }

    -- Keybinds
    S.Keybinds = {}
    for k, v in pairs(UCam.Keybinds) do
        -- v8.1 FIX: v puede ser EnumItem (enum.KeyCode) → JSONEncode explota.
        -- Convertir siempre a su nombre (string).
        S.Keybinds[k] = (typeof(v) == "EnumItem") and v.Name or v
    end

    -- Cinematic / post-procesado
    S.Letterbox       = { HeightRatio = UCam.Letterbox.HeightRatio }
    S.Bloom           = { Intensity=UCam.Bloom.Intensity, Size=UCam.Bloom.Size, Threshold=UCam.Bloom.Threshold }
    S.DOF             = { FarIntensity=UCam.DOF.FarIntensity, FocusDistance=UCam.DOF.FocusDistance, InFocusRadius=UCam.DOF.InFocusRadius }
    S.SunRays         = { Intensity=UCam.SunRays.Intensity, Spread=UCam.SunRays.Spread }
    S.Vignette        = { Intensity=UCam.Vignette.Intensity, Smoothness=UCam.Vignette.Smoothness,
                          Color = { r=UCam.Vignette.Color.R, g=UCam.Vignette.Color.G, b=UCam.Vignette.Color.B } }
    S.Shake           = { Intensity=UCam.Shake.Intensity, Pattern=UCam.Shake.Pattern }
    S.FovPulse        = { Amplitude=UCam.FovPulse.Amplitude, Speed=UCam.FovPulse.Speed }

    -- Filtros custom (deep copy simple)
    S.CustomFilters = {}
    for i, f in ipairs(UCam.CustomFilters) do
        S.CustomFilters[i] = {}
        for k, v in pairs(f) do
            local tv = type(v)
            if tv == "number" or tv == "string" or tv == "boolean" then
                S.CustomFilters[i][k] = v
            elseif tv == "table" and v.r and v.g and v.b then
                S.CustomFilters[i][k] = { r=v.r, g=v.g, b=v.b }
            end
        end
    end
    S.FilterTransition = { Enabled=UCam.FilterTransition.Enabled, Speed=UCam.FilterTransition.Speed }
    S.FilterCombine    = { Enabled=UCam.FilterCombine.Enabled, IndexA=UCam.FilterCombine.IndexA,
                           IndexB=UCam.FilterCombine.IndexB, Mix=UCam.FilterCombine.Mix }

    -- v8.1: Módulos eliminados (SlowMo, TimeControl) ya no se guardan en perfiles
    
    -- Espectador
    S.Spectate = {
        Mode=UCam.Spectate.Mode, Smoothing=UCam.Spectate.Smoothing, Distance=UCam.Spectate.Distance,
        Height=UCam.Spectate.Height, FOV=UCam.Spectate.FOV, UseCustomFOV=UCam.Spectate.UseCustomFOV,
        HideSelf=UCam.Spectate.HideSelf, AntiClip=UCam.Spectate.AntiClip, AutoJump=UCam.Spectate.AutoJump,
        ZoomScroll=UCam.Spectate.ZoomScroll, OnlyFavorites=UCam.Spectate.OnlyFavorites,
    }

    -- Auto-HUD / Gimbal
    S.AutoHUD    = { Enabled = UCam.AutoHUD.Enabled }
    S.LookAtLock = { Smoothing = UCam.LookAtLock.Smoothing, HeightOffset = UCam.LookAtLock.HeightOffset }

    -- Lighting tweaks
    local L = UCam.LightingTweaks
    S.LightingTweaks = {
        Enabled=L.Enabled, ClockTime=L.ClockTime, ExposureCompensation=L.ExposureCompensation,
        FogColor={r=L.FogColor.R, g=L.FogColor.G, b=L.FogColor.B},
        FogStart=L.FogStart, FogEnd=L.FogEnd,
        OutdoorAmbient={r=L.OutdoorAmbient.R, g=L.OutdoorAmbient.G, b=L.OutdoorAmbient.B},
        Ambient={r=L.Ambient.R, g=L.Ambient.G, b=L.Ambient.B},
        Brightness=L.Brightness, ShadowsEnabled=L.ShadowsEnabled, ShadowIntensity=L.ShadowIntensity,
        SkyboxAssetId=L.SkyboxAssetId,
    }

    -- Fun (parámetros que el usuario ajusta)
    local F = UCam.Fun
    S.Fun = {
        Gravity    = { Mode=F.Gravity.Mode, Custom=F.Gravity.Custom },
        SuperJump  = { Power=F.SuperJump.Power },
        SpeedBoost = { WalkSpeed=F.SpeedBoost.WalkSpeed },
        BodySpin   = { Speed=F.BodySpin.Speed, Axis=F.BodySpin.Axis },
        Rainbow    = { Speed=F.Rainbow.Speed },
        Trail      = { Width=F.Trail.Width, Duration=F.Trail.Duration,
                       Color = (F.Trail.Color and F.Trail.Color.R) and {r=F.Trail.Color.R, g=F.Trail.Color.G, b=F.Trail.Color.B} or nil,
                       Type=F.Trail.Type, Rainbow=F.Trail.Rainbow, Painting=F.Trail.Painting },
        Disco      = { Size=F.Disco.Size, Shape=F.Disco.Shape, AnimatedLights=F.Disco.AnimatedLights, Mirror=F.Disco.Mirror,
                       Color = (F.Disco.Color and F.Disco.Color.R) and {r=F.Disco.Color.R, g=F.Disco.Color.G, b=F.Disco.Color.B} or nil },
        Particles  = { Type=F.Particles.Type, Intensity=F.Particles.Intensity,
                       Color = (F.Particles.Color and F.Particles.Color.R) and {r=F.Particles.Color.R, g=F.Particles.Color.G, b=F.Particles.Color.B} or nil },
        Fly        = { Speed=F.Fly.Speed },
    }

    -- CamCore
    S.CamCore = {
        SmoothZoom=UCam.CamCore.SmoothZoom, ZoomSpeed=UCam.CamCore.ZoomSpeed,
        AutoExposure=UCam.CamCore.AutoExposure, MotionBlur=UCam.CamCore.MotionBlur, MBAmount=UCam.CamCore.MBAmount,
    }

    -- Waypoint/Director
    S.Waypoint = {
        Duration=UCam.Waypoint.Duration, Loop=UCam.Waypoint.Loop, Easing=UCam.Waypoint.Easing,
        UseFOV=UCam.Waypoint.UseFOV, FOV=UCam.Waypoint.FOV, UseRoll=UCam.Waypoint.UseRoll, Roll=UCam.Waypoint.Roll,
        CurveMode=UCam.Waypoint.CurveMode, PreviewArrows=UCam.Waypoint.PreviewArrows,
    }

    -- Replay (solo settings, no frames)
    S.Replay = {
        MaxDuration=UCam.Replay.MaxDuration, PlaybackSpeed=UCam.Replay.PlaybackSpeed, Loop=UCam.Replay.Loop,
    }

    return S
end

-- ============================================================
-- APLICAR estado restaurado a UCam (sin pisar estructuras dinámicas)
-- ============================================================
local function applyState(S)
    if not S then return end
    local function T(k, v) if v ~= nil then UCam[k] = v end end

    -- Cámara
    if S.camMode then UCam.camMode = S.camMode end
    if S.currentSpeed then UCam.currentSpeed = UCam.clamp(S.currentSpeed, UCam.SLIDER_MIN_SPEED, UCam.SLIDER_MAX_SPEED) end
    if S.MOUSE_SENSITIVITY then UCam.MOUSE_SENSITIVITY = S.MOUSE_SENSITIVITY end
    if S.SPRINT_MULTIPLIER then UCam.SPRINT_MULTIPLIER = S.SPRINT_MULTIPLIER end
    if S.currentFilterIndex then UCam.currentFilterIndex = S.currentFilterIndex end
    if S.dutchRoll then UCam.dutchRoll = S.dutchRoll end

    -- Modos de cámara
    local function mergeTable(tbl, data) if data then for k,v in pairs(data) do if tbl[k] ~= nil then tbl[k] = v end end end end

    mergeTable(UCam.Orbit,    S.Orbit)
    mergeTable(UCam.Follow,   S.Follow)
    mergeTable(UCam.Lateral,  S.Lateral)
    mergeTable(UCam.CrashZoom,S.CrashZoom)
    mergeTable(UCam.Vertigo,  S.Vertigo)
    mergeTable(UCam.Crane,    S.Crane)
    mergeTable(UCam.Dolly,    S.Dolly)
    mergeTable(UCam.Handheld, S.Handheld)
    mergeTable(UCam.RollAxis, S.RollAxis)
    mergeTable(UCam.FPVDrone, S.FPVDrone)
    mergeTable(UCam.Snorricam,S.Snorricam)
    mergeTable(UCam.SecurityCam,S.SecurityCam)

    if S.Keybinds then mergeTable(UCam.Keybinds, S.Keybinds) end

    -- Cinematic / post-procesado
    mergeTable(UCam.Letterbox, S.Letterbox)
    mergeTable(UCam.Bloom,      S.Bloom)
    mergeTable(UCam.DOF,        S.DOF)
    mergeTable(UCam.SunRays,    S.SunRays)
    if S.Vignette then
        mergeTable(UCam.Vignette, S.Vignette)
        if S.Vignette.Color then
            UCam.Vignette.Color = Color3.new(S.Vignette.Color.r, S.Vignette.Color.g, S.Vignette.Color.b)
        end
    end
    mergeTable(UCam.Shake,      S.Shake)
    mergeTable(UCam.FovPulse,   S.FovPulse)

    -- Filtros custom (reemplazo completo)
    if S.CustomFilters then
        UCam.CustomFilters = {}
        for i, f in ipairs(S.CustomFilters) do
            local nf = {}
            for k, v in pairs(f) do
                if k == "TintColor" and type(v) == "table" then
                    nf[k] = Color3.new(v.r, v.g, v.b)
                else
                    nf[k] = v
                end
            end
            UCam.CustomFilters[i] = nf
        end
    end
    mergeTable(UCam.FilterTransition, S.FilterTransition)
    mergeTable(UCam.FilterCombine,    S.FilterCombine)

    -- v8.1: SlowMo / TimeControl eliminados — ya no se restauran en perfiles

    -- Espectador
    mergeTable(UCam.Spectate,    S.Spectate)

    -- Auto-HUD / Gimbal
    mergeTable(UCam.AutoHUD,     S.AutoHUD)
    mergeTable(UCam.LookAtLock,  S.LookAtLock)

    -- Lighting
    if S.LightingTweaks then
        local L = S.LightingTweaks
        local LT = UCam.LightingTweaks
        if L.Enabled            ~= nil then LT.Enabled            = L.Enabled end
        if L.ClockTime          ~= nil then LT.ClockTime          = L.ClockTime end
        if L.ExposureCompensation~=nil then LT.ExposureCompensation = L.ExposureCompensation end
        if L.FogColor then LT.FogColor = Color3.new(L.FogColor.r, L.FogColor.g, L.FogColor.b) end
        if L.FogStart           ~= nil then LT.FogStart           = L.FogStart end
        if L.FogEnd             ~= nil then LT.FogEnd             = L.FogEnd end
        if L.OutdoorAmbient then LT.OutdoorAmbient = Color3.new(L.OutdoorAmbient.r, L.OutdoorAmbient.g, L.OutdoorAmbient.b) end
        if L.Ambient then LT.Ambient = Color3.new(L.Ambient.r, L.Ambient.g, L.Ambient.b) end
        if L.Brightness        ~= nil then LT.Brightness        = L.Brightness end
        if L.ShadowsEnabled    ~= nil then LT.ShadowsEnabled    = L.ShadowsEnabled end
        if L.ShadowIntensity   ~= nil then LT.ShadowIntensity   = L.ShadowIntensity end
        if L.SkyboxAssetId     ~= nil then LT.SkyboxAssetId     = L.SkyboxAssetId end
        -- Re-aplicar inmediatamente si está activo
        if UCam.applyLightingTweaks then
            pcall(UCam.applyLightingTweaks)
        end
    end

    -- Fun
    if S.Fun then
        local F = UCam.Fun
        if S.Fun.Gravity   then F.Gravity.Mode   = S.Fun.Gravity.Mode;   F.Gravity.Custom   = S.Fun.Gravity.Custom end
        if S.Fun.SuperJump and S.Fun.SuperJump.Power then F.SuperJump.Power = S.Fun.SuperJump.Power end
        if S.Fun.SpeedBoost and S.Fun.SpeedBoost.WalkSpeed then F.SpeedBoost.WalkSpeed = S.Fun.SpeedBoost.WalkSpeed end
        if S.Fun.BodySpin  then F.BodySpin.Speed = S.Fun.BodySpin.Speed; F.BodySpin.Axis = S.Fun.BodySpin.Axis end
        if S.Fun.Rainbow   and S.Fun.Rainbow.Speed then F.Rainbow.Speed = S.Fun.Rainbow.Speed end
        if S.Fun.Trail then
            local T = F.Trail; local TR = S.Fun.Trail
            if TR.Width     then T.Width     = TR.Width end
            if TR.Duration  then T.Duration  = TR.Duration end
            if TR.Type      then T.Type      = TR.Type end
            if TR.Rainbow   ~= nil then T.Rainbow   = TR.Rainbow end
            if TR.Painting  ~= nil then T.Painting  = TR.Painting end
            if TR.Color then T.Color = Color3.new(TR.Color.r, TR.Color.g, TR.Color.b) end
        end
        if S.Fun.Disco then
            local D = F.Disco; local DI = S.Fun.Disco
            if DI.Size    then D.Size    = DI.Size end
            if DI.Shape   then D.Shape   = DI.Shape end
            if DI.AnimatedLights ~= nil then D.AnimatedLights = DI.AnimatedLights end
            if DI.Mirror  ~= nil then D.Mirror  = DI.Mirror end
            if DI.Color then D.Color = Color3.new(DI.Color.r, DI.Color.g, DI.Color.b) end
        end
        if S.Fun.Particles then
            local P = F.Particles; local PA = S.Fun.Particles
            if PA.Type      then P.Type      = PA.Type end
            if PA.Intensity then P.Intensity = PA.Intensity end
            if PA.Color then P.Color = Color3.new(PA.Color.r, PA.Color.g, PA.Color.b) end
        end
        if S.Fun.Fly and S.Fun.Fly.Speed then F.Fly.Speed = S.Fun.Fly.Speed end
    end

    -- CamCore
    mergeTable(UCam.CamCore, S.CamCore)

    -- Waypoint
    mergeTable(UCam.Waypoint, S.Waypoint)

    -- Replay
    mergeTable(UCam.Replay, S.Replay)

    -- Forzar refresh de UI si existe
    if UCam.UIRefs and UCam.UIRefs.FilterDropdown and UCam.UIRefs.FilterDropdown.Refresh then
        pcall(function() UCam.UIRefs.FilterDropdown:Refresh() end)
    end
end

-- ============================================================
-- SERIALIZACIÓN (compacta: JSON → Base64)
-- ============================================================
local function serializeState(state)
    local ok, json = pcall(function() return HttpService:JSONEncode(state) end)
    if not ok then return nil, "JSONEncode falló: " .. tostring(json) end
    return HttpService:Base64Encode(json)
end

local function deserializeState(base64)
    local ok1, json = pcall(function() return HttpService:Base64Decode(base64) end)
    if not ok1 then return nil, "Base64Decode falló" end
    local ok2, tbl = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok2 or type(tbl) ~= "table" then return nil, "JSONDecode falló o no es tabla" end
    return tbl
end

-- ============================================================
-- API PRINCIPAL: SAVE / LOAD / DELETE / RENAME
-- ============================================================
function UCam.saveProfile(slot, customName)
    slot = math.clamp(math.floor(slot or 1), 1, SCHEMA_PROFILE.SlotCount)
    local name = customName or ("Perfil %d"):format(slot)
    local state = captureState()
    state._slot    = slot
    state._name    = name
    state._savedAt = os.time()
    UCam.Profiles.Slots[slot] = state
    UCam.notify("Perfiles", ("Perfil %d guardado: %s"):format(slot, name))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.loadProfile(slot)
    slot = math.clamp(math.floor(slot or 1), 1, SCHEMA_PROFILE.SlotCount)
    local state = UCam.Profiles.Slots[slot]
    if not state then
        UCam.notify("Perfiles", ("Ranura %d vacía."):format(slot))
        return false
    end
    applyState(state)
    UCam.notify("Perfiles", ("Perfil %d aplicado: %s"):format(slot, state._name or "?"))
    return true
end

function UCam.deleteProfile(slot)
    slot = math.clamp(math.floor(slot or 1), 1, SCHEMA_PROFILE.SlotCount)
    if not UCam.Profiles.Slots[slot] then
        UCam.notify("Perfiles", ("Ranura %d ya estaba vacía."):format(slot))
        return false
    end
    UCam.Profiles.Slots[slot] = nil
    -- Limpiar quick-slots que apunten a esta
    for q, target in pairs(UCam.Profiles.QuickSlots) do
        if target == slot then UCam.Profiles.QuickSlots[q] = nil end
    end
    UCam.notify("Perfiles", ("Ranura %d eliminada."):format(slot))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.renameProfile(slot, newName)
    slot = math.clamp(math.floor(slot or 1), 1, SCHEMA_PROFILE.SlotCount)
    local state = UCam.Profiles.Slots[slot]
    if not state then
        UCam.notify("Perfiles", ("Ranura %d vacía — nada que renombrar."):format(slot))
        return false
    end
    state._name = tostring(newName or ("Perfil %d"):format(slot))
    UCam.notify("Perfiles", ("Ranura %d renombrada a: %s"):format(slot, state._name))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

-- ============================================================
-- QUICK SLOTS (shift/ctrl/alt + 1..3 por defecto)
-- ============================================================
function UCam.quickSaveProfile(quickIndex, slotIndex)
    quickIndex = math.clamp(math.floor(quickIndex or 1), 1, SCHEMA_PROFILE.QuickCount)
    slotIndex  = math.clamp(math.floor(slotIndex or 1), 1, SCHEMA_PROFILE.SlotCount)
    if not UCam.Profiles.Slots[slotIndex] then
        UCam.notify("Perfiles", ("Primero guarda algo en la ranura %d."):format(slotIndex))
        return false
    end
    UCam.Profiles.QuickSlots[quickIndex] = slotIndex
    UCam.notify("Perfiles", ("Quick slot %d → ranura %d"):format(quickIndex, slotIndex))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

function UCam.quickLoadProfile(quickIndex)
    quickIndex = math.clamp(math.floor(quickIndex or 1), 1, SCHEMA_PROFILE.QuickCount)
    local slot = UCam.Profiles.QuickSlots[quickIndex]
    if not slot or not UCam.Profiles.Slots[slot] then
        UCam.notify("Perfiles", ("Quick slot %d vacío."):format(quickIndex))
        return false
    end
    applyState(UCam.Profiles.Slots[slot])
    UCam.notify("Perfiles", ("Quick slot %d aplicado."):format(quickIndex))
    return true
end

-- ============================================================
-- EXPORT / IMPORT (compartir entre jugadores)
-- ============================================================
function UCam.exportProfile(slot)
    slot = math.clamp(math.floor(slot or 1), 1, SCHEMA_PROFILE.SlotCount)
    local state = UCam.Profiles.Slots[slot]
    if not state then
        return nil, ("Ranura %d vacía."):format(slot)
    end
    local b64, err = serializeState(state)
    if not b64 then return nil, err end
    return b64, ("Perfil %d: %s"):format(slot, state._name or "?")
end

function UCam.importProfile(base64, targetSlot)
    local state, err = deserializeState(base64)
    if not state then
        UCam.notify("Perfiles", "Import falló: " .. tostring(err))
        return false
    end
    targetSlot = math.clamp(math.floor(targetSlot or 1), 1, SCHEMA_PROFILE.SlotCount)
    state._slot    = targetSlot
    state._name    = state._name or ("Import %d"):format(targetSlot)
    state._savedAt = os.time()
    UCam.Profiles.Slots[targetSlot] = state
    UCam.notify("Perfiles", ("Perfil importado en ranura %d."):format(targetSlot))
    if UCam.saveConfig then pcall(UCam.saveConfig) end
    return true
end

-- ============================================================
-- LISTAR / INFO
-- ============================================================
function UCam.listProfiles()
    local lines = {}
    for i = 1, SCHEMA_PROFILE.SlotCount do
        local s = UCam.Profiles.Slots[i]
        if s then
            local quick = ""
            for q, t in pairs(UCam.Profiles.QuickSlots) do
                if t == i then quick = (" [hotkey %d]"):format(q) break end
            end
            lines[#lines+1] = ("%d: %s%s"):format(i, s._name or "?", quick)
        else
            lines[#lines+1] = ("%d: (vacío)"):format(i)
        end
    end
    return table.concat(lines, "\n"), lines
end

-- ============================================================
-- NOTA: La persistencia de perfiles se hace via 05_persistence.lua
-- (campo `cfg._profiles` dentro del config_v8.json principal).
-- Este módulo solo gestiona la lógica en memoria.
-- ============================================================
print("[UCam] Perfiles listos — guardado integrado en 05_persistence.")
