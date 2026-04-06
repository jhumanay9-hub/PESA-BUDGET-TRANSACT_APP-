import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';

/// ============================================================================
/// HARDWARE CAPABILITIES - Device Performance Detection
/// ============================================================================
/// This service detects device hardware capabilities and provides
/// configuration flags to adapt UI complexity for smooth 60 FPS performance.
///
/// Detection Criteria:
/// 1. RAM amount (primary indicator)
/// 2. CPU core count
/// 3. Android SDK version
/// 4. Device model (known low-end devices)
/// 5. Real-time frame timing (optional)
/// ============================================================================

enum DeviceTier {
  lowEnd, // < 4GB RAM, < 4 cores - Minimal effects
  midRange, // 4-6GB RAM, 4-6 cores - Moderate effects
  highEnd, // > 6GB RAM, > 6 cores - Full effects
}

class HardwareCapabilities {
  static final HardwareCapabilities _instance =
      HardwareCapabilities._internal();
  factory HardwareCapabilities() => _instance;
  HardwareCapabilities._internal();

  // Cached device info
  DeviceTier? _deviceTier;
  int? _ramGB;
  int? _cpuCores;
  String? _deviceModel;
  int? _sdkVersion;
  bool? _isLowEndDevice;

  // Performance thresholds
  static const int LOW_END_RAM_GB = 4;
  static const int MID_RANGE_RAM_GB = 6;
  static const int LOW_END_CPU_CORES = 4;
  static const int MID_RANGE_CPU_CORES = 6;

  /// Initialize hardware detection (call once at app startup)
  Future<void> initialize() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceModel = androidInfo.model;
        _sdkVersion = androidInfo.version.sdkInt;

        // Get RAM info - estimate based on device model
        // Note: device_info_plus doesn't expose RAM info directly in newer versions
        _ramGB = _estimateAndroidRam(androidInfo.model);

        // Get CPU core count - estimate based on device model keywords
        _cpuCores = _estimateAndroidCores(androidInfo.model);

        AppLogger.logInfo(
          'Hardware: ${androidInfo.model} | RAM: ${_ramGB}GB | Cores: $_cpuCores | SDK: $_sdkVersion',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceModel = iosInfo.model;
        // iOS doesn't expose RAM/CPU info easily, use model-based detection
        _ramGB = _estimateIOSRam(iosInfo.model);
        _cpuCores = _estimateIOSCores(iosInfo.model);

        AppLogger.logInfo(
          'Hardware: ${iosInfo.model} | Estimated RAM: ${_ramGB}GB | Cores: $_cpuCores',
        );
      } else {
        // Desktop/Web - assume high-end
        _ramGB = 8;
        _cpuCores = 4;
        _deviceModel = 'Desktop/Web';
        _sdkVersion = 0;
      }

      // Calculate device tier
      _calculateDeviceTier();

      AppLogger.logSuccess(
        'Hardware: Device tier = ${_deviceTier?.name} | Low-end = $_isLowEndDevice',
      );
    } catch (e) {
      AppLogger.logError('Hardware: Detection failed', e);
      // Default to mid-range on error
      _deviceTier = DeviceTier.midRange;
      _isLowEndDevice = false;
      _ramGB = 4;
      _cpuCores = 4;
    }
  }

  /// Estimate iOS RAM based on model (approximate)
  int _estimateIOSRam(String model) {
    final lowerModel = model.toLowerCase();
    if (lowerModel.contains('iphone se') ||
        lowerModel.contains('iphone 6') ||
        lowerModel.contains('iphone 7') ||
        lowerModel.contains('iphone 8')) {
      return 2; // Low-end
    } else if (lowerModel.contains('iphone x') ||
        lowerModel.contains('iphone 11') ||
        lowerModel.contains('iphone 12')) {
      return 4; // Mid-range
    } else if (lowerModel.contains('iphone 13') ||
        lowerModel.contains('iphone 14') ||
        lowerModel.contains('iphone 15')) {
      return 6; // High-end
    }
    return 4; // Default
  }

  /// Estimate Android RAM based on device model (approximate)
  int _estimateAndroidRam(String model) {
    final lowerModel = model.toLowerCase();
    // Known low-end device patterns
    if (lowerModel.contains('go edition') ||
        lowerModel.contains('lite') ||
        lowerModel.contains('core') ||
        lowerModel.contains('play') ||
        lowerModel.contains('y5') ||
        lowerModel.contains('y6') ||
        lowerModel.contains('a10') ||
        lowerModel.contains('a20') ||
        lowerModel.contains('j2') ||
        lowerModel.contains('j3')) {
      return 2; // Low-end (2GB or less)
    }
    // Known mid-range device patterns
    if (lowerModel.contains('a30') ||
        lowerModel.contains('a40') ||
        lowerModel.contains('a50') ||
        lowerModel.contains('a70') ||
        lowerModel.contains('note 8') ||
        lowerModel.contains('y7') ||
        lowerModel.contains('y9')) {
      return 4; // Mid-range (4GB)
    }
    // Known high-end device patterns
    if (lowerModel.contains('s20') ||
        lowerModel.contains('s21') ||
        lowerModel.contains('s22') ||
        lowerModel.contains('s23') ||
        lowerModel.contains('note 10') ||
        lowerModel.contains('note 20') ||
        lowerModel.contains('pixel 5') ||
        lowerModel.contains('pixel 6') ||
        lowerModel.contains('pixel 7') ||
        lowerModel.contains('pixel 8')) {
      return 8; // High-end (8GB+)
    }
    return 4; // Default to mid-range
  }

  /// Estimate Android CPU cores based on device model (approximate)
  int _estimateAndroidCores(String model) {
    final lowerModel = model.toLowerCase();
    // Check for CPU core keywords in model name
    if (lowerModel.contains('octa')) {
      return 8; // Octa-core
    } else if (lowerModel.contains('hexa')) {
      return 6; // Hexa-core
    } else if (lowerModel.contains('quad')) {
      return 4; // Quad-core
    }
    // Estimate based on device tier
    final ram = _estimateAndroidRam(model);
    if (ram >= 8) return 8; // High-end usually has 8 cores
    if (ram >= 4) return 6; // Mid-range usually has 6 cores
    return 4; // Low-end usually has 4 cores
  }

  /// Estimate iOS CPU cores based on model (approximate)
  int _estimateIOSCores(String model) {
    final lowerModel = model.toLowerCase();
    if (lowerModel.contains('iphone se') ||
        lowerModel.contains('iphone 6') ||
        lowerModel.contains('iphone 7')) {
      return 2; // Dual-core
    } else if (lowerModel.contains('iphone 8') ||
        lowerModel.contains('iphone x') ||
        lowerModel.contains('iphone 11')) {
      return 4; // Quad-core
    } else if (lowerModel.contains('iphone 12') ||
        lowerModel.contains('iphone 13') ||
        lowerModel.contains('iphone 14') ||
        lowerModel.contains('iphone 15')) {
      return 6; // Hexa-core
    }
    return 4; // Default
  }

  /// Calculate device tier based on hardware specs
  void _calculateDeviceTier() {
    if (_ramGB == null || _cpuCores == null) {
      _deviceTier = DeviceTier.midRange;
      _isLowEndDevice = false;
      return;
    }

    // Low-end: RAM < 4GB OR CPU cores < 4
    if (_ramGB! < LOW_END_RAM_GB || _cpuCores! < LOW_END_CPU_CORES) {
      _deviceTier = DeviceTier.lowEnd;
      _isLowEndDevice = true;
      return;
    }

    // High-end: RAM >= 6GB AND CPU cores >= 6
    if (_ramGB! >= MID_RANGE_RAM_GB && _cpuCores! >= MID_RANGE_CPU_CORES) {
      _deviceTier = DeviceTier.highEnd;
      _isLowEndDevice = false;
      return;
    }

    // Mid-range: Everything else
    _deviceTier = DeviceTier.midRange;
    _isLowEndDevice = false;
  }

  /// Check if device is low-end
  bool get isLowEndDevice => _isLowEndDevice ?? false;

  /// Check if device is high-end
  bool get isHighEndDevice => _deviceTier == DeviceTier.highEnd;

  /// Check if device is mid-range
  bool get isMidRangeDevice => _deviceTier == DeviceTier.midRange;

  /// Get device tier
  DeviceTier get deviceTier => _deviceTier ?? DeviceTier.midRange;

  /// Get RAM in GB
  int get ramGB => _ramGB ?? 4;

  /// Get CPU core count
  int get cpuCores => _cpuCores ?? 4;

  /// Get device model
  String get deviceModel => _deviceModel ?? 'Unknown';

  /// Get SDK version
  int get sdkVersion => _sdkVersion ?? 0;

  /// Should we disable animations?
  bool get shouldDisableAnimations => isLowEndDevice;

  /// Should we disable blur effects?
  bool get shouldDisableBlurs => isLowEndDevice;

  /// Should we disable complex shadows?
  bool get shouldDisableShadows => isLowEndDevice;

  /// Should we use simplified rendering?
  bool get shouldUseSimplifiedRendering => isLowEndDevice;

  /// Should we reduce image quality?
  bool get shouldReduceImageQuality => isLowEndDevice;

  /// Get animation duration multiplier (1.0 = normal, 0.5 = half speed, 0 = disabled)
  double get animationDurationMultiplier {
    if (isLowEndDevice) return 0.5;
    if (isHighEndDevice) return 1.0;
    return 0.75;
  }

  /// Get max concurrent operations
  int get maxConcurrentOperations {
    if (isLowEndDevice) return 2;
    if (isHighEndDevice) return 8;
    return 4;
  }

  /// Get cache size multiplier
  double get cacheSizeMultiplier {
    if (isLowEndDevice) return 0.5;
    if (isHighEndDevice) return 2.0;
    return 1.0;
  }

  /// Check if a specific feature should be enabled
  bool shouldEnableFeature(HardwareFeature feature) {
    switch (feature) {
      case HardwareFeature.blur:
      case HardwareFeature.parallax:
      case HardwareFeature.complexShadows:
      case HardwareFeature.realTimeUpdates:
        return !isLowEndDevice;
      case HardwareFeature.basicAnimations:
      case HardwareFeature.simpleShadows:
      case HardwareFeature.cachedUpdates:
        return true;
      case HardwareFeature.highResImages:
        return isHighEndDevice;
    }
  }

  /// Force re-detection (for testing)
  Future<void> forceRedetect() async {
    _deviceTier = null;
    _isLowEndDevice = null;
    await initialize();
  }
}

/// Hardware features enum
enum HardwareFeature {
  blur,
  parallax,
  complexShadows,
  realTimeUpdates,
  basicAnimations,
  simpleShadows,
  cachedUpdates,
  highResImages,
}

/// ============================================================================
/// HARDWARE-AWARE WIDGET BUILDER
/// ============================================================================
/// Helper widget to conditionally render based on device tier
/// ============================================================================

class HardwareAwareBuilder extends StatelessWidget {
  final Widget Function(bool isLowEnd, DeviceTier tier) builder;
  final Widget? fallbackForLowEnd;

  const HardwareAwareBuilder({
    super.key,
    required this.builder,
    this.fallbackForLowEnd,
  });

  @override
  Widget build(BuildContext context) {
    final hardware = HardwareCapabilities();
    final isLowEnd = hardware.isLowEndDevice;
    final tier = hardware.deviceTier;

    if (isLowEnd && fallbackForLowEnd != null) {
      return fallbackForLowEnd!;
    }

    return builder(isLowEnd, tier);
  }
}

/// ============================================================================
/// PERFORMANCE MONITOR - Real-time Frame Timing
/// ============================================================================
/// Monitors frame rendering times to detect performance issues
/// ============================================================================

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final List<Duration> _frameTimes = [];
  bool _isMonitoring = false;
  int _frameCount = 0;
  Duration _totalFrameTime = Duration.zero;

  /// Start monitoring frame times
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _frameTimes.clear();
    _frameCount = 0;
    _totalFrameTime = Duration.zero;
  }

  /// Record a frame time
  void recordFrame(Duration frameTime) {
    if (!_isMonitoring) return;

    _frameTimes.add(frameTime);
    _frameCount++;
    _totalFrameTime += frameTime;

    // Keep only last 100 frames
    if (_frameTimes.length > 100) {
      _frameTimes.removeAt(0);
    }
  }

  /// Get average frame time
  Duration get averageFrameTime {
    if (_frameTimes.isEmpty) return Duration.zero;
    return _totalFrameTime ~/ _frameCount;
  }

  /// Get frames per second
  double get fps {
    final avgMs = averageFrameTime.inMilliseconds;
    if (avgMs == 0) return 60.0;
    return 1000.0 / avgMs;
  }

  /// Check if performance is degraded (avg frame time > 16ms)
  bool get isPerformanceDegraded {
    return averageFrameTime.inMilliseconds > 16;
  }

  /// Get performance score (0-100)
  int get performanceScore {
    final avgMs = averageFrameTime.inMilliseconds;
    if (avgMs <= 16) return 100; // 60 FPS
    if (avgMs <= 33) return 75; // 30 FPS
    if (avgMs <= 50) return 50; // 20 FPS
    return 25; // < 20 FPS
  }

  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
  }

  /// Reset monitoring
  void reset() {
    _frameTimes.clear();
    _frameCount = 0;
    _totalFrameTime = Duration.zero;
  }
}
