import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import 'nyan_sheet_appearance.dart';

class NyanSelectionSheetRow<T> extends StatelessWidget {
  const NyanSelectionSheetRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: isSelected
          ? theme.colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.1 : 0.055,
            )
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NyanSheetAppearance.compactRowHorizontalPadding,
            vertical: NyanSheetAppearance.compactRowVerticalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.9)
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: NyanSpacing.space4),
                      Text(
                        description!,
                        style: NyanSheetAppearance.compactDescriptionStyle(
                          theme,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isSelected ? 1 : 0,
                child: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}