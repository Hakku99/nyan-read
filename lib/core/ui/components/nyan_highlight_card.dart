import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';
import '../nyan_icons.dart';

class NyanHighlightCard extends StatelessWidget {
  final String label;
  final String excerpt;
  final Color highlightColor;
  final String? note;
  final String? meta;
  final String? noteTagLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NyanHighlightCard({
    super.key,
    required this.label,
    required this.excerpt,
    required this.highlightColor,
    this.note,
    this.meta,
    this.noteTagLabel,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardSurfaceColor = isDark
        ? Color.alphaBlend(
            nyanTheme.surface.withValues(alpha: 0.78),
            nyanTheme.background,
          )
        : theme.cardColor;
    final cardBorderColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.2 : 0.14,
    );
    final cardShadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.022),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ];
    final compactExcerpt = excerpt.replaceAll(RegExp(r'\s+'), ' ').trim();
    final compactNote = note?.replaceAll(RegExp(r'\s+'), ' ').trim();

    final content = Container(
      decoration: BoxDecoration(
        color: cardSurfaceColor,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        border: Border.all(color: cardBorderColor, width: 0.6),
        boxShadow: cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space12,
          vertical: NyanSpacing.space8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Container(
                    width: 5,
                    height: 40,
                    decoration: BoxDecoration(
                      color: highlightColor.withValues(
                        alpha: isDark ? 0.9 : 0.86,
                      ),
                      borderRadius: BorderRadius.circular(NyanRadius.small),
                    ),
                  ),
                ),
                const SizedBox(width: NyanSpacing.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: NyanSpacing.space8,
                        runSpacing: NyanSpacing.space4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              color: nyanTheme.textSecondary.withValues(
                                alpha: isDark ? 0.78 : 0.56,
                              ),
                              fontWeight: FontWeight.w500,
                              height: 1.04,
                            ),
                          ),
                          if (compactNote != null && compactNote.isNotEmpty)
                            _HighlightNoteTag(
                              label: noteTagLabel ?? 'Note',
                              color: highlightColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        compactExcerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: nyanTheme.textPrimary.withValues(
                            alpha: isDark ? 0.95 : 0.86,
                          ),
                          fontWeight: FontWeight.w400,
                          height: 1.22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (compactNote != null && compactNote.isNotEmpty) ...[
              const SizedBox(height: NyanSpacing.space8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    highlightColor.withValues(alpha: isDark ? 0.095 : 0.05),
                    isDark ? cardSurfaceColor : nyanTheme.surfaceMuted,
                  ),
                  borderRadius: BorderRadius.circular(NyanRadius.input),
                  border: isDark
                      ? Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.14),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      NyanIcons.editNote,
                      size: 14,
                      color: nyanTheme.textSecondary.withValues(
                        alpha: isDark ? 0.78 : 0.58,
                      ),
                    ),
                    const SizedBox(width: NyanSpacing.space8),
                    Expanded(
                      child: Text(
                        compactNote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: nyanTheme.textSecondary.withValues(
                            alpha: isDark ? 0.86 : 0.72,
                          ),
                          height: 1.26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (meta != null && meta!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                meta!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: nyanTheme.textSecondary.withValues(
                    alpha: isDark ? 0.82 : 0.56,
                  ),
                  fontWeight: FontWeight.w400,
                  height: 1.04,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        child: content,
      ),
    );
  }
}

class _HighlightNoteTag extends StatelessWidget {
  final String label;
  final Color color;

  const _HighlightNoteTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: isDark ? 0.08 : 0.06),
          nyanTheme.surfaceMuted,
        ),
        borderRadius: BorderRadius.circular(NyanRadius.small),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: nyanTheme.textSecondary.withValues(
            alpha: isDark ? 0.74 : 0.58,
          ),
          fontWeight: FontWeight.w600,
          height: 1.02,
        ),
      ),
    );
  }
}