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
        error: Colors.redAccent,
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
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
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
    textPrimary: Color(0xFF333333),
    textSecondary: Color(0xFF757575),
    accent: Color(0xFF8ED1B2),
    divider: Color(0xFFE0E0E0),
    brightness: Brightness.light,
  ),
  ThemePreset.midnightBlue: const NyanTheme(
    preset: ThemePreset.midnightBlue,
    name: "Midnight Blue",
    primary: Color(0xFF2E2A3A),
    surface: Color(0xFF3B3550),
    background: Color(0xFF1E1B2E),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: Color(0xFFAAAAAA),
    accent: Color(0xFF7DB7D9),
    divider: Color(0xFF424242),
    brightness: Brightness.dark,
  ),
  ThemePreset.sepiaWarm: const NyanTheme(
    preset: ThemePreset.sepiaWarm,
    name: "Sepia Warm",
    primary: Color(0xFFD7CCC8), // Brown 100
    surface: Color(0xFFEFEBE9), // Brown 50
    background: Color(0xFFF5F5DC), // Beige
    textPrimary: Color(0xFF5D4037), // Brown 700
    textSecondary: Color(0xFF8D6E63), // Brown 400
    accent: Color(0xFF8D6E63),
    divider: Color(0xFFBCAAA4),
    brightness: Brightness.light,
  ),
};
