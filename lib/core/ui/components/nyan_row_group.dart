import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../nyan_theme_context.dart';

/// Container for a stack of [NyanListRow] / [NyanActionSheetRow] children
/// with hairline `divider`-coloured separators between items.
///
/// Per design: no Material [Divider] widget — separators are 1px Containers
/// using the `divider` token. Outer is a [NyanRadius.card] rounded panel on
/// the [surface] colour, hairline-bordered.
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

    final separatorColor = nyan.divider.withValues(alpha: 0.6);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Container(
          height: 1,
          color: separatorColor,
        ));
      }
    }

    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: nyan.surface,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}
