import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_overlay_style.dart';
import 'package:nyan_read/core/utils/chapter_heading_display.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../bookshelf/widgets/segmented_tab_control.dart';
import '../reader_engine/reader_engine.dart';

enum _TocSortOrder { asc, desc }

/// Handle + header + gaps + sort bar (see [ChapterListWidget] `build` structure).
const double _kTocSheetChromeHeight = 150;

/// Typical chapter row (badge + padding + up to 2 lines); tuning constant for compact estimate.
const double _kTocApproxRowHeight = 72;

/// Above this many visible rows we always use full-height sheet + virtualized list (no shrinkWrap).
const int _kTocMaxShrinkWrapRows = 48;

class ChapterListWidget extends StatefulWidget {
  final String bookTitle;
  final String? bookAuthor;
  final List<ReaderChapter> chapters;
  final int? currentChapterIndex;
  final double currentProgress;

  /// Max height for this sheet (e.g. 92% of screen). Used to choose compact vs full layout.
  final double maxSheetHeight;

  final void Function(int index, ChapterLocator locator) onChapterTap;

  const ChapterListWidget({
    super.key,
    required this.bookTitle,
    this.bookAuthor,
    required this.chapters,
    this.currentChapterIndex,
    required this.currentProgress,
    required this.maxSheetHeight,
    required this.onChapterTap,
  });

  @override
  State<ChapterListWidget> createState() => _ChapterListWidgetState();
}

class _ChapterListWidgetState extends State<ChapterListWidget> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  _TocSortOrder _sortOrder = _TocSortOrder.asc;
  bool _showJumpToCurrent = false;

  List<_ChapterEntry> get _visibleEntries {
    final loc = AppLocalizations.of(context)!;
    final entries = <_ChapterEntry>[];
    for (int i = 0; i < widget.chapters.length; i++) {
      final chapter = widget.chapters[i];
      final chapterIndex = chapter.index ?? i;
      final rawTitle =
          chapter.title.isNotEmpty ? chapter.title : loc.chapterName(i + 1);
      final candidate = _ChapterEntry(
        sourceIndex: i,
        chapterIndex: chapterIndex,
        chapter: chapter,
        title: normalizeChapterHeadingForDisplay(rawTitle),
        isCurrent: widget.currentChapterIndex == chapterIndex,
      );

      if (entries.isNotEmpty &&
          _isLikelyDuplicateChapter(entries.last.title, candidate.title)) {
        final preferred = _pickRicherTitle(entries.last, candidate);
        entries[entries.length - 1] = preferred;
      } else {
        entries.add(candidate);
      }
    }
    if (_sortOrder == _TocSortOrder.desc) {
      return entries.reversed.toList(growable: false);
    }
    return entries;
  }

  bool _isLikelyDuplicateChapter(String a, String b) {
    final aNo = extractChapterOrdinalFromHeading(a);
    final bNo = extractChapterOrdinalFromHeading(b);
    if (aNo == null || bNo == null || aNo != bNo) {
      return false;
    }
    return isGenericNumericChapterTitle(a) || isGenericNumericChapterTitle(b);
  }

  _ChapterEntry _pickRicherTitle(_ChapterEntry a, _ChapterEntry b) {
    final aGeneric = isGenericNumericChapterTitle(a.title);
    final bGeneric = isGenericNumericChapterTitle(b.title);
    if (aGeneric != bGeneric) {
      return aGeneric ? b : a;
    }
    return a.title.length >= b.title.length ? a : b;
  }

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions
        .addListener(_handleItemPositionsChanged);
    if (widget.currentChapterIndex != null &&
        widget.currentChapterIndex! >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToCurrentChapter(animated: false);
      });
    }
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions
        .removeListener(_handleItemPositionsChanged);
    super.dispose();
  }

  void _handleItemPositionsChanged() {
    final currentChapterIndex = widget.currentChapterIndex;
    if (currentChapterIndex == null) return;
    final entries = _visibleEntries;
    if (entries.isEmpty) return;
    final currentVisibleIndex =
        entries.indexWhere((item) => item.chapterIndex == currentChapterIndex);
    final visiblePositions = _itemPositionsListener.itemPositions.value
        .where((item) => item.itemLeadingEdge < 1 && item.itemTrailingEdge > 0)
        .map((item) => item.index)
        .toSet();
    final shouldShow = currentVisibleIndex == -1 ||
        !visiblePositions.contains(currentVisibleIndex);
    if (_showJumpToCurrent != shouldShow) {
      setState(() {
        _showJumpToCurrent = shouldShow;
      });
    }
  }

  void _jumpToCurrentChapter({required bool animated}) {
    if (!_itemScrollController.isAttached ||
        widget.currentChapterIndex == null) {
      return;
    }
    final index = _visibleEntries.indexWhere(
      (item) => item.chapterIndex == widget.currentChapterIndex,
    );
    if (index < 0) return;
    if (animated) {
      _itemScrollController.scrollTo(
        index: index,
        alignment: 0.1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _itemScrollController.jumpTo(index: index, alignment: 0.1);
    }
  }

  bool _shouldUseCompactSheet(BuildContext context, int visibleCount) {
    if (visibleCount > _kTocMaxShrinkWrapRows) return false;
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final estimate = _kTocSheetChromeHeight * scale +
        visibleCount * (_kTocApproxRowHeight * scale);
    return estimate <= widget.maxSheetHeight * 0.98;
  }

  Widget _buildListStack({
    required AppLocalizations loc,
    required List<_ChapterEntry> entries,
    required bool listShrinkWrap,
  }) {
    if (entries.isEmpty) {
      return _EmptyChapterState(label: loc.noChaptersDetected);
    }
    return Stack(
      children: [
        ScrollablePositionedList.builder(
          shrinkWrap: listShrinkWrap,
          itemCount: entries.length,
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: const EdgeInsets.fromLTRB(
            NyanSpacing.space12,
            NyanSpacing.space4,
            NyanSpacing.space12,
            NyanSpacing.space16,
          ).copyWith(
            bottom: NyanSpacing.space16 +
                (_showJumpToCurrent ? NyanSpacing.space32 : 0),
          ),
          itemBuilder: (context, index) {
            final item = entries[index];
            return ChapterListItem(
              title: item.title,
              indexLabel: '${item.sourceIndex + 1}',
              isCurrent: item.isCurrent,
              showDivider: index != entries.length - 1,
              onTap: () =>
                  widget.onChapterTap(item.sourceIndex, item.chapter.locator),
            );
          },
        ),
        if (_showJumpToCurrent)
          Positioned(
            right: NyanSpacing.space16,
            bottom: NyanSpacing.space16,
            child: Semantics(
              label: loc.jumpToCurrentChapter,
              child: FloatingActionButton.extended(
                heroTag: 'toc-jump-current',
                onPressed: () => _jumpToCurrentChapter(animated: true),
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  loc.jumpToCurrentChapter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSheetHeader(
    BuildContext context,
    AppLocalizations loc,
    NyanTheme nyanTheme,
  ) {
    return [
      Center(
        child: Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: nyanTheme.divider.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(NyanRadius.small),
          ),
        ),
      ),
      const SizedBox(height: NyanSpacing.space12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space16),
        child: _BookHeaderCard(
          title: widget.bookTitle,
          chapterCountText: loc.chapterCount(widget.chapters.length),
          onCopyTitle: () async {
            await Clipboard.setData(ClipboardData(text: widget.bookTitle));
          },
        ),
      ),
      const SizedBox(height: NyanSpacing.space12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space16),
        child: SegmentedTabControl(
          tabs: [
            SegmentedTab(label: loc.sortOrderAsc),
            SegmentedTab(label: loc.sortOrderDesc),
          ],
          selectedIndex: _sortOrder == _TocSortOrder.asc ? 0 : 1,
          onTabChanged: (index) {
            setState(() {
              _sortOrder = index == 0 ? _TocSortOrder.asc : _TocSortOrder.desc;
            });
          },
          backgroundColor: NyanOverlayStyle.recessedSurface(context),
          labelLineHeight: 1.15,
        ),
      ),
      const SizedBox(height: NyanSpacing.space12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = resolveNyanTheme(theme);
    final loc = AppLocalizations.of(context)!;
    final entries = _visibleEntries;
    final compact = _shouldUseCompactSheet(context, entries.length);

    final sheetBody = ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: true,
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._buildSheetHeader(context, loc, nyanTheme),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        NyanSpacing.space12,
                        0,
                        NyanSpacing.space12,
                        NyanSpacing.space16,
                      ),
                      child: _buildListStack(
                        loc: loc,
                        entries: entries,
                        listShrinkWrap: true,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            (widget.maxSheetHeight - _kTocSheetChromeHeight)
                                .clamp(120.0, widget.maxSheetHeight),
                      ),
                      child: _buildListStack(
                        loc: loc,
                        entries: entries,
                        listShrinkWrap: true,
                      ),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._buildSheetHeader(context, loc, nyanTheme),
                  Expanded(
                    child: _buildListStack(
                      loc: loc,
                      entries: entries,
                      listShrinkWrap: false,
                    ),
                  ),
                ],
              ),
      ),
    );

    if (compact) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxSheetHeight),
        child: sheetBody,
      );
    }
    return SizedBox(
      height: widget.maxSheetHeight,
      child: sheetBody,
    );
  }
}

class _ChapterEntry {
  final int sourceIndex;
  final int chapterIndex;
  final ReaderChapter chapter;
  final String title;
  final bool isCurrent;

  const _ChapterEntry({
    required this.sourceIndex,
    required this.chapterIndex,
    required this.chapter,
    required this.title,
    required this.isCurrent,
  });
}

class _BookHeaderCard extends StatelessWidget {
  final String title;
  final String chapterCountText;
  final VoidCallback onCopyTitle;

  const _BookHeaderCard({
    required this.title,
    required this.chapterCountText,
    required this.onCopyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = resolveNyanTheme(theme);
    final titleSmallSize = theme.textTheme.titleSmall?.fontSize ?? 14;
    final titleMediumSize = theme.textTheme.titleMedium?.fontSize ?? 20;
    // Between titleSmall and titleMedium: slightly larger than current, smaller than old header.
    final bookTitleFontSize =
        lerpDouble(titleSmallSize, titleMediumSize, 0.45)!;
    return InkWell(
      borderRadius: BorderRadius.circular(NyanRadius.panel),
      onLongPress: onCopyTitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space4,
          vertical: NyanSpacing.space4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: nyanTheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(NyanRadius.input),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.menu_book_rounded,
                  color: nyanTheme.primary, size: 19),
            ),
            const SizedBox(width: NyanSpacing.space12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: bookTitleFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: NyanSpacing.space8),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  chapterCountText,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChapterState extends StatelessWidget {
  final String label;

  const _EmptyChapterState({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NyanSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 42,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
            const SizedBox(height: NyanSpacing.space12),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ChapterListItem extends StatelessWidget {
  final String title;
  final String indexLabel;
  final bool isCurrent;
  final bool showDivider;
  final VoidCallback onTap;

  const ChapterListItem({
    super.key,
    required this.title,
    required this.indexLabel,
    required this.isCurrent,
    this.showDivider = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nyanTheme = resolveNyanTheme(Theme.of(context));
    final rowColor = isCurrent
        ? nyanTheme.primary.withValues(alpha: 0.08)
        : nyanTheme.surface.withValues(alpha: 0);
    final numberBg = isCurrent ? nyanTheme.primary : nyanTheme.surfaceMuted;
    final numberFg = isCurrent ? nyanTheme.onPrimary : nyanTheme.textSecondary;
    final titleColor =
        isCurrent ? nyanTheme.primaryDeep : nyanTheme.textPrimary;
    final loc = AppLocalizations.of(context)!;

    return Semantics(
      label:
          '$indexLabel, $title, ${isCurrent ? loc.jumpToCurrentChapter : ''}',
      button: true,
      child: Material(
        color: rowColor,
        borderRadius: BorderRadius.circular(NyanRadius.small),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NyanRadius.small),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space12,
              vertical: NyanSpacing.space12,
            ),
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(
                      bottom: BorderSide(
                        color: nyanTheme.divider.withValues(alpha: 0.34),
                        width: 0.5,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: numberBg,
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    indexLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: numberFg,
                    ),
                  ),
                ),
                const SizedBox(width: NyanSpacing.space12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ),
                if (isCurrent)
                  Icon(
                    Icons.play_arrow_rounded,
                    color: nyanTheme.primary,
                    size: 21,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
