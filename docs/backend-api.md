# Celestial Bridge Simulator - Backend API Documentation

## Overview

The Celestial Backend provides a WebSocket-based API for real-time communication between the server and client applications (Godot frontend stations). This document describes the complete WebSocket protocol, message formats, and API endpoints.

## WebSocket Connection

### Connection URL
```
ws://localhost:8080/ws
```

### Connection Flow
1. Client connects to WebSocket endpoint
2. Client sends `station_connect` message to identify station type
3. Server confirms connection and begins sending filtered state updates
4. Client can send input events and receive real-time updates

## Message Format

All WebSocket messages use JSON format with the following structure:

```json
{
  "type": "message_type",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": { ... }
}
```

### Message Types

#### Client to Server Messages

##### Station Connection
```json
{
  "type": "station_connect",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "station": "helm|tactical|communication|logistics|captain|gamemaster",
    "client_id": "unique_client_identifier",
    "version": "1.0.0"
  }
}
```

##### Input Events
```json
{
  "type": "input_event",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "station": "helm",
    "action": "throttle",
    "value": 0.75,
    "context": {
      "additional_data": "optional"
    }
  }
}
```

##### Heartbeat
```json
{
  "type": "heartbeat",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "client_id": "client_123",
    "ping": "2023-12-01T12:00:00Z"
  }
}
```

##### Mission Load (Game Master Only)
```json
{
  "type": "mission_load",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "mission_file": "missions/tutorial.lua",
    "parameters": {
      "difficulty": "easy",
      "custom_setting": "value"
    }
  }
}
```

##### Game Master Command
```json
{
  "type": "gamemaster_command",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "command": "spawn_object",
    "target": "optional_target_id",
    "position": {"x": 1000, "y": 0, "z": 500},
    "value": {"custom": "data"},
    "object_def": {
      "id": "new_object_123",
      "type": "ship",
      "name": "Enemy Cruiser",
      "position": {"x": 1000, "y": 0, "z": 500}
    }
  }
}
```

#### Server to Client Messages

##### State Updates
```json
{
  "type": "state_update",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "objects": [
      {
        "id": "player_ship",
        "type": "ship",
        "name": "USS Celestial",
        "position": {"x": 0, "y": 0, "z": 0},
        "velocity": {"x": 100, "y": 0, "z": 0},
        "rotation": {"x": 0, "y": 0, "z": 0, "w": 1},
        "scale": {"x": 1, "y": 1, "z": 1},
        "health": 100,
        "max_health": 100,
        "shield": 80,
        "max_shield": 100,
        "power": 95,
        "max_power": 100,
        "mass": 50000,
        "radius": 50,
        "is_player_ship": true,
        "properties": {}
      }
    ],
    "effects": [
      {
        "id": "phaser_beam_1",
        "type": "phaser_beam",
        "position": {"x": 0, "y": 0, "z": 25},
        "direction": {"x": 0, "y": 0, "z": 1},
        "color": [1.0, 0.2, 0.2],
        "intensity": 1.0,
        "duration": 0.5,
        "time_left": 0.3,
        "properties": {
          "end_position": {"x": 0, "y": 0, "z": 1000},
          "width": 2.0
        }
      }
    ],
    "removed": ["old_object_id"],
    "meta": {
      "time_acceleration": 1.0,
      "alert_level": 0,
      "station_specific_data": true
    }
  }
}
```

##### Error Messages
```json
{
  "type": "error",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "code": 400,
    "message": "Invalid input data",
    "details": "Throttle value must be between 0 and 1"
  }
}
```

## Station-Specific APIs

### Helm Station

#### Input Actions
- `throttle`: Engine throttle control (0.0 to 1.0)
- `rudder`: Rudder control (-1.0 to 1.0)
- `pitch`: Pitch control (-1.0 to 1.0)
- `roll`: Roll control (-1.0 to 1.0)
- `autopilot_mode`: Autopilot mode ("manual", "position", "heading", "follow", "station_keeping")
- `warp_factor`: Time acceleration (0.1 to 10.0)
- `desired_heading`: Target heading in degrees (-180 to 180)
- `navigation_plot`: Array of waypoint positions

#### State Filter
Helm station receives:
- Player ship position, velocity, rotation
- Navigation objects (planets, stations)
- Time acceleration factor
- Navigation-specific metadata

### Tactical Station

#### Input Actions
- `fire_weapon`: Fire weapons with tactical data
- `target_lock`: Lock onto target by ID
- `shield_power`: Shield power allocation (0.0 to 1.0)
- `weapon_power`: Weapon power allocation (0.0 to 1.0)
- `raise_shields`: Enable/disable shields (boolean)
- `tactical_scan`: Scan target by ID

#### Tactical Input Data Format
```json
{
  "weapon_type": "phaser|torpedo",
  "target_id": "enemy_ship_1",
  "target_position": {"x": 1000, "y": 0, "z": 0},
  "fire_command": true,
  "shield_power": 0.8,
  "weapon_power": 1.0,
  "torpedo_type": "standard"
}
```

#### State Filter
Tactical station receives:
- Combat-relevant objects (ships, torpedoes, mines)
- Weapon effects (phaser beams, explosions)
- Shield and weapon status
- Alert level information

### Communication Station

#### Input Actions
- `send_message`: Send communication with comm data
- `set_frequency`: Set communication frequency
- `emergency_broadcast`: Send emergency broadcast
- `comm_auto_response`: Enable/disable auto-response
- `comm_log_clear`: Clear communication log

#### Communication Input Data Format
```json
{
  "frequency": 123.45,
  "message": "This is USS Celestial, requesting assistance",
  "target_ship_id": "station_alpha|broadcast",
  "broadcast_type": "general|emergency|diplomatic",
  "priority": 2,
  "auto_response": false
}
```

#### State Filter
Communication station receives:
- Ships and stations (for communication targets)
- Communication-related metadata
- Alert level for priority handling

### Logistics Station

#### Input Actions
- `power_allocation`: Distribute power across systems
- `repair_system`: Initiate system repairs
- `crew_assignment`: Assign crew to stations
- `system_priority`: Set system priority levels
- `damage_control`: Enable damage control teams

#### Logistics Input Data Format
```json
{
  "power_allocation": {
    "engines": 0.3,
    "shields": 0.2,
    "weapons": 0.3,
    "life_support": 0.2
  },
  "repair_priority": ["engines", "shields", "weapons"],
  "crew_assignment": {
    "engineering": "repair_teams",
    "security": "battle_stations"
  },
  "system_priority": {
    "engines": 1,
    "life_support": 1,
    "shields": 2
  }
}
```

#### State Filter
Logistics station receives:
- Player ship detailed status
- System efficiency and damage reports
- Power grid information
- Repair queue status

### Captain Station

#### Input Actions
- `alert_level`: Set ship alert condition (0-3)
- `general_quarters`: Battle stations alert
- `emergency_power`: Activate emergency power
- `ship_startup`: Initialize all ship systems
- `camera_control`: Select viewscreen camera
- `ship_lockdown`: Emergency lockdown procedures

#### State Filter
Captain station receives:
- Complete universe state (full access)
- All ship systems status
- Alert conditions and ship-wide information

### Game Master Station

#### Input Actions
- `spawn_object`: Create new universe objects
- `modify_object`: Modify existing objects
- `delete_object`: Remove objects from universe
- `universe_control`: Control universe parameters
- `mission_intervention`: Direct mission intervention

#### Game Master Commands
```json
{
  "command": "spawn_object|modify_object|delete_object|universe_control",
  "target": "object_id",
  "position": {"x": 0, "y": 0, "z": 0},
  "value": "command_specific_data",
  "object_def": { "complete_object_definition" },
  "script": "lua_script_to_execute",
  "context": { "additional_parameters" }
}
```

#### State Filter
Game Master station receives:
- Complete universe state with admin metadata
- Debug information and performance metrics
- Mission status and script execution info

## HTTP API Endpoints

### Status Endpoint
```
GET /status
```

Returns server status and statistics:
```json
{
  "running": true,
  "uptime": 3600.5,
  "connected_clients": {
    "helm": 1,
    "tactical": 1,
    "gamemaster": 1
  },
  "connected_panels": {
    "helm_main": true,
    "tactical_weapons": true
  },
  "universe_objects": 45,
  "active_mission": {
    "name": "Tutorial Mission",
    "is_active": true
  }
}
```

### Universe State Endpoint
```
GET /api/universe/state
```

Returns complete universe state (same format as state_update message).

### Stations Endpoint
```
GET /api/stations
```

Returns all station configurations and status.

### Panels Endpoint
```
GET /api/panels
```

Returns ESP32 panel status and configurations.

### Missions Endpoint
```
GET /api/missions
POST /api/missions
```

GET returns active missions. POST loads a new mission file.

### Configuration Endpoint
```
GET /api/config
PUT /api/config
```

GET returns server configuration. PUT updates configuration.

## Error Codes

- `400`: Bad Request - Invalid message format or data
- `401`: Unauthorized - Invalid station permissions
- `404`: Not Found - Requested object or resource not found
- `429`: Too Many Requests - Rate limiting exceeded
- `500`: Internal Server Error - Server-side error

## Rate Limiting

- Input events: 60 per second per client
- State updates: 60 FPS to all clients
- Heartbeat: Every 30 seconds required
- Client timeout: 60 seconds without heartbeat

## Connection States

1. **Disconnected**: No WebSocket connection
2. **Connected**: WebSocket established, awaiting station identification
3. **Authenticated**: Station type confirmed, receiving filtered updates
4. **Active**: Fully operational, sending/receiving all message types

## Best Practices

### For Client Developers

1. Always send station_connect immediately after WebSocket connection
2. Implement proper heartbeat handling with ping/pong
3. Handle partial state updates efficiently
4. Validate input values before sending
5. Implement reconnection logic with exponential backoff
6. Filter received data based on your station's requirements

### For Mission Scripters

1. Use Game Master WebSocket API for real-time mission control
2. Implement proper error handling for all API calls
3. Use rate limiting to avoid overwhelming the server
4. Test missions thoroughly with multiple connected stations

### Performance Tips

1. State updates are sent at 60 FPS - implement client-side interpolation
2. Use object ID tracking to handle partial updates
3. Implement client-side prediction for responsive controls
4. Cache static object data to reduce bandwidth usage

## Security Considerations

1. All communications are currently unencrypted WebSocket
2. Station permissions are enforced server-side
3. Game Master station has full universe access
4. Input validation prevents most injection attacks
5. Rate limiting prevents DoS attacks

For production deployment, consider implementing:
- WSS (WebSocket over TLS) encryption
- Authentication tokens
- IP-based access controls
- Additional input sanitization

## Troubleshooting

### Common Connection Issues

1. **Connection Refused**: Check if server is running on correct port
2. **Authentication Failed**: Verify station type in connect message
3. **No State Updates**: Check if station_connect was sent successfully
4. **Input Ignored**: Verify action names and value ranges
5. **Frequent Disconnections**: Check network stability and heartbeat implementation

### Debug Mode

Run server with `-debug` flag for verbose logging of all WebSocket communications.