# Celestial Bridge Simulator - Configuration Documentation

## Overview

The Celestial Bridge Simulator uses a comprehensive JSON-based configuration system that allows customization of all aspects of the server behavior, universe simulation, networking, panel management, and mission scripting.

## Configuration File Location

Default configuration file: `./config/config.json`

Custom configuration can be specified with the `-config` flag:
```bash
./celestial-backend -config /path/to/custom-config.json
```

## Configuration Structure

### Complete Configuration Example

```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8080,
    "tcp_port": 8081,
    "max_connections": 100,
    "read_timeout": 60,
    "write_timeout": 60,
    "enable_cors": true,
    "static_files_path": "./static"
  },
  "universe": {
    "tick_rate": 60,
    "physics_enabled": true,
    "collision_enabled": true,
    "max_objects": 10000,
    "gravity_constant": 6.67430e-11,
    "drag_coefficient": 0.01,
    "max_gravity_distance": 100000.0,
    "auto_save": false,
    "auto_save_interval": 300
  },
  "network": {
    "heartbeat_interval": 30,
    "client_timeout": 60,
    "max_message_size": 65536,
    "compression_enabled": false,
    "encryption_enabled": false,
    "broadcast_batch_size": 50,
    "state_update_interval": 16,
    "wifi_ssid": "Celestial_Bridge",
    "wifi_password": "starship2024"
  },
  "panels": {
    "enabled": true,
    "auto_discovery": true,
    "max_panels": 20,
    "heartbeat_interval": 10,
    "config_retry_attempts": 3,
    "device_response_time": 100,
    "supported_device_types": ["button", "potentiometer", "led", "7segment", "rgb_strip", "encoder", "switch"]
  },
  "missions": {
    "scripts_path": "./missions",
    "auto_load": false,
    "default_mission": "tutorial.lua",
    "lua_timeout": 5000,
    "max_script_memory": 10485760,
    "allowed_libraries": ["math", "string", "table"]
  },
  "logging": {
    "level": "info",
    "output_file": "./logs/celestial.log",
    "max_file_size": 10485760,
    "max_files": 5,
    "enable_console": true,
    "enable_timestamp": true,
    "log_requests": true,
    "log_errors": true
  }
}
```

## Configuration Sections

### Server Configuration

Controls HTTP, WebSocket, and TCP server behavior.

```json
{
  "server": {
    "host": "0.0.0.0",              // Bind address (0.0.0.0 for all interfaces)
    "port": 8080,                   // WebSocket/HTTP port
    "tcp_port": 8081,               // TCP port for ESP32 panels
    "max_connections": 100,         // Maximum concurrent connections
    "read_timeout": 60,             // Socket read timeout (seconds)
    "write_timeout": 60,            // Socket write timeout (seconds)
    "enable_cors": true,            // Enable CORS headers for web clients
    "static_files_path": "./static" // Path to static web files
  }
}
```

**Configuration Options:**

- `host`: Server bind address
  - `"0.0.0.0"`: All interfaces (default)
  - `"127.0.0.1"`: Local only
  - `"192.168.1.100"`: Specific IP

- `port`: WebSocket/HTTP port (1-65535)
- `tcp_port`: ESP32 panel port (1-65535)
- `max_connections`: Concurrent connection limit
- `read_timeout`/`write_timeout`: Socket timeouts in seconds
- `enable_cors`: CORS support for web frontends
- `static_files_path`: Directory for web assets

### Universe Configuration

Controls physics simulation and universe behavior.

```json
{
  "universe": {
    "tick_rate": 60,                    // Simulation updates per second
    "physics_enabled": true,            // Enable physics simulation
    "collision_enabled": true,          // Enable collision detection
    "max_objects": 10000,               // Maximum universe objects
    "gravity_constant": 6.67430e-11,    // Gravitational constant
    "drag_coefficient": 0.01,           // Space drag coefficient
    "max_gravity_distance": 100000.0,   // Maximum gravity influence range
    "auto_save": false,                 // Automatic state saving
    "auto_save_interval": 300           // Auto-save interval (seconds)
  }
}
```

**Performance Tuning:**

- `tick_rate`: Higher values = smoother simulation, more CPU usage
  - Recommended: 60 for normal operation, 30 for lower-end hardware
- `max_objects`: Limits memory usage and processing load
- `max_gravity_distance`: Reduces gravity calculations for distant objects

**Physics Parameters:**

- `gravity_constant`: Realistic value for space simulation
- `drag_coefficient`: Adds resistance to movement (0 = no drag)
- `collision_enabled`: Can be disabled for performance in large scenarios

### Network Configuration

Controls communication protocols and timing.

```json
{
  "network": {
    "heartbeat_interval": 30,       // Heartbeat frequency (seconds)
    "client_timeout": 60,           // Client timeout (seconds)
    "max_message_size": 65536,      // Maximum message size (bytes)
    "compression_enabled": false,   // Enable message compression
    "encryption_enabled": false,    // Enable message encryption
    "broadcast_batch_size": 50,     // State update batching
    "state_update_interval": 16,    // State update frequency (ms)
    "wifi_ssid": "Celestial_Bridge", // Panel Wi-Fi network
    "wifi_password": "starship2024"  // Panel Wi-Fi password
  }
}
```

**Timing Configuration:**

- `heartbeat_interval`: How often clients send heartbeats
- `client_timeout`: When to consider a client disconnected
- `state_update_interval`: Frequency of universe state broadcasts (16ms = 60 FPS)

**Message Handling:**

- `max_message_size`: Prevents oversized message attacks
- `compression_enabled`: Reduces bandwidth (increases CPU usage)
- `encryption_enabled`: Secures communications (requires TLS setup)
- `broadcast_batch_size`: Groups state updates for efficiency

**Panel Network:**

- `wifi_ssid`/`wifi_password`: Credentials sent to ESP32 panels

### Panel Configuration

Controls ESP32 hardware panel management.

```json
{
  "panels": {
    "enabled": true,                // Enable panel system
    "auto_discovery": true,         // Automatic panel detection
    "max_panels": 20,               // Maximum connected panels
    "heartbeat_interval": 10,       // Panel heartbeat frequency
    "config_retry_attempts": 3,     // Configuration retry count
    "device_response_time": 100,    // Device response timeout (ms)
    "supported_device_types": [     // Allowed device types
      "button", "potentiometer", "led", 
      "7segment", "rgb_strip", "encoder", "switch"
    ]
  }
}
```

**Panel Management:**

- `enabled`: Master switch for panel functionality
- `auto_discovery`: Automatically configure new panels
- `max_panels`: Prevents resource exhaustion
- `heartbeat_interval`: Panel health check frequency

**Device Configuration:**

- `config_retry_attempts`: How many times to retry failed configuration
- `device_response_time`: Maximum time to wait for device responses
- `supported_device_types`: Whitelist of allowed device types

### Mission Configuration

Controls Lua scripting and mission system.

```json
{
  "missions": {
    "scripts_path": "./missions",       // Mission script directory
    "auto_load": false,                 // Load default mission on startup
    "default_mission": "tutorial.lua",  // Default mission file
    "lua_timeout": 5000,                // Script execution timeout (ms)
    "max_script_memory": 10485760,      // Maximum Lua memory (bytes)
    "allowed_libraries": [              // Permitted Lua libraries
      "math", "string", "table"
    ]
  }
}
```

**Script Management:**

- `scripts_path`: Directory containing `.lua` mission files
- `auto_load`: Whether to start with default mission
- `default_mission`: Mission file to load automatically

**Security and Performance:**

- `lua_timeout`: Prevents infinite loops in scripts
- `max_script_memory`: Limits memory usage per script
- `allowed_libraries`: Security whitelist for Lua libraries

### Logging Configuration

Controls log output and management.

```json
{
  "logging": {
    "level": "info",                    // Log level
    "output_file": "./logs/celestial.log", // Log file path
    "max_file_size": 10485760,          // Maximum log file size
    "max_files": 5,                     // Log rotation count
    "enable_console": true,             // Console output
    "enable_timestamp": true,           // Include timestamps
    "log_requests": true,               // Log HTTP requests
    "log_errors": true                  // Log error details
  }
}
```

**Log Levels:**

- `"debug"`: Verbose debugging information
- `"info"`: General operational messages (default)
- `"warn"`: Warning conditions
- `"error"`: Error conditions only

**Log Management:**

- `output_file`: Path to log file (directory must exist)
- `max_file_size`: Size limit before rotation (bytes)
- `max_files`: Number of rotated files to keep
- `enable_console`: Also output to console/terminal
- `enable_timestamp`: Include ISO8601 timestamps

## Environment-Specific Configurations

### Development Configuration

```json
{
  "server": {
    "host": "127.0.0.1",
    "enable_cors": true
  },
  "universe": {
    "tick_rate": 30,
    "max_objects": 1000
  },
  "logging": {
    "level": "debug",
    "enable_console": true
  },
  "panels": {
    "enabled": false
  }
}
```

### Production Configuration

```json
{
  "server": {
    "host": "0.0.0.0",
    "max_connections": 200,
    "enable_cors": false
  },
  "universe": {
    "tick_rate": 60,
    "max_objects": 10000
  },
  "network": {
    "compression_enabled": true,
    "encryption_enabled": true
  },
  "logging": {
    "level": "info",
    "enable_console": false,
    "log_requests": false
  }
}
```

### Testing Configuration

```json
{
  "server": {
    "host": "127.0.0.1",
    "port": 8888,
    "tcp_port": 8889
  },
  "universe": {
    "tick_rate": 10,
    "physics_enabled": false,
    "max_objects": 100
  },
  "logging": {
    "level": "debug"
  },
  "missions": {
    "lua_timeout": 1000
  }
}
```

## Configuration Validation

The system validates all configuration values on startup:

### Server Validation
- Port numbers must be 1-65535
- Timeouts must be positive integers
- Host must be valid IP address or hostname

### Universe Validation
- Tick rate must be 1-1000 FPS
- Physics constants must be reasonable values
- Object limits must be positive

### Network Validation
- Heartbeat interval must be less than client timeout
- Message sizes must be reasonable (1KB-1MB)
- Update intervals must be 1-1000ms

### Common Validation Errors

```
Invalid server port: 0 (must be 1-65535)
Invalid tick rate: 0 (must be 1-1000)
Client timeout must be greater than heartbeat interval
Invalid log level: verbose (must be debug/info/warn/error)
```

## Configuration Management

### Runtime Configuration Changes

Some settings can be changed at runtime via HTTP API:

```bash
# Update log level
curl -X PUT http://localhost:8080/api/config \
  -H "Content-Type: application/json" \
  -d '{"logging": {"level": "debug"}}'

# Update universe tick rate
curl -X PUT http://localhost:8080/api/config \
  -H "Content-Type: application/json" \
  -d '{"universe": {"tick_rate": 30}}'
```

### Configuration Backup

Always backup configuration before making changes:

```bash
cp config/config.json config/config.json.backup
```

### Configuration Templates

Create environment-specific templates:

```bash
config/
├── config.json           # Current configuration
├── config.dev.json       # Development template
├── config.prod.json      # Production template
├── config.test.json      # Testing template
└── config.local.json     # Local overrides
```

## Performance Tuning

### High-Performance Configuration

For systems with powerful hardware:

```json
{
  "universe": {
    "tick_rate": 120,
    "max_objects": 50000
  },
  "network": {
    "state_update_interval": 8,
    "broadcast_batch_size": 100
  }
}
```

### Low-Resource Configuration

For systems with limited resources:

```json
{
  "universe": {
    "tick_rate": 20,
    "max_objects": 500,
    "physics_enabled": false
  },
  "network": {
    "state_update_interval": 50,
    "compression_enabled": true
  }
}
```

## Security Configuration

### Production Security Settings

```json
{
  "server": {
    "enable_cors": false,
    "max_connections": 50
  },
  "network": {
    "encryption_enabled": true,
    "max_message_size": 8192
  },
  "missions": {
    "lua_timeout": 1000,
    "max_script_memory": 1048576,
    "allowed_libraries": ["math"]
  },
  "logging": {
    "log_requests": false,
    "log_errors": true
  }
}
```

### Development Security Settings

```json
{
  "server": {
    "enable_cors": true,
    "max_connections": 10
  },
  "network": {
    "encryption_enabled": false
  },
  "missions": {
    "lua_timeout": 10000,
    "allowed_libraries": ["math", "string", "table", "io"]
  },
  "logging": {
    "level": "debug",
    "log_requests": true
  }
}
```

## Troubleshooting Configuration Issues

### Common Problems

1. **Server Won't Start**
   - Check port availability: `netstat -ln | grep :8080`
   - Verify JSON syntax: `jq . config/config.json`
   - Check file permissions: `ls -la config/config.json`

2. **Poor Performance**
   - Reduce `tick_rate` for lower CPU usage
   - Increase `state_update_interval` for less network traffic
   - Enable `compression_enabled` for bandwidth savings

3. **Connection Issues**
   - Verify `host` setting allows external connections
   - Check firewall rules for configured ports
   - Ensure `client_timeout` > `heartbeat_interval`

4. **Panel Connection Problems**
   - Verify `wifi_ssid` and `wifi_password` are correct
   - Check `tcp_port` is accessible from panel network
   - Ensure `panels.enabled` is true

### Configuration Debugging

Enable debug logging to troubleshoot configuration issues:

```json
{
  "logging": {
    "level": "debug",
    "enable_console": true
  }
}
```

Run with verbose output:

```bash
./celestial-backend -debug -config config/config.json
```

### Default Value Restoration

If configuration becomes corrupted, delete the config file to restore defaults:

```bash
rm config/config.json
./celestial-backend  # Will create new default config
```

## Configuration Best Practices

1. **Version Control**: Keep configuration files in version control
2. **Environment Separation**: Use different configs for dev/test/prod
3. **Validation**: Test configuration changes in development first
4. **Documentation**: Comment configuration changes in commit messages
5. **Backup**: Always backup working configurations before changes
6. **Monitoring**: Monitor system performance after configuration changes
7. **Security**: Never commit sensitive data like passwords to version control

Use environment variables for sensitive data:

```bash
export CELESTIAL_WIFI_PASSWORD="secure_password"
./celestial-backend -config config/config.json
```

This comprehensive configuration system provides fine-grained control over all aspects of the Celestial Bridge Simulator while maintaining sensible defaults for easy deployment.