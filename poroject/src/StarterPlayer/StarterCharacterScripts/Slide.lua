local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")

-- Animation
local SLIDE_ANIM_ID = "rbxassetid://114939330195832"
local slideAnim = Instance.new("Animation")
slideAnim.AnimationId = SLIDE_ANIM_ID
local slideTrack = animator:LoadAnimation(slideAnim)
slideTrack.Priority = Enum.AnimationPriority.Action2
slideTrack.Looped = true

-- Settings
local INITIAL_SLIDE_SPEED = 48
local MAX_DOWNHILL_SPEED = 75
local MIN_SLIDE_SPEED = 12
local FLAT_DECAY = 25 -- Speed lost per second on flat ground
local UPHILL_DECAY = 50 -- Speed lost per second going uphill

local isSliding = false
local slideSpeed = 0
local slideDirection = Vector3.zero
local slideForce = nil
local slideAttachment = nil
local loopConnection = nil

local function StopSlide()
	if not isSliding then return end
	isSliding = false
	character:SetAttribute("IsSliding", false)
	
	slideTrack:Stop(0.2)
	
	if slideForce then slideForce:Destroy() end
	if slideAttachment then slideAttachment:Destroy() end
	if loopConnection then loopConnection:Disconnect() end
	
	-- Pop them out of sliding posture via slight jump impulse so they don't clip into floor
	-- (Optional, but helps with clean exits)
end

local function StartSlide()
	-- Prevent sliding if not moving, already sliding, or in the air, or attacking
	if isSliding or humanoid.MoveDirection.Magnitude == 0 or character:GetAttribute("IsAttacking") then return end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then return end
	
	isSliding = true
	character:SetAttribute("IsSliding", true)
	
	-- We lock the direction the moment they hit slide
	slideDirection = humanoid.MoveDirection
	slideSpeed = INITIAL_SLIDE_SPEED
	
	slideTrack:Play(0.1)
	
	slideAttachment = Instance.new("Attachment")
	slideAttachment.Parent = rootPart
	
	slideForce = Instance.new("LinearVelocity")
	-- Allowing gravity to work on Y axis so they stick to slopes
	slideForce.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	slideForce.MaxAxesForce = Vector3.new(100000, 0, 100000) 
	slideForce.RelativeTo = Enum.ActuatorRelativeTo.World
	slideForce.VectorVelocity = slideDirection * slideSpeed
	slideForce.Attachment0 = slideAttachment
	slideForce.Parent = rootPart
	
	loopConnection = RunService.Heartbeat:Connect(function(dt)
		if not isSliding then return end
		
		-- Cancel if player jumps or falls off completely
		if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			StopSlide()
			return
		end
		
		-- Slope Detection via Raycast
		local rayOrigin = rootPart.Position
		local rayDir = Vector3.new(0, -5, 0)
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {character}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		
		local result = workspace:Raycast(rayOrigin, rayDir, rayParams)
		
		if result then
			local normal = result.Normal
			-- Pure flat ground normal is (0, 1, 0)
			if normal.Y > 0.99 then
				-- Flat Ground
				slideSpeed = slideSpeed - (FLAT_DECAY * dt)
			else
				-- On a slope
				-- Taking the dot product of the floor Normal and our SlideDirection lets us know if facing uphill or downhill
				local slopeDot = slideDirection:Dot(normal)
				
				if slopeDot < -0.05 then
					-- Uphill (Fighting gravity)
					slideSpeed = slideSpeed - (UPHILL_DECAY * dt)
				elseif slopeDot > 0.05 then
					-- Downhill (Gaining Momentum!)
					slideSpeed = math.min(MAX_DOWNHILL_SPEED, slideSpeed + (slopeDot * 100 * dt))
				else
					-- Very slight angle, treat as flat
					slideSpeed = slideSpeed - (FLAT_DECAY * dt)
				end
			end
		else
			-- In mid air very temporarily?
			slideSpeed = slideSpeed - (FLAT_DECAY * dt)
		end
		
		-- If they run out of momentum, end the slide automatically
		if slideSpeed <= MIN_SLIDE_SPEED then
			StopSlide()
			return
		end
		
		-- Rotate player to face slide direction
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + slideDirection)
		
		-- Apply updated speed to X/Z axes
		slideForce.VectorVelocity = slideDirection * slideSpeed
	end)
end

-- Keybinds
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
		StartSlide()
	end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
		StopSlide()
	end
end)
