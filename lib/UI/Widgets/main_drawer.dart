import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 1. Header (Profile Quick-View)
          _buildHeader(),

          // 2. Navigation Items (Categorized)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(
                  icon: Icons.person_outline,
                  label: "Profile",
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                _drawerItem(
                  icon: Icons.history,
                  label: "Transaction History",
                  onTap: () => Navigator.pushNamed(context, '/history'),
                ),
                _drawerItem(
                  icon: Icons.file_download_outlined,
                  label: "Download Statement",
                  onTap: () => Navigator.pushNamed(context, '/statements'),
                ),
                const Divider(),
                _drawerItem(
                  icon: Icons.settings_outlined,
                  label: "Settings",
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                _drawerItem(
                  icon: Icons.gavel_outlined,
                  label: "Legal & Privacy",
                  onTap: () => Navigator.pushNamed(context, '/legal'),
                ),
              ],
            ),
          ),

          // 3. Footer (Logout Action)
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const UserAccountsDrawerHeader(
      decoration: BoxDecoration(color: Color(0xFF2C3E50)),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Color(0xFF2ECC71),
        child: Icon(Icons.person, color: Colors.white, size: 40),
      ),
      accountName: Text(
        "Pesa Budget User",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      accountEmail: Text("jhumanay9-hub"),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2C3E50)),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text(
            "Logout",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            AppLogger.logWarning("Auth: User initiated Logout");
            await SessionRepository().setLoginStatus(false);
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
        ),
        const SizedBox(height: 10),
        const Text(
          "v1.0.0 (Clean Slate)",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
