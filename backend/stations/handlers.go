package stations

import (
	"celestial-backend/networking"
	"celestial-backend/universe"
	"celestial-backend/utils"
	"encoding/json"
)

func (sm *StationManager) handleHelmInput(inputData *networking.InputEventData) {
	playerShip := sm.universe.GetPlayerShip()
	if playerShip == nil {
		return
	}

	switch inputData.Action {
	case "throttle":
		if throttle, ok := inputData.Value.(float64); ok {
			playerShip.EngineThrust = throttle * playerShip.MaxThrust
		}

	case "thrust_vector":
		var helmData networking.HelmInputData
		if err := json.Unmarshal(inputData.Context["helm_data"].([]byte), &helmData); err == nil {
			thrustVector := helmData.Thrust.Normalize().Mul(playerShip.EngineThrust)
			playerShip.ApplyForce(thrustVector)
		}

	case "desired_heading":
		if heading, ok := inputData.Value.(float64); ok {
			playerShip.SetAutoPilot("heading", heading)
		}

	case "autopilot_mode":
		if mode, ok := inputData.Value.(string); ok {
			switch mode {
			case "manual":
				playerShip.DisableAutoPilot()
			case "station_keeping":
				playerShip.SetAutoPilot("station_keeping", nil)
			case "position":
				if pos, exists := inputData.Context["target_position"]; exists {
					if position, ok := pos.(utils.Vector3); ok {
						playerShip.SetAutoPilot("position", position)
					}
				}
			}
		}

	case "warp_factor":
		if factor, ok := inputData.Value.(float64); ok {
			sm.universe.SetTimeAcceleration(factor)
		}

	case "navigation_plot":
		if waypoints, ok := inputData.Value.([]utils.Vector3); ok {
			if len(waypoints) > 0 {
				playerShip.SetAutoPilot("position", waypoints[0])
			}
		}
	}
}

func (sm *StationManager) handleTacticalInput(inputData *networking.InputEventData) {
	playerShip := sm.universe.GetPlayerShip()
	if playerShip == nil {
		return
	}

	switch inputData.Action {
	case "fire_weapon":
		var tacticalData networking.TacticalInputData
		if err := json.Unmarshal(inputData.Context["tactical_data"].([]byte), &tacticalData); err == nil {
			weaponID := "phaser_array_1"
			if tacticalData.WeaponType == "torpedo" {
				weaponID = "torpedo_launcher_1"
			}

			var targetPos *utils.Vector3
			if tacticalData.TargetPosition.Length() > 0 {
				targetPos = &tacticalData.TargetPosition
			}

			sm.universe.FireWeapon(playerShip.ID, weaponID, tacticalData.TargetID, targetPos)
		}

	case "target_lock":
		if targetID, ok := inputData.Value.(string); ok {
			playerShip.Properties["current_target"] = targetID
		}

	case "shield_power":
		if power, ok := inputData.Value.(float64); ok {
			shieldSystem := playerShip.Systems["shields"]
			shieldSystem.Efficiency = power
			playerShip.Systems["shields"] = shieldSystem
		}

	case "weapon_power":
		if power, ok := inputData.Value.(float64); ok {
			weaponSystem := playerShip.Systems["weapons"]
			weaponSystem.Efficiency = power
			playerShip.Systems["weapons"] = weaponSystem
		}

	case "raise_shields":
		if raise, ok := inputData.Value.(bool); ok {
			shieldSystem := playerShip.Systems["shields"]
			shieldSystem.IsOnline = raise
			playerShip.Systems["shields"] = shieldSystem
		}

	case "tactical_scan":
		if targetID, ok := inputData.Value.(string); ok {
			target := sm.universe.GetObject(targetID)
			if target != nil && playerShip.SensorRange >= playerShip.GetDistance(target) {
				playerShip.Properties["scan_result"] = target
			}
		}
	}
}

func (sm *StationManager) handleCommunicationInput(inputData *networking.InputEventData) {
	playerShip := sm.universe.GetPlayerShip()
	if playerShip == nil {
		return
	}

	switch inputData.Action {
	case "send_message":
		var commData networking.CommunicationInputData
		if err := json.Unmarshal(inputData.Context["comm_data"].([]byte), &commData); err == nil {
			message := map[string]interface{}{
				"from":      playerShip.ID,
				"to":        commData.TargetShipID,
				"message":   commData.Message,
				"frequency": commData.Frequency,
				"priority":  commData.Priority,
				"timestamp": inputData.Timestamp,
			}

			if commData.TargetShipID == "broadcast" {
				playerShip.Properties["last_broadcast"] = message
			} else {
				if messages, exists := playerShip.Properties["outgoing_messages"]; exists {
					if msgList, ok := messages.([]interface{}); ok {
						msgList = append(msgList, message)
						playerShip.Properties["outgoing_messages"] = msgList
					}
				} else {
					playerShip.Properties["outgoing_messages"] = []interface{}{message}
				}
			}
		}

	case "set_frequency":
		if frequency, ok := inputData.Value.(float64); ok {
			playerShip.Properties["comm_frequency"] = frequency
		}

	case "emergency_broadcast":
		if broadcast, ok := inputData.Value.(bool); ok && broadcast {
			emergencyMsg := map[string]interface{}{
				"from":      playerShip.ID,
				"type":      "emergency",
				"message":   "Mayday! Mayday! This is " + playerShip.Name + " requesting immediate assistance!",
				"priority":  1,
				"timestamp": inputData.Timestamp,
			}
			playerShip.Properties["emergency_broadcast"] = emergencyMsg
		}

	case "comm_auto_response":
		if enabled, ok := inputData.Value.(bool); ok {
			playerShip.Properties["auto_response_enabled"] = enabled
		}

	case "comm_log_clear":
		if clear, ok := inputData.Value.(bool); ok && clear {
			playerShip.Properties["comm_log"] = []interface{}{}
		}
	}
}

func (sm *StationManager) handleLogisticsInput(inputData *networking.InputEventData) {
	playerShip := sm.universe.GetPlayerShip()
	if playerShip == nil {
		return
	}

	switch inputData.Action {
	case "power_allocation":
		var logData networking.LogisticsInputData
		if err := json.Unmarshal(inputData.Context["logistics_data"].([]byte), &logData); err == nil {
			for systemName, allocation := range logData.PowerAllocation {
				if system, exists := playerShip.Systems[systemName]; exists {
					system.Efficiency = allocation
					playerShip.Systems[systemName] = system
				}
			}
		}

	case "repair_system":
		if systemName, ok := inputData.Value.(string); ok {
			if system, exists := playerShip.Systems[systemName]; exists {
				repairAmount := 10.0
				system.Health = utils.Clamp(system.Health+repairAmount, 0, system.MaxHealth)
				if system.Health > 50 && !system.IsOnline {
					system.IsOnline = true
				}
				playerShip.Systems[systemName] = system
			}
		}

	case "crew_assignment":
		var logData networking.LogisticsInputData
		if err := json.Unmarshal(inputData.Context["logistics_data"].([]byte), &logData); err == nil {
			playerShip.Properties["crew_assignments"] = logData.CrewAssignment
		}

	case "system_priority":
		var logData networking.LogisticsInputData
		if err := json.Unmarshal(inputData.Context["logistics_data"].([]byte), &logData); err == nil {
			for systemName, priority := range logData.SystemPriority {
				if system, exists := playerShip.Systems[systemName]; exists {
					system.Priority = priority
					playerShip.Systems[systemName] = system
				}
			}
		}

	case "damage_control":
		if enable, ok := inputData.Value.(bool); ok {
			playerShip.Properties["damage_control_active"] = enable
		}

	case "resource_transfer":
		if transferData, ok := inputData.Context["transfer"]; ok {
			playerShip.Properties["last_transfer"] = transferData
		}
	}
}

func (sm *StationManager) handleCaptainInput(inputData *networking.InputEventData) {
	playerShip := sm.universe.GetPlayerShip()
	if playerShip == nil {
		return
	}

	switch inputData.Action {
	case "alert_level":
		if level, ok := inputData.Value.(int); ok {
			sm.universe.SetAlertLevel(level)
			playerShip.Properties["alert_condition"] = level
		}

	case "general_quarters":
		if quarters, ok := inputData.Value.(bool); ok && quarters {
			sm.universe.SetAlertLevel(3)
			playerShip.Properties["battle_stations"] = true
		}

	case "emergency_power":
		if emergency, ok := inputData.Value.(bool); ok {
			for systemName, system := range playerShip.Systems {
				if system.IsCritical {
					system.Efficiency = 1.2
					playerShip.Systems[systemName] = system
				}
			}
			playerShip.Properties["emergency_power"] = emergency
		}

	case "ship_startup":
		if startup, ok := inputData.Value.(bool); ok && startup {
			for systemName, system := range playerShip.Systems {
				system.IsOnline = true
				system.Health = system.MaxHealth
				playerShip.Systems[systemName] = system
			}
			playerShip.Power = playerShip.MaxPower
			playerShip.Shield = playerShip.MaxShield
		}

	case "camera_control":
		if camera, ok := inputData.Value.(string); ok {
			playerShip.Properties["viewscreen_camera"] = camera
		}

	case "ship_lockdown":
		if lockdown, ok := inputData.Value.(bool); ok {
			playerShip.Properties["lockdown_active"] = lockdown
		}

	case "captain_override":
		if override, ok := inputData.Context["override_data"]; ok {
			playerShip.Properties["captain_override"] = override
		}
	}
}

func (sm *StationManager) handleGameMasterInput(inputData *networking.InputEventData) {
	switch inputData.Action {
	case "spawn_object":
		var gmCmd networking.GameMasterCommand
		if err := json.Unmarshal(inputData.Context["gm_command"].([]byte), &gmCmd); err == nil {
			if gmCmd.ObjectDef != nil {
				obj := &universe.Object{
					ID:           gmCmd.ObjectDef.ID,
					Type:         universe.ObjectType(gmCmd.ObjectDef.Type),
					Name:         gmCmd.ObjectDef.Name,
					Position:     gmCmd.ObjectDef.Position,
					Velocity:     gmCmd.ObjectDef.Velocity,
					Rotation:     gmCmd.ObjectDef.Rotation,
					Scale:        gmCmd.ObjectDef.Scale,
					Health:       gmCmd.ObjectDef.Health,
					MaxHealth:    gmCmd.ObjectDef.MaxHealth,
					Shield:       gmCmd.ObjectDef.Shield,
					MaxShield:    gmCmd.ObjectDef.MaxShield,
					Power:        gmCmd.ObjectDef.Power,
					MaxPower:     gmCmd.ObjectDef.MaxPower,
					Mass:         gmCmd.ObjectDef.Mass,
					Radius:       gmCmd.ObjectDef.Radius,
					IsPlayerShip: gmCmd.ObjectDef.IsPlayerShip,
					Properties:   gmCmd.ObjectDef.Properties,
				}
				sm.universe.AddObject(obj)
			}
		}

	case "modify_object":
		var gmCmd networking.GameMasterCommand
		if err := json.Unmarshal(inputData.Context["gm_command"].([]byte), &gmCmd); err == nil {
			if obj := sm.universe.GetObject(gmCmd.Target); obj != nil {
				if gmCmd.Position != nil {
					obj.Position = *gmCmd.Position
				}
				if value, ok := gmCmd.Value.(map[string]interface{}); ok {
					for key, val := range value {
						obj.Properties[key] = val
					}
				}
			}
		}

	case "delete_object":
		if objectID, ok := inputData.Value.(string); ok {
			sm.universe.RemoveObject(objectID)
		}

	case "universe_control":
		var gmCmd networking.GameMasterCommand
		if err := json.Unmarshal(inputData.Context["gm_command"].([]byte), &gmCmd); err == nil {
			switch gmCmd.Command {
			case "time_acceleration":
				if factor, ok := gmCmd.Value.(float64); ok {
					sm.universe.SetTimeAcceleration(factor)
				}
			case "alert_level":
				if level, ok := gmCmd.Value.(float64); ok {
					sm.universe.SetAlertLevel(int(level))
				}
			case "reset_universe":
				playerShip := sm.universe.GetPlayerShip()
				if playerShip != nil {
					playerPos := playerShip.Position
					sm.universe = universe.NewUniverse()
					newPlayerShip := universe.NewPlayerShip("player_ship", "USS Celestial", playerPos)
					sm.universe.AddShip(newPlayerShip)
					sm.universe.PlayerShipID = newPlayerShip.ID
				}
			}
		}

	case "mission_intervention":
		var gmCmd networking.GameMasterCommand
		if err := json.Unmarshal(inputData.Context["gm_command"].([]byte), &gmCmd); err == nil {
			sm.universe.GetPlayerShip().Properties["gm_intervention"] = gmCmd
		}
	}
}

func (sm *StationManager) filterHelmUpdate(fullState *networking.UniverseState) *networking.StateUpdateData {
	filteredObjects := make([]networking.UniverseObject, 0)

	for _, obj := range fullState.Objects {
		if obj.IsPlayerShip {
			filteredObjects = append(filteredObjects, obj)
		} else if obj.Type == networking.ObjectTypePlanet || obj.Type == networking.ObjectTypeStation {
			filteredObjects = append(filteredObjects, obj)
		}
	}

	return &networking.StateUpdateData{
		Objects: filteredObjects,
		Meta: map[string]interface{}{
			"time_acceleration": fullState.TimeAcceleration,
			"navigation_data":   true,
		},
	}
}

func (sm *StationManager) filterTacticalUpdate(fullState *networking.UniverseState) *networking.StateUpdateData {
	filteredObjects := make([]networking.UniverseObject, 0)
	filteredEffects := make([]networking.VisualEffect, 0)

	for _, obj := range fullState.Objects {
		if obj.Type == networking.ObjectTypeShip ||
			obj.Type == networking.ObjectTypeTorpedo ||
			obj.Type == networking.ObjectTypeMine {
			filteredObjects = append(filteredObjects, obj)
		}
	}

	for _, effect := range fullState.Effects {
		if effect.Type == "phaser_beam" ||
			effect.Type == "torpedo_trail" ||
			effect.Type == "explosion" {
			filteredEffects = append(filteredEffects, effect)
		}
	}

	return &networking.StateUpdateData{
		Objects: filteredObjects,
		Effects: filteredEffects,
		Meta: map[string]interface{}{
			"alert_level":   fullState.AlertLevel,
			"tactical_data": true,
		},
	}
}

func (sm *StationManager) filterCommunicationUpdate(fullState *networking.UniverseState) *networking.StateUpdateData {
	filteredObjects := make([]networking.UniverseObject, 0)

	for _, obj := range fullState.Objects {
		if obj.Type == networking.ObjectTypeShip || obj.Type == networking.ObjectTypeStation {
			commObj := obj
			commObj.Velocity = utils.Vector3{}
			commObj.Health = 0
			commObj.MaxHealth = 0
			commObj.Shield = 0
			commObj.MaxShield = 0
			filteredObjects = append(filteredObjects, commObj)
		}
	}

	return &networking.StateUpdateData{
		Objects: filteredObjects,
		Meta: map[string]interface{}{
			"communication_data": true,
			"alert_level":        fullState.AlertLevel,
		},
	}
}

func (sm *StationManager) filterLogisticsUpdate(fullState *networking.UniverseState) *networking.StateUpdateData {
	filteredObjects := make([]networking.UniverseObject, 0)

	for _, obj := range fullState.Objects {
		if obj.IsPlayerShip {
			filteredObjects = append(filteredObjects, obj)
			break
		}
	}

	return &networking.StateUpdateData{
		Objects: filteredObjects,
		Meta: map[string]interface{}{
			"logistics_data": true,
			"power_grid":     true,
			"damage_report":  true,
		},
	}
}

func (sm *StationManager) filterCaptainUpdate(fullState *networking.UniverseState) *networking.StateUpdateData {
	return &networking.StateUpdateData{
		Full: fullState,
		Meta: map[string]interface{}{
			"captain_view": true,
			"alert_level":  fullState.AlertLevel,
			"ship_status":  true,
		},
	}
}

func (sm *StationManager) filterGameMasterUpdate(fullState *networking.UniverseState) *networking.StateUpdateData {
	return &networking.StateUpdateData{
		Full: fullState,
		Meta: map[string]interface{}{
			"gamemaster_view": true,
			"admin_data":      true,
			"debug_info":      true,
		},
	}
}
