--[[
	GunServer  –  Script (Server)
	Place inside ServerScriptService
	
	Handles:
	  • Listening to FireEvent from clients
	  • Raycast sanity-check to validate hits
	  • Damage with falloff + headshots
	  • VAMPIRE MARK PASSIVE: 3 hits = burst (40 dmg) + heal shooter
	  • BillboardGui mark above enemies' heads (transparency changes per stack)
]]

-------------------------------------------------
-- SERVICES
-------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

-------------------------------------------------
-- REFERENCES
-------------------------------------------------
local fireEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireEvent")

-- Burst VFX: blood explosion on the target when 3rd mark pops
local vfxFolder        = ReplicatedStorage:WaitForChild("VFX")
local bloodExplosionVFX = vfxFolder:WaitForChild("BloodExplosion")

-------------------------------------------------
-- CONFIG: GUN DAMAGE
-------------------------------------------------
local MAX_DAMAGE      = 20
local MIN_DAMAGE      = 8
local FALLOFF_START   = 60
local FALLOFF_END     = 200
local HEADSHOT_MULTI  = 2.0
local MAX_VALID_DIST  = 550
local SANITY_RADIUS   = 10

-------------------------------------------------
-- CONFIG: VAMPIRE MARK PASSIVE
-------------------------------------------------
local MARK_STACKS_NEEDED = 3        -- shots needed to trigger burst
local BURST_DAMAGE       = 40       -- bonus damage on burst
local HEAL_AMOUNT        = 25       -- health restored to shooter on burst
local MARK_DECAY_TIME    = 6        -- seconds before marks expire if you stop shooting
local MARK_SIZE          = 3.5      -- size of the logo above the head (was 2)

-- Transparency for each stack level (1 = almost invisible, 0 = fully solid)
local MARK_TRANSPARENCY = {
	[1] = 0.7,   -- first shot:  very faint
	[2] = 0.4,   -- second shot: half visible
	[3] = 0.0,   -- third shot:  fully visible (then burst)
}

-- The image that appears above the enemy's head (vampire icon / bat / blood drop)
-- Replace this with your own decal/image ID!
local MARK_IMAGE_ID = "rbxassetid://107666365975187"  -- default skull icon, replace with your logo

-------------------------------------------------
-- MARK TRACKING: { [targetModel] = { shooter = player, stacks = number, gui = BillboardGui } }
-------------------------------------------------
local activeMarks = {}

-------------------------------------------------
-- HELPER: is this player alive?
-------------------------------------------------
local function isAlive(plr)
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

-------------------------------------------------
-- CREATE / UPDATE the mark icon above a target's head
-------------------------------------------------
local function createOrUpdateMark(targetModel, stacks)
	local head = targetModel:FindFirstChild("Head")
	if not head then return end

	local markData = activeMarks[targetModel]
	local gui = markData and markData.gui

	-- Create BillboardGui if it doesn't exist yet
	if not gui or not gui.Parent then
		gui = Instance.new("BillboardGui")
		gui.Name = "VampireMark"
		gui.Size = UDim2.new(MARK_SIZE, 0, MARK_SIZE, 0)
		gui.StudsOffset = Vector3.new(0, 3, 0)  -- float above head
		gui.AlwaysOnTop = true
		gui.Parent = head

		local icon = Instance.new("ImageLabel")
		icon.Name = "MarkIcon"
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Image = MARK_IMAGE_ID
		icon.ImageColor3 = Color3.fromRGB(180, 0, 0) -- dark red tint
		icon.Parent = gui

		if markData then
			markData.gui = gui
		end
	end

	-- Update transparency based on current stacks
	local icon = gui:FindFirstChild("MarkIcon")
	if icon then
		icon.ImageTransparency = MARK_TRANSPARENCY[stacks] or 0
	end
end

-------------------------------------------------
-- TRIGGER BURST (3rd stack reached)
-------------------------------------------------
local function triggerBurst(targetModel, shooterPlayer)
	local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if targetHumanoid and targetHumanoid.Health > 0 then
		targetHumanoid:TakeDamage(BURST_DAMAGE)
	end

	-- Spawn BloodExplosion VFX on the target
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso")
	if targetRoot then
		local explosionClone = bloodExplosionVFX:Clone()

		if explosionClone:IsA("Model") then
			explosionClone:PivotTo(targetRoot.CFrame)
			for _, part in explosionClone:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
		elseif explosionClone:IsA("BasePart") then
			explosionClone.CFrame = targetRoot.CFrame
			explosionClone.Anchored = true
			explosionClone.CanCollide = false
		end

		explosionClone.Parent = workspace

		-- Fire all particle emitters once for the burst effect
		for _, emitter in explosionClone:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = true
				emitter:Emit(50) -- big burst of blood
			end
		end

		Debris:AddItem(explosionClone, 1) -- reduced from 2 to 1 second
	end

	-- Heal the vampire
	if isAlive(shooterPlayer) then
		local shooterHum = shooterPlayer.Character:FindFirstChildOfClass("Humanoid")
		if shooterHum then
			shooterHum.Health = math.min(shooterHum.Health + HEAL_AMOUNT, shooterHum.MaxHealth)
		end
	end

	-- Remove the mark GUI
	local markData = activeMarks[targetModel]
	if markData and markData.gui then
		markData.gui:Destroy()
	end
	activeMarks[targetModel] = nil
end

-------------------------------------------------
-- REMOVE expired marks
-------------------------------------------------
local function cleanupMark(targetModel)
	local markData = activeMarks[targetModel]
	if markData then
		if markData.gui then markData.gui:Destroy() end
		activeMarks[targetModel] = nil
	end
end

-------------------------------------------------
-- MAIN HANDLER
-------------------------------------------------
fireEvent.OnServerEvent:Connect(function(firingPlayer, hitPart, hitPoint)
	------------------------------------------------------------
	-- 1.  Basic type checks  (anti-exploit)
	------------------------------------------------------------
	if typeof(hitPart) ~= "Instance" then return end
	if typeof(hitPoint) ~= "Vector3" then return end

	------------------------------------------------------------
	-- 2.  Make sure the shooter is alive
	------------------------------------------------------------
	if not isAlive(firingPlayer) then return end

	local shooterChar = firingPlayer.Character
	local shooterRoot = shooterChar:FindFirstChild("HumanoidRootPart")
	if not shooterRoot then return end

	------------------------------------------------------------
	-- 3.  Distance check
	------------------------------------------------------------
	local dist = (hitPoint - shooterRoot.Position).Magnitude
	if dist > MAX_VALID_DIST then return end

	------------------------------------------------------------
	-- 4.  Find the target Humanoid
	------------------------------------------------------------
	local targetModel = hitPart:FindFirstAncestorOfClass("Model")
	if not targetModel then return end

	local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid then return end
	if targetHumanoid.Health <= 0 then return end

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if targetPlayer == firingPlayer then return end

	------------------------------------------------------------
	-- 5.  Server-side raycast sanity check
	------------------------------------------------------------
	local origin    = shooterRoot.Position
	local direction = (hitPoint - origin)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooterChar }

	local result = workspace:Raycast(origin, direction.Unit * math.min(direction.Magnitude + SANITY_RADIUS, MAX_VALID_DIST), params)

	if not result then return end

	local serverHitModel = result.Instance:FindFirstAncestorOfClass("Model")
	if serverHitModel ~= targetModel then return end

	------------------------------------------------------------
	-- 6.  Calculate gun damage (falloff + headshot)
	------------------------------------------------------------
	local baseDamage = MAX_DAMAGE

	if dist > FALLOFF_START then
		if dist >= FALLOFF_END then
			baseDamage = MIN_DAMAGE
		else
			local falloffRange = FALLOFF_END - FALLOFF_START
			local pastStart = dist - FALLOFF_START
			local dropPercent = pastStart / falloffRange
			local damageDrop = (MAX_DAMAGE - MIN_DAMAGE) * dropPercent
			baseDamage = MAX_DAMAGE - damageDrop
		end
	end

	local finalDamage = baseDamage
	if hitPart.Name == "Head" then
		finalDamage = finalDamage * HEADSHOT_MULTI
	end

	targetHumanoid:TakeDamage(finalDamage)

	------------------------------------------------------------
	-- 7.  VAMPIRE MARK PASSIVE
	------------------------------------------------------------
	-- Check if the shooter has DualGun equipped
	local hasDualGun = false
	for _, item in shooterChar:GetChildren() do
		if item:IsA("Tool") and item.Name == "DualGun" then
			hasDualGun = true
			break
		end
	end

	if not hasDualGun then return end  -- passive only works with DualGun

	-- Get or create mark data for this target
	local markData = activeMarks[targetModel]

	if not markData or markData.shooter ~= firingPlayer then
		-- New mark (or different shooter takes over)
		if markData and markData.gui then markData.gui:Destroy() end
		markData = { shooter = firingPlayer, stacks = 0, gui = nil, decayThread = nil }
		activeMarks[targetModel] = markData
	end

	-- Add a stack
	markData.stacks = markData.stacks + 1

	-- Cancel any existing decay timer and start a new one
	if markData.decayThread then
		task.cancel(markData.decayThread)
	end
	markData.decayThread = task.delay(MARK_DECAY_TIME, function()
		cleanupMark(targetModel)
	end)

	-- Check if we reached the burst threshold
	if markData.stacks >= MARK_STACKS_NEEDED then
		-- Show fully solid mark briefly before burst
		createOrUpdateMark(targetModel, 3)

		-- Small delay so the player sees the full mark before it pops
		task.delay(0.15, function()
			triggerBurst(targetModel, firingPlayer)
		end)
	else
		-- Update the mark visual (transparency changes)
		createOrUpdateMark(targetModel, markData.stacks)
	end
end)

-- Cleanup marks when a character dies or leaves
Players.PlayerRemoving:Connect(function(plr)
	-- Remove any marks this player placed
	for model, data in pairs(activeMarks) do
		if data.shooter == plr then
			cleanupMark(model)
		end
	end
end)
