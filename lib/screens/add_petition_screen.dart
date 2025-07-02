import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPetitionScreen extends StatelessWidget {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  AddPetitionScreen({super.key});

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          toolbarHeight: 80,
          centerTitle: true,
          title: const Text(
            "ADD PETITION",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 24,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Petition Title"),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Petition Description",
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitPetition(context),
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
