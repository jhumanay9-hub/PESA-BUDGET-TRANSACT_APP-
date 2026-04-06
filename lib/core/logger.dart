import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// The Diagnostic Heart of the App.
/// Handles tiered logging and prepares data for the Diagnostic Overlay.
class AppLogger {
  // Simple toggle for production vs development
  static const bool _isLogEnabled = kDebugMode;

  /// [INFO] - General flow (App start, Page navigation)
  static void logInfo(String message) {
    _emit('INFO', message, level: 0);
  }

  /// [SUCCESS] - Crucial for tracking M-PESA saves and Supabase syncs
  static void logSuccess(String message) {
    _emit('SUCCESS', '✅ $message', level: 0);
  }

  /// [WARNING] - Non-fatal issues (Network lag, SMS ID missing - using Hash)
  static void logWarning(String message) {
    _emit('WARNING', '⚠️ $message', level: 500);
  }

  /// [ERROR] - Fatal issues (DB corruption, Supabase Auth failure)
  static void logError(String message, [dynamic error, StackTrace? stack]) {
    _emit('ERROR', '❌ $message', level: 1000, error: error, stack: stack);
  }

  /// [DATABASE] - Specific tracking for the 'transactions' table
  static void logData(String message) {
    _emit('DATABASE', '📊 $message', level: 0);
  }

  /// Internal emitter using dart:developer for better performance than 'print'
  static void _emit(
    String tag,
    String message, {
    required int level,
    dynamic error,
    StackTrace? stack,
  }) {
    if (!_isLogEnabled) return;

    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 8);
    final formattedMessage = '[$timestamp] [$tag] $message';

    // 1. Log to the system console (Low overhead)
    dev.log(
      message,
      name: tag,
      time: DateTime.now(),
      level: level,
      error: error,
      stackTrace: stack,
    );

    // 2. Also print for easy viewing in the Flutter terminal
    if (error != null) {
      debugPrint('$formattedMessage | Error: $error');
    } else {
      debugPrint(formattedMessage);
    }

    // NOTE: In the next phase, we will add a 'List<String> history' here
    // so the Diagnostic Overlay can pull the last 50 logs directly.
  }
}
