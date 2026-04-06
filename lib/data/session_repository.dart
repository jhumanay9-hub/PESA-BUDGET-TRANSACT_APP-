import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transaction_app/core/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:transaction_app/services/connectivity_service.dart';

class SessionRepository {
  static final SessionRepository _instance = SessionRepository._internal();
  factory SessionRepository() => _instance;
  SessionRepository._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  static bool _supabaseInitialized = false;

  // Connectivity service for network awareness
  final _connectivityService = ConnectivityService();

  // ============================================================================
  // PATIENCE PROTOCOL: Connectivity Stream for Stable Connection Detection
  // ============================================================================
  // Listens to connectivity changes and tracks stable connection state
  // to avoid auth attempts during DNS transitions
  // ============================================================================
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  DateTime? _connectivityStableSince;
  static const _stableConnectionThreshold = Duration(seconds: 2);

  /// Start listening to connectivity changes (called during initialization)
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      AppLogger.logInfo('Session: Connectivity changed to ${result.name}');

      if (result != ConnectivityResult.none) {
        // Connection available - mark as potentially stable
        _connectivityStableSince = DateTime.now();
        AppLogger.logInfo(
            'Session: Connection available, waiting ${_stableConnectionThreshold.inSeconds}s for stability');
      } else {
        // Connection lost - reset stability timer
        _connectivityStableSince = null;
        AppLogger.logWarning('Session: Connection lost');
      }
    });
  }

  /// Check if connection is stable (not in transition)
  Future<bool> _isConnectionStable() async {
    // If we haven't been monitoring long enough, do a fresh check
    if (_connectivityStableSince == null) {
      return await _isNetworkReady();
    }

    // Check if enough time has passed since connectivity changed
    final timeSinceStable =
        DateTime.now().difference(_connectivityStableSince!);
    if (timeSinceStable < _stableConnectionThreshold) {
      AppLogger.logInfo(
          'Session: Connection stabilizing (${timeSinceStable.inMilliseconds}ms elapsed)');
      return false; // Still stabilizing
    }

    // Connection has been stable, verify with DNS probe
    return await _isNetworkReady();
  }

  /// Stop connectivity monitoring (cleanup)
  void _stopConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Initialize Supabase lazily before first auth call
  /// This prevents the "_instance._isInitialized" crash during PIN signup
  static Future<void> _ensureSupabase() async {
    if (!_supabaseInitialized) {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
      _supabaseInitialized = true;
      AppLogger.logInfo('SessionRepository: Supabase initialized');
    }
  }

  /// Check if network is ready for Supabase connection
  /// Uses Patience Protocol to wait for stable connection
  Future<bool> _isNetworkReady() async {
    // Use ConnectivityService for comprehensive network check
    try {
      // Check basic internet connectivity
      if (!await _connectivityService.hasInternet()) {
        AppLogger.logWarning('Session: No network connectivity detected');
        return false;
      }

      // Check network quality
      final quality = await _connectivityService.getNetworkQuality();
      if (quality == NetworkQuality.none || quality == NetworkQuality.poor) {
        AppLogger.logWarning(
            'Session: Network quality too poor for auth ($quality)');
        return false;
      }

      // DNS probe already done by ConnectivityService
      AppLogger.logInfo('Session: Network ready - quality = ${quality.name}');
      return true;
    } catch (e) {
      AppLogger.logError('Session: Network check failed', e);
      return false;
    }
  }

  /// Internal auth method with retry logic
  /// Implements "Patience Protocol" with exponential backoff
  /// FIX: Added specific handling for AuthRetryableFetchException (errno 7)
  Future<bool> _doAuthWithRetry(
    String phoneNumber,
    String pin,
    bool isSignUp,
  ) async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // PATIENCE PROTOCOL: Check for stable connection (not just available)
        if (!await _isConnectionStable()) {
          AppLogger.logWarning(
            'Session: Connection not stable (attempt $attempt/$maxAttempts)',
          );

          if (attempt < maxAttempts) {
            // EXPONENTIAL BACKOFF: 3s → 8s → 15s
            // Formula: (attempt * 3) + (attempt * attempt) seconds
            final delaySeconds = (attempt * 3) + (attempt * attempt);
            final delay = Duration(seconds: delaySeconds);

            AppLogger.logInfo(
              'Session: Waiting ${delay.inSeconds}s for connection to stabilize...',
            );
            await Future.delayed(delay);
            continue;
          }
          return false;
        }

        // Connection is stable, proceed with auth

        // FIX: Wrap auth call in try-catch for AuthRetryableFetchException
        try {
          if (isSignUp) {
            await Supabase.instance.client.auth.signUp(
              email: '$phoneNumber@phone.pesabudget.local',
              password: pin,
            );
            AppLogger.logInfo('Session: Signup successful');
          } else {
            await Supabase.instance.client.auth.signInWithPassword(
              email: '$phoneNumber@phone.pesabudget.local',
              password: pin,
            );
            AppLogger.logInfo('Session: Signin successful');
          }

          await linkPhoneNumber(phoneNumber);
          await setLoginStatus(true);

          AppLogger.logSuccess('Session: Phone + PIN auth successful');
          return true;
        } on SocketException catch (e) {
          // FIX: Specific handling for errno 7 (Failed host lookup)
          AppLogger.logWarning(
            'Session: Auth SocketException (attempt $attempt/$maxAttempts): ${e.message}',
          );

          if (attempt < maxAttempts) {
            // Wait 3 seconds to let Huawei network stack "wake up"
            const delay = Duration(seconds: 3);
            AppLogger.logInfo(
              'Session: DNS may be stale, waiting ${delay.inSeconds}s before retry...',
            );
            await Future.delayed(delay);
            continue;
          }
          AppLogger.logError(
            'Session: Auth failed after retries - DNS resolution blocked',
            e,
          );
          return false;
        }
      } on SocketException catch (e) {
        AppLogger.logWarning(
          'Session: Network error (attempt $attempt/$maxAttempts): ${e.message}',
        );

        if (attempt < maxAttempts) {
          // EXPONENTIAL BACKOFF for SocketException
          final delaySeconds = (attempt * 3) + (attempt * attempt);
          final delay = Duration(seconds: delaySeconds);

          AppLogger.logInfo(
            'Session: Retrying in ${delay.inSeconds}s (exponential backoff)...',
          );
          await Future.delayed(delay);
        } else {
          AppLogger.logError(
            'Session: All auth attempts failed - device offline',
            e,
          );
        }
      } on AuthException catch (e) {
        // Auth errors (wrong PIN, etc.) - don't retry
        AppLogger.logError('Session: Auth failed', e);
        return false;
      } catch (e) {
        AppLogger.logError('Session: Unexpected error', e);
        return false;
      }
    }

    return false;
  }

  // --- Keys (Decoupled & Standardized) ---
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _pinKey = 'user_secure_pin';
  static const String _userIdKey = 'cached_user_id';
  static const String _accountModeKey =
      'active_account_mode'; // Personal vs Business
  static const String _permissionsGrantedKey = 'permissions_granted';
  static const String _firstTimeUserKey = 'is_first_time_user';
  static const String _initialSmsSyncKey = 'initial_sms_sync_completed';
  static const String _linkedPhoneKey = 'linked_phone_number';
  static const String _authTypeKey = 'auth_type'; // 'device' or 'phone'

  /// Initialize at boot in main.dart
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // If firstTimeUserKey doesn't exist, this is a first-time user
    if (!_prefs.containsKey(_firstTimeUserKey)) {
      await _prefs.setBool(_firstTimeUserKey, true);
    }
    _isInitialized = true;

    // Start connectivity monitoring for Patience Protocol
    _startConnectivityMonitoring();

    AppLogger.logSuccess('SessionRepository: Local Vault Connected');
  }

  bool get isInitialized => _isInitialized;

  // --- Getters (Zero-Latency for AuthWrapper) ---

  bool get isLoggedLocally => _prefs.getBool(_isLoggedInKey) ?? false;

  // Alias for compatibility
  bool get isLoggedIn => isLoggedLocally;

  bool get hasSecurePin => _prefs.getString(_pinKey) != null;

  // Alias for compatibility
  bool get hasCreatedPin => hasSecurePin;

  bool get isFirstTimeUser => _prefs.getBool(_firstTimeUserKey) ?? true;

  String get activeAccountMode =>
      _prefs.getString(_accountModeKey) ?? 'Personal';

  String? get userId => _prefs.getString(_userIdKey);

  bool get hasGrantedPermissions =>
      _prefs.getBool(_permissionsGrantedKey) ?? false;

  bool get hasCompletedInitialSmsSync =>
      _prefs.getBool(_initialSmsSyncKey) ?? false;

  // --- PIN + Phone Number Cloud Recovery ---

  /// Get linked phone number (if user set up cloud recovery)
  String? get linkedPhoneNumber => _prefs.getString(_linkedPhoneKey);

  /// Get auth type ('device' or 'phone')
  String get authType => _prefs.getString(_authTypeKey) ?? 'device';

  // --- Actions (Mutations) ---

  /// Sets the Login status.
  Future<void> setLoginStatus(bool status) async {
    await _prefs.setBool(_isLoggedInKey, status);
    AppLogger.logSuccess('Session: Login status set to $status');
  }

  /// Saves the PIN for cloud authentication
  Future<void> savePin(String pin) async {
    await _prefs.setString(_pinKey, pin);
    AppLogger.logSuccess('Session: Secure PIN established');
  }

  /// Validates the PIN input
  bool validatePin(String input) {
    return _prefs.getString(_pinKey) == input;
  }

  /// Toggles the "Page Flip" (Personal <-> Business)
  Future<void> toggleAccountMode(String mode) async {
    await _prefs.setString(_accountModeKey, mode);
    AppLogger.logInfo('Session: Account mode flipped to $mode');
  }

  /// Marks permissions as granted after user completes PermissionManagerScreen
  Future<void> setPermissionsGranted(bool granted) async {
    await _prefs.setBool(_permissionsGrantedKey, granted);
    AppLogger.logSuccess('Session: Permissions flag set to $granted');
  }

  /// Mark first-time user flow as complete (called after PIN creation)
  Future<void> setFirstTimeUserComplete() async {
    await _prefs.setBool(_firstTimeUserKey, false);
    AppLogger.logInfo('Session: First-time user flow complete');
  }

  /// Mark initial SMS sync as completed (called after first successful sync)
  Future<void> markInitialSmsSyncCompleted() async {
    await _prefs.setBool(_initialSmsSyncKey, true);
    AppLogger.logInfo('Session: Initial SMS sync completed');
  }

  /// Link phone number for cloud recovery (PIN + Phone auth)
  Future<void> linkPhoneNumber(String phoneNumber) async {
    await _prefs.setString(_linkedPhoneKey, phoneNumber);
    await _prefs.setString(_authTypeKey, 'phone');
    AppLogger.logSuccess('Session: Phone number linked for cloud recovery');
  }

  /// Sign in with phone number + PIN (for cloud sync and recovery)
  /// This is called during onboarding to create cloud account
  Future<bool> signInWithPhoneAndPin(String phoneNumber, String pin) async {
    // CRITICAL: Ensure Supabase is initialized before any auth calls
    await _ensureSupabase();

    // Try sign in first (user may already exist)
    bool result = await _doAuthWithRetry(phoneNumber, pin, false);
    if (result) return true;

    // If sign in failed, try sign up (new user)
    AppLogger.logInfo('Session: Signin failed, trying signup...');
    return await _doAuthWithRetry(phoneNumber, pin, true);
  }

  /// Sign in with phone number + PIN (for recovery on new phone)
  Future<bool> recoverWithPhoneAndPin(String phoneNumber, String pin) async {
    // CRITICAL: Ensure Supabase is initialized before any auth calls
    await _ensureSupabase();

    // Validate PIN format (4-6 digits)
    if (pin.length < 4 || pin.length > 6) {
      return false;
    }

    // Use retry logic for recovery
    return await _doAuthWithRetry(phoneNumber, pin, false);
  }

  /// Complete Wipe for "Clean Slate" repairs
  Future<void> clearAll() async {
    await _prefs.clear();
    AppLogger.logWarning('Session: Local vault nuked for maintenance');
  }

  /// Cleanup resources when app shuts down
  void dispose() {
    _stopConnectivityMonitoring();
    _connectivityService.dispose();
    AppLogger.logInfo('SessionRepository: Disposed');
  }
}
