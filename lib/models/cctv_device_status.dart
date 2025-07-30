/// CCTV 디바이스 실시간 상태 모델
class CCTVDeviceStatus {
  final String deviceId;
  final String deviceName;
  final String location;
  final bool isOnline;
  final bool isMonitoring;
  final double blueIntensity;
  final bool isWaitingDetected;
  final double batteryLevel;
  final DateTime lastUpdate;
  final String? errorMessage;
  final int connectionQuality; // 0-100%

  const CCTVDeviceStatus({
    required this.deviceId,
    required this.deviceName,
    required this.location,
    required this.isOnline,
    required this.isMonitoring,
    required this.blueIntensity,
    required this.isWaitingDetected,
    required this.batteryLevel,
    required this.lastUpdate,
    this.errorMessage,
    this.connectionQuality = 100,
  });

  /// Firebase Realtime Database에서 데이터 생성
  factory CCTVDeviceStatus.fromFirebase(
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return CCTVDeviceStatus(
      deviceId: deviceId,
      deviceName: data['deviceName'] ?? 'Unknown Device',
      location: data['location'] ?? 'Unknown Location',
      isOnline: data['isOnline'] ?? false,
      isMonitoring: data['isMonitoring'] ?? false,
      blueIntensity: (data['blueIntensity'] ?? 0.0).toDouble(),
      isWaitingDetected: data['isWaitingDetected'] ?? false,
      batteryLevel: (data['batteryLevel'] ?? 0.0).toDouble(),
      lastUpdate:
          data['lastUpdate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['lastUpdate'])
              : DateTime.now(),
      errorMessage: data['errorMessage'],
      connectionQuality: data['connectionQuality'] ?? 100,
    );
  }

  /// Firebase Realtime Database로 데이터 변환
  Map<String, dynamic> toFirebase() {
    return {
      'deviceName': deviceName,
      'location': location,
      'isOnline': isOnline,
      'isMonitoring': isMonitoring,
      'blueIntensity': blueIntensity,
      'isWaitingDetected': isWaitingDetected,
      'batteryLevel': batteryLevel,
      'lastUpdate': lastUpdate.millisecondsSinceEpoch,
      'errorMessage': errorMessage,
      'connectionQuality': connectionQuality,
    };
  }

  /// 간소화된 Monitor Service 호환성을 위한 Map 변환
  Map<String, dynamic> toMonitorMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'location': location,
      'isOnline': isOnline,
      'isMonitoring': isMonitoring,
      'blueIntensity': blueIntensity,
      'isBlueDetected': isWaitingDetected,
      'batteryLevel': batteryLevel,
      'lastUpdate': lastUpdate,
      'errorMessage': errorMessage,
      'connectionQuality': connectionQuality,
    };
  }

  /// 상태 복사본 생성
  CCTVDeviceStatus copyWith({
    String? deviceId,
    String? deviceName,
    String? location,
    bool? isOnline,
    bool? isMonitoring,
    double? blueIntensity,
    bool? isWaitingDetected,
    double? batteryLevel,
    DateTime? lastUpdate,
    String? errorMessage,
    int? connectionQuality,
  }) {
    return CCTVDeviceStatus(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      location: location ?? this.location,
      isOnline: isOnline ?? this.isOnline,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      blueIntensity: blueIntensity ?? this.blueIntensity,
      isWaitingDetected: isWaitingDetected ?? this.isWaitingDetected,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      errorMessage: errorMessage ?? this.errorMessage,
      connectionQuality: connectionQuality ?? this.connectionQuality,
    );
  }

  /// 디바이스 상태 요약
  String get statusSummary {
    if (!isOnline) return '오프라인';
    if (errorMessage != null) return '오류';
    if (!isMonitoring) return '대기중';
    if (isWaitingDetected) return '고객 대기 감지';
    return '정상 모니터링';
  }

  /// 연결 품질 상태
  String get connectionQualityStatus {
    if (connectionQuality >= 80) return '우수';
    if (connectionQuality >= 60) return '양호';
    if (connectionQuality >= 40) return '보통';
    if (connectionQuality >= 20) return '불량';
    return '매우 불량';
  }

  /// 배터리 상태
  String get batteryStatus {
    if (batteryLevel >= 0.8) return '충분';
    if (batteryLevel >= 0.5) return '보통';
    if (batteryLevel >= 0.2) return '부족';
    return '매우 부족';
  }

  @override
  String toString() {
    return 'CCTVDeviceStatus(deviceId: $deviceId, deviceName: $deviceName, '
        'isOnline: $isOnline, isWaitingDetected: $isWaitingDetected, '
        'blueIntensity: $blueIntensity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CCTVDeviceStatus &&
        other.deviceId == deviceId &&
        other.isOnline == isOnline &&
        other.isMonitoring == isMonitoring &&
        other.blueIntensity == blueIntensity &&
        other.isWaitingDetected == isWaitingDetected;
  }

  @override
  int get hashCode {
    return Object.hash(
      deviceId,
      isOnline,
      isMonitoring,
      blueIntensity,
      isWaitingDetected,
    );
  }
}
