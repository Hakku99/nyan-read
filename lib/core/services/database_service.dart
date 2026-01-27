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
      version: 1,
      onCreate: _onCreate,
    );
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
        added_at INTEGER
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
  }

  // --- CRUD Helpers (Base) ---

  Future<void> insertBook(Map<String, dynamic> bookData) async {
    final db = await database;
    await db.insert('books', bookData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getBooks({bool isPrivate = false}) async {
    final db = await database;
    // 0 = false, 1 = true
    return await db.query('books', where: 'is_private = ?', whereArgs: [isPrivate ? 1 : 0]);
  }

  // --- Bookmarks CRUD ---

  Future<void> insertBookmark(Map<String, dynamic> bookmarkData) async {
    final db = await database;
    await db.insert('bookmarks', bookmarkData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async {
    final db = await database;
    return await db.query('bookmarks', where: 'book_id = ?', whereArgs: [bookId], orderBy: 'page_index ASC');
  }

  Future<void> deleteBookmark(String id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
