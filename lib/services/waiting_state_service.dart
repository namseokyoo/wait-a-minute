import 'package:flutter/foundation.dart';

/// Service to manage waiting state and notify monitor devices
class WaitingStateService extends ChangeNotifier {
  // Current state
  bool _isWaitingState = false;
  DateTime? _lastStateChange;
  String _cctvDeviceId = '';
  String _cctvLocation = '';

  // State change listeners
  final List<Function(bool)> _stateChangeCallbacks = [];

  // Getters
  bool get isWaitingState => _isWaitingState;
  DateTime? get lastStateChange => _lastStateChange;
  String get cctvDeviceId => _cctvDeviceId;
  String get cctvLocation => _cctvLocation;

  /// Initialize with CCTV device information
  void initializeCCTV(String deviceId, String location) {
    _cctvDeviceId = deviceId;
    _cctvLocation = location;

    if (kDebugMode) {
      print(
        'WaitingStateService initialized for device: $deviceId at $location',
      );
    }
  }

  /// Update waiting state from CCTV device
  void updateWaitingState(bool newState, {String? sourceDeviceId}) {
    // Only accept updates from the registered CCTV device
    if (sourceDeviceId != null && sourceDeviceId != _cctvDeviceId) {
      if (kDebugMode) {
        print(
          'Ignoring state update from unauthorized device: $sourceDeviceId',
        );
      }
      return;
    }

    if (_isWaitingState != newState) {
      final previousState = _isWaitingState;
      _isWaitingState = newState;
      _lastStateChange = DateTime.now();

      if (kDebugMode) {
        print('Waiting state changed: $previousState -> $newState');
      }

      // Notify all listeners
      notifyListeners();

      // Trigger state change callbacks (for notifications)
      for (final callback in _stateChangeCallbacks) {
        try {
          callback(newState);
        } catch (e) {
          if (kDebugMode) {
            print('Error in state change callback: $e');
          }
        }
      }
    }
  }

  /// Add callback for state changes (used for notifications)
  void addStateChangeCallback(Function(bool) callback) {
    _stateChangeCallbacks.add(callback);
  }

  /// Remove callback for state changes
  void removeStateChangeCallback(Function(bool) callback) {
    _stateChangeCallbacks.remove(callback);
  }

  /// Get current state description
  String getStateDescription() {
    if (_isWaitingState) {
      return '대기인원 있음';
    } else {
      return '대기인원 없음';
    }
  }

  /// Get detailed state information
  Map<String, dynamic> getStateInfo() {
    return {
      'isWaitingState': _isWaitingState,
      'lastStateChange': _lastStateChange?.toIso8601String(),
      'cctvDeviceId': _cctvDeviceId,
      'cctvLocation': _cctvLocation,
      'stateDescription': getStateDescription(),
    };
  }

  /// Reset state
  void reset() {
    _isWaitingState = false;
    _lastStateChange = null;
    _stateChangeCallbacks.clear();
    notifyListeners();
  }

  /// Get time since last state change
  Duration? getTimeSinceLastChange() {
    if (_lastStateChange == null) return null;
    return DateTime.now().difference(_lastStateChange!);
  }

  /// Check if state change is recent (within specified duration)
  bool isRecentStateChange([Duration threshold = const Duration(seconds: 30)]) {
    final timeSince = getTimeSinceLastChange();
    return timeSince != null && timeSince < threshold;
  }
}
