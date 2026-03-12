-- 3D SKILL GUI SYSTEM
-- Styled EXACTLY like the reference image
-- Opacity lowered (semi-transparent gray/black)
-- Position set to X=1, Y=-3

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- 1. Setup Player & GUI
local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Cleanup old frames
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "3d ui frame" then
		child:Destroy()
	end
end

-- Cooldown Manager integration
local CooldownManager = nil
pcall(function()
	CooldownManager = require(ReplicatedStorage:WaitForChild("CooldownManager"))
end)

-- ============================================
-- STEP 1: Creating the Part
-- ============================================
local frame = Instance.new("Part")
frame.Size = Vector3.new(100, 10, 0.5)
frame.CanCollide = false
frame.CanQuery = false
frame.CanTouch = false
frame.CastShadow = false
frame.Massless = true
frame.Transparency = 1
frame.Name = "3d ui frame"
frame.Parent = workspace

-- ============================================
-- STEP 2: Creating Surface GUI
-- ============================================
local uiPixelPerStuds = 512
local surface = Instance.new("SurfaceGui")
surface.Adornee = frame
surface.Face = Enum.NormalId.Back
surface.PixelsPerStud = uiPixelPerStuds 
surface.ClipsDescendants = false
surface.AlwaysOnTop = true
surface.ResetOnSpawn = false -- Ensure GUI stays when player respawns
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.Name = "SkillSurfaceGUI"
surface.Parent = playerGui

-- ============================================
-- UI Design (EXACT IMAGE REPLICA)
-- ============================================
local mainContainer = Instance.new("Frame")
mainContainer.Name = "SkillContainer"
mainContainer.Size = UDim2.new(1, 0, 1, 0)
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = surface

local skillLayout = Instance.new("UIListLayout")
skillLayout.Name = "SkillLayout"
skillLayout.FillDirection = Enum.FillDirection.Horizontal
skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
skillLayout.Padding = UDim.new(0, 120) -- Spacing between slots
skillLayout.Parent = mainContainer

-- SKILL LIST
local skillsData = {
	{key = "1", name = "Punch", isUltimate = false},
	{key = "2", name = "Leap", isUltimate = false},
	{key = "3", name = "Dash", isUltimate = false},
	{key = "R", name = "Ultimate", isUltimate = true},
}

local skillFrames = {}

-- SCALE FACTOR (Adjusted for visibility)
local SF = 1.66

for i, skillData in ipairs(skillsData) do
	local skillContainer = Instance.new("Frame")
	skillContainer.Name = "Skill_" .. skillData.key
	skillContainer.Size = UDim2.new(0, 100 * SF, 0, 180 * SF)
	skillContainer.BackgroundTransparency = 1
	skillContainer.Parent = mainContainer
	
	-- 1. Keybind Box (Matching image: semi-transparent dark background)
	local keybindBox = Instance.new("Frame")
	keybindBox.Size = UDim2.new(0, 50 * SF, 0, 50 * SF)
	keybindBox.Position = UDim2.new(0.5, -25 * SF, 0, 0)
	keybindBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	keybindBox.BackgroundTransparency = 0.5 -- Lower opacity as requested
	keybindBox.Parent = skillContainer
	
	local keybindStroke = Instance.new("UIStroke")
	keybindStroke.Color = Color3.new(1, 1, 1)
	keybindStroke.Thickness = 2.5 * SF
	keybindStroke.Parent = keybindBox
	
	local keybindCorner = Instance.new("UICorner")
	keybindCorner.CornerRadius = UDim.new(0, 8 * SF)
	keybindCorner.Parent = keybindBox
	
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = skillData.key
	keyLabel.TextColor3 = Color3.new(1, 1, 1)
	keyLabel.TextSize = 28 * SF
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Parent = keybindBox

	-- 2. Card Visual (Tilted)
	local cardSize = UDim2.new(0, 80 * SF, 0, 80 * SF)
	local cardPos = UDim2.new(0.5, -40 * SF, 0, 65 * SF)
	
	if skillData.isUltimate then
		cardSize = UDim2.new(0, 110 * SF, 0, 110 * SF)
		cardPos = UDim2.new(0.5, -55 * SF, 0, 65 * SF)
	end
	
	-- Shadow (Solid dark offset like in image)
	local cardShadow = Instance.new("Frame")
	cardShadow.Size = cardSize
	cardShadow.Position = cardPos + UDim2.new(0, 6 * SF, 0, 6 * SF)
	cardShadow.BackgroundColor3 = Color3.new(0, 0, 0)
	cardShadow.BackgroundTransparency = 0.4
	cardShadow.Rotation = 5 -- Angled separately
	cardShadow.BorderSizePixel = 0
	cardShadow.Parent = skillContainer
	
	-- Main Card (Semi-transparent dark gray)
	local cardMain = Instance.new("Frame")
	cardMain.Size = cardSize
	cardMain.Position = cardPos
	cardMain.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	cardMain.BackgroundTransparency = 0.3 -- Lower opacity, not fully black
	cardMain.ClipsDescendants = true
	cardMain.Rotation = 5 -- Angled separately
	cardMain.BorderSizePixel = 0
	cardMain.Parent = skillContainer
	
	-- Card Border
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.new(1, 1, 1)
	cardStroke.Thickness = 1.5 * SF
	cardStroke.Parent = cardMain
	
	-- Cooldown Overlay (The White Fill)
	local fillFrame = Instance.new("Frame")
	fillFrame.Name = "CooldownOverlay"
	fillFrame.Size = UDim2.new(1, 0, 1, 0)
	fillFrame.Position = UDim2.new(0, 0, 0, 0)
	fillFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	fillFrame.BackgroundTransparency = 0.1
	fillFrame.BorderSizePixel = 0
	fillFrame.ZIndex = 2
	fillFrame.Parent = cardMain

    -- Checkmark/Arrow Icon in bottom right corner (from image)
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 25 * SF, 0, 25 * SF)
    icon.Position = UDim2.new(1, -25 * SF, 1, -25 * SF)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://10650942544" 
    icon.ImageColor3 = Color3.new(0, 0, 0)
    icon.ZIndex = 3
    icon.Parent = cardMain

	-- Ultimate Text (Percentage)
	local chargeTextLabel = nil
	if skillData.isUltimate then
		chargeTextLabel = Instance.new("TextLabel")
		chargeTextLabel.Size = UDim2.new(1, 0, 1, 0)
		chargeTextLabel.BackgroundTransparency = 1
		chargeTextLabel.Text = "100%"
		chargeTextLabel.TextColor3 = Color3.new(1, 1, 1)
		chargeTextLabel.TextSize = 35 * SF
		chargeTextLabel.Font = Enum.Font.PermanentMarker
		chargeTextLabel.Rotation = -10 -- Angled separately
		chargeTextLabel.ZIndex = 5
		chargeTextLabel.Parent = cardMain
		
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 2 * SF
		textStroke.Color = Color3.new(0, 0, 0)
		textStroke.Parent = chargeTextLabel
	end

	table.insert(skillFrames, {
		fill = fillFrame,
		text = chargeTextLabel,
		data = skillData,
		keybindBox = keybindBox
	})
end

-- ============================================
-- STEP 3: RunServicing (EXACT POSITIONING)
-- ============================================
local function onRender()
	if not camera then return end
	
	local xRatio = camera.ViewportSize.X / camera.ViewportSize.Y
	local yRatio = camera.ViewportSize.Y / camera.ViewportSize.X
	
	-- Custom Position as requested: X=1, Y=-3
	local offset = Vector3.new(
		1.5 * xRatio,
		-3.2 * yRatio, 
		-3.5 -- Depth
	)

	local rotOffset = Vector3.new(0, 0, 0) -- Straightened as a whole (horizontal)
	local calculatedRot = CFrame.Angles(math.rad(rotOffset.X), math.rad(rotOffset.Y), math.rad(rotOffset.Z))
	
	local newCframe = camera.CFrame * CFrame.new(offset) * calculatedRot
	
	if frame then
		frame.CFrame = newCframe
	end
end

RunService:BindToRenderStep("3D_UI_System_Styled", Enum.RenderPriority.Camera.Value + 1, onRender)

-- ============================================
-- Cooldown & Feedback
-- ============================================
RunService.Heartbeat:Connect(function()
	if not CooldownManager then return end
	for _, skillFrame in ipairs(skillFrames) do
		local success, result = pcall(function() return CooldownManager:GetPercentage(skillFrame.data.name) end)
		local charge = 100
		if success and result then charge = result <= 1 and result * 100 or result end
		skillFrame.fill.Size = UDim2.new(1, 0, 1 - (charge / 100), 0)
		if skillFrame.text then skillFrame.text.Text = math.floor(charge) .. "%" end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	for _, skillFrame in ipairs(skillFrames) do
		local keyMap = {["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three, ["R"] = Enum.KeyCode.R}
		if input.KeyCode == keyMap[skillFrame.data.key] then
			skillFrame.keybindBox.BackgroundColor3 = Color3.new(1, 1, 1)
			skillFrame.keybindBox.BackgroundTransparency = 0.5
			task.delay(0.1, function() skillFrame.keybindBox.BackgroundTransparency = 1 end)
		end
	end
end)
