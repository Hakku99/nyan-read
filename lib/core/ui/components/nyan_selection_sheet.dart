import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_bottom_sheet.dart';
import 'nyan_selection_sheet_row.dart';
import 'nyan_sheet_appearance.dart';

class NyanSelectionOption<T> {
  const NyanSelectionOption({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}

Future<T?> showNyanSelectionSheet<T>({
  required BuildContext context,
  required String title,
  String? description,
  required T currentValue,
  required List<NyanSelectionOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return NyanSelectionSheet<T>(
        title: title,
        description: description,
        currentValue: currentValue,
        options: options,
      );
    },
  );
}

class NyanSelectionSheet<T> extends StatelessWidget {
  const NyanSelectionSheet({
    super.key,
    required this.title,
    required this.currentValue,
    required this.options,
    this.description,
  });

  final String title;
  final String? description;
  final T currentValue;
  final List<NyanSelectionOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleToOptionsGap = description == null
        ? NyanSpacing.space20
        : NyanSpacing.space24;
    final bottomContentPadding = description == null
        ? NyanSpacing.space8
        : NyanSpacing.space12;

    return NyanBottomSheet(
      title: title,
      description: description,
      titleStyle: NyanSheetAppearance.compactTitleStyle(theme),
      descriptionStyle: NyanSheetAppearance.compactDescriptionStyle(theme),
      handleColor: NyanSheetAppearance.compactHandleColor(theme),
      contentPadding: EdgeInsets.only(
        left: NyanSheetAppearance.compactHorizontalPadding,
        right: NyanSheetAppearance.compactHorizontalPadding,
        top: NyanSpacing.space12,
        bottom: bottomContentPadding + MediaQuery.of(context).padding.bottom,
      ),
      titleTopSpacing: NyanSpacing.space8,
      titleChildSpacing: titleToOptionsGap,
      child: _NyanSelectionGroup<T>(
        currentValue: currentValue,
        options: options,
      ),
    );
  }
}

class _NyanSelectionGroup<T> extends StatelessWidget {
  const _NyanSelectionGroup({
    required this.currentValue,
    required this.options,
  });

  final T currentValue;
  final List<NyanSelectionOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.16 : 0.2,
    );
    final dividerColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.08 : 0.1,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        border: Border.all(
          color: borderColor,
          width: 0.55,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < options.length; index++) ...[
              NyanSelectionSheetRow<T>(
                label: options[index].label,
                description: options[index].description,
                isSelected: options[index].value == currentValue,
                onTap: () => Navigator.of(context).pop(options[index].value),
              ),
              if (index != options.length - 1)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: NyanSpacing.space16,
                  ),
                  color: dividerColor,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
