local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Hide default cursor
UserInputService.MouseIconEnabled = false

-- Create GUI
local gui = Instance.new("ScreenGui")
gui.Name = "CustomCursor"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local cursor = Instance.new("TextLabel")
cursor.Size = UDim2.new(0,20,0,20)
cursor.BackgroundTransparency = 1
cursor.Text = "^"
cursor.TextScaled = true
cursor.Font = Enum.Font.GothamBold
cursor.TextColor3 = Color3.new(1,1,1)
cursor.AnchorPoint = Vector2.new(0.5,0.5)
cursor.Parent = gui

-- Update cursor position
RunService.RenderStepped:Connect(function()
	local mousePos = UserInputService:GetMouseLocation()
	cursor.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
end)