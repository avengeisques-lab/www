--[[
    Universal ESP + Aimbot v2 for Roblox
    Works with most executors (Synapse, Script-Ware, Fluxus, etc.)
    Uses the Drawing library for rendering + Rayfield UI

    Features:
    - Box ESP (corner boxes + full boxes)
    - Skeleton ESP (bones between body parts)
    - Name / Health / Distance / Weapon ESP
    - Tracer ESP
    - Off-screen arrows
    - Head dot
    - Chams / Highlight through walls
    - Aimbot (hold + toggle/aimlock modes)
    - Triggerbot (auto-fire on target)
    - Custom crosshair
    - FOV circle
    - Item ESP
    - Team check / visibility check
    - Config saving via Rayfield
]]

-- ═══════════════════════════════════════════════════════════════
-- Services
-- ═══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════
-- Configuration
-- ═══════════════════════════════════════════════════════════════
local Config = {
    Enabled = true,
    ToggleKey = Enum.KeyCode.RightShift,

    -- Box ESP
    BoxEnabled = true,
    BoxStyle = "Full", -- "Full" or "Corner"
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxFilled = false,
    BoxFillTransparency = 0.5,
    BoxThickness = 1,

    -- Skeleton ESP
    SkeletonEnabled = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    SkeletonThickness = 1,

    -- Head Dot
    HeadDotEnabled = false,
    HeadDotColor = Color3.fromRGB(255, 255, 255),
    HeadDotFilled = false,
    HeadDotRadius = 5,

    -- Name ESP
    NameEnabled = true,
    NameColor = Color3.fromRGB(255, 255, 255),
    NameSize = 13,
    NameFont = Drawing.Fonts.UI,
    NameOutline = true,
    NameOutlineColor = Color3.fromRGB(0, 0, 0),

    -- Health ESP
    HealthEnabled = true,
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    HealthTextColor = Color3.fromRGB(255, 255, 255),
    HealthTextSize = 12,
    HealthTextFont = Drawing.Fonts.UI,

    -- Distance ESP
    DistanceEnabled = true,
    DistanceColor = Color3.fromRGB(255, 255, 255),
    DistanceSize = 12,
    DistanceFont = Drawing.Fonts.UI,

    -- Weapon ESP
    WeaponEnabled = false,
    WeaponColor = Color3.fromRGB(180, 180, 255),
    WeaponSize = 12,
    WeaponFont = Drawing.Fonts.UI,

    -- Tracer ESP
    TracerEnabled = false,
    TracerColor = Color3.fromRGB(255, 255, 255),
    TracerThickness = 1,
    TracerOrigin = "Bottom",

    -- Off-screen arrows
    OffscreenEnabled = false,
    OffscreenColor = Color3.fromRGB(255, 255, 255),
    OffscreenDistance = 150,
    OffscreenSize = 15,

    -- Chams / Highlight
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsFillTransparency = 0.5,
    ChamsOutlineTransparency = 0,

    -- Team
    TeamCheck = false,
    TeamColor = true,

    -- Max distance (0 = unlimited)
    MaxDistance = 0,

    -- Aimbot
    AimbotEnabled = false,
    AimbotMode = "Hold", -- "Hold" or "Toggle"
    AimbotKey = Enum.KeyCode.E,
    AimbotPart = "Head",
    AimbotSmoothness = 0.3,
    AimbotFOV = 120,
    AimbotShowFOV = true,
    AimbotFOVColor = Color3.fromRGB(255, 255, 255),
    AimbotTeamCheck = false,
    AimbotMaxDistance = 0,
    AimbotVisibilityCheck = false,
    AimbotPrediction = 0,

    -- Triggerbot
    TriggerbotEnabled = false,
    TriggerbotKey = Enum.KeyCode.T,
    TriggerbotDelay = 0,
    TriggerbotTeamCheck = false,

    -- Crosshair
    CrosshairEnabled = false,
    CrosshairColor = Color3.fromRGB(255, 255, 255),
    CrosshairSize = 12,
    CrosshairThickness = 1,
    CrosshairGap = 4,
    CrosshairDot = true,

    -- Item ESP
    HighlightItems = false,
    HighlightItemNames = {"Coin", "Gem", "Chest", "Key", "Orb", "Crystal", "Star"},
    HighlightItemColor = Color3.fromRGB(255, 215, 0),
}

-- ═══════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════
local ESPObjects = {}
local ChamsObjects = {}
local ItemESPObjects = {}

local AimbotLocked = nil
local AimbotHolding = false
local AimbotToggled = false
local TriggerbotHolding = false
local LastTriggerTime = 0

-- ═══════════════════════════════════════════════════════════════
-- Persistent Drawing Objects (FOV circle, crosshair)
-- ═══════════════════════════════════════════════════════════════
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = Config.AimbotFOVColor
FOVCircle.Visible = false

local CrosshairLines = {
    Top = Drawing.new("Line"),
    Bottom = Drawing.new("Line"),
    Left = Drawing.new("Line"),
    Right = Drawing.new("Line"),
}
local CrosshairDot = Drawing.new("Circle")

for _, line in pairs(CrosshairLines) do
    line.Thickness = Config.CrosshairThickness
    line.Color = Config.CrosshairColor
    line.Transparency = 1
    line.Visible = false
end

CrosshairDot.Radius = 1
CrosshairDot.Filled = true
CrosshairDot.Color = Config.CrosshairColor
CrosshairDot.Transparency = 1
CrosshairDot.Visible = false

-- ═══════════════════════════════════════════════════════════════
-- Utilities
-- ═══════════════════════════════════════════════════════════════
local function GetPlayerColor(player)
    if Config.TeamColor and player.Team and player.TeamColor then
        return player.TeamColor.Color
    end
    return Config.BoxColor
end

local function IsTeamMate(player)
    if not Config.TeamCheck then return false end
    if not player.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function GetCharacter(player)
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not head or not humanoid or humanoid.Health <= 0 then
        return nil
    end
    return char, hrp, head, humanoid
end

local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

-- Get the tool a player is holding
local function GetHeldTool(player)
    local char = player.Character
    if not char then return nil end
    for _, item in pairs(char:GetChildren()) do
        if item:IsA("Tool") then
            return item.Name
        end
    end
    return nil
end

-- Skeleton body part connections
local SkeletonPairs = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

-- R6 fallback skeleton
local SkeletonPairsR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Left Arm", "Left Leg"},
    {"Torso", "Right Arm"},
    {"Right Arm", "Right Leg"},
}

local function IsR6(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.RigType == Enum.HumanoidRigType.R6
    end
    return false
end

-- Calculate bounding box from character parts
local function GetBoundingBox(char)
    local positions = {}
    local descendants = char:GetDescendants()

    for _, part in pairs(descendants) do
        if part:IsA("BasePart") then
            table.insert(positions, part.Position)
        end
    end

    if #positions == 0 then return nil end

    -- Project all positions to screen
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local avgDepth = 0
    local onScreenCount = 0

    for _, pos in pairs(positions) do
        local screenPos, onScreen, depth = WorldToScreen(pos)
        if onScreen then
            minX = math.min(minX, screenPos.X)
            minY = math.min(minY, screenPos.Y)
            maxX = math.max(maxX, screenPos.X)
            maxY = math.max(maxY, screenPos.Y)
            avgDepth = avgDepth + depth
            onScreenCount = onScreenCount + 1
        end
    end

    if onScreenCount == 0 then return nil end

    avgDepth = avgDepth / onScreenCount

    return {
        TopLeft = Vector2.new(minX, minY),
        TopRight = Vector2.new(maxX, minY),
        BottomLeft = Vector2.new(minX, maxY),
        BottomRight = Vector2.new(maxX, maxY),
        Center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2),
        Width = maxX - minX,
        Height = maxY - minY,
        Depth = avgDepth,
    }
end

-- ═══════════════════════════════════════════════════════════════
-- ESP Object Creation
-- ═══════════════════════════════════════════════════════════════
local function CreateESP(player)
    local objects = {}

    -- Box lines (4 for full box, 8 for corner box)
    objects.BoxTop = Drawing.new("Line")
    objects.BoxBottom = Drawing.new("Line")
    objects.BoxLeft = Drawing.new("Line")
    objects.BoxRight = Drawing.new("Line")

    -- Corner box extra lines
    objects.BoxCornerTL1 = Drawing.new("Line")
    objects.BoxCornerTL2 = Drawing.new("Line")
    objects.BoxCornerTR1 = Drawing.new("Line")
    objects.BoxCornerTR2 = Drawing.new("Line")
    objects.BoxCornerBL1 = Drawing.new("Line")
    objects.BoxCornerBL2 = Drawing.new("Line")
    objects.BoxCornerBR1 = Drawing.new("Line")
    objects.BoxCornerBR2 = Drawing.new("Line")

    -- Box fill
    objects.BoxFill = Drawing.new("Square")

    -- Skeleton lines
    objects.SkeletonLines = {}
    for i = 1, 14 do
        objects.SkeletonLines[i] = Drawing.new("Line")
    end

    -- Head dot
    objects.HeadDot = Drawing.new("Circle")

    -- Name
    objects.Name = Drawing.new("Text")

    -- Health bar
    objects.HealthBarOutline = Drawing.new("Line")
    objects.HealthBar = Drawing.new("Line")
    objects.HealthText = Drawing.new("Text")

    -- Distance
    objects.Distance = Drawing.new("Text")

    -- Weapon
    objects.Weapon = Drawing.new("Text")

    -- Tracer
    objects.Tracer = Drawing.new("Line")

    -- Off-screen arrow
    objects.OffscreenArrow = Drawing.new("Triangle")

    -- Apply defaults
    local boxLines = {
        objects.BoxTop, objects.BoxBottom, objects.BoxLeft, objects.BoxRight,
        objects.BoxCornerTL1, objects.BoxCornerTL2,
        objects.BoxCornerTR1, objects.BoxCornerTR2,
        objects.BoxCornerBL1, objects.BoxCornerBL2,
        objects.BoxCornerBR1, objects.BoxCornerBR2,
    }
    for _, line in pairs(boxLines) do
        line.Thickness = Config.BoxThickness
        line.Transparency = 1
        line.Visible = false
    end

    objects.BoxFill.Filled = true
    objects.BoxFill.Transparency = Config.BoxFillTransparency
    objects.BoxFill.Visible = false

    for _, line in pairs(objects.SkeletonLines) do
        line.Thickness = Config.SkeletonThickness
        line.Transparency = 1
        line.Visible = false
    end

    objects.HeadDot.Thickness = 1
    objects.HeadDot.NumSides = 32
    objects.HeadDot.Filled = Config.HeadDotFilled
    objects.HeadDot.Radius = Config.HeadDotRadius
    objects.HeadDot.Transparency = 1
    objects.HeadDot.Visible = false

    objects.Name.Size = Config.NameSize
    objects.Name.Font = Config.NameFont
    objects.Name.Outline = Config.NameOutline
    objects.Name.OutlineColor = Config.NameOutlineColor
    objects.Name.Center = true
    objects.Name.Visible = false

    objects.HealthBarOutline.Thickness = 3
    objects.HealthBarOutline.Transparency = 1
    objects.HealthBarOutline.Visible = false

    objects.HealthBar.Thickness = 1
    objects.HealthBar.Transparency = 1
    objects.HealthBar.Visible = false

    objects.HealthText.Size = Config.HealthTextSize
    objects.HealthText.Font = Config.HealthTextFont
    objects.HealthText.Center = true
    objects.HealthText.Outline = true
    objects.HealthText.OutlineColor = Color3.fromRGB(0, 0, 0)
    objects.HealthText.Visible = false

    objects.Distance.Size = Config.DistanceSize
    objects.Distance.Font = Config.DistanceFont
    objects.Distance.Center = true
    objects.Distance.Outline = true
    objects.Distance.OutlineColor = Color3.fromRGB(0, 0, 0)
    objects.Distance.Visible = false

    objects.Weapon.Size = Config.WeaponSize
    objects.Weapon.Font = Config.WeaponFont
    objects.Weapon.Center = true
    objects.Weapon.Outline = true
    objects.Weapon.OutlineColor = Color3.fromRGB(0, 0, 0)
    objects.Weapon.Visible = false

    objects.Tracer.Thickness = Config.TracerThickness
    objects.Tracer.Transparency = 1
    objects.Tracer.Visible = false

    objects.OffscreenArrow.Filled = true
    objects.OffscreenArrow.Transparency = 1
    objects.OffscreenArrow.Visible = false

    ESPObjects[player] = objects
end

local function RemoveESP(player)
    local objects = ESPObjects[player]
    if not objects then return end
    for _, obj in pairs(objects) do
        if type(obj) == "table" then
            for _, line in pairs(obj) do
                pcall(function() line:Remove() end)
            end
        else
            pcall(function() obj:Remove() end)
        end
    end
    ESPObjects[player] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- Chams (Highlight instances)
-- ═══════════════════════════════════════════════════════════════
local function CreateChams(player)
    local char = player.Character
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Cham"
    highlight.FillColor = Config.ChamsFillColor
    highlight.FillTransparency = Config.ChamsFillTransparency
    highlight.OutlineColor = Config.ChamsOutlineColor
    highlight.OutlineTransparency = Config.ChamsOutlineTransparency
    highlight.Adornee = char
    highlight.Parent = char

    ChamsObjects[player] = highlight
end

local function RemoveChams(player)
    local cham = ChamsObjects[player]
    if cham then
        pcall(function() cham:Destroy() end)
        ChamsObjects[player] = nil
    end
end

local function UpdateChams(player)
    if not Config.ChamsEnabled then
        RemoveChams(player)
        return
    end

    local char = player.Character
    if not char or player == LocalPlayer or IsTeamMate(player) then
        RemoveChams(player)
        return
    end

    local cham = ChamsObjects[player]
    if not cham or cham.Parent ~= char then
        RemoveChams(player)
        CreateChams(player)
        cham = ChamsObjects[player]
    end

    if cham then
        cham.FillColor = Config.ChamsFillColor
        cham.FillTransparency = Config.ChamsFillTransparency
        cham.OutlineColor = Config.ChamsOutlineColor
        cham.OutlineTransparency = Config.ChamsOutlineTransparency
        cham.Adornee = char
        cham.Enabled = Config.Enabled
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ESP Update
-- ═══════════════════════════════════════════════════════════════
local function HideAllObjects(objects)
    for key, obj in pairs(objects) do
        if key == "SkeletonLines" then
            for _, line in pairs(obj) do
                line.Visible = false
            end
        else
            pcall(function() obj.Visible = false end)
        end
    end
end

local function UpdateESP(player)
    local objects = ESPObjects[player]
    if not objects then return end

    if not Config.Enabled or player == LocalPlayer or IsTeamMate(player) then
        HideAllObjects(objects)
        return
    end

    local char, hrp, head, humanoid = GetCharacter(player)
    if not char then
        HideAllObjects(objects)
        return
    end

    local box = GetBoundingBox(char)
    if not box then
        HideAllObjects(objects)
        return
    end

    -- Distance check
    if Config.MaxDistance > 0 and box.Depth > Config.MaxDistance then
        HideAllObjects(objects)
        return
    end

    local color = GetPlayerColor(player)
    local healthRatio = humanoid.Health / humanoid.MaxHealth

    -- ── Box ESP ──
    if Config.BoxEnabled then
        if Config.BoxStyle == "Full" then
            objects.BoxTop.From = box.TopLeft
            objects.BoxTop.To = box.TopRight
            objects.BoxTop.Color = color
            objects.BoxTop.Visible = true

            objects.BoxBottom.From = box.BottomLeft
            objects.BoxBottom.To = box.BottomRight
            objects.BoxBottom.Color = color
            objects.BoxBottom.Visible = true

            objects.BoxLeft.From = box.TopLeft
            objects.BoxLeft.To = box.BottomLeft
            objects.BoxLeft.Color = color
            objects.BoxLeft.Visible = true

            objects.BoxRight.From = box.TopRight
            objects.BoxRight.To = box.BottomRight
            objects.BoxRight.Color = color
            objects.BoxRight.Visible = true

            -- Hide corner lines
            for _, key in pairs({"BoxCornerTL1","BoxCornerTL2","BoxCornerTR1","BoxCornerTR2","BoxCornerBL1","BoxCornerBL2","BoxCornerBR1","BoxCornerBR2"}) do
                objects[key].Visible = false
            end
        else -- Corner box
            local cornerLen = math.min(box.Width, box.Height) * 0.25

            -- Hide full box lines
            objects.BoxTop.Visible = false
            objects.BoxBottom.Visible = false
            objects.BoxLeft.Visible = false
            objects.BoxRight.Visible = false

            -- Top-left corner
            objects.BoxCornerTL1.From = box.TopLeft
            objects.BoxCornerTL1.To = Vector2.new(box.TopLeft.X + cornerLen, box.TopLeft.Y)
            objects.BoxCornerTL1.Color = color
            objects.BoxCornerTL1.Visible = true

            objects.BoxCornerTL2.From = box.TopLeft
            objects.BoxCornerTL2.To = Vector2.new(box.TopLeft.X, box.TopLeft.Y + cornerLen)
            objects.BoxCornerTL2.Color = color
            objects.BoxCornerTL2.Visible = true

            -- Top-right corner
            objects.BoxCornerTR1.From = box.TopRight
            objects.BoxCornerTR1.To = Vector2.new(box.TopRight.X - cornerLen, box.TopRight.Y)
            objects.BoxCornerTR1.Color = color
            objects.BoxCornerTR1.Visible = true

            objects.BoxCornerTR2.From = box.TopRight
            objects.BoxCornerTR2.To = Vector2.new(box.TopRight.X, box.TopRight.Y + cornerLen)
            objects.BoxCornerTR2.Color = color
            objects.BoxCornerTR2.Visible = true

            -- Bottom-left corner
            objects.BoxCornerBL1.From = box.BottomLeft
            objects.BoxCornerBL1.To = Vector2.new(box.BottomLeft.X + cornerLen, box.BottomLeft.Y)
            objects.BoxCornerBL1.Color = color
            objects.BoxCornerBL1.Visible = true

            objects.BoxCornerBL2.From = box.BottomLeft
            objects.BoxCornerBL2.To = Vector2.new(box.BottomLeft.X, box.BottomLeft.Y - cornerLen)
            objects.BoxCornerBL2.Color = color
            objects.BoxCornerBL2.Visible = true

            -- Bottom-right corner
            objects.BoxCornerBR1.From = box.BottomRight
            objects.BoxCornerBR1.To = Vector2.new(box.BottomRight.X - cornerLen, box.BottomRight.Y)
            objects.BoxCornerBR1.Color = color
            objects.BoxCornerBR1.Visible = true

            objects.BoxCornerBR2.From = box.BottomRight
            objects.BoxCornerBR2.To = Vector2.new(box.BottomRight.X, box.BottomRight.Y - cornerLen)
            objects.BoxCornerBR2.Color = color
            objects.BoxCornerBR2.Visible = true
        end

        -- Box fill
        if Config.BoxFilled then
            objects.BoxFill.Position = box.TopLeft
            objects.BoxFill.Size = Vector2.new(box.Width, box.Height)
            objects.BoxFill.Color = color
            objects.BoxFill.Transparency = Config.BoxFillTransparency
            objects.BoxFill.Visible = true
        else
            objects.BoxFill.Visible = false
        end
    else
        -- Hide all box lines
        objects.BoxTop.Visible = false
        objects.BoxBottom.Visible = false
        objects.BoxLeft.Visible = false
        objects.BoxRight.Visible = false
        objects.BoxFill.Visible = false
        for _, key in pairs({"BoxCornerTL1","BoxCornerTL2","BoxCornerTR1","BoxCornerTR2","BoxCornerBL1","BoxCornerBL2","BoxCornerBR1","BoxCornerBR2"}) do
            objects[key].Visible = false
        end
    end

    -- ── Skeleton ESP ──
    if Config.SkeletonEnabled then
        local pairs = IsR6(char) and SkeletonPairsR6 or SkeletonPairs
        for i, pair in pairs(pairs) do
            local line = objects.SkeletonLines[i]
            if not line then break end

            local partA = char:FindFirstChild(pair[1])
            local partB = char:FindFirstChild(pair[2])

            if partA and partB then
                local posA, onScreenA = WorldToScreen(partA.Position)
                local posB, onScreenB = WorldToScreen(partB.Position)
                if onScreenA and onScreenB then
                    line.From = posA
                    line.To = posB
                    line.Color = Config.SkeletonColor
                    line.Thickness = Config.SkeletonThickness
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
        -- Hide unused skeleton lines
        for i = #pairs + 1, #objects.SkeletonLines do
            objects.SkeletonLines[i].Visible = false
        end
    else
        for _, line in pairs(objects.SkeletonLines) do
            line.Visible = false
        end
    end

    -- ── Head Dot ──
    if Config.HeadDotEnabled then
        local headPos, headOnScreen = WorldToScreen(head.Position)
        if headOnScreen then
            objects.HeadDot.Position = headPos
            objects.HeadDot.Color = Config.HeadDotColor
            objects.HeadDot.Radius = Config.HeadDotRadius
            objects.HeadDot.Filled = Config.HeadDotFilled
            objects.HeadDot.Visible = true
        else
            objects.HeadDot.Visible = false
        end
    else
        objects.HeadDot.Visible = false
    end

    -- ── Name ESP ──
    if Config.NameEnabled then
        objects.Name.Position = Vector2.new(box.Center.X, box.TopLeft.Y - 16)
        objects.Name.Text = player.DisplayName
        objects.Name.Color = color
        objects.Name.Visible = true
    else
        objects.Name.Visible = false
    end

    -- ── Health ESP ──
    if Config.HealthEnabled then
        local barX = box.TopLeft.X - 5
        local barTopY = box.TopLeft.Y
        local barBottomY = box.BottomLeft.Y
        local barHeight = barBottomY - barTopY

        objects.HealthBarOutline.From = Vector2.new(barX - 1, barTopY)
        objects.HealthBarOutline.To = Vector2.new(barX - 1, barBottomY)
        objects.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        objects.HealthBarOutline.Visible = true

        local healthColor = Color3.fromRGB(
            255 * (1 - healthRatio),
            255 * healthRatio,
            0
        )
        objects.HealthBar.From = Vector2.new(barX - 1, barBottomY)
        objects.HealthBar.To = Vector2.new(barX - 1, barBottomY - barHeight * healthRatio)
        objects.HealthBar.Color = healthColor
        objects.HealthBar.Visible = true

        objects.HealthText.Position = Vector2.new(barX - 1, barTopY - 14)
        objects.HealthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
        objects.HealthText.Color = Config.HealthTextColor
        objects.HealthText.Visible = true
    else
        objects.HealthBarOutline.Visible = false
        objects.HealthBar.Visible = false
        objects.HealthText.Visible = false
    end

    -- ── Distance ESP ──
    if Config.DistanceEnabled then
        objects.Distance.Position = Vector2.new(box.Center.X, box.BottomLeft.Y + 2)
        objects.Distance.Text = math.floor(box.Depth) .. "m"
        objects.Distance.Color = color
        objects.Distance.Visible = true
    else
        objects.Distance.Visible = false
    end

    -- ── Weapon ESP ──
    if Config.WeaponEnabled then
        local tool = GetHeldTool(player)
        if tool then
            objects.Weapon.Position = Vector2.new(box.Center.X, box.BottomLeft.Y + 14)
            objects.Weapon.Text = tool
            objects.Weapon.Color = Config.WeaponColor
            objects.Weapon.Visible = true
        else
            objects.Weapon.Visible = false
        end
    else
        objects.Weapon.Visible = false
    end

    -- ── Tracer ESP ──
    if Config.TracerEnabled then
        local origin
        if Config.TracerOrigin == "Mouse" then
            local mousePos = UserInputService:GetMouseLocation()
            origin = Vector2.new(mousePos.X, mousePos.Y)
        else
            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        end
        objects.Tracer.From = origin
        objects.Tracer.To = Vector2.new(box.Center.X, box.BottomLeft.Y)
        objects.Tracer.Color = color
        objects.Tracer.Visible = true
    else
        objects.Tracer.Visible = false
    end

    -- ── Off-screen Arrow ──
    if Config.OffscreenEnabled then
        local hrpPos, hrpOnScreen = WorldToScreen(hrp.Position)
        if not hrpOnScreen then
            local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local inset = GuiService:GetGuiInset()
            local safeArea = {
                Min = Vector2.new(inset.X + Config.OffscreenDistance, inset.Y + Config.OffscreenDistance),
                Max = Vector2.new(Camera.ViewportSize.X - Config.OffscreenDistance, Camera.ViewportSize.Y - Config.OffscreenDistance),
            }

            -- Direction from center to target
            local dir = (hrpPos - screenCenter).Unit
            local angle = math.atan2(dir.Y, dir.X)

            -- Clamp position to screen edges
            local edgePos = hrpPos
            local t = math.huge

            if dir.X ~= 0 then
                local tx = ((dir.X > 0 and safeArea.Max.X or safeArea.Min.X) - screenCenter.X) / dir.X
                if tx > 0 then t = math.min(t, tx) end
            end
            if dir.Y ~= 0 then
                local ty = ((dir.Y > 0 and safeArea.Max.Y or safeArea.Min.Y) - screenCenter.Y) / dir.Y
                if ty > 0 then t = math.min(t, ty) end
            end

            edgePos = screenCenter + dir * t

            -- Draw triangle pointing toward target
            local size = Config.OffscreenSize
            local tip = edgePos + dir * size
            local left = edgePos + Vector2.new(math.cos(angle + 2.5), math.sin(angle + 2.5)) * size * 0.6
            local right = edgePos + Vector2.new(math.cos(angle - 2.5), math.sin(angle - 2.5)) * size * 0.6

            objects.OffscreenArrow.PointA = tip
            objects.OffscreenArrow.PointB = left
            objects.OffscreenArrow.PointC = right
            objects.OffscreenArrow.Color = color
            objects.OffscreenArrow.Visible = true
        else
            objects.OffscreenArrow.Visible = false
        end
    else
        objects.OffscreenArrow.Visible = false
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Aimbot
-- ═══════════════════════════════════════════════════════════════
local function GetClosestPlayerToMouse()
    local closestPlayer = nil
    local shortestDist = Config.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.AimbotTeamCheck and IsTeamMate(player) then continue end

        local char, hrp, head, humanoid = GetCharacter(player)
        if not char then continue end

        local targetPart = Config.AimbotPart == "Head" and head or hrp
        if not targetPart then continue end

        local screenPos, onScreen, depth = WorldToScreen(targetPart.Position)
        if not onScreen then continue end

        if Config.AimbotMaxDistance > 0 and depth > Config.AimbotMaxDistance then continue end

        if Config.AimbotVisibilityCheck then
            local rayOrigin = Camera.CFrame.Position
            local rayDirection = (targetPart.Position - rayOrigin).Unit * 1000
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {LocalPlayer.Character or nil}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
            if result and result.Instance then
                local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
                if hitChar ~= char then continue end
            end
        end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < shortestDist then
            shortestDist = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

local function UpdateAimbot()
    -- FOV circle
    if Config.AimbotShowFOV and Config.AimbotEnabled then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Color = Config.AimbotFOVColor
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    if not Config.AimbotEnabled then
        AimbotLocked = nil
        return
    end

    local isActive = (Config.AimbotMode == "Hold" and AimbotHolding) or (Config.AimbotMode == "Toggle" and AimbotToggled)
    if not isActive then
        AimbotLocked = nil
        return
    end

    if not AimbotLocked then
        AimbotLocked = GetClosestPlayerToMouse()
    end

    if AimbotLocked then
        local char, hrp, head, humanoid = GetCharacter(AimbotLocked)
        if not char then
            AimbotLocked = nil
            return
        end

        local targetPart = Config.AimbotPart == "Head" and head or hrp
        if not targetPart then
            AimbotLocked = nil
            return
        end

        local screenPos, onScreen = WorldToScreen(targetPart.Position)
        if not onScreen then
            AimbotLocked = nil
            return
        end

        local mousePos = UserInputService:GetMouseLocation()
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist > Config.AimbotFOV then
            AimbotLocked = nil
            return
        end

        -- Prediction
        local targetPos = targetPart.Position
        if Config.AimbotPrediction > 0 and hrp then
            local velocity = hrp.AssemblyLinearVelocity
            targetPos = targetPos + velocity * Config.AimbotPrediction / 60
        end

        local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.AimbotSmoothness)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Triggerbot
-- ═══════════════════════════════════════════════════════════════
local function UpdateTriggerbot()
    if not Config.TriggerbotEnabled or not TriggerbotHolding then return end

    local now = tick()
    if now - LastTriggerTime < Config.TriggerbotDelay / 1000 then return end

    local mousePos = UserInputService:GetMouseLocation()
    local rayOrigin = Camera.CFrame.Position
    local rayDirection = (Camera.CFrame.LookVector * 1000)

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character or nil}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        if hitChar then
            local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                if Config.TriggerbotTeamCheck and IsTeamMate(hitPlayer) then return end
                local humanoid = hitChar:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    -- Simulate click
                    mouse1click()
                    LastTriggerTime = now
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Crosshair
-- ═══════════════════════════════════════════════════════════════
local function UpdateCrosshair()
    if not Config.CrosshairEnabled then
        for _, line in pairs(CrosshairLines) do
            line.Visible = false
        end
        CrosshairDot.Visible = false
        return
    end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local size = Config.CrosshairSize
    local gap = Config.CrosshairGap

    CrosshairLines.Top.From = Vector2.new(center.X, center.Y - gap - size)
    CrosshairLines.Top.To = Vector2.new(center.X, center.Y - gap)
    CrosshairLines.Top.Color = Config.CrosshairColor
    CrosshairLines.Top.Thickness = Config.CrosshairThickness
    CrosshairLines.Top.Visible = true

    CrosshairLines.Bottom.From = Vector2.new(center.X, center.Y + gap)
    CrosshairLines.Bottom.To = Vector2.new(center.X, center.Y + gap + size)
    CrosshairLines.Bottom.Color = Config.CrosshairColor
    CrosshairLines.Bottom.Thickness = Config.CrosshairThickness
    CrosshairLines.Bottom.Visible = true

    CrosshairLines.Left.From = Vector2.new(center.X - gap - size, center.Y)
    CrosshairLines.Left.To = Vector2.new(center.X - gap, center.Y)
    CrosshairLines.Left.Color = Config.CrosshairColor
    CrosshairLines.Left.Thickness = Config.CrosshairThickness
    CrosshairLines.Left.Visible = true

    CrosshairLines.Right.From = Vector2.new(center.X + gap, center.Y)
    CrosshairLines.Right.To = Vector2.new(center.X + gap + size, center.Y)
    CrosshairLines.Right.Color = Config.CrosshairColor
    CrosshairLines.Right.Thickness = Config.CrosshairThickness
    CrosshairLines.Right.Visible = true

    if Config.CrosshairDot then
        CrosshairDot.Position = center
        CrosshairDot.Color = Config.CrosshairColor
        CrosshairDot.Radius = 1
        CrosshairDot.Visible = true
    else
        CrosshairDot.Visible = false
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Item ESP
-- ═══════════════════════════════════════════════════════════════
local function CreateItemESP()
    if not Config.HighlightItems then return end

    for _, obj in pairs(ItemESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    ItemESPObjects = {}

    for _, descendant in pairs(Workspace:GetDescendants()) do
        if descendant:IsA("BasePart") or descendant:IsA("Model") then
            local name = descendant.Name
            local matched = false
            for _, keyword in pairs(Config.HighlightItemNames) do
                if name:lower():find(keyword:lower()) then
                    matched = true
                    break
                end
            end

            if matched then
                local highlight = Instance.new("Highlight")
                highlight.Name = "ESP_ItemHighlight"
                highlight.FillColor = Config.HighlightItemColor
                highlight.FillTransparency = 0.5
                highlight.OutlineColor = Config.HighlightItemColor
                highlight.OutlineTransparency = 0
                highlight.Adornee = descendant:IsA("Model") and descendant or descendant.Parent
                highlight.Parent = descendant

                table.insert(ItemESPObjects, highlight)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Input Handling
-- ═══════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- ESP toggle
    if input.KeyCode == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
        if not Config.Enabled then
            for player, objects in pairs(ESPObjects) do
                HideAllObjects(objects)
            end
            for _, highlight in pairs(ItemESPObjects) do
                pcall(function() highlight.Enabled = false end)
            end
        else
            for _, highlight in pairs(ItemESPObjects) do
                pcall(function() highlight.Enabled = true end)
            end
        end
    end

    -- Aimbot hold key
    if input.KeyCode == Config.AimbotKey then
        if Config.AimbotMode == "Hold" then
            AimbotHolding = true
        else
            AimbotToggled = not AimbotToggled
            if not AimbotToggled then AimbotLocked = nil end
        end
    end

    -- Triggerbot key
    if input.KeyCode == Config.TriggerbotKey then
        TriggerbotHolding = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Config.AimbotKey and Config.AimbotMode == "Hold" then
        AimbotHolding = false
        AimbotLocked = nil
    end
    if input.KeyCode == Config.TriggerbotKey then
        TriggerbotHolding = false
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Player Event Handlers
-- ═══════════════════════════════════════════════════════════════
Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    RemoveChams(player)
end)

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- Main Render Loop
-- ═══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    for player, objects in pairs(ESPObjects) do
        UpdateESP(player)
        UpdateChams(player)
    end
    UpdateAimbot()
    UpdateTriggerbot()
    UpdateCrosshair()
end)

-- Item ESP refresh
task.spawn(function()
    while true do
        if Config.HighlightItems and Config.Enabled then
            CreateItemESP()
        end
        task.wait(5)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Rayfield UI
-- ═══════════════════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Universal ESP + Aimbot v2",
    LoadingTitle = "Universal v2",
    LoadingSubtitle = "Loading...",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UniversalESPv2",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ── Tab: Player ESP ──
local TabPlayers = Window:CreateTab("Player ESP", 4483362458)

TabPlayers:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Config.Enabled,
    Flag = "EnableESP",
    Callback = function(value)
        Config.Enabled = value
        if not value then
            for player, objects in pairs(ESPObjects) do
                HideAllObjects(objects)
            end
            for _, highlight in pairs(ItemESPObjects) do
                pcall(function() highlight.Enabled = false end)
            end
        else
            for _, highlight in pairs(ItemESPObjects) do
                pcall(function() highlight.Enabled = true end)
            end
        end
    end,
})

TabPlayers:CreateKeybind({
    Name = "Toggle Keybind",
    CurrentKeybind = Config.ToggleKey,
    HoldToInteract = false,
    Flag = "ToggleKey",
    Callback = function(keybind)
        Config.ToggleKey = keybind
    end,
})

TabPlayers:CreateSection("Box")

TabPlayers:CreateToggle({
    Name = "Box ESP",
    CurrentValue = Config.BoxEnabled,
    Flag = "BoxESP",
    Callback = function(value) Config.BoxEnabled = value end,
})

TabPlayers:CreateDropdown({
    Name = "Box Style",
    Options = {"Full", "Corner"},
    CurrentOption = {Config.BoxStyle},
    MultipleOptions = false,
    Flag = "BoxStyle",
    Callback = function(value) Config.BoxStyle = value[1] or value end,
})

TabPlayers:CreateToggle({
    Name = "Filled Box",
    CurrentValue = Config.BoxFilled,
    Flag = "BoxFilled",
    Callback = function(value) Config.BoxFilled = value end,
})

TabPlayers:CreateSlider({
    Name = "Box Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.BoxThickness,
    Flag = "BoxThickness",
    Callback = function(value)
        Config.BoxThickness = value
        for player, objects in pairs(ESPObjects) do
            for _, key in pairs({"BoxTop","BoxBottom","BoxLeft","BoxRight","BoxCornerTL1","BoxCornerTL2","BoxCornerTR1","BoxCornerTR2","BoxCornerBL1","BoxCornerBL2","BoxCornerBR1","BoxCornerBR2"}) do
                objects[key].Thickness = value
            end
        end
    end,
})

TabPlayers:CreateSlider({
    Name = "Box Fill Transparency",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = Config.BoxFillTransparency,
    Flag = "BoxFillTransparency",
    Callback = function(value) Config.BoxFillTransparency = value end,
})

TabPlayers:CreateColorPicker({
    Name = "Box Color",
    Color = Config.BoxColor,
    Flag = "BoxColor",
    Callback = function(value) Config.BoxColor = value end,
})

TabPlayers:CreateSection("Skeleton")

TabPlayers:CreateToggle({
    Name = "Skeleton ESP",
    CurrentValue = Config.SkeletonEnabled,
    Flag = "SkeletonESP",
    Callback = function(value) Config.SkeletonEnabled = value end,
})

TabPlayers:CreateSlider({
    Name = "Skeleton Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.SkeletonThickness,
    Flag = "SkeletonThickness",
    Callback = function(value)
        Config.SkeletonThickness = value
        for player, objects in pairs(ESPObjects) do
            for _, line in pairs(objects.SkeletonLines) do
                line.Thickness = value
            end
        end
    end,
})

TabPlayers:CreateColorPicker({
    Name = "Skeleton Color",
    Color = Config.SkeletonColor,
    Flag = "SkeletonColor",
    Callback = function(value) Config.SkeletonColor = value end,
})

TabPlayers:CreateSection("Head Dot")

TabPlayers:CreateToggle({
    Name = "Head Dot",
    CurrentValue = Config.HeadDotEnabled,
    Flag = "HeadDot",
    Callback = function(value) Config.HeadDotEnabled = value end,
})

TabPlayers:CreateToggle({
    Name = "Head Dot Filled",
    CurrentValue = Config.HeadDotFilled,
    Flag = "HeadDotFilled",
    Callback = function(value)
        Config.HeadDotFilled = value
        for player, objects in pairs(ESPObjects) do
            objects.HeadDot.Filled = value
        end
    end,
})

TabPlayers:CreateSlider({
    Name = "Head Dot Radius",
    Range = {2, 20},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.HeadDotRadius,
    Flag = "HeadDotRadius",
    Callback = function(value)
        Config.HeadDotRadius = value
        for player, objects in pairs(ESPObjects) do
            objects.HeadDot.Radius = value
        end
    end,
})

TabPlayers:CreateColorPicker({
    Name = "Head Dot Color",
    Color = Config.HeadDotColor,
    Flag = "HeadDotColor",
    Callback = function(value) Config.HeadDotColor = value end,
})

TabPlayers:CreateSection("Name")

TabPlayers:CreateToggle({
    Name = "Name ESP",
    CurrentValue = Config.NameEnabled,
    Flag = "NameESP",
    Callback = function(value) Config.NameEnabled = value end,
})

TabPlayers:CreateSlider({
    Name = "Name Size",
    Range = {8, 24},
    Increment = 1,
    Suffix = "pt",
    CurrentValue = Config.NameSize,
    Flag = "NameSize",
    Callback = function(value)
        Config.NameSize = value
        for player, objects in pairs(ESPObjects) do
            objects.Name.Size = value
        end
    end,
})

TabPlayers:CreateToggle({
    Name = "Name Outline",
    CurrentValue = Config.NameOutline,
    Flag = "NameOutline",
    Callback = function(value)
        Config.NameOutline = value
        for player, objects in pairs(ESPObjects) do
            objects.Name.Outline = value
        end
    end,
})

TabPlayers:CreateColorPicker({
    Name = "Name Color",
    Color = Config.NameColor,
    Flag = "NameColor",
    Callback = function(value) Config.NameColor = value end,
})

TabPlayers:CreateSection("Health")

TabPlayers:CreateToggle({
    Name = "Health ESP",
    CurrentValue = Config.HealthEnabled,
    Flag = "HealthESP",
    Callback = function(value) Config.HealthEnabled = value end,
})

TabPlayers:CreateSlider({
    Name = "Health Text Size",
    Range = {8, 20},
    Increment = 1,
    Suffix = "pt",
    CurrentValue = Config.HealthTextSize,
    Flag = "HealthTextSize",
    Callback = function(value)
        Config.HealthTextSize = value
        for player, objects in pairs(ESPObjects) do
            objects.HealthText.Size = value
        end
    end,
})

TabPlayers:CreateColorPicker({
    Name = "Health Text Color",
    Color = Config.HealthTextColor,
    Flag = "HealthTextColor",
    Callback = function(value) Config.HealthTextColor = value end,
})

TabPlayers:CreateSection("Distance")

TabPlayers:CreateToggle({
    Name = "Distance ESP",
    CurrentValue = Config.DistanceEnabled,
    Flag = "DistanceESP",
    Callback = function(value) Config.DistanceEnabled = value end,
})

TabPlayers:CreateSlider({
    Name = "Distance Text Size",
    Range = {8, 20},
    Increment = 1,
    Suffix = "pt",
    CurrentValue = Config.DistanceSize,
    Flag = "DistanceSize",
    Callback = function(value)
        Config.DistanceSize = value
        for player, objects in pairs(ESPObjects) do
            objects.Distance.Size = value
        end
    end,
})

TabPlayers:CreateColorPicker({
    Name = "Distance Color",
    Color = Config.DistanceColor,
    Flag = "DistanceColor",
    Callback = function(value) Config.DistanceColor = value end,
})

TabPlayers:CreateSection("Weapon")

TabPlayers:CreateToggle({
    Name = "Weapon ESP",
    CurrentValue = Config.WeaponEnabled,
    Flag = "WeaponESP",
    Callback = function(value) Config.WeaponEnabled = value end,
})

TabPlayers:CreateColorPicker({
    Name = "Weapon Color",
    Color = Config.WeaponColor,
    Flag = "WeaponColor",
    Callback = function(value) Config.WeaponColor = value end,
})

-- ── Tab: Tracers ──
local TabTracers = Window:CreateTab("Tracers", 4483362458)

TabTracers:CreateToggle({
    Name = "Tracer ESP",
    CurrentValue = Config.TracerEnabled,
    Flag = "TracerESP",
    Callback = function(value) Config.TracerEnabled = value end,
})

TabTracers:CreateSlider({
    Name = "Tracer Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.TracerThickness,
    Flag = "TracerThickness",
    Callback = function(value)
        Config.TracerThickness = value
        for player, objects in pairs(ESPObjects) do
            objects.Tracer.Thickness = value
        end
    end,
})

TabTracers:CreateDropdown({
    Name = "Tracer Origin",
    Options = {"Bottom", "Mouse"},
    CurrentOption = {Config.TracerOrigin},
    MultipleOptions = false,
    Flag = "TracerOrigin",
    Callback = function(value) Config.TracerOrigin = value[1] or value end,
})

TabTracers:CreateColorPicker({
    Name = "Tracer Color",
    Color = Config.TracerColor,
    Flag = "TracerColor",
    Callback = function(value) Config.TracerColor = value end,
})

-- ── Tab: Off-screen ──
local TabOffscreen = Window:CreateTab("Off-screen", 4483362458)

TabOffscreen:CreateToggle({
    Name = "Off-screen Arrows",
    CurrentValue = Config.OffscreenEnabled,
    Flag = "OffscreenArrows",
    Callback = function(value) Config.OffscreenEnabled = value end,
})

TabOffscreen:CreateSlider({
    Name = "Arrow Distance from Edge",
    Range = {50, 300},
    Increment = 10,
    Suffix = "px",
    CurrentValue = Config.OffscreenDistance,
    Flag = "OffscreenDistance",
    Callback = function(value) Config.OffscreenDistance = value end,
})

TabOffscreen:CreateSlider({
    Name = "Arrow Size",
    Range = {5, 30},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.OffscreenSize,
    Flag = "OffscreenSize",
    Callback = function(value) Config.OffscreenSize = value end,
})

TabOffscreen:CreateColorPicker({
    Name = "Arrow Color",
    Color = Config.OffscreenColor,
    Flag = "OffscreenColor",
    Callback = function(value) Config.OffscreenColor = value end,
})

-- ── Tab: Chams ──
local TabChams = Window:CreateTab("Chams", 4483362458)

TabChams:CreateToggle({
    Name = "Chams / Highlight",
    CurrentValue = Config.ChamsEnabled,
    Flag = "ChamsEnabled",
    Callback = function(value)
        Config.ChamsEnabled = value
        if not value then
            for player, _ in pairs(ChamsObjects) do
                RemoveChams(player)
            end
        end
    end,
})

TabChams:CreateColorPicker({
    Name = "Fill Color",
    Color = Config.ChamsFillColor,
    Flag = "ChamsFillColor",
    Callback = function(value) Config.ChamsFillColor = value end,
})

TabChams:CreateColorPicker({
    Name = "Outline Color",
    Color = Config.ChamsOutlineColor,
    Flag = "ChamsOutlineColor",
    Callback = function(value) Config.ChamsOutlineColor = value end,
})

TabChams:CreateSlider({
    Name = "Fill Transparency",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = Config.ChamsFillTransparency,
    Flag = "ChamsFillTransparency",
    Callback = function(value) Config.ChamsFillTransparency = value end,
})

TabChams:CreateSlider({
    Name = "Outline Transparency",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = Config.ChamsOutlineTransparency,
    Flag = "ChamsOutlineTransparency",
    Callback = function(value) Config.ChamsOutlineTransparency = value end,
})

-- ── Tab: Aimbot ──
local TabAimbot = Window:CreateTab("Aimbot", 4483362458)

TabAimbot:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = Config.AimbotEnabled,
    Flag = "AimbotEnabled",
    Callback = function(value) Config.AimbotEnabled = value end,
})

TabAimbot:CreateDropdown({
    Name = "Aimbot Mode",
    Options = {"Hold", "Toggle"},
    CurrentOption = {Config.AimbotMode},
    MultipleOptions = false,
    Flag = "AimbotMode",
    Callback = function(value)
        Config.AimbotMode = value[1] or value
        AimbotToggled = false
        AimbotHolding = false
        AimbotLocked = nil
    end,
})

TabAimbot:CreateKeybind({
    Name = "Aimbot Key",
    CurrentKeybind = Config.AimbotKey,
    HoldToInteract = false,
    Flag = "AimbotKey",
    Callback = function(keybind) Config.AimbotKey = keybind end,
})

TabAimbot:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart"},
    CurrentOption = {Config.AimbotPart},
    MultipleOptions = false,
    Flag = "AimbotPart",
    Callback = function(value) Config.AimbotPart = value[1] or value end,
})

TabAimbot:CreateSlider({
    Name = "Smoothness",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = Config.AimbotSmoothness,
    Flag = "AimbotSmoothness",
    Callback = function(value) Config.AimbotSmoothness = value end,
})

TabAimbot:CreateSlider({
    Name = "FOV Size",
    Range = {20, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = Config.AimbotFOV,
    Flag = "AimbotFOV",
    Callback = function(value) Config.AimbotFOV = value end,
})

TabAimbot:CreateSlider({
    Name = "Prediction",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = Config.AimbotPrediction,
    Flag = "AimbotPrediction",
    Callback = function(value) Config.AimbotPrediction = value end,
})

TabAimbot:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Config.AimbotShowFOV,
    Flag = "AimbotShowFOV",
    Callback = function(value) Config.AimbotShowFOV = value end,
})

TabAimbot:CreateColorPicker({
    Name = "FOV Circle Color",
    Color = Config.AimbotFOVColor,
    Flag = "AimbotFOVColor",
    Callback = function(value) Config.AimbotFOVColor = value end,
})

TabAimbot:CreateToggle({
    Name = "Team Check",
    CurrentValue = Config.AimbotTeamCheck,
    Flag = "AimbotTeamCheck",
    Callback = function(value) Config.AimbotTeamCheck = value end,
})

TabAimbot:CreateSlider({
    Name = "Max Distance (0 = Unlimited)",
    Range = {0, 5000},
    Increment = 100,
    Suffix = "studs",
    CurrentValue = Config.AimbotMaxDistance,
    Flag = "AimbotMaxDistance",
    Callback = function(value) Config.AimbotMaxDistance = value end,
})

TabAimbot:CreateToggle({
    Name = "Visibility Check",
    CurrentValue = Config.AimbotVisibilityCheck,
    Flag = "AimbotVisibilityCheck",
    Callback = function(value) Config.AimbotVisibilityCheck = value end,
})

-- ── Tab: Triggerbot ──
local TabTriggerbot = Window:CreateTab("Triggerbot", 4483362458)

TabTriggerbot:CreateToggle({
    Name = "Enable Triggerbot",
    CurrentValue = Config.TriggerbotEnabled,
    Flag = "TriggerbotEnabled",
    Callback = function(value) Config.TriggerbotEnabled = value end,
})

TabTriggerbot:CreateKeybind({
    Name = "Triggerbot Key (Hold)",
    CurrentKeybind = Config.TriggerbotKey,
    HoldToInteract = true,
    Flag = "TriggerbotKey",
    Callback = function(keybind) Config.TriggerbotKey = keybind end,
})

TabTriggerbot:CreateSlider({
    Name = "Delay (ms)",
    Range = {0, 500},
    Increment = 10,
    Suffix = "ms",
    CurrentValue = Config.TriggerbotDelay,
    Flag = "TriggerbotDelay",
    Callback = function(value) Config.TriggerbotDelay = value end,
})

TabTriggerbot:CreateToggle({
    Name = "Team Check",
    CurrentValue = Config.TriggerbotTeamCheck,
    Flag = "TriggerbotTeamCheck",
    Callback = function(value) Config.TriggerbotTeamCheck = value end,
})

-- ── Tab: Crosshair ──
local TabCrosshair = Window:CreateTab("Crosshair", 4483362458)

TabCrosshair:CreateToggle({
    Name = "Custom Crosshair",
    CurrentValue = Config.CrosshairEnabled,
    Flag = "CrosshairEnabled",
    Callback = function(value) Config.CrosshairEnabled = value end,
})

TabCrosshair:CreateSlider({
    Name = "Crosshair Size",
    Range = {4, 30},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.CrosshairSize,
    Flag = "CrosshairSize",
    Callback = function(value) Config.CrosshairSize = value end,
})

TabCrosshair:CreateSlider({
    Name = "Crosshair Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.CrosshairThickness,
    Flag = "CrosshairThickness",
    Callback = function(value)
        Config.CrosshairThickness = value
        for _, line in pairs(CrosshairLines) do
            line.Thickness = value
        end
    end,
})

TabCrosshair:CreateSlider({
    Name = "Crosshair Gap",
    Range = {0, 15},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.CrosshairGap,
    Flag = "CrosshairGap",
    Callback = function(value) Config.CrosshairGap = value end,
})

TabCrosshair:CreateToggle({
    Name = "Center Dot",
    CurrentValue = Config.CrosshairDot,
    Flag = "CrosshairDot",
    Callback = function(value) Config.CrosshairDot = value end,
})

TabCrosshair:CreateColorPicker({
    Name = "Crosshair Color",
    Color = Config.CrosshairColor,
    Flag = "CrosshairColor",
    Callback = function(value)
        Config.CrosshairColor = value
        for _, line in pairs(CrosshairLines) do
            line.Color = value
        end
        CrosshairDot.Color = value
    end,
})

-- ── Tab: Item ESP ──
local TabItems = Window:CreateTab("Item ESP", 4483362458)

TabItems:CreateToggle({
    Name = "Highlight Items",
    CurrentValue = Config.HighlightItems,
    Flag = "HighlightItems",
    Callback = function(value)
        Config.HighlightItems = value
        if not value then
            for _, highlight in pairs(ItemESPObjects) do
                pcall(function() highlight:Destroy() end)
            end
            ItemESPObjects = {}
        else
            CreateItemESP()
        end
    end,
})

TabItems:CreateColorPicker({
    Name = "Item Highlight Color",
    Color = Config.HighlightItemColor,
    Flag = "ItemHighlightColor",
    Callback = function(value)
        Config.HighlightItemColor = value
        for _, highlight in pairs(ItemESPObjects) do
            pcall(function()
                highlight.FillColor = value
                highlight.OutlineColor = value
            end)
        end
    end,
})

TabItems:CreateInput({
    Name = "Item Keywords (comma separated)",
    PlaceholderText = "Coin, Gem, Chest, Key",
    RemoveTextWhenFocus = true,
    Callback = function(value)
        Config.HighlightItemNames = {}
        for word in string.gmatch(value, "[^,]+") do
            local trimmed = word:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                table.insert(Config.HighlightItemNames, trimmed)
            end
        end
        if Config.HighlightItems then CreateItemESP() end
    end,
})

-- ── Tab: Settings ──
local TabSettings = Window:CreateTab("Settings", 4483362458)

TabSettings:CreateSection("Team")

TabSettings:CreateToggle({
    Name = "Team Check (Hide Teammates)",
    CurrentValue = Config.TeamCheck,
    Flag = "TeamCheck",
    Callback = function(value) Config.TeamCheck = value end,
})

TabSettings:CreateToggle({
    Name = "Use Team Color",
    CurrentValue = Config.TeamColor,
    Flag = "TeamColor",
    Callback = function(value) Config.TeamColor = value end,
})

TabSettings:CreateSection("Distance")

TabSettings:CreateSlider({
    Name = "Max Distance (0 = Unlimited)",
    Range = {0, 5000},
    Increment = 100,
    Suffix = "studs",
    CurrentValue = Config.MaxDistance,
    Flag = "MaxDistance",
    Callback = function(value) Config.MaxDistance = value end,
})

TabSettings:CreateSection("Font")

local fontOptions = {}
local fontMap = {}
for i = 0, 3 do
    local name
    if i == 0 then name = "UI"
    elseif i == 1 then name = "System"
    elseif i == 2 then name = "Plex"
    elseif i == 3 then name = "Monospace"
    end
    table.insert(fontOptions, name)
    fontMap[name] = i
end

TabSettings:CreateDropdown({
    Name = "ESP Font",
    Options = fontOptions,
    CurrentOption = {"UI"},
    MultipleOptions = false,
    Flag = "ESPFont",
    Callback = function(value)
        local fontIdx = fontMap[value[1] or value] or 0
        Config.NameFont = fontIdx
        Config.HealthTextFont = fontIdx
        Config.DistanceFont = fontIdx
        Config.WeaponFont = fontIdx
        for player, objects in pairs(ESPObjects) do
            objects.Name.Font = fontIdx
            objects.HealthText.Font = fontIdx
            objects.Distance.Font = fontIdx
            objects.Weapon.Font = fontIdx
        end
    end,
})

-- Initialize
Rayfield:LoadDefault()
