import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shelf_ui.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';
import '../nyan_icons.dart';

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
              borderRadius: BorderRadius.circular(NyanRadius.card),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.12),
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? context.selectionSurface
                  : theme.cardColor,
              boxShadow: NyanShadows.subtle(theme.shadowColor),
            ),
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                // 12 pt uniform padding per spec; shrinks to 11 pt when
                // selected so the 2 px border doesn't compress inner content.
                padding: EdgeInsets.all(
                  isSelected
                      ? NyanShelfUi.gridCardSelectedPadding
                      : NyanShelfUi.gridCardPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(NyanSpacing.space4),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(NyanRadius.small),
                        ),
                        child: Icon(
                          NyanIcons.book,
                          size: 26,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: NyanShelfUi.gridCardBlockGap),
                    // Fixed 2-line height reserve: 2 × (12.5 × 1.28) = 32 pt.
                    // Keeps icon-top and progress-top aligned across every card
                    // in the row regardless of title length.
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: NyanShelfUi.gridCardTitleMinHeight,
                      ),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    SizedBox(height: NyanShelfUi.gridCardBlockGap),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        NyanShelfUi.progressBarHeight / 2,
                      ),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: NyanShelfUi.progressBarHeight,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          NyanIcons.check,
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
