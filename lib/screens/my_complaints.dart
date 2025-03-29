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

  Color _getStatusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return theme.brightness == Brightness.dark
            ? Colors.greenAccent.withOpacity(0.8)
            : Colors.green;
      case 'in progress':
        return theme.brightness == Brightness.dark
            ? Colors.orangeAccent.withOpacity(0.8)
            : Colors.orange;
      default:
        return theme.brightness == Brightness.dark
            ? Colors.lightBlueAccent.withOpacity(0.8)
            : Colors.lightBlue;
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
                    children: const [
                      Text(
                        "MY EXPERIENCES",
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
            'Share an Experience',
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
                "You haven't saved or shared any experiences yet.",
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
                // Check if we have access to the specific complaint data from elsewhere
                // or fetch it directly using the complaintId
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                    .collection('complaints')
                    .doc('complaintId') // You need to get this ID from your navigation/state
                    .get(),
                  builder: (context, complaintSnapshot) {
                    if (complaintSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    
                    if (complaintSnapshot.hasData && complaintSnapshot.data!.exists) {
                      final data = complaintSnapshot.data!.data() as Map<String, dynamic>;
                      final originalText = data['original_text'] ?? 'No text available';
                      
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            originalText,
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    
                    return Center(
                      child: Text(
                        'No experience found. Please try again later.',
                        style: theme.textTheme.titleMedium,
                      ),
                    );
                  }
                );
              }


              final allComplaints = snapshot.data!.docs;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSection(
                      context: context,
                      title: "Saved Experiences",
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
                      title: "My Experiences",
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
        docs.where((doc) {
          return complaintIds.any((entry) {
            if (entry is Map<String, dynamic>) {
              return entry['complaintId'] == doc.id;
            } else if (entry is String) {
              return entry == doc.id;
            }
            return false;
          });
        }).toList();

    if (filteredComplaints.isEmpty) {
      // Try to get the original complaint data if you have the ID
      if (complaintIds.isNotEmpty) {
        String complaintId;
        if (complaintIds.first is Map<String, dynamic>) {
          complaintId = complaintIds.first['complaintId'];
        } else {
          complaintId = complaintIds.first.toString();
        }
        
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
            .collection('complaints')
            .doc(complaintId)
            .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original Text:',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['original_text'] ?? 'No text available',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            
            return Center(
              child: Text(
                'Could not find experience details.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          },
        );
      }
      
      return Center(
        child: Text(
          'No experiences found in this section.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }


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
              final currentUpdateCount = data['update_count'] as int? ?? 0;
              String timeAgoText = "Unknown date";

              if (data.containsKey('timestamp') && data['timestamp'] != null) {
                DateTime? dateTime = parseTimestamp(data['timestamp']);
                if (dateTime != null) {
                  timeAgoText = timeAgo(dateTime);
                }
              }
              // Find the saved entry corresponding to this complaint
              dynamic savedEntry;
              int lastSeenCount = 0;
              try {
                savedEntry = complaintIds.firstWhere((entry) {
                  if (entry is Map<String, dynamic>) {
                    return entry['complaintId'] == doc.id;
                  } else if (entry is String) {
                    return entry == doc.id;
                  }
                  return false;
                });
                if (savedEntry is Map<String, dynamic>) {
                  lastSeenCount =
                      (savedEntry['last_seen_update_count'] as num?)?.toInt() ??
                      0;
                }
              } catch (_) {}

              final showUpdateBanner = currentUpdateCount > lastSeenCount;
              final status = data['status'] ?? 'Pending';
              final statusColor = _getStatusColor(theme, status);

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
                      onTap: () async {
                        // First, navigate to the open_complaint screen regardless of update status
                        Navigator.pushNamed(
                          context,
                          '/open_complaint',
                          arguments: {
                            'complaintData': data,
                            'complaintId': doc.id,
                          },
                        );
                        
                        // Then, update last seen count when pressed
                        final userId = FirebaseAuth.instance.currentUser?.uid;
                        if (userId == null) return;

                        final userDoc = FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId);

                        // Check if complaint exists in saved_c
                        final userData =
                            (await userDoc.get()).data()
                                as Map<String, dynamic>? ??
                            {};
                        final List<dynamic> savedList =
                            userData['saved_c'] ?? [];

                        dynamic existingEntry;
                        try {
                          existingEntry = savedList.firstWhere((entry) {
                            if (entry is Map<String, dynamic>) {
                              return entry['complaintId'] == doc.id;
                            } else if (entry is String) {
                              return entry == doc.id;
                            }
                            return false;
                          });
                        } catch (_) {}

                        if (existingEntry != null) {
                          // Remove old entry
                          await userDoc.update({
                            'saved_c': FieldValue.arrayRemove([existingEntry]),
                          });

                          // Add new entry with updated count
                          final newEntry = {
                            'complaintId': doc.id,
                            'last_seen_update_count': currentUpdateCount,
                          };
                          await userDoc.update({
                            'saved_c': FieldValue.arrayUnion([newEntry]),
                          });
                        }
                      },
                      child: Column(
                        children: [
                          // Status bar at the top
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
                          // Card content
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // First row: Issue type tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Second row: Save button and timeago display in one row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        SaveButton(
                                          complaintId: doc.id,
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                                                  style: theme.textTheme.labelSmall?.copyWith(
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
                                // Complaint text
                                Text(
                                data['original_text'] ?? 'No details available',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                                const SizedBox(height: 18),
                                // Location and status row
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
                                // Show "Updated" indicator if there are new updates
                                if (showUpdateBanner)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.update,
                                          size: 16,
                                          color: theme.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Updated',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
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
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _isComplaintInSavedCForCurrentUser(String complaintId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final List<dynamic> savedList = userData['saved_c'] ?? [];
    return savedList.any((entry) {
      if (entry is Map<String, dynamic>) {
        return entry['complaintId'] == complaintId;
      } else if (entry is String) {
        return entry == complaintId;
      }
      return false;
    });
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

        final existingEntry = savedList.firstWhere((entry) {
          if (entry is Map<String, dynamic>) {
            return entry['complaintId'] == complaintId;
          } else if (entry is String) {
            return entry == complaintId;
          }
          return false;
        }, orElse: () => null);

        final isSaved = (existingEntry != null);

        return GestureDetector(
          onTap: () async {
            final userDoc = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);
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
