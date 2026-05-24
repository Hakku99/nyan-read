import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../core/models/book.dart';
import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_shelf_ui.dart';
import '../../../core/theme/nyan_shadows.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/ui/nyan_theme_context.dart';

/// Animated book card for list view mode
class AnimatedBookCardList extends StatefulWidget {
  final Book book;
  final Map<String, dynamic> bookData;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSelectionToggle;

  const AnimatedBookCardList({
    super.key,
    required this.book,
    required this.bookData,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onSelectionToggle,
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
    final theme = Theme.of(context);
    final nyan = context.nyanTheme;

    final progress = widget.book.currentProgress.clamp(0.0, 1.0);
    final loc = AppLocalizations.of(context)!;

    // Meta line: "Author · FORMAT" — mirrors spec `{b.author} · {b.format}`.
    final author = widget.book.author.trim().isEmpty ||
            widget.book.author.trim().toLowerCase() == 'unknown'
        ? loc.unknownAuthor
        : widget.book.author;
    final format = widget.book.format.toUpperCase();
    final metaText = '$author · $format';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: NyanShelfUi.listTileSpacing),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NyanRadius.card),
          border: Border.all(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.12),
            width: widget.isSelected ? 2 : 1,
          ),
          color: widget.isSelected ? context.selectionSurface : theme.cardColor,
          boxShadow: NyanShadows.subtle(theme.shadowColor),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: NyanSpacing.space12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Selection checkbox (only in selection mode)
                if (widget.isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: NyanSpacing.space12),
                    child: Checkbox(
                      value: widget.isSelected,
                      onChanged: (val) => widget.onSelectionToggle?.call(),
                    ),
                  ),

                // Icon badge: primary @ 12% background, radius-small, 22pt book icon
                Container(
                  padding: const EdgeInsets.all(NyanSpacing.space8),
                  decoration: BoxDecoration(
                    color: nyan.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                  ),
                  child: Icon(
                    NyanIcons.book,
                    size: 22,
                    color: nyan.primary,
                  ),
                ),
                const SizedBox(width: NyanSpacing.space12),

                // Text + progress column
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
                                fontSize: 15,
                                height: 1.3,
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
                      // Meta: "Author · FORMAT"
                      Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.meta,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          color: nyan.textSecondary,
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      // Progress bar: 70% width, 5pt height, spec radius 999
                      FractionallySizedBox(
                        widthFactor: 0.7,
                        alignment: Alignment.centerLeft,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: NyanShelfUi.progressBarHeight,
                            backgroundColor: nyan.primary.withValues(alpha: 0.18),
                            valueColor: AlwaysStoppedAnimation<Color>(nyan.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing chevron (hidden in selection mode; checkbox takes that role)
                if (!widget.isSelectionMode) ...[
                  const SizedBox(width: NyanSpacing.space8),
                  Icon(
                    NyanIcons.chevronRight,
                    size: 18,
                    color: nyan.textSecondary.withValues(alpha: 0.44),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Grid view uses NyanBookGridCard (lib/core/ui/components/nyan_book_grid_card.dart)
// directly — no animated wrapper needed for grid.
