import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
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
      await _deleteDirectoryWithRetry(tempDir);
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
        'does not start duplicate pagination for the same in-flight layout key',
        (tester) async {
      var calculationCount = 0;

      engine.dispose();
      engine = TxtReaderEngine(
        Book(
          id: 'txt-test-book',
          title: 'TXT Test',
          author: 'Tester',
          filePath: txtFile.path,
          format: 'txt',
        ),
        paginationCalculator: ({
          required String text,
          required TextStyle style,
          required double maxWidth,
          required double maxHeight,
          required EdgeInsets padding,
          TextScaler? textScaler,
          double? paragraphBottomMargin,
          int? totalTextLength,
        }) {
          calculationCount++;
          return Future<List<int>>.delayed(
            const Duration(milliseconds: 120),
            () => [107, 312],
          );
        },
      );
      await engine.initialize();
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
      ));

      await _pumpReader(tester, engine, const Size(320, 640));
      await _pumpReader(tester, engine, const Size(320, 640));

      expect(calculationCount, 1);

      await tester.pump(const Duration(milliseconds: 180));

      expect(engine.getPageCount(), 107);
    }, skip: Platform.isWindows);

    testWidgets(
        'recalculates pagination when orientation changes and preserves position',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 80));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final portraitPageCount = engine.getPageCount();

      await _pumpReader(tester, engine, const Size(640, 320));
      final landscapePosition =
          engine.getCurrentPosition() as TxtReadingPosition;

      expect(engine.getPageCount(), isNot(portraitPageCount));
      expect(landscapePosition.paragraphIndex, inInclusiveRange(75, 85));
    });

    testWidgets('next then previous restores exact viewport anchor',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.tap,
      ));
      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 64));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final start = engine.getCurrentPosition() as TxtReadingPosition;
      await engine.nextPage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await engine.previousPage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final restored = engine.getCurrentPosition() as TxtReadingPosition;
      expect(restored.paragraphIndex, start.paragraphIndex);
      expect(
        (restored.paragraphLeadingEdge ?? 0) - (start.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.08),
      );
    });

    testWidgets('restores oversized paragraph anchor from serialized position',
        // Windows CI: Isolate.run()-based pagination inside testWidgets can
        // deadlock waiting for a pump cycle that never advances — skip to avoid
        // a hang, same as the in-flight dedup test above.
        skip: Platform.isWindows,
        (tester) async {
      engine.dispose();
      final oversizedFile = File('${tempDir.path}/oversized_anchor.txt');
      final oversizedContent = [
        'CHAPTER ONE',
        // 60 repetitions ≈ 1 200 chars ≈ 60 lines at fontSize 20 / 320 px width
        // (~2 000 px tall) — clearly oversized vs. 640 px viewport, but small
        // enough that TextPainter pagination completes in < 2 s on all platforms.
        'very long paragraph ' * 60,
        'tail line',
      ].join('\n');
      await oversizedFile.writeAsString(oversizedContent);

      engine = TxtReaderEngine(
        Book(
          id: 'txt-oversized-book',
          title: 'Oversized anchor',
          author: 'Tester',
          filePath: oversizedFile.path,
          format: 'txt',
        ),
      );
      await engine.initialize();
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 20,
        lineHeight: 1.7,
        pageTurnMode: PageTurnMode.tap,
      ));

      await _pumpReader(tester, engine, const Size(320, 640));
      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await engine.nextPage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final saved = engine.getCurrentPosition() as TxtReadingPosition;
      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await engine.goToPosition(saved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final restored = engine.getCurrentPosition() as TxtReadingPosition;
      expect(restored.paragraphIndex, saved.paragraphIndex);
      expect(
        (restored.paragraphLeadingEdge ?? 0) - (saved.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.10),
      );
    });

    testWidgets('updown previousPage moves near one viewport distance',
        // Windows: upDown page-turn operations await a layout Completer that
        // requires a pump cycle — same deadlock as the oversized-anchor test.
        skip: Platform.isWindows,
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.swipe,
      ));

      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final start = engine.getCurrentPosition() as TxtReadingPosition;

      await engine.previousPage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final moved = engine.getCurrentPosition() as TxtReadingPosition;

      final delta = start.paragraphIndex - moved.paragraphIndex;
      expect(delta, greaterThanOrEqualTo(8));
    });

    testWidgets('updown previous and next keep symmetric page distance',
        skip: Platform.isWindows,
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.swipe,
      ));

      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final base = engine.getCurrentPosition() as TxtReadingPosition;

      await engine.nextPage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final afterNext = engine.getCurrentPosition() as TxtReadingPosition;
      final forwardDelta = afterNext.paragraphIndex - base.paragraphIndex;

      await engine.goToPosition(TxtReadingPosition(paragraphIndex: 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await engine.previousPage();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final afterPrevious = engine.getCurrentPosition() as TxtReadingPosition;
      final backwardDelta = base.paragraphIndex - afterPrevious.paragraphIndex;

      expect(forwardDelta, greaterThanOrEqualTo(8));
      expect(backwardDelta, greaterThanOrEqualTo(8));
      expect((forwardDelta - backwardDelta).abs(), lessThanOrEqualTo(4));
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

Future<void> _deleteDirectoryWithRetry(Directory dir) async {
  for (var i = 0; i < 6; i++) {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}
