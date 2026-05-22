import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/components/components.dart';

class ImportBookSheet extends StatelessWidget {
  final bool isEmptyShelf;
  final String shelfLabel;
  final VoidCallback onImportFiles;

  const ImportBookSheet({
    super.key,
    required this.isEmptyShelf,
    required this.shelfLabel,
    required this.onImportFiles,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return NyanBottomSheet(
      title: loc.importBooksTitle,
      description: isEmptyShelf
          ? loc.importBooksEmptySubtitle
          : loc.importBooksSubtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShelfBadge(label: shelfLabel),
          const SizedBox(height: NyanSpacing.space12),
          NyanInfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NyanListRow(
                  leadingIcon: NyanIcons.file,
                  title: loc.importFiles,
                  subtitle: loc.importFilesSubtitle,
                  showChevron: true,
                  onTap: onImportFiles,
                ),
                Divider(
                  height: 1,
                  indent: NyanSpacing.space16,
                  endIndent: NyanSpacing.space16,
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NyanSpacing.space16,
                    NyanSpacing.space12,
                    NyanSpacing.space16,
                    NyanSpacing.space16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetLeadingIcon(
                        icon: NyanIcons.book,
                      ),
                      const SizedBox(width: NyanSpacing.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.supportedFormats,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: NyanSpacing.space4),
                            Text(
                              loc.supportedFormatsSubtitle,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: NyanSpacing.space12),
                            Wrap(
                              spacing: NyanSpacing.space8,
                              runSpacing: NyanSpacing.space8,
                              children: const [
                                _FormatChip(label: 'TXT'),
                                _FormatChip(label: 'EPUB'),
                                _FormatChip(label: 'PDF'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfBadge extends StatelessWidget {
  final String label;

  const _ShelfBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space12,
        vertical: NyanSpacing.space8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(NyanRadius.input),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            NyanIcons.bookCollection,
            size: NyanSpacing.space16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: NyanSpacing.space8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetLeadingIcon extends StatelessWidget {
  final IconData icon;

  const _SheetLeadingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: NyanSpacing.minTapTarget,
      height: NyanSpacing.minTapTarget,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(NyanRadius.input),
      ),
      child: Icon(
        icon,
        size: NyanSpacing.space20,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;

  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space12,
        vertical: NyanSpacing.space8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(NyanRadius.input),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return NyanProgressDialog(
      title: loc.importingBooksTitle,
      description: loc.importingBooksSubtitle,
    );
  }
}
