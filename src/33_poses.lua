-- ============================================================
-- Universal Camera Pro v7 · 33_poses
-- Sistema de Poses Avanzadas: 19+ poses predefinidas usando Motor6D.Transform,
-- transiciones suaves, aplicación a otros jugadores (local),
-- rotación manual de partes, guardar/cargar poses custom.
--
-- Dependencias: 00_config, 10_utils
-- Expone (UCam.*):
--   initPoses, applyPose, applyPoseToPlayer, restorePose,
--   restoreAllPlayerPoses, savePoseSnapshot, loadPoseSnapshot,
--   updateAdvPoses, stopAdvPoses, PoseLibrary
-- ============================================================
local UCam = _G.UCam

-- ============================================================
-- POSE LIBRARY — Motor6D CFrame transforms
-- Cada pose define los Transform CFrames para los joints principales
-- ============================================================
UCam.PoseLibrary = {
    ["Normal"] = {
        Neck           = CFrame.new(),
        ["Right Shoulder"] = CFrame.new(),
        ["Left Shoulder"]  = CFrame.new(),
        ["Right Hip"]      = CFrame.new(),
        ["Left Hip"]       = CFrame.new(),
        RootJoint          = CFrame.new(),
    },
    
    ["T-Pose"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
        ["Right Shoulder"] = CFrame.new(1.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
        ["Left Shoulder"]  = CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0) * CFrame.Angles(0, 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(0, 0, 0),
        RootJoint          = CFrame.new(),
    },
    
    ["A-Pose"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
        ["Right Shoulder"] = CFrame.new(1.5, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0),
        ["Left Shoulder"]  = CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(0, math.rad(-45), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0) * CFrame.Angles(0, math.rad(15), 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(0, math.rad(-15), 0),
        RootJoint          = CFrame.new(),
    },
    
    ["Sentado"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(10), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(5), math.rad(10), 0),
        ["Left Shoulder"]  = CFrame.new(-1, 0.5, 0) * CFrame.Angles(math.rad(5), math.rad(-10), 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.2, 0) * CFrame.Angles(math.rad(90), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -0.2, 0) * CFrame.Angles(math.rad(90), 0, 0),
        RootJoint          = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-10), 0, 0),
    },
    
    ["Flotando"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-20), 0, 0),
        ["Right Shoulder"] = CFrame.new(1.2, 0.8, 0) * CFrame.Angles(math.rad(-45), math.rad(30), 0),
        ["Left Shoulder"]  = CFrame.new(-1.2, 0.8, 0) * CFrame.Angles(math.rad(-45), math.rad(-30), 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.8, 0) * CFrame.Angles(math.rad(30), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -0.8, 0) * CFrame.Angles(math.rad(30), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(10), 0, 0),
    },
    
    ["Dab"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(45), math.rad(-30)),
        ["Right Shoulder"] = CFrame.new(1, 0.3, 0.3) * CFrame.Angles(math.rad(-110), math.rad(20), math.rad(-30)),
        ["Left Shoulder"]  = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-20), 0),
    },
    
    ["Superhero Landing"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(30), 0, 0),
        ["Right Shoulder"] = CFrame.new(1.2, -0.2, 0.5) * CFrame.Angles(math.rad(120), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1.2, -0.2, 0.5) * CFrame.Angles(math.rad(120), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.5, 0) * CFrame.Angles(math.rad(70), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(math.rad(100), 0, 0),
        RootJoint          = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(20), 0, 0),
    },
    
    ["Victoria"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-10), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 1, 0) * CFrame.Angles(math.rad(-120), math.rad(10), 0),
        ["Left Shoulder"]  = CFrame.new(-1, 1, 0) * CFrame.Angles(math.rad(-120), math.rad(-10), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(),
    },
    
    ["Manos Arriba"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(5), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 1.2, 0) * CFrame.Angles(math.rad(-170), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1, 1.2, 0) * CFrame.Angles(math.rad(-170), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(),
    },
    
    ["Meditando"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-15), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 0.3, 0.3) * CFrame.Angles(math.rad(-60), math.rad(-20), math.rad(20)),
        ["Left Shoulder"]  = CFrame.new(-1, 0.3, 0.3) * CFrame.Angles(math.rad(-60), math.rad(20), math.rad(-20)),
        ["Right Hip"]      = CFrame.new(0.5, -0.3, 0) * CFrame.Angles(math.rad(100), 0, math.rad(45)),
        ["Left Hip"]       = CFrame.new(-0.5, -0.3, 0) * CFrame.Angles(math.rad(100), 0, math.rad(-45)),
        RootJoint          = CFrame.new(0, -1, 0),
    },
    
    ["Acostado"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0),
        ["Right Shoulder"] = CFrame.new(1.2, 0.5, 0) * CFrame.Angles(math.rad(90), 0, math.rad(30)),
        ["Left Shoulder"]  = CFrame.new(-1.2, 0.5, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-30)),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0) * CFrame.Angles(math.rad(90), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(math.rad(90), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0),
    },
    
    ["Recostado"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(45), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 0, 0.5) * CFrame.Angles(math.rad(90), 0, math.rad(10)),
        ["Left Shoulder"]  = CFrame.new(-1, 0, 0) * CFrame.Angles(math.rad(30), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.5, 0) * CFrame.Angles(math.rad(60), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(math.rad(90), 0, 0),
        RootJoint          = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(30), 0, 0),
    },
    
    ["Durmiendo"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), math.rad(30), 0),
        ["Right Shoulder"] = CFrame.new(1, 0.8, 0) * CFrame.Angles(math.rad(90), 0, math.rad(45)),
        ["Left Shoulder"]  = CFrame.new(-1, 0.2, 0) * CFrame.Angles(math.rad(90), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.8, 0) * CFrame.Angles(math.rad(90), 0, math.rad(20)),
        ["Left Hip"]       = CFrame.new(-0.5, -1.2, 0) * CFrame.Angles(math.rad(95), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(-10)),
    },
    
    ["Zombie Walk"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(30), math.rad(-10), 0),
        ["Right Shoulder"] = CFrame.new(1, 0.5, 0.5) * CFrame.Angles(math.rad(-90), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1, 0.5, 0.4) * CFrame.Angles(math.rad(-80), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0) * CFrame.Angles(math.rad(10), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(math.rad(5), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(10), 0, 0),
    },
    
    ["Robot"] = {
        Neck           = CFrame.new(0, 0, 0),
        ["Right Shoulder"] = CFrame.new(1.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
        ["Left Shoulder"]  = CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(),
    },
    
    ["Bailando"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(20), 0),
        ["Right Shoulder"] = CFrame.new(1, 0.8, 0) * CFrame.Angles(math.rad(-100), 0, math.rad(30)),
        ["Left Shoulder"]  = CFrame.new(-1, 0.3, 0) * CFrame.Angles(math.rad(-30), 0, math.rad(-20)),
        ["Right Hip"]      = CFrame.new(0.5, -0.8, 0) * CFrame.Angles(math.rad(20), 0, math.rad(10)),
        ["Left Hip"]       = CFrame.new(-0.5, -1.2, 0) * CFrame.Angles(math.rad(-10), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(15), math.rad(10)),
    },
    
    ["Caída Dramática"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(45), 0, 0),
        ["Right Shoulder"] = CFrame.new(1.5, 0.3, 0) * CFrame.Angles(math.rad(-30), math.rad(45), 0),
        ["Left Shoulder"]  = CFrame.new(-1.5, 0.8, 0) * CFrame.Angles(math.rad(-80), math.rad(-30), 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.5, 0) * CFrame.Angles(math.rad(60), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1.2, 0) * CFrame.Angles(math.rad(100), 0, 0),
        RootJoint          = CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(30), 0, math.rad(-20)),
    },
    
    ["Pose de Acción"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-30), 0),
        ["Right Shoulder"] = CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(45)),
        ["Left Shoulder"]  = CFrame.new(-1, 0.3, -0.3) * CFrame.Angles(math.rad(45), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.5, 0) * CFrame.Angles(math.rad(30), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1.2, 0) * CFrame.Angles(math.rad(70), 0, 0),
        RootJoint          = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, math.rad(30), 0),
    },
    
    ["Caminando"] = {
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(5), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 0.5, -0.2) * CFrame.Angles(math.rad(40), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1, 0.5, 0.2) * CFrame.Angles(math.rad(-40), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.8, -0.2) * CFrame.Angles(math.rad(-40), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1.2, 0.2) * CFrame.Angles(math.rad(40), 0, 0),
        RootJoint          = CFrame.new(),
    },

    -- ============================================================
    -- v7: POSES CREATIVAS NUEVAS PARA VIDEOS
    -- ============================================================

    ["Superman"] = {  -- Vuelo horizontal tipo superhéroe, puños adelante
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(10), 0, 0),
        ["Right Shoulder"] = CFrame.new(1.2, -0.3, 0.4) * CFrame.Angles(math.rad(85), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1.2, -0.3, 0.4) * CFrame.Angles(math.rad(85), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.3, 0.3) * CFrame.Angles(math.rad(85), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -0.6, 0.3) * CFrame.Angles(math.rad(80), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0),
    },

    ["Kamehameha"] = {  -- Cargar energía entre las manos a un lado
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-5), math.rad(-30), 0),
        ["Right Shoulder"] = CFrame.new(0.6, 0.3, 0.5) * CFrame.Angles(math.rad(-90), math.rad(30), 0),
        ["Left Shoulder"]  = CFrame.new(-0.6, 0.3, 0.5) * CFrame.Angles(math.rad(-90), math.rad(-30), 0),
        ["Right Hip"]      = CFrame.new(0.6, -1, 0) * CFrame.Angles(0, math.rad(30), 0),
        ["Left Hip"]       = CFrame.new(-0.8, -1.1, 0) * CFrame.Angles(0, math.rad(-15), 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(30), 0),
    },

    ["Saludo Militar"] = {  -- Mano derecha a la frente, cuerpo erguido
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(10), 0),
        ["Right Shoulder"] = CFrame.new(0.5, 1.2, 0.2) * CFrame.Angles(math.rad(-150), math.rad(40), math.rad(20)),
        ["Left Shoulder"]  = CFrame.new(-1.2, 0.5, 0) * CFrame.Angles(0, math.rad(-15), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(),
    },

    ["Yoga Árbol"] = {  -- Una pierna doblada tipo árbol de yoga, manos en plegaria
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-5), 0, 0),
        ["Right Shoulder"] = CFrame.new(0.3, 0.8, 0.3) * CFrame.Angles(math.rad(-60), math.rad(20), math.rad(-40)),
        ["Left Shoulder"]  = CFrame.new(-0.3, 0.8, 0.3) * CFrame.Angles(math.rad(-60), math.rad(-20), math.rad(40)),
        ["Right Hip"]      = CFrame.new(0.5, -0.9, 0) * CFrame.Angles(0, 0, math.rad(20)),
        ["Left Hip"]       = CFrame.new(-0.5, -0.5, 0.2) * CFrame.Angles(math.rad(60), 0, 0),
        RootJoint          = CFrame.new(0, -0.5, 0),
    },

    ["Spiderman"] = {  -- Agazapado listo a saltar, una mano al suelo
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(35), math.rad(20), 0),
        ["Right Shoulder"] = CFrame.new(1, -0.6, 0.8) * CFrame.Angles(math.rad(80), math.rad(20), 0),
        ["Left Shoulder"]  = CFrame.new(-1.2, 0.3, 0.2) * CFrame.Angles(math.rad(20), math.rad(-20), 0),
        ["Right Hip"]      = CFrame.new(0.6, -0.6, 0) * CFrame.Angles(math.rad(70), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.4, -1.2, 0) * CFrame.Angles(math.rad(20), 0, 0),
        RootJoint          = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(45), 0, 0),
    },

    ["Crucifixión"] = {  -- Brazos extendidos a los lados, cuerpo recto (cine épico)
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-15), 0, 0),
        ["Right Shoulder"] = CFrame.new(1.5, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
        ["Left Shoulder"]  = CFrame.new(-1.5, 0.5, 0) * CFrame.Angles(0, 0, math.rad(-90)),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(),
    },

    ["Beso"] = {  -- Inclinado adelante, labios fruncidos (cabeza abajo), manos al pecho
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(45), 0, 0),
        ["Right Shoulder"] = CFrame.new(0.6, 0.3, 0.4) * CFrame.Angles(math.rad(-70), math.rad(20), 0),
        ["Left Shoulder"]  = CFrame.new(-0.6, 0.3, 0.4) * CFrame.Angles(math.rad(-70), math.rad(-20), 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0),
        RootJoint          = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(15), 0, 0),
    },

    ["Cargando Poder"] = {  -- Arrodillado, ambos puños al suelo, cabeza baja (earthquake)
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(40), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, -0.4, 0.5) * CFrame.Angles(math.rad(110), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1, -0.4, 0.5) * CFrame.Angles(math.rad(110), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.3, -0.2) * CFrame.Angles(math.rad(95), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -0.3, 0.2) * CFrame.Angles(math.rad(95), 0, 0),
        RootJoint          = CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(30), 0, 0),
    },

    ["Plancha"] = {  -- Horizontal boca abajo, cuerpo recto (plank / push-up)
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, 0.5, 0.3) * CFrame.Angles(math.rad(90), 0, 0),
        ["Left Shoulder"]  = CFrame.new(-1, 0.5, 0.3) * CFrame.Angles(math.rad(90), 0, 0),
        ["Right Hip"]      = CFrame.new(0.5, -1, 0) * CFrame.Angles(math.rad(90), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -1, 0) * CFrame.Angles(math.rad(90), 0, 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0),
    },

    ["Bailarina"] = {  -- Postura de ballet 4ª posición, brazos elegantes
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-10), 0, 0),
        ["Right Shoulder"] = CFrame.new(0.8, 1.0, 0.2) * CFrame.Angles(math.rad(-160), math.rad(30), 0),
        ["Left Shoulder"]  = CFrame.new(-0.8, 1.0, 0.2) * CFrame.Angles(math.rad(-160), math.rad(-30), 0),
        ["Right Hip"]      = CFrame.new(0.5, -0.5, 0.1) * CFrame.Angles(math.rad(-25), 0, math.rad(15)),
        ["Left Hip"]       = CFrame.new(-0.5, -1.2, 0) * CFrame.Angles(math.rad(15), 0, 0),
        RootJoint          = CFrame.new(0, -0.3, 0),
    },

    ["Agachado Listo"] = {  -- Anticipo de salto, peso atrás, brazos atrás
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(20), 0, 0),
        ["Right Shoulder"] = CFrame.new(1, -0.5, -0.6) * CFrame.Angles(math.rad(80), 0, math.rad(20)),
        ["Left Shoulder"]  = CFrame.new(-1, -0.5, -0.6) * CFrame.Angles(math.rad(80), 0, math.rad(-20)),
        ["Right Hip"]      = CFrame.new(0.5, -0.5, 0) * CFrame.Angles(math.rad(70), 0, 0),
        ["Left Hip"]       = CFrame.new(-0.5, -0.7, 0) * CFrame.Angles(math.rad(55), 0, 0),
        RootJoint          = CFrame.new(0, -1.3, 0.2) * CFrame.Angles(math.rad(35), 0, 0),
    },

    ["James Bond"] = {  -- Una mano adelante tipo pistola, cuerpo lateral
        Neck           = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-40), 0),
        ["Right Shoulder"] = CFrame.new(1.3, 0.4, 0.3) * CFrame.Angles(math.rad(180), math.rad(20), 0),
        ["Left Shoulder"]  = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-30), 0),
        ["Right Hip"]      = CFrame.new(0.6, -1, 0) * CFrame.Angles(0, math.rad(-20), 0),
        ["Left Hip"]       = CFrame.new(-0.7, -1.1, 0) * CFrame.Angles(0, math.rad(-40), 0),
        RootJoint          = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-30), 0),
    },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function freezeCharacterControl(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    -- Desactivar scripts de animación
    for _, s in ipairs(character:GetDescendants()) do
        if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
            pcall(function() s.Disabled = true end)
        end
    end
    
    -- Detener animaciones en curso
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0) end)
        end
    end
    
    -- Freeze control
    pcall(function()
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end)
    
    return true
end

local function unfreezeCharacterControl(character)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    for _, s in ipairs(character:GetDescendants()) do
        if s:IsA("LocalScript") and (s.Name == "Animate" or s.Name == "RbxCharacterSounds") then
            pcall(function() s.Disabled = false end)
        end
    end
    
    if humanoid then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

local function snapshotJoints(character)
    local snapshot = {}
    for _, joint in ipairs(character:GetDescendants()) do
        if joint:IsA("Motor6D") then
            snapshot[joint] = joint.Transform
        end
    end
    return snapshot
end

local function restoreJoints(snapshot)
    for joint, transform in pairs(snapshot) do
        if joint and joint.Parent then
            pcall(function() joint.Transform = transform end)
        end
    end
end

-- ============================================================
-- APLICAR POSE A PERSONAJE LOCAL
-- ============================================================
function UCam.applyPose(poseName)
    UCam.refreshCharacterRefs()
    if not UCam.character or not UCam.humanoid then return end
    
    if poseName == "Normal" then
        UCam.Poses.Current = "Normal"
        if UCam.Poses._originals[UCam.character] then
            restoreJoints(UCam.Poses._originals[UCam.character])
            UCam.Poses._originals[UCam.character] = nil
        end
        unfreezeCharacterControl(UCam.character)
        return
    end
    
    local poseData = UCam.PoseLibrary[poseName] or UCam.Poses.CustomPoses[poseName]
    if not poseData then
        warn("[Poses] Pose '" .. poseName .. "' no encontrada")
        return
    end
    
    -- Snapshot original si es la primera vez
    if not UCam.Poses._originals[UCam.character] then
        UCam.Poses._originals[UCam.character] = snapshotJoints(UCam.character)
    end
    
    freezeCharacterControl(UCam.character)
    UCam.Poses.Current = poseName
    UCam.Poses._targetPose = poseData
end

-- ============================================================
-- APLICAR POSE A OTRO JUGADOR (LOCAL)
-- ============================================================
function UCam.applyPoseToPlayer(player, poseName)
    if not player or not player.Character then return end
    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    if poseName == "Normal" then
        if UCam.Poses._playerTargets[player] then
            restoreJoints(UCam.Poses._playerTargets[player].originalJoints)
            unfreezeCharacterControl(character)
            UCam.Poses._playerTargets[player] = nil
        end
        return
    end
    
    local poseData = UCam.PoseLibrary[poseName] or UCam.Poses.CustomPoses[poseName]
    if not poseData then return end
    
    -- Snapshot si es primera vez
    if not UCam.Poses._playerTargets[player] then
        UCam.Poses._playerTargets[player] = {
            originalJoints = snapshotJoints(character),
            targetPose = poseData,
            character = character,
        }
    else
        UCam.Poses._playerTargets[player].targetPose = poseData
    end
    
    freezeCharacterControl(character)
end

-- ============================================================
-- RESTAURAR POSES
-- ============================================================
function UCam.restorePose()
    UCam.applyPose("Normal")
end

function UCam.restoreAllPlayerPoses()
    for player, data in pairs(UCam.Poses._playerTargets) do
        if player and player.Character then
            restoreJoints(data.originalJoints)
            unfreezeCharacterControl(player.Character)
        end
    end
    table.clear(UCam.Poses._playerTargets)
end

-- ============================================================
-- GUARDAR/CARGAR POSES CUSTOM
-- ============================================================
function UCam.savePoseSnapshot(name)
    UCam.refreshCharacterRefs()
    if not UCam.character then return false end
    
    local snapshot = {}
    for _, joint in ipairs(UCam.character:GetDescendants()) do
        if joint:IsA("Motor6D") then
            snapshot[joint.Name] = joint.Transform
        end
    end
    
    UCam.Poses.CustomPoses[name] = snapshot
    table.insert(UCam.Poses.PosesList, name)
    return true
end

function UCam.loadPoseSnapshot(name)
    if UCam.Poses.CustomPoses[name] then
        UCam.applyPose(name)
        return true
    end
    return false
end

-- ============================================================
-- UPDATE LOOP (transiciones suaves)
-- ============================================================
function UCam.updateAdvPoses(dt)
    -- Update local character pose
    if UCam.Poses.Current ~= "Normal" and UCam.Poses._targetPose then
        UCam.refreshCharacterRefs()
        if UCam.character then
            for jointName, targetCF in pairs(UCam.Poses._targetPose) do
                local joint = UCam.character:FindFirstChild("Torso", true)
                if joint then joint = joint:FindFirstChild(jointName) end
                if not joint then
                    -- Try HumanoidRootPart for RootJoint
                    if jointName == "RootJoint" then
                        local hrp = UCam.character:FindFirstChild("HumanoidRootPart")
                        if hrp then joint = hrp:FindFirstChild("RootJoint") end
                    end
                end
                
                if joint and joint:IsA("Motor6D") then
                    pcall(function()
                        joint.Transform = joint.Transform:Lerp(targetCF, UCam.Poses.TransitionSpeed)
                    end)
                end
            end
        end
    end
    
    -- Update other players' poses
    for player, data in pairs(UCam.Poses._playerTargets) do
        if player and player.Character and data.targetPose then
            local character = player.Character
            for jointName, targetCF in pairs(data.targetPose) do
                local joint = character:FindFirstChild("Torso", true)
                if joint then joint = joint:FindFirstChild(jointName) end
                if not joint and jointName == "RootJoint" then
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then joint = hrp:FindFirstChild("RootJoint") end
                end
                
                if joint and joint:IsA("Motor6D") then
                    pcall(function()
                        joint.Transform = joint.Transform:Lerp(targetCF, UCam.Poses.TransitionSpeed)
                    end)
                end
            end
        end
    end
end

-- ============================================================
-- INIT / STOP
-- ============================================================
function UCam.initPoses()
    if UCam.Poses._connHeartbeat then return end
    UCam.Poses._connHeartbeat = UCam.RunService.Heartbeat:Connect(function(dt)
        UCam.updateAdvPoses(dt)
    end)
end

function UCam.stopAdvPoses()
    if UCam.Poses._connHeartbeat then
        UCam.Poses._connHeartbeat:Disconnect()
        UCam.Poses._connHeartbeat = nil
    end
    
    UCam.restorePose()
    UCam.restoreAllPlayerPoses()
    UCam.Poses.Current = "Normal"
    UCam.Poses._targetPose = nil
    table.clear(UCam.Poses._originals)
end
