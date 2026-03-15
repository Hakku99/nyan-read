import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import 'nyan_primary_button.dart';

class NyanConfirmDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final bool isDanger;

  const NyanConfirmDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title),
      content: Text(description),
      actionsPadding: const EdgeInsets.fromLTRB(
        NyanSpacing.space20,
        0,
        NyanSpacing.space20,
        NyanSpacing.space20,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            Expanded(
              child: Theme(
                data: isDanger
                    ? theme.copyWith(
                        filledButtonTheme: FilledButtonThemeData(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                        ),
                      )
                    : theme,
                child: NyanPrimaryButton(
                  label: confirmLabel,
                  expanded: true,
                  onPressed: () {
                    onConfirm?.call();
                    Navigator.of(context).pop(true);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
