import 'package:flutter/material.dart';

import '../nyan_theme_context.dart';

/// Themed Material [Switch] aligned to Nyan tokens.
///
/// ON  — track = `nyanTheme.primary`, thumb = white.
/// OFF — track = `nyanTheme.surfaceMuted`, thumb = white.
/// Splash overlay is suppressed (transparent) so taps don't ripple a Material
/// halo — keeps the surface "paper-like" per design rules.
class NyanSwitch extends StatelessWidget {
  const NyanSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: nyan.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: nyan.surfaceMuted,
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return nyan.primary;
        }
        return nyan.divider.withValues(alpha: 0.6);
      }),
      trackOutlineWidth: const WidgetStatePropertyAll(0.5),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashRadius: 0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
