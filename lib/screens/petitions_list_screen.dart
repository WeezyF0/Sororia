import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PetitionListScreen extends StatelessWidget {
  const PetitionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Active Petitions")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('petitions').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No active petitions."));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              return ListTile(
                title: Text(doc['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(doc['description']),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_petition');
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
