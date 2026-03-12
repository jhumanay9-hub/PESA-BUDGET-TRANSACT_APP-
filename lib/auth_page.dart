import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pin_setup_page.dart';
import 'pin_login_page.dart';
import 'services/db_helper.dart';
import 'services/auth_service.dart';
import 'services/network_service.dart';

class AuthPage extends StatefulWidget {
  final bool isLogin;
  const AuthPage({super.key, this.isLogin = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _isLogin;
  bool _isLoading = false;
  bool _isNavigating = false; // Atomic Navigation Flag
  String? _errorMessage;
  bool _isPasswordStrong = false;
  bool _hasInteracted = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController(); // Email or Phone
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    if (!_hasInteracted) {
      setState(() => _hasInteracted = true);
    }
    final password = _passwordController.text;
    final isStrong = _validatePasswordStrength(password);
    if (isStrong != _isPasswordStrong) {
      setState(() {
        _isPasswordStrong = isStrong;
      });
    }
  }

  bool _validatePasswordStrength(String password) {
    if (password.length < 8) return false;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[@#\$%]').hasMatch(password);
    return hasUppercase && hasLowercase && hasNumber && hasSpecial;
  }

  Future<void> _submitForm() async {
    // Clear previous errors
    setState(() => _errorMessage = null);
    
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();
      final connectivity = await NetworkService().checkConnectivity();
      final isOnline = NetworkService().isOnline(connectivity);
      
      if (!_isLogin) {
        // --- Registration Logic (Offline-First) ---
        final identifier = _identifierController.text.trim();
        final password = _passwordController.text;
        final name = _nameController.text.trim();
        final isPhone = RegExp(r'^\+?[0-9\s\-]{7,15}$').hasMatch(identifier);
        
        String? phone = isPhone ? identifier : null;
        String? email = !isPhone ? identifier : null;
        
        bool cloudUserCreated = false;

        // Try cloud registration if online
        if (isOnline) {
          try {
            final response = await AuthService().signUp(identifier, password);
            if (response.user != null) {
              cloudUserCreated = true;
            } else {
              debugPrint('Supabase sign up returned null user, falling back to local-only');
            }
          } catch (e) {
            debugPrint('Supabase sign up failed (likely network/auth issue): $e');
            // Continue with local-only registration
          }
        }

        // Always save/update local user record
        await DbHelper.insertUser(
          identifier: identifier,
          name: name,
          phone: phone,
          email: email,
          isSyncedToCloud: cloudUserCreated,
        );

        // Save credentials for auto-login
        await prefs.setString('name', name);
        if (phone != null) await prefs.setString('phone', phone);
        if (email != null) await prefs.setString('email', email);
        await storage.write(key: 'user_password', value: password);
        
        if (!cloudUserCreated) {
          debugPrint('User registered locally-only (offline mode or cloud failure)');
        }
      } else {
        // --- Login Logic (Offline-First) ---
        final identifier = _identifierController.text.trim();
        final password = _passwordController.text;
        
        bool cloudAuthSuccess = false;

        // Try cloud authentication if online
        if (isOnline) {
          try {
            final response = await AuthService().signIn(identifier, password);
            if (response.user != null) {
              cloudAuthSuccess = true;
            } else {
              debugPrint('Supabase sign in returned null user, falling back to local-only');
            }
          } catch (e) {
            debugPrint('Supabase sign in failed (likely invalid credentials): $e');
            // Will fall back to local check below
          }
        }

        // If cloud auth succeeded, ensure user record is marked as synced
        if (cloudAuthSuccess) {
          await DbHelper.insertUser(
            identifier: identifier,
            name: prefs.getString('name') ?? identifier,
            phone: prefs.getString('phone'),
            email: prefs.getString('email') ?? identifier,
            isSyncedToCloud: true,
          );
        } else {
          // Offline mode or cloud auth failed: verify local credentials exist
          final userExists = await DbHelper.isUserExists(identifier);
          if (!userExists) {
            setState(() {
              _errorMessage = 'Invalid credentials. No local account found.';
            });
            return;
          }
          // Local credentials exist, allow offline login
          debugPrint('Offline login using local credentials');
        }

        // Save credentials for session
        final savedEmail = prefs.getString('email');
        if (savedEmail == null) {
          await prefs.setString('email', identifier);
        }
        await storage.write(key: 'user_password', value: password);
      }

      await prefs.setBool('isLoggedIn', true);

      // Route based on PIN existence
      final hasPin = await storage.containsKey(key: 'user_pin');
      
      if (!mounted) return;

      // Clean the Gesture Arena
      FocusScope.of(context).unfocus();

      if (_isNavigating) return;
      setState(() => _isNavigating = true);

      // Atomic Navigation: Wrap in addPostFrameCallback to prevent 'locked is not true'
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // Show appropriate success message based on mode
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Welcome back!' : 'Account created!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1, milliseconds: 500),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        if (hasPin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PinLoginPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PinSetupPage()),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vault Theme Colors
    const Color vaultBackground = Color(0xFF0D1B2A);
    const Color vaultCard = Color(0xFF162436);
    const Color kineticMint = Color(0xFF00FFCC);

    return Scaffold(
      backgroundColor: vaultBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenHeight = constraints.maxHeight;
            final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight - 32), // Subtract vertical padding
                child: IntrinsicHeight(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: vaultCard,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Visibility(
                              visible: !isKeyboardVisible,
                              child: Column(
                                children: [
                                  Icon(
                                    _isLogin ? Icons.lock_open : Icons.security,
                                    size: 64,
                                    color: kineticMint,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            Text(
                              _isLogin ? 'Welcome Back' : 'Secure Your Budget',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    const SizedBox(height: 32),

                    // Name Field (Registration Only)
                    if (!_isLogin)
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        showCursor: true,
                        cursorColor: const Color(0xFF00FFCC),
                        cursorWidth: 3.0,
                        cursorHeight: 25.0,
                        decoration: _inputDecoration('Full Name', Icons.person),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter your name'
                            : null,
                      ),
                    if (!_isLogin) const SizedBox(height: 16),

                    // Universal Identifier Field
                    TextFormField(
                      controller: _identifierController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      showCursor: true,
                      cursorColor: const Color(0xFF00FFCC),
                      cursorWidth: 3.0,
                      cursorHeight: 25.0,
                      decoration: _inputDecoration('Email or Phone', Icons.account_circle),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email or phone';
                        final trimmed = value.trim();
                        // If input contains '@', treat as email and validate format
                        if (trimmed.contains('@')) {
                          final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
                          if (!emailRegex.hasMatch(trimmed)) {
                            return 'Enter a valid email (e.g., name@gmail.com)';
                          }
                        } else {
                          // Validate as phone number
                          final phoneRegex = RegExp(r'^\+?[0-9\s\-]{7,15}$');
                          if (!phoneRegex.hasMatch(trimmed)) {
                            return 'Enter a valid phone number';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                     // Password Field
                     TextFormField(
                       controller: _passwordController,
                       style: const TextStyle(color: Colors.white),
                       obscureText: true,
                       showCursor: true,
                       cursorColor: const Color(0xFF00FFCC),
                       cursorWidth: 3.0,
                       cursorHeight: 25.0,
                       decoration: _inputDecoration('Password', Icons.lock),
                       validator: (value) {
                         if (value == null || value.isEmpty) return 'Please enter a password';
                         if (!_isLogin) {
                           if (value.length < 8) return 'Password must be at least 8 characters';
                           if (_hasInteracted && !_validatePasswordStrength(value)) {
                             return 'Must include uppercase, lowercase, number, and special (@#\$%)';
                           }
                         }
                         return null;
                       },
                     ),
                     // Password Strength Indicator (Registration only)
                     if (!_isLogin && _hasInteracted)
                       Align(
                         alignment: Alignment.centerLeft,
                         child: Padding(
                           padding: const EdgeInsets.only(left: 12, top: 4),
                           child: Text(
                             _isPasswordStrong ? 'Strong password' : 'Weak: Use 8+ chars with uppercase, lowercase, number, and @#\$%',
                             style: TextStyle(
                               color: _isPasswordStrong ? Colors.green : Colors.red,
                               fontSize: 12,
                             ),
                           ),
                         ),
                       ),
                    const SizedBox(height: 16),

                    // Confirm Password Field (Registration Only)
                    if (!_isLogin)
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        showCursor: true,
                        cursorColor: const Color(0xFF00FFCC),
                        cursorWidth: 2.5,
                        cursorHeight: 22,
                        decoration: _inputDecoration('Confirm Password', Icons.lock_outline),
                        validator: (value) {
                          if (value != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                     if (!_isLogin) const SizedBox(height: 24),
                    if (_isLogin) const SizedBox(height: 32),

                    // Error Message Display
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kineticMint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : (!_isLogin && !_isPasswordStrong)
                                ? null
                                : () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _submitForm();
                            });
                          },
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                _isLogin ? 'LOGIN' : 'REGISTER',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle Link
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLogin = !_isLogin;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'New to Pesa Budget? Register'
                            : 'Welcome back! Login to Vault',
                        style: const TextStyle(color: kineticMint),
                      ),
                    ),
                  ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
      filled: true,
      fillColor: const Color(0xFF0D1B2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
    );
  }
}
