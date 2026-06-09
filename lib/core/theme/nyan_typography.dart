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

  /// Olive eyebrow / section caption — the 6th and smallest type size.
  /// **Reserved for uppercase section eyebrows only** (e.g. the olive dotted
  /// labels inside settings groups, reader settings headers). MUST NOT appear
  /// in body copy, list rows, or any non-caption surface.
  /// Source: `colors_and_type.css` `--fz-caption`; `AGENTS.md §4.2.5`.
  static const double caption = 11;

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

  /// Bookshelf list-row micro-labels — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for [AnimatedBookCardList] ONLY:
  ///   [shelfFormatChip]     → 9pt, the TXT / EPUB / PDF format badge
  ///   [shelfProgressLabel]  → 11pt monospace, the trailing reading percentage
  /// These two values MUST NOT appear in body copy, headings, or any other
  /// surface.
  ///
  /// Source: `nyan-read-design-system/project/screens/bundle3.jsx` `BookListRow`
  static const double shelfFormatChip = 9;
  static const double shelfProgressLabel = 11;

  /// Privacy PIN overlay keypad glyph sizes — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for the U16 PIN keypad ONLY:
  ///   [pinKeyDigit] → 26pt, the 0–9 keypad digits
  ///   [pinKeyGlyph] → 22pt, the backspace glyph
  /// Both sit off the 6-step ladder; they MUST NOT appear in body copy,
  /// headings, or any other surface.
  ///
  /// Source: `nyan-read-design-system/project/screens/bundle4.jsx` `NumPad`
  static const double pinKeyDigit = 26;
  static const double pinKeyGlyph = 22;

  /// "Jump to current" floating action button label — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for the Chapters-sheet FAB
  /// label ONLY. Sits between [meta] 13 and [buttonCompact] 14; it MUST NOT
  /// appear in body copy, headings, list rows, or any other surface.
  ///
  /// Source: `screens/bundle1.jsx` `ChapterDockSheet` button span
  ///   `font: "600 13.5px/1"`
  static const double fabLabel = 13.5;

  /// Olive uppercase eyebrow label — 11pt / w500 / +0.22 letter-spacing.
  /// Pass [color] as `nyan.primaryDeep` from the active [NyanTheme].
  /// Use only for section eyebrows above grouped cards / reader settings headers.
  static TextStyle eyebrowStyle(Color color) => TextStyle(
        fontFamily: uiFontFamily,
        fontSize: caption,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.22,
        height: 1.0,
        color: color,
      );

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
