/// CCTV 감도 설정 모델
class SensitivitySettings {
  /// 감도 배율 (0.1 ~ 3.0)
  final double multiplier;
  
  /// 감도 레벨 이름
  final String levelName;
  
  /// 임계값 (대기 감지를 위한 최소값)
  final double threshold;
  
  /// 설정 생성 시간
  final DateTime createdAt;

  const SensitivitySettings({
    required this.multiplier,
    required this.levelName,
    required this.threshold,
    required this.createdAt,
  });

  /// 기본 감도 설정 (표준)
  factory SensitivitySettings.standard() {
    return SensitivitySettings(
      multiplier: 1.0,
      levelName: '표준',
      threshold: 0.3,
      createdAt: DateTime.now(),
    );
  }

  /// 낮은 감도 (강한 파란불만 감지)
  factory SensitivitySettings.low() {
    return SensitivitySettings(
      multiplier: 0.5,
      levelName: '낮음',
      threshold: 0.5,
      createdAt: DateTime.now(),
    );
  }

  /// 높은 감도 (약한 파란불도 감지)
  factory SensitivitySettings.high() {
    return SensitivitySettings(
      multiplier: 2.0,
      levelName: '높음',
      threshold: 0.15,
      createdAt: DateTime.now(),
    );
  }

  /// 최고 감도 (매우 약한 파란불도 감지)
  factory SensitivitySettings.maximum() {
    return SensitivitySettings(
      multiplier: 3.0,
      levelName: '최고',
      threshold: 0.1,
      createdAt: DateTime.now(),
    );
  }

  /// 맞춤 감도 설정
  factory SensitivitySettings.custom({
    required double multiplier,
    required double threshold,
  }) {
    return SensitivitySettings(
      multiplier: multiplier.clamp(0.1, 3.0),
      levelName: '맞춤',
      threshold: threshold.clamp(0.05, 0.8),
      createdAt: DateTime.now(),
    );
  }

  /// 강도 값에 감도 배율 적용
  double applyMultiplier(double intensity) {
    return (intensity * multiplier).clamp(0.0, 1.0);
  }

  /// 대기 상태 판단 (임계값과 비교)
  bool isWaitingDetected(double amplifiedIntensity) {
    return amplifiedIntensity >= threshold;
  }

  /// 감도 레벨 설명
  String get description {
    switch (levelName) {
      case '낮음':
        return '강한 파란불만 감지 (오탐지 최소화)';
      case '표준':
        return '일반적인 파란불 감지 (권장)';
      case '높음':
        return '약한 파란불도 감지 (민감도 증가)';
      case '최고':
        return '매우 약한 파란불도 감지 (최고 민감도)';
      case '맞춤':
        return '사용자 정의 감도 설정';
      default:
        return '알 수 없는 설정';
    }
  }

  /// 감도 설정을 Map으로 변환 (Firebase 저장용)
  Map<String, dynamic> toMap() {
    return {
      'multiplier': multiplier,
      'levelName': levelName,
      'threshold': threshold,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Map에서 감도 설정 생성 (Firebase 로드용)
  factory SensitivitySettings.fromMap(Map<String, dynamic> map) {
    return SensitivitySettings(
      multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
      levelName: map['levelName'] as String? ?? '표준',
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0.3,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() => toMap();

  /// JSON 역직렬화
  factory SensitivitySettings.fromJson(Map<String, dynamic> json) => 
      SensitivitySettings.fromMap(json);

  /// 복사본 생성
  SensitivitySettings copyWith({
    double? multiplier,
    String? levelName,
    double? threshold,
    DateTime? createdAt,
  }) {
    return SensitivitySettings(
      multiplier: multiplier ?? this.multiplier,
      levelName: levelName ?? this.levelName,
      threshold: threshold ?? this.threshold,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 미리 정의된 감도 레벨 목록
  static List<SensitivitySettings> get presets => [
    SensitivitySettings.low(),
    SensitivitySettings.standard(),
    SensitivitySettings.high(),
    SensitivitySettings.maximum(),
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensitivitySettings &&
        other.multiplier == multiplier &&
        other.levelName == levelName &&
        other.threshold == threshold;
  }

  @override
  int get hashCode {
    return multiplier.hashCode ^
        levelName.hashCode ^
        threshold.hashCode;
  }

  @override
  String toString() {
    return 'SensitivitySettings('
        'multiplier: $multiplier, '
        'levelName: $levelName, '
        'threshold: $threshold'
        ')';
  }
}