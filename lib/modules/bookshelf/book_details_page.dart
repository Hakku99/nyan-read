import 'dart:async' show unawaited;
import 'dart:math' as math;

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
import '../../core/ui/components/nyan_book_logo_mark.dart';
import '../../core/ui/components/nyan_info_card.dart';
import '../../core/ui/components/nyan_primary_button.dart';
import '../../core/ui/components/nyan_recessed_icon_button.dart';
import '../../core/ui/components/nyan_section_header.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/utils/book_source_access.dart';
import '../../core/utils/snackbar_utils.dart';
import 'epub_cover_extractor.dart';
import '../../l10n/app_localizations.dart';

/// Same rhythm as [SettingsPage] list gaps.
const double _kBookDetailsSectionGap = NyanSpacing.space24;

/// Matches settings `_SettingsCard` row insets (horizontal 16 / vertical 12).
const EdgeInsets _kBookDetailsCardPadding = EdgeInsets.fromLTRB(
  NyanSpacing.space16,
  NyanSpacing.space12,
  NyanSpacing.space16,
  NyanSpacing.space12,
);

/// Logical px bounds shared by EPUB thumbnail and placeholder (~trim ratio).
const double _kCoverSlotWidth = 55;
const double _kCoverSlotHeight = 74;

/// Outer square allocated inside hero slot for the logo chip (green tile fills this).
const double _kLogoChipToSlotFactor = 0.8;

/// Source-row folder bubble edge (`minTapTarget` minus one spacing step).
const double _kIconBubbleExtent =
    NyanSpacing.minTapTarget - NyanSpacing.space8;

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
    return lower != 'unknown' && normalized != '\u672a\u77e5';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
        final progressRightLine = !hasLastReadAt
            ? loc.neverRead
            : displayPercent == 0
                ? '${loc.lastOpened} $lastReadAt'
                : '${loc.lastRead} $lastReadAt';
        final progressSemanticsLabel = !hasLastReadAt
            ? '${loc.readingProgress} $displayPercent%. ${loc.neverRead}'
            : displayPercent == 0
                ? '${loc.readingProgress} $displayPercent%. ${loc.lastOpened} $lastReadAt'
                : '${loc.readingProgress} $displayPercent%. ${loc.lastRead} $lastReadAt';

        return Scaffold(
          appBar: AppBar(
            leadingWidth: NyanSpacing.minTapTarget + NyanSpacing.space12,
            titleSpacing: NyanSpacing.space4,
            centerTitle: false,
            leading: Padding(
              padding: const EdgeInsets.only(left: NyanSpacing.space8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NyanRecessedIconButton(
                  icon: NyanIcons.back,
                  tooltip:
                      MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            title: Text(
              loc.bookDetails,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                NyanSpacing.space16,
                NyanSpacing.space16,
                NyanSpacing.space16,
                NyanSpacing.space24 + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NyanSectionHeader(title: loc.bookDetailsOverviewSection),
                  NyanInfoCard(
                    variant: NyanInfoCardVariant.grouped,
                    tone: NyanInfoCardTone.surface,
                    padding: _kBookDetailsCardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BookHeroCover(
                              book: book,
                              isSourceAvailable: isAvailable,
                            ),
                            const SizedBox(width: NyanSpacing.space8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => _showFullTitleBottomSheet(
                                      context,
                                      book.title,
                                      loc,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      NyanRadius.small,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        book.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                          fontSize: NyanTypography.body,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.1,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NyanSpacing.space4),
                                  Text(
                                    author ?? loc.unknownAuthor,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: NyanTypography.meta,
                                      color: author != null
                                          ? nyanTheme.textSecondary
                                          : nyanTheme.textMuted,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasAddedAt && addedAtShort != null) ...[
                          const SizedBox(height: NyanSpacing.space8),
                          Text(
                            '${loc.added} $addedAtShort',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: NyanTypography.meta,
                              color: nyanTheme.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: NyanSpacing.space12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: NyanSpacing.space12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  loc.format,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: NyanTypography.body,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                    color: nyanTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                _formatLabel(book.format, loc),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: NyanTypography.meta,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                  color: nyanTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: NyanSpacing.space12),
                        Semantics(
                          label: progressSemanticsLabel,
                          child: displayPercent == 0 && !hasLastReadAt
                              ? Row(
                                  children: [
                                    Icon(
                                      NyanIcons.bookmark,
                                      size: NyanSpacing.space16,
                                      color: nyanTheme.textMuted,
                                    ),
                                    const SizedBox(width: NyanSpacing.space8),
                                    Expanded(
                                      child: Text(
                                        '${loc.neverRead} ${loc.readyToStart}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          fontSize: NyanTypography.meta,
                                          color: nyanTheme.textMuted,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$displayPercent%',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontSize: NyanTypography.meta,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                        color: nyanTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: NyanSpacing.space8),
                                    Expanded(
                                      child: Text(
                                        progressRightLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          fontSize: NyanTypography.meta,
                                          fontWeight: FontWeight.w400,
                                          color: nyanTheme.textMuted,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: NyanSpacing.space12),
                        NyanPrimaryButton(
                          label: displayPercent > 0
                              ? loc.continueReading
                              : loc.startReading,
                          onPressed: isAvailable
                              ? () => _openReader(context)
                              : null,
                          expanded: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: NyanSpacing.space4,
                          ),
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
                  const SizedBox(height: _kBookDetailsSectionGap),
                  NyanSectionHeader(title: loc.bookDetailsSourceSection),
                  NyanInfoCard(
                    variant: NyanInfoCardVariant.grouped,
                    tone: NyanInfoCardTone.surface,
                    padding: _kBookDetailsCardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _IconBubble(
                              icon: NyanIcons.folderOpen,
                              tint: nyanTheme.primary,
                            ),
                            const SizedBox(width: NyanSpacing.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.originalPath,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: NyanTypography.body,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                      color: nyanTheme.textPrimary,
                                    ),
                                  ),
                                  if (hasAvailability && !isAvailable) ...[
                                    const SizedBox(height: NyanSpacing.space4),
                                    Text(
                                      loc.fileNotFound,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color:
                                            nyanTheme.errorPrimaryTextColor,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(
                              width: NyanSpacing.minTapTarget,
                              height: NyanSpacing.minTapTarget,
                              child: IconButton(
                                onPressed: () {
                                  // Clipboard completes independently; snackbar
                                  // does not depend on success (Android/iOS OK).
                                  unawaited(
                                    Clipboard.setData(
                                      ClipboardData(text: book.sourceLocator),
                                    ),
                                  );
                                  SnackBarUtils.show(
                                    context,
                                    loc.filePathCopied,
                                  );
                                },
                                icon: Icon(
                                  NyanIcons.copy,
                                  size: NyanSpacing.space20,
                                  color: nyanTheme.textSecondary,
                                ),
                                tooltip: loc.copyPath,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: NyanSpacing.space8),
                        if (book.sourceLocator.trim().isEmpty)
                          Text(
                            friendlySource,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: NyanTypography.meta,
                              height: 1.35,
                              color: nyanTheme.textSecondary,
                            ),
                          )
                        else
                          _SourceLocatorPanel(
                            locator: book.sourceLocator,
                            friendlyLine: friendlySource,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Friendly summary + full technical path (always visible, for copy/audit).
class _SourceLocatorPanel extends StatelessWidget {
  const _SourceLocatorPanel({
    required this.locator,
    required this.friendlyLine,
  });

  final String locator;
  final String friendlyLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          friendlyLine,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: NyanTypography.meta,
            height: 1.35,
            color: nyan.textPrimary,
          ),
        ),
        const SizedBox(height: NyanSpacing.space8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              nyan.background.withValues(
                alpha: isDark ? 0.48 : 0.38,
              ),
              theme.cardColor,
            ),
            borderRadius: BorderRadius.circular(NyanRadius.input),
            border: Border.all(
              color: theme.dividerColor.withValues(
                alpha: isDark ? 0.14 : 0.10,
              ),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(NyanSpacing.space12),
          child: SelectableText(
            locator,
            strutStyle: const StrutStyle(
              forceStrutHeight: true,
              height: 1.2,
              leading: 0,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: NyanTypography.monoFontFamily,
              fontSize: NyanTypography.meta,
              height: 1.2,
              color: nyan.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero cover: EPUBs load a real cover in a worker isolate; other formats and
/// failures use [NyanBookLogoMark] like shelf tiles.
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
      // Whole file read is simplest path for cover decode; huge EPUBs cost RAM.
      final bytes = await BookSourceAccess.readBytes(widget.book);
      return extractEpubCoverAsJpeg(bytes);
    } catch (e) {
      debugPrint('Book details cover load failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wantsEpubCover =
        widget.isSourceAvailable && widget.book.format.toLowerCase() == 'epub';

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

/// Fallback when there is no EPUB bitmap: same [NyanBookLogoMark] chrome as shelf,
/// with a tighter glyph so the green tile can stay hero-sized without crowding.
class _BookCoverPlaceholder extends StatelessWidget {
  final String title;

  const _BookCoverPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    final chipExtent = math.min(_kCoverSlotWidth, _kCoverSlotHeight) *
        _kLogoChipToSlotFactor;
    // Green tile stays `chipExtent`; larger inset shrinks only the glyph.
    const logoPadding = NyanSpacing.space8;
    final iconSize = chipExtent - 2 * logoPadding;

    return Semantics(
      label: title,
      child: SizedBox(
        width: _kCoverSlotWidth,
        height: _kCoverSlotHeight,
        child: Center(
          child: SizedBox(
            width: chipExtent,
            height: chipExtent,
            child: Center(
              child: NyanBookLogoMark(
                iconSize: iconSize,
                padding: const EdgeInsets.all(logoPadding),
              ),
            ),
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
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nyanTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(NyanRadius.input),
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

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color tint;

  const _IconBubble({
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final nyanTheme = context.nyanTheme;
    final brightness = Theme.of(context).brightness;

    final bubbleColor = Color.alphaBlend(
      tint.withValues(alpha: brightness == Brightness.dark ? 0.18 : 0.16),
      nyanTheme.surface,
    );

    return SizedBox(
      width: _kIconBubbleExtent,
      height: _kIconBubbleExtent,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: bubbleColor,
          shape: const StadiumBorder(),
        ),
        child: Center(
          child: Icon(icon, size: NyanSpacing.space20, color: tint),
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
