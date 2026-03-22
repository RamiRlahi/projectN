--[[
	GunLogic (Hitscan + Ammo UI)  –  LocalScript
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
local leftGun     = tool:WaitForChild("HandleLeft")
local rightGun    = tool:WaitForChild("HandleRight")

local leftMuzzle  = leftGun:FindFirstChild("Muzzle") or Instance.new("Attachment", leftGun)
local rightMuzzle = rightGun:FindFirstChild("Muzzle") or Instance.new("Attachment", rightGun)
leftMuzzle.Name = "Muzzle"
rightMuzzle.Name = "Muzzle"

local fireEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireEvent")

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
local AIM_TIMEOUT       = 5
local aimTrack           = nil
local lastShotTime       = 0
local aimCheckConnection = nil

-------------------------------------------------
-- AMMO UI
-------------------------------------------------
local ammoGui       = nil
local ammoLabel     = nil
local reloadLabel   = nil

local function createAmmoUI()
	-- Don't create if it already exists
	if ammoGui then return end

	ammoGui = Instance.new("ScreenGui")
	ammoGui.Name = "AmmoHUD"
	ammoGui.ResetOnSpawn = false

	-- Main container (bottom-right corner)
	local frame = Instance.new("Frame")
	frame.Name = "AmmoFrame"
	frame.Size = UDim2.new(0, 140, 0, 60)
	frame.Position = UDim2.new(1, -160, 1, -80)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = ammoGui

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	-- Ammo count text
	ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoCount"
	ammoLabel.Size = UDim2.new(1, 0, 0.65, 0)
	ammoLabel.Position = UDim2.new(0, 0, 0, 0)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = ammo .. " / " .. MAX_AMMO
	ammoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ammoLabel.TextScaled = true
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.Parent = frame

	-- "RELOADING" text (hidden by default)
	reloadLabel = Instance.new("TextLabel")
	reloadLabel.Name = "ReloadText"
	reloadLabel.Size = UDim2.new(1, 0, 0.35, 0)
	reloadLabel.Position = UDim2.new(0, 0, 0.65, 0)
	reloadLabel.BackgroundTransparency = 1
	reloadLabel.Text = "[R] Reload"
	reloadLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	reloadLabel.TextScaled = true
	reloadLabel.Font = Enum.Font.Gotham
	reloadLabel.Parent = frame

	ammoGui.Parent = player.PlayerGui
end

local function updateAmmoUI()
	if not ammoLabel then return end

	ammoLabel.Text = ammo .. " / " .. MAX_AMMO

	-- Change color based on ammo
	if ammo <= 0 then
		ammoLabel.TextColor3 = Color3.fromRGB(255, 60, 60)    -- red when empty
	elseif ammo <= 3 then
		ammoLabel.TextColor3 = Color3.fromRGB(255, 170, 0)    -- orange when low
	else
		ammoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)  -- white normally
	end

	-- Show reload hint
	if reloadLabel then
		if reloading then
			reloadLabel.Text = "RELOADING..."
			reloadLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
		elseif ammo < MAX_AMMO then
			reloadLabel.Text = "[R] Reload"
			reloadLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		else
			reloadLabel.Text = ""
		end
	end
end

local function destroyAmmoUI()
	if ammoGui then
		ammoGui:Destroy()
		ammoGui = nil
		ammoLabel = nil
		reloadLabel = nil
	end
end

-------------------------------------------------
-- TRACER
-------------------------------------------------
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

-------------------------------------------------
-- RELOAD
-------------------------------------------------
local function reload()
	if reloading or ammo == MAX_AMMO then return end
	reloading = true
	updateAmmoUI()

	task.wait(1) 

	ammo = MAX_AMMO
	shootLeft = true
	reloading = false
	updateAmmoUI()
end

-------------------------------------------------
-- FIRE
-------------------------------------------------
local function fire()
	if not equipped or reloading then return end
	if ammo <= 0 then reload() return end

	local now = tick()
	if now - lastFire < FIRE_COOLDOWN then return end
	lastFire = now

	local muzzle = shootLeft and leftMuzzle or rightMuzzle

	shootLeft = not shootLeft
	ammo = ammo - 1
	updateAmmoUI()

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

-------------------------------------------------
-- EQUIP / UNEQUIP
-------------------------------------------------
tool.Equipped:Connect(function()
	equipped = true

	-- Create ammo HUD
	createAmmoUI()
	updateAmmoUI()

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
				aimTrack.Priority = Enum.AnimationPriority.Action3
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

	-- Remove ammo HUD
	destroyAmmoUI()

	-- Stop aim animation
	if aimTrack and aimTrack.IsPlaying then
		aimTrack:Stop(0.2)
	end
	if player.Character then
		player.Character:SetAttribute("IsAiming", false)
	end

	if aimCheckConnection then
		aimCheckConnection:Disconnect()
		aimCheckConnection = nil
	end
end)

tool.Activated:Connect(fire)

-------------------------------------------------
-- R-KEY RELOAD
-------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then
		if equipped and not reloading and ammo < MAX_AMMO then
			reload()
		end
	end
end)
