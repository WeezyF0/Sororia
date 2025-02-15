import 'package:flutter/material.dart';
import 'petitions_list_screen.dart';  // Import Petition model

class AddPetitionScreen extends StatefulWidget {
  const AddPetitionScreen({super.key});

  @override
  _AddPetitionScreenState createState() => _AddPetitionScreenState();
}

class _AddPetitionScreenState extends State<AddPetitionScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Start a Petition")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: "Petition Title"),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: "Petition Description"),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                  final newPetition = Petition(
                    title: titleController.text,
                    description: descriptionController.text,
                  );
                  Navigator.pop(context, newPetition); // Return petition object
                }
              },
              child: Text("Submit Petition"),
            ),
          ],
        ),
      ),
    );
  }
}
