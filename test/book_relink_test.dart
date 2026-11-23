/// Re-linking a book whose source went unreadable when the same content is
/// imported again:
///   - stale old source + readable new source → the row is re-pointed, while
///     id, progress, highlights and is_private stay untouched;
///   - a readable old source is never replaced (sampled-signature collisions
///     must not hijack a healthy book);
///   - an unreadable new source never replaces anything;
///   - the dedup index maps signatures back to their book.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/utils/book_import_fingerprint.dart';
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
            source_type TEXT NOT NULL DEFAULT 'file_path',
            storage_type TEXT NOT NULL DEFAULT 'external_path',
            is_private INTEGER NOT NULL DEFAULT 0,
            current_progress REAL DEFAULT 0, last_read_at INTEGER,
            content_signature TEXT)''');
        await db.execute('''
          CREATE TABLE highlights (
            id TEXT PRIMARY KEY, book_id TEXT NOT NULL,
            selected_text TEXT NOT NULL,
            FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE)''');
      },
    ),
  );
}

void main() {
  late Database db;
  late DatabaseService service;
  late Directory tmp;
  late String readablePath;
  late String missingPath;

  setUp(() async {
    db = await _openDb();
    service = DatabaseService.withDatabase(db);
    tmp = await Directory.systemTemp.createTemp('relink_test');
    readablePath = '${tmp.path}${Platform.pathSeparator}new.txt';
    await File(readablePath).writeAsString('hello');
    missingPath = '${tmp.path}${Platform.pathSeparator}gone.txt';
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> insertBook(
    String id, {
    required String locator,
    String sig = 'S1',
    bool isPrivate = false,
  }) async {
    await db.insert('books', {
      'id': id,
      'title': 'T',
      'file_path': locator,
      'format': 'txt',
      'source_type': BookSourceType.androidContentUri,
      'storage_type': BookStorageType.externalPath,
      'is_private': isPrivate ? 1 : 0,
      'current_progress': 0.42,
      'content_signature': sig,
    });
    await db.insert('highlights',
        {'id': 'h-$id', 'book_id': id, 'selected_text': 'abc'});
  }

  Future<Map<String, Object?>> row(String id) async =>
      (await db.query('books', where: 'id = ?', whereArgs: [id])).single;

  Future<bool> relink(BookSourceRef existing, {String? newLocator}) =>
      BookImportFingerprint.relinkIfStale(
        service,
        existing: existing,
        newSourceType: BookSourceType.filePath,
        newSourceLocator: newLocator ?? readablePath,
        newStorageType: BookStorageType.appPrivateCopy,
      );

  BookSourceRef ref(String id, String locator, {String? type}) => BookSourceRef(
        bookId: id,
        sourceType: type ?? BookSourceType.filePath,
        sourceLocator: locator,
      );

  test('relinkBookSource rewrites only the three source columns', () async {
    await insertBook('a', locator: missingPath, isPrivate: true);
    await service.relinkBookSource(
      'a',
      locator: readablePath,
      sourceType: BookSourceType.filePath,
      storageType: BookStorageType.appPrivateCopy,
    );
    final r = await row('a');
    expect(r['file_path'], readablePath);
    expect(r['source_type'], BookSourceType.filePath);
    expect(r['storage_type'], BookStorageType.appPrivateCopy);
    expect(r['is_private'], 1);
    expect(r['current_progress'], 0.42);
    expect(r['content_signature'], 'S1');
  });

  test('stale old source + readable new source relinks, keeping progress and '
      'highlights', () async {
    await insertBook('a', locator: missingPath);
    expect(await relink(ref('a', missingPath)), isTrue);

    final r = await row('a');
    expect(r['file_path'], readablePath);
    expect(r['source_type'], BookSourceType.filePath);
    expect(r['storage_type'], BookStorageType.appPrivateCopy);
    expect(r['current_progress'], 0.42);
    expect(await db.query('highlights', where: 'book_id = ?', whereArgs: ['a']),
        hasLength(1));
    expect(await db.query('books'), hasLength(1));
  });

  test('private book stays private after relink', () async {
    await insertBook('p', locator: missingPath, isPrivate: true);
    expect(await relink(ref('p', missingPath)), isTrue);
    expect((await row('p'))['is_private'], 1);
  });

  test('readable old source is never relinked', () async {
    final other = '${tmp.path}${Platform.pathSeparator}other.txt';
    await File(other).writeAsString('other');
    await insertBook('a', locator: other);
    expect(await relink(ref('a', other)), isFalse);
    expect((await row('a'))['file_path'], other);
    expect((await row('a'))['source_type'], BookSourceType.androidContentUri);
  });

  test('unreadable new source does not relink', () async {
    await insertBook('a', locator: missingPath);
    final stillMissing = '${tmp.path}${Platform.pathSeparator}nope.txt';
    expect(await relink(ref('a', missingPath), newLocator: stillMissing),
        isFalse);
    expect((await row('a'))['file_path'], missingPath);
  });

  test('dedup index maps each signature back to its book', () async {
    await insertBook('a', locator: missingPath, sig: 'S1');
    await insertBook('b', locator: readablePath, sig: 'S2');
    final index = await BookImportFingerprint.buildExistingIndex(service);
    expect(index.signatures, {'S1', 'S2'});
    expect(index.booksBySignature['S1']!.bookId, 'a');
    expect(index.booksBySignature['S1']!.sourceLocator, missingPath);
    expect(index.booksBySignature['S2']!.bookId, 'b');
  });
}
