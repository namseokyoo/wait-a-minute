import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

/// Batch cleanup manager for periodic database maintenance and optimization
class BatchCleanupManager {
  static final BatchCleanupManager _instance = BatchCleanupManager._internal();
  factory BatchCleanupManager() => _instance;
  BatchCleanupManager._internal();

  DatabaseReference? _database;
  Timer? _cleanupTimer;
  bool _isCleanupActive = false;

  // Cleanup statistics
  int _totalCleanedDevices = 0;
  int _totalCleanedMonitors = 0;
  int _totalCleanedAlerts = 0;
  DateTime _lastCleanupTime = DateTime.now();

  // Cleanup thresholds - 웹 환경에서는 8시간+ 지속 사용을 위해 매우 관대한 설정
  static const Duration _offlineThreshold = Duration(
    hours: 12,
  ); // Devices offline for 12+ hours (장시간 사용 고려)
  static const Duration _alertRetentionPeriod = Duration(
    days: 7,
  ); // Keep alerts for 7 days
  static const Duration _monitorOfflineThreshold = Duration(
    hours: 12,
  ); // Monitors offline for 12+ hours (장시간 사용 고려)
  static const Duration _cleanupInterval = Duration(
    hours: 6,
  ); // Run cleanup every 6 hours (매우 덜 공격적으로)

  /// Initialize and start batch cleanup with configurable interval
  void startBatchCleanup({
    Duration interval = _cleanupInterval,
    DatabaseReference? database,
    bool enableWebCleanup = false, // 웹 환경에서는 기본적으로 정리 기능 비활성화
  }) {
    if (_isCleanupActive) {
      if (kDebugMode) {
        print('BatchCleanupManager: Cleanup already active');
      }
      return;
    }

    // 웹 환경에서 정리 기능이 명시적으로 활성화되지 않은 경우 종료
    if (kIsWeb && !enableWebCleanup) {
      if (kDebugMode) {
        print('BatchCleanupManager: Web cleanup disabled by default for 8+ hour usage');
      }
      return;
    }

    // Initialize database reference
    _database = database ?? FirebaseDatabase.instance.ref();

    _cleanupTimer = Timer.periodic(interval, (timer) {
      _performBatchCleanup();
    });

    _isCleanupActive = true;

    if (kDebugMode) {
      print(
        'BatchCleanupManager: Batch cleanup started with ${interval.inMinutes}분 간격',
      );
    }
  }

  /// Stop batch cleanup
  void stopBatchCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _isCleanupActive = false;

    if (kDebugMode) {
      print('BatchCleanupManager: Batch cleanup stopped');
    }
  }

  /// Perform comprehensive batch cleanup
  Future<void> _performBatchCleanup() async {
    if (_database == null) {
      if (kDebugMode) {
        print(
          'BatchCleanupManager: Database not initialized, skipping cleanup',
        );
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('BatchCleanupManager: Starting batch cleanup...');
      }

      final startTime = DateTime.now();
      int cleanedDevices = 0;
      int cleanedMonitors = 0;
      int cleanedAlerts = 0;

      // 1. Clean up offline devices
      cleanedDevices = await _cleanupOfflineDevices();

      // 2. Clean up offline monitors
      cleanedMonitors = await _cleanupOfflineMonitors();

      // 3. Clean up expired alerts
      cleanedAlerts = await _cleanupExpiredAlerts();

      // 4. Optimize database structure (remove empty nodes)
      await _optimizeDatabaseStructure();

      // Update statistics
      _totalCleanedDevices += cleanedDevices;
      _totalCleanedMonitors += cleanedMonitors;
      _totalCleanedAlerts += cleanedAlerts;
      _lastCleanupTime = DateTime.now();

      final duration = DateTime.now().difference(startTime);

      if (kDebugMode) {
        print(
          'BatchCleanupManager: Cleanup completed in ${duration.inSeconds}s',
        );
        print('  - Cleaned devices: $cleanedDevices');
        print('  - Cleaned monitors: $cleanedMonitors');
        print('  - Cleaned alerts: $cleanedAlerts');
      }
    } catch (e) {
      if (kDebugMode) {
        print('BatchCleanupManager: Cleanup failed - $e');
      }
    }
  }

  /// Clean up offline devices
  Future<int> _cleanupOfflineDevices() async {
    int cleanedCount = 0;

    try {
      final devicesSnapshot = await _database?.child('devices').get();

      if (devicesSnapshot?.exists == true) {
        final devices = Map<String, dynamic>.from(
          devicesSnapshot!.value as Map,
        );
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final entry in devices.entries) {
          final deviceId = entry.key;
          final deviceData = Map<String, dynamic>.from(entry.value);
          final status = deviceData['status'] as Map<String, dynamic>?;

          if (status != null) {
            final lastUpdate = status['lastUpdate'] as int?;
            final isOnline = status['isOnline'] as bool? ?? false;
            final disconnectedAt = status['disconnectedAt'] as int?;

            bool shouldRemove = false;

            // Remove if explicitly offline for more than threshold
            if (!isOnline && disconnectedAt != null) {
              final offlineDuration = now - disconnectedAt;
              if (offlineDuration > _offlineThreshold.inMilliseconds) {
                shouldRemove = true;
              }
            }

            // Remove if no updates for more than threshold (ghost devices)
            // 웹 환경에서는 8시간+ 지속 사용을 위해 매우 관대하게 처리
            if (lastUpdate != null) {
              final updateAge = now - lastUpdate;
              final deviceInfo = deviceData['deviceInfo'] as Map<String, dynamic>?;
              final platform = deviceInfo?['platform'] as String?;
              
              if (platform == 'web') {
                // 웹은 24시간까지 여유 시간 부여 (8시간+ 지속 사용)
                if (updateAge > const Duration(hours: 24).inMilliseconds) {
                  shouldRemove = true;
                }
              } else {
                // 모바일은 기존 12시간 threshold 사용
                if (updateAge > _offlineThreshold.inMilliseconds) {
                  shouldRemove = true;
                }
              }
            }

            // Remove devices with no status updates at all (하지만 등록된 지 얼마 안 된 경우 제외)
            if (lastUpdate == null && disconnectedAt == null) {
              final deviceInfo = deviceData['deviceInfo'] as Map<String, dynamic>?;
              final registeredAt = deviceInfo?['registeredAt'] as int?;
              final platform = deviceInfo?['platform'] as String?;
              
              if (registeredAt != null) {
                final registrationAge = now - registeredAt;
                
                if (platform == 'web') {
                  // 웹은 6시간 이상 된 경우에만 삭제 (8시간+ 지속 사용)
                  if (registrationAge > const Duration(hours: 6).inMilliseconds) {
                    shouldRemove = true;
                  }
                } else {
                  // 모바일은 1시간 이상 된 경우에만 삭제
                  if (registrationAge > const Duration(hours: 1).inMilliseconds) {
                    shouldRemove = true;
                  }
                }
              } else {
                // 등록 시간이 없는 경우는 삭제하지 않음 (웹 환경 고려)
                shouldRemove = false;
              }
            }

            if (shouldRemove) {
              await _database?.child('devices').child(deviceId).remove();
              cleanedCount++;

              if (kDebugMode) {
                print('BatchCleanupManager: Removed offline device: $deviceId');
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BatchCleanupManager: Error cleaning offline devices - $e');
      }
    }

    return cleanedCount;
  }

  /// Clean up offline monitors
  Future<int> _cleanupOfflineMonitors() async {
    int cleanedCount = 0;

    try {
      final monitorsSnapshot = await _database?.child('monitors').get();

      if (monitorsSnapshot?.exists == true) {
        final monitors = Map<String, dynamic>.from(
          monitorsSnapshot!.value as Map,
        );
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final entry in monitors.entries) {
          final monitorId = entry.key;
          final monitorData = Map<String, dynamic>.from(entry.value);

          final isOnline = monitorData['isOnline'] as bool? ?? false;
          final lastSeen = monitorData['lastSeen'] as int?;
          final disconnectedAt = monitorData['disconnectedAt'] as int?;

          bool shouldRemove = false;

          // Remove if offline for more than monitor threshold
          if (!isOnline && disconnectedAt != null) {
            final offlineDuration = now - disconnectedAt;
            if (offlineDuration > _monitorOfflineThreshold.inMilliseconds) {
              shouldRemove = true;
            }
          }

          // Remove if no activity for extended period
          if (lastSeen != null) {
            final inactivityDuration = now - lastSeen;
            if (inactivityDuration > _monitorOfflineThreshold.inMilliseconds) {
              shouldRemove = true;
            }
          }

          if (shouldRemove) {
            await _database?.child('monitors').child(monitorId).remove();
            cleanedCount++;

            if (kDebugMode) {
              print('BatchCleanupManager: Removed offline monitor: $monitorId');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BatchCleanupManager: Error cleaning offline monitors - $e');
      }
    }

    return cleanedCount;
  }

  /// Clean up expired alerts
  Future<int> _cleanupExpiredAlerts() async {
    int cleanedCount = 0;

    try {
      final alertsSnapshot = await _database?.child('alerts').get();

      if (alertsSnapshot?.exists == true) {
        final alerts = Map<String, dynamic>.from(alertsSnapshot!.value as Map);
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final entry in alerts.entries) {
          final alertId = entry.key;
          final alertData = Map<String, dynamic>.from(entry.value);

          final timestamp = alertData['timestamp'] as int?;

          if (timestamp != null) {
            final alertAge = now - timestamp;

            // Remove alerts older than retention period
            if (alertAge > _alertRetentionPeriod.inMilliseconds) {
              await _database?.child('alerts').child(alertId).remove();
              cleanedCount++;

              if (kDebugMode) {
                print('BatchCleanupManager: Removed expired alert: $alertId');
              }
            }
          } else {
            // Remove alerts without timestamp
            await _database?.child('alerts').child(alertId).remove();
            cleanedCount++;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BatchCleanupManager: Error cleaning expired alerts - $e');
      }
    }

    return cleanedCount;
  }

  /// Optimize database structure by removing empty nodes
  Future<void> _optimizeDatabaseStructure() async {
    try {
      final rootSnapshot = await _database?.get();

      if (rootSnapshot?.exists == true) {
        final rootData = rootSnapshot!.value as Map<String, dynamic>?;

        if (rootData != null) {
          // Check for empty collections and clean them up
          for (final collection in ['devices', 'monitors', 'alerts']) {
            final collectionData = rootData[collection];

            if (collectionData == null ||
                (collectionData is Map && collectionData.isEmpty)) {
              // Remove empty collection node
              await _database?.child(collection).remove();

              if (kDebugMode) {
                print(
                  'BatchCleanupManager: Removed empty collection: $collection',
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BatchCleanupManager: Error optimizing database structure - $e');
      }
    }
  }

  /// Force immediate cleanup (for testing or manual triggers)
  Future<void> forceCleanup() async {
    if (kDebugMode) {
      print('BatchCleanupManager: Force cleanup triggered');
    }

    await _performBatchCleanup();
  }

  /// Get cleanup statistics
  Map<String, dynamic> getCleanupStats() {
    return {
      'isActive': _isCleanupActive,
      'lastCleanupTime': _lastCleanupTime.toIso8601String(),
      'totalCleanedDevices': _totalCleanedDevices,
      'totalCleanedMonitors': _totalCleanedMonitors,
      'totalCleanedAlerts': _totalCleanedAlerts,
      'offlineThresholdMinutes': _offlineThreshold.inMinutes,
      'alertRetentionHours': _alertRetentionPeriod.inHours,
      'cleanupIntervalMinutes': _cleanupInterval.inMinutes,
    };
  }

  /// Reset cleanup statistics
  void resetStats() {
    _totalCleanedDevices = 0;
    _totalCleanedMonitors = 0;
    _totalCleanedAlerts = 0;
    _lastCleanupTime = DateTime.now();

    if (kDebugMode) {
      print('BatchCleanupManager: Statistics reset');
    }
  }

  /// Check if cleanup is currently active
  bool get isActive => _isCleanupActive;

  /// Dispose resources
  void dispose() {
    stopBatchCleanup();
  }
}
