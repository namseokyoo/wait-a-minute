# WebSocket Communication Architecture

## Overview
Real-time bidirectional communication system for blue light alert transmission between CCTV and Monitor devices using free WebSocket servers.

## Communication Protocol Design

### Message Types
```dart
enum MessageType {
  deviceRegister,   // Device registration and identification
  blueAlert,        // Blue light detection alert
  heartbeat,        // Connection keepalive
  alertAck,         // Alert acknowledgment
  deviceStatus,     // Device status update
  settings,         // Settings synchronization
}
```

### Message Format Specification
```dart
// Base message structure
class WebSocketMessage {
  final MessageType type;
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  
  // JSON serialization
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'timestamp': timestamp.toIso8601String(),
    'payload': payload,
  };
}
```

### Specific Message Formats

#### 1. Device Registration
```json
{
  "type": "deviceRegister",
  "deviceId": "cctv_living_room_001",
  "deviceName": "Living Room Camera",
  "timestamp": "2024-01-15T10:30:00Z",
  "payload": {
    "mode": "cctv",
    "capabilities": ["blue_detection", "image_capture"],
    "location": "living_room",
    "version": "1.0.0"
  }
}
```

#### 2. Blue Light Alert
```json
{
  "type": "blueAlert", 
  "deviceId": "cctv_living_room_001",
  "deviceName": "Living Room Camera",
  "timestamp": "2024-01-15T10:30:15Z",
  "payload": {
    "intensity": 0.85,
    "duration": 2.5,
    "location": "living_room",
    "confidence": 0.92,
    "detectionArea": {
      "x": 120,
      "y": 80, 
      "width": 200,
      "height": 150
    },
    "imageData": "base64_encoded_thumbnail_optional"
  }
}
```

#### 3. Heartbeat
```json
{
  "type": "heartbeat",
  "deviceId": "cctv_living_room_001", 
  "deviceName": "Living Room Camera",
  "timestamp": "2024-01-15T10:31:00Z",
  "payload": {
    "status": "active",
    "batteryLevel": 0.78,
    "signalStrength": 0.95,
    "lastDetection": "2024-01-15T10:30:15Z"
  }
}
```

## WebSocket Service Architecture

### Core Service Implementation
```dart
class WebSocketService extends ChangeNotifier {
  static const String DEFAULT_SERVER = 'wss://echo.websocket.org/';
  static const Duration HEARTBEAT_INTERVAL = Duration(seconds: 30);
  static const Duration RECONNECT_INTERVAL = Duration(seconds: 5);
  
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  ConnectionState _state = ConnectionState.disconnected;
  List<String> _connectedDevices = [];
  List<AlertMessage> _alertHistory = [];
  
  // Connection Management
  Future<void> connect({String? serverUrl}) async {
    final url = serverUrl ?? DEFAULT_SERVER;
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _state = ConnectionState.connected;
      
      // Setup message listener
      _channel!.stream.listen(
        _onMessageReceived,
        onError: _onError,
        onDone: _onDisconnected,
      );
      
      // Start heartbeat
      _startHeartbeat();
      
      // Register this device
      await _registerDevice();
      
      notifyListeners();
    } catch (e) {
      _state = ConnectionState.error;
      _scheduleReconnect();
      notifyListeners();
    }
  }
  
  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _state = ConnectionState.disconnected;
    notifyListeners();
  }
  
  // Message Sending
  void sendAlert(AlertMessage alert) {
    if (_state != ConnectionState.connected) return;
    
    final message = WebSocketMessage(
      type: MessageType.blueAlert,
      deviceId: _getDeviceId(),
      deviceName: _getDeviceName(),
      timestamp: DateTime.now(),
      payload: alert.toMap(),
    );
    
    _sendMessage(message);
  }
  
  void _sendMessage(WebSocketMessage message) {
    if (_channel == null) return;
    
    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
    } catch (e) {
      print('Failed to send message: $e');
    }
  }
  
  // Message Handling
  void _onMessageReceived(dynamic data) {
    try {
      final Map<String, dynamic> json = jsonDecode(data);
      final message = WebSocketMessage.fromJson(json);
      
      switch (message.type) {
        case MessageType.blueAlert:
          _handleBlueAlert(message);
          break;
        case MessageType.deviceRegister:
          _handleDeviceRegister(message);
          break;
        case MessageType.heartbeat:
          _handleHeartbeat(message);
          break;
        default:
          print('Unknown message type: ${message.type}');
      }
    } catch (e) {
      print('Failed to parse message: $e');
    }
  }
  
  void _handleBlueAlert(WebSocketMessage message) {
    final alert = AlertMessage.fromMap(message.payload);
    _alertHistory.add(alert);
    
    // Notify UI
    _onAlertReceived?.call(alert);
    
    // Trigger local notifications
    _notificationService.showAlert(alert);
    
    notifyListeners();
  }
  
  // Connection Reliability
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(HEARTBEAT_INTERVAL, (_) {
      _sendHeartbeat();
    });
  }
  
  void _sendHeartbeat() {
    final message = WebSocketMessage(
      type: MessageType.heartbeat,
      deviceId: _getDeviceId(),
      deviceName: _getDeviceName(),
      timestamp: DateTime.now(),
      payload: {
        'status': 'active',
        'mode': _currentMode.name,
      },
    );
    
    _sendMessage(message);
  }
  
  void _scheduleReconnect() {
    _reconnectTimer = Timer(RECONNECT_INTERVAL, () {
      if (_state == ConnectionState.error) {
        connect();
      }
    });
  }
}
```

## Free WebSocket Server Options

### 1. WebSocket.org Echo Server
```dart
class EchoServerConfig {
  static const String SERVER_URL = 'wss://echo.websocket.org/';
  static const bool REQUIRES_AUTH = false;
  static const int MAX_MESSAGE_SIZE = 1024 * 1024; // 1MB
  
  // Pros: Free, no registration, immediate use
  // Cons: Echoes messages to all clients, no persistence
  // Best for: Development, testing, simple deployments
}
```

### 2. Pusher Channels (Free Tier)
```dart
class PusherConfig {
  static const String APP_ID = 'your_app_id';
  static const String KEY = 'your_key';
  static const String SECRET = 'your_secret';
  static const String CLUSTER = 'us2';
  
  static String get serverUrl => 
    'wss://ws-$CLUSTER.pusher.app/app/$KEY?protocol=7';
    
  // Pros: 100 connections, 200k messages/day, reliable
  // Cons: Requires registration, complex setup
  // Best for: Production, multiple devices
}
```

### 3. Socket.IO Test Server
```dart
class SocketIOConfig {
  static const String SERVER_URL = 'wss://socketio-echo-server.herokuapp.com/';
  static const bool SUPPORTS_ROOMS = true;
  
  // Pros: Room-based messaging, Socket.IO features
  // Cons: May be unstable, Heroku free tier limitations
  // Best for: Advanced features testing
}
```

### 4. Custom Channel Implementation
```dart
class ChannelBasedMessaging {
  static const String CHANNEL_PREFIX = 'blue_light_monitor_';
  
  String get channelName => '$CHANNEL_PREFIX${_groupId}';
  
  // Use channel/room concept for grouped messaging
  void joinChannel(String groupId) {
    _groupId = groupId;
    
    final joinMessage = {
      'action': 'join_channel',
      'channel': channelName,
      'deviceId': _getDeviceId(),
    };
    
    _sendMessage(joinMessage);
  }
}
```

## Message Routing & Filtering

### Device Management
```dart
class DeviceManager {
  Map<String, DeviceInfo> _devices = {};
  String? _groupId;
  
  void registerDevice(DeviceInfo device) {
    _devices[device.id] = device;
    notifyListeners();
  }
  
  List<DeviceInfo> get cctvDevices => 
    _devices.values.where((d) => d.mode == AppMode.cctv).toList();
    
  List<DeviceInfo> get monitorDevices => 
    _devices.values.where((d) => d.mode == AppMode.monitor).toList();
    
  // Group-based messaging
  void setGroup(String groupId) {
    _groupId = groupId;
    // Re-register with new group
    _webSocketService.rejoinWithGroup(groupId);
  }
}
```

### Message Filtering
```dart
class MessageFilter {
  bool shouldProcessMessage(WebSocketMessage message) {
    // Filter by group ID
    if (_groupId != null) {
      final messageGroup = message.payload['groupId'];
      if (messageGroup != _groupId) return false;
    }
    
    // Filter by device type
    if (_currentMode == AppMode.monitor) {
      return message.type == MessageType.blueAlert ||
             message.type == MessageType.deviceRegister;
    }
    
    // Filter by message age
    final age = DateTime.now().difference(message.timestamp);
    if (age > Duration(minutes: 5)) return false;
    
    return true;
  }
}
```

## Error Handling & Resilience

### Reconnection Strategy
```dart
class ReconnectionManager {
  int _reconnectAttempts = 0;
  static const int MAX_ATTEMPTS = 10;
  static const List<Duration> BACKOFF_DELAYS = [
    Duration(seconds: 1),
    Duration(seconds: 2), 
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
  ];
  
  Future<void> attemptReconnect() async {
    if (_reconnectAttempts >= MAX_ATTEMPTS) {
      _onMaxAttemptsReached();
      return;
    }
    
    final delay = BACKOFF_DELAYS[
      math.min(_reconnectAttempts, BACKOFF_DELAYS.length - 1)
    ];
    
    await Future.delayed(delay);
    
    try {
      await _webSocketService.connect();
      _reconnectAttempts = 0; // Reset on success
    } catch (e) {
      _reconnectAttempts++;
      _scheduleReconnect();
    }
  }
}
```

### Message Queue for Offline Mode
```dart
class OfflineMessageQueue {
  final List<WebSocketMessage> _queue = [];
  static const int MAX_QUEUE_SIZE = 100;
  
  void queueMessage(WebSocketMessage message) {
    _queue.add(message);
    
    // Keep queue size manageable
    if (_queue.length > MAX_QUEUE_SIZE) {
      _queue.removeAt(0);
    }
    
    // Persist to local storage
    _saveQueueToStorage();
  }
  
  Future<void> flushQueue() async {
    while (_queue.isNotEmpty) {
      final message = _queue.removeAt(0);
      
      try {
        await _webSocketService._sendMessage(message);
      } catch (e) {
        // Re-queue message on failure
        _queue.insert(0, message);
        break;
      }
    }
    
    _saveQueueToStorage();
  }
}
```

## Security Considerations

### Message Validation
```dart
class MessageValidator {
  bool isValidMessage(Map<String, dynamic> json) {
    // Required fields check
    if (!json.containsKey('type') || 
        !json.containsKey('deviceId') ||
        !json.containsKey('timestamp')) {
      return false;
    }
    
    // Timestamp validation (not too old/future)
    final timestamp = DateTime.tryParse(json['timestamp']);
    if (timestamp == null) return false;
    
    final now = DateTime.now();
    final age = now.difference(timestamp).abs();
    if (age > Duration(hours: 1)) return false;
    
    // Message size limit
    final messageSize = jsonEncode(json).length;
    if (messageSize > 10 * 1024) return false; // 10KB limit
    
    return true;
  }
}
```

### Rate Limiting
```dart
class RateLimiter {
  final Map<String, List<DateTime>> _deviceMessageTimes = {};
  static const int MAX_MESSAGES_PER_MINUTE = 60;
  
  bool isAllowed(String deviceId) {
    final now = DateTime.now();
    final deviceTimes = _deviceMessageTimes[deviceId] ?? [];
    
    // Remove old timestamps
    deviceTimes.removeWhere((time) => 
      now.difference(time) > Duration(minutes: 1)
    );
    
    // Check rate limit
    if (deviceTimes.length >= MAX_MESSAGES_PER_MINUTE) {
      return false;
    }
    
    // Add current timestamp
    deviceTimes.add(now);
    _deviceMessageTimes[deviceId] = deviceTimes;
    
    return true;
  }
}
```