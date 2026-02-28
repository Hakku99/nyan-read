import 'package:flutter/foundation.dart';
import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';

class BookshelfViewModel extends ChangeNotifier {
  final DatabaseService _db;
  final BookshelfPreferencesService _prefs;

  BookshelfViewModel(this._db, this._prefs) {
    loadBooks();
  }

  // --- Core State ---
  List<Book> _publicBooks = [];
  List<Book> _privateBooks = [];
  bool _isLoading = true;
  String? _error;

  List<Book> get publicBooks => _publicBooks;
  List<Book> get privateBooks => _privateBooks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get publicCount => _publicBooks.length;
  int get privateCount => _privateBooks.length;

  // --- Interaction State ---
  bool _isSelectionMode = false;
  final Set<String> _selectedBookIds = {};

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedBookIds => _selectedBookIds;
  int get selectedCount => _selectedBookIds.length;

  // --- Derived State ---
  bool isBookSelected(String bookId) => _selectedBookIds.contains(bookId);

  // --- Actions ---

  Future<void> loadBooks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final orderBy = _prefs.getOrderByClause();

      // Parallel fetch
      final results = await Future.wait([
        _db.getBooks(isPrivate: false, orderBy: orderBy),
        _db.getBooks(isPrivate: true, orderBy: orderBy),
      ]);

      _publicBooks = results[0].map((e) => Book.fromMap(e)).toList();
      _privateBooks = results[1].map((e) => Book.fromMap(e)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSelectionMode({bool? active, String? initialBookId}) {
    _isSelectionMode = active ?? !_isSelectionMode;
    _selectedBookIds.clear();
    if (_isSelectionMode && initialBookId != null) {
      _selectedBookIds.add(initialBookId);
    }
    notifyListeners();
  }

  void toggleBookSelection(String bookId) {
    if (_selectedBookIds.contains(bookId)) {
      _selectedBookIds.remove(bookId);
    } else {
      _selectedBookIds.add(bookId);
    }
    notifyListeners();
  }

  void selectAll(bool isPrivateShelf) {
    final targetBooks = isPrivateShelf ? _privateBooks : _publicBooks;
    final allIds = targetBooks.map((b) => b.id).toSet();

    final allSelected = allIds.every((id) => _selectedBookIds.contains(id));

    if (allSelected) {
      _selectedBookIds.removeAll(allIds);
    } else {
      _selectedBookIds.addAll(allIds);
    }
    notifyListeners();
  }

  /// Deletes selected books from memory and database (and optionally files)
  Future<void> deleteSelectedBooks(bool deleteFiles) async {
    if (_selectedBookIds.isEmpty) return;

    // We must collect paths before deleting from db if deleteFiles is true
    List<String> pathsToDelete = [];
    if (deleteFiles) {
      for (final id in _selectedBookIds) {
        final book = _publicBooks.followedBy(_privateBooks).firstWhere(
            (b) => b.id == id,
            orElse: () => throw Exception('Book missing'));
        pathsToDelete.add(book.filePath);
      }
    }

    try {
      await _db.deleteBooks(_selectedBookIds.toList());

      // TODO: Actual file deletion would go here using dart:io on pathsToDelete

      _selectedBookIds.clear();
      _isSelectionMode = false;
      await loadBooks(); // Reload state
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Moves selected books between public and private shelf
  Future<void> moveSelectedBooks(bool toPrivate) async {
    if (_selectedBookIds.isEmpty) return;

    try {
      for (final id in _selectedBookIds) {
        await _db.updateBook(id, {'is_private': toPrivate ? 1 : 0});
      }

      _selectedBookIds.clear();
      _isSelectionMode = false;
      await loadBooks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
