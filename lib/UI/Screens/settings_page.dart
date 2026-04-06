import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          // CATEGORY: ACCOUNT & SECURITY
          _buildSectionHeader("Account & Protection"),
          _buildSettingTile(
            icon: Icons.security,
            title: "Security Settings",
            subtitle: "PIN, Biometrics, and Privacy",
            onTap: () => Navigator.pushNamed(context, '/security'),
          ),

          // CATEGORY: APPEARANCE
          const Divider(),
          _buildSectionHeader("Appearance"),
          _buildSettingTile(
            icon: Icons.palette_outlined,
            title: "Dark Mode",
            subtitle: "Easier on the eyes (and Huawei battery)",
            trailing: Switch(
              value: _isDarkMode,
              activeThumbColor: const Color(0xFF2ECC71),
              onChanged: (val) {
                setState(() => _isDarkMode = val);
                AppLogger.logInfo(
                  "Theme: Switched to ${val ? 'Dark' : 'Light'} Mode",
                );
              },
            ),
          ),

          // CATEGORY: NOTIFICATIONS
          const Divider(),
          _buildSectionHeader("Preferences"),
          _buildSettingTile(
            icon: Icons.notifications_none,
            title: "M-PESA Alerts",
            subtitle: "Receive notifications for new SMS",
            trailing: Switch(
              value: _notificationsEnabled,
              activeThumbColor: const Color(0xFF2ECC71),
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
          ),

          // CATEGORY: SYSTEM
          const Divider(),
          _buildSectionHeader("System"),
          _buildSettingTile(
            icon: Icons.delete_sweep_outlined,
            title: "Clear Local Cache",
            subtitle: "Free up space on your device",
            onTap: () =>
                AppLogger.logWarning("Settings: Cache clearing initiated"),
          ),

          const SizedBox(height: 50),
          const Center(
            child: Text(
              "Pesa Budget v1.0.0 (Clean Slate)",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2ECC71),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF2C3E50), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
