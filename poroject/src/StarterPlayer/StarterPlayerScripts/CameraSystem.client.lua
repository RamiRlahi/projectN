local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- Configuration
local CAMERA_OFFSET = Vector3.new(2.5, 2, 0) -- Over-the-shoulder offset
local ROTATION_SPEED = 0.15 -- How smoothly the character turns to face the camera direction
local FIXED_ZOOM_DISTANCE = 10 -- Lock zoom to this distance

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	hrp = character:WaitForChild("HumanoidRootPart")
	humanoid.AutoRotate = false

	-- Reapply zoom lock
	player.CameraMaxZoomDistance = FIXED_ZOOM_DISTANCE
	player.CameraMinZoomDistance = FIXED_ZOOM_DISTANCE
end)

humanoid.AutoRotate = false

-- Lock Zoom
player.CameraMaxZoomDistance = FIXED_ZOOM_DISTANCE
player.CameraMinZoomDistance = FIXED_ZOOM_DISTANCE

RunService.RenderStepped:Connect(function()
	if not character or not hrp or not humanoid then return end

	-- Force Mouse Lock (Shift Lock behavior)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- Apply Camera Offset for the over-the-shoulder look
	-- (2.5 to the right, 2 up)
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(CAMERA_OFFSET, 0.1)

	-- Rotate character to match camera horizontal rotation
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit

	if flatLook.Magnitude > 0 then
		local targetCF = CFrame.lookAt(hrp.Position, hrp.Position + flatLook)
		hrp.CFrame = hrp.CFrame:Lerp(targetCF, ROTATION_SPEED)
	end
end)
