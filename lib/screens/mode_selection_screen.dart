import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_mode.dart';
import '../widgets/mode_card.dart';
import '../services/permission_service.dart';
import 'cctv_screen.dart';
import 'realtime_monitor_screen.dart';

/// Mode selection screen - entry point of the app
class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Check current permission status when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermissionService>().checkPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await _showExitDialog(context);
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        body: SafeArea(
          child: Column(
            children: [
              // App Header
              _buildHeader(),

              // Mode Selection Cards
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Consumer<PermissionService>(
                    builder: (context, permissionService, child) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // CCTV Mode Card
                          ModeCard(
                            mode: AppMode.cctv,
                            title: 'CCTV 모드',
                            subtitle:
                                permissionService.cameraPermissionGranted
                                    ? '파란불빛 감지 및 상태 전송'
                                    : '카메라 권한이 필요합니다',
                            icon: Icons.videocam,
                            color:
                                permissionService.cameraPermissionGranted
                                    ? Colors.blue
                                    : Colors.grey,
                            onTap:
                                permissionService.cameraPermissionGranted
                                    ? () => _selectMode(AppMode.cctv)
                                    : () =>
                                        _showCameraPermissionRequiredDialog(),
                            isEnabled:
                                permissionService.cameraPermissionGranted,
                          ),

                          const SizedBox(height: 20),

                          // Monitor Mode Card
                          ModeCard(
                            mode: AppMode.monitor,
                            title: '모니터링 모드',
                            subtitle: '알림 수신 및 설정 관리',
                            icon: Icons.notifications_active,
                            color: Colors.orange,
                            onTap: () => _selectMode(AppMode.monitor),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // App Info
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build app header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // App Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.visibility, color: Colors.white, size: 40),
          ),

          const SizedBox(height: 16),

          // App Title
          const Text(
            'Wait A Minute',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // App Subtitle
          Text(
            '고객 대기 감지 시스템',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build app footer with version info
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '사용할 모드를 선택하세요',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),

          const SizedBox(height: 8),

          Text(
            'Version 1.0.0',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Show camera permission required dialog
  void _showCameraPermissionRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text(
            'CCTV 모드 사용 불가',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'CCTV 모드를 사용하려면 카메라 권한이 필요합니다.\n\n'
            '설정에서 카메라 권한을 허용하거나, 앱을 다시 시작하여 권한을 허용해주세요.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openPermissionSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('설정 열기'),
            ),
          ],
        );
      },
    );
  }

  /// Open permission settings
  void _openPermissionSettings() {
    final permissionService = context.read<PermissionService>();
    permissionService.openSettings().then((_) {
      // Show guidance if context is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('설정에서 카메라 권한을 허용한 후 돌아와주세요'),
            backgroundColor: Colors.blue,
            action: SnackBarAction(
              label: '새로고침',
              textColor: Colors.white,
              onPressed: () {
                permissionService.checkPermissions();
              },
            ),
          ),
        );
      }
    });
  }

  /// Handle mode selection
  void _selectMode(AppMode mode) {
    switch (mode) {
      case AppMode.cctv:
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, _) => const CCTVScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
                child: child,
              );
            },
          ),
        );
        break;

      case AppMode.monitor:
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, _) => const RealtimeMonitorScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
                child: child,
              );
            },
          ),
        );
        break;

      case AppMode.selection:
        // Already on selection screen
        break;
    }
  }

  /// Show exit confirmation dialog
  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.grey[800],
                title: const Text(
                  '앱 종료',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Wait A Minute 앱을 종료하시겠습니까?',
                  style: TextStyle(color: Colors.grey),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      '취소',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      '종료',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }
}
