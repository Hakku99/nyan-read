import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/services/database_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_radius.dart';
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

  String _headerSubtitle() {
    if (_isZh) {
      return '\u300a${widget.bookTitle}\u300b';
    }
    return widget.bookTitle;
  }

  String _contextTitle() {
    if (_isZh) {
      return '\u9605\u8bfb\u75d5\u8ff9';
    }
    return 'Reading marks';
  }

  String _contextDescription() {
    if (_isZh) {
      return '\u70b9\u5f00\u7247\u6bb5\u8fd4\u56de\u539f\u6587\uff0c\u5de6\u6ed1\u5373\u53ef\u5220\u9664\u3002';
    }
    return 'Tap a passage to return. Swipe left to delete.';
  }

  String _noteTagLabel() {
    if (_isZh) {
      return '\u6709\u7b14\u8bb0';
    }
    return 'Note';
  }

  String _deleteActionLabel() {
    if (_isZh) {
      return '\u5220\u9664';
    }
    return 'Delete';
  }

  String _emptyStateTitle(AppLocalizations loc) {
    if (_isZh) {
      return '\u8fd8\u6ca1\u6709\u7559\u4e0b\u4e66\u7b7e';
    }
    return loc.noBookmarksYet;
  }

  String _emptyStateDescription() {
    if (_isZh) {
      return '\u9605\u8bfb\u65f6\u6807\u8bb0\u4e0b\u6765\u7684\u7247\u6bb5\uff0c\u4f1a\u5b89\u9759\u5730\u7559\u5728\u8fd9\u91cc\u3002';
    }
    return 'Saved reading moments will gather here as you read.';
  }

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
      return '\u4e66\u7b7e ' + index.toString();
    }
    return 'Bookmark ' + index.toString();
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
    final loc = AppLocalizations.of(context)!;
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                nyanTheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.08 : 0.05,
                ),
                nyanTheme.background,
              ),
              nyanTheme.background,
              nyanTheme.background,
            ],
            stops: const [0, 0.24, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              NyanPageHeader(
                title: loc.bookmarksTitle(_bookmarks.length),
                subtitle: _headerSubtitle(),
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
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: nyanTheme.primary),
      );
    }

    if (_bookmarks.isEmpty) {
      return NyanEmptyState(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(
          NyanSpacing.space24,
          NyanSpacing.space24,
          NyanSpacing.space24,
          NyanSpacing.space24,
        ),
        icon: Container(
          width: NyanSpacing.space32 * 3,
          height: NyanSpacing.space32 * 3,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              nyanTheme.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.08 : 0.06,
              ),
              nyanTheme.surface,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.1 : 0.14,
              ),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.bookmark_border_rounded,
              size: NyanSpacing.space32,
              color: nyanTheme.primary.withValues(alpha: 0.86),
            ),
          ),
        ),
        title: _emptyStateTitle(loc),
        description: _emptyStateDescription(),
        iconSpacing: NyanSpacing.space16,
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space16,
        0,
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

    return Container(
      margin: const EdgeInsets.only(bottom: NyanSpacing.space12),
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space12,
        vertical: NyanSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          nyanTheme.primary.withValues(alpha: isDark ? 0.05 : 0.035),
          nyanTheme.surface,
        ),
        borderRadius: BorderRadius.circular(NyanRadius.card),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.14 : 0.12),
          width: 0.6,
        ),
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
              Icons.bookmark_added_rounded,
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
                  _contextTitle(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.08,
                    color: nyanTheme.textPrimary.withValues(
                      alpha: isDark ? 0.9 : 0.82,
                    ),
                  ),
                ),
                const SizedBox(height: NyanSpacing.space4),
                Text(
                  _contextDescription(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
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
          fontSize: 10.5,
          letterSpacing: 0.9,
          color: nyanTheme.textSecondary.withValues(alpha: 0.56),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDeleteRevealBackground() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final railBase = Color.alphaBlend(
      nyanTheme.errorBackgroundColor.withValues(alpha: isDark ? 0.2 : 0.46),
      nyanTheme.surface,
    );
    final railTint = Color.alphaBlend(
      nyanTheme.errorAccentColor.withValues(alpha: isDark ? 0.08 : 0.06),
      nyanTheme.background,
    );
    final railBorder = nyanTheme.errorAccentColor.withValues(
      alpha: isDark ? 0.16 : 0.1,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 88,
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
            padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _deleteActionLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: nyanTheme.errorPrimaryTextColor.withValues(
                        alpha: isDark ? 0.68 : 0.56,
                      ),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space4),
                  Icon(
                    Icons.delete_outline_rounded,
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
        noteTagLabel: _noteTagLabel(),
        onTap: () => Navigator.pop(context, bookmark),
      ),
    );
  }
}
