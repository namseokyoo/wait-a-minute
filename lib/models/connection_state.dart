/// WebSocket connection states
enum ConnectionState {
  /// Not connected
  disconnected,

  /// Attempting to connect
  connecting,

  /// Successfully connected
  connected,

  /// Connection error occurred
  error,
}

/// Extension for ConnectionState with utility methods
extension ConnectionStateExtension on ConnectionState {
  /// Get display text for connection state
  String get displayText {
    switch (this) {
      case ConnectionState.disconnected:
        return '연결끊김';
      case ConnectionState.connecting:
        return '연결중';
      case ConnectionState.connected:
        return '연결됨';
      case ConnectionState.error:
        return '오류';
    }
  }

  /// Check if state indicates active connection
  bool get isActive => this == ConnectionState.connected;

  /// Check if state indicates error condition
  bool get hasError => this == ConnectionState.error;
}
