import 'package:flutter/material.dart';
import 'package:complaints_app/screens/navbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  child: Text(
                    "Sororia",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDark
                  ? 'assets/images/home_bg_night.jpg'
                  : 'assets/images/home_bg_day.jpg',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What would you like to do?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth > 600 ? 3 : 2,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 12.0,
                        mainAxisSpacing: 12.0,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _buildCard(
                              context,
                              title: "Issues Map",
                              icon: Icons.map_outlined,
                              color: Colors.blue,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/complaints_map',
                              ),
                              description: "View experiences in your area",
                            );
                          case 1:
                            return _buildCard(
                              context,
                              title: "Start a Petition",
                              icon: Icons.assignment_outlined,
                              color: Colors.green,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/add_petition',
                              ),
                              description: "Create a new petition",
                            );
                          case 2:
                            return _buildCard(
                              context,
                              title: "Share Experience",
                              icon: Icons.add_comment_outlined,
                              color: Colors.orange,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/add_complaint',
                              ),
                              description: "Share your experience with others",
                            );
                          case 3:
                            return _buildCard(
                              context,
                              title: "Local News",
                              icon: Icons.newspaper_outlined,
                              color: Colors.purple,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/news',
                              ),
                              description: "Check the latest local news",
                            );
                          default:
                            return SizedBox();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? color.withOpacity(0.7) : color.withOpacity(0.9),
                isDark ? color.withOpacity(0.4) : color.withOpacity(0.7),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: Colors.white),
                Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
