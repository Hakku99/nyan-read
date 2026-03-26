import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';

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

  static TextStyle? compactDescriptionStyle(ThemeData theme) {
    return theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.68),
      height: 1.28,
    );
  }

  static Color compactHandleColor(ThemeData theme) {
    return theme.dividerColor.withValues(alpha: 0.44);
  }
}