# UI/UX Design & Component Structure

## Overview
User-centered design for a dual-mode blue light monitoring app with intuitive mode selection, real-time camera monitoring, and effective alert management.

## Design Principles

### Core UX Principles
1. **Simplicity First**: Clear mode selection, minimal cognitive load
2. **Real-time Feedback**: Immediate visual feedback for all actions
3. **Accessibility**: Support for various devices and user abilities
4. **Battery Awareness**: Visual indicators for power consumption
5. **Emergency Focus**: Critical alerts prioritized over aesthetic elements

## Screen Flow Architecture

### Application Flow
```
App Launch
    │
    ▼
┌─────────────────┐
│  Splash Screen  │ (3s, app initialization)
│                 │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Permission      │ (Camera, Notification permissions)
│ Request Screen  │
└─────────────────┘
    │
    ▼
┌─────────────────┐
│ Mode Selection  │ (Primary navigation hub)
│     Screen      │
│                 │
│  [CCTV Mode]   │───────────┐
│  [Monitor Mode] │───┐       │
│  [Settings]     │   │       │
└─────────────────┘   │       │
                      │       │
            ┌─────────▼──┐   ┌▼─────────────┐
            │ Monitor    │   │ CCTV Screen  │
            │ Screen     │   │              │
            └────────────┘   └──────────────┘
```

## Screen Designs

### 1. Mode Selection Screen (Home)
```dart
class ModeSelectionScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            AppHeader(),
            
            // Mode Selection Cards
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // CCTV Mode Card
                    ModeCard(
                      mode: AppMode.cctv,
                      title: 'CCTV 모드',
                      subtitle: '파란불빛 감지 및 알림 전송',
                      icon: Icons.videocam,
                      color: Colors.blue,
                      onTap: () => _selectMode(AppMode.cctv),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Monitor Mode Card
                    ModeCard(
                      mode: AppMode.monitor,
                      title: '모니터링 모드',
                      subtitle: '알림 수신 및 관리',
                      icon: Icons.notifications_active,
                      color: Colors.orange,
                      onTap: () => _selectMode(AppMode.monitor),
                    ),
                  ],
                ),
              ),
            ),
            
            // Settings & Info
            BottomActionBar(),
          ],
        ),
      ),
    );
  }
}
```

### 2. CCTV Screen Design
```dart
class CCTVScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview (Full Screen)
          CameraPreviewWidget(),
          
          // Detection Overlay
          DetectionOverlayWidget(),
          
          // Top Status Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CCTVTopBar(),
          ),
          
          // Side Control Panel (Collapsible)
          Positioned(
            right: 0,
            top: 100,
            bottom: 100,
            child: CCTVControlPanel(),
          ),
          
          // Bottom Status & Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CCTVBottomBar(),
          ),
        ],
      ),
    );
  }
}
```

### 3. Monitor Screen Design
```dart
class MonitorScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header with connection status
          MonitorHeader(),
          
          // Connected Devices Overview
          DeviceStatusGrid(),
          
          // Alert Feed
          Expanded(
            child: AlertFeedWidget(),
          ),
          
          // Bottom navigation/actions
          MonitorBottomBar(),
        ],
      ),
    );
  }
}
```

## Component Specifications

### Core UI Components

#### 1. ModeCard Component
```dart
class ModeCard extends StatelessWidget {
  final AppMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                
                SizedBox(width: 20),
                
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### 2. BlueIntensityMeter Component
```dart
class BlueIntensityMeter extends StatefulWidget {
  final double intensity; // 0.0 - 1.0
  final double threshold;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white30, width: 2),
      ),
      child: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.green.withOpacity(0.3),
                    Colors.yellow.withOpacity(0.3),
                    Colors.orange.withOpacity(0.3),
                    Colors.red.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          
          // Intensity Fill
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              height: (200 - 8) * intensity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: _getIntensityColors(intensity),
                ),
              ),
            ),
          ),
          
          // Threshold Line
          Positioned(
            bottom: (200 - 8) * threshold,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              color: Colors.red,
            ),
          ),
          
          // Value Label
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Text(
              '${(intensity * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 3. DetectionOverlayWidget Component
```dart
class DetectionOverlayWidget extends StatefulWidget {
  final DetectionResult result;
  final bool showDetails;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Detection Area Highlight
        if (result.detectionArea != null)
          Positioned.fromRect(
            rect: result.detectionArea!,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              decoration: BoxDecoration(
                border: Border.all(
                  color: result.isBlueDetected 
                    ? Colors.red 
                    : Colors.yellow,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: result.isBlueDetected
                ? BlinkingContainer(
                    child: Container(
                      color: Colors.red.withOpacity(0.2),
                    ),
                  )
                : null,
            ),
          ),
          
        // Corner Detection Indicators
        ...buildCornerIndicators(result),
        
        // Crosshair Center
        Center(
          child: CustomPaint(
            size: Size(40, 40),
            painter: CrosshairPainter(
              color: result.isBlueDetected ? Colors.red : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
```

#### 4. AlertCardWidget Component
```dart
class AlertCardWidget extends StatelessWidget {
  final AlertMessage alert;
  final VoidCallback? onTap;
  final bool isNew;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isNew ? 8 : 2,
      color: isNew ? Colors.red[50] : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Alert Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              SizedBox(width: 16),
              
              // Alert Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.deviceName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '파란불빛 감지 (강도: ${(alert.blueIntensity * 100).toInt()}%)',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _formatTimestamp(alert.timestamp),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Time Badge
              if (isNew)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Responsive Design Strategy

### Screen Size Adaptations
```dart
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, ScreenSize) builder;
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        ScreenSize screenSize;
        
        if (constraints.maxWidth < 600) {
          screenSize = ScreenSize.mobile;
        } else if (constraints.maxWidth < 1200) {
          screenSize = ScreenSize.tablet;
        } else {
          screenSize = ScreenSize.desktop;
        }
        
        return builder(context, screenSize);
      },
    );
  }
}

enum ScreenSize { mobile, tablet, desktop }
```

### Adaptive Layouts
```dart
// CCTV Screen Responsive Layout
Widget buildCCTVLayout(ScreenSize screenSize) {
  switch (screenSize) {
    case ScreenSize.mobile:
      return _buildMobileLayout();
    case ScreenSize.tablet:
      return _buildTabletLayout();
    case ScreenSize.desktop:
      return _buildDesktopLayout();
  }
}
```

## Accessibility Features

### Screen Reader Support
```dart
class AccessibleModeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title 모드',
      hint: '$subtitle. 탭하여 선택하세요.',
      button: true,
      child: ModeCard(...),
    );
  }
}
```

### High Contrast Mode
```dart
class AccessibilityTheme {
  static ThemeData get highContrastTheme => ThemeData(
    primaryColor: Colors.black,
    backgroundColor: Colors.white,
    textTheme: TextTheme(
      bodyText1: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.black, width: 2),
      ),
    ),
  );
}
```

## Dark Mode Design
```dart
class AppTheme {
  static ThemeData get darkTheme => ThemeData.dark().copyWith(
    primaryColor: Colors.blue,
    backgroundColor: Colors.grey[900],
    cardColor: Colors.grey[800],
    
    // CCTV specific colors
    extensions: [
      CCTVTheme(
        cameraBackground: Colors.black,
        overlayColor: Colors.blue.withOpacity(0.3),
        detectionBorder: Colors.red,
        intensityMeterBackground: Colors.grey[850]!,
      ),
    ],
  );
  
  static ThemeData get lightTheme => ThemeData.light().copyWith(
    primaryColor: Colors.blue,
    backgroundColor: Colors.grey[50],
    
    extensions: [
      CCTVTheme(
        cameraBackground: Colors.black,
        overlayColor: Colors.blue.withOpacity(0.2),
        detectionBorder: Colors.red,
        intensityMeterBackground: Colors.white,
      ),
    ],
  );
}
```

## Animation Specifications

### Screen Transitions
```dart
class ModeTransition extends PageRouteBuilder {
  final Widget child;
  
  ModeTransition({required this.child})
    : super(
        pageBuilder: (context, animation, _) => child,
        transitionDuration: Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(
              begin: Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            )),
            child: child,
          );
        },
      );
}
```

### Alert Animations
```dart
class PulsingAlert extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseAnimation.value * 0.1),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(
                0.5 + (_pulseAnimation.value * 0.3)
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
```

## Performance Optimizations

### Widget Optimization
```dart
// Use const constructors wherever possible
const ModeCard(
  mode: AppMode.cctv,
  title: 'CCTV 모드',
  // ...
);

// Implement proper dispose methods
@override
void dispose() {
  _cameraController?.dispose();
  _animationController?.dispose();
  _webSocketService.disconnect();
  super.dispose();
}
```

### Memory Management
```dart
class CCTVScreen extends StatefulWidget {
  @override
  void dispose() {
    // Dispose camera resources
    _cameraService.stopMonitoring();
    
    // Cancel timers
    _detectionTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    // Clear image caches
    _imageCache.clear();
    
    super.dispose();
  }
}
```