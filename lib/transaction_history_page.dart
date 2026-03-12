import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/services.dart';
import 'services/db_helper.dart';
import 'services/permission_manager.dart';
import 'ui/footer.dart';

class TransactionHistoryPage extends StatefulWidget {
  final String initialCategory;

  const TransactionHistoryPage({
    super.key,
    this.initialCategory = 'All',
  });

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  double totalAmount = 0.0;
  late String selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  StreamSubscription<void>? _dbSubscription;
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 50;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    _scrollController.addListener(_onScroll);
    _loadCategories().then((_) => loadTransactions(reset: true));
    // Listen for DB updates so new accounts appear immediately
    _dbSubscription = DbHelper.onUpdate.listen((_) async {
      await _loadCategories();
      if (mounted) loadTransactions(reset: true);
    });
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DbHelper.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadTransactions({bool reset = false}) async {
    if (reset) {
      setState(() {
        isLoading = true;
        transactions.clear();
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = !reset;
    
    try {
      final db = await DbHelper.getDatabase();

      // If 'All' is selected, use existing helper for paging
      List<Map<String, dynamic>> results;
      if (selectedCategory == 'All') {
        results = await DbHelper.getTransactionsPage(
          categoryName: null,
          limit: _pageSize,
          offset: _offset,
        );
        final totalResult = await db.rawQuery('SELECT SUM(amount) as total FROM transactions');
        totalAmount = (totalResult.first['total'] as num?)?.toDouble() ?? 0.0;
      } else {
        // Find category record to also match by id if needed
        final cat = _categories.firstWhere(
          (c) => (c['name'] as String) == selectedCategory,
          orElse: () => {},
        );
        final catId = cat.isNotEmpty ? (cat['id']?.toString() ?? '') : '';

        // Use a paged raw query matching by name OR id
        const whereClause = '(category = ? OR category = ?)';
        final whereArgs = [selectedCategory, catId];

        results = await db.query(
          'transactions',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'id DESC',
          limit: _pageSize,
          offset: _offset,
        );

        final totalResult = await db.rawQuery(
          'SELECT SUM(amount) as total FROM transactions WHERE $whereClause',
          whereArgs,
        );
        totalAmount = (totalResult.first['total'] as num?)?.toDouble() ?? 0.0;
      }

      setState(() {
        transactions.addAll(results);
        isLoading = false;
        _offset += results.length;
        if (results.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !isLoading) {
        loadTransactions();
      }
    }
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;
    // Try to find by name first
    final found = _categories.firstWhere(
      (c) => (c['name'] as String) == category || (c['id']?.toString() ?? '') == category,
      orElse: () => {},
    );
    if (found.isNotEmpty && found['color'] != null) {
      try {
        return Color(found['color'] as int);
      } catch (_) {}
    }
    return Colors.grey;
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.help_outline;
    final found = _categories.firstWhere(
      (c) => (c['name'] as String) == category || (c['id']?.toString() ?? '') == category,
      orElse: () => {},
    );
    final iconName = found.isNotEmpty ? (found['icon'] as String? ?? '') : '';
    switch (iconName) {
      case 'add_chart':
        return Icons.add_chart;
      case 'restaurant':
        return Icons.restaurant;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'receipt':
        return Icons.receipt;
      case 'savings':
        return Icons.savings;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'category':
      default:
        return Icons.category;
    }
  }

  String _generateCSVString(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Description,Amount,Category,Type');
    for (final row in rows) {
      final date = (row['date'] ?? '').toString().replaceAll(',', ';');
      final desc = ((row['body'] ?? row['merchant']) ?? '')
              .toString()
              .replaceAll(',', ';');
      final amount = row['amount'] ?? 0;
      final category = (row['category'] ?? '').toString().replaceAll(',', ';');
      final isExpense = (row['isExpense'] ??
              (row['body']?.toString().toLowerCase().contains('received') ==
                      true
                  ? 0
                  : 1)) ==
          1;
      final type = isExpense ? 'Expense' : 'Income';
      buffer.writeln('$date,$desc,$amount,$category,$type');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction History"),
        backgroundColor: Colors.green[800],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, size: 30), // Scaled up
            onPressed: _downloadStatement,
            tooltip: "Download Statement",
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              color: Colors.white,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Amount",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                    Text(
                      "Ksh ${totalAmount.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Transactions",
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'sans-serif',
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "${transactions.length}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'sans-serif',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Filter
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: (['All', ..._categories.map((c) => c['name'] as String)]).map((category) {
                final isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedCategory = category;
                      });
                      loadTransactions(reset: true);
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.green[100],
                    checkmarkColor: Colors.green[800],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.green[800] : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Transactions List
          Expanded(
            child: isLoading
                ? ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 6,
                    itemBuilder: (context, index) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.grey.shade200,
                      ),
                      child: const ListTile(
                        title: SizedBox(
                          height: 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white24),
                          ),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: SizedBox(
                            height: 14,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : transactions.isEmpty
                    ? () {
                        debugPrint('Debug: Transactions found: ${transactions.length}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ],
                          ),
                        );
                      }()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tile = Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              color: Colors.white,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(transactions[index]['category']).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  _getCategoryIcon(transactions[index]['category']),
                                  color: _getCategoryColor(transactions[index]['category']),
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Builder(builder: (context) {
                                    final body = (transactions[index]['body'] as String? ?? '').toLowerCase();

                                    final hasIncomeKeyword =
                                        body.contains('received') ||
                                        body.contains('deposited') ||
                                        body.contains('from');

                                    final hasExpenseKeyword =
                                        body.contains('sent') ||
                                        body.contains('paid') ||
                                        body.contains('withdrawn') ||
                                        body.contains('fuliza');

                                    final bool isExpense =
                                        hasExpenseKeyword || !hasIncomeKeyword;

                                    return Text(
                                      "${isExpense ? '-' : '+'} Ksh ${transactions[index]['amount'].toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'sans-serif',
                                        fontSize: 16,
                                        color: isExpense ? Colors.red[700] : Colors.green[700],
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(transactions[index]['category']),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      transactions[index]['category'] ?? 'Unclassified',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'sans-serif',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    transactions[index]['body'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'sans-serif',
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    transactions[index]['date'] ?? 'No date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: 'sans-serif',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 300),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 12 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: tile,
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Future<void> _downloadStatement() async {
    // UX: notify start
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating Statement...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    try {
      // Ensure storage permission with universal manager
      if (Platform.isAndroid) {
        final granted =
            await UniversalPermissionManager.requestStorage(context);
        if (!granted) {
          return;
        }
      }
      
      // Resolve data source: current filtered list or full DB if 'All'
      List<Map<String, dynamic>> data;
      if (selectedCategory != 'All') {
        data = transactions;
      } else {
        final db = await DbHelper.getDatabase();
        data = await db.query('transactions', orderBy: 'date DESC');
      }

      final csv = _generateCSVString(data);

      String savedWhere = 'Downloads';
      File outFile;
      if (Platform.isAndroid) {
        // Try public Downloads first
        final downloadsDir = Directory('/storage/emulated/0/Download');
        Directory targetDir;
        if (await downloadsDir.exists()) {
          targetDir = downloadsDir;
        } else {
          // App-scoped as fallback
          final ext = await getExternalStorageDirectory();
          targetDir = ext ?? await getApplicationDocumentsDirectory();
          savedWhere = 'app storage';
        }
        final outPath =
            '${targetDir.path}${Platform.pathSeparator}Statement_${DateTime.now().millisecondsSinceEpoch}.csv';
        outFile = File(outPath);
      } else {
        final docs = await getApplicationDocumentsDirectory();
        final outPath =
            '${docs.path}${Platform.pathSeparator}Statement_${DateTime.now().millisecondsSinceEpoch}.csv';
        outFile = File(outPath);
        savedWhere = 'Documents';
      }
      await outFile.writeAsString(csv);
      
      // Trigger media scan for immediate visibility
      if (Platform.isAndroid) {
        const MethodChannel('app/notif_channel').invokeMethod('scanFile', {'path': outFile.path});
      }

      if (!mounted) return;
      final msg = (Platform.isAndroid && savedWhere == 'Downloads')
          ? 'Statement saved to Downloads'
          : 'Statement saved to $savedWhere';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green));
    } catch (e) {
      // Fallback: share if saving fails
      try {
        final tmpDir = await getTemporaryDirectory();
        final tmpPath =
            '${tmpDir.path}/Statement_${DateTime.now().millisecondsSinceEpoch}.csv';
        final tmpFile = File(tmpPath);
        final csv = _generateCSVString(transactions);
        await tmpFile.writeAsString(csv);
        if (!mounted) return;
        await Share.shareXFiles([XFile(tmpFile.path)],
            text: 'Transaction Statement');
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error generating statement'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
