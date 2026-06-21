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
  ///   [pinKeyDigit] → 27pt w500, the 0–9 keypad digits
  ///   [pinKeyGlyph] → 24pt, the backspace icon
  /// Both sit off the 6-step ladder; they MUST NOT appear in body copy,
  /// headings, or any other surface.
  ///
  /// Source: `nyan-read-design-system/project/screens/bundle4.jsx` `NumPad`
  static const double pinKeyDigit = 27;
  static const double pinKeyGlyph = 24;

  /// "Jump to current" floating action button label — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for the Chapters-sheet FAB
  /// label ONLY. Sits between [meta] 13 and [buttonCompact] 14; it MUST NOT
  /// appear in body copy, headings, list rows, or any other surface.
  ///
  /// Source: `screens/bundle1.jsx` `ChapterDockSheet` button span
  ///   `font: "600 13.5px/1"`
  static const double fabLabel = 13.5;

  /// Bookshelf sort sheet field row main label — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for [_SortFieldRow] label ONLY.
  /// Sits between [meta] 13 and [body] 16; it MUST NOT appear in body copy,
  /// headings, or any other surface.
  ///
  /// Source: `screens/bundle3.jsx` `ShelfSortSheet` field row
  ///   `font: "600 15px/1.2"` (selected) / `"500 15px/1.2"` (unselected)
  static const double shelfSortFieldLabel = 15.0;

  /// Bookshelf sort sheet field row sub-label — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for [_SortFieldRow] sub-label ONLY.
  /// Sits between [caption] 11 and [meta] 13; it MUST NOT appear in body copy,
  /// list rows, or any other surface.
  ///
  /// Source: `screens/bundle3.jsx` `ShelfSortSheet` field row
  ///   `font: "400 12.5px/1.3"`
  static const double shelfSortFieldSub = 12.5;

  /// Admin Panel switch/flag row main label — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for [_AdminSwitchRow] and [_AdminFlagRow]
  /// main labels ONLY. Sits between [meta] 13 and [body] 16; it MUST NOT appear
  /// in body copy, headings, or any other surface.
  ///
  /// Source: `screens/bundle4.jsx` `AdminPanel` row label
  ///   `font: "600 15px/1.2"` / `"500 15px/1.2"`
  static const double adminRowLabel = 15.0;

  /// Admin Panel feature-flag badge text — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for the [_AdminFlagRow] badge chip ONLY.
  /// Sits between [caption] 11 and [meta] 13; it MUST NOT appear in body copy,
  /// list rows, or any other surface.
  ///
  /// Source: `screens/bundle4.jsx` `FlagBadge`
  ///   `font: "500 12px/1"`
  static const double adminBadgeLabel = 12.0;

  /// Admin Panel hint-card title — design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for the [_AdminHintRow] title ONLY.
  /// Matches [buttonCompact] 14 numerically but is a distinct semantic role;
  /// it MUST NOT appear in buttons, body copy, or any other surface.
  ///
  /// Source: `screens/bundle4.jsx` `AdminPanel` hint card
  ///   `font: "600 14px/1.2"`
  static const double adminHintTitle = 14.0;

  /// Shared response toast (`NyanResponse`) title — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for the [NyanResponse] title
  /// line ONLY. Sits between [meta] 13 and [body] 16; it MUST NOT appear in
  /// body copy, headings, list rows, or any other surface.
  ///
  /// Source: `components/surfaces/NyanResponse.jsx`
  ///   `font: "600 14px/1.25 var(--font-ui)"`
  static const double responseTitle = 14.0;

  /// Bookshelf selection-mode header title — U21 design-system handoff exception
  /// (see AGENTS.md §4.2.5). Reserved for the "N selected" count title inside
  /// the selection-mode AppBar ONLY. Sits between [body] 16 and [section] 20;
  /// it MUST NOT appear in body copy, headings, list rows, or any other surface.
  ///
  /// Source: `screens/bundle3.jsx` `SelectionHeader`
  ///   `font: "600 18px/1.15 var(--font-ui)"`, `letterSpacing: -0.2px`
  static const double selectionHeaderTitle = 18.0;

  /// Shared response toast (`NyanResponse`) description — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for the [NyanResponse]
  /// description line ONLY. Sits between [caption] 11 and [meta] 13; it MUST
  /// NOT appear in body copy, list rows, or any other surface.
  ///
  /// Source: `components/surfaces/NyanResponse.jsx`
  ///   `font: "400 12.5px/1.35 var(--font-ui)"`
  static const double responseDescription = 12.5;

  /// U22 Discover block header title + Pro nudge upgrade button label —
  /// design-system handoff exception (see AGENTS.md §4.2.5).
  /// Sits between [meta] 13 and [body] 16. MUST NOT appear in body copy,
  /// headings, list rows, or any other surface.
  ///
  /// Source: `screens/U22 - Sponsored Shelf Placement.html` `BottomDiscover`
  ///   `font: "600 14.5px/1.25 var(--font-ui)"` (header title)
  ///   `font: "600 14.5px/1 var(--font-ui)"` (upgrade button)
  static const double discoverBlockTitle = 14.5;

  /// U22 Discover block "SPONSORED" badge label — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for the sponsored badge chip
  /// in [NyanShelfDiscoverBlock] ONLY. MUST NOT appear in body copy or any
  /// other surface.
  ///
  /// Source: `screens/U22 - Sponsored Shelf Placement.html` `BottomDiscover`
  ///   `font: "600 9.5px/1 var(--font-ui)"`, `letterSpacing: ".5px"`, uppercase
  static const double sponsoredBadge = 9.5;

  /// U22 Discover block mini-suggest tile title — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for book title text inside
  /// [_MiniSuggestTile] ONLY. MUST NOT appear in body copy or any other
  /// surface.
  ///
  /// Source: `screens/U22 - Sponsored Shelf Placement.html` `MiniSuggest`
  ///   `font: "600 11.5px/1.3 var(--font-ui)"`
  static const double miniSuggestTitle = 11.5;

  /// U22 Discover block mini-suggest tile author — design-system handoff
  /// exception (see AGENTS.md §4.2.5). Reserved for author text inside
  /// [_MiniSuggestTile] ONLY. MUST NOT appear in body copy or any other
  /// surface.
  ///
  /// Source: `screens/U22 - Sponsored Shelf Placement.html` `MiniSuggest`
  ///   `font: "400 10.5px/1.2 var(--font-ui)"`
  static const double miniSuggestAuthor = 10.5;

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
