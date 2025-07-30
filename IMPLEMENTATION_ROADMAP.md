# Implementation Roadmap - Wait A Minute App

## Overview
6-phase development plan for building a blue light monitoring CCTV app with dual-mode functionality and WebSocket communication.

## Development Phases

### Phase 1: Foundation & Core Structure (Week 1-2)
**Objective**: Establish project foundation with simplified CCTV/Monitor architecture

#### Dependencies Setup
```yaml
# pubspec.yaml additions needed
dependencies:
  camera: ^0.10.5+5           # Camera access and control
  image: ^4.1.3               # Basic image processing
  web_socket_channel: ^2.4.0  # WebSocket communication
  permission_handler: ^11.2.0 # Runtime permissions
  provider: ^6.1.1            # State management
  shared_preferences: ^2.2.2  # Local data storage
  flutter_local_notifications: ^16.3.0 # Local notifications
  uuid: ^4.2.1                # Unique device IDs

dev_dependencies:
  mockito: ^5.4.4             # Mocking for tests
  flutter_launcher_icons: ^0.13.1 # App icons
```

#### Core Tasks - Updated for Simplified Design
- [ ] **Project Setup & Dependencies**
  - Add required packages to pubspec.yaml
  - Configure Android/iOS permissions in manifests
  - Setup app icons and splash screen

- [ ] **Basic App Structure**
  - Create AppMode enum and core models
  - Implement Provider-based state management (MonitorService, CCTVService)
  - Setup basic navigation structure

- [ ] **Mode Selection Screen**
  - Implement ModeSelectionScreen with CCTV/Monitor options
  - Create ModeCard components with customer service branding
  - Add basic device identification

- [ ] **Permission Handling**
  - Implement camera permission request flow
  - Add notification permission handling
  - Create permission denied fallback screens

#### Deliverables
- Working app with simplified mode selection
- Basic navigation between CCTV and Monitor modes
- Proper permission handling
- Unit tests for core models

### Phase 2: Simplified CCTV Implementation (Week 2-3)
**Objective**: Create basic CCTV camera operation with start/stop controls

#### Core Tasks - Simplified CCTV Focus
- [ ] **Basic Camera Service**
  - Setup CameraController integration
  - Implement simple camera preview widget
  - Add camera permission and error handling
  - Create start/stop monitoring functionality

- [ ] **Simplified Blue Light Detection**
  - Implement basic HSV color space conversion
  - Create lightweight blue light detection
  - Send raw intensity data to Monitor (no local threshold)
  - Minimal processing for battery efficiency

- [ ] **CCTV Interface Components**
  - Create CCTVControlButton (start/stop with dialog)
  - Implement ConnectionStatusIndicator
  - Add minimal camera preview overlay
  - Create device status transmission

- [ ] **Status Communication**
  - Implement continuous status updates to Monitor
  - Add device heartbeat mechanism
  - Create battery and connection monitoring
  - Handle Monitor settings sync reception

#### Technical Implementation
```dart
// Key files to create/modify:
lib/services/cctv_service.dart          # Simplified camera control
lib/services/blue_light_detector.dart   # Basic detection only
lib/widgets/camera_preview_widget.dart  # Minimal camera display
lib/widgets/cctv_control_button.dart   # Start/stop controls
lib/models/device_status.dart          # Status data structure
lib/screens/cctv_screen.dart           # Simplified CCTV interface
```

#### Deliverables
- Working CCTV mode with start/stop controls
- Basic blue light intensity detection
- Continuous status transmission to Monitor
- Simple, battery-efficient camera operation
- Unit tests for CCTV service

### Phase 3: Monitor Control Center & WebSocket (Week 3-4)
**Objective**: Build centralized Monitor interface with WebSocket status communication

#### Core Tasks - Monitor-Centric Approach
- [ ] **Monitor Service Architecture**
  - Implement MonitorService with device management
  - Create centralized settings control (sensitivity, alerts)
  - Add CCTV device status tracking
  - Implement "고객이 대기중입니다" logic

- [ ] **WebSocket Communication**
  - Implement WebSocketService with reconnection logic
  - Create status update message protocol
  - Add settings synchronization (Monitor → CCTV)
  - Handle device registration and heartbeat

- [ ] **Monitor Interface Components**
  - Create MonitorHeader with alert toggle
  - Implement CustomerWaitingBanner
  - Build CCTVDeviceGrid and CCTVDeviceCard
  - Add SettingsPanel with sensitivity slider

- [ ] **Status Management System**
  - Track multiple CCTV device states
  - Apply Monitor sensitivity to raw CCTV data
  - Generate "customer waiting" status
  - Control push notification delivery

#### Technical Implementation
```dart
// Key files to create:
lib/services/monitor_service.dart       # Centralized control
lib/services/websocket_service.dart     # Communication layer
lib/models/cctv_device.dart            # Device status model
lib/models/status_message.dart         # Status update protocol
lib/screens/monitor_screen.dart        # Control center interface
lib/widgets/customer_waiting_banner.dart # Status display
lib/widgets/cctv_device_grid.dart      # Device overview
lib/widgets/settings_panel.dart       # Sensitivity controls
```

#### Free WebSocket Server Setup
- Configure WebSocket.org echo server for status updates
- Implement message broadcasting for settings sync
- Add connection reliability and reconnection logic
- Test Monitor ↔ CCTV communication

#### Deliverables
- Complete Monitor control center interface
- Functional status communication system
- Centralized sensitivity and alert control
- "고객이 대기중입니다" status display
- Integration tests for Monitor-CCTV interaction

### Phase 4: Complete User Interface (Week 4-5)
**Objective**: Build complete user interfaces for both CCTV and Monitor modes

#### CCTV Mode Interface
- [ ] **CCTV Screen Layout**
  - Implement full-screen camera preview
  - Create collapsible control panels
  - Add detection status indicators
  - Implement settings overlay

- [ ] **Control Components**
  - Create sensitivity adjustment controls
  - Add detection area selection tools
  - Implement recording toggle
  - Create alert history viewer

#### Monitor Mode Interface
- [ ] **Monitor Dashboard**
  - Create device status grid
  - Implement alert feed with filtering
  - Add real-time connection status
  - Create alert management tools

- [ ] **Alert Management**
  - Implement AlertCardWidget with details
  - Add alert acknowledgment system
  - Create alert history and search
  - Implement notification settings

#### Responsive Design
- [ ] **Multi-device Support**
  - Optimize for phone/tablet layouts
  - Implement landscape/portrait modes
  - Add accessibility features
  - Test on various screen sizes

#### Technical Implementation
```dart
// Key files to create:
lib/screens/cctv_screen.dart
lib/screens/monitor_screen.dart
lib/widgets/cctv_control_panel.dart
lib/widgets/alert_feed_widget.dart
lib/widgets/device_status_grid.dart
```

#### Deliverables
- Complete CCTV interface
- Full Monitor mode functionality
- Responsive design implementation
- Accessibility compliance

### Phase 5: Background Processing & Notifications (Week 5-6)
**Objective**: Enable background monitoring and local notifications

#### Core Tasks
- [ ] **Background Service**
  - Implement flutter_background_service
  - Create background camera monitoring
  - Add background WebSocket connection
  - Implement battery optimization

- [ ] **Local Notifications**
  - Setup flutter_local_notifications
  - Create alert notification templates
  - Add notification actions (acknowledge, snooze)
  - Implement notification sound/vibration

- [ ] **App Lifecycle Management**
  - Handle app foreground/background transitions
  - Implement proper resource cleanup
  - Add memory management optimization
  - Create app state persistence

- [ ] **Settings & Configuration**
  - Create comprehensive settings screen
  - Add notification preferences
  - Implement sensitivity calibration
  - Add server configuration options

#### Technical Implementation
```dart
// Key files to create:
lib/services/background_service.dart
lib/services/notification_service.dart
lib/screens/settings_screen.dart
lib/utils/app_lifecycle_manager.dart
```

#### Deliverables
- Background monitoring capability
- Rich local notifications
- Comprehensive settings system
- Battery-optimized operation

### Phase 6: Testing, Polish & Deployment (Week 6-7)
**Objective**: Comprehensive testing, performance optimization, and deployment preparation

#### Testing Strategy
- [ ] **Unit Testing**
  - Test all core services and utilities
  - Mock camera and WebSocket services
  - Test blue light detection algorithm
  - Validate message serialization/deserialization

- [ ] **Widget Testing**
  - Test all custom widgets and screens
  - Validate responsive design behavior
  - Test accessibility features
  - Mock service dependencies

- [ ] **Integration Testing**
  - Test end-to-end alert flow
  - Validate multi-device communication
  - Test background service integration
  - Validate notification delivery

#### Performance Optimization
- [ ] **Memory Management**
  - Optimize image processing memory usage
  - Implement proper widget disposal
  - Monitor for memory leaks
  - Optimize background service resources

- [ ] **Battery Optimization**
  - Implement adaptive processing rates
  - Optimize camera usage patterns
  - Reduce unnecessary background activity
  - Add battery usage monitoring

#### Polish & Documentation
- [ ] **User Experience Polish**
  - Refine animations and transitions
  - Improve error messages and feedback
  - Add loading states and progress indicators
  - Implement smooth gesture handling

- [ ] **Documentation**
  - Update README with complete setup instructions
  - Create user manual/help documentation
  - Document API and architecture decisions
  - Create deployment guide

#### Deployment Preparation
- [ ] **Build Configuration**
  - Setup release build configurations
  - Configure app signing for Android/iOS
  - Optimize app bundle size
  - Test release builds on multiple devices

- [ ] **Store Preparation**
  - Create app store descriptions and screenshots
  - Prepare privacy policy and terms of service
  - Setup app store metadata
  - Prepare for store submission

## Technical Milestones

### Milestone 1: MVP Demo (End of Week 3)
- Basic dual-mode app functionality
- Working blue light detection
- Simple WebSocket communication
- Demo-ready application

### Milestone 2: Beta Release (End of Week 5)
- Complete feature implementation
- Background processing capability
- Comprehensive testing coverage
- Ready for limited user testing

### Milestone 3: Production Release (End of Week 7)
- Fully tested and optimized application
- Complete documentation
- Store-ready deployment
- Production monitoring setup

## Risk Mitigation Strategies

### Technical Risks
1. **Camera Performance Issues**
   - Mitigation: Implement adaptive processing and frame sampling
   - Fallback: Reduce processing resolution and frame rate

2. **WebSocket Reliability**
   - Mitigation: Implement robust reconnection and message queuing
   - Fallback: Local network discovery as backup communication

3. **Battery Consumption**
   - Mitigation: Adaptive processing and background optimization
   - Fallback: User-configurable power saving modes

4. **Detection Accuracy**
   - Mitigation: Comprehensive testing with various lighting conditions
   - Fallback: User-adjustable sensitivity and threshold settings

### Development Risks
1. **Timeline Delays**
   - Mitigation: Prioritize MVP features first
   - Fallback: Reduce scope of advanced features

2. **Platform Compatibility**
   - Mitigation: Test on multiple devices throughout development
   - Fallback: Focus on primary platform (Android) first

## Success Criteria

### Technical Success Metrics
- Blue light detection accuracy: >85% in varied lighting conditions
- Alert delivery time: <2 seconds end-to-end
- App startup time: <3 seconds
- Background battery usage: <5% per hour
- Crash-free sessions: >99.5%

### User Experience Metrics
- Mode selection completion: <10 seconds for new users
- Alert acknowledgment: <5 seconds average response time
- App rating target: >4.0 stars
- User retention: >70% after 7 days

## Development Tools & Environment

### Required Development Setup
- Flutter SDK 3.7.2+
- Android Studio / VS Code with Flutter extensions
- Physical Android/iOS devices for camera testing
- WebSocket testing tools (Postman, wscat)
- Performance profiling tools (Flutter Inspector, Dart DevTools)

### Recommended Testing Devices
- Android: Various screen sizes and camera capabilities
- iOS: iPhone models with different camera configurations
- Low-end devices: Test performance constraints
- High-end devices: Validate advanced features

This roadmap provides a structured approach to building your blue light monitoring CCTV app, with clear phases, deliverables, and risk mitigation strategies. Each phase builds upon the previous one, ensuring a solid foundation while progressively adding complexity.