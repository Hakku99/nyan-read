import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/modules/reader/controllers/content_meta_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

const _fox = 'the quick brown FOX jumps over the lazy dog';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late ContentMetaManager manager;

  Future<void> insert(String id, int paragraph, String text, String pre,
      String post) async {
    await db.insert('highlights', {
      'id': id,
      'book_id': 'b',
      'paragraph_index': paragraph,
      'start_offset': 0,
      'end_offset': text.length,
      'selected_text': text,
      'color_code': '#FFFF00',
      'created_at': 1,
      'pre_context': pre,
      'post_context': post,
    });
  }

  setUp(() async {
    db = await _openDb();
    addTearDown(() => db.close());

    final dir = await Directory.systemTemp.createTemp('nyan_heal');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/sample.txt');
    await file.writeAsString([
      'alpha line zero',
      'He said hello to them',
      'I said no more.',
      'delta line three',
      _fox,
    ].join('\n'));
    final book = Book(
        id: 'b', title: 'T', author: 'A', filePath: file.path, format: 'txt');
    final engine = TxtReaderEngine(book);
    await engine.initialize();
    addTearDown(engine.dispose);
    manager = ContentMetaManager(
      engine: engine,
      book: book,
      databaseService: _MemoryDatabaseService(db),
      onMetaChanged: () {},
    );
  });

  test('heals a highlight stored on a neighbouring paragraph and persists it',
      () async {
    // Stored two paragraphs early, as after an enumeration shift.
    await insert('h1', 2, 'FOX', 'the quick brown ', ' jumps over');

    await manager.loadHighlights();

    final healed = manager.findHighlightById('h1')!;
    expect(healed.paragraphIndex, 4);
    expect(healed.startOffset, _fox.indexOf('FOX'));
    expect(healed.endOffset, _fox.indexOf('FOX') + 3);
    expect(healed.isHealed, 1);

    // The write-back is fire-and-forget; wait for it.
    Map<String, Object?>? row;
    for (var i = 0; i < 40; i++) {
      row = (await db.query('highlights')).single;
      if (row['paragraph_index'] == 4) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(row!['paragraph_index'], 4);
    expect(row['start_offset'], _fox.indexOf('FOX'));
    expect(row['is_healed'], 1);
  });

  test('a highlight whose text is nowhere nearby is dropped from rendering '
      'but kept in the database', () async {
    await insert('h2', 1, 'MISSING', 'not in the ', ' book at all');

    await manager.loadHighlights();

    expect(manager.findHighlightById('h2'), isNull);
    final row = (await db.query('highlights')).single;
    expect(row['paragraph_index'], 1);
    expect(row['is_healed'], 0);
  });

  test('a still-valid highlight is untouched', () async {
    await db.insert('highlights', {
      'id': 'h3',
      'book_id': 'b',
      'paragraph_index': 4,
      'start_offset': 16,
      'end_offset': 19,
      'selected_text': 'FOX',
      'color_code': '#FFFF00',
      'created_at': 1,
      'pre_context': 'the quick brown ',
      'post_context': ' jumps over',
    });

    await manager.loadHighlights();

    final h = manager.findHighlightById('h3')!;
    expect(h.paragraphIndex, 4);
    expect(h.isHealed, 0);
  });

  test('offsets that happen to select the same word on the wrong paragraph '
      'are not trusted without matching context', () async {
    // Stored on "He said hello to them" (offsets 3..7 do select "said"), but
    // the stored context belongs to "I said no more." one paragraph later.
    await db.insert('highlights', {
      'id': 'h4',
      'book_id': 'b',
      'paragraph_index': 1,
      'start_offset': 3,
      'end_offset': 7,
      'selected_text': 'said',
      'color_code': '#FFFF00',
      'created_at': 1,
      'pre_context': 'I ',
      'post_context': ' no more.',
    });

    await manager.loadHighlights();

    final h = manager.findHighlightById('h4')!;
    expect(h.paragraphIndex, 2);
    expect(h.startOffset, 2);
    expect(h.isHealed, 1);
  });

  test('a context-free row heals only to a text that is unique nearby',
      () async {
    // "delta line" occurs once (paragraph 3); stored two paragraphs early.
    await insert('h5', 1, 'delta line', '', '');
    // "line" occurs in every paragraph: ambiguous, so not rendered.
    await insert('h6', 1, 'line', '', '');

    await manager.loadHighlights();

    final healed = manager.findHighlightById('h5')!;
    expect(healed.paragraphIndex, 3);
    expect(healed.startOffset, 0);
    expect(manager.findHighlightById('h6'), isNull);
    // Dropped from rendering, never from the database.
    final rows = await db.query('highlights', where: "id = 'h6'");
    expect(rows, hasLength(1));
  });
}
