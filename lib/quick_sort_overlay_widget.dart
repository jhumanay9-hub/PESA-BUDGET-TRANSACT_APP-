import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'services/db_helper.dart';



/// The floating Quick-Sort overlay widget.
/// Receives data via [FlutterOverlayWindow.overlayListener],
/// shows Amount (red/green), Vendor, and account buttons.
class QuickSortOverlayWidget extends StatefulWidget {
  final bool isLowRam;
  const QuickSortOverlayWidget({super.key, this.isLowRam = false});

  @override
  State<QuickSortOverlayWidget> createState() => _QuickSortOverlayWidgetState();
}

class _QuickSortOverlayWidgetState extends State<QuickSortOverlayWidget> {
  String _amount = '0.00';
  String _vendor = 'Unknown';
  bool _isExpense = true;
  List<Map<String, dynamic>> _categories = [];
  StreamSubscription? _overlaySub;
  bool _isInitialLoadDone = false;

  @override
  void initState() {
    super.initState();
    // Load categories after widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
    _listenForData();
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DbHelper.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isInitialLoadDone = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
      if (mounted) {
        setState(() {
          _categories = [];
          _isInitialLoadDone = true;
        });
      }
    }
  }

  void _listenForData() {
    // Subscribe once and parse flexible payloads (String JSON or Map)
    _overlaySub = FlutterOverlayWindow.overlayListener.listen((data) {
      try {
        Map<String, dynamic>? map;
        if (data == null) return;

        if (data is String) {
          // plugin often sends JSON-encoded strings
          map = jsonDecode(data) as Map<String, dynamic>?;
        } else if (data is Map) {
          // plugin could deliver a Map directly
          map = Map<String, dynamic>.from(data);
        }

        if (map != null) {
          // If the main app passed isLowRam via shared data, apply it
          if (map.containsKey('isLowRam')) {
            if (mounted) {
              setState(() {
                // Note: runtime low-ram check if passed by the main app
              });
            }
          }

          // Transaction specific payload
          if (map.containsKey('amount')) {
            final a = map['amount']?.toString() ?? '0.00';
            if (mounted) setState(() => _amount = a);
          }
          if (map.containsKey('merchant')) {
            final m = map['merchant']?.toString() ?? 'Unknown';
            if (mounted) setState(() => _vendor = m);
          }
          if (map.containsKey('isExpense')) {
            final e = map['isExpense'];
            final bool isExpense = (e == 1) || (e == true) || (e?.toString() == '1');
            if (mounted) setState(() => _isExpense = isExpense);
          }

          // After receiving transaction data, refresh categories in case they changed
          _loadCategories();
        }
      } catch (e) {
        debugPrint('Overlay data error (parse): $e');
      }
    }, onError: (err) {
      debugPrint('overlayListener error: $err');
    });
  }

  Future<void> _sortTo(String categoryName) async {
    try {
      final db = await DbHelper.getDatabase();

      // Parse amount robustly: remove commas and currency chars
      final cleaned = _amount.replaceAll(RegExp(r'[^\d\.\-]'), '');
      final target = double.tryParse(cleaned) ?? 0.0;

      // Use a recent time window to avoid picking an old transaction
      final windowIso = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();

      // Attempt to find a best-match transaction: same merchant, uncategorized (General), and amount approximately equal
      final rows = await db.rawQuery(
        '''
        SELECT * FROM transactions
        WHERE category = ? AND (merchant = ? OR merchant IS NULL) AND date > ?
          AND ABS(amount - ?) < ?
        ORDER BY id DESC
        LIMIT 1
        ''',
        ['General', _vendor, windowIso, target, 1.0],
      );

      // Fallback: if none found, try matching by exact amount and recent time only (no merchant)
      List<Map<String, dynamic>> resultRows = rows;
      if (resultRows.isEmpty) {
        final rows2 = await db.rawQuery(
          '''
          SELECT * FROM transactions
          WHERE category = ? AND date > ?
            AND ABS(amount - ?) < ?
          ORDER BY id DESC
          LIMIT 1
          ''',
          ['General', windowIso, target, 1.0],
        );
        resultRows = rows2;
      }

      if (resultRows.isNotEmpty) {
        final id = resultRows.first['id'] as int;
        await db.update('transactions', {'category': categoryName}, where: 'id = ?', whereArgs: [id]);
        // Let the rest of the app know something changed
        try {
          DbHelper.notifyUpdate();
        } catch (_) {}
      } else {
        debugPrint('No matching transaction found to update for amount $_amount / vendor $_vendor');
      }
    } catch (e) {
      debugPrint('Overlay sort error: $e');
    } finally {
      // Close overlay in all cases so the user returns to the foreground app quickly
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (e) {
        debugPrint('Failed to close overlay: $e');
      }
    }
  }

  Color _getColor(int colorVal) => Color(colorVal);

  @override
  Widget build(BuildContext context) {
    const Color kineticMint = Color(0xFF00FFCC);
    const Color kineticRed = Color(0xFFFF4D4D); // A matching neon red/pink
    final amountColor = _isExpense ? kineticRed : kineticMint;
    final typeLabel = _isExpense ? '↑ Sent / Paid' : '↓ Received';

    // Safe Mode (Tier 2) vs Premium (Tier 1) logic
    final bool useSafeMode = widget.isLowRam;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(useSafeMode ? 8 : 20),
              boxShadow: useSafeMode
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header bar ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(useSafeMode ? 8 : 20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: amountColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Pesa Budget Quick-Sort',
                        style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: useSafeMode ? 'sans-serif' : null,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => FlutterOverlayWindow.closeOverlay(),
                        child: Icon(Icons.close, color: Colors.grey[400], size: 18),
                      ),
                    ],
                  ),
                ),

                // ── Amount & Vendor ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      Text(
                        'Ksh $_amount',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: amountColor,
                          letterSpacing: -0.5,
                          fontFamily: useSafeMode ? 'sans-serif' : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: amountColor.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontFamily: useSafeMode ? 'sans-serif' : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _vendor,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontFamily: useSafeMode ? 'sans-serif' : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // ── Sort to label ───────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Icon(Icons.sort, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Sort to account',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Account Buttons Grid ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: !_isInitialLoadDone
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        )
                      : _categories.isEmpty
                          ? const Text('No accounts found', style: TextStyle(color: Colors.grey))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _categories.map((cat) {
                                final name = cat['name'] as String;
                                final color = _getColor(cat['color'] as int);
                                return _AccountButton(
                                  name: name,
                                  color: color,
                                  onTap: () => _sortTo(name),
                                  useSafeMode: useSafeMode,
                                );
                              }).toList(),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onTap;
  final bool useSafeMode;

  const _AccountButton({
    required this.name,
    required this.color,
    required this.onTap,
    required this.useSafeMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(useSafeMode ? 4 : 20),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: useSafeMode ? 'sans-serif' : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}