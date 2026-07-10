local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local KnitModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitModule)

local LeapService = Knit.CreateService({
	Name = "LeapService",
	Instance = script,
	Client = {
		LeapRequested = Knit.CreateSignal(),
		LeapCooldownUpdate = Knit.CreateSignal(),
		PlatformBroken = Knit.CreateSignal(),
	},
})

---- Datas
local sharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 5).Datas
local LeapDatas = require(sharedDatas:WaitForChild("LeapDatas", 5))

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource", 5).Utilities

---- Knit Services
local ProfileService

-- Leap cooldown tracking
local leapCooldowns = {}
local activeLeaps = {}
local breakablePlatforms = {}

-- Platform breaking system with animations
local function createPlatformBreakEffect(platform, position)
	-- Create visual breaking effect with particles
	local breakEffect = Instance.new("Part")
	breakEffect.Name = "PlatformBreakEffect"
	breakEffect.Size = platform.Size
	breakEffect.Position = position
	breakEffect.Anchored = true
	breakEffect.CanCollide = false
	breakEffect.Transparency = 1
	breakEffect.Parent = workspace
	
	-- Add particle emitter for breaking effect
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "BreakParticles"
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 100, 100))
	particles.Acceleration = Vector3.new(0, -20, 0)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 50
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-50, 50)
	particles.Speed = NumberRange.new(5, 15)
	particles.VelocitySpread = 180
	particles.Parent = breakEffect
	
	-- Add explosion force animation
	spawn(function()
		-- Emit particles for 0.3 seconds
		particles.Enabled = true
		task.wait(0.3)
		particles.Enabled = false
		
		-- Fade out and destroy
		task.delay(1, function()
			breakEffect:Destroy()
		end)
	end)
	
	return breakEffect
end

-- Leap animation system
local function playLeapAnimation(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Try to load leap animation
	local animation = Instance.new("Animation")
	animation.AnimationId = LeapDatas.LEAP_ANIMATION_ID
	
	local animationTrack = humanoid:LoadAnimation(animation)
	if animationTrack then
		animationTrack:Play()
		
		-- Stop animation after leap duration
		task.delay(LeapDatas.LEAP_DURATION, function()
			if animationTrack.IsPlaying then
				animationTrack:Stop()
			end
		end)
	end
	
	-- Create leap trail effect
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local trail = Instance.new("Trail")
		trail.Name = "LeapTrail"
		trail.Color = ColorSequence.new(LeapDatas.LEAP_TRAIL_COLOR)
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1)
		})
			trail.Lifetime = LeapDatas.LEAP_TRAIL_LIFETIME
			trail.WidthScale = NumberSequence.new(LeapDatas.LEAP_TRAIL_WIDTH)
		trail.Attachment0 = Instance.new("Attachment")
		trail.Attachment0.Parent = humanoidRootPart
		trail.Attachment0.Position = Vector3.new(-0.5, 0, 0)
		trail.Attachment1 = Instance.new("Attachment")
		trail.Attachment1.Parent = humanoidRootPart
		trail.Attachment1.Position = Vector3.new(0.5, 0, 0)
		trail.Parent = humanoidRootPart
		
		-- Remove trail after leap
		task.delay(LeapDatas.LEAP_DURATION + 0.5, function()
			trail:Destroy()
		end)
	end
end

-- Check if player can leap
function LeapService:CanLeap(player)
	local userId = player.UserId
	local cooldownEnd = leapCooldowns[userId]
	
	if cooldownEnd then
		local remaining = cooldownEnd - os.time()
		if remaining > 0 then
			return false, remaining
		end
	end
	
	return true, 0
end

-- Perform leap action
function LeapService:PerformLeap(player, direction)
	local canLeap, remaining = self:CanLeap(player)
	if not canLeap then
		return false, "Leap on cooldown: " .. remaining .. "s"
	end
	
	local character = player.Character
	if not character then
		return false, "No character"
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not humanoidRootPart then
		return false, "Character missing required parts"
	end
	
	-- Set cooldown
	leapCooldowns[player.UserId] = os.time() + LeapDatas.LEAP_COOLDOWN
	
	-- Notify client of cooldown
	self.Client.LeapCooldownUpdate:Fire(player, LeapDatas.LEAP_COOLDOWN)
	
	-- Store active leap
	activeLeaps[player.UserId] = {
		startTime = os.time(),
		direction = direction,
		character = character
	}
	
	-- Apply leap force
	local leapForce = direction * LeapDatas.LEAP_FORCE
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = leapForce
	bodyVelocity.P = 1000
	bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
	bodyVelocity.Parent = humanoidRootPart
	
	-- Remove force after duration
	task.delay(LeapDatas.LEAP_DURATION, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
		activeLeaps[player.UserId] = nil
	end)
	
	-- Play leap animation
	playLeapAnimation(character)
	
	-- Check for ANY floor/ground breaking during leap
	spawn(function()
		local startPos = humanoidRootPart.Position
		task.wait(0.1) -- Small delay before checking
		
		-- Create impact detection zone around player
		local impactZone = Instance.new("Part")
		impactZone.Name = "LeapImpactZone"
		impactZone.Size = Vector3.new(5, 1, 5) -- Area around player
		impactZone.Position = humanoidRootPart.Position + Vector3.new(0, -3, 0)
		impactZone.Anchored = true
		impactZone.CanCollide = false
		impactZone.Transparency = 1
		impactZone.Parent = workspace
		
		-- Check for ground breaking
		while activeLeaps[player.UserId] do
			-- Update impact zone position
			impactZone.Position = humanoidRootPart.Position + Vector3.new(0, -3, 0)
			
			-- Check for parts touching the impact zone
			for _, part in ipairs(workspace:GetPartsInPart(impactZone)) do
				-- Break ANY floor/ground part (not the character itself)
				if part ~= impactZone and part ~= humanoidRootPart and not part:IsDescendantOf(character) then
					-- Check if it's a floor/ground (horizontal surface)
					local surfaceNormal = (humanoidRootPart.Position - part.Position).Unit
					local isHorizontal = math.abs(surfaceNormal.Y) > 0.7
					
					if isHorizontal then
						-- Break the floor/ground
						self:BreakPlatform(player, part, part.Position)
						break -- Break one floor at a time
					end
				end
			end
			
			task.wait(0.1)
		end
		
		-- Clean up impact zone
		impactZone:Destroy()
	end)
	
	return true, "Leap activated!"
end

-- Break ANY floor/ground part
function LeapService:BreakPlatform(player, part, hitPosition)
	if not part or part.Parent == nil then
		return
	end
	
	-- Check if part is already being broken
	if breakablePlatforms[part] then
		return
	end
	
	breakablePlatforms[part] = true
	
	-- Create break effect
	createPlatformBreakEffect(part, hitPosition)
	
	-- Notify all clients
	self.Client.PlatformBroken:FireAll(part:GetFullName(), hitPosition)
	
	-- Create temporary hole instead of destroying (optional)
	-- You can choose to destroy or just make it non-collidable
	local originalProperties = {
		CanCollide = part.CanCollide,
		Transparency = part.Transparency,
		Color = part.Color
	}
	
	-- Make the part non-collidable and semi-transparent
	part.CanCollide = false
	part.Transparency = 0.7
	part.Color = Color3.fromRGB(100, 100, 100)
	
	-- Respawn the floor after delay
	task.delay(LeapDatas.PLATFORM_RESPAWN_TIME, function()
		if part and part.Parent then
			-- Restore original properties
			part.CanCollide = originalProperties.CanCollide
			part.Transparency = originalProperties.Transparency
			part.Color = originalProperties.Color
		end
		breakablePlatforms[part] = nil
	end)
	
	-- Give player points or rewards for breaking floor
	if ProfileService then
		ProfileService:AddPoints(player, LeapDatas.PLATFORM_BREAK_POINTS)
	end
	
	print(string.format("[LeapService] %s broke floor: %s", player.Name, part:GetFullName()))
end

-- Client request to leap
function LeapService.Client:RequestLeap(player, direction)
	return self.Server:PerformLeap(player, direction)
end

-- Get leap cooldown for player
function LeapService.Client:GetLeapCooldown(player)
	local canLeap, remaining = self.Server:CanLeap(player)
	return canLeap, remaining
end

-- Initialize breakable platforms in workspace
function LeapService:InitializeBreakablePlatforms()
	print("[LeapService] Initializing breakable platforms...")
	
	-- Find all parts with BreakablePlatform attribute
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("BreakablePlatform") then
			-- Ensure platform has proper collision
			part.CanCollide = true
			part.Anchored = true
			part.Material = Enum.Material.Plastic
			part.Color = Color3.fromRGB(200, 100, 100) -- Reddish color for breakable
			
			-- Add visual indicator
			local surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Adornee = part
			surfaceGui.Face = Enum.NormalId.Top
			surfaceGui.AlwaysOnTop = true
			
			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = "BREAKABLE"
			textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.Parent = surfaceGui
			
			surfaceGui.Parent = part
			
			print("  Found breakable platform:", part:GetFullName())
		end
	end
	
	print("[LeapService] Found " .. #workspace:GetDescendants() .. " total descendants")
end

function LeapService:KnitStart()
	-- Initialize breakable platforms
	self:InitializeBreakablePlatforms()
	
	-- Clean up when player leaves
	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		leapCooldowns[userId] = nil
		activeLeaps[userId] = nil
	end)
	
	-- Start leap tester in development mode
	if self.Components.LeapTester then
		spawn(function()
			task.wait(2) -- Wait for game to initialize
			self.Components.LeapTester:Start()
		end)
	end
	
	print("[LeapService] Started successfully!")
	print("[LeapService] Players can now leap (E key) and break ANY floor!")
end

function LeapService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	
	print("[LeapService] Initialized!")
end

return LeapService