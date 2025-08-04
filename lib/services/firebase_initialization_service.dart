import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options_web.dart';

/// Firebase 초기화와 인증을 안전하게 관리하는 서비스
class FirebaseInitializationService {
  static final FirebaseInitializationService _instance =
      FirebaseInitializationService._internal();
  factory FirebaseInitializationService() => _instance;
  FirebaseInitializationService._internal();

  bool _isFirebaseInitialized = false;
  bool _isAuthInitialized = false;
  final Completer<bool> _initializationCompleter = Completer<bool>();

  // Getters
  bool get isFirebaseInitialized => _isFirebaseInitialized;
  bool get isAuthInitialized => _isAuthInitialized;
  bool get isFullyInitialized => _isFirebaseInitialized && _isAuthInitialized;

  /// Firebase 및 인증 초기화 완료까지 대기
  Future<bool> waitForInitialization() async {
    if (isFullyInitialized) return true;

    if (!_initializationCompleter.isCompleted) {
      return _initializationCompleter.future;
    }

    return isFullyInitialized;
  }

  /// Firebase Core 초기화
  Future<bool> initializeFirebaseCore() async {
    if (_isFirebaseInitialized) return true;

    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: WebFirebaseOptions.currentPlatform,
        );
        if (kDebugMode) {
          print('FirebaseInitializationService: 웹 Firebase Core 초기화 완료');
        }
      } else {
        await Firebase.initializeApp();
        if (kDebugMode) {
          print('FirebaseInitializationService: 모바일 Firebase Core 초기화 완료');
        }
      }
      _isFirebaseInitialized = true;

      _checkAndCompleteInitialization();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseInitializationService: Firebase Core 초기화 실패 - $e');
      }
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete(false);
      }
      return false;
    }
  }

  /// Firebase Auth 익명 인증 초기화
  Future<bool> initializeAuth() async {
    if (_isAuthInitialized) return true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('FirebaseInitializationService: 익명 인증 시작 (웹: $kIsWeb)');
        }
        
        // 웹에서 더 안정적인 인증을 위해 재시도 로직 추가
        UserCredential? credential;
        int attempts = 0;
        const maxAttempts = 3;
        
        while (attempts < maxAttempts && credential == null) {
          try {
            credential = await FirebaseAuth.instance.signInAnonymously();
            break;
          } catch (e) {
            attempts++;
            if (kDebugMode) {
              print('FirebaseInitializationService: 인증 시도 $attempts 실패 - $e');
            }
            if (attempts < maxAttempts) {
              await Future.delayed(Duration(seconds: attempts));
            }
          }
        }
        
        if (credential == null) {
          throw Exception('익명 인증 실패 (모든 시도 소진)');
        }
        
        if (kDebugMode) {
          print(
            'FirebaseInitializationService: 익명 인증 완료 - ${credential.user?.uid}',
          );
        }
      } else {
        if (kDebugMode) {
          print('FirebaseInitializationService: 기존 사용자 인증 확인 - ${user.uid}');
        }
      }

      _isAuthInitialized = true;

      // 인증 상태가 안정화될 때까지 잠시 대기
      await Future.delayed(const Duration(milliseconds: 1000));

      _checkAndCompleteInitialization();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseInitializationService: 인증 초기화 실패 - $e');
      }
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete(false);
      }
      return false;
    }
  }

  /// 전체 초기화 수행
  Future<bool> initializeFully() async {
    if (isFullyInitialized) return true;

    try {
      // Firebase Core 먼저 초기화
      final coreInitialized = await initializeFirebaseCore();
      if (!coreInitialized) return false;

      // 그 다음 인증 초기화
      final authInitialized = await initializeAuth();
      if (!authInitialized) return false;

      if (kDebugMode) {
        print('FirebaseInitializationService: 전체 초기화 완료');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseInitializationService: 전체 초기화 실패 - $e');
      }
      return false;
    }
  }

  /// 초기화 완료 상태 확인 및 completer 완료
  void _checkAndCompleteInitialization() {
    if (isFullyInitialized && !_initializationCompleter.isCompleted) {
      _initializationCompleter.complete(true);
      if (kDebugMode) {
        print('FirebaseInitializationService: 모든 초기화 작업 완료');
      }
    }
  }

  /// 현재 인증된 사용자 정보 반환
  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// 인증 상태 확인
  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;
}
