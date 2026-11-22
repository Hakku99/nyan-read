/// Audit P2-14 / P2-15: bookmark display order and load-error propagation for
/// the notes / bookmarks pages' data path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/modules/notes/book_annotations_controller.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

class _FakeDb extends DatabaseService {
  List<Map<String, dynamic>> bookmarks = [];
  Object? loadError;

  @override
  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async {
    if (loadError != null) throw loadError!;
    return bookmarks;
  }

  @override
  Future<List<Map<String, dynamic>>> getHighlights(String bookId) async {
    if (loadError != null) throw loadError!;
    return const [];
  }
}

int _at(int day, [int hour = 10]) =>
    DateTime(2026, 11, day, hour).millisecondsSinceEpoch;

Map<String, dynamic> _bm(
  String id, {
  required int createdAt,
  String type = 'txt',
  ReadingPosition? position,
  String? rawPayload,
}) =>
    {
      'id': id,
      'created_at': createdAt,
      'page_index': 0, // the real writer always stores 0
      'position_type': type,
      'position_payload': rawPayload ?? position?.toJson(),
    };

List<String> _ids(List<Map<String, dynamic>> rows) =>
    [for (final r in rows) r['id'] as String];

void main() {
  group('sortBookmarksForDisplay', () {
    test('days newest first, reading order within a day', () {
      final sorted = sortBookmarksForDisplay([
        _bm('old-late', createdAt: _at(20), position: const ReadingPosition(paragraphIndex: 90)),
        _bm('new-late', createdAt: _at(22, 9), position: const ReadingPosition(paragraphIndex: 50)),
        _bm('new-early', createdAt: _at(22, 18), position: const ReadingPosition(paragraphIndex: 4)),
        _bm('old-early', createdAt: _at(20), position: const ReadingPosition(paragraphIndex: 2)),
      ]);

      expect(_ids(sorted), ['new-early', 'new-late', 'old-early', 'old-late']);
    });

    test('same paragraph is ordered by text offset', () {
      final sorted = sortBookmarksForDisplay([
        _bm('b', createdAt: _at(22), position: const ReadingPosition(paragraphIndex: 7, textOffset: 40)),
        _bm('a', createdAt: _at(22), position: const ReadingPosition(paragraphIndex: 7, textOffset: 5)),
      ]);

      expect(_ids(sorted), ['a', 'b']);
    });

    test('PDF bookmarks order by page number', () {
      final sorted = sortBookmarksForDisplay([
        _bm('p12', createdAt: _at(22), type: 'pdf', position: const ReadingPosition(pageNumber: 12)),
        _bm('p3', createdAt: _at(22), type: 'pdf', position: const ReadingPosition(pageNumber: 3)),
      ]);

      expect(_ids(sorted), ['p3', 'p12']);
    });

    test('unparseable payloads sort after located ones of the same day', () {
      final sorted = sortBookmarksForDisplay([
        _bm('broken', createdAt: _at(22, 8), rawPayload: 'not json'),
        _bm('missing', createdAt: _at(22, 9)),
        _bm('located', createdAt: _at(22, 20), position: const ReadingPosition(paragraphIndex: 99)),
      ]);

      expect(_ids(sorted), ['located', 'broken', 'missing']);
    });

    test('does not mutate the input rows', () {
      final input = [
        _bm('x', createdAt: _at(22), position: const ReadingPosition(paragraphIndex: 1)),
      ];
      sortBookmarksForDisplay(input).first['index'] = 1;

      expect(input.first.containsKey('index'), isFalse);
    });
  });

  group('BookAnnotationsController', () {
    test('load failures propagate instead of becoming an empty list', () async {
      final db = _FakeDb()..loadError = StateError('db locked');
      final controller = BookAnnotationsController(db);

      await expectLater(controller.loadHighlights('b'), throwsStateError);
      await expectLater(controller.loadBookmarks('b'), throwsStateError);
    });

    test('labels follow creation order and survive a new bookmark', () async {
      final old = _bm('old', createdAt: _at(20), position: const ReadingPosition(paragraphIndex: 90));
      final mid = _bm('mid', createdAt: _at(22, 9), position: const ReadingPosition(paragraphIndex: 4));
      final late = _bm('late', createdAt: _at(22, 18), position: const ReadingPosition(paragraphIndex: 50));
      final db = _FakeDb()..bookmarks = [old, mid, late];
      final controller = BookAnnotationsController(db);

      final first = await controller.loadBookmarks('b');
      expect(_ids(first), ['mid', 'late', 'old']); // day desc, position asc
      expect({for (final r in first) r['id']: r['index']},
          {'old': 1, 'mid': 2, 'late': 3});

      // A newer day, earlier in the book: lands first on screen but must not
      // renumber the bookmarks the user already knows.
      db.bookmarks = [
        old,
        mid,
        late,
        _bm('new', createdAt: _at(23), position: const ReadingPosition(paragraphIndex: 1)),
      ];
      final second = await controller.loadBookmarks('b');
      expect(_ids(second).first, 'new');
      expect({for (final r in second) r['id']: r['index']},
          {'old': 1, 'mid': 2, 'late': 3, 'new': 4});
    });

    test('loadBookmarks returns display order', () async {
      final db = _FakeDb()
        ..bookmarks = [
          _bm('late', createdAt: _at(22), position: const ReadingPosition(paragraphIndex: 9)),
          _bm('early', createdAt: _at(22), position: const ReadingPosition(paragraphIndex: 1)),
        ];

      final rows = await BookAnnotationsController(db).loadBookmarks('b');

      expect(_ids(rows), ['early', 'late']);
    });
  });
}
