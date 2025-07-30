import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simplified_monitor_service.dart';

/// Simplified monitor screen
class SimplifiedMonitorScreen extends StatefulWidget {
  const SimplifiedMonitorScreen({super.key});

  @override
  State<SimplifiedMonitorScreen> createState() =>
      _SimplifiedMonitorScreenState();
}

class _SimplifiedMonitorScreenState extends State<SimplifiedMonitorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<SimplifiedMonitorService>(
        builder: (context, monitorService, child) {
          return Column(
            children: [
              // Header with alert control
              _buildHeader(monitorService),

              // Customer waiting banner
              _buildCustomerWaitingBanner(monitorService),

              // Content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Connected devices
                      _buildDevicesSection(monitorService),

                      const SizedBox(height: 20),

                      // Settings panel
                      _buildSettingsPanel(monitorService),

                      const SizedBox(height: 20),

                      // Background monitoring panel
                      _buildBackgroundMonitoringPanel(monitorService),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build monitor header with alert toggle
  Widget _buildHeader(SimplifiedMonitorService monitorService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[800],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),

            const SizedBox(width: 8),

            // Title
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '고객 대기 모니터링',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '파란불빛 감지 시스템',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build customer waiting banner
  Widget _buildCustomerWaitingBanner(SimplifiedMonitorService monitorService) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: 80,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  monitorService.isWaitingState
                      ? [Colors.blue[400]!, Colors.blue[600]!]
                      : [Colors.grey[400]!, Colors.grey[600]!],
            ),
            boxShadow: [
              BoxShadow(
                color: (monitorService.isWaitingState
                        ? Colors.blue
                        : Colors.grey)
                    .withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  monitorService.isWaitingState
                      ? Icons.person
                      : Icons.person_outline,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monitorService.isWaitingState
                          ? '🔵 고객이 대기중입니다'
                          : '⚪ 대기인원 없음',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      monitorService.isWaitingState
                          ? '파란불빛이 감지되었습니다'
                          : '현재 대기인원이 없습니다',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build devices section
  Widget _buildDevicesSection(SimplifiedMonitorService monitorService) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '연결된 CCTV 기기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${monitorService.onlineDeviceCount}개 연결',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Device list or empty state
            if (monitorService.connectedDevices.isEmpty)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'CCTV 기기가 연결되지 않았습니다',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Device grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: monitorService.connectedDevices.length,
                itemBuilder: (context, index) {
                  final device = monitorService.connectedDevices[index];
                  return _buildDeviceCard(device);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Build individual device card
  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final isBlueDetected = device['isBlueDetected'] == true;
    final blueIntensity = (device['blueIntensity'] ?? 0.0) as double;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBlueDetected ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBlueDetected ? Colors.blue : Colors.grey[300]!,
          width: isBlueDetected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: device['isOnline'] == true ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device['deviceName'] ?? 'Unknown Device',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isBlueDetected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '대기중',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '파란불:',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: LinearProgressIndicator(
                  value: blueIntensity,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isBlueDetected ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${(blueIntensity * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isBlueDetected ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build settings panel
  Widget _buildSettingsPanel(SimplifiedMonitorService monitorService) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '감지 설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '파란색 인식 감도',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${(monitorService.blueSensitivity * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: monitorService.blueSensitivity,
              onChanged: (value) {
                monitorService.setBlueSensitivity(value);
              },
              min: 0.1,
              max: 1.0,
              divisions: 9,
              activeColor: Colors.blue,
              inactiveColor: Colors.grey[300],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('낮음', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('높음', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build background monitoring panel
  Widget _buildBackgroundMonitoringPanel(
    SimplifiedMonitorService monitorService,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '백그라운드 모니터링',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '앱이 백그라운드에 있을 때도 대기인원 알림을 받을 수 있습니다',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      monitorService.backgroundMonitoringEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color:
                          monitorService.backgroundMonitoringEnabled
                              ? Colors.green
                              : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      monitorService.backgroundMonitoringEnabled
                          ? '백그라운드 모니터링 활성화'
                          : '백그라운드 모니터링 비활성화',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: monitorService.backgroundMonitoringEnabled,
                  onChanged: (value) async {
                    if (value) {
                      await monitorService.startBackgroundMonitoring();
                    } else {
                      monitorService.stopBackgroundMonitoring();
                    }
                  },
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.grey,
                ),
              ],
            ),
            if (monitorService.backgroundMonitoringEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '백그라운드에서 실시간으로 대기인원을 감지하고 알림을 보냅니다',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Firebase 초기화 재시도 함수 (사용되지 않음)
  /*void _retryFirebaseInit() async {
    if (kDebugMode) {
      print('Manually retrying Firebase initialization...');
    }
    
    final localNotificationService = LocalNotificationService();
    
    // 로딩 인디케이터 표시
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Firebase 초기화 재시도 중...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    try {
      final success = await firebaseService.retryInitialization();
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? 'Firebase 초기화 성공! 실시간 동기화 사용 가능합니다.'
                : 'Firebase 초기화 실패. 로컬 알림만 사용합니다.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      if (success) {
        // 성공 시 대기 상태 서비스 연결
        final waitingStateService = context.read<WaitingStateService>();
        firebaseService.setupWaitingStateListener(waitingStateService);
        
        if (kDebugMode) {
          print('Firebase retry successful - service reconnected');
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase 초기화 오류: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      if (kDebugMode) {
        print('Firebase retry failed: $e');
      }
    }
  }*/
}
