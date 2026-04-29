import 'package:flutter/material.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/components/nyan_overlay_style.dart';

/// Icon button used in the reader overlay toolbar and chapter progress row.
/// Matches 44×44 minimum touch target with recessed surface styling.
class ReaderOverlayToolButton extends StatelessWidget {
  const ReaderOverlayToolButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isAccent = false,
    this.transparentBackground = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isAccent;
  final bool transparentBackground;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: Ink(
          width: NyanSpacing.minTapTarget,
          height: NyanSpacing.minTapTarget,
          decoration: BoxDecoration(
            color: transparentBackground
                ? Colors.transparent
                : isAccent
                ? NyanOverlayStyle.recessedSurface(
                    context,
                    seed: theme.colorScheme.primary,
                    strength: 0.1,
                  )
                : NyanOverlayStyle.recessedSurface(
                    context,
                    seed: theme.colorScheme.primary,
                    strength: 0.008,
                  ),
            borderRadius: BorderRadius.circular(NyanRadius.input),
            border: Border.all(
              color: isAccent
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : theme.dividerColor.withValues(alpha: 0.12),
              width: 0.72,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isAccent
                ? theme.colorScheme.primary.withValues(alpha: 0.9)
                : theme.colorScheme.primary.withValues(alpha: 0.74),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
