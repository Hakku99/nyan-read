import 'package:flutter/foundation.dart';
import '../../core/models/bookmark.dart';

class BookmarkService extends ChangeNotifier {
  final List<Bookmark> _bookmarks = [];

  List<Bookmark> get bookmarks => _bookmarks;

  void addBookmark(Bookmark bookmark) {
    _bookmarks.add(bookmark);
    notifyListeners();
  }

  void removeBookmark(String id) {
    _bookmarks.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}
