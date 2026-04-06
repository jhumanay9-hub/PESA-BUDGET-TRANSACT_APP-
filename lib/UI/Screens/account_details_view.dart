import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/ui/widgets/tile_detail.dart';
import 'package:transaction_app/ui/widgets/swipe_to_reject_wrapper.dart';
import 'package:transaction_app/ui/utils/ui_utils.dart';
import 'package:transaction_app/services/sms_service.dart';
import 'package:transaction_app/services/category_cache.dart';

/// ============================================================================
/// ACCOUNT DETAILS VIEW - Controller Logic
/// ============================================================================
/// This file now ONLY contains:
/// - StatefulWidget lifecycle management
/// - DatabaseHelper calls
/// - AnimatedList management
/// - State coordination
/// - SMS sync stream listener for auto-refresh
///
/// UI rendering is delegated to:
/// - AccountCompactShell (Dashboard shell)
/// - TransactionTileTemplate (Transaction tiles)
/// ============================================================================
class AccountDetailsView extends StatefulWidget {
  final String category;
  final String accountMode;
  final String filterType;
  final String filterTimeframe;
  final bool isCompact;
  final VoidCallback? onViewAll;

  const AccountDetailsView({
    super.key,
    required this.category,
    required this.accountMode,
    this.filterType = 'All',
    this.filterTimeframe = 'Today',
    this.isCompact = false,
    this.onViewAll,
  });

  @override
  State<AccountDetailsView> createState() => _AccountDetailsViewState();
}

class _AccountDetailsViewState extends State<AccountDetailsView> {
  final _dbHelper = DatabaseHelper();
  final _smsService = SmsService();
  String _sortBy = 'Date';
  String _sortOrder = 'DESC';

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<TransactionModel> _cachedTransactions = [];
  bool _isLoading = true;
  bool _isRemovingTransaction = false; // Track removal to prevent jump

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _listenToSync();
  }

  /// Listen for SMS sync events and auto-refresh
  void _listenToSync() {
    _smsService.syncStream.listen((newCount) {
      // Only refresh if not in the middle of a removal animation
      if (!_isRemovingTransaction) {
        AppLogger.logInfo(
            'AccountDetailsView: Sync detected, refreshing ${widget.category}...');
        _loadTransactions();
      }
    });
  }

  /// Load transactions into cache for AnimatedList
  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final transactions = await _dbHelper.getFilteredTransactions(
      mode: widget.accountMode,
      category: widget.category,
      type: widget.filterType,
      timeframe: widget.filterTimeframe,
      sortBy: _sortBy,
    );
    setState(() {
      _cachedTransactions = transactions;
      _isLoading = false;
    });
  }

  /// Remove transaction with smooth animation
  void _removeTransaction(String transactionId) {
    final index =
        _cachedTransactions.indexWhere((tx) => tx.id == transactionId);
    if (index != -1) {
      _cachedTransactions.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) =>
            TransactionRemovalPlaceholder(animation: animation),
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  /// Callback for transaction movement (matches CategoryMoverButtons signature)
  /// Uses smooth removal without rebuilding the entire list
  void _handleTransactionMove(String transactionId, String newCategory) async {
    // Find the transaction index
    final index =
        _cachedTransactions.indexWhere((tx) => tx.id == transactionId);
    if (index == -1) return;

    // Set flag to prevent SMS sync listener from rebuilding list
    _isRemovingTransaction = true;

    // Update the transaction's category in the database
    await DatabaseHelper()
        .updateTransactionCategory(transactionId, newCategory);

    // Update the transaction's category in the local cache
    _cachedTransactions[index] = _cachedTransactions[index].copyWith(
      category: newCategory,
    );

    // Animate removal from General list (since it's moving to another category)
    _cachedTransactions.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          TransactionRemovalPlaceholder(animation: animation),
      duration: const Duration(milliseconds: 300),
    );

    // Reset flag after animation completes
    Future.delayed(const Duration(milliseconds: 350), () {
      _isRemovingTransaction = false;
    });
  }

  /// Handle swipe reject (AI learning loop)
  void _handleSwipeReject(String transactionId) async {
    final index =
        _cachedTransactions.indexWhere((tx) => tx.id == transactionId);
    if (index == -1) return;

    final tx = _cachedTransactions[index];

    // Process rejection through AI handler
    final handler = AiRejectionHandler();
    await handler.processRejection(
      transactionId: transactionId,
      transactionSender: tx.sender,
      currentCategory: tx.category,
    );

    // Update local cache
    _cachedTransactions[index] = tx.copyWith(
      category: 'General',
      isAutoMoved: false,
    );

    // Animate removal
    _removeTransaction(transactionId);

    AppLogger.logInfo(
      'Swipe Reject: "$transactionId" moved to General for re-learning',
    );
  }

  /// Handle swipe delete (permanent delete from General only)
  void _handleSwipeDelete(String transactionId) async {
    final index =
        _cachedTransactions.indexWhere((tx) => tx.id == transactionId);
    if (index == -1) return;

    // Permanent delete from database
    final handler = AiRejectionHandler();
    await handler.permanentDelete(transactionId);

    // Animate removal
    _removeTransaction(transactionId);

    AppLogger.logWarning(
      'Swipe Delete: Permanently deleted "$transactionId"',
    );
  }

  /// Calculate total balance for this account
  Future<double> _calculateTotal() async {
    final transactions = await _dbHelper.getFilteredTransactions(
      mode: widget.accountMode,
      category: widget.category,
      type: widget.filterType,
      timeframe: widget.filterTimeframe,
      sortBy: _sortBy,
    );
    double total = 0.0;
    for (var tx in transactions) {
      total += tx.type == TransactionType.income ? tx.amount : -tx.amount;
    }
    return total;
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E0C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE74C3C), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C)),
            SizedBox(width: 12),
            Text(
              'Dissolve Account?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Dissolve "${widget.category}"? This action is permanent and will wipe all ${_cachedTransactions.length} associated M-Pesa records from this ledger.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
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
            onPressed: () async {
              await _dbHelper.deleteCategory(widget.category);
              AppLogger.logWarning(
                  'Account: "${widget.category}" dissolved permanently');

              // Refresh category cache to remove ghost category
              await CategoryCache().refreshCategories();

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to Dashboard

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Account "${widget.category}" deleted'),
                    backgroundColor: const Color(0xFF2ECC71),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'DISSOLVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show sort menu modal
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF141D1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sort Transactions By',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2ECC71))),
              const SizedBox(height: 20),
              _sortOption('Date (Newest First)', 'Date'),
              _sortOption('Amount (Highest)', 'Amount'),
              _sortOption('Sender (A-Z)', 'Sender'),
            ],
          ),
        );
      },
    );
  }

  Widget _sortOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: value,
      groupValue: _sortBy,
      activeColor: UIUtils.incomeGreen,
      onChanged: (val) {
        setState(() => _sortBy = val!);
        Navigator.pop(context);
      },
    );
  }

  /// Handle filter chip taps
  void _handleFilterTap(String label) {
    setState(() {
      if (label == 'MAX') {
        _sortOrder = 'DESC';
        _sortBy = 'Amount';
      } else if (label == 'MIN') {
        _sortOrder = 'ASC';
        _sortBy = 'Amount';
      } else if (label == 'DATE') {
        _sortBy = 'Date';
      }
    });
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactShell();
    }
    return _buildDetailedView();
  }

  /// Build Dashboard Shell (inline implementation)
  Widget _buildCompactShell() {
    return FutureBuilder<double>(
      future: _calculateTotal(),
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0.0;

        return GestureDetector(
          onTap: widget.onViewAll ?? () {},
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: UIUtils.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: UIUtils.incomeGreen.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: UIUtils.incomeGreen.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClickableHeader(),
                const Divider(color: UIUtils.incomeGreen, height: 1),
                _buildTotalBalance(total),
                _buildFilterChips(),
                const SizedBox(height: 12),
                Expanded(child: _buildTransactionList(compact: true)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClickableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: UIUtils.incomeGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(UIUtils.getCategoryIcon(widget.category),
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.category.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Text('CLICK TO SEE ALL →',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  Widget _buildTotalBalance(double total) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: total >= 0
                      ? UIUtils.incomeGreen.withValues(alpha: 0.2)
                      : UIUtils.expenseRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  total >= 0 ? 'POSITIVE' : 'NEGATIVE',
                  style: TextStyle(
                    color:
                        total >= 0 ? UIUtils.incomeGreen : UIUtils.expenseRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ksh ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ).copyWith(
              color: total >= 0 ? UIUtils.incomeGreen : UIUtils.expenseRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('MAX', Icons.arrow_upward),
          const SizedBox(width: 8),
          _buildFilterChip('MIN', Icons.arrow_downward),
          const SizedBox(width: 8),
          _buildFilterChip('DATE', Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isActive = (label == 'MAX' && _sortOrder == 'DESC') ||
        (label == 'MIN' && _sortOrder == 'ASC') ||
        (label == 'DATE' && _sortBy == 'Date');

    return GestureDetector(
      onTap: () => _handleFilterTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? UIUtils.incomeGreen.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? UIUtils.incomeGreen
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: isActive
                    ? UIUtils.incomeGreen
                    : Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? UIUtils.incomeGreen
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Detailed View (full screen)
  Widget _buildDetailedView() {
    return Column(
      children: [
        // Header with Total and Sort
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: UIUtils.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<double>(
            future: _calculateTotal(),
            builder: (context, snapshot) {
              final total = snapshot.data ?? 0.0;
              return Column(
                children: [
                  const Text('Total Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    'Ksh ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ).copyWith(
                      color:
                          total >= 0 ? UIUtils.incomeGreen : UIUtils.expenseRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${widget.filterType} • ${widget.filterTimeframe}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Delete Account Button
                          IconButton(
                            onPressed: _showDeleteConfirmation,
                            icon: const Icon(
                              Icons.delete_forever_rounded,
                              color: Color(0xFF2ECC71), // Warning Emerald
                            ),
                            tooltip: 'Dissolve Account',
                          ),
                          TextButton.icon(
                            onPressed: _showSortMenu,
                            icon: const Icon(
                              Icons.sort,
                              color: UIUtils.incomeGreen,
                            ),
                            label: const Text(
                              'Sort',
                              style: TextStyle(color: UIUtils.incomeGreen),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(child: _buildTransactionList(compact: false)),
      ],
    );
  }

  /// Build Transaction List (AnimatedList)
  Widget _buildTransactionList({required bool compact}) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: UIUtils.incomeGreen));
    }
    if (_cachedTransactions.isEmpty) {
      return _buildEmptyState();
    }

    final isGeneralAccount = widget.category.toLowerCase() == 'general';

    return AnimatedList(
      key: _listKey,
      initialItemCount: _cachedTransactions.length,
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 15, vertical: compact ? 8 : 10),
      itemBuilder: (context, index, animation) {
        final tx = _cachedTransactions[index];
        if (compact) {
          return TransactionDetailTile(
            transaction: tx,
            isGeneralAccount: isGeneralAccount,
            onTransactionMoved: _handleTransactionMove,
          );
        }
        return SwipeToRejectWrapper(
          transactionId: tx.id.toString(),
          transactionCategory: tx.category,
          transactionSender: tx.sender,
          isAutoMoved: tx.isAutoMoved,
          onReject: () => _handleSwipeReject(tx.id.toString()),
          onDelete: () => _handleSwipeDelete(tx.id.toString()),
          child: DetailedTransactionTile(
            transaction: tx,
            animation: animation,
            onTransactionMoved: _handleTransactionMove,
          ),
        );
      },
    );
  }

  /// Empty State Widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(UIUtils.getCategoryIcon(widget.category),
              size: 50, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No ${widget.filterType.toLowerCase()} transactions',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            'for ${widget.filterTimeframe.toLowerCase()}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
