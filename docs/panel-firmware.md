# Celestial Bridge Simulator - Panel Firmware Documentation

## Overview

This document covers the ESP32 firmware architecture, configuration format, programming guide, and troubleshooting procedures for the Celestial Bridge Simulator panel system.

## Firmware Architecture

### Core Components

**Main Loop Structure**
- WiFi connection management with auto-reconnection
- TCP client for server communication
- JSON message parsing and generation
- Device polling and state management
- Watchdog timer for stability

**Device Abstraction Layer**
- InputDevice and OutputDevice base classes
- Polymorphic device handling
- Configuration-driven device instantiation
- Real-time input polling and output control

**Communication Protocol**
- JSON-over-TCP messaging
- Heartbeat system for connection monitoring
- Error reporting and status updates
- Bidirectional command/response handling

### Class Hierarchy

```
CelestialPanel (Main Controller)
├── InputDevice (Abstract Base)
│   ├── ButtonDevice
│   ├── PotentiometerDevice
│   ├── EncoderDevice
│   ├── RotarySwitchDevice
│   └── SliderDevice
└── OutputDevice (Abstract Base)
    ├── LEDDevice
    ├── RGBStripDevice
    ├── SevenSegmentDevice
    ├── LEDBarDevice
    └── BuzzerDevice
```

### Memory Management

**Static Allocation**
- Fixed-size device arrays (MAX_DEVICES = 32)
- Pre-allocated JSON document buffer (2KB)
- Static message buffers for efficiency

**Dynamic Allocation**
- Device objects created based on configuration
- RGB LED arrays allocated per strip configuration
- LED bar state arrays sized per device

**Memory Monitoring**
- Periodic heap size reporting
- Watchdog for memory leaks
- Error reporting on allocation failures

## Configuration Format

### Panel Configuration Structure

The server sends panel configuration in this JSON format:

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
          "invert": false,
          "smoothing": 0.1
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

### Device Configuration Parameters

**Button Configuration**
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
- `pullup`: Enable internal pull-up resistor
- `debounce_ms`: Debounce delay in milliseconds
- `press_type`: "momentary" or "toggle"

**Potentiometer Configuration**
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
- `min/max`: ADC value range mapping
- `deadzone`: Minimum change to trigger update
- `invert`: Reverse direction if true
- `smoothing`: Low-pass filter coefficient (0.0-1.0)

**LED Configuration**
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
- `pwm`: Enable PWM brightness control
- `max_brightness`: Maximum brightness value (0-255)
- `default_state`: Initial state on startup

**RGB Strip Configuration**
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
- `pixels`: Number of LEDs in strip
- `type`: LED chip type (WS2812B, WS2811, etc.)
- `max_brightness`: Global brightness limit

### Compile-Time Configuration

**Panel Identity**
- `PANEL_ID`: Unique panel identifier
- `STATION`: Station type (helm, tactical, communication, etc.)
- Set via PlatformIO build flags

**Network Defaults**
- Default WiFi credentials in source code
- Server address and port configuration
- Fallback values if config not received

**Hardware Limits**
- `MAX_DEVICES`: Maximum devices per panel (32)
- `JSON_BUFFER_SIZE`: Message buffer size (2KB)
- `HEARTBEAT_INTERVAL_MS`: Heartbeat frequency (10s)

## Programming Guide

### Setting Up Development Environment

**PlatformIO Installation**
1. Install Visual Studio Code
2. Install PlatformIO extension
3. Clone repository and open esp32-panels folder
4. Select appropriate environment for target panel

**Building and Uploading**
```bash
# Build for specific panel type
pio run -e helm_main

# Upload to connected ESP32
pio run -e helm_main -t upload

# Monitor serial output
pio device monitor
```

### Custom Panel Development

**1. Define Panel Configuration**
Create new environment in `platformio.ini`:
```ini
[env:custom_panel]
extends = env:esp32dev
build_flags =
    ${env:esp32dev.build_flags}
    -DPANEL_ID=\"custom_panel\"
    -DSTATION=\"custom\"
```

**2. Implement Custom Devices**
Extend base classes for specialized hardware:
```cpp
class CustomInputDevice : public InputDevice {
private:
    // Custom device state
    
public:
    bool begin(uint8_t pin, JsonObject config) override {
        // Initialize custom hardware
        return true;
    }
    
    float read() override {
        // Return current value
        return value;
    }
    
    bool hasChanged() override {
        // Return true if value changed
        return changed;
    }
    
    void update() override {
        // Poll hardware and update state
    }
    
    const char* getType() override {
        return "custom_input";
    }
};
```

**3. Register Custom Devices**
Modify `createInputDevice()` in CelestialPanel.cpp:
```cpp
InputDevice* CelestialPanel::createInputDevice(DeviceType type) {
    switch (type) {
        case DEVICE_CUSTOM: return new CustomInputDevice();
        // ... existing cases
        default: return nullptr;
    }
}
```

### Debugging Techniques

**Serial Output**
- Enable debug output with `Serial.println()`
- Monitor connection status and device states
- Log JSON message content for protocol debugging

**Status LED Patterns**
- Solid blink: Connected and operational
- Fast blink: Connecting to WiFi/server
- Multiple blinks: Error condition
- No blink: Offline or error

**Network Debugging**
```cpp
// Enable additional WiFi debugging
#define CORE_DEBUG_LEVEL 3

// Monitor TCP connection state
if (!tcpClient.connected()) {
    Serial.println("TCP disconnected, attempting reconnect");
}

// Log message parsing errors
if (error) {
    Serial.printf("JSON parse error: %s\n", error.c_str());
    Serial.printf("Message: %s\n", message.c_str());
}
```

### Performance Optimization

**Input Polling Optimization**
- Use hardware interrupts for critical inputs
- Implement efficient ADC sampling for analog inputs
- Minimize processing in main loop

**Memory Usage**
- Use static allocation where possible
- Monitor heap usage with `ESP.getFreeHeap()`
- Implement graceful degradation on low memory

**Network Efficiency**
- Send only changed values to reduce bandwidth
- Implement exponential backoff for reconnection
- Use keepalive to detect connection issues

## Configuration Management

### Network Configuration

**WiFi Setup**
- Default credentials compiled into firmware
- Runtime configuration via server messages
- WPS support for easy setup (optional)

**Server Discovery**
- Static IP configuration (default)
- mDNS discovery support (optional)
- Manual configuration via serial commands

### Device Calibration

**Analog Input Calibration**
```json
{
  "config": {
    "min": 50,
    "max": 970,
    "deadzone": 15,
    "calibration_points": [
      [0, 50], [25, 255], [50, 512], [75, 770], [100, 970]
    ]
  }
}
```

**Output Device Calibration**
- LED brightness curves
- RGB color correction
- 7-segment display mapping

### Over-the-Air Updates

**OTA Implementation**
```cpp
#include <ArduinoOTA.h>

void setupOTA() {
    ArduinoOTA.setHostname(PANEL_ID);
    ArduinoOTA.setPassword("celestial_ota");
    
    ArduinoOTA.onStart([]() {
        Serial.println("OTA Start");
    });
    
    ArduinoOTA.onEnd([]() {
        Serial.println("OTA End");
    });
    
    ArduinoOTA.onError([](ota_error_t error) {
        Serial.printf("OTA Error: %u\n", error);
    });
    
    ArduinoOTA.begin();
}
```

**Security Considerations**
- Password-protected OTA updates
- Firmware signature verification
- Rollback capability on failed updates

## Troubleshooting

### Common Issues and Solutions

**Panel Not Connecting to WiFi**
```cpp
// Check WiFi status
WiFi.status() != WL_CONNECTED

// Solutions:
// 1. Verify SSID and password
// 2. Check signal strength
// 3. Ensure WiFi network is 2.4GHz
// 4. Reset WiFi credentials and retry
```

**TCP Connection Failures**
```cpp
// Check TCP connection
!tcpClient.connected()

// Solutions:
// 1. Verify server IP address and port
// 2. Check firewall settings
// 3. Ensure server is running
// 4. Test with telnet from another device
```

**Device Not Responding**
```cpp
// Check device initialization
if (!inputDevices[i]->begin(pin, config)) {
    Serial.printf("Device %s failed to initialize\n", deviceId);
}

// Solutions:
// 1. Verify pin configuration
// 2. Check hardware connections
// 3. Test device independently
// 4. Review configuration parameters
```

**Memory Issues**
```cpp
// Monitor heap usage
Serial.printf("Free heap: %d bytes\n", ESP.getFreeHeap());

// Solutions:
// 1. Reduce JSON buffer size if possible
// 2. Implement dynamic device cleanup
// 3. Check for memory leaks
// 4. Use stack allocation for temporary objects
```

### Diagnostic Commands

**Serial Console Commands**
- `status`: Display panel status and device count
- `devices`: List all configured devices
- `network`: Show network configuration
- `memory`: Display memory usage
- `restart`: Soft restart the panel

**Remote Diagnostics**
```json
{
  "type": "panel_output",
  "data": {
    "panel_id": "helm_main",
    "device_id": "status_led",
    "command": "blink",
    "value": {"rate": 100, "duration": 5000}
  }
}
```

### Error Codes and Messages

**Connection Errors**
- `WiFi connection lost`: WiFi disconnected
- `Server unreachable`: TCP connection failed
- `Invalid configuration received`: Malformed config
- `JSON parse error`: Message parsing failed

**Device Errors**
- `Device initialization failed`: Hardware setup error
- `Pin configuration invalid`: GPIO pin conflict
- `ADC read failure`: Analog input error
- `PWM setup failed`: Output configuration error

**System Errors**
- `Watchdog timeout`: System hang detected
- `Memory allocation failed`: Insufficient RAM
- `Buffer overflow`: Message too large
- `Invalid device type`: Unknown device in config

### Performance Monitoring

**Key Metrics**
- Message processing time (<50ms target)
- Input update frequency (100Hz target)
- Memory usage trend
- Connection uptime percentage

**Monitoring Implementation**
```cpp
unsigned long startTime = millis();
// Process message
unsigned long processingTime = millis() - startTime;

if (processingTime > 50) {
    Serial.printf("Slow message processing: %lums\n", processingTime);
}
```

## Security Considerations

### Network Security
- WPA2 encryption for WiFi connections
- MAC address filtering (optional)
- Network isolation for panel subnet
- Regular credential rotation

### Firmware Security
- Code signing for OTA updates
- Secure boot implementation
- Debug output disable in production
- Protected configuration storage

### Physical Security
- Tamper detection for critical panels
- Secure mounting and cable management
- Emergency shutdown capabilities
- Access control for maintenance

## Best Practices

### Code Organization
- Separate hardware abstraction from application logic
- Use consistent naming conventions
- Comment complex algorithms and hardware interfaces
- Implement proper error handling

### Testing Procedures
1. Unit test individual device drivers
2. Integration test full panel communication
3. Stress test with rapid input changes
4. Long-duration stability testing
5. Network interruption recovery testing

### Documentation
- Maintain up-to-date pin assignments
- Document all configuration parameters
- Keep wiring diagrams current
- Record calibration procedures

### Deployment
- Test firmware on identical hardware
- Verify all devices before deployment
- Create installation checklists
- Establish update procedures

## Revision History

- **v1.0**: Initial firmware architecture
- **v1.1**: Added OTA update support
- **v1.2**: Enhanced error handling and diagnostics
- **v1.3**: Performance optimizations and debugging tools