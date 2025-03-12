import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyPetitionScreen extends StatelessWidget {
  const MyPetitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // If the user is not logged in, show a prompt
    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text("Please log in to view your signed petitions."),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
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
            foregroundDecoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.3), 
                  Colors.purple.withOpacity(0.3)
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Signed Petitions",
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
      // First StreamBuilder: Listen to the current user's document to get `signed_p`.
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text("No user data available."));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> signedPetitions = userData['signed_p'] ?? [];

          // If the user hasn't signed anything yet
          if (signedPetitions.isEmpty) {
            return const Center(
              child: Text("You haven't signed any petitions yet."),
            );
          }

          // Second StreamBuilder: Query only the petitions in the user's signed list.
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('petitions')
                    .where('petition_id', whereIn: signedPetitions)
                    .snapshots(),
            builder: (context, petitionSnapshot) {
              if (petitionSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!petitionSnapshot.hasData ||
                  petitionSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No signed petitions found."));
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children:
                    petitionSnapshot.data!.docs.map((doc) {
                      // Retrieve the petition's owner. It may be null if not set.
                      final petitionOwner = doc['owner'];

                      // If owner is null or equals current user's ID, show green; otherwise white.
                      final Color cardColor =
                          (petitionOwner == null || petitionOwner == userId)
                              ? Colors.green.shade200
                              : Colors.white;

                      return Card(
                        color: cardColor,
                        margin: const EdgeInsets.only(bottom: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8.0),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/open_petition',
                              arguments: doc['petition_id'],
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(doc['description']),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
