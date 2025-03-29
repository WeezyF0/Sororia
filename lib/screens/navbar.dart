import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:complaints_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

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

    // Get current user details if available
    final user = FirebaseAuth.instance.currentUser;
    final String userEmail = user?.email ?? 'Guest User';
    final String userInitial =
        userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'G';

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
                    ? [ColorPalette.backgroundDark, ColorPalette.surfaceDark]
                    : [ColorPalette.backgroundLight, ColorPalette.surfaceLight],
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
              _buildDrawerHeader(context, userInitial, userEmail, isDarkMode),

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
                      icon: CupertinoIcons.map_fill,
                      iconColor: ColorPalette.success,
                      title: "Map View",
                      route: "/complaints_map",
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

                    // news
                    _buildSectionTitle('NEWS', isDarkMode),
                    _buildNavigationTile(
                      context: context,
                      icon: CupertinoIcons.news_solid,
                      iconColor: ColorPalette.primaryLight,
                      title: "View News in your area",
                      route: "/news",
                      isDarkMode: isDarkMode,
                    ),
                    _buildNavigationTile(
                      context: context,
                      icon: CupertinoIcons.lab_flask,
                      iconColor: ColorPalette.warning,
                      title: "Search Experiences",
                      route: "/test",
                      isDarkMode: isDarkMode,
                    ),
                    _buildDivider(isDarkMode),

                    // Settings section
                    _buildSectionTitle('SETTINGS', isDarkMode),
                    _buildThemeSwitchTile(isDarkMode, themeProvider),

                    _buildDivider(isDarkMode),

                    // Account section
                    _buildNavigationTile(
                      context: context,
                      icon: CupertinoIcons.square_arrow_left,
                      iconColor: ColorPalette.error,
                      title: "Logout",
                      isDarkMode: isDarkMode,
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      showTrailing: false,
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
  }

  Widget _buildDrawerHeader(
    BuildContext context,
    String userInitial,
    String userEmail,
    bool isDarkMode,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.darken,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: ColorPalette.primaryLight,
                child: Text(
                  userInitial,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Spacer(),

              // Close button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // User email
          Text(
            userEmail,
            style: _poppinsStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: 4),

          // App name
          InkWell(
            onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Image.asset('assets/images/logo2.png', height: 24, width: 24),
                  SizedBox(width: 8),
                  Text(
                    "Sororia",
                    style: _poppinsStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
