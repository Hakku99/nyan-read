/// Tests for the bookshelf delete/undo semantics (analysis item #4):
///   1. Undo restores books together with their bookmarks and highlights.
///   2. Physical file deletion is deferred past the undo window, and undo
///      cancels it entirely.
///   3. A new delete batch invalidates the previous undo snapshot.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/utils/book_source_access.dart';
import 'package:nyan_read/modules/bookshelf/bookshelf_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in overriding every DatabaseService method the view model
/// touches, so no sqflite/path_provider plumbing is needed.
class _FakeDb extends DatabaseService {
  final Map<String, Map<String, dynamic>> books = {};
  final Map<String, List<Map<String, dynamic>>> bookmarksByBook = {};
  final Map<String, List<Map<String, dynamic>>> highlightsByBook = {};

  int restoreCalls = 0;

  /// Simulates a delete that silently leaves rows behind.
  bool refuseDelete = false;

  @override
  Future<List<Map<String, dynamic>>> getBooks({
    bool isPrivate = false,
    String orderBy = 'last_read_at DESC',
  }) async {
    return books.values
        .where((b) => (b['is_private'] ?? 0) == (isPrivate ? 1 : 0))
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async =>
      List.of(bookmarksByBook[bookId] ?? const []);

  @override
  Future<List<Map<String, dynamic>>> getHighlights(String bookId) async =>
      List.of(highlightsByBook[bookId] ?? const []);

  @override
  Future<void> deleteBooksWithAssociatedData(List<String> bookIds) async {
    if (refuseDelete) return;
    for (final id in bookIds) {
      books.remove(id);
      bookmarksByBook.remove(id);
      highlightsByBook.remove(id);
    }
  }

  @override
  Future<void> restoreDeletedBooksBatch({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> bookmarks,
    required List<Map<String, dynamic>> highlights,
  }) async {
    restoreCalls++;
    for (final book in books) {
      this.books[book['id'] as String] = Map.of(book);
    }
    for (final bm in bookmarks) {
      bookmarksByBook
          .putIfAbsent(bm['book_id'] as String, () => [])
          .add(Map.of(bm));
    }
    for (final h in highlights) {
      highlightsByBook
          .putIfAbsent(h['book_id'] as String, () => [])
          .add(Map.of(h));
    }
  }
}

Map<String, dynamic> _bookRow(String id) => {
      'id': id,
      'title': 'Book $id',
      'author': 'Author',
      'file_path': '/books/$id.txt',
      'format': 'txt',
      'is_private': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDb db;
  late BookshelfViewModel vm;
  late BookshelfPreferencesService prefs;

  Future<void> pumpVm([Map<String, Object> initialPrefs = const {}]) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    prefs = BookshelfPreferencesService();
    await prefs.initialize();
    vm = BookshelfViewModel(db, prefs);
    // Let the constructor's loadBooks() settle.
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    db = _FakeDb();
    db.books['b1'] = _bookRow('b1');
    db.bookmarksByBook['b1'] = [
      {'id': 'bm1', 'book_id': 'b1', 'page_index': 0, 'note': 'keep me'},
    ];
    db.highlightsByBook['b1'] = [
      {
        'id': 'h1',
        'book_id': 'b1',
        'paragraph_index': 3,
        'start_offset': 0,
        'end_offset': 5,
        'selected_text': 'hello',
      },
    ];
    await pumpVm();
  });

  test('undo restores book together with bookmarks and highlights', () async {
    vm.toggleSelectionMode(active: true, initialBookId: 'b1');
    await vm.deleteSelectedBooks(false);

    expect(db.books, isEmpty);
    expect(db.bookmarksByBook, isEmpty);
    expect(db.highlightsByBook, isEmpty);

    await vm.undoLastDelete();

    expect(db.restoreCalls, 1);
    expect(db.books.keys, contains('b1'));
    expect(db.bookmarksByBook['b1']!.single['note'], 'keep me');
    expect(db.highlightsByBook['b1']!.single['selected_text'], 'hello');
  });

  test('undo within grace window keeps the source file alive', () async {
    // deleteFiles=true defers the physical deletion; undoing inside the
    // window must cancel it. The fake path does not exist on disk, so a
    // (buggy) immediate deletion would be silently skipped either way —
    // what we assert is that undo restores rows and never throws.
    vm.toggleSelectionMode(active: true, initialBookId: 'b1');
    await vm.deleteSelectedBooks(true);

    await vm.undoLastDelete();

    expect(db.books.keys, contains('b1'));
    expect(db.bookmarksByBook['b1'], isNotEmpty);
  });

  test('second delete batch invalidates the previous undo snapshot', () async {
    db.books['b2'] = _bookRow('b2');
    await vm.loadBooks();

    vm.toggleSelectionMode(active: true, initialBookId: 'b1');
    await vm.deleteSelectedBooks(false);

    vm.toggleSelectionMode(active: true, initialBookId: 'b2');
    await vm.deleteSelectedBooks(false);

    await vm.undoLastDelete();

    // Only b2 (the latest batch) comes back.
    expect(db.books.keys, contains('b2'));
    expect(db.books.keys, isNot(contains('b1')));
  });

  test('a double-tapped undo restores the batch exactly once', () async {
    vm.toggleSelectionMode(active: true, initialBookId: 'b1');
    await vm.deleteSelectedBooks(true);

    // Both calls start before either finishes its prefs write.
    await Future.wait([vm.undoLastDelete(), vm.undoLastDelete()]);

    expect(db.restoreCalls, 1);
    expect(db.books.keys, contains('b1'));
  });

  test('undo with empty snapshot is a no-op', () async {
    await vm.undoLastDelete();
    expect(db.restoreCalls, 0);
  });

  test('sandbox copies are reclaimed even when deleteFiles is false', () async {
    final tempDir = await Directory.systemTemp.createTemp('nyan_vm_test');
    addTearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });
    final copy = File('${tempDir.path}/b1.txt')..writeAsStringSync('x');

    db.books['b1'] = {
      ..._bookRow('b1'),
      'file_path': copy.path,
      'storage_type': 'app_private_copy',
    };
    await vm.loadBooks();

    vm.toggleSelectionMode(active: true, initialBookId: 'b1');
    await vm.deleteSelectedBooks(false); // user did NOT opt into file deletion

    // Deferred deletion is committed on dispose (grace window shortcut).
    vm.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(copy.existsSync(), isFalse);
  });

  group('pending file deletions survive a process kill', () {
    late Directory tempDir;
    late File sourceFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nyan_vm_pending');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      sourceFile = File('${tempDir.path}/b1.txt')..writeAsStringSync('x');
      db.books['b1'] = {..._bookRow('b1'), 'file_path': sourceFile.path};
      await vm.loadBooks();
    });

    test('deferred deletion is persisted until it commits or is undone',
        () async {
      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(true);

      // Inside the grace window: file alive, but the work is on disk.
      expect(sourceFile.existsSync(), isTrue);
      expect(prefs.pendingFileDeletions, [sourceFile.path]);

      await vm.undoLastDelete();
      expect(prefs.pendingFileDeletions, isEmpty);
      expect(sourceFile.existsSync(), isTrue);
    });

    test('commit deletes the file and clears the persisted list', () async {
      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(true);

      vm.dispose(); // commits the deferred deletion
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(sourceFile.existsSync(), isFalse);
      expect(prefs.pendingFileDeletions, isEmpty);
    });

    test('next launch finishes a deletion interrupted by a kill', () async {
      // Simulate the killed session: the list was persisted, the timer never
      // fired, and the process died with the file still on disk.
      await pumpVm({
        'bookshelf_pending_file_deletions': [sourceFile.path],
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(sourceFile.existsSync(), isFalse);
      expect(prefs.pendingFileDeletions, isEmpty);
    });
  });

  group('library-folder (android_tree_uri) books', () {
    const treeUri = 'content://com.android.externalstorage.documents/tree/'
        'primary%3ABooks/document/primary%3ABooks%2Fa.epub';

    setUp(() async {
      db.books['b1'] = {
        ..._bookRow('b1'),
        'file_path': treeUri,
        'source_type': 'android_tree_uri',
        'format': 'epub',
      };
      await vm.loadBooks();
    });

    const channel = MethodChannel('com.example.nyan_read/book_source');
    late List<String> deletedUris;
    late bool providerAccepts;

    setUp(() {
      deletedUris = [];
      providerAccepts = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'deletePersistedUriDocument') {
          deletedUris.add((call.arguments as Map)['uri'] as String);
          return providerAccepts;
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
    });

    Future<void> deleteBook({required bool deleteFiles}) async {
      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(deleteFiles);
      vm.dispose(); // commits the deferred deletion
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    test('are handed to the platform delete when the user opted in', () async {
      final failures = <int>[];
      vm.onFileDeletionFailed = failures.add;

      await deleteBook(deleteFiles: true);

      // Before the fix the tree book was skipped: nothing was attempted.
      expect(deletedUris, [treeUri]);
      expect(failures, isEmpty);
    });

    test('a refusing provider is reported as a failed deletion', () async {
      providerAccepts = false;
      final failures = <int>[];
      vm.onFileDeletionFailed = failures.add;

      await deleteBook(deleteFiles: true);

      expect(deletedUris, [treeUri]);
      expect(failures, [1]);
    });

    test('are never touched when the user did not opt in', () async {
      final failures = <int>[];
      vm.onFileDeletionFailed = failures.add;

      await deleteBook(deleteFiles: false);

      expect(deletedUris, isEmpty);
      expect(failures, isEmpty);
    });
  });

  group('eraseAllPrivateBooks (forgot-PIN erase)', () {
    setUp(() async {
      db.books['p1'] = {..._bookRow('p1'), 'is_private': 1};
      db.books['p2'] = {..._bookRow('p2'), 'is_private': 1};
      db.bookmarksByBook['p1'] = [
        {'id': 'bm9', 'book_id': 'p1', 'page_index': 0},
      ];
      await vm.loadBooks();
    });

    test('removes every private book and its notes, public shelf untouched',
        () async {
      // A public book is mid-selection: erase must not depend on or consume it.
      vm.toggleSelectionMode(active: true, initialBookId: 'b1');

      final removed = await vm.eraseAllPrivateBooks();

      expect(removed, 2);
      expect(db.books.keys, ['b1']);
      expect(db.bookmarksByBook.containsKey('p1'), isFalse);
      expect(vm.privateBooks, isEmpty);
      expect(vm.selectedBookIds, {'b1'});
    });

    test('a public-only Undo snapshot survives an erase', () async {
      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(false);

      await vm.eraseAllPrivateBooks();
      await vm.undoLastDelete();

      expect(db.restoreCalls, 1, reason: 'the visible Undo toast must work');
      expect(db.books.keys, contains('b1'));
      expect(db.books.values.where((b) => b['is_private'] == 1), isEmpty);
    });

    test('an Undo snapshot holding private books is dropped by erase',
        () async {
      vm.toggleSelectionMode(active: true, initialBookId: 'p1');
      await vm.deleteSelectedBooks(false);

      await vm.eraseAllPrivateBooks();
      await vm.undoLastDelete();

      expect(db.restoreCalls, 0,
          reason: 'Undo must not resurrect a private book after erase');
      expect(db.books.values.where((b) => b['is_private'] == 1), isEmpty);
    });

    test('hasAnyPrivateBooks reads the DB, tracks erase', () async {
      expect(await vm.hasAnyPrivateBooks(), isTrue);
      db.books['p3'] = {..._bookRow('p3'), 'is_private': 1}; // VM list is stale
      await vm.eraseAllPrivateBooks();
      expect(await vm.hasAnyPrivateBooks(), isFalse);
      db.books['p4'] = {..._bookRow('p4'), 'is_private': 1}; // e.g. restored
      expect(await vm.hasAnyPrivateBooks(), isTrue);
    });

    test('is not undoable: no snapshot of the private shelf survives',
        () async {
      await vm.eraseAllPrivateBooks();
      await vm.undoLastDelete();

      expect(db.restoreCalls, 0);
      expect(db.books.keys, ['b1']);
    });

    test('works from the DB even when the VM list is stale', () async {
      db.books['p3'] = {..._bookRow('p3'), 'is_private': 1}; // VM never saw it

      await vm.eraseAllPrivateBooks();

      expect(db.books.values.where((b) => b['is_private'] == 1), isEmpty);
    });

    test('throws when private rows survive, so the PIN stays intact', () async {
      db.refuseDelete = true;

      await expectLater(vm.eraseAllPrivateBooks(), throwsStateError);
      expect(db.books.keys, containsAll(['p1', 'p2']));
    });
  });

  test('malformed pending-deletions value is discarded, not thrown', () async {
    await pumpVm({'bookshelf_pending_file_deletions': 'not-a-list'});

    expect(prefs.pendingFileDeletions, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(
      (await SharedPreferences.getInstance())
          .containsKey('bookshelf_pending_file_deletions'),
      isFalse,
    );
  });

  group('SAF grant give-back on delete', () {
    const channel = MethodChannel('com.example.nyan_read/book_source');
    const fileUri = 'content://com.android.providers.downloads.documents/'
        'document/42';
    const treeUri = 'content://com.android.externalstorage.documents/tree/'
        'primary%3ABooks/document/primary%3ABooks%2Fa.epub';
    late List<String> released;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      released = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'releasePersistedPermission') {
          released.add((call.arguments as Map)['uri'] as String);
          return true;
        }
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      db.books['c1'] = {
        ..._bookRow('c1'),
        'file_path': fileUri,
        'source_type': 'android_content_uri',
        'format': 'epub',
      };
      db.books['t1'] = {
        ..._bookRow('t1'),
        'file_path': treeUri,
        'source_type': 'android_tree_uri',
        'format': 'epub',
      };
      await vm.loadBooks();
    });

    Future<void> deleteBoth() async {
      vm.toggleSelectionMode(active: true, initialBookId: 'c1');
      vm.toggleBookSelection('t1');
      await vm.deleteSelectedBooks(false);
    }

    test('is deferred past the undo window and covers per-file books only',
        () async {
      await deleteBoth();
      expect(released, isEmpty);

      vm.dispose(); // commits the deferred work
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The tree grant belongs to the library folder, not to one book.
      expect(released, [fileUri]);
    });

    test('is persisted until released, and forgotten by commit', () async {
      await deleteBoth();
      expect(prefs.pendingGrantReleases, [fileUri]);

      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(released, [fileUri]);
      expect(prefs.pendingGrantReleases, isEmpty);
    });

    test('undo also forgets the persisted grants', () async {
      await deleteBoth();
      await vm.undoLastDelete();

      expect(prefs.pendingGrantReleases, isEmpty);
    });

    test('next launch releases grants left by a killed session', () async {
      db.books.remove('c1'); // the killed session had deleted it
      await pumpVm({
        'bookshelf_pending_grant_releases': [fileUri],
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(released, [fileUri]);
      expect(prefs.pendingGrantReleases, isEmpty);
    });

    test('recovery never releases a grant a live book still uses', () async {
      // c1 (fileUri) is still on the shelf, e.g. an undo whose prefs write
      // failed left the URI in the persisted list.
      await pumpVm({
        'bookshelf_pending_grant_releases': [fileUri],
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(released, isEmpty);
      expect(prefs.pendingGrantReleases, isEmpty);
    });

    test('undo cancels the give-back', () async {
      await deleteBoth();
      await vm.undoLastDelete();
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(released, isEmpty);
    });
  });

  group('SAF copy cache is reclaimed with the book', () {
    late Directory cacheRoot;

    File copyFor(String signature) {
      final dir = Directory('${cacheRoot.path}/${BookSourceAccess.copyCacheDirName}')
        ..createSync(recursive: true);
      return File('${dir.path}/$signature.epub')..writeAsStringSync('x');
    }

    setUp(() {
      cacheRoot = Directory.systemTemp.createTempSync('nyan_vm_copies');
      addTearDown(() => cacheRoot.deleteSync(recursive: true));
      final originalCacheRoot = BookSourceAccess.cacheRoot;
      addTearDown(() => BookSourceAccess.cacheRoot = originalCacheRoot);
      BookSourceAccess.cacheRoot = () async => cacheRoot;
      db.books['b1'] = {..._bookRow('b1'), 'content_signature': 'sigA'};
      db.books['b2'] = {..._bookRow('b2'), 'content_signature': 'sigB'};
    });

    test('delete removes the copy of that book and leaves others', () async {
      final a = copyFor('sigA');
      final b = copyFor('sigB');
      await vm.loadBooks();

      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(false);

      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isTrue);
    });

    test('a signature still used by a surviving book is kept', () async {
      db.books['b2'] = {..._bookRow('b2'), 'content_signature': 'sigA'};
      final a = copyFor('sigA');
      await vm.loadBooks();

      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(false);

      expect(a.existsSync(), isTrue);
    });

    test('books without a signature delete cleanly with no cache dir',
        () async {
      db.books['b1'] = _bookRow('b1');
      final other = copyFor('sigB');
      await vm.loadBooks();

      vm.toggleSelectionMode(active: true, initialBookId: 'b1');
      await vm.deleteSelectedBooks(false);

      expect(db.books.containsKey('b1'), isFalse);
      expect(other.existsSync(), isTrue); // a null signature must match nothing
    });

    test('startup sweep removes orphan copies and keeps every shelf book',
        () async {
      db.books['b3'] = {
        ..._bookRow('b3'),
        'content_signature': 'sigC',
        'is_private': 1,
      };
      final live = [copyFor('sigA'), copyFor('sigB'), copyFor('sigC')];
      final orphan = copyFor('gone');

      // A fresh VM stands in for the next launch: the sweep runs once, on
      // its first complete load.
      final launched = BookshelfViewModel(db, prefs);
      addTearDown(launched.dispose);
      for (var i = 0; i < 40 && orphan.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(orphan.existsSync(), isFalse);
      expect(live.every((f) => f.existsSync()), isTrue);
    });

    test('forgot-PIN erase also reclaims copies of private books', () async {
      db.books['b1'] = {
        ..._bookRow('b1'),
        'content_signature': 'sigA',
        'is_private': 1,
      };
      final a = copyFor('sigA');
      final b = copyFor('sigB');
      await vm.loadBooks();

      await vm.eraseAllPrivateBooks();

      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isTrue);
    });
  });
}
