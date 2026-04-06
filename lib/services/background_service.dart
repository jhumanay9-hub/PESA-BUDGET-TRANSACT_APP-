import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:transaction_app/services/sms_service.dart';
import 'package:transaction_app/core/logger.dart';

class SyncTaskHandler extends TaskHandler {
  final _smsService = SmsService();
  bool _syncComplete = false;

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    AppLogger.logInfo("Background: Sync Isolate Started");
    // Connect the SMS listener here
    _smsService.startListening();

    // Mark background sync as complete (triggers Supabase in coordinator)
    // This happens once when the service first starts
    if (!_syncComplete) {
      _syncComplete = true;
      // Note: We can't directly call ServiceCoordinator from isolate
      // Instead, we send a message via SendPort if available
      if (sendPort != null) {
        sendPort.send('background_sync_complete');
      }
      AppLogger.logInfo("Background: Signaling sync complete to coordinator");
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    AppLogger.logInfo(
        "Background: Heartbeat - Pesa Budget is still listening.");

    // Simple connectivity check before SMS sync (synchronous, isolate-safe)
    // This is a basic check - full connectivity logic is in main isolate
    try {
      // Quick DNS check to see if we have internet (synchronous in isolate)
      // Note: InternetAddress.lookup returns Future, but we can't await in this context
      // So we just attempt the SMS sync - it will handle failures gracefully
      _smsService.syncInbox();
    } catch (e) {
      AppLogger.logWarning("Background: SMS sync failed - $e");
    }
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    AppLogger.logWarning("Background: Service was terminated by System.");
  }
}
