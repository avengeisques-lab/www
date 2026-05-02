-- Brainrot Script - Fly & Base ESP
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Respawn refly
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    RootPart = newChar:WaitForChild("HumanoidRootPart")
    -- Stop old fly connection
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    -- Refly if was flying
    if config.flyEnabled then
        wait(0.5)
        startFly()
    end
end)

-- Configuration
local config = {
    flySpeed = 50,
    flyEnabled = false,
    espEnabled = false,
    espColor = Color3.fromRGB(255, 0, 0),
    baseEspColor = Color3.fromRGB(0, 255, 0)
}

-- Fly Variables
local flyConnection
local flyDirection = Vector3.new(0, 0, 0)

-- ESP Storage
local espObjects = {}

-- Real Fly Function
local function startFly()
    if flyConnection then return end
    
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = RootPart.CFrame
    bodyGyro.Parent = RootPart
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Parent = RootPart
    
    flyConnection = RunService.RenderStepped:Connect(function()
        if not config.flyEnabled then
            bodyGyro:Destroy()
            bodyVelocity:Destroy()
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
local function createESP(object, color, label, subLabel)
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
    billboard.Size = UDim2.new(0, 150, 0, 60)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = object
    billboard.Parent = object
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Label"
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 0.6, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.Text = label
    textLabel.TextColor3 = color
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboard
    
    if subLabel then
        local subTextLabel = Instance.new("TextLabel")
        subTextLabel.Name = "SubLabel"
        subTextLabel.BackgroundTransparency = 1
        subTextLabel.Size = UDim2.new(1, 0, 0.4, 0)
        subTextLabel.Position = UDim2.new(0, 0, 0.6, 0)
        subTextLabel.Text = subLabel
        subTextLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        subTextLabel.TextStrokeTransparency = 0.5
        subTextLabel.TextScaled = true
        subTextLabel.Font = Enum.Font.SourceSans
        subTextLabel.Parent = billboard
    end
    
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
    
    -- Brainrot ESP with name and price
    local brains = Workspace:FindFirstChild("Brains")
    if brains then
        for _, brain in pairs(brains:GetChildren()) do
            local part = nil
            local brainName = brain.Name
            local price = ""
            
            if brain:IsA("BasePart") then
                part = brain
            elseif brain:IsA("Model") then
                part = brain.PrimaryPart or brain:FindFirstChildWhichIsA("BasePart")
            end
            
            if part then
                -- Try to find price info
                local priceObj = brain:FindFirstChild("Price") or brain:FindFirstChild("price") or brain:FindFirstChild("Cost") or brain:FindFirstChild("cost") or brain:FindFirstChild("Value") or brain:FindFirstChild("value")
                if priceObj then
                    if priceObj:IsA("NumberValue") or priceObj:IsA("IntValue") then
                        price = "$" .. tostring(priceObj.Value)
                    elseif priceObj:IsA("StringValue") then
                        price = priceObj.Value
                    elseif priceObj:IsA("TextLabel") or priceObj:IsA("TextButton") then
                        price = priceObj.Text
                    end
                end
                
                -- Try SurfaceGui text for price
                if price == "" then
                    for _, desc in pairs(brain:GetDescendants()) do
                        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                            local txt = desc.Text
                            if txt and (txt:match("%$") or txt:match("%d") and (txt:lower():match("price") or txt:lower():match("cost"))) then
                                price = txt
                                break
                            end
                        end
                    end
                end
                
                local subLabel = price ~= "" and price or nil
                createESP(part, config.espColor, brainName, subLabel)
            end
        end
    end
    
    -- Base ESP - Only detect actual player bases
    -- Brainrot bases are usually Models with specific structure
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name:match("Base") or obj.Name:match("Plot") or obj.Name:match("Area")) then
            -- Only ESP the main base structure, not every part
            local mainPart = obj:FindFirstChild("Main") or obj:FindFirstChild("Floor") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if mainPart then
                createESP(mainPart, config.baseEspColor, "Base")
            end
        end
    end
    
    -- Check for plot/zone folders that contain bases
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            local nameLower = obj.Name:lower()
            if nameLower:match("plots") or nameLower:match("zones") or nameLower:match("bases") then
                for _, child in pairs(obj:GetChildren()) do
                    if child:IsA("Model") then
                        local mainPart = child:FindFirstChildWhichIsA("BasePart")
                        if mainPart then
                            createESP(mainPart, config.baseEspColor, "Base")
                        end
                    end
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
