import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/ui/widgets/tile_detail.dart';
import 'package:transaction_app/services/category_cache.dart';
import 'dart:async';

/// Callback type for transaction list refresh
typedef OnTransactionListRefresh = void Function();

/// ============================================================================
/// ACCOUNT CARD - CARD TO DETAIL ARCHITECTURE
/// ============================================================================
/// This widget handles the 'Shell' (closed) and 'Detail' (expanded) states.
/// Default: Shows Account Shell with balance and "Click to See All"
/// On Tap: Expands to show Transaction Tile with filters
/// ============================================================================
class AccountCard extends StatefulWidget {
  final String category;
  final int categoryColor; // ARGB32 color value from database
  final String categoryIcon; // Icon code point string from database
  final String accountMode;
  final int index;
  final PageController pageController;
  final VoidCallback onResetToShell;
  final Function(bool) onExpandedChanged; // Callback to lock/unlock PageView
  final int currentPage; // FIX: Track current page for lazy loading

  const AccountCard({
    super.key,
    required this.category,
    required this.categoryColor,
    required this.categoryIcon,
    required this.accountMode,
    required this.index,
    required this.pageController,
    required this.onResetToShell,
    required this.onExpandedChanged,
    required this.currentPage, // FIX: Added for lazy loading
  });

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  final _dbHelper = DatabaseHelper();
  final _categoryCache = CategoryCache();
  bool _isExpanded = false;
  StreamSubscription? _categorySubscription;

  // Filter State
  String? _minAmount;
  String? _maxAmount;
  DateTime? _selectedDate;
  String _transactionType = 'All'; // For General account only

  // FIX: TextEditingControllers for filter inputs (prevents input method restart loop)
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  bool _isUpdatingFilterFromUser = false; // Prevent infinite loop

  // Cache for balance calculation (prevents redundant DB queries)
  double? _cachedTotal;
  String? _cachedTotalKey;

  // FIX: Store future to prevent re-fetching and ensure proper rebuild
  Future<double>? _totalFuture;

  // Callback to refresh transaction list
  OnTransactionListRefresh? _refreshCallback;

  @override
  void initState() {
    super.initState();
    // FIX: Initialize controllers once in initState
    _minController = TextEditingController();
    _maxController = TextEditingController();

    // Listen for user input
    _minController.addListener(_onMinAmountChanged);
    _maxController.addListener(_onMaxAmountChanged);

    // FIX: Listen to category changes to refresh totals
    _listenToCategoryChanges();
  }

  /// Listen to category cache stream for real-time updates
  void _listenToCategoryChanges() {
    _categorySubscription?.cancel();
    _categorySubscription = _categoryCache.categoriesStream.listen((_) {
      // Categories changed - invalidate cache and refresh
      if (mounted) {
        _invalidateBalanceCache();
      }
    });
  }

  /// Invalidate balance cache to force recalculation
  void _invalidateBalanceCache() {
    _cachedTotal = null;
    _totalFuture = null;
    setState(() {}); // Trigger rebuild
  }

  @override
  void didUpdateWidget(AccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // FIX: Clear filters and cache when category changes
    if (oldWidget.category != widget.category ||
        oldWidget.accountMode != widget.accountMode) {
      _isUpdatingFilterFromUser = true;
      _minController.clear();
      _maxController.clear();
      setState(() {
        _minAmount = null;
        _maxAmount = null;
        _selectedDate = null;
        _cachedTotal = null; // Invalidate balance cache
        _totalFuture = null; // Reset future for fresh calculation
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdatingFilterFromUser = false;
        // FIX: Trigger a rebuild after the widget is fully updated
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    // FIX: Dispose controllers properly
    _minController.removeListener(_onMinAmountChanged);
    _maxController.removeListener(_onMaxAmountChanged);
    _minController.dispose();
    _maxController.dispose();
    // FIX: Dispose category subscription
    _categorySubscription?.cancel();
    super.dispose();
  }

  /// Handle min amount change from user
  void _onMinAmountChanged() {
    if (_isUpdatingFilterFromUser) return;
    setState(() => _minAmount = _minController.text);
  }

  /// Handle max amount change from user
  void _onMaxAmountChanged() {
    if (_isUpdatingFilterFromUser) return;
    setState(() => _maxAmount = _maxController.text);
  }

  /// Generate cache key based on query parameters
  String _getCacheKey({String? prefix = 'tx'}) {
    return '$prefix:${widget.category}:${widget.accountMode}:$_transactionType:$_minAmount:$_maxAmount:${_selectedDate?.toIso8601String()}';
  }

  /// Notify parent when expanded state changes
  void _setExpanded(bool expanded) {
    setState(() => _isExpanded = expanded);
    widget.onExpandedChanged(expanded);
  }

  /// Convert icon code point string to IconData
  IconData _getIconFromCode() {
    final codePoint = int.tryParse(widget.categoryIcon);
    if (codePoint != null) {
      return IconData(codePoint, fontFamily: 'MaterialIcons');
    }
    return Icons.account_balance_wallet; // Default fallback
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE74C3C), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE74C3C), size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Account?',
              style: TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to delete "${widget.category}"?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFFE74C3C), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will delete:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• All transactions in this account',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    '• Account settings and icon',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Delete account and all its transactions
  Future<void> _deleteAccount() async {
    try {
      AppLogger.logInfo('Account: Deleting "${widget.category}"...');

      // Delete category and ALL its transactions (permanent delete)
      await _dbHelper.deleteCategoryWithTransactions(widget.category);

      AppLogger.logSuccess(
          'Account: "${widget.category}" deleted successfully');

      // 3. Navigate back to dashboard
      if (mounted) {
        // Close the detail view
        _setExpanded(false);
        widget.onResetToShell();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${widget.category}" deleted'),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.logError('Account: Delete failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _isExpanded ? _buildDetailView() : _buildShellView(),
    );
  }

  /// SHELL VIEW - Default "Closed" State
  Widget _buildShellView() {
    return FutureBuilder<double>(
      future:
          _getTotalFuture(), // FIX: Use stored future for consistent rebuilds
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0.0;
        final categoryColor = Color(widget.categoryColor);

        return GestureDetector(
          onTap: () {
            _setExpanded(true);
          },
          child: Container(
            key: ValueKey('shell-${widget.category}'),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141D1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Account Logo (Top)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconFromCode(),
                      size: 40,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Name
                  Text(
                    widget.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Balance (Center)
                  Text(
                    'Ksh ${total.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ).copyWith(
                      color:
                          total >= 0 ? categoryColor : const Color(0xFFE74C3C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    total >= 0 ? 'POSITIVE' : 'NEGATIVE',
                    style: TextStyle(
                      color:
                          total >= 0 ? categoryColor : const Color(0xFFE74C3C),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer: "Click to See All" (Prominent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'CLICK TO SEE ALL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// DETAIL VIEW - Expanded State
  Widget _buildDetailView() {
    final categoryColor = Color(widget.categoryColor);

    return Container(
      key: ValueKey('detail-${widget.category}'),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141D1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Top Bar: Condensed Summary + Back Button
          _buildDetailHeader(),

          Divider(color: categoryColor, height: 1),

          // Filter Bar: Min, Max, Date
          _buildFilterBar(),

          // General Account Only: Transaction Type Toggle
          if (widget.category.toLowerCase() == 'general')
            _buildTransactionTypeToggle(),

          Divider(color: categoryColor, height: 1),

          // Transaction List
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader() {
    final categoryColor = Color(widget.categoryColor);
    final isGeneralAccount = widget.category.toLowerCase() == 'general';

    return FutureBuilder<double>(
      future:
          _getTotalFuture(), // FIX: Use stored future for consistent rebuilds
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0.0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Back Button (to Shell)
              IconButton(
                icon: Icon(Icons.arrow_back, color: categoryColor),
                onPressed: () {
                  _setExpanded(false);
                  widget.onResetToShell();
                },
              ),
              const SizedBox(width: 12),

              // Condensed Summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ksh ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ).copyWith(
                        color: total >= 0
                            ? categoryColor
                            : const Color(0xFFE74C3C),
                      ),
                    ),
                  ],
                ),
              ),

              // Delete Button (NOT for General account)
              if (!isGeneralAccount)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFE74C3C), size: 20),
                  onPressed: () => _showDeleteConfirmationDialog(),
                  tooltip: 'Delete Account',
                ),

              // Refresh Button
              IconButton(
                icon: Icon(Icons.refresh, color: categoryColor, size: 20),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final categoryColor = Color(widget.categoryColor);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Min Amount
              Expanded(
                child: TextField(
                  controller: _minController,
                  enabled: !_isUpdatingFilterFromUser,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Min',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixText: 'Ksh ',
                    prefixStyle: TextStyle(color: categoryColor, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),

              // Max Amount
              Expanded(
                child: TextField(
                  controller: _maxController,
                  enabled: !_isUpdatingFilterFromUser,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Max',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                    prefixText: 'Ksh ',
                    prefixStyle: TextStyle(color: categoryColor, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),

              // Date Picker
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: categoryColor,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: categoryColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}'
                              : 'Date',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? categoryColor
                                : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Clear Filters Button
          if (_minAmount != null || _maxAmount != null || _selectedDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // FIX: Clear controllers properly to avoid input method issues
                  _isUpdatingFilterFromUser = true;
                  _minController.clear();
                  _maxController.clear();
                  setState(() {
                    _minAmount = null;
                    _maxAmount = null;
                    _selectedDate = null;
                  });
                  // Reset flag after build completes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _isUpdatingFilterFromUser = false;
                  });
                },
                child: Text(
                  'Clear Filters',
                  style: TextStyle(color: categoryColor, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeToggle() {
    final categoryColor = Color(widget.categoryColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Type:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          ...['All', 'Income', 'Expense'].map((type) {
            final isActive = type == _transactionType;
            return GestureDetector(
              onTap: () => setState(() => _transactionType = type),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? categoryColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? categoryColor
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: isActive ? categoryColor : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return TransactionListBuilder(
      accountMode: widget.accountMode,
      category: widget.category,
      transactionType: _transactionType,
      minAmount: _minAmount,
      maxAmount: _maxAmount,
      selectedDate: _selectedDate,
      onRefreshCallback: (refresh) {
        _refreshCallback = refresh;
      },
      onTransactionMoved: (id, newCategory) {
        // Handle transaction moved - refresh the list
        // Invalidate cache when transaction is moved
        _cachedTotal = null;
        _totalFuture = null; // FIX: Reset future to force recalculation

        // Call the refresh callback
        _refreshCallback?.call();

        // Also refresh the total
        setState(() {});
      },
    );
  }

  Future<double> _calculateTotal() async {
    final cacheKey = _getCacheKey(prefix: 'total');

    // Return cached value if available and key matches
    if (_cachedTotal != null && _cachedTotalKey == cacheKey) {
      return _cachedTotal!;
    }

    final transactions = await _dbHelper.getFilteredTransactions(
      mode: widget.accountMode,
      category: widget.category,
      type: 'All',
      timeframe: 'All Time',
      sortBy: 'Date',
    );

    double total = 0.0;
    for (var tx in transactions) {
      total += tx.type == TransactionType.income ? tx.amount : -tx.amount;
    }

    // Cache the result
    _cachedTotal = total;
    _cachedTotalKey = cacheKey;

    return total;
  }

  /// Get or create the total future (prevents redundant calculations)
  /// FIX: Only calculate balance for visible card (current page or expanded)
  Future<double> _getTotalFuture() {
    // FIX: Lazy loading - only calculate if this card is visible
    // Card is visible if: it's the current page OR it's expanded (detail view)
    final isVisible = widget.index == widget.currentPage || _isExpanded;

    if (!isVisible) {
      // Return cached value or 0 without triggering DB query
      return Future.value(_cachedTotal ?? 0.0);
    }

    // If no future exists or cache is invalid, create new future
    if (_totalFuture == null || _cachedTotal == null) {
      _totalFuture = _calculateTotal();
    }
    return _totalFuture!;
  }
}
