import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../core/models/book.dart';
import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_shadows.dart';
import '../../../core/theme/nyan_spacing.dart';
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
    final progress =
        (widget.bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
    final progressPercent = (progress * 100).toInt();

    // Format last read time with relative labels
    String lastReadText = AppLocalizations.of(context)!.neverRead;
    if (widget.bookData['last_read_at'] != null) {
      final now = DateTime.now();
      lastReadText = DateTimeUtils.formatRelativeTimeFromMillis(
        widget.bookData['last_read_at'] as int,
        now,
        AppLocalizations.of(context)!,
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: NyanSpacing.space4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          border: Border.all(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.1),
            width: widget.isSelected ? 2 : 1,
          ),
          color: widget.isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.2)
              : theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: NyanSpacing.space16),

                // Book info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      // Rounded progress bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                tween: Tween<double>(begin: 0, end: progress),
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    minHeight: 4,
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.primary
                                          .withOpacity(0.6),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: NyanSpacing.space8),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: NyanSpacing.space12),

                // Last read time
                if (!widget.isSelectionMode)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastReadText,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                    ],
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
                      : theme.colorScheme.outline.withOpacity(0.1),
                  width: widget.isSelected ? 3 : 1,
                ),
                color: widget.isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.2)
                    : theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
                              color: theme.colorScheme.primary.withOpacity(0.1),
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
                              theme.cardColor.withOpacity(0.9),
                              theme.cardColor.withOpacity(0.0),
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
                        : Colors.grey.withOpacity(0.5),
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
