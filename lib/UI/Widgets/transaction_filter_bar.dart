import 'package:flutter/material.dart';

class TransactionFilterBar extends StatefulWidget {
  final Function(String type, String timeframe) onFilterChanged;

  const TransactionFilterBar({super.key, required this.onFilterChanged});

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  String _selectedType = "All"; // All, Income, Expense
  String _selectedTime = "Today"; // Today, Week, Month

  void _updateFilters() {
    widget.onFilterChanged(_selectedType, _selectedTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Row 1: Transaction Type (Income/Expense)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip("All", Icons.list_alt),
                _filterChip("Income", Icons.add_circle_outline),
                _filterChip("Expense", Icons.remove_circle_outline),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: Timeframe (Today/Week/Month)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _timeChip("Today"),
                _timeChip("This Week"),
                _timeChip("This Month"),
                _timeChip("Custom"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, IconData icon) {
    bool isSelected = _selectedType == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : Colors.grey,
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF2ECC71),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
        onSelected: (val) {
          setState(() => _selectedType = label);
          _updateFilters();
        },
      ),
    );
  }

  Widget _timeChip(String label) {
    bool isSelected = _selectedTime == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        backgroundColor: isSelected
            ? const Color(0xFF2C3E50)
            : Colors.grey.shade100,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onPressed: () {
          setState(() => _selectedTime = label);
          _updateFilters();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
