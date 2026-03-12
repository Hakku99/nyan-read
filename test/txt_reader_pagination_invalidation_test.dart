import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TxtReaderEngine pagination invalidation', () {
    late Directory tempDir;
    late File txtFile;
    late TxtReaderEngine engine;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nyan_txt_reader_test');
      txtFile = File('${tempDir.path}/sample.txt');
      final content = List<String>.generate(
        160,
        (index) =>
            'Paragraph $index ' * 12 +
            'with enough repeated text to affect pagination.',
      ).join('\n');
      await txtFile.writeAsString(content);

      engine = TxtReaderEngine(
        Book(
          id: 'txt-test-book',
          title: 'TXT Test',
          author: 'Tester',
          filePath: txtFile.path,
          format: 'txt',
        ),
      );
      await engine.initialize();
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
      ));
    });

    tearDown(() async {
      engine.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
        'recalculates pagination when font size changes at same viewport',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      final initialPageCount = engine.getPageCount();
      expect(initialPageCount, greaterThan(1));

      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 28,
        lineHeight: 1.4,
      ));
      await _pumpReader(tester, engine, const Size(320, 640));

      expect(engine.getPageCount(), greaterThan(initialPageCount));
    });

    testWidgets(
        'recalculates pagination when line height changes at same viewport',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      final initialPageCount = engine.getPageCount();

      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 2.0,
      ));
      await _pumpReader(tester, engine, const Size(320, 640));

      expect(engine.getPageCount(), greaterThan(initialPageCount));
    });

    testWidgets(
        'recalculates pagination when viewport size changes in same orientation',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      final initialPageCount = engine.getPageCount();

      await _pumpReader(tester, engine, const Size(320, 480));

      expect(engine.getPageCount(), isNot(initialPageCount));
    });

    testWidgets(
        'recalculates pagination when orientation changes and preserves position',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 80));
      await tester.pumpAndSettle();
      final portraitPageCount = engine.getPageCount();

      await _pumpReader(tester, engine, const Size(640, 320));
      final landscapePosition =
          engine.getCurrentPosition() as TxtReadingPosition;

      expect(engine.getPageCount(), isNot(portraitPageCount));
      expect(landscapePosition.paragraphIndex, inInclusiveRange(75, 85));
    });
  });
}

Future<void> _pumpReader(
  WidgetTester tester,
  TxtReaderEngine engine,
  Size viewport,
) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: Builder(
              builder: (context) => engine.buildReader(context),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
