import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'profile_page.dart';
import 'settings_page.dart';
import 'transaction_history_page.dart';

// Top-level dummy to fix the assertion error
@pragma('vm:entry-point')
void dummyBackgroundHandler(SmsMessage message) {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
      const MaterialApp(debugShowCheckedModeBanner: false, home: LoginPage()));
}

// --- DATABASE HELPER ---
class DbHelper {
  static Future<Database> getDatabase() async {
    return openDatabase(
      path.join(await getDatabasesPath(), 'pesa_budget_v3.db'),
      onCreate: (db, version) async {
        // Create transactions table
        await db.execute(
            "CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, smsId TEXT UNIQUE, body TEXT, merchant TEXT, amount REAL, category TEXT, date TEXT)");
        // Create categories table
        await db.execute(
            "CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, color INTEGER, icon TEXT)");
        // Seed categories
        await _seedCategories(db);
      },
      version: 1,
    );
  }

  static Future<void> _seedCategories(Database db) async {
    // Check if categories table is empty
    final result = await db.query('categories');
    if (result.isEmpty) {
      // Insert default categories with colors (as integers)
      final categories = [
        {'name': 'Revenue', 'color': 0xFF4CAF50, 'icon': 'add_chart'}, // Green
        {'name': 'Food', 'color': 0xFFFF9800, 'icon': 'restaurant'}, // Orange
        {'name': 'Rent', 'color': 0xFF2196F3, 'icon': 'home'}, // Blue
        {
          'name': 'Transport',
          'color': 0xFF9C27B0,
          'icon': 'directions_car'
        }, // Purple
        {'name': 'Bills', 'color': 0xFFF44336, 'icon': 'receipt'}, // Red
      ];

      for (final category in categories) {
        await db.insert('categories', category);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await getDatabase();
    return await db.query('categories', orderBy: 'id ASC');
  }
}

// --- SHARED UI COMPONENTS ---
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: Colors.grey[200],
        child: const Text("Pesa Budget v1.0 • Secure",
            textAlign: TextAlign.center, style: TextStyle(fontSize: 10)),
      );
}

// --- LOGIN PAGE ---
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)])),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.account_balance_wallet,
                size: 80, color: Colors.white),
            const Text("Pesa Budget",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const Dashboard())),
                child: const Text("LOGIN")),
          ]),
        ),
        bottomNavigationBar: const AppFooter(),
      );
}

// --- DASHBOARD ---
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Map<String, dynamic>> _userCategories = [];
  Map<String, double> totals = {
    "Revenue": 0,
    "Food": 0,
    "Rent": 0,
    "Transport": 0,
    "Bills": 0,
    "Totals": 0
  };

  // Add Account Dialog state (removed unused fields)

  @override
  void initState() {
    super.initState();
    _loadCategories();
    refreshData();
  }

  Future<void> _loadCategories() async {
    final categories = await DbHelper.getCategories();
    setState(() {
      _userCategories = categories;
    });
  }

  // Helper functions to get icon data from category name
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'add_chart':
        return Icons.add_chart;
      case 'restaurant':
        return Icons.restaurant;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'receipt':
        return Icons.receipt;
      default:
        return Icons.category;
    }
  }

  Color _getColorData(int colorValue) {
    return Color(colorValue);
  }

  Future<void> refreshData() async {
    final db = await DbHelper.getDatabase();
    // Logic for Revenue (Incoming)
    var rev = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE body LIKE '%received%' OR body LIKE '%deposited%'");
    // Logic for categories using database categories
    for (final category in _userCategories) {
      final catName = category['name'] as String;
      var res = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE category = ?",
          [catName]);
      totals[catName] = (res.first['total'] as num?)?.toDouble() ?? 0.0;
    }
    totals["Revenue"] = (rev.first['total'] as num?)?.toDouble() ?? 0.0;
    totals["Totals"] =
        totals.values.reduce((a, b) => a + b) - totals["Revenue"]!;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text("Accounts"), backgroundColor: Colors.green[800]),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.green),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_balance_wallet,
                        size: 40, color: Colors.white),
                    SizedBox(height: 10),
                    Text("Pesa Budget",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    Text("Menu",
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: const Text("Profile",
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.green),
                title: const Text("Settings",
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.green),
                title: const Text("Transaction History",
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const TransactionHistoryPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.green),
                title: const Text("Download Statement",
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () {
                  Navigator.pop(context);
                  _downloadStatement();
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Legal",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontFamily: 'sans-serif',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.grey),
                title: const Text("Terms of Service",
                    style: TextStyle(fontSize: 14, fontFamily: 'sans-serif')),
                onTap: () {
                  // TODO: Navigate to Terms of Service
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip, color: Colors.grey),
                title: const Text("Privacy Policy",
                    style: TextStyle(fontSize: 14, fontFamily: 'sans-serif')),
                onTap: () {
                  // TODO: Navigate to Privacy Policy
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Logout",
                    style: TextStyle(fontFamily: 'sans-serif')),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        body: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(10),
          children: [
            _card(
                "General",
                Icons.list,
                Colors.black,
                () => Navigator.push(context,
                        MaterialPageRoute(builder: (c) => const GeneralHub()))
                    .then((_) => refreshData())),
             // Generate cards dynamically from database categories
             ..._userCategories.map((category) {
               final catName = category['name'] as String;
               final catColor = _getColorData(category['color'] as int);
               final catIcon = _getIconData(category['icon'] as String);

               return _card(
                 catName,
                 catIcon,
                 catColor,
                 () => Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (c) => CategoryDetailPage(
                       category: catName,
                       categoryColor: catColor,
                       categoryIcon: catIcon,
                     ),
                   ),
                 ),
               );
             }),
          ],
        ),
        bottomNavigationBar: const AppFooter(),
      );

  Widget _card(String title, IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        splashColor: Colors.green.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            color: Colors.white,
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0)),
            color: Colors.transparent,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'sans-serif',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Ksh ${totals[title] ?? 0}",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'sans-serif',
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
            ]),
          ),
        ),
      );

  void _downloadStatement() {
    // For now, just log to console as requested
    debugPrint('Generating PDF...');
    debugPrint('Dashboard totals: $totals');

    // Show user feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF statement...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// --- CATEGORY DETAIL PAGE ---
class CategoryDetailPage extends StatefulWidget {
  final String category;
  final Color categoryColor;
  final IconData categoryIcon;

  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  List<Map<String, dynamic>> items = [];
  double totalAmount = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCategoryData();
  }

  Future<void> loadCategoryData() async {
    setState(() => isLoading = true);

    final db = await DbHelper.getDatabase();
    items = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [widget.category],
      orderBy: 'id DESC',
    );

    totalAmount = items.fold<double>(
        0.0, (sum, item) => sum + (item['amount'] as double? ?? 0.0));

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text("${widget.category} Transactions"),
          backgroundColor: widget.categoryColor,
        ),
        body: Column(
          children: [
            // Sticky Totals Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: widget.categoryColor.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(widget.categoryIcon,
                          color: widget.categoryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        widget.category,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.categoryColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Ksh ${totalAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.categoryColor,
                    ),
                  ),
                ],
              ),
            ),
            // List of transactions
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.categoryIcon,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ${widget.category} transactions yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) => Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  width: 0.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              color: Colors.white,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0)),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: widget.categoryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  widget.categoryIcon,
                                  color: widget.categoryColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                "Ksh ${items[index]['amount'].toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'sans-serif',
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                items[index]['body'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: const AppFooter(),
      );
}

// --- GENERAL HUB (THE SORTER) ---
class GeneralHub extends StatefulWidget {
  const GeneralHub({super.key});
  @override
  State<GeneralHub> createState() => _GeneralHubState();
}

class _GeneralHubState extends State<GeneralHub> {
  List<Map<String, dynamic>> items = [];
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final telephony = Telephony.instance;
    await telephony.requestPhoneAndSmsPermissions;
    List<SmsMessage> messages = await telephony.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS).equals("MPESA"));

    final db = await DbHelper.getDatabase();
    for (var m in messages) {
      RegExp reg = RegExp(r"Ksh([0-9,]+\.[0-9]{2})");
      double amt = double.tryParse(
              reg.firstMatch(m.body!)?.group(1)?.replaceAll(',', '') ?? "0") ??
          0;
      await db.insert(
          'transactions',
          {
            'smsId': m.date.toString(),
            'body': m.body,
            'amount': amt,
            'category': 'Unclassified'
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    items = await db.query('transactions', orderBy: 'id DESC');
    setState(() {});
  }

  Future<void> updateCat(int id, String cat) async {
    final db = await DbHelper.getDatabase();
    await db.update('transactions', {'category': cat},
        where: 'id = ?', whereArgs: [id]);
    setState(() {
      selectedCategoryId = id.toString();
    });
    await load();
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Food':
        return Colors.red;
      case 'Rent':
        return Colors.blue;
      case 'Transport':
        return Colors.purple;
      case 'Bills':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text("General Transactions"),
            backgroundColor: Colors.black87),
        body: ListView.builder(
          itemCount: items.length,
          itemBuilder: (c, i) => Card(
            child: ListTile(
              title: Row(
                children: [
                  Text("Ksh ${items[i]['amount']}"),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(items[i]['category']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      items[i]['category'] ?? 'Unclassified',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items[i]['body'],
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      children:
                          ["Rent", "Food", "Transport", "Bills"].map((cat) {
                        final isSelected = items[i]['category'] == cat;
                        return ActionChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check,
                                    size: 12, color: Colors.white),
                                const SizedBox(width: 2),
                              ],
                              Text(cat,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white)),
                            ],
                          ),
                          backgroundColor: _getCategoryColor(cat),
                          onPressed: () {
                            setState(() {
                              selectedCategoryId = items[i]['id'].toString();
                            });
                            updateCat(items[i]['id'], cat);
                          },
                        );
                      }).toList(),
                    ),
                  ]),
            ),
          ),
        ),
        bottomNavigationBar: const AppFooter(),
      );
}
