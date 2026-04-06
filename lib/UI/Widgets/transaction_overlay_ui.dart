import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class TransactionOverlayUI extends StatefulWidget {
  const TransactionOverlayUI({super.key});

  @override
  State<TransactionOverlayUI> createState() => _TransactionOverlayUIState();
}

class _TransactionOverlayUIState extends State<TransactionOverlayUI> {
  // 1. Hold the data coming from the Isolate bridge
  Map<String, dynamic>? _txData;

  @override
  void initState() {
    super.initState();
    // 2. Listen for the serialized Map sent from OverlayService
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _txData = Map<String, dynamic>.from(event);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract data with fallbacks while the Isolate bridge connects
    final amount = _txData?['amount'] ?? '...';
    final sender = _txData?['sender'] ?? 'Loading...';

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emerald Header
              Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF2ECC71)),
                  const SizedBox(width: 8),
                  const Text(
                    "M-PESA SMART SYNC",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2ECC71),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => FlutterOverlayWindow.closeOverlay(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Dynamic Data Display
              const Text(
                "New Transaction Detected",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Text(
                "Ksh $amount",
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50)),
              ),
              Text(
                "From: $sender",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 20),

              const Text(
                "Choose a category to file this record:",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 15),

              // Quick Category Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _quickAction("Personal", Icons.person, Colors.blue),
                  _quickAction("Business", Icons.work, Colors.orange),
                ],
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  // Send a signal to open the main app
                  if (_txData != null) {
                    FlutterOverlayWindow.shareData({
                      'action': 'open_app',
                      'id': _txData!['id'],
                    });
                  }
                  FlutterOverlayWindow.closeOverlay();
                },
                child: const Text(
                  "View Details in Pesa Budget",
                  style: TextStyle(color: Color(0xFF2C3E50)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, Color color) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: () {
            // 3. Send the user's choice back across the Isolate bridge
            if (_txData != null) {
              FlutterOverlayWindow.shareData({
                'action': 'categorize',
                'mode': label, // "Personal" or "Business"
                'id': _txData!['id'],
              });
            }
            // Close the overlay after sending the data
            FlutterOverlayWindow.closeOverlay();
          },
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
