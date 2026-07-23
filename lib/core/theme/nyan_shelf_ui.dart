import 'nyan_spacing.dart';

/// Visual tokens shared by bookshelf hero, grid, and list tiles.
abstract final class NyanShelfUi {
  NyanShelfUi._();

  /// Thin progress track used on shelf cards and continue-reading hero.
  static const double progressBarHeight = 3;

  /// Grid gutters — cross (column gap) 12, main (row gap) 16 per bundle3.jsx spec.
  static const double gridCrossAxisSpacing = 12;
  static const double gridMainAxisSpacing = 16;

  /// Gap after the shelf chrome before the hero/content section begins.
  ///
  /// This is intentionally 10pt to keep the vertical rhythm consistent with
  /// the pinned toolbar, shelf tabs, status filters, and continue-reading card.
  static const double sectionGapAfterShelfChrome = 10;

  /// Cover portrait ratio for grid cards (120 × 156 per bundle3.jsx BookCard).
  static const double gridCoverAspectRatio = 120.0 / 156.0;

  /// Fixed height of the text section below the cover (progress bar + title
  /// with their gaps). Used by the home screen to compute childAspectRatio
  /// dynamically. Grid cards intentionally omit author metadata.
  static const double gridCardTextSectionHeight = 48.0;

  /// Vertical gap between list-mode book cards (bottom margin per tile).
  /// Spec uses 12px gap for list vs 14px for grid — intentional asymmetry.
  static const double listTileSpacing = 12;

  /// List-row thumbnail size — a small portrait cover, not a square badge
  /// (bundle3.jsx `BookListRow`: 44 × 58 with `r-chip` rounding).
  static const double listCoverWidth = 44;
  static const double listCoverHeight = 58;

  /// List-row format badge height (bundle3.jsx `BookListRow`: h18 pill).
  static const double listFormatChipHeight = 18;

  /// Minimum height of the title text slot below a grid cover — reserves 2
  /// lines of 12.5px × 1.28 line-height (= 32px) so every card in a row keeps
  /// the same vertical rhythm regardless of title length.
  static const double gridCardTitleMinHeight = 32.0;

  /// Horizontal inset for the main bookshelf scroll content (screen edge).
  static const double bookshelfPageHorizontalPadding = NyanSpacing.space12;

  /// Extra scroll extent beyond safe area so the FAB does not cover the last row.
  static const double scrollBottomFabClearance =
      NyanSpacing.space16 + 56 + NyanSpacing.space12;

  /// Extra scroll extent for selection mode — clears the floating SelectActionBar
  /// (height ≈ 68pt) + its 12pt bottom inset, plus breathing room.
  /// Source: `screens/bundle3.jsx` `BookshelfManage`: `padding-bottom: 104px`.
  static const double scrollBottomSelectionBarClearance = 104.0;
}
