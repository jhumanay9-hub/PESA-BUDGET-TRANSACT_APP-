import 'package:flutter/material.dart';
import 'package:transaction_app/models/transaction_model.dart';

/// ============================================================================
/// UI UTILITIES - Centralized UI Helpers
/// ============================================================================
/// Provides consistent UI utilities across the app:
/// - Category icon mapping
/// - Color helpers
/// - Common styling utilities
/// - Date formatting
/// ============================================================================
class UIUtils {
  // ============================================================================
  // COLOR CONSTANTS
  // ============================================================================
  static const Color incomeGreen = Color(0xFF2ECC71);
  static const Color expenseRed = Color(0xFFE74C3C);
  static const Color cardBackground = Color(0xFF141D1A);
  static const Color appBackground = Color(0xFF0A0E0C);

  /// Get the appropriate icon for a transaction category
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return Icons.account_balance_wallet_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'bills':
        return Icons.receipt_long_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'salary':
        return Icons.work_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  /// Get the color for a transaction type (income/expense)
  static Color getTransactionColor(TransactionType type) {
    return type == TransactionType.income ? incomeGreen : expenseRed;
  }

  /// Get the appropriate icon for transaction type (compact vs detailed view)
  static IconData getTransactionIcon(TransactionType type,
      {bool isCompact = false}) {
    if (isCompact) {
      return type == TransactionType.income ? Icons.add : Icons.remove;
    }
    return type == TransactionType.income ? Icons.north_east : Icons.south_west;
  }

  /// Get month abbreviation (e.g., 1 -> 'Jan')
  static String getMonthAbbreviation(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  /// Create an emerald-themed container with glow effect
  static BoxDecoration createEmeraldCardDecoration({
    double alpha = 1.0,
    bool withGlow = false,
  }) {
    return BoxDecoration(
      color: cardBackground.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: incomeGreen.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: withGlow
          ? [
              BoxShadow(
                color: incomeGreen.withValues(alpha: 0.15),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ]
          : null,
    );
  }

  /// Create transaction tile decoration based on income/expense
  static BoxDecoration getTransactionDecoration({
    required bool isIncome,
    required bool isCompact,
  }) {
    final accentColor = isIncome ? incomeGreen : expenseRed;
    return BoxDecoration(
      color: isCompact ? Colors.white.withValues(alpha: 0.03) : cardBackground,
      borderRadius: BorderRadius.circular(isCompact ? 12 : 15),
      border: Border.all(
        color: accentColor.withValues(alpha: isCompact ? 0.2 : 0.3),
      ),
    );
  }

  /// Get avatar background color for transaction type
  static Color getAvatarBackgroundColor(TransactionType type,
      {bool isCompact = false}) {
    final accentColor =
        type == TransactionType.income ? incomeGreen : expenseRed;
    return accentColor.withValues(alpha: isCompact ? 0.2 : 0.2);
  }

  /// Get avatar icon color for transaction type
  static Color getAvatarIconColor(TransactionType type) {
    return type == TransactionType.income ? incomeGreen : expenseRed;
  }

  /// Get balance status text color
  static Color getBalanceColor(bool isPositive) {
    return isPositive ? incomeGreen : expenseRed;
  }

  /// Get card decoration with emerald theme
  static BoxDecoration getCardDecoration({
    double borderRadius = 20,
    double borderAlpha = 0.3,
    double shadowAlpha = 0.15,
    double borderWidth = 1.5,
    double blurRadius = 15,
    double spreadRadius = 2,
  }) {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: incomeGreen.withValues(alpha: borderAlpha),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: incomeGreen.withValues(alpha: shadowAlpha),
          blurRadius: blurRadius,
          spreadRadius: spreadRadius,
        ),
      ],
    );
  }

  /// Get simple card decoration (no shadow)
  static BoxDecoration getSimpleCardDecoration({
    double borderRadius = 20,
    double borderAlpha = 0.3,
    double borderWidth = 1.5,
  }) {
    return BoxDecoration(
      color: cardBackground,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: incomeGreen.withValues(alpha: borderAlpha),
        width: borderWidth,
      ),
    );
  }

  /// Get footer decoration for cards
  static BoxDecoration getFooterDecoration() {
    return const BoxDecoration(
      color: incomeGreen,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
    );
  }

  /// Get icon container decoration
  static BoxDecoration getIconContainerDecoration({double alpha = 0.1}) {
    return BoxDecoration(
      color: incomeGreen.withValues(alpha: alpha),
      shape: BoxShape.circle,
    );
  }

  /// Get filter chip decoration
  static BoxDecoration getFilterChipDecoration({
    required bool isActive,
    double activeAlpha = 0.2,
    double inactiveAlpha = 0.05,
  }) {
    return BoxDecoration(
      color: isActive
          ? incomeGreen.withValues(alpha: activeAlpha)
          : Colors.white.withValues(alpha: inactiveAlpha),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isActive ? incomeGreen : Colors.white.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  /// Get input field decoration
  static InputDecoration getInputDecoration({
    required String hintText,
    String prefixText = '',
    bool isCurrency = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixText: isCurrency ? 'Ksh ' : prefixText,
      prefixStyle: const TextStyle(color: incomeGreen, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
