
--[[
    NEXUS v3.1.6
    Complete interface redesign with the v3.1.4 systems preserved

    Includes:
    - Automatic NEXUS folder creation
    - Save configuration
    - Load configuration
    - JSON validation
    - Safe defaults for missing or invalid settings
    - Restore Enum keybinds and Color3 values
    - Apply loaded settings immediately
    - Auto-save on changes
    - Auto-load on startup
    - Five-tab premium UI with compact sidebar mode
    - Aim, ESP, Visuals, Settings, Customize
    - Expanded aim priority and frame-rate independent response curves
]]

if _G.NEXUS_Cleanup then
    pcall(_G.NEXUS_Cleanup)
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local CONFIG_FOLDER = "NEXUS"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"

local Defaults = {
    AimEnabled = false,
    AimKey = "Q",
    MenuKey = "RightShift",
    AimPart = "Head",
    AimMode = "Closest to Crosshair",
    AimResponse = "Exponential",
    FOV = 180,
    AimDistance = 500,
    Smoothness = 12,
    Prediction = 0,
    AimActivation = "Hold",
    StickyTarget = true,
    AimOffsetX = 0,
    AimOffsetY = 0,
    Deadzone = 0,
    TeamCheck = false,
    VisibilityCheck = false,
    ShowFOV = true,

    ESPEnabled = false,
    Names = true,
    Boxes = true,
    HealthBars = true,
    DistanceLabels = true,
    Tracers = false,
    ESPTeamCheck = false,

    ChamsEnabled = false,
    ChamsTransparency = 0.35,
    SkeletonsEnabled = false,
    SkeletonThickness = 2,
    HeadDots = false,
    TargetHighlight = true,

    CrosshairEnabled = false,
    CrosshairSize = 8,

    UIVisible = true,
    UIScale = 1,
    UITransparency = 0,
    Notifications = true,
    PerformanceMode = false,
    CompactSidebar = true,

    Accent = {190, 245, 90},
    FOVColor = {190, 245, 90},
    ESPColor = {190, 245, 90},
    ChamsColor = {190, 245, 90},
    SkeletonColor = {255, 255, 255},
    CrosshairColor = {255, 255, 255},
}

local Config = {}

for key, value in pairs(Defaults) do
    if type(value) == "table" then
        Config[key] = table.clone(value)
    else
        Config[key] = value
    end
end

-- Convert default key names to Enum.KeyCode values immediately.
Config.AimKey = Enum.KeyCode[Config.AimKey] or Enum.KeyCode.Q
Config.MenuKey = Enum.KeyCode[Config.MenuKey] or Enum.KeyCode.RightShift

local Connections = {}
local ESPObjects = {}
local Highlights = {}
local SkeletonObjects = {}
local LockedTarget
local AimToggleActive = false
local AimStatusLabel
local CaptureKey
local MenuOpen = true
local Destroyed = false
local SaveQueued = false
local AppearanceDirty = true

local function Track(connection)
    table.insert(Connections, connection)
    return connection
end

local function Notify(message)
    if not Config.Notifications then return end

    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NEXUS v3.1.6",
            Text = tostring(message),
            Duration = 3
        })
    end)
end

-- CONFIGURATION SYSTEM

local function FileFunctionsAvailable()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function PrepareFolder()
    if type(makefolder) ~= "function" then
        return true
    end

    if type(isfolder) == "function" then
        local ok, exists = pcall(isfolder, CONFIG_FOLDER)
        if ok and exists then
            return true
        end
    end

    local ok = pcall(makefolder, CONFIG_FOLDER)
    return ok
end

local function SerializeConfig()
    local output = {}

    for key, value in pairs(Config) do
        if key == "AimKey" or key == "MenuKey" then
            output[key] = value.Name
        elseif typeof(value) == "Color3" then
            output[key] = {
                math.floor(value.R * 255),
                math.floor(value.G * 255),
                math.floor(value.B * 255)
            }
        else
            output[key] = value
        end
    end

    return output
end

local function SaveConfig(silent)
    if not FileFunctionsAvailable() then
        if not silent then
            Notify("Executor does not support file saving")
        end
        return false
    end

    PrepareFolder()

    local success, result = pcall(function()
        local json = HttpService:JSONEncode(SerializeConfig())
        writefile(CONFIG_FILE, json)
        return true
    end)

    if success and result then
        if not silent then Notify("Configuration saved!") end
        return true
    end

    if not silent then
        Notify("Could not save configuration")
    end

    return false
end

local function ValidNumber(value, minValue, maxValue)
    return type(value) == "number"
        and value == value
        and value >= minValue
        and value <= maxValue
end

local function LoadConfig(silent)
    if not FileFunctionsAvailable() then
        if not silent then
            Notify("Executor does not support file loading")
        end
        return false
    end

    local exists, fileExists = pcall(isfile, CONFIG_FILE)

    if not exists or not fileExists then
        if not silent then
            Notify("No saved configuration found")
        end
        return false
    end

    local readSuccess, raw = pcall(readfile, CONFIG_FILE)

    if not readSuccess or type(raw) ~= "string" then
        if not silent then Notify("Could not read configuration") end
        return false
    end

    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not decodeSuccess or type(data) ~= "table" then
        if not silent then Notify("Invalid configuration file") end
        return false
    end

    local booleanKeys = {
        "AimEnabled", "StickyTarget", "TeamCheck", "VisibilityCheck", "ShowFOV",
        "ESPEnabled", "Names", "Boxes", "HealthBars",
        "DistanceLabels", "Tracers", "ESPTeamCheck",
        "ChamsEnabled", "SkeletonsEnabled", "HeadDots",
        "TargetHighlight", "CrosshairEnabled", "UIVisible",
        "Notifications", "PerformanceMode", "CompactSidebar"
    }

    for _, key in ipairs(booleanKeys) do
        if type(data[key]) == "boolean" then
            Config[key] = data[key]
        end
    end

    local numberRanges = {
        FOV = {30, 600},
        AimDistance = {50, 2000},
        Smoothness = {1, 30},
        Prediction = {0, 0.3},
        AimOffsetX = {-3, 3},
        AimOffsetY = {-3, 3},
        Deadzone = {0, 60},
        ChamsTransparency = {0, 1},
        SkeletonThickness = {1, 5},
        CrosshairSize = {3, 20},
        UIScale = {0.7, 1.3},
        UITransparency = {0, 0.8}
    }

    for key, range in pairs(numberRanges) do
        if ValidNumber(data[key], range[1], range[2]) then
            Config[key] = data[key]
        end
    end

    local stringOptions = {
        AimPart = {"Head", "Neck", "Torso", "Pelvis", "Root"},
        AimMode = {"Closest to Crosshair", "Closest to Character", "Lowest Health"},
        AimResponse = {"Linear", "Ease Out", "Ease In-Out", "Exponential"},
        AimActivation = {"Hold", "Toggle"}
    }

    for key, options in pairs(stringOptions) do
        if type(data[key]) == "string" and table.find(options, data[key]) then
            Config[key] = data[key]
        end
    end

    for _, key in ipairs({"AimKey", "MenuKey"}) do
        if type(data[key]) == "string" and Enum.KeyCode[data[key]] then
            Config[key] = Enum.KeyCode[data[key]]
        end
    end

    local colorKeys = {
        "Accent", "FOVColor", "ESPColor",
        "ChamsColor", "SkeletonColor", "CrosshairColor"
    }

    for _, key in ipairs(colorKeys) do
        local value = data[key]

        if type(value) == "table"
            and ValidNumber(value[1], 0, 255)
            and ValidNumber(value[2], 0, 255)
            and ValidNumber(value[3], 0, 255) then

            Config[key] = Color3.fromRGB(
                value[1], value[2], value[3]
            )
        end
    end

    LockedTarget = nil
    AimToggleActive = false

    if not silent then
        Notify("Configuration loaded successfully!")
    end

    return true
end

local function ScheduleSave()
    AppearanceDirty = true
    if SaveQueued then return end
    SaveQueued = true

    task.delay(1, function()
        SaveQueued = false
        if not Destroyed then
            SaveConfig(true)
        end
    end)
end

-- COLOR HELPERS

local function GetColor(value)
    if typeof(value) == "Color3" then return value end

    if type(value) == "table" then
        return Color3.fromRGB(
            value[1] or 135,
            value[2] or 90,
            value[3] or 255
        )
    end

    return Color3.fromRGB(135, 90, 255)
end

local function ApplyColors()
    Config.Accent = GetColor(Config.Accent)
    Config.FOVColor = GetColor(Config.FOVColor)
    Config.ESPColor = GetColor(Config.ESPColor)
    Config.ChamsColor = GetColor(Config.ChamsColor)
    Config.SkeletonColor = GetColor(Config.SkeletonColor)
    Config.CrosshairColor = GetColor(Config.CrosshairColor)
end

-- LOAD SAVED SETTINGS BEFORE BUILDING THE UI

LoadConfig(true)
ApplyColors()

-- PLAYER HELPERS

local function GetCharacter(player)
    return player and player.Character
end

local function GetRoot(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid(player)
    local character = GetCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(player)
    local humanoid = GetHumanoid(player)
    return humanoid and humanoid.Health > 0
end

local function GetDistance(player)
    local a = GetRoot(LocalPlayer)
    local b = GetRoot(player)

    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

local function IsEnemy(player, teamCheck)
    if player == LocalPlayer then return false end

    if teamCheck and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end

    return true
end

local function GetAimPart(player)
    local character = GetCharacter(player)
    if not character then return nil end

    if Config.AimPart == "Neck" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
    elseif Config.AimPart == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    elseif Config.AimPart == "Pelvis" then
        return character:FindFirstChild("LowerTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    elseif Config.AimPart == "Root" then
        return character:FindFirstChild("HumanoidRootPart")
    end

    return character:FindFirstChild("Head")
        or character:FindFirstChild("HumanoidRootPart")
end

-- Return a useful aim point for named body regions. Neck and pelvis use
-- rig attachments when available, with safe offsets for rigs without them.
local function GetAimPosition(player, part)
    if not part then return nil end

    if Config.AimPart == "Neck" then
        local attachment = part:FindFirstChild("NeckRigAttachment")
            or part:FindFirstChild("NeckAttachment")
        if attachment and attachment:IsA("Attachment") then
            return attachment.WorldPosition
        end
        return part.Position + Vector3.new(0, part.Size.Y * 0.42, 0)
    elseif Config.AimPart == "Pelvis" then
        local attachment = part:FindFirstChild("WaistRigAttachment")
            or part:FindFirstChild("RootRigAttachment")
        if attachment and attachment:IsA("Attachment") then
            return attachment.WorldPosition
        end
        return part.Position - Vector3.new(0, part.Size.Y * 0.25, 0)
    end

    return part.Position
end

-- Visibility uses several points on the selected aim part so small gaps,
-- attachments, or an awkward aim-point position do not cause false negatives.
-- Highly transparent queryable effects are skipped; solid map geometry and
-- other characters continue to block the line of sight.
local function IsVisible(part, character, targetPosition)
    if not Config.VisibilityCheck then return true end
    if not part or not part:IsA("BasePart") then return false end
    if not character or not character.Parent then return false end

    local camera = workspace.CurrentCamera or Camera
    if not camera then return false end

    local origin = camera.CFrame.Position
    local primaryPoint = targetPosition or part.Position
    if typeof(primaryPoint) ~= "Vector3" then return false end

    local points = { primaryPoint }

    -- Test the part center and a few inset points around it. Inset offsets
    -- help avoid aiming exactly at an edge where a neighboring limb can mask it.
    if (part.Position - primaryPoint).Magnitude > 0.05 then
        table.insert(points, part.Position)
    end

    local cf = part.CFrame
    local insetX = math.max(0, part.Size.X * 0.28)
    local insetY = math.max(0, part.Size.Y * 0.28)
    local insetZ = math.max(0, part.Size.Z * 0.28)
    table.insert(points, part.Position + cf.RightVector * insetX)
    table.insert(points, part.Position - cf.RightVector * insetX)
    table.insert(points, part.Position + cf.UpVector * insetY)
    table.insert(points, part.Position - cf.UpVector * insetY)
    table.insert(points, part.Position + cf.LookVector * insetZ)
    table.insert(points, part.Position - cf.LookVector * insetZ)

    local ignored = {}
    if LocalPlayer.Character then
        table.insert(ignored, LocalPlayer.Character)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    params.RespectCanCollide = false

    for _, point in ipairs(points) do
        local direction = point - origin
        if direction.Magnitude > 0.01 then
            -- Recast past highly transparent effects instead of treating them
            -- as walls. The iteration cap prevents pathological raycast loops.
            local castIgnored = table.clone(ignored)
            for _ = 1, 12 do
                params.FilterDescendantsInstances = castIgnored
                local result = workspace:Raycast(origin, direction, params)

                if not result then
                    -- No queryable obstruction exists along this sample ray.
                    return true
                end

                local hit = result.Instance
                if hit and hit:IsDescendantOf(character) then
                    return true
                end

                if hit and hit:IsA("BasePart") and hit.Transparency >= 0.65 then
                    table.insert(castIgnored, hit)
                else
                    -- A solid object or another character is blocking this ray.
                    break
                end
            end
        end
    end

    return false
end

local function GetTarget()
    local best
    local bestScore = math.huge
    local mouse = UIS:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if IsEnemy(player, Config.TeamCheck) and IsAlive(player) then
            local part = GetAimPart(player)
            local character = GetCharacter(player)
            local distance = GetDistance(player)

            local aimPosition = GetAimPosition(player, part)

            if part and aimPosition and distance <= Config.AimDistance
                and IsVisible(part, character, aimPosition) then

                local point, onScreen =
                    Camera:WorldToViewportPoint(aimPosition)

                if onScreen then
                    local screenDistance = (
                        Vector2.new(point.X, point.Y) - mouse
                    ).Magnitude

                    if screenDistance <= Config.FOV then
                        local humanoid = GetHumanoid(player)
                        local score

                        if Config.AimMode == "Closest to Character" then
                            score = distance
                        elseif Config.AimMode == "Lowest Health" then
                            score = humanoid and humanoid.Health or math.huge
                        else
                            score = screenDistance
                        end

                        if score < bestScore then
                            best = player
                            bestScore = score
                        end
                    end
                end
            end
        end
    end

    return best
end

-- UI | NEXUS v3.1.6 — COMPLETE COMMAND-CENTER REDESIGN
-- The existing aim, ESP, visuals, configuration and update systems remain below.

local TweenService = game:GetService("TweenService")

local Palette = {
    -- CARBON//SIGNAL: graphite, smoked metal and high-visibility lime.
    Background = Color3.fromRGB(9, 11, 10),
    Panel = Color3.fromRGB(15, 18, 16),
    PanelRaised = Color3.fromRGB(22, 27, 23),
    Card = Color3.fromRGB(19, 24, 20),
    CardHover = Color3.fromRGB(29, 37, 29),
    Chip = Color3.fromRGB(34, 43, 33),
    Border = Color3.fromRGB(55, 67, 52),
    Text = Color3.fromRGB(240, 244, 235),
    Muted = Color3.fromRGB(151, 161, 145),
    Soft = Color3.fromRGB(103, 115, 98),
    Green = Color3.fromRGB(190, 245, 90),
    Red = Color3.fromRGB(245, 103, 91),
    ToggleOff = Color3.fromRGB(61, 70, 58),
}

local function Round(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = instance
    return corner
end

local function Stroke(instance, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Palette.Border
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
    return stroke
end

local function AddGradient(instance, firstColor, secondColor, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, firstColor),
        ColorSequenceKeypoint.new(1, secondColor),
    })
    gradient.Rotation = rotation or 0
    gradient.Parent = instance
    return gradient
end

local function Animate(instance, duration, properties)
    local ok, tween = pcall(function()
        return TweenService:Create(
            instance,
            TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            properties
        )
    end)
    if ok and tween then tween:Play() end
end

local function MakeLabel(parent, name, text, position, size, font, textSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Palette.Text
    label.Font = font or Enum.Font.Gotham
    label.TextSize = textSize or 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NEXUS_v316"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 50

pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)

if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Main = Instance.new("Frame")
Main.Name = "NEXUSCommandCenter"
Main.Size = UDim2.fromOffset(1040, 700)
Main.Position = UDim2.new(0.5, -520, 0.5, -350)
Main.BackgroundColor3 = Palette.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui
Round(Main, 12)
AddGradient(Main, Color3.fromRGB(16, 20, 16), Color3.fromRGB(8, 10, 9), 90)

local Scale = Instance.new("UIScale")
Scale.Scale = Config.UIScale
Scale.Parent = Main

local MainStroke = Stroke(Main, Config.Accent, 0.12, 1.15)
MainStroke:SetAttribute("NEXUSAccent", true)

-- TOP BAR
local Top = Instance.new("Frame")
Top.Name = "Topbar"
Top.Size = UDim2.new(1, 0, 0, 76)
Top.BackgroundColor3 = Palette.Panel
Top.BorderSizePixel = 0
Top.Parent = Main
AddGradient(Top, Color3.fromRGB(25, 31, 24), Color3.fromRGB(14, 18, 15), 0)

local BrandMark = Instance.new("Frame")
BrandMark.Name = "BrandMark"
BrandMark.Size = UDim2.fromOffset(40, 40)
BrandMark.Position = UDim2.fromOffset(20, 18)
BrandMark.BackgroundColor3 = Config.Accent
BrandMark.BorderSizePixel = 0
BrandMark.Parent = Top
BrandMark:SetAttribute("NEXUSAccent", true)
Round(BrandMark, 8)
local BrandGradient = AddGradient(BrandMark, Color3.fromRGB(255, 255, 255), Config.Accent, 45)

local BrandGlyph = MakeLabel(
    BrandMark, "BrandGlyph", "N",
    UDim2.fromScale(0, 0), UDim2.fromScale(1, 1),
    Enum.Font.Code, 18, Color3.new(0.06, 0.08, 0.05)
)
BrandGlyph.TextXAlignment = Enum.TextXAlignment.Center

local Title = MakeLabel(
    Top, "BrandTitle", "NEXUS  /  CARBON SIGNAL",
    UDim2.fromOffset(73, 10), UDim2.fromOffset(300, 28),
    Enum.Font.GothamBlack, 18, Palette.Text
)

local Subtitle = MakeLabel(
    Top, "BrandSubtitle", "TACTICAL INTERFACE     •     PERSONAL CONTROL LAYER",
    UDim2.fromOffset(74, 39), UDim2.fromOffset(390, 16),
    Enum.Font.Code, 9, Palette.Muted
)

local VersionChip = Instance.new("TextLabel")
VersionChip.Name = "VersionChip"
VersionChip.Size = UDim2.fromOffset(68, 24)
VersionChip.Position = UDim2.new(1, -246, 0, 24)
VersionChip.BackgroundColor3 = Palette.Chip
VersionChip.BorderSizePixel = 0
VersionChip.Text = "V3.1.6"
VersionChip.TextColor3 = Config.Accent
VersionChip.Font = Enum.Font.GothamBold
VersionChip.TextSize = 9
VersionChip.Parent = Top
VersionChip:SetAttribute("NEXUSAccentText", true)
Round(VersionChip, 8)

local Status = Instance.new("TextLabel")
Status.Name = "SystemStatus"
Status.Size = UDim2.fromOffset(124, 26)
Status.Position = UDim2.new(1, -176, 0, 25)
Status.BackgroundColor3 = Color3.fromRGB(20, 43, 39)
Status.BorderSizePixel = 0
Status.Text = "●  SYSTEM ONLINE"
Status.TextColor3 = Palette.Green
Status.Font = Enum.Font.GothamBold
Status.TextSize = 9
Status.Parent = Top
Round(Status, 8)

local Close = Instance.new("TextButton")
Close.Name = "CloseButton"
Close.Size = UDim2.fromOffset(30, 30)
Close.Position = UDim2.new(1, -46, 0, 23)
Close.BackgroundColor3 = Palette.Chip
Close.Text = "×"
Close.TextColor3 = Palette.Muted
Close.Font = Enum.Font.GothamMedium
Close.TextSize = 22
Close.AutoButtonColor = false
Close.Parent = Top
Round(Close, 9)
Close.MouseEnter:Connect(function()
    Animate(Close, 0.12, {BackgroundColor3 = Color3.fromRGB(105, 43, 57), TextColor3 = Palette.Text})
end)
Close.MouseLeave:Connect(function()
    Animate(Close, 0.12, {BackgroundColor3 = Palette.Chip, TextColor3 = Palette.Muted})
end)

local TopLine = Instance.new("Frame")
TopLine.Name = "TopbarDivider"
TopLine.Size = UDim2.new(1, -40, 0, 1)
TopLine.Position = UDim2.new(0, 20, 1, -1)
TopLine.BackgroundColor3 = Palette.Border
TopLine.BackgroundTransparency = 0.25
TopLine.BorderSizePixel = 0
TopLine.Parent = Top

-- LEFT NAVIGATION
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Position = UDim2.fromOffset(16, 94)
Sidebar.Size = UDim2.new(0, 74, 1, -110)
Sidebar.BackgroundColor3 = Palette.Panel
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main
Round(Sidebar, 10)
Stroke(Sidebar, Palette.Border, 0.58, 1)

local NavHeading = MakeLabel(
    Sidebar, "NavigationHeading", "WORKSPACE",
    UDim2.fromOffset(17, 13), UDim2.new(1, -34, 0, 18),
    Enum.Font.GothamBold, 9, Palette.Muted
)

local NavDivider = Instance.new("Frame")
NavDivider.Name = "NavigationDivider"
NavDivider.Position = UDim2.fromOffset(16, 40)
NavDivider.Size = UDim2.new(1, -32, 0, 1)
NavDivider.BackgroundColor3 = Palette.Border
NavDivider.BackgroundTransparency = 0.32
NavDivider.BorderSizePixel = 0
NavDivider.Parent = Sidebar

local NavFooter = Instance.new("Frame")
NavFooter.Name = "SessionFooter"
NavFooter.AnchorPoint = Vector2.new(0, 1)
NavFooter.Position = UDim2.new(0, 12, 1, -12)
NavFooter.Size = UDim2.new(1, -24, 0, 54)
NavFooter.BackgroundColor3 = Palette.PanelRaised
NavFooter.BorderSizePixel = 0
NavFooter.Parent = Sidebar
Round(NavFooter, 11)

local FooterDot = Instance.new("Frame")
FooterDot.Name = "FooterStatusDot"
FooterDot.Position = UDim2.fromOffset(12, 20)
FooterDot.Size = UDim2.fromOffset(7, 7)
FooterDot.BackgroundColor3 = Palette.Green
FooterDot.BorderSizePixel = 0
FooterDot.Parent = NavFooter
Round(FooterDot, 6)

local FooterTitle = MakeLabel(
    NavFooter, "FooterTitle", "LOCAL SESSION",
    UDim2.fromOffset(27, 8), UDim2.new(1, -38, 0, 16),
    Enum.Font.GothamBold, 8, Palette.Text
)
local FooterSub = MakeLabel(
    NavFooter, "FooterSubtitle", "READY  /  CLIENT",
    UDim2.fromOffset(27, 26), UDim2.new(1, -38, 0, 14),
    Enum.Font.Code, 8, Palette.Muted
)

-- MAIN CONTENT HEADER AND PAGE HOST
local ContentTop = Instance.new("Frame")
ContentTop.Name = "ContentHeader"
ContentTop.Position = UDim2.fromOffset(108, 94)
ContentTop.Size = UDim2.new(1, -128, 0, 30)
ContentTop.BackgroundTransparency = 1
ContentTop.Parent = Main

local CurrentPageLabel = MakeLabel(
    ContentTop, "CurrentPageLabel", "AIM CONTROL",
    UDim2.fromOffset(1, 0), UDim2.new(1, -150, 0, 19),
    Enum.Font.GothamBold, 11, Palette.Text
)

local CurrentPageMeta = Instance.new("TextLabel")
CurrentPageMeta.Name = "CurrentPageMeta"
CurrentPageMeta.Size = UDim2.fromOffset(142, 22)
CurrentPageMeta.Position = UDim2.new(1, -142, 0, 0)
CurrentPageMeta.BackgroundColor3 = Palette.PanelRaised
CurrentPageMeta.BorderSizePixel = 0
CurrentPageMeta.Text = "NEXUS  /  ACTIVE"
CurrentPageMeta.TextColor3 = Palette.Muted
CurrentPageMeta.Font = Enum.Font.GothamBold
CurrentPageMeta.TextSize = 8
CurrentPageMeta.Parent = ContentTop
Round(CurrentPageMeta, 7)

local Content = Instance.new("Frame")
Content.Name = "PageHost"
Content.Position = UDim2.fromOffset(108, 132)
Content.Size = UDim2.new(1, -128, 1, -150)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Pages = {}
local TabButtons = {}
local ActivePage = nil
local CurrentGrids = {}
local PageOrders = {}
local ControlRefreshers = {}

local PageInfo = {
    Aim = {"Aim Control", "TARGETING SYSTEM", "Tune target selection, input behaviour and response."},
    ESP = {"Player Overlay", "INFORMATION LAYER", "Choose what player information appears on your display."},
    Visuals = {"Visual Suite", "RENDER OPTIONS", "Manage character highlights and personal visual elements."},
    Settings = {"System Settings", "PREFERENCES", "Manage interface behaviour, performance and shortcuts."},
    Customize = {"Personalization", "WORKSPACE STYLE", "Adjust the NEXUS interface and manage your configuration."},
}

local function NextPageOrder(page)
    PageOrders[page] = (PageOrders[page] or 0) + 1
    return PageOrders[page]
end

local function CreatePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundColor3 = Palette.Panel
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Config.Accent
    page.ScrollBarImageTransparency = 0.15
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = false
    page.Parent = Content
    Round(page, 10)
    Stroke(page, Palette.Border, 0.38, 1)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 19)
    padding.PaddingBottom = UDim.new(0, 22)
    padding.PaddingLeft = UDim.new(0, 18)
    padding.PaddingRight = UDim.new(0, 18)
    padding.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local info = PageInfo[name]
    local kicker = MakeLabel(
        page, "PageKicker", info[2],
        UDim2.new(), UDim2.new(1, -4, 0, 15),
        Enum.Font.GothamBold, 8, Config.Accent
    )
    kicker:SetAttribute("NEXUSAccentText", true)
    kicker.LayoutOrder = NextPageOrder(page)

    local heading = MakeLabel(
        page, "PageHeading", info[1],
        UDim2.new(), UDim2.new(1, -4, 0, 29),
        Enum.Font.GothamBold, 20, Palette.Text
    )
    heading.LayoutOrder = NextPageOrder(page)

    local description = MakeLabel(
        page, "PageDescription", info[3],
        UDim2.new(), UDim2.new(1, -4, 0, 20),
        Enum.Font.Gotham, 10, Palette.Muted
    )
    description.LayoutOrder = NextPageOrder(page)

    Pages[name] = page
    return page
end

local function SwitchPage(name)
    if not Pages[name] then return end
    ActivePage = name

    for pageName, page in pairs(Pages) do
        local selected = pageName == name
        page.Visible = selected
        if selected then
            local pageScale = page:FindFirstChild("PageScale")
            if not pageScale then
                pageScale = Instance.new("UIScale")
                pageScale.Name = "PageScale"
                pageScale.Parent = page
            end
            pageScale.Scale = 0.985
            Animate(pageScale, 0.18, {Scale = 1})
        end
    end

    for tabName, button in pairs(TabButtons) do
        local selected = tabName == name
        Animate(button, 0.14, {
            BackgroundColor3 = selected and Palette.CardHover or Palette.Panel,
        })
        local badge = button:FindFirstChild("IconBadge")
        if badge then
            Animate(badge, 0.14, {
                BackgroundColor3 = selected and Palette.Chip or Palette.PanelRaised,
            })
        end
        local indicator = button:FindFirstChild("ActiveIndicator")
        if indicator then indicator.Visible = selected end
        local icon = button:FindFirstChild("TabIcon", true)
        if icon then icon.TextColor3 = selected and Config.Accent or Palette.Muted end
        local title = button:FindFirstChild("TabTitle")
        if title then title.TextColor3 = selected and Palette.Text or Palette.Muted end
    end

    local info = PageInfo[name]
    CurrentPageLabel.Text = string.upper(info[1])
    CurrentPageLabel.TextColor3 = Config.Accent
    CurrentPageMeta.Text = "NEXUS  /  " .. string.upper(name)
end

local function AddSection(page, sectionName)
    local heading = Instance.new("Frame")
    heading.Name = "SectionHeader"
    heading.Size = UDim2.new(1, -4, 0, 27)
    heading.BackgroundTransparency = 1
    heading.Parent = page
    heading.LayoutOrder = NextPageOrder(page)

    local label = MakeLabel(
        heading, "SectionTitle", string.upper(sectionName),
        UDim2.fromOffset(1, 0), UDim2.new(1, -80, 1, 0),
        Enum.Font.GothamBold, 9, Config.Accent
    )
    label:SetAttribute("NEXUSAccentText", true)

    local rule = Instance.new("Frame")
    rule.Name = "SectionRule"
    rule.AnchorPoint = Vector2.new(1, 0.5)
    rule.Position = UDim2.new(1, -1, 0.5, 0)
    rule.Size = UDim2.new(0, 54, 0, 2)
    rule.BackgroundColor3 = Config.Accent
    rule.BackgroundTransparency = 0.18
    rule.BorderSizePixel = 0
    rule.Parent = heading
    rule:SetAttribute("NEXUSAccent", true)
    Round(rule, 2)

    local grid = Instance.new("Frame")
    grid.Name = "ControlGrid"
    grid.Size = UDim2.new(1, -4, 0, 0)
    grid.BackgroundTransparency = 1
    grid.Parent = page
    grid.LayoutOrder = NextPageOrder(page)

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.Name = "GridLayout"
    gridLayout.CellSize = UDim2.new(0.5, -6, 0, 94)
    gridLayout.CellPadding = UDim2.new(0, 12, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = grid

    Track(gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if grid.Parent then
            grid.Size = UDim2.new(1, -4, 0, gridLayout.AbsoluteContentSize.Y)
        end
    end))

    CurrentGrids[page] = grid
    return grid
end

local function AddCardBase(page, label, detail, className)
    local parent = CurrentGrids[page] or page
    local card = Instance.new(className or "TextButton")
    card.Name = (label:gsub("%W", "")) .. "Control"
    card.BackgroundColor3 = Palette.Card
    card.BorderSizePixel = 0
    if card:IsA("TextButton") then
        card.Text = ""
        card.AutoButtonColor = false
    end
    card.Parent = parent
    card.LayoutOrder = #parent:GetChildren()
    Round(card, 8)
    local outline = Stroke(card, Palette.Border, 0.32, 1)

    local rail = Instance.new("Frame")
    rail.Name = "AccentRail"
    rail.Position = UDim2.fromOffset(0, 14)
    rail.Size = UDim2.fromOffset(3, 34)
    rail.BackgroundColor3 = Config.Accent
    rail.BackgroundTransparency = 0.22
    rail.BorderSizePixel = 0
    rail.Parent = card
    rail:SetAttribute("NEXUSAccent", true)
    Round(rail, 3)

    local title = MakeLabel(
        card, "ControlTitle", label,
        UDim2.fromOffset(16, 12), UDim2.new(1, -32, 0, 19),
        Enum.Font.GothamBold, 10, Palette.Text
    )
    local description = MakeLabel(
        card, "ControlDescription", detail or "",
        UDim2.fromOffset(16, 36), UDim2.new(1, -32, 0, 15),
        Enum.Font.Code, 8, Palette.Muted
    )

    card.MouseEnter:Connect(function()
        Animate(card, 0.13, {BackgroundColor3 = Palette.CardHover})
        Animate(outline, 0.13, {Transparency = 0.18, Color = Config.Accent})
    end)
    card.MouseLeave:Connect(function()
        Animate(card, 0.13, {BackgroundColor3 = Palette.Card})
        Animate(outline, 0.13, {Transparency = 0.48, Color = Palette.Border})
    end)

    return card, title, description
end

local function AddButton(page, label, callback)
    local button, title, description = AddCardBase(page, label, "CLICK TO RUN  /  ACTION")
    local action = Instance.new("TextLabel")
    action.Name = "ActionBadge"
    action.AnchorPoint = Vector2.new(1, 0.5)
    action.Position = UDim2.new(1, -13, 0.5, 0)
    action.Size = UDim2.fromOffset(43, 23)
    action.BackgroundColor3 = Palette.Chip
    action.BorderSizePixel = 0
    action.Text = "RUN  ›"
    action.TextColor3 = Config.Accent
    action.Font = Enum.Font.GothamBold
    action.TextSize = 8
    action.Parent = button
    action:SetAttribute("NEXUSAccentText", true)
    Round(action, 7)
    description.Size = UDim2.new(1, -78, 0, 15)
    button.MouseButton1Click:Connect(callback)
    return button
end

local function AddToggle(page, label, key)
    local button, title, description = AddCardBase(page, label, "DISABLED")

    local pill = Instance.new("Frame")
    pill.Name = "ToggleState"
    pill.Size = UDim2.fromOffset(39, 22)
    pill.Position = UDim2.new(1, -53, 0.5, -11)
    pill.BackgroundColor3 = Palette.ToggleOff
    pill.BorderSizePixel = 0
    pill.Parent = button
    pill:SetAttribute("NEXUSAccentToggle", true)
    Round(pill, 12)

    local knob = Instance.new("Frame")
    knob.Name = "ToggleKnob"
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.fromOffset(4, 4)
    knob.BackgroundColor3 = Color3.fromRGB(246, 248, 252)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    Round(knob, 9)

    local function refresh()
        local enabled = Config[key] == true
        description.Text = enabled and "ENABLED  /  ACTIVE" or "DISABLED  /  INACTIVE"
        description.TextColor3 = enabled and Config.Accent or Palette.Muted
        pill:SetAttribute("Enabled", enabled)
        Animate(pill, 0.12, {
            BackgroundColor3 = enabled and Config.Accent or Palette.ToggleOff,
        })
        Animate(knob, 0.12, {
            Position = enabled and UDim2.new(1, -18, 0, 4) or UDim2.fromOffset(4, 4),
        })
    end

    button.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        if key == "AimEnabled" and not Config.AimEnabled then
            AimToggleActive = false
            LockedTarget = nil
        end
        if key == "UIVisible" then
            MenuOpen = Config.UIVisible
            Main.Visible = MenuOpen
        end
        refresh()
        ScheduleSave()
    end)

    table.insert(ControlRefreshers, refresh)
    refresh()
    return button
end

local function AddSlider(page, label, key, minValue, maxValue, step)
    local holder, title, description = AddCardBase(page, label, "DRAG TO ADJUST", "Frame")
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "SliderValue"
    valueLabel.AnchorPoint = Vector2.new(1, 0)
    valueLabel.Position = UDim2.new(1, -13, 0, 10)
    valueLabel.Size = UDim2.fromOffset(66, 19)
    valueLabel.BackgroundColor3 = Palette.Chip
    valueLabel.BorderSizePixel = 0
    valueLabel.TextColor3 = Config.Accent
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 9
    valueLabel.Parent = holder
    title.Size = UDim2.new(1, -100, 0, 19)
    valueLabel:SetAttribute("NEXUSAccentText", true)
    Round(valueLabel, 6)

    local bar = Instance.new("TextButton")
    bar.Name = "SliderTrack"
    bar.Position = UDim2.fromOffset(14, 62)
    bar.Size = UDim2.new(1, -28, 0, 6)
    bar.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = holder
    Round(bar, 5)

    local fill = Instance.new("Frame")
    fill.Name = "SliderFill"
    fill.BackgroundColor3 = Config.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    fill:SetAttribute("NEXUSAccent", true)
    Round(fill, 5)

    local knob = Instance.new("Frame")
    knob.Name = "SliderKnob"
    knob.Size = UDim2.fromOffset(13, 13)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.BackgroundColor3 = Color3.fromRGB(248, 250, 255)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    Round(knob, 8)
    Stroke(knob, Config.Accent, 0.15, 1)

    local dragging = false
    local function refresh()
        local ratio = math.clamp((Config[key] - minValue) / (maxValue - minValue), 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, 0, 0.5, 0)
        local valueText = string.format("%.2f", Config[key]):gsub("0+$", ""):gsub("%.$", "")
        valueLabel.Text = valueText
    end

    local function update(x)
        local width = math.max(bar.AbsoluteSize.X, 1)
        local ratio = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        local raw = minValue + (maxValue - minValue) * ratio
        Config[key] = math.clamp(math.floor(raw / step + 0.5) * step, minValue, maxValue)
        refresh()
        if key == "AimDistance" then LockedTarget = nil end
        ScheduleSave()
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input.Position.X)
        end
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input.Position.X)
        end
    end))
    Track(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    table.insert(ControlRefreshers, refresh)
    refresh()
    return holder
end

local function AddCycle(page, label, key, options)
    local button, title, description = AddCardBase(page, label, "CURRENT SELECTION")
    local value = Instance.new("TextLabel")
    value.Name = "CycleValue"
    value.AnchorPoint = Vector2.new(1, 0.5)
    value.Position = UDim2.new(1, -13, 0.5, 0)
    value.Size = UDim2.fromOffset(104, 25)
    value.BackgroundColor3 = Palette.Chip
    value.BorderSizePixel = 0
    value.TextColor3 = Config.Accent
    value.Font = Enum.Font.GothamBold
    value.TextSize = 8
    value.TextTruncate = Enum.TextTruncate.AtEnd
    value.Parent = button
    title.Size = UDim2.new(1, -130, 0, 19)
    value:SetAttribute("NEXUSAccentText", true)
    Round(value, 7)
    description.Size = UDim2.new(1, -118, 0, 15)

    local function refresh()
        value.Text = tostring(Config[key])
    end
    button.MouseButton1Click:Connect(function()
        local index = table.find(options, Config[key]) or 1
        Config[key] = options[index % #options + 1]
        refresh()
        ScheduleSave()
    end)
    table.insert(ControlRefreshers, refresh)
    refresh()
    return button
end

local function AddKeybind(page, label, key)
    local button, title, description = AddCardBase(page, label, "CLICK TO ASSIGN A KEY")
    local keyChip = Instance.new("TextLabel")
    keyChip.Name = "KeybindValue"
    keyChip.AnchorPoint = Vector2.new(1, 0.5)
    keyChip.Position = UDim2.new(1, -13, 0.5, 0)
    keyChip.Size = UDim2.fromOffset(86, 25)
    keyChip.BackgroundColor3 = Palette.Chip
    keyChip.BorderSizePixel = 0
    keyChip.TextColor3 = Config.Accent
    keyChip.Font = Enum.Font.GothamBold
    keyChip.TextSize = 9
    keyChip.Parent = button
    title.Size = UDim2.new(1, -110, 0, 19)
    keyChip:SetAttribute("NEXUSAccentText", true)
    Round(keyChip, 7)
    description.Size = UDim2.new(1, -100, 0, 15)

    local function refresh()
        keyChip.Text = Config[key].Name
    end
    button.MouseButton1Click:Connect(function()
        CaptureKey = key
        keyChip.Text = "PRESS KEY"
        description.Text = "WAITING FOR KEY INPUT..."
        description.TextColor3 = Config.Accent
    end)

    Track(UIS.InputBegan:Connect(function(input)
        if CaptureKey == key and input.UserInputType == Enum.UserInputType.Keyboard then
            Config[key] = input.KeyCode
            CaptureKey = nil
            refresh()
            description.Text = "CLICK TO ASSIGN A KEY"
            description.TextColor3 = Palette.Muted
            ScheduleSave()
        end
    end))

    table.insert(ControlRefreshers, refresh)
    refresh()
    return button
end

local function RefreshAllControls()
    for _, refresh in ipairs(ControlRefreshers) do
        pcall(refresh)
    end
end

local AimPage = CreatePage("Aim")
local ESPPage = CreatePage("ESP")
local VisualPage = CreatePage("Visuals")
local SettingsPage = CreatePage("Settings")
local CustomizePage = CreatePage("Customize")

local tabs = {
    {"Aim", "◎", "Targeting"},
    {"ESP", "▤", "Player overlay"},
    {"Visuals", "◉", "Visual effects"},
    {"Settings", "⌘", "Preferences"},
    {"Customize", "✳", "Appearance"},
}

for index, data in ipairs(tabs) do
    local name, glyph, hint = data[1], data[2], data[3]
    local tab = Instance.new("TextButton")
    tab.Name = name .. "Tab"
    tab.Size = UDim2.new(1, -12, 0, 58)
    tab.Position = UDim2.fromOffset(6, 48 + (index - 1) * 66)
    tab.BackgroundColor3 = Palette.Panel
    tab.BorderSizePixel = 0
    tab.Text = ""
    tab.AutoButtonColor = false
    tab.Parent = Sidebar
    Round(tab, 9)

    local indicator = Instance.new("Frame")
    indicator.Name = "ActiveIndicator"
    indicator.Size = UDim2.new(0, 3, 0, 30)
    indicator.Position = UDim2.new(0, 0, 0.5, -15)
    indicator.BackgroundColor3 = Config.Accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.Parent = tab
    indicator:SetAttribute("NEXUSAccent", true)
    Round(indicator, 3)

    local iconBadge = Instance.new("Frame")
    iconBadge.Name = "IconBadge"
    iconBadge.Size = UDim2.fromOffset(38, 38)
    iconBadge.Position = UDim2.new(0.5, -19, 0, 10)
    iconBadge.BackgroundColor3 = Palette.PanelRaised
    iconBadge.BorderSizePixel = 0
    iconBadge.Parent = tab
    Round(iconBadge, 8)

    local icon = MakeLabel(
        iconBadge, "TabIcon", glyph,
        UDim2.fromScale(0, 0), UDim2.fromScale(1, 1),
        Enum.Font.GothamBold, 19, Palette.Muted
    )
    icon.TextXAlignment = Enum.TextXAlignment.Center

    local tabTitle = MakeLabel(
        tab, "TabTitle", name,
        UDim2.fromOffset(55, 9), UDim2.new(1, -64, 0, 19),
        Enum.Font.GothamBold, 10, Palette.Muted
    )
    local tabHint = MakeLabel(
        tab, "TabHint", hint,
        UDim2.fromOffset(55, 29), UDim2.new(1, -64, 0, 15),
        Enum.Font.Gotham, 8, Palette.Soft
    )

    TabButtons[name] = tab
    tab.MouseButton1Click:Connect(function()
        SwitchPage(name)
    end)
end

-- AIM CONTROLS
AddSection(AimPage, "Aim assistance")
AddToggle(AimPage, "Enable Aimlock", "AimEnabled")
AddKeybind(AimPage, "Aimlock Key", "AimKey")
AddCycle(AimPage, "Activation Mode", "AimActivation", {"Hold", "Toggle"})
AddCycle(AimPage, "Target Part", "AimPart", {"Head", "Neck", "Torso", "Pelvis", "Root"})
AddCycle(AimPage, "Target Priority", "AimMode", {"Closest to Crosshair", "Closest to Character", "Lowest Health"})
AddCycle(AimPage, "Aim Response", "AimResponse", {"Linear", "Ease Out", "Ease In-Out", "Exponential"})
AddToggle(AimPage, "Sticky Target", "StickyTarget")
AddToggle(AimPage, "Team Check", "TeamCheck")
AddToggle(AimPage, "Visibility Check", "VisibilityCheck")
AddSlider(AimPage, "FOV Radius", "FOV", 30, 600, 5)
AddSlider(AimPage, "Aim Distance", "AimDistance", 50, 2000, 25)
AddSlider(AimPage, "Smoothness", "Smoothness", 1, 30, 1)
AddSlider(AimPage, "Prediction", "Prediction", 0, 0.3, 0.01)
AddSlider(AimPage, "Horizontal Offset", "AimOffsetX", -3, 3, 0.1)
AddSlider(AimPage, "Vertical Offset", "AimOffsetY", -3, 3, 0.1)
AddSlider(AimPage, "Deadzone", "Deadzone", 0, 60, 1)
AddToggle(AimPage, "Show FOV Circle", "ShowFOV")

local AimStatusCard = Instance.new("Frame")
AimStatusCard.Name = "LiveTargetStatus"
AimStatusCard.BackgroundColor3 = Palette.PanelRaised
AimStatusCard.BorderSizePixel = 0
AimStatusCard.Parent = CurrentGrids[AimPage]
AimStatusCard.LayoutOrder = #CurrentGrids[AimPage]:GetChildren()
Round(AimStatusCard, 12)
Stroke(AimStatusCard, Palette.Border, 0.45, 1)
local AimStatusAccent = Instance.new("Frame")
AimStatusAccent.Size = UDim2.new(0, 3, 0, 28)
AimStatusAccent.Position = UDim2.fromOffset(0, 15)
AimStatusAccent.BackgroundColor3 = Config.Accent
AimStatusAccent.BorderSizePixel = 0
AimStatusAccent.Parent = AimStatusCard
AimStatusAccent:SetAttribute("NEXUSAccent", true)
Round(AimStatusAccent, 3)
AimStatusLabel = MakeLabel(
    AimStatusCard, "TargetStatusText", "TARGET  /  NONE",
    UDim2.fromOffset(14, 0), UDim2.new(1, -26, 1, 0),
    Enum.Font.GothamBold, 9, Palette.Muted
)

-- ESP CONTROLS
AddSection(ESPPage, "Player information")
AddToggle(ESPPage, "Enable ESP", "ESPEnabled")
AddToggle(ESPPage, "Player Names", "Names")
AddToggle(ESPPage, "Player Boxes", "Boxes")
AddToggle(ESPPage, "Health Bars", "HealthBars")
AddToggle(ESPPage, "Distance Labels", "DistanceLabels")
AddToggle(ESPPage, "Tracers", "Tracers")
AddToggle(ESPPage, "ESP Team Check", "ESPTeamCheck")

-- VISUAL CONTROLS
AddSection(VisualPage, "Character effects")
AddToggle(VisualPage, "Chams", "ChamsEnabled")
AddToggle(VisualPage, "Skeletons", "SkeletonsEnabled")
AddToggle(VisualPage, "Head Dots", "HeadDots")
AddToggle(VisualPage, "Highlight Aim Target", "TargetHighlight")
AddSlider(VisualPage, "Chams Transparency", "ChamsTransparency", 0, 1, 0.05)
AddSlider(VisualPage, "Skeleton Thickness", "SkeletonThickness", 1, 5, 1)
AddSection(VisualPage, "Screen elements")
AddToggle(VisualPage, "Custom Crosshair", "CrosshairEnabled")
AddSlider(VisualPage, "Crosshair Size", "CrosshairSize", 3, 20, 1)

-- SYSTEM SETTINGS
AddSection(SettingsPage, "Interface and performance")
AddKeybind(SettingsPage, "Menu Toggle Key", "MenuKey")
AddButton(SettingsPage, "Emergency Reopen", function()
    Notify("Use your configured menu key to reopen NEXUS")
end)
AddToggle(SettingsPage, "Notifications", "Notifications")
AddToggle(SettingsPage, "Performance Mode", "PerformanceMode")
AddSlider(SettingsPage, "UI Scale", "UIScale", 0.7, 1.3, 0.05)
AddSlider(SettingsPage, "Menu Transparency", "UITransparency", 0, 0.8, 0.05)

-- PERSONALIZATION
AddSection(CustomizePage, "Accent palette")
local function SetAccent(color)
    Config.Accent = color
    RefreshAllControls()
    AppearanceDirty = true
    ScheduleSave()
end
AddButton(CustomizePage, "Accent / Signal Lime", function() SetAccent(Color3.fromRGB(190, 245, 90)) end)
AddButton(CustomizePage, "Accent / Violet", function() SetAccent(Color3.fromRGB(135, 90, 255)) end)
AddButton(CustomizePage, "Accent / Blue", function() SetAccent(Color3.fromRGB(70, 150, 255)) end)
AddButton(CustomizePage, "Accent / Green", function() SetAccent(Color3.fromRGB(70, 220, 150)) end)
AddButton(CustomizePage, "Accent / Red", function() SetAccent(Color3.fromRGB(245, 80, 100)) end)
AddButton(CustomizePage, "Accent / Pink", function() SetAccent(Color3.fromRGB(255, 90, 180)) end)
AddButton(CustomizePage, "Accent / Cyan", function() SetAccent(Color3.fromRGB(45, 210, 220)) end)
AddButton(CustomizePage, "Accent / Orange", function() SetAccent(Color3.fromRGB(255, 155, 65)) end)
AddButton(CustomizePage, "Accent / Ice", function() SetAccent(Color3.fromRGB(190, 215, 255)) end)
AddToggle(CustomizePage, "Compact Sidebar", "CompactSidebar")
AddToggle(CustomizePage, "Overlay Visible", "UIVisible")
AddSection(CustomizePage, "Configuration manager")
AddButton(CustomizePage, "Save Configuration", function()
    SaveConfig(false)
end)
AddButton(CustomizePage, "Load Configuration", function()
    if LoadConfig(false) then
        ApplyColors()
        RefreshAllControls()
        AppearanceDirty = true
        Notify("Configuration restored")
    end
end)
AddButton(CustomizePage, "Reset Configuration", function()
    for key, value in pairs(Defaults) do
        Config[key] = type(value) == "table" and table.clone(value) or value
    end
    Config.AimKey = Enum.KeyCode.Q
    Config.MenuKey = Enum.KeyCode.RightShift
    AimToggleActive = false
    LockedTarget = nil
    ApplyColors()
    RefreshAllControls()
    AppearanceDirty = true
    SaveConfig(true)
    Notify("Default settings restored")
end)

SwitchPage("Aim")

-- Subtle entrance animation
Main.Position = UDim2.new(0.5, -520, 0.5, -338)
Animate(Main, 0.24, {Position = UDim2.new(0.5, -520, 0.5, -350)})
-- DRAGGING

local dragging = false
local dragStart
local startPosition

Top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
    end
end)

Track(UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

Track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end))

-- VISUAL OVERLAY

local CircleGui = Instance.new("ScreenGui")
CircleGui.Name = "NEXUS_Visuals"
CircleGui.IgnoreGuiInset = true
CircleGui.ResetOnSpawn = false
CircleGui.Parent = ScreenGui.Parent

local FOVCircle = Instance.new("Frame")
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Parent = CircleGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Parent = FOVCircle

local CrosshairLines = {}

for index = 1, 4 do
    local line = Instance.new("Frame")
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BorderSizePixel = 0
    line.Parent = CircleGui
    CrosshairLines[index] = line
end

-- ESP OBJECTS

local function MakeESP(player)
    if player == LocalPlayer or ESPObjects[player] then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NEXUS_ESP_" .. player.UserId
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = CircleGui.Parent

    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Parent = box

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextStrokeTransparency = 0
    name.Font = Enum.Font.GothamBold
    name.TextSize = 12
    name.Parent = gui

    local distance = Instance.new("TextLabel")
    distance.BackgroundTransparency = 1
    distance.TextColor3 = Color3.new(1, 1, 1)
    distance.TextStrokeTransparency = 0
    distance.Font = Enum.Font.Gotham
    distance.TextSize = 11
    distance.Parent = gui

    local healthBack = Instance.new("Frame")
    healthBack.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    healthBack.BorderSizePixel = 0
    healthBack.Parent = gui

    local healthFill = Instance.new("Frame")
    healthFill.BackgroundColor3 = Color3.fromRGB(80, 220, 145)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBack

    local tracer = Instance.new("Frame")
    tracer.AnchorPoint = Vector2.new(0.5, 0)
    tracer.BorderSizePixel = 0
    tracer.Parent = gui

    ESPObjects[player] = {
        Gui = gui,
        Box = box,
        Stroke = stroke,
        Name = name,
        Distance = distance,
        HealthBack = healthBack,
        HealthFill = healthFill,
        Tracer = tracer
    }
end

local function RemoveESP(player)
    local object = ESPObjects[player]
    if object then
        object.Gui:Destroy()
        ESPObjects[player] = nil
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    MakeESP(player)
end

Track(Players.PlayerAdded:Connect(MakeESP))
Track(Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)

    if Highlights[player] then
        Highlights[player]:Destroy()
        Highlights[player] = nil
    end

    if SkeletonObjects[player] then
        SkeletonObjects[player].Gui:Destroy()
        SkeletonObjects[player] = nil
    end

    if LockedTarget == player then
        LockedTarget = nil
    end
end))

-- CHAMS

local function UpdateChams(player)
    if player == LocalPlayer then return end

    local character = GetCharacter(player)
    local isTarget = Config.TargetHighlight and player == LockedTarget
    local shouldHighlight = Config.ChamsEnabled or isTarget
    local highlight = Highlights[player]

    if not character or not shouldHighlight then
        if highlight then
            highlight:Destroy()
            Highlights[player] = nil
        end
        return
    end

    if not highlight or highlight.Parent ~= character then
        if highlight then highlight:Destroy() end

        highlight = Instance.new("Highlight")
        highlight.Name = "NEXUS_Highlight"
        highlight.Parent = character
        Highlights[player] = highlight
    end

    local color = isTarget and Config.Accent or Config.ChamsColor
    highlight.Enabled = true
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = isTarget and 0.2 or Config.ChamsTransparency
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

-- SKELETONS

local SkeletonConnections = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

local function CreateSkeleton(player)
    if SkeletonObjects[player] then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NEXUS_Skeleton_" .. player.UserId
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = CircleGui.Parent

    local lines = {}

    for index = 1, #SkeletonConnections do
        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.Visible = false
        line.Parent = gui
        lines[index] = line
    end

    SkeletonObjects[player] = {Gui = gui, Lines = lines}
end

local function UpdateSkeleton(player)
    if not Config.SkeletonsEnabled then
        if SkeletonObjects[player] then
            SkeletonObjects[player].Gui:Destroy()
            SkeletonObjects[player] = nil
        end
        return
    end

    local character = GetCharacter(player)

    if not character or not IsAlive(player) then
        local existing = SkeletonObjects[player]
        if existing then
            for _, line in ipairs(existing.Lines) do
                line.Visible = false
            end
        end
        return
    end

    CreateSkeleton(player)
    local skeleton = SkeletonObjects[player]

    for index, pair in ipairs(SkeletonConnections) do
        local aPart = character:FindFirstChild(pair[1])
        local bPart = character:FindFirstChild(pair[2])
        local line = skeleton.Lines[index]

        if aPart and bPart then
            local a, visibleA = Camera:WorldToViewportPoint(aPart.Position)
            local b, visibleB = Camera:WorldToViewportPoint(bPart.Position)

            if visibleA and visibleB then
                local delta = Vector2.new(b.X - a.X, b.Y - a.Y)

                line.Position = UDim2.fromOffset(
                    (a.X + b.X) / 2,
                    (a.Y + b.Y) / 2
                )
                line.Size = UDim2.fromOffset(
                    delta.Magnitude,
                    Config.SkeletonThickness
                )
                line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                line.BackgroundColor3 = Config.SkeletonColor
                line.Visible = true
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

local function UpdateESP(player)
    local object = ESPObjects[player]
    if not object then return end

    local character = GetCharacter(player)
    local root = GetRoot(player)
    local humanoid = GetHumanoid(player)

    local visible = Config.ESPEnabled and character and root
        and humanoid and humanoid.Health > 0
        and (not Config.ESPTeamCheck or not LocalPlayer.Team
            or player.Team ~= LocalPlayer.Team)

    if not visible then
        object.Box.Visible = false
        object.Name.Visible = false
        object.Distance.Visible = false
        object.HealthBack.Visible = false
        object.Tracer.Visible = false
        return
    end

    local rootPoint, onScreen = Camera:WorldToViewportPoint(root.Position)

    if not onScreen then
        object.Box.Visible = false
        object.Name.Visible = false
        object.Distance.Visible = false
        object.HealthBack.Visible = false
        object.Tracer.Visible = false
        return
    end

    local head = character:FindFirstChild("Head")
    local top = head and Camera:WorldToViewportPoint(
        head.Position + Vector3.new(0, 0.5, 0)
    ) or Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))

    local bottom = Camera:WorldToViewportPoint(
        root.Position - Vector3.new(0, 3.5, 0)
    )

    local height = math.abs(bottom.Y - top.Y)
    local width = height * 0.55
    local x = rootPoint.X - width / 2
    local y = top.Y

    object.Box.Position = UDim2.fromOffset(x, y)
    object.Box.Size = UDim2.fromOffset(width, height)
    object.Box.Visible = Config.Boxes
    object.Stroke.Color = Config.ESPColor

    object.Name.Position = UDim2.fromOffset(x, y - 19)
    object.Name.Size = UDim2.fromOffset(width, 16)
    object.Name.Text = player.DisplayName
    object.Name.Visible = Config.Names

    object.Distance.Position = UDim2.fromOffset(x, y + height + 2)
    object.Distance.Size = UDim2.fromOffset(width, 16)
    object.Distance.Text = math.floor(GetDistance(player)) .. " studs"
    object.Distance.Visible = Config.DistanceLabels

    object.HealthBack.Position = UDim2.fromOffset(x - 6, y)
    object.HealthBack.Size = UDim2.fromOffset(3, height)
    object.HealthBack.Visible = Config.HealthBars

    local healthRatio = math.clamp(
        humanoid.Health / math.max(humanoid.MaxHealth, 1),
        0, 1
    )

    object.HealthFill.AnchorPoint = Vector2.new(0, 1)
    object.HealthFill.Position = UDim2.new(0, 0, 1, 0)
    object.HealthFill.Size = UDim2.new(1, 0, healthRatio, 0)
    object.HealthFill.BackgroundColor3 = Color3.fromRGB(
        255 * (1 - healthRatio),
        255 * healthRatio,
        60
    )

    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y)
    local endpoint = Vector2.new(rootPoint.X, rootPoint.Y)
    local delta = endpoint - center

    object.Tracer.Position = UDim2.fromOffset(center.X, center.Y)
    object.Tracer.Size = UDim2.fromOffset(delta.Magnitude, 1)
    object.Tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    object.Tracer.Visible = Config.Tracers
    object.Tracer.BackgroundColor3 = Config.ESPColor
end

local function UpdateHeadDot(player)
    local object = ESPObjects[player]
    if not object then return end

    if not Config.HeadDots then
        if object.HeadDot then object.HeadDot.Visible = false end
        return
    end

    if not object.HeadDot then
        local dot = Instance.new("Frame")
        dot.Size = UDim2.fromOffset(6, 6)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.BackgroundColor3 = Config.ESPColor
        dot.BorderSizePixel = 0
        dot.Parent = object.Gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot

        object.HeadDot = dot
    end

    local character = GetCharacter(player)
    local head = character and character:FindFirstChild("Head")

    if head then
        local point, visible = Camera:WorldToViewportPoint(head.Position)
        object.HeadDot.Position = UDim2.fromOffset(point.X, point.Y)
        object.HeadDot.Visible = visible
    else
        object.HeadDot.Visible = false
    end
end

-- APPLY SETTINGS TO UI AND VISUALS

local function ApplyAppearance()
    MainStroke.Color = Config.Accent
    BrandMark.BackgroundColor3 = Config.Accent
    BrandGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Config.Accent)
    CurrentPageLabel.TextColor3 = Config.Accent
    VersionChip.TextColor3 = Config.Accent
    MainStroke.Transparency = 0.18

    for _, object in ipairs(ScreenGui:GetDescendants()) do
        if object:GetAttribute("NEXUSAccent") then
            if object:IsA("UIStroke") then
                object.Color = Config.Accent
            elseif object:IsA("GuiObject") then
                object.BackgroundColor3 = Config.Accent
            end
        end

        if object:GetAttribute("NEXUSAccentText") and object:IsA("TextLabel") then
            object.TextColor3 = Config.Accent
        end

        if object:GetAttribute("NEXUSAccentToggle") and object:IsA("Frame") then
            local enabled = object:GetAttribute("Enabled") == true
            object.BackgroundColor3 = enabled and Config.Accent or Palette.ToggleOff
        end
    end

    for tabName, tab in pairs(TabButtons) do
        local selected = tabName == ActivePage
        local indicator = tab:FindFirstChild("ActiveIndicator")
        if indicator then indicator.BackgroundColor3 = Config.Accent end

        local iconBadge = tab:FindFirstChild("IconBadge")
        local icon = iconBadge and iconBadge:FindFirstChild("TabIcon")
        if icon then icon.TextColor3 = selected and Config.Accent or Palette.Muted end
        if iconBadge then
            iconBadge.BackgroundColor3 = selected and Palette.Chip or Palette.PanelRaised
        end

        local title = tab:FindFirstChild("TabTitle")
        local hint = tab:FindFirstChild("TabHint")
        if title then
            title.Visible = not Config.CompactSidebar
            title.TextColor3 = selected and Palette.Text or Palette.Muted
        end
        if hint then hint.Visible = not Config.CompactSidebar end

        tab.Size = UDim2.new(1, -12, 0, 58)
        tab.Position = UDim2.fromOffset(6, (Config.CompactSidebar and 12 or 48) + ((table.find({"Aim", "ESP", "Visuals", "Settings", "Customize"}, tabName) or 1) - 1) * 66)
        if iconBadge then
            iconBadge.Position = Config.CompactSidebar
                and UDim2.new(0.5, -19, 0, 10)
                or UDim2.fromOffset(9, 10)
        end
    end

    if Config.CompactSidebar then
        Sidebar.Position = UDim2.fromOffset(16, 94)
        Sidebar.Size = UDim2.new(0, 74, 1, -110)
        ContentTop.Position = UDim2.fromOffset(108, 94)
        ContentTop.Size = UDim2.new(1, -128, 0, 30)
        Content.Position = UDim2.fromOffset(108, 132)
        Content.Size = UDim2.new(1, -128, 1, -150)
        NavHeading.Visible = false
        NavDivider.Visible = false
        NavFooter.Visible = false
    else
        Sidebar.Position = UDim2.fromOffset(16, 94)
        Sidebar.Size = UDim2.new(0, 204, 1, -110)
        ContentTop.Position = UDim2.fromOffset(236, 94)
        ContentTop.Size = UDim2.new(1, -256, 0, 30)
        Content.Position = UDim2.fromOffset(236, 132)
        Content.Size = UDim2.new(1, -256, 1, -150)
        NavHeading.Visible = true
        NavDivider.Visible = true
        NavFooter.Visible = true
    end

    Scale.Scale = Config.UIScale
    Main.BackgroundTransparency = Config.UITransparency
    Top.BackgroundTransparency = Config.UITransparency * 0.35
    Sidebar.BackgroundTransparency = Config.UITransparency * 0.25
    NavFooter.BackgroundTransparency = Config.UITransparency * 0.2
    CurrentPageMeta.BackgroundTransparency = Config.UITransparency * 0.2

    FOVStroke.Color = Config.FOVColor
    FOVStroke.Thickness = 2

    for _, page in pairs(Pages) do
        page.ScrollBarImageColor3 = Config.Accent
        page.BackgroundTransparency = Config.UITransparency * 0.18
    end

    for _, line in ipairs(CrosshairLines) do
        line.BackgroundColor3 = Config.CrosshairColor
    end

    Main.Visible = MenuOpen
end

-- INPUT

Track(UIS.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    -- Emergency recovery: INSERT always reopens NEXUS, even if the
    -- menu was hidden or a keybind capture was active.
    if input.KeyCode == Enum.KeyCode.Insert then
        CaptureKey = nil
        Config.UIVisible = true
        MenuOpen = true
        Main.Visible = true
        ScheduleSave()
        Notify("Emergency recovery: NEXUS reopened")
        return
    end

    if CaptureKey then return end

    if input.KeyCode == Config.AimKey and Config.AimActivation == "Toggle" then
        AimToggleActive = not AimToggleActive
        if not AimToggleActive then
            LockedTarget = nil
        end
    end

    if input.KeyCode == Config.MenuKey then
        -- If the visibility toggle hid the menu, the normal menu key
        -- also restores it instead of leaving it stuck hidden.
        if not Config.UIVisible then
            Config.UIVisible = true
            MenuOpen = true
        else
            MenuOpen = not MenuOpen
        end

        Main.Visible = MenuOpen
        ScheduleSave()
    end
end))

-- UPDATE LOOP

local visualAccumulator = 0

Track(RunService.RenderStepped:Connect(function(deltaTime)
    if Destroyed then return end

    Camera = workspace.CurrentCamera
    if not Camera then return end

    if AppearanceDirty then
        ApplyAppearance()
        AppearanceDirty = false
    end

    local mouse = UIS:GetMouseLocation()
    FOVCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
    FOVCircle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
    FOVCircle.Visible = Config.ShowFOV

    local size = Config.CrosshairSize
    local gap = 4

    local positions = {
        {mouse.X - 1, mouse.Y - gap - size, 2, size},
        {mouse.X - 1, mouse.Y + gap, 2, size},
        {mouse.X - gap - size, mouse.Y - 1, size, 2},
        {mouse.X + gap, mouse.Y - 1, size, 2}
    }

    for index, line in ipairs(CrosshairLines) do
        local p = positions[index]
        line.Position = UDim2.fromOffset(p[1], p[2])
        line.Size = UDim2.fromOffset(p[3], p[4])
        line.Visible = Config.CrosshairEnabled
    end

    local aimActive = Config.AimEnabled and (
        (Config.AimActivation == "Toggle" and AimToggleActive)
        or (Config.AimActivation == "Hold" and UIS:IsKeyDown(Config.AimKey))
    )

    if aimActive then
        local keepCurrent = Config.StickyTarget and LockedTarget
            and IsAlive(LockedTarget)
            and IsEnemy(LockedTarget, Config.TeamCheck)
            and GetDistance(LockedTarget) <= Config.AimDistance

        if keepCurrent then
            local currentPart = GetAimPart(LockedTarget)
            local currentPosition = GetAimPosition(LockedTarget, currentPart)
            keepCurrent = currentPart ~= nil and currentPosition ~= nil

            if keepCurrent then
                local point, onScreen = Camera:WorldToViewportPoint(currentPosition)
                local delta = Vector2.new(point.X, point.Y) - UIS:GetMouseLocation()
                keepCurrent = onScreen and delta.Magnitude <= Config.FOV
            end

            if keepCurrent and Config.VisibilityCheck then
                keepCurrent = IsVisible(
                    currentPart,
                    GetCharacter(LockedTarget),
                    currentPosition
                )
            end
        end

        if not keepCurrent then
            LockedTarget = GetTarget()
        end
    else
        LockedTarget = nil
    end

    if AimStatusLabel then
        if aimActive and LockedTarget then
            AimStatusLabel.Text = string.format(
                "   TARGET  /  %s     •     %.0f STUDS",
                LockedTarget.DisplayName or LockedTarget.Name,
                GetDistance(LockedTarget)
            )
            AimStatusLabel.TextColor3 = Config.Accent
        elseif aimActive then
            AimStatusLabel.Text = "   TARGET  /  SEARCHING..."
            AimStatusLabel.TextColor3 = Palette.Muted
        else
            AimStatusLabel.Text = "   TARGET  /  NONE"
            AimStatusLabel.TextColor3 = Palette.Muted
        end
    end

    if LockedTarget and aimActive then
        local part = GetAimPart(LockedTarget)
        local aimPosition = GetAimPosition(LockedTarget, part)

        if part and aimPosition then
            local predicted = aimPosition
                + part.AssemblyLinearVelocity * Config.Prediction
                + part.CFrame.RightVector * Config.AimOffsetX
                + part.CFrame.UpVector * Config.AimOffsetY

            local screenPoint, onScreen = Camera:WorldToViewportPoint(predicted)
            local screenDelta = Vector2.new(screenPoint.X, screenPoint.Y) - UIS:GetMouseLocation()

            if onScreen and screenDelta.Magnitude > Config.Deadzone then
                local desired = CFrame.lookAt(Camera.CFrame.Position, predicted)
                local responseRate = 2 + ((31 - Config.Smoothness) * 2.2)
                local alpha = 1 - math.exp(-responseRate * math.max(deltaTime, 0))

                if Config.AimResponse == "Linear" then
                    alpha = math.clamp(deltaTime * responseRate, 0, 1)
                elseif Config.AimResponse == "Ease Out" then
                    alpha = alpha * (2 - alpha)
                elseif Config.AimResponse == "Ease In-Out" then
                    alpha = alpha * alpha * (3 - 2 * alpha)
                end

                Camera.CFrame = Camera.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
            end
        end
    end

    visualAccumulator += deltaTime
    local visualInterval = Config.PerformanceMode and (1 / 30) or 0

    if visualInterval == 0 or visualAccumulator >= visualInterval then
        visualAccumulator = 0
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                UpdateESP(player)
                UpdateChams(player)
                UpdateSkeleton(player)
                UpdateHeadDot(player)
            end
        end
    end
end))

-- CLOSE BUTTON

Close.MouseButton1Click:Connect(function()
    if _G.NEXUS_Cleanup then
        _G.NEXUS_Cleanup()
    end
end)

-- CLEANUP

_G.NEXUS_Cleanup = function()
    if Destroyed then return end
    Destroyed = true

    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    for player in pairs(ESPObjects) do
        RemoveESP(player)
    end

    for player, skeleton in pairs(SkeletonObjects) do
        pcall(function() skeleton.Gui:Destroy() end)
        SkeletonObjects[player] = nil
    end

    for player, highlight in pairs(Highlights) do
        pcall(function() highlight:Destroy() end)
        Highlights[player] = nil
    end

    pcall(function() ScreenGui:Destroy() end)
    pcall(function() CircleGui:Destroy() end)

    _G.NEXUS_Cleanup = nil
end

-- SAVE DEFAULT CONFIG IF NO FILE EXISTS

if FileFunctionsAvailable() then
    PrepareFolder()

    local ok, exists = pcall(isfile, CONFIG_FILE)
    if ok and not exists then
        SaveConfig(true)
    end
end

Notify("NEXUS v3.1.6 loaded")
print("NEXUS v3.1.6 loaded successfully!")
