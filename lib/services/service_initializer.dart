import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/services/connectivity_service.dart';

/// The Silent Foundation.
/// This class handles ONLY the hardware/data connections required to show the UI.
/// Heavy lifting (Permissions/Background Services) is deferred to the Dashboard
/// to ensure a smooth, professional user experience.
class ServiceInitializer {
  static final ServiceInitializer _instance = ServiceInitializer._internal();
  factory ServiceInitializer() => _instance;
  ServiceInitializer._internal();

  final _connectivityService = ConnectivityService();

  /// The Silent Boot Sequence
  /// Call this in main.dart - returns immediately to avoid blocking UI
  void initializeApp() {
    // Return immediately to let main.dart call runApp()
    _performBackgroundBoot();
  }

  /// Background initialization - runs asynchronously without blocking UI
  Future<void> _performBackgroundBoot() async {
    try {
      AppLogger.logInfo("System: Initializing Background Boot...");

      // 1. Initialize Local Database (in background)
      final db = DatabaseHelper();
      await db.database;
      AppLogger.logSuccess("System: Local Ledger Engine Ready.");

      // YIELD: Let the UI thread render frames
      await Future.delayed(Duration.zero);

      // 2. Network Awareness Check (using ConnectivityService)
      // This pre-warms the connectivity cache and DNS resolution
      try {
        final hasInternet = await _connectivityService.hasInternet();
        final quality = await _connectivityService.getNetworkQuality();
        AppLogger.logInfo(
            "System: Network check complete - Internet: $hasInternet, Quality: ${quality.name}");

        // Pre-warm Supabase DNS cache (don't wait for result)
        _connectivityService.canReachSupabase().then((reachable) {
          if (reachable) {
            AppLogger.logSuccess("System: Supabase DNS pre-warmed");
          } else {
            AppLogger.logWarning(
                "System: Supabase DNS pre-warm failed (will retry later)");
          }
        });
      } catch (e) {
        AppLogger.logWarning(
            "System: Network check failed (non-critical) - $e");
      }

      // YIELD: Let the UI thread render frames
      await Future.delayed(Duration.zero);

      AppLogger.logSuccess("System: Background Boot Complete.");
    } catch (e, stack) {
      AppLogger.logError("System: Background Boot Failure", e, stack);
    }
  }

  /// Cleanup resources
  void dispose() {
    _connectivityService.dispose();
    AppLogger.logInfo("System: ServiceInitializer disposed");
  }
}
