-- 3D SKILL GUI SYSTEM - V2 PREMIUM
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- 1. Setup Player & GUI
local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- Cleanup old frames
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "3d ui frame" then
		child:Destroy()
	end
end

-- Cooldown Manager integration
local CooldownManager = nil
local managerObj = ReplicatedStorage:FindFirstChild("CooldownManager")
if managerObj then
	pcall(function() CooldownManager = require(managerObj) end)
end

-- ============================================
-- STEP 1: Creating the Part
-- ============================================
local frame = Instance.new("Part")
frame.Size = Vector3.new(10, 4, 0.1) 
frame.CanCollide = false
frame.CanQuery = false
frame.CanTouch = false
frame.CastShadow = false
frame.Massless = true
frame.Transparency = 1 
frame.Name = "3d ui frame"
frame.Anchored = true
frame.Parent = workspace

-- ============================================
-- STEP 2: Creating Surface GUI
-- ============================================
local surface = Instance.new("SurfaceGui")
surface.Adornee = frame
surface.Face = Enum.NormalId.Back
surface.PixelsPerStud = 200 -- High enough for clarity, low enough to avoid points bug
surface.ClipsDescendants = false
surface.AlwaysOnTop = true
surface.ResetOnSpawn = false
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.Name = "SkillSurfaceGUI"
surface.Parent = playerGui

-- ============================================
-- UI Design
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
skillLayout.Padding = UDim.new(0, 100) 
skillLayout.Parent = mainContainer

-- SKILL LIST
local skillsData = {
	{key = "M2", name = "Dash", isUltimate = false, hasCharges = true},
	{key = "E", name = "Phase", isUltimate = false},
	{key = "F", name = "Slash", isUltimate = false},
	{key = "Q", name = "Ultimate", isUltimate = true},
}

local skillFrames = {}
local SF = 1.0 -- Balanced scale factor for the 200 PixelsPerStud

for i, skillData in ipairs(skillsData) do
	local skillContainer = Instance.new("Frame")
	skillContainer.Name = "Skill_" .. skillData.key
	skillContainer.Size = UDim2.new(0, 140 * SF, 0, 240 * SF)
	skillContainer.BackgroundTransparency = 1
	skillContainer.Parent = mainContainer
	
	-- 1. Keybind Box (Matching image: semi-transparent white/black balance)
	local keybindBox = Instance.new("Frame")
	keybindBox.Size = UDim2.new(0, 55 * SF, 0, 55 * SF)
	keybindBox.Position = UDim2.new(0.5, -27.5 * SF, 0, 0)
	keybindBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	keybindBox.BackgroundTransparency = 0.5
	keybindBox.Parent = skillContainer
	
	local keybindStroke = Instance.new("UIStroke")
	keybindStroke.Color = Color3.new(1, 1, 1)
	keybindStroke.Thickness = 3 * SF
	keybindStroke.Parent = keybindBox
	
	local keybindCorner = Instance.new("UICorner")
	keybindCorner.CornerRadius = UDim.new(0, 10 * SF)
	keybindCorner.Parent = keybindBox
	
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text = skillData.key
	keyLabel.TextColor3 = Color3.new(1, 1, 1)
	keyLabel.TextScaled = true
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Parent = keybindBox
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0.2, 0)
    padding.PaddingBottom = UDim.new(0.2, 0)
    padding.Parent = keyLabel

	-- 2. Card Visual (Tilted & Stylized)
	local cardSize = UDim2.new(0, 110 * SF, 0, 110 * SF)
	local cardPos = UDim2.new(0.5, -55 * SF, 0, 75 * SF)
	
	if skillData.isUltimate then
		cardSize = UDim2.new(0, 140 * SF, 0, 140 * SF)
		cardPos = UDim2.new(0.5, -70 * SF, 0, 75 * SF)
	end
	
	-- Shadow (Deeper shadow)
	local cardShadow = Instance.new("Frame")
	cardShadow.Size = cardSize
	cardShadow.Position = cardPos + UDim2.new(0, 8 * SF, 0, 8 * SF)
	cardShadow.BackgroundColor3 = Color3.new(0, 0, 0)
	cardShadow.BackgroundTransparency = 0.4
	cardShadow.Rotation = 5
	cardShadow.BorderSizePixel = 0
	cardShadow.Parent = skillContainer
	
	-- Main Card (Glassmorphism look)
	local cardMain = Instance.new("Frame")
	cardMain.Size = cardSize
	cardMain.Position = cardPos
	cardMain.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	cardMain.BackgroundTransparency = 0.3
	cardMain.ClipsDescendants = true
	cardMain.Rotation = 5
	cardMain.BorderSizePixel = 0
	cardMain.Parent = skillContainer
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.new(1, 1, 1)
	cardStroke.Thickness = 2 * SF
	cardStroke.Parent = cardMain
	
	-- Cooldown Overlay (The White Fill)
	local fillFrame = Instance.new("Frame")
	fillFrame.Name = "CooldownOverlay"
	fillFrame.Size = UDim2.new(1, 0, 1, 0)
	fillFrame.Position = UDim2.new(0, 0, 0, 0)
	fillFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	fillFrame.BackgroundTransparency = 0.3 -- Better visibility for fill
	fillFrame.BorderSizePixel = 0
	fillFrame.ZIndex = 2
	fillFrame.Parent = cardMain

    -- Icon (Correct corner icon)
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 35 * SF, 0, 35 * SF)
    icon.Position = UDim2.new(1, -35 * SF, 1, -35 * SF)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://10650942544" 
    icon.ImageColor3 = Color3.new(0, 0, 0)
    icon.ZIndex = 3
    icon.Parent = cardMain

	-- Ultimate Text (Percentage/READY)
	local chargeTextLabel = nil
	if skillData.isUltimate then
		chargeTextLabel = Instance.new("TextLabel")
		chargeTextLabel.Size = UDim2.new(1, 0, 1, 0)
		chargeTextLabel.BackgroundTransparency = 1
		chargeTextLabel.Text = "READY"
		chargeTextLabel.TextColor3 = Color3.new(1, 1, 1)
		chargeTextLabel.TextScaled = true
		chargeTextLabel.Font = Enum.Font.PermanentMarker
		chargeTextLabel.Rotation = -10
		chargeTextLabel.ZIndex = 5
		chargeTextLabel.Parent = cardMain
		
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 3 * SF
		textStroke.Color = Color3.new(0, 0, 0)
		textStroke.Parent = chargeTextLabel
	end

	-- 2.5 Skill Name Label (THE BOLD WORDS)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1.5, 0, 0, 40 * SF)
	nameLabel.Position = UDim2.new(-0.25, 0, 0, 215 * SF)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = skillData.name:upper()
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Parent = skillContainer
	
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2.5 * SF
	nameStroke.Color = Color3.new(0, 0, 0)
	nameStroke.Parent = nameLabel

	-- 3. Charges Circle (For Dash)
	local chargeCountLabel = nil
	if skillData.hasCharges then
		local chargeCircle = Instance.new("Frame")
		chargeCircle.Name = "ChargeCircle"
		chargeCircle.Size = UDim2.new(0, 45 * SF, 0, 45 * SF)
		chargeCircle.Position = UDim2.new(1, -22.5 * SF, 0, -22.5 * SF)
		chargeCircle.BackgroundColor3 = Color3.new(1, 1, 1)
		chargeCircle.BackgroundTransparency = 0
		chargeCircle.ZIndex = 10
		chargeCircle.Parent = cardMain
		
		local circleCorner = Instance.new("UICorner")
		circleCorner.CornerRadius = UDim.new(1, 0)
		circleCorner.Parent = chargeCircle
		
		local circleStroke = Instance.new("UIStroke")
		circleStroke.Color = Color3.new(0, 0, 0)
		circleStroke.Thickness = 3.5 * SF
		circleStroke.Parent = chargeCircle
		
		chargeCountLabel = Instance.new("TextLabel")
		chargeCountLabel.Size = UDim2.new(1, 0, 1, 0)
		chargeCountLabel.BackgroundTransparency = 1
		chargeCountLabel.Text = "3"
		chargeCountLabel.TextColor3 = Color3.new(0, 0, 0)
		chargeCountLabel.TextScaled = true
		chargeCountLabel.Font = Enum.Font.GothamBold
		chargeCountLabel.ZIndex = 11
		chargeCountLabel.Parent = chargeCircle
	end

	table.insert(skillFrames, {
		fill = fillFrame,
		text = chargeTextLabel,
		chargeText = chargeCountLabel,
		data = skillData,
		keybindBox = keybindBox
	})
end

-- ============================================
-- STEP 3: RunServicing (DYNAMIC POSITIONING)
-- ============================================
local function onRender()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.Y == 0 or camera.ViewportSize.X == 0 then return end
	
	local xRatio = camera.ViewportSize.X / camera.ViewportSize.Y
	
	-- Positioning: Aggressively pinned to the bottom-right corner
	local offset = Vector3.new(3.8 * xRatio, -3.2, -10.5)
	local newCframe = camera.CFrame * CFrame.new(offset)
	
	if frame then
		frame.CFrame = newCframe
	end
end

RunService:BindToRenderStep("3D_UI_System_PREMIUM", Enum.RenderPriority.Camera.Value + 1, onRender)

-- ============================================
-- Cooldown & Feedback Loop
-- ============================================
RunService.Heartbeat:Connect(function()
	local char = plr.Character
	for _, skillFrame in ipairs(skillFrames) do
		if skillFrame.data.hasCharges and char then
			local charges = char:GetAttribute(skillFrame.data.name .. "Charges") or 0
			local regenPercent = char:GetAttribute(skillFrame.data.name .. "RegenPercent") or 0
			
			if skillFrame.chargeText then skillFrame.chargeText.Text = tostring(charges) end
			
			local maxCharges = char:GetAttribute("Max" .. skillFrame.data.name .. "Charges") or 3
			if charges < maxCharges then
				skillFrame.fill.Size = UDim2.new(1, 0, 1 - regenPercent, 0)
			else
				skillFrame.fill.Size = UDim2.new(1, 0, 0, 0)
			end
		elseif CooldownManager then
			local success, result = pcall(function() return CooldownManager:GetPercentage(skillFrame.data.name) end)
			local charge = 100
			if success and result then charge = result <= 1 and result * 100 or result end
			
			if charge < 100 then
				skillFrame.fill.Size = UDim2.new(1, 0, 1 - (charge / 100), 0)
			else
				skillFrame.fill.Size = UDim2.new(1, 0, 0, 0)
			end
			
			if skillFrame.text then 
				skillFrame.text.Text = charge >= 100 and "READY" or math.floor(charge) .. "%"
			end
		else
			skillFrame.fill.Size = UDim2.new(1, 0, 0, 0)
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	for _, skillFrame in ipairs(skillFrames) do
		local key = skillFrame.data.key
		local isTriggered = false
		
		if key == "M2" then
			isTriggered = (input.UserInputType == Enum.UserInputType.MouseButton2)
		else
			local keyMap = {["E"] = Enum.KeyCode.E, ["F"] = Enum.KeyCode.F, ["Q"] = Enum.KeyCode.Q}
			isTriggered = (input.KeyCode == keyMap[key])
		end
		
		if isTriggered then
			skillFrame.keybindBox.BackgroundColor3 = Color3.new(1, 1, 1)
			skillFrame.keybindBox.BackgroundTransparency = 0.2
			task.delay(0.1, function() 
				if skillFrame and skillFrame.keybindBox then
					skillFrame.keybindBox.BackgroundTransparency = 0.5
					skillFrame.keybindBox.BackgroundColor3 = Color3.new(0, 0, 0)
				end
			end)
		end
	end
end)
