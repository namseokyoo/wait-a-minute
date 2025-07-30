import 'package:uuid/uuid.dart';

/// Represents a CCTV device in the system
class CCTVDevice {
  final String id;
  final String name;
  final String location;
  bool isOnline;
  bool isMonitoring;
  double blueIntensity;
  bool isBlueDetected;
  double batteryLevel;
  DateTime lastUpdate;

  CCTVDevice({
    String? id,
    required this.name,
    required this.location,
    this.isOnline = false,
    this.isMonitoring = false,
    this.blueIntensity = 0.0,
    this.isBlueDetected = false,
    this.batteryLevel = 1.0,
    DateTime? lastUpdate,
  }) : id = id ?? const Uuid().v4(),
       lastUpdate = lastUpdate ?? DateTime.now();

  /// Update device status from WebSocket message
  void updateStatus(Map<String, dynamic> status, double sensitivityThreshold) {
    isOnline = status['isOnline'] ?? isOnline;
    isMonitoring = status['isMonitoring'] ?? isMonitoring;
    blueIntensity = (status['blueIntensity'] ?? blueIntensity).toDouble();
    batteryLevel = (status['batteryLevel'] ?? batteryLevel).toDouble();

    // Apply Monitor's sensitivity threshold
    isBlueDetected = blueIntensity >= sensitivityThreshold;

    lastUpdate = DateTime.now();
  }

  /// Create device from JSON
  factory CCTVDevice.fromJson(Map<String, dynamic> json) {
    return CCTVDevice(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      isOnline: json['isOnline'] ?? false,
      isMonitoring: json['isMonitoring'] ?? false,
      blueIntensity: (json['blueIntensity'] ?? 0.0).toDouble(),
      isBlueDetected: json['isBlueDetected'] ?? false,
      batteryLevel: (json['batteryLevel'] ?? 1.0).toDouble(),
      lastUpdate:
          json['lastUpdate'] != null
              ? DateTime.parse(json['lastUpdate'])
              : DateTime.now(),
    );
  }

  /// Convert device to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'isOnline': isOnline,
      'isMonitoring': isMonitoring,
      'blueIntensity': blueIntensity,
      'isBlueDetected': isBlueDetected,
      'batteryLevel': batteryLevel,
      'lastUpdate': lastUpdate.toIso8601String(),
    };
  }

  /// Check if device is in alert state (blue detected and monitoring)
  bool get isInAlertState => isOnline && isMonitoring && isBlueDetected;

  /// Get time since last update in minutes
  int get minutesSinceLastUpdate {
    return DateTime.now().difference(lastUpdate).inMinutes;
  }

  /// Check if device status is stale (no update for >5 minutes)
  bool get isStale => minutesSinceLastUpdate > 5;
}
