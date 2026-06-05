import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../nyan_theme_context.dart';

/// Themed [FloatingActionButton] aligned to Nyan tokens.
///
/// Background/foreground use `nyan.fabBackground` / `nyan.fabForeground`;
/// corner radius is [NyanRadius.input] (16pt) per AGENTS.md §4.2.2;
/// the soft lift comes from [NyanShadows.subtle] applied via an outer
/// [DecoratedBox] so Material's own elevation shadow is suppressed.
class NyanFAB extends StatelessWidget {
  const NyanFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NyanRadius.dock),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NyanRadius.dock),
        boxShadow: NyanShadows.subtle(nyan),
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: nyan.fabBackground,
        foregroundColor: nyan.fabForeground,
        elevation: 0,
        highlightElevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        disabledElevation: 0,
        shape: shape,
        tooltip: tooltip,
        heroTag: heroTag,
        child: Icon(icon),
      ),
    );
  }
}
