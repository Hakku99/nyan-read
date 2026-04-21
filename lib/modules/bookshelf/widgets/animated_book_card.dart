import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../core/models/book.dart';
import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_shelf_ui.dart';
import '../../../core/theme/nyan_shadows.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/nyan_theme_context.dart';
import '../../../core/utils/datetime_utils.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate progress percentage
    final progress = widget.book.currentProgress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).toStringAsFixed(0);

    // Format last read time with relative labels
    final loc = AppLocalizations.of(context)!;
    String lastReadText = loc.neverRead;
    if (widget.bookData['last_read_at'] != null) {
      final now = DateTime.now();
      lastReadText = DateTimeUtils.formatRelativeTimeFromMillis(
        widget.bookData['last_read_at'] as int,
        now,
        loc,
      );
    } else if (progress > 0) {
      // Progress is already shown on the row below; avoid "Never read" + percent mismatch.
      lastReadText = '';
    }

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
          color: widget.isSelected
              ? context.selectionSurface
              : theme.cardColor,
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
            padding: const EdgeInsets.all(NyanSpacing.space12),
            child: Row(
              children: [
                if (widget.isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: NyanSpacing.space12),
                    child: Checkbox(
                      value: widget.isSelected,
                      onChanged: (val) => widget.onSelectionToggle?.call(),
                    ),
                  ),

                // Book icon container
                Container(
                  padding: const EdgeInsets.all(NyanSpacing.space8),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: NyanSpacing.space16),

                // Book info: title row + status, then progress + percent
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.book.title,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.28,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.15,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!widget.isSelectionMode &&
                              lastReadText.isNotEmpty) ...[
                            const SizedBox(width: NyanSpacing.space8),
                            Text(
                              lastReadText,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                NyanShelfUi.progressBarHeight / 2,
                              ),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(begin: 0, end: progress),
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: NyanShelfUi.progressBarHeight,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.18),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: NyanSpacing.space8),
                          Text(
                            '$progressPercent%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated book card for grid view mode
class AnimatedBookCardGrid extends StatefulWidget {
  final Book book;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AnimatedBookCardGrid({
    super.key,
    required this.book,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<AnimatedBookCardGrid> createState() => _AnimatedBookCardGridState();
}

class _AnimatedBookCardGridState extends State<AnimatedBookCardGrid>
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NyanRadius.input),
                border: Border.all(
                  color: widget.isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: widget.isSelected ? 3 : 1,
                ),
                color: widget.isSelected
                    ? context.selectionSurface
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                boxShadow: NyanShadows.subtle(theme.shadowColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NyanRadius.input),
                child: Stack(
                  children: [
                    // Main content
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: NyanSpacing.space16),
                          // Book icon container
                          Container(
                            padding: const EdgeInsets.all(NyanSpacing.space8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(NyanRadius.small),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: NyanSpacing.space8),
                          // Title with gradient
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NyanSpacing.space4,
                            ),
                            child: Text(
                              widget.book.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom gradient for title readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              theme.cardColor.withValues(alpha: 0.9),
                              theme.cardColor.withValues(alpha: 0.0),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(NyanRadius.input),
                            bottomRight: Radius.circular(NyanRadius.input),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Selection indicator
            if (widget.isSelectionMode)
              Positioned(
                top: NyanSpacing.space8,
                right: NyanSpacing.space8,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(NyanSpacing.space4),
                    child: widget.isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : const SizedBox(width: 16, height: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
