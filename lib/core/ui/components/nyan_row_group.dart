import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../nyan_theme_context.dart';

/// Container for a stack of [NyanListRow] / [NyanActionSheetRow] children
/// with hairline `divider`-coloured separators between items.
///
/// Per design spec: outer radius is [NyanRadius.input] (16pt), border is
/// 0.72px @ 16% alpha, separators are indented 64pt from the leading edge
/// (aligns with icon slot), and the card carries a [NyanShadows.settingsGrouped]
/// lift. Shadow is placed on an outer [DecoratedBox] so [Clip.antiAlias] on the
/// inner container does not clip it.
class NyanRowGroup extends StatelessWidget {
  const NyanRowGroup({
    super.key,
    required this.children,
    this.padding,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final separatorColor = nyan.divider.withValues(alpha: 0.5);
    final borderRadius = BorderRadius.circular(NyanRadius.input);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Row(
          children: [
            const SizedBox(width: 64),
            Expanded(
              child: Container(height: 1, color: separatorColor),
            ),
          ],
        ));
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: NyanShadows.settingsGrouped(nyan),
      ),
      child: Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: nyan.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: nyan.divider.withValues(alpha: 0.16),
            width: 0.72,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
  }
}
