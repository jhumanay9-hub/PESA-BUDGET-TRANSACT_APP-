import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/services/sms_parser.dart';
import 'package:transaction_app/services/permission_manager.dart';

/// ============================================================================
/// SMS SERVICE - OPTIMIZED FOR HUAWEI Y5
/// ============================================================================
/// Optimizations:
/// 1. No verbose logging in loops (prevents UI freezing)
/// 2. Filtered SMS query (MPESA only)
/// 3. Background isolate for parsing
/// 4. Batch database inserts
/// 5. Stream for UI refresh notifications
/// 6. Sync guard to prevent duplicate concurrent syncs
/// 7. Time-based debouncing (max once per 30 seconds)
/// 8. FIX: Auto-categorization using learned vendor patterns
/// ============================================================================
class SmsService {
  final Telephony _telephony = Telephony.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PermissionManager _permissionManager = PermissionManager();

  // Sync guard to prevent duplicate concurrent syncs
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Stream to notify UI of sync completion
  final _syncController = StreamController<int>.broadcast();
  Stream<int> get syncStream => _syncController.stream;

  /// Optimized inbox sync - runs in background isolate
  Future<void> syncInbox() async {
    // FIX: Prevent duplicate concurrent syncs
    if (_isSyncing) {
      AppLogger.logWarning('SmsService: Sync already in progress - skipping');
      return;
    }

    // FIX: Debounce by time (max once per 30 seconds)
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) <
            const Duration(seconds: 30)) {
      AppLogger.logWarning('SmsService: Sync called too soon - skipping');
      return;
    }

    AppLogger.logInfo('SmsService: Starting optimized sync...');
    final stopwatch = Stopwatch()..start();

    _isSyncing = true;
    try {
      _lastSyncTime = DateTime.now();

      // 1. Check permissions using PermissionManager
      final smsStatus = await _permissionManager.getSmsStatus();
      if (smsStatus != PermissionStatus.granted) {
        AppLogger.logWarning('SmsService: SMS permission not granted');
        return;
      }

      // 2. Fetch ONLY M-PESA messages (filtered at OS level)
      List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals('MPESA'),
      );

      if (messages.isEmpty) {
        AppLogger.logInfo('SmsService: No M-PESA messages found');
        return;
      }

      AppLogger.logInfo('SmsService: Found ${messages.length} M-PESA messages');

      // 3. Prepare lightweight data for isolate transfer
      final List<Map<String, dynamic>> rawData = messages
          .map((m) => {
                'body': m.body ?? '',
                'date': m.date?.toString() ?? '',
                'address': m.address ?? '',
              })
          .toList();

      // 4. Parse in background isolate (prevents UI freezing)
      AppLogger.logInfo('SmsService: Parsing in background isolate...');
      List<ParseResult> parsedResults = await compute(
        _parseSmsInIsolateWithSignatures,
        rawData,
      );

      AppLogger.logInfo(
          'SmsService: Parsed ${parsedResults.length} valid transactions');

      if (parsedResults.isEmpty) {
        return;
      }

      // FIX: Apply auto-categorization before inserting
      AppLogger.logInfo('SmsService: Applying auto-categorization...');
      List<TransactionModel> autoCategorizedTransactions = [];

      for (final result in parsedResults) {
        TransactionModel tx = result.transaction;
        final vendorSignature = result.vendorSignature;

        // Check if we have a learned pattern for this vendor
        final autoCategory =
            await _dbHelper.getAutoCategoryForVendor(vendorSignature);

        if (autoCategory != null) {
          // Apply auto-categorized category
          tx = tx.copyWith(
            category: autoCategory,
            isAutoCategorized: true,
          );
          AppLogger.logData(
              'AI: Auto-categorized "$vendorSignature" -> "$autoCategory"');
        }

        autoCategorizedTransactions.add(tx);
      }

      // 5. Batch insert (single transaction, not one-by-one)
      AppLogger.logInfo('SmsService: Batch inserting to database...');
      await _dbHelper.insertTransactions(autoCategorizedTransactions);

      // 6. Get final count and notify UI
      final count = await _dbHelper.getRowCount();
      stopwatch.stop();

      AppLogger.logSuccess(
        'SmsService: Sync complete in ${stopwatch.elapsedMilliseconds}ms. Total: $count rows',
      );

      // 7. Notify UI to refresh
      _syncController.add(count);
    } catch (e) {
      AppLogger.logError('SmsService: Sync failed', e);
      stopwatch.stop();
    } finally {
      _isSyncing = false;
    }
  }

  /// Real-time listener for incoming M-PESA messages
  void startListening() {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        // Filter: Only process M-PESA messages
        if (message.address != 'MPESA') {
          return;
        }

        AppLogger.logInfo('SmsService: Real-time M-PESA detected');

        try {
          // Parse single message
          final result = SmsParser.parseSingle(message);
          if (result != null) {
            // FIX: Apply auto-categorization for real-time transactions
            TransactionModel tx = result.transaction;
            final vendorSignature = result.vendorSignature;

            // Check if we have a learned pattern for this vendor
            final autoCategory =
                await _dbHelper.getAutoCategoryForVendor(vendorSignature);

            if (autoCategory != null) {
              tx = tx.copyWith(
                category: autoCategory,
                isAutoCategorized: true,
              );
              AppLogger.logData(
                  'AI: Auto-categorized "$vendorSignature" -> "$autoCategory"');
            }

            // Insert immediately (single transaction is fine for real-time)
            await _dbHelper.insertTransactions([tx]);
            AppLogger.logSuccess('SmsService: Real-time transaction saved');

            // Notify UI
            _syncController.add(await _dbHelper.getRowCount());
          }
        } catch (e) {
          AppLogger.logError('SmsService: Real-time parse failed', e);
        }
      },
      listenInBackground: true,
    );
  }

  /// Dispose stream
  void dispose() {
    _syncController.close();
  }
}

/// Top-level function for compute() isolate
/// Must be top-level (not a class method) to work with isolates
@pragma('vm:entry-point')
List<TransactionModel> _parseSmsInIsolate(List<Map<String, dynamic>> messages) {
  return SmsParser.parseSmsBatch(messages);
}

/// FIX: New isolate entry point that returns ParseResult with vendor signatures
@pragma('vm:entry-point')
List<ParseResult> _parseSmsInIsolateWithSignatures(
    List<Map<String, dynamic>> messages) {
  return SmsParser.parseSmsBatchWithSignatures(messages);
}
