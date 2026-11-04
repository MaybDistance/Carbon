
--[[
    CARBON // SIGNAL
    VERSION 3.1.6 ASTER - KEYBIND UPDATE

    NEW:
      - Keyboard aimlock key selection
      - Mouse aimlock key selection
      - Hold / Toggle activation
      - Live keybind display
      - Key capture protection
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--==================================================
-- CLEANUP
--==================================================

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

    -- ESP
    ESPEnabled = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPHealth = true,
    ESPDistance = true,
    ESPTracers = false,
    ESPHighlights = false,
    ESPTeamCheck = true,
    ESPMaxDistance = 1500,

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

--==================================================
-- ASTER UI
--==================================================

local Aster = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/podivichdev/Aster-UI/main/Library.lua"
))()

local Window = Aster:CreateWindow({
    Title = "CARBON // SIGNAL",
    Subtitle = "TACTICAL CONTROL INTERFACE",
    LoadingTitle = "CARBON 3.1.6",
    LoadingSubtitle = "INITIALIZING SYSTEMS",

    ToggleUIKeybind = "RightShift",

    Theme = "Midnight",
    Density = "Compact",
    Size = UDim2.fromOffset(900, 600),

    ConfigurationSaving = {
        FolderName = "CARBON",
        FileName = "CARBON_3.1.6",
    },
})

_G.CARBON_WINDOW = Window

--==================================================
-- NOTIFICATIONS
--==================================================

local function Notify(title, message)
    if not Config.Notifications then return end

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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CARBON_Overlay"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 40
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

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
-- PLAYER ESP OBJECTS
--==================================================

local ESPObjects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local folder = Instance.new("Folder")
    folder.Name = "CARBON_ESP_" .. player.UserId
    folder.Parent = ScreenGui

    local box = MakeFrame(folder, "Box", Config.ESPColor)
    box.BackgroundTransparency = 1

    local outline = Instance.new("UIStroke")
    outline.Thickness = 1.5
    outline.Color = Config.ESPColor
    outline.Parent = box

    local name = MakeText(folder, "Name")
    name.Size = UDim2.fromOffset(180, 18)
    name.AnchorPoint = Vector2.new(0.5, 1)

    local distance = MakeText(folder, "Distance")
    distance.Size = UDim2.fromOffset(180, 18)
    distance.AnchorPoint = Vector2.new(0.5, 0)

    local healthBack = MakeFrame(folder, "HealthBack", Color3.fromRGB(25, 25, 25))
    local healthFill = MakeFrame(folder, "HealthFill", Color3.fromRGB(100, 240, 110))

    local tracer = MakeFrame(folder, "Tracer", Config.ESPColor)
    tracer.AnchorPoint = Vector2.new(0.5, 0.5)

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
        Name = name,
        Distance = distance,
        HealthBack = healthBack,
        HealthFill = healthFill,
        Tracer = tracer,
        Highlight = highlight,
    }
end

local function RemoveESP(player)
    local object = ESPObjects[player]
    if not object then return end

    object.Folder:Destroy()
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
    if not character then return nil end

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
    end

    return character:FindFirstChild("Head")
end

local function IsAlive(player)
    local humanoid = GetHumanoid(player)
    return humanoid and humanoid.Health > 0
end

local function IsEnemy(player)
    if player == LocalPlayer then return false end

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

--==================================================
-- VISIBILITY CHECK
--==================================================

local function IsVisible(player, part)
    if not Config.VisibilityCheck then
        return true
    end

    if not part then return false end

    local character = GetCharacter(player)
    if not character then return false end

    local origin = Camera.CFrame.Position
    local direction = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
    }

    local result = workspace:Raycast(
        origin,
        direction,
        params
    )

    return result and result.Instance:IsDescendantOf(character)
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
                    and IsVisible(player, part) then

                    local screen, onScreen =
                        Camera:WorldToViewportPoint(part.Position)

                    if onScreen then
                        local screenDistance = (
                            Vector2.new(screen.X, screen.Y) - center
                        ).Magnitude

                        if screenDistance <= Config.AimFOV then
                            local score = screenDistance

                            if Config.AimMode == "Closest to Character" then
                                score = distance
                            elseif Config.AimMode == "Lowest Health" then
                                local humanoid = GetHumanoid(player)
                                score = humanoid and humanoid.Health or math.huge
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
    end

    return AimToggled
end

local function UpdateAim(deltaTime)
    if not AimActive() then
        Target = nil
        TargetLabel.Visible = false
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
        return
    end

    local part = GetPart(Target)
    if not part then
        Target = nil
        return
    end

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

--==================================================
-- ESP UPDATE
--==================================================

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

        if not visible then
            object.Box.Visible = false
            object.Name.Visible = false
            object.Distance.Visible = false
            object.HealthBack.Visible = false
            object.HealthFill.Visible = false
            object.Tracer.Visible = false
            object.Highlight.Enabled = false
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

                    if onScreen then
                        table.insert(corners, Vector2.new(
                            screen.X,
                            screen.Y
                        ))
                    end
                end
            end
        end

        if #corners < 2 then
            object.Box.Visible = false
            object.Name.Visible = false
            object.Distance.Visible = false
            object.HealthBack.Visible = false
            object.HealthFill.Visible = false
            object.Tracer.Visible = false
            object.Highlight.Enabled = false
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
        local centerY = (minY + maxY) / 2

        object.Box.Visible = Config.ESPBoxes
        object.Box.Position = UDim2.fromOffset(minX, minY)
        object.Box.Size = UDim2.fromOffset(width, height)

        object.Box:FindFirstChildOfClass("UIStroke").Color =
            Config.ESPColor

        object.Name.Visible = Config.ESPNames
        object.Name.Position = UDim2.fromOffset(centerX, minY - 20)
        object.Name.Text = player.Name

        object.Distance.Visible = Config.ESPDistance
        object.Distance.Position = UDim2.fromOffset(centerX, maxY + 3)
        object.Distance.Text = math.floor(GetDistance(player)) .. " studs"

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

        object.HealthFill.BackgroundColor3 =
            Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 70)

        object.Highlight.Enabled = Config.ESPHighlights
        object.Highlight.Adornee = character
        object.Highlight.FillColor = Config.ESPColor
        object.Highlight.OutlineColor = Config.ESPColor

        local screenCenter = Vector2.new(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y
        )

        local endPoint = Vector2.new(centerX, maxY)
        local diff = endPoint - screenCenter
        local length = diff.Magnitude

        object.Tracer.Visible = Config.ESPTracers
        object.Tracer.Size = UDim2.fromOffset(length, 1)
        object.Tracer.Position = UDim2.fromOffset(
            (screenCenter.X + endPoint.X) / 2,
            (screenCenter.Y + endPoint.Y) / 2
        )
        object.Tracer.Rotation = math.deg(
            math.atan2(diff.Y, diff.X)
        )
        object.Tracer.BackgroundColor3 = Config.ESPColor
    end
end

--==================================================
-- RAINBOW VIEWMODEL
--==================================================

local OriginalColors = setmetatable({}, {__mode = "k"})

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
    if not Config.RainbowGunEnabled then return end

    Camera = workspace.CurrentCamera
    if not Camera then return end

    RainbowClock = (
        RainbowClock + deltaTime * Config.RainbowGunSpeed
    ) % 1

    local color = Color3.fromHSV(RainbowClock, 0.85, 1)

    for _, instance in ipairs(Camera:GetDescendants()) do
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
-- INPUT - KEYBIND CAPTURE + AIM ACTIVATION
--==================================================

Connect(UIS.InputBegan, function(input, processed)
    if Destroyed then return end

    -- Capture mode takes priority over aim activation.
    if ListeningForAimKey then
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

    if processed then return end

    if IsAimKey(input) then
        if Config.AimActivation == "Hold" then
            AimHeld = true
        else
            AimToggled = not AimToggled
        end
    end
end)

Connect(UIS.InputEnded, function(input)
    if Destroyed then return end

    if IsAimKey(input) then
        AimHeld = false
    end
end)

Connect(UIS.WindowFocusReleased, function()
    AimHeld = false
end)

--==================================================
-- AIM TAB
--==================================================

local AimTab = Window:Tab({
    Name = "Aim",
    Icon = "crosshair",
})

AimTab:Section("AIM CONTROL")

AimTab:Toggle({
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

AimTab:Dropdown({
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

AimTab:Dropdown({
    Name = "Target Part",
    Options = {
        "Head",
        "Neck",
        "Torso",
        "Pelvis",
        "Root",
    },
    Default = Config.AimPart,
    Flag = "AimPart",
    Callback = function(v)
        Config.AimPart = v
    end,
})

--==================================================
-- NEW: AIMLOCK KEYBIND PICKER
--==================================================

AimTab:Section("AIMLOCK KEYBIND")

AimTab:Label("Current Key: " .. GetAimKeyName())

AimTab:Button({
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

AimTab:Button({
    Name = "Cancel Key Selection",
    Icon = "x",
    Callback = function()
        ListeningForAimKey = false
        KeybindStatus.Visible = false
        UpdateKeybindDisplay()
    end,
})

AimTab:Dropdown({
    Name = "Activation Mode",
    Options = {"Hold", "Toggle"},
    Default = Config.AimActivation,
    Flag = "AimActivation",
    Callback = function(v)
        Config.AimActivation = v
        AimHeld = false
        AimToggled = false
        Target = nil
    end,
})

AimTab:Section("RESPONSE")

AimTab:Slider({
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

AimTab:Slider({
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

AimTab:Slider({
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

AimTab:Slider({
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

AimTab:Section("TARGET FILTERS")

AimTab:Toggle({
    Name = "Sticky Target",
    Default = Config.StickyTarget,
    Flag = "StickyTarget",
    Callback = function(v)
        Config.StickyTarget = v
    end,
})

AimTab:Toggle({
    Name = "Team Check",
    Default = Config.TeamCheck,
    Flag = "TeamCheck",
    Callback = function(v)
        Config.TeamCheck = v
        Target = nil
    end,
})

AimTab:Toggle({
    Name = "Visibility Check",
    Default = Config.VisibilityCheck,
    Flag = "VisibilityCheck",
    Callback = function(v)
        Config.VisibilityCheck = v
    end,
})

AimTab:Toggle({
    Name = "Show FOV",
    Default = Config.ShowFOV,
    Flag = "ShowFOV",
    Callback = function(v)
        Config.ShowFOV = v
    end,
})

AimTab:Toggle({
    Name = "Target Indicator",
    Default = Config.TargetIndicator,
    Flag = "TargetIndicator",
    Callback = function(v)
        Config.TargetIndicator = v
    end,
})

AimTab:Section("AIM OFFSET")

AimTab:Slider({
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

AimTab:Slider({
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

--==================================================
-- ESP TAB
--==================================================

local ESPTab = Window:Tab({
    Name = "ESP",
    Icon = "scan-eye",
})

ESPTab:Section("PLAYER OVERLAY")

ESPTab:Toggle({
    Name = "Enable ESP",
    Default = Config.ESPEnabled,
    Flag = "ESPEnabled",
    Callback = function(v)
        Config.ESPEnabled = v
    end,
})

ESPTab:Toggle({
    Name = "2D Boxes",
    Default = Config.ESPBoxes,
    Flag = "ESPBoxes",
    Callback = function(v)
        Config.ESPBoxes = v
    end,
})

ESPTab:Toggle({
    Name = "Player Names",
    Default = Config.ESPNames,
    Flag = "ESPNames",
    Callback = function(v)
        Config.ESPNames = v
    end,
})

ESPTab:Toggle({
    Name = "Health Bars",
    Default = Config.ESPHealth,
    Flag = "ESPHealth",
    Callback = function(v)
        Config.ESPHealth = v
    end,
})

ESPTab:Toggle({
    Name = "Distance Labels",
    Default = Config.ESPDistance,
    Flag = "ESPDistance",
    Callback = function(v)
        Config.ESPDistance = v
    end,
})

ESPTab:Toggle({
    Name = "Tracers",
    Default = Config.ESPTracers,
    Flag = "ESPTracers",
    Callback = function(v)
        Config.ESPTracers = v
    end,
})

ESPTab:Toggle({
    Name = "Character Highlights",
    Default = Config.ESPHighlights,
    Flag = "ESPHighlights",
    Callback = function(v)
        Config.ESPHighlights = v
    end,
})

ESPTab:Toggle({
    Name = "Team Check",
    Default = Config.ESPTeamCheck,
    Flag = "ESPTeamCheck",
    Callback = function(v)
        Config.ESPTeamCheck = v
    end,
})

ESPTab:Slider({
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

ESPTab:ColorPicker({
    Name = "ESP Color",
    Default = Config.ESPColor,
    Flag = "ESPColor",
    Callback = function(v)
        Config.ESPColor = v
    end,
})

--==================================================
-- VISUALS TAB
--==================================================

local VisualsTab = Window:Tab({
    Name = "Visuals",
    Icon = "palette",
})

VisualsTab:Section("CROSSHAIR")

VisualsTab:Toggle({
    Name = "Custom Crosshair",
    Default = Config.CrosshairEnabled,
    Flag = "CrosshairEnabled",
    Callback = function(v)
        Config.CrosshairEnabled = v
        UpdateCrosshair()
    end,
})

VisualsTab:Slider({
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

VisualsTab:Slider({
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

VisualsTab:ColorPicker({
    Name = "Crosshair Color",
    Default = Config.CrosshairColor,
    Flag = "CrosshairColor",
    Callback = function(v)
        Config.CrosshairColor = v
        UpdateCrosshair()
    end,
})

VisualsTab:Section("VIEWMODEL")

VisualsTab:Toggle({
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

VisualsTab:Slider({
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

VisualsTab:Button({
    Name = "Restore Viewmodel Colors",
    Icon = "rotate-ccw",
    Callback = function()
        Config.RainbowGunEnabled = false
        RestoreViewmodel()
    end,
})

--==================================================
-- SETTINGS TAB
--==================================================

local SettingsTab = Window:Tab({
    Name = "Settings",
    Icon = "settings",
})

SettingsTab:Section("SYSTEM")

SettingsTab:Toggle({
    Name = "Notifications",
    Default = Config.Notifications,
    Flag = "Notifications",
    Callback = function(v)
        Config.Notifications = v
    end,
})

SettingsTab:Toggle({
    Name = "Performance Mode",
    Default = Config.PerformanceMode,
    Flag = "PerformanceMode",
    Callback = function(v)
        Config.PerformanceMode = v
    end,
})

SettingsTab:Button({
    Name = "Unload CARBON",
    Icon = "power",
    Style = "Danger",
    Callback = function()
        if _G.CARBON_CLEANUP then
            _G.CARBON_CLEANUP()
        end
    end,
})

--==================================================
-- CUSTOMIZE TAB
--==================================================

local CustomizeTab = Window:Tab({
    Name = "Customize",
    Icon = "sliders-horizontal",
})

CustomizeTab:Section("APPEARANCE")

CustomizeTab:ColorPicker({
    Name = "Accent Color",
    Default = Config.Accent,
    Flag = "Accent",
    Callback = function(v)
        Config.Accent = v
        KeybindStroke.Color = v
    end,
})

CustomizeTab:ColorPicker({
    Name = "FOV Color",
    Default = Config.FOVColor,
    Flag = "FOVColor",
    Callback = function(v)
        Config.FOVColor = v
    end,
})

CustomizeTab:ColorPicker({
    Name = "Target Indicator Color",
    Default = Config.TargetColor,
    Flag = "TargetColor",
    Callback = function(v)
        Config.TargetColor = v
        TargetLabel.TextColor3 = v
    end,
})

--==================================================
-- CONFIG TAB
--==================================================

local ConfigTab = Window:Tab({
    Name = "Config",
    Icon = "folder-cog",
})

ConfigTab:Section("CONFIGURATION")
ConfigTab:ConfigManager()

ConfigTab:Section("THEMES")
ConfigTab:ThemeManager()

ConfigTab:Section("INTERFACE")
ConfigTab:InterfaceManager()

--==================================================
-- RENDER LOOP
--==================================================

local frameCount = 0

Connect(RunService.RenderStepped, function(deltaTime)
    if Destroyed then return end

    Camera = workspace.CurrentCamera
    if not Camera then return end

    FOVCircle.Position = UDim2.fromOffset(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )

    FOVCircle.Size = UDim2.fromOffset(
        Config.AimFOV * 2,
        Config.AimFOV * 2
    )

    FOVCircle.Visible = Config.ShowFOV
    FOVStroke.Color = Config.FOVColor

    UpdateAim(deltaTime)

    frameCount += 1

    local interval = Config.PerformanceMode and 3 or 1

    if frameCount >= interval then
        frameCount = 0
        UpdateESP()
    end

    if Config.RainbowGunEnabled then
        UpdateRainbow(deltaTime)
    end
end)

--==================================================
-- CLEANUP FUNCTION
--==================================================

local function Cleanup()
    if Destroyed then return end
    Destroyed = true

    AimHeld = false
    AimToggled = false
    ListeningForAimKey = false
    Target = nil

    RestoreViewmodel()

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
        ScreenGui:Destroy()
    end)

    pcall(function()
        Window:Destroy()
    end)

    _G.CARBON_CLEANUP = nil
    _G.CARBON_WINDOW = nil
    _G.CARBON_GUI = nil
end

_G.CARBON_CLEANUP = Cleanup

--==================================================
-- INITIALIZE
--==================================================

UpdateCrosshair()
UpdateKeybindDisplay()

Notify(
    "CARBON 3.1.6",
    "Aimlock keybind system initialized."
)

print("[CARBON] 3.1.6 ASTER initialized.")
