import 'package:flutter/material.dart';

class AppTheme {
  // Renk Paleti (Karanlık Lacivert / Koyu Mavi Standart)
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color bgNavy = Color(0xFF091122);
  static const Color cardNavy = Color(0xFF131E33);
  static const Color borderNavy = Color(0xFF1E2D4A);
  static const Color amberGold = Color(0xFFF59E0B);
  static const Color bgSoft = Color(0xFF091122);
  static const Color cardSurface = Color(0xFF131E33);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color borderSubtle = Color(0xFF1E2D4A);
  static const Color successGreen = Color(0xFF10B981);
  static const Color urgentRed = Color(0xFFEF4444);
  static const Color surfaceDark = Color(0xFF1E293B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgNavy,
      primaryColor: primaryBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: primaryBlue,
        secondary: amberGold,
        surface: cardNavy,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkNavy,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardNavy,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderNavy, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkNavy,
        indicatorColor: const Color(0xFF1E3A8A),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8));
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 22);
          }
          return const IconThemeData(color: Color(0xFF94A3B8), size: 22);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
