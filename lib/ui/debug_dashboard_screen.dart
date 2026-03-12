import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/logger.dart';
import '../services/db_helper.dart';
import '../services/database_service.dart';
import '../services/network_service.dart';
import '../services/auth_service.dart';
import '../services/overlay_manager.dart';
import '../services/permission_manager.dart';
import 'dart:io';

class DebugDashboardScreen extends StatefulWidget {
  const DebugDashboardScreen({super.key});

  @override
  State<DebugDashboardScreen> createState() => _DebugDashboardScreenState();
}

class _DebugDashboardScreenState extends State<DebugDashboardScreen> {
  final Battery _battery = Battery();

  // System Diagnostics results
  bool _diagRunning = false;
  List<_DiagResult> _diagResults = [];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: const Text("Debugger"),
          backgroundColor: const Color(0xFF0D1B2A),
          bottom: const TabBar(
            indicatorColor: Color(0xFF00FFCC),
            labelColor: Color(0xFF00FFCC),
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: "Logs"),
              Tab(icon: Icon(Icons.developer_board), text: "System"),
              Tab(icon: Icon(Icons.health_and_safety), text: "Health"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLogsTab(),
            _buildSystemTab(),
            _buildHealthTab(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────── LOGS TAB ────────────────────────────────
  Widget _buildLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              await Logger.clearLogs();
              setState(() {});
            },
            icon: const Icon(Icons.delete_sweep),
            label: const Text("Clear Logs"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Logger.getLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Center(
                    child: Text("No logs found",
                        style: TextStyle(color: Colors.white70)));
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final errorText = log['error'] ?? 'Unknown Error';
                  final subtitleText =
                      "${log['timestamp']} | ${log['model']}";
                  final copyPayload = "$subtitleText\n$errorText";

                  return ListTile(
                    title: Text(errorText,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                    subtitle: Text(subtitleText,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                    // ── Copy icon ──────────────────────────────────
                    trailing: IconButton(
                      icon: const Icon(Icons.copy,
                          color: Colors.white54, size: 18),
                      tooltip: "Copy Error",
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: copyPayload));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Log copied to clipboard"),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── SYSTEM TAB ───────────────────────────────
  Widget _buildSystemTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSystemInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final info = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _infoRow("Model", info['model']),
            _infoRow("Manufacturer", info['manufacturer']),
            _infoRow("OS Version", info['os']),
            _infoRow("Total RAM", info['ram']),
            _infoRow("Battery Level", "${info['battery']}%"),
            _infoRow("Platform", Platform.isAndroid ? "Android" : "iOS"),
          ],
        );
      },
    );
  }

  // ─────────────────────────────── HEALTH TAB ───────────────────────────────
  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sniffer status card ──────────────────────────────────
          FutureBuilder<bool>(
            future: FlutterBackgroundService().isRunning(),
            builder: (context, snapshot) {
              final isRunning = snapshot.data ?? false;
              return Column(
                children: [
                  _statusCard(
                    icon: Icons.circle,
                    iconColor: isRunning ? const Color(0xFF00FFCC) : Colors.redAccent,
                    title: isRunning ? "SNIFFER ACTIVE" : "SNIFFER INACTIVE",
                    subtitle: "Service Running: ${isRunning ? 'YES' : 'NO'}",
                    titleColor: isRunning ? const Color(0xFF00FFCC) : Colors.redAccent,
                  ),
                  if (!isRunning)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          FlutterBackgroundService().startService();
                          setState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Restarting Sniffer..."))
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Restart Sniffer"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: const Color(0xFF0D1B2A),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          FutureBuilder<DateTime?>(
            future: DbHelper.getLastHeartbeat(),
            builder: (context, hSnapshot) {
              final lastTime = hSnapshot.data;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  "Last Heartbeat: ${lastTime?.toIso8601String() ?? 'Never'}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),

          // ── Restore Default Categories button ────────────────────
          ElevatedButton.icon(
            onPressed: () async {
              final count = await DbHelper.restoreDefaultCategories();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(count > 0 
                      ? "Restored $count default categor${count == 1 ? 'y' : 'ies'}!" 
                      : "All default categories are already present."),
                    backgroundColor: count > 0 ? const Color(0xFF00FFCC) : Colors.grey[800],
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text("Restore Default Categories"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // ── Run System Diagnostics button ────────────────────────
          ElevatedButton.icon(
            onPressed: _diagRunning ? null : _runDiagnostics,
            icon: _diagRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.radar),
            label: Text(_diagRunning ? "Running..." : "Run System Health Check"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFCC),
              foregroundColor: const Color(0xFF0D1B2A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),

          // ── TEST UNIVERSAL OVERLAY button ────────────────────────
          ElevatedButton.icon(
            onPressed: () async {
              final granted = await UniversalPermissionManager.requestOverlayPermission(context);
              if (granted) {
                await OverlayManager.show(amount: 1250.50, merchant: "TEST MERCHANT");
              }
            },
            icon: const Icon(Icons.flash_on),
            label: const Text("🔥 TEST UNIVERSAL OVERLAY"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),

          // ── Diagnostics results ──────────────────────────────────
          if (_diagResults.isNotEmpty) ...[
            const Text("Diagnostics Results",
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 8),
            ..._diagResults.map((r) => _diagResultCard(r)),
          ],
        ],
      ),
    );
  }

  // ── Run all diagnostic checks ──────────────────────────────────────────────
  Future<void> _runDiagnostics() async {
    setState(() {
      _diagRunning = true;
      _diagResults = [];
    });

    final results = <_DiagResult>[];

    // 1. SMS permission
    try {
      final smsStatus = await Permission.sms.status;
      results.add(_DiagResult(
        label: "SMS Permission",
        ok: smsStatus.isGranted,
        detail: smsStatus.name,
      ));
    } catch (e) {
      results.add(_DiagResult(label: "SMS Permission", ok: false, detail: e.toString()));
    }

    // 2. Overlay permission
    bool overlayGranted = false;
    try {
      overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
      results.add(_DiagResult(
        label: "Overlay Permission",
        ok: overlayGranted,
        detail: overlayGranted ? "Granted" : "NOT GRANTED",
        fixAction: overlayGranted ? null : _openOverlaySettings,
        fixLabel: "Fix Overlay",
      ));
    } catch (e) {
      results.add(_DiagResult(label: "Overlay Permission", ok: false, detail: e.toString()));
    }

    // 3. Database open
    try {
      final db = DatabaseService.database;
      final isOpen = db != null && db.isOpen;
      results.add(_DiagResult(
        label: "Database",
        ok: isOpen,
        detail: isOpen ? "Open & ready" : "Not open / closed",
      ));
    } catch (e) {
      results.add(_DiagResult(label: "Database", ok: false, detail: e.toString()));
    }

    // 4. Background service running
    try {
      final running = await FlutterBackgroundService().isRunning();
      results.add(_DiagResult(
        label: "Background Sniffer",
        ok: running,
        detail: running ? "Running" : "Stopped",
      ));
    } catch (e) {
      results.add(_DiagResult(label: "Background Sniffer", ok: false, detail: e.toString()));
    }

    // 5. Default Categories Seeded
    try {
      final isSeeded = await DbHelper.checkCategoriesSeeded();
      results.add(_DiagResult(
        label: "Categories Seeded",
        ok: isSeeded,
        detail: isSeeded ? "YES" : "NO",
      ));
    } catch (e) {
      results.add(_DiagResult(label: "Categories Seeded", ok: false, detail: e.toString()));
    }

    // 6. Internet Status
    try {
      final connectivity = await NetworkService().checkConnectivity();
      final status = NetworkService.getStatusString(connectivity);
      final isOnline = NetworkService().isOnline(connectivity);
      results.add(_DiagResult(
        label: "Internet Status",
        ok: isOnline,
        detail: status,
      ));
    } catch (e) {
      results.add(_DiagResult(label: "Internet Status", ok: false, detail: e.toString()));
    }
    
    // 7. Supabase Status
    try {
      final client = AuthService().client;
      final session = client.auth.currentSession;
      results.add(_DiagResult(
        label: "Supabase Status",
        ok: true,
        detail: session != null ? "Online (Auth Active)" : "Online (No Session)",
      ));
      
      // Also show User ID if logged in
      if (session != null) {
        results.add(_DiagResult(
          label: "Supabase User ID",
          ok: true,
          detail: session.user.id,
        ));
      }
    } catch (e) {
      results.add(const _DiagResult(label: "Supabase Status", ok: false, detail: "Not Initialized"));
    }

    if (mounted) {
      setState(() {
        _diagResults = results;
        _diagRunning = false;
      });
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      // Try flutter_overlay_window's built-in request first
      await FlutterOverlayWindow.requestPermission();
    } catch (_) {
      // Fallback: open generic app settings
      await openAppSettings();
    }
  }

  // ── Diag result card ──────────────────────────────────────────────────────
  Widget _diagResultCard(_DiagResult r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: r.ok
            ? const Color(0xFF00FFCC).withValues(alpha: 0.08)
            : Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r.ok ? const Color(0xFF00FFCC) : Colors.redAccent,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            r.ok ? Icons.check_circle : Icons.error,
            color: r.ok ? const Color(0xFF00FFCC) : Colors.redAccent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(r.detail,
                    style: TextStyle(
                        color: r.ok ? Colors.white54 : Colors.redAccent,
                        fontSize: 11)),
              ],
            ),
          ),
          // Fix button if there's an action (e.g., overlay not granted)
          if (!r.ok && r.fixAction != null)
            ElevatedButton(
              onPressed: r.fixAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: Text(r.fixLabel ?? "Fix"),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────── HELPERS ──────────────────────────────────
  Widget _statusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color titleColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Color(0xFF00FFCC))),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getSystemInfo() async {
    final info = <String, dynamic>{};
    final deviceInfo = DeviceInfoPlugin();
    final batteryLevel = await _battery.batteryLevel;
    info['battery'] = batteryLevel.toString();

    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      info['model'] = android.model;
      info['manufacturer'] = android.manufacturer;
      info['os'] = "Android ${android.version.release}";
      final int totalMem = android.data['totalMemory'] ?? 0;
      info['ram'] = totalMem > 0
          ? "${(totalMem / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB"
          : "N/A (SDK limited)";
    } else {
      final ios = await deviceInfo.iosInfo;
      info['model'] = ios.model;
      info['manufacturer'] = "Apple";
      info['os'] = "iOS ${ios.systemVersion}";
      info['ram'] = "N/A (iOS Restricted)";
    }
    return info;
  }
}

// ── Data class for a single diagnostic result ─────────────────────────────
class _DiagResult {
  final String label;
  final bool ok;
  final String detail;
  final VoidCallback? fixAction;
  final String? fixLabel;

  const _DiagResult({
    required this.label,
    required this.ok,
    required this.detail,
    this.fixAction,
    this.fixLabel,
  });
}
