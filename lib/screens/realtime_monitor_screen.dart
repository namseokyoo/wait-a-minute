import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/realtime_monitor_service.dart';
import '../services/local_notification_service.dart';
import '../models/cctv_device_status.dart';

/// 실시간 데이터베이스를 사용하는 모니터 화면
class RealtimeMonitorScreen extends StatefulWidget {
  const RealtimeMonitorScreen({super.key});

  @override
  State<RealtimeMonitorScreen> createState() => _RealtimeMonitorScreenState();
}

class _RealtimeMonitorScreenState extends State<RealtimeMonitorScreen>
    with WidgetsBindingObserver {
  late RealtimeMonitorService _monitorService;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _monitorService = RealtimeMonitorService();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    // 알림 서비스 초기화 (백그라운드에서)
    LocalNotificationService().initialize().catchError((e) {
      if (kDebugMode) {
        print('알림 서비스 초기화 실패: $e');
      }
      return false; // catchError handler must return a value
    });

    // 실시간 모니터 서비스 초기화
    final success = await _monitorService.initialize();

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('실시간 DB 연결 실패: ${_monitorService.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: '재시도',
              textColor: Colors.white,
              onPressed: _initializeServices,
            ),
          ),
        );
      } else {
        // 연결 성공 시 알림 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 실시간 모니터링 시작! 대기 발생 시 알림을 받을 수 있습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 모니터 서비스 정리 후 뒤로가기
  Future<void> _cleanupAndExit() async {
    try {
      if (kDebugMode) {
        print('RealtimeMonitorScreen: 정리 작업 시작');
      }

      // 사용자에게 정리 중임을 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모니터링을 종료하고 있습니다...'),
          duration: Duration(seconds: 1),
        ),
      );

      // 모니터 서비스에서 Firebase 정리 작업 수행
      _monitorService.dispose();

      // 짧은 대기 시간으로 정리 작업 완료를 보장
      await Future.delayed(const Duration(milliseconds: 500));

      if (kDebugMode) {
        print('RealtimeMonitorScreen: 정리 작업 완료');
      }

      // 이제 안전하게 뒤로가기
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (kDebugMode) {
        print('RealtimeMonitorScreen: 정리 작업 중 오류: $e');
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
        print('RealtimeMonitorScreen: 앱 라이프사이클 변화 감지 ($state) - 정리 작업 수행');
      }

      // Firebase에서 모니터 디바이스 정리 (백그라운드에서 수행)
      _monitorService.dispose();
    }
  }

  @override
  void dispose() {
    // 앱 라이프사이클 관찰자 제거
    WidgetsBinding.instance.removeObserver(this);

    // dispose에서는 추가 정리 작업 없이 기본 정리만 수행
    // 실제 Firebase 정리는 _cleanupAndExit에서 처리됨
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 모니터 서비스 정리 후 뒤로가기
        await _cleanupAndExit();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: _isInitializing ? _buildLoadingScreen() : _buildMainContent(),
      ),
    );
  }

  /// 로딩 화면
  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            '실시간 DB 연결 중...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 메인 컨텐츠
  Widget _buildMainContent() {
    return ChangeNotifierProvider.value(
      value: _monitorService,
      child: Consumer<RealtimeMonitorService>(
        builder: (context, service, child) {
          return Column(
            children: [
              // Header
              _buildHeader(service),

              // 전체 대기 상태 배너
              _buildWaitingStatusBanner(service),

              // 메인 컨텐츠
              Expanded(
                child:
                    service.errorMessage != null
                        ? _buildErrorContent(service)
                        : _buildSuccessContent(service),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 헤더 빌드
  Widget _buildHeader(RealtimeMonitorService service) {
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
            // 뒤로가기 버튼
            IconButton(
              onPressed: _cleanupAndExit,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),

            const SizedBox(width: 8),

            // 제목
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '실시간 CCTV 모니터링',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '고객 대기 감지 시스템',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // 새로고침 버튼
            IconButton(
              onPressed: () => service.refresh(),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            ),

            // 디버그 모드에서만 테스트 버튼들 표시
            if (kDebugMode) ...[
              IconButton(
                onPressed: () => service.createTestData(),
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.white70,
                  size: 24,
                ),
                tooltip: '테스트 데이터 생성',
              ),
              IconButton(
                onPressed: () => LocalNotificationService().testNotification(),
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white70,
                  size: 24,
                ),
                tooltip: '테스트 알림',
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 전체 대기 상태 배너
  Widget _buildWaitingStatusBanner(RealtimeMonitorService service) {
    final hasWaiting = service.hasWaitingCustomers;
    final waitingCount = service.waitingDeviceCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              hasWaiting
                  ? [Colors.orange[400]!, Colors.orange[600]!]
                  : [Colors.green[400]!, Colors.green[600]!],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasWaiting ? Icons.warning : Icons.check_circle,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasWaiting ? '🚨 고객 대기 중 ($waitingCount개 위치)' : '✅ 모든 위치 정상',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                hasWaiting ? '즉시 확인이 필요합니다' : '현재 대기인원이 없습니다',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 오류 컨텐츠
  Widget _buildErrorContent(RealtimeMonitorService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              '연결 오류',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.errorMessage ?? '알 수 없는 오류',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 연결'),
            ),
          ],
        ),
      ),
    );
  }

  /// 성공 컨텐츠
  Widget _buildSuccessContent(RealtimeMonitorService service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 통계 카드들
          _buildStatisticsCards(service),

          const SizedBox(height: 20),

          // 디바이스 목록
          _buildDevicesSection(service),

          const SizedBox(height: 20),

          // 파란불 세기 정보
          _buildBlueIntensitySection(service),
        ],
      ),
    );
  }

  /// 통계 카드들
  Widget _buildStatisticsCards(RealtimeMonitorService service) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '전체 기기',
            '${service.deviceCount}개',
            Icons.devices,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '온라인',
            '${service.onlineDeviceCount}개',
            Icons.online_prediction,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '모니터링',
            '${service.monitoringDeviceCount}개',
            Icons.videocam,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '대기 감지',
            '${service.waitingDeviceCount}개',
            Icons.person,
            Colors.red,
          ),
        ),
      ],
    );
  }

  /// 통계 카드
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// 디바이스 섹션
  Widget _buildDevicesSection(RealtimeMonitorService service) {
    final devices = service.devices;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '연결된 CCTV 기기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${devices.length}대',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (devices.isEmpty)
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  return _buildDeviceCard(devices[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 디바이스 카드
  Widget _buildDeviceCard(CCTVDeviceStatus device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: device.isWaitingDetected ? Colors.orange[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              device.isWaitingDetected
                  ? Colors.orange
                  : (device.isOnline ? Colors.green : Colors.red),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 디바이스 정보 헤더
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: device.isOnline ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      device.location,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (device.isWaitingDetected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    '고객 대기중',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // 상태 정보
          Row(
            children: [
              Expanded(child: _buildDeviceInfo('작동 상태', device.statusSummary)),
              Expanded(
                child: _buildDeviceInfo(
                  '연결 품질',
                  device.connectionQualityStatus,
                ),
              ),
              Expanded(child: _buildDeviceInfo('배터리', device.batteryStatus)),
            ],
          ),

          const SizedBox(height: 12),

          // 파란불 세기
          Row(
            children: [
              const Text(
                '파란불 세기: ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: device.blueIntensity,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    device.isWaitingDetected ? Colors.orange : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(device.blueIntensity * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: device.isWaitingDetected ? Colors.orange : Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 디바이스 정보 아이템
  Widget _buildDeviceInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// 파란불 세기 정보 섹션
  Widget _buildBlueIntensitySection(RealtimeMonitorService service) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '파란불 세기 분석',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildIntensityInfo(
                    '평균 세기',
                    '${(service.averageBlueIntensity * 100).toInt()}%',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildIntensityInfo(
                    '최고 세기',
                    '${(service.maxBlueIntensity * 100).toInt()}%',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 세기 정보 아이템
  Widget _buildIntensityInfo(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
