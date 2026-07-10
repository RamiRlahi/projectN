-- 3D SKILL GUI SYSTEM - V4 SCREEN GUI CIRCLE STYLE
-- Skills: bottom-center, large white circles with dark icon silhouettes
-- Keybind box above, name label below, charge badge top-right
-- Uses ScreenGui (not SurfaceGui) for reliable positioning & sizing

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local plr       = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- Remove leftover 3d parts from older versions
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "3d ui frame" then child:Destroy() end
end
-- Remove leftover SurfaceGui
for _, g in ipairs(playerGui:GetChildren()) do
	if g.Name == "SkillSurfaceGUI" then g:Destroy() end
end

-- Cooldown Manager integration (optional)
local CooldownManager = nil
local managerObj = ReplicatedStorage:FindFirstChild("CooldownManager")
if managerObj then
	pcall(function() CooldownManager = require(managerObj) end)
end

-- ============================================================
-- SCREEN GUI ROOT
-- ============================================================
-- Remove any old version
local oldGui = playerGui:FindFirstChild("SkillHUD")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "SkillHUD"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- ============================================================
-- SKILL DATA
-- ============================================================
local skillsData = {
	{key = "M2", name = "Dash",     isUltimate = false, hasCharges = true},
	{key = "E",  name = "Phase",    isUltimate = false},
	{key = "F",  name = "Slash",    isUltimate = false},
	{key = "Q",  name = "Ultimate", isUltimate = true},
}

-- ============================================================
-- LAYOUT CONTAINER  (centered at bottom of screen)
-- ============================================================
local CIRCLE_NORMAL = 80        -- px: normal skill circle diameter
local CIRCLE_ULT    = 100       -- px: ultimate circle diameter
local GAP           = 18        -- px: gap between slots
local KEYBIND_H     = 42        -- px: keybind box height
local LABEL_H       = 24        -- px: name label height
local SLOT_W_NORMAL = CIRCLE_NORMAL + 16
local SLOT_W_ULT    = CIRCLE_ULT    + 16

-- Total bar width
local totalW = (SLOT_W_NORMAL * 3) + SLOT_W_ULT + GAP * 3

local skillBar = Instance.new("Frame")
skillBar.Name                    = "SkillBar"
skillBar.Size                    = UDim2.new(0, totalW, 0, KEYBIND_H + CIRCLE_ULT + LABEL_H + 14)
skillBar.AnchorPoint             = Vector2.new(0.5, 1)
skillBar.Position                = UDim2.new(0.5, 0, 1, -24)
skillBar.BackgroundTransparency  = 1
skillBar.Parent                  = screenGui

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection          = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment    = Enum.HorizontalAlignment.Center
barLayout.VerticalAlignment      = Enum.VerticalAlignment.Bottom
barLayout.Padding                = UDim.new(0, GAP)
barLayout.Parent                 = skillBar

-- ============================================================
-- BUILD ONE SKILL SLOT
-- ============================================================
local skillFrames = {}

local function buildSkillSlot(skillData)
	local isUlt    = skillData.isUltimate
	local circleD  = isUlt and CIRCLE_ULT or CIRCLE_NORMAL
	local slotW    = circleD + 16

	-- Wrapper (vertical stack: keybind / circle / name)
	local slot = Instance.new("Frame")
	slot.Name                   = "Skill_" .. skillData.key
	slot.Size                   = UDim2.new(0, slotW, 1, 0)
	slot.BackgroundTransparency = 1
	slot.Parent                 = skillBar

	-- ── Keybind box ──
	local kbSize = math.min(circleD * 0.52, 44)

	local keybindBox = Instance.new("Frame")
	keybindBox.Name                  = "KeyBind"
	keybindBox.Size                  = UDim2.new(0, kbSize, 0, kbSize * 0.85)
	keybindBox.AnchorPoint           = Vector2.new(0.5, 0)
	keybindBox.Position              = UDim2.new(0.5, 0, 0, 0)
	keybindBox.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
	keybindBox.BackgroundTransparency = 0.42
	keybindBox.BorderSizePixel       = 0
	keybindBox.Parent                = slot

	local kbCorner = Instance.new("UICorner")
	kbCorner.CornerRadius = UDim.new(0, 7)
	kbCorner.Parent       = keybindBox

	local kbStroke = Instance.new("UIStroke")
	kbStroke.Color       = Color3.fromRGB(255, 255, 255)
	kbStroke.Thickness   = 2
	kbStroke.Transparency = 0.25
	kbStroke.Parent      = keybindBox

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size                 = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text                 = skillData.key
	keyLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
	keyLabel.TextScaled           = true
	keyLabel.Font                 = Enum.Font.GothamBold
	keyLabel.Parent               = keybindBox

	local kbPad = Instance.new("UIPadding")
	kbPad.PaddingTop    = UDim.new(0.12, 0)
	kbPad.PaddingBottom = UDim.new(0.12, 0)
	kbPad.PaddingLeft   = UDim.new(0.08, 0)
	kbPad.PaddingRight  = UDim.new(0.08, 0)
	kbPad.Parent        = keyLabel

	-- ── Main circle ──
	local circle = Instance.new("Frame")
	circle.Name                  = "Circle"
	circle.Size                  = UDim2.new(0, circleD, 0, circleD)
	circle.AnchorPoint           = Vector2.new(0.5, 0)
	circle.Position              = UDim2.new(0.5, 0, 0, kbSize * 0.85 + 6)
	circle.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
	circle.BackgroundTransparency = isUlt and 0.0 or 0.06
	circle.BorderSizePixel       = 0
	circle.ClipsDescendants      = false
	circle.Parent                = slot

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent       = circle

	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color       = Color3.fromRGB(255, 255, 255)
	circleStroke.Thickness   = isUlt and 3.5 or 2.5
	circleStroke.Transparency = 0.08
	circleStroke.Parent      = circle

	-- Glow behind circle (ultimate only)
	if isUlt then
		local glow = Instance.new("ImageLabel")
		glow.Name                  = "UltGlow"
		glow.Size                  = UDim2.new(0, circleD * 1.7, 0, circleD * 1.7)
		glow.AnchorPoint           = Vector2.new(0.5, 0.5)
		glow.Position              = UDim2.new(0.5, 0, 0.5, 0)
		glow.BackgroundTransparency = 1
		glow.Image                 = "rbxassetid://5028857084"   -- radial glow
		glow.ImageColor3           = Color3.fromRGB(255, 220, 60)
		glow.ImageTransparency     = 0.62
		glow.ZIndex                = 0
		glow.Parent                = circle
	end

	-- Icon (dark silhouette inside circle)
	local icon = Instance.new("ImageLabel")
	icon.Name                 = "Icon"
	icon.Size                 = UDim2.new(0, circleD * 0.54, 0, circleD * 0.54)
	icon.AnchorPoint          = Vector2.new(0.5, 0.5)
	icon.Position             = UDim2.new(0.5, 0, 0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image                = "rbxassetid://10650942544"
	icon.ImageColor3          = Color3.fromRGB(20, 20, 20)
	icon.ScaleType            = Enum.ScaleType.Fit
	icon.ZIndex               = 2
	icon.Parent               = circle

	-- Cooldown overlay (dark fill from top, recedes as cooldown expires)
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name              = "CooldownOverlay"
	cooldownOverlay.Size              = UDim2.new(1, 0, 0, 0)   -- height = 0 when ready
	cooldownOverlay.Position          = UDim2.new(0, 0, 0, 0)
	cooldownOverlay.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
	cooldownOverlay.BackgroundTransparency = 0.3
	cooldownOverlay.BorderSizePixel   = 0
	cooldownOverlay.ZIndex            = 3
	cooldownOverlay.ClipsDescendants  = true
	cooldownOverlay.Parent            = circle

	local ovCorner = Instance.new("UICorner")
	ovCorner.CornerRadius = UDim.new(1, 0)
	ovCorner.Parent       = cooldownOverlay

	-- Cooldown % text (inside overlay)
	local cdText = nil
	if not skillData.hasCharges then
		cdText = Instance.new("TextLabel")
		cdText.Size                  = UDim2.new(1, 0, 4, 0)  -- tall so it's always centered inside the circle even when overlay is partial
		cdText.Position              = UDim2.new(0, 0, 0, 0)
		cdText.AnchorPoint           = Vector2.new(0, 0)
		cdText.BackgroundTransparency = 1
		cdText.Text                  = ""
		cdText.TextColor3            = Color3.fromRGB(255, 255, 255)
		cdText.TextScaled            = true
		cdText.Font                  = Enum.Font.GothamBold
		cdText.ZIndex                = 6
		cdText.Parent                = cooldownOverlay
	end

	-- Ultimate READY text (over circle)
	local ultText = nil
	if isUlt then
		ultText = Instance.new("TextLabel")
		ultText.Size                  = UDim2.new(1, -4, 1, -4)
		ultText.AnchorPoint           = Vector2.new(0.5, 0.5)
		ultText.Position              = UDim2.new(0.5, 0, 0.5, 0)
		ultText.BackgroundTransparency = 1
		ultText.Text                  = "READY"
		ultText.TextColor3            = Color3.fromRGB(255, 230, 60)
		ultText.TextScaled            = true
		ultText.Font                  = Enum.Font.PermanentMarker
		ultText.Rotation              = -8
		ultText.ZIndex                = 5
		ultText.Parent                = circle

		local ultStroke = Instance.new("UIStroke")
		ultStroke.Thickness = 2.5
		ultStroke.Color     = Color3.fromRGB(0, 0, 0)
		ultStroke.Parent    = ultText
	end

	-- ── Skill name label (below circle) ──
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name                = "SkillName"
	nameLabel.Size                = UDim2.new(1.4, 0, 0, LABEL_H)
	nameLabel.AnchorPoint         = Vector2.new(0.5, 0)
	nameLabel.Position            = UDim2.new(0.5, 0, 0, kbSize * 0.85 + 6 + circleD + 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                = skillData.name:upper()
	nameLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled          = true
	nameLabel.Font                = Enum.Font.GothamBlack
	nameLabel.Parent              = slot

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Color     = Color3.fromRGB(0, 0, 0)
	nameStroke.Parent    = nameLabel

	-- ── Charge badge (top-right of circle) ──
	local chargeCountLabel = nil
	if skillData.hasCharges then
		local BADGE = math.floor(circleD * 0.38)

		local badge = Instance.new("Frame")
		badge.Name               = "ChargeBadge"
		badge.Size               = UDim2.new(0, BADGE, 0, BADGE)
		-- position relative to circle: top-right edge
		badge.Position           = UDim2.new(0.5, circleD / 2 - BADGE * 0.35, 0, kbSize * 0.85 + 6 - BADGE * 0.4)
		badge.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
		badge.BackgroundTransparency = 0
		badge.BorderSizePixel    = 0
		badge.ZIndex             = 10
		badge.Parent             = slot

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent       = badge

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color    = Color3.fromRGB(0, 0, 0)
		badgeStroke.Thickness = 2.5
		badgeStroke.Parent   = badge

		chargeCountLabel = Instance.new("TextLabel")
		chargeCountLabel.Size                 = UDim2.new(1, 0, 1, 0)
		chargeCountLabel.BackgroundTransparency = 1
		chargeCountLabel.Text                 = "3"
		chargeCountLabel.TextColor3           = Color3.fromRGB(0, 0, 0)
		chargeCountLabel.TextScaled           = true
		chargeCountLabel.Font                 = Enum.Font.GothamBold
		chargeCountLabel.ZIndex               = 11
		chargeCountLabel.Parent               = badge
	end

	table.insert(skillFrames, {
		fill       = cooldownOverlay,
		text       = cdText,
		ultText    = ultText,
		chargeText = chargeCountLabel,
		data       = skillData,
		keybindBox = keybindBox,
		circle     = circle,
	})
end

for _, sd in ipairs(skillsData) do
	buildSkillSlot(sd)
end

-- ============================================================
-- COOLDOWN & CHARGE UPDATE LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()
	local char = plr.Character
	for _, sf in ipairs(skillFrames) do
		if sf.data.hasCharges and char then
			local charges    = char:GetAttribute(sf.data.name .. "Charges") or 0
			local regenPct   = char:GetAttribute(sf.data.name .. "RegenPercent") or 0
			local maxCharges = char:GetAttribute("Max" .. sf.data.name .. "Charges") or 3

			if sf.chargeText then sf.chargeText.Text = tostring(charges) end

			if charges < maxCharges then
				sf.fill.Size = UDim2.new(1, 0, 1 - regenPct, 0)
			else
				sf.fill.Size = UDim2.new(1, 0, 0, 0)
			end

		elseif CooldownManager then
			local ok, result = pcall(function()
				return CooldownManager:GetPercentage(sf.data.name)
			end)
			local pct = 100
			if ok and result then
				pct = result <= 1 and result * 100 or result
			end

			if pct < 100 then
				sf.fill.Size     = UDim2.new(1, 0, 1 - (pct / 100), 0)
				sf.fill.Position = UDim2.new(0, 0, 0, 0)
			else
				sf.fill.Size = UDim2.new(1, 0, 0, 0)
			end

			if sf.text then
				sf.text.Text = pct >= 100 and "" or math.floor(pct) .. "%"
			end
			if sf.ultText then
				sf.ultText.Text      = pct >= 100 and "READY" or math.floor(pct) .. "%"
				sf.ultText.TextColor3 = pct >= 100
					and Color3.fromRGB(255, 230, 60)
					or  Color3.fromRGB(255, 255, 255)
			end
		else
			sf.fill.Size = UDim2.new(1, 0, 0, 0)
		end
	end
end)

-- ============================================================
-- INPUT FEEDBACK
-- ============================================================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	for _, sf in ipairs(skillFrames) do
		local key       = sf.data.key
		local triggered = false

		if key == "M2" then
			triggered = (input.UserInputType == Enum.UserInputType.MouseButton2)
		else
			local keyMap = {E = Enum.KeyCode.E, F = Enum.KeyCode.F, Q = Enum.KeyCode.Q}
			triggered    = (input.KeyCode == keyMap[key])
		end

		if triggered then
			TweenService:Create(sf.circle,     TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
			TweenService:Create(sf.keybindBox, TweenInfo.new(0.07),
				{BackgroundTransparency = 0.05, BackgroundColor3 = Color3.fromRGB(255,255,255)}):Play()

			task.delay(0.13, function()
				if sf.circle and sf.circle.Parent then
					TweenService:Create(sf.circle, TweenInfo.new(0.18),
						{BackgroundTransparency = sf.data.isUltimate and 0.0 or 0.06}):Play()
				end
				if sf.keybindBox and sf.keybindBox.Parent then
					TweenService:Create(sf.keybindBox, TweenInfo.new(0.18),
						{BackgroundTransparency = 0.42, BackgroundColor3 = Color3.fromRGB(0,0,0)}):Play()
				end
			end)
		end
	end
end)
