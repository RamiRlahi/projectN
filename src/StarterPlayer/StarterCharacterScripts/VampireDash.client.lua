--[[
	VampireDash  –  LocalScript
	Place inside: StarterPlayer > StarterCharacterScripts
	
	Only works when the DualGun tool is equipped.
	Press X to dash as a bat swarm with blood trail.
	
	VFX Setup:
	  Put your two VFX inside ReplicatedStorage > VFX:
	    • ReplicatedStorage > VFX > BatSwarm    (the bat transformation effect)
	    • ReplicatedStorage > VFX > Blood-01    (the blood trail model: Main + Blood1)
]]

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local Debris             = game:GetService("Debris")

local player    = Players.LocalPlayer
local character = script.Parent
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local DASH_FORCE        = 180
local DASH_DURATION     = 0.25
local DASH_COOLDOWN     = 0          -- no delay between individual dashes
local MAX_CHARGES       = 3
local CHARGE_REGEN_TIME = 4.0
local DASH_DAMAGE       = 25
local TOOL_NAME         = "DualGun"   -- only dash when this tool is equipped
local DASH_KEY          = Enum.KeyCode.X

-- Blood trail drops: how often and how long they last
local BLOOD_DROP_INTERVAL = 0.03      -- seconds between each blood drop
local BLOOD_DROP_LIFETIME = 1.5       -- how long each blood drop stays

-------------------------------------------------
-- VFX REFERENCES
-------------------------------------------------
local vfxFolder     = ReplicatedStorage:WaitForChild("VFX")
local batSwarmVFX   = vfxFolder:WaitForChild("BatSwarm")   -- your bat transformation part/model
local bloodTrailVFX = vfxFolder:WaitForChild("Blood-01")   -- your blood trail model (Main + Blood1)

-------------------------------------------------
-- STATE
-------------------------------------------------
local isDashing      = false
local currentCharges = MAX_CHARGES
local lastDashTime   = 0
local lastRegenTime  = tick()

-- Set initial attributes for GUI
character:SetAttribute("DashCharges", currentCharges)
character:SetAttribute("MaxDashCharges", MAX_CHARGES)
character:SetAttribute("DashRegenPercent", 0)

-------------------------------------------------
-- HELPER: is DualGun equipped?
-------------------------------------------------
local function isDualGunEquipped()
	local char = player.Character
	if not char then return false end
	-- When a Tool is equipped, it becomes a child of the Character
	local tool = char:FindFirstChild(TOOL_NAME)
	return tool and tool:IsA("Tool")
end

-------------------------------------------------
-- PERFORM DASH
-------------------------------------------------
local function performDash()
	local currentTime = tick()

	-- Guards
	if isDashing then return end
	if currentCharges <= 0 then return end
	if currentTime - lastDashTime < DASH_COOLDOWN then return end
	if character:GetAttribute("IsUltimateActive") then return end
	if character:GetAttribute("IsAttacking") then return end
	if not isDualGunEquipped() then return end       -- ← ONLY with DualGun

	-- Consume charge
	currentCharges -= 1
	character:SetAttribute("DashCharges", currentCharges)

	isDashing = true
	lastDashTime = currentTime

	-- Direction: aim toward mouse
	local mouse = player:GetMouse()
	local targetPos = mouse.Hit.Position
	local dashDirection = (targetPos - rootPart.Position).Unit

	-------------------------------------------------
	-- 1. LINEAR VELOCITY (the actual movement)
	-------------------------------------------------
	local attachment = Instance.new("Attachment")
	attachment.Parent = rootPart

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.MaxForce = 1000000
	linearVelocity.VectorVelocity = dashDirection * DASH_FORCE
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = rootPart

	-------------------------------------------------
	-- 2. BAT SWARM + BLOOD TRAIL (start both at the same time)
	-------------------------------------------------

	-- Blood trail: connect FIRST so it fires on the very next frame
	local trailConnection
	trailConnection = RunService.RenderStepped:Connect(function()
		if not isDashing then return end

		local bloodDrop = bloodTrailVFX:Clone()

		-- Position the blood VFX at the player's feet
		local dropCFrame = rootPart.CFrame * CFrame.new(0, -2, 0)

		-- Blood-01 is a Model, so we need to handle it differently
		if bloodDrop:IsA("Model") then
			local primaryPart = bloodDrop.PrimaryPart or bloodDrop:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				bloodDrop:PivotTo(dropCFrame)
			end

			for _, part in bloodDrop:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
		else
			bloodDrop.CFrame = dropCFrame
			bloodDrop.Anchored = true
			bloodDrop.CanCollide = false
		end

		bloodDrop.Parent = workspace

		for _, emitter in bloodDrop:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = true
			end
		end

		Debris:AddItem(bloodDrop, BLOOD_DROP_LIFETIME)
	end)

	-- Bat swarm VFX
	local batClone = batSwarmVFX:Clone()
	local dashCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + dashDirection)
	batClone.CFrame = dashCFrame
	batClone.Parent = character

	-- Weld bat VFX to root so it follows the player
	local batWeld = Instance.new("WeldConstraint")
	batWeld.Part0 = rootPart
	batWeld.Part1 = batClone
	batWeld.Parent = batClone

	-- Enable all ParticleEmitters / Beams inside the bat VFX
	for _, emitter in batClone:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = true
			
			-- 🩸 DEADLOCK STYLE BURST: Big circle that closes in
			local originalSize = emitter.Size
			emitter:Emit(100)  -- Shoots out 100 extra bats instantly!
			
			-- Temporarily increase speed so they spread out into a wide circle fast
			local originalSpeed = emitter.Speed
			emitter.Speed = NumberRange.new(20, 30)
			
			task.delay(0.1, function()
				if emitter.Parent then
					emitter.Speed = originalSpeed
				end
			end)

		elseif emitter:IsA("Beam") then
			emitter.Enabled = true
		end
	end

	-------------------------------------------------
	-- 3. HIDE THE CHARACTER (transform into bats)
	-------------------------------------------------
	local originalStates = {}

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:IsDescendantOf(batClone) then
			originalStates[part] = { Transparency = part.Transparency }
			part.Transparency = 1
		elseif part:IsA("Decal") and not part:IsDescendantOf(batClone) then
			originalStates[part] = { Transparency = part.Transparency }
			part.Transparency = 1
		end
	end

	-------------------------------------------------
	-- 5. DAMAGE ENEMIES DURING DASH
	-------------------------------------------------
	task.spawn(function()
		local dashHits = {}
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = { character }
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude

		local endTime = tick() + DASH_DURATION
		while tick() < endTime and isDashing do
			local hits = workspace:GetPartBoundsInRadius(rootPart.Position, 7.5, overlapParams)
			for _, hit in hits do
				local enemyModel = hit:FindFirstAncestorOfClass("Model")
				if enemyModel and not dashHits[enemyModel] then
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
					if enemyHumanoid and enemyHumanoid.Health > 0 then
						dashHits[enemyModel] = true
						enemyHumanoid:TakeDamage(DASH_DAMAGE)
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)

	-------------------------------------------------
	-- WAIT FOR DASH TO END
	-------------------------------------------------
	task.wait(DASH_DURATION)

	-------------------------------------------------
	-- 6. CLEANUP
	-------------------------------------------------
	linearVelocity:Destroy()
	attachment:Destroy()

	-- Disconnect blood trail spawner
	if trailConnection then
		trailConnection:Disconnect()
	end

	-- Remove bat VFX
	if batClone and batClone.Parent then
		batClone:Destroy()
	end

	-- Restore character visibility
	for part, state in pairs(originalStates) do
		if part and part.Parent then
			part.Transparency = state.Transparency
		end
	end

	isDashing = false
end

-------------------------------------------------
-- CHARGE REGEN
-------------------------------------------------
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

-------------------------------------------------
-- INPUT: X key only
-------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == DASH_KEY then
		performDash()
	end
end)
