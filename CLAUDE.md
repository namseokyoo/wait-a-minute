# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Wait A Minute" (대기 감지 시스템) is a Flutter app designed for customer waiting detection using blue light monitoring. The app operates in dual modes:

- **CCTV Mode**: Uses camera to detect blue light signals indicating customer presence
- **Monitor Mode**: Receives and displays alerts from CCTV devices via Firebase notifications

The project is actively developed with camera services, notification systems, permission handling, and Firebase integration implemented.

## Development Commands

### Core Flutter Commands
```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device-id>

# Build for release
flutter build apk                    # Android APK
flutter build appbundle             # Android App Bundle
flutter build ios                   # iOS

# Testing
flutter test                         # Run all tests
flutter test test/widget_test.dart   # Run specific test file

# Code analysis and linting
flutter analyze                      # Static analysis
dart format .                        # Format all Dart files
dart format lib/                     # Format specific directory

# Clean build artifacts
flutter clean

# Check for dependency updates
flutter pub outdated
flutter pub upgrade
```

### Development Tools
```bash
# Hot reload: Press 'r' in terminal during flutter run
# Hot restart: Press 'R' in terminal during flutter run
# Quit: Press 'q' in terminal

# Flutter doctor (check development environment)
flutter doctor
flutter doctor -v                    # Verbose output

# Firebase configuration (if needed)
# Ensure google-services.json is in android/app/
```

## Architecture Overview

### Core Architecture Pattern
The app uses **Provider** for state management with dependency injection. Key services are provided at the app root and consumed by screens and widgets.

### Service Layer Architecture
- **WaitingStateService**: Central state management for customer waiting status
- **CameraService**: Camera operations with device identification and location tracking
- **SimplifiedMonitorService**: Alert receiving and processing for monitor mode
- **PermissionService**: Camera and notification permission handling
- **NotificationService**: Local notifications with waiting state integration
- **FirebaseNotificationService**: Remote push notifications via FCM

### State Management Flow
```
PermissionService → Camera/Notification permissions
     ↓
CameraService → Initializes with WaitingStateService injection
     ↓  
WaitingStateService → Central state (waiting/not waiting)
     ↓
NotificationService → Listens to state changes
     ↓
SimplifiedMonitorService → Processes alerts for monitor mode
```

Current dependencies include:
- `provider`: State management with dependency injection  
- `camera`: Camera access and preview functionality
- `permission_handler`: Runtime permission handling
- `flutter_local_notifications`: Local push notifications
- `firebase_core` & `firebase_messaging`: Remote notifications via FCM
- `uuid`: Unique device identification

### Current File Structure
```
lib/
├── main.dart                              # App entry with Provider setup
├── models/
│   ├── app_mode.dart                     # CCTV/Monitor mode enum
│   ├── connection_state.dart             # WebSocket connection states
│   ├── cctv_device.dart                  # Device identification model
│   └── status_message.dart               # Alert message structure
├── services/
│   ├── camera_service.dart               # Camera operations
│   ├── waiting_state_service.dart        # Central state management
│   ├── simplified_monitor_service.dart   # Monitor mode alerts
│   ├── permission_service.dart           # Permission handling
│   ├── notification_service.dart         # Local notifications
│   ├── firebase_notification_service.dart # FCM integration
│   ├── blue_light_detector.dart          # Image processing
│   └── websocket_service.dart            # WebSocket communication
├── screens/
│   ├── permission_screen.dart            # Initial permission flow
│   ├── mode_selection_screen.dart        # CCTV/Monitor mode selection
│   ├── cctv_screen.dart                  # Camera monitoring UI
│   ├── monitor_screen.dart               # Alert receiving UI
│   └── simplified_*.dart                 # Simplified variants
└── widgets/
    └── mode_card.dart                    # Mode selection UI component
```

## Testing Strategy

### Current Tests
- App launch verification (test/widget_test.dart)
- Permission screen UI components testing
- Basic widget rendering validation

### Testing Framework
- Uses `flutter_test` for widget and unit testing
- Tests verify Korean UI text and permission flow
- Widget tests use `pumpWidget` for rendering verification

## Development Environment & Configuration

### Environment
- Flutter SDK: >=3.7.2
- Dart SDK: Compatible with Flutter version
- Uses `flutter_lints` 5.0.0 for code quality enforcement

### Android Configuration
- **Permissions**: Camera, Internet, Wake Lock, Vibrate, Post Notifications
- **Features**: Camera hardware required, autofocus optional
- **Firebase**: Google Services JSON configured for FCM

### Key Implementation Details
- **Provider Pattern**: Dependency injection with `MultiProvider` setup
- **Korean Localization**: UI text in Korean for customer waiting system
- **Firebase Integration**: Graceful fallback when Firebase unavailable
- **Permission Flow**: Camera and notification permissions required before mode selection
- **State Management**: Centralized waiting state with change notifications
- **Device Identification**: UUID-based device tracking for CCTV/Monitor coordination