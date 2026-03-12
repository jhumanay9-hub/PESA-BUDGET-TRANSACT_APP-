import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.grey[200],
    child: const Text("Pesa Budget • Master your money", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF00FFCC), fontWeight: FontWeight.bold)),
  );
}
