import 'package:flutter/material.dart';

enum ThemePreset {
  sakuraLight,
  midnightBlue,
  sepiaWarm,
}

class NyanTheme {
  final ThemePreset preset;
  final String name;
  final Color primary;
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color divider;
  final Brightness brightness;

  const NyanTheme({
    required this.preset,
    required this.name,
    required this.primary,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.divider,
    required this.brightness,
  });

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: brightness == Brightness.dark ? textPrimary : Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: brightness == Brightness.dark ? const Color(0xFFCF6679) : Colors.redAccent, // Softer red for dark mode
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: brightness == Brightness.dark ? textPrimary : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: brightness == Brightness.dark ? textPrimary : Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent, // Use Accent color for buttons (Unlock/Cancel)
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 18, height: 1.6), // Reader text
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      ),
      iconTheme: IconThemeData(color: textPrimary),
    );
  }
}

final Map<ThemePreset, NyanTheme> themePresets = {
  ThemePreset.sakuraLight: const NyanTheme(
    preset: ThemePreset.sakuraLight,
    name: "Sakura Light",
    primary: Color(0xFFF7B7C8),
    surface: Color(0xFFFFF8F2),
    background: Color(0xFFF4F4F4),
    textPrimary: Colors.black, // Strict Black
    textSecondary: Color(0xFF555555), // Darker Grey for better contrast
    accent: Color(0xFFFF8A9D),
    divider: Color(0xFFFF8A9D), // Darker divider
    brightness: Brightness.light,
  ),
  ThemePreset.midnightBlue: const NyanTheme(
    preset: ThemePreset.midnightBlue,
    name: "Midnight Blue",
    primary: Color(0xFF2E2A3A),
    surface: Color(0xFF3B3550),
    background: Color(0xFF1E1B2E),
    textPrimary: Colors.white, // Strict White
    textSecondary: Color(0xFFE0E0E0), // Lighter Grey for better contrast
    accent: Color(0xFFFFFFFF),
    divider: Color(0xFF555555),
    brightness: Brightness.dark,
  ),
  ThemePreset.sepiaWarm: const NyanTheme(
    preset: ThemePreset.sepiaWarm,
    name: "Sepia Warm",
    primary: Color(0xFFD7CCC8), 
    surface: Color(0xFFEFEBE9), 
    background: Color(0xFFF5F5DC), 
    textPrimary: Colors.black, // Strict Black
    textSecondary: Color(0xFF5D4037), // Dark Brown
    accent: Color(0xFF8D6E63),
    divider: Color(0xFF8D6E63),
    brightness: Brightness.light,
  ),
};
