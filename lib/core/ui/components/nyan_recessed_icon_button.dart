import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_overlay_style.dart';

/// Soft "inset" icon control (matches shelf toolbar actions / reader chrome).
///
/// Pass `onPressed: null` to render a non-interactive disabled state — the
/// button keeps its footprint so neighbouring chrome does not jump, but the
/// icon dims and the tap target is removed.
class NyanRecessedIconButton extends StatelessWidget {
  const NyanRecessedIconButton({
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
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;

    final iconColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.32);

    final container = Container(
      constraints: const BoxConstraints(
        minWidth: NyanSpacing.minTapTarget,
        minHeight: NyanSpacing.minTapTarget,
      ),
      decoration: BoxDecoration(
        color: NyanOverlayStyle.recessedSurface(context),
        borderRadius: BorderRadius.circular(NyanRadius.input),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );

    return Tooltip(
      message: tooltip,
      child: isEnabled
          ? InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(NyanRadius.input),
              child: container,
            )
          : container,
    );
  }
}
