import 'package:flutter/material.dart';
import '../services/logger.dart';
import '../auth_page.dart';

class GlobalErrorScreen extends StatelessWidget {
  final dynamic error;
  final StackTrace? stackTrace;

  const GlobalErrorScreen({super.key, this.error, this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const AuthPage(isLogin: true),
      },
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Color(0xFF00FFCC)),
                const SizedBox(height: 24),
                const Text(
                  "Something Went Wrong",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Pesa Budget encountered an unexpected error. Don't worry, your data is safe.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                 ElevatedButton(
                    onPressed: () {
                      // Hard reset: Navigate to login screen and clear error stack
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    },
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF00FFCC),
                     foregroundColor: Colors.black,
                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   child: const Text("RESTART APP", style: TextStyle(fontWeight: FontWeight.bold)),
                 ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Logger.info("User reported issue from Error Screen: $error");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Issue reported. Thank you!")),
                    );
                  },
                  child: const Text(
                    "Report Issue",
                    style: TextStyle(color: Color(0xFF00FFCC)),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Error: ${error.toString()}",
                      style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontFamily: 'monospace'),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
