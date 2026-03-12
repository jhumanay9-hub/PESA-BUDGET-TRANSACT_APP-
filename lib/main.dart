import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
// If you have a custom theme file, ensure it's imported too
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'ui/global_error_screen.dart';
import 'ui/footer.dart';
import 'services/logger.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/db_helper.dart';
import 'services/network_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'services/transaction_service.dart';
import 'services/supabase_service.dart';
import 'services/overlay_manager.dart';

import 'account_details_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'transaction_history_page.dart';
import 'quick_classify_page.dart';
import 'services/permission_manager.dart';
import 'auth_page.dart';
import 'terms_of_service_page.dart';
import 'privacy_policy_page.dart';
// AppTheme enum for three selectable themes
enum AppTheme { light, dark, eyeComfort}

// Theme notifier for app-wide theme management. Holds the selected AppTheme
// and persists the selection to SharedPreferences.
class ThemeNotifier extends ValueNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme.light) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt('appTheme') ?? 0;
      // 0 = light, 1 = dark, 2 = eyeComfort
      if (stored >= 0 && stored < AppTheme.values.length) {
        value = AppTheme.values[stored];
      } else {
        value = AppTheme.light;
      }
      notifyListeners();
    } catch (e) {
      // ignore and keep default
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    value = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('appTheme', theme.index);
    } catch (e) {
      // ignore
    }
  }
}

final themeNotifier = ThemeNotifier();

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWindowContent(),
  ));
}

class OverlayWindowContent extends StatefulWidget {
  const OverlayWindowContent({super.key});

  @override
  State<OverlayWindowContent> createState() => _OverlayWindowContentState();
}

class _OverlayWindowContentState extends State<OverlayWindowContent> {
  double _amount = 0.0;
  String _merchant = "Unknown";

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is Map) {
        setState(() {
          _amount = (event['amount'] as num?)?.toDouble() ?? 0.0;
          _merchant = event['merchant']?.toString() ?? "Unknown";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: double.infinity,
          height: 180,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00FFCC), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Color(0xFF00FFCC), size: 28),
                  SizedBox(width: 12),
                  Text(
                    "Transaction Detected",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _merchant,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'sans-serif',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                   Text(
                     "Ksh ${_amount.toStringAsFixed(2)}",
                     style: const TextStyle(
                       color: Color(0xFF00FFCC),
                       fontSize: 22,
                       fontWeight: FontWeight.w900,
                       fontFamily: 'sans-serif',
                     ),
                   ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => FlutterOverlayWindow.closeOverlay(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: const Color(0xFF0D1B2A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void dummyBackgroundHandler(SmsMessage message) {}

@pragma('vm:entry-point')
Future<void> snifferService(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase in background isolate
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseKey,
    );
    debugPrint('[Supabase] Background initialized');
  } catch (e) {
    debugPrint('[Supabase] Background init error: $e');
  }
  
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Handle overlay trigger from the isolate
  service.on('showOverlay').listen((event) async {
    if (event == null) return;
    try {
      final amount = (event['amount'] as num?)?.toDouble() ?? 0.0;
      final merchant = event['merchant']?.toString() ?? "Unknown";
      await OverlayManager.show(amount: amount, merchant: merchant);
    } catch (e) {
      debugPrint('Overlay trigger error (background): $e');
    }
  });

  // Update heartbeat to signal the sniffer is alive
  await DatabaseService.updateHeartbeat();
  
  final telephony = Telephony.instance;
  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage message) async {
      try {
        final msgBody = message.body ?? '';
        if (!msgBody.toUpperCase().contains('M-PESA')) return;
        
        final amountMatch = RegExp(r'Ksh\s*([\d,]+\.?\d*)', caseSensitive: false).firstMatch(msgBody);
        final amountStr = amountMatch?.group(1)?.replaceAll(',', '') ?? '0';
        
        final merchantMatch = RegExp(
                r'(?:sent to|from)\s+([^.]+?)(?=\s+on\b|\s+at\b|\.|\z)',
                caseSensitive: false)
            .firstMatch(msgBody);
        final merchant = merchantMatch?.group(1)?.trim() ?? 'Unknown';

        // Determine transaction direction
        final bodyLower = msgBody.toLowerCase();
        final hasExpense = bodyLower.contains('sent to') ||
            bodyLower.contains('send to') ||
            bodyLower.contains('paid to') ||
            bodyLower.contains('withdrawn') ||
            bodyLower.contains('withdraw') ||
            bodyLower.contains('fuliza') ||
            bodyLower.contains('bought') ||
            bodyLower.contains('purchase');
        final hasIncome =
            bodyLower.contains('received') || bodyLower.contains('deposited');
        final isExpenseFlag = (hasExpense || !hasIncome) ? 1 : 0;
        final amount = double.tryParse(amountStr) ?? 0.0;

        // 1. Persist to DB and Sync to Cloud
        bool insertSuccess = false;
        try {
          final txData = {
            'smsId': message.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'body': msgBody,
            'merchant': merchant,
            'amount': amount,
            'category': 'General',
            'isExpense': isExpenseFlag,
            'date': message.date != null
                ? DateTime.fromMillisecondsSinceEpoch(message.date!).toIso8601String()
                : DateTime.now().toIso8601String(),
          };
          
          // Use unified TransactionService
          await TransactionService().saveTransaction(txData);
          insertSuccess = true;
        } catch (e) {
          debugPrint('Transaction save error (background): $e');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('qc_body', msgBody);
        await prefs.setString('qc_amount', amountStr);
        await prefs.setString('qc_merchant', merchant);

        // 2. Trigger the Quick-Sort Overlay ONLY AFTER DB success
        if (insertSuccess) {
          // Trigger Overlay
          OverlayManager.show(amount: amount, merchant: merchant);
        }
      } catch (e, stack) {
        debugPrint('SMS processing error: $e');
        try {
          final db = await DatabaseService.getDatabase();
          await db.insert('app_logs', {
            'model': 'BackgroundService',
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'SMS processing crashed: $e\n$stack',
          });
        } catch (_) {}
      }
    },
    onBackgroundMessage: dummyBackgroundHandler,
    listenInBackground: true,
  );
}

@pragma('vm:entry-point')
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Supabase
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseKey,
      );
      debugPrint('[Supabase] Main initialized');
    } catch (e) {
      debugPrint('[Supabase] Main init error: $e');
    }

    // Global Flutter Error handling
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      Logger.logError("Flutter Framework Error: ${details.exception}", details.stack);
      
      // If fatal, show Error UI
      if (details.silent != true) {
        runApp(GlobalErrorScreen(error: details.exception, stackTrace: details.stack));
      }
    };

    // Platform level error handling (Asynchronous errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger.logError("Platform Error: $error", stack);
      runApp(GlobalErrorScreen(error: error, stackTrace: stack));
      return true;
    };

    runApp(const MyApp());
    if (Platform.isAndroid) {
      unawaited(Future(() async {
        try {
          const channel = MethodChannel('app/notif_channel');
          try {
            await channel.invokeMethod('createNotificationChannel', {
              'id': 'mpesa_sniffer_channel',
              'name': 'M-Pesa Sniffer',
              'description': 'Foreground service for M-Pesa transaction sniffer',
            });
          } catch (e) {
            debugPrint('Channel creation failed: $e');
          }
          await FlutterBackgroundService().configure(
            androidConfiguration: AndroidConfiguration(
              onStart: snifferService,
              isForegroundMode: true,
              autoStart: true,
              notificationChannelId: 'mpesa_sniffer_channel',
              initialNotificationTitle: 'Master your money',
              initialNotificationContent: 'Monitoring transactions...',
            ),
            iosConfiguration: IosConfiguration(),
          );
          FlutterBackgroundService().startService();

          // Initialize flutter_foreground_task for even more persistent execution
          FlutterForegroundTask.init(
            androidNotificationOptions: AndroidNotificationOptions(
              channelId: 'mpesa_sniffer_channel',
              channelName: 'Pesa Budget Protection',
              channelDescription: 'Foreground service for M-Pesa protection',
              channelImportance: NotificationChannelImportance.HIGH,
              priority: NotificationPriority.HIGH,
              iconData: const NotificationIconData(
                resType: ResourceType.mipmap,
                resPrefix: ResourcePrefix.ic,
                name: 'launcher_icon',
              ),
            ),
            iosNotificationOptions: const IOSNotificationOptions(),
            foregroundTaskOptions: const ForegroundTaskOptions(
              interval: 5000,
              isOnceEvent: false,
              autoRunOnBoot: true,
              allowWakeLock: true,
              allowWifiLock: true,
            ),
          );
        } catch (e, st) {
          debugPrint('Background service init error: $e');
          debugPrint(st.toString());
        }
      }));
    }
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint(stack.toString());
  });
}

// Heavy SMS parsing moved off UI thread with optimized batch processing
List<Map<String, dynamic>> parseSmsBatch(
    List<Map<String, dynamic>> rawMessages) {
  final List<Map<String, dynamic>> parsed = [];

  // Pre-compile regex patterns for better performance
  final amountRegex = RegExp(r'Ksh\s*([\d,]+\.?\d*)', caseSensitive: false);
  final merchantRegex = RegExp(
    r'(?:sent to|from)\s+([^.]+?)(?=\s+on\b|\s+at\b|\.|\z)',
    caseSensitive: false,
  );
  final blacklistRegex = RegExp(r'OTP|Discount|Offer', caseSensitive: false);

  // Pre-define keyword sets for faster lookup
  const financialKeywords = ['mpesa', 'confirmed', 'ksh', 'trans. id'];
  const whitelistedSenders = ['MPESA', 'KCB', 'EQUITY'];
  const expenseKeywords = [
    'sent to',
    'send to',
    'paid to',
    'pay to',
    'payment to',
    'transferred to',
    'withdrawn',
    'withdraw',
    'fuliza',
    'bought',
    'purchase'
  ];
  const incomeKeywords = ['received', 'deposited'];

  for (final raw in rawMessages) {
    final body = (raw['body'] as String?) ?? '';
    if (body.isEmpty) continue;

    final bodyLower = body.toLowerCase();
    final senderHeader = (raw['address'] as String?) ?? '';

    // 0. Quick validation using keyword sets (faster than multiple contains calls)
    final hasFinancialKeyword = financialKeywords.any(bodyLower.contains);
    if (!hasFinancialKeyword) continue;

    // 1. Whitelist Filter
    final isWhitelisted =
        whitelistedSenders.any((s) => senderHeader.toUpperCase().contains(s));
    if (!isWhitelisted) continue;

    // 2. Blacklist Filter
    if (blacklistRegex.hasMatch(body)) continue;

    // 3. Extract Amount (using pre-compiled regex)
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch == null) continue;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount == 0) continue;

    // 4. Extract Merchant (using pre-compiled regex)
    final merchantMatch = merchantRegex.firstMatch(body);
    final merchant = merchantMatch?.group(1)?.trim() ?? 'Unknown';

    // 5. Determine transaction direction (using keyword sets)
    final hasExpenseKeyword = expenseKeywords.any(bodyLower.contains);
    final hasIncomeKeyword = incomeKeywords.any(bodyLower.contains);
    final isExpense = hasExpenseKeyword || !hasIncomeKeyword;

    final int? dateMillis = raw['date'] as int?;

    parsed.add({
      'smsId': (raw['id']?.toString()) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'body': body,
      'merchant': merchant,
      'amount': amount,
      'category': 'General',
      'isExpense': isExpense ? 1 : 0,
      'date': dateMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(dateMillis).toIso8601String()
          : DateTime.now().toIso8601String(),
    });
  }

  return parsed;
}

// Background reclassification helper run inside an isolate via `compute()`.
// It mirrors the in-line logic used in `_reclassifyExistingTransactions` but
// runs only the CPU-bound string checks off the UI isolate and returns the
// id/isExpense pairs for the main isolate to persist.
List<Map<String, dynamic>> _computeReclassification(
    List<Map<String, dynamic>> rows) {
  final List<Map<String, dynamic>> results = [];

  for (final row in rows) {
    final idRaw = row['id'];
    final int id =
        idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '0') ?? 0;
    final bodyLower = (row['body'] as String? ?? '').toLowerCase();

    final bool hasExpenseKeyword = bodyLower.contains('sent to') ||
        bodyLower.contains('send to') ||
        bodyLower.contains('paid to') ||
        bodyLower.contains('pay to') ||
        bodyLower.contains('payment to') ||
        bodyLower.contains('transferred to') ||
        bodyLower.contains('withdrawn') ||
        bodyLower.contains('withdraw') ||
        bodyLower.contains('fuliza') ||
        bodyLower.contains('bought') ||
        bodyLower.contains('purchase');

    final bool hasIncomeKeyword =
        bodyLower.contains('received') || bodyLower.contains('deposited');

    final int isExpense = (hasExpenseKeyword || !hasIncomeKeyword) ? 1 : 0;

    results.add({'id': id, 'isExpense': isExpense});
  }

  return results;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, appTheme, child) {
        // Define the three ThemeData options using Pesa Budget Branding
        // Primary: Midnight Slate (0xFF0D1B2A), Seed: Kinetic Mint (0xFF4CAF50)
        
        final baseLightTextTheme = ThemeData.light().textTheme;
        final baseDarkTextTheme = ThemeData.dark().textTheme;

        final ThemeData lightTheme = ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF0D1B2A),
          scaffoldBackgroundColor: const Color(0xFFF9FAFB),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D1B2A),
            foregroundColor: Colors.white,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00FFCC),
            primary: const Color(0xFF0D1B2A),
            brightness: Brightness.light,
          ),
          textTheme: baseLightTextTheme,
        );

        final ThemeData darkTheme = ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF0D1B2A),
          scaffoldBackgroundColor: const Color(0xFF0D1B2A),
          canvasColor: const Color(0xFF0D1B2A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D1B2A),
            foregroundColor: Colors.white,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00FFCC),
            primary: const Color(0xFF0D1B2A),
            surface: const Color(0xFF162436),
            brightness: Brightness.dark,
          ),
          textTheme: baseDarkTextTheme.apply(
            bodyColor: const Color(0xFFF4F7FA),
            displayColor: const Color(0xFFF4F7FA),
          ),
        );

        final ThemeData eyeComfortTheme = ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF0D1B2A),
          scaffoldBackgroundColor: const Color(0xFFF5F5DC),
          canvasColor: const Color(0xFFF5F5DC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D1B2A),
            foregroundColor: Colors.white,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            primary: const Color(0xFF0D1B2A),
            brightness: Brightness.light,
          ),
          textTheme: baseLightTextTheme.apply(
            bodyColor: const Color(0xFF4E342E),
            displayColor: const Color(0xFF4E342E),
          ),
        );

        // Choose a single ThemeData to apply based on the saved AppTheme.
        final ThemeData themeData = appTheme == AppTheme.light
            ? lightTheme
            : appTheme == AppTheme.dark
                ? darkTheme
                : eyeComfortTheme;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeData,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLoading = true;
  Widget? startPage;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    const storage = FlutterSecureStorage();

    // 1. Check connectivity first
    final connectivity = await NetworkService().checkConnectivity();
    final isOnline = NetworkService().isOnline(connectivity);

    // 2. Check local fallback flags
    final email = prefs.getString('email');
    final hasPin = await storage.containsKey(key: 'user_pin');
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (mounted) {
      if (!isOnline) {
        // OFFLINE MODE: If we have local credentials, allow entry
        if (isLoggedIn && email != null && hasPin) {
          debugPrint('Offline: Using local session fallback');
          startPage = const Dashboard();
        } else {
          // No valid local session, must go to login
          startPage = const AuthPage(isLogin: true);
        }
      } else {
        // ONLINE MODE: Check Supabase session first
        final session = AuthService().client.auth.currentSession;
        
        if (session == null) {
          // No Supabase session -> Go to Login/Signup
          startPage = const AuthPage(isLogin: true);
        } else if (!hasPin) {
          // Logged in but no PIN set -> Go to PIN Setup
          startPage = const PinSetupPage();
        } else {
          // Fully authenticated -> Go to Dashboard
          startPage = const Dashboard();
        }
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return startPage!;
  }
}

// --- DATABASE HELPER AND FOOTER EXTRACTED ---

// --- REGISTRATION PAGE ---
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isNavigating = false; // Atomic Navigation Flag

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isNavigating || !mounted) return;

    // Clean the Gesture Arena
    FocusScope.of(context).unfocus();

    setState(() => _isNavigating = true);

    final prefs = await SharedPreferences.getInstance();

    final enteredEmail = _emailController.text.trim();
    final storedEmail = prefs.getString('email') ?? '';

    // If the entered email already exists in SharedPreferences, block registration.
    if (storedEmail.isNotEmpty && storedEmail == enteredEmail) {
      if (mounted) {
        setState(() => _isNavigating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account already exists'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty) {
      await prefs.setString('name', _nameController.text.trim());
      await prefs.setString('email', enteredEmail);
      await prefs.setString('password',
          _passwordController.text.trim()); // In a real app, hash this
      await prefs.setString('phone', _phoneController.text.trim());

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const PinSetupPage()));
          }
        });
      }
    } else {
      setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.blue[900],
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double screenHeight = constraints.maxHeight;
              final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: screenHeight - (isKeyboardVisible ? 0 : 80)), 
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              Visibility(
                                visible: !isKeyboardVisible,
                                child: const Column(
                                  children: [
                                    Icon(Icons.person_add, size: 80, color: Colors.white),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                              const Text("Create Account",
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 30),
                              TextField(
                                controller: _nameController,
                                showCursor: true,
                                cursorColor: const Color(0xFF00FFCC),
                                cursorWidth: 3.0,
                                cursorHeight: 25.0,
                                decoration: InputDecoration(
                                  hintText: "Full name",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailController,
                                showCursor: true,
                                cursorColor: const Color(0xFF00FFCC),
                                cursorWidth: 3.0,
                                cursorHeight: 25.0,
                                decoration: InputDecoration(
                                  hintText: "Email",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                showCursor: true,
                                cursorColor: const Color(0xFF00FFCC),
                                cursorWidth: 3.0,
                                cursorHeight: 25.0,
                                decoration: InputDecoration(
                                  hintText: "Password",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _phoneController,
                                showCursor: true,
                                cursorColor: const Color(0xFF00FFCC),
                                cursorWidth: 2.5,
                                cursorHeight: 22,
                                decoration: InputDecoration(
                                  hintText: "Phone number",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _register();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50)),
                                child: const Text("REGISTER"),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Pinned footer
                  Visibility(
                    visible: !isKeyboardVisible,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        '\u00a9 2025 Pesa Budget • v1.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

// --- PIN SETUP PAGE ---
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String pin = "";

  void _onKeyPress(String val) {
    if (pin.length < 4) {
      setState(() => pin += val);
      if (pin.length == 4) {
        _savePin();
      }
    }
  }

  Future<void> _savePin() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'user_pin', value: pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const Dashboard()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.green[800],
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 60),
            const Text("Setup 4-Digit PIN",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    4,
                    (i) => Container(
                          margin: const EdgeInsets.all(8),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  pin.length > i ? Colors.white : Colors.white24),
                        ))),
            const SizedBox(height: 50),
            _PinPad(
                onPressed: (val) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onKeyPress(val);
                  });
                },
                onBackspace: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => pin =
                          pin.isNotEmpty ? pin.substring(0, pin.length - 1) : "");
                    })),
            const SizedBox(height: 20),
          ]),
        ),
      );
}

// --- PIN LOGIN PAGE ---
class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String enteredPin = "";
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final isBioEnabled = prefs.getBool('is_biometric_enabled') ?? false;
    if (isBioEnabled) {
      try {
        bool authenticated = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (authenticated) {
          const storage = FlutterSecureStorage();
          final savedPin = await storage.read(key: 'user_pin');
          if (savedPin != null) {
            await prefs.setBool('isLoggedIn', true);
            if (mounted) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const Dashboard()));
            }
          }
        }
      } catch (e) {
        debugPrint('Biometric login error: $e');
      }
    }
  }

  void _onKeyPress(String val) async {
    if (enteredPin.length < 4) {
      setState(() => enteredPin += val);
      if (enteredPin.length == 4) {
        const storage = FlutterSecureStorage();
        final savedPin = await storage.read(key: 'user_pin');
        if (enteredPin == savedPin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const Dashboard()));
          }
        } else {
          setState(() => enteredPin = "");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Wrong PIN"), backgroundColor: Colors.red));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF1B5E20),
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(height: 60),
            const Icon(Icons.lock_outline, size: 60, color: Colors.white),
            const SizedBox(height: 16),
            const Text("Enter PIN",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    4,
                    (i) => Container(
                          margin: const EdgeInsets.all(8),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: enteredPin.length > i
                                  ? Colors.white
                                  : Colors.white24),
                        ))),
            const SizedBox(height: 50),
            _PinPad(
                onPressed: (val) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onKeyPress(val);
                  });
                },
                onBackspace: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => enteredPin =
                          enteredPin.isNotEmpty
                              ? enteredPin.substring(0, enteredPin.length - 1)
                              : "");
                    })),
            const SizedBox(height: 20),
          ]),
        ),
      );
}

class _PinPad extends StatelessWidget {
  final Function(String) onPressed;
  final VoidCallback onBackspace;
  const _PinPad({required this.onPressed, required this.onBackspace});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9']
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var val in row) _padButton(val),
            ],
          ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 80),
          _padButton('0'),
          SizedBox(
              width: 80,
              child: IconButton(
                  onPressed: onBackspace,
                  icon: const Icon(Icons.backspace, color: Colors.white))),
        ]),
      ]);

  Widget _padButton(String val) => Container(
        margin: const EdgeInsets.all(12),
        width: 60,
        height: 60,
        child: OutlinedButton(
          onPressed: () => onPressed(val),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              shape: const CircleBorder()),
          child: Text(val,
              style: const TextStyle(color: Colors.white, fontSize: 24)),
        ),
      );
}

// --- LOGIN PAGE (Legacy - but keeping redirect) ---
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => const RegistrationPage();
}

// --- DASHBOARD ---
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final List<Map<String, dynamic>> _userCategories = [];
  // Future variable for categories to enable proper refreshing
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  // No more hardcoded categories list
  Map<String, double> totals = {
    "Revenue": 0,
    "Food": 0,
    "General": 0,
    "Bills": 0,
    "Transport": 0,
    "Rent": 0,
    "Totals": 0
  };

   TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  late ValueNotifier<bool> _isScanning;
  late ValueNotifier<bool> _isBootstrapping;
  late StreamSubscription _dbSubscription;
  late Telephony _telephony;
  bool _snifferInactive = false;
  bool _isOffline = false;
  StreamSubscription? _netSubDis;
  @override
  void initState() {
    super.initState();
    _isBootstrapping = ValueNotifier(true);
    _isScanning = ValueNotifier(false);
    _telephony = Telephony.instance;
    _categoriesFuture = DbHelper.getCategories();
    _dbSubscription = DbHelper.onUpdate.listen((_) => refreshData());
    _bootstrapDashboard();
    _checkHeartbeat();
    _initNetwork();
  }

  void _initNetwork() async {
    final connectivity = await NetworkService().checkConnectivity();
    if (mounted) setState(() => _isOffline = !NetworkService().isOnline(connectivity));
    
    _netSubDis = NetworkService().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOffline = !NetworkService().isOnline(results));
    });
  }

  Future<void> _checkHeartbeat() async {
    final lastRun = await DbHelper.getLastHeartbeat();
    if (lastRun == null || DateTime.now().difference(lastRun).inHours > 24) {
      if (mounted) setState(() => _snifferInactive = true);
    }
  }

   Future<void> _bootstrapDashboard() async {
     try {
       _isBootstrapping.value = true;
       await _loadCategories();
       await refreshData();
       await _initScanner();
       _setupSmsListener();
       await _checkPendingQuickClassify();
       
       if (mounted) {
         // Schedule overlay permission check after first frame to ensure context is ready
         WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) {
             UniversalPermissionManager.requestOverlayPermission(context);
           }
         });
         await UniversalPermissionManager.requestIgnoreBatteryOptimizations(context);
       }
     } finally {
       if (mounted) {
         _isBootstrapping.value = false;
       }
     }
   }

   @override
   void dispose() {
     _dbSubscription.cancel();
     _accountNameController.dispose();
     _searchController.dispose();
     _isBootstrapping.dispose();
     _isScanning.dispose();
     _tabController?.dispose();
     _netSubDis?.cancel();
     super.dispose();
   }

  Future<void> refreshAccounts() async {
    setState(() {
      _categoriesFuture = DbHelper.getCategories();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DbHelper.getCategories();
      if (!mounted) return;
      setState(() {
        _userCategories
          ..clear()
          ..addAll(cats);
        _categoriesFuture = Future.value(cats);
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _checkPendingQuickClassify() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? body = prefs.getString('qc_body');
      final String? amountStr = prefs.getString('qc_amount');
      final String? merchant = prefs.getString('qc_merchant');
      
      if (body != null && amountStr != null && merchant != null && mounted) {
        // Keyboard & Focus Cleanup
        FocusManager.instance.primaryFocus?.unfocus();

        // Defensive Navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuickClassifyPage(
                  body: body,
                  amountStr: amountStr,
                  merchant: merchant,
                ),
              ),
            );
          }
        });
      }
    } catch (_) {}
  }

  // Helper functions to get icon data from category name
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'add_chart':
        return Icons.add_chart;
      case 'restaurant':
        return Icons.restaurant;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'receipt':
        return Icons.receipt;
      case 'savings':
        return Icons.savings;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      default:
        return Icons.category;
    }
  }

  Color _getColorData(int colorValue) {
    return Color(colorValue);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await DbHelper.getGlobalSearchTransactions(query);
    setState(() => _searchResults = results);
  }

  Future<void> _initScanner() async {
    try {
      final ok =
          await UniversalPermissionManager.ensureUniversalPermissions(context);
      if (ok) {
        await _scanInbox();
      } else {
        debugPrint('Required permissions denied');
      }
    } catch (e) {
      debugPrint('Error in _initScanner: $e');
    }
  }

  Future<void> _scanInbox() async {
    try {
      // Show loading indicator
      if (mounted) {
        setState(() {
          _isScanning.value = true;
        });
      }

      // Get all SMS messages
      final messages = await _telephony.getInboxSms();

      if (messages.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning.value = false;
          });
        }
        return;
      }

      // Convert to lightweight map structure consumable by `parseSmsBatch`
      final rawMessages = messages.map((message) {
        return {
          'id': message.id?.toString(),
          'body': message.body ?? '',
          'date': message.date,
          'address': message.address ?? '',
        };
      }).toList();

      // Offload heavy parsing to an isolate using the optimized helper
      final parsed = await compute(parseSmsBatch, rawMessages);

      if (parsed.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning.value = false;
          });
        }
        return;
      }

      // Batch insert parsed transactions for better performance
      final db = await DbHelper.getDatabase();
      final batch = db.batch();

      for (final item in parsed) {
        batch.insert(
          'transactions',
          {
            'smsId': item['smsId'],
            'body': item['body'],
            'merchant': item['merchant'],
            'amount': item['amount'],
            'category': item['category'],
            'isExpense': item['isExpense'],
            'date': item['date'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Execute batch operation
      await batch.commit(noResult: true);
      // Reclassify any existing transactions using the latest keyword logic
      await _reclassifyExistingTransactions();

      // Refresh data after scanning
      await refreshData();
    } catch (e) {
      debugPrint('Error scanning inbox: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning.value = false;
          _isBootstrapping.value = false;
        });
      }
      FlutterNativeSplash.remove(); // Dashboard is ready!
    }
  }

  /// Re-evaluates the isExpense flag for every transaction in the DB
  /// using the current keyword rules. Safe to call on every launch.
  Future<void> _reclassifyExistingTransactions() async {
    try {
      final db = await DbHelper.getDatabase();
      final rows = await db.query('transactions', columns: ['id', 'body']);

      if (rows.isEmpty) {
        debugPrint('No transactions to reclassify.');
        return;
      }

      // Offload the CPU-heavy classification checks into an isolate.
      final results = await compute(_computeReclassification, rows);

      // Persist the computed results on the main isolate (DB operations).
      for (final r in results) {
        try {
          final id = r['id'] as int;
          final isExpense = r['isExpense'] as int;
          await db.update(
            'transactions',
            {'isExpense': isExpense},
            where: 'id = ?',
            whereArgs: [id],
          );
        } catch (e) {
          debugPrint('Error updating transaction during reclassification: $e');
        }
      }

      debugPrint('Reclassified ${rows.length} transactions.');
    } catch (e) {
      debugPrint('Error reclassifying transactions: $e');
    }
  }

  bool isValidTransaction(String message) {
    final bodyLower = message.toLowerCase();
    return bodyLower.contains('mpesa') ||
        bodyLower.contains('confirmed') ||
        bodyLower.contains('ksh') ||
        bodyLower.contains('trans. id');
  }

  Future<void> _processSms(SmsMessage message) async {
    final body = message.body ?? '';

    // 0. Validation Layer: Discard non-financial messages
    if (!isValidTransaction(body)) return;

    final senderHeader = message.address ?? '';

    // 1. Whitelist Filter: Only process known banking/mobile money headers
    final whitelistedSenders = ['MPESA', 'KCB', 'EQUITY'];
    bool isWhitelisted =
        whitelistedSenders.any((s) => senderHeader.toUpperCase().contains(s));
    if (!isWhitelisted) return;

    // 2. Blacklist Filter: Discard OTPs, Discounts, and Offers
    if (RegExp(r'OTP|Discount|Offer', caseSensitive: false).hasMatch(body)) {
      return;
    }

    // 3. Extract Amount (Regex)
    // Extracts the number after 'Ksh'
    final amountMatch =
        RegExp(r'Ksh\s*([\d,]+\.?\d*)', caseSensitive: false).firstMatch(body);
    if (amountMatch == null) return;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount == 0) return;

    // 4. Extract Merchant/Sender (Regex)
    // Extracts the name after 'sent to' or 'from'
    final merchantMatch = RegExp(
            r'(?:sent to|from)\s+([^.]+?)(?=\s+on\b|\s+at\b|\.|\z)',
            caseSensitive: false)
        .firstMatch(body);
    final merchant = merchantMatch?.group(1)?.trim() ?? 'Unknown';

    // 5. Determine transaction direction from keywords (expense keywords take priority)
    final bodyLower = body.toLowerCase();

    // Expense signals — any of these → red (debit)
    final bool hasExpenseKeyword = bodyLower.contains('sent to') ||
        bodyLower.contains('send to') ||
        bodyLower.contains('paid to') ||
        bodyLower.contains('pay to') ||
        bodyLower.contains('payment to') ||
        bodyLower.contains('transferred to') ||
        bodyLower.contains('withdrawn') ||
        bodyLower.contains('withdraw') ||
        bodyLower.contains('fuliza') ||
        bodyLower.contains('bought') ||
        bodyLower.contains('purchase');

    // Income signals — confirmed incoming credit
    final bool hasIncomeKeyword =
        bodyLower.contains('received') || bodyLower.contains('deposited');

    // Expense wins if explicitly detected; income keyword without expense → income;
    // default to expense (safe fallback)
    final bool isExpense = hasExpenseKeyword || !hasIncomeKeyword;

    // 6. Database Insertion: Capture as 'General'
    final db = await DbHelper.getDatabase();
    await db.insert(
      'transactions',
      {
        'smsId': message.id?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'body': body,
        'merchant': merchant,
        'amount': amount,
        'category': 'General',
        'isExpense': isExpense ? 1 : 0,
        'date': message.date != null
            ? DateTime.fromMillisecondsSinceEpoch(message.date!)
                .toIso8601String()
            : DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 6. Trigger UI Notification via Stream
    DbHelper.notifyUpdate();

    // ── Show Quick-Sort Overlay (foreground) ──────────────────────
    try {
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: 'M-Pesa Quick-Sort',
          overlayContent: 'Sort transaction to an account',
          flag: OverlayFlag.defaultFlag,
          width: -1, // matchParent
          height: 420,
        );
        await FlutterOverlayWindow.shareData({
          'amount': amount.toStringAsFixed(2),
          'merchant': merchant,
          'isExpense': isExpense ? 1 : 0,
        });
      }
    } catch (e) {
      debugPrint('Overlay trigger error (foreground): $e');
    }

    // Decide whether to also alert via snackbar based on settings.
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsEnabled = prefs.getBool('is_alerts_enabled') ?? true;
      if (alertsEnabled && mounted) {
        final amountStr = amount.toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${isExpense ? 'Expense' : 'Income'} recorded: Ksh $amountStr • $merchant'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking alerts preference: $e');
    }

     // Fire-and-forget background sync to Supabase (runs heavy work in an isolate)
     SupabaseSyncService().syncToCloud()
         .catchError((e) => debugPrint('Supabase sync failed: $e'));
  }

  Future<void> refreshData() async {
    // 1. Load latest categories from DB first
    await _loadCategories();

    final db = await DbHelper.getDatabase();

    // 2. Clear and rebuild totals dynamically
    Map<String, double> newTotals = {};

    // Calculate Revenue
    var rev = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE body LIKE '%received%' OR body LIKE '%deposited%'");
    newTotals["Revenue"] = (rev.first['total'] as num?)?.toDouble() ?? 0.0;

    // Calculate each category from the fresh _userCategories list
    double expenseTotal = 0.0;
    for (final category in _userCategories) {
      final catName = category['name'] as String;
      final total = await DbHelper.getTotalForCategory(catName);
      newTotals[catName] = total;

      // Calculate Grand Totals (excluding Revenue/General if needed, but here we sum categorized expenses)
      if (catName != 'Revenue') {
        expenseTotal += total;
      }
    }

    newTotals["Totals"] = expenseTotal;

    if (mounted) {
      setState(() {
        totals = newTotals;
      });
    }
  }

  void _setupSmsListener() {
    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          await _processSms(message);
          refreshData(); // Update UI in real-time
        },
        onBackgroundMessage: dummyBackgroundHandler,
        listenInBackground: true,
      );
    } catch (e) {
      debugPrint('Error in _setupSmsListener: $e');
    }
  }

  void _showAddAccountDialog() {
    // Palette of selectable colors (value → display color)
    const colorOptions = [
      0xFF4CAF50, // Green
      0xFF2196F3, // Blue
      0xFFFF9800, // Orange
      0xFF9C27B0, // Purple
      0xFFF44336, // Red
      0xFF607D8B, // Grey-blue
    ];

    // Icon options: display name → icon data + storage key
    const iconOptions = [
      {'key': 'category', 'icon': Icons.category, 'label': 'General'},
      {'key': 'home', 'icon': Icons.home, 'label': 'Home'},
      {'key': 'savings', 'icon': Icons.savings, 'label': 'Savings'},
      {
        'key': 'shopping_cart',
        'icon': Icons.shopping_cart,
        'label': 'Shopping'
      },
      {'key': 'restaurant', 'icon': Icons.restaurant, 'label': 'Food'},
      {
        'key': 'directions_car',
        'icon': Icons.directions_car,
        'label': 'Transport'
      },
      {'key': 'receipt', 'icon': Icons.receipt, 'label': 'Bills'},
      {'key': 'work', 'icon': Icons.work, 'label': 'Work'},
      {'key': 'school', 'icon': Icons.school, 'label': 'School'},
    ];

    int selectedColor = colorOptions[0];
    String selectedIcon = iconOptions[0]['key'] as String;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Add New Account",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name field ──────────────────────────────────────
                    TextField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: "Account Name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Color picker ────────────────────────────────────
                    const Text("Theme Color",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: colorOptions.map((colorVal) {
                        final isSelected = selectedColor == colorVal;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = colorVal),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSelected ? 40 : 34,
                            height: isSelected ? 40 : 34,
                            decoration: BoxDecoration(
                              color: Color(colorVal),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.black54, width: 3)
                                  : Border.all(color: Colors.transparent),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: Color(colorVal)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2)
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Icon picker ─────────────────────────────────────
                    const Text("Icon",
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: iconOptions.map((opt) {
                        final key = opt['key'] as String;
                        final icon = opt['icon'] as IconData;
                        final label = opt['label'] as String;
                        final isSelected = selectedIcon == key;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(selectedColor).withValues(alpha: 0.15)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Color(selectedColor)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon,
                                    color: isSelected
                                        ? Color(selectedColor)
                                        : Colors.grey[600],
                                    size: 24),
                                const SizedBox(height: 2),
                                Text(label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected
                                          ? Color(selectedColor)
                                          : Colors.grey[600],
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _accountNameController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(selectedColor),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = _accountNameController.text.trim();
                    if (name.isNotEmpty) {
                      await DbHelper.insertCategory(
                        name,
                        color: selectedColor,
                        icon: selectedIcon,
                      );
                      _accountNameController.clear();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Account '$name' Created"),
                            backgroundColor: Color(selectedColor),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }

                       // Refresh the Future variable to update the UI
                       await refreshAccounts();
                       refreshData();
                       // Fire-and-forget background sync to Supabase when a new account is added
                       SupabaseSyncService().syncToCloud()
                           .catchError((e) => debugPrint('Supabase sync failed: $e'));
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search transactions...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => _performSearch(value),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pesa Budget'),
                    if (_isOffline)
                      const Text(
                        "Offline Mode",
                        style: TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
          backgroundColor: const Color(0xFF0D1B2A),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchController.clear();
                    _searchResults = [];
                    refreshData();
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF00FFCC)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        size: 40, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text("Pesa Budget",
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    Text("Master your money",
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: const Color(0xFF0D1B2A).withValues(alpha: 0.7), fontSize: 14)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: const Text("Profile",
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.green),
                title: const Text("Settings",
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.green),
                title: const Text("Transaction History",
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const TransactionHistoryPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.green),
                title: const Text("Download Statement",
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadStatement();
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Legal & Trust",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.grey),
                title: const Text("Terms of Service",
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TermsOfServicePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.grey),
                title: const Row(
                  children: [
                    Text("Privacy Policy",
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                    Icon(Icons.shield, color: Color(0xFF4CAF50), size: 16),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyPage()),
                  );
                },
              ),
              const Divider(),
               ListTile(
                 leading: const Icon(Icons.logout, color: Colors.red),
                 title: const Text("Logout",
                     softWrap: true,
                     overflow: TextOverflow.ellipsis,
                     style: TextStyle(fontFamily: 'sans-serif')),
                 onTap: _performLogout,
               ),
            ],
          ),
        ),
        body: Stack(
          children: [
            RepaintBoundary(
              child: _isSearching
                  ? (_searchResults.isEmpty &&
                          _searchController.text.isNotEmpty)
                      ? const Center(child: Text("No transactions found"))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            final merchant = item['merchant'] ?? 'Unknown';
                            final amount =
                                (item['amount'] as num?)?.toDouble() ?? 0.0;
                            final date = item['date'] ?? '';
                            final category = item['category'] ?? 'General';

                            return ListTile(
                              leading:
                                  const CircleAvatar(child: Icon(Icons.search)),
                              title: Text(merchant,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle:
                                  Text("${item['body']}\n$date • $category"),
                              trailing: Text("Ksh ${amount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              isThreeLine: true,
                            );
                          },
                        )
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _categoriesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildSkeletonLoader();
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}', style: const TextStyle(fontFamily: 'sans-serif')));
                        }

                        final categories = snapshot.data ?? [];
                        if (categories.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  "No accounts found.",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'sans-serif',
                                      color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showAddAccountDialog,
                                  icon: const Icon(Icons.add),
                                  label:
                                      const Text("Create your first account", style: TextStyle(fontFamily: 'sans-serif')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Remove splash once data is fully ready to be built
                        FlutterNativeSplash.remove();

                        return DefaultTabController(
                          length: categories.length,
                          child: Column(
                            children: [
                              // TabBar for categories
                              Container(
                                color: Colors.white,
                                child: TabBar(
                                  isScrollable: true,
                                  labelColor: Colors.green[800],
                                  unselectedLabelColor: Colors.grey,
                                  indicatorColor: Colors.green[800],
                                  tabs: categories
                                      .map((category) => Tab(
                                            text: category['name'] as String,
                                          ))
                                      .toList(),
                                ),
                              ),
                              // TabBarView for content
                              Expanded(
                                child: TabBarView(
                                  children: categories.map<Widget>((category) {
                                    final catName = category['name'] as String;
                                    final catColor =
                                        _getColorData(category['color'] as int);
                                    final catIcon = _getIconData(
                                        category['icon'] as String);

                                    return _card(
                                      catName,
                                      catIcon,
                                      catColor,
                                      () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (ctx) =>
                                                  AccountDetailsPage(
                                                      categoryName: catName,
                                                      categoryColor: catColor,
                                                      categoryIcon: catIcon))),
                                      showDelete: catName != "General",
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isBootstrapping,
              builder: (context, isBootstrapping, child) {
                if (!isBootstrapping) return const SizedBox.shrink();
                return Container(
                  color: Colors.white.withValues(alpha: 0.95),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4CAF50)),
                        SizedBox(height: 24),
                        Text(
                          'Syncing Vault...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'sans-serif',
                            color: Color(0xFF0D1B2A)
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Securely processing your M-Pesa records.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddAccountDialog(),
          backgroundColor: const Color(0xFF0D1B2A),
          child: const Icon(Icons.add, color: Color(0xFF4CAF50)),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_snifferInactive) _buildHeartbeatBanner(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Press the dustbin icon to delete this account and its sorting button.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontFamily: 'sans-serif',
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const AppFooter(),
          ],
        ),
      );

  Widget _buildHeartbeatBanner() {
    return Container(
      color: Colors.red[800],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "M-Pesa Service is inactive. Tap to restart background protection.",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              UniversalPermissionManager.ensureUniversalPermissions(context);
              setState(() => _snifferInactive = false);
            },
            child: const Text("RESTART", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }

  // Skeleton Loader Widget to eliminate flicker
  Widget _buildSkeletonLoader() {
    return Column(
        children: [
          // Simulated Tab Bar
          Container(
            height: 48,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (i) => Container(width: 60, height: 20, color: Colors.grey[200])),
            ),
          ),
          const SizedBox(height: 16),
          // Simulated Cards
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                return Container(
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
        ],
    );
  }

  Widget _card(String title, IconData icon, Color color, VoidCallback onTap,
          {bool showDelete = false}) =>
      InkWell(
        onTap: onTap,
        onLongPress:
            showDelete ? () => _showDeleteConfirmationDialog(title) : null,
        borderRadius: BorderRadius.circular(20.0),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Stack(
                children: [
                  // Icon watermark (30% larger)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      icon,
                      size: 91,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  // ── Horizontal Row: Centered Focal Row ────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Left: Large circular account logo (60dp)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Right: Totals + subtext
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Totals: Ksh ${(totals[title] ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontFamily: 'sans-serif',
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Click to see transactions',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Actions Column (Download)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _downloadStatement(category: title),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                                size: 25, // Scaled up (was 20)
                              ),
                            ),
                          ),
                          if (showDelete) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _deleteAccount(title),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 25, // Scaled up (was 20)
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ), // end Card
        ), // end Container
      ); // end InkWell

  Future<void> _deleteAccount(String accountName) async {
    if (accountName == 'General') return; // PROTECT GENERAL fallback
    // Remove from database
    final db = await DbHelper.getDatabase();
    await db.delete('categories', where: 'name = ?', whereArgs: [accountName]);

    // Remove associated transactions or set them to 'General'
    await db.update(
      'transactions',
      {'category': 'General'},
      where: 'category = ?',
      whereArgs: [accountName],
    );

    // Notify any listeners (e.g. General account details) so they refresh immediately
    DbHelper.notifyUpdate();

    // Refresh TabController and UI
    _loadCategories();
    refreshData();
  }

  Future<void> _showDeleteConfirmationDialog(String accountName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete $accountName?'),
          content: const Text(
              'This will move all its transactions back to General.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount(accountName);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadStatement({String? category}) async {
    // UX: notify start
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating Statement...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    try {
      // Ensure storage permission with universal manager
      if (Platform.isAndroid) {
        final granted =
            await UniversalPermissionManager.requestStorage(context);
        if (!granted) {
          return;
        }
      }
      // Resolve data source: current filtered list, specific category, or full DB
      List<Map<String, dynamic>> data;
      if (_isSearching &&
          _searchController.text.isNotEmpty &&
          _searchResults.isNotEmpty) {
        data = _searchResults;
      } else if (category != null) {
        final db = await DbHelper.getDatabase();
        if (category == 'General') {
          data = await db.query('transactions',
              where: 'category = ? OR category IS NULL OR category = \'\'',
              whereArgs: [category],
              orderBy: 'date DESC');
        } else {
          data = await db.query('transactions',
              where: 'category = ?', whereArgs: [category], orderBy: 'date DESC');
        }
      } else {
        final db = await DbHelper.getDatabase();
        data = await db.query('transactions', orderBy: 'date DESC');
      }

      final csv = _generateCSVString(data);

      String savedWhere = 'Downloads';
      File outFile;
      if (Platform.isAndroid) {
        // Try public Downloads first
        final downloadsDir = Directory('/storage/emulated/0/Download');
        Directory targetDir;
        if (await downloadsDir.exists()) {
          targetDir = downloadsDir;
        } else {
          // App-scoped as fallback
          final ext = await getExternalStorageDirectory();
          targetDir = ext ?? await getApplicationDocumentsDirectory();
          savedWhere = 'app storage';
        }
        final outPath =
            '${targetDir.path}${Platform.pathSeparator}Statement_${DateTime.now().millisecondsSinceEpoch}.csv';
        outFile = File(outPath);
      } else {
        final docs = await getApplicationDocumentsDirectory();
        final outPath =
            '${docs.path}${Platform.pathSeparator}Statement_${DateTime.now().millisecondsSinceEpoch}.csv';
        outFile = File(outPath);
        savedWhere = 'Documents';
      }
      await outFile.writeAsString(csv);
      
      // Trigger media scan for immediate visibility
      if (Platform.isAndroid) {
        const MethodChannel('app/notif_channel').invokeMethod('scanFile', {'path': outFile.path});
      }

      if (!mounted) return;
      final msg = (Platform.isAndroid && savedWhere == 'Downloads')
          ? 'Statement saved to Downloads'
          : 'Statement saved to $savedWhere';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green));
    } catch (e) {
      // Fallback: share if saving fails
      try {
        final tmpDir = await getTemporaryDirectory();
        final tmpPath =
            '${tmpDir.path}/Statement_${DateTime.now().millisecondsSinceEpoch}.csv';
        final tmpFile = File(tmpPath);
        // In case csv failed above, regenerate from DB quickly
        final db = await DbHelper.getDatabase();
        final data = await db.query('transactions', orderBy: 'date DESC');
        final csv = _generateCSVString(data);
        await tmpFile.writeAsString(csv);
        if (!mounted) return;
        await Share.shareXFiles([XFile(tmpFile.path)],
            text: 'Transaction Statement');
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error generating statement'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _generateCSVString(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Description,Amount,Category,Type');
    for (final row in rows) {
      final date = (row['date'] ?? '').toString().replaceAll(',', ';');
      final desc = ((row['body'] ?? row['merchant']) ?? '')
          .toString()
          .replaceAll(',', ';');
      final amount = row['amount'] ?? 0;
      final category = (row['category'] ?? '').toString().replaceAll(',', ';');
      final isExpense = (row['isExpense'] ??
              (row['body']?.toString().toLowerCase().contains('received') ==
                      true
                  ? 0
                  : 1)) ==
          1;
      final type = isExpense ? 'Expense' : 'Income';
       buffer.writeln('$date,$desc,$amount,$category,$type');
     }
     return buffer.toString();
   }

   Future<void> _performLogout() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       await prefs.setBool('isLoggedIn', false);
     } catch (e) {
       debugPrint('Error clearing login state: $e');
     }
     if (!mounted) return;
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!mounted) return;
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (context) => const AuthPage(isLogin: true)),
         (route) => false,
       );
     });
   }
 }

// --- ACCOUNT DETAILS PAGE EXTRACTED ---
