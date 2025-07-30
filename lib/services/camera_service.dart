import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'blue_light_detector.dart';
import 'waiting_state_service.dart';
import 'firebase_realtime_service.dart';
import 'device_health_checker.dart';
import 'smart_update_manager.dart';
import '../models/sensitivity_settings.dart';

/// Real camera service for CCTV functionality with blue light detection
class CameraService extends ChangeNotifier with WidgetsBindingObserver {
  // Device info
  final String _deviceId = const Uuid().v4();
  final String _deviceName;
  final String _location;

  // Camera related
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Monitoring state
  bool _isMonitoring = false;
  double _blueIntensity = 0.0;
  final double _batteryLevel = 1.0;
  final bool _isOnline = true;
  
  // Privacy mode (screen blackout)
  bool _isPrivacyMode = false;

  // Blue light detection
  StreamSubscription? _imageStream;
  final BlueLightDetector _detector = BlueLightDetector();
  bool _isWaitingState = false;
  bool _previousWaitingState = false;
  final WaitingStateService? _waitingStateService;

  // Firebase integration
  final FirebaseRealtimeService _firebaseService = FirebaseRealtimeService();
  final DeviceHealthChecker _healthChecker = DeviceHealthChecker();
  final SmartUpdateManager _updateManager = SmartUpdateManager();
  DateTime? _lastFirebaseUpdate;
  DateTime? _lastUIUpdate;

  // Error handling
  String? _errorMessage;

  // App lifecycle management
  bool _isAppInBackground = false;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  // Sensitivity settings
  SensitivitySettings _sensitivitySettings = SensitivitySettings.standard();

  CameraService({
    required String deviceName,
    required String location,
    WaitingStateService? waitingStateService,
  }) : _deviceName = deviceName,
       _location = location,
       _waitingStateService = waitingStateService {
    _loadSensitivitySettings();
    // Setup app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  // Getters
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get location => _location;
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isMonitoring => _isMonitoring;
  double get blueIntensity => _blueIntensity;
  double get batteryLevel => _batteryLevel;
  bool get isOnline => _isOnline;
  String? get errorMessage => _errorMessage;
  bool get isWaitingState => _isWaitingState;
  bool get detectorCalibrated => _detector.isCalibrated;
  BlueLightDetector get detector => _detector;
  SensitivitySettings get sensitivitySettings => _sensitivitySettings;
  bool get isPrivacyMode => _isPrivacyMode;

  /// Initialize camera
  Future<bool> initializeCamera() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('사용 가능한 카메라가 없습니다');
      }

      // Use back camera (index 0 is usually back camera)
      final camera = _cameras.first;

      // Initialize camera controller with web compatibility
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        // Web에서는 imageFormatGroup을 지정하지 않음 (자동 선택)
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();

      _isInitialized = true;

      if (kDebugMode) {
        print('Camera initialized successfully');
      }

      // Initialize Firebase Realtime Service (비동기로 처리, 실패해도 카메라는 작동)
      _initializeFirebaseAsync();
    } catch (e) {
      _errorMessage = '카메라 초기화 실패: $e';
      if (kDebugMode) {
        print('Camera initialization error: $e');
      }
    }

    _isInitializing = false;
    notifyListeners();
    return _isInitialized;
  }

  /// Firebase 비동기 초기화 (카메라 초기화와 독립적)
  Future<void> _initializeFirebaseAsync() async {
    try {
      final success = await _firebaseService.initialize();
      if (success) {
        // Register device info in Firebase
        await _firebaseService.updateDeviceInfo(_deviceId, {
          'name': _deviceName,
          'location': _location,
          'mode': 'cctv',
        });
        
        if (kDebugMode) {
          print('Firebase initialized and device registered successfully');
        }
      } else {
        if (kDebugMode) {
          print('Firebase initialization failed, but camera will continue to work');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Firebase async initialization error: $e');
      }
      // Firebase 실패해도 에러 메시지 설정하지 않음 (카메라는 정상 작동)
    }
  }

  /// Start monitoring with blue light detection
  Future<void> startMonitoring() async {
    if (!_isInitialized || _isMonitoring) return;

    try {
      _isMonitoring = true;
      _errorMessage = null;
      notifyListeners();

      // Reset detector for new monitoring session
      _detector.reset();
      _isWaitingState = false;
      _previousWaitingState = false;

      // Start image stream for blue light detection
      await _controller!.startImageStream(_onImageReceived);
      
      // Enable wakelock to keep screen on during monitoring
      await WakelockPlus.enable();

      // Start health check monitoring
      _startHealthMonitoring();

      if (kDebugMode) {
        print('Monitoring started with wakelock and health check enabled');
      }
    } catch (e) {
      _errorMessage = '모니터링 시작 실패: $e';
      _isMonitoring = false;
      if (kDebugMode) {
        print('Start monitoring error: $e');
      }
      notifyListeners();
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;
      _blueIntensity = 0.0;

      // Stop image stream
      if (_controller != null && _controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      // Reset detector state
      _detector.reset();
      
      // Disable privacy mode when stopping monitoring
      _isPrivacyMode = false;
      
      // Stop health check monitoring
      _stopHealthMonitoring();
      
      // Disable wakelock when monitoring stops
      await WakelockPlus.disable();

      notifyListeners();

      if (kDebugMode) {
        print('Monitoring stopped, health check and wakelock disabled');
      }
    } catch (e) {
      _errorMessage = '모니터링 중지 실패: $e';
      if (kDebugMode) {
        print('Stop monitoring error: $e');
      }
      notifyListeners();
    }
  }

  /// Process camera image for blue light detection
  void _onImageReceived(CameraImage image) async {
    if (!_isMonitoring) return;

    try {
      // Analyze frame for blue light detection
      final result = await _detector.analyzeFrame(image);

      if (!result.hasError) {
        // Update blue intensity and waiting state
        final previousBlueIntensity = _blueIntensity;
        _blueIntensity = result.normalizedIntensity;
        _previousWaitingState = _isWaitingState;
        _isWaitingState = result.isWaitingState;

        // Smart update to Firebase based on context
        final now = DateTime.now();
        final shouldUpdateFirebase = _updateManager.shouldUpdate(
          isWaitingState: _isWaitingState,
          isAppInBackground: _isAppInBackground,
          blueIntensity: _blueIntensity,
          previousBlueIntensity: previousBlueIntensity,
        );

        if (shouldUpdateFirebase && 
            (_lastFirebaseUpdate == null ||
             now.difference(_lastFirebaseUpdate!) >= _updateManager.getOptimalUpdateInterval(
               isWaitingState: _isWaitingState,
               isAppInBackground: _isAppInBackground,
             ))) {
          await _firebaseService.updateDeviceStatus(_deviceId, {
            'isWaiting': _isWaitingState,
            'blueIntensity': result.amplifiedIntensity, // Send amplified intensity to DB
            'rawBlueIntensity': result.blueIntensity, // Keep raw intensity for reference
            'sensitivityMultiplier': result.sensitivityMultiplier,
            'confidence': result.confidence,
            'isOnline': _isOnline,
            'isMonitoring': _isMonitoring,
            'batteryLevel': _batteryLevel,
            'isBackground': _isAppInBackground,
          });
          _lastFirebaseUpdate = now;
        }

        // Check for waiting state change and send notifications
        if (_previousWaitingState != _isWaitingState) {
          if (kDebugMode) {
            print(
              'Waiting state changed: $_previousWaitingState -> $_isWaitingState',
            );
          }

          // Update shared waiting state service
          _waitingStateService?.updateWaitingState(
            _isWaitingState,
            sourceDeviceId: _deviceId,
          );

          // Create alert in Firebase (for monitor devices to detect changes)
          if (_isWaitingState) {
            await _firebaseService.createAlert(_deviceId, '대기인원 있음');
          }
        }

        // Always notify listeners for UI updates (blue intensity changes frequently)
        // Throttle UI updates to avoid excessive rebuilds (every 100ms)
        final uiUpdateThreshold = const Duration(milliseconds: 100);
        if (_lastUIUpdate == null ||
            now.difference(_lastUIUpdate!) >= uiUpdateThreshold ||
            _previousWaitingState != _isWaitingState ||
            (previousBlueIntensity - _blueIntensity).abs() > 0.01) {
          notifyListeners();
          _lastUIUpdate = now;
        }

        if (kDebugMode && result.stateChanged) {
          print('Detection result: $result');
        }
      } else {
        if (kDebugMode) {
          print('Detection error: ${result.error}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Image processing error: $e');
      }
    }
  }

  /// Switch between available cameras
  Future<void> switchCamera() async {
    if (!_isInitialized || _cameras.length < 2) return;

    try {
      final wasMonitoring = _isMonitoring;
      
      // Clear any existing error messages before switching
      _errorMessage = null;
      notifyListeners();

      // Stop monitoring if active
      if (_isMonitoring) {
        await stopMonitoring();
      }

      // Store current camera description before disposal
      final currentDescription = _controller?.description;
      
      // Dispose current controller
      await _controller?.dispose();
      _controller = null;
      
      // Temporarily mark as not initialized during switch
      _isInitialized = false;
      notifyListeners();

      // Find next camera
      final currentIndex = _cameras.indexWhere(
        (camera) => camera == currentDescription,
      );
      final nextIndex = (currentIndex + 1) % _cameras.length;

      // Initialize with new camera
      _controller = CameraController(
        _cameras[nextIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
      notifyListeners();

      // Small delay to ensure camera is stable before resuming monitoring
      await Future.delayed(const Duration(milliseconds: 500));

      // Resume monitoring if it was active
      if (wasMonitoring) {
        await startMonitoring();
      }

      if (kDebugMode) {
        print('Successfully switched to camera: ${_cameras[nextIndex].name}');
      }
    } catch (e) {
      _errorMessage = '카메라 전환 실패: $e';
      _isInitialized = false;
      if (kDebugMode) {
        print('Camera switch error: $e');
      }
      notifyListeners();
    }
  }

  /// Toggle privacy mode (screen blackout)
  void togglePrivacyMode() {
    _isPrivacyMode = !_isPrivacyMode;
    notifyListeners();
    
    if (kDebugMode) {
      print('Privacy mode ${_isPrivacyMode ? 'enabled' : 'disabled'}');
    }
  }

  /// Load sensitivity settings from SharedPreferences
  Future<void> _loadSensitivitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('sensitivity_settings');
      
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _sensitivitySettings = SensitivitySettings.fromMap(settingsMap);
        
        // Apply to detector
        _detector.updateSensitivitySettings(_sensitivitySettings);
        
        if (kDebugMode) {
          print('CameraService: 감도 설정 로드됨 - ${_sensitivitySettings.levelName}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('CameraService: 감도 설정 로드 실패: $e');
      }
    }
  }

  /// Save sensitivity settings to SharedPreferences
  Future<void> _saveSensitivitySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_sensitivitySettings.toMap());
      await prefs.setString('sensitivity_settings', settingsJson);
      
      if (kDebugMode) {
        print('CameraService: 감도 설정 저장됨 - ${_sensitivitySettings.levelName}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('CameraService: 감도 설정 저장 실패: $e');
      }
    }
  }

  /// Update sensitivity settings
  Future<void> updateSensitivitySettings(SensitivitySettings settings) async {
    _sensitivitySettings = settings;
    
    // Apply to detector
    _detector.updateSensitivitySettings(settings);
    
    // Save to local storage
    await _saveSensitivitySettings();
    
    // Notify listeners
    notifyListeners();
    
    if (kDebugMode) {
      print('CameraService: 감도 설정 업데이트 완료 - ${settings.levelName} (×${settings.multiplier})');
    }
  }

  /// Remove device from Firebase database
  Future<void> removeDeviceFromFirebase() async {
    try {
      if (kDebugMode) {
        print('CameraService: Firebase에서 디바이스 제거 중 ($_deviceId)');
      }

      await _firebaseService.removeDevice(_deviceId);

      if (kDebugMode) {
        print('CameraService: Firebase에서 디바이스 제거 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('CameraService: Firebase 디바이스 제거 실패 (무시됨): $e');
      }
    }
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        _isAppInBackground = true;
        if (_isMonitoring) {
          _startHeartbeat();
          if (kDebugMode) {
            print('CameraService: 백그라운드 모드 - heartbeat 시작');
          }
        }
        break;
        
      case AppLifecycleState.resumed:
        _isAppInBackground = false;
        _stopHeartbeat();
        if (_isMonitoring) {
          _reregisterDevice();
          if (kDebugMode) {
            print('CameraService: 포그라운드 복귀 - 기기 재등록');
          }
        }
        break;
        
      case AppLifecycleState.detached:
        _forceCleanup();
        if (kDebugMode) {
          print('CameraService: 앱 종료 - 강제 정리');
        }
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // No specific action needed
        break;
    }
  }

  /// Start heartbeat in background
  void _startHeartbeat() {
    _stopHeartbeat(); // 기존 타이머 정리
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isMonitoring && _isAppInBackground) {
        _firebaseService.updateDeviceStatus(_deviceId, {
          'isOnline': true,
          'lastHeartbeat': DateTime.now().millisecondsSinceEpoch,
          'isBackground': true,
        }).catchError((e) {
          if (kDebugMode) {
            print('CameraService: Heartbeat 실패: $e');
          }
        });
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Re-register device when returning to foreground
  Future<void> _reregisterDevice() async {
    if (!_isMonitoring) return;
    
    int attempts = 0;
    while (attempts < _maxReconnectAttempts) {
      try {
        // Firebase 연결 상태 확인
        final isConnected = await _firebaseService.checkConnection();
        if (!isConnected) {
          await _firebaseService.initialize();
        }
        
        // 기기 상태 업데이트
        await _firebaseService.updateDeviceStatus(_deviceId, {
          'isWaiting': _isWaitingState,
          'blueIntensity': _blueIntensity,
          'isOnline': true,
          'isMonitoring': _isMonitoring,
          'batteryLevel': _batteryLevel,
          'isBackground': false,
          'lastReconnect': DateTime.now().millisecondsSinceEpoch,
        });
        
        // 기기 정보 업데이트
        await _firebaseService.updateDeviceInfo(_deviceId, {
          'name': _deviceName,
          'location': _location,
          'deviceType': 'CCTV',
          'lastReregistration': DateTime.now().millisecondsSinceEpoch,
        });
        
        _reconnectAttempts = 0; // 성공 시 재시도 카운트 리셋
        if (kDebugMode) {
          print('CameraService: 기기 재등록 성공');
        }
        break;
        
      } catch (e) {
        attempts++;
        _reconnectAttempts = attempts;
        
        if (kDebugMode) {
          print('CameraService: 재등록 시도 $attempts 실패: $e');
        }
        
        if (attempts < _maxReconnectAttempts) {
          // Exponential backoff
          await Future.delayed(Duration(seconds: attempts * 2));
        } else {
          if (kDebugMode) {
            print('CameraService: 재등록 최대 시도 횟수 초과 ($_reconnectAttempts/$_maxReconnectAttempts)');
          }
          // 사용자에게 알림을 보낼 수도 있음 (향후 구현)
        }
      }
    }
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _healthChecker.startHealthCheck(
      interval: Duration(minutes: 2),
      onRegistrationFailure: (deviceId, error) {
        if (deviceId == _deviceId) {
          if (kDebugMode) {
            print('CameraService: 기기 등록 실패 감지 - $error');
          }
          // Attempt auto-recovery
          _recoverDeviceRegistration();
        }
      },
      onConnectionRestored: (deviceId) {
        if (deviceId == _deviceId) {
          if (kDebugMode) {
            print('CameraService: 기기 연결 복구됨');
          }
        }
      },
      onHealthMetrics: (deviceId, metrics) {
        if (deviceId == _deviceId && kDebugMode) {
          print('CameraService: 건강 상태 메트릭 - $metrics');
        }
      },
    );
  }

  /// Stop health monitoring
  void _stopHealthMonitoring() {
    _healthChecker.stopHealthCheck();
  }

  /// Recover device registration using health checker
  Future<void> _recoverDeviceRegistration() async {
    if (!_isMonitoring) return;

    try {
      final recovered = await _healthChecker.recoverDevice(_deviceId, () async {
        // Re-registration callback
        if (kDebugMode) {
          print('CameraService: Health Check에 의한 자동 재등록 시도');
        }
        await _reregisterDevice();
      });

      if (!recovered) {
        _errorMessage = '기기 등록 복구 실패 - 네트워크 연결을 확인해주세요';
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('CameraService: 기기 등록 복구 오류 - $e');
      }
    }
  }

  /// Force cleanup when app is being terminated
  Future<void> _forceCleanup() async {
    try {
      _stopHeartbeat();
      _stopHealthMonitoring();
      
      if (_isMonitoring) {
        await _firebaseService.removeDevice(_deviceId);
        if (kDebugMode) {
          print('CameraService: 강제 정리 완료');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('CameraService: 강제 정리 실패 (무시됨): $e');
      }
    }
  }

  /// Dispose camera resources
  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop health monitoring
    _stopHealthMonitoring();
    
    // Stop heartbeat timer
    _stopHeartbeat();
    
    // Firebase에서 디바이스 제거 (백그라운드에서 수행)
    removeDeviceFromFirebase().catchError((e) {
      if (kDebugMode) {
        print('CameraService dispose: Firebase 정리 실패 (무시됨): $e');
      }
    });

    // Disable wakelock when disposing
    WakelockPlus.disable().catchError((e) {
      if (kDebugMode) {
        print('CameraService dispose: Wakelock 비활성화 실패 (무시됨): $e');
      }
    });

    _imageStream?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Generate status data
  Map<String, dynamic> getStatusData() {
    return {
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'location': _location,
      'isOnline': _isOnline,
      'isInitialized': _isInitialized,
      'isMonitoring': _isMonitoring,
      'blueIntensity': _blueIntensity,
      'batteryLevel': _batteryLevel,
      'cameraCount': _cameras.length,
      'hasError': _errorMessage != null,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Get blue intensity description for UI
  String getBlueIntensityDescription() {
    if (!_detector.isCalibrated) {
      final stats = _detector.getStatistics();
      final calibrationProgress = (stats['calibrationFrameCount'] as int).clamp(
        0,
        30,
      );
      final progressPercent = ((calibrationProgress / 30) * 100).round();
      return '환경 분석 중... ($progressPercent%)';
    }

    if (_isWaitingState) {
      return '대기인원 있음';
    } else {
      return '대기인원 없음';
    }
  }

  /// Get monitoring status description
  String getStatusDescription() {
    if (!_isInitialized) {
      return '카메라 초기화 필요';
    } else if (!_isMonitoring) {
      return '모니터링 대기중';
    } else if (!_detector.isCalibrated) {
      final stats = _detector.getStatistics();
      final calibrationProgress = (stats['calibrationFrameCount'] as int).clamp(
        0,
        30,
      );
      return '환경 분석 중 ($calibrationProgress/30)';
    } else {
      return '모니터링 진행중';
    }
  }
}
