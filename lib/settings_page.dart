import 'dart:async';
import 'package:local_auth/local_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main.dart';
import 'ui/footer.dart';
import 'ui/debug_dashboard_screen.dart';
import 'auth_page.dart';
import 'services/db_helper.dart';
import 'services/network_service.dart';
import 'services/auth_service.dart';
import 'services/transaction_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool biometricLogin = false;
  bool transactionAlerts = true;
  String selectedTheme = 'Light';
  late VoidCallback _themeListener;
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  // Developer mode
  bool _isDeveloperMode = false;
  String _syncMethod = 'mobile';

  // Secret tap counter for debug menu
  int _secretTapCount = 0;
  Timer? _tapResetTimer;

  // Network monitoring
  List<ConnectivityResult> _connectivityResults = [];
  StreamSubscription? _networkSub;

  @override
  void initState() {
    super.initState();
    _updateSelectedThemeFromNotifier();
    _loadPreferences();
    _themeListener = () {
      _updateSelectedThemeFromNotifier();
    };
    themeNotifier.addListener(_themeListener);
    _initNetwork();
  }

  void _initNetwork() async {
    _connectivityResults = await NetworkService().checkConnectivity();
    _networkSub = NetworkService().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _connectivityResults = results);
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alerts = prefs.getBool('is_alerts_enabled') ?? true;
      final bio = prefs.getBool('is_biometric_enabled') ?? false;
      final isDev = prefs.getBool('is_developer_mode') ?? false;
      final syncMethod = prefs.getString('sync_method') ?? 'mobile';
      if (mounted) {
        setState(() {
          transactionAlerts = alerts;
          biometricLogin = bio;
          _isDeveloperMode = isDev;
          _syncMethod = syncMethod;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings prefs: $e');
    }
  }

  void _updateSelectedThemeFromNotifier() {
    final t = themeNotifier.value;
    String label;
    switch (t) {
      case AppTheme.dark:
        label = 'Dark';
        break;
      case AppTheme.eyeComfort:
        label = 'Eye Comfort';
        break;
      case AppTheme.light:
        label = 'Light';
    }
    if (mounted) {
      setState(() => selectedTheme = label);
    }
  }

  void _handleSecretTap() {
    _tapResetTimer?.cancel();
    _secretTapCount++;

    if (_secretTapCount == 7) {
      _secretTapCount = 0;
      _tapResetTimer?.cancel();
      _showDebugMenu();
      return;
    }

    _tapResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _secretTapCount = 0;
        });
      }
    });
  }

  void _showDebugMenu() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Debug Tools', style: TextStyle(fontFamily: 'sans-serif')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugDashboardScreen()),
                );
              },
              child: const Text('Open Debug Dashboard'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All preferences cleared')),
                  );
                }
              },
              child: const Text('Clear SharedPreferences'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_themeListener);
    _networkSub?.cancel();
    _tapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Settings"),
            if (NetworkService().isOnline(_connectivityResults) == false)
              const Text(
                "Offline Mode",
                style: TextStyle(fontSize: 10, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF0D1B2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Section
            _buildSectionHeader("Security"),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.grey[800],
                    displayColor: Colors.grey[800],
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        "Biometric Login",
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        "Use fingerprint or face recognition",
                        style: TextStyle(
                          fontFamily: 'sans-serif',
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      value: biometricLogin,
                      onChanged: (value) async {
                        if (value) {
                          try {
                            final canCheck = await _localAuth.canCheckBiometrics;
                            final isSupported = await _localAuth.isDeviceSupported();
                            if (!canCheck || !isSupported) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Biometrics not available on this device')),
                                );
                              }
                              return;
                            }
                            bool authenticated = await _localAuth.authenticate(
                              localizedReason: 'Please authenticate to enable biometric login',
                              options: const AuthenticationOptions(stickyAuth: true),
                            );
                            if (!authenticated) return;
                          } catch (e) {
                            debugPrint('Bio auth error: $e');
                            return;
                          }
                        }
                        setState(() => biometricLogin = value);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_biometric_enabled', value);
                      },
                      activeThumbColor: const Color(0xFF00FFCC),
                      secondary: const Icon(
                        Icons.fingerprint,
                        color: Color(0xFF00FFCC),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text(
                        "Change App PIN",
                        style: TextStyle(fontFamily: 'sans-serif', fontSize: 16),
                      ),
                      subtitle: Text(
                        "Update your security PIN",
                        style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: Colors.grey[800]),
                      ),
                      leading: Icon(Icons.lock, color: Colors.green[800]),
                      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                      onTap: () => _showChangePinDialog(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notifications Section
            _buildSectionHeader("Notifications"),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      "Transaction Alerts",
                      style: TextStyle(fontFamily: 'sans-serif', fontSize: 16),
                    ),
                    subtitle: Text(
                      "Get notified for new transactions",
                      style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: Colors.grey[800]),
                    ),
                    value: transactionAlerts,
                    onChanged: (value) async {
                      setState(() => transactionAlerts = value);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_alerts_enabled', value);
                      } catch (e) {
                        debugPrint('Error saving alerts preference: $e');
                      }
                    },
                    activeThumbColor: Colors.green[800],
                    secondary: Icon(Icons.notifications_active, color: Colors.green[800]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appearance Section
            _buildSectionHeader("Appearance"),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Theme", style: TextStyle(fontFamily: 'sans-serif', fontSize: 16)),
                    subtitle: Text(
                      "Choose app appearance",
                      style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: Colors.grey[800]),
                    ),
                    leading: Icon(Icons.palette, color: Colors.green[800]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildThemeOption(AppTheme.light, Icons.light_mode),
                        const SizedBox(height: 8),
                        _buildThemeOption(AppTheme.dark, Icons.dark_mode),
                        const SizedBox(height: 8),
                        _buildThemeOption(AppTheme.eyeComfort, Icons.wb_sunny),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cloud & Sync Section
            _buildSectionHeader("Cloud & Sync"),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Sync Now", style: TextStyle(fontFamily: 'sans-serif', fontSize: 16)),
                    subtitle: Builder(builder: (context) {
                      final isOnline = NetworkService().isOnline(_connectivityResults);
                      String statusText = "Last sync: Just now";
                      if (!isOnline) {
                        statusText = "Offline - Sync unavailable";
                      }
                      return Text(
                        statusText,
                        style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: Colors.grey[800]),
                      );
                    }),
                    leading: Builder(builder: (context) {
                      final isOnline = NetworkService().isOnline(_connectivityResults);
                      return Icon(
                        Icons.cloud_upload,
                        color: isOnline ? Colors.blue[700] : Colors.grey,
                      );
                    }),
                    enabled: NetworkService().isOnline(_connectivityResults),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cloud sync started...")),
                      );
                      try {
                        await TransactionService().syncAllLocalTransactions();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Sync complete"), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Sync failed: $e"), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _setSyncMethod('mobile'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _syncMethod == 'mobile' ? Colors.green[800] : Colors.grey[200],
                              foregroundColor: _syncMethod == 'mobile' ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Use Mobile Data'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _setSyncMethod('wifi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _syncMethod == 'wifi' ? Colors.green[800] : Colors.grey[200],
                              foregroundColor: _syncMethod == 'wifi' ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Use WiFi Only'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader("About"),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Developer", style: TextStyle(fontFamily: 'sans-serif', fontSize: 16)),
                    subtitle: const Text(
                      "Pesa Budget Team",
                      style: TextStyle(fontFamily: 'sans-serif', fontSize: 14),
                    ),
                    leading: Icon(Icons.code, color: Colors.green[800]),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(
                      "Debugger",
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 16,
                        color: _isDeveloperMode ? null : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      _isDeveloperMode ? "System diagnostics & logs" : "Tap version 7× to unlock",
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    leading: Icon(
                      Icons.bug_report_outlined,
                      color: _isDeveloperMode ? const Color(0xFF00FFCC) : Colors.grey,
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: _isDeveloperMode ? Colors.grey[400] : Colors.grey[300],
                      size: 16,
                    ),
                    onTap: _isDeveloperMode
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DebugDashboardScreen(),
                              ),
                            );
                          }
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text(
                      "Logout",
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 16,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      "Sign out of your account",
                      style: TextStyle(fontFamily: 'sans-serif', fontSize: 14, color: Colors.red),
                    ),
                    leading: const Icon(Icons.logout, color: Colors.red),
                    onTap: () => _showLogoutConfirmation(),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: const Text(
                        "App Version",
                        style: TextStyle(fontFamily: 'sans-serif', fontSize: 16),
                      ),
                      subtitle: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleSecretTap,
                        child: Text(
                          _isDeveloperMode ? "Pesa Budget v1.0  🛠️ Developer Mode" : "Pesa Budget v1.0",
                          style: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 14,
                            color: _isDeveloperMode ? const Color(0xFF00FFCC) : null,
                          ),
                        ),
                      ),
                      leading: Icon(Icons.info, color: Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Future<void> _setSyncMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_method', method);
    if (mounted) {
      setState(() {
        _syncMethod = method;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
          fontFamily: 'sans-serif',
        ),
      ),
    );
  }

  Widget _buildThemeOption(AppTheme theme, IconData icon) {
    final label = theme == AppTheme.light
        ? 'Light'
        : theme == AppTheme.dark
            ? 'Dark'
            : 'Eye Comfort';
    final isSelected = selectedTheme == label;
    return InkWell(
      onTap: () async {
        await themeNotifier.setTheme(theme);
        if (mounted) setState(() => selectedTheme = label);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green[800]! : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.green[50] : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.green[800] : Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.green[800] : Colors.black87,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: Colors.green[800], size: 20),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog() {
    final TextEditingController currentPinController = TextEditingController();
    final TextEditingController newPinController = TextEditingController();
    final TextEditingController confirmPinController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Change App PIN", style: TextStyle(fontFamily: 'sans-serif')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPinController,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                showCursor: true,
                cursorColor: const Color(0xFF00FFCC),
                cursorWidth: 3.0,
                cursorHeight: 25.0,
                decoration: const InputDecoration(
                  labelText: "Current PIN",
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                showCursor: true,
                cursorColor: const Color(0xFF00FFCC),
                cursorWidth: 3.0,
                cursorHeight: 25.0,
                decoration: const InputDecoration(
                  labelText: "New PIN",
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                showCursor: true,
                cursorColor: const Color(0xFF00FFCC),
                cursorWidth: 3.0,
                cursorHeight: 25.0,
                decoration: const InputDecoration(
                  labelText: "Confirm New PIN",
                  border: OutlineInputBorder(),
                  counterText: "",
                ),
              ),
              if (isSaving)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final currentInput = currentPinController.text;
                      final newPin = newPinController.text;
                      final confirmPin = confirmPinController.text;

                      if (newPin != confirmPin || newPin.length != 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("PINs do not match or are invalid!"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        final storedPin = await _storage.read(key: 'user_pin');
                        if (storedPin != currentInput) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Incorrect current PIN"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          setDialogState(() => isSaving = false);
                          return;
                        }

                        await _storage.write(key: 'user_pin', value: newPin);
                        final prefs = await SharedPreferences.getInstance();
                        final identifier = prefs.getString('email') ?? prefs.getString('phone') ?? 'Unknown';
                        await DbHelper.updateUserPin(identifier, newPin);

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("PIN changed successfully!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Error changing PIN"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
              child: const Text("Change PIN"),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout", style: TextStyle(fontFamily: 'sans-serif')),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(fontFamily: 'sans-serif'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      final navigator = Navigator.of(context);
      try {
        await AuthService().signOut();
      } catch (e) {
        debugPrint('Supabase sign out failed (likely offline): $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('email');
      await _storage.delete(key: 'user_pin');
      await _storage.delete(key: 'user_password');
      await prefs.remove('qc_body');
      await prefs.remove('qc_amount');
      await prefs.remove('qc_merchant');

      if (!mounted) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthPage(isLogin: true)),
          (route) => false,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error logging out'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
