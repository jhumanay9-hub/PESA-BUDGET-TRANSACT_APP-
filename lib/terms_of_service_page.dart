import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light gray background
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D1B2A),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Last Updated: March 2026',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 24),

              // Clause 1
              Text(
                '1. Acceptance of Terms',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
              ),
              SizedBox(height: 8),
              Text(
                'By accessing and using Pesa Budget, you agree to be bound by these local usage laws and Terms of Service. If you do not agree with any part of these terms, you are prohibited from using this app.',
                style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
              SizedBox(height: 24),

              // Zero-Server Rule
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.gpp_good, color: Color(0xFF4CAF50)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '2. The Zero-Server Rule',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Pesa Budget operates strictly offline. All financial data, transactions, and preferences are stored exclusively on your device. We do not upload, transmit, or store any of your transaction history on remote servers. You have complete control over your data.',
                style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
              SizedBox(height: 24),

              // Clause 3
              Text(
                '3. User Responsibilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
              ),
              SizedBox(height: 8),
              Text(
                'You are solely responsible for securing your device and maintaining the confidentiality of your PIN. Since Pesa Budget utilizes a Zero-Server architecture, we are completely unable to retrieve or reset your data if your device is compromised.',
                style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
              SizedBox(height: 40),
              
              Divider(),
              SizedBox(height: 16),
              Center(
                child: Text(
                  '© Pesa Budget. Master your money.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF00FFCC)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
