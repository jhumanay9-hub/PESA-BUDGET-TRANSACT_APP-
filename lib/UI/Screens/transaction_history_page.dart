import 'package:flutter/material.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/models/transaction_model.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final _dbHelper = DatabaseHelper();
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // FIX: Store future to prevent re-fetching on every build
  // Without this, FutureBuilder would query the database on every setState()
  late final Future<List<TransactionModel>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    // Initialize future once - this prevents redundant database queries
    _transactionsFuture = _dbHelper.getAllTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction History"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: "Search name, amount, or code...",
                prefixIcon: Icon(Icons.search, color: Color(0xFF2ECC71)),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future:
            _transactionsFuture, // FIX: Use stored future instead of calling DB directly
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
            );
          }

          final allData = snapshot.data ?? [];
          final filteredData = allData.where((tx) {
            final query = _searchQuery.toLowerCase();
            return tx.sender.toLowerCase().contains(query) ||
                tx.body.toLowerCase().contains(query) ||
                tx.amount.toString().contains(query);
          }).toList();

          if (filteredData.isEmpty) {
            return _buildEmptySearch();
          }

          return ListView.builder(
            itemCount: filteredData.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemBuilder: (context, index) {
              final tx = filteredData[index];
              return _buildHistoryCard(tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(TransactionModel tx) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: tx.type == TransactionType.income
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            tx.type == TransactionType.income
                ? Icons.north_east
                : Icons.south_west,
            color:
                tx.type == TransactionType.income ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          tx.sender,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${tx.date.day}/${tx.date.month} • ${tx.category}"),
        trailing: Text(
          "Ksh ${tx.amount}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF2C3E50),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No results for '$_searchQuery'",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
