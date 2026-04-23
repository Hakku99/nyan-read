import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/modules/reader/controllers/content_meta_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TxtReaderEngine chapter detection', () {
    test('detects Chinese web novel and light novel variants', () async {
      final engine = await _createEngineWithContent('''
序章 开端
正文 1
第1章 初见
正文 2
第3话 xxxx yyy
正文 2.5
第2章 归途
正文 3
第4回 夜雨
正文 3.5
第5节 尾声
正文 3.8
番外篇 夏日
正文 4
卷一 破晓
正文 5
终章
''');
      addTearDown(engine.dispose);

      final chapters = await engine.getChapters();
      final titles = chapters.map((c) => c.title).toList();

      expect(
        titles,
        containsAll(<String>[
          '序章 开端',
          '第1章 初见',
          '第2章 归途',
          '第3话 xxxx yyy',
          '第4回 夜雨',
          '第5节 尾声',
          '番外篇 夏日',
          '卷一 破晓',
          '终章',
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
1 开局
Body paragraph
12 终局
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
          '1 开局',
          '12 终局',
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
序章 起点
正文 1
第1章 初遇
正文 2
正文 3
第2章 转折
正文 4
正文 5
卷一 尾声
正文 5.5
第3章 终章
正文 6
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
      databaseService: _NoopDatabaseService(),
      onMetaChanged: () {},
    );

    await metaManager.loadChapters();
    final chapters = metaManager.chapters;
    expect(chapters.map((c) => c.title), [
      '序章 起点',
      '第1章 初遇',
      '第2章 转折',
      '卷一 尾声',
      '第3章 终章',
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

class _NoopDatabaseService extends DatabaseService {}
