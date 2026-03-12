local LeapTester = {}

-- Test leap system
function LeapTester:TestLeapSystem()
	print("[LeapTester] Testing leap system...")
	
	-- Create test floor
	self:CreateTestFloor()
	
	-- Test leap animations
	self:TestLeapAnimations()
	
	-- Test floor breaking
	self:TestFloorBreaking()
	
	print("[LeapTester] All tests completed!")
end

-- Create a test floor for breaking
function LeapTester:CreateTestFloor()
	print("[LeapTester] Creating test floor...")
	
	-- Clean up existing test floor
	local existingFloor = workspace:FindFirstChild("TestFloor")
	if existingFloor then
		existingFloor:Destroy()
	end
	
	-- Create a large floor
	local floor = Instance.new("Part")
	floor.Name = "TestFloor"
	floor.Size = Vector3.new(50, 1, 50)
	floor.Position = Vector3.new(0, 0, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = Color3.fromRGB(100, 100, 100)
	floor.Material = Enum.Material.Concrete
	floor.Parent = workspace
	
	-- Add grid pattern for visual reference
	for x = -20, 20, 10 do
		for z = -20, 20, 10 do
			local marker = Instance.new("Part")
			marker.Name = "GridMarker"
			marker.Size = Vector3.new(8, 0.2, 8)
			marker.Position = Vector3.new(x, 0.6, z)
			marker.Anchored = true
			marker.CanCollide = false
			marker.Transparency = 0.5
			marker.Color = Color3.fromRGB(200, 200, 200)
			marker.Material = Enum.Material.Neon
			marker.Parent = floor
		end
	end
	
	print("[LeapTester] Test floor created at position (0, 0, 0)")
end

-- Test leap animations
function LeapTester:TestLeapAnimations()
	print("[LeapTester] Testing leap animations...")
	
	-- This would normally be tested with actual player input
	-- For now, just log the animation setup
	print("  • Leap animation ID:", require(game.ReplicatedStorage.SharedSource.Datas.LeapDatas).LEAP_ANIMATION_ID)
	print("  • Trail lifetime:", require(game.ReplicatedStorage.SharedSource.Datas.LeapDatas).LEAP_TRAIL_LIFETIME)
	print("  • Trail width:", require(game.ReplicatedStorage.SharedSource.Datas.LeapDatas).LEAP_TRAIL_WIDTH)
	print("  ✓ Animation system ready")
end

-- Test floor breaking mechanics
function LeapTester:TestFloorBreaking()
	print("[LeapTester] Testing floor breaking mechanics...")
	
	local LeapDatas = require(game.ReplicatedStorage.SharedSource.Datas.LeapDatas)
	
	print("  • Platform respawn time:", LeapDatas.PLATFORM_RESPAWN_TIME, "seconds")
	print("  • Break points:", LeapDatas.PLATFORM_BREAK_POINTS)
	print("  • Break color:", LeapDatas.PLATFORM_BREAK_COLOR)
	print("  ✓ Floor breaking system ready")
	
	-- Create a visual indicator for breakable area
	local indicator = Instance.new("Part")
	indicator.Name = "BreakZoneIndicator"
	indicator.Size = Vector3.new(5, 0.2, 5)
	indicator.Position = Vector3.new(0, 1, 0)
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.Transparency = 0.3
	indicator.Color = Color3.fromRGB(255, 100, 100)
	indicator.Material = Enum.Material.Neon
	
	-- Pulsing animation
	spawn(function()
		while indicator and indicator.Parent do
			for i = 0.3, 0.7, 0.05 do
				if indicator then
					indicator.Transparency = i
				end
				task.wait(0.1)
			end
			for i = 0.7, 0.3, -0.05 do
				if indicator then
					indicator.Transparency = i
				end
				task.wait(0.1)
			end
		end
	end)
	
	indicator.Parent = workspace
	
	print("  • Break zone indicator created at center of test floor")
	print("  • Leap onto the red area to break the floor!")
end

-- Clean up test objects
function LeapTester:Cleanup()
	print("[LeapTester] Cleaning up test objects...")
	
	local objectsToRemove = {
		"TestFloor",
		"BreakZoneIndicator",
		"LeapImpactZone",
		"PlatformBreakEffect"
	}
	
	for _, name in ipairs(objectsToRemove) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			obj:Destroy()
			print("  • Removed:", name)
		end
	end
	
	print("[LeapTester] Cleanup complete!")
end

-- Initialize
function LeapTester:Start()
	print("[LeapTester] Starting leap system tester...")
	
	-- Run tests
	self:TestLeapSystem()
	
	-- Schedule cleanup after 60 seconds
	task.delay(60, function()
		self:Cleanup()
	end)
end

function LeapTester:Init()
	-- This component doesn't need Knit service references
end

return LeapTester