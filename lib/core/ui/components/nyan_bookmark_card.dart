import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';
import '../nyan_icons.dart';

class NyanBookmarkCard extends StatelessWidget {
  static const double _leadingSlotWidth = 12;
  static const double _indicatorInset = 1;

  final String label;
  final String excerpt;
  final String? note;
  final String? meta;
  final VoidCallback? onTap;
  final String? noteTagLabel;

  const NyanBookmarkCard({
    super.key,
    required this.label,
    required this.excerpt,
    this.note,
    this.meta,
    this.onTap,
    this.noteTagLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final compactNote = note?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final cardBorderColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.12 : 0.14,
    );
    final cardShadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: nyanTheme.textPrimary.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ];

    final content = Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        border: Border.all(color: cardBorderColor, width: 0.6),
        boxShadow: cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(NyanSpacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: NyanSpacing.space8,
              runSpacing: NyanSpacing.space4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _BookmarkMetaLine(label: label),
                if (compactNote != null && compactNote.isNotEmpty)
                  _BookmarkNoteTag(label: noteTagLabel ?? 'Note'),
              ],
            ),
            const SizedBox(height: NyanSpacing.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _leadingSlotWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: _indicatorInset),
                      child: Container(
                        width: 2,
                        height: 12,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: nyanTheme.primary.withValues(
                            alpha: isDark ? 0.36 : 0.28,
                          ),
                          borderRadius: BorderRadius.circular(NyanRadius.small),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    excerpt.replaceAll(RegExp(r'\s+'), ' ').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: nyanTheme.textPrimary.withValues(
                        alpha: isDark ? 0.86 : 0.8,
                      ),
                      fontWeight: FontWeight.w400,
                      height: 1.12,
                    ),
                  ),
                ),
              ],
            ),
            if (meta != null && meta!.isNotEmpty) ...[
              const SizedBox(height: NyanSpacing.space8),
              Text(
                meta!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: nyanTheme.textSecondary.withValues(
                    alpha: isDark ? 0.58 : 0.5,
                  ),
                  fontWeight: FontWeight.w400,
                  height: 1.05,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        child: content,
      ),
    );
  }
}

class _BookmarkMetaLine extends StatelessWidget {
  final String label;

  const _BookmarkMetaLine({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: NyanBookmarkCard._leadingSlotWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              NyanIcons.bookmark,
              size: 12,
              color: nyanTheme.primary.withValues(alpha: isDark ? 0.76 : 0.7),
            ),
          ),
        ),
        const SizedBox(width: NyanSpacing.space4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: nyanTheme.textSecondary.withValues(
              alpha: isDark ? 0.7 : 0.62,
            ),
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _BookmarkNoteTag extends StatelessWidget {
  final String label;

  const _BookmarkNoteTag({required this.label});

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
          nyanTheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
          nyanTheme.surfaceMuted,
        ),
        borderRadius: BorderRadius.circular(NyanRadius.small),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: nyanTheme.textSecondary.withValues(
            alpha: isDark ? 0.7 : 0.62,
          ),
          fontWeight: FontWeight.w600,
          height: 1.05,
        ),
      ),
    );
  }
}
