import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/services/database_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_shadows.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/utils/snackbar_utils.dart';

class BookmarkListPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const BookmarkListPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  bool get _isZh =>
      Localizations.localeOf(context).languageCode.startsWith('zh');
  AppLocalizations get _loc => AppLocalizations.of(context)!;

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt is! int) {
      return '';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatSectionDate(String dateLabel) {
    if (dateLabel.isEmpty) {
      return _isZh ? '\u66f4\u65e9' : 'Earlier';
    }
    return dateLabel.replaceAll('-', '.');
  }

  String _bookmarkMetaLabel(int index) {
    if (_isZh) {
      return '\u4e66\u7b7e $index';
    }
    return 'Bookmark $index';
  }

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    try {
      final data = await getIt<DatabaseService>().getBookmarks(widget.bookId);
      if (!mounted) {
        return;
      }

      final bookmarks = List<Map<String, dynamic>>.from(data);
      for (int i = 0; i < bookmarks.length; i++) {
        bookmarks[i] = Map<String, dynamic>.from(bookmarks[i]);
        bookmarks[i]['index'] = i + 1;
      }

      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBookmark(String id) async {
    final loc = _loc;
    final index = _bookmarks.indexWhere((bookmark) => bookmark['id'] == id);
    if (index == -1) {
      return;
    }

    final removedItem = _bookmarks[index];
    setState(() {
      _bookmarks.removeAt(index);
    });

    try {
      await getIt<DatabaseService>().deleteBookmark(id);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bookmarks.insert(index, removedItem);
      });
      SnackBarUtils.show(context, loc.failedToDeleteBookmark(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return Scaffold(
      backgroundColor: nyanTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            NyanPageHeader(
              // Per the design bookmarks page: plain "Bookmarks" title with a
              // "{n} saved" meta — not the book title (you're already in the
              // book's context when arriving here).
              title: loc.bookmarks,
              subtitle: loc.bookmarksSavedCount(_bookmarks.length),
              titleStyle: theme.textTheme.titleLarge?.copyWith(
                fontSize: NyanTypography.section,
                fontWeight: FontWeight.w600,
              ),
              subtitleStyle: theme.textTheme.bodySmall?.copyWith(
                color: nyanTheme.textSecondary.withValues(alpha: 0.78),
              ),
              padding: const EdgeInsets.fromLTRB(
                NyanSpacing.space16,
                NyanSpacing.space12,
                NyanSpacing.space16,
                NyanSpacing.space8,
              ),
              leading: SizedBox(
                width: NyanSpacing.minTapTarget,
                height: NyanSpacing.minTapTarget,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(NyanIcons.back),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: nyanTheme.primary),
      );
    }

    if (_bookmarks.isEmpty) {
      final isDark = theme.brightness == Brightness.dark;
      final heroSize = NyanSpacing.space32 * 2 + NyanSpacing.space20;

      return NyanEmptyState(
        alignment: const Alignment(0, -0.24),
        padding: const EdgeInsets.fromLTRB(
          NyanSpacing.space24,
          NyanSpacing.space16,
          NyanSpacing.space24,
          NyanSpacing.space24,
        ),
        contentMaxWidth: NyanSpacing.space32 * 8,
        icon: Container(
          width: heroSize,
          height: heroSize,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              nyanTheme.primary.withValues(
                alpha: isDark ? 0.09 : 0.05,
              ),
              nyanTheme.surface,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withValues(
                alpha: isDark ? 0.1 : 0.09,
              ),
              width: 0.7,
            ),
          ),
          child: Center(
            child: Icon(
              NyanIcons.bookmark,
              size: NyanSpacing.space32 + NyanSpacing.space8,
              color: nyanTheme.primary.withValues(alpha: isDark ? 0.82 : 0.78),
            ),
          ),
        ),
        title: _loc.noBookmarksYet,
        titleStyle: theme.textTheme.titleMedium?.copyWith(
          fontSize: NyanTypography.section,
          fontWeight: FontWeight.w600,
          color: nyanTheme.textPrimary.withValues(alpha: isDark ? 0.88 : 0.84),
        ),
        description: _loc.bookmarkEmptyDescription,
        descriptionStyle: theme.textTheme.bodyMedium?.copyWith(
          height: 1.3,
          color: nyanTheme.textSecondary.withValues(
            alpha: isDark ? 0.8 : 0.74,
          ),
        ),
        iconSpacing: NyanSpacing.space16,
        descriptionSpacing: NyanSpacing.space12,
        actionSpacing: NyanSpacing.space12,
        action: Text(
          _loc.bookmarkEmptyHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: nyanTheme.textSecondary.withValues(
              alpha: isDark ? 0.68 : 0.62,
            ),
            height: 1.24,
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space16,
        NyanSpacing.space4,
        NyanSpacing.space16,
        NyanSpacing.space24,
      ),
      children: [
        _buildContextPanel(),
        ..._buildGroupedBookmarkItems(),
      ],
    );
  }

  List<Widget> _buildGroupedBookmarkItems() {
    final items = <Widget>[];
    String? previousDate;

    for (final bookmark in _bookmarks) {
      final dateLabel = _formatCreatedAt(bookmark['created_at']);
      if (dateLabel != previousDate) {
        if (items.isNotEmpty) {
          items.add(const SizedBox(height: NyanSpacing.space12));
        }
        items.add(_buildDateHeader(_formatSectionDate(dateLabel)));
        items.add(const SizedBox(height: NyanSpacing.space8));
        previousDate = dateLabel;
      }

      items.add(_buildBookmarkCard(bookmark));
      items.add(const SizedBox(height: NyanSpacing.space8));
    }

    if (items.isNotEmpty) {
      items.removeLast();
    }

    return items;
  }

  Widget _buildContextPanel() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    final panelSurface = isDark
        ? Color.alphaBlend(
            nyanTheme.surface.withValues(alpha: 0.9),
            nyanTheme.background,
          )
        : nyanTheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: NyanSpacing.space12),
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space12,
        vertical: NyanSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: panelSurface,
        borderRadius: BorderRadius.circular(NyanRadius.card),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.22 : 0.18),
          width: 0.6,
        ),
        // v3 ladder: dark no longer opts out of shadow — the ring carries the
        // plane separation. Pass the full theme so the recipe picks the ladder.
        boxShadow: NyanShadows.subtle(nyanTheme),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                nyanTheme.primary.withValues(alpha: isDark ? 0.1 : 0.07),
                nyanTheme.surfaceMuted,
              ),
              borderRadius: BorderRadius.circular(NyanRadius.input),
            ),
            child: Icon(
              NyanIcons.bookmarks,
              size: 16,
              color: nyanTheme.primary.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(width: NyanSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loc.bookmarkContextTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.08,
                    color: nyanTheme.textPrimary.withValues(
                      alpha: isDark ? 0.9 : 0.82,
                    ),
                  ),
                ),
                const SizedBox(height: NyanSpacing.space4),
                Text(
                  _loc.bookmarkContextDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: nyanTheme.textSecondary.withValues(
                      alpha: isDark ? 0.82 : 0.74,
                    ),
                    height: 1.24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: NyanTypography.meta,
          letterSpacing: 0.3,
          color: nyanTheme.textSecondary.withValues(alpha: 0.56),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDeleteRevealBackground() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final railBase = Color.alphaBlend(
      nyanTheme.errorBackgroundColor.withValues(alpha: isDark ? 0.16 : 0.3),
      nyanTheme.surface,
    );
    final railTint = Color.alphaBlend(
      nyanTheme.errorAccentColor.withValues(alpha: isDark ? 0.06 : 0.04),
      nyanTheme.background,
    );
    final railBorder = nyanTheme.errorAccentColor.withValues(
      alpha: isDark ? 0.16 : 0.1,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 104,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NyanRadius.card),
            border: Border.all(color: railBorder, width: 0.5),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                railTint.withValues(alpha: 0.08),
                railTint.withValues(alpha: 0.16),
                railBase,
              ],
              stops: const [0.0, 0.62, 1.0],
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: NyanSpacing.space12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _loc.delete,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: NyanTypography.meta,
                        color: nyanTheme.errorPrimaryTextColor.withValues(
                          alpha: isDark ? 0.68 : 0.56,
                        ),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space4),
                  Icon(
                    NyanIcons.delete,
                    size: 22,
                    color: nyanTheme.errorPrimaryTextColor.withValues(
                      alpha: isDark ? 0.84 : 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bookmark) {
    final note = (bookmark['note'] ?? '').toString().trim();
    final contentSnippet =
        (bookmark['content_snippet'] ?? '').toString().trim();
    final id = bookmark['id'] as String;
    final bookmarkLabel = _bookmarkMetaLabel(bookmark['index'] as int);
    final excerpt = contentSnippet.isNotEmpty
        ? contentSnippet
        : (note.isNotEmpty ? note : bookmarkLabel);
    final supportingNote = note.isNotEmpty && note != excerpt ? note : null;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.34,
      },
      movementDuration: const Duration(milliseconds: 220),
      resizeDuration: const Duration(milliseconds: 180),
      background: _buildDeleteRevealBackground(),
      secondaryBackground: _buildDeleteRevealBackground(),
      onDismissed: (_) => _deleteBookmark(id),
      child: NyanBookmarkCard(
        label: bookmarkLabel,
        excerpt: excerpt,
        note: supportingNote,
        noteTagLabel: _loc.bookmarkNoteTag,
        onTap: () => Navigator.pop(context, bookmark),
      ),
    );
  }
}
