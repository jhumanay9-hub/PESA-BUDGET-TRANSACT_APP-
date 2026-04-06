import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/services/service_initializer.dart';
import 'package:transaction_app/services/hardware_capabilities.dart';
import 'package:transaction_app/data/session_repository.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/ui/auth_wrapper.dart';
import 'package:transaction_app/core/theme.dart';
import 'package:transaction_app/ui/widgets/transaction_overlay_ui.dart';
import 'package:transaction_app/ui/screens/settings_page.dart';
import 'package:transaction_app/ui/screens/security_page.dart';
import 'package:transaction_app/ui/screens/pin_creation_page.dart';
import 'package:transaction_app/ui/screens/dashboard_screen.dart';
import 'package:transaction_app/ui/screens/permission_manager_screen.dart';

// ============================================================================
// ENGINE 1: THE OVERLAY ISOLATE (Unchanged - Specialized Hardware Isolate)
// ============================================================================
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PesaBudgetTheme.darkgreenTheme,
      home: const TransactionOverlayUI(),
    ),
  );
}

// ============================================================================
// ENGINE 2: THE MAIN APPLICATION - FRAME-PERFECT BOOT
// ============================================================================
void main() async {
  // 1. Hardware Binding (Sync call - very fast, <1ms)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. FONT PRELOADING (Prevents first-frame jank)
  // Load Poppins font into memory before first frame render
  await _preloadFonts();

  // 3. BOOT IMMEDIATELY - Local First!
  // We launch the UI immediately without waiting for any network or heavy services.
  // The app works 100% offline first - cloud sync happens LAST in background.
  runApp(const PesaBudgetApp());

  // 4. STAGED BACKGROUND BOOT - Local services only (no Supabase yet!)
  // This fires AFTER the UI is painted on the screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _performStagedBoot();
  });
}

/// Preload fonts to prevent first-frame jank
/// This runs BEFORE runApp() to ensure fonts are ready for first render
Future<void> _preloadFonts() async {
  try {
    // Load Poppins font files into memory
    // This prevents the font loader from blocking the UI thread during first render
    final fontFutures = [
      rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
      rootBundle.load('assets/fonts/Poppins-Medium.ttf'),
      rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
      rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'),
    ];

    await Future.wait(fontFutures);
    AppLogger.logInfo('System: Fonts preloaded');
  } catch (e) {
    // Font preload failed - not critical, Flutter will load on demand
    AppLogger.logWarning('Font preload failed (non-critical): $e');
  }
}

/// The "Emerald Protocol" Boot Logic - LOCAL FIRST!
/// Sequence: Session → Database → (Stop! No network yet)
/// Supabase & Background services start from Dashboard AFTER user is onboarded.
Future<void> _performStagedBoot() async {
  try {
    // Stage A: Give the UI 16ms to finish first frame (prevents 600 frames skipped)
    await Future.delayed(const Duration(milliseconds: 16));

    // Stage B: Essential Session Data (Local only - works offline)
    final sessionRepo = SessionRepository();
    await sessionRepo.initialize();
    AppLogger.logSuccess('System: Session Vault Linked (Local-First)');

    // Stage C: Pre-warm database in background (prevents 109 frames skipped on DB creation)
    await DatabaseHelper.preWarm();
    AppLogger.logInfo('System: Database pre-warmed in background');

    // Stage D: Initialize hardware detection
    await HardwareCapabilities().initialize();
    AppLogger.logInfo('System: Hardware capabilities detected');

    // Stage E: Initialize other services (after DB is ready)
    await Future.delayed(const Duration(milliseconds: 50));
    ServiceInitializer().initializeApp();

    // NOTE: Supabase is NOT initialized here!
    // It will be initialized from Dashboard after onboarding is complete.
    // This ensures the app works 100% offline during registration/PIN/SMS flow.
  } catch (e, stack) {
    AppLogger.logError(
        'System: Local-First Boot encountered a hiccup', e, stack);
  }
}

class PesaBudgetApp extends StatelessWidget {
  const PesaBudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pesa Budget Tracker',
      debugShowCheckedModeBanner: false,

      // CRITICAL: Set the local font family here to override
      // the GoogleFonts network lookup attempts.
      theme: PesaBudgetTheme.lightTheme.copyWith(
        textTheme: PesaBudgetTheme.lightTheme.textTheme.apply(
          fontFamily: 'Poppins',
        ),
      ),

      home: const AuthWrapper(),

      routes: {
        '/create-pin': (context) => const PinCreationPage(),
        '/permissions': (context) => const PermissionManagerScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/settings': (context) => const SettingsPage(),
        '/security': (context) => const SecurityPage(),
      },
    );
  }
}
