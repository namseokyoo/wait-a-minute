# Wait A Minute - Blue Light CCTV System Design

## Overview
A dual-mode Flutter application that functions as both a blue light detection CCTV camera and a monitoring alert receiver using WebSocket communication.

## System Architecture

### High-Level Architecture
```
┌─────────────────┐    WebSocket     ┌─────────────────┐
│   CCTV Mode     │◄────────────────►│  Monitor Mode   │
│                 │                  │                 │
│ • Camera Feed   │                  │ • Alert Receiver│
│ • Blue Light    │                  │ • Notification  │
│   Detection     │                  │   Display       │
│ • Alert Sender  │                  │ • Sound/Vibrate │
└─────────────────┘                  └─────────────────┘
        │                                      │
        ▼                                      ▼
┌─────────────────┐                  ┌─────────────────┐
│ Free WebSocket  │                  │    Local UI     │
│    Server       │                  │   Management    │
│ (ws://echo.     │                  │                 │
│ websocket.org)  │                  │                 │
└─────────────────┘                  └─────────────────┘
```

## Core Components

### 1. Application Structure
```
lib/
├── main.dart                 # App entry point with mode selection
├── config/
│   ├── app_config.dart      # Global configurations
│   └── websocket_config.dart # WebSocket settings
├── models/
│   ├── app_mode.dart        # CCTV/Monitor mode enum
│   ├── alert_message.dart   # Alert data structure
│   └── detection_result.dart # Blue light detection result
├── services/
│   ├── camera_service.dart       # Camera management
│   ├── blue_light_detector.dart  # Image processing
│   ├── websocket_service.dart    # WebSocket communication
│   ├── notification_service.dart # Local notifications
│   └── background_service.dart   # Background processing
├── screens/
│   ├── mode_selection_screen.dart # Initial mode selection
│   ├── cctv_screen.dart          # CCTV monitoring interface
│   └── monitor_screen.dart       # Alert receiving interface
├── widgets/
│   ├── camera_preview_widget.dart
│   ├── detection_overlay_widget.dart
│   ├── alert_card_widget.dart
│   └── settings_panel_widget.dart
└── utils/
    ├── image_processor.dart     # Image analysis utilities
    ├── color_analyzer.dart      # Color detection algorithms
    └── device_info_helper.dart  # Device identification
```

### 2. Dual Mode Design

#### Mode Selection Flow
```
App Launch
    │
    ▼
┌─────────────────┐
│  Mode Selection │
│                 │
│  [CCTV Mode]   │
│  [Monitor Mode] │
└─────────────────┘
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│ CCTV    │ │ Monitor │
│ Screen  │ │ Screen  │
└─────────┘ └─────────┘
```

#### CCTV Mode Components
- **Camera Preview**: Real-time camera feed display
- **Blue Light Detector**: Continuous image analysis
- **Detection Overlay**: Visual indicators for blue light areas
- **Alert Sender**: WebSocket message transmission
- **Settings Panel**: Sensitivity, threshold configuration

#### Monitor Mode Components
- **WebSocket Listener**: Continuous connection to receive alerts
- **Alert Display**: Visual alert notifications
- **Alert History**: Log of received alerts with timestamps
- **Sound/Vibration**: Audio/haptic feedback
- **Device Management**: Multiple CCTV device monitoring

## Data Models

### AppMode Enum
```dart
enum AppMode {
  selection,  // Initial mode selection screen
  cctv,       // CCTV monitoring mode
  monitor     // Alert receiving mode
}
```

### AlertMessage Model
```dart
class AlertMessage {
  final String deviceId;        // Sending device identifier
  final String deviceName;      // Human-readable device name
  final DateTime timestamp;     // Detection timestamp
  final double blueIntensity;   // Detected blue light intensity (0-1)
  final String location;        // Optional location description
  final String? imageData;      // Optional base64 encoded image
}
```

### DetectionResult Model
```dart
class DetectionResult {
  final bool isBlueDetected;    // Whether blue light threshold exceeded
  final double intensity;       // Blue light intensity (0-1)
  final Rect? detectionArea;    // Bounding box of detection area
  final Color dominantColor;    // Dominant color in detection area
  final DateTime timestamp;     // Detection timestamp
}
```

## Technical Specifications

### Blue Light Detection Algorithm
```dart
// Pseudocode for blue light detection
class BlueLightDetector {
  // Configure blue detection parameters
  static const double BLUE_THRESHOLD = 0.7;  // Blue intensity threshold
  static const double HUE_RANGE_MIN = 200;   // Blue hue range start
  static const double HUE_RANGE_MAX = 260;   // Blue hue range end
  static const double MIN_SATURATION = 0.3;  // Minimum saturation
  static const double MIN_VALUE = 0.4;       // Minimum brightness
  
  DetectionResult analyzeFrame(Image frame) {
    // 1. Convert to HSV color space
    // 2. Filter pixels within blue hue range
    // 3. Calculate blue intensity percentage
    // 4. Apply threshold comparison
    // 5. Find detection bounding box
    // 6. Return detection result
  }
}
```

### WebSocket Communication Protocol
```dart
// Message format for alerts
{
  "type": "blue_light_alert",
  "deviceId": "unique_device_id",
  "deviceName": "Living Room Camera",
  "timestamp": "2024-01-15T10:30:00Z",
  "intensity": 0.85,
  "location": "front_door",
  "imageData": "base64_encoded_image_optional"
}

// Heartbeat message format
{
  "type": "heartbeat",
  "deviceId": "unique_device_id",
  "status": "active",
  "timestamp": "2024-01-15T10:30:00Z"
}

// Device registration format
{
  "type": "device_register",
  "deviceId": "unique_device_id", 
  "deviceName": "Living Room Camera",
  "mode": "cctv",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Free WebSocket Server Options

### Recommended Servers
1. **WebSocket.org Echo Server**
   - URL: `wss://echo.websocket.org/`
   - Free, no registration required
   - Echoes back any message sent

2. **Pusher Channels (Free Tier)**
   - 100 connections, 200k messages/day
   - Requires registration
   - More reliable for production

3. **Socket.IO Test Server**
   - URL: `wss://socketio-echo-server.herokuapp.com/`
   - Free testing environment

### WebSocket Implementation
```dart
class WebSocketService {
  static const String DEFAULT_SERVER = 'wss://echo.websocket.org/';
  late WebSocketChannel channel;
  
  // Connection management
  Future<void> connect(String serverUrl);
  void disconnect();
  
  // Message handling
  void sendAlert(AlertMessage alert);
  Stream<AlertMessage> get alertStream;
  
  // Device management
  void registerDevice(String deviceId, AppMode mode);
  void sendHeartbeat();
}
```

## Performance Considerations

### Camera Processing
- **Frame Rate**: 15-30 FPS processing (configurable)
- **Resolution**: 640x480 for processing (lower CPU usage)
- **Background Processing**: Use isolates for heavy computation

### Memory Management
- **Frame Buffering**: Process every Nth frame to reduce load
- **Image Compression**: Compress captured frames before analysis
- **Garbage Collection**: Proper disposal of camera resources

### Battery Optimization
- **Adaptive Processing**: Reduce processing when no blue light detected
- **Background Modes**: Use background service for CCTV mode
- **Screen Management**: Dim screen during monitoring

## Security & Privacy

### Data Protection
- **Local Processing**: Blue light detection happens on device
- **Optional Image Sharing**: Images only sent if explicitly configured
- **Device Identification**: Use anonymous UUIDs
- **No Personal Data**: Avoid collecting personal information

### Connection Security
- **WSS Protocol**: Use secure WebSocket connections when available
- **Message Encryption**: Optional end-to-end encryption for sensitive deployments
- **Rate Limiting**: Prevent spam attacks

## Development Phases

### Phase 1: Core Framework (Week 1-2)
- [ ] Basic dual-mode app structure
- [ ] Mode selection screen
- [ ] Camera service integration
- [ ] Basic WebSocket connection

### Phase 2: Detection Engine (Week 2-3)
- [ ] Blue light detection algorithm
- [ ] Real-time camera processing
- [ ] Detection overlay UI
- [ ] Threshold configuration

### Phase 3: Communication (Week 3-4)
- [ ] WebSocket message protocol
- [ ] Alert sending/receiving
- [ ] Device identification
- [ ] Error handling & reconnection

### Phase 4: Enhancement (Week 4-5)
- [ ] Background service
- [ ] Local notifications
- [ ] Settings management
- [ ] Performance optimization

### Phase 5: Polish (Week 5-6)
- [ ] UI/UX improvements
- [ ] Testing & debugging
- [ ] Documentation
- [ ] Deployment preparation