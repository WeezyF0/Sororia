import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navbar.dart';
import 'package:complaints_app/theme/theme_provider.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final surfaceColor = theme.colorScheme.surface;
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
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
                  Colors.purple.withOpacity(0.3),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "MY COMPLAINTS",
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
      ),
      drawer: const NavBar(),
      floatingActionButton: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, '/add_complaint');
          },
          backgroundColor: theme.primaryColor,
          elevation: 4,
          icon: Icon(
            Icons.add_circle_outline,
            color: theme.colorScheme.onPrimary,
            size: 24,
          ),
          label: Text(
            'Add a complaint',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
          final List<dynamic> savedComplaints = userData['saved_c'] ?? [];
          final List<dynamic> myComplaints = userData['my_c'] ?? [];

          if (savedComplaints.isEmpty && myComplaints.isEmpty) {
            return Center(
              child: Text(
                "You haven't saved or created any complaints yet.",
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
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: theme.primaryColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No complaints found',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              final allComplaints = snapshot.data!.docs;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSection(
                      context: context,
                      title: "Saved Complaints",
                      complaintIds: savedComplaints,
                      docs: allComplaints,
                      theme: theme,
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      primaryColor: primaryColor,
                      textSecondary: textSecondary,
                    ),
                    _buildSection(
                      context: context,
                      title: "My Complaints",
                      complaintIds: myComplaints,
                      docs: allComplaints,
                      theme: theme,
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      primaryColor: primaryColor,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<dynamic> complaintIds,
    required List<QueryDocumentSnapshot<Object?>> docs,
    required ThemeData theme,
    required bool isDark,
    required Color surfaceColor,
    required Color primaryColor,
    required Color textSecondary,
  }) {
    final filteredComplaints =
        docs.where((doc) => complaintIds.contains(doc.id)).toList();
    if (filteredComplaints.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredComplaints.length,
            itemBuilder: (context, index) {
              final doc = filteredComplaints[index];
              final data = doc.data() as Map<String, dynamic>;
              String timeAgoText = "Unknown date";

              if (data.containsKey('timestamp') && data['timestamp'] != null) {
                try {
                  DateTime? dateTime = parseTimestamp(data['timestamp']);
                  if (dateTime != null) {
                    timeAgoText = timeAgo(dateTime);
                  }
                } catch (e) {
                  timeAgoText = "Unknown date";
                }
              }

              String status = data['status'] ?? 'Pending';
              Color statusColor = _getStatusColor(theme, status);

              return Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: surfaceColor,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/open_complaint',
                          arguments: {
                            'complaintData': data,
                            'complaintId': doc.id,
                          },
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  statusColor.withOpacity(0.7),
                                  statusColor,
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Issue Type Container
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        data['issue_type'] ?? 'General',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                            ),
                                      ),
                                    ),

                                    // Spacer to push remaining elements to the right
                                    const Spacer(),

                                    // Save Button and Time Container Row
                                    Row(
                                      children: [
                                        // Save Button Container
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: primaryColor.withOpacity(
                                                0.25,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: SaveButton(
                                            complaintId: doc.id,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ), // Space between save button and time
                                        // Time Container
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: textSecondary.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 14,
                                                color: textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                timeAgoText,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                  data['text'] ?? 'No details available',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: textSecondary.withOpacity(
                                            0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: textSecondary.withOpacity(
                                              0.15,
                                            ),
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
                                                data['location'] ??
                                                    'Unknown location',
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.labelMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                      ),
                                    ),
                                  ],
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
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return theme.colorScheme.brightness == Brightness.dark
            ? ColorPalette.success.withOpacity(0.8)
            : ColorPalette.success;
      case 'in progress':
        return theme.colorScheme.brightness == Brightness.dark
            ? ColorPalette.warning.withOpacity(0.8)
            : ColorPalette.warning;
      default:
        return theme.colorScheme.brightness == Brightness.dark
            ? ColorPalette.info.withOpacity(0.8)
            : ColorPalette.info;
    }
  }
}

// Ensure the SaveButton class is properly placed OUTSIDE the MyComplaintScreen class
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
        final savedList =
            (snapshot.data?.data() as Map<String, dynamic>?)?['saved_c'] ?? [];
        final isSaved = savedList.contains(complaintId);

        return GestureDetector(
          onTap: () async {
            final userDoc = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);

            if (isSaved) {
              await userDoc.update({
                'saved_c': FieldValue.arrayRemove([complaintId]),
              });
            } else {
              await userDoc.update({
                'saved_c': FieldValue.arrayUnion([complaintId]),
              });
            }
          },
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 14, // Match the icon size of the time container
            color:
                isSaved
                    ? Theme.of(context)
                        .primaryColor // Filled color
                    : Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6), // Outline color
          ),
        );
      },
    );
  }
}
