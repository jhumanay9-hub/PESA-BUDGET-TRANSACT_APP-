import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/session_repository.dart';
import 'package:transaction_app/services/permission_manager.dart';

/// ============================================================================
/// PERMISSION MANAGER SCREEN - PRODUCTION READY & VERSION AWARE
/// ============================================================================
/// Features:
/// - Device-aware permission requests (Android SDK version detection)
/// - Emerald green themed UI for permission popups
/// - Sequential permission requests with visual feedback
/// - Handles permanently denied permissions with AppSettings redirect
/// - Auto-navigates to dashboard after all permissions granted
/// ============================================================================
class PermissionManagerScreen extends StatefulWidget {
  const PermissionManagerScreen({super.key});

  @override
  State<PermissionManagerScreen> createState() =>
      _PermissionManagerScreenState();
}

class _PermissionManagerScreenState extends State<PermissionManagerScreen> {
  final _permissionManager = PermissionManager();
  final _sessionRepo = SessionRepository();

  bool _isRequesting = false;
  int _currentStep = 0;
  String _currentPermissionName = '';

  // Permission statuses
  PermissionStatus _smsStatus = PermissionStatus.denied;
  PermissionStatus _storageStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _systemAlertWindowStatus = PermissionStatus.denied;
  PermissionStatus _batteryStatus = PermissionStatus.denied;

  bool _requiresNotification = false;
  bool _requiresManageExternalStorage = false;

  @override
  void initState() {
    super.initState();
    _loadRequirements();
    _refreshAllStatuses();
  }

  Future<void> _loadRequirements() async {
    _requiresNotification =
        await _permissionManager.requiresNotificationPermission;
    _requiresManageExternalStorage =
        await _permissionManager.requiresManageExternalStorage;
    if (mounted) setState(() {});
  }

  Future<void> _refreshAllStatuses() async {
    final statuses = await _permissionManager.getAllPermissionStatuses();

    setState(() {
      _smsStatus = statuses[Permission.sms] ?? PermissionStatus.denied;
      _storageStatus = statuses[_requiresManageExternalStorage
              ? Permission.manageExternalStorage
              : Permission.storage] ??
          PermissionStatus.denied;
      _notificationStatus =
          statuses[Permission.notification] ?? PermissionStatus.denied;
      _systemAlertWindowStatus =
          statuses[Permission.systemAlertWindow] ?? PermissionStatus.denied;
      _batteryStatus = statuses[Permission.ignoreBatteryOptimizations] ??
          PermissionStatus.denied;
    });
  }

  bool get _allGranted =>
      _smsStatus.isGranted &&
      _storageStatus.isGranted &&
      (!_requiresNotification || _notificationStatus.isGranted) &&
      _systemAlertWindowStatus.isGranted &&
      _batteryStatus.isGranted;

  void _showPermanentlyDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D1A),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$permissionName is required for Pesa Budget to function. '
          'Please enable it in app settings.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _permissionManager.openAppSettingsPage();
              await Future.delayed(const Duration(seconds: 2));
              await _refreshAllStatuses();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAllSequential() async {
    setState(() {
      _isRequesting = true;
      _currentStep = 0;
    });

    final permissions = [
      {'permission': Permission.sms, 'name': 'SMS', 'granted': false},
      {
        'permission': _requiresManageExternalStorage
            ? Permission.manageExternalStorage
            : Permission.storage,
        'name': _requiresManageExternalStorage
            ? 'Storage (Android 11+)'
            : 'Storage',
        'granted': false
      },
      if (_requiresNotification)
        {
          'permission': Permission.notification,
          'name': 'Notifications',
          'granted': false
        },
      {
        'permission': Permission.systemAlertWindow,
        'name': 'Display Over Apps',
        'granted': false
      },
      {
        'permission': Permission.ignoreBatteryOptimizations,
        'name': 'Battery Optimization',
        'granted': false
      },
    ];

    for (int i = 0; i < permissions.length; i++) {
      final perm = permissions[i];
      final permission = perm['permission'] as Permission;
      final name = perm['name'] as String;

      setState(() {
        _currentStep = i + 1;
        _currentPermissionName = name;
      });

      // Skip if already granted
      final status = await permission.status;
      if (status.isGranted) {
        perm['granted'] = true;
        continue;
      }

      // Request permission
      await Future.delayed(const Duration(milliseconds: 300));
      bool granted = false;

      switch (permission) {
        case Permission.sms:
          granted = await _permissionManager.requestSms();
          break;
        case Permission.storage:
        case Permission.manageExternalStorage:
          granted = await _permissionManager.requestStorage();
          break;
        case Permission.notification:
          granted = await _permissionManager.requestNotification();
          break;
        case Permission.systemAlertWindow:
          granted = await _permissionManager.requestSystemAlertWindow();
          break;
        case Permission.ignoreBatteryOptimizations:
          granted =
              await _permissionManager.requestIgnoreBatteryOptimizations();
          break;
        default:
          final status = await permission.request();
          granted = status.isGranted;
      }

      perm['granted'] = granted;

      if (!granted) {
        final isPermanentlyDenied =
            await _permissionManager.isPermanentlyDenied(permission);
        if (isPermanentlyDenied) {
          _showPermanentlyDeniedDialog(name);
        }
      }

      await _refreshAllStatuses();
    }

    setState(() {
      _isRequesting = false;
    });

    await _refreshAllStatuses();

    if (_allGranted && mounted) {
      _handleComplete();
    }
  }

  Future<void> _handleComplete() async {
    AppLogger.logSuccess('PermissionManager: All permissions granted');
    await _sessionRepo.setPermissionsGranted(true);
    await _sessionRepo.setFirstTimeUserComplete();

    if (mounted) {
      // Navigate to dashboard - AuthWrapper will handle PIN lock on next app return
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0C),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              const Color(0xFF2ECC71).withValues(alpha: 0.15),
              const Color(0xFF0A0E0C),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Permission Icon with Glow
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _allGranted
                        ? Icons.check_circle_outline
                        : Icons.security_outlined,
                    size: 70,
                    color:
                        _allGranted ? const Color(0xFF2ECC71) : Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  "DEVICE PERMISSIONS",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),

                const Text(
                  "PESA BUDGET NEEDS ACCESS TO FUNCTION",
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 40),

                // SMS Permission
                _buildPermissionTile(
                  icon: Icons.message_outlined,
                  title: "SMS Access",
                  description: "Read M-PESA transaction messages",
                  status: _smsStatus,
                ),

                const SizedBox(height: 15),

                // Storage Permission
                _buildPermissionTile(
                  icon: _requiresManageExternalStorage
                      ? Icons.folder_zip_outlined
                      : Icons.folder_outlined,
                  title: _requiresManageExternalStorage
                      ? "File Access (Android 11+)"
                      : "Storage Access",
                  description: _requiresManageExternalStorage
                      ? "Manage files for statements"
                      : "Save downloaded statements",
                  status: _storageStatus,
                ),

                // Notification (Android 13+)
                if (_requiresNotification) ...[
                  const SizedBox(height: 15),
                  _buildPermissionTile(
                    icon: Icons.notifications_outlined,
                    title: "Notifications",
                    description: "Alert you of new syncs",
                    status: _notificationStatus,
                  ),
                ],

                const SizedBox(height: 15),

                // System Alert Window
                _buildPermissionTile(
                  icon: Icons.display_settings_outlined,
                  title: "Display Over Apps",
                  description: "Show sync status overlay",
                  status: _systemAlertWindowStatus,
                ),

                const SizedBox(height: 15),

                // Battery Optimizations
                _buildPermissionTile(
                  icon: Icons.battery_std_outlined,
                  title: "Battery Unrestricted",
                  description: "Prevent background service kill",
                  status: _batteryStatus,
                ),

                const SizedBox(height: 50),

                // Action Buttons
                if (_isRequesting)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2ECC71)
                                  .withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          color: Color(0xFF2ECC71),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Requesting $_currentPermissionName...",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Step $_currentStep of 5",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 8,
                      ),
                      onPressed:
                          _allGranted ? _handleComplete : _requestAllSequential,
                      child: Text(
                        _allGranted
                            ? "CONTINUE TO DASHBOARD"
                            : "GRANT ALL PERMISSIONS",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (!_allGranted) ...[
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () async {
                        await _permissionManager.openAppSettingsPage();
                        await Future.delayed(const Duration(seconds: 2));
                        await _refreshAllStatuses();
                      },
                      child: const Text(
                        "OPEN APP SETTINGS",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 30),

                // Info Text
                const Text(
                  "We respect your privacy. All data is stored locally first.",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionStatus status,
  }) {
    final isGranted = status.isGranted;
    final isPermanentlyDenied = status.isPermanentlyDenied;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF2ECC71)
              : isPermanentlyDenied
                  ? const Color(0xFFE74C3C)
                  : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF2ECC71).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isGranted
                  ? const Color(0xFF2ECC71)
                  : isPermanentlyDenied
                      ? const Color(0xFFE74C3C)
                      : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isGranted
                            ? const Color(0xFF2ECC71)
                            : isPermanentlyDenied
                                ? const Color(0xFFE74C3C)
                                : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (isPermanentlyDenied) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DENIED',
                          style: TextStyle(
                            color: Color(0xFFE74C3C),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status Indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF2ECC71)
                  : Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: isGranted
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : null,
          ),
        ],
      ),
    );
  }
}
