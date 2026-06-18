import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

/// Bordered square action button for the bookshelf shelf toolbar — matches the
/// design system's `ShelfSettingsBtn` / `ShelfToolBtn` (`_chrome.jsx`):
/// `surface` fill + `r-control` (14pt) + 1px `divider@44%` border, 44×44 tap
/// target, 18px icon in `textSecondary`.
///
/// Pass `isActive: true` to render the `ShelfToolBtn` active state (sort
/// engaged, shelf unlocked): `primary@13%` bg tint, `primary@42%` border,
/// `primaryDeep` icon.
class NyanSquareActionButton extends StatelessWidget {
  const NyanSquareActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.iconSize = 18,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Renders the active (tinted) state per `ShelfToolBtn active` spec.
  final bool isActive;

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isEnabled = onPressed != null;

    final Color bgColor = isActive
        ? Color.lerp(nyan.surface, nyan.primary, 0.13)!
        : nyan.surface;

    final Color borderColor = isActive
        ? nyan.primary.withValues(alpha: 0.42)
        : nyan.divider.withValues(alpha: 0.44);

    final Color iconColor = isActive
        ? nyan.primaryDeep
        : (isEnabled
            ? nyan.textSecondary
            : nyan.textSecondary.withValues(alpha: 0.32));

    final radius = BorderRadius.circular(NyanRadius.control);

    final container = Container(
      constraints: const BoxConstraints(
        minWidth: NyanSpacing.minTapTarget,
        minHeight: NyanSpacing.minTapTarget,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );

    return Tooltip(
      message: tooltip,
      child: isEnabled
          ? InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: container,
            )
          : container,
    );
  }
}
