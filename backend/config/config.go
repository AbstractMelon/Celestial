package config

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"time"
)

type Config struct {
	Server   ServerConfig   `json:"server"`
	Universe UniverseConfig `json:"universe"`
	Network  NetworkConfig  `json:"network"`
	Panels   PanelsConfig   `json:"panels"`
	Missions MissionsConfig `json:"missions"`
	Logging  LoggingConfig  `json:"logging"`
}

type ServerConfig struct {
	Host            string `json:"host"`
	Port            int    `json:"port"`
	TCPPort         int    `json:"tcp_port"`
	MaxConnections  int    `json:"max_connections"`
	ReadTimeout     int    `json:"read_timeout"`
	WriteTimeout    int    `json:"write_timeout"`
	EnableCORS      bool   `json:"enable_cors"`
	StaticFilesPath string `json:"static_files_path"`
}

type UniverseConfig struct {
	TickRate           int     `json:"tick_rate"`
	PhysicsEnabled     bool    `json:"physics_enabled"`
	CollisionEnabled   bool    `json:"collision_enabled"`
	MaxObjects         int     `json:"max_objects"`
	GravityConstant    float64 `json:"gravity_constant"`
	DragCoefficient    float64 `json:"drag_coefficient"`
	MaxGravityDistance float64 `json:"max_gravity_distance"`
	AutoSave           bool    `json:"auto_save"`
	AutoSaveInterval   int     `json:"auto_save_interval"`
}

type NetworkConfig struct {
	HeartbeatInterval   int    `json:"heartbeat_interval"`
	ClientTimeout       int    `json:"client_timeout"`
	MaxMessageSize      int    `json:"max_message_size"`
	CompressionEnabled  bool   `json:"compression_enabled"`
	EncryptionEnabled   bool   `json:"encryption_enabled"`
	BroadcastBatchSize  int    `json:"broadcast_batch_size"`
	StateUpdateInterval int    `json:"state_update_interval"`
	WiFiSSID            string `json:"wifi_ssid"`
	WiFiPassword        string `json:"wifi_password"`
}

type PanelsConfig struct {
	Enabled              bool     `json:"enabled"`
	AutoDiscovery        bool     `json:"auto_discovery"`
	MaxPanels            int      `json:"max_panels"`
	HeartbeatInterval    int      `json:"heartbeat_interval"`
	ConfigRetryAttempts  int      `json:"config_retry_attempts"`
	DeviceResponseTime   int      `json:"device_response_time"`
	SupportedDeviceTypes []string `json:"supported_device_types"`
}

type MissionsConfig struct {
	ScriptsPath      string   `json:"scripts_path"`
	AutoLoad         bool     `json:"auto_load"`
	DefaultMission   string   `json:"default_mission"`
	LuaTimeout       int      `json:"lua_timeout"`
	MaxScriptMemory  int      `json:"max_script_memory"`
	AllowedLibraries []string `json:"allowed_libraries"`
}

type LoggingConfig struct {
	Level           string `json:"level"`
	OutputFile      string `json:"output_file"`
	MaxFileSize     int    `json:"max_file_size"`
	MaxFiles        int    `json:"max_files"`
	EnableConsole   bool   `json:"enable_console"`
	EnableTimestamp bool   `json:"enable_timestamp"`
	LogRequests     bool   `json:"log_requests"`
	LogErrors       bool   `json:"log_errors"`
}

var defaultConfig = Config{
	Server: ServerConfig{
		Host:            "0.0.0.0",
		Port:            8080,
		TCPPort:         8081,
		MaxConnections:  100,
		ReadTimeout:     60,
		WriteTimeout:    60,
		EnableCORS:      true,
		StaticFilesPath: "./static",
	},
	Universe: UniverseConfig{
		TickRate:           60,
		PhysicsEnabled:     true,
		CollisionEnabled:   true,
		MaxObjects:         10000,
		GravityConstant:    6.67430e-11,
		DragCoefficient:    0.01,
		MaxGravityDistance: 100000.0,
		AutoSave:           false,
		AutoSaveInterval:   300,
	},
	Network: NetworkConfig{
		HeartbeatInterval:   30,
		ClientTimeout:       60,
		MaxMessageSize:      65536,
		CompressionEnabled:  false,
		EncryptionEnabled:   false,
		BroadcastBatchSize:  50,
		StateUpdateInterval: 16,
		WiFiSSID:            "Celestial_Bridge",
		WiFiPassword:        "starship2024",
	},
	Panels: PanelsConfig{
		Enabled:              true,
		AutoDiscovery:        true,
		MaxPanels:            20,
		HeartbeatInterval:    10,
		ConfigRetryAttempts:  3,
		DeviceResponseTime:   100,
		SupportedDeviceTypes: []string{"button", "potentiometer", "led", "7segment", "rgb_strip", "encoder", "switch"},
	},
	Missions: MissionsConfig{
		ScriptsPath:      "./missions",
		AutoLoad:         false,
		DefaultMission:   "tutorial.lua",
		LuaTimeout:       5000,
		MaxScriptMemory:  10485760,
		AllowedLibraries: []string{"math", "string", "table"},
	},
	Logging: LoggingConfig{
		Level:           "info",
		OutputFile:      "./logs/celestial.log",
		MaxFileSize:     10485760,
		MaxFiles:        5,
		EnableConsole:   true,
		EnableTimestamp: true,
		LogRequests:     true,
		LogErrors:       true,
	},
}

func Load(configPath string) (*Config, error) {
	config := defaultConfig

	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		log.Printf("Config file not found at %s, creating default config", configPath)
		if err := Save(&config, configPath); err != nil {
			return nil, fmt.Errorf("failed to create default config: %v", err)
		}
		return &config, nil
	}

	data, err := ioutil.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %v", err)
	}

	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %v", err)
	}

	if err := validateConfig(&config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %v", err)
	}

	return &config, nil
}

func Save(config *Config, configPath string) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal config: %v", err)
	}

	if err := os.MkdirAll(filepath.Dir(configPath), 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %v", err)
	}

	if err := ioutil.WriteFile(configPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %v", err)
	}

	return nil
}

func validateConfig(config *Config) error {
	if config.Server.Port < 1 || config.Server.Port > 65535 {
		return fmt.Errorf("invalid server port: %d", config.Server.Port)
	}

	if config.Server.TCPPort < 1 || config.Server.TCPPort > 65535 {
		return fmt.Errorf("invalid TCP port: %d", config.Server.TCPPort)
	}

	if config.Universe.TickRate < 1 || config.Universe.TickRate > 1000 {
		return fmt.Errorf("invalid tick rate: %d", config.Universe.TickRate)
	}

	if config.Network.HeartbeatInterval < 1 {
		return fmt.Errorf("invalid heartbeat interval: %d", config.Network.HeartbeatInterval)
	}

	if config.Network.ClientTimeout < config.Network.HeartbeatInterval {
		return fmt.Errorf("client timeout must be greater than heartbeat interval")
	}

	if config.Panels.MaxPanels < 1 || config.Panels.MaxPanels > 50 {
		return fmt.Errorf("invalid max panels: %d", config.Panels.MaxPanels)
	}

	validLogLevels := []string{"debug", "info", "warn", "error"}
	validLevel := false
	for _, level := range validLogLevels {
		if config.Logging.Level == level {
			validLevel = true
			break
		}
	}
	if !validLevel {
		return fmt.Errorf("invalid log level: %s", config.Logging.Level)
	}

	return nil
}

func GetDefault() *Config {
	config := defaultConfig
	return &config
}

func (c *Config) GetServerAddress() string {
	return fmt.Sprintf("%s:%d", c.Server.Host, c.Server.Port)
}

func (c *Config) GetTCPAddress() string {
	return fmt.Sprintf("%s:%d", c.Server.Host, c.Server.TCPPort)
}

func (c *Config) IsDebugMode() bool {
	return c.Logging.Level == "debug"
}

func (c *Config) GetTickDuration() time.Duration {
	return time.Duration(1000/c.Universe.TickRate) * time.Millisecond
}

func (c *Config) GetHeartbeatDuration() time.Duration {
	return time.Duration(c.Network.HeartbeatInterval) * time.Second
}

func (c *Config) GetClientTimeoutDuration() time.Duration {
	return time.Duration(c.Network.ClientTimeout) * time.Second
}

func (c *Config) GetStateUpdateDuration() time.Duration {
	return time.Duration(c.Network.StateUpdateInterval) * time.Millisecond
}
