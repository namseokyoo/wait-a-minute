import 'package:flutter/foundation.dart';

/// Smart update manager for optimizing Firebase update frequency based on context
class SmartUpdateManager {
  static final SmartUpdateManager _instance = SmartUpdateManager._internal();
  factory SmartUpdateManager() => _instance;
  SmartUpdateManager._internal();

  // Current update intervals
  Duration _updateInterval = Duration(seconds: 1);
  DateTime? _lastCriticalUpdate;
  bool _isAppInBackground = false;
  bool _isWaitingState = false;

  // Performance metrics
  int _updateCount = 0;
  DateTime _sessionStart = DateTime.now();

  /// Get optimal update interval based on current context
  Duration getOptimalUpdateInterval({
    required bool isWaitingState,
    required bool isAppInBackground,
  }) {
    _isWaitingState = isWaitingState;
    _isAppInBackground = isAppInBackground;

    Duration interval;

    if (isWaitingState) {
      // More frequent updates when waiting customers detected
      interval = Duration(milliseconds: 500);
    } else if (isAppInBackground) {
      // Less frequent updates when app is in background
      interval = Duration(seconds: 30);
    } else {
      // Default update frequency for active monitoring
      interval = Duration(seconds: 1);
    }

    // Apply adaptive throttling based on update frequency
    interval = _applyAdaptiveThrottling(interval);

    _updateInterval = interval;
    return interval;
  }

  /// Apply adaptive throttling to prevent excessive updates
  Duration _applyAdaptiveThrottling(Duration baseInterval) {
    final now = DateTime.now();
    final sessionDuration = now.difference(_sessionStart);

    // If we've been updating very frequently for a long time, slow down slightly
    if (sessionDuration.inMinutes > 30 && _updateCount > 1000) {
      if (kDebugMode) {
        print('SmartUpdateManager: Applying adaptive throttling');
      }
      return Duration(
        milliseconds: (baseInterval.inMilliseconds * 1.2).round(),
      );
    }

    return baseInterval;
  }

  /// Check if update should be performed based on smart criteria
  bool shouldUpdate({
    required bool isWaitingState,
    required bool isAppInBackground,
    required double blueIntensity,
    required double previousBlueIntensity,
  }) {
    final now = DateTime.now();

    // Always update if waiting state changed
    if (isWaitingState != _isWaitingState) {
      _lastCriticalUpdate = now;
      _recordUpdate(critical: true);
      return true;
    }

    // Always update if blue intensity changed significantly
    final intensityDelta = (blueIntensity - previousBlueIntensity).abs();
    if (intensityDelta > 0.05) {
      // 5% change threshold
      _recordUpdate();
      return true;
    }

    // Skip updates if app is in background and no critical changes
    if (isAppInBackground && !isWaitingState && intensityDelta < 0.01) {
      return false;
    }

    // Regular interval-based updates
    final timeSinceLastCritical =
        _lastCriticalUpdate != null
            ? now.difference(_lastCriticalUpdate!)
            : Duration.zero;

    if (timeSinceLastCritical >=
        getOptimalUpdateInterval(
          isWaitingState: isWaitingState,
          isAppInBackground: isAppInBackground,
        )) {
      _recordUpdate();
      return true;
    }

    return false;
  }

  /// Record update for metrics
  void _recordUpdate({bool critical = false}) {
    _updateCount++;

    if (critical) {
      _lastCriticalUpdate = DateTime.now();
    }

    if (kDebugMode && _updateCount % 100 == 0) {
      final sessionDuration = DateTime.now().difference(_sessionStart);
      final updatesPerMinute = _updateCount / sessionDuration.inMinutes;
      print(
        'SmartUpdateManager: $updatesPerMinute updates/min (total: $_updateCount)',
      );
    }
  }

  /// Get current update statistics
  Map<String, dynamic> getUpdateStats() {
    final sessionDuration = DateTime.now().difference(_sessionStart);
    return {
      'totalUpdates': _updateCount,
      'sessionDurationMinutes': sessionDuration.inMinutes,
      'averageUpdatesPerMinute':
          sessionDuration.inMinutes > 0
              ? _updateCount / sessionDuration.inMinutes
              : 0,
      'currentInterval': _updateInterval.inMilliseconds,
      'isWaitingState': _isWaitingState,
      'isAppInBackground': _isAppInBackground,
    };
  }

  /// Reset statistics
  void resetStats() {
    _updateCount = 0;
    _sessionStart = DateTime.now();
    _lastCriticalUpdate = null;

    if (kDebugMode) {
      print('SmartUpdateManager: Statistics reset');
    }
  }

  /// Get recommended UI update interval (separate from Firebase updates)
  Duration getUIUpdateInterval({
    required bool isWaitingState,
    required bool isAppInBackground,
  }) {
    if (isAppInBackground) {
      return Duration(seconds: 5); // Very infrequent UI updates in background
    } else if (isWaitingState) {
      return Duration(milliseconds: 200); // Smooth UI updates when active
    } else {
      return Duration(milliseconds: 100); // Regular UI updates
    }
  }

  /// Optimize update frequency based on battery level (future enhancement)
  Duration getOptimalUpdateIntervalForBattery({
    required Duration baseInterval,
    required double batteryLevel,
  }) {
    if (batteryLevel < 0.2) {
      // Below 20% battery
      return Duration(
        milliseconds: (baseInterval.inMilliseconds * 1.5).round(),
      );
    } else if (batteryLevel < 0.1) {
      // Below 10% battery
      return Duration(
        milliseconds: (baseInterval.inMilliseconds * 2.0).round(),
      );
    }

    return baseInterval;
  }
}
