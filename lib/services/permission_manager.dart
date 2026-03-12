import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class UniversalPermissionManager {
  static Future<int?> _sdk() async {
    if (!Platform.isAndroid) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  static Future<bool> requestSms(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.sms.request();
    if (status.isGranted) return true;
    await _explainAndOpenSettings(
      context,
      'SMS Permission',
      'We need SMS permission to detect M‑Pesa messages and help you classify transactions.',
    );
    return false;
  }

  static Future<bool> requestStorage(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    final sdk = await _sdk() ?? 0;
    if (sdk < 30) {
      final status = await Permission.storage.request();
      if (status.isGranted) return true;
      await _explainAndOpenSettings(
        context,
        'Storage Permission',
        'We need storage permission to save or export your statements.',
      );
      return false;
    } else {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
      await _explainAndOpenSettings(
        context,
        'All Files Access',
        'On newer Android versions we need “All files access” to save statements in device storage.',
      );
      return false;
    }
  }

  static Future<bool> ensureUniversalPermissions(BuildContext context) async {
    final sms = await requestSms(context);
    if (!sms) return false;
    final storage = await requestStorage(context);
    return storage;
  }

  static Future<void> _explainAndOpenSettings(
      BuildContext context, String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  static Future<bool> requestIgnoreBatteryOptimizations(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final bool isSamsung = androidInfo.manufacturer.toLowerCase().contains('samsung');
    
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;

    final prefs = await SharedPreferences.getInstance();
    final samsungGuardShown = prefs.getBool('samsung_guard_shown') ?? false;

    if (isSamsung && !samsungGuardShown) {
      await prefs.setBool('samsung_guard_shown', true);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Samsung Guard Active'),
            content: const Text(
              'Pesa Budget has detected you are using a Samsung device. To ensure the SMS sniffer is never killed by the system, please Disable Battery Optimization for this app in the next screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Permission.ignoreBatteryOptimizations.request();
                },
                child: const Text('Disable Now'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    if (!isSamsung) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'To ensure the transaction sniffer runs reliably in the background, please disable battery optimization for Pesa Budget.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await Permission.ignoreBatteryOptimizations.request();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
     }
     return false;
   }

   static Future<bool> requestOverlayPermission(BuildContext context) async {
     if (!Platform.isAndroid) return true;
     
     final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
     if (isGranted) return true;

     if (context.mounted) {
       await showDialog<void>(
         context: context,
         barrierDismissible: false,
         builder: (ctx) => AlertDialog(
           backgroundColor: const Color(0xFF1A1A1A),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF00FFCC), width: 1)),
           title: const Row(
             children: [
               Icon(Icons.layers, color: Color(0xFF00FFCC)),
               SizedBox(width: 10),
               Text('Instant Alerts', style: TextStyle(color: Colors.white)),
             ],
           ),
           content: const Text(
             'Allow Pesa Budget to show instant popups over other apps. This ensures you see your spending the moment it happens.',
             style: TextStyle(color: Colors.white70),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(ctx).pop(),
               child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
             ),
             ElevatedButton(
               onPressed: () async {
                 Navigator.of(ctx).pop();
                 await FlutterOverlayWindow.requestPermission();
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color(0xFF00FFCC),
                 foregroundColor: const Color(0xFF0D1B2A),
               ),
               child: const Text('Grant Permission'),
             ),
           ],
         ),
       );
     }
     
     // Check permission again after dialog interaction
     return await FlutterOverlayWindow.isPermissionGranted();
   }
}
