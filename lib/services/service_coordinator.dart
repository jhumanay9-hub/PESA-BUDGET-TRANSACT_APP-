import 'dart:async';
import 'dart:io' as dart_io;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/services/foreground_service.dart';
import 'package:transaction_app/services/connectivity_service.dart';

/// ============================================================================
/// SERVICE COORDINATOR - EVENT-DRIVEN SERVICE LIFECYCLE
/// ============================================================================
/// This coordinator manages the event-driven startup sequence:
///
/// Android 9-11 (SDK 28-30): Start foreground service immediately
/// Android 12+ (SDK 31+): Wait for user interaction first
///
/// Sequence:
/// 1. Dashboard Loaded → Check Android version
/// 2. Android 9-11: Start Foreground Immediately
///    Android 12+: Wait for user interaction
/// 3. Foreground Stable → Background Sync
/// 4. Background Complete → Initialize Supabase
/// 5. Supabase Ready → Overlay Engine Warm
///
/// This ensures services start in the correct order without blocking UI.
/// ============================================================================
class ServiceCoordinator {
  static final ServiceCoordinator _instance = ServiceCoordinator._internal();
  factory ServiceCoordinator() => _instance;
  ServiceCoordinator._internal();

  final _foregroundService = ForegroundService();
  final _connectivityService = ConnectivityService();

  // Service state flags
  bool _isForegroundStarted = false;
  bool _isBackgroundSyncComplete = false;
  bool _isSupabaseInitialized = false;
  bool _isOverlayWarm = false;
  bool _hasUserInteracted = false;
  bool _isAndroid12OrHigher = false;

  // Stream controllers for event signaling
  final _foregroundStableController = StreamController<bool>.broadcast();
  final _backgroundCompleteController = StreamController<bool>.broadcast();
  final _supabaseReadyController = StreamController<bool>.broadcast();

  // Stream getters for services to listen
  Stream<bool> get foregroundStableStream => _foregroundStableController.stream;
  Stream<bool> get backgroundCompleteStream =>
      _backgroundCompleteController.stream;
  Stream<bool> get supabaseReadyStream => _supabaseReadyController.stream;

  // Service status getters
  bool get isForegroundStarted => _isForegroundStarted;
  bool get isBackgroundSyncComplete => _isBackgroundSyncComplete;
  bool get isSupabaseInitialized => _isSupabaseInitialized;
  bool get isOverlayWarm => _isOverlayWarm;
  bool get hasUserInteracted => _hasUserInteracted;
  bool get isAndroid12Plus => _isAndroid12OrHigher;

  /// ============================================================================
  /// CHECK ANDROID VERSION
  /// ============================================================================
  /// Android 12+ (SDK 31+) requires user interaction before starting
  /// foreground service. Android 9-11 can start immediately.
  /// ============================================================================
  Future<void> _checkAndroidVersion() async {
    if (dart_io.Platform.isAndroid) {
      // Use device_info_plus to get accurate SDK level
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;

      _isAndroid12OrHigher = sdkVersion >= 31; // SDK 31 = Android 12
      AppLogger.logInfo(
          'ServiceCoordinator: Android $_isAndroid12OrHigher (SDK $sdkVersion)');
      return;
    }
    // Non-Android - assume safe to start
    _isAndroid12OrHigher = false;
    AppLogger.logInfo('ServiceCoordinator: Non-Android detected');
  }

  /// ============================================================================
  /// STEP 1: INITIALIZE (Call from Dashboard initState)
  /// ============================================================================
  /// Checks Android version and starts foreground service if Android 9-11
  /// For Android 12+, waits for user interaction
  /// ============================================================================
  Future<void> initialize() async {
    await _checkAndroidVersion();

    if (!_isAndroid12OrHigher) {
      // Android 9-11: Can start foreground service immediately
      AppLogger.logInfo(
          'ServiceCoordinator: Android 9-11 detected - starting foreground immediately');
      await _startForegroundService();
    } else {
      // Android 12+: Must wait for user interaction
      AppLogger.logInfo(
          'ServiceCoordinator: Android 12+ detected - waiting for user interaction');
    }
  }

  /// ============================================================================
  /// STEP 2: MARK USER INTERACTION
  /// ============================================================================
  /// Call this when user first interacts with the app (taps, scrolls, etc.)
  /// This is REQUIRED before starting foreground service (Android 12+ only)
  /// For Android 9-11, this is a no-op since service already started
  /// ============================================================================
  Future<void> markUserInteraction() async {
    if (_hasUserInteracted) return; // Already marked

    _hasUserInteracted = true;
    AppLogger.logInfo('ServiceCoordinator: User interaction detected');

    // Android 12+: Now we can start the foreground service
    if (_isAndroid12OrHigher) {
      await _startForegroundService();
    }
    // Android 9-11: Service already started in initialize()
  }

  /// Force mark user interaction (for PIN creation completion)
  void forceMarkInteraction() {
    if (!_hasUserInteracted) {
      _hasUserInteracted = true;
      AppLogger.logInfo(
          'ServiceCoordinator: User interaction forced (PIN created)');
    }
  }

  /// ============================================================================
  /// STEP 3: START FOREGROUND SERVICE
  /// ============================================================================
  /// Starts the foreground service with persistent notification.
  /// Android 9-11: Called from initialize()
  /// Android 12+: Called from markUserInteraction()
  /// ============================================================================
  Future<void> _startForegroundService() async {
    if (_isForegroundStarted) return; // Already started

    try {
      AppLogger.logInfo('ServiceCoordinator: Starting Foreground Service...');

      _foregroundService.initService();
      await _foregroundService.start();

      _isForegroundStarted = true;
      AppLogger.logSuccess('ServiceCoordinator: Foreground Service STARTED');

      // FIX: Wait longer (3 seconds) for foreground service to stabilize
      // This prevents the "ZeroHung" error by spacing out CPU-intensive operations
      await Future.delayed(const Duration(seconds: 3));

      // Signal that foreground is stable (triggers background sync)
      _foregroundStableController.add(true);
      AppLogger.logInfo(
          'ServiceCoordinator: Foreground stable - Background Sync can now start');
    } catch (e) {
      AppLogger.logError('ServiceCoordinator: Foreground Service failed', e);
      // Continue anyway - app works without foreground service
    }
  }

  /// ============================================================================
  /// STEP 3: MARK BACKGROUND SYNC COMPLETE
  /// ============================================================================
  /// Call this when background SMS sync is complete.
  /// This triggers Supabase initialization.
  /// ============================================================================
  void markBackgroundSyncComplete() {
    if (_isBackgroundSyncComplete) return;

    _isBackgroundSyncComplete = true;
    AppLogger.logSuccess('ServiceCoordinator: Background Sync COMPLETE');

    // Signal that background sync is complete (triggers Supabase)
    _backgroundCompleteController.add(true);
    AppLogger.logInfo(
        'ServiceCoordinator: Background complete - triggering Supabase');
  }

  /// ============================================================================
  /// STEP 4: INITIALIZE SUPABASE
  /// ============================================================================
  /// Initializes Supabase cloud sync.
  /// Called after background service is complete.
  /// Only runs if internet is available.
  /// ============================================================================
  Future<void> initializeSupabase() async {
    if (_isSupabaseInitialized) return; // Already initialized

    try {
      AppLogger.logInfo(
          'ServiceCoordinator: Checking internet for Supabase...');

      // Use ConnectivityService for comprehensive check
      final hasInternet = await _connectivityService.hasInternet();

      if (!hasInternet) {
        AppLogger.logInfo(
            'ServiceCoordinator: No internet - Supabase skipped (offline mode)');
        // Still mark as "initialized" to complete the chain
        _isSupabaseInitialized = true;
        _supabaseReadyController.add(true);
        return;
      }

      // Check Supabase reachability specifically
      final canReachSupabase = await _connectivityService.canReachSupabase();

      if (!canReachSupabase) {
        AppLogger.logWarning(
            'ServiceCoordinator: Supabase unreachable - running in local-only mode');
        // Still mark as initialized to complete the chain
        _isSupabaseInitialized = true;
        _supabaseReadyController.add(true);
        return;
      }

      AppLogger.logInfo(
          'ServiceCoordinator: Internet available - initializing Supabase...');

      // Supabase is initialized in Dashboard where the import exists
      // This just marks the step as complete
      _isSupabaseInitialized = true;
      AppLogger.logSuccess('ServiceCoordinator: Supabase INITIALIZED');

      // Signal that Supabase is ready (warms overlay engine)
      _supabaseReadyController.add(true);
      AppLogger.logInfo(
          'ServiceCoordinator: Supabase ready - warming Overlay Engine');
    } catch (e) {
      AppLogger.logError(
          'ServiceCoordinator: Supabase initialization failed', e);
      // Mark as initialized anyway to complete the chain
      _isSupabaseInitialized = true;
      _supabaseReadyController.add(true);
    }
  }

  /// ============================================================================
  /// STEP 5: MARK OVERLAY WARM
  /// ============================================================================
  /// Called when overlay engine is ready to receive foreground triggers.
  /// ============================================================================
  void markOverlayWarm() {
    if (_isOverlayWarm) return;

    _isOverlayWarm = true;
    AppLogger.logSuccess('ServiceCoordinator: Overlay Engine WARM and ready');
  }

  /// ============================================================================
  /// GET COORDINATOR INSTANCE (for accessing from isolates)
  /// ============================================================================
  static ServiceCoordinator get instance => _instance;

  /// ============================================================================
  /// CLEANUP
  /// ============================================================================
  void dispose() {
    _foregroundStableController.close();
    _backgroundCompleteController.close();
    _supabaseReadyController.close();
    _connectivityService.dispose();
    AppLogger.logInfo('ServiceCoordinator: Disposed');
  }
}
