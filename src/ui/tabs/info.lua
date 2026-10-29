-- ============================================================
-- Universal Camera Pro v12.5 · ui/info
-- Pestaña Info / Ayuda: controles y mapa de la interfaz actual.
-- ============================================================
local UCam = _G.UCam

function UCam.build_info(Window)
    local InfoTab = Window:CreateTab("ℹ️ Info", "info")

    InfoTab:CreateParagraph({
        Title = "Controles básicos",
        Content =
        "Clic derecho + mouse → rotar cámara\n" ..
        "Rueda del mouse → zoom (FOV)\n" ..
        "Shift → sprint\n" ..
        "WASD + Espacio / Ctrl → movimiento\n" ..
        "Delete → mostrar/ocultar UI\n" ..
        "F → activar cámara libre\n" ..
        "X → dejar de espectar\n" ..
        "Z → disparar Camera Shake\n" ..
        "E / Q → siguiente / anterior jugador\n" ..
        "P → reproducir animación de props",
    })

    InfoTab:CreateParagraph({
        Title = "Modos de cámara (19)",
        Content =
        "Libre, Orbita, Tripode, Cenital, Lateral, Dron, Follow, CrashZoom,\n" ..
        "Director, Crane, Dolly Glide, Handheld, Roll Axis, Vertigo, FPV Dron,\n" ..
        "Snorricam, Cable Cam, Security Cam y Personalizada.\n\n" ..
        "En Cámaras solo ves los controles del modo elegido. Personalizada te deja\n" ..
        "definir distancia, altura, giro, inclinación, sway, roll y FOV propios.",
    })

    InfoTab:CreateParagraph({
        Title = "Mapa de la interfaz",
        Content =
        "Inicio: cámara libre, HUD automático/manual y ocultar personaje.\n" ..
        "Cámaras: modo + opciones del modo + lente + posiciones guardadas.\n" ..
        "Espectador: jugadores, auto-ciclo, estilos y encuadre.\n" ..
        "Cinematográfico: encuadre, shake, Director y post-procesado.\n" ..
        "Filtros: selector, editor custom, mezcla y filtro temporal.\n" ..
        "Iluminación: hora, exposición, niebla, ambiente, sombras y skybox.\n" ..
        "Estudio: pantalla de croma con encuadre automático y rotación.\n" ..
        "Gimbal: bloqueo de objetivo (LookAt).\n" ..
        "Props: objetos locales por ID de asset.\n" ..
        "Animador: timeline de keyframes para props.\n" ..
        "Clones: copias locales de cualquier jugador.\n" ..
        "Diversión: montar, física, tamaño, giro y efectos.\n" ..
        "Cuerpo: color, material y presets por partes.\n" ..
        "Creator: toma limpia, biblioteca de tomas, guías y escenas.\n" ..
        "Ajustes: teclas, notificaciones, gamepad, rendimiento y plugins.",
    })

    InfoTab:CreateParagraph({
        Title = "Props y Animador",
        Content =
        "Los props se crean en tu cliente: nadie más los ve. Puedes moverlos con\n" ..
        "la cámara, empujarlos por ejes, rotarlos, escalarlos, duplicarlos y\n" ..
        "apoyarlos en el suelo.\n\n" ..
        "En Animador guarda un keyframe por tiempo (alcance «Todos» o «Prop\n" ..
        "seleccionado»), ajusta duración, easing y loop, y reproduce. Así puedes\n" ..
        "animar una multitud en conjunto o dar a cada prop su propio ritmo.",
    })

    InfoTab:CreateParagraph({
        Title = "Clones locales",
        Content =
        "Copia a cualquier jugador las veces que quieras aunque la partida tenga\n" ..
        "límite de jugadores. «Seguir movimiento» reproduce caminar, saltar y\n" ..
        "emotes; «Fijar en el sitio» deja al clon quieto con la pose copiada.",
    })

    InfoTab:CreateParagraph({
        Title = "Espectador (9 estilos)",
        Content =
        "Primera persona, Tercera persona, Cinematográfico, Sobre hombro,\n" ..
        "Dron aéreo, Contrapicado, Dolly lateral, Órbita dinámica y Steadicam.\n\n" ..
        "El encuadre solo aparece cuando el estilo se aleja del jugador.\n" ..
        "Q/E cambian de jugador; el auto-ciclo lo hace cada N segundos.",
    })

    InfoTab:CreateParagraph({
        Title = "Cinematográfico",
        Content =
        "Letterbox 21:9, viñeta, Camera Shake con patrones, FOV Pulse,\n" ..
        "Director con waypoints, curvas y plantillas de toma,\n" ..
        "y post-procesado: Bloom, DOF con auto-focus y Sun Rays.",
    })

    InfoTab:CreateParagraph({
        Title = "Para creadores de contenido",
        Content =
        "Stack para intros: Crane o Personalizada + Handheld + auto-focus DOF +\n" ..
        "filtro Teal & Orange + Letterbox + Bloom.\n\n" ..
        "Para multitudes: Clones + Props + Animador.\n\n" ..
        "Para una toma limpia usa Creator → Preparar toma; el HUD se oculta solo\n" ..
        "al entrar en cámara libre y vuelve al salir.",
    })
end
