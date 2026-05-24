import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/models/book.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/nyan_list_row.dart';
import '../../core/ui/components/nyan_page_header.dart';
import '../../core/ui/components/nyan_primary_button.dart';
import '../../core/ui/components/nyan_recessed_icon_button.dart';
import '../../core/ui/components/nyan_row_group.dart';
import '../../core/ui/components/nyan_section_header.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/utils/book_source_access.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../l10n/app_localizations.dart';
import 'epub_cover_extractor.dart';

/// Rhythm between page sections — matches [SettingsPage] list gaps.
const double _kBookDetailsSectionGap = NyanSpacing.space24;

/// Hero cover dimensions per BookDetailsScreen.jsx spec (120×156 px).
const double _kCoverSlotWidth = 120;
const double _kCoverSlotHeight = 156;

String _friendlySourceSummary(String locator, AppLocalizations loc) {
  final t = locator.trim();
  if (t.isEmpty) {
    return loc.bookDetailsSourceSummaryImported;
  }
  if (t.startsWith('content://')) {
    final lower = t.toLowerCase();
    if (lower.contains('downloads')) {
      return loc.bookDetailsSourceSummaryDownloads;
    }
    return loc.bookDetailsSourceSummaryImported;
  }
  final name = p.basename(t);
  if (name.isNotEmpty) {
    return name;
  }
  return loc.bookDetailsSourceSummaryImported;
}

String _formatLabel(String format, AppLocalizations loc) {
  switch (format.toLowerCase()) {
    case 'epub':
      return loc.bookFormatEpub;
    case 'txt':
      return loc.bookFormatTxt;
    case 'pdf':
      return loc.bookFormatPdf;
    default:
      return format.trim().isEmpty ? loc.unknown : format.toUpperCase();
  }
}

void _showFullTitleBottomSheet(
  BuildContext context,
  String title,
  AppLocalizations loc,
) {
  final theme = Theme.of(context);
  final nyan = context.nyanTheme;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(NyanRadius.sheet),
      ),
    ),
    builder: (ctx) {
      final pad = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          NyanSpacing.space24,
          NyanSpacing.space8,
          NyanSpacing.space24,
          NyanSpacing.space24 + pad,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.bookDetailsFullTitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: nyan.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: NyanSpacing.space12),
            SelectableText(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: NyanTypography.body,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: nyan.textPrimary,
              ),
            ),
          ],
        ),
      );
    },
  );
}

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
    return lower != 'unknown' && normalized != '未知';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final nyanTheme = context.nyanTheme;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final progress = (bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final displayPercent = (clampedProgress * 100).round();

    final hasAddedAt = bookData['added_at'] != null;
    final addedAtShort = hasAddedAt
        ? DateFormat('yyyy-MM-dd').format(
            DateTime.fromMillisecondsSinceEpoch(bookData['added_at'] as int),
          )
        : null;

    final hasLastReadAt = bookData['last_read_at'] != null;
    final lastReadAt = hasLastReadAt
        ? dateFormat.format(
            DateTime.fromMillisecondsSinceEpoch(
              bookData['last_read_at'] as int,
            ),
          )
        : null;

    final author = _isMeaningfulValue(book.author) ? book.author.trim() : null;

    return FutureBuilder<bool>(
      future: BookSourceAccess.isAvailable(book),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? true;
        final hasAvailability = snapshot.hasData;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final friendlySource =
            _friendlySourceSummary(book.sourceLocator, loc);

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pinned header — stays above the scroll view so it does not
              // vanish when the user scrolls down into the detail rows.
              SafeArea(
                bottom: false,
                child: NyanPageHeader(
                  title: loc.bookDetails,
                  leading: NyanRecessedIconButton(
                    icon: NyanIcons.back,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    NyanRecessedIconButton(
                      icon: NyanIcons.moreHorizontal,
                      // More-actions menu is deferred; placeholder preserves
                      // the header footprint for future implementation.
                      tooltip: '',
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    NyanSpacing.space16,
                    0,
                    NyanSpacing.space16,
                    NyanSpacing.space24 + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Hero ─────────────────────────────────────────────
                      Center(
                        child: _BookHeroCover(
                          book: book,
                          isSourceAvailable: isAvailable,
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space12),
                      // Title — tap to reveal full text in a bottom sheet.
                      GestureDetector(
                        onTap: () => _showFullTitleBottomSheet(
                          context,
                          book.title,
                          loc,
                        ),
                        child: Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: NyanTypography.section,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            height: 1.35,
                            color: nyanTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space4),
                      Text(
                        author ?? loc.unknownAuthor,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.meta,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: author != null
                              ? nyanTheme.textSecondary
                              : nyanTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space12),
                      // CTA row: primary action + share icon button side-by-side.
                      Row(
                        children: [
                          Expanded(
                            child: NyanPrimaryButton(
                              label: displayPercent > 0
                                  ? loc.continueReading
                                  : loc.startReading,
                              onPressed: isAvailable
                                  ? () => _openReader(context)
                                  : null,
                              expanded: true,
                              size: NyanPrimaryButtonSize.comfortable,
                            ),
                          ),
                          const SizedBox(width: NyanSpacing.space8),
                          _HeroShareButton(book: book),
                        ],
                      ),
                      if (hasAvailability && !isAvailable) ...[
                        const SizedBox(height: NyanSpacing.space12),
                        _UnavailableNotice(
                          message: BookSourceAccess.unavailableMessage,
                        ),
                      ],
                      const SizedBox(height: _kBookDetailsSectionGap),

                      // ── Overview ──────────────────────────────────────────
                      NyanSectionHeader(
                        title: loc.bookDetailsOverviewSection,
                        withLeadingDot: true,
                      ),
                      NyanRowGroup(
                        children: [
                          _DetailRow(label: loc.title, value: book.title),
                          _DetailRow(
                            label: loc.author,
                            value: author ?? loc.unknownAuthor,
                          ),
                          _DetailRow(
                            label: loc.format,
                            value: _formatLabel(book.format, loc),
                          ),
                          _DetailRow(
                            label: loc.privacy,
                            value: book.isPrivate
                                ? loc.privateShelf
                                : loc.publicShelf,
                          ),
                          _DetailRow(
                            label: loc.readingProgress,
                            value: '$displayPercent%',
                          ),
                          if (addedAtShort != null)
                            _DetailRow(label: loc.added, value: addedAtShort),
                        ],
                      ),
                      const SizedBox(height: _kBookDetailsSectionGap),

                      // ── Source ────────────────────────────────────────────
                      NyanSectionHeader(
                        title: loc.bookDetailsSourceSection,
                        withLeadingDot: true,
                      ),
                      NyanRowGroup(
                        children: [
                          NyanListRow(
                            leadingIcon: NyanIcons.folderOpen,
                            title: loc.originalPath,
                            // fileNotFound surfaces the error as subtitle text;
                            // the _UnavailableNotice in the hero is the primary indicator.
                            subtitle: hasAvailability && !isAvailable
                                ? loc.fileNotFound
                                : friendlySource,
                          ),
                          NyanListRow(
                            leadingIcon: NyanIcons.copy,
                            title: loc.copyPath,
                            onTap: () {
                              unawaited(
                                Clipboard.setData(
                                  ClipboardData(text: book.sourceLocator),
                                ),
                              );
                              SnackBarUtils.show(context, loc.filePathCopied);
                            },
                          ),
                          NyanListRow(
                            leadingIcon: NyanIcons.clock,
                            title: loc.lastOpened,
                            subtitle: lastReadAt ?? loc.neverRead,
                          ),
                        ],
                      ),
                      const SizedBox(height: _kBookDetailsSectionGap),

                      // ── Highlights & Notes ────────────────────────────────
                      NyanSectionHeader(
                        title: loc.highlightsAndNotes,
                        withLeadingDot: true,
                      ),
                      NyanRowGroup(
                        children: [
                          NyanListRow(
                            leadingIcon: NyanIcons.bookmark,
                            title: loc.highlightsAndNotes,
                            subtitle: loc.noHighlightsYet,
                            showChevron: true,
                            // TODO(#highlight-detail): navigate to per-book highlights list.
                            onTap: null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Private layout widgets ──────────────────────────────────────────────────

/// Label–value row for the Overview section.
///
/// Mirrors the spec's `DetailRow` component (BookDetailsScreen.jsx):
/// label `500/13/textSecondary` left, value `500/14/textPrimary` right.
/// The 14pt value size is a spec-literal for this component — it sits between
/// [NyanTypography.meta] (13) and [NyanTypography.body] (16) and is intentional.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space16,
        vertical: NyanSpacing.space12,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: NyanTypography.uiFontFamily,
              fontSize: NyanTypography.meta,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: nyan.textSecondary,
            ),
          ),
          const SizedBox(width: NyanSpacing.space12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: nyan.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small share icon button beside the hero CTA.
///
/// Spec: 44×44, `surface` background, `divider` border, [NyanRadius.input] corners.
/// Share action is deferred pending export/share implementation.
class _HeroShareButton extends StatelessWidget {
  const _HeroShareButton({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return Material(
      color: nyan.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NyanRadius.input),
        side: BorderSide(color: nyan.divider),
      ),
      child: InkWell(
        // TODO(#share): implement book share / export.
        onTap: null,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
        ),
        child: SizedBox(
          width: NyanSpacing.minTapTarget,
          height: NyanSpacing.minTapTarget,
          child: Icon(
            NyanIcons.share,
            size: NyanSpacing.space20,
            color: nyan.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Cover widgets ───────────────────────────────────────────────────────────

/// Hero cover: EPUBs load a real bitmap in a worker isolate; other formats
/// and failures fall back to [_BookCoverPlaceholder].
class _BookHeroCover extends StatefulWidget {
  final Book book;
  final bool isSourceAvailable;

  const _BookHeroCover({
    required this.book,
    required this.isSourceAvailable,
  });

  @override
  State<_BookHeroCover> createState() => _BookHeroCoverState();
}

class _BookHeroCoverState extends State<_BookHeroCover> {
  late Future<Uint8List?> _coverFuture;

  @override
  void initState() {
    super.initState();
    _coverFuture = _loadCoverBytes();
  }

  @override
  void didUpdateWidget(covariant _BookHeroCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id ||
        oldWidget.isSourceAvailable != widget.isSourceAvailable) {
      _coverFuture = _loadCoverBytes();
    }
  }

  Future<Uint8List?> _loadCoverBytes() async {
    if (!widget.isSourceAvailable) return null;
    if (widget.book.format.toLowerCase() != 'epub') return null;
    try {
      // Full-file read is the simplest cover-decode path; large EPUBs cost RAM
      // but the cover fetch happens once per open and the bytes are not retained.
      final bytes = await BookSourceAccess.readBytes(widget.book);
      return extractEpubCoverAsJpeg(bytes);
    } catch (e) {
      debugPrint('Book details cover load failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wantsEpubCover = widget.isSourceAvailable &&
        widget.book.format.toLowerCase() == 'epub';

    if (!wantsEpubCover) {
      return _placeholder();
    }

    return FutureBuilder<Uint8List?>(
      future: _coverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _placeholder();
        }
        final jpeg = snapshot.data;
        if (jpeg != null && jpeg.isNotEmpty) {
          return _BookCoverMemoryImage(
            jpegBytes: jpeg,
            title: widget.book.title,
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() => _BookCoverPlaceholder(title: widget.book.title);
}

/// Full-slot placeholder when no EPUB bitmap is available.
///
/// Spec (BookDetailsScreen.jsx): the 120×156 cover slot itself is the
/// `primary@12%` tinted tile — not a chip nested inside a transparent box.
class _BookCoverPlaceholder extends StatelessWidget {
  final String title;

  const _BookCoverPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return Semantics(
      label: title,
      child: Container(
        width: _kCoverSlotWidth,
        height: _kCoverSlotHeight,
        decoration: BoxDecoration(
          color: nyan.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(NyanRadius.card),
          border: Border.all(
            // Spec: 0.5px border at 30% divider alpha.
            color: nyan.divider.withValues(alpha: 0.30),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Icon(
            NyanIcons.book,
            size: 48,
            color: nyan.primary,
          ),
        ),
      ),
    );
  }
}

class _BookCoverMemoryImage extends StatelessWidget {
  final Uint8List jpegBytes;
  final String title;

  const _BookCoverMemoryImage({
    required this.jpegBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: _kCoverSlotWidth,
      height: _kCoverSlotHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NyanRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nyanTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(NyanRadius.card),
            border: Border.all(
              color: theme.dividerColor.withValues(
                alpha: isDark ? 0.24 : 0.32,
              ),
            ),
          ),
          child: Image.memory(
            jpegBytes,
            width: _kCoverSlotWidth,
            height: _kCoverSlotHeight,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Book cover decode error: $error');
              return _BookCoverPlaceholder(title: title);
            },
          ),
        ),
      ),
    );
  }
}

// ── Utility widgets ─────────────────────────────────────────────────────────

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
              NyanIcons.info,
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
