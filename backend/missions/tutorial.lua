-- Tutorial Mission: Basic Bridge Operations
-- This mission introduces players to the basic systems of the Celestial Bridge Simulator

log("Loading Tutorial Mission...")

-- Mission setup
startMission("Tutorial: Bridge Operations", "Learn the basic operations of your starship bridge")

-- Set initial objectives
setObjective("Tutorial: Bridge Operations", "Complete system startup sequence")
setObjective("Tutorial: Bridge Operations", "Test helm controls and navigation")
setObjective("Tutorial: Bridge Operations", "Practice tactical systems")
setObjective("Tutorial: Bridge Operations", "Send a test communication")
setObjective("Tutorial: Bridge Operations", "Manage power systems")

-- Get player ship reference
local playerShip = getPlayerShip()
if not playerShip then
    log("Error: No player ship found!")
    return
end

log("Player ship: " .. playerShip.Name)

-- Mission state tracking
local missionState = {
    startup_complete = false,
    helm_tested = false,
    weapons_tested = false,
    comm_tested = false,
    power_tested = false,
    tutorial_complete = false
}

-- Create tutorial waypoint
local waypointId = spawnStation("Tutorial Waypoint", 2000, 0, 500)
log("Created tutorial waypoint: " .. waypointId)

-- Create some asteroids for practice
for i = 1, 5 do
    local x = random(-5000, 5000)
    local y = random(-1000, 1000)
    local z = random(-5000, 5000)
    spawnAsteroid(x, y, z)
end

-- Create a target ship for tactical practice
local targetShipId = spawnShip("Training Target", 3000, 0, 0)
local targetShip = getObject(targetShipId)
if targetShip then
    targetShip.Health = 50
    targetShip.MaxHealth = 50
    targetShip.Shield = 25
    targetShip.MaxShield = 25
    log("Created training target ship")
end

-- Tutorial message system
local function sendTutorialMessage(message, priority)
    priority = priority or 2
    sendMessage("player_ship", "[TUTORIAL] " .. message, priority)
end

-- Welcome message
sendTutorialMessage("Welcome to the Celestial Bridge Simulator Tutorial!", 1)
sendTutorialMessage("This mission will guide you through basic bridge operations.", 2)
sendTutorialMessage("Follow the objectives to learn each station's functions.", 2)

-- Startup sequence check
createTrigger("startup_check", "timer", function()
    if not missionState.startup_complete then
        if playerShip.Power >= playerShip.MaxPower * 0.9 then
            missionState.startup_complete = true
            completeObjective("Tutorial: Bridge Operations", 0)
            sendTutorialMessage("Excellent! Ship startup sequence completed.", 1)
            sendTutorialMessage("Next: Test your helm controls by moving toward the waypoint.", 2)
            return true
        end
    end
    return false
end, function()
    log("Startup sequence completed")
end)

-- Helm control check
createTrigger("helm_check", "timer", function()
    if missionState.startup_complete and not missionState.helm_tested then
        local waypoint = getObject(waypointId)
        if waypoint then
            local distance = getDistance(playerShip.ID, waypointId)
            if distance < 1000 then
                missionState.helm_tested = true
                completeObjective("Tutorial: Bridge Operations", 1)
                sendTutorialMessage("Great navigation! Helm systems are working properly.", 1)
                sendTutorialMessage("Next: Test tactical systems by targeting the training ship.", 2)
                return true
            end
        end
    end
    return false
end, function()
    log("Helm controls tested successfully")
end)

-- Weapons test check
createTrigger("weapons_check", "timer", function()
    if missionState.helm_tested and not missionState.weapons_tested then
        local target = getObject(targetShipId)
        if target and target.Health < target.MaxHealth then
            missionState.weapons_tested = true
            completeObjective("Tutorial: Bridge Operations", 2)
            sendTutorialMessage("Good shooting! Tactical systems operational.", 1)
            sendTutorialMessage("Next: Send a test message using communications.", 2)
            return true
        end
    end
    return false
end, function()
    log("Weapons systems tested")
end)

-- Communication test (simulated by checking if comm system is active)
createTrigger("comm_check", "timer", function()
    if missionState.weapons_tested and not missionState.comm_tested then
        -- Simulate comm test by checking if frequency has been changed
        if playerShip.Properties and playerShip.Properties.comm_frequency then
            missionState.comm_tested = true
            completeObjective("Tutorial: Bridge Operations", 3)
            sendTutorialMessage("Communication systems tested successfully!", 1)
            sendTutorialMessage("Final test: Adjust power allocation in engineering.", 2)
            return true
        end
    end
    return false
end, function()
    log("Communications tested")
end)

-- Power management test
createTrigger("power_check", "timer", function()
    if missionState.comm_tested and not missionState.power_tested then
        -- Check if any system efficiency has been modified
        local systems = playerShip.Systems
        if systems then
            for name, system in pairs(systems) do
                if system.Efficiency ~= 1.0 then
                    missionState.power_tested = true
                    completeObjective("Tutorial: Bridge Operations", 4)
                    sendTutorialMessage("Excellent! Power management systems verified.", 1)
                    sendTutorialMessage("Tutorial complete! You're ready for real missions.", 1)
                    return true
                end
            end
        end
    end
    return false
end, function()
    log("Power management tested")
end)

-- Mission completion check
createTrigger("mission_complete", "timer", function()
    if missionState.startup_complete and missionState.helm_tested and
       missionState.weapons_tested and missionState.comm_tested and
       missionState.power_tested and not missionState.tutorial_complete then
        return true
    end
    return false
end, function()
    missionState.tutorial_complete = true
    completeMission("Tutorial: Bridge Operations")
    sendTutorialMessage("TUTORIAL COMPLETE!", 1)
    sendTutorialMessage("All bridge systems are operational and crew is ready for duty.", 2)
    sendTutorialMessage("Good luck on your missions, Captain!", 2)
    setAlertLevel(0)
    log("Tutorial mission completed successfully")
end)

-- Periodic guidance messages
local guidanceTimer = 0
createTrigger("guidance", "timer", function()
    guidanceTimer = guidanceTimer + 1
    if guidanceTimer % 300 == 0 then -- Every 5 minutes
        if not missionState.startup_complete then
            sendTutorialMessage("Tip: Use the Captain's console to activate ship systems.", 3)
        elseif not missionState.helm_tested then
            sendTutorialMessage("Tip: Use helm controls to navigate to the waypoint.", 3)
        elseif not missionState.weapons_tested then
            sendTutorialMessage("Tip: Use tactical station to target and fire at the training ship.", 3)
        elseif not missionState.comm_tested then
            sendTutorialMessage("Tip: Try changing communication frequency or sending a message.", 3)
        elseif not missionState.power_tested then
            sendTutorialMessage("Tip: Use engineering station to adjust power allocation.", 3)
        end
    end
    return false
end, function() end)

-- Emergency situations for advanced practice
createTrigger("emergency_drill", "timer", function()
    if missionState.helm_tested and random(1, 1000) < 2 then -- 0.2% chance per check
        return true
    end
    return false
end, function()
    setAlertLevel(2)
    sendTutorialMessage("ALERT: Simulated emergency drill activated!", 1)
    sendTutorialMessage("Practice your emergency procedures.", 2)

    -- Return to normal after 30 seconds
    wait(30)
    setAlertLevel(0)
    sendTutorialMessage("Emergency drill complete. Well done!", 2)
end)

-- Cleanup function when mission ends
createTrigger("cleanup", "timer", function()
    return missionState.tutorial_complete
end, function()
    -- Remove tutorial objects
    destroyObject(waypointId)
    if targetShipId then
        destroyObject(targetShipId)
    end
    log("Tutorial cleanup completed")
end)

log("Tutorial mission loaded and ready!")
sendTutorialMessage("Tutorial mission initialized. Begin with ship startup sequence.", 2)
