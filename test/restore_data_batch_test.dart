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
            content_signature TEXT)''');
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
}) =>
    db.insert('books', {
      'id': id,
      'title': title,
      'file_path': '/$id.txt',
      'format': 'txt',
      'content_signature': sig,
      'current_progress': progress,
      'last_read_at': lastReadAt,
    });

Map<String, dynamic> _backupBook({
  String title = 'Same Title',
  String? sig,
  double progress = 0.9,
  int? lastReadAt = 2000,
  List<Map<String, dynamic>> highlights = const [],
}) =>
    {
      'title': title,
      'content_signature': sig,
      'current_progress': progress,
      'last_read_at': lastReadAt,
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
    final n = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(n, 1);
    expect((await row('a'))['current_progress'], 0.9);
    expect(await hlCount('a'), 1);
  });

  test('signed backup book with no signature match skips same-titled book',
      () async {
    await _insertBook(db, 'a', sig: 'OTHER', progress: 0.1, lastReadAt: 1000);
    final n = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(n, 0);
    expect((await row('a'))['current_progress'], 0.1);
    expect(await hlCount('a'), 0);
  });

  test('unsigned backup book matches a unique unsigned local title', () async {
    await _insertBook(db, 'a', lastReadAt: 1000);
    final n = await service.restoreDataBatch({
      'books': [_backupBook(highlights: [_hl('h1')])]
    });
    expect(n, 1);
    expect(await hlCount('a'), 1);
  });

  test('signed backup book matches a unique unsigned local title', () async {
    // Local signature backfill pending or failed: the title is the only link.
    await _insertBook(db, 'a', lastReadAt: 1000);
    final n = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(n, 1);
    expect((await row('a'))['current_progress'], 0.9);
    expect(await hlCount('a'), 1);
  });

  test('signed backup book skips ambiguous unsigned local titles', () async {
    await _insertBook(db, 'a');
    await _insertBook(db, 'b');
    final n = await service.restoreDataBatch({
      'books': [_backupBook(sig: 'S1', highlights: [_hl('h1')])]
    });
    expect(n, 0);
    expect(await hlCount('a') + await hlCount('b'), 0);
  });

  test('unsigned backup book skips an ambiguous local title', () async {
    await _insertBook(db, 'a');
    await _insertBook(db, 'b');
    final n = await service.restoreDataBatch({
      'books': [_backupBook(highlights: [_hl('h1')])]
    });
    expect(n, 0);
    expect(await hlCount('a') + await hlCount('b'), 0);
  });

  test('unsigned backup book does not match a signed local book', () async {
    await _insertBook(db, 'a', sig: 'S1');
    final n = await service.restoreDataBatch({
      'books': [_backupBook()]
    });
    expect(n, 0);
  });

  test('one local book is matched at most once per restore', () async {
    await _insertBook(db, 'a');
    final n = await service.restoreDataBatch({
      'books': [
        _backupBook(progress: 0.3, highlights: [_hl('h1')]),
        _backupBook(progress: 0.8, highlights: [_hl('h2')]),
      ]
    });
    expect(n, 1);
    expect(await hlCount('a'), 1);
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
