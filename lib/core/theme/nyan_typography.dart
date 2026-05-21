import 'package:flutter/material.dart';

class NyanTypography {
  const NyanTypography._();

  static const String uiFontFamily = 'Noto Sans SC';
  static const String readingSansFontFamily = 'Noto Sans SC';
  static const String readingSerifFontFamily = 'Source Han Serif SC';

  /// Generic platform monospace for locators and other technical strings.
  static const String monoFontFamily = 'monospace';

  static const double display = 32;
  static const double title = 24;
  static const double section = 20;
  static const double body = 16;
  static const double meta = 13;

  /// Interactive control label sizes — Claude Design system exception
  /// (see AGENTS.md §4.2.5). These three values are reserved for
  /// [NyanPrimaryButton] labels only and MUST NOT appear in body copy,
  /// headings, or any other surface. The standard (md) size reuses [body].
  ///
  /// Source: `nyan-read-design-system/project/ui_kits/nyan_read_app/components.jsx`
  ///   compact (sm)     → 14pt
  ///   standard (md)    → 16pt (alias: NyanTypography.body)
  ///   comfortable (lg) → 17pt
  static const double buttonCompact = 14;
  static const double buttonComfortable = 17;

  static TextTheme textTheme({
    required Color textMain,
    required Color textSecondary,
  }) {
    return const TextTheme().copyWith(
      displayLarge: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: display,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: title,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: section,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: body,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: body,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: meta,
        fontWeight: FontWeight.w400,
      ),
      labelSmall: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: meta,
        fontWeight: FontWeight.w500,
      ),
    ).apply(
      bodyColor: textMain,
      displayColor: textMain,
    ).copyWith(
      bodySmall: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: meta,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: uiFontFamily,
        fontSize: meta,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    );
  }
}
