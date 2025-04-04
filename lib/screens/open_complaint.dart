import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OpenComplaintScreen extends StatefulWidget {
  final Map<String, dynamic> complaintData;
  final String complaintId;

  const OpenComplaintScreen({
    super.key,
    required this.complaintData,
    required this.complaintId,
  });

  @override
  State<OpenComplaintScreen> createState() => _OpenComplaintScreenState();
}

class _OpenComplaintScreenState extends State<OpenComplaintScreen> {
  final ComplaintAnalyzer _analyzer = ComplaintAnalyzer();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _analysisResult = {};
  bool _isAnalyzing = false;
  final TextEditingController _updateController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analyzeComplaint();
  }

  @override
  void dispose() {
    _isAnalyzing = false;
    _updateController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _analyzeComplaint() async {
    if (_isAnalyzing || !mounted) return;

    try {
      _isAnalyzing = true;
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      double? latitude;
      double? longitude;
      if (widget.complaintData.containsKey('latitude') &&
          widget.complaintData.containsKey('longitude')) {
        latitude = (widget.complaintData['latitude'] as num).toDouble();
        longitude = (widget.complaintData['longitude'] as num).toDouble();
      }

      final result = await _analyzer.analyzeComplaint(
        widget.complaintData['location'] ?? 'Unknown location',
        widget.complaintData['original_text'] ?? 'No experience text',
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to analyze experience: ${e.toString()}';
        });
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  void _navigateToChatbot() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('complaints')
              .doc(widget.complaintId)
              .get();

      if (doc.exists) {
        final complaintData = doc.data();
        final String complaintInfo = complaintData.toString();
        Navigator.pushNamed(context, '/chatbot', arguments: complaintInfo);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Complaint not found.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch complaint: $e')));
    }
  }

  Future<bool> _isComplaintInSavedC() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
    final userData = userDoc.data();
    if (userData == null) return false;

    final List<dynamic> savedComplaints =
        userData['saved_c'] as List<dynamic>? ?? [];
    return savedComplaints.any((entry) {
      if (entry is Map<String, dynamic>) {
        return entry['complaintId'] == widget.complaintId;
      } else if (entry is String) {
        return entry == widget.complaintId;
      }
      return false;
    });
  }

  Future<void> _showAddUpdateDialog() async {
    final isInSavedC = await _isComplaintInSavedC();
    if (!isInSavedC) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must have saved this experience to add an update.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Update'),
            content: TextField(
              controller: _updateController,
              decoration: const InputDecoration(
                hintText: 'Enter update details...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_updateController.text.isEmpty) return;
                  await _addUpdateToFirestore(_updateController.text);
                  Navigator.pop(context);
                  _updateController.clear();
                },
                child: const Text('Add Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _addUpdateToFirestore(String updateText) async {
    try {
      final updateData = {
        'context': updateText,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaintId)
          .update({
            'Updates': FieldValue.arrayUnion([updateData]),
            'update_count': FieldValue.increment(1),
          });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add update: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Colors.purple.withOpacity(0.3),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color:
                              theme.appBarTheme.iconTheme?.color ??
                              Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "EXPERIENCE DETAILS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color:
                              theme.appBarTheme.iconTheme?.color ??
                              Colors.white,
                        ),
                        onPressed: _analyzeComplaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildAnalysisView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToChatbot,
        icon: const Icon(Icons.chat),
        label: const Text('SororiAI Assistance'),
      ),
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _analyzeComplaint,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComplaintCard(),
          const SizedBox(height: 16),
          _buildChatbotRedirectCard(),
          const SizedBox(height: 16),
          _buildCommentCard(),
          const SizedBox(height: 16),
          _buildNewsSection(),
        ],
      ),
    );
  }

  Widget _buildComplaintCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.complaintData['issue_type'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.complaintData['issue_type'],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              widget.complaintData['original_text'] ?? 'No experience text',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.iconTheme.color ?? Colors.black54,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.complaintData['location'] ?? 'Unknown location',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (widget.complaintData['timestamp'] != null)
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: theme.iconTheme.color ?? Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(widget.complaintData['timestamp']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('complaints')
                      .doc(widget.complaintId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error loading updates.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final docData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final updates = docData['Updates'] as List<dynamic>? ?? [];

                updates.sort((a, b) {
                  final aTime =
                      DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
                  final bTime =
                      DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
                  return bTime.compareTo(aTime);
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          updates.isEmpty
                              ? 'No updates available.'
                              : 'Latest Update:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: _isComplaintInSavedC(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final isInSavedC = snapshot.data ?? false;
                            return isInSavedC
                                ? IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _showAddUpdateDialog,
                                )
                                : const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    if (updates.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            updates.first['context'] ?? 'No update details.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            title: const Text('Show all updates'),
                            children:
                                updates.map<Widget>((update) {
                                  final updateMap =
                                      update as Map<String, dynamic>;
                                  return ListTile(
                                    leading: const Icon(Icons.update, size: 20),
                                    title: Text(
                                      _formatTimestamp(
                                        updateMap['timestamp'] ?? '',
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    subtitle: Text(
                                      updateMap['context'] ??
                                          'No update details.',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('complaints')
                  .doc(widget.complaintId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Error loading comments',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docData =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final comments = docData['Comments'] as List<dynamic>? ?? [];

            comments.sort((a, b) {
              final aTime =
                  DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(1970);
              final bTime =
                  DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(1970);
              return bTime.compareTo(aTime);
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comments',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.expand),
                      onPressed: () => _showAllCommentsDialog(context, theme),
                      tooltip: 'Show all comments',
                    ),
                  ],
                ),
                if (comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No comments yet',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (comments.isNotEmpty)
                  _buildFirstComment(
                    comments.first as Map<String, dynamic>,
                    theme,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFirstComment(Map<String, dynamic> comment, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: theme.primaryColor,
              child: Text(
                (comment['user_id']?.toString().substring(0, 2) ?? '??')
                    .toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              maskUserId(comment['user_id']?.toString()),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTimeAgo(comment['timestamp']?.toString() ?? ''),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          comment['context']?.toString() ?? 'No comment text',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  String maskUserId(String? userId) {
    if (userId == null || userId.length < 3) {
      return userId ?? "";
    }
    
    return "${userId.substring(0, userId.length - 3)}\$\$\$";
  }

  void _showAllCommentsDialog(BuildContext context, ThemeData theme) {
    final commentsStream =
        FirebaseFirestore.instance
            .collection('complaints')
            .doc(widget.complaintId)
            .snapshots();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: commentsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docData = snapshot.data!.data() as Map<String, dynamic>;
                  final comments = docData['Comments'] as List<dynamic>? ?? [];

                  comments.sort((a, b) {
                    final aTime =
                        DateTime.tryParse(a['timestamp'] ?? '') ??
                        DateTime(1970);
                    final bTime =
                        DateTime.tryParse(b['timestamp'] ?? '') ??
                        DateTime(1970);
                    return bTime.compareTo(aTime);
                  });

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header and close button
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Comments',
                              style: theme.textTheme.titleLarge,
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: theme.colorScheme.onSurface,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Comments list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          shrinkWrap: true,
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index] as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: theme.primaryColor,
                                        child: Text(
                                          (comment['user_id']?.toString().substring(
                                                    0,
                                                    2,
                                                  ) ??
                                                  '??')
                                              .toUpperCase(),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.onPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        maskUserId(comment['user_id']?.toString()),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimeAgo(
                                          comment['timestamp']?.toString() ?? '',
                                        ),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.textTheme.bodySmall?.color
                                              ?.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment['context']?.toString() ??
                                        'No comment text',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Input field
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: theme.colorScheme.onPrimary,
                                ),
                                onPressed: () async {
                                  await _addCommentToFirestore(
                                    _commentController.text,
                                  );
                                  _commentController.clear();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
    );
  }

  Future<String> _getUserEmail(String? userId) async {
    if (userId == null || userId.isEmpty) return 'Anonymous';

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      return doc.data()?['email'] ?? 'Anonymous';
    } catch (e) {
      return 'Anonymous';
    }
  }

  // Modify the _buildCommentItem widget
  Widget _buildCommentItem(Map<String, dynamic> comment, ThemeData theme) {
    return FutureBuilder<String>(
      future: _getUserEmail(comment['user_id']?.toString()),
      builder: (context, snapshot) {
        final email = snapshot.data ?? 'Anonymous';
        final initials = email.substring(0, 2).toUpperCase();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTimeAgo(comment['timestamp']?.toString() ?? ''),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comment['context']?.toString() ?? 'No comment text',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCommentToFirestore(String commentText) async {
    if (commentText.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to comment')),
      );
      return;
    }

    try {
      final commentData = {
        'user_id': currentUser.uid,
        'context': commentText,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaintId)
          .update({
            'Comments': FieldValue.arrayUnion([commentData]),
            'comment_count': FieldValue.increment(1),
          });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
      );
    }
  }

  String _formatTimeAgo(String timestamp) {
    final dateTime = DateTime.tryParse(timestamp);
    if (dateTime == null) return 'Unknown time';

    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildChatbotRedirectCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: _navigateToChatbot,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Need Help?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Our chatbot SororiAI is always ready to assist you!',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _navigateToChatbot,
                  icon: const Icon(Icons.chat),
                  label: const Text('Open SororiAI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSection() {
    final theme = Theme.of(context);
    final newsResults = _analysisResult['news_results'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Related News',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (newsResults.isEmpty)
              Text('No related news found.', style: theme.textTheme.bodyMedium),
            for (var news in newsResults)
              Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          final url = news['link'];
                          if (url != null) {
                            launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Text(
                          news['title'] ?? 'No Title',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        news['snippet'] ?? 'No snippet available.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            final url = news['link'];
                            if (url != null) {
                              launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: const Text('Read More'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ComplaintAnalyzer {
  late final String? _serperApiKey;

  ComplaintAnalyzer() {
    _serperApiKey = dotenv.env['serper-api'];
    if (_serperApiKey == null) {
      throw Exception('Missing API Key: Ensure serper-api key is present.');
    }
  }

  ComplaintAnalyzer.withKey(this._serperApiKey) {
    if (_serperApiKey == null) {
      throw Exception('Missing API Key: Serper API key must be provided.');
    }
  }

  Future<List<Map<String, dynamic>>> _searchOnline(
    String location,
    String problem,
  ) async {
    final response = await http.post(
      Uri.parse("https://google.serper.dev/search"),
      headers: {
        "X-API-KEY": _serperApiKey!,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"q": "$problem in $location", "num": 5}),
    );

    if (response.statusCode == 200) {
      List<dynamic> results = jsonDecode(response.body)["organic"] ?? [];
      return results
          .map(
            (r) => {
              "title": r["title"] ?? "No Title",
              "link": r["link"] ?? "#",
              "snippet": r["snippet"] ?? "No snippet available.",
            },
          )
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> analyzeComplaint(
    String location,
    String problem, {
    double? latitude,
    double? longitude,
  }) async {
    location = location.trim();
    problem = problem.trim();

    if (location.isEmpty || problem.isEmpty) {
      return {"error": "Both 'location' and 'problem' fields are required!"};
    }

    List<Map<String, dynamic>> newsResults = await _searchOnline(
      location,
      problem,
    );

    return {
      "location": location,
      "problem": problem,
      "news_results": newsResults,
      "coordinates":
          (latitude != null && longitude != null)
              ? {"latitude": latitude, "longitude": longitude}
              : null,
    };
  }
}
