import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  _endOfBookTest();

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

    await engine.goToPosition(TxtReadingPosition(paragraphIndex: 98));
    // Rounded labels must not read "100%" while a paragraph remains.
    expect((engine.getProgress()! * 100).round(), lessThan(100));

    await engine.goToPosition(TxtReadingPosition(paragraphIndex: 99));
    expect(engine.getProgress(), 1.0);
  });

  test('seekToProgress is the inverse of getProgress', () async {
    for (final p in [0.0, 0.25, 0.5, 0.9, 1.0]) {
      await engine.seekToProgress(p);
      // Nearest paragraph start: error is at most half a long paragraph
      // (~1% of this book); a floor would allow ~2%.
      expect(engine.getProgress(), closeTo(p, 0.01), reason: 'p=$p');
    }
  });
}

void _endOfBookTest() {
  testWidgets('scrolled to the end reports 1.0 with a short last paragraph',
      (tester) async {
    final tempDir = await tester
        .runAsync(() => Directory.systemTemp.createTemp('nyan_txt_end'));
    addTearDown(() => tempDir!.delete(recursive: true));
    final file = File('${tempDir!.path}/short_tail.txt');
    // The one-word last paragraph can never scroll to the top of the viewport.
    await tester.runAsync(() =>
        file.writeAsString([...List.filled(60, 'c' * 200), 'end'].join('\n')));
    final engine = TxtReaderEngine(Book(
      id: 'txt-end-book',
      title: 'TXT End Test',
      author: 'Tester',
      filePath: file.path,
      format: 'txt',
    ));
    addTearDown(engine.dispose);
    await tester.runAsync(engine.initialize);
    engine.setConfig(const ReaderConfig(
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 18,
      lineHeight: 1.5,
    ));

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => engine.buildReader(context)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    final list = find.byType(Scrollable).first;
    // Drag until the list stops moving: its scroll limit grows as items lay out.
    for (var i = 0; i < 200; i++) {
      final position = tester.state<ScrollableState>(list).position;
      if (position.extentAfter == 0 && i > 0) break;
      await tester.drag(list, const Offset(0, -2000));
      await tester.pumpAndSettle();
    }
    expect(engine.getProgress(), 1.0);

    await tester.drag(list, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect((engine.getProgress()! * 100).round(), lessThan(100));
  });
}
