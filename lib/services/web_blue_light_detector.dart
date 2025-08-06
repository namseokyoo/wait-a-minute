import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/sensitivity_settings.dart';

// Conditional import for web platform only
import 'dart:html' as html;

/// Web-specific blue light detection using real camera data via MediaStream API
class WebBlueLightDetector {
  // Detection parameters
  static const int _minConsistentFrames = 3;
  static const int _frameHistorySize = 10;

  // State tracking
  final List<double> _frameHistory = [];
  int _consistentFrameCount = 0;
  bool _currentWaitingState = false;
  double _baselineBlueLevel = 0.0;
  bool _baselineCalibrated = false;
  int _calibrationFrameCount = 0;

  // Sensitivity settings
  SensitivitySettings _sensitivitySettings = SensitivitySettings.standard();

  // Web camera components
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  html.CanvasRenderingContext2D? _canvasContext;
  html.MediaStream? _mediaStream;
  bool _isInitialized = false;

  // Getters
  bool get isWaitingState => _currentWaitingState;
  double get currentBlueIntensity =>
      _frameHistory.isNotEmpty ? _frameHistory.last : 0.0;
  bool get isCalibrated => _baselineCalibrated;
  double get baselineBlueLevel => _baselineBlueLevel;
  SensitivitySettings get sensitivitySettings => _sensitivitySettings;
  bool get isInitialized => _isInitialized;

  /// Initialize web camera access
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (kDebugMode) {
        print('WebBlueLightDetector: 카메라 초기화 시작');
      }

      // Create video element
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.display = 'none'; // Hide video element

      // Create canvas for frame capture
      _canvasElement = html.CanvasElement()
        ..width = 320
        ..height = 240
        ..style.display = 'none'; // Hide canvas element

      _canvasContext = _canvasElement!.getContext('2d') as html.CanvasRenderingContext2D?;

      // Add elements to DOM (required for MediaStream)
      html.document.body!.append(_videoElement!);
      html.document.body!.append(_canvasElement!);

      // Request camera access
      final constraints = {
        'video': {
          'width': {'ideal': 320},
          'height': {'ideal': 240},
          'facingMode': 'environment', // Prefer back camera
        },
        'audio': false,
      };

      _mediaStream = await html.window.navigator.mediaDevices!
          .getUserMedia(constraints);

      _videoElement!.srcObject = _mediaStream;

      // Wait for video to be ready
      await _videoElement!.onLoadedMetadata.first;

      _isInitialized = true;

      if (kDebugMode) {
        print('WebBlueLightDetector: 카메라 초기화 완료');
        print('비디오 크기: ${_videoElement!.videoWidth}x${_videoElement!.videoHeight}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('WebBlueLightDetector: 카메라 초기화 실패 - $e');
      }
      return false;
    }
  }

  /// Update sensitivity settings
  void updateSensitivitySettings(SensitivitySettings settings) {
    _sensitivitySettings = settings;
    if (kDebugMode) {
      print(
        'WebBlueLightDetector: 감도 설정 업데이트 - ${settings.levelName} (×${settings.multiplier})',
      );
    }
  }

  /// Analyze current camera frame for blue light detection
  Future<WebDetectionResult> analyzeFrame() async {
    if (!_isInitialized || _videoElement == null || _canvasContext == null) {
      return WebDetectionResult.error('카메라가 초기화되지 않음');
    }

    try {
      // Capture current frame from video to canvas
      _canvasContext!.drawImage(
        _videoElement!,
        0, 0,
      );

      // Get image data from canvas
      final imageData = _canvasContext!.getImageData(
        0, 0,
        _canvasElement!.width!,
        _canvasElement!.height!,
      );

      // Calculate blue light intensity from RGB data
      final blueIntensity = _calculateBlueIntensityFromRGB(imageData.data);

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
      final amplifiedIntensity = _sensitivitySettings.applyMultiplier(
        blueIntensity,
      );

      // Determine waiting state using amplified intensity
      final previousState = _currentWaitingState;
      final newState = _determineWaitingState(amplifiedIntensity);
      final stateChanged = previousState != newState;

      return WebDetectionResult(
        blueIntensity: blueIntensity,
        amplifiedIntensity: amplifiedIntensity,
        normalizedIntensity: _normalizeIntensity(amplifiedIntensity),
        isWaitingState: newState,
        stateChanged: stateChanged,
        confidence: _calculateConfidence(),
        baselineLevel: _baselineBlueLevel,
        sensitivityMultiplier: _sensitivitySettings.multiplier,
        timestamp: DateTime.now(),
        isSimulated: false, // Now using real camera data!
      );
    } catch (e) {
      if (kDebugMode) {
        print('WebBlueLightDetector: 프레임 분석 오류 - $e');
      }
      return WebDetectionResult.error(e.toString());
    }
  }

  /// Calculate blue light intensity from RGB image data
  double _calculateBlueIntensityFromRGB(Uint8ClampedList rgbaData) {
    double totalBlueIntensity = 0.0;
    int sampleCount = 0;

    // Sample every 4th pixel for performance (RGBA format: 4 bytes per pixel)
    const sampleStep = 16; // Skip 4 pixels each time
    
    for (int i = 0; i < rgbaData.length; i += sampleStep) {
      if (i + 3 < rgbaData.length) {
        final r = rgbaData[i];     // Red
        final g = rgbaData[i + 1]; // Green  
        final b = rgbaData[i + 2]; // Blue
        final a = rgbaData[i + 3]; // Alpha
        
        // Skip transparent pixels
        if (a < 128) continue;

        // Calculate blue intensity relative to other colors
        final blueIntensity = _calculatePixelBlueIntensity([r, g, b]);
        totalBlueIntensity += blueIntensity;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalBlueIntensity / sampleCount : 0.0;
  }

  /// Calculate blue intensity for a single RGB pixel
  double _calculatePixelBlueIntensity(List<int> rgb) {
    final r = rgb[0];
    final g = rgb[1];
    final b = rgb[2];

    // Avoid division by zero
    final totalIntensity = r + g + b;
    if (totalIntensity == 0) return 0.0;

    // Calculate blue ratio
    final blueRatio = b / totalIntensity;

    // Enhanced blue detection: look for pixels where blue is dominant
    final blueAdvantage = (b - max(r, g)) / 255.0;
    
    // Combine ratio and advantage for better detection
    final combinedIntensity = (blueRatio * 0.7 + max(0.0, blueAdvantage) * 0.3);
    
    // Apply brightness weighting (brighter blues are more significant)
    final brightness = totalIntensity / (3 * 255.0);
    final weightedIntensity = combinedIntensity * brightness;

    return weightedIntensity.clamp(0.0, 1.0);
  }

  /// Calibrate baseline blue level
  void _calibrateBaseline(double blueIntensity) {
    _calibrationFrameCount++;

    if (_calibrationFrameCount <= 20) {
      // Collect more frames for better baseline
      _baselineBlueLevel =
          ((_baselineBlueLevel * (_calibrationFrameCount - 1)) +
              blueIntensity) /
          _calibrationFrameCount;
    } else {
      _baselineCalibrated = true;
      if (kDebugMode) {
        print('WebBlueLightDetector: 기준값 보정 완료 - $_baselineBlueLevel');
      }
    }
  }

  /// Determine waiting state based on amplified blue intensity
  bool _determineWaitingState(double amplifiedIntensity) {
    if (!_baselineCalibrated) return false;

    // Use sensitivity settings to determine if waiting state is detected
    final isBlueDetected = _sensitivitySettings.isWaitingDetected(
      amplifiedIntensity,
    );

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
      'isInitialized': _isInitialized,
      'cameraActive': _mediaStream?.active ?? false,
    };
  }

  /// Dispose resources and cleanup
  void dispose() {
    try {
      // Stop media stream
      if (_mediaStream != null) {
        for (final track in _mediaStream!.getTracks()) {
          track.stop();
        }
        _mediaStream = null;
      }

      // Remove DOM elements
      _videoElement?.remove();
      _canvasElement?.remove();

      _videoElement = null;
      _canvasElement = null;
      _canvasContext = null;
      _isInitialized = false;

      if (kDebugMode) {
        print('WebBlueLightDetector: 리소스 정리 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebBlueLightDetector: 정리 중 오류 - $e');
      }
    }
  }
}

/// Result of web blue light detection using real camera data
class WebDetectionResult {
  final double blueIntensity;
  final double amplifiedIntensity;
  final double normalizedIntensity;
  final bool isWaitingState;
  final bool stateChanged;
  final double confidence;
  final double baselineLevel;
  final double sensitivityMultiplier;
  final DateTime timestamp;
  final bool isSimulated;
  final String? error;

  const WebDetectionResult({
    required this.blueIntensity,
    required this.amplifiedIntensity,
    required this.normalizedIntensity,    
    required this.isWaitingState,
    required this.stateChanged,
    required this.confidence,
    required this.baselineLevel,
    required this.sensitivityMultiplier,
    required this.timestamp,
    required this.isSimulated,
    this.error,
  });

  WebDetectionResult.error(String errorMessage)
    : blueIntensity = 0.0,
      amplifiedIntensity = 0.0,
      normalizedIntensity = 0.0,
      isWaitingState = false,
      stateChanged = false,
      confidence = 0.0,
      baselineLevel = 0.0,
      sensitivityMultiplier = 1.0,
      timestamp = DateTime.now(),
      isSimulated = false,
      error = errorMessage;

  bool get hasError => error != null;

  String getStateDescription() {
    if (hasError) return '오류 발생';
    if (isWaitingState) return '대기인원 있음 (실제 카메라)';
    return '대기인원 없음 (실제 카메라)';
  }

  @override
  String toString() {
    return 'WebDetectionResult(intensity: ${blueIntensity.toStringAsFixed(3)}, '
        'amplified: ${amplifiedIntensity.toStringAsFixed(3)}, '
        'multiplier: ×${sensitivityMultiplier.toStringAsFixed(1)}, '
        'waiting: $isWaitingState, changed: $stateChanged, '
        'confidence: ${confidence.toStringAsFixed(2)}, real: ${!isSimulated})';
  }
}