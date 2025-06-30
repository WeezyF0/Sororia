import 'package:flutter/material.dart';
import 'navbar.dart';
import 'stats_screen.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Static summaries for demonstration
    const safetySummaries = [
      {
        'title': 'Nightlife Safety',
        'summary':
            'Focuses on safety conditions during evening and night hours across the city. Addresses visibility issues in poorly lit areas, safety in entertainment districts after dark, and recommended precautions when navigating the city at night.',
        'icon': Icons.nightlife,
        'color': Colors.purple,
      },
      {
        'title': 'City Wide Safety',
        'summary':
            'Overall safety assessment across different neighborhoods and districts. Provides information about crime trends, police presence, and general safety recommendations for residents and visitors throughout the city.',
        'icon': Icons.location_city,
        'color': Colors.blue,
      },
      {
        'title': 'Workspace Safety',
        'summary':
            'Examines safety conditions in office environments, construction sites, and other workplaces. Covers common workplace hazards, compliance with safety regulations, and efforts to create secure working environments.',
        'icon': Icons.work,
        'color': Colors.green,
      },
      {
        'title': 'Educational Space Safety',
        'summary':
            'Focuses on safety in schools, colleges, and other educational institutions. Addresses physical security, bullying prevention, mental health support, and initiatives to create safe learning environments for students and staff.',
        'icon': Icons.school,
        'color': Colors.orange,
      },
      {
        'title': 'Public Transport Safety',
        'summary':
            'Evaluates safety on buses, trains, metros and other public transportation. Includes information about security measures, common incidents, and safety tips for commuters using public transit throughout the city.',
        'icon': Icons.directions_bus,
        'color': Colors.teal,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 4,
        shadowColor:
            isDark
                ? Colors.purple.withOpacity(0.2)
                : Colors.pink.withOpacity(0.2),
        centerTitle: true,
        title: Text(
          "SAFETY SUMMARY",
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
            letterSpacing: 1.2,
          ),
        ),
      ),
      drawer: const NavBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                "Safety Overview by Category",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ...safetySummaries.map(
              (summary) => _buildSummaryCard(
                context: context,
                title: summary['title'] as String,
                summary: summary['summary'] as String,
                icon: summary['icon'] as IconData,
                color: summary['color'] as Color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String summary,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StatsScreen(category: title),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isDark ? 0.18 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatsScreen(category: title),
                      ),
                    );
                  },
                  child: const Text("View detailed statistics →"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
