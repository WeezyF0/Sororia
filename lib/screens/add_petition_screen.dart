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
      appBar: AppBar(title: Text("Add Petition")),
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
