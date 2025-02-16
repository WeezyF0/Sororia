import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintListScreen extends StatelessWidget {
  const ComplaintListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Complaints List"),
        actions: [
          IconButton(
            icon: Icon(Icons.gavel), // Navigate to petitions
            onPressed: () {
              Navigator.pushNamed(context, '/petitions');
            },
          ),
          IconButton(
            icon: Icon(Icons.search), // Navigate to complaints map
            onPressed: () {
              Navigator.pushNamed(context, '/complaints_map');
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No complaints available."));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(
                title: Text(doc['text']),
                subtitle: Text(
                    doc['timestamp'] != null
                        ? doc['timestamp'].toDate().toString()
                        : "No timestamp available",
                  ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_complaint'); // Navigate to add complaint
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
