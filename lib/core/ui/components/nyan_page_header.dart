import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../nyan_theme_context.dart';

class NyanPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const NyanPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return Padding(
      // Spec (_chrome.jsx PageHdr): padding "16px 12px 12px" = t:16 h:12 b:12.
      padding: padding ??
          const EdgeInsets.fromLTRB(
            NyanSpacing.space12,
            NyanSpacing.space16,
            NyanSpacing.space12,
            NyanSpacing.space12,
          ),
      // Spec (_chrome.jsx PageHdr): alignItems = subtitle ? flex-start : center.
      child: Row(
        crossAxisAlignment: subtitle != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: NyanSpacing.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(
                        // Spec (_chrome.jsx PageHdr): font "600 20px/1.2".
                  fontSize: NyanTypography.section,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: nyanTheme.textPrimary,
                      )
                      .merge(titleStyle),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: NyanSpacing.space4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                          fontSize: NyanTypography.meta,
                          color: nyanTheme.textMuted,
                          height: 1.35,
                        )
                        .merge(subtitleStyle),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: NyanSpacing.space12),
            Row(
              children: [
                for (int i = 0; i < actions!.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  actions![i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
