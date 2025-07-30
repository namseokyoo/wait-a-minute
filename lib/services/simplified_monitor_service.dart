import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'waiting_state_service.dart';
import 'firebase_realtime_service.dart';
import 'local_notification_service.dart';

/// Monitor service for receiving real-time waiting state updates
class SimplifiedMonitorService extends ChangeNotifier with WidgetsBindingObserver {
  // Settings controlled by Monitor
  bool _pushAlertsEnabled = true;
  double _blueSensitivity = 0.7;

  // Device management
  final Map<String, Map<String, dynamic>> _connectedDevices = {};
  bool _isBlueDetected = false;

  // Waiting state integration
  final WaitingStateService? _waitingStateService;
  bool _isWaitingState = false;
  VoidCallback? _waitingStateListener;
  
  // Firebase integration for background monitoring
  final FirebaseRealtimeService _firebaseService = FirebaseRealtimeService();
  final LocalNotificationService _notificationService = LocalNotificationService();
  StreamSubscription? _firebaseListener;
  bool _backgroundMonitoringEnabled = false;
  
  // Monitor device management
  String? _monitorDeviceId;
  Timer? _keepAliveTimer;
  
  // App lifecycle management - using WidgetsBindingObserver instead

  SimplifiedMonitorService({WaitingStateService? waitingStateService})
    : _waitingStateService = waitingStateService {
    // Create and store the listener function
    _waitingStateListener = _onWaitingStateChanged;
    
    // Listen to waiting state changes
    _waitingStateService?.addListener(_waitingStateListener!);
    
    // Generate unique monitor device ID
    _monitorDeviceId = _generateMonitorId();
    
    // Setup app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  // Getters
  bool get pushAlertsEnabled => _pushAlertsEnabled;
  double get blueSensitivity => _blueSensitivity;
  List<Map<String, dynamic>> get connectedDevices =>
      _connectedDevices.values.toList();
  bool get isBlueDetected => _isBlueDetected;
  bool get isWaitingState => _isWaitingState;
  String get waitingStateDescription => _isWaitingState ? '대기인원 있음' : '대기인원 없음';
  bool get backgroundMonitoringEnabled => _backgroundMonitoringEnabled;

  /// Set push alerts enabled/disabled
  void setPushAlertsEnabled(bool enabled) {
    _pushAlertsEnabled = enabled;
    notifyListeners();
  }

  /// Set blue light sensitivity threshold
  void setBlueSensitivity(double sensitivity) {
    _blueSensitivity = sensitivity.clamp(0.1, 1.0);

    // Reapply sensitivity to all devices
    _updateAllDeviceDetectionStates();

    notifyListeners();
  }

  /// Start background monitoring (Firebase listeners)
  Future<void> startBackgroundMonitoring() async {
    if (_backgroundMonitoringEnabled) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 백그라운드 모니터링이 이미 활성화됨');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 백그라운드 모니터링 시작 중...');
        print('모니터 기기 ID: $_monitorDeviceId');
      }

      // Initialize Firebase service with retry logic
      bool initialized = await _firebaseService.initialize();
      if (!initialized) {
        if (kDebugMode) {
          print('SimplifiedMonitorService: Firebase 초기화 실패 - 재시도 중...');
        }
        // 재시도 로직
        await Future.delayed(const Duration(seconds: 2));
        initialized = await _firebaseService.initialize();
        if (!initialized) {
          if (kDebugMode) {
            print('SimplifiedMonitorService: Firebase 초기화 재시도 실패 - 백그라운드 모니터링 불가');
          }
          return;
        }
      }

      // Initialize notification service
      final notificationInitialized = await _notificationService.initialize();
      if (kDebugMode) {
        print('SimplifiedMonitorService: 알림 서비스 초기화 ${notificationInitialized ? "성공" : "실패"}');
      }

      // Register this device as a monitor
      await _registerAsMonitor();

      // Start listening to all devices
      if (kDebugMode) {
        print('SimplifiedMonitorService: Firebase 리스너 시작');
      }
      _firebaseListener = _firebaseService.watchAllDevices(_onFirebaseDevicesUpdate);

      // Start keepalive timer to maintain monitor presence
      _startKeepAliveTimer();

      _backgroundMonitoringEnabled = true;
      notifyListeners();

      if (kDebugMode) {
        print('SimplifiedMonitorService: 백그라운드 모니터링 시작 완료 (Monitor ID: $_monitorDeviceId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 백그라운드 모니터링 시작 실패 - $e');
      }
      
      // 실패 시 상태 정리
      _backgroundMonitoringEnabled = false;
      _firebaseListener?.cancel();
      _firebaseListener = null;
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      notifyListeners();
    }
  }

  /// Stop background monitoring
  void stopBackgroundMonitoring() {
    if (!_backgroundMonitoringEnabled) return;

    _firebaseListener?.cancel();
    _firebaseListener = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    
    // Remove monitor from Firebase only when explicitly stopping
    if (_monitorDeviceId != null) {
      _firebaseService.removeMonitor(_monitorDeviceId!);
    }
    
    _backgroundMonitoringEnabled = false;
    notifyListeners();

    if (kDebugMode) {
      print('SimplifiedMonitorService: 백그라운드 모니터링 중지됨');
    }
  }

  /// Handle Firebase devices update
  void _onFirebaseDevicesUpdate(Map<String, dynamic> devices) {
    if (kDebugMode) {
      print('SimplifiedMonitorService: Firebase 기기 업데이트 수신');
      print('수신된 기기 수: ${devices.length}');
      print('기기 목록: ${devices.keys.toList()}');
    }

    bool newWaitingStateDetected = false;
    final List<Map<String, dynamic>> waitingDevices = [];

    // Process all devices from Firebase
    for (final entry in devices.entries) {
      final deviceId = entry.key;
      final deviceData = Map<String, dynamic>.from(entry.value);
      
      if (kDebugMode) {
        print('처리 중인 기기: $deviceId');
        print('기기 데이터: $deviceData');
      }
      
      // Extract device status
      final status = deviceData['status'] as Map<String, dynamic>?;
      if (status != null) {
        final isWaiting = status['isWaiting'] as bool? ?? false;
        final isOnline = status['isOnline'] as bool? ?? false;
        final blueIntensity = status['blueIntensity'] as double? ?? 0.0;
        
        // Update local device tracking
        _connectedDevices[deviceId] = {
          'deviceId': deviceId,
          'deviceInfo': deviceData['deviceInfo'] ?? {},
          'status': status,
          'isWaiting': isWaiting,
          'isOnline': isOnline,
          'blueIntensity': blueIntensity,
        };

        // Check for waiting state
        if (isWaiting && isOnline) {
          newWaitingStateDetected = true;
          waitingDevices.add(_connectedDevices[deviceId]!);
        }
      }
    }

    // Update overall waiting state
    final previousWaitingState = _isWaitingState;
    _isWaitingState = newWaitingStateDetected;

    // Send notification if new waiting state detected
    if (!previousWaitingState && _isWaitingState && _pushAlertsEnabled) {
      _sendWaitingNotification(waitingDevices);
    }

    notifyListeners();

    if (kDebugMode && previousWaitingState != _isWaitingState) {
      print('SimplifiedMonitorService: 대기 상태 변경 - $_isWaitingState (기기 ${waitingDevices.length}개)');
    }
  }

  /// Send notification for waiting state
  Future<void> _sendWaitingNotification(List<Map<String, dynamic>> waitingDevices) async {
    if (!_pushAlertsEnabled || waitingDevices.isEmpty) return;

    try {
      String deviceName = '알 수 없는 기기';
      String location = '';

      if (waitingDevices.isNotEmpty) {
        final firstDevice = waitingDevices.first;
        final deviceInfo = firstDevice['deviceInfo'] as Map<String, dynamic>? ?? {};
        deviceName = deviceInfo['name'] as String? ?? '감지 기기';
        location = deviceInfo['location'] as String? ?? '';
      }

      await _notificationService.showWaitingNotification(
        deviceName: deviceName,
        location: location,
      );

      if (kDebugMode) {
        print('SimplifiedMonitorService: 백그라운드 알림 전송 - $deviceName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 알림 전송 실패 - $e');
      }
    }
  }

  /// Add or update device status
  void updateDeviceStatus(String deviceId, Map<String, dynamic> status) {
    // Update device data
    _connectedDevices[deviceId] = {
      ...status,
      'isBlueDetected': (status['blueIntensity'] ?? 0.0) >= _blueSensitivity,
      'lastUpdate': DateTime.now(),
    };

    // Update global blue detection state
    _updateGlobalBlueDetection();

    notifyListeners();
  }

  /// Remove device (when disconnected)
  void removeDevice(String deviceId) {
    _connectedDevices.remove(deviceId);
    _updateGlobalBlueDetection();
    notifyListeners();
  }

  /// Get device count by status
  int get onlineDeviceCount =>
      _connectedDevices.values.where((d) => d['isOnline'] == true).length;

  int get monitoringDeviceCount =>
      _connectedDevices.values.where((d) => d['isMonitoring'] == true).length;

  int get alertDeviceCount =>
      _connectedDevices.values
          .where(
            (d) => d['isBlueDetected'] == true && d['isMonitoring'] == true,
          )
          .length;

  /// Update global blue detection status
  void _updateGlobalBlueDetection() {
    bool previousState = _isBlueDetected;
    _isBlueDetected = _connectedDevices.values.any(
      (device) =>
          device['isBlueDetected'] == true && device['isMonitoring'] == true,
    );

    // If status changed, notify listeners
    if (previousState != _isBlueDetected) {
      if (kDebugMode) {
        print('Global blue detection changed to: $_isBlueDetected');
      }
      notifyListeners();
    }
  }

  /// Apply sensitivity threshold to all devices
  void _updateAllDeviceDetectionStates() {
    for (var deviceId in _connectedDevices.keys) {
      var device = _connectedDevices[deviceId]!;
      device['isBlueDetected'] =
          (device['blueIntensity'] ?? 0.0) >= _blueSensitivity;
    }

    _updateGlobalBlueDetection();
  }


  /// Handle waiting state changes from WaitingStateService
  void _onWaitingStateChanged() {
    if (_waitingStateService != null) {
      final newState = _waitingStateService.isWaitingState;
      if (_isWaitingState != newState) {
        _isWaitingState = newState;

        if (kDebugMode) {
          print('Monitor received waiting state change: $newState');
        }

        notifyListeners();
      }
    }
  }

  /// Generate unique monitor device ID
  String _generateMonitorId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(9999).toString().padLeft(4, '0');
    return 'monitor_${timestamp}_$randomSuffix';
  }

  /// Handle app lifecycle changes (WidgetsBindingObserver)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (kDebugMode) {
          print('SimplifiedMonitorService: 앱이 포그라운드로 전환됨');
          print('백그라운드 모니터링 상태: $_backgroundMonitoringEnabled');
          print('모니터 기기 ID: $_monitorDeviceId');
        }
        // Enhanced re-registration when app comes to foreground
        if (_backgroundMonitoringEnabled && _monitorDeviceId != null) {
          if (kDebugMode) {
            print('포그라운드 복귀 - 향상된 모니터 재등록 시작');
          }
          await _ensureMonitorRegistration();
        }
        break;
        
      case AppLifecycleState.paused:
        if (kDebugMode) {
          print('SimplifiedMonitorService: 앱이 백그라운드로 전환됨');
        }
        // Update monitor status for background mode
        await _updateMonitorStatus(isBackground: true);
        break;
        
      case AppLifecycleState.inactive:
        if (kDebugMode) {
          print('SimplifiedMonitorService: 앱이 비활성 상태로 전환됨');
        }
        break;
        
      case AppLifecycleState.detached:
        if (kDebugMode) {
          print('SimplifiedMonitorService: 앱이 종료됨 - 강제 정리 시작');
        }
        // Force cleanup when app is being terminated
        await _forceCleanupMonitor();
        break;
        
      case AppLifecycleState.hidden:
        if (kDebugMode) {
          print('SimplifiedMonitorService: 앱이 숨겨짐');
        }
        break;
    }
  }

  /// Register this device as a monitor in Firebase
  Future<void> _registerAsMonitor() async {
    if (_monitorDeviceId == null) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 모니터 기기 ID가 없음');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 모니터 등록 시작 - $_monitorDeviceId');
      }
      
      // Firebase 서비스가 초기화되어 있는지 확인
      if (!_firebaseService.isInitialized) {
        if (kDebugMode) {
          print('SimplifiedMonitorService: Firebase 재초기화 시도');
        }
        final initialized = await _firebaseService.initialize();
        if (!initialized) {
          if (kDebugMode) {
            print('SimplifiedMonitorService: Firebase 재초기화 실패');
          }
          return;
        }
      }

      await _firebaseService.registerMonitorDevice(
        _monitorDeviceId!,
        '모니터링 기기',
      );

      if (kDebugMode) {
        print('SimplifiedMonitorService: 모니터 기기 등록 완료 - $_monitorDeviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 모니터 기기 등록 실패 - $e');
      }
    }
  }

  /// Start keepalive timer to maintain monitor presence
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    // 더 자주 keepalive (15초마다)
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_backgroundMonitoringEnabled && _monitorDeviceId != null) {
        _firebaseService.keepMonitorOnline(_monitorDeviceId!);
      }
    });

    if (kDebugMode) {
      print('SimplifiedMonitorService: KeepAlive 타이머 시작됨 (15초 간격)');
    }
  }

  /// Force cleanup monitor when app is being terminated
  Future<void> _forceCleanupMonitor() async {
    try {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 강제 정리 시작');
      }
      
      // Stop keepalive timer
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      
      // Cancel Firebase listener
      _firebaseListener?.cancel();
      _firebaseListener = null;
      
      // Remove monitor from Firebase
      if (_monitorDeviceId != null) {
        await _firebaseService.removeMonitor(_monitorDeviceId!);
        if (kDebugMode) {
          print('SimplifiedMonitorService: Firebase에서 모니터 제거 완료');
        }
      }
      
      _backgroundMonitoringEnabled = false;
      
      if (kDebugMode) {
        print('SimplifiedMonitorService: 강제 정리 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 강제 정리 실패 (무시됨): $e');
      }
    }
  }

  /// Update monitor status (for background/foreground transitions)
  Future<void> _updateMonitorStatus({required bool isBackground}) async {
    if (_monitorDeviceId == null || !_backgroundMonitoringEnabled) return;
    
    try {
      await _firebaseService.registerMonitorDevice(
        _monitorDeviceId!,
        '모니터링 기기',
      );
      
      if (kDebugMode) {
        print('SimplifiedMonitorService: 모니터 상태 업데이트 - background: $isBackground');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SimplifiedMonitorService: 모니터 상태 업데이트 실패: $e');
      }
    }
  }

  /// Ensure monitor registration (enhanced re-registration)
  Future<void> _ensureMonitorRegistration() async {
    if (!_backgroundMonitoringEnabled || _monitorDeviceId == null) return;
    
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      try {
        // Check Firebase connection
        final isConnected = await _firebaseService.checkConnection();
        if (!isConnected) {
          await _firebaseService.initialize();
        }
        
        // Re-register monitor
        await _registerAsMonitor();
        
        // Restart Firebase listener if needed
        if (_firebaseListener == null) {
          _firebaseListener = _firebaseService.watchAllDevices(_onFirebaseDevicesUpdate);
        }
        
        if (kDebugMode) {
          print('SimplifiedMonitorService: 모니터 재등록 성공');
        }
        break;
        
      } catch (e) {
        attempts++;
        if (kDebugMode) {
          print('SimplifiedMonitorService: 재등록 시도 $attempts 실패: $e');
        }
        
        if (attempts < maxAttempts) {
          // Exponential backoff
          await Future.delayed(Duration(seconds: attempts * 2));
        } else {
          if (kDebugMode) {
            print('SimplifiedMonitorService: 재등록 최대 시도 횟수 초과');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    // Stop background monitoring
    stopBackgroundMonitoring();
    
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove listener from waiting state service
    if (_waitingStateListener != null) {
      _waitingStateService?.removeListener(_waitingStateListener!);
      _waitingStateListener = null;
    }
    
    super.dispose();
  }
}
