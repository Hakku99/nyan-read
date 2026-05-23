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
      padding: padding ??
          const EdgeInsets.fromLTRB(
            NyanSpacing.space16,
            NyanSpacing.space16,
            NyanSpacing.space16,
            NyanSpacing.space12,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: NyanTypography.title,
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
            Row(children: actions!),
          ],
        ],
      ),
    );
  }
}
