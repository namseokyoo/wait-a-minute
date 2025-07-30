import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/cctv_device_status.dart';
import 'local_notification_service.dart';

/// 실시간 데이터베이스에서 CCTV 디바이스 상태를 모니터링하는 서비스
/// 읽기 전용 - 데이터 저장은 하지 않음
class RealtimeMonitorService extends ChangeNotifier {
  static const String _devicesPath = '/devices';

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Map<String, CCTVDeviceStatus> _devices = {};
  final Map<String, bool> _previousWaitingStates = {}; // 이전 대기 상태 추적

  StreamSubscription<DatabaseEvent>? _devicesSubscription;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _monitorId; // 현재 모니터 디바이스 ID 추적

  // Getters
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  List<CCTVDeviceStatus> get devices => _devices.values.toList();
  int get deviceCount => _devices.length;
  int get onlineDeviceCount => _devices.values.where((d) => d.isOnline).length;
  int get monitoringDeviceCount =>
      _devices.values.where((d) => d.isMonitoring).length;
  int get waitingDeviceCount =>
      _devices.values.where((d) => d.isWaitingDetected).length;

  /// 서비스 초기화 및 실시간 리스너 설정
  Future<bool> initialize() async {
    try {
      if (kDebugMode) {
        print('RealtimeMonitorService: 초기화 시작');
      }

      // Firebase가 이미 초기화되었는지 확인
      if (Firebase.apps.isEmpty) {
        _errorMessage = 'Firebase가 초기화되지 않았습니다. main.dart에서 Firebase.initializeApp()을 먼저 실행해주세요.';
        if (kDebugMode) {
          print('RealtimeMonitorService: Firebase 초기화되지 않음');
        }
        notifyListeners();
        return false;
      }

      // Firebase Database는 자동으로 올바른 URL을 사용합니다
      // 수동 URL 설정을 제거하고 기본 설정 사용

      // 오프라인 지속성 활성화 (한 번만 설정)
      try {
        _database.setPersistenceEnabled(true);
      } catch (e) {
        if (kDebugMode) {
          print('RealtimeMonitorService: 지속성 이미 설정됨 또는 실패: $e');
        }
      }

      // 실시간 리스너 설정 (즉시 시작)
      _setupDevicesListener();

      // 모니터 디바이스로 등록 (백그라운드에서 처리)
      _registerAsMonitorDevice().catchError((e) {
        if (kDebugMode) {
          print('모니터 등록 실패 (무시됨): $e');
        }
      });

      _isInitialized = true;
      _errorMessage = null;

      if (kDebugMode) {
        print('RealtimeMonitorService: 초기화 완료');
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '실시간 DB 초기화 실패: ${e.toString()}';
      _isInitialized = false;

      if (kDebugMode) {
        print('RealtimeMonitorService 초기화 오류: $e');
      }

      notifyListeners();
      return false;
    }
  }



  /// 모니터 디바이스로 등록 (FCM 알림 수신을 위해) - 안전한 방식
  Future<void> _registerAsMonitorDevice() async {
    try {
      // Firebase 보안 규칙이 허용하는 경우에만 등록
      _monitorId = 'monitor_${DateTime.now().millisecondsSinceEpoch}';
      
      if (kDebugMode) {
        print('RealtimeMonitorService: 모니터 디바이스 등록 시도 ($_monitorId)');
        print('Firebase 보안 규칙에 따라 등록이 실패할 수 있습니다 (정상)');
      }

      // 타임아웃을 설정하여 무한 대기 방지
      await _database.ref('/monitors').child(_monitorId!).set({
        'deviceName': '모니터링 앱',
        'deviceType': 'monitor',
        'isOnline': true,
        'registeredAt': DateTime.now().millisecondsSinceEpoch,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      }).timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        print('RealtimeMonitorService: 모니터 디바이스 등록 성공 ($_monitorId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RealtimeMonitorService: 모니터 등록 실패 (정상): $e');
        print('읽기 전용 모드로 계속 진행합니다');
      }
      // 등록 실패 시 monitorId를 null로 설정
      _monitorId = null;
    }
  }

  /// 모니터 디바이스를 Firebase에서 제거
  Future<void> _unregisterMonitorDevice() async {
    if (_monitorId == null) return;

    try {
      if (kDebugMode) {
        print('RealtimeMonitorService: 모니터 디바이스 제거 중 ($_monitorId)');
      }

      await _database.ref('/monitors').child(_monitorId!).remove().timeout(
        const Duration(seconds: 3),
      );

      if (kDebugMode) {
        print('RealtimeMonitorService: 모니터 디바이스 제거 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RealtimeMonitorService: 모니터 제거 실패 (무시됨): $e');
      }
    } finally {
      _monitorId = null;
    }
  }

  /// CCTV 디바이스들의 실시간 리스너 설정
  void _setupDevicesListener() {
    final devicesRef = _database.ref(_devicesPath);

    _devicesSubscription = devicesRef.onValue.listen(
      (DatabaseEvent event) {
        _handleDevicesUpdate(event);
      },
      onError: (error) {
        _errorMessage = '실시간 데이터 수신 오류: ${error.toString()}';
        if (kDebugMode) {
          print('RealtimeMonitorService 리스너 오류: $error');
        }
        notifyListeners();
      },
    );

    if (kDebugMode) {
      print('RealtimeMonitorService: 디바이스 리스너 설정 완료');
    }
  }

  /// 디바이스 데이터 업데이트 처리
  void _handleDevicesUpdate(DatabaseEvent event) {
    try {
      final data = event.snapshot.value;

      if (data == null) {
        _devices.clear();
        if (kDebugMode) {
          print('RealtimeMonitorService: 디바이스 데이터 없음');
        }
      } else if (data is Map) {
        _updateDevicesFromData(data);
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = '데이터 처리 오류: ${e.toString()}';
      if (kDebugMode) {
        print('RealtimeMonitorService 데이터 처리 오류: $e');
      }
      notifyListeners();
    }
  }

  /// 디바이스 데이터 맵 업데이트
  void _updateDevicesFromData(Map data) {
    final Map<String, CCTVDeviceStatus> newDevices = {};

    data.forEach((key, value) {
      if (value is Map) {
        try {
          final deviceId = key.toString();
          final deviceData = Map<String, dynamic>.from(value);
          
          // Firebase 구조: /devices/{deviceId}/deviceInfo와 /devices/{deviceId}/status
          // 안전한 타입 변환
          final deviceInfo = _safeMapCast(deviceData['deviceInfo']);
          final status = _safeMapCast(deviceData['status']);
          
          if (deviceInfo != null && status != null) {
            // 디바이스 정보와 상태를 결합하여 CCTVDeviceStatus 생성
            final combinedData = <String, dynamic>{
              'deviceName': deviceInfo['name'] ?? deviceInfo['deviceName'] ?? 'Unknown Device',
              'location': deviceInfo['location'] ?? 'Unknown Location',
              'isOnline': status['isOnline'] ?? false,
              'isMonitoring': status['isMonitoring'] ?? false,
              'blueIntensity': (status['blueIntensity'] ?? 0.0).toDouble(),
              'isWaitingDetected': status['isWaiting'] ?? status['isWaitingDetected'] ?? false,
              'batteryLevel': (status['batteryLevel'] ?? 0.0).toDouble(),
              'lastUpdate': status['lastUpdate'],
              'connectionQuality': status['connectionQuality'] ?? 100,
            };
            
            final deviceStatus = CCTVDeviceStatus.fromFirebase(deviceId, combinedData);
            newDevices[deviceId] = deviceStatus;
            
            if (kDebugMode) {
              print('디바이스 파싱 성공 ($deviceId): ${deviceStatus.deviceName}');
            }
          } else {
            if (kDebugMode) {
              print('디바이스 데이터 불완전 ($deviceId):');
              print('  - deviceInfo 존재: ${deviceInfo != null}');
              print('  - status 존재: ${status != null}');
              print('  - 원본 데이터: $deviceData');
              
              // 데이터가 부분적으로만 있는 경우 처리
              if (deviceInfo != null || status != null) {
                print('  - 부분 데이터로 디바이스 생성 시도');
                final combinedData = <String, dynamic>{
                  'deviceName': (deviceInfo?['name'] ?? deviceInfo?['deviceName'] ?? status?['deviceName'] ?? 'Unknown Device'),
                  'location': (deviceInfo?['location'] ?? status?['location'] ?? 'Unknown Location'),
                  'isOnline': (status?['isOnline'] ?? false),
                  'isMonitoring': (status?['isMonitoring'] ?? false),
                  'blueIntensity': ((status?['blueIntensity'] ?? 0.0) as num).toDouble(),
                  'isWaitingDetected': (status?['isWaiting'] ?? status?['isWaitingDetected'] ?? false),
                  'batteryLevel': ((status?['batteryLevel'] ?? 0.0) as num).toDouble(),
                  'lastUpdate': status?['lastUpdate'],
                  'connectionQuality': (status?['connectionQuality'] ?? 50),
                };
                
                final deviceStatus = CCTVDeviceStatus.fromFirebase(deviceId, combinedData);
                newDevices[deviceId] = deviceStatus;
                print('  - 부분 데이터로 디바이스 생성 성공: ${deviceStatus.deviceName}');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('디바이스 파싱 오류 ($key): $e');
          }
        }
      }
    });

    // 디바이스 목록 업데이트
    _devices.clear();
    _devices.addAll(newDevices);

    // 대기 상태 변화 감지 및 알림 처리
    _checkForWaitingStateChanges();

    if (kDebugMode) {
      print('RealtimeMonitorService: ${_devices.length}개 디바이스 업데이트됨');
      for (final device in _devices.values) {
        print('  - ${device.deviceName} (${device.location}): ${device.isOnline ? "온라인" : "오프라인"}, ${device.isMonitoring ? "모니터링중" : "대기중"}');
      }
    }
  }

  /// 대기 상태 변화 감지 및 로컬 알림 발송
  void _checkForWaitingStateChanges() {
    for (final device in _devices.values) {
      final deviceId = device.deviceId;
      final currentWaitingState = device.isWaitingDetected;
      final previousWaitingState = _previousWaitingStates[deviceId] ?? false;

      // 대기 상태가 false에서 true로 변경된 경우 (새로운 대기 발생)
      if (!previousWaitingState && currentWaitingState && device.isOnline) {
        _sendWaitingNotification(device);
        
        if (kDebugMode) {
          print('대기 상태 변화 감지: ${device.deviceName} - 대기 발생!');
        }
      }

      // 현재 상태를 이전 상태로 저장
      _previousWaitingStates[deviceId] = currentWaitingState;
    }
  }

  /// 대기 발생 시 로컬 푸시 알림 전송
  void _sendWaitingNotification(CCTVDeviceStatus device) {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    final title = '🚨 고객 대기 발생!';
    final body = '${device.location}에서 고객이 대기 중입니다. ($timeString)\n'
                '기기: ${device.deviceName}\n'
                '파란불 세기: ${(device.blueIntensity * 100).toInt()}%';

    // 로컬 알림 전송
    LocalNotificationService().showNotification(
      title: title,
      body: body,
      payload: 'waiting_alert_${device.deviceId}',
    ).catchError((e) {
      if (kDebugMode) {
        print('알림 전송 실패: $e');
      }
    });

    if (kDebugMode) {
      print('로컬 푸시 알림 전송: ${device.deviceName} (${device.location})');
    }
  }

  /// 안전한 Map 타입 변환 (Firebase 데이터용)
  Map<String, dynamic>? _safeMapCast(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (e) {
        if (kDebugMode) {
          print('Map 변환 실패: $e');
        }
        return null;
      }
    }
    return null;
  }

  /// 특정 디바이스 상태 조회
  CCTVDeviceStatus? getDevice(String deviceId) {
    return _devices[deviceId];
  }

  /// 온라인 디바이스 목록
  List<CCTVDeviceStatus> get onlineDevices {
    return _devices.values.where((device) => device.isOnline).toList();
  }

  /// 모니터링 중인 디바이스 목록
  List<CCTVDeviceStatus> get monitoringDevices {
    return _devices.values.where((device) => device.isMonitoring).toList();
  }

  /// 대기 감지된 디바이스 목록
  List<CCTVDeviceStatus> get waitingDevices {
    return _devices.values.where((device) => device.isWaitingDetected).toList();
  }

  /// 전체 대기 상태 (하나라도 대기 감지 시 true)
  bool get hasWaitingCustomers {
    return _devices.values.any(
      (device) =>
          device.isOnline && device.isMonitoring && device.isWaitingDetected,
    );
  }

  /// 평균 파란불 세기
  double get averageBlueIntensity {
    final monitoringDevices = this.monitoringDevices;
    if (monitoringDevices.isEmpty) return 0.0;

    final sum = monitoringDevices.fold<double>(
      0.0,
      (sum, device) => sum + device.blueIntensity,
    );
    return sum / monitoringDevices.length;
  }

  /// 최고 파란불 세기
  double get maxBlueIntensity {
    final intensities = _devices.values
        .where((device) => device.isMonitoring)
        .map((device) => device.blueIntensity);

    return intensities.isEmpty
        ? 0.0
        : intensities.reduce((a, b) => a > b ? a : b);
  }

  /// 연결 품질 통계
  Map<String, int> get connectionQualityStats {
    final stats = {'우수': 0, '양호': 0, '보통': 0, '불량': 0, '매우 불량': 0};

    for (final device in _devices.values) {
      if (device.isOnline) {
        stats[device.connectionQualityStatus] =
            (stats[device.connectionQualityStatus] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// 수동 새로고침 (오류 복구용)
  Future<void> refresh() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    try {
      final devicesRef = _database.ref(_devicesPath);
      final snapshot = await devicesRef.get();

      if (snapshot.exists) {
        final data = snapshot.value;
        if (data is Map) {
          _updateDevicesFromData(data);
        }
      } else {
        _devices.clear();
        if (kDebugMode) {
          print('RealtimeMonitorService: 디바이스 데이터가 없습니다. CCTV 앱이 실행되어 있는지 확인하세요.');
        }
      }

      _errorMessage = null;
      notifyListeners();

      if (kDebugMode) {
        print('RealtimeMonitorService: 수동 새로고침 완료');
      }
    } catch (e) {
      _errorMessage = '새로고침 실패: ${e.toString()}';
      if (kDebugMode) {
        print('RealtimeMonitorService 새로고침 오류: $e');
      }
      notifyListeners();
    }
  }

  /// 테스트용 더미 데이터 생성 (개발 전용)
  Future<void> createTestData() async {
    if (!kDebugMode || !_isInitialized) return;

    try {
      final testDeviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
      final deviceRef = _database.ref('$_devicesPath/$testDeviceId');

      await deviceRef.set({
        'deviceInfo': {
          'name': '테스트 CCTV 기기',
          'location': '테스트 위치 (입구)',
          'mode': 'cctv',
        },
        'status': {
          'isOnline': true,
          'isMonitoring': true,
          'blueIntensity': 0.75,
          'isWaiting': true,
          'batteryLevel': 0.85,
          'lastUpdate': DateTime.now().millisecondsSinceEpoch,
          'connectionQuality': 95,
        },
      });

      if (kDebugMode) {
        print('RealtimeMonitorService: 테스트 데이터 생성됨 ($testDeviceId)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RealtimeMonitorService: 테스트 데이터 생성 실패: $e');
      }
    }
  }

  /// Monitor Service 호환성을 위한 디바이스 맵 변환
  List<Map<String, dynamic>> getDevicesForMonitorService() {
    return _devices.values.map((device) => device.toMonitorMap()).toList();
  }

  @override
  void dispose() {
    // Firebase에서 모니터 디바이스 제거
    _unregisterMonitorDevice();
    
    // 리스너 정리
    _devicesSubscription?.cancel();
    
    super.dispose();

    if (kDebugMode) {
      print('RealtimeMonitorService: 리소스 정리 완료');
    }
  }
}
