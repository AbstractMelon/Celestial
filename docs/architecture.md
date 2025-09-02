# Celestial Bridge Simulator - Architecture Documentation

## System Overview

The Celestial Bridge Simulator is a distributed real-time system designed to simulate a spaceship bridge experience. The architecture consists of three main components that work together to provide an immersive multi-station bridge simulation.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ESP32 Panels  │    │   Go Backend    │    │ Godot Frontend  │
│   (Hardware)    │◄──►│   (Authority)   │◄──►│   (Display)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
     TCP/JSON              WebSocket/HTTP           Station UIs
    Panel Protocol          Backend API            & 3D Viewscreen
```

## Core Principles

### Authoritative Server Architecture
- Go backend serves as the single source of truth
- All game state, physics, and logic reside on the server
- Clients are presentation layers that display state and send input
- No client-side game logic to ensure consistency

### Real-Time Performance
- 60 FPS universe simulation
- Sub-50ms input response times
- Efficient state broadcasting with partial updates
- Role-based data filtering to minimize bandwidth

### Modular Design
- Clear separation of concerns between components
- Station-specific functionality isolation
- Pluggable mission scripting system
- Hardware abstraction for panels

## Component Architecture

### Go Backend Server

#### Core Modules

```
backend/
├── main.go                 # Application entry point
├── config/                 # Configuration management
├── server/                 # HTTP/WebSocket/TCP servers
├── universe/               # Physics and object simulation
├── networking/             # Message protocols and types
├── stations/               # Station management and filtering
├── scripting/              # Lua mission engine
├── panels/                 # ESP32 panel management
└── utils/                  # Math and utility functions
```

#### Universe System
The universe module manages the complete 3D simulation:

- **Physics Engine**: Real-time collision detection, gravity, movement
- **Object Management**: Ships, planets, stations, effects, projectiles
- **Visual Effects**: Explosions, phaser beams, particle effects
- **Time Control**: Variable time acceleration, pause/resume

#### Station System
Role-based access control and data filtering:

- **Helm**: Navigation, movement, autopilot, time acceleration
- **Tactical**: Weapons, shields, targeting, combat systems  
- **Communication**: Ship-to-ship comms, alerts, emergency broadcasts
- **Logistics**: Power management, repairs, crew assignments
- **Captain**: Emergency controls, ship-wide systems, camera control
- **Game Master**: Admin access, object spawning, mission control

#### Networking Layer
Multi-protocol communication system:

- **WebSocket Server**: Real-time bidirectional communication with frontends
- **TCP Server**: Reliable communication with ESP32 panels
- **HTTP API**: RESTful endpoints for configuration and status
- **Message Protocol**: JSON-based structured communication

#### Scripting Engine
Lua-based mission system:

- **Mission API**: Comprehensive universe control functions
- **Event System**: Trigger-based reactive programming
- **Object Manipulation**: Create, modify, destroy universe objects
- **Communication Integration**: Send messages, control alerts
- **State Management**: Mission progress tracking

### Godot Frontend

#### Station Interfaces
Each station provides specialized UI for its role:

- **3D Viewscreen**: Primary external view with real-time rendering
- **Station Controls**: Role-specific interface elements
- **HUD Overlays**: Status indicators, alerts, notifications
- **Input Handling**: Keyboard, HOTAS, touch input processing

#### Visual System
- **Real-time 3D Rendering**: Universe objects with proper scaling
- **Effect Systems**: Particle effects for weapons, explosions, trails
- **UI Frameworks**: Responsive interfaces for different screen sizes
- **Audio Integration**: 3D positional audio, ambient sounds, alerts

### ESP32 Panel System

#### Hardware Abstraction
- **Device Drivers**: Buttons, potentiometers, LEDs, displays
- **GPIO Management**: Efficient pin usage and multiplexing
- **Input Processing**: Debouncing, filtering, calibration
- **Output Control**: PWM, digital outputs, display protocols

#### Communication
- **TCP Client**: Reliable connection to backend server
- **JSON Protocol**: Structured command and telemetry exchange
- **Configuration Management**: Dynamic device setup
- **Error Handling**: Connection recovery, device fault detection

## Data Flow Architecture

### State Updates (Backend → Frontends)

```
Universe Simulation
        │
        ▼
State Serialization
        │
        ▼
Station Filtering ────┐
        │             │
        ▼             ▼
WebSocket Broadcast   Panel Commands
        │             │
        ▼             ▼
Frontend Update      ESP32 Output
```

### Input Processing (Frontends → Backend)

```
Input Events
    │
    ▼
Validation & Authentication
    │
    ▼
Station Permission Check
    │
    ▼
Universe State Modification
    │
    ▼
State Broadcasting
```

## Communication Protocols

### WebSocket Protocol (Frontend ↔ Backend)
- **Connection**: `ws://server:8080/ws`
- **Message Format**: JSON with type, timestamp, data fields
- **Station Authentication**: Initial handshake with station type
- **Heartbeat**: 30-second keepalive mechanism
- **State Updates**: 60 FPS filtered universe state
- **Input Events**: Real-time user input transmission

### TCP Protocol (ESP32 ↔ Backend)
- **Connection**: `tcp://server:8081`
- **Message Format**: Newline-delimited JSON
- **Device Configuration**: Server-provided panel setup
- **Input Telemetry**: Real-time hardware state reporting
- **Output Commands**: LED, display, audio control
- **Status Monitoring**: Device health and error reporting

### HTTP API (Management Interface)
- **Endpoints**: RESTful API for system management
- **Authentication**: Role-based access control
- **Configuration**: Runtime system configuration
- **Monitoring**: Status and performance metrics
- **Mission Control**: Load and manage mission scripts

## Threading and Concurrency

### Backend Threading Model

```
Main Thread
├── Universe Simulation (60 FPS)
├── WebSocket Handler Pool
├── TCP Connection Manager
├── Lua Script Execution
└── HTTP Request Handler

Background Threads
├── Network I/O Processing
├── Panel Status Monitoring  
├── Log File Management
└── Configuration Reloading
```

### Synchronization Strategy
- **Mutex Protection**: Universe state modifications
- **Channel Communication**: Inter-thread message passing
- **Read-Write Locks**: Frequent read operations optimization
- **Atomic Operations**: Performance-critical counters

### Performance Considerations
- **Lock-Free Algorithms**: Where possible for hot paths
- **Connection Pooling**: Efficient WebSocket management
- **State Diffing**: Minimize update payload sizes
- **Memory Pooling**: Reduce garbage collection pressure

## Security Architecture

### Network Security
- **Transport Encryption**: TLS/WSS for production deployments
- **Network Isolation**: VLAN separation for panel network
- **Firewall Rules**: Restrictive access control
- **MAC Filtering**: Hardware device authentication

### Application Security
- **Input Validation**: All user input sanitized and validated
- **Role-Based Access**: Station permissions enforced server-side
- **Rate Limiting**: Protection against DoS attacks
- **Audit Logging**: Security event tracking

### Physical Security
- **Panel Tamper Detection**: Hardware integrity monitoring
- **Secure Boot**: ESP32 firmware verification
- **Encrypted Storage**: Sensitive configuration protection
- **Emergency Lockdown**: Physical security breach response

## Scalability and Performance

### Horizontal Scaling
- **Load Balancing**: Multiple backend instances (future)
- **Database Clustering**: Persistent state storage (future)
- **CDN Integration**: Static asset distribution (future)
- **Microservice Architecture**: Service decomposition (future)

### Vertical Scaling
- **Multi-Core Utilization**: Parallel processing optimization
- **Memory Management**: Efficient object lifecycle management
- **Cache Optimization**: Frequently accessed data caching
- **Network Tuning**: TCP/WebSocket parameter optimization

### Performance Monitoring
- **Metrics Collection**: Real-time performance data
- **Profiling Integration**: CPU and memory profiling
- **Error Tracking**: Exception monitoring and alerting
- **Capacity Planning**: Resource utilization trending

## Deployment Architecture

### Development Environment
```
Developer Machine
├── Go Backend (local build)
├── Godot Frontend (editor/exported)
├── ESP32 Simulator (software)
└── Local Network (Wi-Fi hotspot)
```

### Production Environment
```
Server Infrastructure
├── Backend Server (Docker container)
├── Reverse Proxy (nginx/traefik)
├── Database (PostgreSQL) [future]
├── Monitoring (Prometheus/Grafana)
└── Logging (ELK stack)

Bridge Network
├── Dedicated Wi-Fi Network
├── Panel ESP32 Devices
├── Station Display Systems
└── Network Infrastructure
```

## Error Handling and Recovery

### Backend Error Handling
- **Graceful Degradation**: Partial system failure tolerance
- **Circuit Breakers**: Dependency failure isolation
- **Retry Logic**: Transient failure recovery
- **Panic Recovery**: Crash prevention and logging

### Frontend Error Handling
- **Connection Recovery**: Automatic reconnection with backoff
- **State Reconciliation**: Sync after reconnection
- **Fallback UI**: Offline mode capabilities
- **Error Reporting**: User-friendly error messages

### Panel Error Handling
- **Device Fault Tolerance**: Continue with working devices
- **Network Recovery**: Robust reconnection logic
- **Configuration Rollback**: Safe configuration management
- **Watchdog Timers**: Hardware fault detection

## Monitoring and Observability

### System Metrics
- **Performance Metrics**: Response times, throughput, resource usage
- **Business Metrics**: Active sessions, mission completions, errors
- **Infrastructure Metrics**: Server health, network status, panel connectivity
- **Custom Metrics**: Game-specific measurements

### Logging Strategy
- **Structured Logging**: JSON format for machine processing
- **Log Levels**: Debug, info, warning, error, critical
- **Context Propagation**: Request/session tracking
- **Log Aggregation**: Centralized log collection and analysis

### Alerting System
- **Threshold Alerts**: Performance and error rate monitoring
- **Anomaly Detection**: Unusual pattern identification
- **Escalation Policies**: On-call rotation and notification
- **Dashboard Integration**: Real-time status visualization

## Testing Strategy

### Unit Testing
- **Go Backend**: Comprehensive unit test coverage
- **Godot Frontend**: Scene and script testing
- **ESP32 Firmware**: Hardware-in-the-loop testing

### Integration Testing
- **API Testing**: Protocol compliance verification
- **End-to-End Testing**: Complete user workflow validation
- **Load Testing**: Performance under stress
- **Chaos Engineering**: Fault injection testing

### Manual Testing
- **User Acceptance Testing**: Bridge crew experience validation
- **Hardware Testing**: Physical panel functionality
- **Mission Testing**: Scenario completeness verification
- **Regression Testing**: Bug fix validation

## Future Architecture Considerations

### Planned Enhancements
- **Persistent Universe**: Database-backed state storage
- **Multiple Bridges**: Support for multiple simultaneous bridges
- **Cloud Integration**: Hosted backend services
- **Advanced AI**: NPC ship behavior and mission AI

### Technology Evolution
- **WebRTC Integration**: Peer-to-peer communication
- **IoT Platform Integration**: Cloud device management
- **Machine Learning**: Adaptive difficulty and personalization
- **Blockchain Integration**: Achievement and progression tracking

### Performance Optimization
- **GPU Acceleration**: Physics simulation offloading
- **Edge Computing**: Local processing optimization
- **5G Integration**: Low-latency mobile connectivity
- **Quantum Communication**: Future-proof security protocols

This architecture provides a solid foundation for the Celestial Bridge Simulator while maintaining flexibility for future enhancements and scaling requirements.