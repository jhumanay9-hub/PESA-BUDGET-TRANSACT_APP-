import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/services/connectivity_service.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper();
  final _connectivityService = ConnectivityService();

  /// THE UNIVERSAL SYNC ENGINE
  /// This version prioritizes local state and handles offline gracefully.
  Future<void> syncLocalToCloud() async {
    // 1. UNIVERSAL CONNECTIVITY CHECK (Using ConnectivityService)
    if (!await _connectivityService.hasInternet()) {
      AppLogger.logWarning(
          'Sync: Device is offline. Data safe in Local Ledger.');
      return;
    }

    // 2. Check network quality for adaptive sync
    final quality = await _connectivityService.getNetworkQuality();
    if (quality == NetworkQuality.poor || quality == NetworkQuality.none) {
      AppLogger.logWarning(
          'Sync: Network quality too poor ($quality). Data safe in Local Ledger.');
      return;
    }

    try {
      // 2. SESSION CHECK
      final session = _supabase.auth.currentSession;
      if (session == null) {
        AppLogger.logWarning('Sync: No active cloud session. Staying Local.');
        return;
      }

      // 3. FETCH UNSYNCED RECORDS
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> unsyncedMaps = await db.query(
        DatabaseHelper.tableTransactions,
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (unsyncedMaps.isEmpty) {
        AppLogger.logInfo('Sync: Local and Cloud are identical.');
        return;
      }

      AppLogger.logInfo(
          'Sync: Pushing ${unsyncedMaps.length} items to Cloud...');

      // 4. PREPARE DATA (Multi-tenant safe)
      final List<Map<String, dynamic>> uploadData = unsyncedMaps.map((map) {
        var cleanMap = Map<String, dynamic>.from(map);
        cleanMap.remove('is_synced');
        cleanMap['user_id'] = session.user.id;
        return cleanMap;
      }).toList();

      // 5. PERFORM UPSERT (Network intensive part)
      // We use a timeout to ensure the app doesn't wait forever on poor 3G/EDGE.
      await _supabase
          .from('transactions')
          .upsert(uploadData, onConflict: 'id')
          .timeout(const Duration(seconds: 15));

      // 6. BATCH UPDATE LOCAL DB (Only if Upsert succeeded)
      final batch = db.batch();
      for (var record in unsyncedMaps) {
        batch.update(
          DatabaseHelper.tableTransactions,
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      }
      await batch.commit(noResult: true);

      AppLogger.logSuccess('Sync: Cloud updated successfully.');
    } on SocketException {
      AppLogger.logWarning('Sync: Network reachability lost during upload.');
      // Clear connectivity cache to force fresh check
      _connectivityService.clearCache();
    } on HttpException {
      AppLogger.logError('Sync: Supabase service unreachable.', '');
    } catch (e) {
      AppLogger.logError('Sync: Unexpected cloud error.', e);
    }
  }

  /// RESILIENT CHANGE LISTENER
  /// Only subscribes if a session exists to prevent unnecessary background errors.
  void subscribeToChanges() {
    if (_supabase.auth.currentSession == null) return;

    try {
      _supabase.from('transactions').stream(primaryKey: ['id']).listen(
        (data) {
          AppLogger.logInfo(
              'Sync: Remote update received (${data.length} items)');
          // Future: Logic to pull remote updates into local SQLite
        },
        onError: (error) =>
            AppLogger.logError('Sync: Stream error ignored.', error),
      );
    } catch (e) {
      AppLogger.logError('Sync: Could not initialize stream.', e);
    }
  }
}
