import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensitivity_settings.dart';
import '../services/camera_service.dart';

/// CCTV 설정 화면
class CCTVSettingsScreen extends StatefulWidget {
  const CCTVSettingsScreen({super.key});

  @override
  State<CCTVSettingsScreen> createState() => _CCTVSettingsScreenState();
}

class _CCTVSettingsScreenState extends State<CCTVSettingsScreen> {
  late SensitivitySettings _currentSettings;
  late double _customMultiplier;
  late double _customThreshold;
  bool _isCustomMode = false;

  @override
  void initState() {
    super.initState();
    final cameraService = context.read<CameraService>();
    _currentSettings = cameraService.sensitivitySettings;
    _customMultiplier = _currentSettings.multiplier;
    _customThreshold = _currentSettings.threshold;
    _isCustomMode = _currentSettings.levelName == '맞춤';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'CCTV 설정',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 현재 설정 상태
              _buildCurrentStatus(),

              const SizedBox(height: 30),

              // 미리 정의된 감도 레벨
              _buildPresetLevels(),

              const SizedBox(height: 30),

              // 맞춤 설정
              _buildCustomSettings(),

              const SizedBox(height: 30),

              // 테스트 섹션
              _buildTestSection(),

              const SizedBox(height: 20),

              // 도움말
              _buildHelpSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// 현재 설정 상태 표시
  Widget _buildCurrentStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              const Text(
                '현재 감도 설정',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSettings.levelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentSettings.description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '×${_currentSettings.multiplier.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 미리 정의된 감도 레벨
  Widget _buildPresetLevels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '감도 레벨',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ..._buildPresetWidgets(),
      ],
    );
  }

  /// 맞춤 설정
  Widget _buildCustomSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '맞춤 설정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Switch(
              value: _isCustomMode,
              onChanged: (value) {
                setState(() {
                  _isCustomMode = value;
                  if (value) {
                    _currentSettings = SensitivitySettings.custom(
                      multiplier: _customMultiplier,
                      threshold: _customThreshold,
                    );
                  } else {
                    _currentSettings = SensitivitySettings.standard();
                  }
                });
              },
              activeColor: Colors.blue,
            ),
          ],
        ),
        
        if (_isCustomMode) ...[
          const SizedBox(height: 20),
          
          // 감도 배율 슬라이더
          _buildSlider(
            title: '감도 배율',
            subtitle: '파란불빛 강도에 곱해지는 값',
            value: _customMultiplier,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            unit: '×',
            onChanged: (value) {
              setState(() {
                _customMultiplier = value;
                _updateCustomSettings();
              });
            },
          ),
          
          const SizedBox(height: 20),
          
          // 임계값 슬라이더
          _buildSlider(
            title: '감지 임계값',
            subtitle: '대기 감지를 위한 최소 강도',
            value: _customThreshold,
            min: 0.05,
            max: 0.8,
            divisions: 75,
            unit: '',
            onChanged: (value) {
              setState(() {
                _customThreshold = value;
                _updateCustomSettings();
              });
            },
          ),
        ],
      ],
    );
  }

  /// 슬라이더 위젯
  Widget _buildSlider({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required Function(double) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${value.toStringAsFixed(unit == '×' ? 1 : 2)}$unit',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.grey[600],
              thumbColor: Colors.blue,
              overlayColor: Colors.blue.withValues(alpha: 0.1),
              valueIndicatorColor: Colors.blue,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// 테스트 섹션
  Widget _buildTestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                '설정 테스트',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '현재 설정으로 다양한 파란불빛 강도를 테스트해보세요.',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 16),
          
          // 테스트 값들
          ..._buildTestCases(),
        ],
      ),
    );
  }

  /// 도움말 섹션
  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                '도움말',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          const Text(
            '• 감도 배율: 카메라에서 감지된 파란불빛 강도에 곱해지는 값입니다.\n'
            '• 감지 임계값: 이 값 이상일 때 대기인원이 있다고 판단합니다.\n'
            '• 감도를 높이면 약한 파란불도 감지하지만 오탐지가 증가할 수 있습니다.\n'
            '• 환경에 맞게 설정을 조정하여 최적의 감지 성능을 얻으세요.',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build preset widgets
  List<Widget> _buildPresetWidgets() {
    return SensitivitySettings.presets.map((preset) {
      final isSelected = !_isCustomMode && 
          _currentSettings.levelName == preset.levelName;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _selectPreset(preset),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Colors.blue 
                    : Colors.grey[700]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // 선택 표시
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blue : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[500]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected 
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : null,
                ),
                
                const SizedBox(width: 16),
                
                // 설정 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            preset.levelName,
                            style: TextStyle(
                              color: isSelected ? Colors.blue : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, 
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getMultiplierColor(preset.multiplier)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '×${preset.multiplier.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: _getMultiplierColor(preset.multiplier),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.description,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Build test cases for current settings
  List<Widget> _buildTestCases() {
    final testIntensities = [
      {'label': '약한 파란불빛', 'intensity': 0.15, 'color': Colors.lightBlue},
      {'label': '보통 파란불빛', 'intensity': 0.35, 'color': Colors.blue},
      {'label': '강한 파란불빛', 'intensity': 0.65, 'color': Colors.indigo},
    ];

    return testIntensities.map((test) {
      final rawIntensity = test['intensity'] as double;
      final amplifiedIntensity = _currentSettings.applyMultiplier(rawIntensity);
      final isDetected = _currentSettings.isWaitingDetected(amplifiedIntensity);
      final label = test['label'] as String;
      final color = test['color'] as Color;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDetected ? Colors.green : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 색상 표시
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 라벨
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '원본: ${(rawIntensity * 100).toInt()}% → 증폭: ${(amplifiedIntensity * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // 감지 결과
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDetected 
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isDetected ? '감지됨' : '미감지',
                style: TextStyle(
                  color: isDetected ? Colors.green : Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// 미리 정의된 감도 선택
  void _selectPreset(SensitivitySettings preset) {
    setState(() {
      _currentSettings = preset;
      _isCustomMode = false;
    });
  }

  /// 맞춤 설정 업데이트
  void _updateCustomSettings() {
    if (_isCustomMode) {
      _currentSettings = SensitivitySettings.custom(
        multiplier: _customMultiplier,
        threshold: _customThreshold,
      );
    }
  }

  /// 설정 저장
  void _saveSettings() {
    final cameraService = context.read<CameraService>();
    cameraService.updateSensitivitySettings(_currentSettings);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('감도 설정이 저장되었습니다: ${_currentSettings.levelName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Navigator.of(context).pop();
  }

  /// 배율에 따른 색상
  Color _getMultiplierColor(double multiplier) {
    if (multiplier <= 0.7) return Colors.green;
    if (multiplier <= 1.5) return Colors.orange;
    return Colors.red;
  }
}