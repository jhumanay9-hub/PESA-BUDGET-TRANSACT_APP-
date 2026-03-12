import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/db_helper.dart';
import 'services/database_service.dart';
import 'services/transaction_service.dart';
import 'package:device_info_plus/device_info_plus.dart';



class QuickClassifyPage extends StatefulWidget {
  final String body;
  final String amountStr;
  final String merchant;
  const QuickClassifyPage({
    super.key,
    required this.body,
    required this.amountStr,
    required this.merchant,
  });

  @override
  State<QuickClassifyPage> createState() => _QuickClassifyPageState();
}

class _QuickClassifyPageState extends State<QuickClassifyPage> {
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _saving = false;
  bool _isLowEnd = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _checkHardware();
  }

  Future<void> _checkHardware() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final int totalMem = androidInfo.data['totalMemory'] ?? 0;
      // Low-end threshold for blur: < 2GB
      if (mounted) {
        setState(() {
          _isLowEnd = totalMem < (2 * 1024 * 1024 * 1024);
        });
      }
    } catch (_) {
      // ignore hardware check failures — default to non-low-end
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DbHelper.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _selectedCategory = cats.isNotEmpty ? cats.first['name'] as String : null;
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
      if (mounted) {
        setState(() {
          _categories = [];
          _selectedCategory = null;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = await DatabaseService.getDatabase();
      final amount = double.tryParse(widget.amountStr.replaceAll(RegExp(r'[^\d\.\-]'), '')) ?? 0.0;

      // Duplicate Guard: Check last 60 seconds
      final oneMinuteAgo = DateTime.now().subtract(const Duration(seconds: 60)).toIso8601String();
      final duplicates = await db.query(
        'transactions',
        where: 'body = ? AND amount = ? AND date > ?',
        whereArgs: [widget.body, amount, oneMinuteAgo],
      );

      if (duplicates.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This transaction was already classified via the popup'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        if (mounted) setState(() => _saving = false);
        return;
      }

      await TransactionService().saveTransaction({
        'smsId': DateTime.now().millisecondsSinceEpoch.toString(),
        'body': widget.body,
        'merchant': widget.merchant,
        'amount': amount,
        'category': _selectedCategory ?? 'General',
        'isExpense': widget.body.toLowerCase().contains('received') ? 0 : 1,
        'date': DateTime.now().toIso8601String(),
      });

      try {
        DbHelper.notifyUpdate();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('qc_body');
      await prefs.remove('qc_amount');
      await prefs.remove('qc_merchant');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction classified')));
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Failed to save transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save transaction')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color neonMint = Color(0xFF00FFCC);
    const Color darkMint = Color(0xFF00CC99);
    const Color deepCharcoal = Color(0xFF121212);
    const Color surfaceGrey = Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: deepCharcoal,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: neonMint, size: 20),
            SizedBox(width: 10),
            Text('Quick Classify',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [neonMint, darkMint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Branding Watermark
          const Positioned(
            right: -20,
            bottom: 100,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.account_balance_wallet, size: 200, color: neonMint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TRANSACTION AMOUNT',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('Ksh', style: TextStyle(color: neonMint, fontSize: 16, fontWeight: FontWeight.w300)),
                    const SizedBox(width: 4),
                    Text(widget.amountStr,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        )),
                  ],
                ),
                const SizedBox(height: 24),

                // Adaptive Container with Blur
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: _isLowEnd ? 0 : 10, sigmaY: _isLowEnd ? 0 : 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _isLowEnd ? surfaceGrey : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isLowEnd ? Colors.grey.withValues(alpha: 0.3) : neonMint.withValues(alpha: 0.3),
                          width: _isLowEnd ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.store, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(widget.merchant,
                                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Colors.white10),
                          ),
                          const Text('MESSAGE BODY',
                              style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            widget.body,
                            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Text('SELECT CATEGORY',
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: surfaceGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      dropdownColor: surfaceGrey,
                      initialValue: _selectedCategory,
                      style: const TextStyle(color: Colors.white),
                      items: _categories
                          .map((c) => DropdownMenuItem<String>(
                                value: c['name'] as String,
                                child: Text(c['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [neonMint, darkMint]),
                    boxShadow: [
                      BoxShadow(color: neonMint.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _saving ? 'SAVING...' : 'CONFIRM CLASSIFICATION',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: deepCharcoal, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}