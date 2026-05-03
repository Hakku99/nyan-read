import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';

/// Olive section title above grouped cards — same vocabulary as
/// [SettingsPage] (`_SectionHeader`). Uses [FontWeight.w600] per AGENTS.md
/// (Settings historically used w700).
///
/// Pass `withLeadingDot: true` to add a small olive dot before the title — a
/// quietly distinctive accent used by Book Details, opt-out by default so the
/// Settings page renders unchanged.
class NyanSectionHeader extends StatelessWidget {
  const NyanSectionHeader({
    super.key,
    required this.title,
    this.padding,
    this.withLeadingDot = false,
  });

  final String title;
  final EdgeInsetsGeometry? padding;
  final bool withLeadingDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.9 : 0.9,
    );

    final titleWidget = Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: NyanTypography.meta,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.22,
        color: accent,
      ),
    );

    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            NyanSpacing.space16,
            0,
            NyanSpacing.space16,
            NyanSpacing.space12,
          ),
      child: withLeadingDot
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: NyanSpacing.space8),
                titleWidget,
              ],
            )
          : titleWidget,
    );
  }
}
