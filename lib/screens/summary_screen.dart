import 'package:flutter/material.dart';
import 'navbar.dart';
import 'stats_screen.dart'; // We'll create this next

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        "SAFETY SUMMARY",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                "Safety Overview by Category",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StatsScreen(category: title),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "View detailed statistics →",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
