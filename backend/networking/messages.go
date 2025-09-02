package networking

import (
	"celestial-backend/utils"
	"encoding/json"
	"time"
)

type MessageType string

const (
	// WebSocket message types
	MsgTypeStateUpdate    MessageType = "state_update"
	MsgTypeInputEvent     MessageType = "input_event"
	MsgTypeStationConnect MessageType = "station_connect"
	MsgTypeHeartbeat      MessageType = "heartbeat"
	MsgTypeError          MessageType = "error"
	MsgTypeMissionLoad    MessageType = "mission_load"
	MsgTypeMissionControl MessageType = "mission_control"
	MsgTypeGameMasterCmd  MessageType = "gamemaster_command"

	// TCP message types (ESP32)
	MsgTypePanelConfig    MessageType = "panel_config"
	MsgTypePanelInput     MessageType = "panel_input"
	MsgTypePanelOutput    MessageType = "panel_output"
	MsgTypePanelHeartbeat MessageType = "panel_heartbeat"
	MsgTypePanelStatus    MessageType = "panel_status"
)

type StationType string

const (
	StationHelm          StationType = "helm"
	StationTactical      StationType = "tactical"
	StationCommunication StationType = "communication"
	StationLogistics     StationType = "logistics"
	StationCaptain       StationType = "captain"
	StationGameMaster    StationType = "gamemaster"
)

type Message struct {
	Type      MessageType     `json:"type"`
	Timestamp time.Time       `json:"timestamp"`
	Data      json.RawMessage `json:"data,omitempty"`
}

type StationConnectData struct {
	Station  StationType `json:"station"`
	ClientID string      `json:"client_id"`
	Version  string      `json:"version"`
}

type HeartbeatData struct {
	ClientID string    `json:"client_id"`
	Ping     time.Time `json:"ping"`
}

type ErrorData struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Details string `json:"details,omitempty"`
}

type ObjectType string

const (
	ObjectTypeShip      ObjectType = "ship"
	ObjectTypePlanet    ObjectType = "planet"
	ObjectTypeStation   ObjectType = "station"
	ObjectTypeAsteroid  ObjectType = "asteroid"
	ObjectTypeBlackHole ObjectType = "black_hole"
	ObjectTypeMine      ObjectType = "mine"
	ObjectTypeNebula    ObjectType = "nebula"
	ObjectTypeTorpedo   ObjectType = "torpedo"
	ObjectTypeBeam      ObjectType = "beam"
	ObjectTypeExplosion ObjectType = "explosion"
)

type UniverseObject struct {
	ID           string                 `json:"id"`
	Type         ObjectType             `json:"type"`
	Name         string                 `json:"name"`
	Position     utils.Vector3          `json:"position"`
	Velocity     utils.Vector3          `json:"velocity"`
	Rotation     utils.Quaternion       `json:"rotation"`
	Scale        utils.Vector3          `json:"scale"`
	Health       float64                `json:"health"`
	MaxHealth    float64                `json:"max_health"`
	Shield       float64                `json:"shield"`
	MaxShield    float64                `json:"max_shield"`
	Power        float64                `json:"power"`
	MaxPower     float64                `json:"max_power"`
	Mass         float64                `json:"mass"`
	Radius       float64                `json:"radius"`
	IsPlayerShip bool                   `json:"is_player_ship"`
	Properties   map[string]interface{} `json:"properties,omitempty"`
}

type VisualEffect struct {
	ID         string                 `json:"id"`
	Type       string                 `json:"type"`
	Position   utils.Vector3          `json:"position"`
	Direction  utils.Vector3          `json:"direction"`
	Color      [3]float64             `json:"color"`
	Intensity  float64                `json:"intensity"`
	Duration   float64                `json:"duration"`
	TimeLeft   float64                `json:"time_left"`
	Properties map[string]interface{} `json:"properties,omitempty"`
}

type UniverseState struct {
	Objects          []UniverseObject `json:"objects"`
	Effects          []VisualEffect   `json:"effects"`
	PlayerShipID     string           `json:"player_ship_id"`
	TimeAcceleration float64          `json:"time_acceleration"`
	AlertLevel       int              `json:"alert_level"`
	Timestamp        time.Time        `json:"timestamp"`
}

type StateUpdateData struct {
	Full    *UniverseState         `json:"full,omitempty"`
	Objects []UniverseObject       `json:"objects,omitempty"`
	Effects []VisualEffect         `json:"effects,omitempty"`
	Removed []string               `json:"removed,omitempty"`
	Meta    map[string]interface{} `json:"meta,omitempty"`
}

type InputEventData struct {
	Station   StationType            `json:"station"`
	Action    string                 `json:"action"`
	Value     interface{}            `json:"value"`
	Timestamp time.Time              `json:"timestamp"`
	Context   map[string]interface{} `json:"context,omitempty"`
}

type HelmInputData struct {
	Throttle       float64       `json:"throttle"`
	Rudder         float64       `json:"rudder"`
	Pitch          float64       `json:"pitch"`
	Roll           float64       `json:"roll"`
	Thrust         utils.Vector3 `json:"thrust"`
	DesiredHeading float64       `json:"desired_heading"`
	DesiredPitch   float64       `json:"desired_pitch"`
	AutopilotMode  string        `json:"autopilot_mode"`
	WarpFactor     float64       `json:"warp_factor"`
}

type TacticalInputData struct {
	WeaponType     string        `json:"weapon_type"`
	TargetID       string        `json:"target_id"`
	TargetPosition utils.Vector3 `json:"target_position"`
	FireCommand    bool          `json:"fire_command"`
	ShieldPower    float64       `json:"shield_power"`
	WeaponPower    float64       `json:"weapon_power"`
	TorpedoType    string        `json:"torpedo_type"`
}

type CommunicationInputData struct {
	Frequency     float64 `json:"frequency"`
	Message       string  `json:"message"`
	TargetShipID  string  `json:"target_ship_id"`
	BroadcastType string  `json:"broadcast_type"`
	Priority      int     `json:"priority"`
	AutoResponse  bool    `json:"auto_response"`
}

type LogisticsInputData struct {
	PowerAllocation map[string]float64 `json:"power_allocation"`
	RepairPriority  []string           `json:"repair_priority"`
	CrewAssignment  map[string]string  `json:"crew_assignment"`
	SystemPriority  map[string]int     `json:"system_priority"`
}

type GameMasterCommand struct {
	Command   string                 `json:"command"`
	Target    string                 `json:"target,omitempty"`
	Position  *utils.Vector3         `json:"position,omitempty"`
	Value     interface{}            `json:"value,omitempty"`
	ObjectDef *UniverseObject        `json:"object_def,omitempty"`
	Script    string                 `json:"script,omitempty"`
	Context   map[string]interface{} `json:"context,omitempty"`
}

type PanelDevice struct {
	ID     string                 `json:"id"`
	Type   string                 `json:"type"`
	Pin    int                    `json:"pin"`
	Config map[string]interface{} `json:"config,omitempty"`
}

type PanelConfiguration struct {
	PanelID string        `json:"panel_id"`
	Station StationType   `json:"station"`
	Name    string        `json:"name"`
	Devices []PanelDevice `json:"devices"`
	Network NetworkConfig `json:"network"`
}

type NetworkConfig struct {
	ServerHost string `json:"server_host"`
	ServerPort int    `json:"server_port"`
	WiFiSSID   string `json:"wifi_ssid"`
	WiFiPass   string `json:"wifi_pass"`
}

type PanelInputData struct {
	PanelID   string                 `json:"panel_id"`
	DeviceID  string                 `json:"device_id"`
	Value     interface{}            `json:"value"`
	Timestamp time.Time              `json:"timestamp"`
	Context   map[string]interface{} `json:"context,omitempty"`
}

type PanelOutputData struct {
	PanelID  string                 `json:"panel_id"`
	DeviceID string                 `json:"device_id"`
	Command  string                 `json:"command"`
	Value    interface{}            `json:"value"`
	Context  map[string]interface{} `json:"context,omitempty"`
}

type PanelStatusData struct {
	PanelID     string    `json:"panel_id"`
	Status      string    `json:"status"`
	LastSeen    time.Time `json:"last_seen"`
	DeviceCount int       `json:"device_count"`
	Errors      []string  `json:"errors,omitempty"`
}

type MissionLoadData struct {
	MissionFile string                 `json:"mission_file"`
	Parameters  map[string]interface{} `json:"parameters,omitempty"`
}

type MissionControlData struct {
	Command   string      `json:"command"`
	Parameter interface{} `json:"parameter,omitempty"`
}

func NewMessage(msgType MessageType, data interface{}) (*Message, error) {
	dataBytes, err := json.Marshal(data)
	if err != nil {
		return nil, err
	}

	return &Message{
		Type:      msgType,
		Timestamp: time.Now(),
		Data:      json.RawMessage(dataBytes),
	}, nil
}

func (m *Message) UnmarshalData(target interface{}) error {
	return json.Unmarshal(m.Data, target)
}

func (m *Message) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}

func MessageFromJSON(data []byte) (*Message, error) {
	var msg Message
	err := json.Unmarshal(data, &msg)
	return &msg, err
}
