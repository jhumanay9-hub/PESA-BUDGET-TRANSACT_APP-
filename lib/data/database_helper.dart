import 'dart:io' as dart_io;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/models/transaction_model.dart';

/// Cache entry for query results with timestamp
class _QueryCacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _QueryCacheEntry({required this.data, required this.timestamp});
}

/// Initialize database factory for isolates
/// NOTE: sqflite automatically initializes databaseFactory on Android
/// This function is kept for documentation purposes
void initializeDatabaseFactoryForIsolate() {
  // On Android, sqflite automatically sets databaseFactory
  // This is a no-op but we keep it for clarity
  if (dart_io.Platform.isAndroid) {
    AppLogger.logInfo(
        'Database: databaseFactory ready (auto-initialized by sqflite)');
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Flag to track if database is being initialized
  static bool _isInitializing = false;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String tableTransactions = 'transactions';
  static const String tableCategories = 'categories';
  static const String tableVendorCategories =
      'vendor_categories'; // FIX: Auto-categorization table

  /// Pre-warm database in background isolate (prevents UI jank)
  /// FIX: Initialize databaseFactory for isolate context
  static Future<void> preWarm() async {
    // FIX: Initialize databaseFactory for isolates (prevents "not initialized" error)
    initializeDatabaseFactoryForIsolate();

    if (_isInitializing || _database != null) return;
    _isInitializing = true;

    try {
      // Force database initialization in background
      final db = await _instance._initDatabase();
      // Quick query to ensure ready
      await db.query('sqlite_master', limit: 1);
      AppLogger.logInfo('Database: Pre-warmed in background');
    } catch (e) {
      AppLogger.logError('Database: Pre-warm failed', e);
    } finally {
      _isInitializing = false;
    }
  }

  /// Get database instance (with pre-warm check)
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_isInitializing) {
      // Wait for initialization to complete
      while (_isInitializing && _database == null) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (_database != null) return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Only log on first initialization (not on every access)
    final isFirstInit = _database == null;

    String path = join(await getDatabasesPath(), 'pesa_budget_transactions.db');
    if (isFirstInit) {
      AppLogger.logInfo('Database: Initializing at $path');
    }

    return await openDatabase(path,
        version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.logData('Database: Creating table "$tableTransactions"');
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id TEXT PRIMARY KEY,
        amount REAL,
        body TEXT,
        date TEXT,
        sender TEXT,
        type TEXT,
        category TEXT,
        account_type TEXT,
        is_synced INTEGER DEFAULT 0,
        is_auto_categorized INTEGER DEFAULT 0,
        is_auto_moved INTEGER DEFAULT 0,
        rejection_count INTEGER DEFAULT 0
      )
    ''');

    AppLogger.logData('Database: Creating table "$tableCategories"');
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        icon_data TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // FIX: Create vendor_categories table for auto-categorization
    AppLogger.logData('Database: Creating table "$tableVendorCategories"');
    await db.execute('''
      CREATE TABLE $tableVendorCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor_signature TEXT UNIQUE NOT NULL,
        category_id INTEGER NOT NULL,
        confidence_score INTEGER DEFAULT 1,
        rejection_count INTEGER DEFAULT 0,
        last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES $tableCategories(id) ON DELETE CASCADE
      )
    ''');

    // Insert default categories
    await _insertDefaultCategories(db);

    AppLogger.logSuccess('Database: Schema applied successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      AppLogger.logInfo(
          'Database: Upgrading to version 2 - Adding categories table');
      await db.execute('''
        CREATE TABLE $tableCategories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          icon_data TEXT NOT NULL,
          color_value INTEGER NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await _insertDefaultCategories(db);
    }

    // FIX: Upgrade to version 3 - Add vendor_categories table and is_auto_categorized
    if (oldVersion < 3) {
      AppLogger.logInfo(
          'Database: Upgrading to version 3 - Adding auto-categorization');

      // Add is_auto_categorized column to transactions
      try {
        await db.execute(
            'ALTER TABLE $tableTransactions ADD COLUMN is_auto_categorized INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist
        AppLogger.logInfo(
            'Database: is_auto_categorized column may already exist');
      }

      // Create vendor_categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableVendorCategories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vendor_signature TEXT UNIQUE NOT NULL,
          category_id INTEGER NOT NULL,
          confidence_score INTEGER DEFAULT 1,
          last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (category_id) REFERENCES $tableCategories(id) ON DELETE CASCADE
        )
      ''');

      AppLogger.logSuccess('Database: Auto-categorization tables added');
    }

    // Upgrade to version 4 - Add rejection tracking for AI learning
    if (oldVersion < 4) {
      AppLogger.logInfo(
          'Database: Upgrading to version 4 - Adding rejection tracking');

      // Add is_auto_moved and rejection_count columns to transactions
      try {
        await db.execute(
            'ALTER TABLE $tableTransactions ADD COLUMN is_auto_moved INTEGER DEFAULT 0');
      } catch (e) {
        AppLogger.logInfo('Database: is_auto_moved column may already exist');
      }

      try {
        await db.execute(
            'ALTER TABLE $tableTransactions ADD COLUMN rejection_count INTEGER DEFAULT 0');
      } catch (e) {
        AppLogger.logInfo('Database: rejection_count column may already exist');
      }

      // Add rejection_count column to vendor_categories
      try {
        await db.execute(
            'ALTER TABLE $tableVendorCategories ADD COLUMN rejection_count INTEGER DEFAULT 0');
      } catch (e) {
        AppLogger.logInfo(
            'Database: vendor_categories.rejection_count column may already exist');
      }

      AppLogger.logSuccess('Database: Rejection tracking columns added');
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      {
        'name': 'General',
        'icon': 'account_balance_wallet',
        'color': 0xFF2ECC71
      },
      {'name': 'Food', 'icon': 'restaurant', 'color': 0xFFE67E22},
      {'name': 'Bills', 'icon': 'receipt', 'color': 0xFFE74C3C},
      {'name': 'Transport', 'icon': 'directions_bus', 'color': 0xFF3498DB},
    ];

    for (var cat in defaultCategories) {
      await db.insert(
          tableCategories,
          {
            'name': cat['name'],
            'icon_data': cat['icon'],
            'color_value': cat['color'],
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    AppLogger.logSuccess('Database: Default categories inserted');
  }

  // --- NEW: THE ADVANCED FILTER QUERY ---

  // Query result cache - prevents redundant database hits during swiping
  // Using dynamic to support different result types (List<TransactionModel> and double)
  final Map<String, _QueryCacheEntry<dynamic>> _queryCache = {};
  static const _queryCacheDuration = Duration(seconds: 30);

  // Query coalescing - prevents duplicate identical queries in flight
  final Map<String, Future<List<TransactionModel>>> _pendingQueries = {};

  /// This method powers the Filter Bar + Tabs
  Future<List<TransactionModel>> getFilteredTransactions({
    required String mode, // Personal vs Business
    required String category, // General, Food, etc.
    required String type, // All, Income, Expense
    required String timeframe, // Today, Week, Month
    required String sortBy, // Date, Amount, Sender
  }) async {
    // Generate cache key
    final cacheKey = '$mode|$category|$type|$timeframe|$sortBy';

    // CHECK 1: Return pending query if one exists (COALESCING)
    // This prevents 3 identical queries when multiple widgets rebuild
    if (_pendingQueries.containsKey(cacheKey)) {
      AppLogger.logInfo('Database: Coalescing duplicate query for $category');
      return _pendingQueries[cacheKey]!;
    }

    // CHECK 2: Check cache first
    final cachedEntry = _queryCache[cacheKey];
    if (cachedEntry != null &&
        DateTime.now().difference(cachedEntry.timestamp) <
            _queryCacheDuration) {
      AppLogger.logData('Database: Cache hit for $category ($timeframe)');
      return cachedEntry.data as List<TransactionModel>;
    }

    final db = await database;

    // 1. Base Query
    String whereClause = 'account_type = ? AND category = ?';
    List<dynamic> whereArgs = [mode, category];

    // 2. Add Transaction Type Filter
    if (type != "All") {
      whereClause += ' AND type = ?';
      whereArgs.add(type.toLowerCase());
    }

    // 3. Add Timeframe Filter (M-PESA Date logic)
    if (timeframe != "All Time") {
      DateTime now = DateTime.now();
      DateTime startDate;

      if (timeframe == "Today") {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (timeframe == "This Week") {
        startDate = now.subtract(Duration(days: now.weekday - 1));
      } else {
        startDate = DateTime(now.year, now.month, 1); // This Month
      }

      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    // 4. Handle Sorting
    String orderBy;
    switch (sortBy) {
      case "Amount":
        orderBy = "amount DESC";
        break;
      case "Sender":
        orderBy = "sender ASC";
        break;
      default:
        orderBy = "date DESC"; // Date
    }

    AppLogger.logData('Database: Fetching $type for $category ($timeframe)');

    // Create the query future and track it (COALESCING)
    final queryFuture =
        _performQuery(db, tableTransactions, whereClause, whereArgs, orderBy)
            .then((result) {
      // Remove from pending when complete
      _pendingQueries.remove(cacheKey);

      // Cache the result
      _queryCache[cacheKey] = _QueryCacheEntry(
        data: result,
        timestamp: DateTime.now(),
      );

      return result;
    }).catchError((error) {
      // Remove from pending on error too
      _pendingQueries.remove(cacheKey);
      AppLogger.logError('Database: Query failed for $category', error);
      return <TransactionModel>[]; // Return empty list on error
    });

    return queryFuture;
  }

  /// Perform the actual database query (extracted for coalescing)
  Future<List<TransactionModel>> _performQuery(
    Database db,
    String table,
    String whereClause,
    List<dynamic> whereArgs,
    String orderBy,
  ) async {
    final List<Map<String, dynamic>> maps = await db.query(
      table,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  /// Clear query cache (call after data changes)
  void clearQueryCache() {
    _queryCache.clear();
    AppLogger.logInfo('Database: Query cache cleared');
  }

  /// Selective cache invalidation - only clear affected categories
  void _invalidateCategoryCache(String category) {
    // Remove cached queries for this category
    final keysToRemove =
        _queryCache.keys.where((key) => key.contains('|$category|')).toList();
    for (final key in keysToRemove) {
      _queryCache.remove(key);
    }
    AppLogger.logInfo('Database: Cache invalidated for category: $category');
  }

  /// Clear cache for specific category (called after writes)
  void clearCategoryCache(String category) {
    _invalidateCategoryCache(category);
    // Also clear balance caches for this category
    final balanceKeys = _queryCache.keys
        .where(
            (key) => key.startsWith('balance|') && key.contains('|$category|'))
        .toList();
    for (final key in balanceKeys) {
      _queryCache.remove(key);
    }
  }

  // --- BATCH ACTIONS ---

  /// Optimized batch insert - single transaction for all items
  Future<void> insertTransactions(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (var tx in transactions) {
      batch.insert(
        tableTransactions,
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Commit all at once (much faster than individual inserts)
    await batch.commit(noResult: true);

    // FIX: Selective cache invalidation - only clear affected categories
    // This prevents unnecessary cache clears when other categories are unchanged
    final affectedCategories = transactions.map((t) => t.category).toSet();
    for (final category in affectedCategories) {
      clearCategoryCache(category);
    }

    AppLogger.logInfo(
        'Database: Cache invalidated for ${affectedCategories.length} category(s)');
  }

  /// Get count of transactions in a specific category
  Future<int> getCategoryCount(String category) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $tableTransactions WHERE category = ?',
        [category],
      ),
    );
    return count ?? 0;
  }

  /// Get account balance (SUM) - Database-side calculation
  /// Returns net balance (income - expenses) for a category
  Future<double> getAccountBalance({
    required String mode,
    required String category,
  }) async {
    // Generate cache key
    final cacheKey = 'balance|$mode|$category';

    // Check cache first
    final cachedEntry = _queryCache[cacheKey] as _QueryCacheEntry<double>?;
    if (cachedEntry != null &&
        DateTime.now().difference(cachedEntry.timestamp) <
            _queryCacheDuration) {
      AppLogger.logData('Database: Balance cache hit for $category ($mode)');
      return cachedEntry.data;
    }

    final db = await database;

    // Use SQL SUM for efficient calculation
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense
      FROM $tableTransactions
      WHERE account_type = ? AND category = ?
    ''', [mode, category]);

    if (result.isNotEmpty) {
      final totalIncome = result.first['total_income'] as double? ?? 0.0;
      final totalExpense = result.first['total_expense'] as double? ?? 0.0;
      final balance = totalIncome - totalExpense;

      AppLogger.logData(
        'Database: Balance for $category ($mode) = Ksh ${balance.toStringAsFixed(2)}',
      );

      // Cache the result
      _queryCache[cacheKey] = _QueryCacheEntry(
        data: balance,
        timestamp: DateTime.now(),
      );

      return balance;
    }

    return 0.0;
  }

  Future<int> getRowCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableTransactions'),
    );
    return count ?? 0;
  }

  // --- ALL TRANSACTIONS (For History Page) ---

  /// Fetches all transactions for the search/history page
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  // --- DATE RANGE QUERY (For Export/Download) ---

  /// Fetches transactions within a specific date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TransactionModel.fromMap(maps[i]));
  }

  // --- TRANSACTION MOVEMENT SYSTEM ---

  /// Get all unique categories from the database
  Future<List<String>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT DISTINCT category FROM $tableTransactions ORDER BY category ASC',
    );
    return results.map((row) => row['category'] as String).toList();
  }

  // --- CATEGORY MANAGEMENT SYSTEM ---

  /// Get all categories with their icons and colors
  Future<List<Map<String, dynamic>>> getAllCategoriesWithDetails() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      tableCategories,
      orderBy: 'name ASC',
    );
    return results;
  }

  /// Insert a new category (account)
  Future<int> insertCategory(
      String name, String iconData, int colorValue) async {
    final db = await database;
    try {
      final id = await db.insert(
        tableCategories,
        {
          'name': name,
          'icon_data': iconData,
          'color_value': colorValue,
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      AppLogger.logSuccess('Database: Category "$name" created with ID $id');
      return id;
    } on DatabaseException catch (e) {
      AppLogger.logError('Database: Failed to create category "$name"', e);
      return -1; // Indicates failure (duplicate name)
    }
  }

  /// Check if category name already exists
  Future<bool> categoryExists(String name) async {
    final db = await database;
    final results = await db.query(
      tableCategories,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Delete a category (and optionally move transactions to General)
  Future<void> deleteCategory(String name,
      {String moveToCategory = 'General'}) async {
    final db = await database;
    await db.transaction((txn) async {
      // Move all transactions from deleted category to another
      await txn.update(
        tableTransactions,
        {'category': moveToCategory},
        where: 'category = ?',
        whereArgs: [name],
      );
      // Delete the category
      await txn.delete(
        tableCategories,
        where: 'name = ?',
        whereArgs: [name],
      );
    });
    AppLogger.logWarning(
        'Database: Category "$name" deleted, transactions moved to "$moveToCategory"');
  }

  /// Delete a category and ALL its transactions (permanent delete)
  Future<void> deleteCategoryWithTransactions(String name) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete all transactions in this category
      await txn.delete(
        tableTransactions,
        where: 'category = ?',
        whereArgs: [name],
      );
      // Delete the category
      await txn.delete(
        tableCategories,
        where: 'name = ?',
        whereArgs: [name],
      );
    });
    AppLogger.logWarning(
        'Database: Category "$name" and all its transactions deleted');
  }

  /// Delete transactions by category (permanent delete)
  Future<void> deleteTransactionsByCategory(String category) async {
    final db = await database;
    await db.delete(
      tableTransactions,
      where: 'category = ?',
      whereArgs: [category],
    );
    AppLogger.logWarning('Database: All transactions in "$category" deleted');
  }

  /// Update a transaction's category
  Future<void> updateTransactionCategory(String id, String newCategory) async {
    final db = await database;

    // Get the old category before updating
    final existing = await db.query(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    await db.update(
      tableTransactions,
      {'category': newCategory},
      where: 'id = ?',
      whereArgs: [id],
    );

    // FIX: Selective cache invalidation - clear both old and new categories
    if (existing.isNotEmpty) {
      final oldCategory = existing.first['category'] as String;
      clearCategoryCache(oldCategory);
    }
    clearCategoryCache(newCategory);

    AppLogger.logInfo('Database: Transaction $id moved to $newCategory');
  }

  /// Move a transaction to a different account mode (Personal/Business)
  Future<void> updateTransactionAccountType(
      String id, String newAccountType) async {
    final db = await database;
    await db.update(
      tableTransactions,
      {'account_type': newAccountType},
      where: 'id = ?',
      whereArgs: [id],
    );
    // For account type changes, clear all caches (affects all categories)
    clearQueryCache();
  }

  // ============================================================================
  // VENDOR AUTO-CATEGORIZATION METHODS
  // ============================================================================

  /// Get auto-categorized vendor pattern (returns category if confidence >= threshold)
  /// Threshold: 20 for auto, 10 for suggestion
  Future<String?> getAutoCategoryForVendor(String vendorSignature,
      {int threshold = 20}) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT c.name as category_name
      FROM $tableVendorCategories vc
      JOIN $tableCategories c ON vc.category_id = c.id
      WHERE vc.vendor_signature = ? AND vc.confidence_score >= ?
      ORDER BY vc.confidence_score DESC
      LIMIT 1
    ''', [vendorSignature, threshold]);

    if (result.isNotEmpty) {
      final categoryName = result.first['category_name'] as String?;
      if (categoryName != null && categoryName != 'General') {
        AppLogger.logData(
            'Auto-categorization: "$vendorSignature" -> "$categoryName" (confidence: ${result.first['confidence_score']})');
        return categoryName;
      }
    }
    return null; // Use default (General)
  }

  /// Increment confidence score for vendor->category pattern (upsert)
  /// If user changes category, reset confidence to 1
  Future<void> incrementVendorPattern(
      String vendorSignature, String categoryName) async {
    final db = await database;

    // Get category ID
    final categoryResult = await db.query(
      tableCategories,
      where: 'name = ?',
      whereArgs: [categoryName],
      limit: 1,
    );

    if (categoryResult.isEmpty) return;
    final categoryId = categoryResult.first['id'] as int;

    // Check if pattern exists with different category (user correction)
    final existingPattern = await db.query(
      tableVendorCategories,
      where: 'vendor_signature = ?',
      whereArgs: [vendorSignature],
      limit: 1,
    );

    if (existingPattern.isNotEmpty) {
      final existingCategoryId = existingPattern.first['category_id'] as int;

      // If user moved to different category, reset confidence to 1
      if (existingCategoryId != categoryId) {
        await db.update(
          tableVendorCategories,
          {
            'category_id': categoryId,
            'confidence_score': 1,
            'last_updated': DateTime.now().toIso8601String(),
          },
          where: 'vendor_signature = ?',
          whereArgs: [vendorSignature],
        );
        AppLogger.logInfo(
            'AI: User corrected "$vendorSignature" pattern - confidence reset to 1');
      } else {
        // Same category - increment confidence
        await db.rawUpdate('''
          UPDATE $tableVendorCategories
          SET confidence_score = confidence_score + 1,
              last_updated = ?
          WHERE vendor_signature = ?
        ''', [DateTime.now().toIso8601String(), vendorSignature]);
        AppLogger.logInfo(
            'AI: Incremented "$vendorSignature" -> "$categoryName" confidence');
      }
    } else {
      // New pattern - insert with confidence 1
      await db.insert(
        tableVendorCategories,
        {
          'vendor_signature': vendorSignature,
          'category_id': categoryId,
          'confidence_score': 1,
          'last_updated': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      AppLogger.logInfo(
          'AI: New pattern "$vendorSignature" -> "$categoryName" (confidence: 1)');
    }
  }

  /// Get all vendor patterns for a specific vendor (for settings UI)
  Future<Map<String, dynamic>?> getVendorPattern(String vendorSignature) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT vc.*, c.name as category_name
      FROM $tableVendorCategories vc
      JOIN $tableCategories c ON vc.category_id = c.id
      WHERE vc.vendor_signature = ?
    ''', [vendorSignature]);

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Reset AI pattern for a specific vendor (user correction in settings)
  Future<void> resetVendorPattern(String vendorSignature) async {
    final db = await database;
    await db.delete(
      tableVendorCategories,
      where: 'vendor_signature = ?',
      whereArgs: [vendorSignature],
    );
    AppLogger.logInfo('AI: Reset pattern for "$vendorSignature"');
  }

  /// Reset rejection count when user manually moves to a new category
  /// This allows the AI to re-learn with positive reinforcement
  Future<void> resetRejectionCount(
      String vendorSignature, String categoryName) async {
    final db = await database;

    // Get category ID
    final categoryResult = await db.query(
      tableCategories,
      where: 'name = ?',
      whereArgs: [categoryName],
      limit: 1,
    );

    if (categoryResult.isEmpty) return;
    final categoryId = categoryResult.first['id'] as int;

    // Update rejection count to 0 for this vendor->category pattern
    await db.rawUpdate('''
      UPDATE $tableVendorCategories
      SET rejection_count = 0,
          last_updated = ?
      WHERE vendor_signature = ? AND category_id = ?
    ''', [DateTime.now().toIso8601String(), vendorSignature, categoryId]);

    AppLogger.logInfo(
      'AI: Reset rejection count for "$vendorSignature" -> "$categoryName"',
    );
  }

  /// Check if AI auto-categorization is active (any pattern with confidence >= 20)
  Future<bool> isAiReady() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM $tableVendorCategories
      WHERE confidence_score >= 20
    ''');

    if (result.isNotEmpty) {
      final count = result.first['count'] as int? ?? 0;
      return count > 0;
    }
    return false;
  }

  /// Get count of active AI patterns (for UI badge)
  Future<int> getAiPatternCount() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM $tableVendorCategories
      WHERE confidence_score >= 20
    ''');

    if (result.isNotEmpty) {
      return result.first['count'] as int? ?? 0;
    }
    return 0;
  }

  /// Apply recency decay - reduce confidence for old patterns (called monthly)
  Future<void> applyRecencyDecay() async {
    final db = await database;
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

    // Reduce confidence by 20% for patterns not updated in 30 days
    await db.rawUpdate('''
      UPDATE $tableVendorCategories
      SET confidence_score = MAX(1, CAST(confidence_score * 0.8 AS INTEGER)),
          last_updated = CASE WHEN confidence_score <= 1 THEN last_updated ELSE ? END
      WHERE last_updated < ? AND confidence_score > 1
    ''', [DateTime.now().toIso8601String(), thirtyDaysAgo]);

    AppLogger.logInfo('AI: Applied recency decay to old patterns');
  }
}
