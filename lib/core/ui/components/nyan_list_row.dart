import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/theme_presets.dart';
import '../nyan_icons.dart';

/// Canonical list-row primitive for settings, action sheets, and grouped lists.
///
/// Mirrors the Claude Design spec
/// (`nyan-read-design-system/project/preview/list-row.html`):
///
///   • 12pt leading↔content gap, 4pt title↔subtitle gap
///   • Title `w600 16/1.2`, subtitle `w400 13/1.3`
///   • Optional 36×36 [leadingIcon] chip — `NyanRadius.small` (14pt) corners,
///     `primary` @ 9% fill, 17pt glyph in `primary`
///   • Optional [showChevron] — `NyanIcons.chevronRight` at 18pt,
///     `textSecondary` @ 44% alpha
///   • Optional [danger] flag swaps title + chip into the error palette
///
/// **Deviation note (AGENTS.md §4.2.3 honored):** the design HTML uses 14pt
/// vertical padding; we stay on the 8-grid with `NyanSpacing.space12` (12pt).
/// The 2pt delta is a conscious trade — token discipline > visual exactness.
class NyanListRow extends StatelessWidget {
  final Widget? leading;

  /// Convenience: when set, renders a 36×36 primary-tinted icon chip on the
  /// leading edge. Mutually exclusive with [leading] (the explicit widget
  /// wins if both are provided).
  final IconData? leadingIcon;

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Convenience: when true, renders the canonical caret-right chevron on the
  /// trailing edge. Mutually exclusive with [trailing] (the explicit widget
  /// wins if both are provided).
  final bool showChevron;

  /// Destructive variant — title and built-in icon chip flip to the error
  /// palette. Affects [leadingIcon] only (custom [leading] widgets are not
  /// recolored).
  final bool danger;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? titleStyle;

  const NyanListRow({
    super.key,
    this.leading,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showChevron = false,
    this.danger = false,
    this.onTap,
    this.contentPadding,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);

    // Resolve leading widget: explicit `leading` wins over `leadingIcon`.
    final Widget? leadingWidget = leading ?? _buildIconChip(nyan);

    // Resolve trailing widget: explicit `trailing` wins over `showChevron`.
    final Widget? trailingWidget = trailing ?? _buildChevron(nyan);

    final Color titleColor = danger
        ? nyan.errorPrimaryTextColor
        : (theme.textTheme.bodyLarge?.color ?? nyan.textPrimary);

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
            if (leadingWidget != null) ...[
              leadingWidget,
              const SizedBox(width: NyanSpacing.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle ??
                        theme.textTheme.bodyLarge?.copyWith(
                          // Spec: `font:600 16/1.2`.
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: titleColor,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      subtitle!,
                      // Spec: `font:400 13/1.3` — bodySmall already matches.
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: NyanSpacing.space12),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: NyanSpacing.minTapTarget,
                  minHeight: NyanSpacing.minTapTarget,
                ),
                child: Center(child: trailingWidget),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 36×36 icon chip per Claude Design spec.
  /// `primary` @ 9% fill (or `errorBackgroundColor` tint when [danger]),
  /// 17pt glyph in the matching accent color.
  Widget? _buildIconChip(NyanTheme nyan) {
    final icon = leadingIcon;
    if (icon == null) return null;

    final Color chipBg;
    final Color chipFg;
    if (danger) {
      chipBg = nyan.errorBackgroundColor;
      chipFg = nyan.errorPrimaryTextColor;
    } else {
      chipBg = nyan.primary.withValues(alpha: 0.09);
      chipFg = nyan.primary;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(NyanRadius.small),
      ),
      // Spec glyph size: 17pt — sits between space16 and space20 so we
      // use the literal with this explanation rather than a new token.
      child: Icon(icon, size: 17, color: chipFg),
    );
  }

  /// Trailing caret-right chevron — 18pt glyph at 44% `textSecondary`
  /// alpha (matches `color-mix(--nyan-text-secondary 44%)` in the spec).
  Widget? _buildChevron(NyanTheme nyan) {
    if (!showChevron) return null;
    return Icon(
      NyanIcons.chevronRight,
      // Spec glyph size: 18pt — literal with this explanation.
      size: 18,
      color: nyan.textSecondary.withValues(alpha: 0.44),
    );
  }
}
