import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'waiting_state_service.dart';

/// Unified notification service for waiting state alerts (replaces both NotificationService and LocalNotificationService)
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  bool _isListeningToStateChanges = false;
  WaitingStateService? _waitingStateService;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Initialize local notification service only
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kDebugMode) {
        print('Starting local notification initialization...');
      }

      // Initialize local notifications
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final result = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      if (result != true) {
        throw Exception('Failed to initialize local notifications');
      }

      _isInitialized = true;

      if (kDebugMode) {
        print('Local notification service initialized successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Local notification initialization failed: $e');
      }
      return false;
    }
  }

  /// Handle notification response when user taps on notification
  void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
  }

  /// Show waiting state notification
  Future<void> showWaitingNotification({
    required String deviceName,
    required String location,
  }) async {
    if (!_isInitialized || !_notificationsEnabled) return;

    try {
      final title = '대기인원 알림';
      final body = location.isNotEmpty
          ? '$location에서 대기인원이 감지되었습니다'
          : '$deviceName에서 대기인원이 감지되었습니다';

      const androidDetails = AndroidNotificationDetails(
        'waiting_alerts',
        '대기인원 알림',
        channelDescription: '고객 대기인원 감지 알림',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 0, 0),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: 'waiting_alert',
      );

      if (kDebugMode) {
        print('Local waiting notification shown: $body');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to show waiting notification: $e');
      }
    }
  }

  /// Start listening to waiting state changes
  void startListeningToWaitingStateChanges(WaitingStateService waitingStateService) {
    if (_isListeningToStateChanges) return;

    _waitingStateService = waitingStateService;
    _isListeningToStateChanges = true;

    // Create and store the listener function
    _waitingStateListener = () {
      if (_waitingStateService!.isWaitingState) {
        showWaitingNotification(
          deviceName: '감지 기기',
          location: '',
        );
      }
    };

    _waitingStateService!.addListener(_waitingStateListener!);

    if (kDebugMode) {
      print('Started listening to waiting state changes for local notifications');
    }
  }

  // Store the listener function to properly remove it
  VoidCallback? _waitingStateListener;

  /// Stop listening to waiting state changes
  void stopListeningToWaitingStateChanges() {
    if (!_isListeningToStateChanges || _waitingStateService == null || _waitingStateListener == null) return;

    _waitingStateService!.removeListener(_waitingStateListener!);
    _waitingStateListener = null;
    _isListeningToStateChanges = false;
    _waitingStateService = null;

    if (kDebugMode) {
      print('Stopped listening to waiting state changes');
    }
  }

  /// Enable/disable notifications
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    if (kDebugMode) {
      print('Notifications ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  /// Test local notification
  Future<void> testNotification() async {
    await showWaitingNotification(
      deviceName: '테스트 기기',
      location: '테스트 위치',
    );
  }

  /// Setup waiting state listener (from original NotificationService functionality)
  void setupWaitingStateListener(WaitingStateService waitingStateService) {
    startListeningToWaitingStateChanges(waitingStateService);
  }

  /// Show general notification (additional functionality)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized || !_notificationsEnabled) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'general_notifications',
        '일반 알림',
        channelDescription: '앱 일반 알림',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      if (kDebugMode) {
        print('General notification shown: $title - $body');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to show general notification: $e');
      }
    }
  }
}