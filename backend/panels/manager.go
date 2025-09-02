package panels

import (
	"celestial-backend/networking"
	"celestial-backend/stations"
	"sync"
	"time"
)

type PanelManager struct {
	panels          map[string]*PanelState
	configurations  map[string]*networking.PanelConfiguration
	stationManager  *stations.StationManager
	mutex           sync.RWMutex
	outputCallbacks []func(string, *networking.PanelOutputData)
}

type PanelState struct {
	ID            string                         `json:"id"`
	Name          string                         `json:"name"`
	Station       networking.StationType         `json:"station"`
	IsOnline      bool                           `json:"is_online"`
	LastSeen      time.Time                      `json:"last_seen"`
	Configuration *networking.PanelConfiguration `json:"configuration"`
	DeviceStates  map[string]interface{}         `json:"device_states"`
	ErrorCount    int                            `json:"error_count"`
	LastErrors    []string                       `json:"last_errors"`
}

func NewPanelManager(stationManager *stations.StationManager) *PanelManager {
	pm := &PanelManager{
		panels:          make(map[string]*PanelState),
		configurations:  make(map[string]*networking.PanelConfiguration),
		stationManager:  stationManager,
		outputCallbacks: make([]func(string, *networking.PanelOutputData), 0),
	}

	pm.initializeDefaultConfigurations()
	return pm
}

func (pm *PanelManager) initializeDefaultConfigurations() {
	configs := []*networking.PanelConfiguration{
		{
			PanelID: "helm_main",
			Station: networking.StationHelm,
			Name:    "Helm Control Panel",
			Devices: []networking.PanelDevice{
				{ID: "throttle", Type: "potentiometer", Pin: 34, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "rudder", Type: "potentiometer", Pin: 35, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "pitch", Type: "potentiometer", Pin: 32, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "roll", Type: "potentiometer", Pin: 33, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "autopilot_btn", Type: "button", Pin: 18, Config: map[string]interface{}{"pullup": true}},
				{ID: "warp_dial", Type: "encoder", Pin: 19, Config: map[string]interface{}{"steps": 100}},
				{ID: "engine_led", Type: "led", Pin: 2, Config: map[string]interface{}{"pwm": true}},
				{ID: "nav_display", Type: "7segment", Pin: 4, Config: map[string]interface{}{"digits": 4}},
			},
			Network: networking.NetworkConfig{
				ServerHost: "192.168.1.100",
				ServerPort: 8081,
				WiFiSSID:   "Celestial_Bridge",
				WiFiPass:   "starship2024",
			},
		},
		{
			PanelID: "tactical_weapons",
			Station: networking.StationTactical,
			Name:    "Weapons Control Panel",
			Devices: []networking.PanelDevice{
				{ID: "phaser_btn", Type: "button", Pin: 18, Config: map[string]interface{}{"pullup": true}},
				{ID: "torpedo_btn", Type: "button", Pin: 19, Config: map[string]interface{}{"pullup": true}},
				{ID: "target_lock", Type: "button", Pin: 21, Config: map[string]interface{}{"pullup": true}},
				{ID: "shield_power", Type: "potentiometer", Pin: 34, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "weapon_power", Type: "potentiometer", Pin: 35, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "alert_lights", Type: "rgb_strip", Pin: 5, Config: map[string]interface{}{"pixels": 12}},
				{ID: "weapon_status", Type: "led", Pin: 2, Config: map[string]interface{}{"pwm": false}},
				{ID: "ammo_display", Type: "7segment", Pin: 4, Config: map[string]interface{}{"digits": 2}},
			},
			Network: networking.NetworkConfig{
				ServerHost: "192.168.1.100",
				ServerPort: 8081,
				WiFiSSID:   "Celestial_Bridge",
				WiFiPass:   "starship2024",
			},
		},
		{
			PanelID: "comm_main",
			Station: networking.StationCommunication,
			Name:    "Communications Panel",
			Devices: []networking.PanelDevice{
				{ID: "freq_dial", Type: "encoder", Pin: 18, Config: map[string]interface{}{"steps": 999}},
				{ID: "transmit_btn", Type: "button", Pin: 19, Config: map[string]interface{}{"pullup": true}},
				{ID: "emergency_btn", Type: "button", Pin: 21, Config: map[string]interface{}{"pullup": true}},
				{ID: "channel_sel", Type: "rotary_switch", Pin: 22, Config: map[string]interface{}{"positions": 8}},
				{ID: "signal_strength", Type: "led_bar", Pin: 23, Config: map[string]interface{}{"leds": 10}},
				{ID: "freq_display", Type: "7segment", Pin: 4, Config: map[string]interface{}{"digits": 4}},
				{ID: "status_led", Type: "led", Pin: 2, Config: map[string]interface{}{"pwm": false}},
			},
			Network: networking.NetworkConfig{
				ServerHost: "192.168.1.100",
				ServerPort: 8081,
				WiFiSSID:   "Celestial_Bridge",
				WiFiPass:   "starship2024",
			},
		},
		{
			PanelID: "engineering_power",
			Station: networking.StationLogistics,
			Name:    "Power Management Panel",
			Devices: []networking.PanelDevice{
				{ID: "engines_power", Type: "slider", Pin: 34, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "shields_power", Type: "slider", Pin: 35, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "weapons_power", Type: "slider", Pin: 32, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "life_support_power", Type: "slider", Pin: 33, Config: map[string]interface{}{"min": 0, "max": 1023}},
				{ID: "repair_btn", Type: "button", Pin: 18, Config: map[string]interface{}{"pullup": true}},
				{ID: "emergency_power", Type: "button", Pin: 19, Config: map[string]interface{}{"pullup": true}},
				{ID: "power_display", Type: "7segment", Pin: 4, Config: map[string]interface{}{"digits": 3}},
				{ID: "system_leds", Type: "led_array", Pin: 5, Config: map[string]interface{}{"count": 8}},
			},
			Network: networking.NetworkConfig{
				ServerHost: "192.168.1.100",
				ServerPort: 8081,
				WiFiSSID:   "Celestial_Bridge",
				WiFiPass:   "starship2024",
			},
		},
		{
			PanelID: "captain_console",
			Station: networking.StationCaptain,
			Name:    "Captain's Console",
			Devices: []networking.PanelDevice{
				{ID: "red_alert", Type: "button", Pin: 18, Config: map[string]interface{}{"pullup": true}},
				{ID: "yellow_alert", Type: "button", Pin: 19, Config: map[string]interface{}{"pullup": true}},
				{ID: "all_stop", Type: "button", Pin: 21, Config: map[string]interface{}{"pullup": true}},
				{ID: "general_quarters", Type: "button", Pin: 22, Config: map[string]interface{}{"pullup": true}},
				{ID: "camera_select", Type: "rotary_switch", Pin: 23, Config: map[string]interface{}{"positions": 6}},
				{ID: "bridge_lights", Type: "rgb_strip", Pin: 5, Config: map[string]interface{}{"pixels": 20}},
				{ID: "alert_klaxon", Type: "buzzer", Pin: 25, Config: map[string]interface{}{"frequency": 440}},
			},
			Network: networking.NetworkConfig{
				ServerHost: "192.168.1.100",
				ServerPort: 8081,
				WiFiSSID:   "Celestial_Bridge",
				WiFiPass:   "starship2024",
			},
		},
	}

	for _, config := range configs {
		pm.configurations[config.PanelID] = config
		pm.panels[config.PanelID] = &PanelState{
			ID:            config.PanelID,
			Name:          config.Name,
			Station:       config.Station,
			IsOnline:      false,
			Configuration: config,
			DeviceStates:  make(map[string]interface{}),
			ErrorCount:    0,
			LastErrors:    make([]string, 0),
		}
	}
}

func (pm *PanelManager) GetPanelConfiguration(panelID string) *networking.PanelConfiguration {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	return pm.configurations[panelID]
}

func (pm *PanelManager) SetPanelOnline(panelID string) {
	pm.mutex.Lock()
	defer pm.mutex.Unlock()

	if panel, exists := pm.panels[panelID]; exists {
		panel.IsOnline = true
		panel.LastSeen = time.Now()
	}
}

func (pm *PanelManager) SetPanelOffline(panelID string) {
	pm.mutex.Lock()
	defer pm.mutex.Unlock()

	if panel, exists := pm.panels[panelID]; exists {
		panel.IsOnline = false
	}
}

func (pm *PanelManager) UpdatePanelStatus(panelID string, status *networking.PanelStatusData) {
	pm.mutex.Lock()
	defer pm.mutex.Unlock()

	if panel, exists := pm.panels[panelID]; exists {
		panel.LastSeen = status.LastSeen
		panel.ErrorCount = len(status.Errors)
		panel.LastErrors = status.Errors
	}
}

func (pm *PanelManager) ProcessInput(input *networking.PanelInputData) {
	pm.mutex.RLock()
	panel := pm.panels[input.PanelID]
	pm.mutex.RUnlock()

	if panel == nil || !panel.IsOnline {
		return
	}

	panel.DeviceStates[input.DeviceID] = input.Value

	inputEvent := &networking.InputEventData{
		Station:   panel.Station,
		Action:    pm.mapDeviceToAction(input.DeviceID, panel.Configuration),
		Value:     pm.processDeviceValue(input.DeviceID, input.Value, panel.Configuration),
		Timestamp: input.Timestamp,
		Context:   input.Context,
	}

	pm.stationManager.HandleInput(panel.Station, inputEvent)
}

func (pm *PanelManager) mapDeviceToAction(deviceID string, config *networking.PanelConfiguration) string {
	for _, device := range config.Devices {
		if device.ID == deviceID {
			switch config.Station {
			case networking.StationHelm:
				return pm.mapHelmDevice(deviceID)
			case networking.StationTactical:
				return pm.mapTacticalDevice(deviceID)
			case networking.StationCommunication:
				return pm.mapCommDevice(deviceID)
			case networking.StationLogistics:
				return pm.mapLogisticsDevice(deviceID)
			case networking.StationCaptain:
				return pm.mapCaptainDevice(deviceID)
			}
		}
	}
	return deviceID
}

func (pm *PanelManager) mapHelmDevice(deviceID string) string {
	mapping := map[string]string{
		"throttle":      "throttle",
		"rudder":        "rudder",
		"pitch":         "pitch",
		"roll":          "roll",
		"autopilot_btn": "autopilot_mode",
		"warp_dial":     "warp_factor",
	}
	if action, exists := mapping[deviceID]; exists {
		return action
	}
	return deviceID
}

func (pm *PanelManager) mapTacticalDevice(deviceID string) string {
	mapping := map[string]string{
		"phaser_btn":   "fire_weapon",
		"torpedo_btn":  "fire_weapon",
		"target_lock":  "target_lock",
		"shield_power": "shield_power",
		"weapon_power": "weapon_power",
	}
	if action, exists := mapping[deviceID]; exists {
		return action
	}
	return deviceID
}

func (pm *PanelManager) mapCommDevice(deviceID string) string {
	mapping := map[string]string{
		"freq_dial":     "set_frequency",
		"transmit_btn":  "send_message",
		"emergency_btn": "emergency_broadcast",
		"channel_sel":   "comm_channel",
	}
	if action, exists := mapping[deviceID]; exists {
		return action
	}
	return deviceID
}

func (pm *PanelManager) mapLogisticsDevice(deviceID string) string {
	mapping := map[string]string{
		"engines_power":      "power_allocation",
		"shields_power":      "power_allocation",
		"weapons_power":      "power_allocation",
		"life_support_power": "power_allocation",
		"repair_btn":         "repair_system",
		"emergency_power":    "emergency_power",
	}
	if action, exists := mapping[deviceID]; exists {
		return action
	}
	return deviceID
}

func (pm *PanelManager) mapCaptainDevice(deviceID string) string {
	mapping := map[string]string{
		"red_alert":        "alert_level",
		"yellow_alert":     "alert_level",
		"all_stop":         "emergency_stop",
		"general_quarters": "general_quarters",
		"camera_select":    "camera_control",
	}
	if action, exists := mapping[deviceID]; exists {
		return action
	}
	return deviceID
}

func (pm *PanelManager) processDeviceValue(deviceID string, value interface{}, config *networking.PanelConfiguration) interface{} {
	for _, device := range config.Devices {
		if device.ID == deviceID {
			switch device.Type {
			case "potentiometer", "slider":
				rawValue := toFloat64(value)
				min := toFloat64(device.Config["min"])
				max := toFloat64(device.Config["max"])
				if max > min {
					return (rawValue - min) / (max - min)
				}
				return 0.0
			case "encoder":
				rawValue := toFloat64(value)
				steps := toFloat64(device.Config["steps"])
				if steps != 0 {
					return rawValue / steps
				}
				return 0.0
			default:
				return value
			}
		}
	}
	return value
}

func (pm *PanelManager) SendOutput(panelID, deviceID string, command string, value interface{}) {
	output := &networking.PanelOutputData{
		PanelID:  panelID,
		DeviceID: deviceID,
		Command:  command,
		Value:    value,
		Context:  make(map[string]interface{}),
	}

	for _, callback := range pm.outputCallbacks {
		callback(panelID, output)
	}
}

func (pm *PanelManager) SetLED(panelID, deviceID string, brightness float64) {
	pm.SendOutput(panelID, deviceID, "set_brightness", brightness)
}

func (pm *PanelManager) SetRGBStrip(panelID, deviceID string, colors [][3]float64) {
	pm.SendOutput(panelID, deviceID, "set_colors", colors)
}

func (pm *PanelManager) SetDisplay(panelID, deviceID string, text string) {
	pm.SendOutput(panelID, deviceID, "set_text", text)
}

func (pm *PanelManager) SetBuzzer(panelID, deviceID string, frequency float64, duration float64) {
	pm.SendOutput(panelID, deviceID, "set_buzzer", map[string]interface{}{
		"frequency": frequency,
		"duration":  duration,
	})
}

func (pm *PanelManager) AddOutputCallback(callback func(string, *networking.PanelOutputData)) {
	pm.outputCallbacks = append(pm.outputCallbacks, callback)
}

func (pm *PanelManager) GetPanelState(panelID string) *PanelState {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()
	return pm.panels[panelID]
}

func (pm *PanelManager) GetAllPanels() map[string]*PanelState {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()

	result := make(map[string]*PanelState)
	for k, v := range pm.panels {
		result[k] = v
	}
	return result
}

func (pm *PanelManager) GetOnlinePanels() []string {
	pm.mutex.RLock()
	defer pm.mutex.RUnlock()

	online := make([]string, 0)
	for panelID, panel := range pm.panels {
		if panel.IsOnline {
			online = append(online, panelID)
		}
	}
	return online
}

func (pm *PanelManager) UpdatePanelConfiguration(panelID string, config *networking.PanelConfiguration) {
	pm.mutex.Lock()
	defer pm.mutex.Unlock()

	pm.configurations[panelID] = config
	if panel, exists := pm.panels[panelID]; exists {
		panel.Configuration = config
		panel.Name = config.Name
		panel.Station = config.Station
	}
}

func (pm *PanelManager) RemovePanel(panelID string) {
	pm.mutex.Lock()
	defer pm.mutex.Unlock()

	delete(pm.panels, panelID)
	delete(pm.configurations, panelID)
}

func toFloat64(val interface{}) float64 {
	switch v := val.(type) {
	case float64:
		return v
	case float32:
		return float64(v)
	case int:
		return float64(v)
	case int32:
		return float64(v)
	case int64:
		return float64(v)
	case uint:
		return float64(v)
	case uint32:
		return float64(v)
	case uint64:
		return float64(v)
	default:
		return 0.0
	}
}
