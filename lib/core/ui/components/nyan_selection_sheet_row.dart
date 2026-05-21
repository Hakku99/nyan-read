import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import 'nyan_sheet_appearance.dart';
import '../nyan_icons.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final selectedBackground = theme.colorScheme.primary.withValues(
      alpha: isDark ? 0.12 : 0.075,
    );
    final selectedLabelColor = theme.textTheme.bodyLarge?.color?.withValues(
      alpha: isDark ? 0.98 : 0.96,
    );
    final selectedDescriptionColor = theme.textTheme.bodySmall?.color?.withValues(
      alpha: isDark ? 0.82 : 0.74,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      color: isSelected ? selectedBackground : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NyanSheetAppearance.compactRowHorizontalPadding,
            vertical: NyanSpacing.space12,
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
                            ? selectedLabelColor
                            : theme.textTheme.bodyLarge?.color?.withValues(
                                alpha: 0.94,
                              ),
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: NyanSpacing.space4),
                      Text(
                        description!,
                        style: NyanSheetAppearance.compactDescriptionStyle(
                          theme,
                        )?.copyWith(
                          color: isSelected ? selectedDescriptionColor : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              SizedBox(
                width: 20,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: isSelected ? 1 : 0,
                  child: Icon(
                    NyanIcons.check,
                    size: 20,
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.96 : 0.88,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
