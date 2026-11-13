-- ============================================================
-- Pruebas headless de Universal Camera Pro (Replay v13.7)
-- Se ejecutan con el CLI de Luau:
--   ./tools/luau.exe tests/_sources.lua tests/run.lua
-- `tests/_sources.lua` lo genera tests/gen_sources.ps1 con el
-- contenido real de src/; aquí se monta un stub de Roblox.
-- ============================================================

local SOURCES = require("./_sources")
assert(type(SOURCES) == "table", "Falta tests/_sources.lua (ejecuta tests/run.sh)")

-- ============================================================
-- VECTOR3
-- ============================================================
local Vector3 = {}
Vector3.__index = function(self, key)
    if key == "Magnitude" then
        return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    elseif key == "Unit" then
        local m = math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
        if m == 0 then return Vector3.new(0, 0, 0) end
        return Vector3.new(self.x / m, self.y / m, self.z / m)
    elseif key == "X" then
        return self.x
    elseif key == "Y" then
        return self.y
    elseif key == "Z" then
        return self.z
    end
    return Vector3Methods[key]
end
Vector3.__typeof = "Vector3"
Vector3Methods = {
    Cross = function(a, b)
        return Vector3.new(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    end,
    Dot = function(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end,
}
function Vector3.new(x, y, z)
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b) return Vector3.new(a.x + b.x, a.y + b.y, a.z + b.z) end
Vector3.__sub = function(a, b) return Vector3.new(a.x - b.x, a.y - b.y, a.z - b.z) end
Vector3.__mul = function(a, b)
    if type(b) == "number" then return Vector3.new(a.x * b, a.y * b, a.z * b) end
    return Vector3.new(a.x * b.x, a.y * b.y, a.z * b.z)
end
Vector3.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
Vector3.__tostring = function(v) return ("(%.3f, %.3f, %.3f)"):format(v.x, v.y, v.z) end

-- ============================================================
-- CFAFE
-- ============================================================
local CFrame = {}
CFrame.__typeof = "CFrame"

function CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    if type(x) == "table" and x.x ~= nil and y == nil then
        x, y, z = x.x, x.y, x.z
    end
    return setmetatable({
        x = x or 0, y = y or 0, z = z or 0,
        r00 = r00 == nil and 1 or r00, r01 = r01 or 0, r02 = r02 or 0,
        r10 = r10 or 0, r11 = r11 == nil and 1 or r11, r12 = r12 or 0,
        r20 = r20 or 0, r21 = r21 or 0, r22 = r22 == nil and 1 or r22,
    }, CFrame)
end

local function normalize(v)
    local m = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if m == 0 then return Vector3.new(0, 0, 0) end
    return Vector3.new(v.x / m, v.y / m, v.z / m)
end

CFrame.__index = function(self, key)
    if key == "Position" then return Vector3.new(self.x, self.y, self.z) end
    if key == "Rotation" then
        return CFrame.new(0, 0, 0, self.r00, self.r01, self.r02, self.r10, self.r11, self.r12, self.r20, self.r21, self.r22)
    end
    if key == "RightVector" then return Vector3.new(self.r00, self.r10, self.r20) end
    if key == "UpVector" then return Vector3.new(self.r01, self.r11, self.r21) end
    if key == "LookVector" then return Vector3.new(-self.r02, -self.r12, -self.r22) end
    if key == "X" then return self.x end
    if key == "Y" then return self.y end
    if key == "Z" then return self.z end
    return CFrameMethods[key]
end

CFrameMethods = {
    GetComponents = function(cf)
        return cf.x, cf.y, cf.z,
            cf.r00, cf.r01, cf.r02,
            cf.r10, cf.r11, cf.r12,
            cf.r20, cf.r21, cf.r22
    end,
    Inverse = function(cf)
        local r00, r01, r02 = cf.r00, cf.r10, cf.r20
        local r10, r11, r12 = cf.r01, cf.r11, cf.r21
        local r20, r21, r22 = cf.r02, cf.r12, cf.r22
        local x = -(r00 * cf.x + r01 * cf.y + r02 * cf.z)
        local y = -(r10 * cf.x + r11 * cf.y + r12 * cf.z)
        local z = -(r20 * cf.x + r21 * cf.y + r22 * cf.z)
        return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end,
    Lerp = function(a, b, t)
        t = math.clamp(t, 0, 1)
        local right = normalize(Vector3.new(
            a.r00 + (b.r00 - a.r00) * t,
            a.r10 + (b.r10 - a.r10) * t,
            a.r20 + (b.r20 - a.r20) * t))
        local up = Vector3.new(
            a.r01 + (b.r01 - a.r01) * t,
            a.r11 + (b.r11 - a.r11) * t,
            a.r21 + (b.r21 - a.r21) * t)
        local dot = up.x * right.x + up.y * right.y + up.z * right.z
        up = normalize(Vector3.new(up.x - right.x * dot, up.y - right.y * dot, up.z - right.z * dot))
        local back = right:Cross(up)
        return CFrame.new(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t,
            right.x, up.x, back.x,
            right.y, up.y, back.y,
            right.z, up.z, back.z)
    end,
    ToObjectSpace = function(a, b) return a:Inverse() * b end,
    ToWorldSpace = function(a, b) return a * b end,
}
CFrame.__tostring = function(cf) return ("CFrame(%s)"):format(tostring(cf.Position)) end

CFrame.__mul = function(a, b)
    if getmetatable(b) == Vector3 then
        return Vector3.new(
            a.r00 * b.x + a.r01 * b.y + a.r02 * b.z + a.x,
            a.r10 * b.x + a.r11 * b.y + a.r12 * b.z + a.y,
            a.r20 * b.x + a.r21 * b.y + a.r22 * b.z + a.z)
    end
    local r00 = a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20
    local r01 = a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21
    local r02 = a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22
    local r10 = a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20
    local r11 = a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21
    local r12 = a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22
    local r20 = a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20
    local r21 = a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21
    local r22 = a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22
    return CFrame.new(
        a.r00 * b.x + a.r01 * b.y + a.r02 * b.z + a.x,
        a.r10 * b.x + a.r11 * b.y + a.r12 * b.z + a.y,
        a.r20 * b.x + a.r21 * b.y + a.r22 * b.z + a.z,
        r00, r01, r02, r10, r11, r12, r20, r21, r22)
end
CFrame.__add = function(a, v)
    return CFrame.new(a.x + v.x, a.y + v.y, a.z + v.z,
        a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CFrame.__sub = function(a, b)
    if getmetatable(b) == CFrame then
        return Vector3.new(a.x - b.x, a.y - b.y, a.z - b.z)
    end
    return CFrame.new(a.x - b.x, a.y - b.y, a.z - b.z,
        a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end

-- ============================================================
-- TIPOS SIMPLES
-- ============================================================
local Color3 = {}
Color3.__typeof = "Color3"
function Color3.new(r, g, b)
    return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(hex)
    hex = tostring(hex):gsub("#", "")
    return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

local Vector2 = {}
Vector2.__typeof = "Vector2"
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, Vector2) end

local UDim2 = {}
UDim2.__typeof = "UDim2"
function UDim2.fromOffset(x, y) return setmetatable({ X = x, Y = y }, UDim2) end
function UDim2.fromScale(x, y) return setmetatable({ X = x, Y = y }, UDim2) end

local function enumGroup(name, values)
    local group = {}
    for index, value in ipairs(values) do
        group[value] = setmetatable({ Name = value, Value = index, EnumType = name }, { __typeof = "EnumItem" })
    end
    return group
end

local Enum = {
    HumanoidDisplayDistanceType = enumGroup("HumanoidDisplayDistanceType", { "Viewer", "Subject", "None" }),
    HumanoidHealthDisplayType = enumGroup("HumanoidHealthDisplayType", { "DisplayWhenDamaged", "AlwaysOn", "AlwaysOff" }),
    HumanoidStateType = enumGroup("HumanoidStateType", { "Physics", "Running", "Jumping", "Freefall" }),
    CameraType = enumGroup("CameraType", { "Custom", "Scriptable", "Fixed", "Attach", "Watch", "Track", "Follow" }),
    BulkMoveMode = enumGroup("BulkMoveMode", { "FireCFrameChanged", "DontFireCFrameChanged" }),
    Material = enumGroup("Material", { "Plastic", "Neon", "Metal", "Glass", "Wood", "Slate", "Marble", "Granite", "Ice", "ForceField", "SmoothPlastic" }),
    PartType = enumGroup("PartType", { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" }),
    RaycastFilterType = enumGroup("RaycastFilterType", { "Exclude", "Include" }),
    UserInputType = enumGroup("UserInputType", { "MouseButton1", "MouseButton2", "MouseWheel", "Touch" }),
    KeyCode = enumGroup("KeyCode", { "Unknown", "Delete", "Escape", "F", "P", "W", "A", "S", "D", "Space", "LeftControl", "LeftShift" }),
    Font = enumGroup("Font", { "SourceSans", "SourceSansBold" }),
    CoreGuiType = enumGroup("CoreGuiType", { "Backpack", "Chat", "PlayerList", "Health", "All" }),
    RenderPriority = { Camera = { Value = 200 }, Last = { Value = 2000 } },
}
local EnumMt = { __index = function(_, key) return nil end }
setmetatable(Enum, EnumMt)

-- ============================================================
-- SEÑALES
-- ============================================================
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(fn)
    local entry = { fn = fn, connected = true }
    table.insert(self.handlers, entry)
    local connection = {}
    function connection:Disconnect()
        if not entry.connected then return end
        entry.connected = false
        for i, candidate in ipairs(self.handlers) do
            if candidate == entry then table.remove(self.handlers, i) break end
        end
    end
    return connection
end

function Signal:Fire(...)
    local snapshot = {}
    for i, entry in ipairs(self.handlers) do snapshot[i] = entry end
    for _, entry in ipairs(snapshot) do
        if entry.connected then entry.fn(...) end
    end
end

function Signal:Wait() return nil end

-- ============================================================
-- INSTANCES
-- ============================================================
local Instance = {}
local InstanceMt = {}
local InstanceMethods = {}
local INSTANCE_PROPS = {}

local CLASS_BASES = {
    Part = { "BasePart", "PVInstance" },
    MeshPart = { "BasePart", "PVInstance" },
    Model = { "PVInstance" },
    Humanoid = {},
    Motor6D = { "JointInstance" },
    Weld = { "JointInstance" },
    WeldConstraint = {},
    Script = { "BaseScript", "LuaSourceContainer" },
    LocalScript = { "BaseScript", "LuaSourceContainer" },
    Player = {},
    PlayerGui = { "LayerCollector", "GuiBase2d" },
    Camera = {},
    Folder = {},
    ScreenGui = { "LayerCollector", "GuiBase2d" },
    Frame = { "GuiObject", "GuiBase2d" },
    TextLabel = { "GuiObject", "GuiBase2d" },
    BillboardGui = { "LayerCollector", "GuiBase2d" },
    BindableEvent = {},
    Decal = {},
    Accessory = {},
    Tool = {},
    Sound = {},
    Workspace = {},
}

local function newInstance(className)
    local self = {
        ClassName = className,
        Name = className,
        _children = {},
        _parent = nil,
        _props = {},
        _destroyed = false,
    }
    local props = self._props
    -- Señales basicas de instancia (el HUD vigila PlayerGui/RageUI).
    props.ChildAdded = Signal.new()
    props.ChildRemoved = Signal.new()
    props._changed = {}
    props.Archivable = true
    if className == "Part" or className == "MeshPart" then
        props.CFrame = CFrame.new()
        props.Size = Vector3.new(1, 1, 1)
        props.Color = Color3.new(1, 1, 1)
        props.Transparency = 0
        props.Anchored = false
        props.CanCollide = true
        props.CanQuery = true
        props.CanTouch = true
        props.Massless = false
        props.CastShadow = true
        props.Material = Enum.Material.Plastic
        props.Shape = Enum.PartType.Block
        props.Position = Vector3.new()
    elseif className == "Humanoid" then
        props.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        props.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
        props.Enabled = true
        props.WalkSpeed = 16
        props.JumpPower = 50
        props.AutoRotate = true
        props.BreakJointsOnDeath = true
        props.EvaluateStateMachine = true
        props.Health = 100
    elseif className == "Motor6D" or className == "Weld" then
        props.C0 = CFrame.new()
        props.C1 = CFrame.new()
        props.Transform = CFrame.new()
        props.Part0 = nil
        props.Part1 = nil
    elseif className == "ScreenGui" or className == "BillboardGui" then
        props.Enabled = true
    elseif className == "Decal" then
        props.Transparency = 0
    elseif className == "Camera" then
        props.CFrame = CFrame.new()
        props.FieldOfView = 70
        props.CameraType = Enum.CameraType.Custom
        props.CameraSubject = nil
        props.ViewportSize = Vector2.new(1920, 1080)
    elseif className == "Player" then
        props.UserId = 0
        props.Character = nil
        props.CharacterAdded = Signal.new()
        props.CharacterRemoving = Signal.new()
    end
    return setmetatable(self, InstanceMt)
end

local function setParent(self, parent)
    -- rawset: `_parent` empieza en nil, así que una asignación normal
    -- dispararía __newindex y el valor acabaría en _props (Parent se lee
    -- con rawget y devolvía nil).
    local old = rawget(self, "_parent")
    if old and old._children then
        local siblings = old._children
        for i, child in ipairs(siblings) do
            if child == self then table.remove(siblings, i) break end
        end
    end
    if old and old.ChildRemoved then old.ChildRemoved:Fire(self) end
    rawset(self, "_parent", parent)
    if parent then
        table.insert(parent._children, self)
        if parent.ChildAdded then parent.ChildAdded:Fire(self) end
    end
end

InstanceMt.__index = function(self, key)
    if key == "Parent" then return rawget(self, "_parent") end
    if key == "ClassName" then return rawget(self, "ClassName") end
    if key == "Name" then return rawget(self, "Name") end
    local method = InstanceMethods[key]
    if method then return method end
    local props = rawget(self, "_props")
    local value = props[key]
    if value ~= nil then return value end
    return nil
end

InstanceMt.__newindex = function(self, key, value)
    if key == "Parent" then
        setParent(self, value)
        return
    end
    if key == "Name" then
        rawset(self, "Name", tostring(value))
        return
    end
    local props = rawget(self, "_props")
    local old = props[key]
    props[key] = value
    if key == "CFrame" then
        props.Position = value.Position
    end
    local changed = props._changed
    if changed and changed[key] and old ~= value then
        changed[key]:Fire(value)
    end
end

InstanceMt.__typeof = "Instance"
InstanceMt.__tostring = function(self) return ("%s(%s)"):format(self.ClassName, self.Name) end

function Instance.new(className)
    return newInstance(className)
end

function InstanceMethods:IsA(className)
    if self.ClassName == className then return true end
    if className == "Instance" then return true end
    for _, base in ipairs(CLASS_BASES[self.ClassName] or {}) do
        if base == className then return true end
    end
    return false
end

function InstanceMethods:GetChildren()
    local out = {}
    for i, child in ipairs(self._children) do out[i] = child end
    return out
end

function InstanceMethods:GetDescendants()
    local out = {}
    local function walk(node)
        for _, child in ipairs(node._children) do
            out[#out + 1] = child
            walk(child)
        end
    end
    walk(self)
    return out
end

function InstanceMethods:FindFirstChild(name)
    for _, child in ipairs(self._children) do
        if child.Name == name then return child end
    end
    return nil
end

function InstanceMethods:FindFirstChildOfClass(className)
    for _, child in ipairs(self._children) do
        if child.ClassName == className then return child end
    end
    return nil
end

function InstanceMethods:WaitForChild(name)
    return self:FindFirstChild(name)
end

function InstanceMethods:IsDescendantOf(ancestor)
    local node = self._parent
    while node do
        if node == ancestor then return true end
        node = node._parent
    end
    return false
end

function InstanceMethods:Destroy()
    for _, child in ipairs(self:GetChildren()) do
        child:Destroy()
    end
    setParent(self, nil)
    self._destroyed = true
end

function InstanceMethods:GetPropertyChangedSignal(prop)
    local props = rawget(self, "_props")
    local changed = props._changed
    if not changed then
        changed = {}
        props._changed = changed
    end
    local signal = changed[prop]
    if not signal then
        signal = Signal.new()
        changed[prop] = signal
    end
    return signal
end

local function cloneInstance(original)
    local map = {}
    local function copy(source)
        local clone = newInstance(source.ClassName)
        clone.Name = source.Name
        map[source] = clone
        for key, value in pairs(source._props) do
            if key ~= "Position" and key ~= "ChildAdded" and key ~= "ChildRemoved" and key ~= "_changed" then
                clone._props[key] = value
            end
        end
        for _, child in ipairs(source._children) do
            setParent(copy(child), clone)
        end
        return clone
    end
    local root = copy(original)
    local function remap(node)
        for _, key in ipairs({ "Part0", "Part1", "Adornee", "PrimaryPart" }) do
            local value = node._props[key]
            if value ~= nil and map[value] then node._props[key] = map[value] end
        end
        for _, child in ipairs(node._children) do remap(child) end
    end
    remap(root)
    return root
end

function InstanceMethods:Clone()
    return cloneInstance(self)
end

function InstanceMethods:GetPivot()
    local primary = self._props.PrimaryPart
    if primary then return primary.CFrame end
    for _, child in ipairs(self._children) do
        if child:IsA("BasePart") then return child.CFrame end
    end
    return CFrame.new()
end

function InstanceMethods:PivotTo(target)
    local delta = target * self:GetPivot():Inverse()
    local function move(node)
        for _, child in ipairs(node._children) do
            if child:IsA("BasePart") and not child:IsA("Model") then
                child.CFrame = delta * child.CFrame
            end
            move(child)
        end
    end
    move(self)
end

function InstanceMethods:GetExtentsSize()
    return Vector3.new(4, 5, 2)
end

function InstanceMethods:ScaleTo() end
function InstanceMethods:ChangeState() end

-- ============================================================
-- SERVICIOS
-- ============================================================
local workspace = newInstance("Workspace")
workspace.Name = "Workspace"
local camera = newInstance("Camera")
camera.Name = "Camera"
workspace.CurrentCamera = camera

local RunService = {
    Heartbeat = Signal.new(),
    RenderStepped = Signal.new(),
    PreRender = Signal.new(),
    IsStudio = false,
}
function RunService:BindToRenderStep() end
function RunService:UnbindFromRenderStep() end

local UserInputService = {
    InputBegan = Signal.new(),
    InputChanged = Signal.new(),
    InputEnded = Signal.new(),
    MouseIconEnabled = true,
}
function UserInputService:IsKeyDown() return false end
function UserInputService:GetMouseLocation() return Vector2.new(960, 540) end

local testPlayers = {}

local Players = newInstance("Player")
Players.Name = "Players"
function Players:GetPlayers()
    return { testPlayers[1], testPlayers[2] }
end
function Players:GetPlayerByUserId(userId)
    for _, player in ipairs(self:GetPlayers()) do
        if player.UserId == userId then return player end
    end
    return nil
end

local Lighting = newInstance("Lighting")
Lighting.ClockTime = 14
Lighting.ExposureCompensation = 0
Lighting.FogColor = Color3.new(0.5, 0.5, 0.5)
Lighting.FogEnd = 100000
Lighting.FogStart = 0
Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
Lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
Lighting.Brightness = 2
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.2

local StarterGui = newInstance("ScreenGui")
local CoreGui = newInstance("ScreenGui")
local TweenService = { Create = function() return { Play = function() end } end }

-- ============================================================
-- JSON (para HttpService)
-- ============================================================
local function jsonEscape(text)
    return '"' .. tostring(text):gsub('[%c"\\]', function(char)
        local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return map[char] or ("\\u%04x"):format(string.byte(char))
    end) .. '"'
end

local function isArray(t)
    local count = 0
    for key in pairs(t) do
        if type(key) ~= "number" then return false end
        count = count + 1
    end
    if count == 0 then return false end
    for i = 1, count do
        if t[i] == nil then return false end
    end
    return true
end

local function jsonEncode(value)
    local kind = typeof(value)
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return "null" end
        return tostring(value)
    elseif kind == "string" then
        return jsonEscape(value)
    elseif kind == "boolean" then
        return value and "true" or "false"
    elseif kind == "table" then
        if isArray(value) then
            local parts = {}
            for i, item in ipairs(value) do parts[i] = jsonEncode(item) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do
            if type(key) == "string" then keys[#keys + 1] = key end
        end
        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = jsonEscape(key) .. ":" .. jsonEncode(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function jsonDecode(text)
    local position = 1
    local function skip()
        while position <= #text and text:sub(position, position):match("%s") do position = position + 1 end
    end
    local parseValue
    local function parseString()
        position = position + 1
        local out = {}
        while position <= #text do
            local char = text:sub(position, position)
            if char == '"' then position = position + 1 return table.concat(out) end
            if char == "\\" then
                position = position + 1
                local esc = text:sub(position, position)
                local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if esc == "u" then
                    local code = tonumber(text:sub(position + 1, position + 4), 16)
                    out[#out + 1] = utf8.char(code)
                    position = position + 5
                else
                    out[#out + 1] = map[esc] or esc
                    position = position + 1
                end
            else
                out[#out + 1] = char
                position = position + 1
            end
        end
        error("JSON string sin cerrar")
    end
    local function parseNumber()
        local start = position
        while position <= #text and text:sub(position, position):match("[%-%d%.eE%+]") do position = position + 1 end
        return tonumber(text:sub(start, position - 1))
    end
    parseValue = function()
        skip()
        local char = text:sub(position, position)
        if char == "{" then
            position = position + 1
            local object = {}
            skip()
            if text:sub(position, position) == "}" then position = position + 1 return object end
            while true do
                skip()
                local key = parseString()
                skip()
                assert(text:sub(position, position) == ":", "JSON esperaba ':'")
                position = position + 1
                object[key] = parseValue()
                skip()
                local nextChar = text:sub(position, position)
                position = position + 1
                if nextChar == "}" then return object end
                assert(nextChar == ",", "JSON esperaba ',' o '}'")
            end
        elseif char == "[" then
            position = position + 1
            local array = {}
            skip()
            if text:sub(position, position) == "]" then position = position + 1 return array end
            while true do
                array[#array + 1] = parseValue()
                skip()
                local nextChar = text:sub(position, position)
                position = position + 1
                if nextChar == "]" then return array end
                assert(nextChar == ",", "JSON esperaba ',' o ']'")
            end
        elseif char == '"' then
            return parseString()
        elseif text:sub(position, position + 3) == "true" then
            position = position + 4 return true
        elseif text:sub(position, position + 4) == "false" then
            position = position + 5 return false
        elseif text:sub(position, position + 3) == "null" then
            position = position + 4 return nil
        else
            return parseNumber()
        end
    end
    return parseValue()
end

local HttpService = {
    JSONEncode = function(_, value) return jsonEncode(value) end,
    JSONDecode = function(_, text) return jsonDecode(text) end,
}

-- ============================================================
-- FILESYSTEM EN MEMORIA
-- ============================================================
local FS_FILES = {}
local FS_FOLDERS = {}
local function normPath(path) return tostring(path):gsub("\\", "/") end

local function writefile(path, data)
    FS_FILES[normPath(path)] = tostring(data)
end
local function readfile(path)
    local data = FS_FILES[normPath(path)]
    if not data then error("archivo no encontrado: " .. tostring(path)) end
    return data
end
local function isfile(path) return FS_FILES[normPath(path)] ~= nil end
local function makefolder(path) FS_FOLDERS[normPath(path)] = true end
local function delfile(path) FS_FILES[normPath(path)] = nil end
local function listfiles(directory)
    local prefix = normPath(directory):gsub("/+$", "") .. "/"
    local out = {}
    for path in pairs(FS_FILES) do
        if path:sub(1, #prefix) == prefix and not path:sub(#prefix + 1):find("/") then
            out[#out + 1] = path
        end
    end
    table.sort(out)
    return out
end

-- ============================================================
-- GLOBALES DEL ENTORNO
-- ============================================================
local game = {
    PlaceId = 1234,
    JobId = "test",
}
function game:GetService(name)
    local services = {
        RunService = RunService,
        UserInputService = UserInputService,
        Players = Players,
        Lighting = Lighting,
        TweenService = TweenService,
        StarterGui = StarterGui,
        CoreGui = CoreGui,
        HttpService = HttpService,
        Workspace = workspace,
    }
    if name == "Workspace" then return workspace end
    return services[name] or newInstance(name)
end
function game:GetObjects() error("GetObjects no disponible en test") end
function game:HttpGet() error("HttpGet no disponible en test") end

local typeof = function(value)
    if type(value) == "table" then
        local mt = getmetatable(value)
        if mt and mt.__typeof then return mt.__typeof end
    end
    return type(value)
end

local task = {
    wait = function() return 0 end,
    spawn = function(fn, ...) fn(...) end,
    defer = function(fn, ...) fn(...) end,
    delay = function(_, fn, ...) fn(...) end,
    cancel = function() end,
}

local clipboard = ""
local setclipboard = function(text) clipboard = tostring(text) end

-- Publica los globos que los módulos esperan.
Instance = Instance
Enum = Enum
CFrame = CFrame
Vector3 = Vector3
Color3 = Color3
Vector2 = Vector2
UDim2 = UDim2
game = game
workspace = workspace
RunService = RunService
UIS = UserInputService
UserInputService = UserInputService
Players = Players
Lighting = Lighting
task = task
typeof = typeof
warn = function(...) print("[warn]", ...) end
writefile = writefile
readfile = readfile
isfile = isfile
makefolder = makefolder
delfile = delfile
listfiles = listfiles
setclipboard = setclipboard
RaycastParams = { new = function() return {} end }

-- ============================================================
-- FIXTURE
-- ============================================================
local function makeCharacter(name, offsetZ)
    local model = newInstance("Model")
    model.Name = name

    local function part(partName, size, cframe)
        local base = newInstance("Part")
        base.Name = partName
        base.Size = size
        base.CFrame = cframe
        base.Parent = model
        return base
    end

    local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 5, offsetZ or 0))
    model.PrimaryPart = root
    local lower = part("LowerTorso", Vector3.new(2, 2, 1), CFrame.new(0, 4, offsetZ or 0))
    local upper = part("UpperTorso", Vector3.new(2, 2, 1), CFrame.new(0, 5.5, offsetZ or 0))
    local head = part("Head", Vector3.new(2, 1, 1), CFrame.new(0, 7, offsetZ or 0))
    local lua = part("LeftUpperArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 5.5, offsetZ or 0))
    local lla = part("LeftLowerArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3.5, offsetZ or 0))
    local rua = part("RightUpperArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 5.5, offsetZ or 0))
    local rla = part("RightLowerArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3.5, offsetZ or 0))
    local lul = part("LeftUpperLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 2, offsetZ or 0))
    local lll = part("LeftLowerLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 0, offsetZ or 0))
    local rul = part("RightUpperLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 2, offsetZ or 0))
    local rll = part("RightLowerLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 0, offsetZ or 0))

    local function motor(motorName, part0, part1, c0, c1)
        local joint = newInstance("Motor6D")
        joint.Name = motorName
        joint.Part0 = part0
        joint.Part1 = part1
        joint.C0 = c0 or CFrame.new()
        joint.C1 = c1 or CFrame.new()
        joint.Parent = model
        return joint
    end

    motor("Root", root, lower, CFrame.new(0, -1, 0), CFrame.new(0, 1, 0))
    motor("Waist", lower, upper, CFrame.new(0, 0, 0), CFrame.new(0, 0, 0))
    motor("Neck", upper, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
    motor("LeftShoulder", upper, lua, CFrame.new(-1, 0.5, 0), CFrame.new(0, 1, 0))
    motor("LeftElbow", lua, lla, CFrame.new(0, -1, 0), CFrame.new(0, 1, 0))
    motor("RightShoulder", upper, rua, CFrame.new(1, 0.5, 0), CFrame.new(0, 1, 0))
    motor("RightElbow", rua, rla, CFrame.new(0, -1, 0), CFrame.new(0, 1, 0))
    motor("LeftHip", lower, lul, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
    motor("LeftKnee", lul, lll, CFrame.new(0, -1, 0), CFrame.new(0, 1, 0))
    motor("RightHip", lower, rul, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
    motor("RightKnee", rul, rll, CFrame.new(0, -1, 0), CFrame.new(0, 1, 0))

    local humanoid = newInstance("Humanoid")
    humanoid.Parent = model
    local animator = newInstance("Animator")
    animator.Parent = humanoid

    return model
end

local localCharacter = makeCharacter("LocalRig", 0)
local otherCharacter = makeCharacter("OtherRig", 6)

local localPlayer = newInstance("Player")
localPlayer.Name = "Tester"
localPlayer.UserId = 42
localPlayer.Character = localCharacter
localPlayer.Parent = Players

local otherPlayer = newInstance("Player")
otherPlayer.Name = "Companero"
otherPlayer.UserId = 77
otherPlayer.Character = otherCharacter
otherPlayer.Parent = Players

testPlayers[1] = localPlayer
testPlayers[2] = otherPlayer
Players.LocalPlayer = localPlayer

local playerScripts = newInstance("Folder")
playerScripts.Name = "PlayerScripts"
playerScripts.Parent = localPlayer
localCharacter.Parent = workspace
otherCharacter.Parent = workspace

-- ============================================================
-- CARGA DE MÓDULOS
-- ============================================================
-- El CLI de Luau expone _G como solo lectura y las asignaciones
-- `game = game` tocan la local, no una global. Por eso el entorno de los
-- módulos se arma con los valores del stub de forma explícita; `_G`
-- aporta la librería estándar (string, math, table, pcall...).
local env = setmetatable({
    Instance = Instance,
    Enum = Enum,
    CFrame = CFrame,
    Vector3 = Vector3,
    Color3 = Color3,
    Vector2 = Vector2,
    UDim2 = UDim2,
    game = game,
    workspace = workspace,
    RunService = RunService,
    UserInputService = UserInputService,
    Players = Players,
    Lighting = Lighting,
    task = task,
    typeof = typeof,
    warn = warn,
    writefile = writefile,
    readfile = readfile,
    isfile = isfile,
    makefolder = makefolder,
    delfile = delfile,
    listfiles = listfiles,
    setclipboard = setclipboard,
    RaycastParams = RaycastParams,
}, { __index = _G })
env._G = env
env.UCam = {}

local LOAD_ORDER = {
    "core/00_config.lua",
    "core/10_utils.lua",
    "core/05_persistence.lua",
    "props/45_props.lua",
    "demo/92_recorder.lua",
    "demo/94_player.lua",
    "demo/96_file.lua",
    "demo/98_takes.lua",
}

for _, path in ipairs(LOAD_ORDER) do
    local source = SOURCES[path]
    assert(source, "Falta la fuente " .. path)
    local fn, compileError = loadstring(source, path)
    assert(fn, "Error de sintaxis en " .. path .. ": " .. tostring(compileError))
    setfenv(fn, env)
    local ok, runError = pcall(fn)
    assert(ok, "Error cargando " .. path .. ": " .. tostring(runError))
end

local UCam = env.UCam
assert(type(UCam.demoStartRecording) == "function", "demoStartRecording no registrada")
assert(type(UCam.demoPlay) == "function", "demoPlay no registrada")
assert(type(UCam.demoTakeStart) == "function", "demoTakeStart no registrada")
assert(type(UCam.demoEncode) == "function", "demoEncode no registrada")

-- ============================================================
-- UTILIDADES DE PRUEBA
-- ============================================================
local passed, failed = 0, 0
local currentTest = ""

local function test(name, fn)
    currentTest = name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(("  ok   %s"):format(name))
    else
        failed = failed + 1
        print(("  FAIL %s\n       %s"):format(name, tostring(err)))
    end
end

local function near(actual, expected, epsilon, label)
    epsilon = epsilon or 1e-3
    if math.abs((tonumber(actual) or 0) - (tonumber(expected) or 0)) > epsilon then
        error(("%s: esperaba %.4f, obtuve %s"):format(label or "valor", expected, tostring(actual)), 2)
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error(("%s: esperaba %s, obtuve %s"):format(label or "valor", tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(value, label)
    if not value then error(label or "se esperaba un valor verdadero", 2) end
end

local function fireHeartbeat(dt)
    RunService.Heartbeat:Fire(dt or 0.05)
end

local function resetDemoState()
    UCam.Demo.IncludeOthers = false
    if UCam.Demo.Current then UCam.Demo.Current.takes = {} end
    UCam.DemoTakes.Items = {}
    UCam.DemoTakes.Selected = 0
    UCam.demoSequenceStop()
    UCam.demoTakeStop()
    UCam.demoStop()
    UCam.Demo.Recording = false
    UCam.Demo.Current = nil
    UCam.Demo.Duration = 0
    UCam.Demo.Playhead = 0
    UCam.Demo.Paused = false
    UCam.Demo.Elapsed = 0
    UCam.Demo._accum = 0
    UCam.Demo._ghosts = {}
    UCam.Demo._recordingDemo = nil
    UCam.Demo._actorByKey = {}
    UCam.DemoTakes.Items = {}
    UCam.DemoTakes.Selected = 0
    UCam.Props.Items = {}
    UCam.Props.Selected = 0
    localCharacter:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(0, 5, 0)
    for _, descendant in ipairs(localCharacter:GetDescendants()) do
        if descendant.ClassName == "Motor6D" then
            descendant.Transform = CFrame.new()
        end
    end
end

local function recordSamples(count, mover)
    for i = 1, count do
        mover(i)
        fireHeartbeat(0.05)
    end
end

-- ============================================================
-- PRUEBAS
-- ============================================================
print("\n== Replay / Demo ==")

test("el grabador rechaza empezar sin personaje", function()
    resetDemoState()
    local character = UCam.player.Character
    UCam.player.Character = nil
    local ok, err = UCam.demoStartRecording()
    UCam.player.Character = character
    eq(ok, false, "grabar sin personaje")
    truthy(type(err) == "string", "mensaje de error")
end)

local recordedDemo

test("graba 10 muestras de un actor a 20 Hz", function()
    resetDemoState()
    UCam.Demo.Rate = 20
    UCam.Demo.IncludeProps = false
    local ok, err = UCam.demoStartRecording()
    truthy(ok, "inicio de grabacion: " .. tostring(err))

    local root = localCharacter:FindFirstChild("HumanoidRootPart")
    local rootJoint = localCharacter:FindFirstChild("Root")
    recordSamples(10, function(i)
        root.CFrame = CFrame.new(0, 5, i * 0.5)
        rootJoint.Transform = CFrame.new(0, 0, i * 0.1)
    end)

    local stopped, demo = UCam.demoStopRecording("Demo de prueba")
    truthy(stopped, "fin de grabacion: " .. tostring(demo))
    recordedDemo = demo

    eq(#demo.actors, 1, "actores grabados")
    eq(demo.actors[1].frameCount, 11, "frames grabados (incluye t=0)")
    near(demo.duration, 0.5, 1e-6, "duracion")
    near(demo.actors[1].times[1], 0, 1e-6, "muestra inicial")
    near(demo.actors[1].times[11], 0.5, 1e-6, "ultimo tiempo")
    truthy(demo.actors[1].chunk ~= "", "bloque binario")
    eq(#demo.actors[1].joints, 11, "articulaciones")
end)

test("muestrea poses interpoladas al reproducir", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    eq(#UCam.Demo._ghosts, 1, "rig fantasma")
    local ghost = UCam.Demo._ghosts[1]
    truthy(ghost.kind == "clone", "se clona el personaje real")

    UCam.demoSeek(0.25)
    near(ghost.root.CFrame.Position.Z, 2.5, 0.02, "raiz en t=0.25")

    UCam.demoSeek(0.125)
    near(ghost.root.CFrame.Position.Z, 1.25, 0.05, "interpolacion entre frames")

    local lower = ghost.parts["LowerTorso"]
    truthy(lower ~= nil, "torso inferior del clon")
    truthy(lower.CFrame.Position.Z ~= ghost.root.CFrame.Position.Z, "pose articulada")
end)

test("recorta el tiempo al rango del demo", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    local ghost = UCam.Demo._ghosts[1]
    UCam.demoSeek(2)
    near(UCam.Demo.Playhead, 0.5, 1e-6, "playhead recortado")
    eq(ghost.active, true, "ultimo frame visible")
    UCam.demoSeek(-5)
    near(UCam.Demo.Playhead, 0, 1e-6, "playhead en cero")
    eq(ghost.active, true, "primer frame visible")
end)

test("graba otros jugadores en paralelo", function()
    resetDemoState()
    UCam.Demo.IncludeOthers = true
    UCam.Demo.IncludeProps = false
    local ok, err = UCam.demoStartRecording({ rate = 20 })
    truthy(ok, "grabacion multi-actor: " .. tostring(err))
    local otherRoot = otherCharacter:FindFirstChild("HumanoidRootPart")
    recordSamples(4, function(i)
        otherRoot.CFrame = CFrame.new(4, 5, i)
    end)
    local stopped, demo = UCam.demoStopRecording("Dos actores")
    truthy(stopped, "fin multi-actor")
    eq(#demo.actors, 2, "actores grabados")
    local names = {}
    for _, track in ipairs(demo.actors) do names[track.name] = true end
    truthy(names["Tester"] and names["Companero"], "nombres de los dos jugadores")

    local decoded = UCam.demoDecode(UCam.demoEncode(demo))
    eq(#decoded.actors, 2, "actores tras decodificar")
end)

test("codifica y decodifica el demo sin perder datos", function()
    local blob, err = UCam.demoEncode(recordedDemo)
    truthy(blob, "encode: " .. tostring(err))
    truthy(#blob > 100, "blob con datos")

    local decoded, decodeError = UCam.demoDecode(blob)
    truthy(decoded, "decode: " .. tostring(decodeError))
    eq(#decoded.actors, 1, "actores")
    eq(decoded.actors[1].frameCount, 11, "frames")
    eq(decoded.actors[1].joints[1].name, recordedDemo.actors[1].joints[1].name, "nombre de joint")
    eq(decoded.actors[1].id, "p:42", "id exportado por UserId")
    near(decoded.duration, recordedDemo.duration, 1e-6, "duracion")
    near(decoded.actors[1].times[6], 0.25, 1e-6, "tiempo recuperado")
    eq(#decoded.actors[1].chunk, #recordedDemo.actors[1].chunk, "bytes del bloque")

    resetDemoState()
    UCam.demoSetCurrent(decoded)
    local ghost = UCam.Demo._ghosts[1]
    UCam.demoSeek(0.25)
    near(ghost.root.CFrame.Position.Z, 2.5, 0.02, "playback del archivo decodificado")
end)

test("base64 preserva el archivo binario", function()
    local blob = UCam.demoEncode(recordedDemo)
    local encoded = UCam.demoBase64Encode(blob)
    truthy(#encoded > #blob, "base64 crece")
    local decoded, err = UCam.demoBase64Decode(encoded)
    truthy(decoded, "decode base64: " .. tostring(err))
    eq(#decoded, #blob, "longitud")
    eq(decoded, blob, "contenido")
end)

test("guarda, lista, carga y elimina en el filesystem", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    local saved, fileOrError = UCam.demoSaveAs("Prueba FS")
    truthy(saved, "guardar: " .. tostring(fileOrError))
    eq(fileOrError, "Prueba_FS.ucamdemo", "nombre de archivo")

    local path = UCam.demoFolder() .. "/Prueba_FS.ucamdemo"
    truthy(isfile(path), "archivo escrito en " .. path)

    local options = UCam.demoLibraryOptions()
    truthy(#options >= 1, "biblioteca")
    truthy(tostring(options[1]):find("Prueba FS", 1, true) ~= nil, "nombre en la lista")

    local loaded, demoOrError = UCam.demoLoadFile(1)
    truthy(loaded, "cargar: " .. tostring(demoOrError))
    eq(UCam.Demo.Current.name, "Prueba FS", "nombre cargado")
    near(UCam.Demo.Duration, 0.5, 1e-6, "duracion cargada")

    local deleted = UCam.demoDeleteFile(1)
    truthy(deleted, "eliminar")
    truthy(not isfile(path), "archivo borrado")
end)

test("marca momentos del demo", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    UCam.demoSeek(0.2)
    truthy(UCam.demoAddMarker("golpe"), "marca")
    eq(#UCam.Demo.Current.markers, 1, "marcas")
    near(UCam.Demo.Current.markers[1].t, 0.2, 1e-6, "tiempo de la marca")
end)

test("graba props junto al actor y los reproduce", function()
    resetDemoState()
    local prop = newInstance("Part")
    prop.Name = "UCam_Prop_1"
    prop.Size = Vector3.new(2, 2, 2)
    prop.CFrame = CFrame.new(0, 1, 0)
    prop.Parent = workspace
    UCam.Props.Items = {
        { assetId = 1, name = "Caja", model = prop, scale = 1, canCollide = false },
    }
    UCam.Props.Selected = 1
    UCam.Demo.IncludeProps = true

    UCam.demoStartRecording({ rate = 20 })
    recordSamples(6, function(i)
        prop.CFrame = CFrame.new(0, 1, i)
    end)
    local _, demo = UCam.demoStopRecording("Con props")
    truthy(demo.props ~= nil, "pista de props")
    eq(#demo.props.items, 1, "props grabados")
    eq(demo.props.frameCount, 7, "frames de props (incluye t=0)")

    local blob = UCam.demoEncode(demo)
    local decoded = UCam.demoDecode(blob)
    near(decoded.props.times[4], 0.15, 1e-6, "tiempo de props al cargar")

    resetDemoState()
    UCam.Props.Items = {
        { assetId = 1, name = "Caja", model = prop, scale = 1, canCollide = false },
    }
    UCam.Props.Selected = 1
    UCam.demoSetCurrent(decoded)
    UCam.demoSeek(0.25)
    near(prop.CFrame.Position.Z, 5, 0.6, "prop en t=0.25")
    prop:Destroy()
end)

test("reproduce el demo avanzando con Heartbeat", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    UCam.freeCamEnabled = false
    UCam.toggleFreeCam = function() UCam.freeCamEnabled = true end

    truthy(UCam.demoPlay(), "play")
    fireHeartbeat(0.1)
    near(UCam.Demo.Playhead, 0.1, 1e-6, "playhead")
    UCam.demoPause()
    eq(UCam.Demo.Paused, true, "pausa")
    UCam.demoStop()
    eq(#UCam.Demo._ghosts, 0, "fantasmas liberados")
end)

test("graba una toma de camara y la reproduce", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    UCam.freeCamEnabled = true
    UCam.toggleFreeCam = function() UCam.freeCamEnabled = true end
    UCam.demoSeek(0.1)

    local ok, err = UCam.demoTakeStart("Toma A", 1)
    truthy(ok, "inicio de toma: " .. tostring(err))
    for i = 1, 22 do
        camera.CFrame = CFrame.new(i, 6, 0)
        camera.FieldOfView = 60 + (i % 10)
        fireHeartbeat(0.05)
    end
    eq(UCam.DemoTakes._recording, false, "toma cerrada")
    local takes = UCam.Demo.Current.takes
    eq(#takes, 1, "tomas guardadas")
    truthy(#takes[1].route >= 5, "muestras del recorrido")
    near(takes[1].tIn, 0.1, 1e-6, "entrada de la toma")

    local played = UCam.demoTakePlay(1)
    truthy(played, "reproducir toma")
    truthy(UCam.DemoCamera ~= nil, "hook de camara activo")
    for _ = 1, 100 do
        if not UCam.DemoCamera then break end
        UCam.DemoCamera(0.016)
    end
    truthy(UCam.DemoCamera == nil, "hook liberado al terminar")
    truthy(camera.CFrame.Position.X > 1, "camara movida por la toma")
end)

test("secuencia encadena tomas y restaura el render", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    UCam.freeCamEnabled = true
    UCam.toggleFreeCam = function() UCam.freeCamEnabled = true end
    local takes = UCam.Demo.Current.takes
    eq(#takes, 0, "demo limpio de tomas")

    -- Crea dos tomas cortas directamente para probar la secuencia.
    takes[1] = {
        name = "A", tIn = 0, tOut = 0.2, duration = 0.2, easing = "Linear",
        route = {
            { t = 0, cf = { 0, 6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, fov = 70 },
            { t = 0.2, cf = { 4, 6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, fov = 60 },
        },
    }
    takes[2] = {
        name = "B", tIn = 0.1, tOut = 0.3, duration = 0.2, easing = "Linear",
        route = {
            { t = 0, cf = { 0, 8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, fov = 70 },
            { t = 0.2, cf = { -4, 8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, fov = 60 },
        },
    }
    UCam.DemoTakes.Items = takes

    local ok, err = UCam.demoSequenceStart(1)
    truthy(ok, "inicio de secuencia: " .. tostring(err))
    eq(UCam.DemoTakes.SequencePlaying, true, "secuencia activa")
    eq(UCam.DemoTakes._renderActive, true, "modo render")

    local guard = 0
    while UCam.DemoTakes.SequencePlaying and guard < 200 do
        guard = guard + 1
        UCam.DemoCamera(0.05)
    end
    eq(UCam.DemoTakes.SequencePlaying, false, "secuencia terminada")
    eq(UCam.DemoTakes._renderActive, false, "render restaurado")
    eq(UCam.DemoCamera, nil, "camara devuelta al nucleo")
end)

test("el estado resume actores, frames y tomas", function()
    resetDemoState()
    UCam.demoSetCurrent(recordedDemo)
    local status = UCam.demoStatus()
    eq(status.actors, 1, "actores")
    eq(status.frames, 11, "frames")
    truthy(status.hasDemo, "demo cargado")
    truthy(UCam.demoStatusText():find("actores", 1, true) ~= nil, "texto de estado")
end)

test("oculta RageUI con el HUD y la vigila si reaparece", function()
    local playerGui = newInstance("PlayerGui")
    playerGui.Name = "PlayerGui"
    playerGui.Parent = UCam.player

    local rage = newInstance("ScreenGui")
    rage.Name = "RageUI"
    rage.Enabled = true
    UCam.Hud.Hidden = true
    rage.Parent = playerGui
    eq(rage.Enabled, false, "RageUI oculta al aparecer con el HUD oculto")

    UCam.Hud.Hidden = false
    UCam.restoreHudInstances()
    eq(rage.Enabled, true, "RageUI restaurada al mostrar el HUD")

    UCam.Hud.Hidden = true
    local rage2 = newInstance("ScreenGui")
    rage2.Name = "RageUI"
    rage2.Enabled = true
    rage2.Parent = playerGui
    eq(rage2.Enabled, false, "RageUI nueva oculta")

    rage2.Enabled = true
    eq(rage2.Enabled, false, "reabrir RageUI no la muestra")

    UCam.Hud.Hidden = false
    UCam.restoreHudInstances()
    eq(rage2.Enabled, true, "RageUI restaurada al final")

    -- RageUI tambien puede ser una carpeta que se llena despues.
    UCam.Hud.Hidden = true
    local folder = newInstance("Folder")
    folder.Name = "RageUI"
    folder.Parent = playerGui
    local nested = newInstance("ScreenGui")
    nested.Name = "RageUI"
    nested.Enabled = true
    nested.Parent = folder
    eq(nested.Enabled, false, "RageUI anidada oculta al crearse")
    UCam.Hud.Hidden = false
    UCam.restoreHudInstances()
    eq(nested.Enabled, true, "RageUI anidada restaurada")

    playerGui:Destroy()
end)

-- ============================================================
-- RESULTADO
-- ============================================================
print(("\n%d pruebas correctas, %d fallidas"):format(passed, failed))
if failed > 0 then
    error(("%d pruebas fallaron"):format(failed))
end
