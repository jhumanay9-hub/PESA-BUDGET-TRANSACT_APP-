import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Legal & Privacy")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.gavel_rounded, size: 60, color: Color(0xFF2ECC71)),
          const SizedBox(height: 20),
          const Text(
            "Transparency & Trust",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "At Pesa Budget, your financial data remains your own. We prioritize local processing to ensure maximum privacy.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          _buildLegalTile(
            context,
            title: "Privacy Policy",
            icon: Icons.privacy_tip_outlined,
            content:
                "We only access your SMS inbox to identify M-PESA messages. "
                "Transaction data is stored locally on your device and only "
                "synced to your private Supabase cloud account. We never sell your data.",
          ),
          _buildLegalTile(
            context,
            title: "Terms of Service",
            icon: Icons.description_outlined,
            content:
                "By using Pesa Budget, you agree that this app is a tracking tool. "
                "We are not responsible for financial decisions made based on this data. "
                "Always verify your official M-PESA statements for legal purposes.",
          ),
          _buildLegalTile(
            context,
            title: "Data Security",
            icon: Icons.security_outlined,
            content:
                "Your data is protected by a 4-digit PIN and industry-standard "
                "encryption during cloud sync. Unauthorized access is prevented "
                "by our secure 'Soft Lock' mechanism.",
          ),
          _buildLegalTile(
            context,
            title: "Open Source Licenses",
            icon: Icons.code_outlined,
            content:
                "Pesa Budget is built using Flutter and several open-source packages "
                "including Supabase, SQLite, and SMS Handlers. View the full list "
                "on our GitHub repository.",
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              "Last Updated: March 20, 2026",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF2ECC71)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: const TextStyle(color: Color(0xFF2C3E50), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
