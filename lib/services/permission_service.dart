import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Real permission service for handling device permissions
class PermissionService extends ChangeNotifier {
  bool _cameraPermissionGranted = false;
  bool _notificationPermissionGranted = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get cameraPermissionGranted => _cameraPermissionGranted;
  bool get notificationPermissionGranted => _notificationPermissionGranted;
  bool get allPermissionsGranted =>
      _cameraPermissionGranted && _notificationPermissionGranted;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Check all required permissions status
  Future<void> checkPermissions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.status;
      _cameraPermissionGranted = cameraStatus == PermissionStatus.granted;

      // Check notification permission
      final notificationStatus = await Permission.notification.status;
      _notificationPermissionGranted =
          notificationStatus == PermissionStatus.granted;

      if (kDebugMode) {
        print('Camera permission: $_cameraPermissionGranted');
        print('Notification permission: $_notificationPermissionGranted');
      }
    } catch (e) {
      _errorMessage = '권한 상태 확인 실패: $e';
      if (kDebugMode) {
        print('Permission check error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await Permission.camera.request();
      _cameraPermissionGranted = status == PermissionStatus.granted;

      if (status == PermissionStatus.permanentlyDenied) {
        _errorMessage = '카메라 권한이 영구적으로 거부되었습니다. 설정에서 수동으로 허용해주세요.';
      } else if (status == PermissionStatus.denied) {
        _errorMessage = '카메라 권한이 필요합니다.';
      }

      if (kDebugMode) {
        print('Camera permission request result: $status');
      }
    } catch (e) {
      _errorMessage = '카메라 권한 요청 실패: $e';
      if (kDebugMode) {
        print('Camera permission request error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    return _cameraPermissionGranted;
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await Permission.notification.request();
      _notificationPermissionGranted = status == PermissionStatus.granted;

      if (status == PermissionStatus.permanentlyDenied) {
        _errorMessage = '알림 권한이 영구적으로 거부되었습니다. 설정에서 수동으로 허용해주세요.';
      } else if (status == PermissionStatus.denied) {
        _errorMessage = '알림 권한이 필요합니다.';
      }

      if (kDebugMode) {
        print('Notification permission request result: $status');
      }
    } catch (e) {
      _errorMessage = '알림 권한 요청 실패: $e';
      if (kDebugMode) {
        print('Notification permission request error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    return _notificationPermissionGranted;
  }

  /// Request all required permissions
  Future<bool> requestAllPermissions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Request camera permission first
      await requestCameraPermission();

      // Wait a bit between requests to avoid overwhelming the user
      await Future.delayed(const Duration(milliseconds: 500));

      // Request notification permission
      await requestNotificationPermission();

      if (kDebugMode) {
        print(
          'All permissions requested - Camera: $_cameraPermissionGranted, Notification: $_notificationPermissionGranted',
        );
      }
    } catch (e) {
      _errorMessage = '권한 요청 실패: $e';
      if (kDebugMode) {
        print('All permissions request error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    return allPermissionsGranted;
  }

  /// Open app settings for manual permission grant
  Future<void> openSettings() async {
    try {
      await openAppSettings();
      if (kDebugMode) {
        print('Opening app settings');
      }
    } catch (e) {
      _errorMessage = '설정 앱 열기 실패: $e';
      if (kDebugMode) {
        print('Open settings error: $e');
      }
      notifyListeners();
    }
  }

  /// Check if app can request permissions (not permanently denied)
  Future<bool> canRequestPermissions() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final notificationStatus = await Permission.notification.status;

      final canRequestCamera =
          cameraStatus != PermissionStatus.permanentlyDenied;
      final canRequestNotification =
          notificationStatus != PermissionStatus.permanentlyDenied;

      return canRequestCamera && canRequestNotification;
    } catch (e) {
      if (kDebugMode) {
        print('Can request permissions check error: $e');
      }
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get permission status description for UI
  String getPermissionStatusDescription() {
    if (allPermissionsGranted) {
      return '모든 권한이 허용되었습니다';
    } else if (_cameraPermissionGranted && !_notificationPermissionGranted) {
      return '카메라 권한만 허용됨 - 알림 권한 필요';
    } else if (!_cameraPermissionGranted && _notificationPermissionGranted) {
      return '알림 권한만 허용됨 - 카메라 권한 필요';
    } else {
      return '카메라 및 알림 권한이 필요합니다';
    }
  }

  /// Get permission status text
  static String getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '허용됨';
      case PermissionStatus.denied:
        return '거부됨';
      case PermissionStatus.restricted:
        return '제한됨';
      case PermissionStatus.limited:
        return '제한적 허용';
      case PermissionStatus.permanentlyDenied:
        return '영구 거부됨';
      case PermissionStatus.provisional:
        return '임시 허용';
    }
  }
}
