import 'package:flutter/material.dart';
import 'package:nyan_read/core/theme/nyan_shadows.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/ui/nyan_theme_context.dart';
import 'package:nyan_read/modules/bookshelf/widgets/segmented_tab_control.dart';

/// Vertical inset above + below the track (drives the pinned sliver extent).
/// Top = 0: gap above tabs comes entirely from the toolbar's bottom padding (8pt).
/// Bottom = 10: spec `bundle4.jsx` tab wrapper `marginBottom: 10` (§4.6 takes priority).
// ponytail: 10pt is off the 8pt grid by 2pt — pixel-perfect spec value.
const double _kShelfTrackVerticalPaddingTop = 0;
const double _kShelfTrackVerticalPaddingBottom = 10;

/// Horizontal inset — 16pt, matching the toolbar and content slivers.
/// (Outer scaffold Padding no longer contributes horizontal inset.)
const double _kShelfTrackHorizontalPadding = NyanSpacing.space16;

const double _kShelfSegmentedHeight = 40;

/// Subpixel borders / font metrics can exceed the nominal sum by 1px; keeps pinned header from clipping.
const double _kShelfPinnedLayoutSlack = 1;

/// Pinned sliver extent = top padding + segmented control height + bottom padding + slack.
const double kBookshelfShelfToolbarPinnedExtent =
    _kShelfTrackVerticalPaddingTop +
    _kShelfSegmentedHeight +
    _kShelfTrackVerticalPaddingBottom +
    _kShelfPinnedLayoutSlack;

/// Bookshelf pinned tab strip. The tab control is the only element in the
/// pinned chrome; toolbar actions live in the [_ShelfToolbarDelegate] above.
class BookshelfShelfToolbar extends StatelessWidget {
  const BookshelfShelfToolbar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final List<SegmentedTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kShelfTrackHorizontalPadding,
        _kShelfTrackVerticalPaddingTop,
        _kShelfTrackHorizontalPadding,
        _kShelfTrackVerticalPaddingBottom,
      ),
      child: SizedBox(
        height: _kShelfSegmentedHeight,
        child: SegmentedTabControl(
          style: SegmentedTabStyle.shelf,
          // No backgroundColor override — the shelf variant uses the default
          // surfaceMuted track (BookshelfScreen.jsx), which reads as a warm
          // recessed beige against the page and the white selected chip.
          tabs: tabs,
          selectedIndex: selectedIndex,
          onTabChanged: onTabChanged,
          // Spec label is `14px/1`; 1.0 line-height centres cleanly in the chip.
          labelLineHeight: 1.0,
        ),
      ),
    );
  }
}

/// Pinned shelf strip: scaffold background colour, no bottom border.
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
    final nyan = context.nyanTheme;
    // Shadow + hairline bottom border appear only once content scrolls beneath
    // the pinned strip — spec `bundle4.jsx` tab wrapper:
    //   box-shadow: 0 6px 14px -8px rgba(40,36,30,.22)
    //   border-bottom: 1px solid color-mix(in srgb, var(--nyan-divider) 22%, transparent)
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: overlapsContent ? NyanShadows.shelfPinnedHeader(nyan) : const [],
        border: overlapsContent
            ? Border(
                bottom: BorderSide(
                  color: nyan.divider.withValues(alpha: 0.22),
                  width: 1,
                ),
              )
            : null,
      ),
      child: SizedBox(height: maxExtent, child: child),
    );
  }

  @override
  bool shouldRebuild(covariant BookshelfShelfPinnedHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}
