part of 'reader_page.dart';

class _ReaderOverlayToolBar extends StatelessWidget {
  const _ReaderOverlayToolBar({
    required this.showChapterNavigation,
    required this.showNotes,
    required this.onOpenChapters,
    required this.onAddBookmark,
    required this.onOpenBookmarks,
    required this.onOpenNotes,
    required this.onOpenSettings,
    required this.chromeWidth,
  });

  final bool showChapterNavigation;
  final bool showNotes;
  final VoidCallback onOpenChapters;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenSettings;
  final double chromeWidth;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (showChapterNavigation)
        ReaderOverlayToolButton(
          icon: Icons.toc_rounded,
          onTap: onOpenChapters,
        ),
      ReaderOverlayToolButton(
        icon: Icons.bookmark_add_outlined,
        onTap: onAddBookmark,
      ),
      ReaderOverlayToolButton(
        icon: Icons.bookmarks_rounded,
        onTap: onOpenBookmarks,
      ),
      if (showNotes)
        ReaderOverlayToolButton(
          icon: Icons.edit_note_rounded,
          onTap: onOpenNotes,
        ),
      ReaderOverlayToolButton(
        icon: Icons.tune_rounded,
        onTap: onOpenSettings,
        isAccent: true,
      ),
    ];

    final theme = Theme.of(context);

    return Center(
      child: Container(
        key: const Key('reader-overlay-toolbar'),
        width: chromeWidth,
        padding: kReaderOverlayChromePadding,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            theme.colorScheme.surface.withValues(alpha: 0.92),
            theme.scaffoldBackgroundColor,
          ),
          borderRadius: BorderRadius.circular(NyanRadius.panel),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.18),
            width: 0.72,
          ),
          boxShadow: NyanOverlayStyle.noticeShadow(context),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: NyanSpacing.space8),
                actions[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const double kSectionSpacing = 16.0;
const double kRowHeight = 56.0;

double _overlayChromeWidth({
  required bool showChapterNavigation,
  required bool showNotes,
  required double availableWidth,
  double horizontalSafeGutter = 4,
}) {
  final actionCount =
      2 + (showChapterNavigation ? 1 : 0) + (showNotes ? 1 : 0) + 1;
  final buttonWidth = NyanSpacing.minTapTarget;
  final innerSpacing = NyanSpacing.space8 * (actionCount - 1);
  final sidePadding = kReaderOverlayChromePadding.horizontal;
  final targetWidth = (actionCount * buttonWidth) + innerSpacing + sidePadding;
  final maxAllowed = math.max(0.0, availableWidth - horizontalSafeGutter);
  return math.min(targetWidth, maxAllowed);
}
