import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import 'nyan_bottom_sheet.dart';
import 'nyan_pill_button.dart';
import 'nyan_sheet_appearance.dart';

/// A single option in a [showNyanChipSelectionSheet].
class NyanSelectionOption<T> {
  const NyanSelectionOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

/// Bottom sheet that presents a small set of mutually-exclusive options as
/// Nyan's signature outline-on-select pill chips (NOT list-rows-with-checks).
///
/// Single-select: tapping a chip pops the sheet with that value. Designed for
/// small option sets (≤4) — chips render in a bounded [Row] of [Expanded]
/// because [NyanPillButton] uses an internal [Flexible] that would overflow in
/// an unbounded [Wrap].
///
/// Source: design bundle README ("option chips use the single outline-selected
/// pill pattern, not list-rows-with-checks"); `AGENTS.md §4.3`.
Future<T?> showNyanChipSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required T currentValue,
  required List<NyanSelectionOption<T>> options,
  String? description,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => NyanChipSelectionSheet<T>(
      title: title,
      description: description,
      currentValue: currentValue,
      options: options,
    ),
  );
}

class NyanChipSelectionSheet<T> extends StatelessWidget {
  const NyanChipSelectionSheet({
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
        bottom: NyanSpacing.space8 + MediaQuery.of(context).padding.bottom,
      ),
      titleTopSpacing: NyanSpacing.space8,
      titleChildSpacing:
          description == null ? NyanSpacing.space20 : NyanSpacing.space24,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: NyanSpacing.space8),
            Expanded(
              child: NyanPillButton(
                label: options[i].label,
                selected: options[i].value == currentValue,
                onPressed: () =>
                    Navigator.of(context).pop(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
