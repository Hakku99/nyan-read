import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

    // 机制 B：启动期自我疗愈 (Self-Healing)
    await _checkAndHealDatabase(path);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _checkAndHealDatabase(String mainDbPath) async {
    final file = File(mainDbPath);
    if (!file.existsSync()) return;

    try {
      // 避免使用 openReadOnlyDatabase 触发 WAL 丢失。
      // 使用单离单开读写模式强制执行 SQLite WAL Checkpoint 合并日志，再查验。
      final db = await openDatabase(mainDbPath, singleInstance: false);
      final result = await db.rawQuery('PRAGMA integrity_check;');
      await db.close();

      final status = result.first.values.first as String;
      if (status.toLowerCase() != 'ok') {
        debugPrint(
            '--- [DatabaseService] 致命破损: 主库 PRAGMA integrity_check = $status ---');
        throw Exception('Database corrupted');
      } else {
        debugPrint('--- [DatabaseService] 主库完整性校验通过 (ok) ---');
      }
    } catch (e) {
      debugPrint('--- [DatabaseService] 熔断机制激活！准备加载沙盒冷备... 异常原因: $e ---');
      await _restoreFromLatestBackup(mainDbPath);
    }
  }

  Future<void> _restoreFromLatestBackup(String mainDbPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final backupDir = Directory(join(dbPath, 'backups'));

      if (!backupDir.existsSync()) {
        debugPrint('--- [DatabaseService] 破防：无可用冷备目录，放弃疗愈！ ---');
        return;
      }

      final snapshotDirs = backupDir.listSync().whereType<Directory>().toList();
      snapshotDirs.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified)); // 从新到旧

      if (snapshotDirs.isEmpty) {
        debugPrint('--- [DatabaseService] 破防：无可用冷备快照，放弃疗愈！ ---');
        return;
      }

      final latestBackupDir = snapshotDirs.first;
      debugPrint(
          '--- [DatabaseService] 捕获最新冷备: ${latestBackupDir.path}，正在覆盖主库序列 ---');

      // 两步走：先将受损源文件归档剥离，彻底焚毁旧魂 (WAL/SHM)，再切入热备
      final corruptFile = File(mainDbPath);
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (corruptFile.existsSync()) {
        corruptFile.renameSync('${mainDbPath}_corrupted_$ts.bak');
      }

      final oldWal = File('$mainDbPath-wal');
      final oldShm = File('$mainDbPath-shm');
      if (oldWal.existsSync()) oldWal.deleteSync();
      if (oldShm.existsSync()) oldShm.deleteSync();

      // 恢复快照目录中的所有文件
      final backupDb = File(join(latestBackupDir.path, 'nyan_read.db'));
      final backupWal = File(join(latestBackupDir.path, 'nyan_read.db-wal'));
      final backupShm = File(join(latestBackupDir.path, 'nyan_read.db-shm'));

      if (backupDb.existsSync()) backupDb.copySync(mainDbPath);
      if (backupWal.existsSync()) backupWal.copySync('$mainDbPath-wal');
      if (backupShm.existsSync()) backupShm.copySync('$mainDbPath-shm');

      debugPrint('--- [DatabaseService] 冷备降落覆盖完成，即刻重新点火！ ---');
    } catch (e, stack) {
      debugPrint('--- [DatabaseService] 灾难性异常: 自愈机制执行失败 - $e\n$stack ---');
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
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Books Table
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        file_path TEXT NOT NULL,
        cover_path TEXT,
        format TEXT NOT NULL,
        is_private INTEGER DEFAULT 0,
        total_pages INTEGER,
        current_progress REAL DEFAULT 0,
        last_read_at INTEGER,
        added_at INTEGER,
        last_position_type TEXT,
        last_position_payload TEXT
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

  /// 批量插入书籍 (Batch Insert)
  /// 使用独立事务，极大提升性能并防止主线程因反复 DB Lock 而阻塞
  Future<void> batchInsertBooks(List<Map<String, dynamic>> books) async {
    if (books.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final book in books) {
      batch.insert('books', book, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 执行批处理且无需返回每一行的结果
    await batch.commit(noResult: true);
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

  Future<void> deleteBook(String bookId) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> deleteBooks(List<String> bookIds) async {
    if (bookIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in bookIds) {
      batch.delete('books', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
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

  // --- Reading Position Management ---

  /// 更新书籍的最后阅读位置
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

  /// 获取书籍的最后阅读位置
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

  /// 自愈偏移回写接口：即发即弃，不阻塞 UI (Fire-and-forget)
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
        '--- [DatabaseService] 高亮坐标自愈回写完成: id=\$id, newStart=\$newStart ---');
  }
}
