import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';

class NyanListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const NyanListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NyanRadius.card),
      child: Padding(
        padding: contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space16,
              vertical: NyanSpacing.space12,
            ),
        child: Row(
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: NyanSpacing.space12),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: NyanSpacing.minTapTarget,
                  minHeight: NyanSpacing.minTapTarget,
                ),
                child: Center(child: trailing),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
