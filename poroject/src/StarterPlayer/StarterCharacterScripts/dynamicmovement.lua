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
walkAnim.AnimationId = "rbxassetid://913376220"
local walkTrack = humanoid:LoadAnimation(walkAnim)

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

	if isR15 then
		rootJoint.C0 = rootJointC0 * CFrame.Angles(0, relativeAngle, 0)
		waist.C0 = waistC0 * CFrame.Angles(tiltAngle * 0.5, -relativeAngle, 0)
		neck.C0 = neckC0 * CFrame.Angles(tiltAngle * 0.5, 0, 0)
	else
		rootJoint.C0 = rootJointC0 * CFrame.Angles(0, 0, relativeAngle)
		neck.C0 = neckC0 * CFrame.Angles(tiltAngle, -relativeAngle, 0)
	end

	-- Backwards animation
	if isBackward then
		if not walkTrack.IsPlaying then
			walkTrack:Play()
		end

		walkTrack:AdjustSpeed(-1)
	else
		if walkTrack.IsPlaying then
			walkTrack:Stop()
		end
	end

end)