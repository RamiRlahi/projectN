--[[
	UltimateUI – LocalScript
	Shows:
	  • Windup progress bar during the 3-second charge-up
	Place in StarterCharacterScripts
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = script.Parent

-- ═════════════════════════════════════════════════════════════
-- SCREEN GUI
-- ═════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "UltimateUI"
gui.ResetOnSpawn = true
gui.IgnoreGuiInset = false
gui.DisplayOrder = 10
gui.Parent = playerGui

-- ═════════════════════════════════════════════════════════════
-- WINDUP PROGRESS BAR (center-bottom, appears during windup)
-- ═════════════════════════════════════════════════════════════
local barContainer = Instance.new("Frame")
barContainer.Name = "WindupBar"
barContainer.Size = UDim2.new(0, 300, 0, 14)
barContainer.Position = UDim2.new(0.5, -150, 0.75, 0)
barContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
barContainer.BackgroundTransparency = 0.3
barContainer.BorderSizePixel = 0
barContainer.Visible = false
barContainer.Parent = gui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 7)
barCorner.Parent = barContainer

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(150, 150, 150)
barStroke.Thickness = 1.5
barStroke.Transparency = 0.4
barStroke.Parent = barContainer

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barContainer

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 7)
fillCorner.Parent = barFill

local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 80, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})
fillGradient.Parent = barFill

-- ═════════════════════════════════════════════════════════════
-- UPDATE LOOP
-- ═════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
	-- ── WINDUP BAR ──
	local isWindingUp = character:GetAttribute("IsWindingUp")
	if isWindingUp then
		barContainer.Visible = true
		local progress = character:GetAttribute("WindupProgress") or 0
		barFill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)

		-- Pulse the fill color brighter as it gets closer to full
		local brightness = 180 + progress * 75
		barFill.BackgroundColor3 = Color3.fromRGB(brightness, brightness, brightness)
	else
		if barContainer.Visible then
			barContainer.Visible = false
			barFill.Size = UDim2.new(0, 0, 1, 0)
		end
	end
end)
