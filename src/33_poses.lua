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

-- v10: los rigs R15 nuevos (Avatar Joint Upgrade) usan AnimationConstraint
-- en vez de Motor6D; ambos exponen .Transform para aplicar poses.
-- Se declara antes de snapshotJoints porque Lua resuelve locales por alcance
-- léxico; una declaración posterior no está disponible para esa función.
local function isPoseJoint(inst)
    return inst:IsA("Motor6D") or inst:IsA("AnimationConstraint")
end

local function snapshotJoints(character)
    local snapshot = {}
    for _, joint in ipairs(character:GetDescendants()) do
        if isPoseJoint(joint) then
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

-- v8.1 FIX (R15): los Motor6D en R6 cuelgan de "Torso" y se llaman
-- "Right Shoulder"/"Right Hip"; en R15 no hay Torso, cuelgan de
-- UpperTorso/LowerTorso y se llaman "RightShoulder"/"RightHip".
-- Este helper busca el joint por nombre en todo el personaje y
-- normaliza los espacios, así sirve tanto para R6 como para R15.
local function findPoseJoint(character, jointName)
    if not character then return nil end
    local normalized = jointName:gsub("%s", "")
    for _, joint in ipairs(character:GetDescendants()) do
        if isPoseJoint(joint) then
            local name = joint.Name
            if name == jointName or name:gsub("%s", "") == normalized then
                return joint
            end
        end
    end
    return nil
end

-- v10 FIX (lag): resuelve los joints de una pose UNA VEZ y los cachea.
-- El loop viejo hacia GetDescendants() por CADA joint y por CADA frame
-- (6 joints x N descendientes x 60fps = decenas de miles de iteraciones/s)
-- y eso era el bajón de FPS al seleccionar una pose.
--
-- v10 FIX (morphs custom): los juegos que reemplazan el modelo (Sonic, etc.)
-- usan joints con nombres propios, no "Right Shoulder"/"RightShoulder".
-- Si el lookup por nombre falla, se resuelve por ESTRUCTURA: el joint cuyo
-- Part1 es la cabeza = Neck, brazo superior derecho = Right Shoulder, etc.
local JOINT_PART_HINTS = {
    ["Right Shoulder"]  = { "rightupperarm", "rightarm" },
    ["Left Shoulder"]   = { "leftupperarm", "leftarm" },
    ["Right Hip"]       = { "rightupperleg", "rightleg" },
    ["Left Hip"]        = { "leftupperleg", "leftleg" },
    ["Neck"]            = { "head" },
    ["RootJoint"]       = { "lowertorso", "torso" },
}
-- Orden de resolucion: extremidades primero; RootJoint al final porque su
-- Part1 (torso) tambien podria matchear otros joints.
local JOINT_RESOLVE_ORDER = {
    "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip", "Neck", "RootJoint",
}

local function getPoseJointPart1(joint)
    local part1
    -- Motor6D/Weld/Snap expose Part1; AnimationConstraint uses Attachment1.
    pcall(function() part1 = joint.Part1 end)
    if not part1 then
        local attachment1
        pcall(function() attachment1 = joint.Attachment1 end)
        if attachment1 and attachment1.Parent then
            part1 = attachment1.Parent
        end
    end
    return part1
end

local function findJointByPartName(character, hints, used)
    for _, joint in ipairs(character:GetDescendants()) do
        if isPoseJoint(joint) and not used[joint] then
            local part1 = getPoseJointPart1(joint)
            if part1 then
                local n = part1.Name:lower():gsub("%s", "")
                for _, hint in ipairs(hints) do
                    if n:find(hint, 1, true) then
                        return joint
                    end
                end
            end
        end
    end
    return nil
end

local function resolvePoseJoints(character, poseData)
    local entries = {}
    if not character or not poseData then return entries end

    local used = {}
    local resolvedNames = {}

    -- 1) Lookup por nombre (R6/R15 estandar).
    for jointName, targetCF in pairs(poseData) do
        local joint = findPoseJoint(character, jointName)
        if joint then
            used[joint] = true
            resolvedNames[jointName] = true
            table.insert(entries, { joint = joint, target = targetCF })
        end
    end

    -- 2) Fallback estructural para rigs custom: emparejar por nombre de la
    -- parte que mueve el joint (Part1). Cubre morphs con nombres propios.
    for _, jointName in ipairs(JOINT_RESOLVE_ORDER) do
        if not resolvedNames[jointName] and poseData[jointName] then
            local joint = findJointByPartName(character, JOINT_PART_HINTS[jointName] or {}, used)
            if joint then
                used[joint] = true
                table.insert(entries, { joint = joint, target = poseData[jointName] })
            end
        end
    end

    return entries
end

-- Detener animaciones en curso. Se llama CADA frame mientras hay pose activa:
-- los morphs/juegos re-reproducen animaciones (idle propio del modelo) y el
-- Animator pisa nuestro Transform con cada frame de esa animacion, dejando el
-- cuerpo tieso en la pose default del juego en vez de la pose elegida.
local function stopCharacterAnimations(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(function() track:Stop(0) end)
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
        UCam.Poses._active = nil
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
    -- v10: resolver joints UNA vez y cachearlos (el loop por frame ya no
    -- busca joints en GetDescendants). Se guarda poseData para poder
    -- re-resolver si el juego reemplaza el modelo (respawn/morph).
    UCam.Poses._active = {
        character = UCam.character,
        pose = poseData,
        entries = resolvePoseJoints(UCam.character, poseData),
    }
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
            entries = resolvePoseJoints(character, poseData),
        }
    else
        local data = UCam.Poses._playerTargets[player]
        data.targetPose = poseData
        data.character = character
        data.entries = resolvePoseJoints(character, poseData)
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
        if isPoseJoint(joint) then
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
-- v10 FIX (lag): itera joints CACHEADOS (resolvePoseJoints), ya no hace
-- GetDescendants() por joint por frame.
-- v10 FIX (no aplicaba): corre en PreSimulation, no Heartbeat. El Animator
-- reescribe Transform cada frame antes de PreSimulation y el batch se aplica
-- justo después; escribir en Heartbeat llegaba tarde y el valor era pisado
-- por la animación antes de verse (docs: "set manually using PreSimulation").
-- ============================================================
function UCam.updateAdvPoses(dt)
    local alpha = UCam.Poses.TransitionSpeed

    -- Personaje local
    local active = UCam.Poses._active
    if active and UCam.Poses.Current ~= "Normal" then
        local char = UCam.character
        -- El juego reemplazo el modelo (respawn/morph): re-resolver joints.
        if char and char.Parent and active.character ~= char then
            active.character = char
            active.entries = resolvePoseJoints(char, active.pose)
        end
        if active.character and active.character.Parent then
            -- Cortar animaciones cada frame (el Animator pisa Transform).
            stopCharacterAnimations(active.character)
            for _, e in ipairs(active.entries) do
                local joint = e.joint
                if joint and joint.Parent then
                    pcall(function()
                        joint.Transform = joint.Transform:Lerp(e.target, alpha)
                    end)
                end
            end
        end
    end

    -- Otros jugadores
    for player, data in pairs(UCam.Poses._playerTargets) do
        local character = player and player.Character
        if character and character.Parent then
            -- Re-resolver si el jugador respawneó o morpheó.
            if data.character ~= character then
                data.character = character
                data.entries = resolvePoseJoints(character, data.targetPose)
            end
            stopCharacterAnimations(character)
            for _, e in ipairs(data.entries) do
                local joint = e.joint
                if joint and joint.Parent then
                    pcall(function()
                        joint.Transform = joint.Transform:Lerp(e.target, alpha)
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
    -- PreSimulation (Stepped): es el único punto donde nuestra escritura de
    -- Transform gana sobre el Animator y llega al batch de física/render.
    UCam.Poses._connHeartbeat = UCam.RunService.PreSimulation:Connect(function(dt)
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
    UCam.Poses._active = nil
    table.clear(UCam.Poses._originals)
end
