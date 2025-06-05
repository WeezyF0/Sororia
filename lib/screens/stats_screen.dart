import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Add this dependency

class StatsScreen extends StatefulWidget {
  final String category;

  const StatsScreen({super.key, required this.category});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool isLoading = true;
  bool isSummaryLoading = false;
  Map<String, dynamic> statsData = {};
  List<Map<String, dynamic>> recentComplaints = [];
  String? aiSummary;
  bool showSummary = false;

  // Get API key from .env file
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  late final GenerativeModel _model;

  // Map categories to their corresponding issue types
  final Map<String, List<String>> categoryMapping = {
    'Nightlife Safety': ['Night', 'Safety', 'Social'],
    'City Wide Safety': ['City', 'Public', 'Safety'],
    'Workspace Safety': ['Workplace', 'Professional', 'Safety'],
    'Educational Space Safety': ['Education', 'Institutional', 'Safety'],
    'Public Transport Safety': ['Transport', 'Public', 'Safety'],
  };

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _fetchStatsData();
  }

  void _initializeGemini() {
    if (_geminiApiKey.isEmpty) {
      print('Warning: GEMINI_API_KEY not found in .env file');
      return;
    }
    
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: _geminiApiKey,
    );
  }

  Future<void> _generateAISummary() async {
    if (statsData.isEmpty || _geminiApiKey.isEmpty) {
      setState(() {
        aiSummary = 'API key not configured. Please add GEMINI_API_KEY to your .env file.';
        showSummary = true;
      });
      return;
    }

    setState(() {
      isSummaryLoading = true;
    });

    try {
      final prompt = _buildPromptFromStats();
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      setState(() {
        aiSummary = response.text;
        showSummary = true;
        isSummaryLoading = false;
      });
    } catch (e) {
      print('Error generating AI summary: $e');
      setState(() {
        aiSummary = 'Failed to generate summary. Please check your API key and try again.\n\nError: ${e.toString()}';
        showSummary = true;
        isSummaryLoading = false;
      });
    }
  }

  String _buildPromptFromStats() {
    final totalComplaints = statsData['totalComplaints'] ?? 0;
    final avgUpvotes = statsData['avgUpvotes'] ?? 0.0;
    final topLocations = statsData['topLocations'] as Map<String, int>? ?? {};
    final issueTypes = statsData['issueTypeDistribution'] as Map<String, int>? ?? {};
    final weeklyTrend = statsData['weeklyTrend'] as Map<String, int>? ?? {};

    // Get top 3 locations
    final sortedLocations = topLocations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3Locations = sortedLocations.take(3).toList();

    // Get top 3 issue types
    final sortedIssues = issueTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3Issues = sortedIssues.take(3).toList();

    // Calculate weekly trend
    final weeklyValues = weeklyTrend.values.toList();
    String trendDescription = "stable";
    if (weeklyValues.length >= 2) {
      final recent = weeklyValues.length >= 3 
          ? weeklyValues.sublist(weeklyValues.length - 3).fold(0, (a, b) => a + b)
          : weeklyValues.last;
      final earlier = weeklyValues.length >= 4 
          ? weeklyValues.sublist(0, 4).fold(0, (a, b) => a + b)
          : (weeklyValues.length > 1 ? weeklyValues.first : 0);
      if (recent > earlier) {
        trendDescription = "increasing";
      } else if (recent < earlier) {
        trendDescription = "decreasing";
      }
    }

    return '''
Analyze the following safety complaint statistics for ${widget.category} and provide a comprehensive summary with insights and recommendations. Please format your response using Markdown for better readability:

**STATISTICS OVERVIEW:**
- Total Complaints: $totalComplaints
- Average Upvotes per Complaint: ${avgUpvotes.toStringAsFixed(1)}
- Weekly Trend: $trendDescription

**TOP AFFECTED LOCATIONS:**
${top3Locations.map((e) => '- ${e.key}: ${e.value} complaints').join('\n')}

**MOST COMMON ISSUE TYPES:**
${top3Issues.map((e) => '- ${e.key}: ${e.value} occurrences').join('\n')}

**RECENT COMPLAINT SAMPLES:**
${recentComplaints.take(3).map((c) => '- "${c['text']}" at ${c['location']} (${c['upvotes']} upvotes)').join('\n')}

Please provide your analysis using proper Markdown formatting with:
1. **Brief Overview** of the current situation
2. **Key Trends & Patterns** identified
3. **Priority Areas** that need immediate attention
4. **Actionable Recommendations** for improvement
5. **Preventive Measures** to consider

Use headers, bullet points, and emphasis to make the summary clear and actionable for safety improvement initiatives.
''';
  }

  Future<void> _fetchStatsData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final complaintsRef = firestore.collection('complaints');

      // Get relevant issue types for this category
      final List<String> relevantTags = categoryMapping[widget.category] ?? [];
      
      // Fetch all complaints
      final QuerySnapshot allComplaints = await complaintsRef.get();
      
      // Filter complaints by category
      final List<QueryDocumentSnapshot> categoryComplaints = allComplaints.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final issueTypes = data['issue_type']?.toString().split(',') ?? [];
        
        return issueTypes.any((type) => relevantTags.contains(type.trim()));
      }).toList();

      // Calculate statistics
      await _calculateStats(categoryComplaints);

    } catch (e) {
      print('Error fetching stats: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _calculateStats(List<QueryDocumentSnapshot> complaints) async {
    if (complaints.isEmpty) {
      statsData = {
        'totalComplaints': 0,
        'avgUpvotes': 0.0,
        'topLocations': <String, int>{},
        'issueTypeDistribution': <String, int>{},
        'weeklyTrend': <String, int>{},
      };
      return;
    }

    // Total complaints
    final int totalComplaints = complaints.length;

    // Average upvotes
    final int totalUpvotes = complaints.fold(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      return sum + (data['upvotes'] ?? 0) as int;
    });
    final double avgUpvotes = totalUpvotes / totalComplaints;

    // Top locations
    final Map<String, int> locationCount = {};
    for (var doc in complaints) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['location']?.toString() ?? 'Unknown';
      locationCount[location] = (locationCount[location] ?? 0) + 1;
    }

    // Issue type distribution
    final Map<String, int> issueTypeCount = {};
    for (var doc in complaints) {
      final data = doc.data() as Map<String, dynamic>;
      final issueTypes = data['issue_type']?.toString().split(',') ?? [];
      for (String type in issueTypes) {
        final cleanType = type.trim();
        issueTypeCount[cleanType] = (issueTypeCount[cleanType] ?? 0) + 1;
      }
    }

    // Weekly trend (last 7 days)
    final Map<String, int> weeklyTrend = {};
    final DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.day}/${date.month}';
      weeklyTrend[dateKey] = 0;
    }

    for (var doc in complaints) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp']?.toString();
      if (timestamp != null) {
        try {
          final DateTime complaintDate = DateTime.parse(timestamp);
          final daysDiff = now.difference(complaintDate).inDays;
          if (daysDiff <= 6) {
            final dateKey = '${complaintDate.day}/${complaintDate.month}';
            if (weeklyTrend.containsKey(dateKey)) {
              weeklyTrend[dateKey] = weeklyTrend[dateKey]! + 1;
            }
          }
        } catch (e) {
          print('Error parsing timestamp: $e');
        }
      }
    }

    // Recent complaints (last 5)
    complaints.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['timestamp_ms'] ?? 0;
      final bTime = bData['timestamp_ms'] ?? 0;
      return bTime.compareTo(aTime);
    });

    recentComplaints = complaints.take(5).map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'text': data['processed_text'] ?? data['original_text'] ?? 'No description',
        'location': data['location'] ?? 'Unknown',
        'upvotes': data['upvotes'] ?? 0,
        'timestamp': data['timestamp'] ?? '',
        'issue_type': data['issue_type'] ?? '',
      };
    }).toList();

    statsData = {
      'totalComplaints': totalComplaints,
      'avgUpvotes': avgUpvotes,
      'topLocations': locationCount,
      'issueTypeDistribution': issueTypeCount,
      'weeklyTrend': weeklyTrend,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: statsData.isNotEmpty ? _generateAISummary : null,
            tooltip: 'Generate AI Summary',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCards(theme),
                  const SizedBox(height: 24),
                  if (showSummary) ...[
                    _buildAISummaryCard(theme),
                    const SizedBox(height: 24),
                  ],
                  _buildWeeklyTrendChart(theme),
                  const SizedBox(height: 24),
                  _buildTopLocationsChart(theme),
                  const SizedBox(height: 24),
                  _buildIssueTypeDistribution(theme),
                  const SizedBox(height: 24),
                  _buildRecentComplaints(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildAISummaryCard(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded( // Fix overflow here
                  child: Text(
                    'Gen-AI Insights',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => showSummary = false),
                  tooltip: 'Close Summary',
                ),
              ],
            ),
            const Divider(),
            if (isSummaryLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating AI insights...'),
                    ],
                  ),
                ),
              )
                          else if (aiSummary != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: aiSummary!,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontSize: 14,
                      ),
                      h1: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                        fontSize: 20,
                      ),
                      h2: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                        fontSize: 18,
                      ),
                      h3: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                        fontSize: 16,
                      ),
                      listBullet: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                      ),
                      strong: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      em: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      blockquote: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      code: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        backgroundColor: Colors.grey[200],
                        fontSize: 13,
                      ),
                    ),
                    selectable: true,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap( // Use Wrap instead of Row to prevent overflow
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Powered by Gemini 2.0 Flash',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _generateAISummary,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Regenerate'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(ThemeData theme) {
    final totalComplaints = statsData['totalComplaints'] ?? 0;
    final avgUpvotes = (statsData['avgUpvotes'] ?? 0.0).toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.report, size: 32, color: theme.primaryColor),
                  const SizedBox(height: 8),
                  Text(
                    totalComplaints.toString(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total Complaints',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.thumb_up, size: 32, color: Colors.green),
                  const SizedBox(height: 8),
                  Text(
                    avgUpvotes,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Avg Upvotes',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildWeeklyTrendChart(ThemeData theme) {
    final weeklyData = statsData['weeklyTrend'] as Map<String, int>? ?? {};
    
    if (weeklyData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Weekly Stats', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('No data available for the past week'),
            ],
          ),
        ),
      );
    }

    final spots = weeklyData.entries.toList().asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Weekly Stats (Last 7 Days)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            LayoutBuilder( // Use LayoutBuilder for responsive chart
              builder: (context, constraints) {
                return SizedBox(
                  height: 200,
                  width: constraints.maxWidth,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < weeklyData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    weeklyData.keys.toList()[index],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: theme.primaryColor,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: theme.primaryColor.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopLocationsChart(ThemeData theme) {
    final locations = statsData['topLocations'] as Map<String, int>? ?? {};
    
    if (locations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Top Locations', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('No location data available'),
            ],
          ),
        ),
      );
    }

    final sortedLocations = locations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLocations = sortedLocations.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Affected Locations', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...topLocations.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LayoutBuilder( // Use LayoutBuilder for responsive bars
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry.key,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: entry.value / topLocations.first.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 30,
                        child: Text(
                          entry.value.toString(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueTypeDistribution(ThemeData theme) {
    final issueTypes = statsData['issueTypeDistribution'] as Map<String, int>? ?? {};
    
    if (issueTypes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Issue Type Distribution', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('No issue type data available'),
            ],
          ),
        ),
      );
    }

    final sortedTypes = issueTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue Type Distribution', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedTypes.map((entry) => Chip(
                label: Text('${entry.key} (${entry.value})'),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentComplaints(ThemeData theme) {
    if (recentComplaints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Recent Complaints', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('No recent complaints available'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Complaints', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ...recentComplaints.map((complaint) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint['text'],
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap( // Use Wrap instead of Row for responsive layout
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              complaint['location'],
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.thumb_up, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            complaint['upvotes'].toString(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}