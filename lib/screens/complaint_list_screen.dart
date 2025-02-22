import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintListScreen extends StatelessWidget {
  const ComplaintListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0), // Custom AppBar height
        child: AppBar(
          backgroundColor: Colors.transparent, // Transparent to show background image
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/appBar_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0), // Horizontal padding for spacing
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space between children
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left-aligned title text
                      Text(
                        "COMPLAINTS LIST",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      // Right-aligned icons grouped in a Row
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.gavel, color: Colors.white),
                            onPressed: () {
                              Navigator.pushNamed(context, '/petitions');
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              Navigator.pushNamed(context, '/complaints_map');
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.account_circle, color: Colors.white),
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),


      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No complaints available."));
          }
          return ListView(
            padding: EdgeInsets.all(16.0), // Overall padding for the list
            children: snapshot.data!.docs.map((doc) {
              return Card(
                color: Colors.grey[200], // Light grey background for each complaint card
                margin: EdgeInsets.only(bottom: 12.0), // Spacing between cards
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0), // Padding inside each card
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Complaint text
                      Text(
                        doc['text'],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8.0),
                      // Timestamp
                      Text(
                        doc['timestamp'] != null
                            ? doc['timestamp'].toDate().toString()
                            : "No timestamp available",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.grey[900], // Grey FAB to match theme
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_complaint');
        },
        child: Icon(Icons.add, color: Colors.white),
      ),

    );
  }
}
