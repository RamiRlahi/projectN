local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Dash settings
local DASH_FORCE = 100
local DASH_DURATION = 0.2
local DASH_COOLDOWN = 1.0
local isDashing = false
local lastDashTime = 0

-- VFX Settings
local GHOST_COUNT = 5
local GHOST_LIFETIME = 0.4

local function createGhostEffect()
	-- Create a visual "after-image" of the character
	character.Archivable = true
	local ghost = character:Clone()
	character.Archivable = false
	
	-- Remove scripts and physics from ghost
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("LuaSourceContainer") or desc:IsA("ForceEffect") or desc:IsA("Humanoid") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.Anchored = true
			desc.Material = Enum.Material.Neon
			desc.Transparency = 0.5
			desc.Color = Color3.fromRGB(0, 170, 255) -- Dash color
			
			-- Tween transparency to fade out
			TweenService:Create(desc, TweenInfo.new(GHOST_LIFETIME), {Transparency = 1}):Play()
		end
	end
	
	ghost.Parent = workspace
	Debris:AddItem(ghost, GHOST_LIFETIME)
end

local function performDash()
	local currentTime = tick()
	-- Don't dash if already dashing OR if ultimate is active (communicated via attribute)
	if isDashing or (currentTime - lastDashTime < DASH_COOLDOWN) or character:GetAttribute("IsUltimateActive") then return end
	
	isDashing = true
	lastDashTime = currentTime
	
	-- Determine dash direction (movement matching or facing direction)
	local moveDirection = humanoid.MoveDirection
	local dashDirection = moveDirection.Magnitude > 0 and moveDirection or rootPart.CFrame.LookVector
	
	-- Add LinearVelocity for the dash
	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart
	
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = 1000000
	linearVelocity.VectorVelocity = dashDirection * DASH_FORCE
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = rootPart
	
	-- Trail effect
	local ghostConnection
	ghostConnection = RunService.RenderStepped:Connect(function()
		if isDashing then
			createGhostEffect()
		end
	end)
	
	task.wait(DASH_DURATION)
	
	-- Cleanup
	linearVelocity:Destroy()
	attachment:Destroy()
	if ghostConnection then ghostConnection:Disconnect() end
	
	isDashing = false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then -- Use Q for Dash
		performDash()
	end
end)
