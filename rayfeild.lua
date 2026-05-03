-- Load Rayfield
local Rayfield = loadstring(game:HttpGet('https://[Log in to view URL]'))()

-- Create Window
local Window = Rayfield:CreateWindow({
   Name = "🧠 Brainrot Hub",
   Icon = 4483362458,
   LoadingTitle = "Brainrot Hub",
   LoadingSubtitle = "Loading Script...",
   ShowText = "Brainrot Hub",
   Theme = "Default",

   ToggleUIKeybind = "Insert",

   ConfigurationSaving = {
      Enabled = true,
      FileName = "BrainrotHubConfig"
   }
})

-- MAIN TAB
local MainTab = Window:CreateTab("Main", 4483362458)

-- SECTION
MainTab:CreateSection("Core Features")

-- BUTTON EXAMPLE
MainTab:CreateButton({
   Name = "Auto Farm",
   Callback = function()
      print("Auto Farm Enabled")
   end
})

-- TOGGLE
local AutoFarmToggle = MainTab:CreateToggle({
   Name = "Enable Auto Farm",
   CurrentValue = false,
   Callback = function(Value)
      print("Auto Farm:", Value)
   end
})

-- SLIDER
MainTab:CreateSlider({
   Name = "WalkSpeed",
   Range = {16, 100},
   Increment = 1,
   CurrentValue = 16,
   Callback = function(Value)
      game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = Value
   end
})

-- SECOND TAB
local PlayerTab = Window:CreateTab("Player", 4483362458)

PlayerTab:CreateSection("Player Mods")

PlayerTab:CreateButton({
   Name = "Infinite Jump",
   Callback = function()
      local UIS = game:GetService("UserInputService")
      UIS.JumpRequest:Connect(function()
         game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
      end)
   end
})

-- VISUAL TAB
local VisualTab = Window:CreateTab("Visuals", 4483362458)

VisualTab:CreateSection("UI / Effects")

VisualTab:CreateToggle({
   Name = "FullBright",
   CurrentValue = false,
   Callback = function(Value)
      if Value then
         game.Lighting.Brightness = 5
         game.Lighting.ClockTime = 14
      else
         game.Lighting.Brightness = 2
      end
   end
})

-- NOTIFICATION
Rayfield:Notify({
   Title = "Brainrot Hub Loaded",
   Content = "Everything is ready.",
   Duration = 5
})
