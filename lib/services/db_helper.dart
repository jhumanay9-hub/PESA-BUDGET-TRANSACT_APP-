import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'dart:async';
import 'logger.dart';
import 'database_service.dart';

// DatabaseFailure moved to database_service.dart

class DbHelper {
  static final StreamController<void> _updateController = StreamController<void>.broadcast();
  static Stream<void> get onUpdate => _updateController.stream;

  static void notifyUpdate() {
    try {
      _updateController.add(null);
    } catch (_) {}
  }

  static Future<Database> getDatabase() async {
    return DatabaseService.getDatabase();
  }



  static Future<bool> checkCategoriesSeeded() async {
    try {
      final db = await getDatabase();
      final result = await db.query('categories', where: 'name IN (?, ?, ?, ?, ?, ?)', 
        whereArgs: ['General', 'Revenue', 'Food', 'Rent', 'Transport', 'Bills']);
      return result.length >= 6;
    } catch (e) {
      return false;
    }
  }

  static Future<int> restoreDefaultCategories() async {
    int insertedCount = 0;
    try {
      final db = await getDatabase();
      final defaults = [
        {'name': 'General', 'color': 0xFF607D8B, 'icon': 'account_balance_wallet'},
        {'name': 'Revenue', 'color': 0xFF4CAF50, 'icon': 'add_chart'},
        {'name': 'Food', 'color': 0xFFFF9800, 'icon': 'restaurant'},
        {'name': 'Rent', 'color': 0xFF9C27B0, 'icon': 'home'},
        {'name': 'Transport', 'color': 0xFF2196F3, 'icon': 'directions_car'},
        {'name': 'Bills', 'color': 0xFFF44336, 'icon': 'receipt'},
      ];

      final existing = await db.query('categories');
      final existingNames = existing.map((r) => r['name'] as String).toSet();

      for (final cat in defaults) {
        if (!existingNames.contains(cat['name'])) {
          await db.insert('categories', cat, conflictAlgorithm: ConflictAlgorithm.ignore);
          insertedCount++;
        }
      }
      if (insertedCount > 0) notifyUpdate();
      return insertedCount;
    } catch (e) {
      Logger.logError("Error restoring default categories", e);
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final db = await getDatabase();
      return await db.query('categories', orderBy: 'id ASC');
    } catch (e) {
      Logger.logError("Error fetching categories", e);
      return [];
    }
  }

  static Future<dynamic> insertCategory(String name, {int color = 0xFF607D8B, String icon = 'category'}) async {
    try {
      final db = await getDatabase();
      final id = await db.insert(
        'categories',
        {
          'name': name,
          'color': color,
          'icon': icon,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      notifyUpdate();
      return id;
    } catch (e) {
      Logger.logError("Error inserting category", e);
      return -1;
    }
  }

  static Future<dynamic> getFilteredTransactions({
    required String categoryName,
    DateTimeRange? dateRange,
    double? minAmount,
    double? maxAmount,
  }) async {
    try {
      final db = await getDatabase();
      String whereClause = categoryName == 'General' 
          ? '(category = ? OR category IS NULL OR category = \'\')' 
          : 'category = ?';
      List<dynamic> whereArgs = [categoryName];

      if (dateRange != null) {
        whereClause += ' AND date BETWEEN ? AND ?';
        whereArgs.addAll([dateRange.start.toIso8601String(), dateRange.end.toIso8601String()]);
      }
      if (minAmount != null) {
        whereClause += ' AND amount >= ?';
        whereArgs.add(minAmount);
      }
      if (maxAmount != null) {
        whereClause += ' AND amount <= ?';
        whereArgs.add(maxAmount);
      }

      return await db.query(
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'id DESC',
      );
    } catch (e) {
      Logger.logError("Error in getFilteredTransactions", e);
      return [];
    }
  }

  static Future<dynamic> getGlobalSearchTransactions(String query) async {
    try {
      final db = await getDatabase();
      return await db.query(
        'transactions',
        where: 'body LIKE ? OR merchant LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'id DESC',
      );
    } catch (e) {
      Logger.logError("Error in search", e);
      return [];
    }
  }

  /// Paged fetch for transaction history (optional category filter)
  static Future<dynamic> getTransactionsPage({
    String? categoryName,
    required int limit,
    required int offset,
  }) async {
    try {
      final db = await getDatabase();

      String? whereClause;
      List<dynamic>? whereArgs;

      if (categoryName != null && categoryName != 'All') {
        if (categoryName == 'General') {
          whereClause = '(category = ? OR category IS NULL OR category = \'\')';
          whereArgs = [categoryName];
        } else {
          whereClause = 'category = ?';
          whereArgs = [categoryName];
        }
      }

      return db.query(
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'id DESC',
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      Logger.logError("Error fetching transactions page", e);
      return [];
    }
  }

  static Future<double> getTotalForCategory(String categoryName) async {
    try {
      final db = await getDatabase();
      final List<Map<String, Object?>> result;

      // Ensure the General account total also counts uncategorised rows
      if (categoryName == 'General') {
        result = await db.rawQuery(
          'SELECT SUM(amount) as total FROM transactions WHERE category = ? OR category IS NULL OR category = \'\'',
          [categoryName],
        );
      } else {
        result = await db.rawQuery(
          'SELECT SUM(amount) as total FROM transactions WHERE category = ?',
          [categoryName],
        );
      }
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Logger.logError("Error calculating total for $categoryName", e);
      return 0.0;
    }
  }

  static Future<int> deleteTransaction(int id) async {
    try {
      final db = await getDatabase();
      final count = await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyUpdate();
      return count;
    } catch (e) {
      Logger.logError("Error deleting transaction $id", e);
      return -1; // Indicate failure
    }
  }

  static Future<bool> isUserExists(String identifier) async {
    try {
      final db = await getDatabase();
      final result = await db.query(
        'users',
        where: 'identifier = ?',
        whereArgs: [identifier],
      );
      return result.isNotEmpty;
    } catch (e) {
      Logger.logError("Error checking if user exists", e);
      return false;
    }
  }

  static Future<void> updateUserPin(String identifier, String newPin) async {
    final db = await getDatabase();
    await db.update(
      'users',
      {'pin': newPin},
      where: 'identifier = ?',
      whereArgs: [identifier],
    );
  }

  static Future<void> updateHeartbeat() async {
    await DatabaseService.updateHeartbeat();
  }

  static Future<DateTime?> getLastHeartbeat() async {
    return DatabaseService.getLastHeartbeat();
  }
  static Future<void> insertUser({
    required String identifier,
    required String name,
    String? phone,
    String? email,
    bool isSyncedToCloud = false,
  }) async {
    final db = await getDatabase();
    await db.insert(
      'users',
      {
        'identifier': identifier,
        'name': name,
        'phone': phone,
        'email': email,
        'is_synced_to_cloud': isSyncedToCloud ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
