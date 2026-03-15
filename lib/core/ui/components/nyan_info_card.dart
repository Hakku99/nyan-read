import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';

class NyanInfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const NyanInfoCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        boxShadow: theme.brightness == Brightness.dark
            ? const []
            : NyanShadows.lightCard(theme.shadowColor),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 
            theme.brightness == Brightness.dark ? 0.24 : 0.3,
          ),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(NyanSpacing.space16),
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        child: content,
      ),
    );
  }
}

