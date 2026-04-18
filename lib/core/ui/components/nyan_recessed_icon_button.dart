import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_overlay_style.dart';

/// Soft “inset” icon control (matches shelf toolbar actions / reader chrome).
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
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: NyanSpacing.minTapTarget,
            minHeight: NyanSpacing.minTapTarget,
          ),
          decoration: BoxDecoration(
            color: NyanOverlayStyle.recessedSurface(context),
            borderRadius: BorderRadius.circular(NyanRadius.input),
          ),
          child: Icon(icon, size: iconSize, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}
