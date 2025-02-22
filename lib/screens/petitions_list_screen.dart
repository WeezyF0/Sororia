import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PetitionListScreen extends StatelessWidget {
  const PetitionListScreen({super.key});

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
                      "Active Petitions",
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
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('petitions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No active petitions."));
          }
          return ListView(
            padding: EdgeInsets.all(16.0),
            children: snapshot.data!.docs.map((doc) {
              return Card(
                color: Colors.grey[200],
                margin: EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0),),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'],
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(doc['description']),
                    ]
                  )
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.grey[900],
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_petition');
        },
        child: Icon(Icons.add, color: Colors.white,),
      ),
    );
  }
}
