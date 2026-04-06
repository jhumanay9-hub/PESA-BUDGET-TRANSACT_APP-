import 'package:telephony/telephony.dart';
import 'package:transaction_app/models/transaction_model.dart';
import 'package:transaction_app/services/vendor_signature.dart';

/// ============================================================================
/// SMS PARSER - ISOLATE-OPTIMIZED
/// ============================================================================
/// Silent parser: No logging during batch processing to prevent UI freezing.
/// All logging happens at the service level after processing completes.
///
/// FIX 1: Improved vendor name extraction for institutions (Naivas, etc.)
/// FIX 2: Filter out transactions with amount <= 0
/// FIX 3: Return vendor signature for auto-categorization
/// ============================================================================

/// Result class for parsed SMS with vendor signature
class ParseResult {
  final TransactionModel transaction;
  final String vendorSignature;

  ParseResult({required this.transaction, required this.vendorSignature});
}

class SmsParser {
  /// Parse a single M-PESA SMS
  static ParseResult? parseMpesaSms(String body, String smsId) {
    try {
      // 1. Extract Transaction Code (e.g., RCL81HB7Z9) - Keep as String, never parse as int
      final codeRegex = RegExp(r'^([A-Z0-9]{8,})');
      final codeMatch = codeRegex.firstMatch(body);
      final txCode = codeMatch?.group(1) ?? smsId;

      // 2. Extract Amount (e.g., Ksh2,500.00 or Ksh2500)
      // Match digits with optional commas and optional decimal part
      final amountRegex = RegExp(r'Ksh([\d,]+(?:\.\d{1,2})?)');
      final amountMatch = amountRegex.firstMatch(body);
      final rawAmountStr = amountMatch?.group(1)?.replaceAll(',', '') ?? '0';
      // Use tryParse to prevent FormatException
      final double amount = double.tryParse(rawAmountStr) ?? 0.0;

      // FIX 2: Skip transactions with zero or negative amount
      if (amount <= 0) {
        return null;
      }

      // 3. Determine Type (Sent vs Received)
      TransactionType type = TransactionType.expense;
      if (body.contains("received") || body.contains("Give")) {
        type = TransactionType.income;
      }

      // 4. Extract Entity (Who sent it or who did you pay?)
      String entity = "Unknown";
      String? extractedVendor;

      // ========================================================================
      // FULIZA SPECIAL HANDLING
      // ========================================================================
      // Check if this is a Fuliza transaction (debt/loan related)
      final isFuliza = body.toLowerCase().contains('fuliza');

      if (isFuliza) {
        // Set vendor name to "Fuliza" for all Fuliza-related transactions
        entity = "Fuliza";
        extractedVendor = "Fuliza";

        // Determine specific Fuliza transaction type
        if (body.toLowerCase().contains('settled') ||
            body.toLowerCase().contains('repay') ||
            body.toLowerCase().contains('repayment') ||
            body.toLowerCase().contains('paid') ||
            body.toLowerCase().contains('fee') ||
            body.toLowerCase().contains('interest') ||
            body.toLowerCase().contains('penalty')) {
          type = TransactionType.expense; // Debt repayment/fee
        } else if (body.toLowerCase().contains('advanced') ||
            body.toLowerCase().contains('disbursed') ||
            body.toLowerCase().contains('received') ||
            body.toLowerCase().contains('credited')) {
          type = TransactionType.income; // Fuliza advance/loan received
        }
        // Note: Vendor signature will be "fuliza" for AI pattern learning
      } else if (type == TransactionType.income) {
        final fromRegex = RegExp(r'from\s+(.*?)\s+\d{10}');
        extractedVendor = fromRegex.firstMatch(body)?.group(1);
        entity = extractedVendor ?? "M-PESA Deposit";
      } else {
        // Try multiple patterns to extract vendor name
        String? vendor;

        // FIX 1: Pattern 1 - "paid to VENDOR on" (most common for paybill/till)
        // Updated to capture more vendor name formats including lowercase
        final paidToRegex = RegExp(
            r'''paid\s+to\s+([A-Za-z][A-Za-z0-9 &.'-]+?)\s+on''',
            caseSensitive: false);
        vendor = paidToRegex.firstMatch(body)?.group(1);

        // Filter out invalid vendor names (like "Amount", "Ksh", etc.)
        if (vendor != null && _isValidVendorName(vendor)) {
          entity = vendor;
          extractedVendor = vendor;
        } else {
          vendor = null;
        }

        // FIX 1: Pattern 2 - "to VENDOR on" (fallback for send money)
        if (vendor == null) {
          final toRegex = RegExp(
              r'''\s+to\s+([A-Za-z][A-Za-z0-9 &.'-]+?)\s+on''',
              caseSensitive: false);
          vendor = toRegex.firstMatch(body)?.group(1);
          if (vendor != null && _isValidVendorName(vendor)) {
            entity = vendor;
            extractedVendor = vendor;
          } else {
            vendor = null;
          }
        }

        // FIX 1: Pattern 3 - "Completed to VENDOR" (for lipa na mpesa) - moved up for priority
        if (vendor == null) {
          final completedRegex = RegExp(
              r'''Completed\s+to\s+([A-Za-z][A-Za-z0-9 &.'-]+)''',
              caseSensitive: false);
          vendor = completedRegex.firstMatch(body)?.group(1);
          if (vendor != null && _isValidVendorName(vendor)) {
            entity = vendor;
            extractedVendor = vendor;
          } else {
            vendor = null;
          }
        }

        // FIX 1: Pattern 4 - "VENDOR account" (for paybill account reference)
        if (vendor == null) {
          final accountRegex = RegExp(
              r'''([A-Za-z][A-Za-z0-9 &.'-]+?)\s+account''',
              caseSensitive: false);
          vendor = accountRegex.firstMatch(body)?.group(1);
          if (vendor != null && _isValidVendorName(vendor)) {
            entity = vendor;
            extractedVendor = vendor;
          } else {
            vendor = null;
          }
        }

        // FIX 1: Pattern 5 - Extract from "for account" transactions
        if (vendor == null) {
          final forAccountRegex = RegExp(
              r'''for\s+account\s+([A-Za-z][A-Za-z0-9 &.'-]+)''',
              caseSensitive: false);
          vendor = forAccountRegex.firstMatch(body)?.group(1);
          if (vendor != null && _isValidVendorName(vendor)) {
            entity = vendor;
            extractedVendor = vendor;
          } else {
            vendor = null;
          }
        }

        // FIX 1: Pattern 6 - "Buy Goods from VENDOR" or "Buy from VENDOR"
        if (vendor == null) {
          final buyFromRegex = RegExp(
              r'''(?:Buy\s+(?:Goods\s+)?from|from)\s+([A-Za-z][A-Za-z0-9 &.'-]+?)\s+''',
              caseSensitive: false);
          vendor = buyFromRegex.firstMatch(body)?.group(1);
          if (vendor != null && _isValidVendorName(vendor)) {
            entity = vendor;
            extractedVendor = vendor;
          } else {
            vendor = null;
          }
        }

        // FIX 1: Pattern 7 - Look for vendor name after "M-PESA" or "MPESA"
        if (vendor == null) {
          final mpesaVendorRegex = RegExp(
              r'''M-?PESA\s+([A-Za-z][A-Za-z0-9 &.'-]+?)(?:\s+on|\s+for|\s+at|$)''',
              caseSensitive: false);
          vendor = mpesaVendorRegex.firstMatch(body)?.group(1);
          if (vendor != null &&
              _isValidVendorName(vendor) &&
              !vendor.toLowerCase().contains('payment') &&
              !vendor.toLowerCase().contains('transaction')) {
            entity = vendor;
            extractedVendor = vendor;
          } else {
            vendor = null;
          }
        }

        // Fallback: Use M-PESA Payment as default
        if (vendor == null) {
          entity = "M-PESA Payment";
        }
      }

      // FIX 3: Generate normalized vendor signature for auto-categorization
      final vendorSignature =
          VendorSignature.normalize(extractedVendor ?? entity);

      final transaction = TransactionModel(
        id: txCode,
        sender: entity,
        amount: amount,
        type: type,
        date: DateTime.now(),
        category:
            "General", // Default category - will be overridden by auto-categorization
        accountType: "Personal",
        body: body,
      );

      return ParseResult(
        transaction: transaction,
        vendorSignature: vendorSignature,
      );
    } catch (e) {
      // Silent fail in isolate - errors logged at service level
      return null;
    }
  }

  /// Batch parser for compute() isolate - NO LOGGING for performance
  /// Returns list of ParseResult with vendor signatures
  static List<ParseResult> parseSmsBatchWithSignatures(
      List<Map<String, dynamic>> messages) {
    List<ParseResult> parsed = [];
    for (var msg in messages) {
      final body = msg['body'] as String? ?? '';
      final dateStr = msg['date']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final result = parseMpesaSms(body, dateStr);
      if (result != null) {
        parsed.add(result);
      }
    }
    return parsed;
  }

  /// Batch parser for compute() isolate - NO LOGGING for performance
  /// Legacy method - returns just transactions
  static List<TransactionModel> parseSmsBatch(
      List<Map<String, dynamic>> messages) {
    List<TransactionModel> parsed = [];
    for (var msg in messages) {
      final body = msg['body'] as String? ?? '';
      final dateStr = msg['date']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final result = parseMpesaSms(body, dateStr);
      if (result != null) {
        parsed.add(result.transaction);
      }
    }
    return parsed;
  }

  /// Parse a single message (for real-time listener)
  static ParseResult? parseSingle(SmsMessage message) {
    return parseMpesaSms(
      message.body ?? '',
      message.date?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Validate extracted vendor name (filter out false positives)
  /// FIX: More permissive for institution names while filtering generic terms
  static bool _isValidVendorName(String name) {
    final trimmedName = name.trim();

    // List of invalid generic terms (not actual vendor names)
    final invalidNames = [
      'Amount',
      'Ksh',
      'Mpesa',
      'M-PESA',
      'MPESA',
      'Transaction',
      'Completed',
      'Sent',
      'Received',
      'From',
      'To',
      'For',
      'On',
      'At',
      'Payment',
      'M-PESA Payment',
      'Mpesa Payment',
      'Lipa Na Mpesa',
      'Buy Goods',
      'Till Number',
      'Paybill',
      'Account',
    ];

    // Check if name is in invalid list
    if (invalidNames
        .any((invalid) => trimmedName.toLowerCase() == invalid.toLowerCase())) {
      return false;
    }

    // Check if name contains only generic payment terms
    if (trimmedName.toLowerCase().contains('payment') ||
        trimmedName.toLowerCase().contains('transaction')) {
      return false;
    }

    // Check if name is too short (likely not a vendor)
    if (trimmedName.length < 2) {
      return false;
    }

    // Check if name contains only numbers (likely not a vendor)
    if (RegExp(r'^[\d\s]+$').hasMatch(trimmedName)) {
      return false;
    }

    // FIX: Allow mixed case names (institutions like "Naivas", "Kenya Power")
    // Check if it has at least one letter
    if (!RegExp(r'[A-Za-z]').hasMatch(trimmedName)) {
      return false;
    }

    return true;
  }
}
