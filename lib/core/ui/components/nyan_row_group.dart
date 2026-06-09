import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../nyan_theme_context.dart';

/// Container for a stack of [NyanListRow] / [NyanActionSheetRow] children
/// with hairline divider-coloured separators between items.
///
/// Per `_chrome.jsx` `RowGroup` (canonical Phase-4 HANDOFF):
/// outer radius [NyanRadius.cardNested] (16pt), border `1px chrome-edge`
/// (transparent light / nyan.divider dark), separators 0.5px @ 34% alpha with
/// symmetric 16pt inset, [NyanShadows.settingsGrouped] lift.
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

    // Spec: divider = nyan.divider @ 34%, 0.5px, symmetric 16pt inset.
    final separatorColor = nyan.divider.withValues(alpha: 0.34);
    // Spec: chrome-edge = transparent in light, nyan.divider in dark.
    final borderColor = nyan.brightness == Brightness.dark
        ? nyan.divider
        : Colors.transparent;
    final borderRadius = BorderRadius.circular(NyanRadius.cardNested);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Padding(
            // Spec: `margin: "0 16px"` — symmetric, not left-indent.
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(height: 0.5, child: ColoredBox(color: separatorColor)),
          ),
        );
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
          // Spec: `1px solid chrome-edge`.
          border: Border.all(color: borderColor, width: 1),
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
