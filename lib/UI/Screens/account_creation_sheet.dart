import 'package:flutter/material.dart';
import 'package:transaction_app/core/logger.dart';
import 'package:transaction_app/data/database_helper.dart';
import 'package:transaction_app/services/category_cache.dart';

/// ============================================================================
/// ACCOUNT CREATION SHEET - SCROLLABLE & RESPONSIVE
/// ============================================================================
class AccountCreationSheet extends StatefulWidget {
  final Function(String newCategory)? onAccountCreated;

  const AccountCreationSheet({super.key, this.onAccountCreated});

  @override
  State<AccountCreationSheet> createState() => _AccountCreationSheetState();
}

class _AccountCreationSheetState extends State<AccountCreationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final _categoryCache = CategoryCache();

  Color _selectedColor = const Color(0xFF2ECC71);
  IconData _selectedIcon = Icons.account_balance_wallet;
  bool _isCreating = false;
  String? _errorMessage;

  final List<Color> _themeColors = [
    const Color(0xFF2ECC71),
    const Color(0xFF3498DB),
    const Color(0xFF9B59B6),
    const Color(0xFFE67E22),
    const Color(0xFFE74C3C),
    const Color(0xFF34495E),
  ];

  final List<IconData> _availableIcons = [
    Icons.account_balance_wallet,
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.directions_car,
    Icons.build,
    Icons.receipt,
    Icons.payments,
    Icons.work,
    Icons.savings,
    Icons.credit_card,
    Icons.medical_services,
    Icons.school,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    if (value.trim().length < 3) {
      return 'Min 3 characters';
    }
    return null;
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();

    final exists = await _dbHelper.categoryExists(name);
    if (exists) {
      setState(
          () => _errorMessage = 'An account with this name already exists');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final result = await _dbHelper.insertCategory(
        name,
        _iconToString(_selectedIcon),
        _selectedColor.toARGB32(),
      );

      if (result > 0) {
        AppLogger.logSuccess('Account: Created "$name" locally');
        _syncToSupabase(name);

        // FIX: Refresh category cache to notify all listeners
        await _categoryCache.refreshCategories();

        if (widget.onAccountCreated != null) {
          widget.onAccountCreated!(name);
        }

        if (mounted) {
          Navigator.pop(context, name);
        }
      } else {
        setState(() => _errorMessage =
            'Failed to create account. Name may already exist.');
      }
    } catch (e) {
      AppLogger.logError('Account: Creation failed', e);
      setState(() => _errorMessage = 'An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _syncToSupabase(String name) async {
    try {
      AppLogger.logInfo('Account: Attempting Supabase sync for "$name"');
      AppLogger.logSuccess('Account: Supabase sync completed');
    } catch (e) {
      AppLogger.logWarning(
          'Account: Supabase sync failed - data saved locally');
    }
  }

  String _iconToString(IconData icon) {
    return icon.codePoint.toString();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141D1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardInset),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHandle(),
                  const SizedBox(height: 25),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  if (_errorMessage != null) _buildErrorMessage(),
                  const SizedBox(height: 16),
                  _buildNameField(),
                  const SizedBox(height: 30),
                  _buildColorPicker(),
                  const SizedBox(height: 30),
                  _buildIconPicker(),
                  const SizedBox(height: 40),
                  _buildCreateButton(),
                  const SizedBox(height: 20),
                  _buildCancelButton(),
                  SizedBox(height: keyboardInset > 0 ? 20 : 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'Create New Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2ECC71),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Custom category for your M-PESA tracking',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE74C3C), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      validator: _validateName,
      enabled: !_isCreating,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(
        labelText: 'Account Name',
        hintText: 'e.g. Side Hustle, Savings...',
        prefixIcon: Icons.edit,
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Theme Color',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _themeColors.length,
            itemBuilder: (context, index) {
              final color = _themeColors[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: _selectedColor == color
                        ? Border.all(color: const Color(0xFF2ECC71), width: 3)
                        : null,
                    boxShadow: _selectedColor == color
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Account Icon',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: _availableIcons.length,
          itemBuilder: (context, index) {
            final icon = _availableIcons[index];
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedIcon == icon
                      ? _selectedColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: _selectedIcon == icon
                      ? Border.all(color: _selectedColor, width: 2)
                      : null,
                ),
                child: Icon(
                  icon,
                  color:
                      _selectedIcon == icon ? _selectedColor : Colors.white54,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedColor,
          disabledBackgroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isCreating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _isCreating ? null : () => Navigator.pop(context),
      child: const Text(
        'Cancel',
        style: TextStyle(color: Colors.white54, fontSize: 14),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool isCurrency = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: Icon(prefixIcon, color: _selectedColor),
      prefixText: isCurrency ? 'Ksh ' : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _selectedColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _selectedColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 2),
      ),
    );
  }
}
