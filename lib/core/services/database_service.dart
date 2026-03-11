import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:path_provider/path_provider.dart';
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
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureHighlightColumns(db);
    await _ensureBookColumns(db);
    final appDocsDir = await getApplicationDocumentsDirectory();
    await _backfillBookStorageTypes(db, appDocsDir.path);
    return db;
  }

  Future<void> _ensureHighlightColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(highlights)');
    final columnNames = columns
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();

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
    final columnNames = columns
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();

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
  }


  Future<void> _backfillBookStorageTypes(Database db, String appDocsPath) async {
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
      // Avoid openReadOnlyDatabase here because WAL files may be missed.
      // Open a dedicated writable connection, force a WAL checkpoint, then verify integrity.
      final db = await openDatabase(mainDbPath, singleInstance: false);
      final result = await db.rawQuery('PRAGMA integrity_check;');
      await db.close();

      final status = result.first.values.first as String;
      if (status.toLowerCase() != 'ok') {
        debugPrint(
            '--- [DatabaseService] integrity_check failed: PRAGMA integrity_check = $status ---');
        throw Exception('Database corrupted');
      } else {
        debugPrint('--- [DatabaseService] 涓诲簱瀹屾暣鎬ф牎楠岄€氳繃 (ok) ---');
      }
    } catch (e) {
      debugPrint('--- [DatabaseService] Database self-heal triggered. Recovery reason: $e ---');
      await _restoreFromLatestBackup(mainDbPath);
    }
  }

  Future<void> _restoreFromLatestBackup(String mainDbPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final backupDir = Directory(join(dbPath, 'backups'));

      if (!backupDir.existsSync()) {
        debugPrint('--- [DatabaseService] 鐮撮槻锛氭棤鍙敤鍐峰鐩綍锛屾斁寮冪枟鎰堬紒 ---');
        return;
      }

      final snapshotDirs = backupDir.listSync().whereType<Directory>().toList();
      snapshotDirs.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified)); // 浠庢柊鍒版棫

      if (snapshotDirs.isEmpty) {
        debugPrint('--- [DatabaseService] 鐮撮槻锛氭棤鍙敤鍐峰蹇収锛屾斁寮冪枟鎰堬紒 ---');
        return;
      }

      final latestBackupDir = snapshotDirs.first;
      debugPrint(
          '--- [DatabaseService] Captured latest cold backup ${latestBackupDir.path}, restoring main database snapshot ---');

      // Two-step restore: archive the corrupted main files first, then replace with the latest backup set.
      final corruptFile = File(mainDbPath);
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (corruptFile.existsSync()) {
        corruptFile.renameSync('${mainDbPath}_corrupted_$ts.bak');
      }

      final oldWal = File('$mainDbPath-wal');
      final oldShm = File('$mainDbPath-shm');
      if (oldWal.existsSync()) oldWal.deleteSync();
      if (oldShm.existsSync()) oldShm.deleteSync();

      // Restore every database file from the snapshot directory.
      final backupDb = File(join(latestBackupDir.path, 'nyan_read.db'));
      final backupWal = File(join(latestBackupDir.path, 'nyan_read.db-wal'));
      final backupShm = File(join(latestBackupDir.path, 'nyan_read.db-shm'));

      if (backupDb.existsSync()) backupDb.copySync(mainDbPath);
      if (backupWal.existsSync()) backupWal.copySync('$mainDbPath-wal');
      if (backupShm.existsSync()) backupShm.copySync('$mainDbPath-shm');

      debugPrint('--- [DatabaseService] Cold backup restore completed successfully ---');
    } catch (e, stack) {
      debugPrint('--- [DatabaseService] Catastrophic recovery failed - $e\n$stack ---');
    }
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
    await db.insert('books', bookData,
        conflictAlgorithm: ConflictAlgorithm.replace);
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
        columns: ['id', 'file_path', 'source_type', 'content_signature', 'storage_type'],
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
    await db.update(
      'books',
      data,
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

  /// Batch restore entry point v2: logical metadata sync by title.
  ///
  /// Core contract:
  ///   - Never INSERT a new book here; only UPDATE metadata for existing local books.
  ///   - Match by title as the logical key to avoid duplicate books caused by UUID splits.
  ///   - Rebind matched highlights/bookmarks to the local UUID before upsert.
  Future<int> restoreDataBatch(Map<String, dynamic> parsedJson) async {
    final db = await database;

    // 1. Build a local title -> UUID index for O(1) lookup.
    final localBooksRaw = await db.query('books', columns: ['id', 'title']);
    final Map<String, String> localBooksMap = {
      for (final row in localBooksRaw)
        (row['title'] as String): (row['id'] as String)
    };

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

    final books = (parsedJson['books'] as List?) ?? [];
    for (final book in books) {
      if (book is! Map<String, dynamic>) continue;

      final title = book['title'] as String?;
      if (title == null) continue;

      // 2. Skip unmatched books; never insert a new local book during restore.
      final localBookId = localBooksMap[title];
      if (localBookId == null) {
        debugPrint('--- [Restore] Skip book with no local match: "$title" ---');
        continue;
      }

      debugPrint('--- [Restore] Matched local book: "$title" -> $localBookId ---');

      // 3. Only update progress metadata; never rewrite id or file_path.
      final progressUpdate = <String, dynamic>{};
      if (book['current_progress'] != null)
        progressUpdate['current_progress'] = book['current_progress'];
      if (book['last_position_type'] != null)
        progressUpdate['last_position_type'] = book['last_position_type'];
      if (book['last_position_payload'] != null)
        progressUpdate['last_position_payload'] = book['last_position_payload'];
      if (book['last_read_at'] != null)
        progressUpdate['last_read_at'] = book['last_read_at'];

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
    debugPrint('--- [DatabaseService] Logical restore finished: $syncedBookCount books synced into local assets ---');
    return syncedBookCount;
  }
}









