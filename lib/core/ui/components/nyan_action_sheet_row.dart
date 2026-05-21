import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_sheet_appearance.dart';
import '../nyan_icons.dart';

class NyanActionSheetRow extends StatelessWidget {
  const NyanActionSheetRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NyanSheetAppearance.compactRowHorizontalPadding,
          vertical: NyanSheetAppearance.compactRowVerticalPadding,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(NyanRadius.small),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 17,
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: NyanSpacing.space4),
                  Text(
                    subtitle,
                    style: NyanSheetAppearance.compactDescriptionStyle(theme),
                  ),
                ],
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: NyanSpacing.space12),
              Icon(
                NyanIcons.chevronRight,
                size: 18,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.44),
              ),
            ],
          ],
        ),
      ),
    );
  }
}