import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';

/// Simplified permission screen without actual permission requests
class SimplifiedPermissionScreen extends StatefulWidget {
  const SimplifiedPermissionScreen({super.key});

  @override
  State<SimplifiedPermissionScreen> createState() =>
      _SimplifiedPermissionScreenState();
}

class _SimplifiedPermissionScreenState
    extends State<SimplifiedPermissionScreen> {
  bool _permissionsGranted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Permission info
              Expanded(child: _buildPermissionInfo()),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Column(
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

        const SizedBox(height: 24),

        // Title
        const Text(
          'Wait A Minute',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Description
        Text(
          '고객 대기 감지 시스템',
          style: TextStyle(color: Colors.grey[300], fontSize: 16),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  /// Build permission information
  Widget _buildPermissionInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _permissionsGranted ? Icons.check_circle : Icons.info,
          color: _permissionsGranted ? Colors.green : Colors.blue,
          size: 64,
        ),

        const SizedBox(height: 24),

        Text(
          _permissionsGranted ? '모든 권한이 허용되었습니다' : '데모 모드로 실행됩니다',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        Text(
          _permissionsGranted
              ? '앱의 모든 기능을 사용할 수 있습니다.'
              : '실제 카메라와 알림 기능 없이 UI를 체험할 수 있습니다.',
          style: TextStyle(color: Colors.grey[300], fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Continue button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _navigateToModeSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: _permissionsGranted ? Colors.green : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _permissionsGranted ? '시작하기' : '데모 모드로 계속',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (!_permissionsGranted)
          TextButton(
            onPressed: () {
              setState(() {
                _permissionsGranted = true;
              });
            },
            child: const Text(
              '권한 허용 시뮬레이션',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
      ],
    );
  }

  /// Navigate to mode selection screen
  void _navigateToModeSelection() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
    );
  }
}
