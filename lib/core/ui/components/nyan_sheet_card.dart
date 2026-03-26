import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';

class NyanSheetCard extends StatelessWidget {
  const NyanSheetCard({
    super.key,
    required this.children,
    this.radius = NyanRadius.input,
  });

  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.18 : 0.16),
          width: 0.6,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}