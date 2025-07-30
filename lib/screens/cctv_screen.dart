import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import 'cctv_settings_screen.dart';

/// CCTV screen with real camera functionality and blue light detection
class CCTVScreen extends StatefulWidget {
  const CCTVScreen({super.key});

  @override
  State<CCTVScreen> createState() => _CCTVScreenState();
}

class _CCTVScreenState extends State<CCTVScreen> with WidgetsBindingObserver {
  late final CameraService _cameraService;

  @override
  void initState() {
    super.initState();
    _cameraService = context.read<CameraService>();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initializeCamera();
  }

  /// CCTV 서비스 정리 후 뒤로가기
  Future<void> _cleanupAndExit() async {
    try {
      if (kDebugMode) {
        print('CCTVScreen: 정리 작업 시작');
      }

      // 사용자에게 정리 중임을 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CCTV를 종료하고 있습니다...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 카메라 서비스에서 Firebase 정리 작업 수행
      await _cameraService.removeDeviceFromFirebase();

      // 짧은 대기 시간으로 정리 작업 완료를 보장
      await Future.delayed(const Duration(milliseconds: 500));

      if (kDebugMode) {
        print('CCTVScreen: 정리 작업 완료');
      }

      // 이제 안전하게 뒤로가기
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (kDebugMode) {
        print('CCTVScreen: 정리 작업 중 오류: $e');
      }
      // 오류가 있어도 뒤로가기는 수행
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 앱이 종료되거나 백그라운드로 이동할 때 정리 작업 수행
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      if (kDebugMode) {
        print('CCTVScreen: 앱 라이프사이클 변화 감지 ($state) - 정리 작업 수행');
      }
      
      // Firebase에서 디바이스 정리 (백그라운드에서 수행)
      _cameraService.removeDeviceFromFirebase().catchError((e) {
        if (kDebugMode) {
          print('CCTVScreen: 백그라운드 Firebase 정리 실패 (무시됨): $e');
        }
      });
    }
  }

  @override
  void dispose() {
    // 앱 라이프사이클 관찰자 제거
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // CCTV 서비스 정리 후 뒤로가기
        await _cleanupAndExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CameraService>(
          builder: (context, cameraService, child) {
            return Stack(
              children: [
                // Camera Preview
                _buildCameraPreview(cameraService),

                // Blue Light Intensity Overlay (hidden in privacy mode)
                if (!cameraService.isPrivacyMode)
                  _buildBlueIntensityOverlay(cameraService),

                // Privacy Mode Overlay
                if (cameraService.isPrivacyMode)
                  _buildPrivacyOverlay(cameraService),

                // Top Controls
                _buildTopControls(cameraService),

                // Bottom Controls
                _buildBottomControls(cameraService),

                // Error Message
                if (cameraService.errorMessage != null)
                  _buildErrorMessage(cameraService),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build camera preview widget
  Widget _buildCameraPreview(CameraService cameraService) {
    // Show black screen in privacy mode
    if (cameraService.isPrivacyMode) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
      );
    }

    if (cameraService.isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              '카메라 초기화 중...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (!cameraService.isInitialized || cameraService.controller == null) {
      return Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[900],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                '카메라를 사용할 수 없습니다',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _initializeCamera(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    // Show camera preview
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: cameraService.controller!.value.previewSize?.height ?? 0,
          height: cameraService.controller!.value.previewSize?.width ?? 0,
          child: CameraPreview(cameraService.controller!),
        ),
      ),
    );
  }

  /// Build blue light intensity overlay
  Widget _buildBlueIntensityOverlay(CameraService cameraService) {
    if (!cameraService.isMonitoring) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getBlueIntensityColor(cameraService.blueIntensity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '파란불빛',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${(cameraService.blueIntensity * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cameraService.getBlueIntensityDescription(),
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
            const SizedBox(height: 8),
            // Show calibration progress or intensity bar
            _buildIntensityProgressBar(cameraService),
          ],
        ),
      ),
    );
  }

  /// Build privacy mode overlay
  Widget _buildPrivacyOverlay(CameraService cameraService) {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.visibility_off,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 20),
              Text(
                '화면 가리기 모드',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '모니터링은 백그라운드에서 계속 진행됩니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '화면을 다시 보려면 화면 보기 버튼을 누르세요',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build top controls
  Widget _buildTopControls(CameraService cameraService) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Back button
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _cleanupAndExit,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

              const Spacer(),

              // Device info
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cameraService.isMonitoring
                          ? Icons.fiber_manual_record
                          : Icons.pause,
                      color:
                          cameraService.isMonitoring ? Colors.red : Colors.grey,
                      size: 12,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cameraService.getStatusDescription(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Camera switch button (if multiple cameras available)
              if (cameraService.isInitialized)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => cameraService.switchCamera(),
                    icon: const Icon(
                      Icons.flip_camera_android,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build bottom controls
  Widget _buildBottomControls(CameraService cameraService) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Battery indicator
              _buildBatteryIndicator(cameraService),

              // Start/Stop monitoring button
              _buildMonitoringButton(cameraService),

              // Privacy mode toggle button (only when monitoring)
              if (cameraService.isMonitoring)
                _buildPrivacyToggleButton(cameraService),

              // Settings button
              _buildSettingsButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build battery indicator
  Widget _buildBatteryIndicator(CameraService cameraService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.battery_full,
            color: _getBatteryColor(cameraService.batteryLevel),
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '${(cameraService.batteryLevel * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build monitoring button
  Widget _buildMonitoringButton(CameraService cameraService) {
    if (!cameraService.isInitialized) {
      return FloatingActionButton.extended(
        onPressed: () => _initializeCamera(),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.refresh),
        label: const Text('카메라 초기화'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => _toggleMonitoring(cameraService),
      backgroundColor: cameraService.isMonitoring ? Colors.red : Colors.green,
      foregroundColor: Colors.white,
      icon: Icon(
        cameraService.isMonitoring ? Icons.stop : Icons.play_arrow,
        size: 28,
      ),
      label: Text(
        cameraService.isMonitoring ? '모니터링 중지' : '모니터링 시작',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Build privacy mode toggle button
  Widget _buildPrivacyToggleButton(CameraService cameraService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => cameraService.togglePrivacyMode(),
        icon: Icon(
          cameraService.isPrivacyMode ? Icons.visibility : Icons.visibility_off,
          color: cameraService.isPrivacyMode ? Colors.orange : Colors.white,
          size: 24,
        ),
        tooltip: cameraService.isPrivacyMode ? '화면 보기' : '화면 가리기',
      ),
    );
  }

  /// Build settings button
  Widget _buildSettingsButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CCTVSettingsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.settings, color: Colors.white, size: 24),
      ),
    );
  }

  /// Build error message overlay
  Widget _buildErrorMessage(CameraService cameraService) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cameraService.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              IconButton(
                onPressed: () => cameraService.clearError(),
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle monitoring state
  Future<void> _toggleMonitoring(CameraService cameraService) async {
    if (cameraService.isMonitoring) {
      await cameraService.stopMonitoring();
    } else {
      await cameraService.startMonitoring();
    }
  }

  /// Get color for blue intensity indicator
  Color _getBlueIntensityColor(double intensity) {
    if (intensity < 0.2) return Colors.grey;
    if (intensity < 0.5) return Colors.lightBlue;
    if (intensity < 0.8) return Colors.blue;
    return Colors.indigo;
  }

  /// Build intensity or calibration progress bar
  Widget _buildIntensityProgressBar(CameraService cameraService) {
    // Check if detector is available
    final detector = cameraService.detector;

    if (!detector.isCalibrated) {
      // Show calibration progress
      final stats = detector.getStatistics();
      final calibrationProgress = (stats['calibrationFrameCount'] as int).clamp(
        0,
        30,
      );
      final progressRatio = calibrationProgress / 30.0;

      return Column(
        children: [
          Container(
            width: 100,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '환경 분석 중',
            style: TextStyle(
              color: Colors.orange[300],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      // Show blue intensity bar
      return Container(
        width: 100,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: cameraService.blueIntensity,
          child: Container(
            decoration: BoxDecoration(
              color: _getBlueIntensityColor(cameraService.blueIntensity),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
  }

  /// Get color for battery indicator
  Color _getBatteryColor(double batteryLevel) {
    if (batteryLevel > 0.5) return Colors.green;
    if (batteryLevel > 0.2) return Colors.orange;
    return Colors.red;
  }
}
