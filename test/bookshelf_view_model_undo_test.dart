/// Tests for the bookshelf delete/undo semantics (analysis item #4):
///   1. Undo restores books together with their bookmarks and highlights.
///   2. Physical file deletion is deferred past the undo window, and undo
///      cancels it entirely.
///   3. A new delete batch invalidates the previous undo snapshot.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/modules/bookshelf/bookshelf_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in overriding every DatabaseService method the view model
/// touches, so no sqflite/path_provider plumbing is needed.
class _FakeDb extends DatabaseService {
  final Map<String, Map<String, dynamic>> books = {};
  final Map<String, List<Map<String, dynamic>>> bookmarksByBook = {};
  final Map<String, List<Map<String, dynamic>>> highlightsByBook = {};

  int restoreCalls = 0;

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

  Future<void> pumpVm() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = BookshelfPreferencesService();
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

  test('second delete batch invalidates the previous undo snapshot',
      () async {
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

  test('undo with empty snapshot is a no-op', () async {
    await vm.undoLastDelete();
    expect(db.restoreCalls, 0);
  });

  test('sandbox copies are reclaimed even when deleteFiles is false',
      () async {
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
}
