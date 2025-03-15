import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:complaints_app/theme/theme_provider.dart';

class MyPetitionScreen extends StatelessWidget {
  const MyPetitionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    // If the user is not logged in, show a prompt.
    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Please log in to view your signed petitions.",
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.appBarTheme.iconTheme?.color ?? Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "SIGNED PETITIONS",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(
              child: Text(
                "No user data available.",
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> signedPetitions = userData['signed_p'] ?? [];

          if (signedPetitions.isEmpty) {
            return Center(
              child: Text(
                "You haven't signed any petitions yet.",
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('petitions')
                .where('petition_id', whereIn: signedPetitions)
                .snapshots(),
            builder: (context, petitionSnapshot) {
              if (petitionSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!petitionSnapshot.hasData ||
                  petitionSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "No signed petitions found.",
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: petitionSnapshot.data!.docs.map((doc) {
                  final petitionData = doc.data() as Map<String, dynamic>;
                  final petitionOwner = petitionData['owner'];
                  final Color cardColor = (petitionOwner == null || petitionOwner == userId)
                      ? ColorPalette.success.withOpacity(0.3)
                      : theme.cardTheme.color ?? Colors.white;

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
                          arguments: petitionData['petition_id'],
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              petitionData['title'],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              petitionData['description'],
                              style: theme.textTheme.bodyMedium,
                            ),
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
