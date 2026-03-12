import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'services/db_helper.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> with SingleTickerProviderStateMixin {
  String _firstPin = "";
  String _secondPin = "";
  bool _isConfirming = false;
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _isNavigating = false; // Atomic Navigation Flag
  final TextEditingController _pinController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animationController.dispose();
    super.dispose();
  }



  Future<void> _setupPin() async {
    if (_firstPin != _secondPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Restarting...'), backgroundColor: Colors.red),
      );
      setState(() {
        _firstPin = "";
        _secondPin = "";
        _isConfirming = false;
        _pinController.clear();
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _storage.write(key: 'user_pin', value: _firstPin);
      final prefs = await SharedPreferences.getInstance();
      
      // Update DB with PIN for data integrity
      final identifier = prefs.getString('email') ?? prefs.getString('phone') ?? 'Unknown';
      await DbHelper.updateUserPin(identifier, _firstPin);

      await prefs.setBool('pin_setup_complete', true);
      await prefs.setBool('isLoggedIn', true);

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      _animationController.forward();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _navigateToDashboard();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setup failed. Try again.')),
      );
    }
  }

  void _navigateToDashboard() {
    if (_isNavigating || !mounted) return;

    // Clean the Gesture Arena
    FocusScope.of(context).unfocus();

    setState(() => _isNavigating = true);

    // Atomic Navigation
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _isSuccess ? _buildSuccessUI() : _buildSetupUI(),
      ),
    );
  }

  Widget _buildSetupUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
        final double verticalSpacing = screenHeight * 0.04;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(height: verticalSpacing),
                  // Keyboard Safety: Hide logo if keyboard is up or screen is small
                  Visibility(
                    visible: !isKeyboardVisible && screenHeight > 500,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 80,
                          color: Color(0xFF4CAF50),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                  Text(
                    _isConfirming ? "Confirm PIN" : "Create Security PIN",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConfirming 
                      ? "Enter your 4-digit PIN again" 
                      : "Protect your vault with a 4-digit PIN",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: verticalSpacing),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: TextField(
                      controller: _pinController,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      showCursor: true,
                      cursorColor: const Color(0xFF00FFCC),
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
                        hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 24),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: const Color(0xFF00FFCC).withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00FFCC), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.black12,
                      ),
                      onChanged: (val) {
                        if (_isLoading || _isSuccess) return;
                        if (!_isConfirming) {
                          _firstPin = val;
                          if (_firstPin.length == 4) {
                            Future.delayed(const Duration(milliseconds: 200), () {
                              if (mounted) {
                                setState(() {
                                  _isConfirming = true;
                                  _pinController.clear();
                                });
                              }
                            });
                          }
                        } else {
                          _secondPin = val;
                          if (_secondPin.length == 4) {
                            FocusScope.of(context).unfocus();
                            _setupPin();
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 80, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "PIN Set Successfully!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Welcome to your secure vault.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Custom keypad removed in favor of standard system TextField

}
