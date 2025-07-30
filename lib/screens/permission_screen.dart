import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permission_service.dart';
import 'mode_selection_screen.dart';

/// Real permission screen with actual permission handling
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  @override
  void initState() {
    super.initState();
    // Check permissions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermissionService>().checkPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Consumer<PermissionService>(
          builder: (context, permissionService, child) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // App Header
                  _buildHeader(),

                  // Permission Status Section
                  Expanded(child: _buildPermissionSection(permissionService)),

                  // Action Buttons
                  _buildActionButtons(permissionService),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build app header with icon and title
  Widget _buildHeader() {
    return Column(
      children: [
        // App Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.security, color: Colors.white, size: 50),
        ),

        const SizedBox(height: 24),

        // App Title
        const Text(
          'Wait A Minute',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
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
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  /// Build permission status section
  Widget _buildPermissionSection(PermissionService permissionService) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Permission status icon
          _buildPermissionStatusIcon(permissionService),

          const SizedBox(height: 24),

          // Permission status text
          Text(
            permissionService.getPermissionStatusDescription(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Individual permission items
          _buildPermissionItems(permissionService),

          // Error message if any
          if (permissionService.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[300], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      permissionService.errorMessage!,
                      style: TextStyle(color: Colors.red[300], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build permission status icon
  Widget _buildPermissionStatusIcon(PermissionService permissionService) {
    IconData iconData;
    Color iconColor;

    if (permissionService.isLoading) {
      return const CircularProgressIndicator(color: Colors.blue);
    } else if (permissionService.allPermissionsGranted) {
      iconData = Icons.check_circle;
      iconColor = Colors.green;
    } else {
      iconData = Icons.warning_amber;
      iconColor = Colors.orange;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Icon(iconData, color: iconColor, size: 40),
    );
  }

  /// Build individual permission items
  Widget _buildPermissionItems(PermissionService permissionService) {
    return Card(
      color: Colors.grey[800],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Camera permission
            _buildPermissionItem(
              icon: Icons.videocam,
              title: '카메라 권한',
              description: '파란불빛 감지를 위한 카메라 접근',
              isGranted: permissionService.cameraPermissionGranted,
            ),

            const SizedBox(height: 16),

            Divider(color: Colors.grey[600]),

            const SizedBox(height: 16),

            // Notification permission
            _buildPermissionItem(
              icon: Icons.notifications,
              title: '푸시 알림 권한',
              description: '고객 대기 상태 변화 알림 수신',
              isGranted: permissionService.notificationPermissionGranted,
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual permission item
  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    return Row(
      children: [
        // Permission icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                isGranted
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isGranted ? Colors.green : Colors.grey,
            size: 24,
          ),
        ),

        const SizedBox(width: 16),

        // Permission info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),

        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isGranted
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isGranted ? '허용됨' : '필요함',
            style: TextStyle(
              color: isGranted ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(PermissionService permissionService) {
    return Column(
      children: [
        // Main action button
        if (permissionService.allPermissionsGranted)
          // Continue to app
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToModeSelection(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text(
                '앱 시작하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else
          // Request permissions
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed:
                  permissionService.isLoading
                      ? null
                      : () => _requestPermissions(permissionService),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              icon:
                  permissionService.isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.security),
              label: Text(
                permissionService.isLoading ? '권한 요청 중...' : '권한 허용하기',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Skip permissions button (only when permissions not granted)
        if (!permissionService.allPermissionsGranted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _skipPermissionsAndStart(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[400],
                side: BorderSide(color: Colors.grey[600]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.skip_next, color: Colors.grey[400]),
              label: Text(
                '무시하고 시작',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Additional actions row
        Row(
          children: [
            // Settings button (if permissions denied)
            if (!permissionService.allPermissionsGranted &&
                permissionService.errorMessage != null)
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openSettings(permissionService),
                  icon: Icon(Icons.settings, color: Colors.grey[400]),
                  label: Text(
                    '설정 열기',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              ),

            // Refresh button
            if (!permissionService.allPermissionsGranted) ...[
              if (permissionService.errorMessage != null)
                const SizedBox(width: 16),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _refreshPermissions(permissionService),
                  icon: Icon(Icons.refresh, color: Colors.grey[400]),
                  label: Text(
                    '다시 확인',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Request all permissions
  Future<void> _requestPermissions(PermissionService permissionService) async {
    final granted = await permissionService.requestAllPermissions();

    if (granted && mounted) {
      // Show success message and auto-navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 권한이 허용되었습니다!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Auto-navigate after a brief delay
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _navigateToModeSelection();
      }
    }
  }

  /// Open app settings
  Future<void> _openSettings(PermissionService permissionService) async {
    await permissionService.openSettings();

    // Show instruction to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('설정에서 카메라와 푸시 알림 권한을 허용한 후 돌아와주세요'),
          backgroundColor: Colors.blue,
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: () => _refreshPermissions(permissionService),
          ),
        ),
      );
    }
  }

  /// Refresh permission status
  Future<void> _refreshPermissions(PermissionService permissionService) async {
    await permissionService.checkPermissions();

    if (permissionService.allPermissionsGranted && mounted) {
      _navigateToModeSelection();
    }
  }

  /// Skip permissions and start app anyway
  void _skipPermissionsAndStart() {
    // Show warning dialog first
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: const Text(
            '권한 없이 시작',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '일부 기능이 제한될 수 있습니다:\n\n'
            '• 카메라 권한 없음: CCTV 모드 사용 불가\n'
            '• 알림 권한 없음: 대기 알림 수신 불가\n\n'
            '나중에 설정에서 권한을 허용할 수 있습니다.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _navigateToModeSelection(); // Navigate to app
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('계속하기'),
            ),
          ],
        );
      },
    );
  }

  /// Navigate to mode selection screen
  void _navigateToModeSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
    );
  }
}
