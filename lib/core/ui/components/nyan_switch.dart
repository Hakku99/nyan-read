import 'package:flutter/material.dart';

import '../nyan_theme_context.dart';

/// Spec-matched toggle switch (`primitives.jsx` `NyanSwitch`).
///
/// Track: 44×26pt pill. Thumb: 20×20pt surface circle with 3pt inset.
/// OFF track = `nyan.divider`. ON track = `nyan.primary`.
/// Null [onChanged] renders the switch in a non-interactive (disabled) state.
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
    final enabled = onChanged != null;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: (value ? nyan.primary : nyan.divider)
                .withValues(alpha: enabled ? 1.0 : 0.45),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: nyan.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
