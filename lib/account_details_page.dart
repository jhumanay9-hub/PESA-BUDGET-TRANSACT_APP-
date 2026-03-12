import 'package:flutter/material.dart';
import 'services/db_helper.dart';
import 'services/transaction_service.dart';
import 'ui/footer.dart';
import 'dart:async';

class AccountDetailsPage extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  final IconData categoryIcon;
  
  const AccountDetailsPage({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
  });
  
  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}
class _AccountDetailsPageState extends State<AccountDetailsPage> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> _allCategories = []; // dynamic from DB
  Future<double>? _totalFuture;
  bool isLoading = true;
  DateTimeRange? _selectedDateRange;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  bool _showFilters = false;
  late StreamSubscription _dbSubscription;

  @override
  void initState() {
    super.initState();
    loadCategoryData();
    _dbSubscription = DbHelper.onUpdate.listen((_) => loadCategoryData());
  }

  @override
  void dispose() {
    _dbSubscription.cancel();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> loadCategoryData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _totalFuture = DbHelper.getTotalForCategory(widget.categoryName);
    });
    
    try {
      final min = double.tryParse(_minAmountController.text) ?? 0.0;
      final max = double.tryParse(_maxAmountController.text) ?? double.infinity;
      
      final result = await DbHelper.getFilteredTransactions(
        categoryName: widget.categoryName,
        dateRange: _selectedDateRange,
        minAmount: min,
        maxAmount: max,
      );
      
      // Also fetch all categories for the dynamic classify buttons
      final allCats = await DbHelper.getCategories();

      if (mounted) {
        setState(() {
          items = result;
          _allCategories = allCats;
          isLoading = false;
        });
        // Debug visibility into what the list is showing
        debugPrint('Debug: Transactions found: ${items.length} for ${widget.categoryName}');
      }
    } catch (e) {
      debugPrint('Error loading category data: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Transaction History"),
      backgroundColor: widget.categoryColor,
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_list_off : Icons.filter_list,
            size: 30, // Scaled up (was default 24)
          ),
          onPressed: () => setState(() => _showFilters = !_showFilters),
          tooltip: "Toggle Filters",
        ),
      ],
    ),
    body: Column(
      children: [
        if (_showFilters) 
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                initialDateRange: _selectedDateRange,
                              );
                              if (range != null) {
                                setState(() => _selectedDateRange = range);
                                loadCategoryData();
                              }
                            },
                            icon: const Icon(Icons.date_range),
                            label: Text(_selectedDateRange == null 
                              ? "Select Date Range" 
                              : "${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}"),
                          ),
                        ),
                        if (_selectedDateRange != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _selectedDateRange = null);
                              loadCategoryData();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minAmountController,
                            decoration: const InputDecoration(labelText: "Min Amount", border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => loadCategoryData(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _maxAmountController,
                            decoration: const InputDecoration(labelText: "Max Amount", border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => loadCategoryData(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Themed balance card with adaptive gradient + icon
        FutureBuilder<double>(
          future: _totalFuture,
          builder: (context, snapshot) {
            String balance = "...";
            if (snapshot.hasData) {
              balance = snapshot.data!.toStringAsFixed(2);
            } else if (snapshot.hasError) {
              balance = "Error";
            }

            final themeColor = widget.categoryColor;
            final themeColorSoft = themeColor.withValues(alpha: 0.8);

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [themeColor, themeColorSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Icon watermark
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        widget.categoryIcon,
                        size: 72,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  widget.categoryIcon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.categoryName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Current balance",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Ksh $balance",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // List of transactions
        Expanded(
          child: isLoading
              ? ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: 6,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.0),
                      color: widget.categoryColor.withValues(alpha: 0.06),
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
              : items.isEmpty
                  ? () {
                      // Extra debug when the list is empty for this account
                      debugPrint('Debug: Transactions found: ${items.length} for ${widget.categoryName}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.categoryIcon, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No ${widget.categoryName} transactions yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final itemId = item['id'] as int;
                        final body = item['body'] ?? '';
                        final merchant = item['merchant'] ?? 'General';
                        final date = item['date'] ?? 'N/A';
                        final amountValue = item['amount'] as double;
                        final bodyLower = body.toLowerCase();

                        // Red/Green rule based on message text
                        final hasIncomeKeyword =
                            bodyLower.contains('received') ||
                            bodyLower.contains('deposited') ||
                            bodyLower.contains('from');

                        final hasExpenseKeyword =
                            bodyLower.contains('sent') ||
                            bodyLower.contains('paid') ||
                            bodyLower.contains('withdrawn') ||
                            bodyLower.contains('fuliza');

                        final bool isExpense =
                            hasExpenseKeyword || !hasIncomeKeyword;
                        
                        final content = Dismissible(
                          key: ValueKey(itemId),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Transaction"),
                                content: const Text("Are you sure you want to delete this transaction?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) async {
                            await DbHelper.deleteTransaction(itemId);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[700],
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                                  leading: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: widget.categoryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(widget.categoryIcon, color: widget.categoryColor, size: 20),
                                  ),
                                  title: Text(
                                    merchant, 
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(body),
                                      const SizedBox(height: 4),
                                      Text(
                                        "ID: $itemId • $date",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    "${isExpense ? '-' : '+'} Ksh ${amountValue.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: isExpense ? Colors.red[700] : Colors.green[700]
                                    ),
                                  ),
                                ),
                                if (widget.categoryName == "General") ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Divider(height: 1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                                          child: Text("Categorize", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: _allCategories
                                            .where((cat) => cat['name'] != 'General')
                                            .map((cat) => _catButton(
                                              cat['name'] as String,
                                              Color(cat['color'] as int),
                                              itemId,
                                            ))
                                            .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                          child: content,
                        );
                      },
                    ),
        ),
      ],
    ),
    bottomNavigationBar: const AppFooter(),
  );

  Widget _catButton(String name, Color color, int id) {
    return ElevatedButton(
      onPressed: () => _classifyTransaction(id, name),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(name, style: const TextStyle(fontSize: 11)),
    );
  }

  Future<void> _classifyTransaction(int localId, String newCategory) async {
    // Find the smsId for this transaction
    final tx = items.firstWhere((item) => item['id'] == localId);
    final smsId = tx['smsId'] as String;

    await TransactionService().updateCategory(localId, smsId, newCategory);
    loadCategoryData();
  }
}
