import 'dart:convert';
import 'package:crypto/crypto.dart';

enum TransactionType { income, expense, transfer, unknown }

class TransactionModel {
  final String id; // M-PESA ID (e.g., RK82IDK92)
  final double amount;
  final String body; // The raw SMS for diagnostic history
  final DateTime date;
  final String sender; // e.g., 'KPLC' or '0722...'
  final TransactionType type;
  final String category; // For the "Pesa Budget" UI sorting
  final String accountType; // For the "Page Flip" (Personal vs Business)
  final bool isSynced; // For Supabase status tracking
  final bool
      isAutoCategorized; // FIX: True if AI auto-categorized this transaction
  final bool
      isAutoMoved; // True if transaction was auto-moved by AI to a category
  final int rejectionCount; // Number of times user rejected this categorization

  TransactionModel({
    required this.id,
    required this.amount,
    required this.body,
    required this.date,
    required this.sender,
    this.type = TransactionType.unknown,
    this.category = 'General',
    this.accountType = 'Personal',
    this.isSynced = false,
    this.isAutoCategorized = false, // FIX: Default to false
    this.isAutoMoved = false,
    this.rejectionCount = 0,
  });

  /// The "Self-Healing" ID Logic
  /// If M-PESA ID is missing, we create a deterministic hash of body + date.
  static String generateUniqueId(String body, DateTime date) {
    final bytes = utf8.encode(body + date.toIso8601String());
    final digest = sha256.convert(bytes);
    return 'HASH_${digest.toString().substring(0, 10)}';
  }

  /// Convert SQLite/Supabase Map to Model
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      body: map['body'] ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      sender: map['sender'] ?? 'Unknown',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.unknown,
      ),
      category: map['category'] ?? 'General',
      accountType: map['account_type'] ?? 'Personal',
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true),
      isAutoCategorized: (map['is_auto_categorized'] == 1 ||
          map['is_auto_categorized'] == true),
      isAutoMoved: (map['is_auto_moved'] == 1 || map['is_auto_moved'] == true),
      rejectionCount: (map['rejection_count'] as int?) ?? 0,
    );
  }

  /// Convert Model to Map for Database/Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'body': body,
      'date': date.toIso8601String(),
      'sender': sender,
      'type': type.name,
      'category': category,
      'account_type': accountType,
      'is_synced': isSynced ? 1 : 0,
      'is_auto_categorized':
          isAutoCategorized ? 1 : 0, // FIX: Include auto-categorization flag
      'is_auto_moved': isAutoMoved ? 1 : 0,
      'rejection_count': rejectionCount,
    };
  }

  /// Create a copy with updated fields (for smooth UI updates)
  TransactionModel copyWith({
    String? id,
    double? amount,
    String? body,
    DateTime? date,
    String? sender,
    TransactionType? type,
    String? category,
    String? accountType,
    bool? isSynced,
    bool? isAutoCategorized,
    bool? isAutoMoved,
    int? rejectionCount,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      body: body ?? this.body,
      date: date ?? this.date,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      category: category ?? this.category,
      accountType: accountType ?? this.accountType,
      isSynced: isSynced ?? this.isSynced,
      isAutoCategorized: isAutoCategorized ?? this.isAutoCategorized,
      isAutoMoved: isAutoMoved ?? this.isAutoMoved,
      rejectionCount: rejectionCount ?? this.rejectionCount,
    );
  }

  /// Check if this transaction is Fuliza-related
  bool get isFuliza =>
      sender.toLowerCase() == 'fuliza' || body.toLowerCase().contains('fuliza');

  /// Check if this is a debt repayment (Fuliza settlement, loan repayment, etc.)
  bool get isDebtRepayment {
    if (isFuliza && type == TransactionType.expense) {
      final lowerBody = body.toLowerCase();
      return lowerBody.contains('settled') ||
          lowerBody.contains('repay') ||
          lowerBody.contains('repayment') ||
          lowerBody.contains('paid') ||
          lowerBody.contains('fee') ||
          lowerBody.contains('interest') ||
          lowerBody.contains('penalty');
    }
    return false;
  }

  /// Check if this is a debt advance (Fuliza advance, loan disbursement, etc.)
  bool get isDebtAdvance {
    if (isFuliza && type == TransactionType.income) {
      final lowerBody = body.toLowerCase();
      return lowerBody.contains('advanced') ||
          lowerBody.contains('disbursed') ||
          lowerBody.contains('received') ||
          lowerBody.contains('credited');
    }
    return false;
  }

  /// Get recommended category for debt transactions
  String get recommendedDebtCategory => 'Debts';

  /// Get transaction subtype for financial categorization
  String get transactionSubtype {
    if (isDebtRepayment) return 'DEBT_REPAYMENT';
    if (isDebtAdvance) return 'DEBT_ADVANCE';
    if (isFuliza) return 'FULIZA';
    return 'STANDARD';
  }
}
