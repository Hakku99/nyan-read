import 'package:flutter/material.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_info_card.dart';
import 'package:nyan_read/core/ui/components/nyan_overlay_style.dart';
import 'package:nyan_read/modules/bookshelf/widgets/segmented_tab_control.dart';

/// Must match [BookshelfShelfToolbar] structure: card padding + fixed segment + gap + fixed tool row.
/// Tool row is explicitly [SizedBox] height [NyanSpacing.minTapTarget] so intrinsic height is stable.
const double _kShelfCardPadding = NyanSpacing.space12;
const double _kShelfSegmentedHeight = 40;
const double _kShelfTabToolsGap = 8;

/// Subpixel borders / font metrics can exceed the nominal sum by 1px; keeps pinned header from clipping.
const double _kShelfPinnedLayoutSlack = 1;

/// Pinned sliver extent = structural sum + [_kShelfPinnedLayoutSlack].
const double kBookshelfShelfToolbarPinnedExtent =
    _kShelfCardPadding +
    _kShelfSegmentedHeight +
    _kShelfTabToolsGap +
    NyanSpacing.minTapTarget +
    _kShelfCardPadding +
    _kShelfPinnedLayoutSlack;

/// Bookshelf shelf chrome. Uses the same [SegmentedTabControl] + [SegmentedTabStyle.emphasis] as
/// reader settings so the app reads as one system; hero CTA stays visually heavier via size/layout.
///
/// Row 1: full-width [SegmentedTabControl]. Row 2: optional [toolbarLeading] + right-aligned
/// [toolbarActions]. Lock/unlock privacy belongs on actions, not on the private tab.
class BookshelfShelfToolbar extends StatelessWidget {
  const BookshelfShelfToolbar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    required this.toolbarActions,
    this.toolbarLeading,
  });

  final List<SegmentedTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final List<Widget> toolbarActions;

  /// Optional left side on row 2 (e.g. shelf context). Keep lightweight; avoid duplicating tab labels.
  final Widget? toolbarLeading;

  @override
  Widget build(BuildContext context) {
    return NyanInfoCard(
      padding: const EdgeInsets.all(_kShelfCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _kShelfSegmentedHeight,
            child: SegmentedTabControl(
              style: SegmentedTabStyle.emphasis,
              backgroundColor: NyanOverlayStyle.recessedSurface(context),
              tabs: tabs,
              selectedIndex: selectedIndex,
              onTabChanged: onTabChanged,
              labelLineHeight: 1.15,
            ),
          ),
          const SizedBox(height: _kShelfTabToolsGap),
          SizedBox(
            height: NyanSpacing.minTapTarget,
            child: Row(
              mainAxisAlignment: toolbarLeading == null
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (toolbarLeading != null) ...[
                  Expanded(child: toolbarLeading!),
                  const SizedBox(width: NyanSpacing.space8),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < toolbarActions.length; i++) ...[
                      if (i != 0) const SizedBox(width: NyanSpacing.space8),
                      toolbarActions[i],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned shelf strip: surface background + 1dp divider using [NyanTheme.divider].
class BookshelfShelfPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  BookshelfShelfPinnedHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);
    final bottomAlpha = theme.brightness == Brightness.dark ? 0.35 : 0.28;

    // Use scaffold background so the square [Material] behind [NyanInfoCard]'s rounded rect does
    // not read as bright "corner slivers" (card leaves the bbox corners unpainted; surface≠scaffold).
    return SizedBox(
      height: maxExtent,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: nyan.divider.withValues(alpha: bottomAlpha),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant BookshelfShelfPinnedHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}
