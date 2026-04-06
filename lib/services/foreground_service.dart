import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/services/background_service.dart';

class ForegroundService {
  /// Initialize the service with Pesa Budget-themed notification
  void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pesa_budget_sync_channel',
        channelName: 'Pesa Budget M-PESA Sync',
        channelDescription:
            'Keeps Pesa Budget listening for new transactions in real-time.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher', // Use your app icon
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the sync engine
  Future<bool> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    AppLogger.logInfo("System: Starting Foreground Sync Service...");

    return await FlutterForegroundTask.startService(
      notificationTitle: 'Pesa Budget is Active',
      notificationText: 'Monitoring M-PESA transactions safely.',
      callback: startCallback,
    );
  }
}

// This must be a top-level function (outside any class)
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SyncTaskHandler());
}
