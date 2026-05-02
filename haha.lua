--[[
    Universal ESP Script for Roblox
    Works with most executors (Synapse, Script-Ware, Fluxus, etc.)
    Uses the Drawing library for rendering + Rayfield UI
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Local player reference
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Configuration
local Config = {
    Enabled = true,
    ToggleKey = Enum.KeyCode.RightShift,

    -- Box ESP
    BoxEnabled = true,
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxFilled = false,
    BoxFillTransparency = 0.5,
    BoxThickness = 1,

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

    -- Tracer ESP
    TracerEnabled = false,
    TracerColor = Color3.fromRGB(255, 255, 255),
    TracerThickness = 1,
    TracerOrigin = "Bottom",

    -- Team check
    TeamCheck = false,
    TeamColor = true,

    -- Max distance (0 = unlimited)
    MaxDistance = 0,

    -- Highlight specific items
    HighlightItems = false,
    HighlightItemNames = {"Coin", "Gem", "Chest", "Key", "Orb", "Crystal", "Star"},
    HighlightItemColor = Color3.fromRGB(255, 215, 0),

    -- Aimbot
    AimbotEnabled = false,
    AimbotKey = Enum.KeyCode.E,
    AimbotPart = "Head", -- "Head" or "HumanoidRootPart"
    AimbotSmoothness = 0.3,
    AimbotFOV = 120,
    AimbotShowFOV = true,
    AimbotFOVColor = Color3.fromRGB(255, 255, 255),
    AimbotTeamCheck = false,
    AimbotMaxDistance = 0,
    AimbotVisibilityCheck = false,
}

-- ESP data storage per player
local ESPObjects = {}

-- Aimbot state
local AimbotLocked = nil
local AimbotHolding = false

-- FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = Config.AimbotFOVColor
FOVCircle.Visible = false

-- Utility: Get team color or default color
local function GetPlayerColor(player)
    if Config.TeamColor and player.Team and player.TeamColor then
        return player.TeamColor.Color
    end
    return Config.BoxColor
end

-- Utility: Check if player is on same team
local function IsTeamMate(player)
    if not Config.TeamCheck then return false end
    if not player.Team then return false end
    return player.Team == LocalPlayer.Team
end

-- Utility: Get character and parts
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

-- Utility: World to screen with viewport support
local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

-- Utility: Calculate box corners from character
local function GetBox(hrp)
    local pos, onScreen, depth = WorldToScreen(hrp.Position)
    if not onScreen then return nil end

    local size = math.clamp(3000 / depth, 4, 300)
    local halfSize = size / 2

    return {
        TopLeft = Vector2.new(pos.X - halfSize, pos.Y - halfSize * 1.5),
        TopRight = Vector2.new(pos.X + halfSize, pos.Y - halfSize * 1.5),
        BottomLeft = Vector2.new(pos.X - halfSize, pos.Y + halfSize * 0.5),
        BottomRight = Vector2.new(pos.X + halfSize, pos.Y + halfSize * 0.5),
        Center = pos,
        Depth = depth,
        Size = size
    }
end

-- Create ESP objects for a player
local function CreateESP(player)
    local objects = {}

    -- Box (4 lines)
    objects.BoxTop = Drawing.new("Line")
    objects.BoxBottom = Drawing.new("Line")
    objects.BoxLeft = Drawing.new("Line")
    objects.BoxRight = Drawing.new("Line")

    -- Box fill (optional)
    objects.BoxFill = Drawing.new("Square")

    -- Name
    objects.Name = Drawing.new("Text")

    -- Health bar (2 lines + text)
    objects.HealthBarOutline = Drawing.new("Line")
    objects.HealthBar = Drawing.new("Line")
    objects.HealthText = Drawing.new("Text")

    -- Distance
    objects.Distance = Drawing.new("Text")

    -- Tracer
    objects.Tracer = Drawing.new("Line")

    -- Apply default settings
    for _, line in pairs({objects.BoxTop, objects.BoxBottom, objects.BoxLeft, objects.BoxRight}) do
        line.Thickness = Config.BoxThickness
        line.Transparency = 1
        line.Visible = false
    end

    objects.BoxFill.Filled = true
    objects.BoxFill.Transparency = Config.BoxFillTransparency
    objects.BoxFill.Visible = false

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

    objects.Tracer.Thickness = Config.TracerThickness
    objects.Tracer.Transparency = 1
    objects.Tracer.Visible = false

    ESPObjects[player] = objects
end

-- Remove ESP for a player
local function RemoveESP(player)
    local objects = ESPObjects[player]
    if not objects then return end
    for _, obj in pairs(objects) do
        obj:Remove()
    end
    ESPObjects[player] = nil
end

-- Update ESP for a single player
local function UpdateESP(player)
    local objects = ESPObjects[player]
    if not objects then return end

    if not Config.Enabled or player == LocalPlayer or IsTeamMate(player) then
        for _, obj in pairs(objects) do
            obj.Visible = false
        end
        return
    end

    local char, hrp, head, humanoid = GetCharacter(player)
    if not char then
        for _, obj in pairs(objects) do
            obj.Visible = false
        end
        return
    end

    local box = GetBox(hrp)
    if not box then
        for _, obj in pairs(objects) do
            obj.Visible = false
        end
        return
    end

    -- Distance check
    if Config.MaxDistance > 0 and box.Depth > Config.MaxDistance then
        for _, obj in pairs(objects) do
            obj.Visible = false
        end
        return
    end

    local color = GetPlayerColor(player)
    local healthRatio = humanoid.Health / humanoid.MaxHealth

    -- Box ESP
    if Config.BoxEnabled then
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

        -- Box fill
        if Config.BoxFilled then
            objects.BoxFill.Position = box.TopLeft
            objects.BoxFill.Size = Vector2.new(box.Size, box.Size * 2)
            objects.BoxFill.Color = color
            objects.BoxFill.Transparency = Config.BoxFillTransparency
            objects.BoxFill.Visible = true
        else
            objects.BoxFill.Visible = false
        end
    else
        objects.BoxTop.Visible = false
        objects.BoxBottom.Visible = false
        objects.BoxLeft.Visible = false
        objects.BoxRight.Visible = false
        objects.BoxFill.Visible = false
    end

    -- Name ESP
    if Config.NameEnabled then
        objects.Name.Position = Vector2.new(box.Center.X, box.TopLeft.Y - 16)
        objects.Name.Text = player.DisplayName
        objects.Name.Color = color
        objects.Name.Visible = true
    else
        objects.Name.Visible = false
    end

    -- Health ESP
    if Config.HealthEnabled then
        local barX = box.TopLeft.X - 5
        local barTopY = box.TopLeft.Y
        local barBottomY = box.BottomLeft.Y
        local barHeight = barBottomY - barTopY

        -- Outline
        objects.HealthBarOutline.From = Vector2.new(barX - 1, barTopY)
        objects.HealthBarOutline.To = Vector2.new(barX - 1, barBottomY)
        objects.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        objects.HealthBarOutline.Visible = true

        -- Health bar
        local healthColor = Color3.fromRGB(
            255 * (1 - healthRatio),
            255 * healthRatio,
            0
        )
        objects.HealthBar.From = Vector2.new(barX - 1, barBottomY)
        objects.HealthBar.To = Vector2.new(barX - 1, barBottomY - barHeight * healthRatio)
        objects.HealthBar.Color = healthColor
        objects.HealthBar.Visible = true

        -- Health text
        objects.HealthText.Position = Vector2.new(barX - 1, barTopY - 14)
        objects.HealthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
        objects.HealthText.Color = Config.HealthTextColor
        objects.HealthText.Visible = true
    else
        objects.HealthBarOutline.Visible = false
        objects.HealthBar.Visible = false
        objects.HealthText.Visible = false
    end

    -- Distance ESP
    if Config.DistanceEnabled then
        objects.Distance.Position = Vector2.new(box.Center.X, box.BottomLeft.Y + 2)
        objects.Distance.Text = math.floor(box.Depth) .. "m"
        objects.Distance.Color = color
        objects.Distance.Visible = true
    else
        objects.Distance.Visible = false
    end

    -- Tracer ESP
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
end

-- ═══════════════════════════════════════════════════════════════
-- Aimbot Logic
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

        -- Visibility check
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
    -- Update FOV circle
    if Config.AimbotShowFOV and Config.AimbotEnabled then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Color = Config.AimbotFOVColor
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    if not Config.AimbotEnabled then return end
    if not AimbotHolding then AimbotLocked = nil; return end

    -- Find target
    if not AimbotLocked then
        AimbotLocked = GetClosestPlayerToMouse()
    end

    -- Validate locked target
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

        -- Check if target is still within FOV
        local mousePos = UserInputService:GetMouseLocation()
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist > Config.AimbotFOV then
            AimbotLocked = nil
            return
        end

        -- Smooth aim
        local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Config.AimbotSmoothness)
    end
end

-- Aimbot input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.AimbotKey then
        AimbotHolding = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Config.AimbotKey then
        AimbotHolding = false
        AimbotLocked = nil
    end
end)

-- Item ESP storage
local ItemESPObjects = {}

-- Create ESP for world items
local function CreateItemESP()
    if not Config.HighlightItems then return end

    -- Clear old item ESP
    for _, obj in pairs(ItemESPObjects) do
        pcall(function() obj:Remove() end)
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
                highlight.Name = "ESP_Highlight"
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

-- Toggle function
local function ToggleESP()
    Config.Enabled = not Config.Enabled
    if not Config.Enabled then
        for player, objects in pairs(ESPObjects) do
            for _, obj in pairs(objects) do
                obj.Visible = false
            end
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

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleKey then
        ToggleESP()
    end
end)

-- Player added/removed handlers
Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

-- Create ESP for existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

-- Main render loop
local connection
connection = RunService.RenderStepped:Connect(function()
    for player, objects in pairs(ESPObjects) do
        UpdateESP(player)
    end
    UpdateAimbot()
end)

-- Item ESP refresh timer
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
    Name = "Universal ESP",
    LoadingTitle = "Universal ESP",
    LoadingSubtitle = "by Rayfield",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UniversalESP",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

-- Tab: Player ESP
local TabPlayers = Window:CreateTab("Player ESP", 4483362458)

TabPlayers:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Config.Enabled,
    Flag = "EnableESP",
    Callback = function(value)
        Config.Enabled = value
        if not value then
            for player, objects in pairs(ESPObjects) do
                for _, obj in pairs(objects) do
                    obj.Visible = false
                end
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
    Callback = function(value)
        Config.BoxEnabled = value
    end,
})

TabPlayers:CreateToggle({
    Name = "Filled Box",
    CurrentValue = Config.BoxFilled,
    Flag = "BoxFilled",
    Callback = function(value)
        Config.BoxFilled = value
    end,
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
            for _, line in pairs({objects.BoxTop, objects.BoxBottom, objects.BoxLeft, objects.BoxRight}) do
                line.Thickness = value
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
    Callback = function(value)
        Config.BoxFillTransparency = value
    end,
})

TabPlayers:CreateColorPicker({
    Name = "Box Color",
    Color = Config.BoxColor,
    Flag = "BoxColor",
    Callback = function(value)
        Config.BoxColor = value
    end,
})

TabPlayers:CreateSection("Name")

TabPlayers:CreateToggle({
    Name = "Name ESP",
    CurrentValue = Config.NameEnabled,
    Flag = "NameESP",
    Callback = function(value)
        Config.NameEnabled = value
    end,
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
    Callback = function(value)
        Config.NameColor = value
    end,
})

TabPlayers:CreateSection("Health")

TabPlayers:CreateToggle({
    Name = "Health ESP",
    CurrentValue = Config.HealthEnabled,
    Flag = "HealthESP",
    Callback = function(value)
        Config.HealthEnabled = value
    end,
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
    Callback = function(value)
        Config.HealthTextColor = value
    end,
})

TabPlayers:CreateSection("Distance")

TabPlayers:CreateToggle({
    Name = "Distance ESP",
    CurrentValue = Config.DistanceEnabled,
    Flag = "DistanceESP",
    Callback = function(value)
        Config.DistanceEnabled = value
    end,
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
    Callback = function(value)
        Config.DistanceColor = value
    end,
})

-- Tab: Tracers
local TabTracers = Window:CreateTab("Tracers", 4483362458)

TabTracers:CreateToggle({
    Name = "Tracer ESP",
    CurrentValue = Config.TracerEnabled,
    Flag = "TracerESP",
    Callback = function(value)
        Config.TracerEnabled = value
    end,
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
    Callback = function(value)
        Config.TracerOrigin = value[1] or value
    end,
})

TabTracers:CreateColorPicker({
    Name = "Tracer Color",
    Color = Config.TracerColor,
    Flag = "TracerColor",
    Callback = function(value)
        Config.TracerColor = value
    end,
})

-- Tab: Settings
local TabSettings = Window:CreateTab("Settings", 4483362458)

TabSettings:CreateSection("Team")

TabSettings:CreateToggle({
    Name = "Team Check (Hide Teammates)",
    CurrentValue = Config.TeamCheck,
    Flag = "TeamCheck",
    Callback = function(value)
        Config.TeamCheck = value
    end,
})

TabSettings:CreateToggle({
    Name = "Use Team Color",
    CurrentValue = Config.TeamColor,
    Flag = "TeamColor",
    Callback = function(value)
        Config.TeamColor = value
    end,
})

TabSettings:CreateSection("Distance")

TabSettings:CreateSlider({
    Name = "Max Distance (0 = Unlimited)",
    Range = {0, 5000},
    Increment = 100,
    Suffix = "studs",
    CurrentValue = Config.MaxDistance,
    Flag = "MaxDistance",
    Callback = function(value)
        Config.MaxDistance = value
    end,
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
        for player, objects in pairs(ESPObjects) do
            objects.Name.Font = fontIdx
            objects.HealthText.Font = fontIdx
            objects.Distance.Font = fontIdx
        end
    end,
})

-- Tab: Item ESP
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
        if Config.HighlightItems then
            CreateItemESP()
        end
    end,
})

-- Tab: Aimbot
local TabAimbot = Window:CreateTab("Aimbot", 4483362458)

TabAimbot:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = Config.AimbotEnabled,
    Flag = "AimbotEnabled",
    Callback = function(value)
        Config.AimbotEnabled = value
    end,
})

TabAimbot:CreateKeybind({
    Name = "Aimbot Key (Hold)",
    CurrentKeybind = Config.AimbotKey,
    HoldToInteract = true,
    Flag = "AimbotKey",
    Callback = function(keybind)
        Config.AimbotKey = keybind
    end,
})

TabAimbot:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart"},
    CurrentOption = {Config.AimbotPart},
    MultipleOptions = false,
    Flag = "AimbotPart",
    Callback = function(value)
        Config.AimbotPart = value[1] or value
    end,
})

TabAimbot:CreateSlider({
    Name = "Smoothness",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = Config.AimbotSmoothness,
    Flag = "AimbotSmoothness",
    Callback = function(value)
        Config.AimbotSmoothness = value
    end,
})

TabAimbot:CreateSlider({
    Name = "FOV Size",
    Range = {20, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = Config.AimbotFOV,
    Flag = "AimbotFOV",
    Callback = function(value)
        Config.AimbotFOV = value
    end,
})

TabAimbot:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Config.AimbotShowFOV,
    Flag = "AimbotShowFOV",
    Callback = function(value)
        Config.AimbotShowFOV = value
    end,
})

TabAimbot:CreateColorPicker({
    Name = "FOV Circle Color",
    Color = Config.AimbotFOVColor,
    Flag = "AimbotFOVColor",
    Callback = function(value)
        Config.AimbotFOVColor = value
    end,
})

TabAimbot:CreateToggle({
    Name = "Team Check",
    CurrentValue = Config.AimbotTeamCheck,
    Flag = "AimbotTeamCheck",
    Callback = function(value)
        Config.AimbotTeamCheck = value
    end,
})

TabAimbot:CreateSlider({
    Name = "Max Distance (0 = Unlimited)",
    Range = {0, 5000},
    Increment = 100,
    Suffix = "studs",
    CurrentValue = Config.AimbotMaxDistance,
    Flag = "AimbotMaxDistance",
    Callback = function(value)
        Config.AimbotMaxDistance = value
    end,
})

TabAimbot:CreateToggle({
    Name = "Visibility Check",
    CurrentValue = Config.AimbotVisibilityCheck,
    Flag = "AimbotVisibilityCheck",
    Callback = function(value)
        Config.AimbotVisibilityCheck = value
    end,
})

-- Initialize Rayfield
Rayfield:LoadDefault()
