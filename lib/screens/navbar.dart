import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:complaints_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  // Helper function for text styling with Poppins font
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Always fetch user profile from Firestore if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future:
          user != null
              ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get()
              : null,
      builder: (context, snapshot) {
        String userIdentifier;
        String userInitial;
        String? userName;
        String? phoneNo;
        // Use Firestore profile if available
        if (user != null &&
            snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          userName = userData?['name'] as String?;
          phoneNo = userData?['phone_no'] as String?;
          if (userName != null && userName.isNotEmpty) {
            userIdentifier = userName;
            userInitial = userName[0].toUpperCase();
          } else if (phoneNo != null && phoneNo.isNotEmpty) {
            userIdentifier = phoneNo;
            userInitial =
                phoneNo.contains('+')
                    ? phoneNo[phoneNo.indexOf('+') + 1].toUpperCase()
                    : phoneNo[0].toUpperCase();
          } else {
            userIdentifier = 'Guest User';
            userInitial = 'G';
          }
        } else {
          // Not logged in or no Firestore profile
          userIdentifier = 'Guest User';
          userInitial = 'G';
        }

        return Drawer(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    isDarkMode
                        ? [
                          ColorPalette.backgroundDark,
                          ColorPalette.surfaceDark,
                        ]
                        : [
                          ColorPalette.backgroundLight,
                          ColorPalette.surfaceLight,
                        ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black26 : Colors.black12,
                  blurRadius: 8,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header section
                  _buildDrawerHeader(
                    context,
                    userInitial,
                    userIdentifier,
                    isDarkMode,
                  ),

                  // Options list
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(top: 8),
                      physics: BouncingScrollPhysics(),
                      children: [
                        //Home Page
                        _buildSectionTitle('HOME', isDarkMode),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.home,
                          iconColor: ColorPalette.info,
                          title: "Home Page",
                          route: "/home",
                          isDarkMode: isDarkMode,
                        ),
                        _buildDivider(isDarkMode),
                        // Complaints section
                        _buildSectionTitle('EXPERIENCES', isDarkMode),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.doc_text_search,
                          iconColor: ColorPalette.info,
                          title: "View Experiences",
                          route: "/complaints",
                          isDarkMode: isDarkMode,
                        ),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.doc_text_search,
                          iconColor: ColorPalette.info,
                          title: "My Experiences",
                          route: "/my_complaints",
                          isDarkMode: isDarkMode,
                        ),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.search,
                          iconColor: ColorPalette.warning,
                          title: "Search Experiences",
                          route: "/test",
                          isDarkMode: isDarkMode,
                        ),

                        _buildDivider(isDarkMode),

                        // Petitions section
                        _buildSectionTitle('PETITIONS', isDarkMode),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.collections,
                          iconColor: ColorPalette.primaryLight,
                          title: "All Petitions",
                          route: "/petitions",
                          isDarkMode: isDarkMode,
                        ),
                        _buildNavigationTile(
                          context: context,
                          icon:
                              CupertinoIcons
                                  .person_crop_circle_fill_badge_checkmark,
                          iconColor: Color(0xFF9575CD),
                          title: "My Petitions",
                          route: "/my_petitions",
                          isDarkMode: isDarkMode,
                        ),

                        _buildDivider(isDarkMode),

                        // safety
                        _buildSectionTitle('SAFETY', isDarkMode),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.news_solid,
                          iconColor: ColorPalette.primaryLight,
                          title: "Find Safest Route",
                          route: "/safest_route",
                          isDarkMode: isDarkMode,
                        ),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.exclamationmark_triangle_fill,
                          iconColor: Colors.red,
                          title: "Emergency SOS",
                          route: "/sos",
                          isDarkMode: isDarkMode,
                        ),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.chart_bar_square_fill,
                          iconColor: ColorPalette.primaryLight,
                          title: "Safety Summary",
                          route: "/summary_screen",
                          isDarkMode: isDarkMode,
                        ),

                        _buildDivider(isDarkMode),

                        // news
                        _buildSectionTitle('NEWS', isDarkMode),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.news_solid,
                          iconColor: ColorPalette.primaryLight,
                          title: "View Gov Schemes in your area",
                          route: "/news",
                          isDarkMode: isDarkMode,
                        ),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.news,
                          iconColor: ColorPalette.primaryLight,
                          title: "News Map",
                          route: "/news_map",
                          isDarkMode: isDarkMode,
                        ),

                        // In your NavBar class, replace the Settings section with:
                        _buildDivider(isDarkMode),

                        // Settings section
                        _buildSectionTitle('SETTINGS', isDarkMode),
                        _buildNavigationTile(
                          context: context,
                          icon: CupertinoIcons.settings,
                          iconColor: Colors.blueGrey,
                          title: "Settings",
                          route: "/settings_screen",
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),

                  // App version footer
                  _buildAppVersionFooter(isDarkMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerHeader(
    BuildContext context,
    String userInitial,
    String userIdentifier,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(); // close drawer
        Navigator.pushNamed(context, '/profile_screen');
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 38 * 0.85, // Decrease logo height
                  child: Image.asset(
                    'assets/images/logo2.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 10 * 0.85),
                Text(
                  "SORORIA",
                  style: _poppinsStyle(
                    color: Color(0xFFE91E63),
                    fontSize: 22 * 0.85, // Decrease font size
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // User initial avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFE91E63),
              child: Text(
                userInitial,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 10),
            // User identifier
            Text(
              userIdentifier,
              style: _poppinsStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: _poppinsStyle(
          color:
              isDarkMode
                  ? ColorPalette.textLightSecondary
                  : ColorPalette.textDarkSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? route,
    required bool isDarkMode,
    Function()? onTap,
    bool showTrailing = true,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(
          title,
          style: _poppinsStyle(
            color:
                isDarkMode
                    ? ColorPalette.textLightPrimary.withOpacity(0.9)
                    : ColorPalette.textDarkPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing:
            showTrailing
                ? Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color:
                      isDarkMode
                          ? ColorPalette.textLightSecondary.withOpacity(0.6)
                          : ColorPalette.textDarkSecondary.withOpacity(0.6),
                )
                : null,
        onTap:
            onTap ??
            (route != null
                ? () {
                  Navigator.pushNamed(context, route);
                }
                : null),
      ),
    );
  }

  Widget _buildThemeSwitchTile(bool isDarkMode, ThemeProvider themeProvider) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDarkMode
                ? CupertinoIcons.sun_max_fill
                : CupertinoIcons.moon_stars_fill,
            size: 18,
            color: Colors.purple,
          ),
        ),
        title: Text(
          isDarkMode ? "Light Theme" : "Dark Theme",
          style: _poppinsStyle(
            color:
                isDarkMode
                    ? ColorPalette.textLightPrimary.withOpacity(0.9)
                    : ColorPalette.textDarkPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Switch.adaptive(
          value: isDarkMode,
          activeColor: Colors.purple,
          onChanged: (_) {
            themeProvider.toggleTheme();
          },
        ),
        onTap: () {
          themeProvider.toggleTheme();
        },
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Divider(
        color:
            isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
        thickness: 1,
      ),
    );
  }

  Widget _buildAppVersionFooter(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "Version 1.0.1",
              style: _poppinsStyle(
                color:
                    isDarkMode
                        ? Colors.white.withOpacity(0.5)
                        : Colors.black.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),

          SizedBox(height: 8),

          Text(
            "© 2025 Sororia",
            style: _poppinsStyle(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
