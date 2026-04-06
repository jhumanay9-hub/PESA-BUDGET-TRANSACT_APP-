import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/core/logger.dart';

class DatabaseService {
  final _dbHelper = DatabaseHelper();

  /// Logic: The "High Level" Fetcher
  /// This doesn't just get data; it can handle errors and log them before the UI sees them.
  Future<List<TransactionModel>> getTransactionsForTab(
    String mode,
    String category, {
    String sort = "Date",
  }) async {
    try {
      AppLogger.logInfo(
          "DB Service: Fetching $category items for $mode mode...");
      return await _dbHelper.getFilteredTransactions(
        mode: mode,
        category: category,
        type: 'All',
        timeframe: 'All Time',
        sortBy: sort,
      );
    } catch (e) {
      AppLogger.logError("DB Service: Failed to fetch tab data", e);
      return [];
    }
  }

  /// Logic: Calculate Balance
  /// Instead of the UI doing math, the Service calculates the balance from the DB.
  Future<double> calculateBalance(String mode, String category) async {
    try {
      final transactions = await getTransactionsForTab(mode, category);
      double balance = 0.0;
      for (var tx in transactions) {
        if (tx.type == TransactionType.income) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }
      AppLogger.logInfo("DB Service: Calculated balance: $balance");
      return balance;
    } catch (e) {
      AppLogger.logError("DB Service: Balance calculation failed", e);
      return 0.0;
    }
  }
}
