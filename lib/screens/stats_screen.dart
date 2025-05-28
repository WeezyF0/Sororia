import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gemini_service.dart'; // Import your GeminiService

class StatsScreen extends StatefulWidget {
  final String category;

  const StatsScreen({super.key, required this.category});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late List<String> _issueTypes;
  String _summary = "";
  bool _isLoading = true;
  int _complaintCount = 0;
  String _safetyRating = "N/A";
  String _trend = "N/A";
  String _responseRate = "N/A";

  @override
  void initState() {
    super.initState();
    _mapCategoryToIssueTypes();
    _loadData();
  }

  void _mapCategoryToIssueTypes() {
    switch (widget.category) {
      case 'Nightlife Safety':
        _issueTypes = ['nightlife', 'entertainment', 'social'];
        break;
      case 'City Wide Safety':
        _issueTypes = ['public', 'infrastructure', 'environmental'];
        break;
      case 'Workspace Safety':
        _issueTypes = ['workplace', 'professional', 'institutional'];
        break;
      case 'Educational Space Safety':
        _issueTypes = ['educational', 'campus', 'academic'];
        break;
      case 'Public Transport Safety':
        _issueTypes = ['transport', 'commute', 'transit'];
        break;
      default:
        _issueTypes = [];
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final complaints = await _fetchComplaints();
      _complaintCount = complaints.length;
      _calculateMetrics(complaints);

      if (complaints.isNotEmpty) {
        print("Generating summary for ${complaints.length} complaints");
        final complaintsText = complaints.join('\n\n');
        final geminiService = Provider.of<GeminiService>(
          context,
          listen: false,
        );

        try {
          _summary = await geminiService.generateSummary(
            complaintsText,
            widget.category,
          );
          print("Successfully generated AI summary");
        } catch (e) {
          print("Error generating AI summary: $e");
          _summary = "AI Summary unavailable. ${_getStaticSummary()}";
        }
      } else {
        print("No complaints found, using static summary");
        _summary = _getStaticSummary();
      }
    } catch (e) {
      print("Error in _loadData: $e");
      _summary = "Error loading data. ${_getStaticSummary()}";
    }

    setState(() => _isLoading = false);
  }

  Future<List<String>> _fetchComplaints() async {
    try {
      print("Fetching complaints for issue types: $_issueTypes");

      final snapshot =
          await FirebaseFirestore.instance
              .collection('complaints')
              .where(
                'issue_tags',
                arrayContainsAny: _issueTypes,
              ) // Changed to arrayContainsAny
              .limit(100)
              .get();

      print("Found ${snapshot.docs.length} documents");

      final results =
          snapshot.docs
              .map((doc) => doc['original_text'] as String? ?? "No description")
              .toList();

      print(
        "First complaint text: ${results.isNotEmpty ? results.first : 'N/A'}",
      );
      return results;
    } catch (e) {
      print("Error fetching complaints: $e");
      return [];
    }
  }

  void _calculateMetrics(List<String> complaints) {
    // Simple metric calculations based on complaint count
    // In a real app, you would analyze actual data

    final count = complaints.length;

    if (count == 0) {
      _safetyRating = "N/A";
      _trend = "N/A";
      _responseRate = "N/A";
      return;
    }

    // Safety rating: Higher rating for fewer complaints
    final rating = 9.0 - (count / 50).clamp(0.0, 8.0);
    _safetyRating = "${rating.toStringAsFixed(1)}/10";

    // Trend: Simulated improvement based on count
    final trendValue = (10 - (count / 20)).clamp(1, 15).toInt();
    _trend = "↓ $trendValue%";

    // Response rate: Higher for fewer complaints
    final response = 95 - (count / 10).clamp(0, 30);
    _responseRate = "${response.toInt()}%";
  }

  String _getStaticSummary() {
    return "summary";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = textColor.withOpacity(0.7);

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
                    children: [
                      Expanded(
                        child: Text(
                          "${widget.category} Statistics",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
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
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(),
                            size: 36,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            widget.category,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Safety Summary Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Safety Intelligence Summary",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _summary,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: secondaryTextColor,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Statistics Section
                    Text(
                      "Safety Metrics",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildStatCardWithBar(
                          context,
                          title: "Total Reports",
                          value: "N/A",
                          barValue: 0.5, // Half bar for placeholder
                          icon: Icons.assignment,
                          color: theme.primaryColor,
                        ),
                        _buildStatCardWithBar(
                          context,
                          title: "Severity Level",
                          value: "N/A",
                          barValue: 0.3, // Partial bar for placeholder
                          icon: Icons.warning,
                          color: theme.primaryColor,
                        ),
                        _buildStatCardWithBar(
                          context,
                          title: "Response Rate",
                          value: "N/A",
                          barValue: 0.7, // Partial bar for placeholder
                          icon: Icons.quickreply,
                          color: theme.primaryColor,
                        ),
                        _buildStatCardWithBar(
                          context,
                          title: "Resolution Rate",
                          value: "N/A",
                          barValue: 0.4, // Partial bar for placeholder
                          icon: Icons.check_circle,
                          color: theme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case 'Nightlife Safety':
        return Icons.nightlife;
      case 'City Wide Safety':
        return Icons.location_city;
      case 'Workspace Safety':
        return Icons.work;
      case 'Educational Space Safety':
        return Icons.school;
      case 'Public Transport Safety':
        return Icons.directions_bus;
      default:
        return Icons.security;
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: theme.primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildStatCardWithBar(
  BuildContext context, {
  required String title,
  required String value,
  required double barValue,
  required IconData icon,
  required Color color,
}) {
  final theme = Theme.of(context);
  final barHeight = 5.0;

  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(value),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: barHeight,
                child: Stack(
                  children: [
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: barValue.clamp(0.0, 1.0),
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${value == "N/A" ? "—" : (barValue * 100).toStringAsFixed(0) + "%"}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
