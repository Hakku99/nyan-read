import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';

class NyanBookGridCard extends StatelessWidget {
  final Book book;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NyanBookGridCard({
    super.key,
    required this.book,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.currentProgress.clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NyanRadius.input),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.12),
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.28 : 0.45,
                    ),
              boxShadow: NyanShadows.subtle(theme.shadowColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(NyanSpacing.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(NyanSpacing.space12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(NyanRadius.small),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: NyanSpacing.space32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: NyanSpacing.space8),
                  Text(
                    book.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: NyanSpacing.space8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: NyanSpacing.space4,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelectionMode)
            Positioned(
              top: NyanSpacing.space8,
              right: NyanSpacing.space8,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(NyanSpacing.space4),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: NyanSpacing.space16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : const SizedBox(
                          width: NyanSpacing.space16,
                          height: NyanSpacing.space16,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
