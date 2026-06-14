import 'package:flutter/material.dart';

import 'nyan_colors.dart';
import 'nyan_radius.dart';
import 'nyan_spacing.dart';
import 'nyan_typography.dart';

enum ThemePreset {
  creamLight,
  sumiDark,
  /// Follows the device's light/dark mode setting via [ThemeMode.system].
  matchSystem,
}

@immutable
class NyanTheme extends ThemeExtension<NyanTheme> {
  final ThemePreset preset;
  final String name;
  final Color primary;
  final Color primaryDeep;
  final Color surface;
  final Color surfaceMuted;

  /// Highest elevation tier — dialogs, bottom sheets, popovers, menus.
  /// In Sumi Dark this is one ladder step lighter than [surface] (`#2E342B`);
  /// in Cream Light it reuses [surface] (the elevation ladder is dark-only —
  /// light lift is carried by the soft `lightCard` shadow instead).
  final Color surfaceRaised;
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
    required this.surfaceRaised,
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

  Color get onPrimary => brightness == Brightness.dark
      ? const Color(0xFF1C1B1A)
      : NyanColors.white;
  Color get onSecondary => NyanColors.white;
  Color get onError => NyanColors.white;
  Color get inverseBorder => brightness == Brightness.dark
      ? NyanColors.white.withValues(alpha: 0.08)
      : divider;

  ThemeData get themeData {
    final transparentSurface = surface.withValues(alpha: 0);
    final softError = brightness == Brightness.dark
        ? errorSecondaryTextColor
        : errorPrimaryTextColor;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent,
      onSecondary: onSecondary,
      error: softError,
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
            color: inverseBorder,
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
          backgroundColor: brightness == Brightness.dark
              ? primary.withValues(alpha: 0.15)
              : primary,
          foregroundColor: brightness == Brightness.dark ? primary : onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NyanRadius.input),
            side: brightness == Brightness.dark
                ? BorderSide(color: primary.withValues(alpha: 0.5), width: 1)
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
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
      ),
      // Dialogs and sheets sit on the highest elevation tier (surfaceRaised).
      // In Cream Light this equals surface; in Sumi Dark it steps one ladder
      // level lighter (#2E342B) so they visually float above cards.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NyanRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NyanRadius.panel),
        ),
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return transparentSurface;
          }
          return divider.withValues(
              alpha: brightness == Brightness.dark ? 0.14 : 0.18);
        }),
        overlayColor: WidgetStatePropertyAll(transparentSurface),
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
    Color? surfaceRaised,
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
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
      borderColor: borderColor ?? this.borderColor,
      brightness: brightness ?? this.brightness,
      primaryButtonBackground:
          primaryButtonBackground ?? this.primaryButtonBackground,
      primaryButtonForeground:
          primaryButtonForeground ?? this.primaryButtonForeground,
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
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      background: Color.lerp(background, other.background, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
      primaryButtonBackground: Color.lerp(
          primaryButtonBackground, other.primaryButtonBackground, t)!,
      primaryButtonForeground: Color.lerp(
          primaryButtonForeground, other.primaryButtonForeground, t)!,
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
      errorAccentColor:
          Color.lerp(errorAccentColor, other.errorAccentColor, t)!,
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
    // D1: light has no distinct raised tone — reuse surface (ladder is dark-only).
    surfaceRaised: NyanColors.creamSurface,
    background: NyanColors.creamBackground,
    textPrimary: NyanColors.creamTextMain,
    textSecondary: NyanColors.creamTextSecondary,
    textMuted: NyanColors.creamTextMuted,
    accent: NyanColors.creamPrimaryDeep,
    divider: NyanColors.creamDivider,
    borderColor: NyanColors.creamDivider,
    brightness: Brightness.light,
    // creamPrimaryDeep gives ~6.0:1 vs creamSurface foreground (AA+); creamPrimary
    // was marginal at ~4.5:1 — Fix #2B.
    primaryButtonBackground: NyanColors.creamPrimaryDeep,
    primaryButtonForeground: NyanColors.creamSurface,
    successColor: NyanColors.creamSuccess,
    warningColor: NyanColors.highlightOrange,
    infoColor: NyanColors.readerInfoBlue,
    errorBackgroundColor: NyanColors.errorBackgroundLight,
    errorPrimaryTextColor: NyanColors.errorPrimaryLight,
    errorSecondaryTextColor: NyanColors.errorSecondaryLight,
    errorAccentColor: NyanColors.errorAccentLight,
    fabBackground: NyanColors.creamPrimaryDeep,
    fabForeground: NyanColors.creamSurface,
  ),
  ThemePreset.sumiDark: const NyanTheme(
    preset: ThemePreset.sumiDark,
    name: 'Sumi Dark',
    primary: NyanColors.inkNightPrimary,
    primaryDeep: NyanColors.inkNightPrimaryDeep,
    surface: NyanColors.inkNightSurface,
    surfaceMuted: NyanColors.inkNightSurfaceMuted,
    surfaceRaised: NyanColors.inkNightSurfaceRaised,
    background: NyanColors.inkNightBackground,
    textPrimary: NyanColors.inkNightTextMain,
    textSecondary: NyanColors.inkNightTextSecondary,
    textMuted: NyanColors.inkNightTextMuted,
    accent: NyanColors.highlightOrange,
    divider: NyanColors.inkNightDivider,
    // v3 ladder: explicit card edge is brighter than the divider hairline.
    borderColor: NyanColors.inkNightBorder,
    brightness: Brightness.dark,
    // inkNightBackground (~7.6:1) on inkNightPrimary (green) button passes AAA.
    // inkNightTextMain was 1.65:1 — critical AA failure, Fix #1.
    primaryButtonBackground: NyanColors.inkNightPrimary,
    primaryButtonForeground: NyanColors.inkNightBackground,
    successColor: NyanColors.inkNightSuccess,
    warningColor: NyanColors.highlightOrange,
    infoColor: NyanColors.readerInfoBlue,
    errorBackgroundColor: NyanColors.errorBackgroundDark,
    errorPrimaryTextColor: NyanColors.errorPrimaryDark,
    errorSecondaryTextColor: NyanColors.errorSecondaryDark,
    errorAccentColor: NyanColors.errorAccentDark,
    // inkNightBackground (~7.6:1) on inkNightPrimary (green) FAB passes AAA.
    // inkNightTextMain was 1.65:1 — critical AA failure, Fix #1.
    fabBackground: NyanColors.inkNightPrimary,
    fabForeground: NyanColors.inkNightBackground,
  ),
};

NyanTheme resolveNyanTheme(ThemeData theme) {
  return theme.extension<NyanTheme>() ?? themePresets[ThemePreset.creamLight]!;
}
