import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Simplified CCTV service without camera dependencies
class SimplifiedCCTVService extends ChangeNotifier {
  // Device info
  final String _deviceId = const Uuid().v4();
  final String _deviceName;
  final String _location;

  // Status tracking
  bool _isMonitoring = false;
  double _blueIntensity = 0.0;
  double _batteryLevel = 1.0;
  final bool _isOnline = true;

  SimplifiedCCTVService({required String deviceName, required String location})
    : _deviceName = deviceName,
      _location = location;

  // Getters
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get location => _location;
  bool get isMonitoring => _isMonitoring;
  double get blueIntensity => _blueIntensity;
  double get batteryLevel => _batteryLevel;
  bool get isOnline => _isOnline;

  /// Start monitoring (simulated)
  void startMonitoring() {
    _isMonitoring = true;
    notifyListeners();

    // Simulate blue light detection
    _startSimulatedDetection();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _blueIntensity = 0.0;
    notifyListeners();
  }

  /// Simulate blue light detection with varying intensity
  void _startSimulatedDetection() async {
    while (_isMonitoring) {
      await Future.delayed(const Duration(milliseconds: 1000));

      if (_isMonitoring) {
        // Simulate random blue light intensity
        _blueIntensity = (_blueIntensity + (0.1 - 0.2 * _blueIntensity)).clamp(
          0.0,
          1.0,
        );

        // Simulate battery drain
        _batteryLevel = (_batteryLevel - 0.0001).clamp(0.0, 1.0);

        notifyListeners();
      }
    }
  }

  /// Generate status data
  Map<String, dynamic> getStatusData() {
    return {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'location': _location,
      'isOnline': _isOnline,
      'isMonitoring': _isMonitoring,
      'blueIntensity': _blueIntensity,
      'batteryLevel': _batteryLevel,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }
}
