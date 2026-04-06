import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';
import 'package:transaction_app/ui/screens/pin_lock_screen.dart';
import 'package:transaction_app/ui/screens/pin_creation_page.dart';
import 'package:transaction_app/ui/screens/dashboard_screen.dart';

/// ============================================================================
/// AUTH WRAPPER - REACTIVE ROUTING LOGIC
/// ============================================================================
/// This widget determines which screen to show based on app state:
/// 1. System Loading → SessionRepository initializing
/// 2. PIN Creation → First-time user (no PIN set)
/// 3. PIN Lock → Has PIN, needs verification for this session
/// 4. Dashboard → Authenticated or silent login
///
/// CRITICAL: Uses ValueListenableBuilder to react to session changes
/// ============================================================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final SessionRepository _sessionRepo = SessionRepository();
  bool _isSystemReady = false;

  // Session authentication flag
  // Reset when app is backgrounded, set when PIN verified
  bool _isSessionAuthenticated = false;

  // FIX: Track navigation state to prevent race conditions
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waitForSystem();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset session auth when app is backgrounded
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      AppLogger.logInfo("AuthWrapper: App paused - locking session");
      setState(() => _isSessionAuthenticated = false);
    }

    // Rebuild when app resumes
    if (state == AppLifecycleState.resumed) {
      AppLogger.logInfo("AuthWrapper: App resumed");
      setState(() {});
    }
  }

  /// Wait for SessionRepository to finish initialization
  Future<void> _waitForSystem() async {
    while (!_sessionRepo.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() => _isSystemReady = true);
    }
  }

  /// Determine which screen to show
  Widget _determineScreen() {
    // FIX: Prevent navigation during transition
    if (_isNavigating) {
      AppLogger.logInfo(
          'AuthWrapper: Navigation in progress - showing loading');
      return const _SystemLoadingScreen();
    }

    final bool isFirstTime = _sessionRepo.isFirstTimeUser;
    final bool hasPin = _sessionRepo.hasCreatedPin;
    final bool isLoggedIn = _sessionRepo.isLoggedIn;

    AppLogger.logInfo(
        'AuthWrapper Routing: FirstTime=$isFirstTime, HasPin=$hasPin, LoggedIn=$isLoggedIn, SessionAuth=$_isSessionAuthenticated');

    // ROUTE 1: First-time user → PIN Creation
    if (isFirstTime && !hasPin) {
      AppLogger.logInfo('→ PIN Creation (First-time user)');
      return const PinCreationPage();
    }

    // ROUTE 2: Has PIN but session not authenticated → PIN Lock
    // This is the MOST COMMON case after first launch
    if (hasPin && !_isSessionAuthenticated) {
      AppLogger.logInfo('→ PIN Lock Screen (Session requires verification)');
      return PinLockScreen(
        onVerified: () {
          // FIX: Set navigation flag to prevent race conditions
          if (_isNavigating) return;
          _isNavigating = true;

          // Schedule state update for after pop completes
          // This prevents navigation conflicts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isSessionAuthenticated = true;
                _isNavigating = false;
              });
            }
          });
        },
      );
    }

    // ROUTE 3: Authenticated session → Dashboard
    // This shows after PIN is verified and state is updated
    if (hasPin && _isSessionAuthenticated) {
      AppLogger.logInfo('→ Dashboard (Authenticated session)');
      return const DashboardScreen();
    }

    // ROUTE 4: Has PIN, logged out (user explicitly logged out) → Dashboard with silent login
    if (hasPin && !isLoggedIn) {
      AppLogger.logInfo('→ Dashboard (Silent login after logout)');
      _sessionRepo.setLoginStatus(true);
      setState(() {
        _isSessionAuthenticated = true;
      });
      return const DashboardScreen();
    }

    // FALLBACK: Dashboard
    AppLogger.logInfo('→ Dashboard (Fallback)');
    return const DashboardScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while system initializes
    if (!_isSystemReady) {
      return const _SystemLoadingScreen();
    }

    // Route to appropriate screen
    return _determineScreen();
  }
}

/// ============================================================================
/// SYSTEM LOADING SCREEN
/// ============================================================================
/// Lightweight loading screen shown during initial boot (first 300ms)
/// ============================================================================
class _SystemLoadingScreen extends StatelessWidget {
  const _SystemLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0C),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF2ECC71),
              strokeWidth: 2,
            ),
            const SizedBox(height: 24),
            Text(
              "PESA BUDGET",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 2,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
