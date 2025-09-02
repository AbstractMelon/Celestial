# Celestial Bridge Simulator - Panel Protocol Documentation

## Overview

The Celestial Panel Protocol defines the TCP-based communication between ESP32 hardware panels and the Go backend server. This protocol enables real-time bidirectional communication for physical bridge controls including buttons, switches, LEDs, displays, and other hardware components.

## Connection Details

### Network Configuration
- **Protocol**: TCP over Wi-Fi
- **Default Port**: 8081
- **Message Format**: JSON over TCP with newline delimiters
- **Encoding**: UTF-8

### Connection Flow
1. ESP32 connects to server TCP port
2. ESP32 sends heartbeat with panel ID
3. Server responds with configuration data
4. Bidirectional communication begins
5. Heartbeat messages maintain connection

## Message Format

All messages are JSON objects terminated with a newline character (`\n`):

```json
{"type":"message_type","timestamp":"2023-12-01T12:00:00Z","data":{...}}
```

### Message Types

#### ESP32 to Server Messages

##### Panel Heartbeat
```json
{
  "type": "panel_heartbeat",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "client_id": "helm_main",
    "ping": "2023-12-01T12:00:00Z"
  }
}
```

##### Panel Status
```json
{
  "type": "panel_status",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "panel_id": "helm_main",
    "status": "online",
    "last_seen": "2023-12-01T12:00:00Z",
    "device_count": 8,
    "errors": ["Device pin_18 unresponsive"]
  }
}
```

##### Panel Input
```json
{
  "type": "panel_input",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "panel_id": "helm_main",
    "device_id": "throttle",
    "value": 512,
    "context": {
      "raw_value": 512,
      "calibrated": true
    }
  }
}
```

#### Server to ESP32 Messages

##### Panel Configuration
```json
{
  "type": "panel_config",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "panel_id": "helm_main",
    "station": "helm",
    "name": "Helm Control Panel",
    "devices": [
      {
        "id": "throttle",
        "type": "potentiometer",
        "pin": 34,
        "config": {
          "min": 0,
          "max": 1023,
          "deadzone": 10,
          "invert": false
        }
      },
      {
        "id": "engine_led",
        "type": "led",
        "pin": 2,
        "config": {
          "pwm": true,
          "brightness": 255
        }
      }
    ],
    "network": {
      "server_host": "192.168.1.100",
      "server_port": 8081,
      "wifi_ssid": "Celestial_Bridge",
      "wifi_pass": "starship2024"
    }
  }
}
```

##### Panel Output
```json
{
  "type": "panel_output",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "panel_id": "helm_main",
    "device_id": "engine_led",
    "command": "set_brightness",
    "value": 128,
    "context": {
      "fade_time": 500
    }
  }
}
```

##### Heartbeat Response
```json
{
  "type": "panel_heartbeat",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "client_id": "helm_main",
    "ping": "2023-12-01T12:00:00Z"
  }
}
```

## Device Types and Configurations

### Input Devices

#### Button
```json
{
  "id": "fire_button",
  "type": "button",
  "pin": 18,
  "config": {
    "pullup": true,
    "debounce_ms": 50,
    "press_type": "momentary"
  }
}
```

**Values**: `true` (pressed), `false` (released)

#### Potentiometer
```json
{
  "id": "throttle",
  "type": "potentiometer",
  "pin": 34,
  "config": {
    "min": 0,
    "max": 1023,
    "deadzone": 10,
    "invert": false,
    "smoothing": 0.1
  }
}
```

**Values**: Integer (0-1023 typical ADC range)

#### Rotary Encoder
```json
{
  "id": "frequency_dial",
  "type": "encoder",
  "pin": 19,
  "config": {
    "steps": 100,
    "direction": "clockwise",
    "acceleration": true,
    "button_pin": 20
  }
}
```

**Values**: Integer (step count), Boolean (button state if configured)

#### Rotary Switch
```json
{
  "id": "channel_select",
  "type": "rotary_switch",
  "pin": 22,
  "config": {
    "positions": 8,
    "starting_position": 0
  }
}
```

**Values**: Integer (0 to positions-1)

#### Slider
```json
{
  "id": "power_slider",
  "type": "slider",
  "pin": 35,
  "config": {
    "min": 0,
    "max": 1023,
    "orientation": "vertical",
    "center_detent": false
  }
}
```

**Values**: Integer (0-1023 typical ADC range)

### Output Devices

#### LED
```json
{
  "id": "status_led",
  "type": "led",
  "pin": 2,
  "config": {
    "pwm": true,
    "max_brightness": 255,
    "default_state": false
  }
}
```

**Commands**:
- `set_brightness`: Integer (0-255)
- `set_state`: Boolean (on/off)
- `blink`: Object `{"rate": 500, "duration": 5000}`

#### RGB LED Strip
```json
{
  "id": "alert_strip",
  "type": "rgb_strip",
  "pin": 5,
  "config": {
    "pixels": 12,
    "type": "WS2812B",
    "max_brightness": 128
  }
}
```

**Commands**:
- `set_colors`: Array of `[r, g, b]` values (0-255 each)
- `set_all`: Single `[r, g, b]` for all pixels
- `set_pattern`: Object `{"pattern": "chase", "colors": [[255,0,0]], "speed": 100}`

#### 7-Segment Display
```json
{
  "id": "nav_display",
  "type": "7segment",
  "pin": 4,
  "config": {
    "digits": 4,
    "driver": "MAX7219",
    "brightness": 8
  }
}
```

**Commands**:
- `set_text`: String (numbers, basic letters)
- `set_brightness`: Integer (0-15)
- `set_decimal`: Object `{"position": 2, "state": true}`

#### LED Bar Graph
```json
{
  "id": "signal_strength",
  "type": "led_bar",
  "pin": 23,
  "config": {
    "leds": 10,
    "orientation": "horizontal",
    "color": "green"
  }
}
```

**Commands**:
- `set_level`: Float (0.0-1.0)
- `set_pattern`: Array of boolean values

#### Buzzer
```json
{
  "id": "alert_buzzer",
  "type": "buzzer",
  "pin": 25,
  "config": {
    "frequency": 440,
    "max_volume": 128
  }
}
```

**Commands**:
- `set_buzzer`: Object `{"frequency": 440, "duration": 1000, "volume": 100}`
- `play_tone`: Object `{"notes": [440, 523, 659], "durations": [250, 250, 500]}`

## Panel Configurations by Station

### Helm Main Panel
```json
{
  "panel_id": "helm_main",
  "station": "helm",
  "name": "Helm Control Panel",
  "devices": [
    {"id": "throttle", "type": "potentiometer", "pin": 34},
    {"id": "rudder", "type": "potentiometer", "pin": 35},
    {"id": "pitch", "type": "potentiometer", "pin": 32},
    {"id": "roll", "type": "potentiometer", "pin": 33},
    {"id": "autopilot_btn", "type": "button", "pin": 18},
    {"id": "warp_dial", "type": "encoder", "pin": 19},
    {"id": "engine_led", "type": "led", "pin": 2},
    {"id": "nav_display", "type": "7segment", "pin": 4}
  ]
}
```

### Tactical Weapons Panel
```json
{
  "panel_id": "tactical_weapons",
  "station": "tactical",
  "name": "Weapons Control Panel",
  "devices": [
    {"id": "phaser_btn", "type": "button", "pin": 18},
    {"id": "torpedo_btn", "type": "button", "pin": 19},
    {"id": "target_lock", "type": "button", "pin": 21},
    {"id": "shield_power", "type": "potentiometer", "pin": 34},
    {"id": "weapon_power", "type": "potentiometer", "pin": 35},
    {"id": "alert_lights", "type": "rgb_strip", "pin": 5},
    {"id": "weapon_status", "type": "led", "pin": 2},
    {"id": "ammo_display", "type": "7segment", "pin": 4}
  ]
}
```

### Communications Panel
```json
{
  "panel_id": "comm_main",
  "station": "communication",
  "name": "Communications Panel",
  "devices": [
    {"id": "freq_dial", "type": "encoder", "pin": 18},
    {"id": "transmit_btn", "type": "button", "pin": 19},
    {"id": "emergency_btn", "type": "button", "pin": 21},
    {"id": "channel_sel", "type": "rotary_switch", "pin": 22},
    {"id": "signal_strength", "type": "led_bar", "pin": 23},
    {"id": "freq_display", "type": "7segment", "pin": 4},
    {"id": "status_led", "type": "led", "pin": 2}
  ]
}
```

### Engineering Power Panel
```json
{
  "panel_id": "engineering_power",
  "station": "logistics",
  "name": "Power Management Panel",
  "devices": [
    {"id": "engines_power", "type": "slider", "pin": 34},
    {"id": "shields_power", "type": "slider", "pin": 35},
    {"id": "weapons_power", "type": "slider", "pin": 32},
    {"id": "life_support_power", "type": "slider", "pin": 33},
    {"id": "repair_btn", "type": "button", "pin": 18},
    {"id": "emergency_power", "type": "button", "pin": 19},
    {"id": "power_display", "type": "7segment", "pin": 4},
    {"id": "system_leds", "type": "led_array", "pin": 5}
  ]
}
```

### Captain Console
```json
{
  "panel_id": "captain_console",
  "station": "captain",
  "name": "Captain's Console",
  "devices": [
    {"id": "red_alert", "type": "button", "pin": 18},
    {"id": "yellow_alert", "type": "button", "pin": 19},
    {"id": "all_stop", "type": "button", "pin": 21},
    {"id": "general_quarters", "type": "button", "pin": 22},
    {"id": "camera_select", "type": "rotary_switch", "pin": 23},
    {"id": "bridge_lights", "type": "rgb_strip", "pin": 5},
    {"id": "alert_klaxon", "type": "buzzer", "pin": 25}
  ]
}
```

## Communication Timing

### Heartbeat Schedule
- **Interval**: 10 seconds from ESP32 to server
- **Timeout**: 60 seconds server-side before disconnect
- **Retry**: 3 attempts before declaring panel offline

### Input Debouncing
- **Buttons**: 50ms default debounce
- **Encoders**: 10ms step debounce
- **Potentiometers**: 100ms change threshold

### Output Response Time
- **LEDs**: Immediate response (<10ms)
- **Displays**: 50ms update rate limit
- **RGB Strips**: 20ms minimum between updates
- **Buzzers**: Immediate activation

## Error Handling

### Connection Errors
```json
{
  "type": "panel_status",
  "data": {
    "panel_id": "helm_main",
    "status": "error",
    "errors": [
      "WiFi connection lost",
      "Server unreachable",
      "Invalid configuration received"
    ]
  }
}
```

### Device Errors
```json
{
  "type": "panel_status",
  "data": {
    "panel_id": "tactical_weapons",
    "status": "partial",
    "errors": [
      "Device phaser_btn pin 18 read failure",
      "RGB strip initialization failed",
      "ADC calibration out of range"
    ]
  }
}
```

### Recovery Procedures
1. **Connection Lost**: Automatic reconnection with exponential backoff
2. **Configuration Error**: Request fresh config from server
3. **Device Failure**: Disable faulty device, report error
4. **Watchdog Timeout**: Full system restart

## Security Considerations

### Network Security
- Wi-Fi WPA2 encryption required
- MAC address filtering recommended
- Isolated VLAN for panel network
- Regular credential rotation

### Data Validation
- Input range checking on ESP32
- Server-side validation of all inputs
- Configuration checksum verification
- Rate limiting for input events

### Physical Security
- Tamper detection on critical panels
- Secure mounting of devices
- Protected wiring and connectors
- Emergency shutdown capabilities

## Troubleshooting

### Common Issues

#### Panel Not Connecting
1. Verify Wi-Fi credentials in configuration
2. Check server IP address and port
3. Ensure panel is on same network as server
4. Check firewall settings on server

#### Input Not Responding
1. Verify pin configuration matches hardware
2. Check device wiring and connections
3. Test with multimeter for proper voltages
4. Review device configuration parameters

#### Output Not Working
1. Check power supply capacity
2. Verify correct pin assignments
3. Test device independently
4. Review command format and timing

#### Intermittent Disconnections
1. Check Wi-Fi signal strength
2. Verify power supply stability
3. Monitor for network congestion
4. Check for hardware interference

### Debug Commands

#### Panel Status Check
Send to specific panel:
```json
{
  "type": "panel_output",
  "data": {
    "panel_id": "helm_main",
    "device_id": "status_led",
    "command": "blink",
    "value": {"rate": 100, "duration": 2000}
  }
}
```

#### Configuration Refresh
Server can resend configuration:
```json
{
  "type": "panel_config",
  "data": { ... }
}
```

#### Force Reconnection
Panel can disconnect and reconnect to refresh state.

## Implementation Guidelines

### ESP32 Code Structure
1. Setup Wi-Fi connection
2. Initialize all configured devices
3. Establish TCP connection to server
4. Send heartbeat with panel ID
5. Parse and store configuration
6. Main loop: read inputs, send changes, process outputs
7. Handle disconnections gracefully

### Server Integration
1. Accept TCP connections on configured port
2. Maintain panel state and configuration
3. Route input events to appropriate station handlers
4. Send output commands based on game state
5. Monitor panel health and connectivity
6. Provide panel management API

### Testing Procedures
1. Unit test individual device drivers
2. Integration test full panel communication
3. Load test with multiple panels
4. Fault injection testing
5. Long-duration stability testing
6. Network interruption testing

## Performance Specifications

### Latency Requirements
- Input event transmission: <50ms
- Output command execution: <100ms
- Heartbeat response: <1000ms
- Configuration update: <5000ms

### Bandwidth Usage
- Typical panel: 1-5 KB/minute
- Peak usage (rapid inputs): 10-20 KB/minute
- Configuration transfer: 1-2 KB one-time
- Total network overhead: <1% of 802.11n capacity

### Reliability Targets
- Connection uptime: >99.9%
- Input accuracy: >99.99%
- Output response rate: >99.9%
- False disconnection rate: <0.1%