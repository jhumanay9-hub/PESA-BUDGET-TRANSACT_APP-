import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';

/// ============================================================================
/// PIN LOCK SCREEN - RECREATED WITH UNIFORM THEME
/// ============================================================================
/// This screen appears when:
/// 1. App is launched and user has PIN but session not authenticated
/// 2. User returns to app after being away (app was paused)
///
/// Navigation:
/// - Success: Calls onVerified callback and pops
/// - Failure: Shows error and clears input
/// ============================================================================
class PinLockScreen extends StatefulWidget {
  /// Callback when PIN is successfully verified
  final VoidCallback onVerified;

  /// Optional title text
  final String title;

  const PinLockScreen({
    super.key,
    required this.onVerified,
    this.title = 'Enter PIN to Unlock',
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with TickerProviderStateMixin {
  final List<String> _inputPin = [];
  final int _pinLength = 4;
  final SessionRepository _sessionRepo = SessionRepository();
  String _errorMessage = '';

  // Animation controller for shake effect on wrong PIN
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Haptic feedback for better UX
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String value) {
    // Prevent input if already processing or PIN complete
    if (_inputPin.length >= _pinLength) return;

    setState(() {
      _inputPin.add(value);
      _errorMessage = ''; // Clear error on new input
    });

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    // Auto-verify when PIN is complete
    if (_inputPin.length == _pinLength) {
      // Small delay for visual feedback
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _verifyPin();
        }
      });
    }
  }

  void _backspace() {
    if (_inputPin.isEmpty) return;

    setState(() {
      _inputPin.removeLast();
      _errorMessage = '';
    });

    HapticFeedback.lightImpact();
  }

  void _verifyPin() {
    final String enteredPin = _inputPin.join();
    final bool isValid = _sessionRepo.validatePin(enteredPin);

    if (isValid) {
      AppLogger.logSuccess('Security: PIN Verified - Unlocking Dashboard');

      // Success haptic feedback
      HapticFeedback.mediumImpact();

      // FIX: Call onVerified FIRST to update parent state, THEN pop
      // This ensures AuthWrapper sets _isSessionAuthenticated = true before navigation
      widget.onVerified();

      // Small delay to ensure state update is processed
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } else {
      AppLogger.logWarning('Security: Incorrect PIN attempt');

      // Error haptic feedback
      HapticFeedback.vibrate();

      // Trigger shake animation
      _shakeController.forward().then((_) {
        _shakeController.reverse();
      });

      // Show error and clear input
      setState(() {
        _inputPin.clear();
        _errorMessage = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unlock App"),
        backgroundColor: const Color(0xFF0A0E0C),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0A0E0C),
      body: _buildPinView(),
    );
  }

  Widget _buildPinView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Enter your 4-digit PIN",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF2ECC71),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // PIN Display (Dots)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _inputPin.length
                    ? const Color(0xFF2ECC71)
                    : Colors.grey.shade800,
              ),
            );
          }),
        ),

        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 14),
            ),
          ),

        const SizedBox(height: 60),

        // Custom Numpad
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              if (index == 9) return const SizedBox.shrink();
              if (index == 10) return _buildNumButton("0");
              if (index == 11) {
                return IconButton(
                  onPressed: _backspace,
                  icon:
                      const Icon(Icons.backspace_outlined, color: Colors.white),
                );
              }
              return _buildNumButton("${index + 1}");
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumButton(String value) {
    return TextButton(
      onPressed: () => _onKeyPress(value),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
