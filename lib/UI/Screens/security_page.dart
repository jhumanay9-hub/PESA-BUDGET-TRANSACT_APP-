import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _biometricsEnabled = false;

  void _navigateToChangePin() {
    AppLogger.logInfo("Security: Navigating to PIN Update");
    Navigator.of(
      context,
    ).pushNamed('/create-pin', arguments: {'mode': 'change'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Security & Privacy")),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _buildSecurityTile(
            icon: Icons.lock_outline,
            title: "Update Access PIN",
            subtitle: "Set a new 4-digit code for Pesa Budget",
            onTap: _navigateToChangePin,
          ),
          const Divider(indent: 70),
          _buildSecurityTile(
            icon: Icons.fingerprint,
            title: "Biometric Login",
            subtitle: "Unlock Pesa Budget with your fingerprint",
            trailing: Switch(
              value: _biometricsEnabled,
              activeThumbColor: const Color(0xFF2ECC71),
              onChanged: (val) {
                setState(() => _biometricsEnabled = val);
                AppLogger.logInfo(
                  "Security: Biometrics ${val ? 'Enabled' : 'Disabled'}",
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Note: PIN is always required as a backup if biometric authentication fails.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF0FDF4),
        child: Icon(icon, color: const Color(0xFF2C3E50), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }
}
