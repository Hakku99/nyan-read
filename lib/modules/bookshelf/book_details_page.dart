import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/book.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/ui/components/nyan_info_card.dart';
import '../../core/ui/components/nyan_list_row.dart';
import '../../core/ui/components/nyan_primary_button.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/utils/book_source_access.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../l10n/app_localizations.dart';

class BookDetailsPage extends StatelessWidget {
  final Book book;
  final Map<String, dynamic> bookData;

  const BookDetailsPage({
    super.key,
    required this.book,
    required this.bookData,
  });

  void _openReader(BuildContext context) {
    context.pushReplacement('/reader/${book.id}');
  }

  bool _isMeaningfulValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    final lower = normalized.toLowerCase();
    return lower != 'unknown' && normalized != '\u672a\u77e5';
  }

  String _summarizeSourceLocator() {
    final locator = book.sourceLocator.trim();
    if (locator.isEmpty) {
      return locator;
    }

    final uri = Uri.tryParse(locator);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      try {
        final decoded = Uri.decodeComponent(lastSegment);
        final parts = decoded.split(RegExp(r'[\\/]'));
        return parts.isNotEmpty ? parts.last : decoded;
      } catch (_) {
        final parts = lastSegment.split(RegExp(r'[\\/]'));
        return parts.isNotEmpty ? parts.last : lastSegment;
      }
    }

    final parts = locator.split(RegExp(r'[\\/]'));
    return parts.isNotEmpty ? parts.last : locator;
  }

  String _progressStateLabel(AppLocalizations loc, int progressPercent) {
    if (progressPercent <= 0) {
      return loc.neverRead;
    }

    return '$progressPercent%';
  }

  Widget _buildLeadingIcon(BuildContext context, IconData icon) {
    final nyanTheme = context.nyanTheme;

    return SizedBox.square(
      dimension: NyanSpacing.space24,
      child: Center(
        child: Icon(
          icon,
          size: NyanSpacing.space24,
          color: nyanTheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final progress = (bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
    final progressPercent = (progress * 100).round();
    final summarizedLocator = _summarizeSourceLocator();

    final addedAt = bookData['added_at'] == null
        ? loc.unknown
        : dateFormat.format(
            DateTime.fromMillisecondsSinceEpoch(bookData['added_at'] as int),
          );

    final lastReadAt = bookData['last_read_at'] == null
        ? loc.never
        : dateFormat.format(
            DateTime.fromMillisecondsSinceEpoch(bookData['last_read_at'] as int),
          );

    final author = _isMeaningfulValue(book.author) ? book.author.trim() : null;
    final hasAddedAt = bookData['added_at'] != null;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: BookSourceAccess.isAvailable(book),
          builder: (context, snapshot) {
            final isAvailable = snapshot.data ?? true;
            final hasAvailability = snapshot.hasData;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: NyanSpacing.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NyanSpacing.space16,
                      NyanSpacing.space12,
                      NyanSpacing.space16,
                      NyanSpacing.space8,
                    ),
                    child: SizedBox(
                      height: NyanSpacing.minTapTarget,
                      child: Row(
                        children: [
                          SizedBox(
                            width: NyanSpacing.minTapTarget,
                            height: NyanSpacing.minTapTarget,
                            child: IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                            ),
                          ),
                          const SizedBox(width: NyanSpacing.space8),
                          Expanded(
                            child: Text(
                              loc.bookDetails,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: theme.textTheme.bodyLarge?.fontSize,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: NyanSpacing.space8),
                          SizedBox(
                            width: NyanSpacing.minTapTarget,
                            height: NyanSpacing.minTapTarget,
                            child: IconButton(
                              onPressed:
                                  isAvailable ? () => _openReader(context) : null,
                              icon: const Icon(Icons.menu_book_rounded),
                              tooltip: loc.startReading,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NyanSpacing.space16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NyanInfoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: nyanTheme.surfaceMuted,
                                      borderRadius: BorderRadius.circular(
                                        NyanRadius.card,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        NyanSpacing.space12,
                                      ),
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        size: NyanSpacing.space32,
                                        color: nyanTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: NyanSpacing.space12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          book.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                        if (author != null) ...[
                                          const SizedBox(
                                            height: NyanSpacing.space4,
                                          ),
                                          Text(
                                            author,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: nyanTheme.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: NyanSpacing.space16),
                              Wrap(
                                spacing: NyanSpacing.space8,
                                runSpacing: NyanSpacing.space8,
                                children: [
                                  _DetailBadge(
                                    label: book.format.toUpperCase(),
                                    icon: Icons.description_outlined,
                                  ),
                                  _DetailBadge(
                                    label: book.isPrivate
                                        ? loc.privateShelf
                                        : loc.publicShelf,
                                    icon: book.isPrivate
                                        ? Icons.lock_outline_rounded
                                        : Icons.lock_open_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: NyanSpacing.space16),
                              Text(
                                loc.readingProgress,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: nyanTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: NyanSpacing.space4),
                              Text(
                                _progressStateLabel(loc, progressPercent),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: nyanTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: NyanSpacing.space12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  NyanRadius.small,
                                ),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: NyanSpacing.space8,
                                  backgroundColor: nyanTheme.surfaceMuted,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    nyanTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: NyanSpacing.space16),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: NyanPrimaryButton(
                                      label: loc.startReading,
                                      onPressed: isAvailable
                                          ? () => _openReader(context)
                                          : null,
                                      icon: const Icon(Icons.menu_book_rounded),
                                      expanded: true,
                                    ),
                                  ),
                                  const Spacer(flex: 3),
                                ],
                              ),
                              if (hasAvailability && !isAvailable) ...[
                                const SizedBox(height: NyanSpacing.space12),
                                _UnavailableNotice(
                                  message: BookSourceAccess.unavailableMessage,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: NyanSpacing.space16),
                        NyanInfoCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              if (hasAddedAt) ...[
                                NyanListRow(
                                  leading: _buildLeadingIcon(
                                    context,
                                    Icons.add_circle_outline_rounded,
                                  ),
                                  title: loc.added,
                                  subtitle: addedAt,
                                ),
                                _CardDivider(theme: theme),
                              ],
                              NyanListRow(
                                leading: _buildLeadingIcon(
                                  context,
                                  Icons.access_time_rounded,
                                ),
                                title: loc.lastRead,
                                subtitle: lastReadAt,
                              ),
                              _CardDivider(theme: theme),
                              NyanListRow(
                                leading: _buildLeadingIcon(
                                  context,
                                  Icons.folder_open_rounded,
                                ),
                                title: loc.fileLocation,
                                subtitle: hasAvailability && !isAvailable
                                    ? loc.fileNotFound
                                    : null,
                                trailing: IconButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: book.sourceLocator),
                                    );
                                    SnackBarUtils.show(
                                      context,
                                      loc.filePathCopied,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    color: nyanTheme.textSecondary,
                                  ),
                                  tooltip: loc.copyPath,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  NyanSpacing.space16,
                                  0,
                                  NyanSpacing.space16,
                                  NyanSpacing.space16,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: nyanTheme.surfaceMuted,
                                    borderRadius: BorderRadius.circular(
                                      NyanRadius.input,
                                    ),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(
                                        alpha: theme.brightness ==
                                                Brightness.dark
                                            ? 0.18
                                            : 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      NyanSpacing.space12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          summarizedLocator,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: NyanSpacing.space4,
                                        ),
                                        SelectableText(
                                          book.sourceLocator,
                                          maxLines: 3,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                                height: 1.4,
                                                color: nyanTheme.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (hasAvailability && !isAvailable)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    NyanSpacing.space16,
                                    0,
                                    NyanSpacing.space16,
                                    NyanSpacing.space16,
                                  ),
                                  child: _UnavailableNotice(
                                    message: BookSourceAccess.unavailableMessage,
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
          },
        ),
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _DetailBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: nyanTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        border: Border.all(
          color: theme.dividerColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.28,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space12,
          vertical: NyanSpacing.space8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: NyanSpacing.space16, color: nyanTheme.primary),
            const SizedBox(width: NyanSpacing.space8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: nyanTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  final String message;

  const _UnavailableNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: nyanTheme.errorBackgroundColor,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        border: Border.all(
          color: nyanTheme.errorAccentColor.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NyanSpacing.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: NyanSpacing.space16,
              color: nyanTheme.errorPrimaryTextColor,
            ),
            const SizedBox(width: NyanSpacing.space8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: nyanTheme.errorPrimaryTextColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  final ThemeData theme;

  const _CardDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.dividerColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.14 : 0.24,
      ),
    );
  }
}
