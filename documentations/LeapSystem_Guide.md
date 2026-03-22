# Leap System with Animations & Floor Breaking

## Overview
A complete leap system that allows players to perform animated leaps from anywhere and break normal floors/ground upon impact.

## Features

### 1. Animated Leaps
- **Leap Animation**: Plays a jump animation when leaping
- **Trail Effects**: Creates visual trails during leaps
- **Camera-Based Direction**: Leaps forward relative to camera view
- **Cooldown System**: 3-second cooldown between leaps

### 2. Floor Breaking Mechanics
- **Break ANY Floor**: Can break normal floors, not just special platforms
- **Temporary Holes**: Creates temporary non-collidable areas (10-second respawn)
- **Visual Effects**: Particle explosions and color changes
- **Points System**: Awards points for breaking floors

### 3. Visual Feedback
- **UI Display**: Cooldown timer and readiness indicator
- **Break Indicators**: Floating text when breaking floors
- **Particle Effects**: Breaking animations with particles
- **Trail Effects**: Visual trails during leaps

## How to Use

### Basic Usage
1. **Press E** to leap forward
2. **Land on any floor** to break it
3. **Watch cooldown** in bottom-center UI

### Key Features
- **Leap from anywhere**: No special platforms needed
- **Break normal floors**: Works on any horizontal surface
- **Temporary destruction**: Floors respawn after 10 seconds
- **Visual feedback**: Animations, particles, and UI updates

## Configuration

### LeapDatas.lua Settings
```lua
-- Leap mechanics
LEAP_FORCE = Vector3.new(0, 100, 50)  -- Forward/upward force
LEAP_DURATION = 0.5                    -- Leap duration in seconds
LEAP_COOLDOWN = 3                      -- Cooldown in seconds

-- Floor breaking
PLATFORM_BREAK_POINTS = 10             -- Points awarded
PLATFORM_RESPAWN_TIME = 10             -- Floor respawn time

-- Animations
LEAP_ANIMATION_ID = "rbxassetid://148840371"  -- Jump animation
LEAP_TRAIL_LIFETIME = 0.5                     -- Trail duration
LEAP_TRAIL_WIDTH = 0.5                        -- Trail width

-- Keybinds
LEAP_KEY = Enum.KeyCode.E              -- Primary leap key
LEAP_KEY_SECONDARY = Enum.KeyCode.ButtonR2  -- Controller support
```

## File Structure

```
src/
├── ServerScriptService/ServerSource/Server/LeapService/
│   ├── init.lua                    # Main service
│   └── Components/Others/
│       └── LeapTester.lua          # Test system
├── ReplicatedStorage/ClientSource/Client/LeapController/
│   └── init.lua                    # Client controller
└── ReplicatedStorage/SharedSource/Datas/
    └── LeapDatas.lua               # Configuration
```

## Testing

The system includes a built-in tester:
1. Creates a 50x50 test floor
2. Adds visual grid markers
3. Places break zone indicator
4. Automatically cleans up after 60 seconds

## Integration

### With Other Systems
- **ProfileService**: Awards points for breaking floors
- **UI Systems**: Displays cooldown and break notifications
- **Animation Systems**: Plays leap animations

### Customization
1. Modify `LeapDatas.lua` for different settings
2. Change animation IDs for custom animations
3. Adjust force values for different leap styles
4. Modify respawn times for floor regeneration

## Troubleshooting

### Common Issues
1. **No leap animation**: Check animation ID in LeapDatas
2. **Floors not breaking**: Ensure part is horizontal (Y normal > 0.7)
3. **No UI display**: Check PlayerGui for LeapUI
4. **Cooldown not working**: Verify os.time() synchronization

### Debug Commands
```lua
-- Check leap cooldown
LeapService:GetLeapCooldown(player)

-- Force leap (for testing)
LeapService:PerformLeap(player, direction)

-- Test floor breaking
LeapService:BreakPlatform(player, part, position)
```

## Performance Notes
- Uses efficient raycasting for floor detection
- Particle effects auto-cleanup
- Temporary floor modification (not destruction)
- Minimal UI updates (once per frame)

## Future Enhancements
1. **Different leap types** (charged leaps, directional leaps)
2. **Break patterns** (circular, radial, shaped breaks)
3. **Material-based breaking** (different effects per material)
4. **Combo system** (multiple breaks in succession)
5. **Environmental effects** (screen shake, sound effects)