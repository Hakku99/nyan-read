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
    // Fire-and-forget: finishing a previous session's interrupted file
    // deletion must not delay the first shelf load.
    unawaited(_recoverInterruptedFileDeletions());
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

  // --- Status filter views (docs/DESIGN_LIBRARY_FOLDERS.md §5.1) ---
  // Cached here — NOT filtered in build() — so grid rebuilds never re-run
  // .where().toList() on the shelf list (§3.4 build purity).
  List<Book> _visiblePublicBooks = [];
  List<Book> _visiblePrivateBooks = [];

  List<Book> get visiblePublicBooks => _visiblePublicBooks;
  List<Book> get visiblePrivateBooks => _visiblePrivateBooks;

  // Hero-card picks, cached for the same reason: the lists only change in
  // loadBooks(), so build() must not rescan them.
  Book? _continueReadingPublic;
  Book? _continueReadingPrivate;

  Book? continueReadingBookFor({required bool isPrivate}) =>
      isPrivate ? _continueReadingPrivate : _continueReadingPublic;

  ShelfStatusFilter statusFilterFor({required bool isPrivate}) =>
      _prefs.statusFilterFor(isPrivate: isPrivate);

  Future<void> setStatusFilter({
    required bool isPrivate,
    required ShelfStatusFilter filter,
  }) async {
    await _prefs.setStatusFilter(isPrivate: isPrivate, filter: filter);
    _rebuildVisibleBooks();
    notifyListeners();
  }

  void _rebuildVisibleBooks() {
    _visiblePublicBooks = filterBooksByStatus(
        _publicBooks, _prefs.statusFilterFor(isPrivate: false));
    _visiblePrivateBooks = filterBooksByStatus(
        _privateBooks, _prefs.statusFilterFor(isPrivate: true));
    _continueReadingPublic = resolveContinueReadingBook(_publicBooks);
    _continueReadingPrivate = resolveContinueReadingBook(_privateBooks);
  }

  /// `reading` vs `unread` keys off last_read_at — the same signal the sort
  /// clause already uses for "keep unread books at the end".
  @visibleForTesting
  static List<Book> filterBooksByStatus(
      List<Book> books, ShelfStatusFilter filter) {
    switch (filter) {
      case ShelfStatusFilter.all:
        return books;
      case ShelfStatusFilter.reading:
        return books.where((b) => b.lastReadAt != null).toList(growable: false);
      case ShelfStatusFilter.unread:
        return books.where((b) => b.lastReadAt == null).toList(growable: false);
    }
  }

  /// The in-progress book opened most recently, independent of the shelf's
  /// sort order. A null `lastReadAt` counts as "never opened" and loses to any
  /// timestamp; ties keep the shelf's sort order. Falls back to the first book
  /// so the hero never disappears on a shelf with nothing in progress.
  static Book? resolveContinueReadingBook(List<Book> books) {
    Book? best;
    for (final book in books) {
      if (book.currentProgress <= 0 || book.currentProgress >= 1) continue;
      if (best == null || (book.lastReadAt ?? 0) > (best.lastReadAt ?? 0)) {
        best = book;
      }
    }
    return best ?? (books.isEmpty ? null : books.first);
  }

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
  // SAF grants to hand back once the undo window closes. In-memory only: a
  // kill inside the 8s window leaks at most this batch's grants.
  List<String> _pendingGrantReleases = const [];
  Timer? _pendingFileDeleteTimer;

  // Undo toast shows for 4s; leave margin so a last-moment tap still wins.
  static const _fileDeleteGraceWindow = Duration(seconds: 8);

  /// Called with the number of source files that could not be deleted once
  /// the deferred deletion commits. The shelf screen sets this to surface a
  /// toast; null (screen gone) means the failure stays in the debug log.
  void Function(int failedCount)? onFileDeletionFailed;

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
      _rebuildVisibleBooks();
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
    // Acts on the VISIBLE (status-filtered) list — selecting books the user
    // cannot see would make bulk delete a trap.
    final targetBooks =
        isPrivateShelf ? _visiblePrivateBooks : _visiblePublicBooks;
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

      // Independent of the "also delete files" toggle: the grant is ours to
      // give back either way (Android silently evicts the oldest grants once
      // the per-app quota is exceeded).
      _pendingGrantReleases = _collectReleasableGrants(selectedBooks);

      if (pathsToDelete.isNotEmpty || _pendingGrantReleases.isNotEmpty) {
        _pendingFileDeletions = pathsToDelete;
        if (pathsToDelete.isNotEmpty) {
          await _persistPendingDeletions(pathsToDelete);
        }
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
    _pendingGrantReleases = const [];

    // Take and clear the snapshot BEFORE the first await: a second Undo tap
    // (or a new delete batch) during the prefs write must not see it.
    final books = List<Map<String, dynamic>>.from(_lastDeletedBookMaps);
    final bookmarks = List<Map<String, dynamic>>.from(_lastDeletedBookmarkMaps);
    final highlights =
        List<Map<String, dynamic>>.from(_lastDeletedHighlightMaps);
    _clearUndoSnapshot();

    // Before the restore, so a kill mid-restore cannot replay the deletion.
    await _persistPendingDeletions(const []);

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

  /// Fresh DB check (not the cached list) for "does a private book exist?".
  /// Gates PIN-less first-time setup: private rows that survive without a PIN
  /// (restored backup, self-heal) must not be handed to whoever taps first.
  Future<bool> hasAnyPrivateBooks() async =>
      (await _db.getBooks(isPrivate: true)).isNotEmpty;

  /// Forgot-PIN "erase": removes EVERY private book with its bookmarks and
  /// highlights. Deliberately independent of the selection state (the user may
  /// have public books selected) and of undo — a restorable snapshot of the
  /// private shelf would defeat the point of erasing it, so an undo snapshot
  /// that holds private rows is committed and dropped. A snapshot of public
  /// books only is left alone, so a visible Undo toast keeps working.
  ///
  /// Only app-private sandbox copies are reclaimed; user-owned source files
  /// stay put, matching the default "also delete files" = off of a normal
  /// delete. Returns the number of books removed.
  ///
  /// Reads the private rows straight from the DB (not [_privateBooks]) and
  /// verifies none survive: the caller clears the PIN right after, and a PIN-
  /// less shelf that still holds books would be open to whoever taps unlock
  /// next. Throws if anything remains, so the PIN is left untouched.
  Future<int> eraseAllPrivateBooks() async {
    if (_lastDeletedBookMaps.any((m) => m['is_private'] == 1)) {
      await _commitPendingFileDeletions();
      _clearUndoSnapshot();
    }

    final books = (await _db.getBooks(isPrivate: true))
        .map(Book.fromMap)
        .toList(growable: false);
    if (books.isEmpty) return 0;

    final ids = books.map((b) => b.id).toList(growable: false);
    final pathsToDelete = _collectDeletableSourcePaths(books
        .where((b) => b.storageType == BookStorageType.appPrivateCopy)
        .toList());

    await _db.deleteBooksWithAssociatedData(ids);
    _selectedBookIds.removeAll(ids);
    if ((await _db.getBooks(isPrivate: true)).isNotEmpty) {
      await loadBooks();
      throw StateError('Private books survived erase');
    }
    await _releaseGrants(_collectReleasableGrants(books));

    if (pathsToDelete.isNotEmpty) {
      // Persist first so a kill mid-deletion replays on next launch, then
      // delete right away: there is no undo window to wait out.
      // Merged, not replaced: a public delete may still be inside its undo
      // window with its own paths persisted.
      await _persistPendingDeletions(
          [..._prefs.pendingFileDeletions, ...pathsToDelete]);
      final failed = await _deleteSourceFilesBestEffort(pathsToDelete);
      await _forgetPersistedDeletions(pathsToDelete);
      if (failed > 0) onFileDeletionFailed?.call(failed);
    }

    await loadBooks();
    return ids.length;
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
    final grants = _pendingGrantReleases;
    _pendingFileDeletions = const [];
    _pendingGrantReleases = const [];
    if (paths.isEmpty && grants.isEmpty) return;

    // Once files are gone or grants released an undo could no longer restore
    // a working book.
    _clearUndoSnapshot();
    if (paths.isNotEmpty) {
      final failed = await _deleteSourceFilesBestEffort(paths);
      // Forgotten only after the attempt: a kill mid-deletion replays the
      // (safe, idempotent) list on next launch instead of losing it.
      await _forgetPersistedDeletions(paths);
      if (failed > 0) onFileDeletionFailed?.call(failed);
    }
    // After the file delete: deleting a document needs the grant.
    await _releaseGrants(grants);
  }

  /// Per-file `content://` grants only. A library-folder (tree) grant covers
  /// every book under it and is owned by the folder, not by any one book.
  /// Fingerprint dedup keeps one book per locator, so the grant is not shared.
  List<String> _collectReleasableGrants(List<Book> books) => [
        for (final b in books)
          if (b.isAndroidContentUri &&
              b.sourceLocator.toLowerCase().startsWith('content://'))
            b.sourceLocator,
      ];

  Future<void> _releaseGrants(List<String> uris) async {
    for (final uri in uris) {
      try {
        await BookSourcePlatform.releasePersistedPermission(uri);
      } catch (e) {
        debugPrint('Failed to release persisted permission: $e');
      }
    }
  }

  /// Drops only [done] from the persisted list. A blanket clear would also
  /// wipe a newer batch persisted while this one's files were being deleted
  /// (the timer commit and a fresh delete can overlap).
  Future<void> _forgetPersistedDeletions(List<String> done) =>
      _persistPendingDeletions([
        for (final p in _prefs.pendingFileDeletions)
          if (!done.contains(p)) p,
      ]);

  /// Best-effort: if persisting fails we fall back to the in-memory-only
  /// behavior (files can be orphaned by a kill) rather than failing a delete
  /// whose DB rows are already gone.
  Future<void> _persistPendingDeletions(List<String> locators) async {
    try {
      await _prefs.setPendingFileDeletions(locators);
    } catch (e) {
      debugPrint('Failed to persist pending file deletions: $e');
    }
  }

  /// Finishes deletions left over from a session that died inside the undo
  /// grace window. Undo is impossible after a restart, so deleting is the
  /// only consistent outcome.
  Future<void> _recoverInterruptedFileDeletions() async {
    final stale = _prefs.pendingFileDeletions;
    if (stale.isEmpty) return;
    // Forget only after the attempt, like the normal commit path: dying
    // again mid-recovery must not drop the list with the files still on disk.
    await _deleteSourceFilesBestEffort(stale);
    await _forgetPersistedDeletions(stale);
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

      // Library-folder books (android_tree_uri) are SAF documents too; they
      // were silently skipped here, so "also delete files" left them on disk.
      if (book.isAndroidContentUri || book.isAndroidTreeUri) {
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

  /// Returns how many files could NOT be deleted (already-missing files do
  /// not count as failures).
  Future<int> _deleteSourceFilesBestEffort(List<String> locators) async {
    var failed = 0;
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
        failed++;
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
          failed++;
        }
      }),
    );
    return failed;
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
