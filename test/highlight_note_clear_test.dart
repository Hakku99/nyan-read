import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/modules/reader/controllers/content_meta_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real DatabaseService logic over an in-memory db (no path_provider).
class _MemoryDatabaseService extends DatabaseService {
  _MemoryDatabaseService(this.db);
  final Database db;

  @override
  Future<Database> get database async => db;
}

Future<Database> _openDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) => db.execute('''
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
          is_healed INTEGER DEFAULT 0
        )
      '''),
    ),
  );
}

Future<String?> _storedNote(Database db, String id) async {
  final rows = await db.query('highlights', where: 'id = ?', whereArgs: [id]);
  return rows.single['note'] as String?;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseService service;

  setUp(() async {
    db = await _openDb();
    service = _MemoryDatabaseService(db);
    await db.insert('highlights', {
      'id': 'h1',
      'book_id': 'b',
      'paragraph_index': 0,
      'start_offset': 0,
      'end_offset': 5,
      'selected_text': 'Hello',
      'color_code': '#FF0000',
      'note': 'old note',
      'created_at': 1,
    });
  });

  tearDown(() => db.close());

  group('DatabaseService.updateHighlight note semantics', () {
    test('empty string clears the note to NULL', () async {
      await service.updateHighlight('h1', note: '');
      expect(await _storedNote(db, 'h1'), isNull);
    });

    test('null note (colour-only edit) keeps the existing note', () async {
      await service.updateHighlight('h1', colorCode: '#00FF00');
      expect(await _storedNote(db, 'h1'), 'old note');
      final row = (await db.query('highlights')).single;
      expect(row['color_code'], '#00FF00');
    });

    test('non-empty note replaces the stored note', () async {
      await service.updateHighlight('h1', note: 'new');
      expect(await _storedNote(db, 'h1'), 'new');
    });
  });

  group('ContentMetaManager.updateHighlight note semantics', () {
    late TxtReaderEngine engine;
    late ContentMetaManager manager;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('nyan_note_clear');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/sample.txt');
      await file.writeAsString('Hello world');
      final book = Book(
        id: 'b',
        title: 'T',
        author: 'A',
        filePath: file.path,
        format: 'txt',
      );
      engine = TxtReaderEngine(book);
      await engine.initialize();
      addTearDown(engine.dispose);
      manager = ContentMetaManager(
        engine: engine,
        book: book,
        databaseService: service,
        onMetaChanged: () {},
      );
      await manager.loadHighlights();
    });

    test('empty string clears the in-memory and stored note', () async {
      expect(manager.findHighlightById('h1')!.note, 'old note');
      await manager.updateHighlight('h1', note: '');
      expect(manager.findHighlightById('h1')!.note, isNull);
      expect(await _storedNote(db, 'h1'), isNull);
    });

    test('colour-only edit keeps the note in memory and DB', () async {
      await manager.updateHighlight('h1', colorCode: '#00FF00');
      final h = manager.findHighlightById('h1')!;
      expect(h.note, 'old note');
      expect(h.colorCode, '#00FF00');
      expect(await _storedNote(db, 'h1'), 'old note');
    });
  });
}
