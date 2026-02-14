import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/book.dart';

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
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Calculate progress percentage
    final progress =
        (widget.bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
    final progressPercent = (progress * 100).toInt();

    // Format last read time
    String lastReadText = 'Never read';
    if (widget.bookData['last_read_at'] != null) {
      final lastRead = DateTime.fromMillisecondsSinceEpoch(
          widget.bookData['last_read_at'] as int);
      lastReadText = dateFormat.format(lastRead);
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor,
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        color: widget.isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.2)
            : theme.cardColor,
        elevation: 0,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                if (widget.isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Checkbox(
                      value: widget.isSelected,
                      onChanged: (val) => widget.onSelectionToggle?.call(),
                    ),
                  ),

                // Book icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),

                // Book info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.book.author} · ${widget.book.format.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.3,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                          const SizedBox(width: 10),
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

                const SizedBox(width: 12),

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
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: widget.isSelected
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                  width: widget.isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              child: Stack(
                children: [
                  // Main content
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Book icon container
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Title with gradient
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text(
                            widget.book.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
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
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (widget.isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
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
