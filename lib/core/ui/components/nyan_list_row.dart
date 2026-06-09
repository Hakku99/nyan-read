import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../../theme/theme_presets.dart';
import '../nyan_icons.dart';

/// Canonical list-row primitive for settings, action sheets, and grouped lists.
///
/// Mirrors the Claude Design spec
/// (`nyan-read-design-system/project/preview/list-row.html`):
///
///   • 12pt vertical / 16pt horizontal padding, 12pt leading↔content gap
///   • minHeight 44pt (spec: `min-height: 44`)
///   • Title `w500 15/1.2`, subtitle `w400 13/1.3 textSecondary`
///   • Optional 32×32 [leadingIcon] chip — `NyanRadius.chip` (12pt) corners,
///     9% primary / surfaceMuted (opaque), 16pt glyph in `primary`
///   • Optional [showChevron] — `NyanIcons.chevronRight` (`ph-caret-right`)
///     at 16pt, `textMuted` color
///   • Optional [danger] flag swaps title + chip into the error palette
///
/// Source: `screens/_chrome.jsx` `ListRow` (canonical superset, Phase-4 HANDOFF).
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
      child: ConstrainedBox(
        // Spec: `min-height: 44` (_chrome.jsx ListRow).
        constraints: const BoxConstraints(minHeight: 44),
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
                          TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            // Spec: `font:500 15/1.2` (_chrome.jsx ListRow).
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: titleColor,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        // Spec: `font:400 13/1.3 textSecondary` (_chrome.jsx).
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: nyan.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: NyanSpacing.space12),
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 32×32 icon chip per `_chrome.jsx` canonical spec.
  /// Opaque blend: `primary @ 9%` over `surfaceMuted`. Glyph 16pt in primary.
  Widget? _buildIconChip(NyanTheme nyan) {
    final icon = leadingIcon;
    if (icon == null) return null;

    final Color chipBg;
    final Color chipFg;
    if (danger) {
      chipBg = nyan.errorBackgroundColor;
      chipFg = nyan.errorPrimaryTextColor;
    } else {
      // Spec: `color-mix(in srgb, primary 9%, surfaceMuted)` — opaque blend
      // so the chip reads correctly on any surface behind it.
      chipBg = Color.alphaBlend(
        nyan.primary.withValues(alpha: 0.09),
        nyan.surfaceMuted,
      );
      chipFg = nyan.primary;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: chipBg,
        // Spec: `var(--r-chip)` = 12pt.
        borderRadius: BorderRadius.circular(NyanRadius.chip),
      ),
      child: Icon(icon, size: 16, color: chipFg),
    );
  }

  /// Trailing `ph-caret-right` — 16pt, `textMuted` (_chrome.jsx ListRow).
  Widget? _buildChevron(NyanTheme nyan) {
    if (!showChevron) return null;
    return Icon(
      NyanIcons.chevronRight,
      size: 16,
      color: nyan.textMuted,
    );
  }
}
