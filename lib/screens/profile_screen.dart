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
    final contact = emergencyContacts[index];
    final bool isEmailContact = contact['contactType'] == 'email' || contact['contactType'] == null;
    
    final TextEditingController nameController = TextEditingController(
      text: contact['name'],
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Edit Contact Name",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show contact type
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    isEmailContact ? Icons.email : Icons.phone,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEmailContact 
                          ? contact['email'] ?? 'Unknown email'
                          : "+91 ${contact['phone'] ?? 'Unknown number'}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Display Name",
                hintText: "Enter new name",
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
            child: Text(
              "Cancel",
              style: TextStyle(color: Color(0xFFf88379)),
            ),
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

                  // Create updated contact with the new name
                  final updatedContact = Map<String, dynamic>.from(contact);
                  updatedContact['name'] = nameController.text;

                  // Find index to replace
                  final indexToReplace = currentContacts.indexWhere(
                    (c) => isEmailContact 
                      ? (c['email'] == contact['email'])
                      : (c['phone'] == contact['phone'])
                  );
                  
                  if (indexToReplace >= 0) {
                    currentContacts[indexToReplace] = updatedContact;
                    transaction.update(userDoc.reference, {
                      'e_contacts': currentContacts,
                    });
                  }
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
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    
    // Track which contact type is selected (email or phone)
    bool useEmail = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update dialog state
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            "Add Emergency Contact",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView( // To prevent overflow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle between email and phone
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setDialogState(() => useEmail = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: useEmail 
                              ? Theme.of(context).primaryColor.withOpacity(0.2)
                              : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: useEmail 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Email",
                              style: TextStyle(
                                fontWeight: useEmail ? FontWeight.bold : FontWeight.normal,
                                color: useEmail 
                                  ? Theme.of(context).primaryColor 
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setDialogState(() => useEmail = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !useEmail 
                              ? Theme.of(context).primaryColor.withOpacity(0.2) 
                              : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !useEmail 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Phone",
                              style: TextStyle(
                                fontWeight: !useEmail ? FontWeight.bold : FontWeight.normal,
                                color: !useEmail 
                                  ? Theme.of(context).primaryColor 
                                  : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Show either email or phone input based on selection
                if (useEmail)
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "User Email",
                      hintText: "Enter user's email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "User Phone",
                      hintText: "Enter 10-digit number",
                      prefixText: "+91 ",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                const SizedBox(height: 16),
                
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: Color(0xFFf88379)),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (useEmail && emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter an email address"))
                  );
                  return;
                }
                
                if (!useEmail && phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter a phone number"))
                  );
                  return;
                }
                
                if (!useEmail && (phoneController.text.trim().length != 10 || 
                    !RegExp(r'^[0-9]+$').hasMatch(phoneController.text.trim()))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter a valid 10-digit phone number"))
                  );
                  return;
                }
                
                try {
                  QuerySnapshot query;
                  
                  if (useEmail) {
                    // Search by email (existing functionality)
                    query = await _firestore
                      .collection('users')
                      .where('email', isEqualTo: emailController.text)
                      .limit(1)
                      .get();
                  } else {
                    // Search by phone number (new functionality)
                    query = await _firestore
                      .collection('users')
                      .where('phone_no', isEqualTo: phoneController.text.trim())
                      .limit(1)
                      .get();
                  }

                  if (query.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("User not found"))
                    );
                    return;
                  }

                  // Create contact object with a contactType field to distinguish between email/phone
                  final newContact = {
                    'contactType': useEmail ? 'email' : 'phone',
                    'email': useEmail ? emailController.text : null,
                    'phone': !useEmail ? phoneController.text.trim() : null,
                    'name': nameController.text.isNotEmpty
                        ? nameController.text
                        : useEmail 
                            ? emailController.text.split('@')[0]
                            : "Contact ${phoneController.text.trim().substring(6)}", // Last 4 digits
                    'userId': query.docs.first.id,
                    'addedAt': DateTime.now().toIso8601String(),
                  };

                  // Use transaction to ensure atomic update
                  await _firestore.runTransaction((transaction) async {
                    final userDoc = await transaction.get(
                      _firestore.collection('users').doc(user.uid),
                    );
                    final currentContacts = List<Map<String, dynamic>>.from(
                      userDoc.data()?['e_contacts'] ?? [],
                    );

                    // Check if contact already exists by userId
                    if (currentContacts.any((c) => c['userId'] == query.docs.first.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("This contact already exists"))
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
                    SnackBar(content: Text("Error adding contact: ${e.toString()}")),
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
      ),
    );
  }

  // Add these new variables for inline editing
  bool isEditingName = false;
  bool isEditingPhone = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final GlobalKey<FormState> nameFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> phoneFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // Replace _editName and _editPhoneNumber with these methods:
  void _toggleNameEdit() {
    if (isEditingName) {
      // Save the changes
      if (nameFormKey.currentState?.validate() ?? false) {
        _saveName();
      }
    } else {
      // Start editing
      nameController.text = userData?['name'] ?? '';
    }
    setState(() => isEditingName = !isEditingName);
  }

  Future<void> _saveName() async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'name': nameController.text.trim(),
      });
      setState(() {
        userData?['name'] = nameController.text.trim();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating name")));
    }
  }

  void _togglePhoneEdit() {
    if (isEditingPhone) {
      // Save the changes
      if (phoneFormKey.currentState?.validate() ?? false) {
        _verifyPhoneNumber();
      }
    } else {
      // Start editing
      phoneController.text = userData?['phone_no']?.toString() ?? '';
    }
    setState(() => isEditingPhone = !isEditingPhone);
  }

  Future<void> _verifyPhoneNumber() async {
    final phone = phoneController.text.trim();
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (context) => VerifyPhoneUpdate(
              userId: _auth.currentUser!.uid,
              phoneNumber: phone,
            ),
      ),
    );

    if (verified == true) {
      setState(() {
        userData?['phone_no'] = phone;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Phone number updated successfully")),
      );
    } else {
      // Reset to original value if verification failed
      phoneController.text = userData?['phone_no']?.toString() ?? '';
    }
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
          toolbarHeight: 80,
          centerTitle: true,
          title: const Text(
            "PROFILE",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 24,
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 24,
                                    color: Color(0xFFf88379),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Name",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFf88379),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        isEditingName
                                            ? Form(
                                              key: nameFormKey,
                                              child: TextFormField(
                                                controller: nameController,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  border: InputBorder.none,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.trim().isEmpty) {
                                                    return 'Name is required';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            )
                                            : Text(
                                              userData?['name'] != null
                                                  ? "${userData!['name']}"
                                                  : "Not provided",
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
                                  IconButton(
                                    icon: Icon(
                                      isEditingName ? Icons.check : Icons.edit,
                                      size: 20,
                                      color: primaryColor,
                                    ),
                                    onPressed: _toggleNameEdit,
                                  ),
                                ],
                              ),
                            ),

                            // Updated Phone Field with inline editing
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 24,
                                    color: Color(0xFFf88379),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Phone",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFf88379),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        isEditingPhone
                                            ? Form(
                                              key: phoneFormKey,
                                              child: TextFormField(
                                                controller: phoneController,
                                                keyboardType:
                                                    TextInputType.phone,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  border: InputBorder.none,
                                                  prefixText: '+91 ',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.trim().isEmpty) {
                                                    return 'Phone is required';
                                                  } else if (value
                                                          .trim()
                                                          .length !=
                                                      10) {
                                                    return 'Must be 10 digits';
                                                  } else if (!RegExp(
                                                    r'^[0-9]+$',
                                                  ).hasMatch(value.trim())) {
                                                    return 'Digits only';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            )
                                            : Text(
                                              userData?['phone_no'] != null
                                                  ? "+91 ${userData!['phone_no']}"
                                                  : "Not provided",
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
                                  IconButton(
                                    icon: Icon(
                                      isEditingPhone ? Icons.check : Icons.edit,
                                      size: 20,
                                      color: primaryColor,
                                    ),
                                    onPressed: _togglePhoneEdit,
                                  ),
                                ],
                              ),
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
                              final bool isEmailContact = contact['contactType'] == 'email' || contact['contactType'] == null; // Null check for backward compatibility
                              
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
                                    backgroundColor: primaryColor.withOpacity(0.2),
                                    child: Icon(
                                      isEmailContact ? Icons.email : Icons.phone,
                                      color: primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    contact['name'],
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isEmailContact 
                                      ? contact['email'] ?? 'Unknown email'
                                      : "+91 ${contact['phone'] ?? 'Unknown number'}",
                                    style: theme.textTheme.bodySmall?.copyWith(color: textSecondary),
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
                                        onPressed: () => _deleteContact(index),
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
          Icon(icon, size: 24, color: Color(0xFFf88379)),
          const SizedBox(width: 16),
          Expanded(
            // ← This is the key fix
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFf88379),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1, // ← Ensures single line
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1, // ← Ensures single line
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
