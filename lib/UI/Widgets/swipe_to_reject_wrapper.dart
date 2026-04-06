import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/services/vendor_signature.dart';

/// ============================================================================
/// SWIPE TO REJECT WRAPPER - AI Learning Loop
/// ============================================================================
/// Implements the "Exile" logic for the Reinforcement Learning system:
///
/// 1. Swipe in Category Account → Move to General (Exile)
/// 2. Increment rejection_count for vendor signature
/// 3. If rejection_count >= 5 → Reset AI confidence (mute pattern)
///
/// 4. Swipe in General Account → Permanent Delete (only way to remove data)
/// ============================================================================
class SwipeToRejectWrapper extends StatelessWidget {
  final Widget child;
  final String transactionId;
  final String transactionCategory;
  final String transactionSender;
  final bool isAutoMoved;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const SwipeToRejectWrapper({
    super.key,
    required this.child,
    required this.transactionId,
    required this.transactionCategory,
    required this.transactionSender,
    required this.isAutoMoved,
    required this.onReject,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(transactionId),
      direction: DismissDirection.endToStart, // Swipe from right to left
      onDismissed: (direction) {
        _handleSwipe(context);
      },
      confirmDismiss: (direction) async {
        return await _showConfirmationDialog(context);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isGeneralAccount ? Icons.delete_forever : Icons.undo,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              _isGeneralAccount ? "Delete" : "Reject",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  /// Check if current account is General (for permanent delete)
  bool get _isGeneralAccount => transactionCategory.toLowerCase() == 'general';

  /// Handle swipe action based on account type
  void _handleSwipe(BuildContext context) {
    if (_isGeneralAccount) {
      // Permanent delete from General account
      AppLogger.logWarning(
        "Swipe: Permanent delete transaction $transactionId from General",
      );
      onDelete();
      _showSuccessMessage(context, "Transaction deleted permanently");
    } else {
      // Exile to General (AI rejection)
      AppLogger.logWarning(
        "Swipe: Rejecting transaction $transactionId from $transactionCategory",
      );
      onReject();
      _showSuccessMessage(context, "Moved back to General for re-learning");
    }
  }

  /// Show confirmation dialog with context-aware messaging
  Future<bool?> _showConfirmationDialog(BuildContext context) {
    if (_isGeneralAccount) {
      return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Permanently?"),
          content: const Text(
            "This will permanently remove this transaction from your database. This action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text("DELETE", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Reject Categorization?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This will move the transaction back to General account.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology,
                            size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          "AI Learning",
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "The AI will learn from this rejection. After 5 rejections, it will stop auto-categorizing this vendor.",
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text("REJECT", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  /// Show success message after action
  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _isGeneralAccount ? Colors.red : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// ============================================================================
/// AI REJECTION HANDLER - Business Logic
/// ============================================================================
/// Handles the reinforcement learning loop when user rejects a categorization
/// ============================================================================
class AiRejectionHandler {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Process rejection: Move to General and update AI learning
  Future<void> processRejection({
    required String transactionId,
    required String transactionSender,
    required String currentCategory,
  }) async {
    // Step 1: Move transaction back to General (Exile)
    await _moveToGeneral(transactionId);

    // Step 2: Normalize vendor signature
    final vendorSignature = VendorSignature.normalize(transactionSender);

    // Step 3: Increment rejection count for this vendor pattern
    await _incrementRejectionCount(vendorSignature, currentCategory);

    // Step 4: Check if pattern should be muted (rejection_count >= 5)
    await _checkAndMutePattern(vendorSignature);

    AppLogger.logWarning(
      'AI Rejection: "$vendorSignature" rejected from "$currentCategory" - moved to General',
    );
  }

  /// Move transaction back to General account
  Future<void> _moveToGeneral(String transactionId) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableTransactions,
      {
        'category': 'General',
        'is_auto_moved': 0,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Increment rejection count for vendor->category pattern
  Future<void> _incrementRejectionCount(
      String vendorSignature, String categoryName) async {
    final db = await _dbHelper.database;

    // Get category ID
    final categoryResult = await db.query(
      DatabaseHelper.tableCategories,
      where: 'name = ?',
      whereArgs: [categoryName],
      limit: 1,
    );

    if (categoryResult.isEmpty) return;
    final categoryId = categoryResult.first['id'] as int;

    // Check if pattern exists
    final existingPattern = await db.query(
      DatabaseHelper.tableVendorCategories,
      where: 'vendor_signature = ?',
      whereArgs: [vendorSignature],
      limit: 1,
    );

    if (existingPattern.isNotEmpty) {
      final existingCategoryId = existingPattern.first['category_id'] as int;

      // Only increment if same category (user is rejecting this specific pattern)
      if (existingCategoryId == categoryId) {
        await db.rawUpdate('''
          UPDATE ${DatabaseHelper.tableVendorCategories}
          SET rejection_count = rejection_count + 1,
              last_updated = ?
          WHERE vendor_signature = ?
        ''', [DateTime.now().toIso8601String(), vendorSignature]);

        AppLogger.logInfo(
          'AI: Incremented rejection count for "$vendorSignature" -> "$categoryName"',
        );
      }
    }
  }

  /// Check if pattern should be muted (rejection_count >= 5)
  Future<void> _checkAndMutePattern(String vendorSignature) async {
    final db = await _dbHelper.database;

    final pattern = await db.query(
      DatabaseHelper.tableVendorCategories,
      where: 'vendor_signature = ?',
      whereArgs: [vendorSignature],
      limit: 1,
    );

    if (pattern.isNotEmpty) {
      final rejectionCount = pattern.first['rejection_count'] as int;

      // REINFORCEMENT LEARNING: If rejected 5+ times, mute the pattern
      if (rejectionCount >= 5) {
        await db.rawUpdate('''
          UPDATE ${DatabaseHelper.tableVendorCategories}
          SET confidence_score = 0
          WHERE vendor_signature = ?
        ''', [vendorSignature]);

        AppLogger.logWarning(
          'AI MUTED: "$vendorSignature" pattern disabled (rejected $rejectionCount times)',
        );
      }
    }
  }

  /// Permanent delete from General account
  Future<void> permanentDelete(String transactionId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableTransactions,
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    AppLogger.logWarning(
        'Database: Permanently deleted transaction $transactionId');
  }
}
