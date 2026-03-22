local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- CHANGE YOUR NORMAL SPRINT ANIMATION HERE:
local NORMAL_SPRINT_ID = "rbxassetid://118334590993548"

local normalSprintAnim = Instance.new("Animation")
normalSprintAnim.AnimationId = NORMAL_SPRINT_ID
local NormalSprintTrack = humanoid:WaitForChild("Animator"):LoadAnimation(normalSprintAnim)

-- Priority is Action to overlap the default roblox walking
NormalSprintTrack.Priority = Enum.AnimationPriority.Action
NormalSprintTrack.Looped = true

-- Configuration
local RUN_SPEED = 32

local AirborneState = {
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}

local function hasSwordEquipped()
	local tool = character:FindFirstChildWhichIsA("Tool")
	return (tool and tool.Name == "Tool" or false)
end

local function UpdateMovement()
	if character:GetAttribute("IsAttacking") then return end
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	local isGrounded = not AirborneState[humanoid:GetState()]
	local isWallrunning = character:GetAttribute("IsWallrunning")
	local isSliding = character:GetAttribute("IsSliding")
	
	if not isSliding then
		humanoid.WalkSpeed = RUN_SPEED
	end

	-- If the sword is equipped, let AutoEquipKatana.lua solely handle the sword sprint!
	if hasSwordEquipped() then
		if NormalSprintTrack.IsPlaying then
			NormalSprintTrack:Stop(0.25)
		end
		return
	end

	-- Normal Sprint Logic
	if isMoving and isGrounded and not isWallrunning and not isSliding then
		if not NormalSprintTrack.IsPlaying then
			NormalSprintTrack:Play(0.25)
		end
		NormalSprintTrack:AdjustSpeed(1)
	elseif isMoving and not isGrounded and not isWallrunning and not isSliding then
		if not NormalSprintTrack.IsPlaying then
			NormalSprintTrack:Play(0.25)
		end
		NormalSprintTrack:AdjustSpeed(0.25)
	else
		-- Stop normal sprint if not moving, wallrunning, or sliding
		if NormalSprintTrack.IsPlaying then
			NormalSprintTrack:Stop(0.25)
		end
	end
end

-- Loop
RunService.Heartbeat:Connect(UpdateMovement)
