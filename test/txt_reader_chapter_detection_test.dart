import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/controllers/content_meta_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TxtReaderEngine chapter detection', () {
    test('detects Chinese web novel and light novel variants', () async {
      final engine = await _createEngineWithContent('''
??? ????
???? 1
?1??????
???? 2
?3?xxxx yyy
???? 2.5
?2? ??
???? 3
????4? ??
???? 3.5
????5???
???? 3.8
??????
???? 4
?? ????
???? 5
???? ??? ??
''');
      addTearDown(engine.dispose);

      final chapters = await engine.getChapters();
      final titles = chapters.map((c) => c.title).toList();

      expect(
        titles,
        containsAll(<String>[
          '??? ????',
          '?1??????',
          '?2? ??',
          '?3?xxxx yyy',
          '????4? ??',
          '????5???',
          '??????',
          '?? ????',
          '???? ??? ??',
        ]),
      );
    });

    test('detects English and Arabic-numbered chapter variants', () async {
      final engine = await _createEngineWithContent('''
Prologue
Opening paragraph
Chapter 1 The Beginning
Body paragraph
Volume 2 Chapter 7 Reunion
Body paragraph
1?xxxx
Body paragraph
12????
Body paragraph
Afterword
''');
      addTearDown(engine.dispose);

      final chapters = await engine.getChapters();
      final titles = chapters.map((c) => c.title).toList();

      expect(
        titles,
        containsAll(<String>[
          'Prologue',
          'Chapter 1 The Beginning',
          'Volume 2 Chapter 7 Reunion',
          '1?xxxx',
          '12????',
          'Afterword',
        ]),
      );
    });

    test('treats standalone numeric headings with subtitle lines as chapters', () async {
      final engine = await _createEngineWithContent('''
1
??
???? 1
2
???
???? 2
''');
      addTearDown(engine.dispose);

      final chapters = await engine.getChapters();

      expect(chapters.map((c) => c.title), ['1', '2']);
      expect(chapters.first.locator.chapterIndex, 0);
      expect(chapters.last.locator.chapterIndex, 3);
    });
  });

  test('chapter navigation buttons follow TOC order directly', () async {
    final engine = await _createEngineWithContent('''
??? ??
?? 1
?1? ??
?? 2
?? 3
?2? ??
?? 4
?? 5
??? ??
?? 5.5
?3? ??
?? 6
''');
    addTearDown(engine.dispose);

    final book = Book(
      id: 'chapter-navigation-book',
      title: 'Chapter Navigation Test',
      author: 'Tester',
      filePath: '',
      format: 'txt',
    );
    final metaManager = ContentMetaManager(
      engine: engine,
      book: book,
      onMetaChanged: () {},
    );

    await metaManager.loadChapters();
    final chapters = metaManager.chapters;
    expect(chapters.map((c) => c.title), [
      '??? ??',
      '?1? ??',
      '?2? ??',
      '??? ??',
      '?3? ??',
    ]);

    await engine.goToPosition(TxtReadingPosition(paragraphIndex: 11));
    await metaManager.syncCurrentChapterFromPosition(engine.getCurrentPosition());
    expect(metaManager.currentChapterIndex, 4);

    await metaManager.jumpToPreviousChapter(() async {});
    final afterPrevious = engine.getCurrentPosition() as TxtReadingPosition;
    expect(afterPrevious.paragraphIndex, 8);

    await metaManager.syncCurrentChapterFromPosition(engine.getCurrentPosition());
    expect(metaManager.currentChapterIndex, 3);

    await metaManager.jumpToPreviousChapter(() async {});
    final afterSecondPrevious = engine.getCurrentPosition() as TxtReadingPosition;
    expect(afterSecondPrevious.paragraphIndex, 5);
  });
}

Future<TxtReaderEngine> _createEngineWithContent(String content) async {
  final tempDir = await Directory.systemTemp.createTemp('nyan_txt_chapters');
  addTearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final txtFile = File('${tempDir.path}/sample.txt');
  await txtFile.writeAsString(content.trim());

  final engine = TxtReaderEngine(
    Book(
      id: 'txt-chapter-test',
      title: 'TXT Chapter Test',
      author: 'Tester',
      filePath: txtFile.path,
      format: 'txt',
    ),
  );
  await engine.initialize();
  return engine;
}
