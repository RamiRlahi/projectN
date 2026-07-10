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
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Animation IDs
local LAZER_ANIM_ID = "rbxassetid://124154429170886"
local BLACK_HOLE_CAST_ANIM_ID = "rbxassetid://97374117281075"
local BLACK_HOLE_TRAPPED_ANIM_ID = "rbxassetid://131529727909335"

-- Load Animation
local lazerAnim = Instance.new("Animation")
lazerAnim.AnimationId = LAZER_ANIM_ID
local lazerTrack = animator:LoadAnimation(lazerAnim)
lazerTrack.Priority = Enum.AnimationPriority.Action4
lazerTrack.Looped = false -- Force animation to play only once

local blackHoleCastAnim = Instance.new("Animation")
blackHoleCastAnim.AnimationId = BLACK_HOLE_CAST_ANIM_ID
local blackHoleCastTrack = animator:LoadAnimation(blackHoleCastAnim)
blackHoleCastTrack.Priority = Enum.AnimationPriority.Action4
blackHoleCastTrack.Looped = false

local function resetLazerTrack()
	if lazerTrack.IsPlaying then
		lazerTrack:Stop(0)
	end

	lazerTrack.Looped = false
	lazerTrack.Priority = Enum.AnimationPriority.Action4
	lazerTrack.TimePosition = 0
	lazerTrack:AdjustSpeed(1)
end

local function playLazerTrack(speed, fadeTime)
	resetLazerTrack()
	lazerTrack:Play(fadeTime or 0.05)
	lazerTrack:AdjustSpeed(speed or 1)
end

-- Combat run animation (same sprint/run used by the Assassin class)
local ASSASSIN_SPRINT_ANIM_ID = "rbxassetid://122913503621727"

local runAnim = Instance.new("Animation")
runAnim.AnimationId = ASSASSIN_SPRINT_ANIM_ID
local timeRunTrack = animator:LoadAnimation(runAnim)
timeRunTrack.Looped = true

local TIME_RUN_FADE = 0
timeRunTrack.Priority = Enum.AnimationPriority.Action4
local timeRunActive = false
local runConnection = nil

local function updateTimeRunAnim(speed)
	if not timeRunActive then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if speed > 0.1 then
		local moveDir = humanoid.MoveDirection
		local look = root.CFrame.LookVector
		local dot = moveDir:Dot(look)

		if not timeRunTrack.IsPlaying then
			timeRunTrack:Play(TIME_RUN_FADE)
		end

		if dot < -0.2 then
			timeRunTrack:AdjustSpeed(-1.5)
		else
			timeRunTrack:AdjustSpeed(1.5)
		end
	else
		if timeRunTrack.IsPlaying then timeRunTrack:Stop(TIME_RUN_FADE) end
	end
end

local function startTimeRunAnim()
	if timeRunActive then return end
	timeRunActive = true
	runConnection = humanoid.Running:Connect(updateTimeRunAnim)
	-- Initial update based on current movement state
	updateTimeRunAnim(humanoid.WalkSpeed * (humanoid.MoveDirection.Magnitude > 0.05 and 1 or 0))
end

local function stopTimeRunAnim()
	if not timeRunActive then return end
	timeRunActive = false
	timeRunTrack:Stop(TIME_RUN_FADE)
	if runConnection then runConnection:Disconnect() runConnection = nil end
end

-- Track the Current Tool State
local toolInCharacter = false

-- State
local isAttacking = false
local isLazerActive = false
local lazerConnection = nil
local activeLazerOuter = nil
local activeLazerCore = nil
local activeLazerLight = nil
local nextLazerDamageTime = 0
local LAZER_RANGE = 150
local LAZER_DAMAGE = 10
local LAZER_DAMAGE_INTERVAL = 0.2
local LAZER_AIM_HOLD_DELAY = 0.2
local LAZER_AIM_POSE_TIME = 0.35
local BOMB_COOLDOWN = 2
local BOMB_CAST_LOCK_TIME = 0.6
local nextBombTime = 0

-- F Ability: Time Dash
local SPRINT_DURATION = 2
local SPRINT_SPEED = 120
local SPRINT_COOLDOWN = 2
local GHOST_COLOR = Color3.fromRGB(0, 255, 255) -- Cyan for Time
local GHOST_LIFETIME = 0.5
local SPRINT_FOV = 100
local NORMAL_FOV = 70
local nextSprintTime = 0

-- M2 Ability: Rewind
local REWIND_MAX_SECONDS = 4
local REWIND_COOLDOWN = 12
local REWIND_FPS = 20
local REWIND_PLAYBACK_STEP = 3
local RECALL_VFX_LIFETIME = 2
local RECALL_VFX_SCALE = 2.5
local RECALL_VANISH_TIME = 0.12
local RECALL_EXTRA_HIDDEN_TIME = 0.5
local nextRewindTime = 0
local positionHistory = {}

-- Q Ability: Black Hole Ultimate
local BLACK_HOLE_DURATION = 5
local BLACK_HOLE_COOLDOWN = 30
local BLACK_HOLE_RADIUS = 150
local BLACK_HOLE_PULL_DISTANCE = 8
local BLACK_HOLE_PULL_SPEED = 8
local BLACK_HOLE_FLIP_SPEED = 10
local BLACK_HOLE_FLOAT_HEIGHT = 4
local BLACK_HOLE_VFX_SCALE = 4
local nextBlackHoleTime = 0

local function findChildCaseInsensitive(parent, childName)
	local exact = parent:FindFirstChild(childName)
	if exact then return exact end

	local loweredName = string.lower(childName)
	for _, child in ipairs(parent:GetChildren()) do
		if string.lower(child.Name) == loweredName then
			return child
		end
	end

	return nil
end

local function findTimeVFXSource(vfxName)
	local vfxFolder = findChildCaseInsensitive(ReplicatedStorage, "VFX")
	if not vfxFolder then
		warn("DEBUG WARNING: ReplicatedStorage.VFX folder not found for Time VFX")
		return nil
	end

	local timeFolder = findChildCaseInsensitive(vfxFolder, "time")
	if not timeFolder then
		warn("DEBUG WARNING: ReplicatedStorage.VFX.time folder not found for Time VFX")
		return nil
	end

	local source = findChildCaseInsensitive(timeFolder, vfxName)
	if not source then
		warn("DEBUG WARNING: ReplicatedStorage.VFX.time." .. vfxName .. " not found")
	end

	return source
end

local function findRecallVFXSource()
	return findTimeVFXSource("recallvfx")
end

local function positionVFX(vfx, cframe)
	if vfx:IsA("Model") then
		vfx:PivotTo(cframe)
	elseif vfx:IsA("BasePart") then
		vfx.CFrame = cframe
	else
		local pivotPart = vfx:FindFirstChildWhichIsA("BasePart", true)
		if pivotPart then
			local offset = cframe * pivotPart.CFrame:Inverse()
			for _, desc in ipairs(vfx:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.CFrame = offset * desc.CFrame
				end
			end
		end
	end
end

local function scaleNumberSequence(sequence, scale)
	local keypoints = {}
	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(keypoints, NumberSequenceKeypoint.new(
			keypoint.Time,
			keypoint.Value * scale,
			keypoint.Envelope * scale
		))
	end
	return NumberSequence.new(keypoints)
end

local function scaleBlackHoleVFX(vfx)
	if vfx:IsA("Model") then
		vfx:ScaleTo(vfx:GetScale() * BLACK_HOLE_VFX_SCALE)
	elseif vfx:IsA("BasePart") then
		vfx.Size *= BLACK_HOLE_VFX_SCALE
	end
end

local function scaleRecallVFX(vfx)
	if vfx:IsA("Model") then
		vfx:ScaleTo(RECALL_VFX_SCALE)
	elseif vfx:IsA("BasePart") then
		vfx.Size *= RECALL_VFX_SCALE
	elseif vfx:IsA("ParticleEmitter") then
		vfx.Size = scaleNumberSequence(vfx.Size, RECALL_VFX_SCALE)
	end

	for _, desc in ipairs(vfx:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Size = scaleNumberSequence(desc.Size, RECALL_VFX_SCALE)
		end
	end
end

local function createRecallVFXAnchor(cframe)
	local anchor = Instance.new("Part")
	anchor.Name = "ActiveRecallVFXAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = cframe
	anchor.Parent = workspace
	return anchor
end

local function spawnRecallVFX(cframe)
	local source = findRecallVFXSource()
	if not source then return nil end

	local vfx = source:Clone()
	vfx.Name = "ActiveRecallVFX"
	scaleRecallVFX(vfx)

	local cleanupTarget = vfx
	if vfx:IsA("Attachment") then
		local anchor = createRecallVFXAnchor(cframe)
		vfx.Parent = anchor
		cleanupTarget = anchor
	elseif vfx:IsA("ParticleEmitter") or vfx:IsA("Beam") or vfx:IsA("Trail") then
		local anchor = createRecallVFXAnchor(cframe)
		local attachment = Instance.new("Attachment")
		attachment.Name = "ActiveRecallVFXAttachment"
		attachment.Parent = anchor
		vfx.Parent = attachment
		cleanupTarget = anchor
	else
		positionVFX(vfx, cframe)
		vfx.Parent = workspace
	end

	for _, desc in ipairs(vfx:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.Massless = true
			desc.Anchored = true
		elseif desc:IsA("ParticleEmitter") then
			desc.Enabled = true
			desc:Emit(desc:GetAttribute("EmitCount") or 30)
		elseif desc:IsA("Beam") or desc:IsA("Trail") then
			desc.Enabled = true
		end
	end

	if vfx:IsA("BasePart") then
		vfx.CanCollide = false
		vfx.CanTouch = false
		vfx.CanQuery = false
		vfx.Massless = true
		vfx.Anchored = true
	elseif vfx:IsA("ParticleEmitter") then
		vfx.Enabled = true
		vfx:Emit(vfx:GetAttribute("EmitCount") or 30)
	elseif vfx:IsA("Beam") or vfx:IsA("Trail") then
		vfx.Enabled = true
	end

	Debris:AddItem(cleanupTarget, RECALL_VFX_LIFETIME)
	return vfx
end

local function setRecallCharacterHidden(hidden, savedTransparency)
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
			if hidden then
				if savedTransparency[desc] == nil then
					savedTransparency[desc] = desc.Transparency
				end
				TweenService:Create(desc, TweenInfo.new(RECALL_VANISH_TIME), {Transparency = 1}):Play()
			else
				local originalTransparency = savedTransparency[desc]
				if originalTransparency ~= nil then
					TweenService:Create(desc, TweenInfo.new(RECALL_VANISH_TIME), {Transparency = originalTransparency}):Play()
				end
			end
		end
	end
end

local function enableVFXEmitters(vfx)
	for _, desc in ipairs(vfx:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			desc.Anchored = true
		elseif desc:IsA("ParticleEmitter") then
			desc.Enabled = true
			desc:Emit(desc:GetAttribute("EmitCount") or 50)
		elseif desc:IsA("Beam") or desc:IsA("Trail") then
			desc.Enabled = true
		end
	end

	if vfx:IsA("BasePart") then
		vfx.CanCollide = false
		vfx.CanTouch = false
		vfx.CanQuery = false
		vfx.Anchored = true
	elseif vfx:IsA("ParticleEmitter") then
		vfx.Enabled = true
		vfx:Emit(vfx:GetAttribute("EmitCount") or 50)
	elseif vfx:IsA("Beam") or vfx:IsA("Trail") then
		vfx.Enabled = true
	end
end

local function spawnBlackHoleVFX(cframe)
	local source = findTimeVFXSource("Black Hole")
	if not source then return nil end

	local vfx = source:Clone()
	vfx.Name = "ActiveBlackHoleVFX"
	scaleBlackHoleVFX(vfx)

	local cleanupTarget = vfx
	if vfx:IsA("Attachment") then
		local anchor = createRecallVFXAnchor(cframe)
		vfx.Parent = anchor
		cleanupTarget = anchor
	elseif vfx:IsA("ParticleEmitter") or vfx:IsA("Beam") or vfx:IsA("Trail") then
		local anchor = createRecallVFXAnchor(cframe)
		local attachment = Instance.new("Attachment")
		attachment.Name = "ActiveBlackHoleVFXAttachment"
		attachment.Parent = anchor
		vfx.Parent = attachment
		cleanupTarget = anchor
	else
		positionVFX(vfx, cframe)
		vfx.Parent = workspace
	end

	enableVFXEmitters(vfx)
	Debris:AddItem(cleanupTarget, BLACK_HOLE_DURATION)
	return vfx
end

local function playTrackForDuration(track, duration)
	if track.IsPlaying then
		track:Stop(0)
	end

	track.TimePosition = 0
	track:AdjustSpeed(1)
	track:Play(0.05)

	task.defer(function()
		task.wait()
		if track.Length > 0 then
			track:AdjustSpeed(track.Length / duration)
		end
	end)
end

-- Function to setup the tool's visual effect and arm replacement
local function setupToolVFX(tool)
	print("DEBUG: setupToolVFX starting for", tool.Name)
	
	local rightHand = character:WaitForChild("RightHand", 5)
	local rightLower = character:WaitForChild("RightLowerArm", 5)
	local rightUpper = character:WaitForChild("RightUpperArm", 5)

	if not rightHand or not rightLower or not rightUpper then 
		warn("DEBUG ERROR: One or more arm segments NOT FOUND in character")
		return 
	end
	
	print("DEBUG: Arm segments found. Hiding real arm...")

	-- 1. Hide the REAL arm
	rightHand.Transparency = 1
	rightLower.Transparency = 1
	rightUpper.Transparency = 1

	-- Hide decals
	for _, v in ipairs(character:GetDescendants()) do
		if v:IsA("Decal") and (v.Parent == rightHand or v.Parent == rightLower or v.Parent == rightUpper) then
			v.Transparency = 1
		end
	end

	-- 2. Clone/Scale Logic
	local customArmParts = {"RightUpperArm", "RightLowerArm", "RightHand"}
	local mapping = {
		["RightHand"] = rightHand,
		["RightLowerArm"] = rightLower,
		["RightUpperArm"] = rightUpper
	}

	local ARM_SCALE = 0.75
	local clonedArmParts = {}

	local function alignPVInstanceByAttachment(pvInstance, attachmentName, targetPart, targetAttachmentName)
		local targetAttachment = targetPart:FindFirstChild(targetAttachmentName, true)
		if not targetAttachment then
			return false
		end

		local pvAttachment = pvInstance:FindFirstChild(attachmentName, true)
		if not pvAttachment then
			return false
		end

		local currentPivot = pvInstance:GetPivot()
		local currentAttachmentWorld = pvAttachment.WorldCFrame
		local offset = currentAttachmentWorld:Inverse() * currentPivot
		local targetPivot = targetAttachment.WorldCFrame * offset
		pvInstance:PivotTo(targetPivot)
		return true
	end

	local targetContainer = tool:FindFirstChild("Model") or tool:FindFirstChild("Handle")

	for _, partName in ipairs(customArmParts) do
		local source = targetContainer and targetContainer:FindFirstChild(partName)
		if source then
			print("DEBUG: Processing segment:", partName)
			
			-- Clean up any old clone
			local oldClone = character:FindFirstChild("Time_" .. partName)
			if oldClone then 
				print("DEBUG: Destroying old clone for", partName)
				oldClone:Destroy() 
			end

			-- Create new clone FIRST to flawlessly preserve original textures & transparency
			local clone = source:Clone()
			clone.Name = "Time_" .. partName
			clone.Parent = character
			print("DEBUG: Clone created and parented to character for", partName)

			-- CRITICAL FIX: NOW hide the original parts inside the tool so they don't fall/show
			if source:IsA("BasePart") then
				source.Transparency = 1
				source.CanCollide = false
				source.CanTouch = false
				source.CanQuery = false
			end
			for _, d in ipairs(source:GetDescendants()) do
				if d:IsA("BasePart") then 
					d.Transparency = 1 
					d.CanCollide = false 
				end
			end

			if clone:IsA("Model") then
				clone:ScaleTo(clone:GetScale() * ARM_SCALE)
			elseif clone:IsA("BasePart") then
				clone.Size = clone.Size * ARM_SCALE

				-- Only manually scale attachments and descendants if it is NOT a Model
				-- (since Model:ScaleTo already handles it perfectly!)
				for _, descendant in ipairs(clone:GetDescendants()) do
					if descendant:IsA("Attachment") then
						descendant.Position = descendant.Position * ARM_SCALE
					end
				end

				for _, descendant in ipairs(clone:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Size = descendant.Size * ARM_SCALE
						local weld = descendant:FindFirstChildOfClass("Weld") or descendant:FindFirstChildOfClass("ManualWeld") or descendant:FindFirstChildOfClass("Motor6D")
						if weld then
							weld.C0 = weld.C0 + (weld.C0.Position * (ARM_SCALE - 1))
							weld.C1 = weld.C1 + (weld.C1.Position * (ARM_SCALE - 1))
						else
							-- CRITICAL PHYSICS FIX: If the clone process broke the Steampunk internal welds,
							-- we force a WeldConstraint so the decorations stick and don't fall through the map!
							-- We ONLY do this if there is no native weld (like a script-rotated gear)
							local lockWeld = Instance.new("WeldConstraint")
							lockWeld.Part0 = clone
							lockWeld.Part1 = descendant
							lockWeld.Parent = descendant
						end
					end
				end
			end

			-- 1. Clean up invalid/broken welds that reference parts outside of the clone first
			for _, c in ipairs(clone:GetDescendants()) do
				if c:IsA("Weld") or c:IsA("ManualWeld") or c:IsA("WeldConstraint") or c:IsA("Motor6D") then
					local part0Valid = c.Part0 and (c.Part0 == clone or c.Part0:IsDescendantOf(clone))
					local part1Valid = c.Part1 and (c.Part1 == clone or c.Part1:IsDescendantOf(clone))
					if not (part0Valid and part1Valid) then
						c:Destroy()
					end
				end
			end

			-- 2. Common configuration and critical physics welds for all BaseParts inside the clone
			local descendantsToConfig = clone:IsA("BasePart") and {clone, unpack(clone:GetDescendants())} or clone:GetDescendants()
			for _, descendant in ipairs(descendantsToConfig) do
				if descendant:IsA("BasePart") then
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
					descendant.Anchored = false
					descendant.Massless = true
					
					-- Ensure it has a weld to the clone root so it doesn't fall through the map!
					if descendant ~= clone then
						local hasWeld = descendant:FindFirstChildOfClass("Weld") or 
						                descendant:FindFirstChildOfClass("ManualWeld") or 
						                descendant:FindFirstChildOfClass("WeldConstraint") or 
						                descendant:FindFirstChildOfClass("Motor6D")
						if not hasWeld then
							local lockWeld = Instance.new("WeldConstraint")
							lockWeld.Part0 = clone:IsA("BasePart") and clone or (clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true))
							lockWeld.Part1 = descendant
							lockWeld.Parent = descendant
						end
					end
				end
			end

			-- Always weld each clone to its corresponding REAL arm part so it
			-- follows the animation's joint rotations (elbow bend, wrist twist).
			-- Welding clone-to-clone would create a rigid chain that can't bend.
			local target = mapping[partName]

			if not alignPVInstanceByAttachment(clone, 
				partName == "RightLowerArm" and "RightElbowRigAttachment" or
				partName == "RightHand" and "RightWristRigAttachment" or
				"RightShoulderRigAttachment",
				target,
				partName == "RightLowerArm" and "RightElbowRigAttachment" or
				partName == "RightHand" and "RightWristRigAttachment" or
				"RightShoulderRigAttachment"
			) then
				clone:PivotTo(target:GetPivot())
			end

			-- WeldConstraint needs to connect BaseParts, not a Model.
			local weldPart = nil
			if clone:IsA("BasePart") then
				weldPart = clone
			elseif clone:IsA("Model") then
				weldPart = clone.PrimaryPart or clone:FindFirstChild(partName, true) or clone:FindFirstChildWhichIsA("BasePart", true)
			end

			if weldPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = target
				weld.Part1 = weldPart
				weld.Parent = weldPart
				clonedArmParts[partName] = clone
				print("DEBUG: WeldConstraint established for", partName, "-> real", partName)
			else
				warn("DEBUG ERROR: No BasePart found in clone to weld for", partName)
			end
		else
			warn("DEBUG ERROR: Source part NOT FOUND in tool's Model/Handle for", partName)
		end
	end

	-- 3. Add the magical glow effect
	local rightHandPart = character:FindFirstChild("RightHand")
	if rightHandPart then
		local attachment = rightHandPart:FindFirstChild("TimeHandVFX")
		if not attachment then
			print("DEBUG: Adding glow effect to RightHand")
			attachment = Instance.new("Attachment")
			attachment.Name = "TimeHandVFX"
			attachment.Parent = rightHandPart

			local particles = Instance.new("ParticleEmitter")
			particles.Name = "TimeParticles"
			particles.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))
			})
			particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
			particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
			particles.Lifetime = NumberRange.new(0.4, 0.8)
			particles.Rate = 25
			particles.Texture = "rbxassetid://15077160455"
			particles.Parent = attachment
		end
	end

	-- Only disable collision on the tool's Handle to prevent it from
	-- hitting the floor during arm swing animations. Don't touch other
	-- tool parts to avoid breaking the physics assembly.
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CanCollide = false
		handle.Massless = true
	end
end

local function cleanupLazerBeam()
	if lazerConnection then
		lazerConnection:Disconnect()
		lazerConnection = nil
	end

	local fadeInfo = TweenInfo.new(0.15)
	if activeLazerOuter then
		TweenService:Create(activeLazerOuter, fadeInfo, {Transparency = 1, Size = Vector3.new(0, 0, activeLazerOuter.Size.Z)}):Play()
		Debris:AddItem(activeLazerOuter, 0.15)
		activeLazerOuter = nil
	end
	if activeLazerCore then
		TweenService:Create(activeLazerCore, fadeInfo, {Transparency = 1, Size = Vector3.new(0, 0, activeLazerCore.Size.Z)}):Play()
		Debris:AddItem(activeLazerCore, 0.15)
		activeLazerCore = nil
	end
	activeLazerLight = nil
end

local function stopLazer()
	if not isLazerActive then return end

	isLazerActive = false
	isAttacking = false
	character:SetAttribute("IsAttacking", false)
	cleanupLazerBeam()

	if lazerTrack.IsPlaying then
		lazerTrack:Stop(0.1)
	end

	lazerTrack.TimePosition = 0
	lazerTrack:AdjustSpeed(1)
	lazerTrack.Looped = false
	character:SetAttribute("IsAiming", false)
end

-- Function to perform the M1 Lazer Ability
local function startLazer()
	if isAttacking then return end
	if isLazerActive then return end
	isAttacking = true
	isLazerActive = true
	nextLazerDamageTime = 0

	playLazerTrack(1.5, 0.05)
	character:SetAttribute("IsAiming", true)

	task.delay(LAZER_AIM_HOLD_DELAY, function()
		if not isLazerActive or not lazerTrack.IsPlaying then return end

		local poseTime = LAZER_AIM_POSE_TIME
		if lazerTrack.Length > 0 then
			poseTime = math.min(poseTime, lazerTrack.Length * 0.5)
		end

		lazerTrack.TimePosition = poseTime
		lazerTrack:AdjustSpeed(0)
	end)

	-- Find the custom steampunk hand we cloned earlier
	local sourceHand = character:FindFirstChild("Time_RightHand") or character:FindFirstChild("RightHand")
	if not sourceHand then
		stopLazer()
		return
	end

	local outer = Instance.new("Part")
	outer.Name = "TimeLazerContour"
	outer.Anchored = true
	outer.CanCollide = false
	outer.CanTouch = false
	outer.CanQuery = false
	outer.Material = Enum.Material.Neon
	outer.Color = Color3.fromRGB(120, 255, 255)
	outer.Transparency = 0.55
	outer.Size = Vector3.new(0.18, 0.18, 0.1)
	outer.Parent = workspace

	local lazer = Instance.new("Part")
	lazer.Name = "TimeLazerCore"
	lazer.Anchored = true
	lazer.CanCollide = false
	lazer.CanTouch = false
	lazer.CanQuery = false
	lazer.Material = Enum.Material.Neon
	lazer.Color = Color3.fromRGB(80, 255, 255)
	lazer.Transparency = 0 -- Full brightness
	lazer.Size = Vector3.new(0.08, 0.08, 0.1)
	lazer.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 255, 255)
	light.Range = 18
	light.Brightness = 8
	light.Parent = lazer

	activeLazerOuter = outer
	activeLazerCore = lazer
	activeLazerLight = light

	local mouse = player:GetMouse()
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {character, outer, lazer}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	lazerConnection = RunService.RenderStepped:Connect(function()
		if not isLazerActive then return end

		local currentTool = character:FindFirstChildWhichIsA("Tool")
		sourceHand = character:FindFirstChild("Time_RightHand") or character:FindFirstChild("RightHand")
		if not currentTool or currentTool.Name ~= "TimeClass" or not sourceHand or humanoid.Health <= 0 then
			stopLazer()
			return
		end

		local origin = sourceHand.Position
		local targetPosition = mouse.Hit.Position
		local aim = targetPosition - origin
		if aim.Magnitude < 0.1 then
			aim = rootPart.CFrame.LookVector
		end

		local result = workspace:Raycast(origin, aim.Unit * LAZER_RANGE, rayParams)
		local endPos = result and result.Position or (origin + aim.Unit * LAZER_RANGE)
		local distance = (endPos - origin).Magnitude
		if distance < 0.1 then
			endPos = origin + aim.Unit * 0.1
			distance = 0.1
		end
		local beamCFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -distance / 2)

		outer.Size = Vector3.new(0.18, 0.18, distance)
		outer.CFrame = beamCFrame
		lazer.Size = Vector3.new(0.08, 0.08, distance + 0.1)
		lazer.CFrame = beamCFrame

		if result and tick() >= nextLazerDamageTime then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum:TakeDamage(LAZER_DAMAGE)
				nextLazerDamageTime = tick() + LAZER_DAMAGE_INTERVAL
			end
		end
	end)
end

-- Function to perform the E Bomb Ability
local function performBomb()
	if isAttacking then return end
	if tick() < nextBombTime then return end

	isAttacking = true
	character:SetAttribute("IsAttacking", true)

	local mouse = player:GetMouse()
	local targetPosition = mouse.Hit.Position

	-- Find the custom steampunk hand
	local sourceHand = character:FindFirstChild("Time_RightHand") or character:FindFirstChild("RightHand")
	if not sourceHand then
		isAttacking = false
		character:SetAttribute("IsAttacking", false)
		return
	end

	-- Find the VFX templates in ReplicatedStorage
	local timeVFX = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("time")
	if not timeVFX then
		warn("DEBUG ERROR: 'VFX/time' folder NOT found in ReplicatedStorage!")
		isAttacking = false 
		character:SetAttribute("IsAttacking", false)
		return
	end

	local impactModelPrefab = timeVFX:FindFirstChild("Model")
	-- We throw the Orb instead of the Part based on user request
	local bombPrefab = timeVFX:FindFirstChild("Orb")
	if not bombPrefab or not impactModelPrefab then
		warn("DEBUG ERROR: Missing 'Orb' or 'Model' inside VFX/time folder!")
		isAttacking = false
		character:SetAttribute("IsAttacking", false)
		return
	end

	nextBombTime = tick() + BOMB_COOLDOWN

	-- 1. Generic Throw Animation (Reusing Lazer pose quickly)
	playLazerTrack(2.5, 0.05)
	
	task.wait(0.1)
	
	-- Refresh target for pinpoint accuracy at the exact mouse cursor location
	targetPosition = player:GetMouse().Hit.Position

	-- 2. Spawn and Throw Bomb
	local bomb = bombPrefab:Clone()
	if bomb:IsA("Model") then
		for _, p in ipairs(bomb:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end
		bomb:PivotTo(sourceHand.CFrame)
	else
		bomb.Anchored = true
		bomb.CanCollide = false
		bomb.CFrame = sourceHand.CFrame
	end
	bomb.Parent = workspace

	local origin = sourceHand.Position
	local distance = (targetPosition - origin).Magnitude
	
	-- Height of the curve depends tightly on distance to feel like a high lob
	local heightBoost = math.clamp(distance * 0.4, 10, 40)
	local controlPoint = origin:Lerp(targetPosition, 0.5) + Vector3.new(0, heightBoost, 0)

	local t = 0
	-- Drastically slow down the throw speed (varies smoothly between 0.8s and 1.8s) 
	local throwDuration = math.clamp(distance / 50, 0.85, 1.8)

	-- Ensure any visual particles/trails on the bomb actually turn on when thrown
	for _, v in ipairs(bomb:GetDescendants()) do
		if v:IsA("ParticleEmitter") or v:IsA("Trail") then
			v.Enabled = true
		end
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		t = t + (dt / throwDuration)
		if t >= 1 then
			t = 1
			connection:Disconnect()
			bomb:Destroy()

			-- 3. Spawn Impact Model and Execute Time Area
			local impact = impactModelPrefab:Clone()
			local nativeRotation = impactModelPrefab:GetPivot().Rotation
			impact:PivotTo(nativeRotation + targetPosition)
			impact.Parent = workspace

			-- MANUAL VFX INTEGRATION ====================================================
			local midGears = {}
			local spinDir = 1
			for _, v in ipairs(impact:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
					v.CanTouch = false
					v.CanQuery = false
					v.Anchored = true
					if string.find(string.upper(v.Name), "MIDGEAR") then
						table.insert(midGears, {part = v, dir = spinDir})
						spinDir = spinDir * -1 -- Opposite rotating interleaved gears
					end
				elseif v:IsA("ParticleEmitter") then
					-- Instantly burst particles in perfect synchronization instead of staggering
					v:Clear()
					v:Emit(15)
				end
			end

			local pulseContainer = impact:FindFirstChild("Script")
			if pulseContainer then
				local pulseParts = {}
				for _, obj in ipairs(pulseContainer:GetDescendants()) do
					if obj:IsA("BasePart") then table.insert(pulseParts, obj) end
				end
				
				task.spawn(function()
					local function setTransparency(value)
						for _, p in ipairs(pulseParts) do p.Transparency = value end
					end
					while impact.Parent do
						for i = 1, 3 do
							if not impact.Parent then break end
							for t = 0, 0.6, 0.1 do
								setTransparency(t)
								task.wait(0.01)
							end
							for t = 0.6, 0, -0.1 do
								setTransparency(t)
								task.wait(0.01)
							end
						end
						
						setTransparency(1)
						-- Idle delay happens AFTER the first synchronized burst
						task.wait(1) 
					end
				end)
			end
			-- =========================================================================

			local dur = 5
			local tickTracker = 0
			-- Rely on the Bounding Box of the model to know the physical limits of the area 
			local impactCFrame, impactSize = impact:GetBoundingBox()
			if impactSize.Magnitude < 1 then impactSize = Vector3.new(15,15,15) end -- Fallback if empty model

			local function tickDamageAndSlow()
				local overlapParams = OverlapParams.new()
				overlapParams.FilterDescendantsInstances = {character, impact}
				overlapParams.FilterType = Enum.RaycastFilterType.Exclude

				local partsInBox = workspace:GetPartBoundsInBox(impactCFrame, impactSize, overlapParams)
				local hitHumanoids = {}

				for _, p in ipairs(partsInBox) do
					local hum = p.Parent and p.Parent:FindFirstChildOfClass("Humanoid")
					if hum and not hitHumanoids[hum] and hum.Health > 0 then
						hitHumanoids[hum] = true
						
						-- Deal Damage
						hum:TakeDamage(5) 

						-- Slow Enemy
						local originalSpeed = hum:GetAttribute("OriginalWalkSpeed") or 16
						if not hum:GetAttribute("OriginalWalkSpeed") then
							hum:SetAttribute("OriginalWalkSpeed", hum.WalkSpeed)
						end
						
						hum.WalkSpeed = originalSpeed * 0.4 -- 60% slow deduction
						hum:SetAttribute("SlowTill", tick() + 0.6)

						-- Automatically restore their speed 0.6s after their last "tick"
						-- This guarantees if they walk out, they regain speed instantly
						task.delay(0.6, function()
							if tick() >= (hum:GetAttribute("SlowTill") or 0) then
								hum.WalkSpeed = hum:GetAttribute("OriginalWalkSpeed") or 16
								hum:SetAttribute("OriginalWalkSpeed", nil)
							end
						end)
					end
				end
			end

			-- Fire initial tick instantly on creation
			tickDamageAndSlow()

			-- Maintain the area actively
			local aoeLoop
			aoeLoop = RunService.Heartbeat:Connect(function(dt2)
				dur = dur - dt2
				tickTracker = tickTracker + dt2
				
				-- Rotate VFX Gears natively on the Z Axis (Flat turntable spin for this particular mesh orientation)
				for _, data in ipairs(midGears) do
					data.part.CFrame = data.part.CFrame * CFrame.Angles(0, 0, math.rad(90) * dt2 * data.dir)
				end

				if tickTracker >= 0.5 then
					tickTracker = 0
					tickDamageAndSlow() -- Tick every 0.5s for 5 full seconds
				end

				if dur <= 0 then
					aoeLoop:Disconnect()
					-- Smooth fade out the model upon finishing
					for _, v in ipairs(impact:GetDescendants()) do
						if v:IsA("BasePart") then
							TweenService:Create(v, TweenInfo.new(0.5), {Transparency = 1}):Play()
						end
					end
					Debris:AddItem(impact, 0.5)
				end
			end)
			
			return
		end

		-- Bezier Curve Math (Aiming smoothly forward along trajectory)
		local l1 = origin:Lerp(controlPoint, t)
		local l2 = controlPoint:Lerp(targetPosition, t)
		local pos = l1:Lerp(l2, t)
		
		-- Calculate the next tiny fraction of the curve to figure out the "look" direction
		local nextT = math.clamp(t + 0.05, 0, 1)
		local n1 = origin:Lerp(controlPoint, nextT)
		local n2 = controlPoint:Lerp(targetPosition, nextT)
		local nextPos = n1:Lerp(n2, nextT)
		
		if (nextPos - pos).Magnitude > 0.05 then
			if bomb:IsA("Model") then
				bomb:PivotTo(CFrame.lookAt(pos, nextPos))
			else
				bomb.CFrame = CFrame.lookAt(pos, nextPos)
			end
		else
			if bomb:IsA("Model") then
				bomb:PivotTo(CFrame.new(pos))
			else
				bomb.CFrame = CFrame.new(pos)
			end
		end
	end)

	-- Explicitly stop throw animation
	task.delay(0.6, function()
		if lazerTrack.IsPlaying and not isLazerActive then
			lazerTrack:Stop(0.15)
		end
	end)

	task.delay(BOMB_CAST_LOCK_TIME, function()
		isAttacking = false
		character:SetAttribute("IsAttacking", false)
	end)
end

local function createSprintGhost()
	character.Archivable = true
	local ghost = character:Clone()
	character.Archivable = false
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("LuaSourceContainer") or desc:IsA("ForceEffect") or desc:IsA("Humanoid") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.Anchored = true
			desc.Material = Enum.Material.Neon
			desc.Transparency = 0.5
			desc.Color = GHOST_COLOR
			TweenService:Create(desc, TweenInfo.new(GHOST_LIFETIME), {Transparency = 1}):Play()
		end
	end
	ghost.Parent = workspace
	Debris:AddItem(ghost, GHOST_LIFETIME)
end

local function performSprint()
	if isAttacking then return end
	if tick() < nextSprintTime then return end

	isAttacking = true
	character:SetAttribute("IsAttacking", true)

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then 
		isAttacking = false
		character:SetAttribute("IsAttacking", false)
		return 
	end

	nextSprintTime = tick() + SPRINT_COOLDOWN

	local originalCollisions = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then 
			originalCollisions[part] = part.CanCollide
			part.CanCollide = false 
		end
	end
	
	local camera = workspace.CurrentCamera
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {FieldOfView = SPRINT_FOV}):Play()
	
	local att = Instance.new("Attachment", rootPart)
	local velocity = Instance.new("LinearVelocity")
	velocity.MaxForce = 10000000 
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Attachment0 = att
	velocity.Parent = rootPart
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(10000000, 0, 10000000) 
	
	local ghostTimer = 0
	local sprintStartTime = tick()
	
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local elapsed = tick() - sprintStartTime
		if elapsed >= SPRINT_DURATION or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		
		local moveDir = humanoid.MoveDirection
		local targetDir = moveDir.Magnitude > 0 and moveDir or rootPart.CFrame.LookVector
		velocity.VectorVelocity = Vector3.new(targetDir.X * SPRINT_SPEED, 0, targetDir.Z * SPRINT_SPEED)
		
		ghostTimer += dt
		if ghostTimer >= 0.05 then 
			createSprintGhost() 
			ghostTimer = 0 
		end
	end)
	
	task.wait(SPRINT_DURATION)
	
	if connection then connection:Disconnect() end
	if velocity and velocity.Parent then velocity:Destroy() end
	if att and att.Parent then att:Destroy() end
	
	for part, state in pairs(originalCollisions) do
		if part and part.Parent then
			part.CanCollide = state
		end
	end
	
	TweenService:Create(camera, TweenInfo.new(0.4), {FieldOfView = NORMAL_FOV}):Play()

	isAttacking = false
	character:SetAttribute("IsAttacking", false)
end

local historyTimer = 0
RunService.Heartbeat:Connect(function(dt)
	if not rootPart or not humanoid then return end
	if character:GetAttribute("IsRewinding") then return end
	
	historyTimer += dt
	if historyTimer >= (1 / REWIND_FPS) then
		historyTimer = 0
		table.insert(positionHistory, 1, {
			cframe = rootPart.CFrame,
			health = humanoid.Health
		})
		if #positionHistory > (REWIND_MAX_SECONDS * REWIND_FPS) then
			table.remove(positionHistory)
		end
	end
end)

local function performRewind()
	if isAttacking then return end
	if tick() < nextRewindTime then return end
	if humanoid.Health <= 0 then return end
	if #positionHistory == 0 then return end

	nextRewindTime = tick() + REWIND_COOLDOWN
	isAttacking = true
	character:SetAttribute("IsAttacking", true)
	character:SetAttribute("IsRewinding", true)

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	rootPart.Anchored = true

	local recallTransparency = {}
	spawnRecallVFX(rootPart.CFrame)
	setRecallCharacterHidden(true, recallTransparency)
	task.wait(RECALL_VANISH_TIME)

	local originalCollisions = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then 
			originalCollisions[part] = part.CanCollide
			part.CanCollide = false 
		end
	end
	
	local camera = workspace.CurrentCamera
	local originalFOV = camera.FieldOfView
	TweenService:Create(camera, TweenInfo.new(0.3), {FieldOfView = 110}):Play()
	
	for i = 1, #positionHistory, REWIND_PLAYBACK_STEP do
		local state = positionHistory[i]
		rootPart.CFrame = state.cframe
		humanoid.Health = state.health

		RunService.Heartbeat:Wait()
	end

	local finalState = positionHistory[#positionHistory]
	if finalState then
		rootPart.CFrame = finalState.cframe
		humanoid.Health = finalState.health
	end

	task.wait(RECALL_EXTRA_HIDDEN_TIME)
	spawnRecallVFX(rootPart.CFrame)
	setRecallCharacterHidden(false, recallTransparency)
	
	TweenService:Create(camera, TweenInfo.new(0.3), {FieldOfView = originalFOV}):Play()
	
	rootPart.Anchored = false
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	for part, state in pairs(originalCollisions) do
		if part and part.Parent then
			part.CanCollide = state
		end
	end
	
	positionHistory = {} 
	character:SetAttribute("IsRewinding", false)

	isAttacking = false
	character:SetAttribute("IsAttacking", false)
end

local function performBlackHoleUltimate()
	if isAttacking then return end
	if tick() < nextBlackHoleTime then return end
	if humanoid.Health <= 0 then return end

	isAttacking = true
	character:SetAttribute("IsAttacking", true)
	character:SetAttribute("IsUltimateActive", true)

	local casterRoot = character:FindFirstChild("HumanoidRootPart")
	if not casterRoot then
		isAttacking = false
		character:SetAttribute("IsAttacking", false)
		character:SetAttribute("IsUltimateActive", false)
		return
	end

	nextBlackHoleTime = tick() + BLACK_HOLE_COOLDOWN

	if timeRunTrack.IsPlaying then
		timeRunTrack:Stop(0)
	end

	local originalCasterWalkSpeed = humanoid.WalkSpeed
	local originalCasterJumpPower = humanoid.JumpPower
	local originalCasterJumpHeight = humanoid.JumpHeight
	local originalCasterAutoRotate = humanoid.AutoRotate
	local originalCasterAnchored = casterRoot.Anchored

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	casterRoot.Anchored = true

	spawnBlackHoleVFX(casterRoot.CFrame)
	playTrackForDuration(blackHoleCastTrack, BLACK_HOLE_DURATION)

	local trappedTargets = {}
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local function releaseTrappedTarget(targetHumanoid, data)
		if data.track then
			data.track:Stop(0.1)
		end

		if targetHumanoid and targetHumanoid.Parent then
			targetHumanoid.AutoRotate = data.autoRotate
			targetHumanoid.WalkSpeed = data.walkSpeed
			targetHumanoid.JumpPower = data.jumpPower
			targetHumanoid.JumpHeight = data.jumpHeight
		end

		if data.root and data.root.Parent then
			data.root.Anchored = data.anchored
		end
	end

	local function trapHumanoid(targetHumanoid)
		if trappedTargets[targetHumanoid] then return end
		if targetHumanoid == humanoid or targetHumanoid.Health <= 0 then return end

		local targetCharacter = targetHumanoid.Parent
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRoot then return end

		local targetAnimator = targetHumanoid:FindFirstChildOfClass("Animator")
		if not targetAnimator then
			targetAnimator = Instance.new("Animator")
			targetAnimator.Parent = targetHumanoid
		end

		local trappedAnim = Instance.new("Animation")
		trappedAnim.AnimationId = BLACK_HOLE_TRAPPED_ANIM_ID
		local trappedTrack = targetAnimator:LoadAnimation(trappedAnim)
		trappedTrack.Priority = Enum.AnimationPriority.Action4
		trappedTrack.Looped = true
		trappedTrack:Play(0.05)

		local direction = targetRoot.Position - casterRoot.Position
		local angle = math.atan2(direction.Z, direction.X)
		if direction.Magnitude < 0.1 then
			angle = math.random() * math.pi * 2
		end

		trappedTargets[targetHumanoid] = {
			root = targetRoot,
			track = trappedTrack,
			angle = angle,
			flipAngle = 0,
			floatHeight = math.clamp(direction.Y, 2, BLACK_HOLE_FLOAT_HEIGHT),
			anchored = targetRoot.Anchored,
			autoRotate = targetHumanoid.AutoRotate,
			walkSpeed = targetHumanoid.WalkSpeed,
			jumpPower = targetHumanoid.JumpPower,
			jumpHeight = targetHumanoid.JumpHeight,
		}

		targetHumanoid.WalkSpeed = 0
		targetHumanoid.JumpPower = 0
		targetHumanoid.JumpHeight = 0
		targetHumanoid.AutoRotate = false
		targetRoot.Anchored = true
	end

	local elapsed = 0
	local blackHoleConnection
	blackHoleConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local center = casterRoot.Position

		local nearbyParts = workspace:GetPartBoundsInRadius(center, BLACK_HOLE_RADIUS, overlapParams)
		for _, part in ipairs(nearbyParts) do
			local targetModel = part:FindFirstAncestorOfClass("Model")
			local targetHumanoid = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
			if targetHumanoid then
				trapHumanoid(targetHumanoid)
			end
		end

		for targetHumanoid, data in pairs(trappedTargets) do
			if targetHumanoid.Health <= 0 or not data.root.Parent then
				releaseTrappedTarget(targetHumanoid, data)
				trappedTargets[targetHumanoid] = nil
			else
				data.flipAngle += BLACK_HOLE_FLIP_SPEED * dt

				local currentOffset = data.root.Position - center
				local flatOffset = Vector3.new(currentOffset.X, 0, currentOffset.Z)
				local pullDirection = flatOffset.Magnitude > 0.1 and flatOffset.Unit or Vector3.new(math.cos(data.angle), 0, math.sin(data.angle))
				local pullPosition = center + (pullDirection * BLACK_HOLE_PULL_DISTANCE) + Vector3.new(0, data.floatHeight, 0)
				local alpha = math.clamp(dt * BLACK_HOLE_PULL_SPEED, 0, 1)
				local targetPosition = data.root.Position:Lerp(pullPosition, alpha)

				data.root.CFrame =
					CFrame.lookAt(targetPosition, center)
					* CFrame.Angles(data.flipAngle, 0, data.flipAngle * 0.65)
			end
		end

		if elapsed >= BLACK_HOLE_DURATION then
			blackHoleConnection:Disconnect()
		end
	end)

	task.wait(BLACK_HOLE_DURATION)
	if blackHoleConnection and blackHoleConnection.Connected then
		blackHoleConnection:Disconnect()
	end

	for targetHumanoid, data in pairs(trappedTargets) do
		releaseTrappedTarget(targetHumanoid, data)
	end

	if blackHoleCastTrack.IsPlaying then
		blackHoleCastTrack:Stop(0.1)
	end

	humanoid.WalkSpeed = originalCasterWalkSpeed
	humanoid.JumpPower = originalCasterJumpPower
	humanoid.JumpHeight = originalCasterJumpHeight
	humanoid.AutoRotate = originalCasterAutoRotate
	casterRoot.Anchored = originalCasterAnchored

	character:SetAttribute("IsUltimateActive", false)
	isAttacking = false
	character:SetAttribute("IsAttacking", false)
end

-- Function to handle the tool setup (connecting existing and future)
local function handleToolMonitor()
	print("DEBUG: handleToolMonitor active")
	
	-- Check for the tool initially if it's already there
	local initialTool = character:FindFirstChild("TimeClass")
	if initialTool then
		print("DEBUG: TimeClass tool found already in character!")
		initialTool:SetAttribute("AmmoDisplay", "INF")
		startTimeRunAnim()
		setupToolVFX(initialTool)
	end

	-- Listen for future additions
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "TimeClass" then
			print("DEBUG: TimeClass tool ADDED to character!")
			task.wait(0.1)
			child:SetAttribute("AmmoDisplay", "INF")
			startTimeRunAnim()
			setupToolVFX(child)
		end
	end)
end

task.spawn(handleToolMonitor)

character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") and child.Name == "TimeClass" then
		stopLazer()
		stopTimeRunAnim()

		-- Restore the REAL arm
		local rightHand = character:FindFirstChild("RightHand")
		local rightLower = character:FindFirstChild("RightLowerArm")
		local rightUpper = character:FindFirstChild("RightUpperArm")

		if rightHand then rightHand.Transparency = 0 end
		if rightLower then rightLower.Transparency = 0 end
		if rightUpper then rightUpper.Transparency = 0 end

		-- Restore decals
		for _, v in ipairs(character:GetDescendants()) do
			if v:IsA("Decal") and (v.Parent == rightHand or v.Parent == rightLower or v.Parent == rightUpper) then
				v.Transparency = 0
			end
		end

		-- Cleanup clones
		local customArmParts = {"RightHand", "RightLowerArm", "RightUpperArm"}
		for _, partName in ipairs(customArmParts) do
			local clone = character:FindFirstChild("Time_" .. partName)
			if clone then clone:Destroy() end
		end

		local vfx = rightHand and rightHand:FindFirstChild("TimeHandVFX")
		if vfx then vfx:Destroy() end
	end
end)

-- We will listen for input only when the "TimeClass" tool is equipped
UserInputService.InputBegan:Connect(function(input,gameProcessed)
	if gameProcessed then return end

	-- Verify the TimeClass tool is equipped
	local currentTool = character:FindFirstChildWhichIsA("Tool")
	if not currentTool or currentTool.Name ~= "TimeClass" then return end

	-- Block inputs while already attacking/using an ability
	if isAttacking then return end

	-- Mapping inputs to abilities
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startLazer()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		performRewind()
	elseif input.KeyCode == Enum.KeyCode.E then
		performBomb()
	elseif input.KeyCode == Enum.KeyCode.F then
		performSprint()
	elseif input.KeyCode == Enum.KeyCode.Q then
		performBlackHoleUltimate()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopLazer()
	end
end)
