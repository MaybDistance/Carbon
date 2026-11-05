--[[
    CARBON // SIGNAL
    VERSION 3.3.0 ASTER - SKIN SYSTEM + EXTENDED FEATURES

    AIM:
      - Keyboard / mouse aimlock key selection
      - Hold / Toggle / Always activation
      - Target selection, prediction and offsets
      - FOV circle and target indicator
      - Camera-priority bind so Arsenal's scriptable camera cannot overwrite it

    ESP:
      - Boxes, names, health, distance, tracers, highlights
      - Skeleton, display names, visibility filter

    VISUALS:
      - Chams (highlight fill and solid body clones)
      - Crosshair customization
      - Rainbow viewmodel
      - Melee changer
      - Weapon skin changer
      - Skin and melee previews
      - Auto melee and skin reapplication

    LOCAL:
      - Fullbright, camera FOV
      - Walk speed, jump power, infinite jump, noclip
      - Anti-AFK, rejoin

    SKIN FIXES (3.2.2):
      - Remove restores Material / Color / BrickColor, not just textures
      - Restore Melee no longer changes the UI without changing the value
      - Collector melee suffixes no longer trigger the auto-reapply loop
      - Unload rebuilds the real viewmodel instead of stripping its skin
      - The viewmodel rebuild is what makes swapped melee hits register

    FIXES (3.2.3):
      - Camera FOV now applies after Arsenal's per-frame FieldOfView write
      - Reloads tear down every earlier instance instead of stacking a second
        ESP / aim / skin watcher

    FIXES (3.2.4):
      - Melee rebuild now uses the selected Melees folder and the game's deploy
        speed, exactly like Weapons:1654. Every knife now gets its own Fire
        animation, so swapped melees swing and hit like the real weapon instead
        of replaying the base knife swing

    NEW IN 3.3.0:
      AIM:
       - Target highlight chase light on the locked player
      ESP:
       - Head dots, weapon labels and translucent box fills
       - Off-screen directional arrows
       - Rotating corner radar with range and size controls
      VISUALS:
       - World tint (ColorCorrection) with colour, brightness and contrast
       - Remove skybox
      LOCAL:
       - Fly with speed control
       - Spin, hip height
       - Time of day, remove fog
       - Click teleport
       - Reset character, copy job id, server hop
      PLAYERS:
       - Live player list with teleport, spectate, copy name and camera reset

    CLEANUP:
      - Shared CARBON cleanup
      - Skin watcher shutdown
      - Viewmodel color restoration
      - Chams and local feature restoration
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==================================================
-- CLEANUP
--==================================================

-- Tear down every earlier CARBON instance. The list keeps cleanup functions
-- from previous runs so a reload cannot leave a second copy of the hub (and a
-- second ESP / aim / skin watcher) alive alongside this one.
if type(_G.CARBON_CLEANUPS) == "table" then
    for _, fn in ipairs(_G.CARBON_CLEANUPS) do
        pcall(fn)
    end

    table.clear(_G.CARBON_CLEANUPS)
else
    _G.CARBON_CLEANUPS = {}
end

if _G.CARBON_CLEANUP then
    pcall(_G.CARBON_CLEANUP)
end

local Connections = {}
local Destroyed = false

local function Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local SkinDestroy

--==================================================
-- CONFIG
--==================================================

local Config = {
    -- AIM
    AimEnabled = false,
    AimActivation = "Hold",
    AimKeyType = "Mouse",
    AimKeyCode = Enum.UserInputType.MouseButton2,

    AimMode = "Closest to Crosshair",
    AimPart = "Head",
    AimFOV = 180,
    AimDistance = 1000,
    Smoothness = 8,
    Prediction = 0,
    AimOffsetX = 0,
    AimOffsetY = 0,
    StickyTarget = true,
    TeamCheck = true,
    VisibilityCheck = true,
    ShowFOV = true,
    TargetIndicator = true,
    AimTargetHighlight = false,
    TargetHighlightColor = Color3.fromRGB(255, 90, 90),

    -- ESP
    ESPEnabled = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPDisplayName = false,
    ESPHealth = true,
    ESPDistance = true,
    ESPTracers = false,
    ESPHighlights = false,
    ESPSkeleton = false,
    ESPTeamCheck = true,
    ESPVisibleOnly = false,
    ESPMaxDistance = 1500,

    -- ESP EXTRAS
    ESPHeadDot = false,
    ESPWeapon = false,
    ESPBoxFill = false,
    ESPArrows = false,
    ESPRadar = false,
    RadarSize = 160,
    RadarRange = 300,
    RadarOpacity = 0.35,
    RadarRotate = true,

    -- CHAMS
    ChamsEnabled = false,
    ChamsMode = "Highlight",
    ChamsWalls = true,
    ChamsFill = Color3.fromRGB(255, 70, 70),
    ChamsFillTransparency = 0.5,
    ChamsOutline = Color3.fromRGB(255, 255, 255),
    ChamsOutlineTransparency = 0.1,
    ChamsSolid = Color3.fromRGB(255, 70, 70),
    ChamsSolidTransparency = 0,
    ChamsMaterial = "Neon",

    -- LOCAL
    Fullbright = false,
    LocalFov = false,
    LocalFovValue = 90,
    WalkSpeedEnabled = false,
    WalkSpeedValue = 16,
    JumpEnabled = false,
    JumpValue = 50,
    InfiniteJump = false,
    NoClip = false,
    AntiAFK = true,
    FlyEnabled = false,
    FlySpeed = 55,
    SpinEnabled = false,
    SpinSpeed = 180,
    HipHeightEnabled = false,
    HipHeightValue = 2,
    TimeOfDayEnabled = false,
    TimeOfDayValue = 14,
    RemoveFog = false,
    ClickTP = false,
    ClickTPDistance = 600,

    -- VISUALS
    CrosshairEnabled = false,
    CrosshairSize = 8,
    CrosshairGap = 5,
    CrosshairThickness = 2,
    CrosshairColor = Color3.fromRGB(190, 245, 90),

    FOVColor = Color3.fromRGB(190, 245, 90),
    ESPColor = Color3.fromRGB(190, 245, 90),
    TargetColor = Color3.fromRGB(255, 190, 80),

    RainbowGunEnabled = false,
    RainbowGunSpeed = 0.32,

    -- WORLD TINT
    WorldTint = false,
    WorldTintColor = Color3.fromRGB(130, 180, 255),
    WorldTintBrightness = 0,
    WorldTintContrast = 0.05,
    NoSkybox = false,

    -- SETTINGS
    Notifications = true,
    PerformanceMode = false,

    -- CUSTOMIZE
    Accent = Color3.fromRGB(190, 245, 90),
}

local Target = nil
local AimHeld = false
local AimToggled = false
local RainbowClock = 0
local ListeningForAimKey = false

-- Runtime objects for the extended feature set. Grouped into one table so the
-- top-level chunk stays inside Luau's 200 local-register limit.
local Extra = {
    AimHighlight = nil,
    WorldTintEffect = nil,
    SkyBackup = nil,
    FlyVelocity = nil,
    FlyAttachment = nil,
    SpectatedPlayer = nil,
}

--==================================================
-- ASTER UI
--==================================================

local Aster = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/podivichdev/Aster-UI/main/Library.lua"
))()

local Window = Aster:CreateWindow({
    Title = "CARBON // SIGNAL",
    Subtitle = "TACTICAL CONTROL INTERFACE",
    LoadingTitle = "CARBON 3.3.0",
    LoadingSubtitle = "INITIALIZING SYSTEMS",
    ToggleUIKeybind = "RightShift",
    Icon = "None",
    Theme = "Midnight",
    Weather = "Snow",
    Backdrop = { Dim = true },
    AlwaysOnTop = true,
    AutoTranslate = false,
    ShowCustomCursor = false,
    ConfigurationSaving = {
        FolderName = "CARBON",
        FileName = "CARBON_3.3.0",
    },
    Home = {
        Stats = {
            "FPS",
            "Ping",
            "Game",
            "Players",
            "ServerAge",
            "Session",
            "Executor",
        },
    },
})

_G.CARBON_WINDOW = Window
_G.CARBON_CONFIG = Config
_G.CARBON_ASTER = Aster

--==================================================
-- NOTIFICATIONS
--==================================================

local function Notify(title, message)
    if not Config.Notifications then
        return
    end

    pcall(function()
        Window:Notify({
            Title = title,
            Content = message,
            Icon = "info",
            Duration = 3,
        })
    end)
end

--==================================================
-- SCREEN GUI
--==================================================

local function UiContainer()
    if gethui then
        local ok, parent = pcall(gethui)
        if ok and parent then
            return parent
        end
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CARBON_Overlay"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 40
ScreenGui.Parent = UiContainer()

_G.CARBON_GUI = ScreenGui

--==================================================
-- VISUAL HELPERS
--==================================================

local function MakeFrame(parent, name, color)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Parent = parent
    return frame
end

local function MakeText(parent, name)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.4
    label.Parent = parent
    return label
end

--==================================================
-- KEYBIND DISPLAY
--==================================================

local KeybindStatus = MakeFrame(
    ScreenGui,
    "AimKeybindStatus",
    Color3.fromRGB(20, 23, 25)
)

KeybindStatus.AnchorPoint = Vector2.new(0.5, 0)
KeybindStatus.Position = UDim2.new(0.5, 0, 0, 18)
KeybindStatus.Size = UDim2.fromOffset(260, 42)
KeybindStatus.BackgroundTransparency = 0.12
KeybindStatus.Visible = false

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 8)
KeybindCorner.Parent = KeybindStatus

local KeybindStroke = Instance.new("UIStroke")
KeybindStroke.Color = Config.Accent
KeybindStroke.Thickness = 1
KeybindStroke.Parent = KeybindStatus

local KeybindText = MakeText(KeybindStatus, "Status")
KeybindText.Size = UDim2.fromScale(1, 1)
KeybindText.TextSize = 13
KeybindText.Text = "PRESS A KEY..."

local function GetAimKeyName()
    if Config.AimKeyType == "Keyboard" then
        return Config.AimKeyCode.Name
    end

    return Config.AimKeyCode.Name:gsub("MouseButton", "Mouse ")
end

local function UpdateKeybindDisplay()
    KeybindText.Text = "AIMLOCK KEY: " .. GetAimKeyName()
end

local function SetAimKey(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Unknown then
            return false
        end

        Config.AimKeyType = "Keyboard"
        Config.AimKeyCode = input.KeyCode

    elseif input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.MouseButton3 then

        Config.AimKeyType = "Mouse"
        Config.AimKeyCode = input.UserInputType

    else
        return false
    end

    AimHeld = false
    AimToggled = false
    Target = nil

    UpdateKeybindDisplay()

    Notify(
        "AIMLOCK KEY UPDATED",
        "New key: " .. GetAimKeyName()
    )

    return true
end

local function IsAimKey(input)
    if Config.AimKeyType == "Keyboard" then
        return input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode == Config.AimKeyCode
    end

    return input.UserInputType == Config.AimKeyCode
end

--==================================================
-- FOV CIRCLE
--==================================================

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "AimFOV"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Parent = ScreenGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 1.5
FOVStroke.Parent = FOVCircle

--==================================================
-- CROSSHAIR
--==================================================

local CrosshairParts = {}

local function CreateCrosshairPart(name)
    local part = MakeFrame(
        ScreenGui,
        name,
        Config.CrosshairColor
    )

    table.insert(CrosshairParts, part)
    return part
end

local CrossTop = CreateCrosshairPart("CrossTop")
local CrossBottom = CreateCrosshairPart("CrossBottom")
local CrossLeft = CreateCrosshairPart("CrossLeft")
local CrossRight = CreateCrosshairPart("CrossRight")

local function UpdateCrosshair()
    local s = Config.CrosshairSize
    local g = Config.CrosshairGap
    local t = Config.CrosshairThickness

    CrossTop.Size = UDim2.fromOffset(t, s)
    CrossTop.Position = UDim2.new(0.5, -t / 2, 0.5, -g - s)

    CrossBottom.Size = UDim2.fromOffset(t, s)
    CrossBottom.Position = UDim2.new(0.5, -t / 2, 0.5, g)

    CrossLeft.Size = UDim2.fromOffset(s, t)
    CrossLeft.Position = UDim2.new(0.5, -g - s, 0.5, -t / 2)

    CrossRight.Size = UDim2.fromOffset(s, t)
    CrossRight.Position = UDim2.new(0.5, g, 0.5, -t / 2)

    for _, part in ipairs(CrosshairParts) do
        part.BackgroundColor3 = Config.CrosshairColor
        part.Visible = Config.CrosshairEnabled
    end
end

--==================================================
-- TARGET INDICATOR
--==================================================

local TargetLabel = MakeText(ScreenGui, "TargetIndicator")
TargetLabel.Size = UDim2.fromOffset(260, 25)
TargetLabel.AnchorPoint = Vector2.new(0.5, 0)
TargetLabel.Position = UDim2.new(0.5, 0, 0.57, 0)
TargetLabel.TextColor3 = Config.TargetColor
TargetLabel.Text = ""
TargetLabel.Visible = false

--==================================================
-- RADAR
--==================================================

local Radar = {}

do
    Radar.Frame = MakeFrame(
        ScreenGui,
        "CARBON_Radar",
        Color3.fromRGB(12, 16, 24)
    )

    Radar.Frame.AnchorPoint = Vector2.new(1, 1)
    Radar.Frame.Position = UDim2.new(1, -20, 1, -20)
    Radar.Frame.Size = UDim2.fromOffset(Config.RadarSize, Config.RadarSize)
    Radar.Frame.BackgroundTransparency = 1 - Config.RadarOpacity
    Radar.Frame.ClipsDescendants = true
    Radar.Frame.Visible = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = Radar.Frame

    Radar.Stroke = Instance.new("UIStroke")
    Radar.Stroke.Color = Config.ESPColor
    Radar.Stroke.Thickness = 1
    Radar.Stroke.Transparency = 0.35
    Radar.Stroke.Parent = Radar.Frame

    Radar.Ring = Instance.new("Frame")
    Radar.Ring.Name = "Ring"
    Radar.Ring.AnchorPoint = Vector2.new(0.5, 0.5)
    Radar.Ring.Position = UDim2.fromScale(0.5, 0.5)
    Radar.Ring.Size = UDim2.fromScale(0.9, 0.9)
    Radar.Ring.BackgroundTransparency = 1
    Radar.Ring.Parent = Radar.Frame

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = Radar.Ring

    Radar.RingStroke = Instance.new("UIStroke")
    Radar.RingStroke.Color = Config.ESPColor
    Radar.RingStroke.Thickness = 1
    Radar.RingStroke.Transparency = 0.6
    Radar.RingStroke.Parent = Radar.Ring

    Radar.H = MakeFrame(Radar.Frame, "H", Config.ESPColor)
    Radar.H.AnchorPoint = Vector2.new(0.5, 0.5)
    Radar.H.Position = UDim2.fromScale(0.5, 0.5)
    Radar.H.Size = UDim2.new(0.84, 0, 0, 1)
    Radar.H.BackgroundTransparency = 0.78

    Radar.V = MakeFrame(Radar.Frame, "V", Config.ESPColor)
    Radar.V.AnchorPoint = Vector2.new(0.5, 0.5)
    Radar.V.Position = UDim2.fromScale(0.5, 0.5)
    Radar.V.Size = UDim2.new(0, 1, 0.84, 0)
    Radar.V.BackgroundTransparency = 0.78

    Radar.Forward = MakeFrame(Radar.Frame, "Forward", Config.ESPColor)
    Radar.Forward.AnchorPoint = Vector2.new(0.5, 0.5)
    Radar.Forward.Position = UDim2.fromScale(0.5, 0.08)
    Radar.Forward.Size = UDim2.fromOffset(3, 9)
end

--==================================================
-- TARGET HIGHLIGHT
--==================================================

Extra.AimHighlight = Instance.new("Highlight")
Extra.AimHighlight.Name = "CARBON_TargetHighlight"
Extra.AimHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
Extra.AimHighlight.FillTransparency = 1
Extra.AimHighlight.OutlineTransparency = 0
Extra.AimHighlight.Enabled = false
Extra.AimHighlight.Parent = workspace

--==================================================
-- PLAYER ESP OBJECTS
--==================================================

local ESPObjects = {}

local R15_BONES = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

local function CreateESP(player)
    if player == LocalPlayer then
        return
    end

    if ESPObjects[player] then
        return
    end

    local folder = Instance.new("Folder")
    folder.Name = "CARBON_ESP_" .. player.UserId
    folder.Parent = ScreenGui

    local box = MakeFrame(folder, "Box", Config.ESPColor)
    box.BackgroundTransparency = 1
    box.ZIndex = 1

    local outline = Instance.new("UIStroke")
    outline.Thickness = 1.5
    outline.Color = Config.ESPColor
    outline.Parent = box

    local boxFill = MakeFrame(folder, "BoxFill", Config.ESPColor)
    boxFill.BackgroundTransparency = 0.78
    boxFill.ZIndex = 0

    local name = MakeText(folder, "Name")
    name.Size = UDim2.fromOffset(180, 18)
    name.AnchorPoint = Vector2.new(0.5, 1)
    name.ZIndex = 2

    local weapon = MakeText(folder, "Weapon")
    weapon.Size = UDim2.fromOffset(200, 14)
    weapon.TextSize = 11
    weapon.AnchorPoint = Vector2.new(0.5, 1)
    weapon.ZIndex = 2

    local headDot = MakeFrame(folder, "HeadDot", Config.ESPColor)
    headDot.AnchorPoint = Vector2.new(0.5, 0.5)
    headDot.Size = UDim2.fromOffset(5, 5)
    headDot.ZIndex = 3

    local headDotCorner = Instance.new("UICorner")
    headDotCorner.CornerRadius = UDim.new(1, 0)
    headDotCorner.Parent = headDot

    local arrow = MakeFrame(folder, "Arrow", Config.ESPColor)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Size = UDim2.fromOffset(20, 3)
    arrow.ZIndex = 3

    local distance = MakeText(folder, "Distance")
    distance.Size = UDim2.fromOffset(180, 18)
    distance.AnchorPoint = Vector2.new(0.5, 0)
    distance.ZIndex = 2

    local radarDot = MakeFrame(Radar.Frame, "Dot", Config.ESPColor)
    radarDot.AnchorPoint = Vector2.new(0.5, 0.5)
    radarDot.Size = UDim2.fromOffset(6, 6)
    radarDot.Visible = false

    local radarDotCorner = Instance.new("UICorner")
    radarDotCorner.CornerRadius = UDim.new(1, 0)
    radarDotCorner.Parent = radarDot

    local healthBack = MakeFrame(
        folder,
        "HealthBack",
        Color3.fromRGB(25, 25, 25)
    )

    local healthFill = MakeFrame(
        folder,
        "HealthFill",
        Color3.fromRGB(100, 240, 110)
    )

    local tracer = MakeFrame(folder, "Tracer", Config.ESPColor)
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)

    local bones = {}
    for index = 1, #R15_BONES do
        local line = MakeFrame(folder, "Bone" .. index, Config.ESPColor)
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.Visible = false
        bones[index] = line
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "CARBON_Highlight"
    highlight.FillColor = Config.ESPColor
    highlight.OutlineColor = Config.ESPColor
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0
    highlight.Enabled = false
    highlight.Parent = folder

    ESPObjects[player] = {
        Folder = folder,
        Box = box,
        Outline = outline,
        BoxFill = boxFill,
        Name = name,
        Weapon = weapon,
        HeadDot = headDot,
        Arrow = arrow,
        Distance = distance,
        RadarDot = radarDot,
        HealthBack = healthBack,
        HealthFill = healthFill,
        Tracer = tracer,
        Bones = bones,
        Highlight = highlight,
    }
end

local function RemoveESP(player)
    local object = ESPObjects[player]
    if not object then
        return
    end

    object.Folder:Destroy()

    if object.RadarDot then
        object.RadarDot:Destroy()
    end

    ESPObjects[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
    CreateESP(player)
end

Connect(Players.PlayerAdded, CreateESP)
Connect(Players.PlayerRemoving, RemoveESP)

--==================================================
-- PLAYER HELPERS
--==================================================

local function GetCharacter(player)
    return player and player.Character
end

local function GetHumanoid(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetRoot(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetPart(player)
    local character = GetCharacter(player)
    if not character then
        return nil
    end

    local part = Config.AimPart

    if part == "Root" then
        return character:FindFirstChild("HumanoidRootPart")
    elseif part == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
    elseif part == "Pelvis" then
        return character:FindFirstChild("LowerTorso")
            or character:FindFirstChild("Torso")
    elseif part == "Neck" then
        return character:FindFirstChild("Head")
    elseif part == "Nearest" then
        local camera = workspace.CurrentCamera
        if not camera then
            return character:FindFirstChild("Head")
        end

        local best, bestDistance

        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart")
                and child.Name ~= "HumanoidRootPart"
                and child.Transparency < 1 then

                local distance =
                    (child.Position - camera.CFrame.Position).Magnitude

                if not bestDistance or distance < bestDistance then
                    best = child
                    bestDistance = distance
                end
            end
        end

        return best or character:FindFirstChild("Head")
    end

    return character:FindFirstChild("Head")
end

local function IsAlive(player)
    local humanoid = GetHumanoid(player)
    return humanoid and humanoid.Health > 0
end

local function IsEnemy(player)
    if player == LocalPlayer then
        return false
    end

    if Config.TeamCheck
        and LocalPlayer.Team
        and player.Team == LocalPlayer.Team then

        return false
    end

    return true
end

local function GetDistance(player)
    local a = GetRoot(LocalPlayer)
    local b = GetRoot(player)

    if not a or not b then
        return math.huge
    end

    return (a.Position - b.Position).Magnitude
end

local function IsLimb(part, character)
    if not part:IsA("BasePart") then
        return false
    end

    local node = part.Parent
    while node and node ~= character do
        if node:IsA("Accessory") or node:IsA("Tool") then
            return false
        end
        node = node.Parent
    end

    return node == character
end

--==================================================
-- CHAMS
--==================================================

local ChamsBodies = Instance.new("Folder")
ChamsBodies.Name = "CARBON_ChamsBodies"
ChamsBodies.Parent = workspace

local ChamsFolder = Instance.new("Folder")
ChamsFolder.Name = "CARBON_Chams"
ChamsFolder.Parent = ScreenGui

local ChamsEntries = {}

local function StyleChamsBody(part)
    part.Color = Config.ChamsSolid
    part.Transparency = Config.ChamsSolidTransparency
    part.Material = Enum.Material.Neon

    local ok, material = pcall(function()
        return Enum.Material[Config.ChamsMaterial]
    end)

    if ok and material then
        part.Material = material
    end
end

local function StyleChamsHighlight(highlight)
    highlight.DepthMode = Config.ChamsWalls
        and Enum.HighlightDepthMode.AlwaysOnTop
        or Enum.HighlightDepthMode.Occluded

    highlight.FillColor = Config.ChamsFill
    highlight.FillTransparency = Config.ChamsFillTransparency
    highlight.OutlineColor = Config.ChamsOutline
    highlight.OutlineTransparency = Config.ChamsOutlineTransparency
end

local function IsChamsPart(part, character)
    if not part:IsA("BasePart") then
        return false
    end

    if part.Name == "HumanoidRootPart" or part.Transparency >= 1 then
        return false
    end

    local node = part.Parent
    while node and node ~= character do
        if node:IsA("Accessory")
            or node:IsA("Tool")
            or node:IsA("Humanoid") then

            return false
        end
        node = node.Parent
    end

    return node == character
end

local function RemoveChams(player)
    local entry = ChamsEntries[player]
    if not entry then
        return
    end

    if entry.Highlight then
        entry.Highlight:Destroy()
    end

    if entry.Body then
        for _, item in ipairs(entry.Body) do
            item.Clone:Destroy()
        end
    end

    ChamsEntries[player] = nil
end

local function ClearChams()
    local players = {}

    for player in pairs(ChamsEntries) do
        table.insert(players, player)
    end

    for _, player in ipairs(players) do
        RemoveChams(player)
    end
end

local function BuildChamsBody(character)
    local body = {}

    for _, part in ipairs(character:GetDescendants()) do
        if IsChamsPart(part, character) then
            local clone = part:Clone()

            for _, child in ipairs(clone:GetChildren()) do
                if not child:IsA("DataModelMesh") then
                    child:Destroy()
                end
            end

            clone.Name = "CARBON_Body"
            clone.Anchored = true
            clone.CanCollide = false
            clone.CanQuery = false
            clone.CanTouch = false
            clone.CastShadow = false
            clone.Massless = true
            clone.CFrame = part.CFrame

            StyleChamsBody(clone)

            clone.Parent = ChamsBodies
            table.insert(body, {
                Source = part,
                Clone = clone,
            })
        end
    end

    return body
end

local function ReconcileChams()
    if not Config.ChamsEnabled then
        ClearChams()
        return
    end

    local wantsHighlight = Config.ChamsMode ~= "Solid"
    local wantsSolid = Config.ChamsMode ~= "Highlight"

    local targets = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if IsEnemy(player) and IsAlive(player) then
            local character = GetCharacter(player)

            if character then
                targets[player] = character
            end
        end
    end

    for player, entry in pairs(ChamsEntries) do
        if targets[player] ~= entry.Character then
            RemoveChams(player)
        end
    end

    for player, character in pairs(targets) do
        local entry = ChamsEntries[player]

        if not entry then
            entry = {
                Character = character,
                Highlight = nil,
                Body = nil,
            }

            ChamsEntries[player] = entry
        end

        if wantsHighlight and not entry.Highlight then
            local highlight = Instance.new("Highlight")
            highlight.Name = "CARBON_Chams"
            highlight.Adornee = character
            highlight.Parent = ChamsFolder

            StyleChamsHighlight(highlight)
            entry.Highlight = highlight
        elseif not wantsHighlight and entry.Highlight then
            entry.Highlight:Destroy()
            entry.Highlight = nil
        end

        if wantsSolid and not entry.Body then
            entry.Body = BuildChamsBody(character)
        elseif not wantsSolid and entry.Body then
            for _, item in ipairs(entry.Body) do
                item.Clone:Destroy()
            end
            entry.Body = nil
        end
    end
end

local function SyncChams()
    for player, entry in pairs(ChamsEntries) do
        if entry.Body then
            for index = #entry.Body, 1, -1 do
                local item = entry.Body[index]

                if item.Source.Parent and item.Clone.Parent then
                    item.Clone.CFrame = item.Source.CFrame
                else
                    item.Clone:Destroy()
                    table.remove(entry.Body, index)
                end
            end
        end

        if entry.Highlight and not entry.Highlight.Parent then
            entry.Highlight = nil
        end

        if not GetCharacter(player) then
            RemoveChams(player)
        end
    end
end

local function RestyleChams()
    for _, entry in pairs(ChamsEntries) do
        if entry.Highlight then
            StyleChamsHighlight(entry.Highlight)
        end

        if entry.Body then
            for _, item in ipairs(entry.Body) do
                StyleChamsBody(item.Clone)
            end
        end
    end
end

--==================================================
-- VISIBILITY CHECK
--==================================================

local function IsVisible(player, part)
    if not part then
        return false
    end

    local character = GetCharacter(player)
    if not character then
        return false
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
    }
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)

    return result ~= nil and result.Instance:IsDescendantOf(character)
end

--==================================================
-- TARGET SELECTION
--==================================================

local function GetBestTarget()
    local bestTarget = nil
    local bestScore = math.huge

    local mouse = UIS:GetMouseLocation()
    local center = Vector2.new(mouse.X, mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if IsEnemy(player) and IsAlive(player) then
            local part = GetPart(player)
            local root = GetRoot(player)

            if part and root then
                local distance = GetDistance(player)

                if distance <= Config.AimDistance
                    and (not Config.VisibilityCheck
                        or IsVisible(player, part)) then

                    local screen, onScreen =
                        Camera:WorldToViewportPoint(part.Position)

                    if screen.Z > 0 then
                        local screenDistance = (
                            Vector2.new(screen.X, screen.Y) - center
                        ).Magnitude

                        if screenDistance <= Config.AimFOV then
                            local score = screenDistance

                            if Config.AimMode == "Closest to Character" then
                                score = distance
                            elseif Config.AimMode == "Lowest Health" then
                                local humanoid = GetHumanoid(player)
                                score = humanoid and humanoid.Health
                                    or math.huge
                            end

                            if score < bestScore then
                                bestScore = score
                                bestTarget = player
                            end
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

--==================================================
-- AIMLOCK
--==================================================

local function AimActive()
    if not Config.AimEnabled then
        return false
    end

    if Config.AimActivation == "Hold" then
        return AimHeld
    elseif Config.AimActivation == "Always" then
        return true
    end

    return AimToggled
end

Extra.SetAimHighlight = function(player)
    if not Extra.AimHighlight then
        return
    end

    local character = player and GetCharacter(player)

    if Config.AimTargetHighlight and character then
        Extra.AimHighlight.Adornee = character
        Extra.AimHighlight.OutlineColor = Config.TargetHighlightColor
        Extra.AimHighlight.Enabled = true
    else
        Extra.AimHighlight.Enabled = false
        Extra.AimHighlight.Adornee = nil
    end
end

local function UpdateAim(deltaTime)
    if not AimActive() then
        Target = nil
        TargetLabel.Visible = false
        Extra.SetAimHighlight(nil)
        return
    end

    Camera = workspace.CurrentCamera
    if not Camera then
        return
    end

    if Config.StickyTarget and Target then
        if not IsAlive(Target)
            or not IsEnemy(Target)
            or GetDistance(Target) > Config.AimDistance then

            Target = nil
        end
    else
        Target = nil
    end

    if not Target then
        Target = GetBestTarget()
    end

    if not Target then
        TargetLabel.Visible = false
        Extra.SetAimHighlight(nil)
        return
    end

    local part = GetPart(Target)
    if not part then
        Target = nil
        Extra.SetAimHighlight(nil)
        return
    end

    Extra.SetAimHighlight(Target)

    local velocity = part.AssemblyLinearVelocity
    local aimPosition = part.Position + velocity * Config.Prediction

    aimPosition += Camera.CFrame.RightVector * Config.AimOffsetX
    aimPosition += Camera.CFrame.UpVector * Config.AimOffsetY

    local goal = CFrame.lookAt(
        Camera.CFrame.Position,
        aimPosition
    )

    local alpha = math.clamp(
        deltaTime * (31 - Config.Smoothness) * 2,
        0,
        1
    )

    Camera.CFrame = Camera.CFrame:Lerp(goal, alpha)

    TargetLabel.Visible = Config.TargetIndicator
    TargetLabel.Text = "LOCKED: " .. Target.Name
end

_G.CARBON_DEBUG = {
    GetBestTarget = GetBestTarget,
    GetPart = GetPart,
    GetDistance = GetDistance,
    IsVisible = IsVisible,
    IsEnemy = IsEnemy,
    IsAlive = IsAlive,
    GetCamera = function()
        return Camera
    end,
    ResetTarget = function()
        Target = nil
    end,
}

--==================================================
-- ESP UPDATE
--==================================================

local function SetESPLine(frame, from, to)
    local difference = to - from
    local length = difference.Magnitude

    if length < 1 then
        frame.Visible = false
        return
    end

    frame.Visible = true
    frame.Size = UDim2.fromOffset(length, 1)
    frame.Position = UDim2.fromOffset(from.X, from.Y)
    frame.Rotation = math.deg(math.atan2(difference.Y, difference.X))
end

local function HideESP(object)
    object.Box.Visible = false
    object.BoxFill.Visible = false
    object.Name.Visible = false
    object.Weapon.Visible = false
    object.HeadDot.Visible = false
    object.Arrow.Visible = false
    object.Distance.Visible = false
    object.HealthBack.Visible = false
    object.HealthFill.Visible = false
    object.Tracer.Visible = false
    object.Highlight.Enabled = false

    if object.RadarDot then
        object.RadarDot.Visible = false
    end

    for _, line in ipairs(object.Bones) do
        line.Visible = false
    end
end

local function UpdateESPArrow(object, root)
    object.Arrow.Visible = false

    if not Config.ESPArrows or not root then
        return
    end

    local screen, onScreen = Camera:WorldToViewportPoint(root.Position)

    if onScreen and screen.Z > 0 then
        return
    end

    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local point = Vector2.new(screen.X, screen.Y)

    -- Behind the camera: mirror the projection so the arrow points behind us.
    if screen.Z <= 0 then
        point = center - (point - center)

        if (point - center).Magnitude < 1 then
            point = center + Vector2.new(0, 100)
        end
    end

    local direction = point - center

    if direction.Magnitude < 1 then
        return
    end

    direction = direction.Unit

    local radius = math.min(viewport.X, viewport.Y) * 0.36
    local position = center + direction * radius

    object.Arrow.Visible = true
    object.Arrow.Position = UDim2.fromOffset(position.X, position.Y)
    object.Arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
    object.Arrow.BackgroundColor3 = Config.ESPColor
end

local function GetWeaponName(character)
    local tool = character:FindFirstChildWhichIsA("Tool")

    if tool then
        return tool.Name
    end

    return nil
end

local function UpdateESP()
    for player, object in pairs(ESPObjects) do
        local character = GetCharacter(player)
        local humanoid = GetHumanoid(player)
        local root = GetRoot(player)

        local visible = Config.ESPEnabled
            and character
            and humanoid
            and humanoid.Health > 0
            and root
            and GetDistance(player) <= Config.ESPMaxDistance

        if visible and Config.ESPTeamCheck
            and LocalPlayer.Team
            and player.Team == LocalPlayer.Team then

            visible = false
        end

        if visible and Config.ESPVisibleOnly then
            local part = GetPart(player)

            if not IsVisible(player, part) then
                visible = false
            end
        end

        if not visible then
            HideESP(object)
            continue
        end

        local cf, size = character:GetBoundingBox()
        local corners = {}

        for x = -1, 1, 2 do
            for y = -1, 1, 2 do
                for z = -1, 1, 2 do
                    local point = cf:PointToWorldSpace(
                        Vector3.new(
                            size.X * x / 2,
                            size.Y * y / 2,
                            size.Z * z / 2
                        )
                    )

                    local screen, onScreen =
                        Camera:WorldToViewportPoint(point)

                    if onScreen and screen.Z > 0 then
                        table.insert(
                            corners,
                            Vector2.new(screen.X, screen.Y)
                        )
                    end
                end
            end
        end

        if #corners < 2 then
            HideESP(object)
            UpdateESPArrow(object, root)
            continue
        end

        local minX, minY = math.huge, math.huge
        local maxX, maxY = -math.huge, -math.huge

        for _, point in ipairs(corners) do
            minX = math.min(minX, point.X)
            minY = math.min(minY, point.Y)
            maxX = math.max(maxX, point.X)
            maxY = math.max(maxY, point.Y)
        end

        local width = maxX - minX
        local height = maxY - minY

        local centerX = (minX + maxX) / 2

        object.Box.Visible = Config.ESPBoxes
        object.Box.Position = UDim2.fromOffset(minX, minY)
        object.Box.Size = UDim2.fromOffset(width, height)
        object.Outline.Color = Config.ESPColor

        object.BoxFill.Visible = Config.ESPBoxes and Config.ESPBoxFill
        object.BoxFill.Position = object.Box.Position
        object.BoxFill.Size = object.Box.Size
        object.BoxFill.BackgroundColor3 = Config.ESPColor

        object.Name.Visible = Config.ESPNames
        object.Name.Position = UDim2.fromOffset(centerX, minY - 20)
        object.Name.TextColor3 = Config.ESPColor
        object.Name.Text = Config.ESPDisplayName
            and player.DisplayName
            or player.Name

        local weaponName = Config.ESPWeapon and GetWeaponName(character)

        object.Weapon.Visible = weaponName ~= nil and weaponName ~= ""
        object.Weapon.Position = UDim2.fromOffset(centerX, minY - 36)
        object.Weapon.TextColor3 = Config.ESPColor
        object.Weapon.Text = weaponName and ("[ " .. weaponName .. " ]") or ""

        local head = character:FindFirstChild("Head")
        local headScreen, headOnScreen = nil, false

        if head then
            headScreen, headOnScreen = Camera:WorldToViewportPoint(
                head.Position + Vector3.new(0, head.Size.Y / 2, 0)
            )
        end

        object.HeadDot.Visible = Config.ESPHeadDot
            and headScreen ~= nil
            and headOnScreen
            and headScreen.Z > 0

        if object.HeadDot.Visible then
            object.HeadDot.Position = UDim2.fromOffset(
                headScreen.X,
                headScreen.Y
            )
            object.HeadDot.BackgroundColor3 = Config.ESPColor
        end

        object.Arrow.Visible = false

        object.Distance.Visible = Config.ESPDistance
        object.Distance.Position = UDim2.fromOffset(centerX, maxY + 3)
        object.Distance.TextColor3 = Config.ESPColor
        object.Distance.Text =
            math.floor(GetDistance(player)) .. " studs"

        local healthPercent = math.clamp(
            humanoid.Health / math.max(humanoid.MaxHealth, 1),
            0,
            1
        )

        object.HealthBack.Visible = Config.ESPHealth
        object.HealthBack.Position = UDim2.fromOffset(minX - 6, minY)
        object.HealthBack.Size = UDim2.fromOffset(3, height)

        object.HealthFill.Visible = Config.ESPHealth
        object.HealthFill.Position = UDim2.fromOffset(
            minX - 6,
            minY + height * (1 - healthPercent)
        )
        object.HealthFill.Size = UDim2.fromOffset(
            3,
            height * healthPercent
        )

        object.HealthFill.BackgroundColor3 = Color3.fromRGB(
            255 * (1 - healthPercent),
            255 * healthPercent,
            70
        )

        object.Highlight.Enabled = Config.ESPHighlights
        object.Highlight.Adornee = character
        object.Highlight.FillColor = Config.ESPColor
        object.Highlight.OutlineColor = Config.ESPColor

        local screenCenter = Vector2.new(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y
        )

        local endPoint = Vector2.new(centerX, maxY)
        local difference = endPoint - screenCenter
        local length = difference.Magnitude

        object.Tracer.Visible = Config.ESPTracers
        object.Tracer.Size = UDim2.fromOffset(length, 1)
        object.Tracer.Position = UDim2.fromOffset(
            (screenCenter.X + endPoint.X) / 2,
            (screenCenter.Y + endPoint.Y) / 2
        )
        object.Tracer.Rotation = math.deg(
            math.atan2(difference.Y, difference.X)
        )
        object.Tracer.BackgroundColor3 = Config.ESPColor

        -- Skeleton
        local rig = character:FindFirstChild("UpperTorso")
            and R15_BONES
            or R6_BONES

        local parts = {}
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("BasePart") then
                parts[child.Name] = child
            end
        end

        for index, bone in ipairs(rig) do
            local line = object.Bones[index]

            if line then
                local from = parts[bone[1]]
                local to = parts[bone[2]]

                if Config.ESPSkeleton and from and to then
                    local a, aOn = Camera:WorldToViewportPoint(
                        from.Position
                    )
                    local b, bOn = Camera:WorldToViewportPoint(
                        to.Position
                    )

                    if aOn and bOn and a.Z > 0 and b.Z > 0 then
                        line.BackgroundColor3 = Config.ESPColor
                        SetESPLine(
                            line,
                            Vector2.new(a.X, a.Y),
                            Vector2.new(b.X, b.Y)
                        )
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        end

        for index = #rig + 1, #object.Bones do
            object.Bones[index].Visible = false
        end
    end
end

--==================================================
-- RADAR UPDATE
--==================================================

local function UpdateRadar()
    Radar.Frame.Visible = Config.ESPEnabled and Config.ESPRadar
    Radar.Frame.Size = UDim2.fromOffset(Config.RadarSize, Config.RadarSize)
    Radar.Frame.BackgroundTransparency = 1 - Config.RadarOpacity
    Radar.Stroke.Color = Config.ESPColor
    Radar.RingStroke.Color = Config.ESPColor
    Radar.H.BackgroundColor3 = Config.ESPColor
    Radar.V.BackgroundColor3 = Config.ESPColor
    Radar.Forward.BackgroundColor3 = Config.ESPColor

    if not Radar.Frame.Visible then
        for _, object in pairs(ESPObjects) do
            if object.RadarDot then
                object.RadarDot.Visible = false
            end
        end

        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local camera = Camera

    if not root or not camera then
        return
    end

    local range = math.max(Config.RadarRange, 1)
    local radius = math.max(Config.RadarSize / 2 - 10, 1)

    local forward = camera.CFrame.LookVector
    local angle = Config.RadarRotate
        and math.atan2(-forward.X, -forward.Z)
        or 0

    local cos, sin = math.cos(angle), math.sin(angle)

    for player, object in pairs(ESPObjects) do
        local dot = object.RadarDot

        if dot then
            local otherRoot = GetRoot(player)
            local humanoid = GetHumanoid(player)
            local shown = false

            if otherRoot and humanoid and humanoid.Health > 0 then
                local teamBlocked = Config.ESPTeamCheck
                    and LocalPlayer.Team
                    and player.Team == LocalPlayer.Team

                if not teamBlocked then
                    local offset = otherRoot.Position - root.Position
                    local distance = Vector2.new(offset.X, offset.Z).Magnitude

                    if distance <= range then
                        local x = offset.X
                        local z = offset.Z

                        if Config.RadarRotate then
                            x, z = x * cos - z * sin, x * sin + z * cos
                        end

                        local screenX = x / range * radius
                        local screenY = z / range * radius
                        local height = otherRoot.Position.Y - root.Position.Y
                        local size = height > 12 and 8
                            or (height < -12 and 4 or 6)

                        dot.Position = UDim2.new(0.5, screenX, 0.5, screenY)
                        dot.Size = UDim2.fromOffset(size, size)
                        dot.BackgroundColor3 = Config.ESPColor
                        shown = true
                    end
                end
            end

            dot.Visible = shown
        end
    end
end

--==================================================
-- RAINBOW VIEWMODEL
--==================================================

local OriginalColors = setmetatable({}, { __mode = "k" })

local function RestoreViewmodel()
    for part, color in pairs(OriginalColors) do
        if part and part.Parent then
            pcall(function()
                part.Color = color
            end)
        end
    end

    table.clear(OriginalColors)
end

local function UpdateRainbow(deltaTime)
    if not Config.RainbowGunEnabled then
        return
    end

    Camera = workspace.CurrentCamera
    if not Camera then
        return
    end

    RainbowClock = (
        RainbowClock + deltaTime * Config.RainbowGunSpeed
    ) % 1

    local color = Color3.fromHSV(RainbowClock, 0.85, 1)

    local arms = Camera:FindFirstChild("Arms")
    local container = arms or Camera

    for _, instance in ipairs(container:GetDescendants()) do
        if instance:IsA("BasePart")
            and instance:FindFirstAncestorOfClass("Model") then

            if not OriginalColors[instance] then
                OriginalColors[instance] = instance.Color
            end

            instance.Color = color
        end
    end
end

--==================================================
-- LOCAL FEATURES
--==================================================

local LocalBackup = {
    Lighting = nil,
    Fov = nil,
    WalkSpeed = nil,
    JumpPower = nil,
    JumpHeight = nil,
    UseJumpPower = nil,
    ClockTime = nil,
    FogStart = nil,
    FogEnd = nil,
    HipHeight = nil,
}

local function CurrentHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function SetFullbright(on)
    Config.Fullbright = on

    if on then
        if not LocalBackup.Lighting then
            LocalBackup.Lighting = {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                FogStart = Lighting.FogStart,
                FogEnd = Lighting.FogEnd,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
            }
        end

        Lighting.Brightness = 3
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e6
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    elseif LocalBackup.Lighting then
        local backup = LocalBackup.Lighting

        Lighting.Brightness = backup.Brightness
        Lighting.Ambient = backup.Ambient
        Lighting.OutdoorAmbient = backup.OutdoorAmbient
        Lighting.FogStart = backup.FogStart
        Lighting.FogEnd = backup.FogEnd
        Lighting.ClockTime = backup.ClockTime
        Lighting.GlobalShadows = backup.GlobalShadows

        LocalBackup.Lighting = nil
    end
end

local function ApplyLocal()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid and Config.WalkSpeedEnabled then
        humanoid.WalkSpeed = Config.WalkSpeedValue
    end

    if humanoid and Config.JumpEnabled then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.JumpValue
    end

    if humanoid and Config.HipHeightEnabled then
        humanoid.HipHeight = Config.HipHeightValue
    end

    if character and Config.NoClip then
        for _, part in ipairs(character:GetDescendants()) do
            if IsLimb(part, character) then
                part.CanCollide = false
            end
        end
    end

    local camera = workspace.CurrentCamera

    if camera and Config.LocalFov then
        camera.FieldOfView = Config.LocalFovValue
    end
end

local function RestoreLocal()
    SetFullbright(false)

    if LocalBackup.Fov and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = LocalBackup.Fov
        LocalBackup.Fov = nil
    end

    local humanoid = CurrentHumanoid()

    if humanoid then
        humanoid.AutoRotate = true

        if LocalBackup.HipHeight ~= nil then
            pcall(function()
                humanoid.HipHeight = LocalBackup.HipHeight
            end)

            LocalBackup.HipHeight = nil
        end

        if LocalBackup.WalkSpeed then
            humanoid.WalkSpeed = LocalBackup.WalkSpeed
            LocalBackup.WalkSpeed = nil
        end

        if LocalBackup.JumpPower ~= nil then
            pcall(function()
                humanoid.JumpPower = LocalBackup.JumpPower

                if LocalBackup.JumpHeight ~= nil then
                    humanoid.JumpHeight = LocalBackup.JumpHeight
                end

                if LocalBackup.UseJumpPower ~= nil then
                    humanoid.UseJumpPower = LocalBackup.UseJumpPower
                end
            end)

            LocalBackup.JumpPower = nil
            LocalBackup.JumpHeight = nil
            LocalBackup.UseJumpPower = nil
        end
    end

    local character = LocalPlayer.Character

    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if IsLimb(part, character)
                and part.Name ~= "HumanoidRootPart" then

                pcall(function()
                    part.CanCollide = true
                end)
            end
        end
    end

    if Extra.FlyVelocity then
        Extra.FlyVelocity:Destroy()
        Extra.FlyVelocity = nil
    end

    if Extra.FlyAttachment then
        Extra.FlyAttachment:Destroy()
        Extra.FlyAttachment = nil
    end

    if Extra.WorldTintEffect then
        Extra.WorldTintEffect:Destroy()
        Extra.WorldTintEffect = nil
    end

    if Extra.SkyBackup then
        if Extra.SkyBackup.Parent == nil then
            Extra.SkyBackup.Parent = Lighting
        end

        Extra.SkyBackup = nil
    end

    if LocalBackup.ClockTime ~= nil then
        Lighting.ClockTime = LocalBackup.ClockTime
        LocalBackup.ClockTime = nil
    end

    if LocalBackup.FogStart ~= nil then
        Lighting.FogStart = LocalBackup.FogStart
        Lighting.FogEnd = LocalBackup.FogEnd
        LocalBackup.FogStart = nil
        LocalBackup.FogEnd = nil
    end
end

--==================================================
-- EXTENDED LOCAL RUNTIME
--==================================================

Extra.StopFly = function()
    if Extra.FlyVelocity then
        Extra.FlyVelocity:Destroy()
        Extra.FlyVelocity = nil
    end

    if Extra.FlyAttachment then
        Extra.FlyAttachment:Destroy()
        Extra.FlyAttachment = nil
    end

    local humanoid = CurrentHumanoid()

    if humanoid then
        humanoid.PlatformStand = false
    end
end

Extra.SetFly = function(on)
    Config.FlyEnabled = on
    Extra.StopFly()

    if not on then
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not root then
        return
    end

    if humanoid then
        humanoid.PlatformStand = true
    end

    Extra.FlyAttachment = Instance.new("Attachment")
    Extra.FlyAttachment.Name = "CARBON_FlyAttachment"
    Extra.FlyAttachment.Parent = root

    Extra.FlyVelocity = Instance.new("BodyVelocity")
    Extra.FlyVelocity.Name = "CARBON_FlyVelocity"
    Extra.FlyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    Extra.FlyVelocity.Velocity = Vector3.zero
    Extra.FlyVelocity.Parent = root
end

Extra.UpdateFly = function()
    if not Config.FlyEnabled then
        if Extra.FlyVelocity then
            Extra.StopFly()
        end

        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        Extra.StopFly()
        return
    end

    if not Extra.FlyVelocity or Extra.FlyVelocity.Parent ~= root then
        Extra.SetFly(true)
        return
    end

    local camera = workspace.CurrentCamera

    if not camera then
        return
    end

    local direction = Vector3.zero

    if UIS:IsKeyDown(Enum.KeyCode.W) then
        direction += camera.CFrame.LookVector
    end

    if UIS:IsKeyDown(Enum.KeyCode.S) then
        direction -= camera.CFrame.LookVector
    end

    if UIS:IsKeyDown(Enum.KeyCode.D) then
        direction += camera.CFrame.RightVector
    end

    if UIS:IsKeyDown(Enum.KeyCode.A) then
        direction -= camera.CFrame.RightVector
    end

    if UIS:IsKeyDown(Enum.KeyCode.Space) then
        direction += Vector3.yAxis
    end

    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        direction -= Vector3.yAxis
    end

    if direction.Magnitude > 0 then
        Extra.FlyVelocity.Velocity = direction.Unit * Config.FlySpeed
    else
        Extra.FlyVelocity.Velocity = Vector3.zero
    end
end

Extra.UpdateSpin = function(deltaTime)
    if not Config.SpinEnabled then
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if root and humanoid and humanoid.Health > 0 then
        humanoid.AutoRotate = false
        root.CFrame = root.CFrame
            * CFrame.Angles(0, math.rad(Config.SpinSpeed) * deltaTime, 0)
    end
end

Extra.ApplyEnvironment = function()
    if Config.TimeOfDayEnabled then
        Lighting.ClockTime = Config.TimeOfDayValue
    end

    if Config.RemoveFog then
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e6
    end

    if Config.WorldTint then
        if not Extra.WorldTintEffect or not Extra.WorldTintEffect.Parent then
            Extra.WorldTintEffect = Instance.new("ColorCorrectionEffect")
            Extra.WorldTintEffect.Name = "CARBON_WorldTint"
            Extra.WorldTintEffect.Parent = Lighting
        end

        Extra.WorldTintEffect.TintColor = Config.WorldTintColor
        Extra.WorldTintEffect.Brightness = Config.WorldTintBrightness
        Extra.WorldTintEffect.Contrast = Config.WorldTintContrast
        Extra.WorldTintEffect.Enabled = true
    elseif Extra.WorldTintEffect then
        Extra.WorldTintEffect:Destroy()
        Extra.WorldTintEffect = nil
    end

    if Config.NoSkybox then
        if not Extra.SkyBackup or Extra.SkyBackup.Parent ~= nil then
            local sky = Lighting:FindFirstChildOfClass("Sky")

            if sky then
                Extra.SkyBackup = sky
                sky.Parent = nil
            end
        end
    elseif Extra.SkyBackup then
        if Extra.SkyBackup.Parent == nil then
            Extra.SkyBackup.Parent = Lighting
        end

        Extra.SkyBackup = nil
    end
end

Extra.SetTimeOfDay = function(on)
    Config.TimeOfDayEnabled = on

    if on then
        if LocalBackup.ClockTime == nil then
            LocalBackup.ClockTime = Lighting.ClockTime
        end

        Lighting.ClockTime = Config.TimeOfDayValue
    elseif LocalBackup.ClockTime ~= nil then
        Lighting.ClockTime = LocalBackup.ClockTime
        LocalBackup.ClockTime = nil
    end
end

Extra.SetRemoveFog = function(on)
    Config.RemoveFog = on

    if on then
        if LocalBackup.FogStart == nil then
            LocalBackup.FogStart = Lighting.FogStart
            LocalBackup.FogEnd = Lighting.FogEnd
        end

        Lighting.FogStart = 0
        Lighting.FogEnd = 1e6
    elseif LocalBackup.FogStart ~= nil then
        Lighting.FogStart = LocalBackup.FogStart
        Lighting.FogEnd = LocalBackup.FogEnd
        LocalBackup.FogStart = nil
        LocalBackup.FogEnd = nil
    end
end

Extra.SetHipHeight = function(on)
    Config.HipHeightEnabled = on
    local humanoid = CurrentHumanoid()

    if not humanoid then
        return
    end

    if on then
        if LocalBackup.HipHeight == nil then
            LocalBackup.HipHeight = humanoid.HipHeight
        end

        humanoid.HipHeight = Config.HipHeightValue
    else
        humanoid.HipHeight = LocalBackup.HipHeight or 2
        LocalBackup.HipHeight = nil
    end
end

Extra.CopyText = function(text)
    local copied = pcall(function()
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        else
            error("no clipboard function")
        end
    end)

    Notify(copied and "Copied" or "Copy failed", tostring(text))
end

Extra.ResetCharacter = function()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not character or not humanoid then
        return
    end

    pcall(function()
        humanoid.Health = 0
    end)

    pcall(function()
        character:BreakJoints()
    end)
end

Extra.ServerHop = function()
    Notify("Server hop", "Requesting a new server...")

    task.spawn(function()
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)

        if not ok then
            Notify("Server hop failed", tostring(err))
        end
    end)
end

Extra.ResetCamera = function()
    Extra.SpectatedPlayer = nil
    local camera = workspace.CurrentCamera
    local humanoid = CurrentHumanoid()

    if camera then
        pcall(function()
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid or LocalPlayer.Character
        end)
    end
end

Extra.SpectatePlayer = function(player)
    local camera = workspace.CurrentCamera
    local humanoid = GetHumanoid(player)

    if camera and humanoid then
        Extra.SpectatedPlayer = player

        pcall(function()
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end)

        Notify("Spectating", player.DisplayName)
    end
end

Extra.TeleportToPlayer = function(player)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local targetRoot = GetRoot(player)

    if not root or not targetRoot then
        return
    end

    pcall(function()
        root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
    end)
end

Connect(LocalPlayer.CharacterAdded, function()
    task.wait(0.4)

    Extra.StopFly()
    ApplyLocal()
    Extra.ApplyEnvironment()
end)

Connect(UIS.InputBegan, function(input, gameProcessed)
    if Destroyed or not Config.ClickTP then
        return
    end

    if gameProcessed
        or input.UserInputType ~= Enum.UserInputType.MouseButton1
        or UIS:GetFocusedTextBox() then

        return
    end

    local camera = workspace.CurrentCamera
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not camera or not root then
        return
    end

    local mouse = UIS:GetMouseLocation()
    local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }

    local result = workspace:Raycast(
        ray.Origin,
        ray.Direction * Config.ClickTPDistance,
        params
    )

    if result then
        root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3.5, 0))
    end
end)

Connect(UIS.JumpRequest, function()
    if not Config.InfiniteJump then
        return
    end

    local humanoid = CurrentHumanoid()

    if humanoid then
        humanoid.Jump = true
    end
end)

Connect(LocalPlayer.Idled, function()
    if not Config.AntiAFK then
        return
    end

    pcall(function()
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--==================================================
-- INPUT - KEYBIND CAPTURE + AIM ACTIVATION
--==================================================

Connect(UIS.InputBegan, function(input, processed)
    if Destroyed then
        return
    end

    if ListeningForAimKey then
        if input.KeyCode == Enum.KeyCode.Escape then
            ListeningForAimKey = false
            KeybindStatus.Visible = false
            UpdateKeybindDisplay()
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard
            or input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then

            if SetAimKey(input) then
                ListeningForAimKey = false
                KeybindStatus.Visible = false
            end
        end

        return
    end

    if processed then
        return
    end

    if IsAimKey(input) then
        if Config.AimActivation == "Hold" then
            AimHeld = true
        elseif Config.AimActivation == "Toggle" then
            AimToggled = not AimToggled
        end
    end
end)

Connect(UIS.InputEnded, function(input)
    if Destroyed then
        return
    end

    if IsAimKey(input) then
        AimHeld = false
    end
end)

Connect(UIS.WindowFocusReleased, function()
    AimHeld = false
end)

--==================================================
-- TABS
--==================================================

local Tabs = {
    Aim = Window:Tab({
        Name = "Aim",
        Icon = "crosshair",
    }),

    ESP = Window:Tab({
        Name = "ESP",
        Icon = "scan-eye",
    }),

    Visuals = Window:Tab({
        Name = "Visuals",
        Icon = "palette",
    }),

    Local = Window:Tab({
        Name = "Local",
        Icon = "user",
    }),

    Players = Window:Tab({
        Name = "Players",
        Icon = "user",
    }),

    Customize = Window:Tab({
        Name = "Customize",
        Icon = "sliders-horizontal",
    }),

    Settings = Window:Tab({
        Name = "Settings",
        Icon = "settings",
    }),
}

--==================================================
-- AIM TAB
--==================================================

do
    local AimbotPage = Tabs.Aim:SubTab({
        Name = "Aimbot",
        Icon = "crosshair",
    })

    local FovPage = Tabs.Aim:SubTab({
        Name = "Fov Visual",
        Icon = "eye",
    })

    local KeybindPage = Tabs.Aim:SubTab({
        Name = "Keybind",
        Icon = "keyboard",
    })

    local AimbotBox = AimbotPage:AddLeftGroupbox({
        Name = "Aimbot",
        Icon = "crosshair",
    })

    local ResponseBox = AimbotPage:AddRightGroupbox({
        Name = "Response",
        Icon = "sliders-horizontal",
    })

    local FovBox = FovPage:AddLeftGroupbox({
        Name = "Fov Circle",
        Icon = "eye",
    })

    local TargetingBox = FovPage:AddRightGroupbox({
        Name = "Targeting",
        Icon = "target",
    })

    local KeybindBox = KeybindPage:AddLeftGroupbox({
        Name = "Aimlock Keybind",
        Icon = "keyboard",
    })

    local ActivationBox = KeybindPage:AddRightGroupbox({
        Name = "Activation",
        Icon = "power",
    })

    AimbotBox:Toggle({
        Name = "Enable Aimlock",
        Default = Config.AimEnabled,
        Flag = "AimEnabled",
        Callback = function(v)
            Config.AimEnabled = v
            Target = nil
            AimHeld = false
            AimToggled = false
        end,
    })

    AimbotBox:Dropdown({
        Name = "Target Selection",
        Options = {
            "Closest to Crosshair",
            "Closest to Character",
            "Lowest Health",
        },
        Default = Config.AimMode,
        Flag = "AimMode",
        Callback = function(v)
            Config.AimMode = v
            Target = nil
        end,
    })

    AimbotBox:Dropdown({
        Name = "Target Part",
        Options = {
            "Head",
            "Neck",
            "Torso",
            "Pelvis",
            "Root",
            "Nearest",
        },
        Default = Config.AimPart,
        Flag = "AimPart",
        Callback = function(v)
            Config.AimPart = v
        end,
    })

    ResponseBox:Slider({
        Name = "Maximum Distance",
        Min = 50,
        Max = 2000,
        Step = 25,
        Default = Config.AimDistance,
        Flag = "AimDistance",
        Callback = function(v)
            Config.AimDistance = v
        end,
    })

    ResponseBox:Slider({
        Name = "Smoothness",
        Min = 1,
        Max = 30,
        Step = 1,
        Default = Config.Smoothness,
        Flag = "Smoothness",
        Callback = function(v)
            Config.Smoothness = v
        end,
    })

    ResponseBox:Slider({
        Name = "Prediction",
        Min = 0,
        Max = 0.3,
        Step = 0.01,
        Default = Config.Prediction,
        Flag = "Prediction",
        Callback = function(v)
            Config.Prediction = v
        end,
    })

    ResponseBox:Divider()

    ResponseBox:Slider({
        Name = "Horizontal Offset",
        Min = -3,
        Max = 3,
        Step = 0.1,
        Default = Config.AimOffsetX,
        Flag = "AimOffsetX",
        Callback = function(v)
            Config.AimOffsetX = v
        end,
    })

    ResponseBox:Slider({
        Name = "Vertical Offset",
        Min = -3,
        Max = 3,
        Step = 0.1,
        Default = Config.AimOffsetY,
        Flag = "AimOffsetY",
        Callback = function(v)
            Config.AimOffsetY = v
        end,
    })

    FovBox:Slider({
        Name = "FOV Radius",
        Min = 30,
        Max = 600,
        Step = 5,
        Default = Config.AimFOV,
        Flag = "AimFOV",
        Callback = function(v)
            Config.AimFOV = v
        end,
    })

    FovBox:Toggle({
        Name = "Show FOV",
        Default = Config.ShowFOV,
        Flag = "ShowFOV",
        Callback = function(v)
            Config.ShowFOV = v
        end,
    })

    FovBox:Divider()

    FovBox:Paragraph({
        Name = "Note",
        Content = "* FOV Radius drives both the visual circle and the aimlock selection radius.",
    })

    TargetingBox:Toggle({
        Name = "Target Indicator",
        Default = Config.TargetIndicator,
        Flag = "TargetIndicator",
        Callback = function(v)
            Config.TargetIndicator = v
        end,
    })

    TargetingBox:Toggle({
        Name = "Sticky Target",
        Default = Config.StickyTarget,
        Flag = "StickyTarget",
        Callback = function(v)
            Config.StickyTarget = v
        end,
    })

    TargetingBox:Divider()

    TargetingBox:Toggle({
        Name = "Team Check",
        Default = Config.TeamCheck,
        Flag = "TeamCheck",
        Callback = function(v)
            Config.TeamCheck = v
            Target = nil
        end,
    })

    TargetingBox:Toggle({
        Name = "Visibility Check",
        Default = Config.VisibilityCheck,
        Flag = "VisibilityCheck",
        Callback = function(v)
            Config.VisibilityCheck = v
        end,
    })

    TargetingBox:Divider()

    TargetingBox:Toggle({
        Name = "Target Highlight",
        Desc = "Outline the locked player through walls",
        Default = Config.AimTargetHighlight,
        Flag = "AimTargetHighlight",
        Callback = function(v)
            Config.AimTargetHighlight = v

            if not v then
                Extra.SetAimHighlight(nil)
            end
        end,
    })

    TargetingBox:ColorPicker({
        Name = "Highlight Colour",
        Default = Config.TargetHighlightColor,
        Flag = "TargetHighlightColor",
        Callback = function(color)
            Config.TargetHighlightColor = color

            if Extra.AimHighlight then
                Extra.AimHighlight.OutlineColor = color
            end
        end,
    })

    KeybindBox:Label("Current Key: " .. GetAimKeyName())

    KeybindBox:Button({
        Name = "Set Aimlock Key",
        Icon = "keyboard",
        Callback = function()
            ListeningForAimKey = true
            AimHeld = false
            AimToggled = false
            Target = nil

            KeybindStatus.Visible = true
            KeybindText.Text = "PRESS ANY KEY OR MOUSE BUTTON"

            Notify(
                "KEYBIND LISTENING",
                "Press a keyboard key or mouse button."
            )
        end,
    })

    KeybindBox:Button({
        Name = "Cancel Key Selection",
        Icon = "x",
        Callback = function()
            ListeningForAimKey = false
            KeybindStatus.Visible = false
            UpdateKeybindDisplay()
        end,
    })

    KeybindBox:Divider()

    KeybindBox:Paragraph({
        Name = "Note",
        Content = "* Press Set Aimlock Key, then press any keyboard key or mouse button to bind it.",
    })

    ActivationBox:Dropdown({
        Name = "Activation Mode",
        Options = {
            "Hold",
            "Toggle",
            "Always",
        },
        Default = Config.AimActivation,
        Flag = "AimActivation",
        Callback = function(v)
            Config.AimActivation = v
            AimHeld = false
            AimToggled = false
            Target = nil
        end,
    })

    ActivationBox:Divider()

    ActivationBox:Paragraph({
        Name = "Note",
        Content = "* Hold: aimlock only while the key is down. Toggle: press once to arm, press again to release. Always: permanent lock while enabled.",
    })
end

--==================================================
-- ESP TAB
--==================================================

do
    local EspBox = Tabs.ESP:AddLeftGroupbox({
        Name = "Esp",
        Icon = "scan-eye",
    })

    local ElementsBox = Tabs.ESP:AddRightGroupbox({
        Name = "Elements",
        Icon = "list",
    })

    EspBox:Toggle({
        Name = "Enable ESP",
        Default = Config.ESPEnabled,
        Flag = "ESPEnabled",
        Callback = function(v)
            Config.ESPEnabled = v
        end,
    })

    EspBox:Slider({
        Name = "Maximum ESP Distance",
        Min = 100,
        Max = 3000,
        Step = 50,
        Default = Config.ESPMaxDistance,
        Flag = "ESPMaxDistance",
        Callback = function(v)
            Config.ESPMaxDistance = v
        end,
    })

    EspBox:Divider()

    EspBox:Toggle({
        Name = "Team Check",
        Default = Config.ESPTeamCheck,
        Flag = "ESPTeamCheck",
        Callback = function(v)
            Config.ESPTeamCheck = v
        end,
    })

    EspBox:Toggle({
        Name = "Visible Only",
        Desc = "Skip players behind geometry",
        Default = Config.ESPVisibleOnly,
        Flag = "ESPVisibleOnly",
        Callback = function(v)
            Config.ESPVisibleOnly = v
        end,
    })

    ElementsBox:Toggle({
        Name = "2D Boxes",
        Default = Config.ESPBoxes,
        Flag = "ESPBoxes",
        Callback = function(v)
            Config.ESPBoxes = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Player Names",
        Default = Config.ESPNames,
        Flag = "ESPNames",
        Callback = function(v)
            Config.ESPNames = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Display Name",
        Desc = "Use display names instead of usernames",
        Default = Config.ESPDisplayName,
        Flag = "ESPDisplayName",
        Callback = function(v)
            Config.ESPDisplayName = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Health Bars",
        Default = Config.ESPHealth,
        Flag = "ESPHealth",
        Callback = function(v)
            Config.ESPHealth = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Distance Labels",
        Default = Config.ESPDistance,
        Flag = "ESPDistance",
        Callback = function(v)
            Config.ESPDistance = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Tracers",
        Default = Config.ESPTracers,
        Flag = "ESPTracers",
        Callback = function(v)
            Config.ESPTracers = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Skeleton",
        Default = Config.ESPSkeleton,
        Flag = "ESPSkeleton",
        Callback = function(v)
            Config.ESPSkeleton = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Character Highlights",
        Default = Config.ESPHighlights,
        Flag = "ESPHighlights",
        Callback = function(v)
            Config.ESPHighlights = v
        end,
    })

    ElementsBox:Divider()

    ElementsBox:Toggle({
        Name = "Head Dots",
        Default = Config.ESPHeadDot,
        Flag = "ESPHeadDot",
        Callback = function(v)
            Config.ESPHeadDot = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Weapon Labels",
        Default = Config.ESPWeapon,
        Flag = "ESPWeapon",
        Callback = function(v)
            Config.ESPWeapon = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Box Fill",
        Desc = "Translucent colour inside the 2D box",
        Default = Config.ESPBoxFill,
        Flag = "ESPBoxFill",
        Callback = function(v)
            Config.ESPBoxFill = v
        end,
    })

    ElementsBox:Toggle({
        Name = "Off-screen Arrows",
        Desc = "Point toward players outside the viewport",
        Default = Config.ESPArrows,
        Flag = "ESPArrows",
        Callback = function(v)
            Config.ESPArrows = v
        end,
    })

    local RadarBox = Tabs.ESP:AddLeftGroupbox({
        Name = "Radar",
        Icon = "scan-eye",
    })

    RadarBox:Toggle({
        Name = "Enable Radar",
        Default = Config.ESPRadar,
        Flag = "ESPRadar",
        Callback = function(v)
            Config.ESPRadar = v
        end,
    })

    RadarBox:Slider({
        Name = "Radar Size",
        Min = 100,
        Max = 320,
        Step = 10,
        Default = Config.RadarSize,
        Flag = "RadarSize",
        Callback = function(v)
            Config.RadarSize = v
        end,
    })

    RadarBox:Slider({
        Name = "Radar Range",
        Min = 50,
        Max = 1500,
        Step = 25,
        Default = Config.RadarRange,
        Flag = "RadarRange",
        Callback = function(v)
            Config.RadarRange = v
        end,
    })

    RadarBox:Slider({
        Name = "Radar Opacity",
        Min = 0.05,
        Max = 0.9,
        Step = 0.05,
        Default = Config.RadarOpacity,
        Flag = "RadarOpacity",
        Callback = function(v)
            Config.RadarOpacity = v
        end,
    })

    RadarBox:Toggle({
        Name = "Rotate With Camera",
        Default = Config.RadarRotate,
        Flag = "RadarRotate",
        Callback = function(v)
            Config.RadarRotate = v
        end,
    })
end

--==================================================
-- VISUALS TAB
--==================================================

do
    local CrosshairPage = Tabs.Visuals:SubTab({
        Name = "Crosshair",
        Icon = "crosshair",
    })

    local ViewmodelPage = Tabs.Visuals:SubTab({
        Name = "Viewmodel",
        Icon = "layers",
    })

    local ChamsPage = Tabs.Visuals:SubTab({
        Name = "Chams",
        Icon = "scan",
    })

    local SkinsPage = Tabs.Visuals:SubTab({
        Name = "Skins",
        Icon = "palette",
    })

    local CrosshairBox = CrosshairPage:AddLeftGroupbox({
        Name = "Crosshair",
        Icon = "crosshair",
    })

    local CrosshairColorBox = CrosshairPage:AddRightGroupbox({
        Name = "Crosshair Color",
        Icon = "palette",
    })

    local RainbowBox = ViewmodelPage:AddLeftGroupbox({
        Name = "Rainbow Viewmodel",
        Icon = "layers",
    })

    CrosshairBox:Toggle({
        Name = "Custom Crosshair",
        Default = Config.CrosshairEnabled,
        Flag = "CrosshairEnabled",
        Callback = function(v)
            Config.CrosshairEnabled = v
            UpdateCrosshair()
        end,
    })

    CrosshairBox:Slider({
        Name = "Crosshair Size",
        Min = 3,
        Max = 24,
        Step = 1,
        Default = Config.CrosshairSize,
        Flag = "CrosshairSize",
        Callback = function(v)
            Config.CrosshairSize = v
            UpdateCrosshair()
        end,
    })

    CrosshairBox:Slider({
        Name = "Crosshair Gap",
        Min = 0,
        Max = 20,
        Step = 1,
        Default = Config.CrosshairGap,
        Flag = "CrosshairGap",
        Callback = function(v)
            Config.CrosshairGap = v
            UpdateCrosshair()
        end,
    })

    CrosshairColorBox:ColorPicker({
        Name = "Crosshair Color",
        Default = Config.CrosshairColor,
        Flag = "CrosshairColor",
        Callback = function(v)
            Config.CrosshairColor = v
            UpdateCrosshair()
        end,
    })

    RainbowBox:Toggle({
        Name = "Rainbow Viewmodel",
        Default = Config.RainbowGunEnabled,
        Flag = "RainbowGunEnabled",
        Callback = function(v)
            Config.RainbowGunEnabled = v

            if not v then
                RestoreViewmodel()
            end
        end,
    })

    RainbowBox:Slider({
        Name = "Rainbow Speed",
        Min = 0.05,
        Max = 1.5,
        Step = 0.05,
        Default = Config.RainbowGunSpeed,
        Flag = "RainbowGunSpeed",
        Callback = function(v)
            Config.RainbowGunSpeed = v
        end,
    })

    RainbowBox:Divider()

    RainbowBox:Button({
        Name = "Restore Viewmodel Colors",
        Icon = "rotate-ccw",
        Callback = function()
            Config.RainbowGunEnabled = false
            RestoreViewmodel()
        end,
    })

    --==================================================
    -- CHAMS PAGE
    --==================================================

    local ChamsBox = ChamsPage:AddLeftGroupbox({
        Name = "Chams",
        Icon = "scan",
    })

    local ChamsColorBox = ChamsPage:AddRightGroupbox({
        Name = "Colors",
        Icon = "palette",
    })

    ChamsBox:Toggle({
        Name = "Enable Chams",
        Desc = "Fill or clone player bodies",
        Default = Config.ChamsEnabled,
        Flag = "ChamsEnabled",
        Callback = function(v)
            Config.ChamsEnabled = v

            if v then
                ReconcileChams()
            else
                ClearChams()
            end
        end,
    })

    ChamsBox:Dropdown({
        Name = "Render Mode",
        Options = {
            "Highlight",
            "Solid",
            "Both",
        },
        Default = Config.ChamsMode,
        Flag = "ChamsMode",
        Callback = function(v)
            Config.ChamsMode = v

            if Config.ChamsEnabled then
                ReconcileChams()
            end
        end,
    })

    ChamsBox:Toggle({
        Name = "Through Walls",
        Desc = "Draw chams on top of geometry",
        Default = Config.ChamsWalls,
        Flag = "ChamsWalls",
        Callback = function(v)
            Config.ChamsWalls = v
            RestyleChams()
        end,
    })

    ChamsBox:Dropdown({
        Name = "Solid Material",
        Options = {
            "Neon",
            "ForceField",
            "SmoothPlastic",
            "Glass",
            "Plastic",
            "Metal",
        },
        Default = Config.ChamsMaterial,
        Flag = "ChamsMaterial",
        Callback = function(v)
            Config.ChamsMaterial = v
            RestyleChams()
        end,
    })

    ChamsColorBox:ColorPicker({
        Name = "Fill",
        Default = Config.ChamsFill,
        Flag = "ChamsFill",
        Callback = function(v)
            Config.ChamsFill = v
            RestyleChams()
        end,
    })

    ChamsColorBox:Slider({
        Name = "Fill Transparency",
        Min = 0,
        Max = 1,
        Step = 0.05,
        Default = Config.ChamsFillTransparency,
        Flag = "ChamsFillTransparency",
        Callback = function(v)
            Config.ChamsFillTransparency = v
            RestyleChams()
        end,
    })

    ChamsColorBox:ColorPicker({
        Name = "Outline",
        Default = Config.ChamsOutline,
        Flag = "ChamsOutline",
        Callback = function(v)
            Config.ChamsOutline = v
            RestyleChams()
        end,
    })

    ChamsColorBox:Slider({
        Name = "Outline Transparency",
        Min = 0,
        Max = 1,
        Step = 0.05,
        Default = Config.ChamsOutlineTransparency,
        Flag = "ChamsOutlineTransparency",
        Callback = function(v)
            Config.ChamsOutlineTransparency = v
            RestyleChams()
        end,
    })

    ChamsColorBox:ColorPicker({
        Name = "Solid Color",
        Default = Config.ChamsSolid,
        Flag = "ChamsSolid",
        Callback = function(v)
            Config.ChamsSolid = v
            RestyleChams()
        end,
    })

    ChamsColorBox:Slider({
        Name = "Solid Transparency",
        Min = 0,
        Max = 1,
        Step = 0.05,
        Default = Config.ChamsSolidTransparency,
        Flag = "ChamsSolidTransparency",
        Callback = function(v)
            Config.ChamsSolidTransparency = v
            RestyleChams()
        end,
    })

    ChamsBox:Paragraph({
        Name = "Note",
        Content = "* Highlight uses the engine's Highlight object. Solid clones are anchored copies inside CARBON_ChamsBodies.",
    })

    --==================================================
    -- CARBON SKIN SYSTEM
    -- Integrated from the supplied Arsenal skin changer.
    -- Uses the existing CARBON window and cleanup.
    --==================================================

    local SkinClient = ReplicatedFirst:FindFirstChild("Client")
    local SkinUtility = SkinClient
        and SkinClient:FindFirstChild("Utility")

    local SkinGameFolder = SkinClient
        and SkinClient:FindFirstChild("Game")

    local SkinData = LocalPlayer:FindFirstChild("Data")
    local SkinMeleeValue = SkinData
        and SkinData:FindFirstChild("Melee")

    local SkinEquippedValue = LocalPlayer:FindFirstChild("Equipped")

    local SkinMeleesFolder =
        ReplicatedStorage:FindFirstChild("Melees")

    local SkinViewmodelsFolder =
        ReplicatedStorage:FindFirstChild("Viewmodels")

    local SkinSkinsFolder =
        ReplicatedStorage:FindFirstChild("Skins")

    local SkinCommonFolder =
        ReplicatedStorage:FindFirstChild("Common")

    local SkinTemplate = SkinCommonFolder
        and SkinCommonFolder:FindFirstChild("Skin")

    local SkinStateModule
    local SkinViewmodelsModule
    local SkinBridgeModule

    local function SkinGetState()
        if SkinStateModule then
            return SkinStateModule
        end

        local module = SkinUtility
            and SkinUtility:FindFirstChild("State")

        if not module then
            return nil
        end

        local ok, result = pcall(require, module)

        if ok and type(result) == "table" then
            SkinStateModule = result
        end

        return SkinStateModule
    end

    local function SkinGetViewmodels()
        if SkinViewmodelsModule then
            return SkinViewmodelsModule
        end

        local module = SkinGameFolder
            and SkinGameFolder:FindFirstChild("Viewmodels")

        if not module then
            return nil
        end

        local ok, result = pcall(require, module)

        if ok and type(result) == "table" then
            SkinViewmodelsModule = result
        end

        return SkinViewmodelsModule
    end

    local function SkinGetBridge()
        if SkinBridgeModule then
            return SkinBridgeModule
        end

        local module = SkinUtility
            and SkinUtility:FindFirstChild("Bridge")

        if not module then
            return nil
        end

        local ok, result = pcall(require, module)

        if ok and type(result) == "table" then
            SkinBridgeModule = result
        end

        return SkinBridgeModule
    end

    SkinGetState()

    local SkinOriginalMelee =
        SkinMeleeValue and SkinMeleeValue.Value or nil

    if SkinOriginalMelee == "" then
        SkinOriginalMelee = nil
    end

    local SkinRunning = true
    local SkinSuppressMeleeWatch = false
    local SkinRebuilding = false
    local SkinRebuildQueued = false
    local SkinLastForcedRebuild = 0

    local SkinSelectedMelee
    local SkinAppliedMelee
    local SkinSelectedSkin
    local SkinAppliedSkin

    local SkinMeleeOptions = {}
    local SkinSkinOptions = { "Nenhuma" }

    local SkinStatusPanels = {}

    local SkinMeleeDropdown
    local SkinSkinDropdown
    local SkinMeleePreview
    local SkinMeleeInfo
    local SkinImagePreview
    local SkinImageInfo

    local SkinAutoMelee = false
    local SkinAutoSkin = true

    local function SkinBaseMelee(value)
        if type(value) ~= "string" or value == "" then
            return nil
        end

        return value:match("^([^_]+)") or value
    end

    local function SkinCurrentMelee()
        return SkinMeleeValue and SkinMeleeValue.Value or nil
    end

    local function SkinCurrentBaseMelee()
        return SkinBaseMelee(SkinCurrentMelee())
    end

    local function SkinGetArms()
        local camera = workspace.CurrentCamera
        return camera and camera:FindFirstChild("Arms") or nil
    end

    local function SkinIsMeleeEquipped()
        local state = SkinGetState()

        return state ~= nil
            and state.equipped == "melee"
            and state.gun ~= nil
    end

    local function SkinNotify(title, message, kind)
        if Destroyed or not SkinRunning then
            return
        end

        pcall(function()
            Window:Notify({
                Title = tostring(title or "CARBON SKINS"),
                Content = tostring(message or ""),
                Type = kind or "Info",
                Duration = 4,
            })
        end)
    end

    local function SkinCanRebuild()
        local state = SkinGetState()

        if not state then
            return false, "Game state module unavailable."
        end

        if state.equipped ~= "melee" then
            return false, "Equip your melee first."
        end

        if not state.gun then
            return false, "Current viewmodel has not loaded."
        end

        if state.meleeslot ~= "Knife"
            and state.meleeslot ~= "Golden Knife" then

            return false, "The equipped slot is not a knife."
        end

        return true
    end

    local function SkinWaitForIdle(timeout)
        local state = SkinGetState()

        if not state then
            return
        end

        local deadline = os.clock() + (timeout or 5)

        while SkinRunning
            and not Destroyed
            and (state.equipping or state.DISABLED)
            and os.clock() < deadline do

            task.wait(0.05)
        end
    end

    -- The game's own mapSkin changes Material / Color / BrickColor as well as
    -- adding textures. Remember those values so Remove can put the weapon back
    -- instead of leaving it neon or tinted.
    local SKIN_PART_ATTRS = {
        "CarbonSkinTouched",
        "CarbonSkinMaterial",
        "CarbonSkinBrickColor",
        "CarbonSkinColor",
    }

    local function SkinCapturePart(part)
        if part:GetAttribute("CarbonSkinTouched") then
            return
        end

        part:SetAttribute("CarbonSkinMaterial", part.Material.Name)
        part:SetAttribute("CarbonSkinBrickColor", part.BrickColor)
        part:SetAttribute("CarbonSkinColor", part.Color)
        part:SetAttribute("CarbonSkinTouched", true)
    end

    local function SkinRestorePart(part)
        if not part:GetAttribute("CarbonSkinTouched") then
            return
        end

        local material = part:GetAttribute("CarbonSkinMaterial")
        local brickColor = part:GetAttribute("CarbonSkinBrickColor")
        local color = part:GetAttribute("CarbonSkinColor")

        if material then
            pcall(function()
                part.Material = Enum.Material[material]
            end)
        end

        if brickColor then
            part.BrickColor = brickColor
        end

        if color then
            part.Color = color
        end

        for _, attribute in ipairs(SKIN_PART_ATTRS) do
            part:SetAttribute(attribute, nil)
        end
    end

    local function SkinRemoveTextures(arms)
        if not arms then
            return 0
        end

        local removed = 0

        for _, descendant in ipairs(arms:GetDescendants()) do
            if descendant:IsA("Texture")
                and descendant.Name == "Skin" then

                descendant:Destroy()
                removed += 1
            elseif descendant:IsA("BasePart") then
                SkinRestorePart(descendant)
            end
        end

        return removed
    end

    -- True only when this hub actually changed the viewmodel. Without this
    -- check, Remove or unload would strip the skin the game itself applied.
    local function SkinHasOurChanges(arms)
        if not arms then
            return false
        end

        if arms:GetAttribute("ArsenalSkin") ~= nil then
            return true
        end

        for _, descendant in ipairs(arms:GetDescendants()) do
            if descendant:GetAttribute("CarbonSkinTouched") then
                return true
            end
        end

        return false
    end

    local function SkinCountTextures(arms)
        if not arms then
            return 0
        end

        local count = 0

        for _, descendant in ipairs(arms:GetDescendants()) do
            if descendant:IsA("Texture")
                and descendant.Name == "Skin" then

                count += 1
            end
        end

        return count
    end

    local SKIN_FACES = {
        Enum.NormalId.Top,
        Enum.NormalId.Bottom,
        Enum.NormalId.Right,
        Enum.NormalId.Left,
        Enum.NormalId.Front,
        Enum.NormalId.Back,
    }

    local SKIN_EXCLUDED = {
        ["Left Arm"] = true,
        ["Right Arm"] = true,
        ["HumanoidRootPart"] = true,
        ["Joint"] = true,
    }

    --==================================================
    -- SKIN FALLBACK
    --==================================================

    local function SkinApplyFallback(arms, skinName)
        if not arms or not SkinTemplate or not SkinSkinsFolder then
            return 0
        end

        local skin = SkinSkinsFolder:FindFirstChild(skinName)

        if not skin then
            return 0
        end

        local scaleObject = skin:FindFirstChild("Scale")
        local shadeObject = skin:FindFirstChild("Shade")
        local multiplierObject = skin:FindFirstChild("Multiplier")

        local scale = tonumber(
            scaleObject and scaleObject.Value
        ) or 1

        if scale <= 0 then
            scale = 1
        end

        local shade = shadeObject
            and shadeObject.Value
            or Color3.new(1, 1, 1)

        local multiplier = tonumber(
            multiplierObject and multiplierObject.Value
        ) or 1

        local color = Color3.new(
            shade.R * multiplier,
            shade.G * multiplier,
            shade.B * multiplier
        )

        local applied = 0

        for _, part in ipairs(arms:GetDescendants()) do
            if part:IsA("BasePart")
                and part.Transparency <= 0
                and not SKIN_EXCLUDED[part.Name] then

                SkinCapturePart(part)

                local neon = skin:FindFirstChild("Neon")

                if neon then
                    part.Material = Enum.Material.Neon

                    if neon:IsA("BrickColorValue") then
                        part.BrickColor = neon.Value
                    elseif neon:IsA("Color3Value") then
                        part.Color = neon.Value
                    end
                end

                local colored = skin:FindFirstChild("Colored")

                if colored and colored:IsA("BrickColorValue") then
                    part.BrickColor = colored.Value
                end

                local material = skin:FindFirstChild("Material")

                if material and material:IsA("StringValue") then
                    pcall(function()
                        part.Material = Enum.Material[material.Value]
                    end)
                end

                for _, face in ipairs(SKIN_FACES) do
                    local texture = SkinTemplate:Clone()

                    texture.Name = "Skin"
                    texture.Texture = skin.Value
                    texture.Color3 = color
                    texture.StudsPerTileU = scale
                    texture.StudsPerTileV = scale
                    texture.Face = face

                    texture.OffsetStudsV =
                        -(part.Size.Y + (part.Position.Y - part.Size.Y / 2) % scale)

                    texture.OffsetStudsU =
                        part.Position.Z - part.Size.Z / 2 % scale

                    texture.Parent = part
                    applied += 1
                end
            end
        end

        return applied
    end

    --==================================================
    -- GAME SKIN EVENT
    --==================================================

    local function SkinFireGameSkin(arms, skinName)
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local mapDat = playerGui
            and playerGui:FindFirstChild("MapDat")

        if mapDat and mapDat:IsA("BindableEvent") then
            local ok = pcall(function()
                mapDat:Fire(arms, skinName, LocalPlayer)
            end)

            if ok then
                return true
            end
        end

        local bridge = SkinGetBridge()
        local signal = bridge and bridge.MapWeaponSkin

        if signal and type(signal.Fire) == "function" then
            local ok = pcall(function()
                signal:Fire(arms, skinName, LocalPlayer)
            end)

            if ok then
                return true
            end
        end

        return false
    end

    --==================================================
    -- APPLY SKIN
    --==================================================

    local function SkinApplyToArms(arms, skinName, silent)
        if not arms or not arms.Parent then
            return 0
        end

        if not skinName
            or skinName == ""
            or skinName == "Nenhuma" then

            SkinRemoveTextures(arms)

            arms:SetAttribute("ArsenalSkin", nil)
            arms:SetAttribute("ArsenalSkinCount", nil)

            return 0
        end

        local skin = SkinSkinsFolder
            and SkinSkinsFolder:FindFirstChild(skinName)

        if not skin then
            if not silent then
                SkinNotify("Invalid skin", skinName, "Error")
            end

            return 0
        end

        SkinRemoveTextures(arms)

        -- mapSkin can change Material / Color as well as add textures, so record
        -- the clean state before letting it run.
        for _, part in ipairs(arms:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency <= 0 then
                SkinCapturePart(part)
            end
        end

        SkinFireGameSkin(arms, skinName)

        local count = SkinCountTextures(arms)

        if count == 0 then
            count = SkinApplyFallback(arms, skinName)
        end

        arms:SetAttribute("ArsenalSkin", skinName)
        arms:SetAttribute("ArsenalSkinCount", count)

        if not silent then
            if count > 0 then
                SkinNotify(
                    "Skin applied",
                    ("%s • %d textures"):format(skinName, count),
                    "Success"
                )
            else
                SkinNotify(
                    "No support",
                    "This melee did not accept the texture.",
                    "Warning"
                )
            end
        end

        return count
    end

    --==================================================
    -- MELEE PREVIEW
    --==================================================

    local function SkinMakePreviewModel(name)
        local folder = SkinMeleesFolder
            and SkinMeleesFolder:FindFirstChild(name or "")

        local model = folder and folder:FindFirstChild("Model")

        if not model then
            return nil
        end

        if model:IsA("Model") then
            return model
        end

        local wrapper = Instance.new("Model")
        wrapper.Name = name

        local clone = model:Clone()
        clone.Parent = wrapper

        return wrapper
    end

    local function SkinUpdateMeleePreview()
        if not SkinMeleePreview then
            return
        end

        local previewModel = SkinMakePreviewModel(SkinSelectedMelee)

        SkinMeleePreview:SetModel(previewModel)
        SkinMeleePreview:SetCaption(
            SkinSelectedMelee or "No melee selected"
        )

        if SkinMeleePreview.Model and SkinSelectedSkin then
            SkinRemoveTextures(SkinMeleePreview.Model)
            SkinApplyFallback(
                SkinMeleePreview.Model,
                SkinSelectedSkin
            )
        end

        if SkinMeleeInfo then
            local folder = SkinMeleesFolder
                and SkinMeleesFolder:FindFirstChild(
                    SkinSelectedMelee or ""
                )

            local meleeType = "Melee"

            if folder then
                local typeObject = folder:FindFirstChild("Type")

                if typeObject and typeObject:IsA("StringValue") then
                    meleeType = typeObject.Value
                end
            end

            SkinMeleeInfo:Set(
                ("Model: %s\nType: %s\nPreview skin: %s"):format(
                    SkinSelectedMelee or "—",
                    meleeType,
                    SkinSelectedSkin or "None"
                )
            )
        end
    end

    local function SkinUpdateImagePreview()
        if not SkinImagePreview then
            return
        end

        local skin = SkinSelectedSkin
            and SkinSkinsFolder
            and SkinSkinsFolder:FindFirstChild(SkinSelectedSkin)

        if skin then
            local url = skin.Value

            task.spawn(function()
                if not SkinRunning or Destroyed then
                    return
                end

                pcall(function()
                    SkinImagePreview:SetImage(url)
                    SkinImagePreview:SetCaption(SkinSelectedSkin)
                end)
            end)

            if SkinImageInfo then
                local scaleObject = skin:FindFirstChild("Scale")

                SkinImageInfo:Set(
                    ("Texture: %s\nScale: %s"):format(
                        tostring(url),
                        tostring(
                            scaleObject and scaleObject.Value or 1
                        )
                    )
                )
            end
        else
            pcall(function()
                SkinImagePreview:SetImage(nil)
                SkinImagePreview:SetCaption("No skin selected")
            end)

            if SkinImageInfo then
                SkinImageInfo:Set(
                    "Choose a skin to preview its texture."
                )
            end
        end
    end

    --==================================================
    -- SKIN STATUS
    --==================================================

    local function SkinStatusText()
        local state = SkinGetState()
        local current = SkinCurrentBaseMelee() or "?"
        local inMelee = state and state.equipped == "melee"
        local arms = SkinGetArms()

        local mode
        local tone

        if inMelee then
            mode = arms and "In game" or "Equipping"
            tone = arms and "Success" or "Warning"
        else
            mode = "Menu / not in combat"
            tone = "Warning"
        end

        return (
            "<%s>%s</%s>\nMelee: <Accent>%s</Accent> • Applied: <Accent>%s</Accent>\nSkin: <Accent>%s</Accent>"
        ):format(
            tone,
            mode,
            tone,
            current,
            SkinAppliedMelee or "—",
            SkinAppliedSkin or "None"
        )
    end

    --==================================================
    -- VIEWMODEL REBUILD
    --==================================================

    local SkinScheduleRebuild

    -- Resolve the arguments Arsenal's own equip path uses (Weapons:1509-1554):
    -- the selected ReplicatedStorage.Melees folder and State.gun.Deploy * 1.15.
    -- The folder is what supplies the humanoid Fire animation, so using
    -- Weapons[slot] here gives every non-default knife the base knife swing.
    local function SkinViewmodelArgs()
        local state = SkinGetState()

        if not state or not state.gun then
            return nil, 1.15, nil
        end

        local meleeBase = SkinCurrentBaseMelee()

        local meleeFolder = meleeBase
            and SkinMeleesFolder
            and SkinMeleesFolder:FindFirstChild(meleeBase)

        local modelArg = state.gun

        if meleeFolder
            and meleeFolder:FindFirstChild("Model")
            and meleeFolder:FindFirstChild("Fire") then

            modelArg = meleeFolder
        end

        local deploySpeed = 1

        if state.gun:FindFirstChild("Deploy") then
            local deploy = state.gun.Deploy

            if typeof(deploy) == "NumberValue" then
                deploySpeed = deploy.Value
            end
        end

        return modelArg, deploySpeed * 1.15, meleeFolder
    end

    local function SkinRebuildViewmodel(opts)
        opts = opts or {}

        if SkinRebuilding then
            SkinRebuildQueued = true
            return false, "rebuilding"
        end

        local ok, reason = SkinCanRebuild()

        if not ok then
            if opts.notify ~= false then
                SkinNotify("Unable to rebuild", reason, "Warning")
            end

            return false, reason
        end

        local state = SkinGetState()

        if state.equipping or state.DISABLED then
            if opts.wait ~= false then
                task.spawn(function()
                    SkinWaitForIdle(5)

                    if SkinRunning and not Destroyed then
                        SkinRebuildViewmodel(opts)
                    end
                end)
            end

            return false, "equipping"
        end

        local viewmodels = SkinGetViewmodels()

        if not viewmodels
            or type(viewmodels.CreateViewmodel) ~= "function" then

            if opts.notify ~= false then
                SkinNotify(
                    "Error",
                    "Viewmodels module unavailable.",
                    "Error"
                )
            end

            return false, "no viewmodels"
        end

        local camera = workspace.CurrentCamera

        if not camera then
            return false, "no camera"
        end

        local modelArg, equipSpeed = SkinViewmodelArgs()

        if not modelArg then
            return false, "no viewmodel target"
        end

        SkinRebuilding = true

        local oldArms = camera:FindFirstChild("Arms")

        if oldArms then
            oldArms:Destroy()
        end

        local success, err = pcall(function()
            viewmodels.CreateViewmodel(modelArg, equipSpeed)
        end)

        SkinRebuilding = false

        if not success then
            if opts.notify ~= false then
                SkinNotify(
                    "Rebuild error",
                    tostring(err),
                    "Error"
                )
            end

            return false, err
        end

        local arms = camera:FindFirstChild("Arms")

        if not arms then
            if opts.notify ~= false then
                SkinNotify(
                    "Viewmodel missing",
                    "The game did not create a viewmodel for this melee.",
                    "Warning"
                )
            end

            return false, "no arms"
        end

        arms:SetAttribute(
            "ArsenalMelee",
            SkinCurrentBaseMelee() or ""
        )

        if SkinAppliedSkin then
            task.defer(function()
                task.wait(0.05)

                if SkinRunning
                    and not Destroyed
                    and arms.Parent then

                    SkinApplyToArms(
                        arms,
                        SkinAppliedSkin,
                        true
                    )
                end
            end)
        end

        if SkinRebuildQueued then
            SkinRebuildQueued = false

            task.delay(0.15, function()
                if SkinRunning and not Destroyed then
                    SkinRebuildViewmodel({
                        notify = false,
                    })
                end
            end)
        end

        return true, arms
    end

    SkinScheduleRebuild = function()
        if SkinRebuildQueued then
            return
        end

        SkinRebuildQueued = true

        task.delay(0.12, function()
            SkinRebuildQueued = false

            if SkinRunning and not Destroyed then
                SkinRebuildViewmodel({
                    notify = false,
                })
            end
        end)
    end

    --==================================================
    -- APPLY / RESTORE MELEE
    --==================================================

    local function SkinApplyMelee(name)
        if type(name) ~= "string" or name == "" then
            SkinNotify(
                "Select a melee",
                "Choose a model from the list.",
                "Warning"
            )

            return false
        end

        local folder = SkinMeleesFolder
            and SkinMeleesFolder:FindFirstChild(name)

        local viewmodel = SkinViewmodelsFolder
            and SkinViewmodelsFolder:FindFirstChild("v_" .. name)

        if not folder
            or not folder:FindFirstChild("Model")
            or not viewmodel then

            SkinNotify(
                "Melee unavailable",
                "This model does not have a viewmodel.",
                "Error"
            )

            return false
        end

        SkinAppliedMelee = name
        SkinSelectedMelee = name

        -- Record the value we are about to overwrite so Restore has a target
        -- even when the hub was loaded while Data.Melee was still empty.
        if SkinMeleeValue and not SkinOriginalMelee then
            local current = SkinMeleeValue.Value
            SkinOriginalMelee = (current ~= "" and current) or nil
        end

        if SkinMeleeValue and SkinMeleeValue.Value ~= name then
            SkinSuppressMeleeWatch = true
            SkinMeleeValue.Value = name

            task.defer(function()
                SkinSuppressMeleeWatch = false
            end)
        end

        if SkinMeleeDropdown then
            SkinMeleeDropdown:Set(name, true)
        end

        SkinUpdateMeleePreview()

        -- The rebuild is not cosmetic. Arsenal resolves melee hits through the
        -- live viewmodel, so changing Data.Melee without rebuilding leaves a
        -- stale knife that cannot hit anything.
        if SkinIsMeleeEquipped() then
            local rebuilt = SkinRebuildViewmodel({
                notify = false,
            })

            if rebuilt then
                SkinNotify("Melee applied", name, "Success")
            end
        else
            SkinNotify(
                "Melee selected",
                "Equip your melee in-game to see the model.",
                "Warning"
            )
        end

        return true
    end

    local function SkinRestoreMelee()
        local original = SkinOriginalMelee

        SkinAppliedMelee = nil

        -- Nothing was recorded, so do not silently swap the player to a
        -- different melee just to make the UI look restored.
        if not original or original == "" then
            SkinNotify(
                "Nothing to restore",
                "No original melee was recorded.",
                "Warning"
            )

            return
        end

        local target = SkinBaseMelee(original)

        if not target or not table.find(SkinMeleeOptions, target) then
            target = SkinCurrentBaseMelee()
        end

        if not target or not table.find(SkinMeleeOptions, target) then
            target = table.find(SkinMeleeOptions, "Dagger")
                and "Dagger"
                or SkinMeleeOptions[1]
        end

        if target then
            SkinSelectedMelee = target

            if SkinMeleeDropdown then
                SkinMeleeDropdown:Set(target, true)
            end

            SkinUpdateMeleePreview()
        end

        if SkinMeleeValue then
            SkinSuppressMeleeWatch = true
            SkinMeleeValue.Value = original

            task.defer(function()
                SkinSuppressMeleeWatch = false
            end)
        end

        if SkinIsMeleeEquipped() then
            SkinRebuildViewmodel({
                notify = false,
            })
        end

        SkinNotify(
            "Original restored",
            original,
            "Success"
        )
    end

    --==================================================
    -- APPLY / REMOVE SKIN
    --==================================================

    local function SkinApplySelected()
        if not SkinSelectedSkin then
            SkinNotify(
                "No skin selected",
                "Choose a texture first.",
                "Warning"
            )

            return
        end

        SkinAppliedSkin = SkinSelectedSkin

        if SkinIsMeleeEquipped() then
            local rebuilt = SkinRebuildViewmodel({
                notify = false,
            })

            if rebuilt then
                SkinNotify(
                    "Skin applied",
                    SkinSelectedSkin,
                    "Success"
                )
            end
        else
            local arms = SkinGetArms()

            if arms then
                SkinApplyToArms(
                    arms,
                    SkinAppliedSkin
                )
            else
                SkinNotify(
                    "Skin selected",
                    "Equip your melee to see the texture.",
                    "Warning"
                )
            end
        end
    end

    local function SkinRemove()
        SkinAppliedSkin = nil
        SkinSelectedSkin = nil

        if SkinSkinDropdown then
            SkinSkinDropdown:Set("Nenhuma", true)
        end

        SkinUpdateImagePreview()
        SkinUpdateMeleePreview()

        local arms = SkinGetArms()

        if arms and SkinHasOurChanges(arms) then
            SkinRemoveTextures(arms)
            arms:SetAttribute("ArsenalSkin", nil)
            arms:SetAttribute("ArsenalSkinCount", nil)
        end

        if SkinIsMeleeEquipped() then
            SkinRebuildViewmodel({
                notify = false,
            })
        end

        SkinNotify(
            "Skin removed",
            "The custom texture has been removed.",
            "Success"
        )
    end

    --==================================================
    -- BUILD MELEE OPTIONS
    --==================================================

    if SkinMeleesFolder then
        for _, item in ipairs(SkinMeleesFolder:GetChildren()) do
            if item:IsA("Folder")
                and item:FindFirstChild("Model") then

                if not SkinViewmodelsFolder
                    or SkinViewmodelsFolder:FindFirstChild(
                        "v_" .. item.Name
                    ) then

                    table.insert(
                        SkinMeleeOptions,
                        item.Name
                    )
                end
            end
        end
    end

    table.sort(SkinMeleeOptions, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    SkinSelectedMelee = SkinCurrentBaseMelee()

    if not SkinSelectedMelee
        or not table.find(SkinMeleeOptions, SkinSelectedMelee) then

        SkinSelectedMelee = table.find(
            SkinMeleeOptions,
            "Dagger"
        ) and "Dagger" or SkinMeleeOptions[1]
    end

    --==================================================
    -- BUILD SKIN OPTIONS
    --==================================================

    if SkinSkinsFolder then
        local skinNames = {}

        for _, item in ipairs(SkinSkinsFolder:GetChildren()) do
            if item:IsA("StringValue") then
                table.insert(skinNames, item.Name)
            end
        end

        table.sort(skinNames, function(a, b)
            return string.lower(a) < string.lower(b)
        end)

        for _, name in ipairs(skinNames) do
            table.insert(SkinSkinOptions, name)
        end
    end

    --==================================================
    -- SKINS UI - MELEE
    --==================================================

    local MeleeLeft = SkinsPage:AddLeftGroupbox({
        Name = "Melee / Knife",
        Icon = "sword",
    })

    local MeleeRight = SkinsPage:AddRightGroupbox({
        Name = "Melee Preview",
        Icon = "eye",
    })

    SkinMeleeDropdown = MeleeLeft:Dropdown({
        Name = "Melee Model",
        Options = SkinMeleeOptions,
        Default = SkinSelectedMelee,
        Searchable = true,
        SearchAfter = 3,
        MaxRows = 7,

        Callback = function(value)
            if value then
                SkinSelectedMelee = value
                SkinUpdateMeleePreview()
            end
        end,
    })

    MeleeLeft:ButtonRow({
        {
            Name = "Apply Melee",
            Style = "Primary",
            Callback = function()
                SkinApplyMelee(SkinSelectedMelee)
            end,
        },

        {
            Name = "Restore",
            Style = "Danger",
            Callback = SkinRestoreMelee,
        },
    })

    MeleeLeft:Toggle({
        Name = "Keep Selected Melee",
        Desc = "Reapplies your selected melee if the game changes it.",
        Default = SkinAutoMelee,

        Callback = function(value)
            SkinAutoMelee = value
        end,
    })

    MeleeLeft:Label({
        Text = "Cosmetic changes are local to this client.",
    })

    table.insert(
        SkinStatusPanels,
        MeleeLeft:Paragraph({
            Name = "Melee Status",
            Content = SkinStatusText(),
        })
    )

    SkinMeleePreview = MeleeRight:Viewport({
        Name = "Selected Model",
        Height = 230,
        Spin = true,
        SpinSpeed = 22,
        Caption = SkinSelectedMelee or "",
    })

    SkinMeleeInfo = MeleeRight:Paragraph({
        Name = "Melee Details",
        Content = "",
    })

    SkinUpdateMeleePreview()

    --==================================================
    -- SKINS UI - TEXTURES
    --==================================================

    local TextureLeft = SkinsPage:AddLeftGroupbox({
        Name = "Weapon Skin",
        Icon = "palette",
    })

    local TextureRight = SkinsPage:AddRightGroupbox({
        Name = "Texture Preview",
        Icon = "image",
    })

    SkinSkinDropdown = TextureLeft:Dropdown({
        Name = "Texture",
        Options = SkinSkinOptions,
        Default = "Nenhuma",
        Searchable = true,
        SearchAfter = 3,
        MaxRows = 7,

        Callback = function(value)
            SkinSelectedSkin =
                (value and value ~= "Nenhuma")
                and value
                or nil

            SkinUpdateImagePreview()
            SkinUpdateMeleePreview()
        end,
    })

    TextureLeft:ButtonRow({
        {
            Name = "Apply Skin",
            Style = "Primary",
            Callback = SkinApplySelected,
        },

        {
            Name = "Remove",
            Style = "Danger",
            Callback = SkinRemove,
        },
    })

    TextureLeft:Toggle({
        Name = "Automatic Reapply",
        Desc = "Keeps your selected skin when the viewmodel is recreated.",
        Default = SkinAutoSkin,

        Callback = function(value)
            SkinAutoSkin = value
        end,
    })

    TextureLeft:Label({
        Text = "Skin changes are applied locally.",
    })

    table.insert(
        SkinStatusPanels,
        TextureLeft:Paragraph({
            Name = "Skin Status",
            Content = SkinStatusText(),
        })
    )

    SkinImagePreview = TextureRight:Image({
        Name = "Texture",
        Height = 200,
        ScaleType = "Fit",
        Caption = "No skin selected",
    })

    SkinImageInfo = TextureRight:Paragraph({
        Name = "Texture Details",
        Content = "Choose a skin to preview its texture.",
    })

    SkinUpdateImagePreview()

    --==================================================
    -- SKINS UI - SESSION
    --==================================================

    local SkinSessionBox = SkinsPage:AddLeftGroupbox({
        Name = "Skin Session",
        Icon = "refresh-cw",
    })

    SkinSessionBox:Button({
        Name = "Reapply Everything",
        Style = "Primary",

        Callback = function()
            if SkinAppliedMelee
                and SkinMeleeValue
                and SkinMeleeValue.Value ~= SkinAppliedMelee then

                SkinMeleeValue.Value = SkinAppliedMelee
            end

            if SkinIsMeleeEquipped() then
                SkinRebuildViewmodel({
                    notify = true,
                })
            else
                SkinNotify(
                    "Not in combat",
                    "Equip your melee in a match first.",
                    "Warning"
                )
            end
        end,
    })

    SkinSessionBox:Button({
        Name = "Restore Original Melee",
        Style = "Danger",
        Callback = SkinRestoreMelee,
    })

    SkinSessionBox:Button({
        Name = "Remove Active Skin",
        Style = "Danger",
        Callback = SkinRemove,
    })

    --==================================================
    -- SKIN STATUS WATCHER
    --==================================================

    task.spawn(function()
        while SkinRunning and not Destroyed do
            local status = SkinStatusText()

            for _, panel in ipairs(SkinStatusPanels) do
                pcall(function()
                    panel:Set(status)
                end)
            end

            task.wait(0.5)
        end
    end)

    --==================================================
    -- MELEE / SKIN WATCHER
    --==================================================

    task.spawn(function()
        while SkinRunning and not Destroyed do
            task.wait(0.2)

            if not SkinRunning or Destroyed then
                break
            end

            local state = SkinGetState()

            if state and not state.equipping and not state.DISABLED then
                local current = SkinCurrentMelee()

                -- Compare the base melee, not the raw value: collector variants
                -- store a suffix such as "Dagger_Collector Sparkle".
                if SkinAutoMelee
                    and SkinAppliedMelee
                    and SkinBaseMelee(current) ~= SkinAppliedMelee
                    and not SkinSuppressMeleeWatch
                    and SkinMeleeValue then

                    SkinSuppressMeleeWatch = true
                    SkinMeleeValue.Value = SkinAppliedMelee

                    task.defer(function()
                        SkinSuppressMeleeWatch = false
                    end)

                    if state.equipped == "melee"
                        and os.clock() - SkinLastForcedRebuild > 0.75 then

                        SkinLastForcedRebuild = os.clock()
                        SkinScheduleRebuild()
                    end
                end

                local arms = SkinGetArms()

                if arms
                    and SkinAppliedMelee
                    and SkinCurrentBaseMelee() == SkinAppliedMelee then

                    if arms:GetAttribute("ArsenalMelee")
                        ~= SkinAppliedMelee then

                        arms:SetAttribute(
                            "ArsenalMelee",
                            SkinAppliedMelee
                        )
                    end
                end

                if arms and SkinAutoSkin and SkinAppliedSkin then
                    if arms:GetAttribute("ArsenalSkin")
                        ~= SkinAppliedSkin then

                        SkinApplyToArms(
                            arms,
                            SkinAppliedSkin,
                            true
                        )
                    end
                end
            end
        end
    end)

    --==================================================
    -- SKIN MELEE VALUE WATCHER
    --==================================================

    if SkinMeleeValue then
        Connect(
            SkinMeleeValue:GetPropertyChangedSignal("Value"),
            function()
                if Destroyed
                    or not SkinRunning
                    or SkinSuppressMeleeWatch then

                    return
                end

                if SkinAutoMelee
                    and SkinAppliedMelee
                    and SkinBaseMelee(SkinMeleeValue.Value)
                        ~= SkinAppliedMelee then

                    SkinSuppressMeleeWatch = true
                    SkinMeleeValue.Value = SkinAppliedMelee

                    task.defer(function()
                        SkinSuppressMeleeWatch = false
                    end)

                    local state = SkinGetState()

                    if state
                        and state.equipped == "melee"
                        and os.clock() - SkinLastForcedRebuild > 0.75 then

                        SkinLastForcedRebuild = os.clock()
                        SkinScheduleRebuild()
                    end
                end
            end
        )
    end

    --==================================================
    -- SKIN CLEANUP
    --==================================================

    SkinDestroy = function()
        if not SkinRunning then
            return
        end

        local state = SkinGetState()
        local hadChanges =
            SkinAppliedMelee ~= nil or SkinAppliedSkin ~= nil

        SkinRunning = false

        -- Stop auto-reapplication.
        SkinAutoMelee = false
        SkinAutoSkin = false

        -- Restore the initial melee value.
        if SkinMeleeValue and SkinOriginalMelee then
            pcall(function()
                SkinSuppressMeleeWatch = true
                SkinMeleeValue.Value = SkinOriginalMelee
            end)
        end

        -- Rebuild the game's own viewmodel so the restored melee and the
        -- player's legitimate skin are visible again. Deleting our textures
        -- alone would also delete the skin the game had applied.
        local rebuilt = false

        if hadChanges
            and state
            and state.equipped == "melee"
            and state.gun then

            local viewmodels = SkinGetViewmodels()

            if viewmodels
                and type(viewmodels.CreateViewmodel) == "function" then

                local camera = workspace.CurrentCamera

                if camera then
                    pcall(function()
                        local oldArms = camera:FindFirstChild("Arms")

                        if oldArms then
                            oldArms:Destroy()
                        end

                        local modelArg, equipSpeed = SkinViewmodelArgs()

                        viewmodels.CreateViewmodel(
                            modelArg or state.gun,
                            equipSpeed or 1.15
                        )
                    end)

                    rebuilt = camera:FindFirstChild("Arms") ~= nil
                end
            end
        end

        local arms = SkinGetArms()

        -- Outside a match, or if the rebuild failed, clean the current
        -- viewmodel and restore any material / colour changes.
        if hadChanges
            and arms
            and not rebuilt
            and SkinHasOurChanges(arms) then

            pcall(function()
                SkinRemoveTextures(arms)
                arms:SetAttribute("ArsenalSkin", nil)
                arms:SetAttribute("ArsenalSkinCount", nil)
                arms:SetAttribute("ArsenalMelee", nil)
            end)
        end

        SkinAppliedMelee = nil
        SkinAppliedSkin = nil
    end

    -- Scriptable skin access, also used for live verification of the melee
    -- path. Nothing in the UI depends on it.
    _G.CARBON_SKINS = {
        ApplyMelee = SkinApplyMelee,
        RestoreMelee = SkinRestoreMelee,
        RebuildViewmodel = SkinRebuildViewmodel,
        ApplySkin = SkinApplySelected,
        Remove = SkinRemove,
    }
end

--==================================================
-- LOCAL TAB
--==================================================

do
    local WorldBox = Tabs.Local:AddLeftGroupbox({
        Name = "World",
        Icon = "sun",
    })

    local MovementBox = Tabs.Local:AddRightGroupbox({
        Name = "Movement",
        Icon = "move",
    })

    local UtilityBox = Tabs.Local:AddLeftGroupbox({
        Name = "Utility",
        Icon = "wrench",
    })

    WorldBox:Toggle({
        Name = "Fullbright",
        Desc = "Lift ambient light and remove fog",
        Default = Config.Fullbright,
        Flag = "Fullbright",
        Callback = SetFullbright,
    })

    WorldBox:Toggle({
        Name = "Camera FOV",
        Default = Config.LocalFov,
        Flag = "LocalFov",
        Callback = function(v)
            Config.LocalFov = v

            local camera = workspace.CurrentCamera

            if v and camera then
                LocalBackup.Fov = camera.FieldOfView
                camera.FieldOfView = Config.LocalFovValue
            elseif LocalBackup.Fov and camera then
                camera.FieldOfView = LocalBackup.Fov
                LocalBackup.Fov = nil
            end
        end,
    })

    WorldBox:Slider({
        Name = "FOV Value",
        Min = 60,
        Max = 120,
        Step = 1,
        Default = Config.LocalFovValue,
        Flag = "LocalFovValue",
        Callback = function(v)
            Config.LocalFovValue = v

            local camera = workspace.CurrentCamera

            if Config.LocalFov and camera then
                camera.FieldOfView = v
            end
        end,
    })

    WorldBox:Divider()

    WorldBox:Toggle({
        Name = "Time of Day",
        Default = Config.TimeOfDayEnabled,
        Flag = "TimeOfDayEnabled",
        Callback = Extra.SetTimeOfDay,
    })

    WorldBox:Slider({
        Name = "Clock Time",
        Min = 0,
        Max = 24,
        Step = 0.5,
        Default = Config.TimeOfDayValue,
        Flag = "TimeOfDayValue",
        Callback = function(v)
            Config.TimeOfDayValue = v

            if Config.TimeOfDayEnabled then
                Lighting.ClockTime = v
            end
        end,
    })

    WorldBox:Toggle({
        Name = "Remove Fog",
        Desc = "Clear distance fog without changing lighting",
        Default = Config.RemoveFog,
        Flag = "RemoveFog",
        Callback = Extra.SetRemoveFog,
    })

    WorldBox:Divider()

    WorldBox:Toggle({
        Name = "World Tint",
        Desc = "Colour grade the whole scene",
        Default = Config.WorldTint,
        Flag = "WorldTint",
        Callback = function(v)
            Config.WorldTint = v
            Extra.ApplyEnvironment()
        end,
    })

    WorldBox:ColorPicker({
        Name = "Tint Colour",
        Default = Config.WorldTintColor,
        Flag = "WorldTintColor",
        Callback = function(v)
            Config.WorldTintColor = v
            Extra.ApplyEnvironment()
        end,
    })

    WorldBox:Slider({
        Name = "Tint Brightness",
        Min = -1,
        Max = 1,
        Step = 0.05,
        Default = Config.WorldTintBrightness,
        Flag = "WorldTintBrightness",
        Callback = function(v)
            Config.WorldTintBrightness = v
            Extra.ApplyEnvironment()
        end,
    })

    WorldBox:Slider({
        Name = "Tint Contrast",
        Min = -1,
        Max = 1,
        Step = 0.05,
        Default = Config.WorldTintContrast,
        Flag = "WorldTintContrast",
        Callback = function(v)
            Config.WorldTintContrast = v
            Extra.ApplyEnvironment()
        end,
    })

    WorldBox:Toggle({
        Name = "Remove Skybox",
        Default = Config.NoSkybox,
        Flag = "NoSkybox",
        Callback = function(v)
            Config.NoSkybox = v
            Extra.ApplyEnvironment()
        end,
    })

    MovementBox:Toggle({
        Name = "Walk Speed",
        Default = Config.WalkSpeedEnabled,
        Flag = "WalkSpeedEnabled",
        Callback = function(v)
            Config.WalkSpeedEnabled = v

            local humanoid = CurrentHumanoid()

            if v and humanoid then
                LocalBackup.WalkSpeed = humanoid.WalkSpeed
                humanoid.WalkSpeed = Config.WalkSpeedValue
            elseif humanoid and LocalBackup.WalkSpeed then
                humanoid.WalkSpeed = LocalBackup.WalkSpeed
                LocalBackup.WalkSpeed = nil
            end
        end,
    })

    MovementBox:Slider({
        Name = "Speed Value",
        Min = 16,
        Max = 120,
        Step = 1,
        Default = Config.WalkSpeedValue,
        Flag = "WalkSpeedValue",
        Callback = function(v)
            Config.WalkSpeedValue = v

            local humanoid = CurrentHumanoid()

            if Config.WalkSpeedEnabled and humanoid then
                humanoid.WalkSpeed = v
            end
        end,
    })

    MovementBox:Toggle({
        Name = "Jump Power",
        Default = Config.JumpEnabled,
        Flag = "JumpEnabled",
        Callback = function(v)
            Config.JumpEnabled = v

            local humanoid = CurrentHumanoid()

            if v and humanoid then
                -- Arsenal leaves UseJumpPower off and uses JumpHeight. Back up
                -- all three values so disabling puts the humanoid back exactly
                -- as the game had it instead of leaving the higher JumpPower
                -- path (and its derived JumpHeight) active.
                LocalBackup.JumpPower = humanoid.JumpPower
                LocalBackup.JumpHeight = humanoid.JumpHeight
                LocalBackup.UseJumpPower = humanoid.UseJumpPower

                humanoid.UseJumpPower = true
                humanoid.JumpPower = Config.JumpValue
            elseif humanoid and LocalBackup.JumpPower ~= nil then
                humanoid.JumpPower = LocalBackup.JumpPower

                if LocalBackup.JumpHeight ~= nil then
                    humanoid.JumpHeight = LocalBackup.JumpHeight
                end

                if LocalBackup.UseJumpPower ~= nil then
                    humanoid.UseJumpPower = LocalBackup.UseJumpPower
                end

                LocalBackup.JumpPower = nil
                LocalBackup.JumpHeight = nil
                LocalBackup.UseJumpPower = nil
            end
        end,
    })

    MovementBox:Slider({
        Name = "Jump Value",
        Min = 50,
        Max = 250,
        Step = 5,
        Default = Config.JumpValue,
        Flag = "JumpValue",
        Callback = function(v)
            Config.JumpValue = v

            local humanoid = CurrentHumanoid()

            if Config.JumpEnabled and humanoid then
                humanoid.UseJumpPower = true
                humanoid.JumpPower = v
            end
        end,
    })

    MovementBox:Toggle({
        Name = "Infinite Jump",
        Desc = "Jump again while airborne",
        Default = Config.InfiniteJump,
        Flag = "InfiniteJump",
        Callback = function(v)
            Config.InfiniteJump = v
        end,
    })

    MovementBox:Toggle({
        Name = "No Clip",
        Desc = "Disable collision on your character",
        Default = Config.NoClip,
        Flag = "NoClip",
        Callback = function(v)
            Config.NoClip = v

            if not v then
                local character = LocalPlayer.Character

                if character then
                    for _, part in ipairs(character:GetDescendants()) do
                        if IsLimb(part, character)
                            and part.Name ~= "HumanoidRootPart" then

                            pcall(function()
                                part.CanCollide = true
                            end)
                        end
                    end
                end
            end
        end,
    })

    MovementBox:Divider()

    MovementBox:Toggle({
        Name = "Fly",
        Desc = "WASD to move, Space up, Left Ctrl down",
        Default = Config.FlyEnabled,
        Flag = "FlyEnabled",
        Callback = Extra.SetFly,
    })

    MovementBox:Slider({
        Name = "Fly Speed",
        Min = 10,
        Max = 250,
        Step = 5,
        Default = Config.FlySpeed,
        Flag = "FlySpeed",
        Callback = function(v)
            Config.FlySpeed = v
        end,
    })

    MovementBox:Toggle({
        Name = "Spin",
        Default = Config.SpinEnabled,
        Flag = "SpinEnabled",
        Callback = function(v)
            Config.SpinEnabled = v

            if not v then
                local humanoid = CurrentHumanoid()

                if humanoid then
                    humanoid.AutoRotate = true
                end
            end
        end,
    })

    MovementBox:Slider({
        Name = "Spin Speed",
        Min = 30,
        Max = 1440,
        Step = 30,
        Default = Config.SpinSpeed,
        Flag = "SpinSpeed",
        Callback = function(v)
            Config.SpinSpeed = v
        end,
    })

    MovementBox:Toggle({
        Name = "Hip Height",
        Desc = "Float the character above the ground",
        Default = Config.HipHeightEnabled,
        Flag = "HipHeightEnabled",
        Callback = Extra.SetHipHeight,
    })

    MovementBox:Slider({
        Name = "Hip Height Value",
        Min = 0,
        Max = 20,
        Step = 0.5,
        Default = Config.HipHeightValue,
        Flag = "HipHeightValue",
        Callback = function(v)
            Config.HipHeightValue = v

            local humanoid = CurrentHumanoid()

            if Config.HipHeightEnabled and humanoid then
                humanoid.HipHeight = v
            end
        end,
    })

    UtilityBox:Toggle({
        Name = "Anti-AFK",
        Desc = "Prevents the 20 minute idle kick",
        Default = Config.AntiAFK,
        Flag = "AntiAFK",
        Callback = function(v)
            Config.AntiAFK = v
        end,
    })

    UtilityBox:Toggle({
        Name = "Click Teleport",
        Desc = "Click any surface to teleport there",
        Default = Config.ClickTP,
        Flag = "ClickTP",
        Callback = function(v)
            Config.ClickTP = v
        end,
    })

    UtilityBox:Slider({
        Name = "Teleport Range",
        Min = 50,
        Max = 2000,
        Step = 25,
        Default = Config.ClickTPDistance,
        Flag = "ClickTPDistance",
        Callback = function(v)
            Config.ClickTPDistance = v
        end,
    })

    UtilityBox:Divider()

    UtilityBox:Button({
        Name = "Reset Character",
        Icon = "rotate-ccw",
        Callback = Extra.ResetCharacter,
    })

    UtilityBox:Button({
        Name = "Copy Job ID",
        Icon = "copy",
        Callback = function()
            Extra.CopyText(game.JobId)
        end,
    })

    UtilityBox:Button({
        Name = "Server Hop",
        Icon = "shuffle",
        Style = "Danger",
        Callback = Extra.ServerHop,
    })

    UtilityBox:Divider()

    UtilityBox:Button({
        Name = "Rejoin Server",
        Icon = "rotate-ccw",
        Style = "Danger",
        Callback = function()
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end,
    })

    UtilityBox:Paragraph({
        Name = "Note",
        Content = "* Local changes are client-side only and are restored when you unload or respawn.",
    })
end

--==================================================
-- PLAYERS TAB
--==================================================

do
    local PlayersBox = Tabs.Players:AddLeftGroupbox({
        Name = "Player List",
        Icon = "user",
    })

    local ActionsBox = Tabs.Players:AddRightGroupbox({
        Name = "Actions",
        Icon = "crosshair",
    })

    local selectedName = nil

    local function PlayerOptions()
        local options = { "None" }

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(options, player.Name)
            end
        end

        table.sort(options, function(a, b)
            if a == "None" then
                return true
            end

            if b == "None" then
                return false
            end

            return a < b
        end)

        return options
    end

    local function SelectedPlayer()
        if not selectedName or selectedName == "None" then
            return nil
        end

        return Players:FindFirstChild(selectedName)
    end

    local PlayerDropdown = PlayersBox:Dropdown({
        Name = "Player",
        Options = PlayerOptions(),
        Default = "None",
        Flag = "SelectedPlayer",
        Callback = function(value)
            selectedName = value
        end,
    })

    local function RefreshPlayerList()
        PlayerDropdown:Refresh(PlayerOptions(), true, true)

        if selectedName and selectedName ~= "None"
            and not Players:FindFirstChild(selectedName) then

            selectedName = "None"
            PlayerDropdown:Set("None", true)
        end
    end

    PlayersBox:Button({
        Name = "Refresh List",
        Icon = "rotate-ccw",
        Callback = RefreshPlayerList,
    })

    PlayersBox:Paragraph({
        Name = "Tip",
        Content = "* The list refreshes automatically when players join or leave. Pick a name, then use the actions on the right.",
    })

    ActionsBox:Button({
        Name = "Teleport To Player",
        Icon = "move",
        Callback = function()
            local player = SelectedPlayer()

            if player then
                Extra.TeleportToPlayer(player)
            else
                Notify("No player", "Select a player first.")
            end
        end,
    })

    ActionsBox:Button({
        Name = "Spectate Player",
        Icon = "eye",
        Callback = function()
            local player = SelectedPlayer()

            if player then
                Extra.SpectatePlayer(player)
            else
                Notify("No player", "Select a player first.")
            end
        end,
    })

    ActionsBox:Button({
        Name = "Copy Name",
        Icon = "copy",
        Callback = function()
            local player = SelectedPlayer()

            if player then
                Extra.CopyText(player.Name)
            else
                Notify("No player", "Select a player first.")
            end
        end,
    })

    ActionsBox:Divider()

    ActionsBox:Button({
        Name = "Reset Camera",
        Icon = "rotate-ccw",
        Callback = Extra.ResetCamera,
    })

    Connect(Players.PlayerAdded, function()
        task.defer(RefreshPlayerList)
    end)

    Connect(Players.PlayerRemoving, function()
        task.defer(RefreshPlayerList)
    end)
end

--==================================================
-- CUSTOMIZE TAB
--==================================================

do
    local OverlayBox = Tabs.Customize:AddLeftGroupbox({
        Name = "Overlay Colors",
        Icon = "palette",
    })

    local AccentBox = Tabs.Customize:AddRightGroupbox({
        Name = "Accent",
        Icon = "sliders-horizontal",
    })

    OverlayBox:ColorPicker({
        Name = "ESP Color",
        Default = Config.ESPColor,
        Flag = "ESPColor",
        Callback = function(v)
            Config.ESPColor = v
        end,
    })

    OverlayBox:ColorPicker({
        Name = "FOV Color",
        Default = Config.FOVColor,
        Flag = "FOVColor",
        Callback = function(v)
            Config.FOVColor = v
        end,
    })

    OverlayBox:ColorPicker({
        Name = "Target Indicator Color",
        Default = Config.TargetColor,
        Flag = "TargetColor",
        Callback = function(v)
            Config.TargetColor = v
            TargetLabel.TextColor3 = v
        end,
    })

    AccentBox:ColorPicker({
        Name = "Accent Color",
        Default = Config.Accent,
        Flag = "Accent",
        Callback = function(v)
            Config.Accent = v
            KeybindStroke.Color = v
        end,
    })

    AccentBox:Divider()

    AccentBox:Paragraph({
        Name = "Note",
        Content = "* Accent tints the aimlock keybind display.",
    })
end

--==================================================
-- SETTINGS TAB
--==================================================

do
    local SystemBox = Tabs.Settings:AddRightGroupbox({
        Name = "System",
        Icon = "power",
    })

    SystemBox:Toggle({
        Name = "Notifications",
        Default = Config.Notifications,
        Flag = "Notifications",
        Callback = function(v)
            Config.Notifications = v
        end,
    })

    SystemBox:Toggle({
        Name = "Performance Mode",
        Default = Config.PerformanceMode,
        Flag = "PerformanceMode",
        Callback = function(v)
            Config.PerformanceMode = v
        end,
    })

    SystemBox:Divider()

    SystemBox:Button({
        Name = "Unload CARBON",
        Icon = "power",
        Style = "Danger",

        Callback = function()
            if _G.CARBON_CLEANUP then
                _G.CARBON_CLEANUP()
            end
        end,
    })

    Tabs.Settings:InterfaceManager({
        Name = "Interface",
        Side = "Left",
        Icon = "tv-minimal",
    })

    Tabs.Settings:ConfigManager({
        Name = "Configs",
        Side = "Left",
        Icon = "folder",
    })

    Tabs.Settings:ThemeManager({
        Name = "Themes",
        Side = "Right",
        Icon = "palette",
    })

    Window:LoadAutoload()

    -- Autoload can restore an armed aimlock from a previous session. Never
    -- start locked: the user has to enable it every time the script runs.
    local aimFlag = Aster.Flags and Aster.Flags.AimEnabled

    if aimFlag and aimFlag.Set and aimFlag.Value == true then
        aimFlag:Set(false)
    end

    Config.AimEnabled = false
    AimHeld = false
    AimToggled = false
    Target = nil
end

--==================================================
-- RENDER LOOP
--==================================================

-- Arsenal's viewmodel loop rewrites CurrentCamera.FieldOfView from a
-- RunService.RenderStepped handler every frame. RenderStepped handlers run
-- after BindToRenderStep, so binding the FOV override there (even at Last) was
-- always overwritten in the same frame. Running it from our own RenderStepped
-- connection, registered after Arsenal's, puts the value back last.
local function ApplyCameraFov()
    if not Config.LocalFov then
        return
    end

    local camera = workspace.CurrentCamera

    if camera and camera.FieldOfView ~= Config.LocalFovValue then
        camera.FieldOfView = Config.LocalFovValue
    end
end

local frameCount = 0
local localElapsed = 0
local chamsElapsed = 0

Connect(RunService.RenderStepped, function(deltaTime)
    if Destroyed then
        return
    end

    Camera = workspace.CurrentCamera

    if not Camera then
        return
    end

    local mouse = UIS:GetMouseLocation()

    FOVCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
    FOVCircle.Size = UDim2.fromOffset(
        Config.AimFOV * 2,
        Config.AimFOV * 2
    )

    FOVCircle.Visible = Config.ShowFOV
    FOVStroke.Color = Config.FOVColor

    frameCount += 1

    local interval = Config.PerformanceMode and 3 or 1

    if frameCount >= interval then
        frameCount = 0
        UpdateESP()
        UpdateRadar()
    end

    Extra.UpdateFly()
    Extra.UpdateSpin(deltaTime)

    if Config.RainbowGunEnabled then
        UpdateRainbow(deltaTime)
    end

    chamsElapsed += deltaTime

    if chamsElapsed >= 0.15 then
        chamsElapsed = 0
        ReconcileChams()
    end

    if Config.ChamsEnabled and Config.ChamsMode ~= "Highlight" then
        SyncChams()
    end

    localElapsed += deltaTime

    if localElapsed >= 0.25 then
        localElapsed = 0
        ApplyLocal()
    end

    -- Last write of the frame: Arsenal already restored its own FOV above.
    ApplyCameraFov()
end)

-- Aim runs after the camera update so Arsenal's scriptable camera cannot
-- overwrite the lock in the same frame.
RunService:BindToRenderStep(
    "CARBON_AimStep",
    Enum.RenderPriority.Camera.Value + 10,
    UpdateAim
)

--==================================================
-- CLEANUP FUNCTION
--==================================================

local function Cleanup()
    if Destroyed then
        return
    end

    Destroyed = true

    AimHeld = false
    AimToggled = false
    ListeningForAimKey = false
    Target = nil

    -- Stop the integrated skin system first.
    if SkinDestroy then
        pcall(SkinDestroy)
    end

    pcall(function()
        RunService:UnbindFromRenderStep("CARBON_AimStep")
    end)

    pcall(function()
        RunService:UnbindFromRenderStep("CARBON_LocalCamera")
    end)

    pcall(RestoreViewmodel)
    pcall(RestoreLocal)
    pcall(ClearChams)

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(Connections)

    local playersToRemove = {}

    for player in pairs(ESPObjects) do
        table.insert(playersToRemove, player)
    end

    for _, player in ipairs(playersToRemove) do
        RemoveESP(player)
    end

    pcall(function()
        ChamsBodies:Destroy()
    end)

    pcall(function()
        ScreenGui:Destroy()
    end)

    pcall(function()
        Window:Destroy()
    end)

    _G.CARBON_CLEANUP = nil
    _G.CARBON_WINDOW = nil
    _G.CARBON_GUI = nil
    _G.CARBON_CONFIG = nil
    _G.CARBON_ASTER = nil
    _G.CARBON_DEBUG = nil
    _G.CARBON_SKINS = nil
end

_G.CARBON_CLEANUP = Cleanup

if type(_G.CARBON_CLEANUPS) == "table" then
    table.insert(_G.CARBON_CLEANUPS, Cleanup)
end

--==================================================
-- INITIALIZE
--==================================================

UpdateCrosshair()
UpdateKeybindDisplay()

Notify(
    "CARBON 3.3.0",
    "Aim, ESP, radar, chams, world and player tools initialized."
)

print("[CARBON] 3.3.0 ASTER + SKIN SYSTEM initialized.")
