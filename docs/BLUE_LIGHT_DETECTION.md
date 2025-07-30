# Blue Light Detection Algorithm Design

## Overview
Advanced blue light detection system using HSV color space analysis with configurable sensitivity and real-time processing optimization.

## Detection Algorithm Specifications

### Color Space Analysis
```dart
// HSV-based blue light detection parameters
class BlueDetectionConfig {
  // Blue hue range in HSV (degrees)
  static const double BLUE_HUE_MIN = 200.0;  // Deep blue start
  static const double BLUE_HUE_MAX = 260.0;  // Violet blue end
  
  // Saturation requirements (0.0 - 1.0)
  static const double MIN_SATURATION = 0.3;   // Avoid gray/white
  static const double MAX_SATURATION = 1.0;   // Pure colors
  
  // Value/Brightness requirements (0.0 - 1.0)
  static const double MIN_VALUE = 0.4;        // Minimum brightness
  static const double MAX_VALUE = 1.0;        // Full brightness
  
  // Detection thresholds
  static const double INTENSITY_THRESHOLD = 0.7;  // % of blue pixels
  static const int MIN_DETECTION_AREA = 50;       // Minimum pixel area
}
```

### Core Detection Algorithm
```dart
class BlueLightDetector {
  DetectionResult analyzeFrame(Uint8List imageBytes) {
    // 1. Image preprocessing
    final image = img.decodeImage(imageBytes);
    if (image == null) return DetectionResult.empty();
    
    // 2. Convert RGB to HSV and analyze
    int bluePixelCount = 0;
    int totalPixels = image.width * image.height;
    List<Point<int>> bluePixels = [];
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final hsv = _rgbToHsv(pixel);
        
        if (_isBluePixel(hsv)) {
          bluePixelCount++;
          bluePixels.add(Point(x, y));
        }
      }
    }
    
    // 3. Calculate blue intensity percentage
    double blueIntensity = bluePixelCount / totalPixels;
    
    // 4. Find detection area bounding box
    Rect? detectionArea = _calculateBoundingBox(bluePixels);
    
    // 5. Determine if threshold exceeded
    bool isDetected = blueIntensity >= BlueDetectionConfig.INTENSITY_THRESHOLD;
    
    return DetectionResult(
      isBlueDetected: isDetected,
      intensity: blueIntensity,
      detectionArea: detectionArea,
      dominantColor: _calculateDominantBlue(image, bluePixels),
      timestamp: DateTime.now(),
    );
  }
  
  // HSV color space conversion
  HSV _rgbToHsv(int rgb) {
    int r = (rgb >> 16) & 0xFF;
    int g = (rgb >> 8) & 0xFF;
    int b = rgb & 0xFF;
    
    double rNorm = r / 255.0;
    double gNorm = g / 255.0;
    double bNorm = b / 255.0;
    
    double max = math.max(rNorm, math.max(gNorm, bNorm));
    double min = math.min(rNorm, math.min(gNorm, bNorm));
    double delta = max - min;
    
    // Calculate hue
    double hue = 0;
    if (delta != 0) {
      if (max == rNorm) {
        hue = 60 * ((gNorm - bNorm) / delta);
      } else if (max == gNorm) {
        hue = 60 * (2 + (bNorm - rNorm) / delta);
      } else {
        hue = 60 * (4 + (rNorm - gNorm) / delta);
      }
    }
    if (hue < 0) hue += 360;
    
    // Calculate saturation
    double saturation = (max == 0) ? 0 : delta / max;
    
    // Calculate value
    double value = max;
    
    return HSV(hue, saturation, value);
  }
  
  // Blue pixel detection logic
  bool _isBluePixel(HSV hsv) {
    return hsv.hue >= BlueDetectionConfig.BLUE_HUE_MIN &&
           hsv.hue <= BlueDetectionConfig.BLUE_HUE_MAX &&
           hsv.saturation >= BlueDetectionConfig.MIN_SATURATION &&
           hsv.value >= BlueDetectionConfig.MIN_VALUE;
  }
}
```

## Performance Optimization

### Frame Processing Strategy
```dart
class OptimizedDetector {
  static const int SKIP_FRAMES = 2;  // Process every 3rd frame
  static const int SAMPLE_RATE = 4;  // Sample every 4th pixel
  
  int _frameCounter = 0;
  DetectionResult? _lastResult;
  
  DetectionResult? processFrame(Uint8List imageBytes) {
    _frameCounter++;
    
    // Skip frames for performance
    if (_frameCounter % SKIP_FRAMES != 0) {
      return _lastResult;
    }
    
    // Process with sampling
    _lastResult = _analyzeSampledFrame(imageBytes);
    return _lastResult;
  }
  
  DetectionResult _analyzeSampledFrame(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) return DetectionResult.empty();
    
    int bluePixelCount = 0;
    int totalSamples = 0;
    List<Point<int>> bluePixels = [];
    
    // Sample pixels for faster processing
    for (int y = 0; y < image.height; y += SAMPLE_RATE) {
      for (int x = 0; x < image.width; x += SAMPLE_RATE) {
        totalSamples++;
        final pixel = image.getPixel(x, y);
        final hsv = _rgbToHsv(pixel);
        
        if (_isBluePixel(hsv)) {
          bluePixelCount++;
          bluePixels.add(Point(x, y));
        }
      }
    }
    
    double blueIntensity = bluePixelCount / totalSamples;
    return DetectionResult(
      isBlueDetected: blueIntensity >= BlueDetectionConfig.INTENSITY_THRESHOLD,
      intensity: blueIntensity,
      detectionArea: _calculateBoundingBox(bluePixels),
      dominantColor: Colors.blue, // Simplified for performance
      timestamp: DateTime.now(),
    );
  }
}
```

### Adaptive Sensitivity
```dart
class AdaptiveDetector {
  double _currentThreshold = BlueDetectionConfig.INTENSITY_THRESHOLD;
  List<double> _recentIntensities = [];
  static const int HISTORY_SIZE = 30; // 30 frame history
  
  void updateSensitivity() {
    if (_recentIntensities.length < HISTORY_SIZE) return;
    
    // Calculate average background blue level
    double avgBlue = _recentIntensities.reduce((a, b) => a + b) / HISTORY_SIZE;
    
    // Adaptive threshold: background + margin
    _currentThreshold = math.max(
      avgBlue + 0.2,  // 20% above background
      0.3             // Minimum threshold
    );
  }
  
  void recordIntensity(double intensity) {
    _recentIntensities.add(intensity);
    if (_recentIntensities.length > HISTORY_SIZE) {
      _recentIntensities.removeAt(0);
    }
    
    if (_recentIntensities.length % 10 == 0) {
      updateSensitivity();
    }
  }
}
```

## Detection Modes

### Standard Detection Mode
- **Frame Rate**: 10 FPS processing
- **Resolution**: Full camera resolution
- **Accuracy**: High precision detection
- **Use Case**: Stationary monitoring with good lighting

### Performance Mode
- **Frame Rate**: 5 FPS processing  
- **Resolution**: 320x240 downscaled
- **Accuracy**: Moderate precision
- **Use Case**: Battery conservation, background monitoring

### High Sensitivity Mode
- **Frame Rate**: 15 FPS processing
- **Resolution**: Full resolution with region of interest
- **Accuracy**: Maximum precision with false positive filtering
- **Use Case**: Critical monitoring, low blue light environments

## Configuration Interface
```dart
class DetectionSettings {
  double sensitivity = 0.7;        // Detection threshold (0.1 - 1.0)
  int processingRate = 10;         // FPS for processing
  bool adaptiveThreshold = true;   // Enable adaptive sensitivity
  DetectionMode mode = DetectionMode.standard;
  
  // UI configurable parameters
  double blueHueRange = 60.0;      // Adjustable hue range width
  double minSaturation = 0.3;      // Minimum color saturation
  double minBrightness = 0.4;      // Minimum brightness threshold
  
  // Advanced settings
  int minDetectionArea = 50;       // Minimum pixel area for detection
  bool enableROI = false;          // Region of interest mode
  Rect? regionOfInterest;          // Custom detection area
}
```

## Real-time Visualization
```dart
class DetectionOverlay extends StatelessWidget {
  final DetectionResult result;
  
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blue intensity meter
        Positioned(
          top: 50,
          right: 20,
          child: BlueIntensityMeter(intensity: result.intensity),
        ),
        
        // Detection area highlight
        if (result.detectionArea != null)
          Positioned.fromRect(
            rect: result.detectionArea!,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: result.isBlueDetected ? Colors.red : Colors.yellow,
                  width: 3,
                ),
              ),
            ),
          ),
          
        // Status indicator
        Positioned(
          bottom: 50,
          left: 20,
          child: DetectionStatusCard(
            isDetected: result.isBlueDetected,
            intensity: result.intensity,
            timestamp: result.timestamp,
          ),
        ),
      ],
    );
  }
}
```

## Testing & Calibration

### Test Cases
1. **Blue LED Light**: Direct blue LED exposure test
2. **Blue Screen**: Computer monitor blue screen test
3. **Blue Objects**: Blue colored objects under various lighting
4. **Mixed Lighting**: Blue light mixed with other colors
5. **Low Light**: Blue detection in dim conditions
6. **Bright Ambient**: Blue detection with bright background

### Calibration Process
1. **Background Calibration**: 30-second background analysis
2. **Sensitivity Testing**: Controlled blue light exposure
3. **False Positive Check**: Non-blue light sources verification
4. **Performance Benchmark**: Processing speed validation