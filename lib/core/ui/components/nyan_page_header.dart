import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';

class NyanPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  const NyanPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: NyanTypography.title,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: NyanSpacing.space4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: NyanTypography.meta,
                    ),
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
