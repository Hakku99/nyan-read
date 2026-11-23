/// Tests for DatabaseService.restoreDataBatch matching and progress rules:
///   - a backup book whose signature misses locally must NOT fall back to a
///     same-titled local book that already has a different signature;
///   - title fallback only targets a unique local book that has no signature
///     yet (backup book signed or not), and one local book is matched at most
///     once;
///   - progress is only overwritten by a strictly newer backup.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT,
            file_path TEXT NOT NULL, format TEXT NOT NULL,
            current_progress REAL DEFAULT 0, last_read_at INTEGER,
            last_position_type TEXT, last_position_payload TEXT,
            content_signature TEXT, is_private INTEGER DEFAULT 0)''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id TEXT PRIMARY KEY, book_id TEXT NOT NULL,
            page_index INTEGER NOT NULL,
            FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE)''');
        await db.execute('''
          CREATE TABLE highlights (
            id TEXT PRIMARY KEY, book_id TEXT NOT NULL,
            paragraph_index INTEGER NOT NULL, start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL, selected_text TEXT NOT NULL,
            color_code TEXT NOT NULL,
            FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE)''');
      },
    ),
  );
}

Future<void> _insertBook(
  Database db,
  String id, {
  String title = 'Same Title',
  String? sig,
  double progress = 0,
  int? lastReadAt,
  int isPrivate = 0,
}) =>
    db.insert('books', {
      'id': id,
      'title': title,
      'file_path': '/$id.txt',
      'format': 'txt',
      'content_signature': sig,
      'current_progress': progress,
      'last_read_at': lastReadAt,
      'is_private': isPrivate,
    });

Map<String, dynamic> _backupBook({
  String title = 'Same Title',
  String? sig,
  double progress = 0.9,
  int? lastReadAt = 2000,
  int? isPrivate,
  List<Map<String, dynamic>> highlights = const [],
}) =>
    {
      'title': title,
      'content_signature': sig,
      'current_progress': progress,
      'last_read_at': lastReadAt,
      'is_private': isPrivate,
      'highlights': highlights,
    };

Map<String, dynamic> _hl(String id) => {
      'id': id,
      'paragraph_index': 0,
      'start_offset': 0,
      'end_offset': 3,
      'selected_text': 'abc',
      'color_code': '#F2E58A',
    };

void main() {
  late Database db;
  late DatabaseService service;

  setUp(() async {
    db = await _openDb();
    service = DatabaseService.withDatabase(db);
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> row(String id) async =>
      (await db.query('books', where: 'id = ?', whereArgs: [id])).single;
  Future<int> hlCount(String bookId) async => (await db.query('highlights',
          where: 'book_id = ?', whereArgs: [bookId]))
      .length;

  test('signature match restores progress and highlights', () async {
    await _insertBook(db, 'a', sig: 'S1', lastReadAt: 1000);
    final r = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(r.written, 1);
    expect((await row('a'))['current_progress'], 0.9);
    expect(await hlCount('a'), 1);
  });

  test('signed backup book with no signature match skips same-titled book',
      () async {
    await _insertBook(db, 'a', sig: 'OTHER', progress: 0.1, lastReadAt: 1000);
    final r = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(r.written, 0);
    expect((r.matched, r.unmatched), (0, 1));
    expect((await row('a'))['current_progress'], 0.1);
    expect(await hlCount('a'), 0);
  });

  test('unsigned backup book matches a unique unsigned local title', () async {
    await _insertBook(db, 'a', lastReadAt: 1000);
    final r = await service.restoreDataBatch({
      'books': [_backupBook(highlights: [_hl('h1')])]
    });
    expect(r.written, 1);
    expect(await hlCount('a'), 1);
  });

  test('signed backup book matches a unique unsigned local title', () async {
    // Local signature backfill pending or failed: the title is the only link.
    await _insertBook(db, 'a', lastReadAt: 1000);
    final r = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(r.written, 1);
    expect((await row('a'))['current_progress'], 0.9);
    expect(await hlCount('a'), 1);
  });

  test('signed backup book skips ambiguous unsigned local titles', () async {
    await _insertBook(db, 'a');
    await _insertBook(db, 'b');
    final r = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(r.written, 0);
    expect(await hlCount('a') + await hlCount('b'), 0);
  });

  test('unsigned backup book skips an ambiguous local title', () async {
    await _insertBook(db, 'a');
    await _insertBook(db, 'b');
    final r = await service.restoreDataBatch({
      'books': [_backupBook(highlights: [_hl('h1')])]
    });
    expect(r.written, 0);
    expect(await hlCount('a') + await hlCount('b'), 0);
  });

  test('unsigned backup book does not match a signed local book', () async {
    await _insertBook(db, 'a', sig: 'S1');
    final r = await service.restoreDataBatch({
      'books': [_backupBook()]
    });
    expect(r.written, 0);
  });

  test('one local book is matched at most once per restore', () async {
    await _insertBook(db, 'a');
    final r = await service.restoreDataBatch({
      'books': [
        _backupBook(progress: 0.3, highlights: [_hl('h1')]),
        _backupBook(progress: 0.8, highlights: [_hl('h2')]),
      ]
    });
    expect(r.written, 1);
    // The duplicate entry has a local book (already used): not "missing".
    expect((r.matched, r.unmatched), (1, 0));
    expect(await hlCount('a'), 1);
  });

  test('duplicate same-signature backup entries match once, none unmatched',
      () async {
    await _insertBook(db, 'a', sig: 'S1', lastReadAt: 1000);
    final r = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1'), _backupBook(sig: 'S1')]
    });
    expect((r.matched, r.written, r.unmatched), (1, 1, 0));
  });

  test('backup without a books list reports nothing matched or unmatched',
      () async {
    await _insertBook(db, 'a', sig: 'S1');
    final r = await service.restoreDataBatch({'version': 1});
    expect((r.matched, r.written, r.unmatched), (0, 0, 0));
  });

  group('is_private (tighten only)', () {
    Future<Object?> privateAfter({required int local, int? backup}) async {
      await _insertBook(db, 'a',
          sig: 'S1', lastReadAt: 3000, isPrivate: local);
      await service.restoreDataBatch({
        'books': [_backupBook(sig: 'S1', lastReadAt: 2000, isPrivate: backup)]
      });
      return (await row('a'))['is_private'];
    }

    test('backup private makes a public local book private', () async {
      await _insertBook(db, 'a', sig: 'S1', lastReadAt: 3000);
      final r = await service.restoreDataBatch({
        'books': [_backupBook(sig: 'S1', lastReadAt: 2000, isPrivate: 1)]
      });
      expect((await row('a'))['is_private'], 1);
      // Local progress is newer, so the privacy change is the only write.
      expect((r.matched, r.written, r.movedToPrivate), (1, 1, 1));
      expect((await row('a'))['last_read_at'], 3000);
    });

    test('backup public never exposes a private local book', () async {
      expect(await privateAfter(local: 1, backup: 0), 1);
    });
    test('backup without the field leaves a private book private', () async {
      expect(await privateAfter(local: 1), 1);
    });
    test('backup without the field leaves a public book public', () async {
      expect(await privateAfter(local: 0), 0);
    });
    test('already private local book is not counted as written', () async {
      await _insertBook(db, 'a', sig: 'S1', lastReadAt: 3000, isPrivate: 1);
      final r = await service.restoreDataBatch({
        'books': [_backupBook(sig: 'S1', lastReadAt: 2000, isPrivate: 1)]
      });
      expect((r.matched, r.written, r.movedToPrivate), (1, 0, 0));
    });
  });

  test('matched and unmatched are counted across a mixed backup', () async {
    await _insertBook(db, 'a', sig: 'S1', progress: 0.1, lastReadAt: 3000);
    final r = await service.restoreDataBatch({
      'books': [
        _backupBook(sig: 'S1'), // matched, local newer, nothing to write
        _backupBook(title: 'Gone', sig: 'S2'),
        _backupBook(title: 'Gone Too', sig: 'S3'),
      ]
    });
    expect((r.matched, r.written, r.unmatched), (1, 0, 2));
  });

  group('progress overwrite', () {
    Future<Object?> restoredProgress(
        {int? local, int? backup, double localProgress = 0.1}) async {
      await _insertBook(db, 'a',
          sig: 'S1', progress: localProgress, lastReadAt: local);
      await service.restoreDataBatch({
        'books': [_backupBook(sig: 'S1', lastReadAt: backup)]
      });
      return (await row('a'))['current_progress'];
    }

    test('newer backup overwrites', () async {
      expect(await restoredProgress(local: 1000, backup: 2000), 0.9);
    });
    test('older backup keeps local', () async {
      expect(await restoredProgress(local: 3000, backup: 2000), 0.1);
    });
    test('equal timestamps keep local', () async {
      expect(await restoredProgress(local: 2000, backup: 2000), 0.1);
    });
    test('never-opened local takes backup', () async {
      expect(await restoredProgress(local: null, backup: 2000), 0.9);
    });
    test('backup without timestamp keeps local', () async {
      expect(await restoredProgress(local: 1000, backup: null), 0.1);
    });

    test('matched book with nothing written is not counted', () async {
      await _insertBook(db, 'a', sig: 'S1', progress: 0.1, lastReadAt: 3000);
      final r = await service.restoreDataBatch({
        'books': [_backupBook(sig: 'S1')]
      });
      expect(r.written, 0);
    });

    test('highlights still restore when progress is kept', () async {
      await _insertBook(db, 'a', sig: 'S1', progress: 0.1, lastReadAt: 3000);
      await service.restoreDataBatch({
        'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
      });
      expect((await row('a'))['current_progress'], 0.1);
      expect(await hlCount('a'), 1);
    });
  });
}
