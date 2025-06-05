import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:complaints_app/theme/theme_provider.dart';
import 'navbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> emergencyContacts = [];
  bool isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          emergencyContacts = List<Map<String, dynamic>>.from(
            doc.data()?['e_contacts'] ?? [],
          );
          isLoadingContacts = false;
        });
      }
    } catch (e) {
      print("Error loading contacts: $e");
      setState(() => isLoadingContacts = false);
    }
  }

  Future<void> _addEmergencyContact() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Add Emergency Contact",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "User Email",
                    hintText: "Enter user's email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Display Name",
                    hintText: "Optional contact name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  if (emailController.text.isEmpty) return;

                  try {
                    final query =
                        await _firestore
                            .collection('users')
                            .where('email', isEqualTo: emailController.text)
                            .limit(1)
                            .get();

                    if (query.docs.isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("User not found")));
                      return;
                    }

                    final newContact = {
                      'email': emailController.text,
                      'name':
                          nameController.text.isNotEmpty
                              ? nameController.text
                              : emailController.text.split('@')[0],
                      'userId': query.docs.first.id,
                      'addedAt':
                          DateTime.now()
                              .toIso8601String(), // Changed to regular timestamp
                    };

                    // Use transaction to ensure atomic update
                    await _firestore.runTransaction((transaction) async {
                      final userDoc = await transaction.get(
                        _firestore.collection('users').doc(user.uid),
                      );
                      final currentContacts = List<Map<String, dynamic>>.from(
                        userDoc.data()?['e_contacts'] ?? [],
                      );

                      // Check if contact already exists
                      if (currentContacts.any(
                        (c) => c['email'] == emailController.text,
                      )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Contact already exists")),
                        );
                        return;
                      }

                      currentContacts.add(newContact);
                      transaction.update(userDoc.reference, {
                        'e_contacts': currentContacts,
                      });
                    });

                    setState(() {
                      emergencyContacts.add(newContact);
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error adding contact: ${e.toString()}"),
                      ),
                    );
                  }
                },
                child: Text(
                  "Add",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteContact(int index) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'e_contacts': FieldValue.arrayRemove([emergencyContacts[index]]),
      });

      setState(() {
        emergencyContacts.removeAt(index);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting contact")));
    }
  }

  Future<void> _editContact(int index) async {
    final TextEditingController nameController = TextEditingController(
      text: emergencyContacts[index]['name'],
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Edit Contact Name",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Display Name",
                hintText: "Enter new name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;

                  final user = _auth.currentUser;
                  if (user == null) return;

                  try {
                    await _firestore.runTransaction((transaction) async {
                      final userDoc = await transaction.get(
                        _firestore.collection('users').doc(user.uid),
                      );
                      final currentContacts = List<Map<String, dynamic>>.from(
                        userDoc.data()?['e_contacts'] ?? [],
                      );

                      final updatedContact = Map<String, dynamic>.from(
                        emergencyContacts[index],
                      );
                      updatedContact['name'] = nameController.text;

                      // Remove old contact and add updated one
                      currentContacts.removeWhere(
                        (c) => c['email'] == emergencyContacts[index]['email'],
                      );
                      currentContacts.add(updatedContact);

                      transaction.update(userDoc.reference, {
                        'e_contacts': currentContacts,
                      });
                    });

                    setState(() {
                      emergencyContacts[index]['name'] = nameController.text;
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error updating contact")),
                    );
                  }
                },
                child: Text(
                  "Save",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final surfaceColor = theme.colorScheme.surface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.6);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "SETTINGS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/appBar_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.purple.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Contacts Section
            _buildSectionHeader(
              context,
              title: "Emergency Contacts",
              icon: Icons.emergency,
              primaryColor: primaryColor,
            ),
            SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (isLoadingContacts)
                      Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    else if (emergencyContacts.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          "No emergency contacts added",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      )
                    else
                      ...emergencyContacts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final contact = entry.value;
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: textSecondary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: Text(
                                contact['name'][0].toUpperCase(),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              contact['name'],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              contact['email'],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textSecondary,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: primaryColor,
                                  ),
                                  onPressed: () => _editContact(index),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteContact(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.add, size: 20),
                      label: Text("Add Contact"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _addEmergencyContact,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Visual Settings Section
            _buildSectionHeader(
              context,
              title: "Visual Settings",
              icon: Icons.palette,
              primaryColor: primaryColor,
            ),
            SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [primaryColor.withOpacity(0.7), primaryColor],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: primaryColor,
                        ),
                      ),
                      title: Text(
                        "Dark Mode",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Switch.adaptive(
                        value: isDark,
                        activeColor: primaryColor,
                        onChanged: (_) => themeProvider.toggleTheme(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Account Settings Section
            _buildSectionHeader(
              context,
              title: "Account Settings",
              icon: Icons.account_circle,
              primaryColor: primaryColor,
            ),
            SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.red.withOpacity(0.7), Colors.red],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.logout, color: Colors.red),
                      ),
                      title: Text(
                        "Logout",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.red),
                      onTap: () async {
                        await _auth.signOut();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color primaryColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: primaryColor),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
