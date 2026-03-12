import 'database_service.dart';
import 'db_helper.dart';
import 'auth_service.dart';
import 'supabase_service.dart';
import 'package:sqflite/sqflite.dart';

class TransactionService extends SupabaseService {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  /// Saves a transaction locally and attempts to sync it to Supabase.
  Future<void> saveTransaction(Map<String, dynamic> transaction) async {
    // 1. Save Locally
    final db = await DatabaseService.getDatabase();
    await db.insert(
      'transactions',
      transaction,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    DbHelper.notifyUpdate();

    // 2. Attempt Sync to Cloud
    await syncToCloud(transaction);
  }

  /// Updates a transaction's category locally and in Supabase.
  Future<void> updateCategory(int localId, String smsId, String newCategory) async {
    // 1. Update Locally
    final db = await DatabaseService.getDatabase();
    await db.update(
      'transactions',
      {'category': newCategory},
      where: 'id = ?',
      whereArgs: [localId],
    );
    DbHelper.notifyUpdate();

    // 2. Update in Supabase
    log('Attempting Cloud Update for category: $smsId');
    if (!await ensureConnection()) return;

    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      await client
          .from('transactions')
          .update({'category': newCategory})
          .eq('sms_id', smsId)
          .eq('user_id', user.id);
      log('Cloud Update Success');
    } catch (e) {
      log('Cloud Update Error: $e');
    }
  }

  /// Upserts a single transaction to Supabase.
  Future<void> syncToCloud(Map<String, dynamic> transaction) async {
    log('Attempting Cloud Sync for transaction: ${transaction['smsId']}');
    
    if (!await ensureConnection()) {
      log('Sync Skipped: Offline');
      return;
    }

    final user = AuthService().currentUser;
    if (user == null) {
      log('Sync Skipped: No authenticated user');
      return;
    }

    try {
      final mapping = {
        'sms_id': transaction['smsId'],
        'body': transaction['body'],
        'merchant': transaction['merchant'],
        'amount': transaction['amount'],
        'category': transaction['category'],
        'is_expense': transaction['isExpense'] == 1,
        'date': transaction['date'],
        'user_id': user.id,
      };

      await client.from('transactions').upsert(mapping);
      log('Cloud Sync Success!');
    } catch (e) {
      log('Cloud Sync Error: $e');
    }
  }

  /// Syncs all local transactions that are not yet in the cloud.
  Future<void> syncAllLocalTransactions() async {
    log('Attempting BATCH Cloud Sync');
    if (!await ensureConnection()) return;

    final user = AuthService().currentUser;
    if (user == null) return;

    try {
      final db = await DatabaseService.getDatabase();
      final localTransactions = await db.query('transactions');
      
      log('Preparing to sync ${localTransactions.length} transactions');
      
      final List<Map<String, dynamic>> batch = localTransactions.map((t) => {
        'sms_id': t['smsId'],
        'body': t['body'],
        'merchant': t['merchant'],
        'amount': t['amount'],
        'category': t['category'],
        'is_expense': t['isExpense'] == 1,
        'date': t['date'],
        'user_id': user.id,
      }).toList();

      if (batch.isNotEmpty) {
        await client.from('transactions').upsert(batch);
        log('Batch Sync Success: ${batch.length} items');
      }
    } catch (e) {
      log('Batch Sync Error: $e');
      rethrow;
    }
  }
}
