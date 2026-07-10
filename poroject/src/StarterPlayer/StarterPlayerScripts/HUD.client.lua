-- ============================================================
-- HUD SYSTEM - Premium Game UI
-- Layout:
--   Bottom-Left  : Augment circles (white circle + icon outline)
--   Top-Center   : Round countdown + round tracker circles
--   World-Space  : Player HP bar (green) + Enemy HP bars (red)
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr       = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

-- ============================================================
-- SCREEN GUI ROOT
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "PremiumHUD"
screenGui.ResetOnSpawn     = false
screenGui.IgnoreGuiInset   = true
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.Parent           = playerGui

-- ============================================================
-- SECTION 1 ─ AUGMENT CIRCLES  (bottom-left)
-- ============================================================
-- Augments the player has picked this round
-- Each one: white circle + icon image (outline only, like the ref image)
local augmentData = {
	{icon = "rbxassetid://10650942544", name = "Surge"},
	{icon = "rbxassetid://10650942544", name = "Veil"},
	{icon = "rbxassetid://10650942544", name = "Echo"},
}

local augmentHolder = Instance.new("Frame")
augmentHolder.Name               = "AugmentHolder"
augmentHolder.Size               = UDim2.new(0, 280, 0, 90)
augmentHolder.Position           = UDim2.new(0, 20, 1, -110)
augmentHolder.BackgroundTransparency = 1
augmentHolder.Parent             = screenGui

local augmentLayout = Instance.new("UIListLayout")
augmentLayout.FillDirection        = Enum.FillDirection.Horizontal
augmentLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
augmentLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Left
augmentLayout.Padding              = UDim.new(0, 10)
augmentLayout.SortOrder            = Enum.SortOrder.LayoutOrder   -- preserve insertion order
augmentLayout.Parent               = augmentHolder

-- Build one augment circle
local augmentCount = 0
local function createAugmentCircle(iconId, label, parent)
	local CIRCLE_SIZE = 72
	augmentCount = augmentCount + 1

	local wrapper = Instance.new("Frame")
	wrapper.Name                 = "Aug_" .. label
	wrapper.Size                 = UDim2.new(0, CIRCLE_SIZE, 0, CIRCLE_SIZE + 24)
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder          = augmentCount   -- preserve insertion order
	wrapper.Parent               = parent

	-- White circle background
	local circle = Instance.new("Frame")
	circle.Name                  = "Circle"
	circle.Size                  = UDim2.new(0, CIRCLE_SIZE, 0, CIRCLE_SIZE)
	circle.Position              = UDim2.new(0.5, -CIRCLE_SIZE/2, 0, 0)
	circle.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
	circle.BackgroundTransparency = 0.08
	circle.BorderSizePixel       = 0
	circle.ClipsDescendants      = false
	circle.Parent                = wrapper

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent       = circle

	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color     = Color3.fromRGB(255, 255, 255)
	circleStroke.Thickness = 2.5
	circleStroke.Parent    = circle

	-- Icon inside circle (dark silhouette style)
	local icon = Instance.new("ImageLabel")
	icon.Size                 = UDim2.new(0, CIRCLE_SIZE * 0.56, 0, CIRCLE_SIZE * 0.56)
	icon.AnchorPoint          = Vector2.new(0.5, 0.5)
	icon.Position             = UDim2.new(0.5, 0, 0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image                = iconId
	icon.ImageColor3          = Color3.fromRGB(30, 30, 30)
	icon.ScaleType            = Enum.ScaleType.Fit
	icon.Parent               = circle

	-- Small label BELOW the wrapper (outside circle)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size               = UDim2.new(1, 0, 0, 20)
	nameLabel.Position           = UDim2.new(0, 0, 0, CIRCLE_SIZE + 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text               = label:upper()
	nameLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled         = true
	nameLabel.Font               = Enum.Font.GothamBold
	nameLabel.Parent             = wrapper

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 1.5
	nameStroke.Color     = Color3.fromRGB(0, 0, 0)
	nameStroke.Parent    = nameLabel

	return wrapper
end

-- Populate augment circles
local augmentCircles = {}
for _, data in ipairs(augmentData) do
	local c = createAugmentCircle(data.icon, data.name, augmentHolder)
	table.insert(augmentCircles, c)
end

-- Public API: Add a new augment circle at runtime
local function addAugment(iconId, label)
	local c = createAugmentCircle(iconId, label, augmentHolder)
	table.insert(augmentCircles, c)
end

-- ============================================================
-- SECTION 2 ─ TOP-CENTER: Round Timer + Round Tracker
-- ============================================================
local TOP_CONTAINER_W = 280
local TOP_CONTAINER_H = 90

local topContainer = Instance.new("Frame")
topContainer.Name                = "TopCenter"
topContainer.Size                = UDim2.new(0, TOP_CONTAINER_W, 0, TOP_CONTAINER_H)
topContainer.Position            = UDim2.new(0.5, -TOP_CONTAINER_W/2, 0, 12)
topContainer.BackgroundTransparency = 1
topContainer.Parent              = screenGui

-- ── Round Tracker (circles: filled = wins, outline = remaining) ──
local TOTAL_ROUNDS     = 5
local roundsWon        = 0   -- set from game logic; start at 0

local trackerHolder = Instance.new("Frame")
trackerHolder.Name               = "RoundTracker"
trackerHolder.Size               = UDim2.new(1, 0, 0, 28)
trackerHolder.Position           = UDim2.new(0, 0, 0, 0)
trackerHolder.BackgroundTransparency = 1
trackerHolder.Parent             = topContainer

local trackerLayout = Instance.new("UIListLayout")
trackerLayout.FillDirection       = Enum.FillDirection.Horizontal
trackerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
trackerLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
trackerLayout.Padding             = UDim.new(0, 8)
trackerLayout.Parent              = trackerHolder

local trackerDots = {}
local DOT_SIZE = 20

local function buildTrackerDots()
	for _, d in ipairs(trackerDots) do d:Destroy() end
	trackerDots = {}

	for i = 1, TOTAL_ROUNDS do
		local dot = Instance.new("Frame")
		dot.Size              = UDim2.new(0, DOT_SIZE, 0, DOT_SIZE)
		dot.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
		dot.BackgroundTransparency = (i <= roundsWon) and 0 or 0.75
		dot.BorderSizePixel   = 0
		dot.Parent            = trackerHolder

		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent       = dot

		local ds = Instance.new("UIStroke")
		ds.Color     = Color3.fromRGB(255, 255, 255)
		ds.Thickness = 2
		ds.Parent    = dot

		table.insert(trackerDots, dot)
	end
end

buildTrackerDots()

-- ── Countdown Timer ──
local timerFrame = Instance.new("Frame")
timerFrame.Name                  = "TimerFrame"
timerFrame.Size                  = UDim2.new(0, 180, 0, 52)
timerFrame.Position              = UDim2.new(0.5, -90, 0, 32)
timerFrame.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
timerFrame.BackgroundTransparency = 0.45
timerFrame.BorderSizePixel       = 0
timerFrame.Parent                = topContainer

local timerCorner = Instance.new("UICorner")
timerCorner.CornerRadius = UDim.new(0, 10)
timerCorner.Parent       = timerFrame

local timerStroke = Instance.new("UIStroke")
timerStroke.Color     = Color3.fromRGB(255, 255, 255)
timerStroke.Thickness = 1.5
timerStroke.Transparency = 0.5
timerStroke.Parent    = timerFrame

-- "ROUND 2" label
local roundLabel = Instance.new("TextLabel")
roundLabel.Name                = "RoundLabel"
roundLabel.Size                = UDim2.new(1, 0, 0, 20)
roundLabel.Position            = UDim2.new(0, 0, 0, 4)
roundLabel.BackgroundTransparency = 1
roundLabel.Text                = "ROUND 1"
roundLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
roundLabel.TextScaled          = true
roundLabel.Font                = Enum.Font.GothamBlack
roundLabel.Parent              = timerFrame

local roundStroke = Instance.new("UIStroke")
roundStroke.Thickness = 1.5
roundStroke.Color     = Color3.fromRGB(0, 0, 0)
roundStroke.Parent    = roundLabel

-- Timer digits "0:30"
local timerLabel = Instance.new("TextLabel")
timerLabel.Name                = "TimerLabel"
timerLabel.Size                = UDim2.new(1, 0, 0, 28)
timerLabel.Position            = UDim2.new(0, 0, 1, -30)
timerLabel.BackgroundTransparency = 1
timerLabel.Text                = "0:30"
timerLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
timerLabel.TextScaled          = true
timerLabel.Font                = Enum.Font.GothamBold
timerLabel.Parent              = timerFrame

local timerTextStroke = Instance.new("UIStroke")
timerTextStroke.Thickness = 1.5
timerTextStroke.Color     = Color3.fromRGB(0, 0, 0)
timerTextStroke.Parent    = timerLabel

-- ============================================================
-- SECTION 3 ─ PLAYER HP BAR (world-space billboard, green)
-- ============================================================
-- This follows the player character. Displays current HP.
-- Style: diagonal parallelogram fill like the reference image.

local function createHealthBarGui(character, isEnemy)
	local hpGui = Instance.new("BillboardGui")
	hpGui.Name           = isEnemy and "EnemyHPBar" or "PlayerHPBar"
	hpGui.Size           = UDim2.new(0, 180, 0, 44)
	hpGui.StudsOffset    = Vector3.new(0, 3.5, 0)
	hpGui.AlwaysOnTop    = false
	hpGui.ResetOnSpawn   = false
	hpGui.LightInfluence = 0

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")
	if not humanoid or not rootPart then return nil end

	hpGui.Adornee = rootPart
	hpGui.Parent  = character

	-- Outer container (dark background)
	local bg = Instance.new("Frame")
	bg.Size                  = UDim2.new(1, 0, 0, 22)
	bg.Position              = UDim2.new(0, 0, 0.5, -11)
	bg.BackgroundColor3      = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel       = 0
	bg.Parent                = hpGui

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent       = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color     = isEnemy and Color3.fromRGB(180, 30, 30) or Color3.fromRGB(60, 200, 60)
	bgStroke.Thickness = 1.5
	bgStroke.Parent    = bg

	-- Fill bar
	local fill = Instance.new("Frame")
	fill.Name                  = "Fill"
	fill.Size                  = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3      = isEnemy and Color3.fromRGB(220, 40, 40) or Color3.fromRGB(60, 210, 60)
	fill.BorderSizePixel       = 0
	fill.ClipsDescendants      = true
	fill.Parent                = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent       = fill

	-- Shine overlay
	local shine = Instance.new("Frame")
	shine.Size                  = UDim2.new(1, 0, 0.45, 0)
	shine.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.82
	shine.BorderSizePixel       = 0
	shine.Parent                = fill

	-- HP number label (e.g. "2026 / 2026")
	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name                = "HPLabel"
	hpLabel.Size                = UDim2.new(1, -8, 1, 0)
	hpLabel.Position            = UDim2.new(0, 4, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
	hpLabel.TextScaled          = true
	hpLabel.Font                = Enum.Font.GothamBold
	hpLabel.Text                = "100 / 100"
	hpLabel.ZIndex              = 5
	hpLabel.Parent              = bg

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Thickness = 1.5
	hpStroke.Color     = Color3.fromRGB(0, 0, 0)
	hpStroke.Parent    = hpLabel

	-- Update loop
	local conn = RunService.Heartbeat:Connect(function()
		if not humanoid or not humanoid.Parent then
			hpGui:Destroy()
			return
		end
		local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		hpLabel.Text = math.ceil(humanoid.Health) .. " / " .. math.ceil(humanoid.MaxHealth)
	end)

	-- Cleanup
	humanoid.Died:Connect(function()
		task.delay(3, function()
			conn:Disconnect()
			if hpGui and hpGui.Parent then hpGui:Destroy() end
		end)
	end)

	return hpGui
end

-- ============================================================
-- SECTION 4 ─ HOOK UP PLAYER HP BAR
-- ============================================================
local function setupPlayerHPBar(char)
	task.wait(0.5) -- small wait for character to fully load
	createHealthBarGui(char, false) -- green
end

if plr.Character then setupPlayerHPBar(plr.Character) end
plr.CharacterAdded:Connect(setupPlayerHPBar)

-- ============================================================
-- SECTION 5 ─ HOOK UP ENEMY HP BARS (all non-local humanoids)
-- ============================================================
local function onDescendantAdded(descendant)
	if descendant:IsA("Humanoid") then
		local char = descendant.Parent
		-- Make sure it's not local player
		local owningPlayer = Players:GetPlayerFromCharacter(char)
		if owningPlayer == plr then return end
		task.delay(0.1, function()
			if char and char.Parent then
				createHealthBarGui(char, true) -- red
			end
		end)
	end
end

-- Scan already-existing NPCs/enemies
for _, desc in ipairs(workspace:GetDescendants()) do
	onDescendantAdded(desc)
end
workspace.DescendantAdded:Connect(onDescendantAdded)

-- ============================================================
-- SECTION 6 ─ ROUND TIMER LOGIC (driven by ReplicatedStorage attributes)
-- ============================================================
-- The server should set:
--   ReplicatedStorage:SetAttribute("RoundTime", <seconds_remaining>)
--   ReplicatedStorage:SetAttribute("CurrentRound", <round_number>)
--   ReplicatedStorage:SetAttribute("RoundsWon", <player_round_wins>)

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local lastTimerFlash = 0

RunService.Heartbeat:Connect(function()
	-- Round time
	local timeLeft = ReplicatedStorage:GetAttribute("RoundTime") or 30
	timerLabel.Text = formatTime(timeLeft)

	-- Flash red when under 10 seconds
	if timeLeft <= 10 then
		local now = tick()
		if now - lastTimerFlash > 0.5 then
			lastTimerFlash = now
			local isRed = (timerLabel.TextColor3 == Color3.fromRGB(255, 80, 80))
			timerLabel.TextColor3 = isRed and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 80, 80)
		end
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	-- Round number
	local currentRound = ReplicatedStorage:GetAttribute("CurrentRound") or 1
	roundLabel.Text = "ROUND " .. tostring(currentRound)

	-- Round wins
	local wins = ReplicatedStorage:GetAttribute("RoundsWon") or 0
	if wins ~= roundsWon then
		roundsWon = wins
		buildTrackerDots()
	end
end)

-- ============================================================
-- EXPOSE API FOR EXTERNAL SCRIPTS
-- ============================================================
-- Other scripts can call these via:
--   local hud = require(script) -- if converted to ModuleScript
--   hud.addAugment(iconId, label)

-- For now, expose via a BindableFunction in ReplicatedStorage
local api = Instance.new("BindableFunction")
api.Name   = "HUD_AddAugment"
api.Parent = ReplicatedStorage

api.OnInvoke = function(iconId, label)
	addAugment(iconId, label)
end

print("[HUD] Premium HUD loaded successfully.")
