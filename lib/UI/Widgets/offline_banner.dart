import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final connectivity = snapshot.data;
        // Check if connectivity is available
        final hasConnectivity =
            connectivity != null && connectivity != ConnectivityResult.none;

        // If we are connected to Wifi or Mobile, return an empty box (invisible)
        if (hasConnectivity && snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // If offline, show the "Offline Ledger" strip
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: const Color(0xFFE74C3C).withValues(alpha: 0.9), // Warning Red
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                "Offline Mode: Transactions saved locally",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
