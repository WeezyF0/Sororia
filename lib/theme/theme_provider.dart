import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorPalette {
  // Primary colors
  static const Color primaryLight = Color(0xFF426CB4);
  static const Color primaryDark = Color(0xFF6889D5);
  
  // Secondary colors
  static const Color accentLight = Color(0xFF219653);
  static const Color accentDark = Color(0xFF27AE60);
  
  // Background colors
  static const Color backgroundLight = Color(0xFFF9FAFC);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  
  // Text colors
  static const Color textDarkPrimary = Color(0xFF212121);
  static const Color textDarkSecondary = Color(0xFF757575);
  static const Color textLightPrimary = Color(0xFFF5F5F5);
  static const Color textLightSecondary = Color(0xFFBDBDBD);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF2C94C);
  static const Color error = Color(0xFFEB5757);
  static const Color info = Color(0xFF2D9CDB);
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
  
  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  ThemeData _buildTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    Color primaryColor = isDark ? ColorPalette.primaryDark : ColorPalette.primaryLight;
    Color secondaryColor = isDark ? ColorPalette.accentDark : ColorPalette.accentLight;
    Color backgroundColor = isDark ? ColorPalette.backgroundDark : ColorPalette.backgroundLight;
    Color surfaceColor = isDark ? ColorPalette.surfaceDark : ColorPalette.surfaceLight;
    Color textPrimary = isDark ? ColorPalette.textLightPrimary : ColorPalette.textDarkPrimary;
    Color textSecondary = isDark ? ColorPalette.textLightSecondary : ColorPalette.textDarkSecondary;
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: ColorPalette.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: _getTextTheme(isDark).titleLarge?.copyWith(
          color: Colors.white, 
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 2,
        shadowColor: isDark ? Colors.black54 : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textSecondary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: TextStyle(color: primaryColor),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textTheme: _getTextTheme(isDark),
      dividerColor: textSecondary.withOpacity(0.1),
      iconTheme: IconThemeData(
        color: textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: TextStyle(color: textPrimary),
        actionTextColor: primaryColor,
      ),
    );
  }
  
  TextTheme _getTextTheme(bool isDark) {
    Color primaryTextColor = isDark ? ColorPalette.textLightPrimary : ColorPalette.textDarkPrimary;
    Color secondaryTextColor = isDark ? ColorPalette.textLightSecondary : ColorPalette.textDarkSecondary;
    
    return GoogleFonts.poppinsTextTheme(
      TextTheme(
        displayLarge: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w400),
        displaySmall: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500),
        headlineLarge: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: primaryTextColor),
        bodyMedium: TextStyle(color: secondaryTextColor),
        labelLarge: TextStyle(color: secondaryTextColor),
        labelMedium: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: secondaryTextColor, letterSpacing: 0.5),
      ),
    );
  }
}