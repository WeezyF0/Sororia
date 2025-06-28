import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPetitionScreen extends StatelessWidget {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  AddPetitionScreen({super.key});

  static const sororiaPink = Color(0xFFE91E63);
  static const accentBlue = Color(0xFF1976D2);

  Future<void> _submitPetition(BuildContext context) async {
    // Retrieve the current user's ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    String title = _titleController.text.trim();
    String description = _descriptionController.text.trim();

    if (title.isNotEmpty && description.isNotEmpty) {
      try {
        // Create a new petition document reference with an auto-generated ID
        DocumentReference docRef =
            FirebaseFirestore.instance.collection('petitions').doc();

        // Set petition data with additional fields: owner and signatures
        await docRef.set({
          'petition_id': docRef.id,
          'title': title,
          'description': description,
          'timestamp': FieldValue.serverTimestamp(),
          'owner': currentUserId, // New field: owner
          'signatures': [
            currentUserId,
          ], // Initialize signatures with current user's ID
        });

        // Update the user's document to add this petition's ID to the signed_p array
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({
              'signed_p': FieldValue.arrayUnion([docRef.id]),
            }, SetOptions(merge: true));

        Navigator.pop(context);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding petition: $error")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Blue gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F7F9), Color(0xFFE3F0FF), Color(0xFFD0E6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // White AppBar with pink title
              AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: sororiaPink),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  "Add Petition",
                  style: TextStyle(
                    color: sororiaPink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                iconTheme: const IconThemeData(color: sororiaPink),
              ),
              // Form card
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Card(
                      elevation: 8.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: "Petition Title",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: "Petition Description",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _submitPetition(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text("Submit"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
