import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_initialization_service.dart';
import 'batch_cleanup_manager.dart';

/// Firebase Realtime Database service for real-time state synchronization
class FirebaseRealtimeService extends ChangeNotifier {
  static final FirebaseRealtimeService _instance =
      FirebaseRealtimeService._internal();
  factory FirebaseRealtimeService() => _instance;
  FirebaseRealtimeService._internal();

  DatabaseReference? _database;
  bool _isInitialized = false;
  final Map<String, StreamSubscription> _listeners = {};
  final BatchCleanupManager _batchCleanupManager = BatchCleanupManager();

  // Getters
  bool get isInitialized => _isInitialized;
  DatabaseReference? get database => _database;

  /// Initialize Firebase Realtime Database
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Wait for Firebase initialization to complete with timeout
      final firebaseInitService = FirebaseInitializationService();
      final initializationFuture = firebaseInitService.waitForInitialization();
      final isReady = await initializationFuture.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            print('FirebaseRealtimeService: Firebase 초기화 타임아웃');
          }
          return false;
        },
      );

      if (!isReady) {
        if (kDebugMode) {
          print('FirebaseRealtimeService: Firebase 초기화가 완료되지 않음');
        }
        return false;
      }

      // Verify authentication (웹에서는 익명 인증이 완료되어야 함)
      final user = firebaseInitService.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('FirebaseRealtimeService: 인증된 사용자가 없음 - 익명 인증 재시도');
        }
        // 웹에서 익명 인증 재시도
        final authSuccess = await firebaseInitService.initializeAuth();
        if (!authSuccess) {
          if (kDebugMode) {
            print('FirebaseRealtimeService: 익명 인증 재시도 실패');
          }
          return false;
        }
      }

      final currentUser = firebaseInitService.currentUser;
      if (kDebugMode) {
        print('FirebaseRealtimeService: 인증 확인 완료 - ${currentUser?.uid}');
      }

      // Initialize database connection with proper web configuration
      if (kIsWeb) {
        _database = FirebaseDatabase.instance.ref();
        if (kDebugMode) {
          print('FirebaseRealtimeService: 웹 데이터베이스 연결 설정');
        }
      } else {
        _database = FirebaseDatabase.instance.ref();
        if (kDebugMode) {
          print('FirebaseRealtimeService: 모바일 데이터베이스 연결 설정');
        }
      }

      // Test database connection by writing a test value
      await _testDatabaseConnection();

      _isInitialized = true;

      if (kDebugMode) {
        print('FirebaseRealtimeService: 데이터베이스 연결 완료');
      }

      // Start batch cleanup system after successful initialization
      _batchCleanupManager.startBatchCleanup(database: _database);

      if (kDebugMode) {
        print('FirebaseRealtimeService: 배치 정리 시스템 시작됨');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseRealtimeService: 초기화 실패 - $e');
      }
      return false;
    }
  }

  /// Test database connection
  Future<void> _testDatabaseConnection() async {
    if (_database == null) return;

    try {
      final testRef = _database!.child('_test');
      await testRef.set({
        'timestamp': ServerValue.timestamp,
        'platform': kIsWeb ? 'web' : 'mobile',
      });

      // Read it back to confirm it works
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        if (kDebugMode) {
          print('FirebaseRealtimeService: 데이터베이스 읽기/쓰기 테스트 성공');
        }
        // Clean up test data
        await testRef.remove();
      }
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseRealtimeService: 데이터베이스 연결 테스트 실패 - $e');
      }
      // Don't throw - just log the error
    }
  }

  /// Register monitor device (simplified, no FCM)
  Future<void> registerMonitorDevice(String deviceId, String deviceName) async {
    if (!_isInitialized || _database == null) {
      if (kDebugMode) {
        print('Firebase not initialized');
      }
      return;
    }

    try {
      final monitorRef = _database!.child('monitors').child(deviceId);

      await monitorRef.set({
        'deviceName': deviceName,
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'registeredAt': ServerValue.timestamp,
      });

      // Set up presence tracking for monitor
      await _setupMonitorPresence(deviceId);

      if (kDebugMode) {
        print('Monitor device registered: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register monitor device: $e');
      }
    }
  }

  /// Setup monitor presence tracking with smart persistence
  Future<void> _setupMonitorPresence(String deviceId) async {
    try {
      final monitorRef = _database!.child('monitors').child(deviceId);
      final connectedRef = FirebaseDatabase.instance.ref('.info/connected');

      // Listen to connection status
      connectedRef.onValue.listen((event) {
        if (event.snapshot.value == true) {
          // When connected, ensure monitor is marked online
          monitorRef.update({
            'isOnline': true,
            'lastSeen': ServerValue.timestamp,
            'connectionRestored': ServerValue.timestamp,
          });

          // Set up disconnect handler for monitors (mark as offline but don't remove)
          monitorRef.onDisconnect().update({
            'isOnline': false,
            'disconnectedAt': ServerValue.timestamp,
            'lastSeen': ServerValue.timestamp,
          });

          if (kDebugMode) {
            print(
              'Monitor presence tracking setup for $deviceId with disconnect handler',
            );
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to setup monitor presence: $e');
      }
    }
  }

  /// Keep monitor online (call this periodically to maintain presence)
  Future<void> keepMonitorOnline(String deviceId) async {
    if (!_isInitialized || _database == null) return;

    try {
      final monitorRef = _database!.child('monitors').child(deviceId);

      await monitorRef.update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      });

      if (kDebugMode) {
        print('Monitor keepalive updated: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to keep monitor online: $e');
      }
    }
  }

  /// Update device status in Firebase with presence tracking
  Future<void> updateDeviceStatus(
    String deviceId,
    Map<String, dynamic> status,
  ) async {
    if (!_isInitialized || _database == null) {
      if (kDebugMode) {
        print('Firebase Realtime Database not initialized');
      }
      return;
    }

    try {
      final deviceRef = _database!.child('devices').child(deviceId);

      // Add timestamp and presence tracking
      final statusWithTimestamp = {
        ...status,
        'lastUpdate': ServerValue.timestamp,
        'isOnline': true,
      };

      await deviceRef.child('status').update(statusWithTimestamp);

      // Set up device disconnect detection
      await _setupDevicePresence(deviceId);

      if (kDebugMode) {
        print('Device status updated for $deviceId: $status');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update device status: $e');
      }
    }
  }

  /// Setup device presence tracking for automatic cleanup
  Future<void> _setupDevicePresence(String deviceId) async {
    try {
      final deviceRef = _database!.child('devices').child(deviceId);
      final connectedRef = FirebaseDatabase.instance.ref('.info/connected');

      // Listen to connection status
      connectedRef.onValue.listen((event) {
        if (event.snapshot.value == true) {
          // When connected, ensure device status is marked online
          deviceRef.child('status').update({
            'isOnline': true,
            'lastUpdate': ServerValue.timestamp,
            'connectionRestored': ServerValue.timestamp,
          });

          // Setup disconnect handler with graceful offline marking
          deviceRef.child('status').onDisconnect().update({
            'isOnline': false,
            'disconnectedAt': ServerValue.timestamp,
            'lastSeen': ServerValue.timestamp,
          });

          if (kDebugMode) {
            print(
              'Device presence tracking setup for $deviceId with disconnect handler',
            );
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to setup device presence: $e');
      }
    }
  }

  /// Update device info in Firebase
  Future<void> updateDeviceInfo(
    String deviceId,
    Map<String, dynamic> deviceInfo,
  ) async {
    if (!_isInitialized || _database == null) return;

    try {
      final deviceRef = _database!.child('devices').child(deviceId);

      final deviceInfoWithTimestamp = {
        ...deviceInfo,
        'lastSeen': ServerValue.timestamp,
      };

      await deviceRef.child('deviceInfo').set(deviceInfoWithTimestamp);

      if (kDebugMode) {
        print('Device info updated for $deviceId: $deviceInfo');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update device info: $e');
      }
    }
  }

  /// Listen to device status changes
  StreamSubscription<DatabaseEvent>? watchDeviceStatus(
    String deviceId,
    Function(Map<String, dynamic>?) onStatusChange,
  ) {
    if (!_isInitialized || _database == null) return null;

    try {
      final statusRef = _database!
          .child('devices')
          .child(deviceId)
          .child('status');

      final subscription = statusRef.onValue.listen((DatabaseEvent event) {
        final data = event.snapshot.value;
        if (data != null && data is Map) {
          final status = Map<String, dynamic>.from(data);
          onStatusChange(status);
        } else {
          onStatusChange(null);
        }
      });

      // Store subscription for cleanup
      _listeners['device_status_$deviceId'] = subscription;

      if (kDebugMode) {
        print('Started watching device status for $deviceId');
      }

      return subscription;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to watch device status: $e');
      }
      return null;
    }
  }

  /// Clean up offline devices periodically
  Future<void> cleanupOfflineDevices() async {
    if (!_isInitialized || _database == null) return;

    try {
      final devicesSnapshot = await _database!.child('devices').get();

      if (devicesSnapshot.exists) {
        final devices = Map<String, dynamic>.from(devicesSnapshot.value as Map);
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final entry in devices.entries) {
          final deviceId = entry.key;
          final deviceData = Map<String, dynamic>.from(entry.value);
          final status = deviceData['status'] as Map<String, dynamic>?;

          if (status != null) {
            final lastUpdate = status['lastUpdate'] as int?;
            final isOnline = status['isOnline'] as bool? ?? false;

            // Remove devices offline for more than 2 minutes
            if (!isOnline ||
                (lastUpdate != null && (now - lastUpdate) > 120000)) {
              await _database!.child('devices').child(deviceId).remove();

              if (kDebugMode) {
                print('Removed offline device: $deviceId');
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to cleanup offline devices: $e');
      }
    }
  }

  /// Listen to all devices status changes (for monitor mode)
  StreamSubscription<DatabaseEvent>? watchAllDevices(
    Function(Map<String, dynamic>) onDevicesChange,
  ) {
    if (!_isInitialized || _database == null) {
      if (kDebugMode) {
        print('FirebaseRealtimeService: 초기화되지 않음 또는 데이터베이스 없음');
      }
      return null;
    }

    try {
      final devicesRef = _database!.child('devices');

      final subscription = devicesRef.onValue.listen(
        (DatabaseEvent event) {
          if (kDebugMode) {
            print('FirebaseRealtimeService: devices 이벤트 수신');
            print('스냅샷 존재: ${event.snapshot.exists}');
            print('스냅샷 값: ${event.snapshot.value}');
          }

          final data = event.snapshot.value;
          if (data != null && data is Map) {
            final devices = Map<String, dynamic>.from(data);
            if (kDebugMode) {
              print('FirebaseRealtimeService: ${devices.length}개 기기 발견');
              print('기기 목록: ${devices.keys.toList()}');
            }
            onDevicesChange(devices);
          } else {
            if (kDebugMode) {
              print('FirebaseRealtimeService: 기기 데이터 없음 또는 잘못된 형식');
            }
            onDevicesChange({});
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('FirebaseRealtimeService: devices 리스너 에러: $error');
          }
        },
      );

      _listeners['all_devices'] = subscription;

      if (kDebugMode) {
        print('FirebaseRealtimeService: devices 감시 시작됨');
      }

      return subscription;
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseRealtimeService: devices 감시 실패: $e');
      }
      return null;
    }
  }

  /// Update monitor settings
  Future<void> updateMonitorSettings(
    String monitorId,
    Map<String, dynamic> settings,
  ) async {
    if (!_isInitialized || _database == null) return;

    try {
      final monitorRef = _database!.child('monitors').child(monitorId);

      await monitorRef.child('settings').update(settings);
      await monitorRef
          .child('deviceInfo')
          .child('lastSeen')
          .set(ServerValue.timestamp);

      if (kDebugMode) {
        print('Monitor settings updated for $monitorId: $settings');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update monitor settings: $e');
      }
    }
  }

  /// Create alert record
  Future<void> createAlert(String deviceId, String message) async {
    if (!_isInitialized || _database == null) return;

    try {
      final alertsRef = _database!.child('alerts');
      final newAlertRef = alertsRef.push();

      await newAlertRef.set({
        'deviceId': deviceId,
        'message': message,
        'timestamp': ServerValue.timestamp,
        'acknowledged': false,
      });

      if (kDebugMode) {
        print('Alert created for device $deviceId: $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create alert: $e');
      }
    }
  }

  /// Get device status once (without listening)
  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    if (!_isInitialized || _database == null) return null;

    try {
      final statusRef = _database!
          .child('devices')
          .child(deviceId)
          .child('status');
      final snapshot = await statusRef.get();

      if (snapshot.exists && snapshot.value != null) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get device status: $e');
      }
      return null;
    }
  }

  /// Stop watching a specific device
  void stopWatchingDevice(String deviceId) {
    final subscription = _listeners['device_status_$deviceId'];
    subscription?.cancel();
    _listeners.remove('device_status_$deviceId');

    if (kDebugMode) {
      print('Stopped watching device $deviceId');
    }
  }

  /// Stop watching all devices
  void stopWatchingAllDevices() {
    final subscription = _listeners['all_devices'];
    subscription?.cancel();
    _listeners.remove('all_devices');

    if (kDebugMode) {
      print('Stopped watching all devices');
    }
  }

  /// Remove device from database (when device goes offline)
  Future<void> removeDevice(String deviceId) async {
    if (!_isInitialized || _database == null) return;

    try {
      await _database!.child('devices').child(deviceId).remove();

      if (kDebugMode) {
        print('Device removed: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to remove device: $e');
      }
    }
  }

  /// Remove monitor from database (only when explicitly stopping monitoring)
  Future<void> removeMonitor(String deviceId) async {
    if (!_isInitialized || _database == null) return;

    try {
      await _database!.child('monitors').child(deviceId).remove();

      if (kDebugMode) {
        print('Monitor removed: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to remove monitor: $e');
      }
    }
  }

  /// Get batch cleanup statistics
  Map<String, dynamic> getBatchCleanupStats() {
    return _batchCleanupManager.getCleanupStats();
  }

  /// Force immediate batch cleanup
  Future<void> forceBatchCleanup() async {
    await _batchCleanupManager.forceCleanup();
  }

  /// Clean up all listeners and connections
  @override
  void dispose() {
    // Stop batch cleanup
    _batchCleanupManager.dispose();

    // Cancel all subscriptions
    for (final subscription in _listeners.values) {
      subscription.cancel();
    }
    _listeners.clear();

    if (kDebugMode) {
      print('Firebase Realtime Service disposed');
    }

    super.dispose();
  }

  /// Get real-time database URL for debugging
  String? getDatabaseUrl() {
    try {
      return FirebaseDatabase.instance.app.options.databaseURL;
    } catch (e) {
      return null;
    }
  }

  /// Check connection status
  Future<bool> checkConnection() async {
    if (!_isInitialized || _database == null) return false;

    try {
      // Try to read from a simple reference to test connectivity
      final testRef = _database!.child('.info/connected');
      final snapshot = await testRef.get();
      return snapshot.exists;
    } catch (e) {
      if (kDebugMode) {
        print('Connection check failed: $e');
      }
      return false;
    }
  }
}
