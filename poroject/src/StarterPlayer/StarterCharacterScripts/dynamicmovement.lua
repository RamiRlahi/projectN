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
local neck = head:WaitForChild("Neck")
local waist = if isR15 then upperTorso:WaitForChild("Waist") else nil
local rootJoint = if isR15 then lowerTorso:WaitForChild("Root") else hrp:WaitForChild("RootJoint")

local neckC0 = neck.C0
local waistC0 = if waist then waist.C0 else nil
local rootJointC0 = rootJoint.C0

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
		rootJoint.C0 = rootJointC0 * CFrame.Angles(0, relativeAngle, 0)
		-- Skip upper-body joint overrides when dual-gun aim is active
		if not isAiming then
			waist.C0 = waistC0 * CFrame.Angles(tiltAngle * 0.5, -relativeAngle, 0)
			neck.C0 = neckC0 * CFrame.Angles(tiltAngle * 0.5, 0, 0)
		end
	else
		rootJoint.C0 = rootJointC0 * CFrame.Angles(0, 0, relativeAngle)
		if not isAiming then
			neck.C0 = neckC0 * CFrame.Angles(tiltAngle, -relativeAngle, 0)
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