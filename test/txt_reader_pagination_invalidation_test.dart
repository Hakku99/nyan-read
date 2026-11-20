import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/reader_baseline/baseline_support.dart' show perform;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TxtReaderEngine pagination invalidation', () {
    late Directory tempDir;
    late File txtFile;
    late TxtReaderEngine engine;
    ReaderConfig estimateConfig(
            {double fontSize = 16, bool useSerif = false}) =>
        ReaderConfig(
          backgroundColor: Colors.white,
          textColor: Colors.black,
          fontSize: fontSize,
          lineHeight: 1.4,
          useSerif: useSerif,
        );
    final config = estimateConfig();

    Future<List<_EstimateCall>> useControlledCalculator(
        WidgetTester tester) async {
      final calls = <_EstimateCall>[];
      final book = engine.book;
      engine.dispose();
      engine = TxtReaderEngine(book, paginationCalculator: ({
        required String text,
        required TextStyle style,
        required double maxWidth,
        required double maxHeight,
        required EdgeInsets padding,
        TextScaler? textScaler,
        double? paragraphBottomMargin,
        int? totalTextLength,
      }) {
        final call = _EstimateCall(style, textScaler!);
        calls.add(call);
        return call.result.future;
      });
      await tester.runAsync(engine.initialize);
      engine.setConfig(config);
      return calls;
    }

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
      engine.setConfig(config);
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
      final calls = await useControlledCalculator(tester);
      const viewport = Size(320, 640);
      final firstScaler = _NonlinearScaler(1.4);
      final equivalentScaler = _NonlinearScaler(1.4);
      expect(identical(firstScaler, equivalentScaler), isFalse);
      await _pumpReader(tester, engine, viewport, textScaler: firstScaler);
      await _pumpReader(tester, engine, viewport, textScaler: equivalentScaler);
      expect(calls, hasLength(1));
      calls.single.result.complete([107, 312]);
      await tester.pump();
      expect(engine.getPageCount(), 107);
      await _pumpReader(tester, engine, viewport,
          textScaler: _NonlinearScaler(1.4));
      expect(calls, hasLength(1));
    });

    testWidgets('changing the font family refreshes the mounted page count',
        (tester) async {
      final calls = await useControlledCalculator(tester);
      await _pumpReader(tester, engine, const Size(320, 640));
      expect(calls.single.style.fontFamily, NyanTypography.uiFontFamily);
      calls.single.result.complete([107, 312]);
      await tester.pump();

      engine.setConfig(estimateConfig(useSerif: true));
      await tester.pump();
      expect(calls, hasLength(2));
      expect(
          calls.last.style.fontFamily, NyanTypography.readingSerifFontFamily);
      calls.last.result.complete([123, 260]);
      await tester.pump();
      expect(engine.getPageCount(), 123);
    });

    testWidgets('compares nonlinear scaling at the estimated font size',
        (tester) async {
      final calls = await useControlledCalculator(tester);
      const viewport = Size(320, 640);
      final first = _NonlinearScaler(1.2);
      final second = _NonlinearScaler(1.6);
      expect(first.scale(1), second.scale(1));
      expect(
          first.scale(config.fontSize), isNot(second.scale(config.fontSize)));

      await _pumpReader(tester, engine, viewport, textScaler: first);
      calls.single.result.complete([107, 312]);
      await tester.pump();
      await _pumpReader(tester, engine, viewport, textScaler: second);
      expect(calls, hasLength(2));
      expect(calls.last.scaler.scale(config.fontSize),
          second.scale(config.fontSize));
      calls.last.result.complete([150, 210]);
      await tester.pump();
      expect(engine.getPageCount(), 150);
    });

    for (final aFinishesFirst in [false, true]) {
      testWidgets('A -> B -> A publishes A only (A first: $aFinishesFirst)',
          (tester) async {
        final calls = await useControlledCalculator(tester);
        await _pumpReader(tester, engine, const Size(320, 640));
        engine.setConfig(estimateConfig(fontSize: 24));
        await tester.pump();
        engine.setConfig(config);
        await tester.pump();
        expect(calls.map((call) => call.style.fontSize), [16, 24]);

        if (aFinishesFirst) {
          calls.first.result.complete([107, 312]);
          await tester.pump();
          expect(engine.getPageCount(), 107);
          calls.last.result.complete([150, 210]);
        } else {
          calls.last.result.complete([150, 210]);
          await tester.pump();
          expect(engine.getPageCount(), 1);
          calls.first.result.complete([107, 312]);
        }
        await tester.pump();
        expect(engine.getPageCount(), 107);
      });
    }

    testWidgets(
        'recalculates pagination when orientation changes and preserves position',
        (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 80)));
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
      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 64)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final start = engine.getCurrentPosition() as TxtReadingPosition;
      await perform(tester, engine.nextPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await perform(tester, engine.previousPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final restored = engine.getCurrentPosition() as TxtReadingPosition;
      expect(restored.paragraphIndex, start.paragraphIndex);
      expect(
        (restored.paragraphLeadingEdge ?? 0) -
            (start.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.08),
      );
    });

    testWidgets('restores oversized paragraph anchor from serialized position',
        // Windows CI: Isolate.run()-based pagination inside testWidgets can
        // deadlock waiting for a pump cycle that never advances — skip to avoid
        // a hang, same as the in-flight dedup test above.
        skip: Platform.isWindows, (tester) async {
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
      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await perform(tester, engine.nextPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final saved = engine.getCurrentPosition() as TxtReadingPosition;
      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await perform(tester, () => engine.goToPosition(saved));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final restored = engine.getCurrentPosition() as TxtReadingPosition;
      expect(restored.paragraphIndex, saved.paragraphIndex);
      expect(
        (restored.paragraphLeadingEdge ?? 0) -
            (saved.paragraphLeadingEdge ?? 0),
        closeTo(0, 0.10),
      );
    });

    testWidgets('updown previousPage moves near one viewport distance',
        // Windows: upDown page-turn operations await a layout Completer that
        // requires a pump cycle — same deadlock as the oversized-anchor test.
        skip: Platform.isWindows, (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.swipe,
      ));

      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 80)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final start = engine.getCurrentPosition() as TxtReadingPosition;

      await perform(tester, engine.previousPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final moved = engine.getCurrentPosition() as TxtReadingPosition;

      final delta = start.paragraphIndex - moved.paragraphIndex;
      expect(delta, greaterThanOrEqualTo(8));
    });

    testWidgets('updown previous and next keep symmetric page distance',
        skip: Platform.isWindows, (tester) async {
      await _pumpReader(tester, engine, const Size(320, 640));
      engine.setConfig(const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16,
        lineHeight: 1.4,
        pageTurnMode: PageTurnMode.swipe,
      ));

      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 80)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final base = engine.getCurrentPosition() as TxtReadingPosition;

      await perform(tester, engine.nextPage);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      final afterNext = engine.getCurrentPosition() as TxtReadingPosition;
      final forwardDelta = afterNext.paragraphIndex - base.paragraphIndex;

      await perform(tester,
          () => engine.goToPosition(TxtReadingPosition(paragraphIndex: 80)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await perform(tester, engine.previousPage);
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
  Size viewport, {
  TextScaler? textScaler,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => textScaler == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
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

class _EstimateCall {
  _EstimateCall(this.style, this.scaler);

  final TextStyle style;
  final TextScaler scaler;
  final result = Completer<List<int>>();
}

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler(this.factor);

  final double factor;

  @override
  double scale(double fontSize) =>
      fontSize <= 1 ? fontSize : 1 + (fontSize - 1) * factor;

  @override
  double get textScaleFactor => factor;
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
