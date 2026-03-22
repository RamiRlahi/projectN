local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Dash settings
local DASH_FORCE = 180
local DASH_DURATION = 0.15
local DASH_COOLDOWN = 0 -- Removed delay between individual dashes
local MAX_CHARGES = 3
local CHARGE_REGEN_TIME = 4.0 -- Time to regen one charge

-- State
local isDashing = false
local currentCharges = MAX_CHARGES
local lastDashTime = 0
local lastRegenTime = tick()

-- Set initial attributes for GUI
character:SetAttribute("DashCharges", currentCharges)
character:SetAttribute("MaxDashCharges", MAX_CHARGES)
character:SetAttribute("DashRegenPercent", 0)

-- Speed VFX part (ReplicatedStorage > VFX > Speed)
local speedVFX = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("Speed")

local function performDash()
	-- Must have katana ("Tool") equipped to dash
	local currentTool = character:FindFirstChildWhichIsA("Tool")
	if not currentTool or currentTool.Name ~= "Tool" then return end

	local currentTime = tick()
	
	-- Check charges and cooldown
	if currentCharges <= 0 or isDashing or (currentTime - lastDashTime < DASH_COOLDOWN) or character:GetAttribute("IsUltimateActive") or character:GetAttribute("IsAttacking") then 
		return 
	end
	
	currentCharges -= 1
	character:SetAttribute("DashCharges", currentCharges)
	
	isDashing = true
	lastDashTime = currentTime
	lastRegenTime = currentTime -- Reset regen timer on use? Or keep it ticking? Usually keep it ticking but restart if full? 
	-- Actually, let's keep it ticking independently in the heartbeat.
	
	-- Determine dash direction (Full 3D Aim-based)
	local mouse = player:GetMouse()
	local targetPos = mouse.Hit.Position
	local dashDirection = (targetPos - rootPart.Position).Unit
	
	-- Add LinearVelocity for the dash
	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart
	
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = 1000000
	linearVelocity.VectorVelocity = dashDirection * DASH_FORCE
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = rootPart
	
	-- Clone and attach the Speed VFX part
	local speedClone = speedVFX:Clone()
	
	-- Create a CFrame that exactly faces the dash direction
	local dashCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + dashDirection)
	
	-- Position the VFX DEAD CENTER on the player so they are inside the thickest part of the energy
	speedClone.CFrame = dashCFrame * CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0)
	speedClone.Parent = character
	
	-- Weld the VFX to the root part so it follows the player
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = speedClone
	weld.Parent = speedClone
	
	-- INTENSE VISUALS: Player dematerializes into pure energy
	local originalStates = {}
	
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			originalStates[part] = { Transparency = part.Transparency }
			part.Transparency = 1 
		elseif part:IsA("Decal") then
			originalStates[part] = { Transparency = part.Transparency }
			part.Transparency = 1 
		end
	end
	
	task.spawn(function()
		local dashHits = {}
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = {character}
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude

		local endTime = tick() + DASH_DURATION
		while tick() < endTime and isDashing do
			local hits = workspace:GetPartBoundsInRadius(rootPart.Position, 7.5, overlapParams)
			for _, hit in ipairs(hits) do
				local enemyModel = hit:FindFirstAncestorOfClass("Model")
				if enemyModel and not dashHits[enemyModel] then
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
					if enemyHumanoid and enemyHumanoid.Health > 0 then
						dashHits[enemyModel] = true
						enemyHumanoid:TakeDamage(25) -- Dash Deal 25 damage
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)

	task.wait(DASH_DURATION)
	
	-- Cleanup and restore player
	linearVelocity:Destroy()
	attachment:Destroy()
	if speedClone then speedClone:Destroy() end
	
	for part, state in pairs(originalStates) do
		if part and part.Parent then
			part.Transparency = state.Transparency
		end
	end
	
	isDashing = false
end

-- Regen Logic
RunService.Heartbeat:Connect(function()
	if currentCharges < MAX_CHARGES then
		local now = tick()
		local elapsed = now - lastRegenTime
		local percent = math.clamp(elapsed / CHARGE_REGEN_TIME, 0, 1)
		
		character:SetAttribute("DashRegenPercent", percent)
		
		if elapsed >= CHARGE_REGEN_TIME then
			currentCharges += 1
			lastRegenTime = now
			character:SetAttribute("DashCharges", currentCharges)
			character:SetAttribute("DashRegenPercent", 0)
		end
	else
		lastRegenTime = tick()
		character:SetAttribute("DashRegenPercent", 0)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then -- Use Right Click for Dash
		performDash()
	end
end)
