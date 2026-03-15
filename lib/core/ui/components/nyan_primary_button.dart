import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';

class NyanPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool expanded;
  final EdgeInsetsGeometry? padding;

  const NyanPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        padding == null ? null : FilledButton.styleFrom(padding: padding);

    final button = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: NyanSpacing.minTapTarget,
      ),
      child: icon == null
          ? FilledButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: icon!,
              label: Text(label),
            ),
    );

    if (!expanded) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
