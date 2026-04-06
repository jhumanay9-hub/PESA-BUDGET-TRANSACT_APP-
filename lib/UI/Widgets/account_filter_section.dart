import 'package:flutter/material.dart';
import 'package:transaction_app/ui/utils/ui_utils.dart';

/// ============================================================================
/// ACCOUNT FILTER SECTION
/// ============================================================================
/// Reusable filter bar for account transaction lists.
/// Includes: Min/Max amount filters, Date picker, and Clear filters button.
/// ============================================================================
class AccountFilterSection extends StatelessWidget {
  final String? minAmount;
  final String? maxAmount;
  final DateTime? selectedDate;
  final bool showTypeToggle;
  final String transactionType;
  final ValueChanged<String?> onMinAmountChanged;
  final ValueChanged<String?> onMaxAmountChanged;
  final ValueChanged<DateTime?> onDateSelected;
  final ValueChanged<String>? onTransactionTypeChanged;
  final VoidCallback onClearFilters;

  const AccountFilterSection({
    super.key,
    this.minAmount,
    this.maxAmount,
    this.selectedDate,
    this.showTypeToggle = false,
    this.transactionType = 'All',
    required this.onMinAmountChanged,
    required this.onMaxAmountChanged,
    required this.onDateSelected,
    this.onTransactionTypeChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(context),
        if (showTypeToggle) _buildTransactionTypeToggle(context),
        const Divider(color: UIUtils.incomeGreen, height: 1),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Min Amount
              Expanded(
                child: TextField(
                  onChanged: onMinAmountChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: UIUtils.getInputDecoration(
                    hintText: 'Min',
                    isCurrency: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),

              // Max Amount
              Expanded(
                child: TextField(
                  onChanged: onMaxAmountChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: UIUtils.getInputDecoration(
                    hintText: 'Max',
                    isCurrency: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),

              // Date Picker
              Expanded(
                child: _buildDatePicker(context),
              ),
            ],
          ),

          // Clear Filters Button
          if (minAmount != null || maxAmount != null || selectedDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClearFilters,
                child: const Text(
                  'Clear Filters',
                  style: TextStyle(color: UIUtils.incomeGreen, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: UIUtils.incomeGreen,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: UIUtils.incomeGreen, size: 14),
            const SizedBox(width: 4),
            Text(
              selectedDate != null
                  ? '${selectedDate!.day}/${selectedDate!.month}'
                  : 'Date',
              style: TextStyle(
                color:
                    selectedDate != null ? UIUtils.incomeGreen : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Type:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          ...['All', 'Income', 'Expense'].map((type) {
            final isActive = type == transactionType;
            return GestureDetector(
              onTap: () => onTransactionTypeChanged?.call(type),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: UIUtils.getFilterChipDecoration(isActive: isActive),
                child: Text(
                  type,
                  style: TextStyle(
                    color: isActive ? UIUtils.incomeGreen : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
