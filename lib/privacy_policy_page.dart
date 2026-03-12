import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Light gray background
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
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
                'Privacy Policy',
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
              
              // Non-Affiliation Clause
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF4CAF50)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1. Non-Affiliation Clause',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Pesa Budget is an independent financial tracking utility. It is NOT affiliated with, endorsed by, or connected to Safaricom PLC, M-Pesa, or any of their subsidiaries. All trademarks and brand names belong to their respective owners.',
                style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
              SizedBox(height: 24),

              // SMS Parsing
              Text(
                '2. SMS Parsing & Local Storage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
              ),
              SizedBox(height: 8),
              Text(
                'The app requires access to read your SMS messages exclusively to identify and categorize M-Pesa transactions. All parsing and extraction happens entirely on your local device. The developer cannot view your messages.',
                style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
              SizedBox(height: 24),

              // Data Security
              Text(
                '3. Data Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
              ),
              SizedBox(height: 8),
              Text(
                'Your PIN and authentication data are encrypted and securely stored using standard mobile secure keystore technology present on your phone. No data leaves your mobile device under any circumstances.',
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
