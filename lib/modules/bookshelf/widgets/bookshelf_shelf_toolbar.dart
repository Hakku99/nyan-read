import 'package:flutter/material.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/ui/components/nyan_overlay_style.dart';
import 'package:nyan_read/modules/bookshelf/widgets/segmented_tab_control.dart';

const double _kShelfCardPadding = NyanSpacing.space12;
const double _kShelfSegmentedHeight = 40;

/// Subpixel borders / font metrics can exceed the nominal sum by 1px; keeps pinned header from clipping.
const double _kShelfPinnedLayoutSlack = 1;

/// Pinned sliver extent = card padding × 2 + segmented control height + slack.
const double kBookshelfShelfToolbarPinnedExtent =
    _kShelfCardPadding +
    _kShelfSegmentedHeight +
    _kShelfCardPadding +
    _kShelfPinnedLayoutSlack;

/// Bookshelf pinned tab strip. Per design spec the tab control is the only
/// element in the pinned chrome; sort / view-mode / lock actions live in the
/// [NyanPageHeader] action row above the scroll region.
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
      padding: const EdgeInsets.all(_kShelfCardPadding),
      child: SizedBox(
        height: _kShelfSegmentedHeight,
        child: SegmentedTabControl(
          style: SegmentedTabStyle.subtle,
          backgroundColor: NyanOverlayStyle.recessedSurface(context),
          tabs: tabs,
          selectedIndex: selectedIndex,
          onTabChanged: onTabChanged,
          labelLineHeight: 1.15,
        ),
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
    return SizedBox(
      height: maxExtent,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant BookshelfShelfPinnedHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}
