local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local KnitModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitModule)

local LeapController = Knit.CreateController({
	Name = "LeapController",
	Instance = script,
})

---- Datas
local sharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 5).Datas
local LeapDatas = require(sharedDatas:WaitForChild("LeapDatas", 5))

---- Knit Services
local LeapService
local UIService

-- UI elements
local leapUI
local cooldownText
local cooldownBar
local platformBreakIndicator

-- State tracking
local isLeapCooldown = false
local leapCooldownEnd = 0
local lastPlatformBreakTime = 0

-- Create leap UI
local function createLeapUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Clean up existing UI
	local existingUI = playerGui:FindFirstChild("LeapUI")
	if existingUI then
		existingUI:Destroy()
	end
	
	-- Create main container
	leapUI = Instance.new("ScreenGui")
	leapUI.Name = "LeapUI"
	leapUI.ResetOnSpawn = false
	leapUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	leapUI.Parent = playerGui
	
	-- Leap indicator frame (bottom center)
	local leapFrame = Instance.new("Frame")
	leapFrame.Name = "LeapFrame"
	leapFrame.Size = UDim2.new(0, 200, 0, 80)
	leapFrame.Position = UDim2.new(0.5, -100, 1, -100)
	leapFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	leapFrame.BackgroundTransparency = 0.3
	leapFrame.BorderSizePixel = 0
	leapFrame.Parent = leapUI
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = leapFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 200, 255)
	stroke.Thickness = 2
	stroke.Parent = leapFrame
	
	-- Leap keybind label
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Keybind"
	keyLabel.Size = UDim2.new(0, 40, 0, 40)
	keyLabel.Position = UDim2.new(0, 10, 0.5, -20)
	keyLabel.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	keyLabel.BackgroundTransparency = 0.2
	keyLabel.Text = "E"
	keyLabel.TextColor3 = Color3.new(1, 1, 1)
	keyLabel.TextScaled = true
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Parent = leapFrame
	
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 6)
	keyCorner.Parent = keyLabel
	
	-- Leap name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0, 100, 0, 30)
	nameLabel.Position = UDim2.new(0, 60, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "LEAP"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = leapFrame
	
	-- Cooldown bar background
	local cooldownBg = Instance.new("Frame")
	cooldownBg.Name = "CooldownBackground"
	cooldownBg.Size = UDim2.new(0, 130, 0, 10)
	cooldownBg.Position = UDim2.new(0, 60, 0, 50)
	cooldownBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	cooldownBg.BorderSizePixel = 0
	cooldownBg.Parent = leapFrame
	
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = cooldownBg
	
	-- Cooldown bar fill
	cooldownBar = Instance.new("Frame")
	cooldownBar.Name = "CooldownBar"
	cooldownBar.Size = UDim2.new(1, 0, 1, 0)
	cooldownBar.BackgroundColor3 = LeapDatas.READY_DISPLAY_COLOR
	cooldownBar.BorderSizePixel = 0
	cooldownBar.Parent = cooldownBg
	
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = cooldownBar
	
	-- Cooldown text
	cooldownText = Instance.new("TextLabel")
	cooldownText.Name = "CooldownText"
	cooldownText.Size = UDim2.new(0, 130, 0, 20)
	cooldownText.Position = UDim2.new(0, 60, 0, 60)
	cooldownText.BackgroundTransparency = 1
	cooldownText.Text = "READY"
	cooldownText.TextColor3 = LeapDatas.READY_DISPLAY_COLOR
	cooldownText.TextScaled = true
	cooldownText.TextXAlignment = Enum.TextXAlignment.Left
	cooldownText.Font = Enum.Font.Gotham
	cooldownText.Parent = leapFrame
	
	-- Platform break indicator (floating text)
	platformBreakIndicator = Instance.new("TextLabel")
	platformBreakIndicator.Name = "PlatformBreakIndicator"
	platformBreakIndicator.Size = UDim2.new(0, 200, 0, 40)
	platformBreakIndicator.Position = UDim2.new(0.5, -100, 0.3, 0)
	platformBreakIndicator.BackgroundTransparency = 1
	platformBreakIndicator.Text = ""
	platformBreakIndicator.TextColor3 = Color3.fromRGB(255, 100, 100)
	platformBreakIndicator.TextScaled = true
	platformBreakIndicator.TextStrokeTransparency = 0.5
	platformBreakIndicator.TextStrokeColor3 = Color3.new(0, 0, 0)
	platformBreakIndicator.Visible = false
	platformBreakIndicator.Font = Enum.Font.GothamBold
	platformBreakIndicator.Parent = leapUI
	
	print("[LeapController] UI created successfully")
end

-- Update cooldown display
local function updateCooldownDisplay()
	if not leapUI or not cooldownBar or not cooldownText then
		return
	end
	
	local currentTime = os.time()
	
	if isLeapCooldown and leapCooldownEnd > currentTime then
		local remaining = leapCooldownEnd - currentTime
		local progress = remaining / LeapDatas.LEAP_COOLDOWN
		
		-- Update bar
		cooldownBar.Size = UDim2.new(1 - progress, 0, 1, 0)
		cooldownBar.BackgroundColor3 = LeapDatas.COOLDOWN_DISPLAY_COLOR
		
		-- Update text
		cooldownText.Text = string.format("COOLDOWN: %.1fs", remaining)
		cooldownText.TextColor3 = LeapDatas.COOLDOWN_DISPLAY_COLOR
	else
		-- Ready state
		isLeapCooldown = false
		cooldownBar.Size = UDim2.new(1, 0, 1, 0)
		cooldownBar.BackgroundColor3 = LeapDatas.READY_DISPLAY_COLOR
		cooldownText.Text = "READY"
		cooldownText.TextColor3 = LeapDatas.READY_DISPLAY_COLOR
	end
end

-- Show platform break indicator
local function showPlatformBreakIndicator()
	if not platformBreakIndicator then
		return
	end
	
	local currentTime = os.time()
	if currentTime - lastPlatformBreakTime < 2 then
		return -- Already showing
	end
	
	lastPlatformBreakTime = currentTime
	platformBreakIndicator.Text = "PLATFORM BROKEN! +10"
	platformBreakIndicator.Visible = true
	
	-- Animate floating up
	spawn(function()
		local startPos = platformBreakIndicator.Position
		for i = 0, 1, 0.05 do
			platformBreakIndicator.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset,
				startPos.Y.Scale - i * 0.1,
				startPos.Y.Offset
			)
			platformBreakIndicator.TextTransparency = i
			task.wait(0.05)
		end
		platformBreakIndicator.Visible = false
		platformBreakIndicator.TextTransparency = 0
		platformBreakIndicator.Position = startPos
	end)
end

-- Handle leap input
local function onLeapInput(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		-- Get camera direction for leap
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		
		if not camera or not character then
			return
		end
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end
		
		-- Calculate leap direction (forward relative to camera)
		local cameraCFrame = camera.CFrame
		local leapDirection = (cameraCFrame.LookVector * LeapDatas.LEAP_FORCE.Z) + 
						  (Vector3.new(0, LeapDatas.LEAP_FORCE.Y, 0))
		
		-- Request leap from server
		LeapService:RequestLeap(leapDirection)
			:andThen(function(success, message)
				if success then
					print("[LeapController] Leap activated:", message)
					
					-- Visual feedback
					if leapUI then
						leapUI.LeapFrame.UIStroke.Thickness = 4
						task.delay(0.2, function()
							if leapUI and leapUI.LeapFrame then
								leapUI.LeapFrame.UIStroke.Thickness = 2
							end
						end)
					end
				else
					warn("[LeapController] Leap failed:", message)
				end
			end)
			:catch(function(err)
				warn("[LeapController] Leap error:", err)
			end)
	end
end

-- Set leap cooldown
local function setLeapCooldown(cooldownDuration)
	isLeapCooldown = true
	leapCooldownEnd = os.time() + cooldownDuration
	print("[LeapController] Leap cooldown set:", cooldownDuration, "seconds")
end

-- Handle platform break event
local function onPlatformBroken(platformName, position)
	print("[LeapController] Platform broken:", platformName)
	showPlatformBreakIndicator()
	
	-- Optional: Play sound effect
	-- local sound = Instance.new("Sound")
	-- sound.SoundId = LeapDatas.SOUND_PLATFORM_BREAK
	-- sound.Parent = workspace
	-- sound:Play()
	-- game.Debris:AddItem(sound, 3)
end

function LeapController:KnitStart()
	-- Create UI
	createLeapUI()
	
	-- Bind input
	ContextActionService:BindAction("LeapAction", onLeapInput, false, 
		LeapDatas.LEAP_KEY, LeapDatas.LEAP_KEY_SECONDARY)
	
	-- Update cooldown display every frame
	RunService.RenderStepped:Connect(updateCooldownDisplay)
	
	-- Listen for server events
	LeapService.LeapCooldownUpdate:Connect(setLeapCooldown)
	LeapService.PlatformBroken:Connect(onPlatformBroken)
	
	print("[LeapController] Started successfully!")
	print("[LeapController] Press E to leap and break platforms!")
end

function LeapController:KnitInit()
	LeapService = Knit.GetService("LeapService")
	
	print("[LeapController] Initialized!")
end

return LeapController