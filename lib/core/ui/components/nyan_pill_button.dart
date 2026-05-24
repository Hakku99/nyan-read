import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../nyan_theme_context.dart';

/// Pill-segmented button — Nyan's signature anti-Material style:
/// selection is communicated by a 1.5px primaryDeep outline + text colour,
/// NOT by a filled background. Per pill-segmented.html.
class NyanPillButton extends StatelessWidget {
  const NyanPillButton({
    super.key,
    required this.label,
    required this.selected,
    this.onPressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    final Color borderColor = selected ? nyan.primaryDeep : nyan.divider;
    final Color textColor = selected ? nyan.primaryDeep : nyan.textPrimary;
    final double borderWidth = selected ? 1.5 : 1.0;

    return Material(
      color: nyan.surface,
      shape: StadiumBorder(
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: NyanSpacing.minTapTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space16,
              vertical: NyanSpacing.space8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                ],
                // [Flexible] so the pill gracefully degrades when placed
                // inside a constrained Expanded slot (e.g. 3-pill preset rows
                // on narrow phones). Without this the inner Row overflows.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
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
    );
  }
}
