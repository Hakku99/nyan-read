import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';

class NyanBottomSheet extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget child;
  final Widget? footer;

  const NyanBottomSheet({
    super.key,
    this.title,
    this.description,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NyanRadius.sheet),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: NyanSpacing.space24,
            right: NyanSpacing.space24,
            top: NyanSpacing.space12,
            bottom: NyanSpacing.space24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: NyanSpacing.space4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: NyanSpacing.space16),
                Text(
                  title!,
                  style: theme.textTheme.titleLarge,
                ),
              ],
              if (description != null) ...[
                const SizedBox(height: NyanSpacing.space8),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                  ),
                ),
              ],
              const SizedBox(height: NyanSpacing.space16),
              child,
              if (footer != null) ...[
                const SizedBox(height: NyanSpacing.space20),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
