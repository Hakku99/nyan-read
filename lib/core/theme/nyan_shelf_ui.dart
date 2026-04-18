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
  static const double listTileSpacing = 14;

  /// Equal gaps between grid card blocks: icon — title — progress.
  static const double gridCardBlockGap = NyanSpacing.space8;

  /// Horizontal inset for the main bookshelf scroll content (screen edge).
  static const double bookshelfPageHorizontalPadding = NyanSpacing.space12;

  /// Extra scroll extent beyond safe area so the FAB does not cover the last row.
  static const double scrollBottomFabClearance =
      NyanSpacing.space16 + 56 + NyanSpacing.space12;
}
