-- ============================================================
-- Universal Camera Pro v8 · ui/info
-- Pestaña Info / Ayuda: documentacion de controles, modos y modulos.
-- ============================================================
local UCam = _G.UCam

function UCam.build_info(Window)
    local InfoTab = Window:CreateTab("ℹ️ Info", "info")
    InfoTab:CreateParagraph({
        Title   = "Controles basicos",
        Content =
        "Clic derecho + mouse -> rotar camara\nRueda del mouse -> zoom (FOV)\nShift -> sprint (modo Libre / Handheld)\nWASD + Espacio / Ctrl -> movimiento\nDelete -> mostrar/ocultar UI\nF -> activar camara libre\nX -> dejar de espectar\nZ -> disparar Camera Shake\nE / Q -> Siguiente / Anterior jugador (Espectar)",
    })
    InfoTab:CreateParagraph({
        Title   = "Modos de camara (18 modos)",
        Content =
        "Libre: WASD + rotacion con clic derecho.\nOrbita: gira alrededor del personaje.\nTripode: fijo, solo rotacion.\nCenital: vista de pajaro (top-down).\nLateral: side-scroller cinematico.\nDron: orbitas suaves (circulo o figura 8).\nFollow: chase cam estilo hombro.\nCrashZoom: dolly-in dramatico.\nDirector: ruta de waypoints para intros/outros.\nCrane: plano de grua (sube/baja con Space/Ctrl + giro opcional).\nDolly Glide: carril cinematico (lateral / forward / diagonal).\nHandheld: camara en mano con sacudida procedural.\nRoll Axis: rotacion continua sobre el eje forward (barrel roll).\nVertigo: dolly zoom Hitchcock - el FOV se compensa mientras la camara se acerca/aleja y el fondo se deforma.\nFPV Dron: drone acrobatico con inercia y roll extremo.\nSnorricam: camara atada al personaje mirando hacia su cara.\nCable Cam: camara restringida a una linea entre dos puntos.\nSecurity Cam: camara estatica con paneo automatico lento.",
    })
    InfoTab:CreateParagraph({
        Title   = "Como esta organizada la UI (v8)",
        Content =
        "Inicio: camara libre, ocultar HUD/personaje, auto-HUD y acciones rapidas (captura, teletransporte, restablecer todo).\nCamaras: los 18 modos y todos sus parametros agrupados por modo.\nEspectador: jugadores, auto-ciclo, estilos y FOV.\nReplay: graba el recorrido con camara libre y lo reproduce suavemente (alternativa al Director sin waypoints).\nCinematografico: letterbox, vignette, shake, FOV pulse, director y post-procesado (bloom, DOF, sun rays).\nFiltros: 30 built-in + editor custom + tus presets.\nIluminacion / Estudio / Gimbal: modulos de ambiente y bloqueo.\nDiversion: montar, fisicas, tamano, poses, aspecto y efectos visuales.\nCuerpo / Poses / Jugadores: modifica aspecto de tu personaje y otros.\nPerfiles: guarda/carga setups completos.\nAjustes: teclas + idioma.\nPlugins: extensiones cargadas de la carpeta UniversalCamera/plugins.",
    })
    InfoTab:CreateParagraph({
        Title   = "Pestana Filtros",
        Content =
        "Hay 30 filtros built-in. Ademas incluye un editor custom en vivo: ajusta Brillo, Contraste, Saturacion y el tinte RGB con sliders; presiona 'Guardar filtro custom' y asignale un nombre para anadirlo a tu coleccion. Puedes guardar hasta 12 filtros custom. En 'Mis filtros custom guardados' eliges uno para aplicarlo o eliminarlo.",
    })
    InfoTab:CreateParagraph({
        Title   = "Cinematografico (post-procesado + efectos)",
        Content =
        "Letterbox: barras 21:9.\nDutch angle: inclina la camara (en Camaras).\nBloom: brillo intenso.\nDOF: desenfoque.\nAuto-Focus DOF: enfoca automaticamente al personaje/jugador espectado o realiza raycast en camara libre.\nSun Rays: rayos volumetricos.\nVignette: oscurece los bordes para enmarcar la toma.\nCamera Shake: sutil / terremoto / explosion / pulso / impacto (toggle, one-shots y tecla Z).\nFOV Pulse: respiracion del FOV, util para horror / suspenso.\nDirector: graba waypoints y reproduce (con visualizador de ruta 3D).",
    })
    InfoTab:CreateParagraph({
        Title   = "Espectador Mejorado (9 modos)",
        Content =
        "Primera persona = ojos del jugador.\nTercera persona = detras del jugador (clic derecho para orbitar).\nCinematico = orbita automatica.\nSobre hombro = estilo shooter.\nDron aereo: vista de drone con bobbing.\nContrapicado: angulo bajo dramatico.\nDolly lateral: camara en riel lateral con sway.\nOrbita dinamica: orbita auto con cambios de distancia/altura.\nSteadicam: seguimiento suave detras del personaje.\n\nAuto-ciclo: cambia de jugador automaticamente cada N segundos.\nNavegacion rapida: teclas Q/E cambian de jugador instantaneamente.\nRotacion con Mouse: activado en todos los modos (excepto 1ra persona).",
    })
    InfoTab:CreateParagraph({
        Title   = "Diversion - Efectos visuales (v8)",
        Content =
        "Invisibilidad: vuelve transparente a tu personaje (solo local).\nTrail: deja una estela de esferas neon con ancho, duracion y color RGB configurables.\nDisco floor: panel neon bajo tus pies que TE SIGUE a todas partes, con tamano y color RGB.\nMaterial: convierte tu cuerpo en Neon, Metal, Glass, ForceField, etc.",
    })
    InfoTab:CreateParagraph({
        Title   = "Para creadores de contenido",
        Content =
        "Stack recomendado para intros epicas:\n  Crane (grua) + Handheld (sacudida sutil) + transiciones suaves + auto-focus DOF + filtro Teal & Orange + Letterbox + Bloom.\n\nVertigo: perfecto para revelar al personaje con tension dramatica.\n\nCaptura de pantalla limpia:\n  Usa el boton en Inicio para ocultar la UI del script por 3s y tomar la foto sin destruir el script. Activa 'Auto-ocultar HUD' para que la UI del juego desaparezca sola al entrar en camara libre.",
    })
end
