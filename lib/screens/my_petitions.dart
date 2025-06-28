import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyPetitionScreen extends StatelessWidget {
  const MyPetitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    const sororiaPink = Color(0xFFE91E63);
    final accentBlue = const Color(0xFF1976D2);

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
      // Bluish-white gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F7F9), Color(0xFFE3F0FF), Color(0xFFD0E6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: AppBar(
                  backgroundColor: Colors.white,
                  elevation: 2,
                  centerTitle: true,
                  iconTheme: const IconThemeData(color: sororiaPink),
                  title: Text(
                    "SIGNED PETITIONS",
                    style: const TextStyle(
                      color: sororiaPink,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  toolbarHeight: 64,
                ),
              ),
              // Add the subtitle as a header below the AppBar
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                child: Center(
                  child: Text(
                    "All petitions you've signed are listed below.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .snapshots(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
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

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final List<dynamic> signedPetitions =
                        userData['signed_p'] ?? [];

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
                        if (petitionSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                          physics: const BouncingScrollPhysics(),
                          children: [
                            ...petitionSnapshot.data!.docs.map((doc) {
                              final petitionData =
                                  doc.data() as Map<String, dynamic>;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/open_petition',
                                        arguments: petitionData['petition_id'],
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            petitionData['title'] ?? '',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: sororiaPink,
                                                  fontSize: 20,
                                                ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            petitionData['description'] ?? '',
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.8),
                                                  fontSize: 16,
                                                ),
                                            maxLines: 8,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
