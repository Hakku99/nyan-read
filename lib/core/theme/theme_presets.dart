import 'package:flutter/material.dart';

import 'nyan_colors.dart';
import 'nyan_radius.dart';
import 'nyan_spacing.dart';
import 'nyan_typography.dart';

enum ThemePreset {
  creamLight,
  sumiDark,
  sepiaWarm,
}

@immutable
class NyanTheme extends ThemeExtension<NyanTheme> {
  final ThemePreset preset;
  final String name;
  final Color primary;
  final Color primaryDeep;
  final Color surface;
  final Color surfaceMuted;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color divider;
  final Color borderColor;
  final Brightness brightness;
  final Color primaryButtonBackground;
  final Color primaryButtonForeground;
  final Color successColor;
  final Color warningColor;
  final Color infoColor;
  final Color errorBackgroundColor;
  final Color errorPrimaryTextColor;
  final Color errorSecondaryTextColor;
  final Color errorAccentColor;
  final Color fabBackground;
  final Color fabForeground;

  static const Color creamRecess = NyanColors.creamSurfaceMuted;

  const NyanTheme({
    required this.preset,
    required this.name,
    required this.primary,
    required this.primaryDeep,
    required this.surface,
    required this.surfaceMuted,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.divider,
    required this.borderColor,
    required this.brightness,
    required this.primaryButtonBackground,
    required this.primaryButtonForeground,
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
    required this.errorBackgroundColor,
    required this.errorPrimaryTextColor,
    required this.errorSecondaryTextColor,
    required this.errorAccentColor,
    required this.fabBackground,
    required this.fabForeground,
  });

  Color get onPrimary =>
      brightness == Brightness.dark ? const Color(0xFF1C1B1A) : NyanColors.white;
  Color get onSecondary => NyanColors.white;
  Color get onError => NyanColors.white;
  Color get inverseBorder =>
      brightness == Brightness.dark ? NyanColors.white.withOpacity(0.08) : divider;

  ThemeData get themeData {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent,
      onSecondary: onSecondary,
      error: brightness == Brightness.dark
          ? const Color(0xFFCF6679)
          : Colors.redAccent,
      onError: onError,
      surface: surface,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: NyanTypography.uiFontFamily,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[this],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: NyanSpacing.space4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NyanRadius.card),
          side: BorderSide(
            color: preset == ThemePreset.sepiaWarm
                ? accent.withOpacity(0.15)
                : inverseBorder,
            width: brightness == Brightness.dark ? 0.5 : 1,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fabBackground,
        foregroundColor: fabForeground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryButtonBackground,
          foregroundColor: primaryButtonForeground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NyanRadius.input),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NyanSpacing.space24,
            vertical: NyanSpacing.space12,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              brightness == Brightness.dark ? primary.withOpacity(0.15) : primary,
          foregroundColor: brightness == Brightness.dark ? primary : onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NyanRadius.input),
            side: brightness == Brightness.dark
                ? BorderSide(color: primary.withOpacity(0.5), width: 1)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NyanSpacing.space24,
            vertical: NyanSpacing.space12,
          ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space16,
          vertical: NyanSpacing.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.7)),
      ),
      switchTheme: preset == ThemePreset.sepiaWarm
          ? SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return NyanColors.sepiaBackground;
                }
                return const Color(0xFFD7CCC8);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primary;
                }
                return const Color(0xFFA1887F);
              }),
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return NyanColors.transparent;
                }
                return const Color(0xFFA1887F);
              }),
            )
          : null,
      sliderTheme: preset == ThemePreset.sepiaWarm
          ? SliderThemeData(
              activeTrackColor: primary,
              inactiveTrackColor: const Color(0xFFA1887F).withOpacity(0.5),
              thumbColor: primary,
              overlayColor: primary.withOpacity(0.1),
              trackHeight: 4,
            )
          : null,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NyanRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NyanRadius.panel),
        ),
      ),
      textTheme: NyanTypography.textTheme(
        textMain: textPrimary,
        textSecondary: textSecondary,
      ),
      iconTheme: IconThemeData(color: textPrimary),
      shadowColor: textPrimary,
    );
  }

  @override
  NyanTheme copyWith({
    ThemePreset? preset,
    String? name,
    Color? primary,
    Color? primaryDeep,
    Color? surface,
    Color? surfaceMuted,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? divider,
    Color? borderColor,
    Brightness? brightness,
    Color? primaryButtonBackground,
    Color? primaryButtonForeground,
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
    Color? errorBackgroundColor,
    Color? errorPrimaryTextColor,
    Color? errorSecondaryTextColor,
    Color? errorAccentColor,
    Color? fabBackground,
    Color? fabForeground,
  }) {
    return NyanTheme(
      preset: preset ?? this.preset,
      name: name ?? this.name,
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
      borderColor: borderColor ?? this.borderColor,
      brightness: brightness ?? this.brightness,
      primaryButtonBackground: primaryButtonBackground ?? this.primaryButtonBackground,
      primaryButtonForeground: primaryButtonForeground ?? this.primaryButtonForeground,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      errorBackgroundColor: errorBackgroundColor ?? this.errorBackgroundColor,
      errorPrimaryTextColor:
          errorPrimaryTextColor ?? this.errorPrimaryTextColor,
      errorSecondaryTextColor:
          errorSecondaryTextColor ?? this.errorSecondaryTextColor,
      errorAccentColor: errorAccentColor ?? this.errorAccentColor,
      fabBackground: fabBackground ?? this.fabBackground,
      fabForeground: fabForeground ?? this.fabForeground,
    );
  }

  @override
  NyanTheme lerp(ThemeExtension<NyanTheme>? other, double t) {
    if (other is! NyanTheme) {
      return this;
    }

    return NyanTheme(
      preset: t < 0.5 ? preset : other.preset,
      name: t < 0.5 ? name : other.name,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
      primaryButtonBackground:
          Color.lerp(primaryButtonBackground, other.primaryButtonBackground, t)!,
      primaryButtonForeground:
          Color.lerp(primaryButtonForeground, other.primaryButtonForeground, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      errorBackgroundColor:
          Color.lerp(errorBackgroundColor, other.errorBackgroundColor, t)!,
      errorPrimaryTextColor:
          Color.lerp(errorPrimaryTextColor, other.errorPrimaryTextColor, t)!,
      errorSecondaryTextColor: Color.lerp(
        errorSecondaryTextColor,
        other.errorSecondaryTextColor,
        t,
      )!,
      errorAccentColor: Color.lerp(errorAccentColor, other.errorAccentColor, t)!,
      fabBackground: Color.lerp(fabBackground, other.fabBackground, t)!,
      fabForeground: Color.lerp(fabForeground, other.fabForeground, t)!,
    );
  }
}

final Map<ThemePreset, NyanTheme> themePresets = {
  ThemePreset.creamLight: const NyanTheme(
    preset: ThemePreset.creamLight,
    name: 'Cream Light',
    primary: NyanColors.creamPrimary,
    primaryDeep: NyanColors.creamPrimaryDeep,
    surface: NyanColors.creamSurface,
    surfaceMuted: NyanColors.creamSurfaceMuted,
    background: NyanColors.creamBackground,
    textPrimary: NyanColors.creamTextMain,
    textSecondary: NyanColors.creamTextSecondary,
    textMuted: Color(0xFFB0ACA5),
    accent: NyanColors.creamPrimaryDeep,
    divider: NyanColors.creamDivider,
    borderColor: NyanColors.creamDivider,
    brightness: Brightness.light,
    primaryButtonBackground: NyanColors.creamPrimary,
    primaryButtonForeground: NyanColors.creamSurface,
    successColor: Color(0xFF6B8E23),
    warningColor: NyanColors.highlightOrange,
    infoColor: Color(0xFF7FABAC),
    errorBackgroundColor: Color(0xFFFFF0F0),
    errorPrimaryTextColor: Color(0xFFC62828),
    errorSecondaryTextColor: Color(0xFFD32F2F),
    errorAccentColor: Color(0xFFFFCDD2),
    fabBackground: NyanColors.creamPrimaryDeep,
    fabForeground: NyanColors.creamSurface,
  ),
  ThemePreset.sumiDark: const NyanTheme(
    preset: ThemePreset.sumiDark,
    name: 'Sumi Dark',
    primary: NyanColors.inkNightPrimary,
    primaryDeep: NyanColors.amoledPrimary,
    surface: NyanColors.inkNightSurface,
    surfaceMuted: Color(0xFF202520),
    background: NyanColors.inkNightBackground,
    textPrimary: NyanColors.inkNightTextMain,
    textSecondary: NyanColors.inkNightTextSecondary,
    textMuted: Color(0xFF8F8A84),
    accent: NyanColors.highlightOrange,
    divider: NyanColors.inkNightDivider,
    borderColor: NyanColors.inkNightDivider,
    brightness: Brightness.dark,
    primaryButtonBackground: NyanColors.inkNightPrimary,
    primaryButtonForeground: NyanColors.inkNightTextMain,
    successColor: Color(0xFF8FBC8F),
    warningColor: NyanColors.highlightOrange,
    infoColor: Color(0xFF7FABAC),
    errorBackgroundColor: Color(0xFF2B2020),
    errorPrimaryTextColor: Color(0xFFFFCDD2),
    errorSecondaryTextColor: Color(0xFFE57373),
    errorAccentColor: Color(0xFFEF9A9A),
    fabBackground: NyanColors.inkNightPrimary,
    fabForeground: NyanColors.inkNightTextMain,
  ),
  ThemePreset.sepiaWarm: const NyanTheme(
    preset: ThemePreset.sepiaWarm,
    name: 'Sepia Warm',
    primary: NyanColors.sepiaPrimary,
    primaryDeep: Color(0xFF795548),
    surface: NyanColors.sepiaSurface,
    surfaceMuted: Color(0xFFFAF2E6),
    background: NyanColors.sepiaBackground,
    textPrimary: NyanColors.sepiaTextMain,
    textSecondary: NyanColors.sepiaTextSecondary,
    textMuted: Color(0xFFA1887F),
    accent: Color(0xFF795548),
    divider: NyanColors.sepiaDivider,
    borderColor: NyanColors.sepiaDivider,
    brightness: Brightness.light,
    primaryButtonBackground: Color(0xFF795548),
    primaryButtonForeground: NyanColors.sepiaSurface,
    successColor: Color(0xFF558B2F),
    warningColor: Color(0xFFEF6C00),
    infoColor: Color(0xFF0277BD),
    errorBackgroundColor: Color(0xFFFAF0E6),
    errorPrimaryTextColor: Color(0xFF5D4037),
    errorSecondaryTextColor: Color(0xFF8D6E63),
    errorAccentColor: Color(0xFFD7CCC8),
    fabBackground: NyanColors.sepiaPrimary,
    fabForeground: NyanColors.sepiaSurface,
  ),
};

NyanTheme resolveNyanTheme(ThemeData theme) {
  return theme.extension<NyanTheme>() ??
      themePresets[ThemePreset.creamLight]!;
}



