import 'dart:async';
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
  // Populated by deleteSelectedBooks so undoLastDelete can restore the rows
  // *and* their bookmarks/highlights. Cleared after a successful undo, the
  // next delete batch, or when the deferred file deletion commits.
  List<Map<String, dynamic>> _lastDeletedBookMaps = [];
  List<Map<String, dynamic>> _lastDeletedBookmarkMaps = [];
  List<Map<String, dynamic>> _lastDeletedHighlightMaps = [];

  // Physical file deletion is deferred past the undo toast so "Undo" can
  // still bring the book back with a working source. Committed when the
  // timer fires, a new delete batch starts, or the VM is disposed.
  List<String> _pendingFileDeletions = const [];
  Timer? _pendingFileDeleteTimer;

  // Undo toast shows for 4s; leave margin so a last-moment tap still wins.
  static const _fileDeleteGraceWindow = Duration(seconds: 8);

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
  /// The user's bookmarks/highlights are snapshotted first so
  /// [undoLastDelete] can restore them. When [deleteFiles] is true the
  /// physical deletion is *deferred* by [_fileDeleteGraceWindow] so an undo
  /// within the toast window brings back a book whose source still exists:
  /// plain filesystem paths via [File.delete], Android `content://` URIs via
  /// [BookSourcePlatform.deletePersistedUriDocument]. Per-file failures are
  /// logged and do not abort the batch.
  Future<void> deleteSelectedBooks(bool deleteFiles) async {
    if (_selectedBookIds.isEmpty) return;

    // A new batch supersedes the previous undo window: commit any deferred
    // file deletions and drop the stale snapshot.
    await _commitPendingFileDeletions();

    final idsToDelete = _selectedBookIds.toList(growable: false);
    final booksById = {
      for (final book in _publicBooks.followedBy(_privateBooks)) book.id: book,
    };
    final selectedBooks =
        idsToDelete.map((id) => booksById[id]).whereType<Book>().toList();
    // App-private sandbox copies are our own storage, invisible to the user —
    // reclaim them unconditionally; the "also delete files" toggle only
    // governs user-owned files.
    final booksWithDeletableSources = selectedBooks
        .where((b) =>
            deleteFiles || b.storageType == BookStorageType.appPrivateCopy)
        .toList();
    final pathsToDelete =
        _collectDeletableSourcePaths(booksWithDeletableSources);

    // Snapshot rows (book + bookmarks + highlights) before deletion so
    // undoLastDelete can restore the user's notes, not just the book rows.
    _lastDeletedBookMaps =
        selectedBooks.map((b) => Map<String, dynamic>.from(b.toMap())).toList();
    final bookmarkMaps = <Map<String, dynamic>>[];
    final highlightMaps = <Map<String, dynamic>>[];
    for (final id in idsToDelete) {
      bookmarkMaps
          .addAll((await _db.getBookmarks(id)).map(Map<String, dynamic>.from));
      highlightMaps
          .addAll((await _db.getHighlights(id)).map(Map<String, dynamic>.from));
    }
    _lastDeletedBookmarkMaps = bookmarkMaps;
    _lastDeletedHighlightMaps = highlightMaps;

    try {
      await _db.deleteBooksWithAssociatedData(idsToDelete);

      if (pathsToDelete.isNotEmpty) {
        _pendingFileDeletions = pathsToDelete;
        _pendingFileDeleteTimer = Timer(_fileDeleteGraceWindow, () {
          // Fire-and-forget: the timer callback cannot await, and a failed
          // deferred deletion only leaves an orphan file behind.
          unawaited(_commitPendingFileDeletions());
        });
      }

      _selectedBookIds.clear();
      _isSelectionMode = false;
      await loadBooks(); // Reload state
    } catch (e) {
      _clearUndoSnapshot();
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Restores the most recently deleted batch: book rows together with their
  /// bookmarks/highlights (single transaction), and cancels the deferred
  /// physical file deletion so the restored books still open.
  Future<void> undoLastDelete() async {
    if (_lastDeletedBookMaps.isEmpty) return;

    // Cancel the deferred file deletion — the sources must survive the undo.
    _pendingFileDeleteTimer?.cancel();
    _pendingFileDeleteTimer = null;
    _pendingFileDeletions = const [];

    final books = List<Map<String, dynamic>>.from(_lastDeletedBookMaps);
    final bookmarks =
        List<Map<String, dynamic>>.from(_lastDeletedBookmarkMaps);
    final highlights =
        List<Map<String, dynamic>>.from(_lastDeletedHighlightMaps);
    _clearUndoSnapshot();

    try {
      await _db.restoreDeletedBooksBatch(
        books: books,
        bookmarks: bookmarks,
        highlights: highlights,
      );
      await loadBooks();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _clearUndoSnapshot() {
    _lastDeletedBookMaps = [];
    _lastDeletedBookmarkMaps = [];
    _lastDeletedHighlightMaps = [];
  }

  /// Runs the deferred physical deletion (if any) and invalidates the undo
  /// snapshot — once the files are gone an undo could no longer restore a
  /// working book.
  Future<void> _commitPendingFileDeletions() async {
    _pendingFileDeleteTimer?.cancel();
    _pendingFileDeleteTimer = null;
    final paths = _pendingFileDeletions;
    _pendingFileDeletions = const [];
    if (paths.isEmpty) return;

    _clearUndoSnapshot();
    await _deleteSourceFilesBestEffort(paths);
  }

  @override
  void dispose() {
    // Honour the user's "also delete files" choice even if the shelf page
    // goes away before the grace window elapses.
    unawaited(_commitPendingFileDeletions());
    super.dispose();
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
