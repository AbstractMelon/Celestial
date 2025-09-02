# Celestial Bridge Simulator - Panel Installation Guide

## Overview

This guide provides step-by-step instructions for installing, configuring, and testing ESP32-based control panels for the Celestial Bridge Simulator. Follow these procedures to ensure proper operation and integration with the backend system.

## Prerequisites

### Hardware Requirements
- ESP32 development boards (one per panel)
- Assembled control panels with mounted components
- USB cables for programming and power
- Computer with Arduino IDE or PlatformIO
- Multimeter for testing
- Network router with 2.4GHz WiFi capability

### Software Requirements
- PlatformIO Core or Arduino IDE
- Git for repository access
- Serial terminal application
- Network scanning tools (optional)

### Network Infrastructure
- WiFi network with internet access
- Static IP for Celestial backend server
- Adequate bandwidth for real-time communication
- Network access to ESP32 devices

## Pre-Installation Checklist

### Panel Hardware Verification

**Visual Inspection**
1. Check all solder joints for quality and shorts
2. Verify component orientation (LEDs, ICs, connectors)
3. Ensure proper mounting of panel components
4. Inspect wiring for damage or stress points
5. Confirm all connectors are properly seated

**Electrical Testing**
1. **Power Supply Test**
   - Measure 3.3V and 5V rails with multimeter
   - Check current draw under load
   - Verify clean power without excessive ripple

2. **Continuity Test**
   - Test all button and switch connections
   - Verify potentiometer wiper connections
   - Check LED and display wiring

3. **Input Device Test**
   - Test button actuation and release
   - Verify potentiometer smooth operation
   - Check encoder rotation and detents

### Network Preparation

**WiFi Network Setup**
- SSID: `Celestial_Bridge`
- Password: `starship2024`
- Frequency: 2.4GHz (ESP32 compatible)
- Security: WPA2-PSK minimum

**Server Configuration**
- Backend server running on port 8081
- Panel protocol documentation accessible
- Network firewall configured for ESP32 access

## Firmware Installation

### Environment Setup

**PlatformIO Installation**
1. Install Visual Studio Code
2. Add PlatformIO extension
3. Clone Celestial repository
4. Navigate to `esp32-panels` directory

**Arduino IDE Alternative**
1. Install Arduino IDE 1.8.19 or newer
2. Add ESP32 board package
3. Install required libraries:
   - ArduinoJson 6.21.4+
   - FastLED 3.6.0+
   - Adafruit GFX Library
   - Adafruit SSD1306

### Panel-Specific Compilation

**Select Target Panel**
Choose appropriate build environment:
- `helm_main`: Helm control panel
- `tactical_weapons`: Tactical weapons station
- `comm_main`: Communications panel
- `engineering_power`: Engineering/logistics panel
- `captain_console`: Captain's console

**Build and Upload**
```bash
# Using PlatformIO
cd Celestial/esp32-panels
pio run -e helm_main
pio run -e helm_main -t upload

# Monitor serial output
pio device monitor
```

**Arduino IDE Steps**
1. Open `src/main.cpp` in Arduino IDE
2. Set board to "ESP32 Dev Module"
3. Configure build flags for target panel
4. Select correct COM port
5. Upload firmware

### Initial Configuration

**Serial Monitor Setup**
- Baud rate: 115200
- Line ending: Both NL & CR
- Connect immediately after upload

**Expected Boot Sequence**
```
=== Celestial Bridge Panel System ===
Panel ID: helm_main
Station: helm
Version: 1.0.0
ESP32 Chip ID: 123456789ABCDEF0
Free Heap: 298234 bytes
=====================================
Connecting to WiFi: Celestial_Bridge
WiFi connected: 192.168.1.105
Connecting to server: 192.168.1.100:8081
TCP connected
Heartbeat sent: helm_main
Panel system ready!
```

## Network Configuration

### WiFi Connection Verification

**Check Connection Status**
1. Monitor serial output for WiFi connection
2. Verify IP address assignment
3. Test ping from another device
4. Check signal strength if connection issues

**Troubleshooting WiFi Issues**
- Ensure 2.4GHz network (ESP32 doesn't support 5GHz)
- Check password accuracy (case sensitive)
- Verify network visibility from panel location
- Test with mobile hotspot if network issues persist

### Server Communication Test

**TCP Connection Verification**
1. Confirm backend server is running
2. Check firewall rules allow port 8081
3. Verify server IP address in firmware
4. Test telnet connection from development machine

**Protocol Testing**
```bash
# Test server connection manually
telnet 192.168.1.100 8081

# Send test heartbeat (after connection)
{"type":"panel_heartbeat","timestamp":"2023-12-01T12:00:00Z","data":{"client_id":"test_panel","ping":"2023-12-01T12:00:00Z"}}
```

## Panel Configuration

### Server-Side Setup

**Panel Registration**
1. Add panel definition to backend configuration
2. Define device mappings for panel type
3. Set station assignment and permissions
4. Configure network parameters

**Device Configuration Example**
```json
{
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
  ]
}
```

### Dynamic Configuration

**Configuration Reception**
1. Panel sends heartbeat with ID
2. Server responds with configuration
3. Panel initializes devices based on config
4. Status message confirms setup completion

**Verification Steps**
1. Monitor serial output for "Configuration complete"
2. Check device count matches expected
3. Verify no initialization errors
4. Test input/output functionality

## Device Testing

### Input Device Verification

**Button Testing**
1. Press each button and verify serial output
2. Check for proper debouncing (no multiple triggers)
3. Verify button LED illumination if equipped
4. Test button release detection

**Potentiometer/Slider Testing**
1. Rotate/slide controls through full range
2. Verify smooth value changes without jumps
3. Check deadzone operation (no noise)
4. Test center detents if equipped

**Encoder Testing**
1. Rotate encoder in both directions
2. Verify step counting accuracy
3. Test encoder button if equipped
4. Check for proper direction sensing

### Output Device Verification

**LED Testing**
1. Send brightness commands via server
2. Test on/off state changes
3. Verify PWM dimming if enabled
4. Test blink patterns and timing

**RGB Strip Testing**
1. Set individual pixel colors
2. Test solid color fill
3. Verify brightness control
4. Check color accuracy and uniformity

**Display Testing**
1. Send text/numeric data
2. Verify character display accuracy
3. Test brightness adjustment
4. Check decimal point control

## System Integration Testing

### End-to-End Communication

**Input Event Flow**
1. Actuate physical control
2. Verify ESP32 detects change
3. Check message transmission to server
4. Confirm server receives and processes event

**Output Command Flow**
1. Send command from server/frontend
2. Verify ESP32 receives message
3. Check device responds correctly
4. Confirm visual/audio feedback

### Performance Testing

**Response Time Measurement**
- Input response: <50ms target
- Output response: <100ms target
- Heartbeat interval: 10 second nominal
- Reconnection time: <5 seconds

**Load Testing**
1. Rapid input changes (stress test)
2. Multiple simultaneous outputs
3. Extended operation (8+ hours)
4. Network interruption recovery

## Troubleshooting Procedures

### Connection Issues

**WiFi Connection Failures**
```
Symptoms: Panel cannot connect to WiFi
Solutions:
1. Verify network SSID and password
2. Check 2.4GHz network availability
3. Test signal strength at panel location
4. Reset WiFi credentials and retry
```

**Server Connection Failures**
```
Symptoms: WiFi connected but no server communication
Solutions:
1. Verify server IP address and port
2. Check backend server is running
3. Test firewall rules
4. Confirm network routing
```

### Device Malfunctions

**Input Not Responding**
```
Symptoms: Button press or control movement not detected
Diagnostics:
1. Check serial monitor for input events
2. Verify GPIO pin configuration
3. Test hardware with multimeter
4. Check pull-up resistor configuration

Solutions:
1. Verify wiring connections
2. Replace faulty component
3. Update pin configuration
4. Check for GPIO conflicts
```

**Output Not Working**
```
Symptoms: LEDs not lighting, displays not showing data
Diagnostics:
1. Check power supply voltages
2. Verify GPIO pin modes
3. Test component independently
4. Monitor command reception

Solutions:
1. Check current limiting resistors
2. Verify power supply capacity
3. Replace faulty components
4. Update configuration parameters
```

### Performance Issues

**Slow Response Times**
```
Symptoms: Delayed input recognition or output response
Diagnostics:
1. Monitor processing time in serial output
2. Check network latency
3. Verify loop timing
4. Monitor memory usage

Solutions:
1. Optimize polling frequency
2. Reduce JSON message size
3. Implement hardware interrupts
4. Check for blocking operations
```

**Intermittent Operation**
```
Symptoms: Occasional missed inputs or outputs
Diagnostics:
1. Check power supply stability
2. Monitor WiFi signal strength
3. Verify connection uptime
4. Test thermal conditions

Solutions:
1. Improve power supply regulation
2. Relocate WiFi router or panel
3. Add connection monitoring
4. Improve ventilation/cooling
```

## Calibration Procedures

### Analog Input Calibration

**Potentiometer/Slider Calibration**
1. **Record Minimum Value**
   - Move control to minimum position
   - Record ADC reading via serial monitor
   - Update configuration min value

2. **Record Maximum Value**
   - Move control to maximum position  
   - Record ADC reading
   - Update configuration max value

3. **Set Deadzone**
   - Determine noise level when stationary
   - Set deadzone 2-3x noise level
   - Test for stable operation

4. **Verify Linearity**
   - Test control at 25%, 50%, 75% positions
   - Verify proportional output values
   - Adjust calibration points if needed

### Output Device Calibration

**LED Brightness Calibration**
1. Set LED to 25%, 50%, 75%, 100% brightness
2. Verify visual brightness progression
3. Adjust PWM values for linear perception
4. Test in operational lighting conditions

**RGB Color Calibration**
1. Set pure red, green, blue colors
2. Verify color accuracy with reference
3. Adjust color correction values
4. Test white balance across brightness range

## Maintenance Procedures

### Regular Maintenance

**Weekly Checks**
- Visual inspection for loose connections
- Test all input devices for proper operation
- Verify all output devices function correctly
- Check WiFi connection stability

**Monthly Procedures**
- Update firmware if new version available
- Backup panel configurations
- Clean dust from electronics enclosures
- Tighten mechanical connections

### Preventive Maintenance

**Environmental Monitoring**
- Check operating temperature range
- Monitor humidity levels
- Verify adequate ventilation
- Inspect for dust accumulation

**Electrical System**
- Measure power supply voltages
- Check current consumption trends
- Inspect cables for wear
- Test emergency shutdown procedures

## Documentation Requirements

### Installation Records

**Panel Documentation**
- Serial number and MAC address
- Firmware version and upload date
- Configuration file version
- Initial test results and calibration data

**Network Configuration**
- IP address assignment
- WiFi signal strength measurement
- Network speed test results
- Server connectivity verification

### Maintenance Logs

**Service Records**
- Date and type of maintenance performed
- Any issues discovered and resolution
- Firmware updates and configuration changes
- Performance metrics and trends

## Safety Considerations

### Electrical Safety
- Always disconnect power before hardware changes
- Use proper ESD precautions when handling ESP32
- Verify voltage levels before connecting devices
- Install proper fuses and protection circuits

### Operational Safety  
- Test emergency stop functionality
- Verify all controls operate in correct direction
- Check for proper fail-safe behavior
- Document emergency procedures

### Network Security
- Change default WiFi passwords
- Use WPA2 or better encryption
- Implement MAC address filtering if required
- Monitor for unauthorized access attempts

## Revision History

- **v1.0**: Initial installation procedures
- **v1.1**: Added calibration and troubleshooting sections  
- **v1.2**: Enhanced testing procedures and safety guidelines
- **v1.3**: Updated for latest firmware features