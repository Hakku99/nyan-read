import 'nyan_spacing.dart';

/// Visual tokens shared by bookshelf hero, grid, and list tiles.
abstract final class NyanShelfUi {
  NyanShelfUi._();

  /// Thin progress track used on shelf cards and continue-reading hero.
  static const double progressBarHeight = 5;

  /// Grid gutters (equal cross/main).
  static const double gridCrossAxisSpacing = 14;
  static const double gridMainAxisSpacing = 14;

  /// Same rhythm as a grid row gap: pinned shelf → first row, list top, ad margins.
  static const double sectionGapAfterShelfChrome = gridMainAxisSpacing;

  /// 3-column shelf tiles: width/height. ~1.0 works with vertically centered card content.
  static const double gridChildAspectRatio = 1.0;

  /// Vertical gap between list-mode book cards (bottom margin per tile).
  /// Spec uses 12px gap for list vs 14px for grid — intentional asymmetry.
  static const double listTileSpacing = 12;

  /// Equal gaps between grid card blocks: icon — title — progress.
  static const double gridCardBlockGap = NyanSpacing.space8;

  /// Uniform padding on all 4 sides of the grid card — 12 pt per Claude Design
  /// spec (`shelf-grid.html` rule: "Padding 12 px on all four sides").
  static const double gridCardPadding = NyanSpacing.space12;

  /// Reduced padding used when the card is selected (border grows 1→2 px,
  /// so we subtract 1 pt to keep the inner content area identical:
  /// 12 − 1 = 11. Not a standard 8-grid value; derivation is 100% intentional).
  static const double gridCardSelectedPadding = 11.0;

  /// Minimum height of the title text slot — reserves 2 lines of
  /// 12.5 px × 1.28 line-height (= 32 px) so every card in a row
  /// shares the same content rhythm regardless of title length.
  static const double gridCardTitleMinHeight = 32.0;

  /// Horizontal inset for the main bookshelf scroll content (screen edge).
  static const double bookshelfPageHorizontalPadding = NyanSpacing.space12;

  /// Extra scroll extent beyond safe area so the FAB does not cover the last row.
  static const double scrollBottomFabClearance =
      NyanSpacing.space16 + 56 + NyanSpacing.space12;
}
