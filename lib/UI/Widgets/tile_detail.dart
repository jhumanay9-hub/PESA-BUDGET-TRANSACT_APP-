import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/ui/widgets/category_mover_buttons.dart';
import 'package:transaction_app/ui/utils/ui_utils.dart';

/// ============================================================================
/// TRANSACTION DETAIL TILE
/// ============================================================================
/// Displays individual transactions within an expanded AccountCard.
/// Shows: Sender, Date, Amount, and Category Mover Buttons (General account only)
/// Optimized for Huawei Y5 with efficient rendering
/// ============================================================================
class TransactionDetailTile extends StatelessWidget {
  final TransactionModel transaction;
  final bool isGeneralAccount;
  final Function(String transactionId, String newCategory)? onTransactionMoved;

  const TransactionDetailTile({
    super.key,
    required this.transaction,
    required this.isGeneralAccount,
    this.onTransactionMoved,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: UIUtils.getTransactionDecoration(
        isIncome: isIncome,
        isCompact: isGeneralAccount,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // FIX: Allow height to expand naturally
        children: [
          // BOX LIFT HEADER - Visually distinct transaction info zone
          _buildBoxLiftHeader(isIncome),

          // Visual separator between header and action zone
          if (isGeneralAccount) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: UIUtils.incomeGreen.withValues(alpha: 0.2),
              indent: 12,
              endIndent: 12,
            ),
            // MOVER BUTTONS AREA - Dynamic Wrap layout
            _buildMoverArea(),
          ],
        ],
      ),
    );
  }

  /// BOX LIFT HEADER - Elevated visual container for transaction details
  /// Creates a distinct "lifted" zone with shadow and different background
  Widget _buildBoxLiftHeader(bool isIncome) {
    final accentColor = isIncome ? UIUtils.incomeGreen : UIUtils.expenseRed;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Slightly different background for visual separation
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        // Subtle shadow for "lifted" effect
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        // Border for definition
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: UIUtils.getAvatarBackgroundColor(transaction.type),
            child: Icon(
              UIUtils.getTransactionIcon(transaction.type, isCompact: true),
              color: UIUtils.getAvatarIconColor(transaction.type),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGeneralAccount) ...[
                  // Vendor name (compact for mover buttons space)
                  Text(
                    transaction.sender,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Date
                  Text(
                    '${transaction.date.day}/${transaction.date.month}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ] else ...[
                  // Full message body for non-General accounts
                  Text(
                    transaction.body,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Text(
            "${isIncome ? '+' : '-'}Ksh ${transaction.amount.toStringAsFixed(0)}",
            style: TextStyle(
              color: UIUtils.getTransactionColor(transaction.type),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// MOVER BUTTONS AREA - Dynamic Wrap layout for unlimited categories
  /// FIX: Replaces Row with Wrap to handle 20+ accounts without overflow
  Widget _buildMoverArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label with icon
          const Row(
            children: [
              Icon(
                Icons.drive_file_move_rounded,
                size: 12,
                color: UIUtils.incomeGreen,
              ),
              SizedBox(width: 6),
              Text(
                'Move to:',
                style: TextStyle(
                  color: UIUtils.incomeGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // FIX: Wrap widget - auto-wraps when width depleted
          // Height expands naturally as rows are added
          Wrap(
            spacing: 8.0, // Horizontal gap between buttons
            runSpacing: 4.0, // Vertical gap between rows
            alignment: WrapAlignment.start, // Left-align buttons
            runAlignment: WrapAlignment.start, // Top-align rows
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              CategoryMoverButtons(
                transaction: transaction,
                onTransactionMoved: onTransactionMoved ?? (_, __) {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  // REMOVED: _buildTransactionInfo and _buildMoveRow - replaced with _buildBoxLiftHeader and _buildMoverArea
}

/// ============================================================================
/// TRANSACTION LIST BUILDER
/// ============================================================================
/// Handles loading and displaying transactions with filters applied.
/// Uses ListView.builder for memory efficiency on Huawei Y5
/// ============================================================================
class TransactionListBuilder extends StatefulWidget {
  final String accountMode;
  final String category;
  final String transactionType;
  final String? minAmount;
  final String? maxAmount;
  final DateTime? selectedDate;
  final Function(String transactionId, String newCategory)? onTransactionMoved;
  final Function(VoidCallback)? onRefreshCallback;

  const TransactionListBuilder({
    super.key,
    required this.accountMode,
    required this.category,
    required this.transactionType,
    this.minAmount,
    this.maxAmount,
    this.selectedDate,
    this.onTransactionMoved,
    this.onRefreshCallback,
  });

  @override
  State<TransactionListBuilder> createState() => _TransactionListBuilderState();
}

class _TransactionListBuilderState extends State<TransactionListBuilder> {
  final _dbHelper = DatabaseHelper();

  // Scroll controller to preserve position after transaction move
  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0.0;

  // FIX: Cache for transaction queries (prevents 30-42 frames skipped)
  List<TransactionModel>? _cachedTransactions;
  String? _cachedKey;

  // FIX: Debounce for transaction move notifications (prevents 3x reload)
  DateTime? _lastMoveTime;
  static const _moveDebounce = Duration(milliseconds: 500);

  // Track if we need to force refresh (after transaction move)
  bool _needsRefresh = false;

  /// Generate cache key from filter parameters
  String _getCacheKey() {
    return '${widget.category}:${widget.accountMode}:${widget.transactionType}:${widget.minAmount}:${widget.maxAmount}:${widget.selectedDate?.toIso8601String()}';
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();

    // Save scroll position
    _scrollController.addListener(() {
      _lastScrollOffset = _scrollController.offset;
    });

    // Register refresh callback with parent
    widget.onRefreshCallback?.call(forceRefresh);
  }

  @override
  void didUpdateWidget(TransactionListBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if filters changed OR if refresh is needed
    if (oldWidget.category != widget.category ||
        oldWidget.accountMode != widget.accountMode ||
        oldWidget.transactionType != widget.transactionType ||
        oldWidget.minAmount != widget.minAmount ||
        oldWidget.maxAmount != widget.maxAmount ||
        oldWidget.selectedDate != widget.selectedDate ||
        _needsRefresh) {
      _needsRefresh = false;
      _loadTransactions();
    }
  }

  /// Force refresh (called when transaction is moved)
  /// FIX: Debounced to prevent 3x reload when moving transaction
  void forceRefresh() {
    final now = DateTime.now();

    // FIX: Debounce check - skip if called within 500ms of last move
    if (_lastMoveTime != null &&
        now.difference(_lastMoveTime!) < _moveDebounce) {
      AppLogger.logInfo(
          'TransactionList: Move debounce active (${now.difference(_lastMoveTime!).inMilliseconds}ms)');
      return;
    }
    _lastMoveTime = now;

    _needsRefresh = true;
    _cachedTransactions = null;
    _cachedKey = null;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final cacheKey = _getCacheKey();

    // Return cached value if available and key matches (and no refresh needed)
    if (_cachedTransactions != null &&
        _cachedKey == cacheKey &&
        !_needsRefresh) {
      return;
    }

    // Query in background to prevent UI jank
    final transactions = await _dbHelper.getFilteredTransactions(
      mode: widget.accountMode,
      category: widget.category,
      type: widget.transactionType,
      timeframe: 'All Time',
      sortBy: 'Date',
    );

    if (mounted) {
      setState(() {
        _cachedTransactions = transactions;
        _cachedKey = cacheKey;
      });

      // Restore scroll position after data loads
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _lastScrollOffset > 0) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetScroll =
              _lastScrollOffset < maxScroll ? _lastScrollOffset : maxScroll;
          _scrollController.jumpTo(targetScroll);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use cached data directly - no FutureBuilder waiting
    final transactions = _cachedTransactions ?? [];

    if (transactions.isEmpty && _cachedKey == null) {
      // First load - show loading indicator
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
      );
    }

    if (transactions.isEmpty) {
      // No transactions - show empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 50, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No transactions found',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Check if this is the General account (shows mover buttons)
    final isGeneralAccount = widget.category.toLowerCase() == 'general';

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return TransactionDetailTile(
          transaction: transactions[index],
          isGeneralAccount: isGeneralAccount,
          onTransactionMoved: widget.onTransactionMoved,
        );
      },
    );
  }
}

/// ============================================================================
/// DETAILED TRANSACTION TILE - For Full Screen View
/// ============================================================================
/// Shows: Full transaction details with animation
/// Used in account_details_view.dart for full-screen transaction list
/// ============================================================================
class DetailedTransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final Animation<double> animation;
  final Function(String transactionId, String newCategory) onTransactionMoved;

  const DetailedTransactionTile({
    super.key,
    required this.transaction,
    required this.animation,
    required this.onTransactionMoved,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;

    return SizeTransition(
      sizeFactor: animation,
      key: Key(transaction.id.toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: UIUtils.getTransactionDecoration(
          isIncome: isIncome,
          isCompact: false,
        ),
        child: Column(
          children: [
            _buildListTile(isIncome),
            // Category Mover Buttons (General account only)
            if (transaction.category.toLowerCase() == 'general')
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TransactionMoveRow(
                  transaction: transaction,
                  onTransactionMoved: onTransactionMoved,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(bool isIncome) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: UIUtils.getAvatarBackgroundColor(transaction.type),
        child: Icon(
          UIUtils.getTransactionIcon(transaction.type, isCompact: false),
          color: UIUtils.getAvatarIconColor(transaction.type),
          size: 20,
        ),
      ),
      title: Text(
        transaction.sender,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        transaction.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.white54),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "${isIncome ? '+' : '-'} Ksh ${transaction.amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: UIUtils.getTransactionColor(transaction.type),
            ),
          ),
          Text(
            '${transaction.date.day} ${UIUtils.getMonthAbbreviation(transaction.date.month)}',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// TRANSACTION MOVE ROW - SHARED COMPONENT
/// ============================================================================
/// Reusable row widget for "Move to:" label and CategoryMoverButtons
/// Used by both TransactionDetailTile and DetailedTransactionTile
/// ============================================================================
class TransactionMoveRow extends StatelessWidget {
  final TransactionModel transaction;
  final Function(String transactionId, String newCategory)? onTransactionMoved;

  const TransactionMoveRow({
    super.key,
    required this.transaction,
    this.onTransactionMoved,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.drive_file_move_rounded,
            size: 12, color: UIUtils.incomeGreen),
        const SizedBox(width: 6),
        const Text(
          'Move to:',
          style: TextStyle(
            color: UIUtils.incomeGreen,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: CategoryMoverButtons(
            transaction: transaction,
            onTransactionMoved: onTransactionMoved ?? (_, __) {},
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// TRANSACTION REMOVAL PLACEHOLDER
/// ============================================================================
/// Shown when a transaction is being removed from the list (animated)
/// Used in account_details_view.dart for smooth removal animations
/// ============================================================================
class TransactionRemovalPlaceholder extends StatelessWidget {
  final Animation<double> animation;

  const TransactionRemovalPlaceholder({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UIUtils.cardBackground,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: UIUtils.incomeGreen.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text(
            'Transaction moved/deleted',
            style: TextStyle(
                color: UIUtils.incomeGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
