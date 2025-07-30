/// App operation modes
enum AppMode {
  /// Initial mode selection screen
  selection,

  /// CCTV monitoring mode - simple camera sensor
  cctv,

  /// Monitor mode - centralized control center
  monitor,
}

/// Extension for AppMode with utility methods
extension AppModeExtension on AppMode {
  /// Get display name for the mode
  String get displayName {
    switch (this) {
      case AppMode.selection:
        return '모드 선택';
      case AppMode.cctv:
        return 'CCTV 모드';
      case AppMode.monitor:
        return '모니터링 모드';
    }
  }

  /// Get description for the mode
  String get description {
    switch (this) {
      case AppMode.selection:
        return '사용할 모드를 선택하세요';
      case AppMode.cctv:
        return '파란불빛 감지 및 상태 전송';
      case AppMode.monitor:
        return '알림 수신 및 설정 관리';
    }
  }
}
