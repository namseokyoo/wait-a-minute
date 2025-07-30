import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sensitivity_settings.dart';

/// Web-specific blue light detection using simulated signals
/// Since web cannot access raw camera data, this provides a demo implementation
class WebBlueLightDetector {
  // Detection parameters
  static const int _minConsistentFrames = 3;
  static const int _frameHistorySize = 10;

  // State tracking
  final List<double> _frameHistory = [];
  int _consistentFrameCount = 0;
  bool _currentWaitingState = false;
  double _baselineBlueLevel = 0.15; // Fixed baseline for web demo
  bool _baselineCalibrated = false;
  int _calibrationFrameCount = 0;

  // Sensitivity settings
  SensitivitySettings _sensitivitySettings = SensitivitySettings.standard();

  // Demo simulation state
  DateTime? _lastStateChange;
  int _simulationCycle = 0;

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
      print(
        'WebBlueLightDetector: 감도 설정 업데이트 - ${settings.levelName} (×${settings.multiplier})',
      );
    }
  }

  /// Simulate blue light detection for web platform
  Future<WebDetectionResult> simulateBlueLight() async {
    try {
      // Generate realistic blue light intensity simulation
      final blueIntensity = _generateSimulatedIntensity();

      // Add to frame history
      _frameHistory.add(blueIntensity);
      if (_frameHistory.length > _frameHistorySize) {
        _frameHistory.removeAt(0);
      }

      // Auto-calibrate after a few frames
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

      // Track state changes for realistic timing
      if (stateChanged) {
        _lastStateChange = DateTime.now();
        _simulationCycle = (_simulationCycle + 1) % 10;
      }

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
        isSimulated: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Web blue light simulation error: $e');
      }
      return WebDetectionResult.error(e.toString());
    }
  }

  /// Generate realistic blue light intensity simulation
  double _generateSimulatedIntensity() {
    final now = DateTime.now();
    final secondsOfDay = now.hour * 3600 + now.minute * 60 + now.second;

    // Create a semi-realistic pattern with some randomness
    // Higher intensity during certain times (simulating customer activity)
    double baseIntensity = 0.1;

    // Add time-based variation (higher during business hours)
    final hour = now.hour;
    if (hour >= 9 && hour <= 18) {
      baseIntensity += 0.05; // Slightly higher during business hours
    }

    // Add periodic variation (customers come in waves)
    final periodicVariation = sin(secondsOfDay / 60) * 0.08;

    // Add some controlled randomness
    final randomComponent = (now.millisecond % 100) / 100.0 * 0.1;

    // Simulation cycles to create realistic customer patterns
    double cycleModifier = 0.0;
    switch (_simulationCycle % 4) {
      case 0: // No customer
        cycleModifier = -0.05;
        break;
      case 1: // Customer approaching
        cycleModifier = 0.1;
        break;
      case 2: // Customer waiting
        cycleModifier = 0.15;
        break;
      case 3: // Customer leaving
        cycleModifier = 0.05;
        break;
    }

    final result = (baseIntensity +
            periodicVariation +
            randomComponent +
            cycleModifier)
        .clamp(0.0, 0.4);

    return result;
  }

  /// Calibrate baseline blue level (for web, this is mostly for UI consistency)
  void _calibrateBaseline(double blueIntensity) {
    _calibrationFrameCount++;

    if (_calibrationFrameCount <= 10) {
      // Faster calibration for web
      _baselineBlueLevel =
          ((_baselineBlueLevel * (_calibrationFrameCount - 1)) +
              blueIntensity) /
          _calibrationFrameCount;
    } else {
      _baselineCalibrated = true;
      if (kDebugMode) {
        print('Web baseline calibrated: $_baselineBlueLevel');
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
    _baselineBlueLevel = 0.15;
    _baselineCalibrated = false;
    _calibrationFrameCount = 0;
    _lastStateChange = null;
    _simulationCycle = 0;
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
      'simulationCycle': _simulationCycle,
      'lastStateChange': _lastStateChange?.toIso8601String(),
    };
  }
}

/// Result of web blue light detection simulation
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
      isSimulated = true,
      error = errorMessage;

  bool get hasError => error != null;

  String getStateDescription() {
    if (hasError) return '오류 발생';
    if (isWaitingState) return '대기인원 있음 (웹 데모)';
    return '대기인원 없음 (웹 데모)';
  }

  @override
  String toString() {
    return 'WebDetectionResult(intensity: ${blueIntensity.toStringAsFixed(3)}, '
        'amplified: ${amplifiedIntensity.toStringAsFixed(3)}, '
        'multiplier: ×${sensitivityMultiplier.toStringAsFixed(1)}, '
        'waiting: $isWaitingState, changed: $stateChanged, '
        'confidence: ${confidence.toStringAsFixed(2)}, simulated: $isSimulated)';
  }
}
