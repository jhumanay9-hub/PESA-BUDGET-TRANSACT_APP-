import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_page.dart';
import 'main.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isNavigating = false;
  
  static const _storage = FlutterSecureStorage();
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
          localizedReason: 'Please authenticate to unlock Vault',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (authenticated) {
          final savedPin = await _storage.read(key: 'user_pin');
          if (savedPin != null) {
            await prefs.setBool('isLoggedIn', true);
            if (mounted) {
              FocusManager.instance.primaryFocus?.unfocus();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => const Dashboard()));
                }
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Biometric login error: $e');
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loginWithPin() async {
    if (_pinController.text.length != 4) {
      _showErrorDialog('PIN must be exactly 4 digits');
      return;
    }

    if (_isNavigating) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final storedPin = await _storage.read(key: 'user_pin');
      if (storedPin == _pinController.text) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        if (mounted) {
          setState(() => _isNavigating = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Dashboard()),
                (route) => false,
              );
            }
          });
        }
      } else {
        _showErrorDialog('Invalid PIN');
      }
    } catch (e) {
      _showErrorDialog('PIN verification failed');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color vaultBackground = Color(0xFF0D1B2A);
    const Color kineticMint = Color(0xFF00FFCC);
    const Color vaultCard = Color(0xFF162436);

    return Scaffold(
      backgroundColor: vaultBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenHeight = constraints.maxHeight;
            final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Visibility(
                        visible: !isKeyboardVisible,
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: kineticMint.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 50,
                                color: kineticMint,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      const Text(
                        "Unlock Vault",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Enter your 4-digit PIN",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 60),
                      
                      // PIN Form Container
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: vaultCard,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: TextField(
                                controller: _pinController,
                                autofocus: true,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                showCursor: true,
                                cursorColor: kineticMint,
                                cursorWidth: 3.0,
                                cursorHeight: 25.0,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  letterSpacing: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  counterText: "",
                                  hintText: "••••",
                                  hintStyle: const TextStyle(
                                    color: Colors.white24,
                                    letterSpacing: 24,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: kineticMint.withValues(alpha: 0.5)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: kineticMint, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black12,
                                ),
                                onChanged: (value) {
                                  if (value.length == 4) {
                                    // Auto-trigger login when 4 digits are entered
                                    _loginWithPin();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                if (_isLoading) return;
                                FocusScope.of(context).unfocus();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AuthPage(isLogin: true)),
                                );
                              },
                              child: const Text(
                                "Login with Universal Identifier",
                                style: TextStyle(color: kineticMint),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kineticMint,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _loginWithPin,
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        "Unlock",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Keyboard removed in favor of standard system TextField
}
