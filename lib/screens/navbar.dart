import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  // Helper function to create Poppins text style to avoid repetition
  TextStyle _poppinsStyle({
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.poppins(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Dark, easy on the eyes color scheme
    const Color darkBackground = Color(0xFF121212);
    const Color darkSurface = Color(0xFF1E1E1E);
    const Color primaryIndigo = Color(0xFF5C6BC0); // Softer indigo
    const Color textPrimary = Color(0xFFEEEEEE);
    const Color textSecondary = Color(0xFFAAAAAA);
    
    return Drawer(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              darkBackground,
              darkSurface,
            ],
          ),
        ),
        child: SafeArea( // Prevents overflow at the top
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Header with reduced height to avoid overflow
              Container(
                height: 160, // Reduced height
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/bg.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.7), // Darker overlay for better contrast
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryIndigo.withOpacity(0.8), primaryIndigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "GramSewa",
                      style: _poppinsStyle(
                        color: textPrimary,
                        fontSize: 22, // Slightly smaller
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Village Services Portal",
                      style: _poppinsStyle(
                        color: textPrimary.withOpacity(0.7),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Complaints section
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 4.0),
                child: Text(
                  "COMPLAINTS",
                  style: _poppinsStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.doc_text_search,
                iconColor: Color(0xFFE6A14C), // Softer amber
                title: "View Complaints",
                route: "/complaints",
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.map_fill,
                iconColor: Color(0xFF4CAF50), // Softer green
                title: "Map View",
                route: "/complaints_map",
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
              ),
              
              // Petitions section
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
                child: Text(
                  "PETITIONS",
                  style: _poppinsStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.collections,
                iconColor: Color(0xFF5C6BC0), // Softer blue
                title: "All Petitions",
                route: "/petitions",
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.person_crop_circle_fill_badge_checkmark,
                iconColor: Color(0xFF9575CD), // Softer violet
                title: "My Petitions",
                route: "/my_petitions",
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
              ),
              
              // Account section
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.square_arrow_left,
                iconColor: Color(0xFFEF5350), // Softer red
                title: "Logout",
                route: "/login",
                showTrailing: false,
              ),

              SizedBox(height: 24),
              
              // App version with modern style
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Version 1.0.0",
                    style: _poppinsStyle(
                      color: textSecondary.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build consistent nav items with Poppins font
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String route,
    bool showTrailing = true,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity(horizontal: 0, vertical: -2), // Reduced vertical density
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        leading: Container(
          padding: EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 18, // Slightly smaller icon
            color: iconColor,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w400, // Slightly lighter weight
            fontSize: 14, // Slightly smaller
          ),
        ),
        trailing: showTrailing
            ? Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white38)
            : null,
        onTap: () {
          Navigator.pushNamed(context, route);
        },
      ),
    );
  }
}