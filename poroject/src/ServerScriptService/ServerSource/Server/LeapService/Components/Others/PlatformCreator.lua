-- Platform Creator Component for LeapService
-- Creates breakable platforms for testing the leap system

local PlatformCreator = {}

-- Services
local Workspace = game:GetService("Workspace")

-- Create a grid of breakable platforms
function PlatformCreator:CreateTestPlatforms()
	print("[PlatformCreator] Creating test platforms...")
	
	-- Clear existing test platforms
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "TestBreakablePlatform" then
			child:Destroy()
		end
	end
	
	-- Create a 3x3 grid of platforms
	local platformSize = Vector3.new(10, 1, 10)
	local startPosition = Vector3.new(0, 5, 20)
	local spacing = 15
	
	for x = 0, 2 do
		for z = 0, 2 do
			local platform = Instance.new("Part")
			platform.Name = "TestBreakablePlatform"
			platform.Size = platformSize
			platform.Position = startPosition + Vector3.new(x * spacing, 0, z * spacing)
			platform.Anchored = true
			platform.CanCollide = true
			platform.Material = Enum.Material.Plastic
			platform.Color = Color3.fromRGB(200, 100, 100) -- Reddish color for breakable
			
			-- Mark as breakable
			platform:SetAttribute("BreakablePlatform", true)
			
			-- Add visual indicator
			local surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Adornee = platform
			surfaceGui.Face = Enum.NormalId.Top
			surfaceGui.AlwaysOnTop = true
			surfaceGui.PixelsPerStud = 20
			
			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = "BREAKABLE"
			textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.Parent = surfaceGui
			
			surfaceGui.Parent = platform
			platform.Parent = Workspace
			
			print("  Created platform at:", platform.Position)
		end
	end
	
	print("[PlatformCreator] Created 9 test platforms!")
	print("[PlatformCreator] Platforms are marked as breakable and will shatter when leaped on")
end

-- Create a single platform at specific position
function PlatformCreator:CreatePlatform(position, size)
	local platform = Instance.new("Part")
	platform.Name = "BreakablePlatform"
	platform.Size = size or Vector3.new(10, 1, 10)
	platform.Position = position
	platform.Anchored = true
	platform.CanCollide = true
	platform.Material = Enum.Material.Plastic
	platform.Color = Color3.fromRGB(200, 100, 100)
	
	-- Mark as breakable
	platform:SetAttribute("BreakablePlatform", true)
	
	-- Add visual indicator
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Adornee = platform
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.AlwaysOnTop = true
	surfaceGui.PixelsPerStud = 20
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "BREAK ME!"
	textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = surfaceGui
	
	surfaceGui.Parent = platform
	platform.Parent = Workspace
	
	return platform
end

-- Initialize
function PlatformCreator.Start()
	print("[PlatformCreator] Component started")
end

function PlatformCreator.Init()
	print("[PlatformCreator] Component initialized")
end

return PlatformCreator