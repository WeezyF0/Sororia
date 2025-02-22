import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPetitionScreen extends StatelessWidget {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  AddPetitionScreen({super.key});

  void _submitPetition(BuildContext context) {
  String title = _titleController.text.trim();
  String description = _descriptionController.text.trim();

  if (title.isNotEmpty && description.isNotEmpty) {
    DocumentReference docRef = FirebaseFirestore.instance.collection('petitions').doc();

    docRef.set({
      'petition_id': docRef.id,  // Firestore auto-generated unique ID
      'title': title,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    }).then((_) {
      Navigator.pop(context);
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding petition: $error")),
      );
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          // Remove default leading/back button to avoid misalignment
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/appBar_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            // SafeArea prevents overlap with status bar
            child: SafeArea(
              // Center horizontally & vertically
              child: Center(
                // Row sized to its children, so they remain together in the center
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // Distribute space between children
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Custom back arrow (white)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    const Text(
                      "Add Petition",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: "Petition Title"),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: "Petition Description"),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitPetition(context),
              child: Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
