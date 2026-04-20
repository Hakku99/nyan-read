/// Tests for the critical Phase-1 database fixes:
///   1. Hot-path indexes are created by _ensureHotIndexes.
///   2. insertBook uses ConflictAlgorithm.abort → duplicate insert fails.
///   3. ON DELETE CASCADE does NOT fire after the duplicate insert fails,
///      so existing highlights and bookmarks are preserved.
///
/// We exercise the raw SQL directly via sqflite_common_ffi in-memory
/// databases to keep the test hermetic (no path_provider, no device disk).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

// ---------------------------------------------------------------------------
// Schema helpers – mirrors DatabaseService._onCreate and _ensureHotIndexes
// ---------------------------------------------------------------------------

Future<Database> _openFreshDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => _createSchema(db),
    ),
  );
  return db;
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE books (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      author TEXT,
      file_path TEXT NOT NULL,
      source_type TEXT NOT NULL DEFAULT 'file_path',
      cover_path TEXT,
      format TEXT NOT NULL,
      is_private INTEGER DEFAULT 0,
      total_pages INTEGER,
      current_progress REAL DEFAULT 0,
      last_read_at INTEGER,
      added_at INTEGER,
      last_position_type TEXT,
      last_position_payload TEXT,
      content_signature TEXT,
      storage_type TEXT NOT NULL DEFAULT 'external_path'
    )
  ''');

  await db.execute('''
    CREATE TABLE bookmarks (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      page_index INTEGER NOT NULL,
      cfi TEXT,
      content_snippet TEXT,
      note TEXT,
      created_at INTEGER,
      color_code TEXT,
      position_type TEXT,
      position_payload TEXT,
      FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE highlights (
      id TEXT PRIMARY KEY,
      book_id TEXT NOT NULL,
      paragraph_index INTEGER NOT NULL,
      start_offset INTEGER NOT NULL,
      end_offset INTEGER NOT NULL,
      selected_text TEXT NOT NULL,
      color_code TEXT NOT NULL,
      note TEXT,
      created_at INTEGER,
      updated_at INTEGER,
      pre_context TEXT DEFAULT '',
      post_context TEXT DEFAULT '',
      is_healed INTEGER DEFAULT 0,
      FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
    )
  ''');
}

/// Exact SQL from DatabaseService._ensureHotIndexes
Future<void> _ensureHotIndexes(Database db) async {
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_highlights_book ON highlights(book_id, paragraph_index, start_offset)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks(book_id, page_index)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_books_privacy_last_read ON books(is_private, last_read_at)');
}

Map<String, dynamic> _bookRow(String id) => {
      'id': id,
      'title': 'Test Book',
      'author': 'Author',
      'file_path': '/test/$id.txt',
      'format': 'txt',
    };

Map<String, dynamic> _highlightRow(String id, String bookId) => {
      'id': id,
      'book_id': bookId,
      'paragraph_index': 0,
      'start_offset': 0,
      'end_offset': 5,
      'selected_text': 'Hello',
      'color_code': '#FF0000',
    };

Map<String, dynamic> _bookmarkRow(String id, String bookId) => {
      'id': id,
      'book_id': bookId,
      'page_index': 1,
    };

// ---------------------------------------------------------------------------

void main() {
  group('DatabaseService – Phase 1 fixes', () {
    late Database db;

    setUp(() async {
      db = await _openFreshDb();
    });

    tearDown(() async {
      await db.close();
    });

    // -----------------------------------------------------------------------
    // 1. Hot-path indexes
    // -----------------------------------------------------------------------

    test('_ensureHotIndexes creates all three hot-path indexes', () async {
      await _ensureHotIndexes(db);

      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
      );
      final names = rows.map((r) => r['name'] as String).toSet();

      expect(names, contains('idx_highlights_book'));
      expect(names, contains('idx_bookmarks_book'));
      expect(names, contains('idx_books_privacy_last_read'));
    });

    test('_ensureHotIndexes is idempotent (IF NOT EXISTS)', () async {
      // Running twice must not throw.
      await _ensureHotIndexes(db);
      await expectLater(_ensureHotIndexes(db), completes);
    });

    test('idx_highlights_book covers the three declared columns', () async {
      await _ensureHotIndexes(db);

      final rows = await db.rawQuery(
        "PRAGMA index_info('idx_highlights_book')",
      );
      final cols = rows.map((r) => r['name'] as String).toSet();

      expect(cols, containsAll(['book_id', 'paragraph_index', 'start_offset']));
    });

    // -----------------------------------------------------------------------
    // 2. insertBook uses ConflictAlgorithm.abort
    // -----------------------------------------------------------------------

    test('duplicate insertBook throws and does not silently succeed', () async {
      await db.insert('books', _bookRow('book-1'));

      // Second insert with the same primary key must fail.
      await expectLater(
        db.insert('books', _bookRow('book-1'),
            conflictAlgorithm: ConflictAlgorithm.abort),
        throwsA(isA<DatabaseException>()),
      );
    });

    // -----------------------------------------------------------------------
    // 3. Highlights survive a failed duplicate book insert (CASCADE guard)
    // -----------------------------------------------------------------------

    test(
        'highlights are NOT deleted when a duplicate insertBook fails '
        '(abort vs replace regression)', () async {
      // Insert the original book and attach a highlight + bookmark.
      await db.insert('books', _bookRow('book-2'));
      await db.insert('highlights', _highlightRow('hl-1', 'book-2'));
      await db.insert('bookmarks', _bookmarkRow('bm-1', 'book-2'));

      // Attempt a duplicate insert with abort (our fixed behaviour).
      // This must fail with an exception.
      await expectLater(
        db.insert('books', _bookRow('book-2'),
            conflictAlgorithm: ConflictAlgorithm.abort),
        throwsA(isA<DatabaseException>()),
      );

      // Critical: highlights must still be there.
      final highlights = await db.query(
        'highlights',
        where: 'book_id = ?',
        whereArgs: ['book-2'],
      );
      expect(highlights, hasLength(1),
          reason: 'Highlight must survive the failed duplicate book insert');

      // Critical: bookmarks must still be there.
      final bookmarks = await db.query(
        'bookmarks',
        where: 'book_id = ?',
        whereArgs: ['book-2'],
      );
      expect(bookmarks, hasLength(1),
          reason: 'Bookmark must survive the failed duplicate book insert');
    });

    test(
        'REPLACE would have deleted highlights – confirms the old bug '
        '(regression canary)', () async {
      // This test documents the OLD (broken) behaviour: REPLACE fires DELETE
      // on the old row → ON DELETE CASCADE wipes highlights.
      // We keep it as a canary so we never accidentally regress.
      await db.insert('books', _bookRow('book-3'));
      await db.insert('highlights', _highlightRow('hl-2', 'book-3'));

      // REPLACE would succeed but silently nuke the highlight via CASCADE.
      await db.insert('books', _bookRow('book-3'),
          conflictAlgorithm: ConflictAlgorithm.replace);

      final highlights = await db.query(
        'highlights',
        where: 'book_id = ?',
        whereArgs: ['book-3'],
      );
      // With REPLACE, highlights are gone – the old bug.
      expect(highlights, isEmpty,
          reason:
              'REPLACE triggers CASCADE delete: this is why we switched to abort');
    });
  });
}
