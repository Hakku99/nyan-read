import 'package:flutter/material.dart';

class NyanSheetDivider extends StatelessWidget {
  const NyanSheetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.55,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
    );
  }
}