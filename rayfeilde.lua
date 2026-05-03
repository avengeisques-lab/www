--[[
    Steal a Brainrot Script
    Features: Brainrot ESP + Value, Auto-Buy Highest, Anti-AFK
    UI: Rayfield
]]

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// State
local espEnabled = false
local autoBuyEnabled = false
local antiAFKEnabled = true
local espObjects = {}
local autoBuyConnection = nil

--// Anti-AFK
local antiAFKConnection
antiAFKConnection = LocalPlayer.Idled:Connect(function()
    if antiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

--// Helper: Get brainrot parts/objects in workspace
local function getBrainrots()
    local brainrots = {}

    -- Common parent locations for collectibles in these types of games
    local searchPaths = {
        Workspace:FindFirstChild("Brainrots") or Workspace:FindFirstChild("Brainrot") or Workspace:FindFirstChild("Collectibles") or Workspace:FindFirstChild("Items") or Workspace:FindFirstChild("Map"),
        Workspace:FindFirstChild("Ignored"),
        Workspace
    }

    for _, searchParent in ipairs(searchPaths) do
        if searchParent then
            for _, obj in ipairs(searchParent:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    local name = obj.Name:lower()
                    -- Filter for brainrot-related objects
                    if name:find("brainrot") or name:find("brain_rot") or name:find("pet") or name:find("collectible") or name:find("item") or name:find("loot") or name:find("drop") or name:find("money") or name:find("cash") or name:find("gem") or name:find("coin") or name:find("steal") then
                        local part = obj:IsA("BasePart") and obj or (obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart"))
                        if part then
                            -- Try to get value from attributes or value objects
                            local value = 0
                            local valueObj = obj:FindFirstChildWhichIsA("IntValue") or obj:FindFirstChildWhichIsA("NumberValue")
                            if valueObj then
                                value = valueObj.Value
                            elseif obj:GetAttribute("Value") then
                                value = obj:GetAttribute("Value")
                            elseif obj:GetAttribute("Price") then
                                value = obj:GetAttribute("Price")
                            elseif obj:GetAttribute("Worth") then
                                value = obj:GetAttribute("Worth")
                            elseif obj:GetAttribute("Cost") then
                                value = obj:GetAttribute("Cost")
                            elseif part:GetAttribute("Value") then
                                value = part:GetAttribute("Value")
                            elseif part:GetAttribute("Price") then
                                value = part:GetAttribute("Price")
                            end

                            table.insert(brainrots, {
                                object = obj,
                                part = part,
                                value = tonumber(value) or 0,
                                name = obj.Name
                            })
                        end
                    end
                end
            end
        end
    end

    return brainrots
end

--// Helper: Get player's money/currency
local function getPlayerMoney()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            local name = stat.Name:lower()
            if name:find("money") or name:find("cash") or name:find("coin") or name:find("dollar") or name:find("currency") or name:find("balance") then
                return tonumber(stat.Value) or 0
            end
        end
        -- Fallback to first IntValue/NumberValue
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("IntValue") or stat:IsA("NumberValue") then
                return tonumber(stat.Value) or 0
            end
        end
    end
    return 0
end

--// ESP System
local function createESP(brainrot)
    if espObjects[brainrot.object] then return end

    local part = brainrot.part
    local obj = brainrot.object

    -- Billboard GUI for name + value
    local bb = Instance.new("BillboardGui")
    bb.Name = "BrainrotESP"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 500

    -- Value label (top)
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(1, 0, 0.5, 0)
    valueLabel.Position = UDim2.new(0, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    valueLabel.TextStrokeTransparency = 0
    valueLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = "$" .. tostring(brainrot.value)
    valueLabel.Parent = bb

    -- Name label (bottom)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Text = brainrot.name
    nameLabel.Parent = bb

    -- Highlight effect
    local highlight = Instance.new("Highlight")
    highlight.Name = "BrainrotHighlight"
    highlight.Adornee = obj:IsA("Model") and obj or part
    highlight.FillColor = Color3.fromRGB(255, 0, 255)
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.Parent = obj:IsA("Model") and obj or part

    bb.Parent = part

    espObjects[brainrot.object] = {
        billboard = bb,
        highlight = highlight,
        valueLabel = valueLabel
    }
end

local function removeESP(brainrotObj)
    local espData = espObjects[brainrotObj]
    if espData then
        if espData.billboard then espData.billboard:Destroy() end
        if espData.highlight then espData.highlight:Destroy() end
        espObjects[brainrotObj] = nil
    end
end

local function clearAllESP()
    for obj, _ in pairs(espObjects) do
        removeESP(obj)
    end
    espObjects = {}
end

local function refreshESP()
    if not espEnabled then return end
    local brainrots = getBrainrots()
    local currentObjects = {}

    for _, brainrot in ipairs(brainrots) do
        currentObjects[brainrot.object] = true
        if not espObjects[brainrot.object] then
            createESP(brainrot)
        else
            -- Update value display
            local espData = espObjects[brainrot.object]
            if espData and espData.valueLabel then
                espData.valueLabel.Text = "$" .. tostring(brainrot.value)
            end
        end
    end

    -- Remove ESP for objects that no longer exist
    for obj, _ in pairs(espObjects) do
        if not currentObjects[obj] or obj.Parent == nil then
            removeESP(obj)
        end
    end
end

--// ESP Loop
local espLoopConnection
local function startESPLoop()
    if espLoopConnection then espLoopConnection:Disconnect() end
    espLoopConnection = RunService.Heartbeat:Connect(function()
        if espEnabled then
            refreshESP()
        end
    end)
end

local function stopESPLoop()
    if espLoopConnection then
        espLoopConnection:Disconnect()
        espLoopConnection = nil
    end
    clearAllESP()
end

--// Auto-Buy System
local function findBuyRemote()
    -- Search for buy-related remotes
    local searchAreas = {ReplicatedStorage, Workspace}
    for _, area in ipairs(searchAreas) do
        for _, desc in ipairs(area:GetDescendants()) do
            if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                local name = desc.Name:lower()
                if name:find("buy") or name:find("purchase") or name:find("steal") or name:find("collect") or name:find("claim") or name:find("grab") or name:find("pickup") then
                    return desc
                end
            end
        end
    end
    return nil
end

local function attemptBuy(brainrot)
    local remote = findBuyRemote()
    if remote then
        if remote:IsA("RemoteEvent") then
            remote:FireServer(brainrot.object)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(brainrot.object)
        end
    else
        -- Fallback: try to touch/collect the part (proximity prompt or touch)
        local part = brainrot.part
        if part and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Check for ProximityPrompt
                local prompt = brainrot.object:FindFirstChildWhichIsA("ProximityPrompt") or part:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                else
                    -- Touch-based collection
                    firetouchinterest(hrp, part, 0)
                    firetouchinterest(hrp, part, 1)
                end
            end
        end
    end
end

local function autoBuyLoop()
    if not autoBuyEnabled then return end

    local brainrots = getBrainrots()
    local playerMoney = getPlayerMoney()

    -- Sort by value descending (buy highest value first)
    table.sort(brainrots, function(a, b)
        return a.value > b.value
    end)

    for _, brainrot in ipairs(brainrots) do
        if brainrot.value > 0 and brainrot.value <= playerMoney then
            -- Teleport to the brainrot first
            local part = brainrot.part
            if part and LocalPlayer.Character then
                local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = part.CFrame * CFrame.new(0, 2, 0)
                    task.wait(0.3)
                    attemptBuy(brainrot)
                end
            end
            break -- Buy one at a time per cycle
        end
    end
end

local function startAutoBuy()
    if autoBuyConnection then autoBuyConnection:Disconnect() end
    autoBuyConnection = RunService.Heartbeat:Connect(function()
        task.wait(2) -- Throttle to avoid issues
        if autoBuyEnabled then
            autoBuyLoop()
        end
    end)
end

local function stopAutoBuy()
    if autoBuyConnection then
        autoBuyConnection:Disconnect()
        autoBuyConnection = nil
    end
end

--// Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()

local Window = Rayfield:CreateWindow({
    Name = "Steal a Brainrot",
    LoadingTitle = "Loading Brainrot Hub...",
    LoadingSubtitle = "by Brainrot Enjoyer",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "StealABrainrot"
    },
    Discord = nil,
    KeySystem = false
})

--// Main Tab
local MainTab = Window:CreateTab("Main", 4483362458)

-- Brainrot ESP Toggle
MainTab:CreateToggle({
    Name = "Brainrot ESP",
    CurrentValue = false,
    Flag = "BrainrotESP",
    Callback = function(value)
        espEnabled = value
        if espEnabled then
            startESPLoop()
        else
            stopESPLoop()
        end
    end
})

-- ESP Value Display Toggle
MainTab:CreateToggle({
    Name = "Show Brainrot Value",
    CurrentValue = true,
    Flag = "ShowValue",
    Callback = function(value)
        for _, espData in pairs(espObjects) do
            if espData.valueLabel then
                espData.valueLabel.Visible = value
            end
        end
    end
})

-- Auto-Buy Toggle
MainTab:CreateToggle({
    Name = "Auto-Buy Highest Value",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(value)
        autoBuyEnabled = value
        if autoBuyEnabled then
            startAutoBuy()
        else
            stopAutoBuy()
        end
    end
})

-- Anti-AFK Toggle
MainTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAFK",
    Callback = function(value)
        antiAFKEnabled = value
    end
})

--// Settings Tab
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- ESP Distance Slider
SettingsTab:CreateSlider({
    Name = "ESP Max Distance",
    Range = {50, 2000},
    Increment = 50,
    Suffix = "Studs",
    CurrentValue = 500,
    Flag = "ESPDistance",
    Callback = function(value)
        for _, espData in pairs(espObjects) do
            if espData.billboard then
                espData.billboard.MaxDistance = value
            end
        end
    end
})

-- Auto-Buy Interval Slider
SettingsTab:CreateSlider({
    Name = "Auto-Buy Interval",
    Range = {1, 10},
    Increment = 1,
    Suffix = "Seconds",
    CurrentValue = 2,
    Flag = "AutoBuyInterval",
    Callback = function(value)
        -- Restart auto-buy with new interval
        if autoBuyEnabled then
            stopAutoBuy()
            autoBuyConnection = RunService.Heartbeat:Connect(function()
                task.wait(value)
                if autoBuyEnabled then
                    autoBuyLoop()
                end
            end)
        end
    end
})

-- Teleport to Highest Value Button
SettingsTab:CreateButton({
    Name = "Teleport to Highest Value",
    Callback = function()
        local brainrots = getBrainrots()
        table.sort(brainrots, function(a, b)
            return a.value > b.value
        end)

        if #brainrots > 0 and brainrots[1].part and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = brainrots[1].part.CFrame * CFrame.new(0, 3, 0)
                Rayfield:Notify("Teleported!", "Teleported to: " .. brainrots[1].name .. " ($" .. brainrots[1].value .. ")", 4483362458, 3)
            end
        else
            Rayfield:Notify("Error", "No brainrots found!", 4483362458, 3)
        end
    end
})

-- Refresh ESP Button
SettingsTab:CreateButton({
    Name = "Refresh ESP",
    Callback = function()
        clearAllESP()
        if espEnabled then
            refreshESP()
        end
        Rayfield:Notify("Refreshed", "ESP has been refreshed", 4483362458, 2)
    end
})

--// Info Tab
local InfoTab = Window:CreateTab("Info", 4483362458)

InfoTab:CreateLabel("Steal a Brainrot Script")
InfoTab:CreateLabel("Made with Rayfield UI")
InfoTab:CreateParagraph({
    Title = "Features",
    Content = "• Brainrot ESP with value display\n• Auto-Buy highest value brainrots\n• Anti-AFK kick prevention\n• Teleport to highest value\n• Adjustable ESP distance & buy interval"
})

Rayfield:Notify("Loaded!", "Steal a Brainrot script is ready!", 4483362458, 4)
