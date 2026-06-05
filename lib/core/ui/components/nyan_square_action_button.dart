import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

/// Bordered square action button for page-header chrome — the design's
/// `SquareAction` (BookshelfScreen U9): `surface` fill + `r-control` (14pt)
/// rounded square + a 1px `divider` border, 44×44 min tap target.
///
/// Distinct from [NyanRecessedIconButton] (borderless, recessed `surfaceMuted`
/// fill) which is used for reader chrome / inset toolbars. Header actions
/// "sit on" the page as outlined surface squares; they do not recess into it.
class NyanSquareActionButton extends StatelessWidget {
  const NyanSquareActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = NyanSpacing.space20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isEnabled = onPressed != null;

    final iconColor = isEnabled
        ? nyan.textPrimary
        : nyan.textPrimary.withValues(alpha: 0.32);

    final radius = BorderRadius.circular(NyanRadius.control);

    final container = Container(
      constraints: const BoxConstraints(
        minWidth: NyanSpacing.minTapTarget,
        minHeight: NyanSpacing.minTapTarget,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: nyan.surface,
        borderRadius: radius,
        border: Border.all(color: nyan.divider, width: 1),
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
