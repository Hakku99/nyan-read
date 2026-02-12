import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
// I'll use raw maps from DB or construct Bookmark objects.

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
      final data = await DatabaseService().getBookmarks(widget.bookId);
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
    // Optimistic update
    final index = _bookmarks.indexWhere((b) => b['id'] == id);
    if (index == -1) return;

    final removedItem = _bookmarks[index];
    setState(() {
      _bookmarks.removeAt(index);
    });

    try {
      await DatabaseService().deleteBookmark(id);
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _bookmarks.insert(index, removedItem);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete bookmark: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookmarks (${_bookmarks.length})'),
            Text(
              widget.bookTitle,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _isLoading
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
                        'No bookmarks yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bm) {
    final theme = Theme.of(context);
    final note = bm['note'] ?? '';
    final time = DateTime.fromMillisecondsSinceEpoch(bm['created_at'] ?? 0);
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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: () {
            Navigator.pop(context, bm);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16), // More padding for card look
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bookmark, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Bookmark #${bm['index']}",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.grey[500],
                      onPressed: () => _deleteBookmark(id),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 32), // Align with text
                    child: Text(
                      note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
