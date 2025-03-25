import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navbar.dart';
import 'package:complaints_app/theme/theme_provider.dart';

class ComplaintListScreen extends StatelessWidget {
  const ComplaintListScreen({super.key});

  // Function to format timestamp as "time ago"
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

  // Parse the timestamp string to DateTime
  DateTime? parseTimestamp(String timestamp) {
    try {
      // The timestamp format is "2025-03-14T15:43:09.441437"
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

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "COMPLAINTS LIST",
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
      drawer: NavBar(),
      floatingActionButton: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: 8),
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
      body: StreamBuilder(
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
                  const SizedBox(height: 8),
                  Text(
                    'Add a new complaint to get started',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.0),
            physics: const BouncingScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              final Map<String, dynamic> data =
                  doc.data() as Map<String, dynamic>;

              // Format the timestamp as "time ago"
              String timeAgoText = "Unknown date";
              if (data.containsKey('timestamp') && data['timestamp'] != null) {
                try {
                  // Parse the timestamp string
                  DateTime? dateTime = parseTimestamp(data['timestamp']);
                  if (dateTime != null) {
                    timeAgoText = timeAgo(dateTime);
                  }
                } catch (e) {
                  timeAgoText = "Unknown date";
                }
              }

              // Get complaint status or default to 'Pending'
              String status = data['status'] ?? 'Pending';
              Color statusColor;

              // Assign colors based on status
              switch (status.toLowerCase()) {
                case 'resolved':
                  statusColor =
                      theme.colorScheme.brightness == Brightness.dark
                          ? ColorPalette.success.withOpacity(0.8)
                          : ColorPalette.success;
                  break;
                case 'in progress':
                  statusColor =
                      theme.colorScheme.brightness == Brightness.dark
                          ? ColorPalette.warning.withOpacity(0.8)
                          : ColorPalette.warning;
                  break;
                default:
                  statusColor =
                      theme.colorScheme.brightness == Brightness.dark
                          ? ColorPalette.info.withOpacity(0.8)
                          : ColorPalette.info;
                  break;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 16.0),
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
                      offset: Offset(0, 4),
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
                          // Enhanced status indicator bar at top
                          Container(
                            height: 6,
                            width: double.infinity,
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
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row with issue type and date
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
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

                                    // Modified layout for responsive UI
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          // Save Button - Now a simple icon with minimal container
                                          SaveButton(
                                            complaintId: doc.id,
                                            theme: theme,
                                          ),
                                          const SizedBox(width: 8),

                                          // Time display - Now with more flexible layout
                                          Flexible(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: textSecondary
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                textSecondary,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),

                                // Complaint text with better styling
                                Text(
                                  data['text'] ?? 'No details available',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(height: 18),

                                // Footer with location and status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Location with enhanced styling
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
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
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                data['location'] ??
                                                    'Unknown location',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),

                                    // Status chip with improved styling
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.1),
                                            blurRadius: 4,
                                            spreadRadius: 0,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        status,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                              letterSpacing: 0.3,
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
          );
        },
      ),
    );
  }
}

class SaveButton extends StatelessWidget {
  final String complaintId;
  final ThemeData theme;

  const SaveButton({super.key, required this.complaintId, required this.theme});

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

        final savedList =
            (snapshot.data?.data() as Map<String, dynamic>?)?['saved_c'] ?? [];
        final isSaved = savedList.any((entry) {
          if (entry is Map<String, dynamic>) {
            return entry['complaintId'] == complaintId;
          } else if (entry is String) {
            return entry == complaintId;
          }
          return false;
        });

        return InkWell(
          onTap: () async {
            final userDoc = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);

            if (isSaved) {
              // Remove all entries that match either map or string format
              final entriesToRemove =
                  savedList.where((entry) {
                    if (entry is Map<String, dynamic>) {
                      return entry['complaintId'] == complaintId;
                    } else if (entry is String) {
                      return entry == complaintId;
                    }
                    return false;
                  }).toList();

              await userDoc.update({
                'saved_c': FieldValue.arrayRemove(entriesToRemove),
              });
            } else {
              // Add new map entry with initial update count
              final newEntry = {
                'complaintId': complaintId,
                'last_seen_update_count': 0,
              };
              await userDoc.update({
                'saved_c': FieldValue.arrayUnion([newEntry]),
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 16,
              color:
                  isSaved
                      ? theme.primaryColor
                      : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        );
      },
    );
  }
}
