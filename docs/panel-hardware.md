# Celestial Bridge Simulator - Panel Hardware Documentation

## Overview

This document provides detailed hardware specifications, circuit diagrams, and wiring guides for the ESP32-based physical control panels used in the Celestial Bridge Simulator.

## Hardware Requirements

### ESP32 Development Board
- **Recommended**: ESP32 DevKit V1 or similar
- **CPU**: Dual-core Tensilica LX6 microprocessor
- **Memory**: 520KB SRAM, 4MB Flash minimum
- **Wi-Fi**: 802.11 b/g/n
- **GPIO Pins**: 30+ available pins
- **ADC**: 12-bit resolution, multiple channels
- **PWM**: 16 channels
- **Power**: 3.3V operation, 5V tolerant inputs

### Power Supply
- **Input Voltage**: 5V DC via USB or external supply
- **Current Capacity**: 2A minimum per panel
- **Regulation**: Clean 3.3V and 5V rails
- **Protection**: Overcurrent and reverse polarity protection

### Interface Components

#### Input Devices

**Momentary Buttons**
- **Type**: SPST tactile switches
- **Voltage Rating**: 12V DC minimum
- **Current Rating**: 50mA minimum
- **Actuation Force**: 160-250gf
- **Travel**: 0.25mm-0.4mm
- **Debounce**: Hardware RC filter recommended

**Toggle Switches**
- **Type**: SPDT or DPDT
- **Voltage Rating**: 12V DC minimum
- **Current Rating**: 100mA minimum
- **Handle Options**: Paddle, toggle, or rocker
- **Mounting**: Panel mount with nut

**Potentiometers**
- **Type**: Linear or audio taper
- **Resistance**: 10kΩ typical
- **Power Rating**: 0.1W minimum
- **Linearity**: ±5%
- **Rotation**: 270° or 300°
- **Shaft**: 6mm D-shaft recommended

**Rotary Encoders**
- **Type**: Mechanical with detents
- **Resolution**: 20-24 steps per revolution
- **Electrical**: Quadrature output
- **Switch**: Integrated push button optional
- **Mounting**: Panel mount with threaded bushing

**Sliders**
- **Type**: Linear potentiometer
- **Travel**: 60mm-100mm
- **Resistance**: 10kΩ typical
- **Linearity**: ±3%
- **Mounting**: Panel mount with hardware

#### Output Devices

**LEDs**
- **Type**: 5mm or 3mm standard LEDs
- **Voltage**: 3.3V compatible
- **Current**: 20mA maximum
- **Colors**: Red, green, yellow, blue, white
- **Viewing Angle**: 30°-60°

**RGB LED Strips**
- **Type**: WS2812B or similar
- **Voltage**: 5V DC
- **Current**: 60mA per LED maximum
- **Protocol**: Single-wire data
- **Density**: 30-60 LEDs per meter

**7-Segment Displays**
- **Type**: Common cathode or MAX7219 driven
- **Size**: 0.56" or 0.8" character height
- **Color**: Red or green
- **Digits**: 4-digit modules typical
- **Interface**: SPI or parallel

**Buzzers**
- **Type**: Piezo or magnetic
- **Voltage**: 3.3V-5V compatible
- **Frequency**: 400Hz-4kHz range
- **Sound Level**: 85dB at 10cm
- **Mounting**: PCB mount or panel mount

## Circuit Diagrams

### Basic Input Circuit - Button with Debouncing

```
ESP32 GPIO Pin ----[10kΩ]---- 3.3V
        |
        +----[Switch]---- GND
        |
        +----[100nF]---- GND
```

### Potentiometer Circuit

```
3.3V ---- [Pot Pin 1]
          [Pot Pin 2 (Wiper)] ---- ESP32 ADC Pin
GND  ---- [Pot Pin 3]
```

### LED Output Circuit

```
ESP32 GPIO Pin ----[220Ω]---- LED Anode
                              LED Cathode ---- GND
```

### RGB LED Strip Circuit

```
5V ---- RGB Strip VCC
ESP32 GPIO Pin ---- RGB Strip Data In
GND ---- RGB Strip GND

Note: Add 470Ω resistor between GPIO and Data In
      Add 1000µF capacitor between VCC and GND
```

### 7-Segment Display (MAX7219)

```
ESP32 Pin 18 (SCK) ---- MAX7219 CLK
ESP32 Pin 19 (MISO) --- (Not Connected)
ESP32 Pin 23 (MOSI) --- MAX7219 DIN
ESP32 Pin 5 (CS) ------ MAX7219 CS

5V ---- MAX7219 VCC
GND --- MAX7219 GND
```

### Buzzer Circuit

```
ESP32 GPIO Pin ---- [100Ω] ---- Buzzer Positive
                                Buzzer Negative ---- GND
```

## Panel Layouts

### Helm Main Panel

**Physical Layout:**
```
[Throttle Pot]    [Pitch Pot]     [Engine LED]
[Rudder Pot]      [Roll Pot]      [Nav Display]
[Autopilot Btn]   [Warp Encoder]  [Status LED]
```

**Pin Assignments:**
- GPIO 34: Throttle Potentiometer (ADC)
- GPIO 35: Rudder Potentiometer (ADC)
- GPIO 32: Pitch Potentiometer (ADC)
- GPIO 33: Roll Potentiometer (ADC)
- GPIO 18: Autopilot Button (Digital Input)
- GPIO 19: Warp Encoder A (Digital Input)
- GPIO 21: Warp Encoder B (Digital Input)
- GPIO 2: Engine Status LED (PWM Output)
- GPIO 4: Navigation Display CS (SPI)
- GPIO 22: Status LED (Digital Output)

### Tactical Weapons Panel

**Physical Layout:**
```
[Phaser Btn]      [Target Lock]    [Alert Lights]
[Torpedo Btn]     [Shield Power]   [Weapon Status]
[Power Sliders]   [Ammo Display]   [System LEDs]
```

**Pin Assignments:**
- GPIO 18: Phaser Fire Button
- GPIO 19: Torpedo Fire Button
- GPIO 21: Target Lock Button
- GPIO 34: Shield Power Potentiometer
- GPIO 35: Weapon Power Potentiometer
- GPIO 5: Alert RGB Strip
- GPIO 2: Weapon Status LED
- GPIO 4: Ammo Display CS
- GPIO 22-25: System Status LEDs

### Communications Panel

**Physical Layout:**
```
[Freq Encoder]    [Channel Select] [Signal Bar]
[Transmit Btn]    [Emergency Btn]  [Freq Display]
[Volume Slider]   [Status LEDs]    [Audio Jack]
```

**Pin Assignments:**
- GPIO 18: Frequency Encoder A
- GPIO 19: Frequency Encoder B
- GPIO 21: Transmit Button
- GPIO 22: Emergency Button
- GPIO 34: Volume Slider
- GPIO 5: Signal Strength LED Bar
- GPIO 4: Frequency Display CS
- GPIO 2: Status LED

### Engineering Power Panel

**Physical Layout:**
```
[Engine Power]    [Shield Power]   [System Display]
[Weapon Power]    [Life Support]   [Status LEDs]
[Repair Btn]      [Emergency Btn]  [Power Meter]
```

**Pin Assignments:**
- GPIO 34: Engine Power Slider
- GPIO 35: Shield Power Slider
- GPIO 32: Weapon Power Slider
- GPIO 33: Life Support Slider
- GPIO 18: Repair Button
- GPIO 19: Emergency Power Button
- GPIO 4: System Display CS
- GPIO 5: Status LED Array

### Captain Console

**Physical Layout:**
```
[Red Alert]       [Yellow Alert]   [Bridge Lights]
[All Stop]        [Gen Quarters]   [Alert Klaxon]
[Camera Select]   [Override Keys]  [Status Panel]
```

**Pin Assignments:**
- GPIO 18: Red Alert Button
- GPIO 19: Yellow Alert Button
- GPIO 21: All Stop Button
- GPIO 22: General Quarters Button
- GPIO 34: Camera Select Switch
- GPIO 5: Bridge RGB Lighting
- GPIO 25: Alert Klaxon
- GPIO 2-4: Override Key LEDs

## Wiring Standards

### Cable Specifications
- **Signal Wires**: 22-24 AWG stranded copper
- **Power Wires**: 18-20 AWG stranded copper
- **Shielding**: Required for analog signals >12 inches
- **Connectors**: JST-XH or Molex KK series recommended
- **Colors**: Follow standard color codes

### Color Coding
- **Power (+3.3V)**: Red
- **Power (+5V)**: Orange
- **Ground**: Black
- **Digital Signals**: Blue
- **Analog Signals**: Green
- **SPI Clock**: Yellow
- **SPI Data**: White
- **I2C SDA**: Purple
- **I2C SCL**: Gray

### Panel Interconnects
- **Backbone**: CAT6 Ethernet cable for power and data
- **Local Signals**: Ribbon cable or individual wires
- **Strain Relief**: Required at all connection points
- **Labeling**: Clear identification on both ends

## Assembly Instructions

### PCB Layout Guidelines
1. **Power Planes**: Separate analog and digital power
2. **Ground Planes**: Continuous ground plane recommended
3. **Bypass Capacitors**: 100nF ceramic near each IC
4. **Pull-up Resistors**: 10kΩ for all digital inputs
5. **Protection**: TVS diodes on external connections

### Mechanical Assembly
1. **Panel Cutting**: Use CNC or laser cutting for precision
2. **Component Mounting**: Secure all panel-mount components
3. **Wire Routing**: Avoid sharp bends and pinch points
4. **Connector Placement**: Accessible for maintenance
5. **Strain Relief**: Use appropriate boots and clamps

### Testing Procedures
1. **Continuity Test**: Verify all connections
2. **Power Test**: Check voltage levels and regulation
3. **Input Test**: Verify all buttons and controls
4. **Output Test**: Check all LEDs and displays
5. **Communication Test**: Verify ESP32 connectivity

## Troubleshooting

### Common Issues

**No Power**
- Check power supply connections
- Verify voltage levels with multimeter
- Check for short circuits
- Inspect fuses or protection circuits

**Input Not Working**
- Verify GPIO pin configuration
- Check pull-up resistors
- Test switch continuity
- Verify debouncing circuit

**Output Not Responding**
- Check current limiting resistors
- Verify GPIO pin mode
- Test component independently
- Check power supply capacity

**Intermittent Operation**
- Inspect solder joints
- Check connector seating
- Verify cable integrity
- Test under thermal stress

**Communication Failure**
- Verify network settings
- Check Wi-Fi signal strength
- Test TCP connectivity
- Monitor serial debug output

### Diagnostic Tools
- **Multimeter**: Voltage and continuity testing
- **Oscilloscope**: Signal timing and integrity
- **Logic Analyzer**: Digital signal debugging
- **Network Analyzer**: Wi-Fi troubleshooting
- **Thermal Camera**: Heat distribution analysis

## Safety Considerations

### Electrical Safety
- **Isolation**: Maintain proper isolation between circuits
- **Grounding**: Ensure proper grounding of all metal parts
- **Protection**: Use appropriate fuses and protection
- **Testing**: Always test with proper safety equipment

### Mechanical Safety
- **Sharp Edges**: File or deburr all cut edges
- **Pinch Points**: Avoid exposed moving parts
- **Secure Mounting**: Ensure all components are properly secured
- **Emergency Stop**: Provide accessible emergency shutoffs

### Environmental
- **Temperature**: Operating range 0°C to +70°C
- **Humidity**: <90% non-condensing
- **Vibration**: Secure mounting to minimize stress
- **ESD Protection**: Use anti-static procedures

## Component Sourcing

### Recommended Suppliers
- **Digikey**: Electronic components and connectors
- **Mouser**: Semiconductors and passive components
- **Adafruit**: Sensors and development boards
- **SparkFun**: Prototyping and hobbyist components
- **Amazon**: Basic components and tools

### Bill of Materials Template
- **ESP32 DevKit**: 1x per panel
- **Resistors**: Assorted 1/4W carbon film
- **Capacitors**: Ceramic and electrolytic assortment
- **LEDs**: Assorted colors and sizes
- **Switches**: Panel-mount momentary and toggle
- **Potentiometers**: Linear 10kΩ rotary and slider
- **Connectors**: JST-XH series assorted
- **Wire**: 22AWG stranded, multiple colors
- **PCB**: Custom or prototyping board

### Cost Estimation
- **Basic Panel**: $50-75 per panel
- **Complex Panel**: $100-150 per panel
- **Enclosure**: $25-50 per panel
- **Assembly Labor**: 4-8 hours per panel
- **Testing Time**: 1-2 hours per panel

## Revision History

- **v1.0**: Initial hardware specification
- **v1.1**: Added safety considerations and troubleshooting
- **v1.2**: Updated component recommendations and sourcing