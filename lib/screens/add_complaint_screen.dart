import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddComplaintScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  AddComplaintScreen({super.key});

  void _submitComplaint(BuildContext context) {
    String complaintText = _controller.text.trim();
    if (complaintText.isNotEmpty) {
      // Store complaint in Firestore
      FirebaseFirestore.instance.collection('complaints').add({
        'text': complaintText,
        'timestamp': FieldValue.serverTimestamp(),
      }).then((_) {
        Navigator.pop(context); // Close screen after submission
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding complaint: $error")),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Complaint")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: "Enter your complaint"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitComplaint(context),
              child: Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
