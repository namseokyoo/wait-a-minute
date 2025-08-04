import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// 웹 브라우저 전용 생명주기 관리 서비스
/// 탭 활성/비활성, 브라우저 최소화, 절전 모드 등을 감지하여 Firebase 연결 유지
class WebLifecycleService {
  static final WebLifecycleService _instance = WebLifecycleService._internal();
  factory WebLifecycleService() => _instance;
  WebLifecycleService._internal();

  // 상태 관리
  bool _isTabVisible = true;
  bool _isPageFocused = true;
  bool _isOnline = true;
  DateTime _lastVisibilityChange = DateTime.now();
  
  // 콜백 관리
  final List<Function(bool isVisible)> _visibilityCallbacks = [];
  final List<Function(bool isFocused)> _focusCallbacks = [];
  final List<Function(bool isOnline)> _connectionCallbacks = [];
  
  // 타이머 관리
  Timer? _backgroundHeartbeat;
  Timer? _reconnectionTimer;
  
  // 초기화 상태
  bool _isInitialized = false;

  // Getters
  bool get isTabVisible => _isTabVisible;
  bool get isPageFocused => _isPageFocused;
  bool get isOnline => _isOnline;
  bool get isInBackground => !_isTabVisible || !_isPageFocused;
  Duration get timeSinceLastVisibilityChange => 
      DateTime.now().difference(_lastVisibilityChange);

  /// 웹 생명주기 이벤트 리스너 초기화
  void initialize() {
    if (_isInitialized || !kIsWeb) return;

    try {
      // Page Visibility API 리스너
      html.document.addEventListener('visibilitychange', _handleVisibilityChange);
      
      // Window focus/blur 이벤트 리스너
      html.window.addEventListener('focus', _handleWindowFocus);
      html.window.addEventListener('blur', _handleWindowBlur);
      
      // 온라인/오프라인 상태 리스너
      html.window.addEventListener('online', _handleOnline);
      html.window.addEventListener('offline', _handleOffline);
      
      // Page Lifecycle API 리스너 (최신 브라우저)
      html.document.addEventListener('freeze', _handlePageFreeze);
      html.document.addEventListener('resume', _handlePageResume);
      
      // Beforeunload 이벤트 (페이지 종료 감지)
      html.window.addEventListener('beforeunload', _handleBeforeUnload);

      _isInitialized = true;

      if (kDebugMode) {
        print('WebLifecycleService: 웹 생명주기 이벤트 리스너 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebLifecycleService: 초기화 실패 - $e');
      }
    }
  }

  /// 탭 가시성 변경 처리
  void _handleVisibilityChange(html.Event event) {
    final wasVisible = _isTabVisible;
    _isTabVisible = !html.document.hidden!;
    _lastVisibilityChange = DateTime.now();

    if (wasVisible != _isTabVisible) {
      if (kDebugMode) {
        print('WebLifecycleService: 탭 가시성 변경 - ${_isTabVisible ? "표시" : "숨김"}');
      }

      if (_isTabVisible) {
        _handleTabVisible();
      } else {
        _handleTabHidden();
      }

      // 콜백 실행
      for (final callback in _visibilityCallbacks) {
        try {
          callback(_isTabVisible);
        } catch (e) {
          if (kDebugMode) {
            print('WebLifecycleService: 가시성 콜백 오류 - $e');
          }
        }
      }
    }
  }

  /// 윈도우 포커스 처리
  void _handleWindowFocus(html.Event event) {
    if (!_isPageFocused) {
      _isPageFocused = true;
      
      if (kDebugMode) {
        print('WebLifecycleService: 윈도우 포커스 획득');
      }

      _handlePageActive();
      
      // 콜백 실행
      for (final callback in _focusCallbacks) {
        try {
          callback(true);
        } catch (e) {
          if (kDebugMode) {
            print('WebLifecycleService: 포커스 콜백 오류 - $e');
          }
        }
      }
    }
  }

  /// 윈도우 블러 처리
  void _handleWindowBlur(html.Event event) {
    if (_isPageFocused) {
      _isPageFocused = false;
      
      if (kDebugMode) {
        print('WebLifecycleService: 윈도우 포커스 상실');
      }

      _handlePageInactive();
      
      // 콜백 실행
      for (final callback in _focusCallbacks) {
        try {
          callback(false);
        } catch (e) {
          if (kDebugMode) {
            print('WebLifecycleService: 블러 콜백 오류 - $e');
          }
        }
      }
    }
  }

  /// 온라인 상태 복구
  void _handleOnline(html.Event event) {
    if (!_isOnline) {
      _isOnline = true;
      
      if (kDebugMode) {
        print('WebLifecycleService: 네트워크 연결 복구');
      }

      _stopReconnectionTimer();
      
      // 콜백 실행
      for (final callback in _connectionCallbacks) {
        try {
          callback(true);
        } catch (e) {
          if (kDebugMode) {
            print('WebLifecycleService: 온라인 콜백 오류 - $e');
          }
        }
      }
    }
  }

  /// 오프라인 상태 처리
  void _handleOffline(html.Event event) {
    if (_isOnline) {
      _isOnline = false;
      
      if (kDebugMode) {
        print('WebLifecycleService: 네트워크 연결 끊김');
      }

      _startReconnectionTimer();
      
      // 콜백 실행
      for (final callback in _connectionCallbacks) {
        try {
          callback(false);
        } catch (e) {
          if (kDebugMode) {
            print('WebLifecycleService: 오프라인 콜백 오류 - $e');
          }
        }
      }
    }
  }

  /// 페이지 고정 (절전 모드 등)
  void _handlePageFreeze(html.Event event) {
    if (kDebugMode) {
      print('WebLifecycleService: 페이지 고정됨 (절전 모드)');
    }
    _startBackgroundHeartbeat();
  }

  /// 페이지 복구
  void _handlePageResume(html.Event event) {
    if (kDebugMode) {
      print('WebLifecycleService: 페이지 복구됨');
    }
    _stopBackgroundHeartbeat();
  }

  /// 페이지 종료 감지
  void _handleBeforeUnload(html.Event event) {
    if (kDebugMode) {
      print('WebLifecycleService: 페이지 종료 감지');
    }
    // 정리 작업은 dispose에서 처리
  }

  /// 탭이 보이게 될 때
  void _handleTabVisible() {
    _stopBackgroundHeartbeat();
    // Firebase 연결 상태 재확인 및 복구 로직은 콜백에서 처리
  }

  /// 탭이 숨겨질 때
  void _handleTabHidden() {
    _startBackgroundHeartbeat();
  }

  /// 페이지가 활성화될 때
  void _handlePageActive() {
    _stopBackgroundHeartbeat();
  }

  /// 페이지가 비활성화될 때
  void _handlePageInactive() {
    _startBackgroundHeartbeat();
  }

  /// 백그라운드 heartbeat 시작 (브라우저 제한 고려)
  void _startBackgroundHeartbeat() {
    _stopBackgroundHeartbeat();
    
    // 백그라운드에서는 최소 1초 간격으로 제한됨
    _backgroundHeartbeat = Timer.periodic(Duration(seconds: 10), (timer) {
      if (kDebugMode) {
        print('WebLifecycleService: 백그라운드 heartbeat - ${DateTime.now()}');
      }
      
      // Firebase 연결 유지 신호를 콜백으로 전달
      for (final callback in _connectionCallbacks) {
        try {
          callback(_isOnline);
        } catch (e) {
          if (kDebugMode) {
            print('WebLifecycleService: Heartbeat 콜백 오류 - $e');
          }
        }
      }
    });
  }

  /// 백그라운드 heartbeat 중지
  void _stopBackgroundHeartbeat() {
    _backgroundHeartbeat?.cancel();
    _backgroundHeartbeat = null;
  }

  /// 재연결 타이머 시작
  void _startReconnectionTimer() {
    _stopReconnectionTimer();
    
    _reconnectionTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (kDebugMode) {
        print('WebLifecycleService: 재연결 시도 - ${timer.tick}');
      }
      
      // 실제 재연결 로직은 콜백에서 처리
      if (_isOnline) {
        _stopReconnectionTimer();
      }
    });
  }

  /// 재연결 타이머 중지
  void _stopReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  /// 가시성 변경 콜백 등록
  void addVisibilityCallback(Function(bool isVisible) callback) {
    _visibilityCallbacks.add(callback);
  }

  /// 포커스 변경 콜백 등록
  void addFocusCallback(Function(bool isFocused) callback) {
    _focusCallbacks.add(callback);
  }

  /// 연결 상태 변경 콜백 등록
  void addConnectionCallback(Function(bool isOnline) callback) {
    _connectionCallbacks.add(callback);
  }

  /// 콜백 제거
  void removeVisibilityCallback(Function(bool isVisible) callback) {
    _visibilityCallbacks.remove(callback);
  }

  void removeFocusCallback(Function(bool isFocused) callback) {
    _focusCallbacks.remove(callback);
  }

  void removeConnectionCallback(Function(bool isOnline) callback) {
    _connectionCallbacks.remove(callback);
  }

  /// 현재 상태 정보 반환
  Map<String, dynamic> getStatus() {
    return {
      'isTabVisible': _isTabVisible,
      'isPageFocused': _isPageFocused,
      'isOnline': _isOnline,
      'isInBackground': isInBackground,
      'timeSinceLastVisibilityChange': timeSinceLastVisibilityChange.inSeconds,
      'hasBackgroundHeartbeat': _backgroundHeartbeat != null,
      'hasReconnectionTimer': _reconnectionTimer != null,
    };
  }

  /// 리소스 정리
  void dispose() {
    if (!kIsWeb || !_isInitialized) return;

    try {
      // 이벤트 리스너 제거
      html.document.removeEventListener('visibilitychange', _handleVisibilityChange);
      html.window.removeEventListener('focus', _handleWindowFocus);
      html.window.removeEventListener('blur', _handleWindowBlur);
      html.window.removeEventListener('online', _handleOnline);
      html.window.removeEventListener('offline', _handleOffline);
      html.document.removeEventListener('freeze', _handlePageFreeze);
      html.document.removeEventListener('resume', _handlePageResume);
      html.window.removeEventListener('beforeunload', _handleBeforeUnload);

      // 타이머 정리
      _stopBackgroundHeartbeat();
      _stopReconnectionTimer();

      // 콜백 정리
      _visibilityCallbacks.clear();
      _focusCallbacks.clear();
      _connectionCallbacks.clear();

      _isInitialized = false;

      if (kDebugMode) {
        print('WebLifecycleService: 리소스 정리 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebLifecycleService: 정리 중 오류 - $e');
      }
    }
  }
}