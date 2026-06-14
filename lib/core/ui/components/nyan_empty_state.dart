import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../../theme/theme_presets.dart';

/// Canonical empty-state scaffold per Claude Design spec
/// (`nyan-read-design-system/project/preview/empty-state.html`).
///
/// **Icon slot** — two paths, mutually exclusive (explicit [icon] wins):
///   • Pass [icon] (Widget) for mascot art or custom containers.
///   • Pass [iconData] (IconData) for the canonical rounded-square chip:
///     radius-card (20pt) container, `primary` @ 8% fill, 34pt glyph at
///     `primary` @ 80% — matching the spec exactly.
///
/// **Default text styles** — applied when the caller does not pass
/// [titleStyle] / [descriptionStyle]:
///   • Title: 20pt / w600 / height 1.3 (spec: `font:600 20px/1.3`)
///   • Description: bodyMedium (14pt) / w400 / height 1.5 / `textSecondary`
///     (spec: `font:400 14px/1.5 text-secondary`)
class NyanEmptyState extends StatelessWidget {
  final Widget? icon;

  /// Convenience: builds the canonical 34pt-glyph rounded-square icon chip
  /// automatically. Ignored when [icon] is also provided.
  final IconData? iconData;

  final String title;
  final String? description;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;
  final double iconSpacing;
  final double descriptionSpacing;
  final double actionSpacing;
  final double? textMinHeight;
  final double? contentMaxWidth;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  const NyanEmptyState({
    super.key,
    this.icon,
    this.iconData,
    required this.title,
    this.description,
    this.action,
    this.padding,
    this.alignment = Alignment.center,
    this.iconSpacing = NyanSpacing.space16,
    this.descriptionSpacing = NyanSpacing.space8,
    this.actionSpacing = NyanSpacing.space20,
    this.textMinHeight,
    this.contentMaxWidth,
    this.titleStyle,
    this.descriptionStyle,
  }) : assert(
         icon != null || iconData != null,
         'NyanEmptyState requires either icon or iconData.',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);

    // Explicit Widget wins; fall back to canonical iconData chip.
    final Widget resolvedIcon = icon ?? _buildIconChip(nyan);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ??
            const EdgeInsets.symmetric(
              vertical: NyanSpacing.space32,
              horizontal: NyanSpacing.space24,
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            resolvedIcon,
            SizedBox(height: iconSpacing),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: textMinHeight ?? 0,
                maxWidth: contentMaxWidth ?? double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: titleStyle ??
                        TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.section, // 20pt
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: nyan.textPrimary,
                        ),
                  ),
                  if (description != null) ...[
                    SizedBox(height: descriptionSpacing),
                    Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: descriptionStyle ??
                          TextStyle(
                            // Spec: `font:400 14px/1.5 text-secondary`
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: NyanTypography.body,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: nyan.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              SizedBox(height: actionSpacing),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  /// Spec canonical chip: radius-card (20pt) container, `primary` @ 8% fill,
  /// 34pt glyph at `primary` @ 80%. Padding 14pt matches spec value;
  /// not on the 8-grid but is a design-system literal (documented here).
  Widget _buildIconChip(NyanTheme nyan) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: nyan.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
      ),
      child: Icon(
        iconData,
        size: 34,
        color: nyan.primary.withValues(alpha: 0.80),
      ),
    );
  }
}
