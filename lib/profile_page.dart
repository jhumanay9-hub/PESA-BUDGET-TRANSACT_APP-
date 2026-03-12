import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import 'ui/footer.dart';
import 'services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isBusinessProfile = false;
  String _name = '';
  String _email = '';
  String _id = '';
  String _address = '';
  String _phone = '';
  String _businessName = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = AuthService().currentUser;
      final metadata = user?.userMetadata ?? {};

      if (!mounted) return;
      setState(() {
        // Priority: Supabase Metadata > SharedPreferences > Empty
        _name = metadata['full_name']?.toString() ?? prefs.getString('name') ?? '';
        _email = user?.email ?? prefs.getString('email') ?? '';
        _businessName = metadata['business_name']?.toString() ?? prefs.getString('businessName') ?? '';
        _id = metadata['id_number']?.toString() ?? prefs.getString('id') ?? '';
        _address = metadata['address']?.toString() ?? prefs.getString('address') ?? '';
        _phone = metadata['phone']?.toString() ?? prefs.getString('phone') ?? '';
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _showEditProfileDialog() async {
    _nameController.text = _name;
    _idController.text = _id;
    _phoneController.text = _phone;
    _emailController.text = _email;
    _businessNameController.text = _businessName;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = _nameController.text.trim();
                final newId = _idController.text.trim();
                final newPhone = _phoneController.text.trim();
                final newEmail = _emailController.text.trim();
                final newBusiness = _businessNameController.text.trim();

                // 1. Local Save
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('name', newName);
                await prefs.setString('id', newId);
                await prefs.setString('phone', newPhone);
                await prefs.setString('email', newEmail);
                await prefs.setString('businessName', newBusiness);

                // 2. Cloud Save (Supabase Metadata)
                try {
                  final client = AuthService().client;
                  await client.auth.updateUser(
                    UserAttributes(
                      data: {
                        'full_name': newName,
                        'id_number': newId,
                        'phone': newPhone,
                        'business_name': newBusiness,
                        'address': _address, // Preserve address
                      },
                    ),
                  );
                } catch (e) {
                  debugPrint('Supabase metadata update failed: $e');
                }

                if (!mounted) return;
                setState(() {
                  _name = newName;
                  _id = newId;
                  _phone = newPhone;
                  _email = newEmail;
                  _businessName = newBusiness;
                });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated and synced')));
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF0D1B2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header with Verified Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border:
                    Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // Avatar and Verified Badge
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF00FFCC).withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF00FFCC),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                          color: const Color(0xFF00FFCC),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Color(0xFF0D1B2A),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name and Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _name.isNotEmpty ? _name : 'No name set',
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'sans-serif',
                            color: _name.isNotEmpty ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Verified",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Business Profile Toggle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border:
                    Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Profile Type",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Business Profile",
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ),
                      Switch(
                        value: isBusinessProfile,
                        onChanged: (value) {
                          setState(() {
                            isBusinessProfile = value;
                          });
                        },
                        activeThumbColor: const Color(0xFF00FFCC),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contact Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border:
                    Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBusinessProfile ? "Business Details" : "Personal Details",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    icon: Icons.person,
                    label: isBusinessProfile ? "Business Name" : "Legal Name",
                    value: isBusinessProfile ? _businessName : _name,
                    placeholder: isBusinessProfile ? "Add business name" : "Add legal name",
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.phone,
                    label: "Phone",
                    value: _phone,
                    placeholder: "Add phone number",
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.location_on,
                    label: "Address",
                    value: _address,
                    placeholder: "Add address",
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.email,
                    label: "Email",
                    value: _email,
                    placeholder: "Add email",
                  ),
                  if (isBusinessProfile) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.business,
                      label: "Business ID",
                      value: _id,
                      placeholder: "Add business ID",
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Additional Actions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                border:
                    Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: Column(
                children: [
                  _buildActionRow(
                    icon: Icons.edit,
                    title: "Edit Profile",
                    onTap: () {
                      _showEditProfileDialog();
                    },
                  ),
                  const Divider(height: 32),
                  _buildActionRow(
                    icon: Icons.security,
                    title: "Security Settings",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required String placeholder,
  }) {
    final bool isSet = value.isNotEmpty;
    return Row(
      children: [
            Icon(icon, color: const Color(0xFF00FFCC), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'sans-serif',
                ),
              ),
              Text(
                isSet ? value : placeholder,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'sans-serif',
                  color: isSet ? Colors.black : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.green[800], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
