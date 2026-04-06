import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';

class DownloadStatementPage extends StatefulWidget {
  const DownloadStatementPage({super.key});

  @override
  State<DownloadStatementPage> createState() => _DownloadStatementPageState();
}

class _DownloadStatementPageState extends State<DownloadStatementPage> {
  DateTimeRange? _selectedDateRange;
  bool _isProcessing = false;

  /// Emerald-themed Date Range Picker
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2ECC71), // Mint Primary
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  Future<void> _handleExport(String type) async {
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date range first")),
      );
      return;
    }

    setState(() => _isProcessing = true);
    AppLogger.logInfo(
      "Export: Initiating $type download for ${_selectedDateRange.toString()}",
    );

    try {
      // 1. Fetch filtered data from SQLite
      await DatabaseHelper().getTransactionsByDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );

      // 2. IO Operation (Simulated for now)
      // We will integrate the 'pdf' or 'csv' package logic here later
      await Future.delayed(const Duration(seconds: 2));

      AppLogger.logSuccess("Export: $type generated successfully.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$type Statement saved to Downloads"),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      AppLogger.logError("Export Failure", e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Download Statement")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Generate Report",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choose a timeframe to export your M-PESA transaction records.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),

            // Date Range Selection Box
            GestureDetector(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Color(0xFF2ECC71)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedDateRange == null
                            ? "Select Date Range"
                            : "${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            if (_isProcessing)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
              )
            else ...[
              _exportButton(
                title: "Download PDF",
                subtitle: "Best for printing and sharing",
                icon: Icons.picture_as_pdf,
                onTap: () => _handleExport("PDF"),
              ),
              const SizedBox(height: 16),
              _exportButton(
                title: "Export CSV",
                subtitle: "Best for Excel and accounting",
                icon: Icons.grid_on,
                onTap: () => _handleExport("CSV"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _exportButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF0FDF4),
              child: Icon(icon, color: const Color(0xFF2ECC71)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
