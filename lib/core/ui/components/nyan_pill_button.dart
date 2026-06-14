import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../nyan_theme_context.dart';

/// Nyan's signature option chip / segmented button.
///
/// Shape: squared `r-chip` (12pt) — NOT a stadium pill.
/// Selection = outline only: the unselected state has a recessed `surfaceMuted`
/// fill with a transparent border; the selected state drops the fill to
/// transparent and adds a `primaryDeep` border + `primaryDeep` text.
/// The chip "lifts off the track" when selected — no fill, just a matcha edge.
///
/// Source: `colors_and_type.css` `--r-chip`; `components/primitives.jsx`
/// `PillButton`; `AGENTS.md §4.3`.
class NyanPillButton extends StatelessWidget {
  const NyanPillButton({
    super.key,
    required this.label,
    required this.selected,
    this.onPressed,
    this.icon,
    this.horizontalPadding,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData? icon;
  // Optional horizontal padding override — spec allows 6pt for dense rows
  // (e.g. Compact/Standard/Comfortable line-height pills). §4.6 delivery package.
  final double? horizontalPadding;

  static const _kRadius = NyanRadius.chip;
  static const _kBorderRadius = BorderRadius.all(Radius.circular(_kRadius));
  static const _kBorderWidth = 1.5;
  static const Duration _kDuration = Duration(milliseconds: 160);
  static const Curve _kCurve = Curves.easeOutCubic; // ≈ ease-paper

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    final Color bg = selected ? Colors.transparent : nyan.surfaceMuted;
    final Color borderColor = selected ? nyan.primaryDeep : Colors.transparent;
    final Color textColor = selected ? nyan.primaryDeep : nyan.textSecondary;

    // AnimatedContainer owns the background + border so they cross-fade.
    // Material is transparent and only provides the InkWell ripple clip.
    return AnimatedContainer(
      duration: _kDuration,
      curve: _kCurve,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _kBorderRadius,
        border: Border.all(color: borderColor, width: _kBorderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: _kBorderRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: _kBorderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              // Spec PillButton: minHeight 36 (§4.6 delivery-package override
              // of §4.3 minTapTarget 44 — dense settings panel context).
              minHeight: 36.0,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding ?? NyanSpacing.space16,
                // Spec: padding "9px 16px".
                vertical: 9.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: textColor),
                    const SizedBox(width: 6),
                  ],
                  // [Flexible] prevents overflow when 3 pills share a Row on
                  // narrow phones (e.g. compact/standard/comfortable row).
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
