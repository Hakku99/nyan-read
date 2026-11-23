import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 50 short lines followed by 50 long ones: line-based progress would put
  // line 50 at ~50%, character-based progress at ~5%.
  late TxtReaderEngine engine;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('nyan_txt_progress');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final file = File('${tempDir.path}/uneven.txt');
    await file.writeAsString([
      ...List.filled(50, 'a' * 10),
      ...List.filled(50, 'b' * 200),
    ].join('\n'));

    engine = TxtReaderEngine(Book(
      id: 'txt-progress-book',
      title: 'TXT Progress Test',
      author: 'Tester',
      filePath: file.path,
      format: 'txt',
    ));
    addTearDown(engine.dispose);
    await engine.initialize();
    engine.setConfig(const ReaderConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 18,
      lineHeight: 1.5,
    ));
  });

  test('progress is character-based with 0 and 1 endpoints', () async {
    expect(engine.getProgress(), 0);

    await engine.goToPosition(TxtReadingPosition(paragraphIndex: 50));
    expect(engine.getProgress()!, lessThan(0.1));

    await engine.goToPosition(TxtReadingPosition(paragraphIndex: 99));
    expect(engine.getProgress(), 1.0);
  });

  test('seekToProgress is the inverse of getProgress', () async {
    for (final p in [0.0, 0.25, 0.5, 0.9, 1.0]) {
      await engine.seekToProgress(p);
      // One long paragraph is ~2% of this book.
      expect(engine.getProgress(), closeTo(p, 0.02), reason: 'p=$p');
    }
  });
}
