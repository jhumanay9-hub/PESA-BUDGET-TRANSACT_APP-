import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'dart:async';

class DatabaseFailure {
  final String message;
  final dynamic originalError;
  DatabaseFailure(this.message, [this.originalError]);
  @override
  String toString() => 'DatabaseFailure: $message ($originalError)';
}

class DatabaseService {
  static Database? _database;
  static Completer<Database>? _openCompleter;

  /// Exposes the raw database instance for health checks (does NOT open the DB).
  static Database? get database => _database;

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    
    // If an open request is already in progress, wait for it
    if (_openCompleter != null) return _openCompleter!.future;

    _openCompleter = Completer<Database>();
    try {
      final dbPath = path.join(await getDatabasesPath(), 'pesa_budget_v3.db');
      _database = await openDatabase(
        dbPath,
        version: 3,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, smsId TEXT UNIQUE, body TEXT, amount REAL, merchant TEXT, date TEXT, category TEXT, isExpense INTEGER DEFAULT 1)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, color INTEGER, icon TEXT)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS app_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, model TEXT, timestamp TEXT, error TEXT)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS heartbeat (id INTEGER PRIMARY KEY, last_run TEXT)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS users (identifier TEXT PRIMARY KEY, name TEXT, phone TEXT, email TEXT, pin TEXT, is_synced_to_cloud INTEGER DEFAULT 0)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, color INTEGER, icon TEXT)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS app_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, model TEXT, timestamp TEXT, error TEXT)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS heartbeat (id INTEGER PRIMARY KEY, last_run TEXT)'
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS users (identifier TEXT PRIMARY KEY, name TEXT, phone TEXT, email TEXT, pin TEXT, is_synced_to_cloud INTEGER DEFAULT 0)'
          );
          
          // Seed default categories
          final defaults = [
            {'name': 'General', 'color': 0xFF607D8B, 'icon': 'account_balance_wallet'},
            {'name': 'Revenue', 'color': 0xFF4CAF50, 'icon': 'add_chart'},
            {'name': 'Food', 'color': 0xFFFF9800, 'icon': 'restaurant'},
            {'name': 'Rent', 'color': 0xFF9C27B0, 'icon': 'home'},
            {'name': 'Transport', 'color': 0xFF2196F3, 'icon': 'directions_car'},
            {'name': 'Bills', 'color': 0xFFF44336, 'icon': 'receipt'},
          ];
          for (final cat in defaults) {
            await db.insert('categories', cat);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('CREATE TABLE IF NOT EXISTS app_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, model TEXT, timestamp TEXT, error TEXT)');
            await db.execute('CREATE TABLE IF NOT EXISTS heartbeat (id INTEGER PRIMARY KEY, last_run TEXT)');
            await db.execute('CREATE TABLE IF NOT EXISTS users (identifier TEXT PRIMARY KEY, name TEXT, phone TEXT, email TEXT, pin TEXT)');
            try {
              await db.execute('ALTER TABLE transactions ADD COLUMN isExpense INTEGER DEFAULT 1');
            } catch (_) {}
            try {
              await db.execute('ALTER TABLE transactions ADD COLUMN smsId TEXT UNIQUE');
            } catch (_) {}
          }
          if (oldVersion < 3) {
            try {
              await db.execute('ALTER TABLE users ADD COLUMN is_synced_to_cloud INTEGER DEFAULT 0');
              await db.execute('UPDATE users SET is_synced_to_cloud = 0 WHERE is_synced_to_cloud IS NULL');
            } catch (_) {}
          }
        },
      );
      _openCompleter!.complete(_database!);
      return _database!;
    } catch (e) {
      _openCompleter!.completeError(e);
      _openCompleter = null;
      rethrow;
    }
  }

  static Future<void> updateHeartbeat() async {
    try {
      final db = await getDatabase();
      final now = DateTime.now().toIso8601String();
      await db.insert('heartbeat', {'id': 1, 'last_run': now}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  static Future<DateTime?> getLastHeartbeat() async {
    try {
      final db = await getDatabase();
      final List<Map<String, dynamic>> maps = await db.query('heartbeat', where: 'id = ?', whereArgs: [1]);
      if (maps.isNotEmpty) {
        return DateTime.parse(maps.first['last_run'] as String);
      }
    } catch (_) {}
    return null;
  }
}
