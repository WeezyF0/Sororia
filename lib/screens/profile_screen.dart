import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:complaints_app/theme/theme_provider.dart';
import 'navbar.dart';
import 'package:complaints_app/screens/verify_phone_update.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isLoadingContacts = true;
  List<Map<String, dynamic>> emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userData = doc.data();
          emergencyContacts = List<Map<String, dynamic>>.from(
            userData?['e_contacts'] ?? [],
          );
          isLoading = false;
          isLoadingContacts = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        isLoading = false;
        isLoadingContacts = false;
      });
    }
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

  void _editPhoneNumber() async {
    final TextEditingController controller = TextEditingController(
      text: userData?['phone_no']?.toString().replaceAll('+91', ''),
    );

    final formKey = GlobalKey<FormState>();

    // First show dialog to get the new phone number
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Phone Number"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                prefixText: '+91 ',
                counterText: "", // Hide character counter
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                } else if (value.trim().length != 10) {
                  return 'Must be exactly 10 digits';
                } else if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                  return 'Digits only';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );

    // If user canceled, return early
    if (result == null) return;

    // Now launch the verification screen
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => VerifyPhoneUpdate(
              userId: _auth.currentUser!.uid,
              phoneNumber: result,
            ),
      ),
    );

    // If verification was successful, update the UI
    if (verified == true) {
      setState(() {
        userData?['phone_no'] = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Phone number updated successfully")),
      );
    }
  }

  void _editName() async {
    final TextEditingController controller = TextEditingController(
      text: userData?['name']?.toString(),
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Name"),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Name",
                counterText: "", // Hide character counter
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final phone = controller.text.trim();
                  await _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .update({'name': phone});

                  setState(() {
                    userData?['name'] = phone;
                  });

                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Please log in to view your profile",
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "MY PROFILE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
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

      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                size: 40,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildProfileItem(
                              icon: Icons.email,
                              label: "Email",
                              value: user.email ?? "Not provided",
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildProfileItem(
                                    icon: Icons.person,
                                    label: "Name",
                                    value:
                                        userData?['name'] != null
                                            ? "${userData!['name']}"
                                            : "Not provided",
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: primaryColor,
                                  ),
                                  onPressed: _editName,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildProfileItem(
                                    icon: Icons.phone,
                                    label: "Phone",
                                    value:
                                        userData?['phone_no'] != null
                                            ? "+91 ${userData!['phone_no']}"
                                            : "Not provided",
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: primaryColor,
                                  ),
                                  onPressed: _editPhoneNumber,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      context,
                      title: "My Content",
                      icon: Icons.link,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 8),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.report, color: primaryColor),
                            title: const Text("My Experiences"),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, '/my_complaints');
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.article, color: primaryColor),
                            title: const Text("My Petitions"),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pushNamed(context, '/my_petitions');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Emergency Contacts Section
                    _buildSectionHeader(
                      context,
                      title: "Emergency Contacts",
                      icon: Icons.emergency,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (isLoadingContacts)
                              Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                ),
                              )
                            else if (emergencyContacts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: textSecondary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: primaryColor.withOpacity(
                                        0.2,
                                      ),
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
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    subtitle: Text(
                                      contact['email'],
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: textSecondary),
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
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          onPressed:
                                              () => _deleteContact(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text("Add Contact"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
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
                  ],
                ),
              ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color primaryColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
