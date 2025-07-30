import 'dart:async';
import 'package:flutter/foundation.dart';
import 'firebase_realtime_service.dart';

/// Health check system for monitoring device registration and connection status
class DeviceHealthChecker {
  static final DeviceHealthChecker _instance = DeviceHealthChecker._internal();
  factory DeviceHealthChecker() => _instance;
  DeviceHealthChecker._internal();

  final FirebaseRealtimeService _firebaseService = FirebaseRealtimeService();
  Timer? _healthCheckTimer;
  bool _isHealthCheckActive = false;

  // Health check callbacks
  Function(String deviceId, String error)? onRegistrationFailure;
  Function(String deviceId)? onConnectionRestored;
  Function(String deviceId, Map<String, dynamic> metrics)? onHealthMetrics;

  /// Start health check monitoring
  void startHealthCheck({
    Duration interval = const Duration(minutes: 2),
    Function(String deviceId, String error)? onRegistrationFailure,
    Function(String deviceId)? onConnectionRestored,
    Function(String deviceId, Map<String, dynamic> metrics)? onHealthMetrics,
  }) {
    if (_isHealthCheckActive) {
      if (kDebugMode) {
        print('DeviceHealthChecker: Health check already active');
      }
      return;
    }

    this.onRegistrationFailure = onRegistrationFailure;
    this.onConnectionRestored = onConnectionRestored;
    this.onHealthMetrics = onHealthMetrics;

    _healthCheckTimer = Timer.periodic(interval, (timer) {
      _performHealthCheck();
    });

    _isHealthCheckActive = true;

    if (kDebugMode) {
      print('DeviceHealthChecker: Health check started with ${interval.inMinutes}분 간격');
    }
  }

  /// Stop health check monitoring
  void stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _isHealthCheckActive = false;

    if (kDebugMode) {
      print('DeviceHealthChecker: Health check stopped');
    }
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    try {
      if (kDebugMode) {
        print('DeviceHealthChecker: Performing health check...');
      }

      // 1. Check Firebase connection
      final isConnected = await _checkFirebaseConnection();
      
      // 2. Check device registration status
      // (This would be called with specific device IDs from the services)
      
      if (kDebugMode) {
        print('DeviceHealthChecker: Health check completed - Connected: $isConnected');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DeviceHealthChecker: Health check failed - $e');
      }
    }
  }

  /// Check Firebase connection status
  Future<bool> _checkFirebaseConnection() async {
    try {
      return await _firebaseService.checkConnection();
    } catch (e) {
      if (kDebugMode) {
        print('DeviceHealthChecker: Firebase connection check failed - $e');
      }
      return false;
    }
  }

  /// Check device registration status
  Future<bool> checkDeviceRegistration(String deviceId) async {
    try {
      // Check if device exists in Firebase
      final deviceStatus = await _firebaseService.getDeviceStatus(deviceId);
      final isRegistered = deviceStatus != null;
      
      if (kDebugMode) {
        print('DeviceHealthChecker: Device $deviceId registration check - $isRegistered');
      }

      // Collect health metrics
      final metrics = {
        'isRegistered': isRegistered,
        'checkTime': DateTime.now().millisecondsSinceEpoch,
        'deviceStatus': deviceStatus,
      };

      onHealthMetrics?.call(deviceId, metrics);
      
      return isRegistered;
    } catch (e) {
      if (kDebugMode) {
        print('DeviceHealthChecker: Device registration check failed for $deviceId - $e');
      }
      
      onRegistrationFailure?.call(deviceId, e.toString());
      return false;
    }
  }

  /// Recover device registration
  Future<bool> recoverDevice(
    String deviceId, 
    Future<void> Function() reregistrationCallback
  ) async {
    try {
      if (kDebugMode) {
        print('DeviceHealthChecker: Attempting device recovery for $deviceId');
      }

      // 1. Check Firebase connection and reinitialize if needed
      final isConnected = await _checkFirebaseConnection();
      if (!isConnected) {
        await _firebaseService.initialize();
      }

      // 2. Call the reregistration callback
      await reregistrationCallback();

      // 3. Verify recovery
      await Future.delayed(Duration(seconds: 2)); // Wait for registration to complete
      final isRecovered = await checkDeviceRegistration(deviceId);

      if (isRecovered) {
        onConnectionRestored?.call(deviceId);
        if (kDebugMode) {
          print('DeviceHealthChecker: Device recovery successful for $deviceId');
        }
      } else {
        if (kDebugMode) {
          print('DeviceHealthChecker: Device recovery failed for $deviceId');
        }
      }

      return isRecovered;
    } catch (e) {
      if (kDebugMode) {
        print('DeviceHealthChecker: Device recovery error for $deviceId - $e');
      }
      return false;
    }
  }

  /// Get health check status
  bool get isActive => _isHealthCheckActive;

  /// Dispose resources
  void dispose() {
    stopHealthCheck();
  }
}