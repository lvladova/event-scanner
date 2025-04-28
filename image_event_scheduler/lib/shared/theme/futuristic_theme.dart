import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FuturisticTheme {
  // Color Palette
  static const Color backgroundDark = Color(0xFF0A0A1A);
  static const Color primaryBlue = Color(0xFF00B4FF);
  static const Color accentBlue = Color(0xFF4DFAFF);
  static const Color softBlue = Color(0xFF1E2D3C);
  static const Color gridLineColor = Color(0xFF1A1A2E);

  // Text Styles with Orbitron font
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.orbitron(
      fontSize: 32,
      color: primaryBlue,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    ),
    displayMedium: GoogleFonts.orbitron(
      fontSize: 24,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.orbitron(
      fontSize: 16,
      color: Colors.white70,
      letterSpacing: 0.5,
    ),
    titleLarge: GoogleFonts.orbitron(
      fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.orbitron(
      fontSize: 14,
      color: primaryBlue,
      fontWeight: FontWeight.w500,
    ),
  );

  // Dark Theme with Futuristic Modifications
  static ThemeData get darkTheme {
    // Create a base text theme with Orbitron font for all text styles
    final orbitronTextTheme = GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme);

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryBlue,
      colorScheme: ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentBlue,
        surface: softBlue,
        background: backgroundDark,
      ),
      // Apply Orbitron font to the entire app
      textTheme: orbitronTextTheme.copyWith(
        // Override specific text styles with our custom ones
        displayLarge: textTheme.displayLarge,
        displayMedium: textTheme.displayMedium,
        bodyLarge: textTheme.bodyLarge,
        titleLarge: textTheme.titleLarge,
        labelLarge: textTheme.labelLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: orbitronTextTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: softBlue,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }
}