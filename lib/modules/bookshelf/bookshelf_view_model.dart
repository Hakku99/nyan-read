import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/utils/book_source_platform.dart';

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

  // --- Undo State ---
  // Populated by deleteSelectedBooks so undoLastDelete can restore the rows.
  // Cleared after a successful undo or the next delete batch.
  List<Map<String, dynamic>> _lastDeletedBookMaps = [];

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedBookIds => _selectedBookIds;
  int get selectedCount => _selectedBookIds.length;

  // --- Derived State ---
  bool isBookSelected(String bookId) => _selectedBookIds.contains(bookId);

  List<Book> get selectedBooks {
    final byId = {
      for (final b in _publicBooks.followedBy(_privateBooks)) b.id: b,
    };
    return _selectedBookIds.map((id) => byId[id]).whereType<Book>().toList();
  }

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

  /// Deletes selected books from memory and database (and optionally files).
  ///
  /// When [deleteFiles] is true, deletes each book's source on disk: plain
  /// filesystem paths via [File.delete], Android `content://` URIs via
  /// [BookSourcePlatform.deletePersistedUriDocument]. Per-file failures are
  /// logged and do not abort the batch; DB rows are still removed first.
  Future<void> deleteSelectedBooks(bool deleteFiles) async {
    if (_selectedBookIds.isEmpty) return;

    final idsToDelete = _selectedBookIds.toList(growable: false);
    final booksById = {
      for (final book in _publicBooks.followedBy(_privateBooks)) book.id: book,
    };
    final selectedBooks =
        idsToDelete.map((id) => booksById[id]).whereType<Book>().toList();
    final pathsToDelete = deleteFiles
        ? _collectDeletableSourcePaths(selectedBooks)
        : const <String>[];

    // Save book maps before deletion so undoLastDelete can restore them.
    _lastDeletedBookMaps =
        selectedBooks.map((b) => Map<String, dynamic>.from(b.toMap())).toList();

    try {
      await _db.deleteBooksWithAssociatedData(idsToDelete);
      await _deleteSourceFilesBestEffort(pathsToDelete);

      _selectedBookIds.clear();
      _isSelectionMode = false;
      await loadBooks(); // Reload state
    } catch (e) {
      _lastDeletedBookMaps = [];
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Re-inserts the most recently deleted batch of books (DB rows only —
  /// associated data such as bookmarks and highlights is not restored since it
  /// was permanently removed by [deleteSelectedBooks]).
  Future<void> undoLastDelete() async {
    if (_lastDeletedBookMaps.isEmpty) return;

    final mapsToRestore = List<Map<String, dynamic>>.from(_lastDeletedBookMaps);
    _lastDeletedBookMaps = [];

    try {
      for (final bookMap in mapsToRestore) {
        await _db.insertBook(bookMap);
      }
      await loadBooks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Locators the user opted to delete alongside DB rows (`content://` or
  /// filesystem paths).
  ///
  /// Skips empty locators and unknown source kinds.
  List<String> _collectDeletableSourcePaths(List<Book> books) {
    if (books.isEmpty) return const [];

    final seenNormalized = <String>{};
    final pathsToDelete = <String>[];

    for (final book in books) {
      final locator = book.sourceLocator.trim();
      if (locator.isEmpty) {
        continue;
      }

      if (book.isAndroidContentUri) {
        if (!locator.toLowerCase().startsWith('content://')) {
          continue;
        }
        final key = locator.toLowerCase();
        if (!seenNormalized.add(key)) {
          continue;
        }
        pathsToDelete.add(book.sourceLocator);
        continue;
      }

      if (!book.isFilePathSource) {
        continue;
      }

      if (locator.toLowerCase().startsWith('content://')) {
        continue;
      }

      final normalized = path.normalize(locator).toLowerCase();
      if (!seenNormalized.add(normalized)) {
        continue;
      }

      pathsToDelete.add(book.sourceLocator);
    }

    return pathsToDelete;
  }

  Future<void> _deleteSourceFilesBestEffort(List<String> locators) async {
    // content:// URIs must be deleted serially — platform channel is not
    // concurrency-safe across simultaneous calls.
    final contentUris = <String>[];
    final fsPaths = <String>[];

    for (final rawLocator in locators) {
      final locator = rawLocator.trim();
      if (locator.isEmpty) continue;
      if (locator.toLowerCase().startsWith('content://')) {
        contentUris.add(locator);
      } else {
        fsPaths.add(locator);
      }
    }

    // Serial deletion of content:// URIs (platform channel constraint).
    for (final locator in contentUris) {
      final deleted =
          await BookSourcePlatform.deletePersistedUriDocument(locator);
      if (!deleted) {
        debugPrint(
          'Failed to delete content Uri (unsupported provider or no '
          'persistable delete permission): $locator',
        );
      }
    }

    // Parallel deletion of filesystem paths.
    await Future.wait(
      fsPaths.map((locator) async {
        try {
          var fsPath = locator;
          if (locator.toLowerCase().startsWith('file://')) {
            fsPath = Uri.parse(locator).toFilePath();
          }
          fsPath = path.normalize(fsPath);
          final file = File(fsPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e, stackTrace) {
          debugPrint(
            'Failed to delete source file: $locator\n$e\n$stackTrace',
          );
        }
      }),
    );
  }

  /// Moves selected books between public and private shelf using a single batch.
  Future<void> moveSelectedBooks(bool toPrivate) async {
    if (_selectedBookIds.isEmpty) return;

    try {
      await _db.updateBooksPrivacy(_selectedBookIds.toList(), toPrivate);

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
