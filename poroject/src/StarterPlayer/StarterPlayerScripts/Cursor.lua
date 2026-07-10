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
gui.IgnoreGuiInset = true -- Fixes the 36-pixel topbar offset!
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

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.new(0, 90, 0, 22)
ammoLabel.BackgroundTransparency = 1
ammoLabel.Text = ""
ammoLabel.TextSize = 16
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextColor3 = Color3.new(1, 1, 1)
ammoLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
ammoLabel.TextStrokeTransparency = 0.35
ammoLabel.AnchorPoint = Vector2.new(0.5, 0)
ammoLabel.Visible = false
ammoLabel.Parent = gui

local function getAmmoText()
	local character = player.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	if not tool then return nil end

	local display = tool:GetAttribute("AmmoDisplay")
	if display then
		return tostring(display)
	end

	local ammo = tool:GetAttribute("Ammo")
	local maxAmmo = tool:GetAttribute("MaxAmmo")
	if typeof(ammo) == "number" and typeof(maxAmmo) == "number" then
		return string.format("%d / %d", ammo, maxAmmo)
	end

	return nil
end

-- Update cursor position
RunService.RenderStepped:Connect(function()
	local mousePos = UserInputService:GetMouseLocation()
	cursor.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)

	local ammoText = getAmmoText()
	ammoLabel.Position = UDim2.fromOffset(mousePos.X, mousePos.Y + 22)
	ammoLabel.Text = ammoText or ""
	ammoLabel.Visible = ammoText ~= nil
end)
