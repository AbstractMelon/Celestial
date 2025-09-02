# Celestial Bridge Simulator - Lua API Documentation

## Overview

The Celestial Lua API provides comprehensive scripting capabilities for mission design and universe control. Mission scripters can create dynamic scenarios, spawn objects, handle events, and interact with all aspects of the game universe through Lua scripts.

## Getting Started

### Basic Mission Structure

```lua
-- Mission header
log("Loading My Mission...")

-- Initialize mission
startMission("Mission Name", "Mission description for the crew")

-- Set objectives
setObjective("Mission Name", "Primary objective description")
setObjective("Mission Name", "Secondary objective description")

-- Get player ship reference
local playerShip = getPlayerShip()
if not playerShip then
    log("Error: No player ship found!")
    return
end

-- Mission logic here...

log("Mission loaded successfully!")
```

### Mission State Management

```lua
-- Track mission progress
local missionState = {
    phase = 1,
    objectives_complete = 0,
    total_objectives = 3,
    enemy_ships_destroyed = 0
}

-- Update mission state
local function updateMissionPhase()
    if missionState.objectives_complete >= missionState.total_objectives then
        completeMission("Mission Name")
        log("Mission completed successfully!")
    end
end
```

## Core API Functions

### Universe Management

#### Object Creation

##### createObject(type, name, x, y, z, [additional_params])
Creates a new object in the universe.

**Parameters:**
- `type` (string): Object type ("ship", "planet", "station", "asteroid", "mine", "nebula")
- `name` (string): Display name for the object
- `x, y, z` (number): Position coordinates
- `additional_params` (number, optional): Type-specific parameters

**Returns:** Object ID (string) or nil on failure

```lua
-- Create a planet
local planetId = createObject("planet", "Kepler-442b", -10000, 0, 5000, 2000)

-- Create a space station
local stationId = createObject("station", "Deep Space Nine", 5000, 0, 0)

-- Create an asteroid
local asteroidId = createObject("asteroid", "Asteroid Alpha", 1000, 500, -2000)

-- Create a mine with custom damage
local mineId = createObject("mine", "Space Mine", 2000, 0, 1000, 750)
```

##### Specialized Spawn Functions

```lua
-- Spawn specific object types with better control
local shipId = spawnShip("Enemy Cruiser", 3000, 0, 0)
local planetId = spawnPlanet("Vulcan", -5000, 0, 2000, 1500)
local stationId = spawnStation("Starbase Alpha", 8000, 1000, 0)
local asteroidId = spawnAsteroid(-2000, 500, 3000)
local mineId = spawnMine(1500, 0, -1000, 500)
```

#### Object Manipulation

##### getObject(objectId)
Retrieves an object by its ID.

```lua
local ship = getObject("player_ship")
if ship then
    log("Player ship health: " .. ship.Health)
    log("Player ship position: " .. ship.Position.X .. ", " .. ship.Position.Y .. ", " .. ship.Position.Z)
end
```

##### modifyObject(objectId, property, value)
Modifies properties of an existing object.

```lua
-- Change object position
modifyObject("enemy_ship_1", "position", {1000, 0, 500})

-- Modify health
modifyObject("player_ship", "health", 75)

-- Adjust shields
modifyObject("station_alpha", "shield", 50)

-- Change velocity
modifyObject("asteroid_1", "velocity", {10, 0, -5})
```

##### moveObject(objectId, x, y, z)
Moves an object to a new position.

```lua
-- Move enemy ship to new coordinates
moveObject("enemy_ship_1", 2000, 500, -1000)

-- Move asteroid
moveObject("asteroid_field_1", -5000, 0, 3000)
```

##### destroyObject(objectId)
Removes an object from the universe.

```lua
-- Destroy a damaged ship
destroyObject("enemy_cruiser_2")

-- Remove completed waypoint
destroyObject("nav_waypoint_alpha")
```

### Player Ship Access

##### getPlayerShip()
Returns the player's ship object.

```lua
local playerShip = getPlayerShip()
if playerShip then
    log("Ship name: " .. playerShip.Name)
    log("Crew count: " .. playerShip.Crew)
    log("Current power: " .. playerShip.Power .. "/" .. playerShip.MaxPower)
    
    -- Access ship systems
    local engines = playerShip.Systems["engines"]
    if engines then
        log("Engine efficiency: " .. (engines.Efficiency * 100) .. "%")
    end
end
```

### Spatial Functions

##### getDistance(objectId1, objectId2)
Calculates distance between two objects.

```lua
local distance = getDistance("player_ship", "enemy_ship_1")
if distance < 1000 then
    log("Enemy ship approaching!")
    setAlertLevel(2)
end
```

##### getObjectsInRange(x, y, z, radius)
Returns array of object IDs within specified range.

```lua
-- Find all objects near a position
local nearbyObjects = getObjectsInRange(0, 0, 0, 5000)
for i, objectId in ipairs(nearbyObjects) do
    log("Nearby object: " .. objectId)
end

-- Check for enemies near player
local playerShip = getPlayerShip()
if playerShip then
    local threats = getObjectsInRange(
        playerShip.Position.X, 
        playerShip.Position.Y, 
        playerShip.Position.Z, 
        2000
    )
    if #threats > 1 then -- More than just the player ship
        log("Multiple contacts detected!")
    end
end
```

### Effects and Events

##### createExplosion(x, y, z, force)
Creates an explosion at specified coordinates.

```lua
-- Create explosion at enemy ship location
local enemy = getObject("enemy_ship_1")
if enemy and enemy.Health <= 0 then
    createExplosion(enemy.Position.X, enemy.Position.Y, enemy.Position.Z, 1000)
end

-- Create mine detonation
createExplosion(1000, 0, 500, 750)
```

##### createEffect(type, x, y, z, duration)
Creates a visual effect.

```lua
-- Create nebula effect
local nebulaEffect = createEffect("nebula_glow", -3000, 0, 2000, 60)

-- Create wormhole effect
local wormholeEffect = createEffect("wormhole", 5000, 0, 0, 30)

-- Create ion storm
local stormEffect = createEffect("ion_storm", 0, 1000, -2000, 45)
```

### Communication System

##### sendMessage(targetId, message, priority)
Sends a message to a specific target.

```lua
-- Send message to player ship
sendMessage("player_ship", "Incoming transmission from Starfleet Command", 1)

-- Send warning message
sendMessage("player_ship", "WARNING: Enemy ships detected in sector 7", 2)

-- Send mission briefing
sendMessage("player_ship", "Your mission is to escort the convoy to Starbase 12", 2)
```

##### broadcastMessage(message, priority)
Sends a broadcast message to all ships.

```lua
-- Emergency broadcast
broadcastMessage("All ships, this is Starfleet Command. Red Alert status is now in effect.", 1)

-- General announcement
broadcastMessage("Navigation hazard detected in sector 5. All ships use caution.", 3)
```

### Universe Control

##### setAlertLevel(level)
Sets the ship's alert condition.

```lua
-- Green alert (normal operations)
setAlertLevel(0)

-- Yellow alert (increased readiness)
setAlertLevel(1)

-- Red alert (battle stations)
setAlertLevel(2)

-- Maximum alert (critical situation)
setAlertLevel(3)
```

##### setTimeAcceleration(factor)
Controls time acceleration.

```lua
-- Normal time
setTimeAcceleration(1.0)

-- Half speed for precision work
setTimeAcceleration(0.5)

-- Double speed for travel
setTimeAcceleration(2.0)

-- Maximum acceleration
setTimeAcceleration(10.0)
```

## Trigger System

### Creating Triggers

##### createTrigger(triggerId, triggerType, condition, action)
Creates an event trigger that executes when conditions are met.

```lua
-- Proximity trigger
createTrigger("enemy_proximity", "proximity", function()
    local distance = getDistance("player_ship", "enemy_ship_1")
    return distance < 2000
end, function()
    log("Enemy ship detected!")
    setAlertLevel(2)
    sendMessage("player_ship", "Enemy vessel approaching!", 1)
end)

-- Timer trigger
local missionTimer = 0
createTrigger("mission_timer", "timer", function()
    missionTimer = missionTimer + 1
    return missionTimer >= 300 -- 5 minutes
end, function()
    log("Mission time limit reached!")
    sendMessage("player_ship", "Time is running out, Captain!", 1)
end)

-- Health trigger
createTrigger("player_damage", "health", function()
    local playerShip = getPlayerShip()
    return playerShip and playerShip.Health < 50
end, function()
    log("Player ship severely damaged!")
    sendMessage("player_ship", "Hull breach detected! Damage control teams respond!", 1)
    setAlertLevel(3)
end)
```

##### removeTrigger(triggerId)
Removes an active trigger.

```lua
-- Remove trigger when no longer needed
removeTrigger("enemy_proximity")
```

##### checkTrigger(triggerId)
Manually checks if a trigger is active.

```lua
if checkTrigger("mission_timer") then
    log("Mission timer trigger is active")
end
```

## Mission Management

### Mission Control

##### startMission(name, description)
Initializes a new mission.

```lua
startMission("The Klingon Gambit", "Investigate unusual Klingon activity in the Neutral Zone")
```

##### completeMission(name)
Marks a mission as completed.

```lua
-- Complete mission when all objectives done
if allObjectivesComplete then
    completeMission("The Klingon Gambit")
    broadcastMessage("Mission accomplished! Well done, crew.", 1)
end
```

##### setObjective(missionName, objective)
Adds an objective to the mission.

```lua
setObjective("The Klingon Gambit", "Reach the Neutral Zone border")
setObjective("The Klingon Gambit", "Scan for Klingon ships")
setObjective("The Klingon Gambit", "Report findings to Starfleet")
```

##### completeObjective(missionName, objectiveIndex)
Marks a specific objective as completed.

```lua
-- Complete first objective (index 0)
completeObjective("The Klingon Gambit", 0)
sendMessage("player_ship", "Objective complete: Neutral Zone reached", 2)
```

## Utility Functions

### Logging and Debug

##### log(message)
Outputs a message to the server log.

```lua
log("Mission script starting...")
log("Player ship position: " .. tostring(playerShip.Position.X))
log("Enemy count: " .. enemyCount)
```

##### wait(seconds)
Pauses script execution (use sparingly).

```lua
-- Wait 5 seconds before next action
wait(5)
log("5 seconds have passed")
```

### Mathematics

##### random(min, max)
Generates a random number between min and max.

```lua
-- Random position for asteroid
local x = random(-10000, 10000)
local y = random(-1000, 1000)
local z = random(-10000, 10000)
spawnAsteroid(x, y, z)

-- Random damage amount
local damage = random(10, 50)
modifyObject("player_ship", "health", playerShip.Health - damage)
```

##### Vector3(x, y, z)
Creates a 3D vector object.

```lua
-- Create position vector
local position = Vector3(1000, 0, -500)

-- Use in object modification
modifyObject("ship_1", "position", position)

-- Vector operations
local playerPos = playerShip.Position
local targetPos = Vector3(2000, 0, 0)
local distance = playerPos:Distance(targetPos)
```

## Advanced Examples

### Dynamic Enemy Spawning

```lua
local waveCount = 0
local enemiesPerWave = 3
local maxWaves = 5

createTrigger("spawn_wave", "timer", function()
    -- Check if previous wave is defeated
    local enemies = 0
    for i = 1, enemiesPerWave do
        local enemyId = "enemy_wave_" .. waveCount .. "_" .. i
        if getObject(enemyId) then
            enemies = enemies + 1
        end
    end
    
    return enemies == 0 and waveCount < maxWaves
end, function()
    waveCount = waveCount + 1
    log("Spawning enemy wave " .. waveCount)
    
    for i = 1, enemiesPerWave do
        local angle = (i * 360 / enemiesPerWave) * math.pi / 180
        local distance = 5000
        local x = math.cos(angle) * distance
        local z = math.sin(angle) * distance
        
        local enemyId = spawnShip("Enemy Fighter " .. i, x, 0, z)
        -- Configure enemy ship properties
        modifyObject(enemyId, "health", 75)
        modifyObject(enemyId, "shield", 50)
    end
    
    sendMessage("player_ship", "Enemy wave " .. waveCount .. " incoming!", 1)
    setAlertLevel(2)
end)
```

### Escort Mission

```lua
local convoy = {}
local convoySize = 3
local destination = Vector3(10000, 0, 5000)

-- Spawn convoy ships
for i = 1, convoySize do
    local shipId = spawnShip("Freighter " .. i, i * 200, 0, -500)
    table.insert(convoy, shipId)
    
    -- Set convoy ship properties
    modifyObject(shipId, "health", 100)
    modifyObject(shipId, "max_health", 100)
end

-- Monitor convoy health
createTrigger("convoy_check", "timer", function()
    local survivingShips = 0
    for _, shipId in ipairs(convoy) do
        local ship = getObject(shipId)
        if ship and ship.Health > 0 then
            survivingShips = survivingShips + 1
        end
    end
    
    if survivingShips == 0 then
        log("All convoy ships destroyed - mission failed!")
        sendMessage("player_ship", "Mission failed: Convoy destroyed", 1)
        return true
    end
    
    -- Check if convoy reached destination
    for _, shipId in ipairs(convoy) do
        local ship = getObject(shipId)
        if ship then
            local distance = getDistance(shipId, "destination_marker")
            if distance < 500 then
                log("Convoy ship reached destination!")
                completeObjective("Escort Mission", 0)
            end
        end
    end
    
    return false
end, function()
    -- Mission failure cleanup
end)
```

### Exploration Mission

```lua
local scanPoints = {
    {name = "Nebula Alpha", pos = Vector3(-5000, 0, 3000), scanned = false},
    {name = "Asteroid Field Beta", pos = Vector3(3000, 500, -2000), scanned = false},
    {name = "Derelict Station", pos = Vector3(7000, -1000, 1000), scanned = false}
}

-- Create scan markers
for i, point in ipairs(scanPoints) do
    local markerId = createObject("station", point.name .. " Marker", 
                                 point.pos.X, point.pos.Y, point.pos.Z)
    point.markerId = markerId
end

-- Check for scanning
createTrigger("scan_check", "timer", function()
    local playerShip = getPlayerShip()
    if not playerShip then return false end
    
    for i, point in ipairs(scanPoints) do
        if not point.scanned then
            local distance = getDistance("player_ship", point.markerId)
            if distance < 1000 then
                point.scanned = true
                log("Scanned: " .. point.name)
                sendMessage("player_ship", "Scan complete: " .. point.name, 2)
                completeObjective("Exploration Mission", i - 1)
            end
        end
    end
    
    -- Check if all points scanned
    local allScanned = true
    for _, point in ipairs(scanPoints) do
        if not point.scanned then
            allScanned = false
            break
        end
    end
    
    return allScanned
end, function()
    log("All scan points completed!")
    completeMission("Exploration Mission")
    sendMessage("player_ship", "Exploration complete! Return to base.", 1)
end)
```

## Best Practices

### Performance Optimization

1. **Limit Trigger Frequency**: Use timer-based triggers sparingly
2. **Cache Object References**: Store frequently accessed objects
3. **Efficient Distance Checks**: Use squared distance when possible
4. **Cleanup Resources**: Remove unused triggers and objects

```lua
-- Good: Cache player ship reference
local playerShip = getPlayerShip()

-- Good: Use efficient distance checking
local function isNearPlayer(objectId, threshold)
    if not playerShip then return false end
    
    local obj = getObject(objectId)
    if not obj then return false end
    
    local dx = obj.Position.X - playerShip.Position.X
    local dy = obj.Position.Y - playerShip.Position.Y
    local dz = obj.Position.Z - playerShip.Position.Z
    local distanceSquared = dx*dx + dy*dy + dz*dz
    
    return distanceSquared < (threshold * threshold)
end
```

### Error Handling

```lua
-- Always check if objects exist
local function safeGetObject(objectId)
    local obj = getObject(objectId)
    if not obj then
        log("Warning: Object not found: " .. objectId)
        return nil
    end
    return obj
end

-- Validate player ship before use
local function getValidPlayerShip()
    local ship = getPlayerShip()
    if not ship then
        log("Error: No player ship available!")
        return nil
    end
    return ship
end
```

### Mission Structure

1. **Modular Design**: Break missions into phases
2. **Clear Objectives**: Use descriptive objective text
3. **Progressive Difficulty**: Gradually increase challenge
4. **Player Feedback**: Provide regular status updates

```lua
-- Good mission structure
local MissionPhases = {
    BRIEFING = 1,
    TRAVEL = 2,
    COMBAT = 3,
    RESOLUTION = 4
}

local currentPhase = MissionPhases.BRIEFING

local function advancePhase()
    currentPhase = currentPhase + 1
    log("Mission phase advanced to: " .. currentPhase)
end
```

## Debugging and Testing

### Debug Functions

```lua
-- Debug: Print all nearby objects
local function debugNearbyObjects()
    local playerShip = getPlayerShip()
    if playerShip then
        local objects = getObjectsInRange(
            playerShip.Position.X, 
            playerShip.Position.Y, 
            playerShip.Position.Z, 
            10000
        )
        
        log("=== Nearby Objects Debug ===")
        for _, objId in ipairs(objects) do
            local obj = getObject(objId)
            if obj then
                log(objId .. ": " .. obj.Name .. " at (" .. 
                    obj.Position.X .. ", " .. obj.Position.Y .. ", " .. obj.Position.Z .. ")")
            end
        end
        log("=== End Debug ===")
    end
end

-- Debug: Mission state
local function debugMissionState()
    log("=== Mission State Debug ===")
    log("Current phase: " .. tostring(currentPhase))
    log("Objectives complete: " .. objectivesComplete)
    log("=== End Debug ===")
end
```

### Testing Missions

1. **Test with Debug Mode**: Run server with `-debug` flag
2. **Validate Object Creation**: Check all spawned objects exist
3. **Test Edge Cases**: What happens if player ship is destroyed?
4. **Performance Testing**: Monitor with many objects/triggers

## API Reference Summary

### Object Management
- `createObject(type, name, x, y, z, [params])` - Create universe object
- `spawnShip(name, x, y, z)` - Create ship
- `spawnPlanet(name, x, y, z, radius)` - Create planet  
- `spawnStation(name, x, y, z)` - Create station
- `spawnAsteroid(x, y, z)` - Create asteroid
- `spawnMine(x, y, z, damage)` - Create mine
- `getObject(id)` - Get object by ID
- `modifyObject(id, property, value)` - Modify object
- `moveObject(id, x, y, z)` - Move object
- `destroyObject(id)` - Remove object

### Spatial Functions
- `getPlayerShip()` - Get player ship object
- `getDistance(id1, id2)` - Distance between objects
- `getObjectsInRange(x, y, z, radius)` - Find nearby objects

### Effects
- `createExplosion(x, y, z, force)` - Create explosion
- `createEffect(type, x, y, z, duration)` - Create visual effect

### Communication
- `sendMessage(target, message, priority)` - Send message
- `broadcastMessage(message, priority)` - Broadcast to all

### Control
- `setAlertLevel(level)` - Set alert condition (0-3)
- `setTimeAcceleration(factor)` - Control time speed

### Triggers
- `createTrigger(id, type, condition, action)` - Create event trigger
- `removeTrigger(id)` - Remove trigger
- `checkTrigger(id)` - Check trigger status

### Missions
- `startMission(name, description)` - Initialize mission
- `completeMission(name)` - Complete mission
- `setObjective(mission, objective)` - Add objective
- `completeObjective(mission, index)` - Complete objective

### Utilities
- `log(message)` - Debug logging
- `wait(seconds)` - Pause execution
- `random(min, max)` - Random number
- `Vector3(x, y, z)` - Create 3D vector

This comprehensive API enables the creation of rich, interactive missions that fully utilize the Celestial Bridge Simulator's universe system.