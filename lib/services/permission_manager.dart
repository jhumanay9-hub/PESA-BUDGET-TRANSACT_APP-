import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transaction_app/core/logger.dart';

/// ============================================================================
/// PERMISSION MANAGER - PRODUCTION READY & VERSION AWARE
/// ============================================================================
/// This class handles the logic for identifying which permissions a specific
/// device needs and triggering the native OS pop-up screens.
/// ============================================================================
class PermissionManager {
  // Device Info Cache
  int? _androidSdk;

  /// Internal helper to get the Android SDK level
  Future<int> _getSdkInt() async {
    if (_androidSdk != null) return _androidSdk!;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      _androidSdk = androidInfo.version.sdkInt;
      return _androidSdk!;
    }
    return 0;
  }

  /// Check if notification permission is required (Android 13+ / SDK 33)
  Future<bool> get requiresNotificationPermission async {
    return await _getSdkInt() >= 33;
  }

  /// Check if MANAGE_EXTERNAL_STORAGE is required (Android 11+ / SDK 30)
  Future<bool> get requiresManageExternalStorage async {
    return await _getSdkInt() >= 30;
  }

  /// Returns the status of all permissions applicable to this specific device
  Future<Map<Permission, PermissionStatus>> getAllPermissionStatuses() async {
    final sdk = await _getSdkInt();
    final statuses = <Permission, PermissionStatus>{};

    // SMS (Always needed for M-PESA)
    statuses[Permission.sms] = await Permission.sms.status;

    // Storage (Version Aware)
    if (sdk >= 30) {
      statuses[Permission.manageExternalStorage] =
          await Permission.manageExternalStorage.status;
    } else {
      statuses[Permission.storage] = await Permission.storage.status;
    }

    // Notifications (Version Aware)
    if (sdk >= 33) {
      statuses[Permission.notification] = await Permission.notification.status;
    }

    // Foreground Service / Overlay permissions
    statuses[Permission.systemAlertWindow] =
        await Permission.systemAlertWindow.status;
    statuses[Permission.ignoreBatteryOptimizations] =
        await Permission.ignoreBatteryOptimizations.status;

    return statuses;
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllPermissions() async {
    final statuses = await getAllPermissionStatuses();
    final sdk = await _getSdkInt();

    // Check SMS
    if (!(statuses[Permission.sms]?.isGranted ?? false)) return false;

    // Check Storage (version aware)
    if (sdk >= 30) {
      if (!(statuses[Permission.manageExternalStorage]?.isGranted ?? false)) {
        return false;
      }
    } else {
      if (!(statuses[Permission.storage]?.isGranted ?? false)) return false;
    }

    // Check Notifications (if required)
    if (sdk >= 33) {
      if (!(statuses[Permission.notification]?.isGranted ?? false)) {
        return false;
      }
    }

    // Check System Alert Window
    if (!(statuses[Permission.systemAlertWindow]?.isGranted ?? false)) {
      return false;
    }

    // Check Battery Optimization
    if (!(statuses[Permission.ignoreBatteryOptimizations]?.isGranted ?? false)) {
      return false;
    }

    return true;
  }

  /// --------------------------------------------------------------------------
  /// INDIVIDUAL REQUEST METHODS
  /// --------------------------------------------------------------------------

  Future<PermissionStatus> getSmsStatus() async {
    return await Permission.sms.status;
  }

  Future<bool> requestSms() async {
    AppLogger.logInfo('Permissions: Requesting SMS access...');
    return (await Permission.sms.request()).isGranted;
  }

  Future<bool> requestNotification() async {
    if (await requiresNotificationPermission) {
      AppLogger.logInfo('Permissions: Requesting notification access...');
      return (await Permission.notification.request()).isGranted;
    }
    return true; // Auto-pass if old Android
  }

  Future<bool> requestStorage() async {
    if (await requiresManageExternalStorage) {
      AppLogger.logInfo(
          'Permissions: Requesting MANAGE_EXTERNAL_STORAGE (Android 11+)');
      return (await Permission.manageExternalStorage.request()).isGranted;
    } else {
      AppLogger.logInfo('Permissions: Requesting legacy storage');
      return (await Permission.storage.request()).isGranted;
    }
  }

  Future<bool> requestSystemAlertWindow() async {
    AppLogger.logInfo('Permissions: Requesting SYSTEM_ALERT_WINDOW...');
    return (await Permission.systemAlertWindow.request()).isGranted;
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    AppLogger.logInfo(
        'Permissions: Requesting IGNORE_BATTERY_OPTIMIZATIONS...');
    return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
  }

  /// --------------------------------------------------------------------------
  /// SEQUENTIAL MASTER REQUEST (Triggering all pop-ups)
  /// --------------------------------------------------------------------------
  /// Call this on app launch to trigger all native pop-ups in order.
  /// --------------------------------------------------------------------------
  Future<bool> requestAll() async {
    AppLogger.logInfo('Permissions: Starting native pop-up sequence...');

    // 1. SMS
    final sms = await requestSms();

    // 2. Storage (Will open the special settings screen on Android 11+)
    final storage = await requestStorage();

    // 3. Notifications (Android 13+ only)
    final notifs = await requestNotification();

    // 4. Overlays (System Alert Window)
    final saw = await requestSystemAlertWindow();

    // 5. Battery (Critical for background syncing)
    final battery = await requestIgnoreBatteryOptimizations();

    final allGranted = sms && storage && notifs && saw && battery;

    if (allGranted) {
      AppLogger.logSuccess('Permissions: All system pop-ups accepted.');
    } else {
      AppLogger.logWarning('Permissions: Some permissions were declined.');
    }

    return allGranted;
  }

  /// Check if a permission is permanently denied
  Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Open app settings for manual grant if the user clicked "Don't ask again"
  Future<void> openAppSettingsPage() async {
    AppLogger.logInfo('Permissions: Redirecting to System Settings...');
    await openAppSettings();
  }
}
