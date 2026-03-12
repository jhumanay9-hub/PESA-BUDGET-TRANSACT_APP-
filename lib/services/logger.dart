import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'database_service.dart';
import 'dart:io';

class Logger {
  static Future<void> logError(String message, [dynamic stackTrace]) async {
    final timestamp = DateTime.now().toIso8601String();
    String model = "Unknown";
    
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        model = "${info.manufacturer} ${info.model}";
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        model = info.utsname.machine;
      }
    } catch (_) {}

    final logEntry = "[$timestamp] [$model] ERROR: $message";
    debugPrint(logEntry);
    if (stackTrace != null) debugPrint(stackTrace.toString());

    try {
      final db = await DatabaseService.getDatabase();
      await db.insert('app_logs', {
        'model': model,
        'timestamp': timestamp,
        'error': stackTrace != null ? "$message | $stackTrace" : message,
      });
    } catch (e) {
      debugPrint("Failed to write to app_logs: $e");
    }
  }

  static void info(String message) {
    debugPrint("[INFO] ${DateTime.now().toIso8601String()}: $message");
  }

  static void logInfo(String message) {
    info(message);
  }

  static void logWarning(String message) {
    debugPrint("[WARNING] ${DateTime.now().toIso8601String()}: $message");
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final db = await DatabaseService.getDatabase();
      return await db.query('app_logs', orderBy: 'id DESC', limit: 50);
    } catch (e) {
      debugPrint("Failed to fetch logs: $e");
      return [];
    }
  }

  static Future<void> clearLogs() async {
    try {
      final db = await DatabaseService.getDatabase();
      await db.delete('app_logs');
    } catch (e) {
      debugPrint("Failed to clear logs: $e");
    }
  }
}
