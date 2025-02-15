import 'package:flutter/material.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  _ComplaintListScreenState createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  List<String> complaints = []; // Stores complaints

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Complaints List"),
        actions: [
          IconButton(
            icon: Icon(Icons.gavel),  // Gavel icon for petitions
            onPressed: () {
              Navigator.pushNamed(context, '/petitions');  // Navigate to PetitionListScreen
            },
          ),
        ],
      ),
      body: complaints.isEmpty
          ? Center(child: Text("No complaints available."))
          : ListView.builder(
              itemCount: complaints.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(complaints[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newComplaint = await Navigator.pushNamed(context, '/add_complaint');
          if (newComplaint != null) {
            setState(() {
              complaints.add(newComplaint as String);
            });
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
