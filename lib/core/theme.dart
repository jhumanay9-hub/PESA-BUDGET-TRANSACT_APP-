import 'package:flutter/material.dart';

class PesaBudgetTheme {
  // --- The Emerald Palette ---
  static const Color emeraldGreen = Color(0xFF2ECC71);
  static const Color darkMint = Color(0xFF27AE60);
  static const Color softWhite = Color(0xFFF9FBF9);
  static const Color charcoal = Color(0xFF2C3E50);
  static const Color slateGray = Color(0xFF95A5A6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: emeraldGreen,
      scaffoldBackgroundColor: softWhite,

      // --- AppBar Styling (Clean & High Contrast) ---
      appBarTheme: const AppBarTheme(
        backgroundColor: softWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: charcoal,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: charcoal),
      ),

      // --- Button Styling (The "Pesa Budget" Look) ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // --- Input Fields (Minimalist) ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: slateGray.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emeraldGreen, width: 2),
        ),
      ),

      // --- Text Styling (Readability first) ---
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: charcoal, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: charcoal, fontSize: 16),
        bodyMedium: TextStyle(color: slateGray, fontSize: 14),
      ),

      colorScheme: ColorScheme.fromSeed(
        seedColor: emeraldGreen,
        primary: emeraldGreen,
        secondary: darkMint,
        surface: Colors.white,
      ),
    );
  }

  static ThemeData get darkgreenTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: emeraldGreen,
      scaffoldBackgroundColor: const Color(0xFF0A0E0C),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0E0C),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emeraldGreen, width: 2),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: emeraldGreen,
        secondary: darkMint,
        surface: Color(0xFF0A0E0C),
      ),
    );
  }
}
