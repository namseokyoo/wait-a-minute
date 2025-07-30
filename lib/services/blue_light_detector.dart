import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../models/sensitivity_settings.dart';

/// Blue light detection algorithm for analyzing camera frames
class BlueLightDetector {
  // Detection parameters
  static const int _minConsistentFrames = 3; // Frames needed for state change
  static const int _frameHistorySize =
      10; // Number of frames to keep for analysis

  // State tracking
  final List<double> _frameHistory = [];
  int _consistentFrameCount = 0;
  bool _currentWaitingState = false;
  double _baselineBlueLevel = 0.0;
  bool _baselineCalibrated = false;
  int _calibrationFrameCount = 0;

  // Sensitivity settings
  SensitivitySettings _sensitivitySettings = SensitivitySettings.standard();

  // Getters
  bool get isWaitingState => _currentWaitingState;
  double get currentBlueIntensity =>
      _frameHistory.isNotEmpty ? _frameHistory.last : 0.0;
  bool get isCalibrated => _baselineCalibrated;
  double get baselineBlueLevel => _baselineBlueLevel;
  SensitivitySettings get sensitivitySettings => _sensitivitySettings;

  /// Update sensitivity settings
  void updateSensitivitySettings(SensitivitySettings settings) {
    _sensitivitySettings = settings;
    if (kDebugMode) {
      print('BlueLightDetector: 감도 설정 업데이트 - ${settings.levelName} (×${settings.multiplier})');
    }
  }

  /// Analyze camera frame and detect blue light intensity
  Future<DetectionResult> analyzeFrame(CameraImage image) async {
    try {
      // Convert camera image to analyzable format and calculate blue intensity
      final blueIntensity = await _calculateBlueIntensity(image);

      // Add to frame history
      _frameHistory.add(blueIntensity);
      if (_frameHistory.length > _frameHistorySize) {
        _frameHistory.removeAt(0);
      }

      // Calibrate baseline if not done
      if (!_baselineCalibrated) {
        _calibrateBaseline(blueIntensity);
      }

      // Apply sensitivity multiplier
      final amplifiedIntensity = _sensitivitySettings.applyMultiplier(blueIntensity);
      
      // Determine waiting state using amplified intensity
      final previousState = _currentWaitingState;
      final newState = _determineWaitingState(amplifiedIntensity);
      final stateChanged = previousState != newState;

      return DetectionResult(
        blueIntensity: blueIntensity,
        amplifiedIntensity: amplifiedIntensity,
        normalizedIntensity: _normalizeIntensity(amplifiedIntensity),
        isWaitingState: newState,
        stateChanged: stateChanged,
        confidence: _calculateConfidence(),
        baselineLevel: _baselineBlueLevel,
        sensitivityMultiplier: _sensitivitySettings.multiplier,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Blue light detection error: $e');
      }
      return DetectionResult.error(e.toString());
    }
  }

  /// Calculate blue light intensity from camera image
  Future<double> _calculateBlueIntensity(CameraImage image) async {
    if (image.format.group != ImageFormatGroup.yuv420) {
      throw Exception('Unsupported image format: ${image.format.group}');
    }

    // Get Y, U, V planes from YUV420 format
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final width = image.width;
    final height = image.height;

    // Sample pixels for analysis (use every 4th pixel for performance)
    final sampleStep = 4;
    double totalBlueIntensity = 0.0;
    int sampleCount = 0;

    for (int row = 0; row < height; row += sampleStep) {
      for (int col = 0; col < width; col += sampleStep) {
        final yIndex = row * yPlane.bytesPerRow + col;
        final uvIndex = (row ~/ 2) * uPlane.bytesPerRow + (col ~/ 2);

        if (yIndex < yBytes.length &&
            uvIndex < uBytes.length &&
            uvIndex < vBytes.length) {
          // Get YUV values
          final y = yBytes[yIndex];
          final u = uBytes[uvIndex];
          final v = vBytes[uvIndex];

          // Convert YUV to RGB
          final rgb = _yuvToRgb(y, u, v);

          // Calculate blue intensity relative to other colors
          final blueIntensity = _calculatePixelBlueIntensity(rgb);
          totalBlueIntensity += blueIntensity;
          sampleCount++;
        }
      }
    }

    return sampleCount > 0 ? totalBlueIntensity / sampleCount : 0.0;
  }

  /// Convert YUV pixel to RGB
  List<int> _yuvToRgb(int y, int u, int v) {
    // YUV to RGB conversion formulas
    final yAdjusted = y - 16;
    final uAdjusted = u - 128;
    final vAdjusted = v - 128;

    int r = ((298 * yAdjusted + 409 * vAdjusted + 128) >> 8).clamp(0, 255);
    int g = ((298 * yAdjusted - 100 * uAdjusted - 208 * vAdjusted + 128) >> 8)
        .clamp(0, 255);
    int b = ((298 * yAdjusted + 516 * uAdjusted + 128) >> 8).clamp(0, 255);

    return [r, g, b];
  }

  /// Calculate blue intensity for a single pixel
  double _calculatePixelBlueIntensity(List<int> rgb) {
    final r = rgb[0] / 255.0;
    final g = rgb[1] / 255.0;
    final b = rgb[2] / 255.0;

    // Calculate blue dominance
    // Blue intensity is high when blue channel is significantly higher than red and green
    final blueDominance = b - ((r + g) / 2);

    // Also consider overall brightness to avoid false positives in dark areas
    final brightness = (r + g + b) / 3;
    final brightnessWeight = brightness.clamp(0.3, 1.0);

    return (blueDominance * brightnessWeight).clamp(0.0, 1.0);
  }

  /// Calibrate baseline blue level (first few frames)
  void _calibrateBaseline(double blueIntensity) {
    _calibrationFrameCount++;

    if (_calibrationFrameCount <= 30) {
      // Average first 30 frames for baseline
      _baselineBlueLevel =
          ((_baselineBlueLevel * (_calibrationFrameCount - 1)) +
              blueIntensity) /
          _calibrationFrameCount;
    } else {
      _baselineCalibrated = true;
      if (kDebugMode) {
        print('Baseline calibrated: $_baselineBlueLevel');
      }
    }
  }

  /// Determine waiting state based on amplified blue intensity
  bool _determineWaitingState(double amplifiedIntensity) {
    if (!_baselineCalibrated) return false;

    // Use sensitivity settings to determine if waiting state is detected
    final isBlueDetected = _sensitivitySettings.isWaitingDetected(amplifiedIntensity);

    // Use consistent frame counting to avoid flickering
    if (isBlueDetected && !_currentWaitingState) {
      _consistentFrameCount++;
      if (_consistentFrameCount >= _minConsistentFrames) {
        _currentWaitingState = true;
        _consistentFrameCount = 0;
      }
    } else if (!isBlueDetected && _currentWaitingState) {
      _consistentFrameCount++;
      if (_consistentFrameCount >= _minConsistentFrames) {
        _currentWaitingState = false;
        _consistentFrameCount = 0;
      }
    } else {
      _consistentFrameCount = 0;
    }

    return _currentWaitingState;
  }

  /// Normalize intensity for display (0.0 to 1.0)
  double _normalizeIntensity(double rawIntensity) {
    if (!_baselineCalibrated) return rawIntensity;

    final relativeIntensity = (rawIntensity - _baselineBlueLevel).clamp(
      0.0,
      1.0,
    );
    return relativeIntensity;
  }

  /// Calculate confidence level of detection
  double _calculateConfidence() {
    if (_frameHistory.length < 3) return 0.5;

    // Calculate consistency of recent frames
    final recentFrames = _frameHistory.take(3).toList();
    final average = recentFrames.reduce((a, b) => a + b) / recentFrames.length;
    final variance =
        recentFrames
            .map((x) => (x - average) * (x - average))
            .reduce((a, b) => a + b) /
        recentFrames.length;

    // High confidence when variance is low (consistent readings)
    final consistency = (1.0 - variance.clamp(0.0, 1.0));

    // Also factor in how different from baseline
    final significance =
        _baselineCalibrated
            ? ((currentBlueIntensity - _baselineBlueLevel).abs() * 2).clamp(
              0.0,
              1.0,
            )
            : 0.5;

    return (consistency * 0.7 + significance * 0.3).clamp(0.0, 1.0);
  }

  /// Reset detector state
  void reset() {
    _frameHistory.clear();
    _consistentFrameCount = 0;
    _currentWaitingState = false;
    _baselineBlueLevel = 0.0;
    _baselineCalibrated = false;
    _calibrationFrameCount = 0;
  }

  /// Get detection statistics
  Map<String, dynamic> getStatistics() {
    return {
      'frameHistory': List.from(_frameHistory),
      'consistentFrameCount': _consistentFrameCount,
      'currentWaitingState': _currentWaitingState,
      'baselineBlueLevel': _baselineBlueLevel,
      'baselineCalibrated': _baselineCalibrated,
      'calibrationFrameCount': _calibrationFrameCount,
      'confidence': _calculateConfidence(),
    };
  }
}

/// Result of blue light detection analysis
class DetectionResult {
  final double blueIntensity;
  final double amplifiedIntensity;
  final double normalizedIntensity;
  final bool isWaitingState;
  final bool stateChanged;
  final double confidence;
  final double baselineLevel;
  final double sensitivityMultiplier;
  final DateTime timestamp;
  final String? error;

  const DetectionResult({
    required this.blueIntensity,
    required this.amplifiedIntensity,
    required this.normalizedIntensity,
    required this.isWaitingState,
    required this.stateChanged,
    required this.confidence,
    required this.baselineLevel,
    required this.sensitivityMultiplier,
    required this.timestamp,
    this.error,
  });

  DetectionResult.error(String errorMessage)
    : blueIntensity = 0.0,
      amplifiedIntensity = 0.0,
      normalizedIntensity = 0.0,
      isWaitingState = false,
      stateChanged = false,
      confidence = 0.0,
      baselineLevel = 0.0,
      sensitivityMultiplier = 1.0,
      timestamp = DateTime.now(),
      error = errorMessage;

  bool get hasError => error != null;

  String getStateDescription() {
    if (hasError) return '오류 발생';
    if (isWaitingState) return '대기인원 있음';
    return '대기인원 없음';
  }

  @override
  String toString() {
    return 'DetectionResult(intensity: ${blueIntensity.toStringAsFixed(3)}, '
        'amplified: ${amplifiedIntensity.toStringAsFixed(3)}, '
        'multiplier: ×${sensitivityMultiplier.toStringAsFixed(1)}, '
        'waiting: $isWaitingState, changed: $stateChanged, '
        'confidence: ${confidence.toStringAsFixed(2)})';
  }
}
