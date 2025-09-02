# Celestial ESP32 Panel System

A comprehensive ESP32-based hardware control system for the Celestial Bridge Simulator. This system provides physical controls and displays for spaceship bridge stations, communicating with the Go backend via TCP over Wi-Fi.

## Overview

The ESP32 Panel System enables tactile control of the Celestial Bridge Simulator through physical hardware panels. Each panel contains buttons, switches, potentiometers, LEDs, displays, and other interface elements that provide an authentic spaceship bridge experience.

### Key Features

- **Real-time Communication**: TCP-based JSON protocol with <50ms response times
- **Modular Design**: Support for multiple panel types with different device configurations
- **Hot Configuration**: Dynamic device setup from backend server
- **Robust Networking**: Auto-reconnection and error recovery
- **Comprehensive I/O**: Support for buttons, potentiometers, encoders, LEDs, RGB strips, displays, and buzzers
- **Over-the-Air Updates**: Remote firmware updates for easy maintenance

## Supported Panel Types

### Helm Main Panel (`helm_main`)
- Throttle, rudder, pitch, and roll controls
- Autopilot and warp drive controls
- Navigation displays and status indicators

### Tactical Weapons Panel (`tactical_weapons`)
- Phaser and torpedo firing controls
- Shield and weapon power management
- Alert lighting and ammunition displays

### Communications Panel (`comm_main`)
- Frequency control and channel selection
- Transmission controls and signal strength indicators
- Emergency broadcast capabilities

### Engineering Power Panel (`engineering_power`)
- Power allocation sliders for ship systems
- Repair controls and system status displays
- Emergency power management

### Captain Console (`captain_console`)
- Alert condition controls (red/yellow alert)
- Camera selection and bridge lighting
- Emergency override capabilities

## Hardware Requirements

### ESP32 Development Board
- ESP32 DevKit V1 or compatible
- Minimum 4MB Flash memory
- Wi-Fi 802.11 b/g/n capability
- 30+ GPIO pins available

### Power Supply
- 5V DC, 2A minimum per panel
- Clean power regulation for analog inputs
- Overcurrent protection recommended

### Interface Components
- Momentary and toggle switches
- Linear potentiometers and sliders
- Rotary encoders with optional push buttons
- LEDs (single color and RGB strips)
- 7-segment displays or OLED screens
- Piezo buzzers for audio feedback

## Quick Start

### 1. Hardware Setup

Connect your ESP32 and interface components according to the panel-specific wiring diagrams in [`docs/panel-hardware.md`](docs/panel-hardware.md).

### 2. Install Development Environment

**Option A: PlatformIO (Recommended)**
```bash
# Install PlatformIO Core
pip install platformio

# Clone repository
git clone <repository-url>
cd Celestial/esp32-panels
```

**Option B: Arduino IDE**
```bash
# Install Arduino IDE 1.8.19+
# Add ESP32 board package
# Install required libraries (see platformio.ini)
```

### 3. Build and Upload Firmware

**Using Build Script (Recommended)**
```bash
# Build and upload helm panel firmware
./build.sh -u helm_main

# Build all panel types
./build.sh --all

# Build, upload, and monitor
./build.sh -cum tactical_weapons
```

**Using PlatformIO Directly**
```bash
# Build specific panel
pio run -e helm_main

# Upload to connected ESP32
pio run -e helm_main -t upload

# Monitor serial output
pio device monitor
```

### 4. Configure Network

The firmware includes default network settings:
- **WiFi SSID**: `Celestial_Bridge`
- **WiFi Password**: `starship2024`
- **Server Host**: `192.168.1.100`
- **Server Port**: `8081`

These can be updated in the source code or configured dynamically by the backend server.

### 5. Test Installation

```bash
# Test panel connectivity
python3 test_panel.py --panel helm_main

# Run comprehensive tests
python3 test_panel.py --all

# Stress test specific panel
python3 test_panel.py --panel tactical_weapons --stress 60
```

## Project Structure

```
esp32-panels/
├── src/                    # Source code
│   ├── main.cpp           # Main Arduino sketch
│   ├── CelestialPanel.h   # Core class definitions
│   └── CelestialPanel.cpp # Core implementation
├── lib/                   # Custom libraries
├── examples/              # Panel-specific examples
│   ├── helm_main.cpp      # Helm panel example
│   ├── tactical_weapons.cpp
│   └── ...
├── docs/                  # Documentation (shared with main project)
├── platformio.ini         # PlatformIO configuration
├── build.sh              # Build automation script
├── test_panel.py         # Testing and diagnostics
└── README.md             # This file
```

## Device Types and Configuration

### Input Devices

**Button**
```json
{
  "id": "fire_button",
  "type": "button", 
  "pin": 18,
  "config": {
    "pullup": true,
    "debounce_ms": 50
  }
}
```

**Potentiometer**
```json
{
  "id": "throttle",
  "type": "potentiometer",
  "pin": 34,
  "config": {
    "min": 0,
    "max": 1023,
    "deadzone": 10,
    "smoothing": 0.1
  }
}
```

**Rotary Encoder**
```json
{
  "id": "frequency_dial",
  "type": "encoder",
  "pin": 19,
  "config": {
    "steps": 100,
    "direction": "clockwise",
    "button_pin": 20
  }
}
```

### Output Devices

**LED**
```json
{
  "id": "status_led",
  "type": "led",
  "pin": 2,
  "config": {
    "pwm": true,
    "max_brightness": 255
  }
}
```

**RGB LED Strip**
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

**7-Segment Display**
```json
{
  "id": "nav_display",
  "type": "7segment",
  "pin": 4,
  "config": {
    "digits": 4,
    "driver": "MAX7219"
  }
}
```

## Communication Protocol

The ESP32 panels communicate with the backend server using JSON messages over TCP:

### Panel → Server Messages

**Heartbeat**
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

**Input Event**
```json
{
  "type": "panel_input",
  "timestamp": "2023-12-01T12:00:00Z", 
  "data": {
    "panel_id": "helm_main",
    "device_id": "throttle",
    "value": 0.75,
    "context": {
      "raw_value": 768,
      "calibrated": true
    }
  }
}
```

### Server → Panel Messages

**Configuration**
```json
{
  "type": "panel_config",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "panel_id": "helm_main",
    "devices": [...],
    "network": {...}
  }
}
```

**Output Command**
```json
{
  "type": "panel_output",
  "timestamp": "2023-12-01T12:00:00Z",
  "data": {
    "panel_id": "helm_main", 
    "device_id": "engine_led",
    "command": "set_brightness",
    "value": 128
  }
}
```

## Development Guide

### Adding Custom Devices

1. **Define Device Class**
```cpp
class CustomDevice : public InputDevice {
public:
    bool begin(uint8_t pin, JsonObject config) override;
    float read() override;
    bool hasChanged() override;
    void update() override;
    const char* getType() override { return "custom"; }
};
```

2. **Register Device Type**
```cpp
// In CelestialPanel.cpp
InputDevice* CelestialPanel::createInputDevice(DeviceType type) {
    switch (type) {
        case DEVICE_CUSTOM: return new CustomDevice();
        // ... existing cases
    }
}
```

3. **Update Configuration**
Add device definitions to backend panel configurations.

### Custom Panel Types

1. **Create PlatformIO Environment**
```ini
[env:custom_panel]
extends = env:esp32dev
build_flags =
    ${env:esp32dev.build_flags}
    -DPANEL_ID=\"custom_panel\"
    -DSTATION=\"custom\"
```

2. **Define Pin Mappings**
Create hardware-specific pin assignments in your panel configuration.

3. **Test Configuration**
Use the test utility to verify panel functionality.

## Troubleshooting

### Connection Issues

**WiFi Connection Fails**
- Verify 2.4GHz network (ESP32 doesn't support 5GHz)
- Check SSID and password accuracy
- Ensure adequate signal strength at panel location

**Server Connection Fails**
- Verify backend server is running on correct port
- Check firewall settings allow TCP connections
- Test connectivity with `telnet <server_ip> 8081`

### Device Issues

**Input Not Responding**
- Check GPIO pin configuration and wiring
- Verify pull-up resistors for digital inputs
- Test hardware with multimeter
- Monitor serial output for debug information

**Output Not Working**
- Verify power supply capacity and voltage levels
- Check current limiting resistors for LEDs
- Test devices independently of ESP32
- Review command format and timing

### Performance Issues

**Slow Response Times**
- Monitor processing times in serial output
- Check network latency and packet loss
- Optimize polling frequencies
- Remove blocking operations from main loop

**Memory Issues**
- Monitor heap usage with `ESP.getFreeHeap()`
- Reduce JSON buffer sizes if needed
- Check for memory leaks in device drivers
- Use static allocation where possible

## Testing and Validation

### Automated Testing

```bash
# Test specific panel
python3 test_panel.py --panel helm_main

# Test all panels
python3 test_panel.py --all

# Stress test with rapid inputs
python3 test_panel.py --panel tactical_weapons --stress 120

# Test specific device
python3 test_panel.py --input-test helm_main throttle
python3 test_panel.py --output-test helm_main engine_led
```

### Manual Testing

1. **Visual Inspection**: Check all connections and component mounting
2. **Power Test**: Verify voltage levels and current consumption
3. **Input Test**: Actuate all controls and verify response
4. **Output Test**: Test all LEDs, displays, and audio devices
5. **Integration Test**: Verify communication with backend server

### Performance Benchmarks

- **Input Response**: <50ms from physical input to server message
- **Output Response**: <100ms from server command to device activation
- **Connection Uptime**: >99.9% during normal operation
- **Error Rate**: <0.1% message transmission failures

## Safety and Compliance

### Electrical Safety
- Use proper voltage levels for all components
- Install appropriate fuses and protection circuits
- Ensure proper grounding of all metal parts
- Follow ESD precautions during assembly

### Operational Safety
- Test emergency stop functionality
- Verify fail-safe behavior on power loss
- Document emergency procedures
- Provide adequate ventilation for electronics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with appropriate tests
4. Update documentation as needed
5. Submit a pull request

### Code Style
- Follow existing naming conventions
- Add comments for complex algorithms
- Include error handling for all operations
- Test on actual hardware before submitting

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Support

- **Documentation**: See [`docs/`](../docs/) directory for detailed guides
- **Issues**: Report bugs and feature requests via GitHub issues
- **Hardware Guide**: [`docs/panel-hardware.md`](../docs/panel-hardware.md)
- **Firmware Guide**: [`docs/panel-firmware.md`](../docs/panel-firmware.md)
- **Installation Guide**: [`docs/panel-installation.md`](../docs/panel-installation.md)

## Revision History

- **v1.0.0**: Initial ESP32 panel system implementation
- **v1.1.0**: Added RGB LED strip and display support
- **v1.2.0**: Enhanced error handling and diagnostics
- **v1.3.0**: Over-the-air update capability and stress testing