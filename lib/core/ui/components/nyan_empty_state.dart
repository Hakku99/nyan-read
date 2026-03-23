import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';

class NyanEmptyState extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? description;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;
  final double iconSpacing;
  final double descriptionSpacing;
  final double actionSpacing;
  final double? textMinHeight;
  final double? contentMaxWidth;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  const NyanEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.padding,
    this.alignment = Alignment.center,
    this.iconSpacing = NyanSpacing.space16,
    this.descriptionSpacing = NyanSpacing.space8,
    this.actionSpacing = NyanSpacing.space20,
    this.textMinHeight,
    this.contentMaxWidth,
    this.titleStyle,
    this.descriptionStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(NyanSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(height: iconSpacing),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: textMinHeight ?? 0,
                maxWidth: contentMaxWidth ?? double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style:
                        titleStyle ??
                        theme.textTheme.titleMedium?.copyWith(
                          fontSize: NyanTypography.section,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (description != null) ...[
                    SizedBox(height: descriptionSpacing),
                    Text(
                      description!,
                      textAlign: TextAlign.center,
                      style:
                          descriptionStyle ??
                          theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              SizedBox(height: actionSpacing),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
