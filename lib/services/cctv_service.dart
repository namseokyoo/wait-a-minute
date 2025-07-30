import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';
import '../models/connection_state.dart';
import '../models/status_message.dart';

/// CCTV service for simplified camera operations
class CCTVService extends ChangeNotifier {
  // Camera related
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isMonitoring = false;
  bool _isCameraInitialized = false;

  // Device info
  final String _deviceId = const Uuid().v4();
  final String _deviceName;
  final String _location;

  // Status tracking
  ConnectionState _connectionState = ConnectionState.disconnected;
  double _blueIntensity = 0.0;
  double _batteryLevel = 1.0;

  // Settings from Monitor (removed unused fields)

  CCTVService({required String deviceName, required String location})
    : _deviceName = deviceName,
      _location = location;

  // Getters
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get location => _location;
  bool get isMonitoring => _isMonitoring;
  bool get isCameraInitialized => _isCameraInitialized;
  ConnectionState get connectionState => _connectionState;
  double get blueIntensity => _blueIntensity;
  double get batteryLevel => _batteryLevel;
  CameraController? get cameraController => _cameraController;

  /// Initialize camera system
  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('카메라를 찾을 수 없습니다');
      }

      // Use back camera (first camera is usually back camera)
      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.medium, // Medium resolution for battery efficiency
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      notifyListeners();
    } catch (e) {
      print('카메라 초기화 실패: $e');
      _isCameraInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Start monitoring (camera and blue light detection)
  Future<void> startMonitoring() async {
    if (!_isCameraInitialized) {
      await initializeCamera();
    }

    _isMonitoring = true;
    notifyListeners();

    // Start blue light detection (simplified for now)
    _startBlueDetectionLoop();
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _blueIntensity = 0.0;
    notifyListeners();
  }

  /// Update connection state
  void setConnectionState(ConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  /// Update settings from Monitor (deprecated - settings moved to monitor services)
  void updateSettings({double? blueSensitivity, bool? pushAlertsEnabled}) {
    // Settings are now managed by monitor services
    // This method is kept for compatibility
    notifyListeners();
  }

  /// Generate status message for WebSocket transmission
  StatusUpdateMessage generateStatusMessage() {
    return StatusUpdateMessage(
      deviceId: _deviceId,
      deviceName: _deviceName,
      isMonitoring: _isMonitoring,
      isOnline: true,
      blueIntensity: _blueIntensity,
      batteryLevel: _batteryLevel,
      location: _location,
    );
  }

  /// Simplified blue light detection loop
  void _startBlueDetectionLoop() async {
    while (_isMonitoring && _isCameraInitialized) {
      try {
        // Simulate blue light detection
        // In real implementation, this would analyze camera frames
        await Future.delayed(const Duration(milliseconds: 500));

        if (_isMonitoring) {
          // Simulate varying blue intensity (for demo purposes)
          _blueIntensity = (_blueIntensity + (0.1 - 0.05)) % 1.0;

          // Update battery level (simulate drain)
          _batteryLevel = (_batteryLevel - 0.0001).clamp(0.0, 1.0);

          notifyListeners();
        }
      } catch (e) {
        print('Blue detection error: $e');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
