import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import for user authentication

class OpenPetitionScreen extends StatelessWidget {
  const OpenPetitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve the petition ID from route arguments
    final String petitionId =
        ModalRoute.of(context)!.settings.arguments as String;

    // Get current user ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      // Handle case where user is not logged in
      return const Scaffold(
        body: Center(child: Text("Please log in to view petitions")),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(80.0),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "REVIEW PETITION",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleSpacing: 0,
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
        ),
      ),
    ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('petitions')
                .doc(petitionId)
                .snapshots(),
        builder: (context, petitionSnapshot) {
          if (petitionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!petitionSnapshot.hasData || !petitionSnapshot.data!.exists) {
            return const Center(child: Text("No petition data available."));
          }

          // Extract petition data
          final petitionData =
              petitionSnapshot.data!.data() as Map<String, dynamic>;
          final String id = petitionData['petition_id'] ?? petitionId;
          final String title = petitionData['title'] ?? 'No Title';
          final String description =
              petitionData['description'] ?? 'No Description';

          // Get signatures (initialize to empty list if not available)
          final List<dynamic> signatures = petitionData['signatures'] ?? [];
          final int signatureCount = signatures.length;

          // Check if current user has already signed
          final bool hasUserSigned = signatures.contains(currentUserId);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Petition ID outside the card
                  Text(
                    "Petition ID: $id",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Card for petition details
                  Card(
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Petition Title (bold)
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Petition Description
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Use LayoutBuilder for adaptive layout based on available width
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Check if screen is wide enough for row layout
                              bool useRowLayout = constraints.maxWidth > 400;
                              
                              return useRowLayout 
                                ? _buildRowLayout(context, signatureCount, hasUserSigned, currentUserId, petitionId)
                                : _buildColumnLayout(context, signatureCount, hasUserSigned, currentUserId, petitionId);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // Row layout for wider screens
  Widget _buildRowLayout(BuildContext context, int signatureCount, bool hasUserSigned, 
                       String currentUserId, String petitionId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Show signature count
        Expanded(
          flex: 3,
          child: Text(
            "$signatureCount ${signatureCount == 1 ? 'person has' : 'people have'} already signed",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Sign Petition button
        Expanded(
          flex: 2,
          child: _buildSignButton(context, hasUserSigned, currentUserId, petitionId),
        ),
      ],
    );
  }
  
  // Column layout for narrower screens
  Widget _buildColumnLayout(BuildContext context, int signatureCount, bool hasUserSigned, 
                         String currentUserId, String petitionId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Show signature count
        Text(
          "$signatureCount ${signatureCount == 1 ? 'person has' : 'people have'} already signed",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Sign Petition button - full width in column layout
        _buildSignButton(context, hasUserSigned, currentUserId, petitionId),
      ],
    );
  }
  
  // Extracted sign button widget to avoid code duplication
  Widget _buildSignButton(BuildContext context, bool hasUserSigned, 
                       String currentUserId, String petitionId) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasUserSigned ? Colors.grey[600] : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: hasUserSigned
          ? null // Disable button if already signed
          : () async {
              try {
                // 1. Update the petition's signatures array
                final petitionRef = FirebaseFirestore.instance
                    .collection('petitions')
                    .doc(petitionId);

                await petitionRef.update({
                  'signatures': FieldValue.arrayUnion([currentUserId]),
                });

                // 2. Update the user's "signed_p" array
                final userRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId);

                // If "signed_p" doesn't exist, create or merge it
                await userRef.set({
                  'signed_p': FieldValue.arrayUnion([petitionId]),
                }, SetOptions(merge: true));

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Petition signed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error signing petition: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
      child: Text(
        hasUserSigned ? "You've Signed" : "Sign Petition",
        style: TextStyle(
          color: hasUserSigned ? Colors.white70 : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}