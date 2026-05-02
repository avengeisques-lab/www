-- Brainrot Script - Anti-Detect Fly & Base ESP
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Configuration
local config = {
    flySpeed = 50,
    flyEnabled = false,
    espEnabled = false,
    espColor = Color3.fromRGB(255, 0, 0),
    baseEspColor = Color3.fromRGB(0, 255, 0),
    antiDetectFly = true
}

-- Fly Variables
local flyConnection
local flyDirection = Vector3.new(0, 0, 0)
local groundSpoofPart
local realPosition
local spoofConnection

-- ESP Storage
local espObjects = {}

-- Anti-Detect Fly Function
local function startFly()
    if flyConnection then return end
    
    -- Create ground spoof part
    groundSpoofPart = Instance.new("Part")
    groundSpoofPart.Name = "GroundSpoof"
    groundSpoofPart.Anchored = true
    groundSpoofPart.CanCollide = false
    groundSpoofPart.Transparency = 1
    groundSpoofPart.Size = Vector3.new(1, 1, 1)
    groundSpoofPart.Position = RootPart.Position
    groundSpoofPart.Parent = Workspace
    
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = RootPart.CFrame
    bodyGyro.Parent = RootPart
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Parent = RootPart
    
    local lastGroundPos = RootPart.Position
    
    flyConnection = RunService.RenderStepped:Connect(function()
        if not config.flyEnabled then
            bodyGyro:Destroy()
            bodyVelocity:Destroy()
            if groundSpoofPart then groundSpoofPart:Destroy() end
            flyConnection:Disconnect()
            flyConnection = nil
            return
        end
        
        local cameraCFrame = Camera.CFrame
        local moveDirection = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + cameraCFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - cameraCFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - cameraCFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + cameraCFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit * config.flySpeed
        end
        
        bodyVelocity.Velocity = moveDirection
        bodyGyro.CFrame = cameraCFrame
        
        -- Anti-detect: spoof position to ground level
        if config.antiDetectFly then
            -- Keep spoof part at ground level near real position
            local rayOrigin = RootPart.Position
            local rayDirection = Vector3.new(0, -1000, 0)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
            if result then
                groundSpoofPart.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
            else
                groundSpoofPart.CFrame = CFrame.new(RootPart.Position.X, lastGroundPos.Y, RootPart.Position.Z)
            end
            
            -- Spoof CFrame to ground for anti-cheat
            local currentCFrame = RootPart.CFrame
            RootPart.CFrame = groundSpoofPart.CFrame
            task.wait()
            RootPart.CFrame = currentCFrame
        end
    end)
end

local function stopFly()
    config.flyEnabled = false
end

local function toggleFly()
    config.flyEnabled = not config.flyEnabled
    if config.flyEnabled then
        startFly()
    end
end

-- ESP Functions
local function createESP(object, color, label)
    if not object then return end
    
    local espBox = Instance.new("BoxHandleAdornment")
    espBox.Size = object.Size + Vector3.new(0.1, 0.1, 0.1)
    espBox.CFrame = object.CFrame
    espBox.Color3 = color
    espBox.Transparency = 0.5
    espBox.AlwaysOnTop = true
    espBox.ZIndex = 10
    espBox.Adornee = object
    espBox.Parent = object
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = object
    billboard.Parent = object
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Label"
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Text = label
    textLabel.TextColor3 = color
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextScaled = true
    textLabel.Parent = billboard
    
    table.insert(espObjects, {espBox, billboard})
    
    return espBox, billboard
end

local function clearESP()
    for _, obj in pairs(espObjects) do
        if obj[1] then obj[1]:Destroy() end
        if obj[2] then obj[2]:Destroy() end
    end
    espObjects = {}
end

local function updateESP()
    clearESP()
    
    if not config.espEnabled then return end
    
    -- Brain ESP
    local brains = Workspace:FindFirstChild("Brains")
    if brains then
        for _, brain in pairs(brains:GetChildren()) do
            if brain:IsA("BasePart") or brain:IsA("Model") then
                local part = brain:IsA("Model") and brain.PrimaryPart or brain:FindFirstChildWhichIsA("BasePart") or brain
                if part then
                    createESP(part, config.espColor, "Brain")
                end
            end
        end
    end
    
    -- Base ESP - check multiple locations
    local baseNames = {"Base", "Bases", "base", "bases", "Home", "home", "Spawn", "spawn", "Baseplate", "baseplate"}
    
    -- Check direct children
    for _, name in pairs(baseNames) do
        local obj = Workspace:FindFirstChild(name)
        if obj then
            if obj:IsA("BasePart") then
                createESP(obj, config.baseEspColor, "Base")
            elseif obj:IsA("Model") or obj:IsA("Folder") then
                for _, child in pairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") and child.Size.Magnitude > 5 then
                        createESP(child, config.baseEspColor, "Base")
                    end
                end
            end
        end
    end
    
    -- Check player's base (common in Brainrot)
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local baseFolder = player:FindFirstChild("Base") or player:FindFirstChild("base")
            if baseFolder then
                for _, part in pairs(baseFolder:GetDescendants()) do
                    if part:IsA("BasePart") then
                        createESP(part, config.baseEspColor, player.Name .. " Base")
                    end
                end
            end
        end
    end
    
    -- Check map structures
    local map = Workspace:FindFirstChild("Map")
    if map then
        for _, obj in pairs(map:GetDescendants()) do
            if obj:IsA("BasePart") then
                local nameLower = obj.Name:lower()
                if nameLower:match("base") or nameLower:match("home") or nameLower:match("spawn") or nameLower:match("platform") then
                    createESP(obj, config.baseEspColor, "Base")
                end
            end
        end
    end
    
    -- Generic large parts that could be bases
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Size.Magnitude > 20 and obj ~= RootPart then
            local nameLower = obj.Name:lower()
            if nameLower:match("base") or nameLower:match("floor") or nameLower:match("platform") or nameLower:match("ground") then
                local alreadyAdded = false
                for _, existing in pairs(espObjects) do
                    if existing[1] and existing[1].Adornee == obj then
                        alreadyAdded = true
                        break
                    end
                end
                if not alreadyAdded then
                    createESP(obj, config.baseEspColor, "Base")
                end
            end
        end
    end
end

-- Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Brainrot Script",
    LoadingTitle = "Brainrot",
    LoadingSubtitle = "by Script Author",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BrainrotConfig",
        FileName = "Config"
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)

-- Anti-Detect Toggle
local AntiDetectToggle = MainTab:CreateToggle({
    Name = "Anti-Detect Fly",
    CurrentValue = true,
    Flag = "AntiDetectToggle",
    Callback = function(Value)
        config.antiDetectFly = Value
    end,
})

-- Fly Toggle
local FlyToggle = MainTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(Value)
        config.flyEnabled = Value
        if Value then
            startFly()
        end
    end,
})

-- Fly Speed Slider
local FlySpeedSlider = MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 10,
    CurrentValue = 50,
    Flag = "FlySpeed",
    Callback = function(Value)
        config.flySpeed = Value
    end,
})

-- ESP Toggle
local ESPToggle = MainTab:CreateToggle({
    Name = "ESP",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(Value)
        config.espEnabled = Value
        updateESP()
    end,
})

-- Refresh ESP Button
local RefreshESP = MainTab:CreateButton({
    Name = "Refresh ESP",
    Callback = function()
        if config.espEnabled then
            updateESP()
        end
    end,
})

-- Auto refresh ESP
spawn(function()
    while true do
        wait(2)
        if config.espEnabled then
            updateESP()
        end
    end
end)

print("Brainrot script loaded - Fly & ESP ready!")
