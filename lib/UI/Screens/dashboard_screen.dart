import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/services/sms_service.dart';
import 'package:transaction_app/services/service_coordinator.dart';
import 'package:transaction_app/services/category_cache.dart';
import 'package:transaction_app/services/connectivity_service.dart';
import 'package:transaction_app/services/hardware_capabilities.dart';
import 'package:transaction_app/ui/widgets/offline_banner.dart';
import 'package:transaction_app/ui/widgets/account_card.dart';
import 'package:transaction_app/ui/widgets/app_drawer.dart';
import 'package:transaction_app/ui/screens/account_creation_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _sessionRepo = SessionRepository();
  final _smsService = SmsService();
  final _dbHelper = DatabaseHelper();
  final _coordinator = ServiceCoordinator();
  final _connectivityService = ConnectivityService();
  final _hardware = HardwareCapabilities();

  late String _currentMode;
  bool _hasUserInteracted = false;

  // FIX: Track SMS sync status for progress indicator
  bool _isSyncing = false;

  // Connectivity status for UI updates
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  // Account Categories - Will be loaded from database
  List<Map<String, dynamic>> _categoriesData = [];
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Track expanded state for each account (resets on swipe)
  final Map<int, bool> _expandedState = {};

  // Track if PageView swipe should be locked (when detail view is expanded)
  bool _isPageViewLocked = false;

  // Stream subscription for background sync complete
  StreamSubscription<bool>? _backgroundSub;
  StreamSubscription<int>? _syncSub; // FIX: Subscribe to SMS sync stream

  // FIX 1: Cache for categories to prevent redundant database queries
  List<Map<String, dynamic>>? _categoriesCache;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 2);

  // FIX 2: Query deduplication - prevent redundant DB calls within debounce window
  DateTime? _lastQueryTime;
  static const _queryDebounce = Duration(milliseconds: 300);

  // FIX 3: Optimistic UI - track if we're showing cached data during swipe
  bool _isLoadingFreshData = false;

  // FIX 4: Debouncer for refresh operations
  Timer? _refreshDebouncer;
  static const _refreshDebounceDuration = Duration(milliseconds: 100);

  /// Lock or unlock PageView swiping
  void _lockPageView(bool lock) {
    setState(() => _isPageViewLocked = lock);
  }

  @override
  void initState() {
    super.initState();
    _currentMode = _sessionRepo.activeAccountMode;

    // Listen to connectivity changes for real-time UI updates
    _connectivitySub = _connectivityService.connectivityStream.listen((status) {
      if (mounted) {
        _handleConnectivityChange(status);
      }
    });

    // ========================================================================
    // FRAME-PERFECT INITIALIZATION - Prevents 768 skipped frames
    // ========================================================================
    // Strategy: Let the first frame render COMPLETELY before any heavy work.
    // Each phase yields back to the UI thread to maintain 60 FPS.
    // ========================================================================
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Phase 1: Load categories AFTER first frame (16ms delay for frame buffer)
      // This ensures the empty dashboard shell renders first
      Future.delayed(const Duration(milliseconds: 16), () {
        if (!mounted) return;
        _loadCategories();

        // Phase 2: Service initialization (100ms - UI is stable by now)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          _initializeEventDrivenSequence();

          // Phase 3: Permission checks (300ms - user is looking at UI now)
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            _checkAndRequestPermissions();

            // Phase 4: SMS sync (500ms - everything else is stable)
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!mounted) return;
              _prewarmDatabaseInBackground();
            });
          });
        });
      });
    });

    // FIX: Subscribe to SMS sync stream to show progress indicator
    _syncSub = _smsService.syncStream.listen((count) {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    });
  }

  @override
  void dispose() {
    _backgroundSub?.cancel();
    _syncSub?.cancel(); // FIX: Cancel sync subscription
    _connectivitySub?.cancel(); // Cancel connectivity subscription
    _refreshDebouncer?.cancel(); // FIX: Cancel debouncer
    _pageController.dispose();
    _connectivityService.dispose();
    super.dispose();
  }

  /// ============================================================================
  /// DATABASE PRE-WARM (Background Isolate)
  /// ============================================================================
  /// Runs database pre-warm in a background isolate to prevent UI jank.
  /// This is called 500ms after startup when the UI is fully stable.
  /// ============================================================================
  Future<void> _prewarmDatabaseInBackground() async {
    // Use compute() to run in background isolate
    await compute((_) async {
      await DatabaseHelper.preWarm();
      AppLogger.logInfo('Dashboard: Database pre-warmed in background isolate');
      return true;
    }, null);
  }

  /// ============================================================================
  /// EVENT-DRIVEN INITIALIZATION SEQUENCE
  /// ============================================================================
  /// This sets up the event-driven chain:
  /// 1. Dashboard loads (UI rendered)
  /// 2. Check Android version (9-11 vs 12+)
  /// 3. Android 9-11: Start Foreground Immediately
  ///    Android 12+: Wait for user interaction (tap, scroll, etc.)
  /// 4. Foreground stable → Background sync starts automatically
  /// 5. Background complete → Trigger Supabase
  /// 6. Supabase ready → Warm Overlay Engine
  /// ============================================================================
  Future<void> _initializeEventDrivenSequence() async {
    // Run initialization in background to prevent blocking UI thread
    await Future.microtask(() async {
      AppLogger.logInfo('Dashboard: Event-driven sequence initialized');

      // Initialize service coordinator (checks Android version)
      await _coordinator.initialize();

      // FIX: Listen to foreground stable stream BEFORE starting SMS sync
      // This ensures foreground service is fully running before SMS sync starts
      _coordinator.foregroundStableStream.listen((stable) {
        if (stable) {
          AppLogger.logInfo(
              'Dashboard: Foreground stable - SMS sync can now start safely');
          // SMS sync will be triggered by permission check
        }
      });

      // Listen for background sync complete event (triggers Supabase)
      _backgroundSub = _coordinator.backgroundCompleteStream.listen((_) {
        AppLogger.logInfo(
            'Dashboard: Background sync complete - initializing Supabase');
        _initializeSupabase();
      });

      // FIX: Listen to SMS service sync stream to refresh totals after SMS sync
      _smsService.syncStream.listen((count) {
        AppLogger.logInfo(
            'Dashboard: SMS sync complete ($count transactions) - refreshing totals');
        // Refresh categories to update totals
        _refreshCategoriesAndTotals();
      });

      // If user already interacted (e.g., came from PIN creation), ensure services start
      if (_coordinator.hasUserInteracted && !_coordinator.isForegroundStarted) {
        AppLogger.logInfo(
            'Dashboard: User already interacted - ensuring services start');
        _coordinator.markUserInteraction();
      } else if (!_coordinator.isAndroid12Plus) {
        AppLogger.logInfo(
            'Dashboard: Android 9-11 - services starting automatically');
      } else {
        AppLogger.logInfo(
            'Dashboard: Android 12+ - waiting for user interaction to start services');
      }
    });
  }

  /// ============================================================================
  /// USER INTERACTION DETECTOR
  /// ============================================================================
  /// Call this on first user interaction (tap, scroll, etc.)
  /// Android 9-11: No-op (service already started)
  /// Android 12+: Triggers Foreground Service to start
  /// ============================================================================
  void _onUserInteraction() {
    if (_hasUserInteracted) return; // Already triggered

    _hasUserInteracted = true;
    AppLogger.logInfo('Dashboard: First user interaction detected');

    // Trigger the service coordinator to start foreground service
    _coordinator.markUserInteraction();
  }

  /// ============================================================================
  /// CONNECTIVITY CHANGE HANDLER
  /// ============================================================================
  /// Handles connectivity status changes and triggers appropriate actions
  /// ============================================================================
  void _handleConnectivityChange(ConnectivityStatus status) {
    switch (status) {
      case ConnectivityStatus.offline:
        AppLogger.logWarning('Dashboard: Device went offline');
        // Show snackbar or update UI to indicate offline status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('No internet connection. Data saved locally.'),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 3),
            ),
          );
        }
        break;

      case ConnectivityStatus.noInternet:
        AppLogger.logWarning(
            'Dashboard: WiFi/Mobile connected but no internet');
        break;

      case ConnectivityStatus.supabaseUnreachable:
        AppLogger.logWarning('Dashboard: Supabase unreachable');
        break;

      case ConnectivityStatus.unstable:
        AppLogger.logWarning('Dashboard: Connection unstable');
        break;

      case ConnectivityStatus.connected:
        AppLogger.logSuccess('Dashboard: Connection restored');
        // Trigger sync if we were offline before
        if (_coordinator.isSupabaseInitialized) {
          _refreshCategoriesAndTotals();
        }
        break;
    }
  }

  /// Load categories from database - ensures 'General' is first
  /// Also populates the shared CategoryCache for all widgets
  Future<void> _loadCategories() async {
    // FIX 1: Check cache first to prevent redundant database queries
    final now = DateTime.now();
    if (_categoriesCache != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheDuration) {
      // Use cached data
      setState(() {
        _categoriesData = _categoriesCache!;
      });
      AppLogger.logInfo(
          'Dashboard: Using cached categories (${_categoriesData.length} items)');
      // Also update shared cache
      CategoryCache().loadCategories();
      return;
    }

    // FIX 2: Query deduplication - skip if called within debounce window
    if (_lastQueryTime != null &&
        now.difference(_lastQueryTime!) < _queryDebounce) {
      AppLogger.logInfo(
          'Dashboard: Query skipped (debounce active, ${now.difference(_lastQueryTime!).inMilliseconds}ms)');
      return;
    }
    _lastQueryTime = now;

    try {
      final categoriesData = await _dbHelper.getAllCategoriesWithDetails();

      // Convert to mutable list (query results are read-only)
      var categoryList = List<Map<String, dynamic>>.from(categoriesData);

      // Find and move 'General' to index 0
      final generalIndex =
          categoryList.indexWhere((c) => c['name'] == 'General');
      if (generalIndex > 0) {
        final general = categoryList.removeAt(generalIndex);
        categoryList.insert(0, general);
      }

      setState(() {
        _categoriesData = categoryList;
        // Update cache
        _categoriesCache = categoryList;
        _cacheTimestamp = now;
      });

      // Populate shared CategoryCache for all widgets
      CategoryCache().loadCategories();

      AppLogger.logInfo(
          'Dashboard: Loaded ${_categoriesData.length} categories (General first)');
    } catch (e, stackTrace) {
      AppLogger.logError('Dashboard: Failed to load categories: $e');
      AppLogger.logError('Stack trace: $stackTrace');
      setState(() {
        _categoriesData = [];
      });
    }
  }

  /// ============================================================================
  /// REFRESH CATEGORIES AND TOTALS (Called after SMS sync or account changes)
  /// ============================================================================
  /// This forces a complete refresh of categories and triggers balance
  /// recalculation for all AccountCard widgets.
  /// FIX: Uses debouncing to prevent duplicate fetches
  /// ============================================================================
  Future<void> _refreshCategoriesAndTotals() async {
    if (!mounted) return;

    // FIX: Cancel any pending refresh
    _refreshDebouncer?.cancel();

    // Debounce refresh - wait 100ms before actually refreshing
    _refreshDebouncer = Timer(_refreshDebounceDuration, () {
      if (!mounted) return;

      // Clear cache to force fresh data
      _categoriesCache = null;
      _cacheTimestamp = null;

      // Reload categories
      _loadCategories();

      // Refresh CategoryCache (notifies all listeners)
      CategoryCache().refreshCategories();

      AppLogger.logInfo(
          'Dashboard: Categories and totals refreshed (debounced)');
    });

    AppLogger.logInfo('Dashboard: Refresh debounced (100ms)');
  }

  /// ============================================================================
  /// SUPABASE INITIALIZATION (Triggered by Background Sync Complete event)
  /// ============================================================================
  Future<void> _initializeSupabase() async {
    await _coordinator.initializeSupabase();

    // After Supabase is ready, warm the overlay engine
    _coordinator.markOverlayWarm();
    AppLogger.logSuccess('Dashboard: Event-driven sequence COMPLETE');
  }

  /// ============================================================================
  /// SMS PERMISSION CHECK & REQUEST
  /// ============================================================================
  /// Checks SMS permission and shows dialog if not granted.
  /// SMS sync only runs ONCE after first-time install (not on every launch).
  /// ============================================================================
  Future<void> _checkAndRequestPermissions() async {
    final smsStatus = await Permission.sms.status;

    if (smsStatus != PermissionStatus.granted) {
      AppLogger.logWarning(
          'Dashboard: SMS permission not granted - showing dialog');
      _showPermissionDialog();
    } else {
      AppLogger.logInfo('Dashboard: SMS permission already granted');
      // Only sync SMS on first-time initialization (not on every app launch)
      if (!_sessionRepo.hasCompletedInitialSmsSync) {
        AppLogger.logInfo(
            'Dashboard: Running initial SMS sync (first-time only)');
        // FIX: Set syncing flag to show progress indicator
        setState(() => _isSyncing = true);
        await _smsService.syncInbox();
        _sessionRepo.markInitialSmsSyncCompleted();
      } else {
        AppLogger.logInfo(
            'Dashboard: Initial SMS sync already completed - skipping');
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2ECC71), width: 1),
        ),
        title: const Text(
          'SMS Permission Required',
          style: TextStyle(
            color: Color(0xFF2ECC71),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'To track M-PESA transactions, Pesa Budget needs permission to read SMS messages.\n\n'
          'Your messages are processed locally and never sent to the cloud.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AppLogger.logWarning('Dashboard: User denied SMS permission');
            },
            child: const Text(
              'Not Now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestSmsPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();

    if (status.isGranted) {
      AppLogger.logSuccess('Dashboard: SMS permission granted');
      // Run initial sync only if not completed before
      if (!_sessionRepo.hasCompletedInitialSmsSync) {
        // FIX: Set syncing flag to show progress indicator
        setState(() => _isSyncing = true);
        await _smsService.syncInbox();
        _sessionRepo.markInitialSmsSyncCompleted();
      }
    } else if (status.isPermanentlyDenied) {
      AppLogger.logError('Dashboard: SMS permission permanently denied');
      _showSettingsDialog();
    } else {
      AppLogger.logWarning('Dashboard: SMS permission denied');
      _showPermissionDialog(); // Show again
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D1A),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Color(0xFF2ECC71)),
        ),
        content: const Text(
          'SMS permission is permanently denied. Please enable it in Settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _toggleMode() async {
    _onUserInteraction(); // Trigger service start on first interaction
    final newMode = _currentMode == 'Personal' ? 'Business' : 'Personal';
    await _sessionRepo.toggleAccountMode(newMode);
    setState(() {
      _currentMode = newMode;
    });
    AppLogger.logInfo('Dashboard: Switched to $newMode Mode');
  }

  void _showAccountCreation() async {
    _onUserInteraction(); // Trigger service start on first interaction
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountCreationSheet(
        onAccountCreated: (newCategory) {
          AppLogger.logInfo('Dashboard: New account created: $newCategory');
        },
      ),
    );

    if (result != null) {
      // FIX: Invalidate cache and debounce timer when new account is created
      _categoriesCache = null;
      _cacheTimestamp = null;
      _lastQueryTime = null;

      // Reload categories and wait for build to complete
      await _loadCategories();
      AppLogger.logSuccess('Dashboard: Account "$result" added successfully');

      // FIX: Use addPostFrameCallback to ensure PageView has rebuilt with new itemCount
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final newIndex = _categoriesData.indexWhere((c) => c['name'] == result);
        if (newIndex >= 0 && newIndex < _categoriesData.length) {
          // Update current page to avoid out-of-bounds
          setState(() {
            _currentPage = newIndex;
          });

          // Animate to new page after build completes
          _pageController.animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          AppLogger.logInfo(
              'Dashboard: Navigated to new account at index $newIndex');
        }
      });
    }
  }

  /// Reset expanded state when user swipes to a new card
  /// FIX: Optimistic UI - show cached data immediately, refresh in background
  /// FIX 2: Only fetch if cache is empty or for new category
  void _onPageChanged(int index) {
    _onUserInteraction(); // Trigger service start on first scroll

    setState(() {
      _currentPage = index;
      // Reset ALL expanded states when swiping
      _expandedState.clear();
    });

    final categoryName = _categoriesData.isNotEmpty
        ? _categoriesData[index]['name'] as String?
        : 'Unknown';

    AppLogger.logInfo('Dashboard: Swiped to account $index ($categoryName)');

    // FIX: Only refresh if cache is empty or invalid
    // Don't fetch on every swipe - let AccountCard use cached data
    final categoryCache = CategoryCache();
    if (!_isLoadingFreshData && !categoryCache.isValid) {
      _isLoadingFreshData = true;

      // Use microtask to avoid blocking the swipe animation
      Future.microtask(() async {
        try {
          // Small delay to let swipe animation complete
          await Future.delayed(const Duration(milliseconds: 50));
          await _loadCategories();
        } finally {
          _isLoadingFreshData = false;
        }
      });
    } else {
      AppLogger.logInfo(
          'Dashboard: Using cached data for swipe (no fetch needed)');
    }
  }

  /// Toggle expanded state for a specific account
  void _toggleExpanded(int index) {
    setState(() {
      _expandedState[index] = !(_expandedState[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hardware-aware rendering
    final isLowEnd = _hardware.isLowEndDevice;
    final deviceTier = _hardware.deviceTier;

    AppLogger.logInfo(
        'Dashboard: Building UI - Device tier: ${deviceTier.name}, Low-end: $isLowEnd');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0C),
      drawer: AppDrawer(), // Hamburger menu
      body: SafeArea(
        child: Column(
          children: [
            // Header with Mode Switch
            _buildHeader(),

            // FIX: Sync Progress Indicator
            if (_isSyncing)
              const LinearProgressIndicator(
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF2ECC71),
                ),
                minHeight: 3,
              ),

            // Offline Banner
            const OfflineBanner(),

            // Page Indicator Dots
            _buildPageIndicator(),

            // PageView - Full area below header
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _categoriesData.length,
                onPageChanged: _onPageChanged,
                // Lock swiping when detail view is expanded
                physics: _isPageViewLocked
                    ? const NeverScrollableScrollPhysics()
                    : _hardware.shouldDisableAnimations
                        ? const ClampingScrollPhysics()
                        : const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final categoryData = _categoriesData[index];
                  return AccountCard(
                    category: categoryData['name'] as String,
                    categoryColor: categoryData['color_value'] as int,
                    categoryIcon: categoryData['icon_data'] as String,
                    accountMode: _currentMode,
                    index: index,
                    pageController: _pageController,
                    onResetToShell: () => _toggleExpanded(index),
                    onExpandedChanged: _lockPageView,
                    currentPage:
                        _currentPage, // FIX: Pass current page for lazy loading
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Account Creation FAB (Bottom Left)
          FloatingActionButton(
            heroTag: "addAccount",
            onPressed: _showAccountCreation,
            backgroundColor: const Color(0xFF2ECC71),
            // Simplified elevation for low-end devices
            elevation: isLowEnd ? 0 : 8,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Mode Switch FAB (Bottom Right)
          FloatingActionButton(
            heroTag: "switchMode",
            onPressed: _toggleMode,
            backgroundColor: const Color(0xFF141D1A),
            child: Text(
              _currentMode == 'Personal' ? 'B' : 'P',
              style: const TextStyle(
                color: Color(0xFF2ECC71),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hamburger Menu + Title
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF2ECC71)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pesa Budget",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF2ECC71),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "$_currentMode Account",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action Buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF2ECC71)),
                onPressed: () {
                  // FIX: Reset cache and debounce timer for explicit refresh
                  _categoriesCache = null;
                  _cacheTimestamp = null;
                  _lastQueryTime = null;
                  _loadCategories();
                  AppLogger.logInfo('Dashboard: UI refreshed (cache cleared)');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_categoriesData.length, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2ECC71)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
