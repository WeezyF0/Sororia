import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:complaints_app/theme/theme_provider.dart';
import 'navbar.dart';

class MyPetitionScreen extends StatelessWidget {
  const MyPetitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

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
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          toolbarHeight: 80,
          centerTitle: true,
          title: const Text(
            "MY PETITIONS",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 24,
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_petition');
        },
        backgroundColor: colorScheme.secondary,
        elevation: 4,
        icon: Icon(
          Icons.add_circle_outline,
          color: colorScheme.onSecondary,
          size: 24,
        ),
        label: Text(
          'Start a Petition',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondary,
          ),
        ),
      ),
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
                return Center(
                  child: Text(
                    "No signed petitions found.",
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children:
                    petitionSnapshot.data!.docs.map((doc) {
                      final petitionData = doc.data() as Map<String, dynamic>;
                      final petitionOwner = petitionData['owner'];
                      final Color cardColor =
                          (petitionOwner == null || petitionOwner == userId)
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
