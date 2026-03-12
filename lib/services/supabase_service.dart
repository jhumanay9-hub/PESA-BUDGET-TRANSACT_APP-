import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'db_helper.dart';
import 'network_service.dart';
import 'logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base class for all Supabase-related services.
/// Provides common access to the client, connectivity checks, and logging.
abstract class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  /// Logs a message to the developer console.
  void log(String message) {
    developer.log('[SupabaseService] $message', name: 'service.supabase');
  }

  /// Ensures an active internet connection before performing cloud operations.
  Future<bool> ensureConnection() async {
    final results = await NetworkService().checkConnectivity();
    final isOnline = NetworkService().isOnline(results);
    if (!isOnline) {
      log('Connectivity Check: OFFLINE');
      return false;
    }
    return true;
  }
}


class SupabaseSyncService extends SupabaseService {
  /// Queries local DB tables and syncs them to Supabase.
  /// Uses compute() to offload JSON/Network work to a background isolate.
  Future<void> syncToCloud() async {
    try {
      // Check network connectivity
      final connectivityResults = await NetworkService().checkConnectivity();
      final isOnline = NetworkService().isOnline(connectivityResults);
      if (!isOnline) {
        log('SupabaseSyncService: Offline, sync aborted.');
        return;
      }

      // Attempt to promote any offline-registered local accounts to cloud first
      await _promoteOfflineUserIfNeeded();

      // Check sync method preference
      final prefs = await SharedPreferences.getInstance();
      final syncMethod = prefs.getString('sync_method') ?? 'mobile';
      if (syncMethod == 'wifi' && !connectivityResults.contains(ConnectivityResult.wifi)) {
        log('SupabaseSyncService: WiFi-only mode and no WiFi connection, sync aborted.');
        return;
      }

      final db = await DbHelper.getDatabase();
      final transactions = await db.query('transactions');

      if (transactions.isEmpty) {
        log('SupabaseSyncService: No transactions to sync.');
        return;
      }

      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        log('SupabaseSyncService: No authenticated user found. Sync aborted.');
        return;
      }

      await compute(_performSupabaseSync, {
        'transactions': transactions,
        'userId': userId,
      });
    } catch (e, st) {
      Logger.logError('SupabaseSyncService.syncToCloud error: $e', st);
    }
  }

  /// Promotes a locally-registered offline user to Supabase when internet becomes available.
  Future<void> _promoteOfflineUserIfNeeded() async {
    try {
      final db = await DbHelper.getDatabase();
      final offlineUsers = await db.query(
        'users',
        where: 'is_synced_to_cloud = 0',
        limit: 1,
      );
      if (offlineUsers.isEmpty) {
        return;
      }
      final user = offlineUsers.first;
      final identifier = user['identifier'] as String;
      const storage = FlutterSecureStorage();
      final password = await storage.read(key: 'user_password');
      if (password == null || password.isEmpty) {
        log('Promotion skipped: No password stored for offline user');
        return;
      }
      // Attempt cloud sign up
      try {
        final response = await AuthService().signUp(identifier, password);
        if (response.user != null) {
          // Mark user as synced
          await db.update(
            'users',
            {'is_synced_to_cloud': 1},
            where: 'identifier = ?',
            whereArgs: [identifier],
          );
          log('Offline user promoted to cloud: $identifier');
          // Update prefs to indicate cloud login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
        } else {
          log('Offline user promotion failed: null user response');
        }
      } on AuthException catch (e) {
        // If user already exists in Supabase, mark as synced
        if (e.message.toLowerCase().contains('already') || e.code == 'already_exists') {
          await db.update(
            'users',
            {'is_synced_to_cloud': 1},
            where: 'identifier = ?',
            whereArgs: [identifier],
          );
          log('User already exists in cloud, marked as synced: $identifier');
        } else {
          rethrow;
        }
      }
    } catch (e, st) {
      Logger.logError('Offline user promotion error: $e', st);
    }
  }
}

/// Top-level function executed inside the background isolate.
Future<void> _performSupabaseSync(Map<String, dynamic> data) async {
  try {
    final List<Map<String, dynamic>> rawTransactions = List<Map<String, dynamic>>.from(data['transactions']);
    final String userId = data['userId'];
    final supabase = Supabase.instance.client;

    // Prepare transactions with user_id
    final transactionsToUpsert = rawTransactions.map((tx) {
      final newTx = Map<String, dynamic>.from(tx);
      newTx['user_id'] = userId;
      return newTx;
    }).toList();

    // Perform Upsert
    await supabase
        .from('transactions')
        .upsert(transactionsToUpsert);

    debugPrint('SupabaseSyncService: Successfully synced ${transactionsToUpsert.length} transactions.');
  } catch (e) {
    debugPrint('SupabaseSyncService._performSupabaseSync error: $e');
  }
}
