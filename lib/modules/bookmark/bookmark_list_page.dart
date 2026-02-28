import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../core/services/database_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/snackbar_utils.dart';

class BookmarkListPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const BookmarkListPage(
      {super.key, required this.bookId, required this.bookTitle});

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    try {
      final data = await getIt<DatabaseService>().getBookmarks(widget.bookId);
      if (mounted) {
        // Convert to modifiable list
        final List<Map<String, dynamic>> bookmarks = List.from(data);
        // Add index
        for (int i = 0; i < bookmarks.length; i++) {
          bookmarks[i] = Map<String, dynamic>.from(bookmarks[i]);
          bookmarks[i]['index'] = i + 1;
        }
        setState(() {
          _bookmarks = bookmarks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBookmark(String id) async {
    final loc = AppLocalizations.of(context)!;
    // Optimistic update
    final index = _bookmarks.indexWhere((b) => b['id'] == id);
    if (index == -1) return;

    final removedItem = _bookmarks[index];
    setState(() {
      _bookmarks.removeAt(index);
    });

    try {
      await getIt<DatabaseService>().deleteBookmark(id);
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _bookmarks.insert(index, removedItem);
        });
        SnackBarUtils.show(context, loc.failedToDeleteBookmark(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.bookmarksTitle(_bookmarks.length)),
            Text(
              widget.bookTitle,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookmarks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          loc.noBookmarksYet,
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      final bm = _bookmarks[index];
                      return _buildBookmarkCard(bm);
                    },
                  ),
      ),
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bm) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final note = bm['note'] ?? '';
    // final time = DateTime.fromMillisecondsSinceEpoch(bm['created_at'] ?? 0); // Removed date display
    final contentSnippet = bm['content_snippet'] ?? '';
    final id = bm['id'];

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteBookmark(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            Navigator.pop(context, bm);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10), // Slimmer padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Wrap content
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center, // Center vert
                  children: [
                    Icon(Icons.bookmark, color: theme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loc.bookmarkName(bm['index']),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _deleteBookmark(id),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (contentSnippet.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      contentSnippet.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary
                            .withOpacity(0.7), // Match theme color as requested
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
