import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/title_sort_key.dart';

class DatabaseService {
  Database? _database;

  DatabaseService();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nyan_read.db');

    // Self-heal the database before opening it.
    await _checkAndHealDatabase(path);

    final db = await openDatabase(
      path,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureHighlightColumns(db);
    await _ensureBookColumns(db);
    await _ensureHotIndexes(db);
    final appDocsDir = await getApplicationDocumentsDirectory();
    await _backfillBookStorageTypes(db, appDocsDir.path);
    return db;
  }

  // Hot-path indexes defended outside of version migration as well, so older
  // corrupted installs that somehow landed at v>=9 without the indexes still
  // get them. Creating an existing index with IF NOT EXISTS is a cheap no-op.
  Future<void> _ensureHotIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_highlights_book ON highlights(book_id, paragraph_index, start_offset)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks(book_id, page_index)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_books_privacy_last_read ON books(is_private, last_read_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_books_privacy_added_at ON books(is_private, added_at)');
  }

  Future<void> _ensureHighlightColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(highlights)');
    final columnNames =
        columns.map((row) => row['name']).whereType<String>().toSet();

    if (!columnNames.contains('pre_context')) {
      await db.execute(
          'ALTER TABLE highlights ADD COLUMN pre_context TEXT DEFAULT ""');
    }
    if (!columnNames.contains('post_context')) {
      await db.execute(
          'ALTER TABLE highlights ADD COLUMN post_context TEXT DEFAULT ""');
    }
    if (!columnNames.contains('is_healed')) {
      await db.execute(
          'ALTER TABLE highlights ADD COLUMN is_healed INTEGER DEFAULT 0');
    }
  }

  Future<void> _ensureBookColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(books)');
    final columnNames =
        columns.map((row) => row['name']).whereType<String>().toSet();

    if (!columnNames.contains('content_signature')) {
      await db.execute('ALTER TABLE books ADD COLUMN content_signature TEXT');
    }
    if (!columnNames.contains('storage_type')) {
      await db.execute(
          "ALTER TABLE books ADD COLUMN storage_type TEXT DEFAULT 'external_path'");
    }
    if (!columnNames.contains('source_type')) {
      await db.execute(
          "ALTER TABLE books ADD COLUMN source_type TEXT DEFAULT 'file_path'");
    }
    if (!columnNames.contains('title_sort_key')) {
      await db.execute('ALTER TABLE books ADD COLUMN title_sort_key TEXT');
    }
    await _backfillMissingAddedAt(db);
    await _backfillMissingTitleSortKeys(db);
  }

  Future<void> _backfillMissingAddedAt(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      'UPDATE books SET added_at = ? WHERE added_at IS NULL',
      [now],
    );
  }

  Future<void> _backfillMissingTitleSortKeys(Database db) async {
    final rows = await db.query(
      'books',
      columns: ['id', 'title'],
      where: 'title_sort_key IS NULL OR title_sort_key = ?',
      whereArgs: [''],
    );
    if (rows.isEmpty) return;

    final batch = db.batch();
    for (final row in rows) {
      final id = row['id'] as String?;
      final title = row['title'] as String?;
      if (id == null || title == null) {
        continue;
      }
      batch.update(
        'books',
        {'title_sort_key': buildTitleSortKey(title)},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _backfillBookStorageTypes(
      Database db, String appDocsPath) async {
    final rows = await db.query(
      'books',
      columns: ['id', 'file_path', 'storage_type', 'source_type'],
      where: 'storage_type IS NULL OR storage_type = ?',
      whereArgs: [''],
    );
    if (rows.isEmpty) return;

    final normalizedAppDocsPath = normalize(appDocsPath).toLowerCase();
    final batch = db.batch();

    for (final row in rows) {
      final id = row['id'] as String?;
      final filePath = row['file_path'] as String?;
      final sourceType = row['source_type'] as String?;
      if (sourceType != null && sourceType != 'file_path') {
        continue;
      }
      if (id == null || id.isEmpty || filePath == null || filePath.isEmpty) {
        continue;
      }

      final normalizedFilePath = normalize(filePath).toLowerCase();
      final storageType = isWithin(normalizedAppDocsPath, normalizedFilePath)
          ? 'app_private_copy'
          : 'external_path';

      batch.update(
        'books',
        {'storage_type': storageType},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> _checkAndHealDatabase(String mainDbPath) async {
    final file = File(mainDbPath);
    if (!file.existsSync()) return;

    try {
      // sqflite's Platform Channel MUST run on the main isolate, so the
      // integrity check stays here. Phase 2 · P0-7 moves the *recovery*
      // work (rename / copy / delete of the WAL + SHM triad) into an
      // isolate so a corrupt-DB boot no longer holds the splash screen on
      // Android while we shuffle megabytes of backup files.
      //
      // We also deliberately avoid `openReadOnlyDatabase` because it skips
      // the WAL, which would hide some classes of corruption.
      final db = await openDatabase(mainDbPath, singleInstance: false);
      final result = await db.rawQuery('PRAGMA integrity_check;');
      await db.close();

      final status = result.first.values.first as String;
      if (status.toLowerCase() != 'ok') {
        debugPrint(
            '--- [DatabaseService] integrity_check failed: PRAGMA integrity_check = $status ---');
        throw Exception('Database corrupted');
      } else {
        debugPrint(
            '--- [DatabaseService] Main database integrity check passed (ok) ---');
      }
    } catch (e) {
      debugPrint(
          '--- [DatabaseService] Database self-heal triggered. Recovery reason: $e ---');
      await _restoreFromLatestBackup(mainDbPath);
    }
  }

  Future<void> _restoreFromLatestBackup(String mainDbPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final backupDirPath = join(dbPath, 'backups');

      // Phase 2 / P0-7: the whole restore is pure file-system work (no
      // sqflite channel calls), so we hand it to a helper isolate to keep
      // the boot path off the UI thread. Only primitive strings cross the
      // isolate boundary. Logs are collected and replayed on the main
      // isolate via debugPrint so they still show up in IDE consoles.
      final outcome = await Isolate.run(
        () => _runRestoreFromBackupInIsolate(
          mainDbPath: mainDbPath,
          backupDirPath: backupDirPath,
        ),
      );

      for (final line in outcome.logs) {
        debugPrint(line);
      }
    } catch (e, stack) {
      debugPrint(
          '--- [DatabaseService] Catastrophic recovery failed - $e\n$stack ---');
    }
  }

  /// Top-level-ish helper for [Isolate.run]. Runs the rename-archive-then
  /// copy-from-snapshot restore in the helper isolate. Returns a DTO
  /// instead of calling [debugPrint] directly so the output still shows up
  /// on the main isolate's logger. Static so Dart can send the closure
  /// handle across isolates without capturing this.
  static _DbRestoreOutcome _runRestoreFromBackupInIsolate({
    required String mainDbPath,
    required String backupDirPath,
  }) {
    final logs = <String>[];
    try {
      final backupDir = Directory(backupDirPath);
      if (!backupDir.existsSync()) {
        logs.add(
            '--- [DatabaseService] Self-heal aborted: no backup directory available ---');
        return _DbRestoreOutcome(logs);
      }

      final snapshotDirs = backupDir.listSync().whereType<Directory>().toList();
      // Newest snapshot first.
      snapshotDirs.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      if (snapshotDirs.isEmpty) {
        logs.add(
            '--- [DatabaseService] Self-heal aborted: no cold-backup snapshots found ---');
        return _DbRestoreOutcome(logs);
      }

      final latestBackupDir = snapshotDirs.first;
      logs.add(
          '--- [DatabaseService] Captured latest cold backup ${latestBackupDir.path}, restoring main database snapshot ---');

      // Two-step restore: archive the corrupted main files first, then
      // replace with the latest backup set. The -wal / -shm sidecars are
      // torn down first because sqlite refuses to touch a main DB whose
      // WAL header does not match.
      final corruptFile = File(mainDbPath);
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (corruptFile.existsSync()) {
        corruptFile.renameSync('${mainDbPath}_corrupted_$ts.bak');
      }

      final oldWal = File('$mainDbPath-wal');
      final oldShm = File('$mainDbPath-shm');
      if (oldWal.existsSync()) oldWal.deleteSync();
      if (oldShm.existsSync()) oldShm.deleteSync();

      final backupDb = File(join(latestBackupDir.path, 'nyan_read.db'));
      final backupWal = File(join(latestBackupDir.path, 'nyan_read.db-wal'));
      final backupShm = File(join(latestBackupDir.path, 'nyan_read.db-shm'));

      if (backupDb.existsSync()) backupDb.copySync(mainDbPath);
      if (backupWal.existsSync()) backupWal.copySync('$mainDbPath-wal');
      if (backupShm.existsSync()) backupShm.copySync('$mainDbPath-shm');

      logs.add(
          '--- [DatabaseService] Cold backup restore completed successfully ---');
    } catch (e, stack) {
      logs.add(
          '--- [DatabaseService] Cold backup restore failed in isolate: $e\n$stack ---');
    }
    return _DbRestoreOutcome(logs);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE bookmarks ADD COLUMN position_type TEXT');
      await db
          .execute('ALTER TABLE bookmarks ADD COLUMN position_payload TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE books ADD COLUMN last_position_type TEXT');
      await db
          .execute('ALTER TABLE books ADD COLUMN last_position_payload TEXT');
    }
    if (oldVersion < 4) {
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
          FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
        )
      '''); // Closing the CREATE TABLE statement
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE highlights ADD COLUMN pre_context TEXT DEFAULT ""');
      await db.execute(
          'ALTER TABLE highlights ADD COLUMN post_context TEXT DEFAULT ""');
      await db.execute(
          'ALTER TABLE highlights ADD COLUMN is_healed INTEGER DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE books ADD COLUMN content_signature TEXT');
    }
    if (oldVersion < 7) {
      await db.execute(
          "ALTER TABLE books ADD COLUMN storage_type TEXT DEFAULT 'external_path'");
    }
    if (oldVersion < 8) {
      await db.execute(
          "ALTER TABLE books ADD COLUMN source_type TEXT DEFAULT 'file_path'");
    }
    if (oldVersion < 9) {
      // Hot-path indexes: highlights/bookmarks were doing full table scans on
      // every chapter switch on large libraries, and the bookshelf query
      // filters by (is_private, last_read_at).
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_highlights_book ON highlights(book_id, paragraph_index, start_offset)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks(book_id, page_index)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_books_privacy_last_read ON books(is_private, last_read_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_books_privacy_added_at ON books(is_private, added_at)');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Books Table
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        file_path TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'file_path',
        cover_path TEXT,
        format TEXT NOT NULL,
        title_sort_key TEXT,
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

    // 2. Bookmarks Table
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

    // 3. Stats Table
    await db.execute('''
      CREATE TABLE reading_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_str TEXT NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        books_opened INTEGER DEFAULT 0
      )
    ''');

    // 4. Highlights Table
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

  // --- CRUD Helpers (Base) ---

  Future<void> insertBook(Map<String, dynamic> bookData) async {
    final db = await database;
    final payload = Map<String, dynamic>.from(bookData);
    payload['added_at'] ??= DateTime.now().millisecondsSinceEpoch;
    final title = payload['title'] as String?;
    if (title != null && title.isNotEmpty) {
      payload['title_sort_key'] ??= buildTitleSortKey(title);
    }
    // Deliberately NOT using ConflictAlgorithm.replace: REPLACE on a books
    // row fires the FK ON DELETE CASCADE path and silently deletes every
    // highlight and bookmark the user ever made for that book.  The import
    // pipeline already de-duplicates via BookImportFingerprint, so a real
    // duplicate here is a bug and we want it to be loud, not destructive.
    await db.insert('books', payload,
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Map<String, dynamic>>> getBooks({
    bool isPrivate = false,
    String orderBy = 'last_read_at DESC',
  }) async {
    final db = await database;
    // 0 = false, 1 = true
    return await db.query(
      'books',
      where: 'is_private = ?',
      whereArgs: [isPrivate ? 1 : 0],
      orderBy: orderBy,
    );
  }

  Future<List<Map<String, dynamic>>> getBookImportEntries() async {
    final db = await database;
    return await db.query(
      'books',
      columns: [
        'id',
        'file_path',
        'source_type',
        'content_signature',
        'storage_type'
      ],
    );
  }

  Future<void> updateBookContentSignature(
      String bookId, String contentSignature) async {
    final db = await database;
    await db.update(
      'books',
      {'content_signature': contentSignature},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<Set<String>> getAllBookFilenames() async {
    final db = await database;
    final results = await db.query(
      'books',
      columns: ['file_path'],
    );

    return results.map((row) => basename(row['file_path'] as String)).toSet();
  }

  Future<Map<String, dynamic>?> getBookById(String bookId) async {
    final db = await database;
    final results = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    return results.isEmpty ? null : results.first;
  }

  @Deprecated(
    'Use deleteBooksWithAssociatedData or the bookshelf delete flow instead.',
  )
  Future<void> deleteBook(String bookId) async {
    await deleteBooksWithAssociatedData([bookId]);
  }

  @Deprecated(
    'Use deleteBooksWithAssociatedData or the bookshelf delete flow instead.',
  )
  Future<void> deleteBooks(List<String> bookIds) async {
    await deleteBooksWithAssociatedData(bookIds);
  }

  Future<void> updateBook(String bookId, Map<String, dynamic> data) async {
    final db = await database;
    final payload = Map<String, dynamic>.from(data);
    final title = payload['title'] as String?;
    if (title != null && title.isNotEmpty) {
      payload['title_sort_key'] ??= buildTitleSortKey(title);
    }
    await db.update(
      'books',
      payload,
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> updateBookPrivacy(String bookId, bool isPrivate) async {
    final db = await database;
    await db.update(
      'books',
      {'is_private': isPrivate ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // --- Bookmarks CRUD ---

  Future<void> insertBookmark(Map<String, dynamic> bookmarkData) async {
    final db = await database;
    await db.insert('bookmarks', bookmarkData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBookmark(String id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('bookmarks', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async {
    final db = await database;
    return await db.query('bookmarks',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'page_index ASC');
  }

  Future<void> deleteBookmark(String id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBookmarksForBook(String bookId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
  }

  /// Preferred safe deletion path for books and their associated metadata.
  Future<void> deleteBooksWithAssociatedData(List<String> bookIds) async {
    if (bookIds.isEmpty) return;

    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in bookIds) {
        batch.delete('bookmarks', where: 'book_id = ?', whereArgs: [id]);
        batch.delete('highlights', where: 'book_id = ?', whereArgs: [id]);
        batch.delete('books', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });
  }

  // --- Reading Position Management ---

  /// Update the last reading position for a book.
  Future<void> updateBookPosition(
      String bookId, String positionType, String positionPayload,
      {double? progress}) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'last_position_type': positionType,
      'last_position_payload': positionPayload,
      'last_read_at': DateTime.now().millisecondsSinceEpoch,
    };

    // Also update progress if provided
    if (progress != null) {
      updateData['current_progress'] = progress;
    }

    await db.update(
      'books',
      updateData,
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  /// Get the last reading position for a book.
  Future<Map<String, dynamic>?> getBookPosition(String bookId) async {
    final db = await database;
    final results = await db.query(
      'books',
      columns: ['last_position_type', 'last_position_payload'],
      where: 'id = ?',
      whereArgs: [bookId],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    if (row['last_position_type'] == null ||
        row['last_position_payload'] == null) {
      return null;
    }

    return {
      'position_type': row['last_position_type'],
      'position_payload': row['last_position_payload'],
    };
  }

  // --- Highlights CRUD ---

  Future<void> insertHighlight(Map<String, dynamic> highlightData) async {
    final db = await database;
    await db.insert('highlights', highlightData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getHighlights(String bookId) async {
    final db = await database;
    return await db.query(
      'highlights',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'paragraph_index ASC, start_offset ASC',
    );
  }

  Future<void> updateHighlight(String id,
      {String? note, String? colorCode}) async {
    final db = await database;
    final Map<String, dynamic> values = {
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (note != null) values['note'] = note;
    if (colorCode != null) values['color_code'] = colorCode;

    await db.update(
      'highlights',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteHighlight(String id) async {
    final db = await database;
    await db.delete('highlights', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteHighlightsForBook(String bookId) async {
    final db = await database;
    await db.delete('highlights', where: 'book_id = ?', whereArgs: [bookId]);
  }

  /// Fire-and-forget healed offset writeback; should not block the UI.
  Future<void> updateHighlightHealedOffset(
      String id, int newStart, int newEnd) async {
    final db = await database;
    await db.update(
      'highlights',
      {
        'start_offset': newStart,
        'end_offset': newEnd,
        'is_healed': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint(
        '--- [DatabaseService] Highlight healed offset persisted: id=$id, newStart=$newStart ---');
  }

  // --- 鍏ㄩ噺鏁版嵁瀵煎嚭鎺ュ彛 (For Global Export) ---

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await database;
    return await db.query('books');
  }

  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final db = await database;
    return await db.query('bookmarks');
  }

  Future<List<Map<String, dynamic>>> getAllHighlights() async {
    final db = await database;
    return await db.query('highlights');
  }

  /// Batch restore entry point v3: logical metadata sync by content_signature.
  ///
  /// Core contract (AGENTS.md §3.5.5):
  ///   - Never INSERT a new book here; only UPDATE metadata for existing local books.
  ///   - Primary match key is `content_signature` (SHA-256 of the source
  ///     bytes) so a user who renamed their file / retitled the book still
  ///     gets their highlights back, AND two different books that happen to
  ///     share a title (different translations of "Le Petit Prince", for
  ///     instance) no longer cross-contaminate each other's notes.
  ///   - Fallback to `title` matching **only** when the backup payload or
  ///     the local row has no signature yet (legacy data). Fallback hits
  ///     are logged with `[Restore][legacy]` so we can track migration
  ///     progress.
  ///   - Rebind matched highlights/bookmarks to the local UUID before upsert.
  Future<int> restoreDataBatch(Map<String, dynamic> parsedJson) async {
    final db = await database;

    // 1. Build TWO local indexes: the primary one keyed by content_signature,
    //    and a secondary one keyed by title for legacy fallback. Books with
    //    a null signature are only reachable via the title index.
    final localBooksRaw = await db.query(
      'books',
      columns: ['id', 'title', 'content_signature'],
    );
    final Map<String, String> localBySignature = {};
    final Map<String, String> localByTitle = {};
    for (final row in localBooksRaw) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final sig = row['content_signature'] as String?;
      if (sig != null && sig.isNotEmpty) {
        localBySignature[sig] = id;
      }
      final title = row['title'] as String?;
      if (title != null && title.isNotEmpty) {
        localByTitle[title] = id;
      }
    }

    // [Schema self-heal] Read actual child-table columns to avoid crashes on unexpected schema drift.
    Future<Set<String>> getValidColumns(String table) async {
      final pragma = await db.rawQuery('PRAGMA table_info($table)');
      return pragma.map((row) => row['name'] as String).toSet();
    }

    final validHighlightCols = await getValidColumns('highlights');
    final validBookmarkCols = await getValidColumns('bookmarks');

    Map<String, dynamic> sanitize(
            Map<String, dynamic> raw, Set<String> validCols) =>
        Map.fromEntries(raw.entries.where((e) => validCols.contains(e.key)));

    final batch = db.batch();
    int syncedBookCount = 0;
    int legacyFallbackCount = 0;

    final books = (parsedJson['books'] as List?) ?? [];
    for (final book in books) {
      if (book is! Map<String, dynamic>) continue;

      final title = book['title'] as String?;
      final signature = book['content_signature'] as String?;

      // 2. Match by content_signature first, falling back to title only if
      //    we have no signature on either side. Skip entirely if we can not
      //    identify the target row.
      String? localBookId;
      bool matchedByLegacy = false;
      if (signature != null && signature.isNotEmpty) {
        localBookId = localBySignature[signature];
      }
      if (localBookId == null && title != null && title.isNotEmpty) {
        localBookId = localByTitle[title];
        if (localBookId != null) {
          matchedByLegacy = true;
        }
      }
      if (localBookId == null) {
        final label = title ?? signature ?? '(unknown)';
        debugPrint('--- [Restore] Skip book with no local match: "$label" ---');
        continue;
      }

      if (matchedByLegacy) {
        legacyFallbackCount++;
        debugPrint(
            '--- [Restore][legacy] Title-fallback matched: "${title ?? '(no title)'}" -> $localBookId ---');
      } else {
        debugPrint(
            '--- [Restore] Signature-matched local book: "${title ?? '(no title)'}" -> $localBookId ---');
      }

      // 3. Only update progress metadata; never rewrite id or file_path.
      final progressUpdate = <String, dynamic>{};
      if (book['current_progress'] != null) {
        progressUpdate['current_progress'] = book['current_progress'];
      }
      if (book['last_position_type'] != null) {
        progressUpdate['last_position_type'] = book['last_position_type'];
      }
      if (book['last_position_payload'] != null) {
        progressUpdate['last_position_payload'] = book['last_position_payload'];
      }
      if (book['last_read_at'] != null) {
        progressUpdate['last_read_at'] = book['last_read_at'];
      }

      if (progressUpdate.isNotEmpty) {
        batch.update('books', progressUpdate,
            where: 'id = ?', whereArgs: [localBookId]);
      }

      // 4. Rebind highlights/bookmarks book_id to the local UUID before upsert.
      final highlights = (book['highlights'] as List?) ?? [];
      for (final h in highlights) {
        if (h is Map<String, dynamic>) {
          final sanitized = sanitize(
            Map<String, dynamic>.from(h)..['book_id'] = localBookId,
            validHighlightCols,
          );
          batch.insert('highlights', sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      final bookmarks = (book['bookmarks'] as List?) ?? [];
      for (final b in bookmarks) {
        if (b is Map<String, dynamic>) {
          final sanitized = sanitize(
            Map<String, dynamic>.from(b)..['book_id'] = localBookId,
            validBookmarkCols,
          );
          batch.insert('bookmarks', sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      syncedBookCount++;
    }

    // 5. noResult: true avoids returning rowIds for every row and reduces memory pressure.
    await batch.commit(noResult: true);
    if (legacyFallbackCount > 0) {
      debugPrint(
          '--- [DatabaseService] Logical restore finished: $syncedBookCount books synced (including $legacyFallbackCount legacy title fallbacks) ---');
    } else {
      debugPrint(
          '--- [DatabaseService] Logical restore finished: $syncedBookCount books synced into local assets ---');
    }
    return syncedBookCount;
  }
}

/// Isolate-safe DTO for the cold-backup restore helper.  We collect logs in
/// the helper isolate and replay them on the main isolate because
/// `debugPrint` inside an isolate does not flush to IDE consoles on every
/// platform.
class _DbRestoreOutcome {
  _DbRestoreOutcome(this.logs);
  final List<String> logs;
}
