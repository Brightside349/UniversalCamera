-- ============================================================
-- Universal Camera Pro v8 · 06_i18n
-- Sistema multi-idioma. Tablas por locale, función T(key), y
-- selector persistente via 05_persistence.
--
-- Dependencias: 00_config
-- Expone (UCam.*):
--   Locale, Locales (es/en/pt), T(key), setLocale(code),
--   getAvailableLocales(), getLocaleDisplayName(code)
--
-- Uso:
--   local T = UCam.T
--   Tab:CreateButton({ Name = T("inicio.camara_libre"), ... })
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- LOCALES
-- ============================================================
local es = {
    -- Meta
    _lang_name        = "Español",
    _lang_english     = "Spanish",

    -- Nombre del window
    window_title      = "Universal Camera Pro v8 Por Cocoa Feliz",
    window_loading    = "Cargando interfaz v8...",

    -- Tab Inicio
    tab_inicio        = "🎬 Inicio",
    inicio_section1   = "Cámara Libre",
    inicio_toggle_cam = "Activar / Desactivar Cámara",
    inicio_hide_hud   = "Ocultar HUD",
    inicio_hide_char  = "Ocultar Mi Personaje",
    inicio_auto_hud   = "Auto-ocultar HUD con cámara libre (v6)",
    inicio_quick      = "Acciones rápidas",
    inicio_screenshot = "Captura de pantalla (ocultar UI 3s)",
    inicio_tp_cam     = "Teletransportar cámara al personaje",
    inicio_reset_all  = "Restablecer todos los valores",

    -- Tab Cámaras
    tab_camaras       = "📷 Cámaras",
    camaras_mode      = "Modo de cámara",
    camaras_speed     = "Velocidad",
    camaras_smooth    = "Suavizado",
    camaras_fov       = "FOV",

    -- Tab Espectador
    tab_espectador    = "👁️ Espectador",
    espectador_target = "Jugador objetivo",
    espectador_mode   = "Modo de cámara",
    espectador_next   = "Siguiente (E)",
    espectador_prev   = "Anterior (Q)",
    espectador_stop   = "Dejar de espectar (X)",



    -- Tab Cinemática
    tab_cinematic     = "🎬 Cinemática",

    -- Tab Filtros
    tab_filters       = "🎨 Filtros",

    -- Tab Iluminación
    tab_light         = "💡 Iluminación",

    -- Tab Estudio
    tab_estudio       = "🎥 Estudio",

    -- Tab Gimbal
    tab_gimbal        = "🔒 Gimbal",

    -- Tab Fun
    tab_fun           = "🎉 Divertido",

    -- Tab Cuerpo
    tab_bodycolor     = "🎨 Cuerpo",

    -- Tab Poses
    tab_poses         = "🧍 Poses",

    -- Tab Mod Jugadores
    tab_playermod     = "👥 Jugadores",

    -- Tab Replay
    tab_replay        = "🎬 Replay",

    -- Tab Perfiles (v8)
    tab_profiles      = "📁 Perfiles",

    -- Tab Plugins (v8)
    tab_plugins       = "🧩 Plugins",

    -- Tab Config
    tab_config        = "⚙️ Config",

    -- Tab Info
    tab_info          = "ℹ️ Info",

    -- Notificaciones genéricas
    notify_ready      = "Listo",
    notify_error      = "Error",
    notify_warning    = "Aviso",
    notify_loaded     = "Cargado",
    notify_saved      = "Guardado",

    -- Persistencia
    persist_saved     = "Configuración guardada en disco.",
    persist_loaded    = "Configuración cargada desde disco.",
    persist_unavail   = "writefile/readfile no disponibles. La config no persistirá.",

    -- Perfiles
    profiles_saved    = "Perfil guardado.",
    profiles_loaded   = "Perfil aplicado.",
    profiles_deleted  = "Perfil eliminado.",
    profiles_empty    = "Ranura vacía.",
    profiles_exported = "Perfil exportado al portapapeles.",
    profiles_imported = "Perfil importado.",
}

-- ============================================================
local en = {
    _lang_name        = "English",
    _lang_english     = "English",

    window_title      = "Universal Camera Pro v8 By Cocoa Feliz",
    window_loading    = "Loading v8 interface...",

    tab_inicio        = "🎬 Home",
    inicio_section1   = "Free Camera",
    inicio_toggle_cam = "Toggle Free Cam",
    inicio_hide_hud   = "Hide HUD",
    inicio_hide_char  = "Hide My Character",
    inicio_auto_hud   = "Auto-hide HUD with free cam (v6)",
    inicio_quick      = "Quick actions",
    inicio_screenshot = "Screenshot (hide UI 3s)",
    inicio_tp_cam     = "Teleport camera to character",
    inicio_reset_all  = "Reset all values",

    tab_camaras       = "📷 Cameras",
    camaras_mode      = "Camera mode",
    camaras_speed     = "Speed",
    camaras_smooth    = "Smoothing",
    camaras_fov       = "FOV",

    tab_espectador    = "👁️ Spectate",
    espectador_target = "Target player",
    espectador_mode   = "Camera mode",
    espectador_next   = "Next (E)",
    espectador_prev   = "Previous (Q)",
    espectador_stop   = "Stop spectating (X)",



    tab_cinematic     = "🎬 Cinematic",
    tab_filters       = "🎨 Filters",
    tab_light         = "💡 Lighting",
    tab_estudio       = "🎥 Studio",
    tab_gimbal        = "🔒 Gimbal",
    tab_fun           = "🎉 Fun",
    tab_bodycolor     = "🎨 Body",
    tab_poses         = "🧍 Poses",
    tab_playermod     = "👥 Players",
    tab_replay        = "🎬 Replay",
    tab_profiles      = "📁 Profiles",
    tab_plugins       = "🧩 Plugins",
    tab_config        = "⚙️ Settings",
    tab_info          = "ℹ️ Info",

    notify_ready      = "Ready",
    notify_error      = "Error",
    notify_warning    = "Warning",
    notify_loaded     = "Loaded",
    notify_saved      = "Saved",

    persist_saved     = "Configuration saved to disk.",
    persist_loaded    = "Configuration loaded from disk.",
    persist_unavail   = "writefile/readfile not available. Config will not persist.",

    profiles_saved    = "Profile saved.",
    profiles_loaded   = "Profile applied.",
    profiles_deleted  = "Profile deleted.",
    profiles_empty    = "Empty slot.",
    profiles_exported = "Profile exported to clipboard.",
    profiles_imported = "Profile imported.",
}

-- ============================================================
local pt = {
    _lang_name        = "Português",
    _lang_english     = "Portuguese",

    window_title      = "Universal Camera Pro v8 Por Cocoa Feliz",
    window_loading    = "Carregando interface v8...",

    tab_inicio        = "🎬 Início",
    inicio_section1   = "Câmera Livre",
    inicio_toggle_cam = "Ativar / Desativar Câmera",
    inicio_hide_hud   = "Ocultar HUD",
    inicio_hide_char  = "Ocultar Meu Personagem",
    inicio_auto_hud   = "Auto-ocultar HUD com câmera livre (v6)",
    inicio_quick      = "Ações rápidas",
    inicio_screenshot = "Captura de tela (ocultar UI 3s)",
    inicio_tp_cam     = "Teletransportar câmera para o personagem",
    inicio_reset_all  = "Restaurar todos os valores",

    tab_camaras       = "📷 Câmeras",
    camaras_mode      = "Modo de câmera",
    camaras_speed     = "Velocidade",
    camaras_smooth    = "Suavização",
    camaras_fov       = "FOV",

    tab_espectador    = "👁️ Espectador",
    espectador_target = "Jogador alvo",
    espectador_mode   = "Modo de câmera",
    espectador_next   = "Próximo (E)",
    espectador_prev   = "Anterior (Q)",
    espectador_stop   = "Parar de assistir (X)",



    tab_cinematic     = "🎬 Cinemático",
    tab_filters       = "🎨 Filtros",
    tab_light         = "💡 Iluminação",
    tab_estudio       = "🎥 Estúdio",
    tab_gimbal        = "🔒 Gimbal",
    tab_fun           = "🎉 Diversão",
    tab_bodycolor     = "🎨 Corpo",
    tab_poses         = "🧍 Poses",
    tab_playermod     = "👥 Jogadores",
    tab_replay        = "🎬 Replay",
    tab_profiles      = "📁 Perfis",
    tab_plugins       = "🧩 Plugins",
    tab_config        = "⚙️ Configurações",
    tab_info          = "ℹ️ Info",

    notify_ready      = "Pronto",
    notify_error      = "Erro",
    notify_warning    = "Aviso",
    notify_loaded     = "Carregado",
    notify_saved      = "Salvo",

    persist_saved     = "Configuração salva em disco.",
    persist_loaded    = "Configuração carregada do disco.",
    persist_unavail   = "writefile/readfile não disponíveis. Config não persistirá.",

    profiles_saved    = "Perfil salvo.",
    profiles_loaded   = "Perfil aplicado.",
    profiles_deleted  = "Perfil deletado.",
    profiles_empty    = "Slot vazio.",
    profiles_exported = "Perfil exportado para a área de transferência.",
    profiles_imported = "Perfil importado.",
}

-- ============================================================
-- REGISTRO
-- ============================================================
UCam.Locales = { es = es, en = en, pt = pt }

-- Idioma activo (se lee de config persistida al arrancar)
UCam.Locale = UCam.Locale or "es"

-- ============================================================
-- API
-- ============================================================

--- Devuelve el string traducido. Si no existe, fallback a es/en/code.
-- UCam.T("tab_inicio") → "🎬 Inicio"
function UCam.T(key)
    local locales = UCam.Locales
    if not locales then return key end
    local tbl = locales[UCam.Locale]
    if tbl and tbl[key] then return tbl[key] end
    -- Fallback al inglés
    local en = locales.en
    if en and en[key] then return en[key] end
    -- Fallback al español
    local es = locales.es
    if es and es[key] then return es[key] end
    return key
end

--- Cambia el idioma en caliente. Persiste via scheduleSave.
function UCam.setLocale(code)
    if not UCam.Locales[code] then
        warn(("[UCam] Locale '%s' no válido. Disponibles: es, en, pt"):format(tostring(code)))
        return false
    end
    UCam.Locale = code
    if UCam.scheduleSave then pcall(UCam.scheduleSave) end
    UCam.notify("Idioma", ("Idioma → %s\n(Reinicia para recargar toda la UI)"):format(
        UCam.Locales[code]._lang_name))
    return true
end

function UCam.getAvailableLocales()
    return { "es", "en", "pt" }
end

function UCam.getLocaleDisplayName(code)
    local t = UCam.Locales[code]
    return t and t._lang_name or tostring(code)
end

print("[UCam] i18n cargado — idiomas disponibles: es, en, pt. Activo: " .. UCam.Locale)
