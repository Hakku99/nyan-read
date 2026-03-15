import 'package:flutter/material.dart';

import '../nyan_theme_context.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import 'nyan_info_card.dart';

enum NyanInlineAdDensity { regular, compact }

class NyanInlineAdCard extends StatelessWidget {
  final String sponsoredLabel;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final Widget? leading;
  final NyanInlineAdDensity density;

  const NyanInlineAdCard({
    super.key,
    required this.sponsoredLabel,
    required this.title,
    required this.description,
    this.onTap,
    this.leading,
    this.density = NyanInlineAdDensity.regular,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isCompact = density == NyanInlineAdDensity.compact;
    final cardPadding = isCompact ? NyanSpacing.space8 : NyanSpacing.space12;
    final iconPadding = isCompact ? NyanSpacing.space8 : NyanSpacing.space12;
    final horizontalGap = isCompact ? NyanSpacing.space8 : NyanSpacing.space12;
    final labelGap = isCompact ? NyanSpacing.space4 : NyanSpacing.space8;

    return NyanInfoCard(
      onTap: onTap,
      padding: EdgeInsets.all(cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              color: nyanTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(NyanRadius.small),
            ),
            child: leading ??
                Icon(
                  Icons.auto_stories_outlined,
                  size: isCompact ? NyanSpacing.space16 : NyanSpacing.space20,
                  color: nyanTheme.primary,
                ),
          ),
          SizedBox(width: horizontalGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sponsoredLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: nyanTheme.textSecondary,
                  ),
                ),
                SizedBox(height: labelGap),
                Text(
                  title,
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nyanTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: NyanSpacing.space4),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.25,
                    color: nyanTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: NyanSpacing.space8),
            Icon(
              Icons.chevron_right_rounded,
              size: NyanSpacing.space20,
              color: nyanTheme.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}
