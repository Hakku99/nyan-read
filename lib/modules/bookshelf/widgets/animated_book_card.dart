import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../core/models/book.dart';
import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_shelf_ui.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/ui/nyan_theme_context.dart';

/// Animated book card for list view mode.
///
/// Per the design-system handoff (`bundle3.jsx` `BookListRow`), the list is a
/// single grouped panel: rows are borderless and divided by hairlines, with the
/// surface / radius / shadow owned by the enclosing [DecoratedSliver] group
/// (built in `home_screen.dart`). Each row therefore draws only its own top
/// divider ([showTopDivider]) and rounds its selection tint on the group's
/// outer corners ([isFirst] / [isLast]).
class AnimatedBookCardList extends StatefulWidget {
  final Book book;
  final Map<String, dynamic> bookData;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSelectionToggle;

  /// Draw a hairline divider above this row (every row except the group's first).
  final bool showTopDivider;

  /// Round the selection tint on the top / bottom outer corners so it follows
  /// the grouped panel's [NyanRadius.cardNested] edge.
  final bool isFirst;
  final bool isLast;

  const AnimatedBookCardList({
    super.key,
    required this.book,
    required this.bookData,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onSelectionToggle,
    this.showTopDivider = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<AnimatedBookCardList> createState() => _AnimatedBookCardListState();
}

class _AnimatedBookCardListState extends State<AnimatedBookCardList>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  bool _isSourceAvailable() {
    if (widget.book.sourceLocator.isEmpty) return false;
    // Android content URIs are always available if they're in the database
    if (widget.book.isAndroidContentUri) return true;
    try {
      return File(widget.book.sourceLocator).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    final progress = widget.book.currentProgress.clamp(0.0, 1.0);
    final hasProgress = progress > 0;
    final progressPercent = (progress * 100).round();
    final loc = AppLocalizations.of(context)!;

    // Author sits on its own line in the spec; format moves to a trailing chip.
    final author = widget.book.author.trim().isEmpty ||
            widget.book.author.trim().toLowerCase() == 'unknown'
        ? loc.unknownAuthor
        : widget.book.author;
    final format = widget.book.format.toUpperCase();

    // Selection tint follows the grouped panel's outer radius on its first /
    // last rows so the highlight never pokes past the rounded group edge.
    const radius = Radius.circular(NyanRadius.cardNested);
    final tintRadius = BorderRadius.only(
      topLeft: widget.isFirst ? radius : Radius.zero,
      topRight: widget.isFirst ? radius : Radius.zero,
      bottomLeft: widget.isLast ? radius : Radius.zero,
      bottomRight: widget.isLast ? radius : Radius.zero,
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hairline separator between rows (0.5px, inset 12pt) — drawn above
            // the tint so a selected neighbour can't bury it.
            if (widget.showTopDivider)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space12,
                ),
                child: Container(
                  height: 0.5,
                  color: nyan.divider.withValues(alpha: 0.34),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? context.selectionSurface
                    : Colors.transparent,
                borderRadius: tintRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space12,
                  vertical: NyanSpacing.space12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Selection checkbox (only in selection mode)
                    if (widget.isSelectionMode)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: NyanSpacing.space12),
                        child: Checkbox(
                          value: widget.isSelected,
                          onChanged: (val) => widget.onSelectionToggle?.call(),
                        ),
                      ),

                    // Portrait cover thumbnail — 44×58, r-chip, 20pt book glyph
                    Container(
                      width: NyanShelfUi.listCoverWidth,
                      height: NyanShelfUi.listCoverHeight,
                      decoration: BoxDecoration(
                        color: nyan.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(NyanRadius.chip),
                        border: Border.all(
                          color: nyan.divider.withValues(alpha: 0.30),
                          width: 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        NyanIcons.book,
                        size: NyanSpacing.space20,
                        color: nyan.primary,
                      ),
                    ),
                    const SizedBox(width: NyanSpacing.space12),

                    // Title / author / progress column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row — source-missing warning badge sits inline
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: NyanTypography.uiFontFamily,
                                    fontSize: 14,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: nyan.textPrimary,
                                  ),
                                ),
                              ),
                              if (!_isSourceAvailable())
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: NyanSpacing.space4,
                                  ),
                                  child: Tooltip(
                                    message: 'Source file missing',
                                    child: Icon(
                                      NyanIcons.warning,
                                      size: 14,
                                      color: Colors.amber[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Author — own line, muted
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NyanTypography.uiFontFamily,
                              fontSize: NyanTypography.meta - 1,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                              color: nyan.textMuted,
                            ),
                          ),
                          // Progress bar + percentage — only when started
                          if (hasProgress) ...[
                            const SizedBox(height: NyanSpacing.space8),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight:
                                          NyanShelfUi.progressBarHeight,
                                      backgroundColor: nyan.primary
                                          .withValues(alpha: 0.16),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        nyan.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: NyanSpacing.space8),
                                Text(
                                  '$progressPercent%',
                                  style: TextStyle(
                                    fontFamily: NyanTypography.monoFontFamily,
                                    fontSize: NyanTypography.shelfProgressLabel,
                                    height: 1.0,
                                    fontWeight: FontWeight.w500,
                                    color: nyan.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: NyanSpacing.space12),

                    // Format badge — TXT / EPUB / PDF pill
                    Container(
                      height: NyanShelfUi.listFormatChipHeight,
                      padding:
                          const EdgeInsets.symmetric(horizontal: NyanSpacing.space8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: nyan.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: nyan.divider.withValues(alpha: 0.44),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        format,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.shelfFormatChip,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
                          color: nyan.primaryDeep,
                        ),
                      ),
                    ),

                    // Trailing chevron (hidden in selection mode)
                    if (!widget.isSelectionMode) ...[
                      const SizedBox(width: NyanSpacing.space8),
                      Icon(
                        NyanIcons.chevronRight,
                        size: 15,
                        color: nyan.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Grid view uses NyanBookGridCard (lib/core/ui/components/nyan_book_grid_card.dart)
// directly — no animated wrapper needed for grid.
