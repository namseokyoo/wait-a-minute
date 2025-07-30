import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simplified_cctv_service.dart';

/// Simplified CCTV screen without actual camera
class SimplifiedCCTVScreen extends StatefulWidget {
  const SimplifiedCCTVScreen({super.key});

  @override
  State<SimplifiedCCTVScreen> createState() => _SimplifiedCCTVScreenState();
}

class _SimplifiedCCTVScreenState extends State<SimplifiedCCTVScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<SimplifiedCCTVService>(
        builder: (context, cctvService, child) {
          return Stack(
            children: [
              // Simulated camera preview
              _buildCameraPreview(cctvService),

              // Back button
              Positioned(
                top: 50,
                left: 20,
                child: SafeArea(
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Connection status
              Positioned(
                top: 50,
                right: 20,
                child: SafeArea(child: _buildConnectionStatus(cctvService)),
              ),

              // Blue intensity indicator
              Positioned(
                right: 20,
                top: 120,
                child: _buildBlueIntensityMeter(cctvService),
              ),

              // Control button
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: _buildControlButton(cctvService),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build simulated camera preview
  Widget _buildCameraPreview(SimplifiedCCTVService cctvService) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.grey[800]!,
            // Add blue tint based on detected intensity
            cctvService.isMonitoring
                ? Colors.blue.withValues(alpha: cctvService.blueIntensity * 0.3)
                : Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              cctvService.isMonitoring ? Icons.videocam : Icons.videocam_off,
              size: 80,
              color: cctvService.isMonitoring ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              cctvService.isMonitoring ? 'CCTV 모니터링 중' : 'CCTV 대기 중',
              style: TextStyle(
                color: cctvService.isMonitoring ? Colors.white : Colors.grey,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cctvService.isMonitoring) ...[
              const SizedBox(height: 8),
              Text(
                '파란불 강도: ${(cctvService.blueIntensity * 100).toInt()}%',
                style: TextStyle(
                  color:
                      cctvService.blueIntensity > 0.5
                          ? Colors.blue
                          : Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build connection status indicator
  Widget _buildConnectionStatus(SimplifiedCCTVService cctvService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cctvService.isOnline ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cctvService.isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            cctvService.isOnline ? '연결됨' : '연결끊김',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build blue intensity meter
  Widget _buildBlueIntensityMeter(SimplifiedCCTVService cctvService) {
    return Container(
      width: 60,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white30, width: 2),
      ),
      child: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x4D4CAF50), // Green
                    Color(0x4DFFEB3B), // Yellow
                    Color(0x4DFF9800), // Orange
                    Color(0x4DF44336), // Red
                  ],
                ),
              ),
            ),
          ),

          // Intensity fill
          Positioned(
            bottom: 4,
            left: 4,
            right: 4,
            child: Container(
              height: (150 - 8) * cctvService.blueIntensity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors:
                      cctvService.blueIntensity > 0.5
                          ? [Colors.blue, Colors.lightBlue]
                          : [Colors.grey, Colors.grey[400]!],
                ),
              ),
            ),
          ),

          // Value label
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Text(
              '${(cctvService.blueIntensity * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build control button
  Widget _buildControlButton(SimplifiedCCTVService cctvService) {
    return Center(
      child: FloatingActionButton.extended(
        onPressed: () {
          if (cctvService.isMonitoring) {
            _showStopDialog(cctvService);
          } else {
            cctvService.startMonitoring();
          }
        },
        backgroundColor: cctvService.isMonitoring ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        icon: Icon(
          cctvService.isMonitoring ? Icons.stop : Icons.play_arrow,
          size: 32,
        ),
        label: Text(
          cctvService.isMonitoring ? '모니터링 중지' : '모니터링 시작',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Show stop confirmation dialog
  void _showStopDialog(SimplifiedCCTVService cctvService) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('모니터링 중지'),
            content: const Text('파란불빛 감지를 중지하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  cctvService.stopMonitoring();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('중지'),
              ),
            ],
          ),
    );
  }
}
