--[[
	GunLogic (Hitscan Version)  –  LocalScript
	Place inside the DualGun Tool
]]

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local Debris             = game:GetService("Debris")

local player    = Players.LocalPlayer
local mouse     = player:GetMouse()

local tool        = script.Parent
-- CHANGED TO MATCH YOUR SCREENSHOT
local leftGun     = tool:WaitForChild("HandleLeft")
local rightGun    = tool:WaitForChild("HandleRight")

-- We will create Attachments via code if you haven't made them!
local leftMuzzle  = leftGun:FindFirstChild("Muzzle") or Instance.new("Attachment", leftGun)
local rightMuzzle = rightGun:FindFirstChild("Muzzle") or Instance.new("Attachment", rightGun)
leftMuzzle.Name = "Muzzle"
rightMuzzle.Name = "Muzzle"

-- Make sure RemoteEvent exists
local fireEvent = ReplicatedStorage:FindFirstChild("RemoteEvents") and ReplicatedStorage.RemoteEvents:FindFirstChild("FireEvent")

local MAX_AMMO      = 12
local FIRE_COOLDOWN = 0.15     
local MAX_DISTANCE  = 500      

local ammo      = MAX_AMMO
local shootLeft = true         
local lastFire  = 0
local reloading = false
local equipped  = false

-- Dual-gun aiming animation (upper body only)
local DUAL_AIM_ANIM_ID = "rbxassetid://90957862907806"
local AIM_TIMEOUT       = 5          -- seconds of no shooting before aim pose fades
local aimTrack           = nil
local lastShotTime       = 0
local aimCheckConnection = nil

local function drawTracer(startPos, endPos)
	local distance = (endPos - startPos).Magnitude
	local tracer = Instance.new("Part")
	tracer.Name = "LaserTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Locked = true
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 170, 0)
	tracer.Transparency = 0.2
	tracer.Size = Vector3.new(0.1, 0.1, distance)
	tracer.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance/2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.05)
end

local function reload()
	if reloading or ammo == MAX_AMMO then return end
	reloading = true

	-- You can add animations here later
	task.wait(1) 

	ammo = MAX_AMMO
	shootLeft = true
	reloading = false
end

local function fire()
	if not equipped or reloading then return end
	if ammo <= 0 then reload() return end

	local now = tick()
	if now - lastFire < FIRE_COOLDOWN then return end
	lastFire = now

	local muzzle = shootLeft and leftMuzzle or rightMuzzle

	shootLeft = not shootLeft
	ammo = ammo - 1

	local origin = muzzle.WorldPosition
	local direction = (mouse.Hit.Position - origin).Unit * MAX_DISTANCE

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		params.FilterDescendantsInstances = {player.Character}
	end

	local result = workspace:Raycast(origin, direction, params)
	local endPos = result and result.Position or (origin + direction)

	drawTracer(origin, endPos)

	if result and result.Instance and fireEvent then
		fireEvent:FireServer(result.Instance, endPos)
	end

	-- Play / maintain the upper-body aim pose
	lastShotTime = tick()
	if aimTrack and not aimTrack.IsPlaying then
		aimTrack:Play(0.15)
		if player.Character then
			player.Character:SetAttribute("IsAiming", true)
		end
	end

	if ammo <= 0 then
		task.delay(0.2, reload)
	end
end

tool.Equipped:Connect(function()
	equipped = true

	-- Load the aim animation once
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator and not aimTrack then
				local aimAnim = Instance.new("Animation")
				aimAnim.AnimationId = DUAL_AIM_ANIM_ID
				aimTrack = animator:LoadAnimation(aimAnim)
				aimTrack.Priority = Enum.AnimationPriority.Action3  -- overrides upper body, legs still walk
				aimTrack.Looped = true
			end
		end
	end

	-- Heartbeat: fade aim pose after AIM_TIMEOUT seconds of no shooting
	aimCheckConnection = RunService.Heartbeat:Connect(function()
		if aimTrack and aimTrack.IsPlaying then
			if tick() - lastShotTime >= AIM_TIMEOUT then
				aimTrack:Stop(0.3)
				if player.Character then
					player.Character:SetAttribute("IsAiming", false)
				end
			end
		end
	end)
end)

tool.Unequipped:Connect(function()
	equipped = false

	-- Stop aim animation immediately
	if aimTrack and aimTrack.IsPlaying then
		aimTrack:Stop(0.2)
	end
	if player.Character then
		player.Character:SetAttribute("IsAiming", false)
	end

	-- Disconnect heartbeat checker
	if aimCheckConnection then
		aimCheckConnection:Disconnect()
		aimCheckConnection = nil
	end
end)

tool.Activated:Connect(fire)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then
		if equipped and not reloading and ammo < MAX_AMMO then
			reload()
		end
	end
end)
