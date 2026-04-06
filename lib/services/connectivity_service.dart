import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:transaction_app/core/constants.dart';
import 'package:transaction_app/core/logger.dart';

/// ============================================================================
/// CONNECTIVITY SERVICE - THE NETWORK NERVOUS SYSTEM
/// ============================================================================
/// Provides comprehensive network awareness for the entire app:
/// - Real-time connectivity monitoring with streams
/// - Intelligent caching to prevent network hammering
/// - DNS caching for faster Supabase connections
/// - Exponential backoff retry logic
/// - Detailed status reporting for user-friendly error messages
/// - Integration points for all services (Supabase, SMS, Sync)
/// ============================================================================

/// Detailed connectivity status for precise error reporting
enum ConnectivityStatus {
  offline, // No network connection (WiFi/Mobile data off)
  noInternet, // Connected to WiFi/mobile but no internet access
  supabaseUnreachable, // Internet works but Supabase is down/blocked
  connected, // Fully connected including Supabase
  unstable, // Connection exists but too slow/unstable for sync
}

/// Network quality levels for adaptive sync behavior
enum NetworkQuality {
  excellent, // WiFi with strong signal, fast DNS
  good, // WiFi or 5G with good signal
  fair, // 4G/3G with moderate signal
  poor, // 2G/EDGE or weak signal
  none, // No connectivity
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal() {
    _startStreamMonitoring();
  }

  final Connectivity _connectivity = Connectivity();

  // ============================================================================
  // CACHING LAYERS - Prevent network hammering
  // ============================================================================

  // Internet reachability cache (medium duration)
  bool? _cachedInternetResult;
  DateTime? _internetCacheTime;
  static const _internetCacheDuration = Duration(seconds: 15);

  // Supabase-specific cache (longer duration - DNS issues persist)
  bool? _cachedSupabaseResult;
  DateTime? _supabaseCacheTime;
  static const _supabaseCacheDuration = Duration(minutes: 2);

  // DNS cache for Supabase hostname (extended duration)
  List<InternetAddress>? _supabaseDnsCache;
  DateTime? _dnsCacheTime;
  static const _dnsCacheDuration = Duration(minutes: 5);

  // Network quality cache
  NetworkQuality? _cachedNetworkQuality;
  DateTime? _qualityCacheTime;
  static const _qualityCacheDuration = Duration(seconds: 10);

  // ============================================================================
  // LIVE STREAMS - Real-time connectivity updates
  // ============================================================================

  // Broadcast controller for app-wide connectivity events
  final _connectivityController =
      StreamController<ConnectivityStatus>.broadcast();

  /// Main connectivity stream for UI components
  Stream<ConnectivityStatus> get connectivityStream =>
      _connectivityController.stream;

  // Raw connectivity result stream (for low-level monitoring)
  Stream<ConnectivityResult> get rawConnectivityStream =>
      _connectivity.onConnectivityChanged;

  // ============================================================================
  // STREAM MONITORING - Background connectivity watcher
  // ============================================================================

  StreamSubscription<ConnectivityResult>? _streamSubscription;
  ConnectivityStatus _lastStatus = ConnectivityStatus.offline;

  void _startStreamMonitoring() {
    _streamSubscription = rawConnectivityStream.listen(
      (result) {
        _onConnectivityChanged(result);
      },
      onError: (error) {
        AppLogger.logError('Connectivity: Stream error', error);
      },
      onDone: () {
        AppLogger.logWarning('Connectivity: Stream closed');
      },
    );

    AppLogger.logInfo('Connectivity: Stream monitoring started');
  }

  /// Handle connectivity changes and broadcast to all listeners
  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    // Clear caches to force fresh checks
    _clearConnectivityCache();

    // Determine new status
    final status = await getConnectivityStatus();

    // Only broadcast if status changed
    if (status != _lastStatus) {
      AppLogger.logInfo('Connectivity: Status changed to ${status.name}');
      _connectivityController.add(status);
      _lastStatus = status;

      // Clear Supabase cache on connectivity change
      clearSupabaseCache();
    }
  }

  // ============================================================================
  // PRIMARY API - Connectivity Status
  // ============================================================================

  /// Get detailed connectivity status for precise error handling
  Future<ConnectivityStatus> getConnectivityStatus() async {
    // Check hardware connectivity first
    if (!await hasInternet()) {
      return ConnectivityStatus.offline;
    }

    // Check internet quality
    final quality = await getNetworkQuality();
    if (quality == NetworkQuality.none) {
      return ConnectivityStatus.noInternet;
    }

    // Check Supabase specifically
    if (!await canReachSupabase()) {
      return ConnectivityStatus.supabaseUnreachable;
    }

    // Check if connection is stable enough for sync
    if (quality == NetworkQuality.poor) {
      return ConnectivityStatus.unstable;
    }

    return ConnectivityStatus.connected;
  }

  /// Check if device has internet access (cached with TTL)
  Future<bool> hasInternet() async {
    // Return cached result if fresh
    if (_cachedInternetResult != null &&
        _internetCacheTime != null &&
        DateTime.now().difference(_internetCacheTime!) <
            _internetCacheDuration) {
      AppLogger.logInfo(
          'Connectivity: Using cached internet status: $_cachedInternetResult');
      return _cachedInternetResult!;
    }

    // 1. Check hardware connectivity (WiFi/Mobile)
    List<ConnectivityResult> result;
    try {
      // Use try-catch with Future instead of timeout to avoid type issues
      final connectivityFuture = _connectivity.checkConnectivity();
      result = await Future.any([
        connectivityFuture,
        Future.delayed(const Duration(seconds: 2),
            () => <ConnectivityResult>[ConnectivityResult.none]),
      ]) as List<ConnectivityResult>;
    } catch (e) {
      AppLogger.logError('Connectivity: Hardware check failed', e);
      result = <ConnectivityResult>[ConnectivityResult.none];
    }

    // Check if any connectivity type is available
    final hasConnectivity = result.any((r) =>
        r != ConnectivityResult.none &&
        r != ConnectivityResult.bluetooth &&
        r != ConnectivityResult.vpn);

    AppLogger.logInfo(
        'Connectivity: Hardware check = $hasConnectivity (${result.first.name})');

    if (!hasConnectivity) {
      AppLogger.logWarning('Connectivity: No network interface detected');
      _cachedInternetResult = false;
      _internetCacheTime = DateTime.now();
      return false;
    }

    // 2. Perform DNS probe to verify actual internet access
    final dnsSuccess = await _performDnsProbe();

    if (dnsSuccess) {
      AppLogger.logInfo(
          'Connectivity: ✅ Internet available via ${result.first.name}');
      _cachedInternetResult = true;
      _internetCacheTime = DateTime.now();
      return true;
    } else {
      AppLogger.logWarning(
          'Connectivity: ${result.first.name} connected but NO INTERNET');
      _cachedInternetResult = false;
      _internetCacheTime = DateTime.now();
      return false;
    }
  }

  /// Check if Supabase is reachable (separate from general internet)
  Future<bool> canReachSupabase() async {
    // Return cached result if fresh
    if (_cachedSupabaseResult != null &&
        _supabaseCacheTime != null &&
        DateTime.now().difference(_supabaseCacheTime!) <
            _supabaseCacheDuration) {
      AppLogger.logInfo(
          'Connectivity: Using cached Supabase status: $_cachedSupabaseResult');
      return _cachedSupabaseResult!;
    }

    // Try primary Supabase URL with retry logic
    if (await _checkSupabaseUrlWithRetry(AppConstants.supabaseUrl)) {
      _cachedSupabaseResult = true;
      _supabaseCacheTime = DateTime.now();
      AppLogger.logInfo('Connectivity: ✅ Supabase reachable');
      return true;
    }

    // Try fallback URLs
    for (final fallbackUrl in AppConstants.supabaseFallbackUrls) {
      if (fallbackUrl == AppConstants.supabaseUrl)
        continue; // Skip primary (already tried)

      if (await _checkSupabaseUrlWithRetry(fallbackUrl)) {
        _cachedSupabaseResult = true;
        _supabaseCacheTime = DateTime.now();
        AppLogger.logInfo('Connectivity: ✅ Supabase reachable via fallback');
        return true;
      }
    }

    // All attempts failed
    _cachedSupabaseResult = false;
    _supabaseCacheTime = DateTime.now();
    AppLogger.logWarning(
        'Connectivity: ❌ Supabase unreachable after all attempts');
    return false;
  }

  /// Check Supabase URL with DNS caching and exponential backoff retry
  Future<bool> _checkSupabaseUrlWithRetry(String url) async {
    const maxAttempts = 3;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        // Clear DNS cache on retry to force fresh resolution
        _supabaseDnsCache = null;
        AppLogger.logInfo(
            'Connectivity: Retrying Supabase connection (attempt $attempt/$maxAttempts)');

        // Exponential backoff: 2s, 4s, 8s
        final delay = Duration(seconds: 2 * attempt);
        await Future.delayed(delay);
      }

      if (await _checkSupabaseUrl(url)) {
        return true;
      }
    }
    return false;
  }

  /// Check a single Supabase URL with DNS caching
  Future<bool> _checkSupabaseUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;

      // Step 1: Check DNS cache first
      List<InternetAddress>? dnsResult = _getDnsFromCache();

      if (dnsResult == null) {
        // DNS lookup with timeout (5 seconds for slow networks)
        try {
          dnsResult = await InternetAddress.lookup(host)
              .timeout(const Duration(seconds: 5));

          if (dnsResult.isNotEmpty && dnsResult[0].rawAddress.isNotEmpty) {
            _cacheDnsResult(dnsResult);
            AppLogger.logInfo(
                'Connectivity: DNS resolved for $host -> ${dnsResult[0].address}');
          } else {
            AppLogger.logInfo(
                'Connectivity: DNS lookup returned empty for $host');
            return false;
          }
        } on SocketException catch (e) {
          AppLogger.logInfo(
              'Connectivity: DNS socket error for $host: ${e.message}');
          return false;
        } on TimeoutException {
          AppLogger.logWarning('Connectivity: DNS lookup timed out for $host');
          return false;
        }
      } else {
        AppLogger.logInfo('Connectivity: Using cached DNS for $host');
      }

      // Step 2: HTTP health check
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      try {
        final request = await client.getUrl(uri).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.logWarning(
                'Connectivity: HTTP request timed out for $host');
            throw TimeoutException('HTTP request timeout');
          },
        );

        final response = await request.close();

        if (response.statusCode >= 200 && response.statusCode < 400) {
          AppLogger.logInfo(
              'Connectivity: Supabase health check passed for $host (status: ${response.statusCode})');
          return true;
        }

        // Any response (even 4xx/5xx) means reachable
        AppLogger.logInfo(
            'Connectivity: Supabase returned status ${response.statusCode} for $host');
        return true;
      } on SocketException catch (e) {
        AppLogger.logInfo('Connectivity: HTTP failed for $host: ${e.message}');
        return false;
      } on TimeoutException {
        AppLogger.logWarning('Connectivity: HTTP check timed out for $host');
        return false;
      } finally {
        client.close();
      }
    } catch (e) {
      AppLogger.logWarning('Connectivity: Supabase check error: $e');
      return false;
    }
  }

  /// DNS Probe with multiple endpoints for reliability
  Future<bool> _performDnsProbe() async {
    // Try domain names first, then IP addresses
    final endpoints = [
      ('google.com', null),
      ('cloudflare.com', null),
      ('1.1.1.1', '1.1.1.1'),
      ('8.8.8.8', '8.8.8.8'),
    ];

    for (final endpoint in endpoints) {
      final name = endpoint.$1;
      final ip = endpoint.$2;

      try {
        final result = ip != null
            ? await InternetAddress.lookup(ip)
                .timeout(const Duration(seconds: 3))
            : await InternetAddress.lookup(name)
                .timeout(const Duration(seconds: 3));

        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          AppLogger.logInfo('Connectivity: DNS probe successful via $name');
          return true;
        }
      } on SocketException catch (e) {
        AppLogger.logInfo(
            'Connectivity: DNS probe failed for $name - ${e.message}');
        continue;
      } on TimeoutException {
        AppLogger.logWarning('Connectivity: DNS probe timeout for $name');
        continue;
      } catch (e) {
        AppLogger.logWarning('Connectivity: DNS probe error for $name: $e');
        continue;
      }
    }

    AppLogger.logWarning('Connectivity: All DNS probes failed');
    return false;
  }

  // ============================================================================
  // NETWORK QUALITY ASSESSMENT
  // ============================================================================

  /// Assess network quality for adaptive sync behavior
  Future<NetworkQuality> getNetworkQuality() async {
    // Return cached result if fresh
    if (_cachedNetworkQuality != null &&
        _qualityCacheTime != null &&
        DateTime.now().difference(_qualityCacheTime!) < _qualityCacheDuration) {
      return _cachedNetworkQuality!;
    }

    // Check connectivity type first
    List<ConnectivityResult> result;
    try {
      // Use try-catch with Future instead of timeout to avoid type issues
      final connectivityFuture = _connectivity.checkConnectivity();
      result = await Future.any([
        connectivityFuture,
        Future.delayed(const Duration(seconds: 2),
            () => <ConnectivityResult>[ConnectivityResult.none]),
      ]) as List<ConnectivityResult>;
    } catch (e) {
      result = <ConnectivityResult>[ConnectivityResult.none];
    }

    if (result.isEmpty || result.first == ConnectivityResult.none) {
      _cachedNetworkQuality = NetworkQuality.none;
      _qualityCacheTime = DateTime.now();
      return NetworkQuality.none;
    }

    // Measure latency to assess quality
    final latency = await _measureLatency();

    NetworkQuality quality;
    if (latency < 50) {
      quality = NetworkQuality.excellent;
    } else if (latency < 150) {
      quality = NetworkQuality.good;
    } else if (latency < 300) {
      quality = NetworkQuality.fair;
    } else {
      quality = NetworkQuality.poor;
    }

    _cachedNetworkQuality = quality;
    _qualityCacheTime = DateTime.now();

    AppLogger.logInfo(
        'Connectivity: Network quality = ${quality.name} (${latency}ms)');
    return quality;
  }

  /// Measure network latency using DNS lookup timing
  Future<int> _measureLatency() async {
    final stopwatch = Stopwatch();

    try {
      stopwatch.start();
      await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      stopwatch.stop();
      return 999; // High latency on error
    }
  }

  // ============================================================================
  // DNS CACHE MANAGEMENT
  // ============================================================================

  /// Get DNS result from cache
  List<InternetAddress>? _getDnsFromCache() {
    if (_supabaseDnsCache != null &&
        _dnsCacheTime != null &&
        DateTime.now().difference(_dnsCacheTime!) < _dnsCacheDuration) {
      return _supabaseDnsCache;
    }
    return null;
  }

  /// Cache DNS result
  void _cacheDnsResult(List<InternetAddress> addresses) {
    _supabaseDnsCache = addresses;
    _dnsCacheTime = DateTime.now();
  }

  /// Clear DNS cache
  void clearDnsCache() {
    _supabaseDnsCache = null;
    _dnsCacheTime = null;
    AppLogger.logInfo('Connectivity: DNS cache cleared');
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  /// Clear connectivity cache
  void _clearConnectivityCache() {
    _cachedInternetResult = null;
    _internetCacheTime = null;
    _cachedNetworkQuality = null;
    _qualityCacheTime = null;
  }

  /// Clear Supabase-specific cache
  void clearSupabaseCache() {
    _cachedSupabaseResult = null;
    _supabaseCacheTime = null;
    clearDnsCache();
    AppLogger.logInfo('Connectivity: Supabase cache cleared');
  }

  /// Clear all caches
  void clearCache() {
    _clearConnectivityCache();
    clearSupabaseCache();
    AppLogger.logInfo('Connectivity: All caches cleared');
  }

  /// Force refresh connectivity (ignores cache)
  Future<bool> refreshConnectivity() async {
    clearCache();
    return await hasInternet();
  }

  // ============================================================================
  // WAIT FOR STABLE CONNECTION
  // ============================================================================

  /// Wait for stable Supabase connection with retries
  Future<bool> waitForStableSupabase({
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        clearDnsCache();
        AppLogger.logInfo(
            'Connectivity: Retrying Supabase connection (attempt $attempt/$maxAttempts)');
      }

      if (await canReachSupabase()) {
        return true;
      }

      if (attempt < maxAttempts) {
        await Future.delayed(delay * attempt);
      }
    }

    AppLogger.logWarning(
        'Connectivity: Supabase unreachable after $maxAttempts attempts');
    return false;
  }

  /// Wait for any internet connection with retries
  Future<bool> waitForInternet({
    int maxAttempts = 5,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        AppLogger.logInfo(
            'Connectivity: Retrying internet check (attempt $attempt/$maxAttempts)');
      }

      if (await hasInternet()) {
        return true;
      }

      if (attempt < maxAttempts) {
        await Future.delayed(delay);
      }
    }

    AppLogger.logWarning(
        'Connectivity: No internet after $maxAttempts attempts');
    return false;
  }

  // ============================================================================
  // USER-FRIENDLY ERROR MESSAGES
  // ============================================================================

  /// Get user-friendly connectivity error message
  Future<String> getConnectivityErrorMessage() async {
    final status = await getConnectivityStatus();

    switch (status) {
      case ConnectivityStatus.offline:
        return 'No internet connection. Please check your WiFi or mobile data settings.';
      case ConnectivityStatus.noInternet:
        return 'Connected to network but no internet access. Check your router or data plan.';
      case ConnectivityStatus.supabaseUnreachable:
        return 'Internet works but cannot reach Pesa Budget servers. This may be due to:\n\n• Network firewall blocking access\n• ISP DNS issues\n• Temporary server maintenance\n\nYour data is safe locally. Try again later or switch to a different network.';
      case ConnectivityStatus.unstable:
        return 'Connection is unstable. Transactions will be saved locally and synced when connection improves.';
      case ConnectivityStatus.connected:
        return '';
    }
  }

  /// Check if device is completely offline
  Future<bool> isOffline() async {
    return !(await hasInternet());
  }

  /// Check if Supabase specifically is unreachable
  Future<bool> isSupabaseUnreachable() async {
    if (!await hasInternet()) return false;
    return !(await canReachSupabase());
  }

  /// Check if connection is stable enough for sync operations
  Future<bool> isConnectionStableForSync() async {
    final quality = await getNetworkQuality();
    return quality != NetworkQuality.none && quality != NetworkQuality.poor;
  }

  // ============================================================================
  // STREAM BROADCAST HELPERS
  // ============================================================================

  /// Broadcast connectivity status change
  void broadcastStatus(ConnectivityStatus status) {
    if (_lastStatus != status) {
      _connectivityController.add(status);
      _lastStatus = status;
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Dispose resources
  void dispose() {
    _streamSubscription?.cancel();
    _connectivityController.close();
    AppLogger.logInfo('Connectivity: Service disposed');
  }
}
