import 'package:flutter/material.dart';

class NyanShadows {
  const NyanShadows._();

  static List<BoxShadow> lightCard(Color shadowColor) {
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.02),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> subtle(Color shadowColor) {
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Settings grouped cards — ultra-soft lift (was inlined as `_SettingsCard`).
  static List<BoxShadow> settingsGrouped(Color shadowColor) {
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: 0.014),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
