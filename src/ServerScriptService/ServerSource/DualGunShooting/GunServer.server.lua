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
local TweenService      = game:GetService("TweenService")

-------------------------------------------------
-- REFERENCES
-------------------------------------------------
local fireEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireEvent")
local ultimateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UltimateEvent")

-- VFX References
local vfxFolder         = ReplicatedStorage:WaitForChild("VFX")
local bloodExplosionVFX = vfxFolder:WaitForChild("BloodExplosion")
local bloodSummonVFX    = vfxFolder:WaitForChild("BloodSummonDog")
local mouthDogVFX       = vfxFolder:WaitForChild("MouthDog")

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
	for model, data in pairs(activeMarks) do
		if data.shooter == plr then
			cleanupMark(model)
		end
	end
end)

-------------------------------------------------
-- ULTIMATE CONFIG: CERBERUS BURST
-- Change these values to tweak sizes and timing!
-------------------------------------------------
local ULT_DAMAGE         = 60       -- damage to each enemy in range
local ULT_RADIUS         = 15       -- damage radius in studs
local ULT_HEAL_PER_HIT   = 15       -- HP healed per enemy hit
local ULT_COOLDOWN       = 2        -- ⚠️ IMPORTANT: Must match ULTIMATE_COOLDOWN in GunLogic!

local CIRCLE_SCALE       = 0.7      -- ← resize the circle (0.5 = half, 1 = original, 2 = double)
local CIRCLE_GROW_TIME   = 0.3      -- seconds for the circle to grow from nothing
local CIRCLE_ROTATION    = CFrame.Angles(math.rad(0), math.rad(90), math.rad(0))  -- lies FLAT on the ground

local MOUTH_SCALE        = 0.34     -- ← resize the dog mouth
local MOUTH_RISE_HEIGHT  = 100      -- how far the mouth starts below ground (studs)
local MOUTH_RISE_TIME    = 0.35     -- seconds for the mouth to rise up
local MOUTH_SNAP_TIME    = 0.15     -- seconds for the snap
local MOUTH_SNAP_SHRINK  = 0.7     -- how much it squishes on snap (0.7 = 70% of original — try 0.5 for more dramatic)
local MOUTH_ROTATION = CFrame.Angles(0, 0, math.rad(-100))

local ATTACK_DELAY       = 0.4      -- delay between circle appearing and mouth emerging

local ultCooldowns = {}  -- per-player cooldown tracking

-------------------------------------------------
-- ULTIMATE: CERBERUS BURST
-------------------------------------------------
ultimateEvent.OnServerEvent:Connect(function(firingPlayer, targetPos)
	if not isAlive(firingPlayer) then return end
	if typeof(targetPos) ~= "Vector3" then return end

	-- Server-side cooldown check
	local now = tick()
	if ultCooldowns[firingPlayer] and (now - ultCooldowns[firingPlayer]) < ULT_COOLDOWN then
		return
	end
	ultCooldowns[firingPlayer] = now

	------------------------------------------------------------
	-- 1. BLOOD SUMMONING CIRCLE  (glued to ground, grows from nothing)
	------------------------------------------------------------
	-- Raycast downward to find the exact ground position
	local groundParams = RaycastParams.new()
	groundParams.FilterDescendantsInstances = { firingPlayer.Character }
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	local groundRay = workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), groundParams)
	local groundY = groundRay and groundRay.Position.Y or targetPos.Y
	local groundPos = Vector3.new(targetPos.X, groundY, targetPos.Z)

	local circle = bloodSummonVFX:Clone()

	if circle:IsA("Model") then
		circle:ScaleTo(0.01)
		circle:PivotTo(CFrame.new(groundPos) * CIRCLE_ROTATION)  -- flat, glued to ground

		for _, part in circle:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
	end

	circle.Parent = workspace

	-- Grow outward
	if circle:IsA("Model") then
		task.spawn(function()
			local startScale = 0.01
			local endScale = CIRCLE_SCALE
			local elapsed = 0
			while elapsed < CIRCLE_GROW_TIME do
				local dt = game:GetService("RunService").Heartbeat:Wait()
				elapsed = elapsed + dt
				local alpha = math.clamp(elapsed / CIRCLE_GROW_TIME, 0, 1)
				local eased = 1 - (1 - alpha) ^ 3
				circle:ScaleTo(startScale + (endScale - startScale) * eased)
			end
			circle:ScaleTo(endScale)
		end)
	end

	Debris:AddItem(circle, 3)

	------------------------------------------------------------
	-- 2. WAIT, THEN SPAWN DOG MOUTH
	------------------------------------------------------------
	task.wait(ATTACK_DELAY)

	local mouth = mouthDogVFX:Clone()

	-- Start the mouth BELOW the ground (rises up through the circle)
	local startPos = groundPos + Vector3.new(0, -MOUTH_RISE_HEIGHT, 0)
	local endPos   = groundPos + Vector3.new(0, 4, 0)  -- rises above the sigil

	if mouth:IsA("Model") then
		mouth:ScaleTo(MOUTH_SCALE)
		mouth:PivotTo(CFrame.new(startPos) * MOUTH_ROTATION)  -- correct orientation

		for _, part in mouth:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
	end

	mouth.Parent = workspace

	------------------------------------------------------------
	-- 3. ANIMATE: MOUTH RISES UP FROM CIRCLE
	------------------------------------------------------------
	if mouth:IsA("Model") then
		task.spawn(function()
			-- PHASE 1: Rise up
			local elapsed = 0
			while elapsed < MOUTH_RISE_TIME do
				local dt = game:GetService("RunService").Heartbeat:Wait()
				elapsed = elapsed + dt
				local alpha = math.clamp(elapsed / MOUTH_RISE_TIME, 0, 1)
				-- Ease out: fast at start, slows at top
				local eased = 1 - (1 - alpha) ^ 2
				local currentPos = startPos:Lerp(endPos, eased)
				mouth:PivotTo(CFrame.new(currentPos) * MOUTH_ROTATION)
			end
			mouth:PivotTo(CFrame.new(endPos) * MOUTH_ROTATION)

			-- PHASE 2: Snap shut (squish Y scale quickly — more dramatic)
			local snapStart = MOUTH_SCALE
			local snapEnd = MOUTH_SCALE * MOUTH_SNAP_SHRINK
			local snapElapsed = 0
			while snapElapsed < MOUTH_SNAP_TIME do
				local dt = game:GetService("RunService").Heartbeat:Wait()
				snapElapsed = snapElapsed + dt
				local alpha = math.clamp(snapElapsed / MOUTH_SNAP_TIME, 0, 1)
				local current = snapStart + (snapEnd - snapStart) * alpha
				mouth:ScaleTo(current)
			end
		end)
	end

	-- Fire particles if any
	for _, desc in mouth:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			desc:Emit(100)
		end
	end

	Debris:AddItem(mouth, 2)

	------------------------------------------------------------
	-- 4. AREA DAMAGE
	------------------------------------------------------------
	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = { firingPlayer.Character }
	overlap.FilterType = Enum.RaycastFilterType.Exclude

	local parts = workspace:GetPartBoundsInRadius(targetPos, ULT_RADIUS, overlap)
	local hitHumanoids = {}

	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not hitHumanoids[hum] then
				hitHumanoids[hum] = true
				hum:TakeDamage(ULT_DAMAGE)

				-- Heal the vampire per enemy hit
				if isAlive(firingPlayer) then
					local shooterHum = firingPlayer.Character:FindFirstChildOfClass("Humanoid")
					if shooterHum then
						shooterHum.Health = math.min(shooterHum.Health + ULT_HEAL_PER_HIT, shooterHum.MaxHealth)
					end
				end
			end
		end
	end
end)
