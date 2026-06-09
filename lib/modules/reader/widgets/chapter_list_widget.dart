import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_shadows.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
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

  /// When false, drops the outer surface + height clamp so the widget can be
  /// embedded inside another surface (the One Paper dock). The host must then
  /// provide a bounded height (e.g. via a [Flexible]).
  final bool showSheetChrome;

  /// When false, drops the drag handle + book header card (the host supplies
  /// its own title/meta). The sort control + list are always kept.
  final bool showHeader;

  const ChapterListWidget({
    super.key,
    required this.bookTitle,
    this.bookAuthor,
    required this.chapters,
    this.currentChapterIndex,
    required this.currentProgress,
    required this.maxSheetHeight,
    required this.onChapterTap,
    this.showSheetChrome = true,
    this.showHeader = true,
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
          // When embedded in the dock (showSheetChrome=false), the dock's
          // SingleChildScrollView already provides 16pt horizontal padding —
          // adding our own 12pt here would double-pad the content and make rows
          // appear narrower than the spec. Standalone sheet owns its own margins.
          padding: EdgeInsets.fromLTRB(
            widget.showSheetChrome ? NyanSpacing.space12 : 0,
            NyanSpacing.space4,
            widget.showSheetChrome ? NyanSpacing.space12 : 0,
            NyanSpacing.space16 + (_showJumpToCurrent ? NyanSpacing.space32 : 0),
          ),
          itemBuilder: (context, index) {
            final item = entries[index];
            return ChapterListItem(
              title: item.title,
              indexLabel: '${item.sourceIndex + 1}',
              isCurrent: item.isCurrent,
              onTap: () =>
                  widget.onChapterTap(item.sourceIndex, item.chapter.locator),
            );
          },
        ),
        if (_showJumpToCurrent)
          Positioned(
            right: 0,
            bottom: 10,
            child: _JumpToCurrentButton(
              label: loc.jumpToCurrentChapter,
              onPressed: () => _jumpToCurrentChapter(animated: true),
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
      if (widget.showHeader) ...[
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
      ],
      // Horizontal padding: when embedded the dock body already provides 16pt,
      // so adding more here would double-pad and shrink the sort control.
      // Standalone sheet has no outer padding and needs the full 16pt margin.
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.showSheetChrome ? NyanSpacing.space16 : 0,
        ),
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
          style: SegmentedTabStyle.subtle,
          // surfaceMuted (#F1ECDD) is the correct spec track colour for the subtle
          // variant. recessedSurface (#F8F6F0) is too close to white and makes
          // the track imperceptible against the sheet surface.
          backgroundColor: nyanTheme.surfaceMuted,
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

    // Embedded in the One Paper dock: no surface, no outer height clamp.
    // The dock body is a SingleChildScrollView + Column(mainAxisSize.min), which
    // gives the child unbounded height — Expanded would collapse to 0pt there.
    // Instead, give ScrollablePositionedList a fixed SizedBox height so it can
    // virtualize correctly. The total content (~chrome 150 + list 370 = 520pt)
    // fits within maxSheetHeight, so the outer scroll is inactive.
    if (!widget.showSheetChrome) {
      final listHeight = (widget.maxSheetHeight - _kTocSheetChromeHeight)
          .clamp(120.0, widget.maxSheetHeight);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._buildSheetHeader(context, loc, nyanTheme),
          SizedBox(
            height: listHeight,
            child: _buildListStack(
              loc: loc,
              entries: entries,
              listShrinkWrap: false,
            ),
          ),
        ],
      );
    }

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
              child: Icon(NyanIcons.book,
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
              NyanIcons.book,
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
  final VoidCallback onTap;

  const ChapterListItem({
    super.key,
    required this.title,
    required this.indexLabel,
    required this.isCurrent,
    required this.onTap,
  });

  // Badge↔title gap from reader.jsx ReaderChapterList `gap: 14` — a component-
  // internal spec value, same category as the 6pt button icon-label exception.
  // MUST NOT be used outside chapter list rows.
  static const double _kBadgeTitleGap = 14.0;

  @override
  Widget build(BuildContext context) {
    final nyanTheme = resolveNyanTheme(Theme.of(context));
    final rowColor = isCurrent
        ? nyanTheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    final numberBg = isCurrent ? nyanTheme.primary : nyanTheme.surfaceMuted;
    // Spec: badge text when current = var(--nyan-surface), not onPrimary.
    // In light mode onPrimary resolves to creamBackground (#F6F3EA) while
    // surface is #FFFDF8 — both appear white on the green badge, but surface
    // is the contract value and diverges more noticeably in future theme work.
    final numberFg = isCurrent ? nyanTheme.surface : nyanTheme.textMuted;
    final titleColor =
        isCurrent ? nyanTheme.primaryDeep : nyanTheme.textPrimary;
    final loc = AppLocalizations.of(context)!;

    return Semantics(
      label:
          '$indexLabel, $title, ${isCurrent ? loc.jumpToCurrentChapter : ''}',
      button: true,
      child: Material(
        color: rowColor,
        borderRadius: BorderRadius.circular(NyanRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NyanRadius.chip),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space8,
              vertical: NyanSpacing.space12,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: numberBg,
                    borderRadius: BorderRadius.circular(NyanRadius.chip),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    indexLabel,
                    style: TextStyle(
                      fontFamily: NyanTypography.monoFontFamily,
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w500,
                      color: numberFg,
                    ),
                  ),
                ),
                const SizedBox(width: _kBadgeTitleGap),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight:
                          isCurrent ? FontWeight.w500 : FontWeight.w400,
                      color: titleColor,
                    ),
                  ),
                ),
                if (isCurrent)
                  Icon(
                    NyanIcons.playFilled,
                    color: nyanTheme.primary,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating "Jump to current" button for the Chapters sheet.
///
/// Spec: `bundle1.jsx` `ChapterDockSheet` — extended-FAB style, sticky
/// bottom-right of the scrollable list. Deep-matcha fill, surface glyph,
/// --r-dock radius (24pt), --shadow-light-card lift. Height 44, h-pad 18.
class _JumpToCurrentButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _JumpToCurrentButton({required this.label, required this.onPressed});

  // Icon↔label gap from spec `gap: 8` — internal to this button only.
  static const double _kIconLabelGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final nyan = resolveNyanTheme(Theme.of(context));
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nyan.primaryDeep,
          borderRadius: BorderRadius.circular(NyanRadius.dock),
          boxShadow: NyanShadows.lightCard(nyan),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(NyanRadius.dock),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(NyanRadius.dock),
            splashColor: nyan.surface.withValues(alpha: 0.12),
            highlightColor: nyan.surface.withValues(alpha: 0.08),
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      NyanIcons.jumpToCurrent,
                      size: 17,
                      color: nyan.surface,
                    ),
                    const SizedBox(width: _kIconLabelGap),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: NyanTypography.fabLabel,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: nyan.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
