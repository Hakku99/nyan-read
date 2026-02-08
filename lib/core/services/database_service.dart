import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nyan_read.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
      ''');
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
}
