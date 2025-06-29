import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navbar.dart';

class MyComplaintScreen extends StatelessWidget {
  const MyComplaintScreen({super.key});

  String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 365) {
      return "${(difference.inDays / 365).floor()} ${(difference.inDays / 365).floor() == 1 ? 'year' : 'years'} ago";
    } else if (difference.inDays > 30) {
      return "${(difference.inDays / 30).floor()} ${(difference.inDays / 30).floor() == 1 ? 'month' : 'months'} ago";
    } else if (difference.inDays > 0) {
      return "${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago";
    } else {
      return "Just now";
    }
  }

  DateTime? parseTimestamp(String timestamp) {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      print("Error parsing timestamp: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const sororiaPink = Color(0xFFE91E63);
    final accentBlue = const Color(0xFF1976D2); // Material blue 700
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.6);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Please log in to view your complaints.",
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
              AppBar(
                backgroundColor: Colors.white,
                elevation: 2,
                centerTitle: true,
                title: Text(
                  "SORORIA",
                  style: TextStyle(
                    color: sororiaPink,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                iconTheme: const IconThemeData(color: sororiaPink),
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
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      );
                    }
                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    final List<dynamic> savedComplaints =
                        userData['saved_c'] ?? [];
                    final List<dynamic> myComplaints = userData['my_c'] ?? [];

                    if (savedComplaints.isEmpty && myComplaints.isEmpty) {
                      return Center(
                        child: Text(
                          "You haven't saved or shared any experiences yet.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('complaints')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                      builder: (
                        context,
                        AsyncSnapshot<QuerySnapshot> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: sororiaPink,
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No experiences found.',
                              style: theme.textTheme.titleMedium,
                            ),
                          );
                        }
                        final allComplaints = snapshot.data!.docs;
                        return ListView(
                          padding: const EdgeInsets.all(16.0),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            ..._buildComplaintCards(
                              context: context,
                              title: "Saved Experiences",
                              complaintIds: savedComplaints,
                              docs: allComplaints,
                              theme: theme,
                              textSecondary: textSecondary,
                              sororiaPink: sororiaPink,
                              accentBlue: accentBlue,
                            ),
                            ..._buildComplaintCards(
                              context: context,
                              title: "My Experiences",
                              complaintIds: myComplaints,
                              docs: allComplaints,
                              theme: theme,
                              textSecondary: textSecondary,
                              sororiaPink: sororiaPink,
                              accentBlue: accentBlue,
                            ),
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
      drawer: NavBar(),
      floatingActionButton: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, '/add_complaint');
          },
          backgroundColor: accentBlue,
          elevation: 4,
          icon: const Icon(
            Icons.add_circle_outline,
            color: Colors.white,
            size: 24,
          ),
          label: const Text(
            'Share an Experience',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComplaintCards({
    required BuildContext context,
    required String title,
    required List<dynamic> complaintIds,
    required List<QueryDocumentSnapshot<Object?>> docs,
    required ThemeData theme,
    required Color textSecondary,
    required Color sororiaPink,
    required Color accentBlue,
  }) {
    final filteredComplaints =
        docs.where((doc) {
          return complaintIds.any((entry) {
            String entryId;
            if (entry is Map<String, dynamic>) {
              entryId = entry['complaintId'] ?? '';
            } else if (entry is String) {
              entryId = entry;
            } else {
              return false;
            }
            return entryId == doc.id;
          });
        }).toList();

    if (filteredComplaints.isEmpty) {
      return [];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12.0, top: 16.0),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ),
      ...filteredComplaints.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        String timeAgoText = "Unknown date";
        if (data.containsKey('timestamp') && data['timestamp'] != null) {
          DateTime? dateTime = parseTimestamp(data['timestamp']);
          if (dateTime != null) {
            timeAgoText = timeAgo(dateTime);
          }
        }
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
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/open_complaint',
                  arguments: {'complaintData': data, 'complaintId': doc.id},
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with issue type and date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accentBlue.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            data['issue_type'] ?? 'General',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SaveButton(complaintId: doc.id),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: textSecondary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      timeAgoText,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['original_text'] ?? 'No details available',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: textSecondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: textSecondary.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data['location'] ?? 'Unknown location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ];
  }
}

class SaveButton extends StatelessWidget {
  final String complaintId;

  const SaveButton({super.key, required this.complaintId});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final List<dynamic> savedList = userData['saved_c'] ?? [];

        dynamic existingEntry;
        try {
          existingEntry = savedList.firstWhere((entry) {
            if (entry is Map<String, dynamic>) {
              return entry['complaintId'] == complaintId;
            } else if (entry is String) {
              return entry == complaintId;
            }
            return false;
          });
        } catch (_) {}

        final isSaved = existingEntry != null;

        return GestureDetector(
          onTap: () async {
            final userDoc = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);

            if (existingEntry is String) {
              await userDoc.update({
                'saved_c': FieldValue.arrayRemove([existingEntry]),
              });
              existingEntry = {
                'complaintId': existingEntry,
                'last_seen_update_count': 0,
              };
              await userDoc.update({
                'saved_c': FieldValue.arrayUnion([existingEntry]),
              });
            }

            if (isSaved) {
              await userDoc.update({
                'saved_c': FieldValue.arrayRemove([existingEntry]),
              });
            } else {
              final newEntry = {
                'complaintId': complaintId,
                'last_seen_update_count': 0,
              };
              await userDoc.update({
                'saved_c': FieldValue.arrayUnion([newEntry]),
              });
            }
          },
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 14,
            color:
                isSaved
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        );
      },
    );
  }
}
