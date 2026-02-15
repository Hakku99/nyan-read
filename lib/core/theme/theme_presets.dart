import 'package:flutter/material.dart';

enum ThemePreset {
  creamLight,
  sumiDark,
  sepiaWarm,
}

class NyanTheme {
  final ThemePreset preset;
  final String name;
  final Color primary; // Primary Accent (Matcha)
  final Color surface;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted; // New
  final Color accent; // Secondary Accent (Wood/Beige)
  final Color divider;
  final Color borderColor; // New
  final Brightness brightness;

  // New Semantic Colors
  final Color primaryButtonColor;
  final Color successColor;
  final Color warningColor;
  final Color infoColor;

  // Error Theme Colors
  final Color errorBackgroundColor;
  final Color errorPrimaryTextColor;
  final Color errorSecondaryTextColor;
  final Color errorAccentColor;

  const NyanTheme({
    required this.preset,
    required this.name,
    required this.primary,
    required this.surface,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.divider,
    required this.borderColor,
    required this.brightness,
    required this.primaryButtonColor,
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
    required this.errorBackgroundColor,
    required this.errorPrimaryTextColor,
    required this.errorSecondaryTextColor,
    required this.errorAccentColor,
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
        onPrimary: brightness == Brightness.dark
            ? const Color(0xFF1C1B1A)
            : Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: brightness == Brightness.dark
            ? const Color(0xFFCF6679)
            : Colors.redAccent, // Softer red for dark mode
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background, // Melt into background
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Flat design
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white.withOpacity(0.08)
                : divider,
            width: brightness == Brightness.dark ? 0.5 : 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brightness == Brightness.dark
              ? primary.withOpacity(0.15)
              : primary,
          foregroundColor: brightness == Brightness.dark
              ? primary
              : (brightness == Brightness.dark
                  ? const Color(0xFF1C1B1A)
                  : Colors.white),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: brightness == Brightness.dark
                ? BorderSide(color: primary.withOpacity(0.5), width: 1)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        titleLarge: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.5),
      ),
      iconTheme: IconThemeData(color: textPrimary),
    );
  }
}

final Map<ThemePreset, NyanTheme> themePresets = {
  ThemePreset.creamLight: const NyanTheme(
    preset: ThemePreset.creamLight,
    name: "Cream Light",
    primary: Color(0xFF8E9775),
    surface: Color(0xFFF2F0EB),
    background: Color(0xFFF7F5EF), // New Cream+
    textPrimary: Color(0xFF4A453E),
    textSecondary: Color(0xFF8C867B),
    textMuted: Color(0xFFB0ACA5),
    accent: Color(0xFFD4A373),
    divider: Color(0xFFE6E2D8),
    borderColor: Color(0xFFE6E2D8),
    brightness: Brightness.light,
    primaryButtonColor: Color(0xFF8E9775),
    successColor: Color(0xFF6B8E23),
    warningColor: Color(0xFFD4A373),
    infoColor: Color(0xFF7FABAC),
    errorBackgroundColor: Color(0xFFFFF0F0),
    errorPrimaryTextColor: Color(0xFFC62828),
    errorSecondaryTextColor: Color(0xFFD32F2F),
    errorAccentColor: Color(0xFFFFCDD2),
  ),

  ThemePreset.sumiDark: const NyanTheme(
    preset: ThemePreset.sumiDark,
    name: "Sumi Dark",
    primary: Color(0xFFC5D0A8),
    surface: Color(0xFF262422), // Sumi Ink (for surface/menu)
    background: Color(0xFF141312), // Deep Charcoal (for main background)
    textPrimary: Color(0xFFF5F3ED),
    textSecondary: Color(0xFFC5BFB5),
    textMuted: Color(0xFF8F8A84),
    accent: Color(0xFFD4A373),
    divider: Color(0xFF4A4642),
    borderColor: Color(0xFF4A4642),
    brightness: Brightness.dark,

    primaryButtonColor: Color(0xFFC5D0A8),
    successColor: Color(0xFF8FBC8F),
    warningColor: Color(0xFFD4A373),
    infoColor: Color(0xFF7FABAC),

    errorBackgroundColor: Color(0xFF2B2020),
    errorPrimaryTextColor: Color(0xFFFFCDD2),
    errorSecondaryTextColor: Color(0xFFE57373),
    errorAccentColor: Color(0xFFEF9A9A),
  ),

  // Keeping Sepia as a variation of Cream (maybe slightly warmer/darker)
  ThemePreset.sepiaWarm: const NyanTheme(
    preset: ThemePreset.sepiaWarm,
    name: "Sepia Warm",
    primary: Color(0xFF8D6E63),
    surface: Color(0xFFEFEBE9),
    background: Color(0xFFEDE3C7), // New Warm Sepia
    textPrimary: Color(0xFF3E2723), // Dark Brown
    textSecondary: Color(0xFF5D4037),
    textMuted: Color(0xFFA1887F),
    accent: Color(0xFF8D6E63),
    divider: Color(0xFFD7CCC8),
    borderColor: Color(0xFFD7CCC8),
    brightness: Brightness.light,

    primaryButtonColor: Color(0xFF8D6E63),
    successColor: Color(0xFF558B2F),
    warningColor: Color(0xFFEF6C00),
    infoColor: Color(0xFF0277BD),

    // Error Theme
    errorBackgroundColor: Color(0xFFFAF0E6),
    errorPrimaryTextColor: Color(0xFF5D4037),
    errorSecondaryTextColor: Color(0xFF8D6E63),
    errorAccentColor: Color(0xFFD7CCC8),
  ),
};
