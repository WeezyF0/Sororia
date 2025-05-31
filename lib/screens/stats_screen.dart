import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsScreen extends StatefulWidget {
  final String category;

  const StatsScreen({super.key, required this.category});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool isLoading = true;
  Map<String, dynamic> statsData = {};
  List<Map<String, dynamic>> recentComplaints = [];

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
    _fetchStatsData();
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
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < weeklyData.length) {
                            return Text(
                              weeklyData.keys.toList()[index],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(entry.key),
                  ),
                  Container(
                    width: 100,
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
                  const SizedBox(width: 8),
                  Text(entry.value.toString()),
                ],
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
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        complaint['location'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
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
            )),
          ],
        ),
      ),
    );
  }
}