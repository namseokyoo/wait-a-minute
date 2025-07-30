# Refined System Design - Customer Waiting Monitor

## Overview
Simplified dual-mode system where CCTV devices serve as basic camera sensors, while Monitor devices provide centralized control and customer service management.

## Updated System Architecture

### Core Concept
```
┌─────────────────┐    Real-time Status    ┌─────────────────┐
│   CCTV Mode     │◄───────────────────────►│  Monitor Mode   │
│  (Simple Sensor)│                        │ (Control Center)│
│                 │                        │                 │
│ • Start/Stop    │                        │ • Settings      │
│ • Camera Feed   │                        │ • Blue Level    │
│ • Status Send   │                        │ • Alert Control │
│                 │                        │ • Customer Wait │
└─────────────────┘                        └─────────────────┘
```

## CCTV Mode - Simplified Design

### Minimal Interface Requirements
```dart
class CCTVScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera preview
          CameraPreviewWidget(),
          
          // Simple floating control
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: CCTVControlButton(),
          ),
          
          // Status indicator (top)
          Positioned(
            top: 50,
            right: 20,
            child: ConnectionStatusIndicator(),
          ),
        ],
      ),
    );
  }
}
```

### CCTV Control Button Component
```dart
class CCTVControlButton extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Consumer<CCTVService>(
        builder: (context, cctvService, child) {
          return FloatingActionButton.extended(
            onPressed: cctvService.isMonitoring 
                ? _showStopDialog 
                : _startMonitoring,
            backgroundColor: cctvService.isMonitoring 
                ? Colors.red 
                : Colors.green,
            foregroundColor: Colors.white,
            icon: Icon(
              cctvService.isMonitoring 
                  ? Icons.stop 
                  : Icons.play_arrow,
              size: 32,
            ),
            label: Text(
              cctvService.isMonitoring ? '모니터링 중지' : '모니터링 시작',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _showStopDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('모니터링 중지'),
        content: Text('파란불빛 감지를 중지하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CCTVService>().stopMonitoring();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('중지'),
          ),
        ],
      ),
    );
  }
  
  void _startMonitoring() {
    context.read<CCTVService>().startMonitoring();
  }
}
```

### Connection Status Indicator
```dart
class ConnectionStatusIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, wsService, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(wsService.connectionState),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(wsService.connectionState),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(
                _getStatusText(wsService.connectionState),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Color _getStatusColor(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return Colors.green;
      case ConnectionState.connecting:
        return Colors.orange;
      case ConnectionState.disconnected:
        return Colors.red;
    }
  }
  
  String _getStatusText(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return '연결됨';
      case ConnectionState.connecting:
        return '연결중';
      case ConnectionState.disconnected:
        return '연결끊김';
    }
  }
}
```

## Monitor Mode - Control Center Design

### Enhanced Monitor Interface
```dart
class MonitorScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header with alert control
          MonitorHeader(),
          
          // Customer waiting status display
          CustomerWaitingBanner(),
          
          // Connected CCTV devices
          Expanded(
            flex: 2,
            child: CCTVDeviceGrid(),
          ),
          
          // Settings panel
          Expanded(
            flex: 1,
            child: SettingsPanel(),
          ),
        ],
      ),
    );
  }
}
```

### Monitor Header with Alert Control
```dart
class MonitorHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[800],
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '고객 대기 모니터링',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '파란불빛 감지 시스템',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Alert toggle
            Consumer<MonitorService>(
              builder: (context, monitorService, child) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '푸시 알람',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12),
                      Switch(
                        value: monitorService.pushAlertsEnabled,
                        onChanged: (value) {
                          monitorService.setPushAlertsEnabled(value);
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.grey,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

### Customer Waiting Banner
```dart
class CustomerWaitingBanner extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorService>(
      builder: (context, monitorService, child) {
        final hasWaitingCustomer = monitorService.isBlueDetected;
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 500),
          height: hasWaitingCustomer ? 80 : 0,
          child: AnimatedOpacity(
            opacity: hasWaitingCustomer ? 1.0 : 0.0,
            duration: Duration(milliseconds: 300),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing icon
                    PulsingIcon(
                      icon: Icons.person_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                    
                    SizedBox(width: 16),
                    
                    // Message
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔵 고객이 대기중입니다',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '파란불빛이 감지되었습니다',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

### CCTV Device Grid
```dart
class CCTVDeviceGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Consumer<MonitorService>(
        builder: (context, monitorService, child) {
          final devices = monitorService.connectedDevices;
          
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'CCTV 기기가 연결되지 않았습니다',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return CCTVDeviceCard(device: devices[index]);
            },
          );
        },
      ),
    );
  }
}
```

### CCTV Device Card
```dart
class CCTVDeviceCard extends StatelessWidget {
  final CCTVDevice device;
  
  const CCTVDeviceCard({required this.device});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: device.isBlueDetected ? Colors.blue : Colors.grey[300]!,
            width: device.isBlueDetected ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            // Device header
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: device.isBlueDetected 
                    ? Colors.blue[50] 
                    : Colors.grey[50],
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: device.isOnline ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  SizedBox(width: 8),
                  
                  // Device name
                  Expanded(
                    child: Text(
                      device.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Blue detection indicator
                  if (device.isBlueDetected)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '대기중',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Device content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Blue intensity
                    Row(
                      children: [
                        Text(
                          '파란불 강도:',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: device.blueIntensity,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              device.isBlueDetected ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${(device.blueIntensity * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: device.isBlueDetected ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Last update
                    Text(
                      '최근 업데이트: ${_formatTime(device.lastUpdate)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Settings Panel
```dart
class SettingsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '감지 설정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Blue sensitivity slider
          Consumer<MonitorService>(
            builder: (context, monitorService, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '파란색 인식 감도',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(monitorService.blueSensitivity * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  Slider(
                    value: monitorService.blueSensitivity,
                    onChanged: (value) {
                      monitorService.setBlueSensitivity(value);
                    },
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.grey[300],
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('낮음', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('높음', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

## Updated WebSocket Protocol

### Status Message Format
```dart
// CCTV Status Update Message
{
  "type": "statusUpdate",
  "deviceId": "cctv_entrance_01",
  "deviceName": "입구 카메라",
  "timestamp": "2024-01-15T10:30:15Z",
  "payload": {
    "isMonitoring": true,
    "isOnline": true,
    "blueIntensity": 0.65,
    "isBlueDetected": true,  // Based on Monitor's sensitivity setting
    "batteryLevel": 0.78,
    "location": "entrance"
  }
}

// Monitor Settings Sync Message
{
  "type": "settingsSync",
  "deviceId": "monitor_main_01", 
  "deviceName": "메인 모니터",
  "timestamp": "2024-01-15T10:30:15Z",
  "payload": {
    "blueSensitivity": 0.7,
    "pushAlertsEnabled": true,
    "targetDevices": ["cctv_entrance_01", "cctv_lobby_02"]
  }
}

// Customer Waiting Alert (Only when pushAlertsEnabled = true)
{
  "type": "customerWaiting",
  "deviceId": "cctv_entrance_01",
  "deviceName": "입구 카메라", 
  "timestamp": "2024-01-15T10:30:15Z",
  "payload": {
    "message": "고객이 대기중입니다",
    "intensity": 0.85,
    "location": "entrance",
    "duration": 5.2
  }
}
```

### Service Architecture Updates
```dart
class MonitorService extends ChangeNotifier {
  bool _pushAlertsEnabled = true;
  double _blueSensitivity = 0.7;
  List<CCTVDevice> _connectedDevices = [];
  bool _isBlueDetected = false;
  
  // Getters
  bool get pushAlertsEnabled => _pushAlertsEnabled;
  double get blueSensitivity => _blueSensitivity;
  List<CCTVDevice> get connectedDevices => _connectedDevices;
  bool get isBlueDetected => _isBlueDetected;
  
  // Settings control
  void setPushAlertsEnabled(bool enabled) {
    _pushAlertsEnabled = enabled;
    _syncSettingsToDevices();
    notifyListeners();
  }
  
  void setBlueSensitivity(double sensitivity) {
    _blueSensitivity = sensitivity;
    _syncSettingsToDevices();
    _updateBlueDetectionStates();
    notifyListeners();
  }
  
  // Device status handling
  void updateDeviceStatus(String deviceId, Map<String, dynamic> status) {
    final deviceIndex = _connectedDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex >= 0) {
      _connectedDevices[deviceIndex].updateStatus(status, _blueSensitivity);
      _updateGlobalBlueDetection();
      
      // Send push notification if enabled
      if (_pushAlertsEnabled && _connectedDevices[deviceIndex].isBlueDetected) {
        _sendCustomerWaitingNotification(_connectedDevices[deviceIndex]);
      }
      
      notifyListeners();
    }
  }
  
  void _updateGlobalBlueDetection() {
    _isBlueDetected = _connectedDevices.any((device) => device.isBlueDetected);
  }
  
  void _syncSettingsToDevices() {
    final settingsMessage = {
      'type': 'settingsSync',
      'payload': {
        'blueSensitivity': _blueSensitivity,
        'pushAlertsEnabled': _pushAlertsEnabled,
      },
    };
    
    _webSocketService.broadcast(settingsMessage);
  }
}
```

## Implementation Summary

### Key Changes from Original Design

1. **Simplified CCTV Interface**: 
   - Single start/stop button with confirmation dialog
   - Minimal status indicator
   - No local settings or configuration

2. **Centralized Monitor Control**:
   - All sensitivity settings managed from Monitor
   - Push alert toggle control
   - Real-time "고객이 대기중입니다" status display

3. **Enhanced Status Communication**:
   - Continuous status updates from CCTV to Monitor
   - Settings synchronization from Monitor to CCTV devices
   - Selective push notifications based on Monitor settings

4. **Customer-Centric Messaging**:
   - Business-focused language ("고객이 대기중입니다")
   - Professional waiting status display
   - Context-appropriate alert management

This refined design provides a more practical and user-friendly system for customer service environments while maintaining technical robustness and real-time capabilities.

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"id": "redesign-1", "content": "Analyze refined requirements for simplified CCTV/Monitor roles", "status": "completed", "priority": "high"}, {"id": "redesign-2", "content": "Design simplified CCTV interface with start/stop controls", "status": "completed", "priority": "high"}, {"id": "redesign-3", "content": "Design centralized Monitor interface with settings control", "status": "completed", "priority": "high"}, {"id": "redesign-4", "content": "Update WebSocket protocol for status monitoring", "status": "completed", "priority": "high"}, {"id": "redesign-5", "content": "Create customer waiting status display system", "status": "completed", "priority": "medium"}, {"id": "redesign-6", "content": "Update implementation roadmap", "status": "in_progress", "priority": "medium"}]