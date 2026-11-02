-- ============================================================
-- Universal Camera Pro v13.6 · actors/38_skinexport
-- Exporta el personaje de un jugador a un modelo .rbxmx local
-- (XML de Roblox) para abrirlo en Studio y animarlo.
--
-- No depende de APIs de serializacion del executor: recorre el
-- modelo copiado y escribe el XML de Studio a mano. Se exportan
-- partes, colores, accesorios, texturas, huesos y joints; los
-- scripts y las herramientas se excluyen siempre.
--
-- Dependencias: core/00_config.lua, core/10_utils.lua.
-- Expone (UCam.*):
--   getSkinExportTargets, resolveSkinExportTarget, exportPlayerSkin
-- ============================================================
local UCam = _G.UCam

local EXPORT_FOLDER = "UniversalCamera/skins"
local IDENTITY = CFrame.new()

-- ============================================================
-- HELPERS XML
-- ============================================================
local function escapeXml(value)
    local text = tostring(value or "")
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    text = text:gsub('"', "&quot;")
    text = text:gsub("'", "&apos;")
    return text
end

local function prop(name, kind, body)
    return ("<%s name=\"%s\">%s</%s>\n"):format(kind, name, body, kind)
end

local function stringProp(name, value)
    return prop(name, "string", escapeXml(value))
end

local function boolProp(name, value)
    return prop(name, "bool", value and "true" or "false")
end

local function floatProp(name, value)
    return prop(name, "float", string.format("%.6f", tonumber(value) or 0))
end

local function doubleProp(name, value)
    return prop(name, "double", string.format("%.6f", tonumber(value) or 0))
end

local function tokenProp(name, value)
    local number = tonumber(value)
    return prop(name, "token", tostring(math.floor(number or 0)))
end

local function vector3Prop(name, value)
    return prop(name, "Vector3", string.format(
        "<X>%.6f</X><Y>%.6f</Y><Z>%.6f</Z>",
        tonumber(value.X) or 0,
        tonumber(value.Y) or 0,
        tonumber(value.Z) or 0
    ))
end

local function cframeProp(name, value)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
    return prop(name, "CoordinateFrame", string.format(
        "<X>%.6f</X><Y>%.6f</Y><Z>%.6f</Z>"
            .. "<R00>%.6f</R00><R01>%.6f</R01><R02>%.6f</R02>"
            .. "<R10>%.6f</R10><R11>%.6f</R11><R12>%.6f</R12>"
            .. "<R20>%.6f</R20><R21>%.6f</R21><R22>%.6f</R22>",
        x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22
    ))
end

local function contentProp(name, value)
    local text = tostring(value or "")
    if text == "" then
        return prop(name, "ContentId", "<null></null>")
    end
    return prop(name, "ContentId", "<url>" .. escapeXml(text) .. "</url>")
end

local function color3uint8(value)
    local function channel(component)
        return math.floor(math.clamp(tonumber(component) or 0, 0, 1) * 255 + 0.5)
    end
    return 4278190080 + channel(value.R) * 65536 + channel(value.G) * 256 + channel(value.B)
end

local function colorProp(name, value)
    return prop(name, "Color3uint8", tostring(color3uint8(value)))
end

local function refProp(name, instance, refs)
    local ref = refs[instance]
    if not ref then return nil end
    return prop(name, "Ref", ref)
end

-- Lee una propiedad sin confiar en que exista en todas las clases o
-- versiones del juego. Un rig personalizado no debe romper la exportacion.
local function read(instance, key, default)
    local ok, value = pcall(function()
        return instance[key]
    end)
    if ok then return value end
    return default
end

-- El juego marca cada personaje con atributos "Character" (Sonic, Amy...)
-- y "Skin" (Default, Neo...). Se usan para nombrar el archivo, asi en
-- Studio se reconoce de donde salio el rig.
local function readAttribute(instance, name)
    local ok, value = pcall(function()
        return instance:GetAttribute(name)
    end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

-- ============================================================
-- ARBOL A EXPORTAR
-- ============================================================
local function isExportable(instance)
    if instance:IsA("LuaSourceContainer") then return false end
    if instance:IsA("Tool") then return false end
    if instance:IsA("BasePart") then return true end
    if instance:IsA("Model") or instance:IsA("Folder") then return true end
    if instance:IsA("Humanoid") or instance:IsA("AnimationController") then return true end
    if instance:IsA("Animator") then return true end
    if instance:IsA("Accessory") then return true end
    if instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then return true end
    if instance:IsA("Attachment") then return true end
    if instance:IsA("Decal") or instance:IsA("Texture") then return true end
    if instance:IsA("SpecialMesh") or instance:IsA("CharacterMesh") then return true end
    if instance:IsA("Shirt") or instance:IsA("Pants") then return true end
    if instance:IsA("SurfaceAppearance") then return true end
    return false
end

--- Recorre solo ramas exportables, para no dejar partes huerfanas de un
-- contenedor que no sabemos serializar.
local function walk(instance, fn)
    if not isExportable(instance) then return end
    fn(instance)
    for _, child in ipairs(instance:GetChildren()) do
        walk(child, fn)
    end
end

local function assignRefs(root, refs)
    local counter = 0
    walk(root, function(instance)
        counter = counter + 1
        refs[instance] = "RBX" .. tostring(counter)
    end)
end

-- ============================================================
-- PROPIEDADES
-- ============================================================
local function addBasePartProps(part, props, ctx)
    local cf = read(part, "CFrame")
    if typeof(cf) == "CFrame" then
        props[#props + 1] = cframeProp("CFrame", ctx.origin * cf)
    end

    local size = read(part, "Size")
    if typeof(size) == "Vector3" then
        props[#props + 1] = vector3Prop("Size", size)
    end

    local color = read(part, "Color")
    if typeof(color) == "Color3" then
        props[#props + 1] = colorProp("Color3uint8", color)
    end

    local material = read(part, "Material")
    if typeof(material) == "EnumItem" then
        props[#props + 1] = tokenProp("Material", material.Value)
    end

    props[#props + 1] = floatProp("Transparency", read(part, "Transparency", 0))
    props[#props + 1] = floatProp("Reflectance", read(part, "Reflectance", 0))

    -- El root queda anclado para que el rig no se caiga al importarlo en
    -- Studio; el resto se mueve con los Motor6D. Sin colision para que
    -- las piezas no se empujen entre si.
    local anchored = ctx.anchorAll or part == ctx.root
    props[#props + 1] = boolProp("Anchored", anchored)
    props[#props + 1] = boolProp("CanCollide", false)
    props[#props + 1] = boolProp("Massless", not anchored)
    props[#props + 1] = boolProp("CastShadow", read(part, "CastShadow", true))

    if part:IsA("Part") then
        local shape = read(part, "Shape")
        if typeof(shape) == "EnumItem" then
            props[#props + 1] = tokenProp("Shape", shape.Value)
        end
        for _, face in ipairs({
            "TopSurface", "BottomSurface", "LeftSurface",
            "RightSurface", "FrontSurface", "BackSurface",
        }) do
            props[#props + 1] = tokenProp(face, 0)
        end
    end

    if part:IsA("MeshPart") then
        local meshId = read(part, "MeshId", "")
        if tostring(meshId or "") ~= "" then
            props[#props + 1] = contentProp("MeshId", meshId)
        end
        local textureId = read(part, "TextureID", "")
        if tostring(textureId or "") ~= "" then
            props[#props + 1] = contentProp("TextureID", textureId)
        end
    end

    -- El rig del juego usa UnionOperation para ojos/detalles. Sin el
    -- AssetId la union se importa como un bloque vacio en Studio.
    if part:IsA("PartOperation") then
        local assetId = read(part, "AssetId", "")
        if tostring(assetId or "") ~= "" then
            props[#props + 1] = contentProp("AssetId", assetId)
        end
        local meshId = read(part, "MeshId", "")
        if tostring(meshId or "") ~= "" then
            props[#props + 1] = contentProp("MeshId", meshId)
        end
    end
end

local function addJointProps(joint, props, refs)
    local part0 = read(joint, "Part0")
    local part1 = read(joint, "Part1")
    local ref0 = part0 and refProp("Part0", part0, refs)
    local ref1 = part1 and refProp("Part1", part1, refs)
    if not (ref0 and ref1) then return false end

    props[#props + 1] = ref0
    props[#props + 1] = ref1

    local c0 = read(joint, "C0")
    if typeof(c0) == "CFrame" then
        props[#props + 1] = cframeProp("C0", c0)
    end
    local c1 = read(joint, "C1")
    if typeof(c1) == "CFrame" then
        props[#props + 1] = cframeProp("C1", c1)
    end

    if joint:IsA("Motor6D") then
        -- La pose de reposo vive en C0/C1; Transform se guarda limpio.
        props[#props + 1] = cframeProp("Transform", IDENTITY)
    end
    if joint:IsA("WeldConstraint") then
        props[#props + 1] = boolProp("Enabled", read(joint, "Enabled", true))
    end
    return true
end

local function addInstanceProps(instance, props, refs, ctx)
    local class = instance.ClassName

    props[#props + 1] = stringProp("Name", instance.Name)

    if instance:IsA("BasePart") then
        addBasePartProps(instance, props, ctx)
        return true
    end

    if instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then
        -- Un joint que apunta fuera del arbol exportado no se escribe.
        return addJointProps(instance, props, refs)
    end

    if instance:IsA("Model") then
        local primary = read(instance, "PrimaryPart")
        if primary then
            local ref = refProp("PrimaryPart", primary, refs)
            if ref then props[#props + 1] = ref end
        end
        return true
    end

    if instance:IsA("Humanoid") then
        props[#props + 1] = floatProp("Health", read(instance, "Health", 100))
        props[#props + 1] = floatProp("MaxHealth", read(instance, "MaxHealth", 100))
        local displayName = read(instance, "DisplayName", "")
        if type(displayName) == "string" and displayName ~= "" then
            props[#props + 1] = stringProp("DisplayName", displayName)
        end
        return true
    end

    if instance:IsA("Attachment") then
        local cf = read(instance, "CFrame")
        if typeof(cf) == "CFrame" then
            props[#props + 1] = cframeProp("CFrame", cf)
        end
        local visible = read(instance, "Visible")
        if type(visible) == "boolean" then
            props[#props + 1] = boolProp("Visible", visible)
        end
        return true
    end

    if instance:IsA("Decal") or instance:IsA("Texture") then
        local texture = read(instance, "Texture", "")
        props[#props + 1] = contentProp("Texture", texture)
        local face = read(instance, "Face")
        if typeof(face) == "EnumItem" then
            props[#props + 1] = tokenProp("Face", face.Value)
        end
        props[#props + 1] = floatProp("Transparency", read(instance, "Transparency", 0))
        return true
    end

    if instance:IsA("SpecialMesh") then
        props[#props + 1] = contentProp("MeshId", read(instance, "MeshId", ""))
        props[#props + 1] = contentProp("TextureId", read(instance, "TextureId", ""))
        local meshType = read(instance, "MeshType")
        if typeof(meshType) == "EnumItem" then
            props[#props + 1] = tokenProp("MeshType", meshType.Value)
        end
        local scale = read(instance, "Scale")
        if typeof(scale) == "Vector3" then
            props[#props + 1] = vector3Prop("Scale", scale)
        end
        local offset = read(instance, "Offset")
        if typeof(offset) == "Vector3" then
            props[#props + 1] = vector3Prop("Offset", offset)
        end
        return true
    end

    if instance:IsA("CharacterMesh") then
        props[#props + 1] = contentProp("MeshId", read(instance, "MeshId", ""))
        props[#props + 1] = contentProp("BaseTextureId", read(instance, "BaseTextureId", ""))
        props[#props + 1] = contentProp("OverlayTextureId", read(instance, "OverlayTextureId", ""))
        local bodyPart = read(instance, "BodyPart")
        if typeof(bodyPart) == "EnumItem" then
            props[#props + 1] = tokenProp("BodyPart", bodyPart.Value)
        end
        return true
    end

    if instance:IsA("Shirt") then
        props[#props + 1] = contentProp("ShirtTemplate", read(instance, "ShirtTemplate", ""))
        return true
    end

    if instance:IsA("Pants") then
        props[#props + 1] = contentProp("PantsTemplate", read(instance, "PantsTemplate", ""))
        return true
    end

    if instance:IsA("SurfaceAppearance") then
        for _, key in ipairs({ "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" }) do
            local value = read(instance, key, "")
            if tostring(value or "") ~= "" then
                props[#props + 1] = contentProp(key, value)
            end
        end
        props[#props + 1] = floatProp("AlphaCutoff", read(instance, "AlphaCutoff", 0))
        local alphaMode = read(instance, "AlphaMode")
        if typeof(alphaMode) == "EnumItem" then
            props[#props + 1] = tokenProp("AlphaMode", alphaMode.Value)
        end
        return true
    end

    -- Folder, Animator, AnimationController, Accessory y demas: solo Name.
    if class == "Folder" or class == "Animator" or class == "AnimationController"
        or class == "Accessory" then
        return true
    end

    return false
end

-- ============================================================
-- SERIALIZACION
-- ============================================================
local function serialize(instance, refs, ctx, out)
    local ref = refs[instance]
    if not ref then return end

    -- Los joints se validan antes de abrir el <Item>.
    if instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then
        local part0 = read(instance, "Part0")
        local part1 = read(instance, "Part1")
        if not (part0 and part1 and refs[part0] and refs[part1]) then
            return
        end
    end

    -- Las propiedades se calculan ANTES de escribir la etiqueta: si la
    -- clase no se soporta, se omite sin dejar un <Item> abierto (eso
    -- rompia el XML entero y Studio rechazaba el archivo).
    local props = {}
    if not addInstanceProps(instance, props, refs, ctx) then
        return
    end

    out[#out + 1] = ("<Item class=\"%s\" referent=\"%s\">\n"):format(instance.ClassName, ref)
    out[#out + 1] = "<Properties>\n"
    out[#out + 1] = table.concat(props)
    out[#out + 1] = "</Properties>\n"

    for _, child in ipairs(instance:GetChildren()) do
        if refs[child] then
            serialize(child, refs, ctx, out)
        end
    end
    out[#out + 1] = "</Item>\n"
end

-- ============================================================
-- ARCHIVO
-- ============================================================
local function sanitizeName(value)
    local text = tostring(value or "skin")
    text = text:gsub("%.%.", "_")
    text = text:gsub("[^%w%-_%. ]", "_")
    text = text:gsub("%s+", "_")
    text = text:gsub("_+", "_")
    text = text:gsub("^_", ""):gsub("_$", "")
    if text == "" then text = "skin" end
    return text
end

local function ensureFolder(path)
    if typeof(isfolder) ~= "function" or typeof(makefolder) ~= "function" then
        return false
    end
    local parent = path:match("^(.-)/[^/]+$")
    if parent and not isfolder(parent) then
        pcall(makefolder, parent)
    end
    local ok = pcall(isfolder, path)
    if ok and isfolder(path) then
        return true
    end
    pcall(makefolder, path)
    return isfolder(path) == true
end

local function countTree(root)
    local stats = { parts = 0, accessories = 0, joints = 0, attachments = 0 }
    walk(root, function(instance)
        if instance:IsA("BasePart") then
            stats.parts = stats.parts + 1
        elseif instance:IsA("Accessory") then
            stats.accessories = stats.accessories + 1
        elseif instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then
            stats.joints = stats.joints + 1
        elseif instance:IsA("Attachment") then
            stats.attachments = stats.attachments + 1
        end
    end)
    return stats
end

-- ============================================================
-- API PUBLICA
-- ============================================================
local targetMap = {}

function UCam.getSkinExportTargets()
    targetMap = {}
    local list = {}
    local localPlayer = UCam.player

    if localPlayer then
        local label = localPlayer.Name .. " (tú)"
        targetMap[label] = localPlayer
        list[#list + 1] = label
    end

    local others = {}
    for _, player in ipairs(UCam.Players:GetPlayers()) do
        if player ~= localPlayer then
            others[#others + 1] = player.Name
            targetMap[player.Name] = player
        end
    end
    table.sort(others)
    for _, name in ipairs(others) do
        list[#list + 1] = name
    end

    if #list == 0 then
        list[1] = "(sin jugadores)"
    end
    return list
end

function UCam.resolveSkinExportTarget(label)
    local text = tostring(label or "")
    local player = targetMap[text]
    if player and player.Parent then
        return player
    end
    if UCam.player and UCam.player.Name == text then
        return UCam.player
    end
    for _, candidate in ipairs(UCam.Players:GetPlayers()) do
        if candidate.Name == text then
            return candidate
        end
    end
    return nil
end

--- Exporta el personaje actual de un jugador a UniversalCamera/skins.
-- @param target Player o etiqueta del dropdown.
-- @param opts table { name = "archivo_sin_extension" }
-- @return ok boolean, pathOrError string, stats table|nil
function UCam.exportPlayerSkin(target, opts)
    opts = opts or {}
    local player = target
    if type(player) == "string" then
        player = UCam.resolveSkinExportTarget(player)
    end
    if not player or not player:IsA("Player") then
        return false, "Selecciona un jugador válido.", nil
    end

    local character = player.Character
    if not character or not character.Parent then
        return false, "Ese jugador todavía no tiene personaje.", nil
    end

    -- Algunos juegos marcan el personaje como no archivable: sin esto el
    -- Clone devuelve nil y la exportacion fallaba sin explicacion.
    local wasArchivable = character.Archivable
    if not wasArchivable then
        pcall(function() character.Archivable = true end)
    end
    local ok, clone = pcall(function()
        return character:Clone()
    end)
    if not wasArchivable then
        pcall(function() character.Archivable = wasArchivable end)
    end
    if not ok or not clone then
        return false, "No se pudo copiar el personaje (Archivable false).", nil
    end
    clone.Name = "Skin_" .. sanitizeName(player.Name)
    clone.Archivable = true

    for _, desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("LuaSourceContainer") then
            pcall(function() desc:Destroy() end)
        end
    end

    -- Raiz para anclar y normalizar: el modelo aparece en el origen de
    -- Studio, no en la posicion exacta donde estaba el jugador.
    local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
    if not root then
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("BasePart") then
                root = desc
                break
            end
        end
    end

    local origin = IDENTITY
    if root then
        local okRoot, inverse = pcall(function()
            return root.CFrame:Inverse()
        end)
        if okRoot and typeof(inverse) == "CFrame" then
            origin = inverse
        end
    end

    local refs = {}
    assignRefs(clone, refs)

    local ctx = {
        origin = origin,
        root = root,
        anchorAll = root == nil,
    }

    local out = {}
    serialize(clone, refs, ctx, out)

    local stats = countTree(clone)
    local totalLen = 0
    for _, piece in ipairs(out) do
        totalLen = totalLen + #piece
    end
    if totalLen < 512 or stats.parts == 0 then
        pcall(function() clone:Destroy() end)
        return false, "El personaje no tiene partes exportables.", nil
    end

    local xml = '<?xml version="1.0" encoding="utf-8"?>\n'
        .. '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        .. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        .. 'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        .. '<Meta name="ExplicitAutoJoints">true</Meta>\n'
        .. table.concat(out)
        .. '</roblox>\n'

    pcall(function() clone:Destroy() end)

    if typeof(writefile) ~= "function" then
        return false, "Este executor no permite writefile; no se puede guardar el .rbxmx.", nil
    end

    local baseName = sanitizeName(opts.name)
    if baseName == "" or baseName == "skin" then
        -- Nombre derivado del juego: personaje + skin + fecha. Asi no se
        -- pisan dos exportaciones del mismo jugador.
        local parts = { "UCam" }
        local characterName = readAttribute(character, "Character")
        local skinName = readAttribute(character, "Skin")
        if characterName then parts[#parts + 1] = sanitizeName(characterName) end
        if skinName then parts[#parts + 1] = sanitizeName(skinName) end
        parts[#parts + 1] = sanitizeName(player.Name)
        parts[#parts + 1] = os.date("%Y%m%d_%H%M%S")
        baseName = table.concat(parts, "_")
    end
    if baseName:lower():sub(-6) ~= ".rbxmx" then
        baseName = baseName .. ".rbxmx"
    end

    local filename = baseName
    local path = EXPORT_FOLDER .. "/" .. baseName
    if not ensureFolder(EXPORT_FOLDER) then
        path = filename
    end

    local written, writeErr = pcall(writefile, path, xml)
    if not written then
        -- Algunos executors no permiten subcarpetas: segundo intento en raiz.
        path = filename
        written, writeErr = pcall(writefile, path, xml)
    end
    if not written then
        return false, "No se pudo escribir el archivo: " .. tostring(writeErr), nil
    end

    return true, path, stats
end
