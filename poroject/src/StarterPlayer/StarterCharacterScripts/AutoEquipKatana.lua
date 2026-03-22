local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

-- Combo animation IDs (1 through 5)
local COMBO_ANIMS = {
	"rbxassetid://134318041781183",
	"rbxassetid://92421819898500",
	"rbxassetid://80454176482070",
	"rbxassetid://88583926194331",
	"rbxassetid://94261387402696",
}

-- Combo settings
local COMBO_RESET_TIME = 1.0   -- seconds before combo resets back to hit 1
local HIT_COOLDOWN = 0.25      -- minimum time between hits
local SKILL_F_COOLDOWN = 5.0   -- 5 second cooldown for the slash ability
local lastSkillFTime = 0
local SKILL_E_COOLDOWN = 10.0  -- 10 second cooldown for the phase ability
local lastSkillETime = 0
local ULTIMATE_COOLDOWN = 30.0 -- 30 second cooldown for the ultimate
local lastUltimateTime = 0

-- Ultimate animation IDs
local ULT_WINDUP_ANIM_ID = "rbxassetid://98317680059422"
local ULT_END_ANIM_ID    = "rbxassetid://139570550378920"

-- Ultimate settings
local ULT_WINDUP_DURATION = 3      -- seconds of windup
local ULT_DASH_DISTANCE   = 200     -- studs the ult dash covers
local ULT_DASH_SPEED      = 300    -- velocity of the ult dash
local ULT_DAMAGE          = 150    -- damage to each enemy hit
local ULT_HIT_WIDTH       = 30     -- width of the rectangular damage zone

-- Combo state
local comboIndex = 0
local lastHitTime = 0
local isAttacking = false
local hitDebounce = {} -- Stores models hit during current swing

-- Preload combo animations with Action priority
local loadedAnims = {}
for i, animId in ipairs(COMBO_ANIMS) do
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	loadedAnims[i] = animator:LoadAnimation(anim)
	loadedAnims[i].Priority = Enum.AnimationPriority.Action4
end

-- Combat walk animations (play while any tool is equipped)
local SWORD_SPRINT_ANIM_ID = "rbxassetid://122913503621727"

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = SWORD_SPRINT_ANIM_ID
local combatWalk = animator:LoadAnimation(walkAnim)
combatWalk.Priority = Enum.AnimationPriority.Action 
combatWalk.Looped = true

-- Track if combat anims are active
local combatAnimsActive = false
local runConnection = nil

local function updateCombatAnim(speed)
	if not combatAnimsActive then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if speed > 0.1 then
		-- Detect movement direction
		local moveDir = humanoid.MoveDirection
		local look = root.CFrame.LookVector
		local dot = moveDir:Dot(look)

		if not combatWalk.IsPlaying then combatWalk:Play(0.2) end
		
		if dot < -0.2 then
			combatWalk:AdjustSpeed(-1.5) -- Reverse the sword run!
		else
			combatWalk:AdjustSpeed(1.5) -- Normal sword run!
		end
	else
		if combatWalk.IsPlaying then combatWalk:Stop(0.2) end
	end
end

local function setupSwordVFX(tool)
	local hitBox = tool:FindFirstChild("HitBox", true) or tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
	if not hitBox then return end
	if hitBox:FindFirstChild("SwordTrail") then return end

	local att0 = Instance.new("Attachment")
	att0.Name = "TrailAtt0"
	att0.Position = Vector3.new(0, (hitBox.Size.Y / 2) * 0.8, 0)
	att0.Parent = hitBox

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailAtt1"
	att1.Position = Vector3.new(0, -(hitBox.Size.Y / 2) * 0.8, 0)
	att1.Parent = hitBox

	local trail = Instance.new("Trail")
	trail.Name = "SwordTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(Color3.fromRGB(20, 20, 20)) -- Darker charcoal smoke
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4), -- Softer start
		NumberSequenceKeypoint.new(1, 1)
	})
	trail.Lifetime = 0.4
	trail.MinLength = 0.1
	trail.Parent = hitBox
	trail.Enabled = false

	local light = Instance.new("PointLight")
	light.Name = "SwordLight"
	light.Color = Color3.fromRGB(20, 20, 20)
	light.Brightness = 0.5
	light.Range = 8
	light.Parent = hitBox

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "SwordParticles"
	particles.Texture = "rbxassetid://15077160455"
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 15)), -- Deep charcoal particles
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 40))
	})
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.5)})
	particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)})
	particles.Rate = 15
	particles.Speed = NumberRange.new(0, 1)
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Parent = hitBox
end

local function startCombatAnims()
	if combatAnimsActive then return end
	combatAnimsActive = true
	runConnection = humanoid.Running:Connect(updateCombatAnim)
end

local function stopCombatAnims()
	if not combatAnimsActive then return end
	combatAnimsActive = false
	combatWalk:Stop(0.2)
	if runConnection then runConnection:Disconnect() runConnection = nil end
end

-- Function to spawn the Slash VFX airwave
local function spawnAirwave(comboHit, targetPosition)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local slashSource = vfxFolder and vfxFolder:FindFirstChild("Slash")
	local airwave = nil

	if slashSource then
		airwave = slashSource:Clone()
		-- Scaling fix: Increased to 2.5 for better visibility
		if airwave:IsA("BasePart") then
			airwave.Size = airwave.Size * 2.5
		elseif airwave:IsA("Model") then
			airwave:ScaleTo(2.5)
		end
	else
		airwave = Instance.new("Part")
		airwave.Name = "Slash_Fallback"
		airwave.Size = Vector3.new(4, 0.4, 4)
		airwave.Material = Enum.Material.Neon
		airwave.Color = Color3.fromRGB(15, 15, 15)
		airwave.Transparency = 0.5
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://7229390854"
		mesh.Scale = Vector3.new(2.5, 2.5, 2.5)
		mesh.Parent = airwave
	end

	-- Force Recolor and Physics properties
	for _, p in ipairs(airwave:IsA("Model") and airwave:GetDescendants() or {airwave}) do
		if p:IsA("BasePart") then 
			p.Anchored = false 
			p.CanCollide = false
			p.CanTouch = true 
			p.CanQuery = true 
			p.Massless = true
			p.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
			p.Color = Color3.fromRGB(255, 255, 255) -- Bright core to make black outline pop
			p.Material = Enum.Material.Neon
		end
	end

	-- Black Outline Effect
	local highlight = Instance.new("Highlight")
	highlight.Name = "SlashOutline"
	highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
	highlight.OutlineTransparency = 0
	highlight.FillTransparency = 0.8 -- Subtle core fill
	highlight.FillColor = Color3.fromRGB(200, 200, 200)
	highlight.Parent = airwave

	-- 1. Base CFrame pointing towards the mouse cursor
	local startPos = root.Position + Vector3.new(0, 1.5, 0) -- Slightly lower (hip/chest level) for cleaner launch
	local lookVector = root.CFrame.LookVector

	if targetPosition then
		-- Direction from start point to mouse hit location
		lookVector = (targetPosition - startPos).Unit
	end

	-- Spawn only 2 studs forward to avoid "teleporting" look
	local spawnPos = startPos + (lookVector * 2)
	-- Use world UpVector instead of pitch to keep the airwave from diving/climbing too much
	local baseCFrame = CFrame.lookAt(spawnPos, spawnPos + lookVector)

	local rollAngle = 0
	if comboHit == 2 or comboHit == 4 then rollAngle = 60
	elseif comboHit == 5 then rollAngle = 90 end
	local targetCFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(rollAngle)) * CFrame.Angles(0, math.rad(-90), 0)

	if airwave:IsA("Model") then airwave:PivotTo(targetCFrame) else airwave.CFrame = targetCFrame end
	airwave.Parent = workspace

	local movePart = airwave:IsA("Model") and (airwave.PrimaryPart or airwave:FindFirstChildWhichIsA("BasePart")) or airwave
	if not movePart then airwave:Destroy() return end

	-- Physics & Movement
	local attachment = Instance.new("Attachment", movePart)
	local velocity = Instance.new("LinearVelocity")
	velocity.MaxForce = math.huge -- Force it to resist all gravity
	velocity.VectorVelocity = baseCFrame.LookVector * 700
	velocity.Attachment0 = attachment
	velocity.Parent = movePart

	local alignOrientation = Instance.new("AlignOrientation")
	pcall(function() alignOrientation.Mode = Enum.OrientationControlMode.OneAttachment end) -- Fallback if enum fails
	alignOrientation.Attachment0 = attachment
	alignOrientation.CFrame = targetCFrame
	alignOrientation.MaxTorque = math.huge
	alignOrientation.Responsiveness = 200 -- Maximum snap
	alignOrientation.Parent = movePart

	-- VFX Decor
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 200, 200)
	light.Brightness = 3
	light.Range = 15 -- Increased range for better visibility
	light.Parent = movePart

	-- Black Trail Effect
	local tAtt0 = Instance.new("Attachment", movePart)
	local tAtt1 = Instance.new("Attachment", movePart)
	tAtt0.Position = Vector3.new(0, movePart.Size.Y/2, 0)
	tAtt1.Position = Vector3.new(0, -movePart.Size.Y/2, 0)

	local trail = Instance.new("Trail")
	trail.Attachment0 = tAtt0
	trail.Attachment1 = tAtt1
	trail.Color = ColorSequence.new(Color3.fromRGB(20, 20, 20)) -- Deep charcoal smoke color
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4), -- Softer start
		NumberSequenceKeypoint.new(1, 1)
	})
	trail.Lifetime = 0.4
	trail.LightEmission = 0
	trail.Parent = movePart

	-- Damage Logic & Lifetime
	local projectileHits = {}
	local lastPosCFrame = movePart.CFrame
	local totalDistance = 0

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {character, airwave}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local damageConnection
	local isDestroyed = false

	local function burstAndFade()
		if isDestroyed then return end
		isDestroyed = true
		if damageConnection then damageConnection:Disconnect() end
		
		-- Stop the projectile on contact instantly
		if movePart and movePart.Parent then
			movePart.Anchored = true
			if velocity then velocity:Destroy() end
		end
		
		if trail then trail.Enabled = false end
		TweenService:Create(highlight, TweenInfo.new(0.2), {OutlineTransparency = 1, FillTransparency = 1}):Play()
		
		for _, p in ipairs(airwave:IsA("Model") and airwave:GetDescendants() or {airwave}) do
			if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(0.2), {Transparency = 1}):Play() end
		end
		
		task.delay(0.2, function()
			if airwave then airwave:Destroy() end
		end)
	end

	damageConnection = RunService.RenderStepped:Connect(function()
		if not movePart or not movePart.Parent or isDestroyed then 
			if damageConnection then damageConnection:Disconnect() end
			return 
		end
		
		local currentCFrame = movePart.CFrame
		local frameMove = (currentCFrame.Position - lastPosCFrame.Position)
		totalDistance += frameMove.Magnitude
		
		-- Disappear safely after traveling 60 studs
		if totalDistance >= 60 then
			burstAndFade()
			return
		end

		local hitSomething = false

		-- 1. SHAPECAST SWEEP (Strict exact bounding box)
		if frameMove.Magnitude > 0.01 then
			-- strict visual hitbox
			local hitBoxSize = movePart.Size * 1.0 
			local castResult = workspace:Blockcast(lastPosCFrame, hitBoxSize, frameMove, rayParams)
			
			if castResult then
				local enemyModel = castResult.Instance:FindFirstAncestorOfClass("Model")
				if enemyModel and not projectileHits[enemyModel] then
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
					if enemyHumanoid and enemyHumanoid.Health > 0 then
						projectileHits[enemyModel] = true
						enemyHumanoid:TakeDamage(40)
						hitSomething = true
					end
				end
			end
		end
		lastPosCFrame = currentCFrame

		-- 2. SPATIAL BOX QUERY (Using Box query for better volume coverage)
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = {character, airwave}
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		
		-- strict hitbox so it doesn't clip enemies visually dodged
		local detectionSize = movePart.Size * 1.2
		local hits = workspace:GetPartBoundsInBox(movePart.CFrame, detectionSize, overlapParams)
		
		for _, hit in ipairs(hits) do
			local enemyModel = hit:FindFirstAncestorOfClass("Model")
			if enemyModel then
				if not projectileHits[enemyModel] then
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
					if enemyHumanoid and enemyHumanoid.Health > 0 then
						projectileHits[enemyModel] = true
						enemyHumanoid:TakeDamage(40)
						hitSomething = true
					end
				end
			end
		end

		-- Stop on contact
		if hitSomething then
			burstAndFade()
		end
	end)

	-- Hard fallback cleanup
	task.delay(3, function() if not isDestroyed then burstAndFade() end end)
end

-- Function to spawn the specialized "Slash ability" VFX
local function spawnSlashAbilityVFX(targetPosition)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local source = vfxFolder and (vfxFolder:FindFirstChild("Slash ability") or vfxFolder:FindFirstChild("Slash"))
	if not source then return end

	local abilityVFX = source:Clone()
	if abilityVFX:IsA("Model") then abilityVFX:ScaleTo(4.5) else abilityVFX.Size = abilityVFX.Size * 4.5 end
	
	-- Force premium black/neon look + MAX EMISSION
	for _, p in ipairs(abilityVFX:IsA("Model") and abilityVFX:GetDescendants() or {abilityVFX}) do
		if p:IsA("BasePart") then
			p.Color = Color3.fromRGB(255, 255, 255)
			p.Material = Enum.Material.Neon
			p.CanTouch = true
			p.CanQuery = true
		elseif p:IsA("ParticleEmitter") then
			p:Emit(200) -- Massive burst
			p.Rate = 200 -- High sustained density
		end
	end

	-- Violent Screen Shake Logic (Intense & Longer)
	local camera = workspace.CurrentCamera
	task.spawn(function()
		local startTime = tick()
		local duration = 0.8
		while tick() - startTime < duration do
			local intensity = 0.6 * (1 - (tick() - startTime) / duration)
			local offset = Vector3.new(
				math.random(-100, 100) / 100 * intensity,
				math.random(-100, 100) / 100 * intensity,
				math.random(-100, 100) / 100 * intensity
			)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			RunService.RenderStepped:Wait()
		end
	end)

	-- Centered on the player
	local targetCFrame = root.CFrame * CFrame.Angles(0, math.rad(-90), 0)
	if abilityVFX:IsA("Model") then abilityVFX:PivotTo(targetCFrame) else abilityVFX.CFrame = targetCFrame end
	abilityVFX.Parent = workspace

	local movePart = abilityVFX:IsA("Model") and (abilityVFX.PrimaryPart or abilityVFX:FindFirstChildWhichIsA("BasePart")) or abilityVFX
	if not movePart then abilityVFX:Destroy() return end
	
	-- Weld to follow the player perfectly
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = movePart
	weld.Parent = abilityVFX

	-- Damage logic (100 DMG)
	local hitList = {}
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not movePart or not movePart.Parent or not root then conn:Disconnect() return end
		
		local overlap = OverlapParams.new()
		overlap.FilterDescendantsInstances = {character, abilityVFX}
		overlap.FilterType = Enum.RaycastFilterType.Exclude

		-- Massive 30-stud radius spherical hitbox centered perfectly on the player
		local hits = workspace:GetPartBoundsInRadius(root.Position, 30, overlap)
		for _, hit in ipairs(hits) do
			local model = hit:FindFirstAncestorOfClass("Model")
			if model and not hitList[model] then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum then
					hitList[model] = true
					hum:TakeDamage(100) -- Massive Skill Damage
				end
			end
		end
	end)

	task.delay(1.5, function()
		if conn then conn:Disconnect() end
		if abilityVFX then abilityVFX:Destroy() end
	end)
end

local function performSlashAbility(targetPosition)
	local currentTool = character:FindFirstChildWhichIsA("Tool")
	if not currentTool or currentTool.Name ~= "Tool" then return end
	if isAttacking or (tick() - lastSkillFTime < SKILL_F_COOLDOWN) then return end
	
	isAttacking = true
	character:SetAttribute("IsAttacking", true)
	lastSkillFTime = tick()

	-- Lock character in place (Sprint.lua will now ignore this frame)
	local oldSpeed = humanoid.WalkSpeed
	local oldJump = humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	
	-- Only the 5th, most powerful hit
	local anim = loadedAnims[5]
	if anim then
		anim:Play(0.1)
		anim:AdjustSpeed(1.2)
	end

	-- Launch VFX with Shake
	task.spawn(spawnSlashAbilityVFX, targetPosition)
	
	-- Restore movement after VFX duration (1.5s)
	task.delay(1.5, function()
		humanoid.WalkSpeed = oldSpeed
		humanoid.JumpHeight = oldJump
		isAttacking = false
		character:SetAttribute("IsAttacking", false)
	end)
end

-- BIT 1: Simple 0.6 Ghost Transparency for the Rig
local function performPhaseAbility()
	local currentTool = character:FindFirstChildWhichIsA("Tool")
	if not currentTool or currentTool.Name ~= "Tool" then return end
	if (tick() - lastSkillETime < SKILL_E_COOLDOWN) then return end
	lastSkillETime = tick()
	character:SetAttribute("IsPhasing", true)
	
	-- Eye Parts for that ghost look
	local leftEye = Instance.new("Part")
	leftEye.Size = Vector3.new(0.3, 0.15, 0.1)
	leftEye.Color = Color3.fromRGB(255, 0, 0)
	leftEye.Material = Enum.Material.Neon
	leftEye.CanCollide = false
	leftEye.CanQuery = false
	leftEye.Massless = true
	leftEye.Name = "GhostEye_L"
	
	local rightEye = leftEye:Clone()
	rightEye.Name = "GhostEye_R"
	
	local head = character:WaitForChild("Head")
	leftEye.Parent = character
	rightEye.Parent = character
	
	local weldL = Instance.new("Weld")
	weldL.Part0 = head
	weldL.Part1 = leftEye
	weldL.C0 = CFrame.new(-0.25, 0.25, -0.45)
	weldL.Parent = leftEye
	
	local weldR = Instance.new("Weld")
	weldR.Part0 = head
	weldR.Part1 = rightEye
	weldR.C0 = CFrame.new(0.25, 0.25, -0.45)
	weldR.Parent = rightEye

	-- VFX Setup (Black Smoke)
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local source = vfxFolder and vfxFolder:FindFirstChild("phase ability")
	local phaseVFX = nil
	if source then
		phaseVFX = source:Clone()
		-- Make the physical container parts invisible (only show particles!)
		for _, v in ipairs(phaseVFX:IsA("Model") and phaseVFX:GetDescendants() or {phaseVFX}) do
			if v:IsA("BasePart") then 
				v.Transparency = 1 
				v.CanCollide = false 
				v.Size = Vector3.new(0.01, 0.01, 0.01)
			elseif v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end
		
		-- Explicitly check for the 'Shadow' emitter
		local shadow = phaseVFX:FindFirstChild("Shadow", true)
		if shadow and shadow:IsA("ParticleEmitter") then
			shadow.Enabled = true
		end
		
		local movePart = phaseVFX:IsA("Model") and (phaseVFX.PrimaryPart or phaseVFX:FindFirstChildWhichIsA("BasePart")) or (phaseVFX:IsA("BasePart") and phaseVFX)
		if movePart then
			-- Snapping the VFX to the player BEFORE welding it
			if phaseVFX:IsA("Model") then 
				phaseVFX:PivotTo(character.HumanoidRootPart.CFrame) 
			else 
				phaseVFX.CFrame = character.HumanoidRootPart.CFrame 
			end
			
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = character:WaitForChild("HumanoidRootPart")
			weld.Part1 = movePart
			weld.Parent = phaseVFX
			phaseVFX.Parent = character
		end
	end

	-- State capture for restoration
	local originalStates = {}
	for _, part in ipairs(character:GetDescendants()) do
		if (part:IsA("BasePart") or part:IsA("Decal")) and not part:FindFirstAncestorOfClass("Tool") then
			if part.Parent == character or part.Parent:IsA("Accessory") then
				originalStates[part] = { Transparency = part.Transparency, Color = (part:IsA("BasePart") and part.Color or nil), Size = (part:IsA("BasePart") and part.Size or nil) }
			end
		end
	end

	-- FORCED Silhouette Loop (Pitch Black + 0.6 Transparency)
	local phaseLoop
	local oldHipHeight = humanoid.HipHeight
	humanoid.HipHeight = 4 -- Levitating 4 studs up
	
	phaseLoop = RunService.RenderStepped:Connect(function()
		if not character:GetAttribute("IsPhasing") then 
			phaseLoop:Disconnect() 
			return 
		end
		
		for _, part in ipairs(character:GetDescendants()) do
			-- Specifically target the VFX container
			if phaseVFX and (part == phaseVFX or part:IsDescendantOf(phaseVFX)) then
				if part:IsA("BasePart") then
					part.Transparency = 1
					part.Size = Vector3.new(0.01, 0.01, 0.01)
				end
				continue 
			end
			
			if part == leftEye or part == rightEye then continue end
			
			if part:IsA("BasePart") and not part:FindFirstAncestorWhichIsA("Tool") then
				if part.Parent == character or part.Parent:IsA("Accessory") or part.Parent:IsA("Model") then
					-- HIDE LEGS AND FEET ENTIRELY (Phantom look)
					local lowerName = part.Name:lower()
					if lowerName:find("leg") or lowerName:find("foot") then
						part.Transparency = 1
					else
						part.Transparency = 0.6
						part.Color = Color3.new(0, 0, 0)
					end
					
					if part.Name ~= "HumanoidRootPart" then part.CanCollide = false end
				end
			elseif part:IsA("Decal") then
				part.Transparency = 1 -- Hide face/clothes textures
			end
		end
	end)

	-- End phase after 3 seconds
	task.delay(3, function()
		character:SetAttribute("IsPhasing", false)
		leftEye:Destroy()
		rightEye:Destroy()
		if phaseVFX then phaseVFX:Destroy() end
		
		humanoid.HipHeight = oldHipHeight -- Land back down
		
		for part, state in pairs(originalStates) do
			if part and part.Parent then
				part.Transparency = state.Transparency
				if part:IsA("BasePart") then
					part.Color = state.Color
					part.Size = state.Size or part.Size
					part.CanCollide = true
				end
			end
		end
	end)
end

local function handleDamage(hitBox)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	hitDebounce = {}
	local endTime = tick() + 0.3
	while tick() < endTime and isAttacking do
		local parts = workspace:GetPartsInPart(hitBox, overlapParams)
		for _, part in ipairs(parts) do
			local enemyModel = part:FindFirstAncestorOfClass("Model")
			if enemyModel and not hitDebounce[enemyModel] then
				local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
				if enemyHumanoid and enemyHumanoid.Health > 0 then
					hitDebounce[enemyModel] = true
					enemyHumanoid:TakeDamage(40)
				end
			end
		end
		task.wait(0.05)
	end
end

local function performComboHit(targetPosition)
	local currentTool = character:FindFirstChildWhichIsA("Tool")
	if not currentTool or currentTool.Name ~= "Tool" then return end
	local currentTime = tick()
	if isAttacking then return end
	if (currentTime - lastHitTime) < HIT_COOLDOWN then return end
	if (currentTime - lastHitTime) > COMBO_RESET_TIME then comboIndex = 0 end
	
	comboIndex = comboIndex + 1
	if comboIndex > #COMBO_ANIMS then comboIndex = 1 end
	
	isAttacking = true
	character:SetAttribute("IsAttacking", true)
	lastHitTime = currentTime
	for _, anim in ipairs(loadedAnims) do anim:Stop(0.1) end
	
	local currentAnim = loadedAnims[comboIndex]
	currentAnim:Play(0)
	currentAnim:AdjustSpeed(1.5)
	
	local tool = character:FindFirstChildWhichIsA("Tool")
	if tool then
		local hitBox = tool:FindFirstChild("HitBox", true) or tool:FindFirstChild("Handle")
		if hitBox then
			task.spawn(handleDamage, hitBox)
			local trail = hitBox:FindFirstChild("SwordTrail")
			if trail then
				trail.Enabled = true
				task.delay(0.25, function() trail.Enabled = false end)
			end
			local particles = hitBox:FindFirstChild("SwordParticles")
			if particles then particles:Emit(20) end
		end
	end
	
	task.spawn(spawnAirwave, comboIndex, targetPosition)
	currentAnim.Stopped:Once(function() 
		isAttacking = false 
		character:SetAttribute("IsAttacking", false)
	end)
	task.delay(1, function() 
		isAttacking = false 
		character:SetAttribute("IsAttacking", false)
	end)
end

-- ── ULTIMATE ABILITY (Q) ──────────────────────────────────────────────
local ultWindupTrack, ultEndTrack
do
	local a1 = Instance.new("Animation"); a1.AnimationId = ULT_WINDUP_ANIM_ID
	ultWindupTrack = animator:LoadAnimation(a1)
	ultWindupTrack.Priority = Enum.AnimationPriority.Action4

	local a2 = Instance.new("Animation"); a2.AnimationId = ULT_END_ANIM_ID
	ultEndTrack = animator:LoadAnimation(a2)
	ultEndTrack.Priority = Enum.AnimationPriority.Action4
	ultEndTrack.Looped = false
end

local function performUltimate()
	-- Require katana
	local currentTool = character:FindFirstChildWhichIsA("Tool")
	if not currentTool or currentTool.Name ~= "Tool" then return end
	if isAttacking or character:GetAttribute("IsUltimateActive") then return end
	if (tick() - lastUltimateTime < ULTIMATE_COOLDOWN) then return end

	isAttacking = true
	character:SetAttribute("IsAttacking", true)
	character:SetAttribute("IsUltimateActive", true)
	lastUltimateTime = tick()

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Lock movement during windup
	local oldSpeed = humanoid.WalkSpeed
	local oldJump  = humanoid.JumpHeight
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0

	-- ── PHASE 1: WINDUP (3 seconds) ──
	character:SetAttribute("IsWindingUp", true)
	ultWindupTrack:Play(0.1)

	-- Spawn Ult Charge VFX at the player's feet
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local sourceCharge = vfxFolder and vfxFolder:FindFirstChild("ult charge vfx")
	local chargeVFX
	if sourceCharge then
		chargeVFX = sourceCharge:Clone()
		local targetPos = root.Position + Vector3.new(0, -2.5, 0) -- Drop it to floor level
		
		-- CRITICAL: Retain the original rotation the VFX had in Studio so it goes UP!
		if chargeVFX:IsA("Model") then
			local currentPivot = chargeVFX:GetPivot()
			chargeVFX:PivotTo(currentPivot.Rotation + targetPos)
		else
			chargeVFX.Position = targetPos
		end
		
		-- Drastically boost emission so it erupts thick and massive instantly
		for _, e in ipairs(chargeVFX:GetDescendants()) do
			if e:IsA("ParticleEmitter") then
				e.Rate = e.Rate * 50
				e:Emit(100) -- Instant burst right on frame 1
			end
		end

		chargeVFX.Parent = character
		local movePart = chargeVFX:IsA("Model") and (chargeVFX.PrimaryPart or chargeVFX:FindFirstChildWhichIsA("BasePart")) or chargeVFX
		if movePart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = movePart
			weld.Parent = chargeVFX
		end
	end

	-- Building camera shake during windup
	local camera = workspace.CurrentCamera
	local windupStart = tick()
	local shakeConn
	shakeConn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - windupStart
		if elapsed >= ULT_WINDUP_DURATION then
			shakeConn:Disconnect()
			return
		end
		-- Shake intensity builds from 0 to 0.4 over the windup
		local progress = elapsed / ULT_WINDUP_DURATION
		local intensity = progress * 0.4
		local offset = Vector3.new(
			(math.random() - 0.5) * 2 * intensity,
			(math.random() - 0.5) * 2 * intensity,
			(math.random() - 0.5) * 2 * intensity
		)
		camera.CFrame = camera.CFrame * CFrame.new(offset)

		-- Update windup progress for UI
		character:SetAttribute("WindupProgress", progress)
	end)

	task.wait(ULT_WINDUP_DURATION)
	character:SetAttribute("IsWindingUp", false)
	character:SetAttribute("WindupProgress", 0)
	ultWindupTrack:Stop(0.05)
	if chargeVFX then chargeVFX:Destroy() end

	-- ── PHASE 2: INSTANTANEOUS DASH ──
	local dashDir = root.CFrame.LookVector
	local startPos = root.Position

	-- Make player invisible during the dash blink
	local savedTransparencies = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			savedTransparencies[part] = part.Transparency
			part.Transparency = 1
		elseif part:IsA("Decal") then
			savedTransparencies[part] = part.Transparency
			part.Transparency = 1
		end
	end

	-- Teleport forward along the dash path
	local endPos = startPos + dashDir * ULT_DASH_DISTANCE
	root.CFrame = CFrame.lookAt(endPos, endPos + dashDir)

	-- Spawn Ult End VFX at the landing spot
	local sourceEnd = vfxFolder and vfxFolder:FindFirstChild("ult end")
	local landingVFX
	if sourceEnd then
		landingVFX = sourceEnd:Clone()
		local targetPos = root.Position + Vector3.new(0, -2.5, 0)
		
		-- Use the exact Studio rotation so it doesn't blast completely sideways
		if landingVFX:IsA("Model") then
			local currentPivot = landingVFX:GetPivot()
			landingVFX:PivotTo(currentPivot.Rotation + targetPos)
		else
			landingVFX.Position = targetPos
		end
		
		landingVFX.Parent = workspace
		
		-- Give it plenty of time to linger during the 3 second delay
		Debris:AddItem(landingVFX, 4.0)
	end

	-- Rectangular damage sweep along the entire path
	local ultHits = {}
	local halfLen = ULT_DASH_DISTANCE / 2
	local boxCenter = startPos + dashDir * halfLen
	local boxSize = Vector3.new(ULT_HIT_WIDTH, 10, ULT_DASH_DISTANCE)
	local boxCFrame = CFrame.lookAt(boxCenter, boxCenter + dashDir)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local hits = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
	for _, hit in ipairs(hits) do
		local enemyModel = hit:FindFirstAncestorOfClass("Model")
		if enemyModel and not ultHits[enemyModel] then
			local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
			if enemyHumanoid and enemyHumanoid.Health > 0 then
				ultHits[enemyModel] = true
				enemyHumanoid:TakeDamage(ULT_DAMAGE)
			end
		end
	end

	-- Ghost clones: spawn a black phantom at each enemy that plays a slash animation
	for enemyModel, _ in pairs(ultHits) do
		task.spawn(function()
			local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
			if not enemyRoot then return end

			-- Clone the player's rig (Archivable must be true to clone)
			local wasArchivable = character.Archivable
			character.Archivable = true
			local ghost = character:Clone()
			character.Archivable = wasArchivable

			if not ghost then return end

			-- Strip scripts and UI, but KEEP TOOLS so the ghost holds a sword
			for _, child in ipairs(ghost:GetDescendants()) do
				if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript")
					or child:IsA("ForceField") or child:IsA("BillboardGui") or child:IsA("ScreenGui")
					or child:IsA("Sound") then
					child:Destroy()
				end
			end

			local ghostHumanoid = ghost:FindFirstChildOfClass("Humanoid")
			if ghostHumanoid then
				ghostHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				ghostHumanoid.Health = ghostHumanoid.MaxHealth
			end

			-- Make every part pitch-black + semi-transparent + no collision
			for _, part in ipairs(ghost:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Color = Color3.new(0, 0, 0)
					part.Material = Enum.Material.SmoothPlastic
					part.Transparency = 0.4
					part.CanCollide = false
					part.Anchored = false -- limbs stay unanchored so Motor6D animations work
					part.CastShadow = false
				elseif part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 1
				elseif part:IsA("ParticleEmitter") or part:IsA("Trail") or part:IsA("PointLight") then
					part:Destroy()
				end
			end

			-- Dark silhouette highlight
			local highlight = Instance.new("Highlight")
			highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
			highlight.OutlineTransparency = 0.2
			highlight.FillColor = Color3.fromRGB(10, 10, 10)
			highlight.FillTransparency = 0.3
			highlight.Parent = ghost

			-- Position the ghost near the enemy, facing them
			local offset = (enemyRoot.Position - startPos).Unit
			local ghostPos = enemyRoot.Position - offset * 4 
			local ghostRoot = ghost:FindFirstChild("HumanoidRootPart")
			if not ghostRoot then ghost:Destroy() return end

			ghost:PivotTo(CFrame.lookAt(ghostPos, enemyRoot.Position))
			ghostRoot.Anchored = true
			ghost.Name = "UltGhost"
			ghost.Parent = workspace

			-- Wait a frame for Humanoid to initialize in workspace
			RunService.Heartbeat:Wait()

			if ghostHumanoid then
				-- CRUCIAL FIX: Cloned Animators from the LocalPlayer are notoriously broken client-side.
				-- We MUST destroy the old one and create a completely fresh one.
				local oldAnimator = ghostHumanoid:FindFirstChildOfClass("Animator")
				if oldAnimator then oldAnimator:Destroy() end
				
				local ghostAnimator = Instance.new("Animator")
				ghostAnimator.Parent = ghostHumanoid

				local animIndex = math.random(1, #COMBO_ANIMS)
				local ghostAnim = Instance.new("Animation")
				ghostAnim.AnimationId = COMBO_ANIMS[animIndex]
				
				local ghostTrack = ghostAnimator:LoadAnimation(ghostAnim)
				ghostTrack.Priority = Enum.AnimationPriority.Action4

				-- Create a white swing trail for the ghost's weapon
				local ghostTool = ghost:FindFirstChildWhichIsA("Tool")
				local ghostHitBox = ghostTool and (ghostTool:FindFirstChild("HitBox", true) or ghostTool:FindFirstChild("Handle") or ghostTool:FindFirstChildWhichIsA("BasePart"))
				local ghostTrail

				if ghostHitBox then
					local att0 = Instance.new("Attachment")
					att0.Name = "GhostTrailAtt0"
					att0.Position = Vector3.new(0, (ghostHitBox.Size.Y / 2) * 0.8, 0)
					att0.Parent = ghostHitBox

					local att1 = Instance.new("Attachment")
					att1.Name = "GhostTrailAtt1"
					att1.Position = Vector3.new(0, -(ghostHitBox.Size.Y / 2) * 0.8, 0)
					att1.Parent = ghostHitBox

					ghostTrail = Instance.new("Trail")
					ghostTrail.Name = "GhostSwordTrail"
					ghostTrail.Attachment0 = att0
					ghostTrail.Attachment1 = att1
					ghostTrail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
					ghostTrail.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.2), -- Vivid start
						NumberSequenceKeypoint.new(1, 1)    -- Fade out
					})
					ghostTrail.Lifetime = 0.5
					ghostTrail.MinLength = 0.1
					ghostTrail.Enabled = false -- wait before enabling
					ghostTrail.Parent = ghostHitBox
				end

				-- Play the player's Idle animation during the dramatic pause
				local ghostIdleAnim = Instance.new("Animation")
				ghostIdleAnim.AnimationId = "rbxassetid://113340815496069"
				local ghostIdleTrack = ghostAnimator:LoadAnimation(ghostIdleAnim)
				ghostIdleTrack.Priority = Enum.AnimationPriority.Action2
				ghostIdleTrack.Looped = true
				ghostIdleTrack:Play(0.1)

				-- 1 second dramatic pause before the swing
				task.wait(1)
				ghostIdleTrack:Stop(0.1)

				if ghostTrail then ghostTrail.Enabled = true end
				ghostTrack:Play(0)
				ghostTrack:AdjustSpeed(0.6)

				-- Wait for animation to finish, with a max 3 second timeout
				local t0 = tick()
				while ghostTrack.IsPlaying and (tick() - t0) < 3 do
					RunService.Heartbeat:Wait()
				end

				if ghostTrail then ghostTrail.Enabled = false end
			end

			-- Fade out the ghost rapidly instantly after the swing
			for _, part in ipairs(ghost:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.2), {Transparency = 1}):Play()
				end
			end
			TweenService:Create(highlight, TweenInfo.new(0.2), {OutlineTransparency = 1, FillTransparency = 1}):Play()
			task.wait(0.2)
			ghost:Destroy()
		end)
	end

	-- Violent screen shake on landing
	task.spawn(function()
		local t0 = tick()
		local dur = 0.5
		while tick() - t0 < dur do
			local strength = 0.8 * (1 - (tick() - t0) / dur)
			local off = Vector3.new(
				(math.random() - 0.5) * 2 * strength,
				(math.random() - 0.5) * 2 * strength,
				(math.random() - 0.5) * 2 * strength
			)
			camera.CFrame = camera.CFrame * CFrame.new(off)
			RunService.RenderStepped:Wait()
		end
	end)

	-- Brief pause then restore visibility
	task.wait(0.1)
	for part, trans in pairs(savedTransparencies) do
		if part and part.Parent then
			part.Transparency = trans
		end
	end

	-- ── PHASE 3: LANDING ANIMATION ──
	ultEndTrack:Play(0.1)

	task.wait(3.0) -- Lock character movement only for 3 whole seconds

	-- Restore everything
	humanoid.WalkSpeed = oldSpeed
	humanoid.JumpHeight = oldJump
	isAttacking = false
	character:SetAttribute("IsAttacking", false)
	character:SetAttribute("IsUltimateActive", false)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		performComboHit(player:GetMouse().Hit.Position)
	elseif input.KeyCode == Enum.KeyCode.F then
		performSlashAbility(player:GetMouse().Hit.Position)
	elseif input.KeyCode == Enum.KeyCode.E then
		performPhaseAbility()
	elseif input.KeyCode == Enum.KeyCode.Q then
		performUltimate()
	end
end)

local function handleCoverEquip(tool, isEquipping)
	local cover = tool:FindFirstChild("cover") or tool:FindFirstChild("Cover") or tool:FindFirstChild("Scabbard")

	if not cover then
		for _, child in ipairs(tool:GetDescendants()) do
			if string.lower(child.Name):match("cover") then
				cover = child
				break
			end
		end
	end

	if not cover then return end

	if isEquipping then
		-- Hide original
		cover.Transparency = 1

		-- Clean up old
		local oldClone = character:FindFirstChild("EquippedCoverClone")
		if oldClone then oldClone:Destroy() end

		local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
		if leftHand then
			local clone = cover:Clone()
			clone.Name = "EquippedCoverClone"
			clone.Transparency = 0
			clone.Massless = true
			clone.CanCollide = false
			clone.Anchored = false
			
			for _, c in ipairs(clone:GetChildren()) do
				if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("Weld") or c:IsA("Motor6D") or c:IsA("WeldConstraint") then
					c:Destroy()
				end
			end
			
			clone.Parent = character
			
			-- Snap to LeftHand position first
			if clone:IsA("Model") then
				clone:PivotTo(leftHand.CFrame)
			else
				clone.CFrame = leftHand.CFrame
			end
			
			-- Create relative weld
			local weld = Instance.new("Weld")
			weld.Part0 = leftHand
			weld.Part1 = clone
			
			-- Offset: tweaks the cover's position in the hand.
			-- If it points the wrong way, we adjust these CFrame.Angles
			weld.C0 = CFrame.new(0, 0, 0) 
			weld.C1 = CFrame.Angles(math.rad(0), 0, 0) * CFrame.new(0, 0, 0)
			weld.Parent = clone
		end
	else
		-- Unequipping
		cover.Transparency = 0
		
		local oldClone = character:FindFirstChild("EquippedCoverClone")
		if oldClone then oldClone:Destroy() end
	end
end

character.ChildAdded:Connect(function(child)
	if child:IsA("Tool") and child.Name == "Tool" then 
		setupSwordVFX(child) 
		startCombatAnims() 
		handleCoverEquip(child, true)
	end
end)

character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") and child.Name == "Tool" then 
		comboIndex = 0 
		stopCombatAnims() 
		handleCoverEquip(child, false)
	end
end)

local initialTool = character:FindFirstChildWhichIsA("Tool")
if initialTool and initialTool.Name == "Tool" then 
	setupSwordVFX(initialTool) 
	startCombatAnims() 
	handleCoverEquip(initialTool, true)
end
