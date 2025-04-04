import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'navbar.dart';
import 'package:flutter/cupertino.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  String selectedSort = 'Recent';
  final sortOptions = ['Recent', 'Most Upvoted'];

  // Map to track ongoing upvote operations
  final Map<String, bool> _upvoteInProgress = {};

  // Map to track optimistic upvote states
  final Map<String, int> _optimisticUpvotes = {};

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
          titleSpacing: 0, // Remove default title spacing
          title: Padding(
            padding: EdgeInsets.only(
              left: 16.0,
            ), // Add padding to offset from drawer icon
            child: Text(
              "ALL EXPERIENCES",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          ),
          actions: [
            // Sort dropdown in the actions area
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: selectedSort,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  dropdownColor: theme.primaryColor,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedSort = newValue;
                      });
                    }
                  },
                  items:
                      sortOptions.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ),
          ],
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
      body: StreamBuilder(
        stream:
            selectedSort == 'Recent'
                ? FirebaseFirestore.instance
                    .collection('complaints')
                    .orderBy('timestamp_ms', descending: true)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('complaints')
                    .orderBy('upvotes', descending: true)
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
                    'No experiences found',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share an experience to get started',
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

              // Get the actual or optimistic upvote count
              final upvotes =
                  _optimisticUpvotes.containsKey(doc.id)
                      ? _optimisticUpvotes[doc.id]!
                      : (data['upvotes'] ?? 0);

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
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with issue type and date
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First row: Issue type tag
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
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Second row: Save button, upvote button and timeago display in one row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SaveButton(complaintId: doc.id),
                                    const SizedBox(width: 8),
                                    UpvoteButton(
                                      complaintId: doc.id,
                                      theme: theme,
                                      currentUpvotes: upvotes,
                                      isLoading:
                                          _upvoteInProgress[doc.id] ?? false,
                                      onUpvote:
                                          () => _handleUpvote(doc.id, upvotes),
                                    ),
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
                            SizedBox(height: 16),

                            // Complaint text with better styling
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
                            SizedBox(height: 18),

                            // Footer with location only
                            Container(
                              padding: EdgeInsets.symmetric(
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
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      data['location'] ?? 'Unknown location',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleUpvote(String complaintId, int currentUpvotes) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Check if upvote is already in progress
    if (_upvoteInProgress[complaintId] == true) return;

    // Get user document to check if already upvoted
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final upvotedList = (userDoc.data()?['upvoted'] as List<dynamic>?) ?? [];
    final hasUpvoted = upvotedList.contains(complaintId);

    // Set optimistic state
    setState(() {
      _upvoteInProgress[complaintId] = true;
      _optimisticUpvotes[complaintId] =
          hasUpvoted ? currentUpvotes - 1 : currentUpvotes + 1;
    });

    try {
      // Perform the actual update
      final complaintDoc = FirebaseFirestore.instance
          .collection('complaints')
          .doc(complaintId);
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);

      if (hasUpvoted) {
        // Remove upvote
        await userDocRef.update({
          'upvoted': FieldValue.arrayRemove([complaintId]),
        });
        await complaintDoc.update({'upvotes': FieldValue.increment(-1)});
      } else {
        // Add upvote
        await userDocRef.update({
          'upvoted': FieldValue.arrayUnion([complaintId]),
        });
        await complaintDoc.update({'upvotes': FieldValue.increment(1)});
      }
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _optimisticUpvotes[complaintId] = currentUpvotes;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Clear loading state
      setState(() {
        _upvoteInProgress[complaintId] = false;
      });
    }
  }
}

// Move UpvoteButton out of the class as a separate widget
class UpvoteButton extends StatelessWidget {
  final String complaintId;
  final ThemeData theme;
  final int currentUpvotes;
  final bool isLoading;
  final VoidCallback onUpvote;

  const UpvoteButton({
    super.key,
    required this.complaintId,
    required this.theme,
    required this.currentUpvotes,
    required this.isLoading,
    required this.onUpvote,
  });

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

        final upvotedList =
            (snapshot.data?.data() as Map<String, dynamic>?)?['upvoted'] ?? [];
        final hasUpvoted = upvotedList.contains(complaintId);

        return Row(
          children: [
            InkWell(
              onTap: isLoading ? null : onUpvote,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    isLoading
                        ? SpinKitFadingCircle(
                          color: theme.primaryColor,
                          size: 16,
                        )
                        : Icon(
                          hasUpvoted
                              ? CupertinoIcons.shift_fill
                              : CupertinoIcons.shift,
                          size: 16,
                          color:
                              hasUpvoted
                                  ? theme.primaryColor
                                  : theme.colorScheme.onSurface.withOpacity(
                                    0.6,
                                  ),
                        ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              currentUpvotes.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

// Add the missing SaveButton widget
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
