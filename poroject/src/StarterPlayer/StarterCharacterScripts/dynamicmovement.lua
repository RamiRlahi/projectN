local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- Rig-specific parts
local head = character:WaitForChild("Head")
local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
local upperTorso = if isR15 then character:WaitForChild("UpperTorso") else nil
local lowerTorso = if isR15 then character:WaitForChild("LowerTorso") else character:WaitForChild("Torso")

-- Rig-specific joints
local function isAnimJoint(instance)
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

local function findAnimJoint(name, ...)
	for index = 1, select("#", ...) do
		local parent = select(index, ...)
		if parent then
			local child = parent:FindFirstChild(name)
			if child and isAnimJoint(child) then
				return child
			end
		end
	end

	for _, descendant in character:GetDescendants() do
		if descendant.Name == name and isAnimJoint(descendant) then
			return descendant
		end
	end

	warn("dynamicmovement could not find animation joint named " .. name .. "; skipping that joint")
	return nil
end

local function getJointBase(joint)
	if not joint then
		return nil
	end

	if joint:IsA("Motor6D") then
		return joint.C0
	end

	return CFrame.new()
end

local function setJointOffset(joint, base, offset)
	if not joint then
		return
	end

	if joint:IsA("Motor6D") then
		joint.C0 = base * offset
	else
		joint.Transform =offset
	end
end

local neck = findAnimJoint("Neck", head, upperTorso, lowerTorso)
local waist = if isR15 then findAnimJoint("Waist", upperTorso, lowerTorso) else nil
local rootJoint = if isR15 then findAnimJoint("Root", lowerTorso, hrp) else findAnimJoint("RootJoint", hrp, lowerTorso)

local neckBase = getJointBase(neck)
local waistBase = getJointBase(waist)
local rootJointBase = getJointBase(rootJoint)

-- Animation setup
local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "rbxassetid://73649051439627"
local walkTrack = humanoid:LoadAnimation(walkAnim)
walkTrack.Priority = Enum.AnimationPriority.Action2

local idleAnim = Instance.new("Animation")
idleAnim.AnimationId = "rbxassetid://113340815496069"
local idleTrack = humanoid:LoadAnimation(idleAnim)
idleTrack.Priority = Enum.AnimationPriority.Action2
idleTrack.Looped = true

-- Disable AutoRotate
humanoid.AutoRotate = false

local function getCameraLook()
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X,0,look.Z)

	if flat.Magnitude == 0 then
		return Vector3.zero
	end

	return flat.Unit
end

RunService.RenderStepped:Connect(function()

	local moveDirection = humanoid.MoveDirection
	local cameraLook = getCameraLook()

	-- Root faces camera direction
	if cameraLook.Magnitude > 0 then
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + cameraLook)
	end

	-- Movement calculation
	local relativeAngle = 0
	local isBackward = false

	if moveDirection.Magnitude > 0 then

		local dot = moveDirection:Dot(cameraLook)

		-- Detect backwards including diagonals
		if dot < -0.3 then
			isBackward = true
			relativeAngle = 0
		else
			local moveAngle = math.atan2(moveDirection.X, moveDirection.Z)
			local cameraAngle = math.atan2(cameraLook.X, cameraLook.Z)
			relativeAngle = moveAngle - cameraAngle
		end
	end

	local tiltAngle = math.asin(camera.CFrame.LookVector.Y)

	local isAiming = character:GetAttribute("IsAiming")

	if isR15 then
		setJointOffset(rootJoint, rootJointBase, CFrame.Angles(0, relativeAngle, 0))
		-- Skip upper-body joint overrides when dual-gun aim is active
		if not isAiming then
			setJointOffset(waist, waistBase, CFrame.Angles(tiltAngle * 0.5, -relativeAngle, 0))
			setJointOffset(neck, neckBase, CFrame.Angles(tiltAngle * 0.5, 0, 0))
		end
	else
		setJointOffset(rootJoint, rootJointBase, CFrame.Angles(0, 0, relativeAngle))
		if not isAiming and neck then
			setJointOffset(neck, neckBase, CFrame.Angles(tiltAngle, -relativeAngle, 0))
		end
	end

	local hasSword = character:FindFirstChildWhichIsA("Tool")
	
	-- Backwards animation (Only if NOT holding a sword)
	if isBackward and not hasSword then
		if not walkTrack.IsPlaying then
			walkTrack:Play()
		end
		walkTrack:AdjustSpeed(-1.5)
	else
		if walkTrack.IsPlaying then
			walkTrack:Stop()
		end
	end

	-- Global Idle (Plays whenever stationary, but NOT while aiming with guns)
	if isAiming then
		if idleTrack.IsPlaying then
			idleTrack:Stop(0.2)
		end
	elseif moveDirection.Magnitude < 0.1 then
		if not idleTrack.IsPlaying then
			idleTrack:Play(0.5)
		end
	else
		if idleTrack.IsPlaying then
			idleTrack:Stop(0.5)
		end
	end

	-- Custom footstep speed (half speed)
	local running = hrp:FindFirstChild("Running")
	if running and running:IsA("Sound") then
		running.PlaybackSpeed = (humanoid.WalkSpeed / 16) * 0.75
	end
end)
