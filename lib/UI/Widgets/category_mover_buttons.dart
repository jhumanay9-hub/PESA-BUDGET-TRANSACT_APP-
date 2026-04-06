import 'package:flutter/material.dart';
import 'dart:async';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/services/category_cache.dart';
import 'package:transaction_app/data/database_helper.dart';

/// ============================================================================
/// CATEGORY MOVER BUTTONS - Dynamic Account Movement System
/// ============================================================================
/// This widget dynamically generates movement buttons for all active accounts.
///
/// Features:
/// - Reads categories from CategoryCache (no redundant DB queries)
/// - Creates buttons with custom theme colors and icons
/// - On tap: Updates transaction category in SQLite
/// - Triggers callback to remove item from parent list
/// - Automatically updates when accounts are added/deleted
/// - FIX: Listens to CategoryCache stream for reactive updates
/// ============================================================================
class CategoryMoverButtons extends StatefulWidget {
  final TransactionModel transaction;
  final Function(String transactionId, String newCategory) onTransactionMoved;

  const CategoryMoverButtons({
    super.key,
    required this.transaction,
    required this.onTransactionMoved,
  });

  @override
  State<CategoryMoverButtons> createState() => _CategoryMoverButtonsState();
}

class _CategoryMoverButtonsState extends State<CategoryMoverButtons> {
  final _categoryCache = CategoryCache();
  List<Map<String, dynamic>> _availableCategories = [];
  StreamSubscription? _categoriesSubscription;

  // FIX: Memoization keys to prevent redundant re-filtering
  // Only re-filter when these values change
  String? _lastTransactionId;
  String? _lastTransactionCategory;
  int? _lastCacheCategoryCount;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _listenToCategoryChanges();
  }

  @override
  void didUpdateWidget(CategoryMoverButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if transaction changed (not on parent rebuilds)
    if (oldWidget.transaction.id != widget.transaction.id) {
      _loadCategories();
    }
  }

  /// Listen to category cache stream for real-time updates
  void _listenToCategoryChanges() {
    _categoriesSubscription?.cancel();
    _categoriesSubscription = _categoryCache.categoriesStream.listen((_) {
      // Categories changed - reload
      if (mounted) {
        _loadCategories();
      }
    });
  }

  /// Load categories from cache (no DB query - cache is shared)
  void _loadCategories() {
    final allCategories = _categoryCache.categories;

    if (allCategories.isEmpty) {
      // Cache not loaded yet - load it asynchronously
      _categoryCache.loadCategories().then((_) {
        if (mounted) {
          _filterCategories();
        }
      });
      return;
    }

    _filterCategories();
  }

  /// Filter categories (exclude 'General' and current category)
  /// FIX: Memoized to prevent re-filtering on every parent rebuild
  /// FULIZA: Recommend Debt/Loans category for Fuliza transactions
  void _filterCategories() {
    final allCategories = _categoryCache.categories;
    final transactionId = widget.transaction.id;
    final transactionCategory = widget.transaction.category;
    final cacheCategoryCount = allCategories.length;

    // FIX: Memoization check - skip if params haven't changed
    if (_lastTransactionId == transactionId &&
        _lastTransactionCategory == transactionCategory &&
        _lastCacheCategoryCount == cacheCategoryCount) {
      // Already filtered with these exact params - skip redundant work
      return;
    }

    // ========================================================================
    // FULIZA SPECIAL HANDLING - Recommend Debt category
    // ========================================================================
    final isFuliza = widget.transaction.isFuliza;
    String? recommendedCategory;

    if (isFuliza) {
      // Look for Debt/Loans related categories
      final debtKeywords = [
        'debt',
        'loan',
        'debts',
        'loans',
        'credit',
        'advance'
      ];
      for (var cat in allCategories) {
        final catName = (cat['name'] as String).toLowerCase();
        if (debtKeywords.any((keyword) => catName.contains(keyword))) {
          recommendedCategory = cat['name'] as String;
          break;
        }
      }
    }

    final filtered = allCategories.where((c) {
      final catName = (c['name'] as String).toLowerCase();
      return catName != 'general' &&
          catName != transactionCategory.toLowerCase();
    }).toList();

    if (!mounted) return;

    // If this is a Fuliza transaction and we found a recommended category,
    // move it to the front of the list
    if (isFuliza && recommendedCategory != null) {
      final recommendedIndex = filtered
          .indexWhere((c) => (c['name'] as String) == recommendedCategory);
      if (recommendedIndex > 0) {
        final recommended = filtered.removeAt(recommendedIndex);
        filtered.insert(0, recommended);
      }
    }

    // FIX: Update memoization keys after successful filter
    _lastTransactionId = transactionId;
    _lastTransactionCategory = transactionCategory;
    _lastCacheCategoryCount = cacheCategoryCount;

    setState(() {
      _availableCategories = filtered;
    });
  }

  /// Handle category movement
  /// FIX: Track user corrections for AI auto-categorization learning
  Future<void> _moveToCategory(String newCategory) async {
    try {
      AppLogger.logInfo(
        'MoverButtons: Moving "${widget.transaction.sender}" to $newCategory',
      );

      // 1. Update in Database
      final dbHelper = DatabaseHelper();
      await dbHelper.updateTransactionCategory(
        widget.transaction.id,
        newCategory,
      );

      // FIX 2: Track user correction for AI learning
      // This increments the confidence score for vendor -> category pattern
      final vendorSignature = widget.transaction.sender;
      await dbHelper.incrementVendorPattern(vendorSignature, newCategory);

      // FIX 3: Reset rejection count when user manually moves to a new category
      // This allows the AI to re-learn with positive reinforcement
      await dbHelper.resetRejectionCount(vendorSignature, newCategory);

      AppLogger.logInfo(
          'AI: Tracked user correction "$vendorSignature" -> "$newCategory"');

      // 2. Notify parent to remove from list
      widget.onTransactionMoved(widget.transaction.id, newCategory);

      // 3. FIX: Refresh category cache (triggers stream notification to all listeners)
      await _categoryCache.refreshCategories();

      AppLogger.logSuccess(
        'MoverButtons: Successfully moved to $newCategory',
      );
    } catch (e) {
      AppLogger.logError('MoverButtons: Failed to move transaction', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move transaction: $e'),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _availableCategories.map((categoryData) {
        return _buildMoverButton(categoryData);
      }).toList(),
    );
  }

  Widget _buildMoverButton(Map<String, dynamic> categoryData) {
    final categoryName = categoryData['name'] as String;
    final iconCode = categoryData['icon_data'] as String;
    final colorValue = categoryData['color_value'] as int;
    final themeColor = Color(colorValue);

    // Convert icon code point back to IconData
    final iconData = IconData(
      int.tryParse(iconCode) ?? 0,
      fontFamily: 'MaterialIcons',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _moveToCategory(categoryName),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.2),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                size: 12,
                color: themeColor,
              ),
              const SizedBox(width: 4),
              Text(
                categoryName,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
