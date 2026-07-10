-- ============================================================
-- HUD.client.lua  ·  MASTER HUD SYSTEM
-- Sections:
--   1. Augment circles         (bottom-left)
--   2. Round timer + tracker   (top-center)
--   3. HP bars world-space     (green = player, red = enemy)
--   4. Skill circles           (bottom-center)  ← merged from 3D_Skill_GUI
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr       = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- Clean up any old leftover GUIs from previous versions
for _, g in ipairs(playerGui:GetChildren()) do
	if g.Name == "PremiumHUD" or g.Name == "SkillHUD" or g.Name == "SkillSurfaceGUI" then
		g:Destroy()
	end
end
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "3d ui frame" then child:Destroy() end
end

-- ============================================================
-- ROOT SCREEN GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MasterHUD"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- ============================================================
-- §1  AUGMENT CIRCLES  (bottom-left)
-- ============================================================
local AUGMENT_CIRCLE_SIZE = 36

local augmentHolder = Instance.new("Frame")
augmentHolder.Name                   = "AugmentHolder"
augmentHolder.Size                   = UDim2.new(0, 80, 0, 80) -- 2x2 grid of 36x36 with 6px padding
augmentHolder.AnchorPoint            = Vector2.new(0, 1)
augmentHolder.Position               = UDim2.new(0, 18, 1, -24)
augmentHolder.BackgroundTransparency = 1
augmentHolder.Parent                 = screenGui

local augmentLayout = Instance.new("UIGridLayout")
augmentLayout.CellSize            = UDim2.new(0, AUGMENT_CIRCLE_SIZE, 0, AUGMENT_CIRCLE_SIZE)
augmentLayout.CellPadding         = UDim2.new(0, 6, 0, 6)
augmentLayout.FillDirection       = Enum.FillDirection.Horizontal
augmentLayout.StartCorner         = Enum.StartCorner.TopLeft
augmentLayout.SortOrder           = Enum.SortOrder.LayoutOrder
augmentLayout.Parent              = augmentHolder

local augmentCount = 0

local function createAugmentCircle(iconId, label, color)
	augmentCount += 1
	local D = AUGMENT_CIRCLE_SIZE

	local card = Instance.new("Frame")
	card.Name                   = "Aug_" .. label
	card.Size                   = UDim2.new(0, D, 0, D)
	card.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
	card.BackgroundTransparency = 0.42
	card.BorderSizePixel        = 0
	card.LayoutOrder            = augmentCount
	card.Parent                 = augmentHolder

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 4)

	local cs = Instance.new("UIStroke", card)
	cs.Color       = Color3.fromRGB(255, 255, 255)
	cs.Thickness   = 1
	cs.Transparency = 0.65

	-- Icon
	local icon = Instance.new("ImageLabel", card)
	icon.Size                   = UDim2.new(0, D * 0.72, 0, D * 0.72)
	icon.AnchorPoint            = Vector2.new(0.5, 0.5)
	icon.Position               = UDim2.new(0.5, 0, 0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image                  = iconId
	icon.ImageColor3            = color or Color3.fromRGB(255, 255, 255)
	icon.ScaleType              = Enum.ScaleType.Fit
end

-- Default starter augments (replace icons with your real asset IDs)
local starterAugments = {
	{icon = "rbxassetid://10650942544", name = "Surge", color = Color3.fromRGB(220, 80, 220)}, -- Purple/pink
	{icon = "rbxassetid://10650942544", name = "Veil",  color = Color3.fromRGB(80, 220, 120)}, -- Green
	{icon = "rbxassetid://10650942544", name = "Echo",  color = Color3.fromRGB(80, 180, 255)}, -- Blue
}
for _, a in ipairs(starterAugments) do
	createAugmentCircle(a.icon, a.name, a.color)
end

-- API: other scripts → ReplicatedStorage.HUD_AddAugment:Invoke(iconId, label)
local augmentApi = Instance.new("BindableFunction")
augmentApi.Name   = "HUD_AddAugment"
augmentApi.Parent = ReplicatedStorage
augmentApi.OnInvoke = function(iconId, label, color)
	createAugmentCircle(iconId, label, color)
end

-- ============================================================
-- §2  TOP-CENTER  Round tracker + countdown timer
-- ============================================================
local TOTAL_ROUNDS = 5
local roundsWon    = 0

local topContainer = Instance.new("Frame")
topContainer.Name                   = "TopCenter"
topContainer.Size                   = UDim2.new(0, 280, 0, 92)
topContainer.AnchorPoint            = Vector2.new(0.5, 0)
topContainer.Position               = UDim2.new(0.5, 0, 0, 12)
topContainer.BackgroundTransparency = 1
topContainer.Parent                 = screenGui

-- Round tracker dots
local trackerHolder = Instance.new("Frame")
trackerHolder.Name                   = "RoundTracker"
trackerHolder.Size                   = UDim2.new(1, 0, 0, 26)
trackerHolder.BackgroundTransparency = 1
trackerHolder.Parent                 = topContainer

local trackerLayout = Instance.new("UIListLayout")
trackerLayout.FillDirection       = Enum.FillDirection.Horizontal
trackerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
trackerLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
trackerLayout.Padding             = UDim.new(0, 8)
trackerLayout.Parent              = trackerHolder

local trackerDots = {}
local function buildTrackerDots()
	for _, d in ipairs(trackerDots) do d:Destroy() end
	trackerDots = {}
	for i = 1, TOTAL_ROUNDS do
		local dot = Instance.new("Frame")
		dot.Size                   = UDim2.new(0, 20, 0, 20)
		dot.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
		dot.BackgroundTransparency = i <= roundsWon and 0 or 0.72
		dot.BorderSizePixel        = 0
		dot.Parent                 = trackerHolder

		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

		local ds = Instance.new("UIStroke", dot)
		ds.Color     = Color3.fromRGB(255, 255, 255)
		ds.Thickness = 2

		table.insert(trackerDots, dot)
	end
end
buildTrackerDots()

-- Timer box
local timerFrame = Instance.new("Frame")
timerFrame.Name                   = "TimerFrame"
timerFrame.Size                   = UDim2.new(0, 185, 0, 54)
timerFrame.AnchorPoint            = Vector2.new(0.5, 0)
timerFrame.Position               = UDim2.new(0.5, 0, 0, 30)
timerFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
timerFrame.BackgroundTransparency = 0.42
timerFrame.BorderSizePixel        = 0
timerFrame.Parent                 = topContainer

Instance.new("UICorner", timerFrame).CornerRadius = UDim.new(0, 10)

local tfStroke = Instance.new("UIStroke", timerFrame)
tfStroke.Color       = Color3.fromRGB(255, 255, 255)
tfStroke.Thickness   = 1.5
tfStroke.Transparency = 0.5

-- "ROUND 1" label
local roundLabel = Instance.new("TextLabel", timerFrame)
roundLabel.Size                   = UDim2.new(1, 0, 0, 22)
roundLabel.Position               = UDim2.new(0, 0, 0, 4)
roundLabel.BackgroundTransparency = 1
roundLabel.Text                   = "ROUND 1"
roundLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
roundLabel.TextScaled             = true
roundLabel.Font                   = Enum.Font.GothamBlack

local rls = Instance.new("UIStroke", roundLabel)
rls.Thickness = 1.5; rls.Color = Color3.fromRGB(0,0,0)

-- "0:30" countdown
local timerLabel = Instance.new("TextLabel", timerFrame)
timerLabel.Size                   = UDim2.new(1, 0, 0, 28)
timerLabel.Position               = UDim2.new(0, 0, 1, -30)
timerLabel.BackgroundTransparency = 1
timerLabel.Text                   = "0:30"
timerLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
timerLabel.TextScaled             = true
timerLabel.Font                   = Enum.Font.GothamBold

local tls = Instance.new("UIStroke", timerLabel)
tls.Thickness = 1.5; tls.Color = Color3.fromRGB(0,0,0)

-- Timer heartbeat
local lastFlash = 0
RunService.Heartbeat:Connect(function()
	local timeLeft = ReplicatedStorage:GetAttribute("RoundTime") or 30

	-- Format
	local secs = math.max(0, math.floor(timeLeft))
	timerLabel.Text = string.format("%d:%02d", math.floor(secs/60), secs%60)

	-- Flash red below 10 s
	if timeLeft <= 10 then
		local now = tick()
		if now - lastFlash > 0.5 then
			lastFlash = now
			timerLabel.TextColor3 = timerLabel.TextColor3 == Color3.fromRGB(255,80,80)
				and Color3.fromRGB(255,255,255) or Color3.fromRGB(255,80,80)
		end
	else
		timerLabel.TextColor3 = Color3.fromRGB(255,255,255)
	end

	-- Round label
	local r = ReplicatedStorage:GetAttribute("CurrentRound") or 1
	roundLabel.Text = "ROUND " .. tostring(r)

	-- Tracker dots
	local w = ReplicatedStorage:GetAttribute("RoundsWon") or 0
	if w ~= roundsWon then
		roundsWon = w
		buildTrackerDots()
	end
end)

-- ============================================================
-- §3  HP BARS  (BillboardGui, world-space)
-- ============================================================
-- Player = green bar   |   Enemy = red bar
-- TODO: make vertical + stylized in next iteration

local function createHPBar(character, isEnemy)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root     = character:FindFirstChild("HumanoidRootPart")
		          or character:FindFirstChildWhichIsA("BasePart")
	if not humanoid or not root then return end

	-- Don't add a duplicate
	if root:FindFirstChild(isEnemy and "EnemyHPBar" or "PlayerHPBar") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name           = isEnemy and "EnemyHPBar" or "PlayerHPBar"
	billboard.Size           = UDim2.new(0, 180, 0, 40)
	billboard.StudsOffset    = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop    = false
	billboard.LightInfluence = 0
	billboard.Adornee        = root
	billboard.Parent         = root

	-- Background track
	local bg = Instance.new("Frame", billboard)
	bg.Size                   = UDim2.new(1, 0, 0, 22)
	bg.AnchorPoint            = Vector2.new(0, 0.5)
	bg.Position               = UDim2.new(0, 0, 0.5, 0)
	bg.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel        = 0

	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)

	local bgStroke = Instance.new("UIStroke", bg)
	bgStroke.Color     = isEnemy and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(50, 200, 50)
	bgStroke.Thickness = 1.5

	-- Fill
	local fill = Instance.new("Frame", bg)
	fill.Name                  = "Fill"
	fill.Size                  = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3      = isEnemy and Color3.fromRGB(220, 45, 45) or Color3.fromRGB(55, 210, 55)
	fill.BorderSizePixel       = 0
	fill.ClipsDescendants      = true

	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

	-- Shine
	local shine = Instance.new("Frame", fill)
	shine.Size                   = UDim2.new(1, 0, 0.42, 0)
	shine.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.80
	shine.BorderSizePixel        = 0

	-- HP text
	local hpLabel = Instance.new("TextLabel", bg)
	hpLabel.Size                   = UDim2.new(1, -6, 1, 0)
	hpLabel.Position               = UDim2.new(0, 3, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	hpLabel.TextScaled             = true
	hpLabel.Font                   = Enum.Font.GothamBold
	hpLabel.Text                   = "100 / 100"
	hpLabel.ZIndex                 = 5

	local hls = Instance.new("UIStroke", hpLabel)
	hls.Thickness = 1.5; hls.Color = Color3.fromRGB(0,0,0)

	-- Update connection
	local conn = RunService.Heartbeat:Connect(function()
		if not humanoid or not humanoid.Parent then return end
		local pct  = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		fill.Size  = UDim2.new(pct, 0, 1, 0)
		hpLabel.Text = math.ceil(humanoid.Health) .. " / " .. math.ceil(humanoid.MaxHealth)
	end)

	humanoid.Died:Connect(function()
		task.delay(4, function()
			conn:Disconnect()
			if billboard and billboard.Parent then billboard:Destroy() end
		end)
	end)
end

-- ============================================================
-- §3b  PLAYER SCREEN HEALTH BAR (Tapered, Floating HP Text)
-- ============================================================
local screenHPFrame = Instance.new("Frame")
screenHPFrame.Name                   = "ScreenHPFrame"
screenHPFrame.Size                   = UDim2.new(0, 150, 0, 160)
screenHPFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
screenHPFrame.Position               = UDim2.new(0.5, 0, 0.5, 0)
screenHPFrame.BackgroundTransparency = 1
screenHPFrame.Rotation               = -12
screenHPFrame.ClipsDescendants       = false
screenHPFrame.Parent                 = screenGui

local barFrame = Instance.new("Frame")
barFrame.Name                   = "BarFrame"
barFrame.Size                   = UDim2.new(0, 48, 1, 0)
barFrame.Position               = UDim2.new(0, 0, 0, 0)
barFrame.BackgroundTransparency = 1
barFrame.ClipsDescendants       = false
barFrame.Parent                 = screenHPFrame

local fillSegments = {}

for i = 1, 80 do
	local ratio = i / 80
	
	-- Taper width: 36 at the top (i=80) down to 18 at the bottom (i=1)
	local w_outer = math.floor(18 + (36 - 18) * ratio)
	local w_border = w_outer + 2
	local w_inner = math.max(2, w_outer - 4)

	-- Border segment (black outline frame)
	local segBorder = Instance.new("Frame")
	segBorder.Name                   = "SegBorder_" .. i
	segBorder.Size                   = UDim2.new(0, w_border, 0, 2)
	segBorder.Position               = UDim2.new(0.5, 0, 1 - ratio, 0)
	segBorder.AnchorPoint            = Vector2.new(0.5, 0)
	segBorder.BackgroundColor3       = Color3.fromRGB(0, 0, 0) -- black outline border
	segBorder.BorderSizePixel        = 0
	segBorder.ZIndex                 = 1
	segBorder.Parent                 = barFrame

	-- Outer segment (dark green frame)
	local segOuter = Instance.new("Frame")
	segOuter.Name                   = "SegOuter_" .. i
	segOuter.Size                   = UDim2.new(0, w_outer, 1, 0)
	segOuter.Position               = UDim2.new(0.5, 0, 0.5, 0)
	segOuter.AnchorPoint            = Vector2.new(0.5, 0.5)
	segOuter.BackgroundColor3       = Color3.fromRGB(15, 60, 20) -- dark green outer frame
	segOuter.BorderSizePixel        = 0
	segOuter.ZIndex                 = 2
	segOuter.Parent                 = segBorder

	-- Inner segment (black panel / green health fill)
	local segInner = Instance.new("Frame")
	segInner.Name                   = "SegInner_" .. i
	segInner.Size                   = UDim2.new(0, w_inner, 1, 0)
	segInner.Position               = UDim2.new(0.5, 0, 0.5, 0)
	segInner.AnchorPoint            = Vector2.new(0.5, 0.5)
	segInner.BackgroundColor3       = Color3.fromRGB(0, 0, 0) -- initially black inner panel
	segInner.BorderSizePixel        = 0
	segInner.ZIndex                 = 3
	segInner.Parent                 = segOuter

	fillSegments[i] = segInner
end

-- Floating HP text pane (ZIndex = 4, dark green/black card, fixed in middle)
local hpPane = Instance.new("Frame")
hpPane.Name                   = "HPPane"
hpPane.Size                   = UDim2.new(0, 92, 0, 40)
hpPane.AnchorPoint            = Vector2.new(0, 0.5)
hpPane.Position               = UDim2.new(0, 40, 0.5, 0) -- fixed in the middle vertically and horizontally relative to the bar
hpPane.BackgroundColor3       = Color3.fromRGB(15, 30, 15) -- dark green/black
hpPane.BorderSizePixel        = 0
hpPane.ZIndex                 = 4
hpPane.ClipsDescendants       = false
hpPane.Parent                 = screenHPFrame

local paneCorner = Instance.new("UICorner", hpPane)
paneCorner.CornerRadius = UDim.new(0, 3)

local paneStroke = Instance.new("UIStroke", hpPane)
paneStroke.Color = Color3.fromRGB(15, 60, 20) -- dark green outline matching frame
paneStroke.Thickness = 1.5

-- Floating HP text shadow (ZIndex = 5, black)
local hpTextShadow = Instance.new("TextLabel")
hpTextShadow.Name                   = "HPTextShadow"
hpTextShadow.Size                   = UDim2.new(0, 80, 0, 36)
hpTextShadow.AnchorPoint            = Vector2.new(0, 0)
hpTextShadow.Position               = UDim2.new(0, 10, 0, -12)
hpTextShadow.BackgroundTransparency = 1
hpTextShadow.Text                   = "100"
hpTextShadow.TextColor3             = Color3.fromRGB(0, 0, 0)
hpTextShadow.TextSize               = 28
hpTextShadow.Font                   = Enum.Font.GothamBlack
hpTextShadow.TextScaled             = false
hpTextShadow.TextTransparency       = 0.4
hpTextShadow.ZIndex                 = 5
hpTextShadow.ClipsDescendants       = false
hpTextShadow.Parent                 = hpPane

-- Floating HP text label (ZIndex = 6, white)
local hpTextLabel = Instance.new("TextLabel")
hpTextLabel.Name                   = "HPTextLabel"
hpTextLabel.Size                   = UDim2.new(0, 80, 0, 36)
hpTextLabel.AnchorPoint            = Vector2.new(0, 0)
hpTextLabel.Position               = UDim2.new(0, 8, 0, -14)
hpTextLabel.BackgroundTransparency = 1
hpTextLabel.Text                   = "100"
hpTextLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
hpTextLabel.TextSize               = 28
hpTextLabel.Font                   = Enum.Font.GothamBlack
hpTextLabel.TextScaled             = false
hpTextLabel.ZIndex                 = 6
hpTextLabel.ClipsDescendants       = false
hpTextLabel.Parent                 = hpPane

-- Thick black outline for main text
local textStroke = Instance.new("UIStroke", hpTextLabel)
textStroke.Color = Color3.fromRGB(0, 0, 0)
textStroke.Thickness = 3.5

-- Max HP label (ZIndex = 6, light green, bottom-right)
local maxHpLabel = Instance.new("TextLabel")
maxHpLabel.Name                   = "MaxHPLabel"
maxHpLabel.Size                   = UDim2.new(0, 50, 0, 18)
maxHpLabel.AnchorPoint            = Vector2.new(0, 0)
maxHpLabel.Position               = UDim2.new(0, 38, 0.45, 0)
maxHpLabel.BackgroundTransparency = 1
maxHpLabel.Text                   = "/ 100"
maxHpLabel.TextColor3             = Color3.fromRGB(115, 190, 75) -- light green
maxHpLabel.TextSize               = 16
maxHpLabel.Font                   = Enum.Font.GothamBold
maxHpLabel.TextScaled             = false
maxHpLabel.ZIndex                 = 6
maxHpLabel.ClipsDescendants       = false
maxHpLabel.Parent                 = hpPane

local maxTextStroke = Instance.new("UIStroke", maxHpLabel)
maxTextStroke.Color = Color3.fromRGB(0, 0, 0)
maxTextStroke.Thickness = 1.5

local hpUpdateConn = nil

local function setupPlayerScreenHP(char)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	if hpUpdateConn then
		hpUpdateConn:Disconnect()
		hpUpdateConn = nil
	end

	local currentHP = humanoid.Health
	local maxHP = math.max(humanoid.MaxHealth, 1)
	local displayedHP = currentHP

	local function updateHP(dt)
		currentHP = humanoid.Health
		maxHP = math.max(humanoid.MaxHealth, 1)
		
		-- Smoothly interpolate (lerp) the HP number
		local lerpSpeed = 8
		displayedHP = displayedHP + (currentHP - displayedHP) * math.clamp(dt * lerpSpeed, 0, 1)
		
		local pct = math.clamp(displayedHP / maxHP, 0, 1)
		
		-- Update segments (green fill for parts <= current health percentage, black inner panel otherwise)
		-- We also keep the bottom 2 segments and top 2 segments as solid dark green to form top/bottom frame borders
		for i = 1, 80 do
			local segRatio = i / 80
			local fillSegment = fillSegments[i]
			if fillSegment then
				if i <= 2 or i >= 79 then
					fillSegment.BackgroundColor3 = Color3.fromRGB(15, 60, 20) -- top/bottom frame cap
				elseif segRatio <= pct then
					fillSegment.BackgroundColor3 = Color3.fromRGB(115, 190, 75) -- green health fill
				else
					fillSegment.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- black inner panel
				end
			end
		end

		-- Update numeric values
		local displayVal = math.ceil(displayedHP)
		hpTextLabel.Text = tostring(displayVal)
		hpTextShadow.Text = tostring(displayVal)
		maxHpLabel.Text = "/ " .. tostring(math.ceil(maxHP))

		-- Dynamically follow the player character position on screen
		local rootPart = char:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local camera = workspace.CurrentCamera
			-- Project character's left side (4 studs left, 0.3 studs up) to screen coordinates
			local worldPos = rootPart.CFrame * Vector3.new(-8, 0, -2)
			local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
			if onScreen then
				screenHPFrame.Visible = true
				screenHPFrame.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
			else
				screenHPFrame.Visible = false
			end
		else
			screenHPFrame.Visible = false
		end
	end

	hpUpdateConn = RunService.Heartbeat:Connect(updateHP)

	humanoid.Died:Connect(function()
		if hpUpdateConn then
			hpUpdateConn:Disconnect()
			hpUpdateConn = nil
		end
		screenHPFrame.Visible = false
	end)
end

if plr.Character then setupPlayerScreenHP(plr.Character) end
plr.CharacterAdded:Connect(setupPlayerScreenHP)

-- Hook enemies / NPCs
local function onDescendant(desc)
	if not desc:IsA("Humanoid") then return end
	local char = desc.Parent
	if Players:GetPlayerFromCharacter(char) == plr then return end
	task.delay(0.15, function()
		if char and char.Parent then
			createHPBar(char, true)
		end
	end)
end
for _, d in ipairs(workspace:GetDescendants()) do onDescendant(d) end
workspace.DescendantAdded:Connect(onDescendant)

-- ============================================================
-- §4  SKILL CIRCLES  (bottom-center)  — merged from 3D_Skill_GUI
-- ============================================================
local CooldownManager = nil
local cm = ReplicatedStorage:FindFirstChild("CooldownManager")
if cm then pcall(function() CooldownManager = require(cm) end) end

local skillsData = {
	{key = "M2", name = "Dash",     hasCharges = true,  isUltimate = false},
	{key = "E",  name = "Phase",    hasCharges = false,  isUltimate = false},
	{key = "F",  name = "Slash",    hasCharges = false,  isUltimate = false},
	{key = "Q",  name = "Ultimate", hasCharges = false,  isUltimate = true},
}

-- Sizes
local CD_NORMAL = 40
local CD_ULT    = 40
local SK_GAP    = 10

-- Calculate total bar width
local totalSkillW = 0
for _, sd in ipairs(skillsData) do
	totalSkillW += (sd.isUltimate and CD_ULT or CD_NORMAL) + 8
end
totalSkillW += SK_GAP * (#skillsData - 1)

local skillBar = Instance.new("Frame")
skillBar.Name                   = "SkillBar"
skillBar.Size                   = UDim2.new(0, totalSkillW, 0, CD_ULT + 40)
skillBar.AnchorPoint            = Vector2.new(0.5, 1)
skillBar.Position               = UDim2.new(0.5, 0, 1, -20)
skillBar.BackgroundTransparency = 1
skillBar.Parent                 = screenGui

local skillBarLayout = Instance.new("UIListLayout")
skillBarLayout.FillDirection       = Enum.FillDirection.Horizontal
skillBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillBarLayout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
skillBarLayout.Padding             = UDim.new(0, SK_GAP)
skillBarLayout.SortOrder           = Enum.SortOrder.LayoutOrder
skillBarLayout.Parent              = skillBar

local skillFrames = {}

for idx, sd in ipairs(skillsData) do
	local isUlt   = sd.isUltimate
	local circleD = isUlt and CD_ULT or CD_NORMAL
	local slotW   = circleD + 8
	local KB_H    = math.floor(circleD * 0.48)  -- keybind box height

	local slot = Instance.new("Frame")
	slot.Name                   = "Skill_" .. sd.key
	slot.Size                   = UDim2.new(0, slotW, 1, 0)
	slot.BackgroundTransparency = 1
	slot.LayoutOrder            = idx
	slot.Parent                 = skillBar

	-- ── Keybind box ──────────────────────────────────────────
	local kbW = math.floor(circleD * 0.50)

	local keybindBox = Instance.new("Frame")
	keybindBox.Name                   = "KeyBind"
	keybindBox.Size                   = UDim2.new(0, kbW, 0, KB_H)
	keybindBox.AnchorPoint            = Vector2.new(0.5, 0)
	keybindBox.Position               = UDim2.new(0.5, 0, 0, 0)
	keybindBox.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	keybindBox.BackgroundTransparency = 0.42
	keybindBox.BorderSizePixel        = 0
	keybindBox.Parent                 = slot

	Instance.new("UICorner", keybindBox).CornerRadius = UDim.new(0, 4)

	local kbs = Instance.new("UIStroke", keybindBox)
	kbs.Color       = Color3.fromRGB(255, 255, 255)
	kbs.Thickness   = 1
	kbs.Transparency = 0.25

	local keyLabel = Instance.new("TextLabel", keybindBox)
	keyLabel.Size                   = UDim2.new(1, 0, 1, 0)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Text                   = sd.key
	keyLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	keyLabel.TextScaled             = true
	keyLabel.Font                   = Enum.Font.GothamBold

	local klPad = Instance.new("UIPadding", keyLabel)
	klPad.PaddingTop    = UDim.new(0.10, 0)
	klPad.PaddingBottom = UDim.new(0.10, 0)
	klPad.PaddingLeft   = UDim.new(0.08, 0)
	klPad.PaddingRight  = UDim.new(0.08, 0)

	-- ── Main circle ──────────────────────────────────────────
	local circle = Instance.new("Frame")
	circle.Name                   = "Circle"
	circle.Size                   = UDim2.new(0, circleD, 0, circleD)
	circle.AnchorPoint            = Vector2.new(0.5, 0)
	circle.Position               = UDim2.new(0.5, 0, 0, KB_H + 3)
	circle.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
	circle.BackgroundTransparency = isUlt and 0.0 or 0.06
	circle.BorderSizePixel        = 0
	circle.ClipsDescendants       = false
	circle.Parent                 = slot

	Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

	local cs = Instance.new("UIStroke", circle)
	cs.Color       = Color3.fromRGB(255, 255, 255)
	cs.Thickness   = isUlt and 1.75 or 1.25
	cs.Transparency = 0.08

	-- Ultimate glow ring
	if isUlt then
		local glow = Instance.new("ImageLabel", circle)
		glow.Size                   = UDim2.new(0, circleD * 1.65, 0, circleD * 1.65)
		glow.AnchorPoint            = Vector2.new(0.5, 0.5)
		glow.Position               = UDim2.new(0.5, 0, 0.5, 0)
		glow.BackgroundTransparency = 1
		glow.Image                  = "rbxassetid://5028857084"
		glow.ImageColor3            = Color3.fromRGB(255, 215, 50)
		glow.ImageTransparency      = 0.60
		glow.ZIndex                 = 0
	end

	-- Icon (dark silhouette)
	local icon = Instance.new("ImageLabel", circle)
	icon.Size                   = UDim2.new(0, circleD * 0.54, 0, circleD * 0.54)
	icon.AnchorPoint            = Vector2.new(0.5, 0.5)
	icon.Position               = UDim2.new(0.5, 0, 0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image                  = "rbxassetid://10650942544"
	icon.ImageColor3            = Color3.fromRGB(20, 20, 20)
	icon.ScaleType              = Enum.ScaleType.Fit
	icon.ZIndex                 = 2

	-- Cooldown overlay (dark fill from top)
	local overlay = Instance.new("Frame", circle)
	overlay.Name                   = "Overlay"
	overlay.Size                   = UDim2.new(1, 0, 0, 0)
	overlay.Position               = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.30
	overlay.BorderSizePixel        = 0
	overlay.ZIndex                 = 3
	overlay.ClipsDescendants       = true

	Instance.new("UICorner", overlay).CornerRadius = UDim.new(1, 0)

	-- Cooldown % text (non-charge skills)
	local cdText = nil
	if not sd.hasCharges then
		cdText = Instance.new("TextLabel", overlay)
		cdText.Size                   = UDim2.new(1, 0, 6, 0)  -- tall so centered in circle
		cdText.BackgroundTransparency = 1
		cdText.Text                   = ""
		cdText.TextColor3             = Color3.fromRGB(255, 255, 255)
		cdText.TextScaled             = true
		cdText.Font                   = Enum.Font.GothamBold
		cdText.ZIndex                 = 6
	end

	-- Ultimate READY text
	local ultText = nil
	if isUlt then
		ultText = Instance.new("TextLabel", circle)
		ultText.Size                   = UDim2.new(0.9, 0, 0.9, 0)
		ultText.AnchorPoint            = Vector2.new(0.5, 0.5)
		ultText.Position               = UDim2.new(0.5, 0, 0.5, 0)
		ultText.BackgroundTransparency = 1
		ultText.Text                   = "READY"
		ultText.TextColor3             = Color3.fromRGB(255, 230, 55)
		ultText.TextScaled             = true
		ultText.Font                   = Enum.Font.PermanentMarker
		ultText.Rotation               = -8
		ultText.ZIndex                 = 5

		local uts = Instance.new("UIStroke", ultText)
		uts.Thickness = 1.25; uts.Color = Color3.fromRGB(0,0,0)
	end

	-- Skill name label (below circle)
	local nameLabel = Instance.new("TextLabel", slot)
	nameLabel.Size                   = UDim2.new(1.5, 0, 0, 11)
	nameLabel.AnchorPoint            = Vector2.new(0.5, 0)
	nameLabel.Position               = UDim2.new(0.5, 0, 0, KB_H + 3 + circleD + 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                   = sd.name:upper()
	nameLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled             = true
	nameLabel.Font                   = Enum.Font.GothamBlack

	local nls = Instance.new("UIStroke", nameLabel)
	nls.Thickness = 1; nls.Color = Color3.fromRGB(0,0,0)

	-- Charge badge (top-right, only for charge-based skills)
	local chargeLabel = nil
	if sd.hasCharges then
		local BADGE = math.floor(circleD * 0.38)

		local badge = Instance.new("Frame", slot)
		badge.Size                 = UDim2.new(0, BADGE, 0, BADGE)
		badge.Position             = UDim2.new(0.5, circleD/2 - BADGE*0.32, 0, KB_H + 3 - BADGE*0.42)
		badge.BackgroundColor3     = Color3.fromRGB(255, 255, 255)
		badge.BackgroundTransparency = 0
		badge.BorderSizePixel      = 0
		badge.ZIndex               = 10

		Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)

		local bs = Instance.new("UIStroke", badge)
		bs.Color = Color3.fromRGB(0,0,0); bs.Thickness = 1.25

		chargeLabel = Instance.new("TextLabel", badge)
		chargeLabel.Size                   = UDim2.new(1, 0, 1, 0)
		chargeLabel.BackgroundTransparency = 1
		chargeLabel.Text                   = "3"
		chargeLabel.TextColor3             = Color3.fromRGB(0, 0, 0)
		chargeLabel.TextScaled             = true
		chargeLabel.Font                   = Enum.Font.GothamBold
		chargeLabel.ZIndex                 = 11
	end

	table.insert(skillFrames, {
		overlay    = overlay,
		cdText     = cdText,
		ultText    = ultText,
		chargeText = chargeLabel,
		keybindBox = keybindBox,
		circle     = circle,
		data       = sd,
	})
end

-- ── Skill cooldown/charge update loop ────────────────────────
RunService.Heartbeat:Connect(function()
	local char = plr.Character
	for _, sf in ipairs(skillFrames) do
		local sd = sf.data

		if sd.hasCharges and char then
			local charges    = char:GetAttribute(sd.name .. "Charges")    or 0
			local regenPct   = char:GetAttribute(sd.name .. "RegenPercent") or 0
			local maxCharges = char:GetAttribute("Max" .. sd.name .. "Charges") or 3

			if sf.chargeText then sf.chargeText.Text = tostring(charges) end

			sf.overlay.Size = charges < maxCharges
				and UDim2.new(1, 0, 1 - regenPct, 0)
				or  UDim2.new(1, 0, 0, 0)

		elseif CooldownManager then
			local ok, result = pcall(function()
				return CooldownManager:GetPercentage(sd.name)
			end)
			local pct = 100
			if ok and result then
				pct = result <= 1 and result * 100 or result
			end

			if pct < 100 then
				sf.overlay.Size     = UDim2.new(1, 0, 1 - pct/100, 0)
				sf.overlay.Position = UDim2.new(0, 0, 0, 0)
			else
				sf.overlay.Size = UDim2.new(1, 0, 0, 0)
			end

			if sf.cdText then
				sf.cdText.Text = pct >= 100 and "" or math.floor(pct) .. "%"
			end
			if sf.ultText then
				sf.ultText.Text      = pct >= 100 and "READY" or math.floor(pct) .. "%"
				sf.ultText.TextColor3 = pct >= 100
					and Color3.fromRGB(255, 230, 55)
					or  Color3.fromRGB(255, 255, 255)
			end
		else
			sf.overlay.Size = UDim2.new(1, 0, 0, 0)
		end
	end
end)

-- ── Input flash feedback ──────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	for _, sf in ipairs(skillFrames) do
		local key       = sf.data.key
		local triggered = false

		if key == "M2" then
			triggered = (input.UserInputType == Enum.UserInputType.MouseButton2)
		else
			local map = {E = Enum.KeyCode.E, F = Enum.KeyCode.F, Q = Enum.KeyCode.Q}
			triggered = (input.KeyCode == map[key])
		end

		if triggered then
			TweenService:Create(sf.circle,     TweenInfo.new(0.07),
				{BackgroundTransparency = 0}):Play()
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

print("[MasterHUD] Loaded — Augments | Timer | HP Bars | Skill Circles")
