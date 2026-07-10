-- Leap System Configuration Data
local LeapDatas = {}

-- Leap mechanics
LeapDatas.LEAP_FORCE = Vector3.new(0, 100, 50) -- Forward and upward force
LeapDatas.LEAP_DURATION = 0.5 -- seconds
LeapDatas.LEAP_COOLDOWN = 3 -- seconds

-- Animation settings
LeapDatas.LEAP_ANIMATION_ID = "rbxassetid://148840371" -- Generic jump animation
LeapDatas.LEAP_TRAIL_LIFETIME = 0.5
LeapDatas.LEAP_TRAIL_WIDTH = 0.5

-- Platform breaking
LeapDatas.PLATFORM_BREAK_POINTS = 10
LeapDatas.PLATFORM_BREAK_FORCE = 500
LeapDatas.PLATFORM_RESPAWN_TIME = 10 -- seconds (if implementing respawn)

-- Visual effects
LeapDatas.LEAP_TRAIL_COLOR = Color3.fromRGB(100, 200, 255)
LeapDatas.PLATFORM_BREAK_COLOR = Color3.fromRGB(255, 100, 100)

-- Input keybinds
LeapDatas.LEAP_KEY = Enum.KeyCode.E
LeapDatas.LEAP_KEY_SECONDARY = Enum.KeyCode.ButtonR2 -- For controllers

-- UI settings
LeapDatas.COOLDOWN_DISPLAY_COLOR = Color3.fromRGB(255, 100, 100)
LeapDatas.READY_DISPLAY_COLOR = Color3.fromRGB(100, 255, 100)

-- Sound IDs (Roblox sound assets)
LeapDatas.SOUND_LEAP = "rbxassetid://9119658379" -- Example leap sound
LeapDatas.SOUND_PLATFORM_BREAK = "rbxassetid://9119658380" -- Example break sound

-- Particle effects
LeapDatas.PARTICLE_LEAP_TRAIL = "rbxassetid://245790492" -- Example trail particle
LeapDatas.PARTICLE_PLATFORM_BREAK = "rbxassetid://245790493" -- Example break particle

return LeapDatas