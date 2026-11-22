import 'package:flutter/material.dart';

import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_icons.dart';
import '../../l10n/app_localizations.dart';

/// Shown by the notes / bookmarks pages when the DB read itself failed, so a
/// failure never masquerades as the "nothing saved yet" empty state.
class AnnotationsLoadError extends StatelessWidget {
  const AnnotationsLoadError({
    super.key,
    required this.title,
    required this.onRetry,
  });

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return NyanEmptyState(
      iconData: NyanIcons.error,
      title: title,
      description: loc.failedToLoadHint,
      action: NyanPrimaryButton(
        label: loc.retry,
        onPressed: onRetry,
        size: NyanPrimaryButtonSize.compact,
      ),
    );
  }
}
