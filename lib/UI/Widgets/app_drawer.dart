import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transaction_app/data/session_repository.dart';

/// ============================================================================
/// APP DRAWER - HAMBURGER MENU
/// ============================================================================
/// Navigation menu with Profile, Settings, Reports, and Legal sections.
/// ============================================================================
class AppDrawer extends StatelessWidget {
  final SessionRepository _sessionRepo = SessionRepository();

  AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF0A0E0C),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Profile Header
            _buildProfileHeader(context),

            const Divider(color: Color(0xFF2ECC71), height: 1),

            // Settings Section
            _buildSectionHeader('Settings'),
            _buildDrawerTile(
              context,
              icon: Icons.palette_outlined,
              title: 'Themes',
              subtitle: 'Customize appearance',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            _buildDrawerTile(
              context,
              icon: Icons.lock_outline,
              title: 'Change PIN',
              subtitle: 'Update security code',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/security');
              },
            ),
            _buildDrawerTile(
              context,
              icon: Icons.fingerprint,
              title: 'Biometrics',
              subtitle: 'Fingerprint login',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/security');
              },
            ),

            const Divider(color: Color(0xFF2ECC71), height: 1),

            // Reports Section
            _buildSectionHeader('Reports'),
            _buildDrawerTile(
              context,
              icon: Icons.download_outlined,
              title: 'Download Statement',
              subtitle: 'Export transactions',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/download-statement');
              },
            ),

            const Divider(color: Color(0xFF2ECC71), height: 1),

            // Legal Section
            _buildSectionHeader('Legal'),
            _buildDrawerTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we protect your data',
              onTap: () {
                Navigator.pop(context);
                // Navigate to legal page
              },
            ),
            _buildDrawerTile(
              context,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'User agreement',
              onTap: () {
                Navigator.pop(context);
                // Navigate to legal page
              },
            ),

            const Divider(color: Color(0xFF2ECC71), height: 1),

            // Logout Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // App Version
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Pesa Budget v1.0.0',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF141D1A),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          const CircleAvatar(
            radius: 35,
            backgroundColor: Color(0xFF2ECC71),
            child: Icon(
              Icons.person,
              size: 35,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // User Name
          FutureBuilder<String>(
            future: _getUserName(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? 'Pesa Budget User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          // User Email
          const Text(
            'user@pesabudget.local',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2ECC71),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF2ECC71), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white54,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Future<String> _getUserName() async {
    // In a real app, this would fetch from user profile
    return 'Pesa Budget User';
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2ECC71), width: 1),
        ),
        title: const Text(
          'Logout?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You will need to enter your PIN to access the app again.',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _sessionRepo.setLoginStatus(false);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close drawer
                // Exit the app completely (user will see Registration on next launch)
                SystemNavigator.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
