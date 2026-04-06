import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/services/sms_service.dart';
import 'package:transaction_app/services/service_coordinator.dart';
import 'package:transaction_app/ui/screens/dashboard_screen.dart';

/// PIN Creation Page - Second step in onboarding flow
/// User creates 4-digit PIN + enters phone number for cloud backup
/// Navigation: PinCreationPage -> Dashboard
/// After PIN creation, user interaction is marked to trigger services
class PinCreationPage extends StatefulWidget {
  const PinCreationPage({super.key});

  @override
  State<PinCreationPage> createState() => _PinCreationPageState();
}

class _PinCreationPageState extends State<PinCreationPage> {
  final List<String> _pin = [];
  final int _pinLength = 4;
  final _sessionRepo = SessionRepository();
  final _smsService = SmsService();
  final _dbHelper = DatabaseHelper();
  final _phoneController = TextEditingController();

  bool _isProcessing = false;
  bool _showPhoneInput = false;
  String _errorMessage = '';

  // Pre-fetch dashboard data in background to prevent initial jank
  Future<void> _prefetchDashboardData() async {
    try {
      // Pre-load categories (will be cached for Dashboard)
      await _dbHelper.getAllCategoriesWithDetails();
      // Pre-load transactions (will be cached for Dashboard)
      await _dbHelper.getFilteredTransactions(
        mode: 'Personal',
        category: 'General',
        type: 'All',
        timeframe: 'All Time',
        sortBy: 'Date',
      );
      AppLogger.logInfo('PinCreationPage: Dashboard data pre-fetched');
    } catch (e) {
      // Silently fail - Dashboard will load normally
    }
  }

  void _onKeyPress(String value) {
    if (_isProcessing) return;

    if (_pin.length < _pinLength) {
      setState(() {
        _pin.add(value);
        _errorMessage = '';
      });
    }

    if (_pin.length == _pinLength) {
      // PIN complete - show phone input
      setState(() => _showPhoneInput = true);
    }
  }

  void _backspace() {
    if (_isProcessing) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
        _errorMessage = '';
      });
    }
    if (_pin.length < _pinLength) {
      setState(() => _showPhoneInput = false);
    }
  }

  Future<void> _finalizePinAndPhone() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Phone number required for cloud backup');
      return;
    }

    // Validate phone number (Kenyan format)
    final phoneRegex = RegExp(r'^(\+254|0)?[79]\d{8}$');
    if (!phoneRegex.hasMatch(_phoneController.text.trim())) {
      setState(() => _errorMessage = 'Invalid phone number (e.g., 0712345678)');
      return;
    }

    setState(() => _isProcessing = true);

    String finalPin = _pin.join();
    String phoneNumber = _phoneController.text.trim();

    AppLogger.logInfo('Security: Saving PIN and linking phone number');

    try {
      // 1. Save PIN locally
      await _sessionRepo.savePin(finalPin);
      AppLogger.logSuccess('Security: PIN established');

      // 2. Mark as NOT first-time user
      await _sessionRepo.setFirstTimeUserComplete();
      AppLogger.logInfo('Security: First-time user flag cleared');

      // 3. Sign in to cloud with Phone + PIN (creates account or signs in)
      final authSuccess =
          await _sessionRepo.signInWithPhoneAndPin(phoneNumber, finalPin);
      if (!authSuccess) {
        AppLogger.logWarning(
            'Cloud: Failed to create cloud backup - continuing with local mode');
      }

      // 4. Mark user interaction (PIN creation counts as first interaction)
      ServiceCoordinator().forceMarkInteraction();
      AppLogger.logInfo('ServiceCoordinator: User interaction marked');

      // 5. Pre-fetch dashboard data in background (prevents initial jank)
      // Fire and forget - Dashboard will use cached data
      if (mounted) {
        _prefetchDashboardData();
      }

      // 6. Navigate to Dashboard IMMEDIATELY (don't wait for SMS sync)
      if (mounted) {
        // Use pushAndRemoveUntil to clear the navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false, // Remove all previous routes
        );
      }

      // 7. Fire SMS sync in background
      _smsService.syncInbox().catchError((e) {
        AppLogger.logError('SMS: Background parsing failed', e);
      });
    } catch (e) {
      AppLogger.logError('PIN Creation: Failed', e);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to create PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E0C),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2ECC71)),
              const SizedBox(height: 24),
              const Text(
                "Setting up cloud backup...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Your data is being secured",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_showPhoneInput ? "Enter Phone Number" : "Set Secure PIN"),
        backgroundColor: const Color(0xFF0A0E0C),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0A0E0C),
      body: _showPhoneInput ? _buildPhoneInputView() : _buildPinView(),
    );
  }

  Widget _buildPinView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Create a 4-digit PIN",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Text(
          "You'll use this + phone number for cloud backup",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                color: index < _pin.length
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

  Widget _buildPhoneInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 60,
            color: Color(0xFF2ECC71),
          ),
          const SizedBox(height: 24),
          const Text(
            "Link Phone Number for Cloud Backup",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Your PIN + phone number secure your data in the cloud",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Phone Number Field
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              prefixText: '+254 ',
              prefixStyle:
                  const TextStyle(color: Color(0xFF2ECC71), fontSize: 16),
              hintText: '712 345 678',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              labelText: 'M-PESA Phone Number',
              labelStyle: const TextStyle(color: Color(0xFF2ECC71)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2ECC71)),
              ),
            ),
          ),

          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 14),
              ),
            ),

          const SizedBox(height: 32),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _finalizePinAndPhone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "CONTINUE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Back Button
          TextButton(
            onPressed: () {
              setState(() {
                _showPhoneInput = false;
                _pin.clear();
                _errorMessage = '';
              });
            },
            child: const Text(
              "BACK",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
