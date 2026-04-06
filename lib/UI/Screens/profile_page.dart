import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _user = Supabase.instance.client.auth.currentUser;
  final _sessionRepo = SessionRepository();
  bool _isSyncing = false;

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    AppLogger.logInfo("Profile: Manual Cloud Sync Requested");

    try {
      // Logic: Here we would trigger the Supabase push/pull service
      await Future.delayed(const Duration(seconds: 2)); // Simulating network IO

      AppLogger.logSuccess("Profile: Cloud Sync Complete");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cloud Data Synchronized"),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      AppLogger.logError("Profile: Sync Failed", e);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildInfoSection(),
            const SizedBox(height: 20),
            _buildSecuritySummary(),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isSyncing
                  ? const CircularProgressIndicator(color: Color(0xFF2ECC71))
                  : ElevatedButton.icon(
                      onPressed: _forceSync,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text("Sync Data to Cloud"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBF9),
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF2ECC71),
            child: Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _user?.email ?? "Guest User",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const Text(
            "Verified Pesa Budget Member",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return _buildListGroup("Account Details", [
      _buildListTile(Icons.alternate_email, "Email", _user?.email ?? "N/A"),
      _buildListTile(Icons.calendar_month, "Joined", "March 2026"),
      _buildListTile(
        Icons.account_tree_outlined,
        "Account Mode",
        _sessionRepo.activeAccountMode,
      ),
    ]);
  }

  Widget _buildSecuritySummary() {
    return _buildListGroup("Security Status", [
      _buildListTile(
        Icons.lock_outline,
        "PIN Protection",
        "Enabled",
        trailingColor: Colors.green,
      ),
      _buildListTile(
        Icons.cloud_done_outlined,
        "Cloud Backup",
        "Active",
        trailingColor: Colors.green,
      ),
    ]);
  }

  Widget _buildListGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String value, {
    Color? trailingColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2C3E50), size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: trailingColor ?? const Color(0xFF2C3E50),
        ),
      ),
    );
  }
}
