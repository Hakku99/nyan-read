import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import '../../theme/theme_presets.dart';

class NyanSheetAppearance {
  const NyanSheetAppearance._();

  static const double compactContentGap = 21;
  static const double compactHorizontalPadding = compactContentGap;
  static const double compactRowHorizontalPadding = NyanSpacing.space16;
  static const double compactRowVerticalPadding = NyanSpacing.space12;

  static TextStyle? compactTitleStyle(ThemeData theme) {
    return theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 17.5,
      color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.92),
      height: 1.08,
    );
  }

  /// Spec (`list-row.html`): `font:400 13px/1.3 text-secondary`.
  static TextStyle? compactDescriptionStyle(ThemeData theme) {
    final nyan = resolveNyanTheme(theme);
    return theme.textTheme.bodySmall?.copyWith(
      color: nyan.textSecondary,
      height: 1.3,
    );
  }

  /// Spec (`bottom-sheet.html`): grab handle uses `text-muted` token.
  static Color compactHandleColor(ThemeData theme) {
    return resolveNyanTheme(theme).textMuted;
  }
}