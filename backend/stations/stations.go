package stations

import (
	"celestial-backend/networking"
	"celestial-backend/universe"
	"sync"
	"time"
)

type StationManager struct {
	stations      map[networking.StationType]*StationData
	universe      *universe.Universe
	inputHandlers map[networking.StationType]func(*networking.InputEventData)
	updateFilters map[networking.StationType]func(*networking.UniverseState) *networking.StateUpdateData
	mutex         sync.RWMutex
}

type StationData struct {
	Type         networking.StationType `json:"type"`
	Name         string                 `json:"name"`
	Description  string                 `json:"description"`
	Permissions  []string               `json:"permissions"`
	InputMapping map[string]string      `json:"input_mapping"`
	LastUpdate   time.Time              `json:"last_update"`
	IsActive     bool                   `json:"is_active"`
}

func NewStationManager(u *universe.Universe) *StationManager {
	sm := &StationManager{
		stations:      make(map[networking.StationType]*StationData),
		universe:      u,
		inputHandlers: make(map[networking.StationType]func(*networking.InputEventData)),
		updateFilters: make(map[networking.StationType]func(*networking.UniverseState) *networking.StateUpdateData),
	}

	sm.initializeStations()
	sm.setupInputHandlers()
	sm.setupUpdateFilters()

	return sm
}

func (sm *StationManager) initializeStations() {
	stations := []StationData{
		{
			Type:        networking.StationHelm,
			Name:        "Helm Control",
			Description: "Ship navigation, movement, and autopilot systems",
			Permissions: []string{"navigation", "autopilot", "engines", "time_acceleration"},
			InputMapping: map[string]string{
				"throttle":        "engine_throttle",
				"rudder":          "ship_rudder",
				"pitch":           "ship_pitch",
				"roll":            "ship_roll",
				"autopilot_mode":  "autopilot_control",
				"warp_factor":     "time_acceleration",
				"desired_heading": "navigation_heading",
			},
			IsActive: true,
		},
		{
			Type:        networking.StationTactical,
			Name:        "Tactical Systems",
			Description: "Weapons, shields, and combat operations",
			Permissions: []string{"weapons", "shields", "targeting", "tactical_sensors"},
			InputMapping: map[string]string{
				"weapon_type":  "weapon_selection",
				"target_id":    "target_lock",
				"fire_command": "weapon_fire",
				"shield_power": "shield_allocation",
				"weapon_power": "weapon_allocation",
				"torpedo_type": "torpedo_selection",
			},
			IsActive: true,
		},
		{
			Type:        networking.StationCommunication,
			Name:        "Communications",
			Description: "Ship-to-ship communications and message handling",
			Permissions: []string{"communications", "messages", "alerts", "broadcasts"},
			InputMapping: map[string]string{
				"frequency":      "comm_frequency",
				"message":        "comm_message",
				"target_ship_id": "comm_target",
				"broadcast_type": "comm_broadcast",
				"priority":       "comm_priority",
				"auto_response":  "comm_auto_response",
			},
			IsActive: true,
		},
		{
			Type:        networking.StationLogistics,
			Name:        "Engineering & Logistics",
			Description: "Power management, repairs, and resource allocation",
			Permissions: []string{"power_management", "repairs", "crew_management", "systems"},
			InputMapping: map[string]string{
				"power_allocation": "power_grid",
				"repair_priority":  "repair_queue",
				"crew_assignment":  "crew_stations",
				"system_priority":  "system_priorities",
			},
			IsActive: true,
		},
		{
			Type:        networking.StationCaptain,
			Name:        "Captain's Chair",
			Description: "Emergency controls and ship-wide systems",
			Permissions: []string{"emergency", "startup_sequence", "cameras", "ship_wide_controls"},
			InputMapping: map[string]string{
				"alert_level":      "ship_alert",
				"emergency_power":  "emergency_systems",
				"startup_sequence": "ship_startup",
				"camera_selection": "viewscreen_camera",
				"general_quarters": "battle_stations",
			},
			IsActive: true,
		},
		{
			Type:        networking.StationGameMaster,
			Name:        "Game Master Console",
			Description: "Mission control and universe administration",
			Permissions: []string{"admin", "spawn_objects", "mission_control", "override_all"},
			InputMapping: map[string]string{
				"spawn_object":     "gm_spawn",
				"modify_object":    "gm_modify",
				"mission_load":     "gm_mission",
				"universe_control": "gm_universe",
				"player_assist":    "gm_assist",
			},
			IsActive: true,
		},
	}

	for _, station := range stations {
		sm.stations[station.Type] = &station
	}
}

func (sm *StationManager) setupInputHandlers() {
	sm.inputHandlers[networking.StationHelm] = sm.handleHelmInput
	sm.inputHandlers[networking.StationTactical] = sm.handleTacticalInput
	sm.inputHandlers[networking.StationCommunication] = sm.handleCommunicationInput
	sm.inputHandlers[networking.StationLogistics] = sm.handleLogisticsInput
	sm.inputHandlers[networking.StationCaptain] = sm.handleCaptainInput
	sm.inputHandlers[networking.StationGameMaster] = sm.handleGameMasterInput
}

func (sm *StationManager) setupUpdateFilters() {
	sm.updateFilters[networking.StationHelm] = sm.filterHelmUpdate
	sm.updateFilters[networking.StationTactical] = sm.filterTacticalUpdate
	sm.updateFilters[networking.StationCommunication] = sm.filterCommunicationUpdate
	sm.updateFilters[networking.StationLogistics] = sm.filterLogisticsUpdate
	sm.updateFilters[networking.StationCaptain] = sm.filterCaptainUpdate
	sm.updateFilters[networking.StationGameMaster] = sm.filterGameMasterUpdate
}

func (sm *StationManager) HandleInput(station networking.StationType, inputData *networking.InputEventData) bool {
	sm.mutex.RLock()
	stationData := sm.stations[station]
	handler := sm.inputHandlers[station]
	sm.mutex.RUnlock()

	if stationData == nil || !stationData.IsActive || handler == nil {
		return false
	}

	if !sm.hasPermission(station, inputData.Action) {
		return false
	}

	handler(inputData)
	stationData.LastUpdate = time.Now()
	return true
}

func (sm *StationManager) FilterUpdate(station networking.StationType, fullState *networking.UniverseState) *networking.StateUpdateData {
	sm.mutex.RLock()
	filter := sm.updateFilters[station]
	sm.mutex.RUnlock()

	if filter == nil {
		return &networking.StateUpdateData{Full: fullState}
	}

	return filter(fullState)
}

func (sm *StationManager) hasPermission(station networking.StationType, action string) bool {
	stationData := sm.stations[station]
	if stationData == nil {
		return false
	}

	for _, permission := range stationData.Permissions {
		if permission == action || permission == "override_all" {
			return true
		}
	}
	return false
}

func (sm *StationManager) GetStationData(station networking.StationType) *StationData {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()
	return sm.stations[station]
}

func (sm *StationManager) SetStationActive(station networking.StationType, active bool) {
	sm.mutex.Lock()
	defer sm.mutex.Unlock()

	if stationData := sm.stations[station]; stationData != nil {
		stationData.IsActive = active
	}
}

func (sm *StationManager) GetAllStations() map[networking.StationType]*StationData {
	sm.mutex.RLock()
	defer sm.mutex.RUnlock()

	result := make(map[networking.StationType]*StationData)
	for k, v := range sm.stations {
		result[k] = v
	}
	return result
}

func (sm *StationManager) ValidateInput(station networking.StationType, action string, value interface{}) bool {
	stationData := sm.GetStationData(station)
	if stationData == nil || !stationData.IsActive {
		return false
	}

	if !sm.hasPermission(station, action) {
		return false
	}

	switch station {
	case networking.StationHelm:
		return sm.validateHelmInput(action, value)
	case networking.StationTactical:
		return sm.validateTacticalInput(action, value)
	case networking.StationCommunication:
		return sm.validateCommunicationInput(action, value)
	case networking.StationLogistics:
		return sm.validateLogisticsInput(action, value)
	case networking.StationCaptain:
		return sm.validateCaptainInput(action, value)
	case networking.StationGameMaster:
		return sm.validateGameMasterInput(action, value)
	}

	return false
}

func (sm *StationManager) validateHelmInput(action string, value interface{}) bool {
	switch action {
	case "throttle", "rudder", "pitch", "roll":
		if v, ok := value.(float64); ok {
			return v >= -1.0 && v <= 1.0
		}
	case "warp_factor":
		if v, ok := value.(float64); ok {
			return v >= 0.1 && v <= 10.0
		}
	case "desired_heading", "desired_pitch":
		if v, ok := value.(float64); ok {
			return v >= -180.0 && v <= 180.0
		}
	case "autopilot_mode":
		if v, ok := value.(string); ok {
			validModes := []string{"manual", "position", "heading", "follow", "station_keeping"}
			for _, mode := range validModes {
				if v == mode {
					return true
				}
			}
		}
	}
	return false
}

func (sm *StationManager) validateTacticalInput(action string, value interface{}) bool {
	switch action {
	case "weapon_type":
		if v, ok := value.(string); ok {
			validTypes := []string{"phaser", "torpedo", "mine"}
			for _, wType := range validTypes {
				if v == wType {
					return true
				}
			}
		}
	case "shield_power", "weapon_power":
		if v, ok := value.(float64); ok {
			return v >= 0.0 && v <= 1.0
		}
	case "fire_command":
		_, ok := value.(bool)
		return ok
	case "target_id":
		_, ok := value.(string)
		return ok
	}
	return false
}

func (sm *StationManager) validateCommunicationInput(action string, value interface{}) bool {
	switch action {
	case "frequency":
		if v, ok := value.(float64); ok {
			return v >= 1.0 && v <= 999.9
		}
	case "message", "target_ship_id", "broadcast_type":
		_, ok := value.(string)
		return ok
	case "priority":
		if v, ok := value.(int); ok {
			return v >= 1 && v <= 5
		}
	case "auto_response":
		_, ok := value.(bool)
		return ok
	}
	return false
}

func (sm *StationManager) validateLogisticsInput(action string, value interface{}) bool {
	switch action {
	case "power_allocation":
		if v, ok := value.(map[string]float64); ok {
			total := 0.0
			for _, allocation := range v {
				if allocation < 0.0 || allocation > 1.0 {
					return false
				}
				total += allocation
			}
			return total <= 1.0
		}
	case "repair_priority":
		if v, ok := value.([]string); ok {
			return len(v) <= 10
		}
	case "crew_assignment":
		_, ok := value.(map[string]string)
		return ok
	case "system_priority":
		if v, ok := value.(map[string]int); ok {
			for _, priority := range v {
				if priority < 1 || priority > 10 {
					return false
				}
			}
			return true
		}
	}
	return false
}

func (sm *StationManager) validateCaptainInput(action string, value interface{}) bool {
	switch action {
	case "alert_level":
		if v, ok := value.(int); ok {
			return v >= 0 && v <= 3
		}
	case "emergency_power", "startup_sequence", "general_quarters":
		_, ok := value.(bool)
		return ok
	case "camera_selection":
		_, ok := value.(string)
		return ok
	}
	return false
}

func (sm *StationManager) validateGameMasterInput(action string, value interface{}) bool {
	return true
}
