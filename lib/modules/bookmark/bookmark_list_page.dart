import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
// I'll use raw maps from DB or construct Bookmark objects.

class BookmarkListPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const BookmarkListPage({super.key, required this.bookId, required this.bookTitle});

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  late Future<List<Map<String, dynamic>>> _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarksFuture = DatabaseService().getBookmarks(widget.bookId);
    });
  }

  Future<void> _deleteBookmark(String id) async {
    await DatabaseService().deleteBookmark(id);
    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bookmarks - ${widget.bookTitle}"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookmarks = snapshot.data ?? [];
          
          if (bookmarks.isEmpty) {
             return const Center(child: Text("No bookmarks yet."));
          }

          return ListView.builder(
            itemCount: bookmarks.length,
            itemBuilder: (context, index) {
              final bm = bookmarks[index];
              final page = bm['page_index'];
              final note = bm['note'] ?? '';
              final time = DateTime.fromMillisecondsSinceEpoch(bm['created_at'] ?? 0);
              
              return ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.pink),
                title: Text("Page ${page + 1}"),
                subtitle: note.isNotEmpty ? Text(note) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${time.year}-${time.month}-${time.day}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () => _deleteBookmark(bm['id']),
                    )
                  ],
                ),
                onTap: () {
                   // Return the page index to the reader
                   Navigator.pop(context, page);
                },
              );
            },
          );
        },
      ),
    );
  }
}