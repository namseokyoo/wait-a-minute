/// WebSocket message types
enum MessageType {
  /// Device registration
  deviceRegister,

  /// Status update from CCTV to Monitor
  statusUpdate,

  /// Settings sync from Monitor to CCTV
  settingsSync,

  /// Customer waiting alert
  customerWaiting,

  /// Heartbeat keepalive
  heartbeat,
}

/// Base WebSocket message structure
class WebSocketMessage {
  final MessageType type;
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  WebSocketMessage({
    required this.type,
    required this.deviceId,
    required this.deviceName,
    DateTime? timestamp,
    required this.payload,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from JSON
  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.heartbeat,
      ),
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      payload: json['payload'] ?? {},
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }
}

/// Status update message from CCTV to Monitor
class StatusUpdateMessage extends WebSocketMessage {
  StatusUpdateMessage({
    required String deviceId,
    required String deviceName,
    required bool isMonitoring,
    required bool isOnline,
    required double blueIntensity,
    required double batteryLevel,
    required String location,
    DateTime? timestamp,
  }) : super(
         type: MessageType.statusUpdate,
         deviceId: deviceId,
         deviceName: deviceName,
         timestamp: timestamp,
         payload: {
           'isMonitoring': isMonitoring,
           'isOnline': isOnline,
           'blueIntensity': blueIntensity,
           'batteryLevel': batteryLevel,
           'location': location,
         },
       );
}

/// Settings sync message from Monitor to CCTV
class SettingsSyncMessage extends WebSocketMessage {
  SettingsSyncMessage({
    required String deviceId,
    required String deviceName,
    required double blueSensitivity,
    required bool pushAlertsEnabled,
    required List<String> targetDevices,
    DateTime? timestamp,
  }) : super(
         type: MessageType.settingsSync,
         deviceId: deviceId,
         deviceName: deviceName,
         timestamp: timestamp,
         payload: {
           'blueSensitivity': blueSensitivity,
           'pushAlertsEnabled': pushAlertsEnabled,
           'targetDevices': targetDevices,
         },
       );
}

/// Customer waiting alert message
class CustomerWaitingMessage extends WebSocketMessage {
  CustomerWaitingMessage({
    required String deviceId,
    required String deviceName,
    required String message,
    required double intensity,
    required String location,
    required double duration,
    DateTime? timestamp,
  }) : super(
         type: MessageType.customerWaiting,
         deviceId: deviceId,
         deviceName: deviceName,
         timestamp: timestamp,
         payload: {
           'message': message,
           'intensity': intensity,
           'location': location,
           'duration': duration,
         },
       );
}
