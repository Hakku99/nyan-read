import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';

/// Open-book glyph used on shelf list/grid tiles — soft primary wash + matcha icon.
///
/// Keeps book identity chrome consistent between shelf and detail fallback covers.
class NyanBookLogoMark extends StatelessWidget {
  final double iconSize;
  final double backgroundAlpha;
  final EdgeInsetsGeometry padding;

  const NyanBookLogoMark({
    super.key,
    this.iconSize = 24,
    this.backgroundAlpha = 0.12,
    this.padding = const EdgeInsets.all(NyanSpacing.space8),
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.nyanTheme.primary;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(NyanRadius.small),
      ),
      child: Icon(
        NyanIcons.book,
        size: iconSize,
        color: primary,
      ),
    );
  }
}
