import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/pdf/pdf_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // This exercises the desktop method-channel implementation of the pinned
  // pdfx version. It models document readiness, not native PDF raster speed.
  const channel = MethodChannel('io.scer.pdf_renderer');
  late Completer<Map<String, Object>> opened;
  late Completer<void> openRequested;
  PlatformException? openFailure;
  Completer<void>? renderGate;
  setUp(() {
    renderGate = null;
    openFailure = null;
    opened = Completer<Map<String, Object>>();
    openRequested = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      switch (call.method) {
        case 'open.document.file':
          openRequested.complete();
          final result = await opened.future;
          if (openFailure != null) throw openFailure!;
          return result;
        case 'open.page':
          return {
            'id': 'page-${(call.arguments as Map)['page']}',
            'width': 360,
            'height': 640
          };
        case 'render':
          await renderGate?.future;
          return {
            'width': 1,
            'height': 1,
            'data': img.encodePng(img.Image(width: 1, height: 1)),
          };
        case 'close.page':
        case 'close.document':
          return null;
        default:
          throw StateError('Unexpected PDF method: ${call.method}');
      }
    });
  });
  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  Future<PdfReaderEngine> mount(WidgetTester tester,
      {bool attach = true}) async {
    final engine = PdfReaderEngine(Book(
        id: 'pdf-baseline',
        title: 'PDF baseline',
        author: '',
        filePath: 'baseline.pdf',
        format: 'pdf'));
    await engine.initialize();
    if (attach) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Builder(builder: engine.buildReader))));
    }
    await tester.pump(const Duration(milliseconds: 180));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      engine.dispose();
      await tester.pump();
    });
    return engine;
  }

  Future<void> settleNativeWork(WidgetTester tester) async {
    // pdfx decodes pixels through a real isolate; simulated time alone cannot
    // finish that work while its loading indicator keeps requesting frames.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('The mocked PDF renderer did not become ready.');
  }

  void expectPage(PdfReaderEngine engine, int page) {
    expect(engine.getCurrentPosition()?.pageNumber, page);
    // Inspect the actual public PageController as well as the engine position.
    final pageView = find.byType(PageView).evaluate().single.widget as PageView;
    expect(pageView.controller!.page, closeTo(page - 1, 0.001));
  }

  testWidgets('PDF restore waits for delayed document and viewport',
      (tester) async {
    final engine = await mount(tester);
    var completed = false;
    final restore = engine
        .goToPosition(const ReadingPosition(pageNumber: 7))
        .then((_) => completed = true);
    await tester.pump(const Duration(seconds: 1));
    expect(completed, isFalse);
    expect(engine.getCurrentPosition(), isNull);
    opened.complete({'id': 'delayed', 'pagesCount': 25});
    await settleNativeWork(tester);
    await restore;
    expectPage(engine, 7);
  });

  testWidgets('PDF restore survives document loading before view mount',
      (tester) async {
    final engine = await mount(tester, attach: false);
    final restore = engine.goToPosition(const ReadingPosition(pageNumber: 9));
    opened.complete({'id': 'unmounted', 'pagesCount': 25});
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: engine.buildReader))));
    await settleNativeWork(tester);
    await restore;
    expectPage(engine, 9);
  });

  testWidgets('PDF latest chapter and progress supersede pending restores',
      (tester) async {
    final engine = await mount(tester);
    final first = engine.goToPosition(const ReadingPosition(pageNumber: 7));
    final chapter = engine.goToChapter(const ChapterLocator(pageNumber: 12));
    final latest = engine.seekToProgress(0.75);
    await first;
    await chapter;
    opened.complete({'id': 'latest', 'pagesCount': 25});
    await settleNativeWork(tester);
    await latest;
    expectPage(engine, 19);
    await engine.goToPosition(const ReadingPosition(pageNumber: 4));
    await settleNativeWork(tester);
    expectPage(engine, 4);
  });

  for (final target in [-20, 200]) {
    testWidgets('PDF pending restore clamps page $target', (tester) async {
      final engine = await mount(tester);
      final restore = engine.goToPosition(ReadingPosition(pageNumber: target));
      opened.complete({'id': 'boundary-$target', 'pagesCount': 25});
      await settleNativeWork(tester);
      await restore;
      expectPage(engine, target < 1 ? 1 : 25);
    });
  }

  testWidgets('PDF disposal releases pending restore without replay',
      (tester) async {
    final engine = await mount(tester);
    final restore = engine.goToPosition(const ReadingPosition(pageNumber: 7));
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
    await restore;
    opened.complete({'id': 'disposed', 'pagesCount': 25});
    await tester.pump();
    await engine.goToPosition(const ReadingPosition(pageNumber: 9));
    expect(engine.getCurrentPosition(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF repeated restore and early page turn keep latest target',
      (tester) async {
    final engine = await mount(tester);
    final first = engine.goToPosition(const ReadingPosition(pageNumber: 7));
    final repeated = engine.goToPosition(const ReadingPosition(pageNumber: 7));
    final next = engine.nextPage();
    final previous = engine.previousPage();
    await Future.wait([first, repeated, next]);
    opened.complete({'id': 'repeated', 'pagesCount': 25});
    await settleNativeWork(tester);
    await previous;
    expectPage(engine, 7);
  });

  testWidgets('PDF detached loading view cannot replay a restore',
      (tester) async {
    final engine = await mount(tester);
    final restore = engine.goToPosition(const ReadingPosition(pageNumber: 7));
    await tester.pumpWidget(const SizedBox.shrink());
    opened.complete({'id': 'reattached', 'pagesCount': 25});
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: engine.buildReader))));
    await settleNativeWork(tester);
    await restore;
    expectPage(engine, 7);
  });

  testWidgets('PDF early page turn advances queued progress target',
      (tester) async {
    final engine = await mount(tester);
    final seek = engine.seekToProgress(0.75);
    final next = engine.nextPage();
    await seek;
    opened.complete({'id': 'progress-step', 'pagesCount': 25});
    await settleNativeWork(tester);
    await next;
    expectPage(engine, 20);
  });

  testWidgets('PDF open failure rejects pending restore and shows error',
      (tester) async {
    final engine = await mount(tester);
    final restore = engine.goToPosition(const ReadingPosition(pageNumber: 7));
    final failure = expectLater(restore, throwsA(isA<PlatformException>()));
    await tester.runAsync(() => openRequested.future);
    openFailure = PlatformException(code: 'open_failed');
    opened.complete({'id': 'failed', 'pagesCount': 25});
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await failure;
    expect(find.textContaining('Failed to open PDF'), findsOneWidget);
    await expectLater(engine.goToPosition(const ReadingPosition(pageNumber: 3)),
        throwsA(isA<PlatformException>()));
  });

  for (final cancel in [false, true]) {
    testWidgets(
        'PDF presentation ${cancel ? 'cancels pending raster' : 'waits for decoded target'}',
        (tester) async {
      final engine = await mount(tester);
      opened.complete({'id': 'document', 'pagesCount': 25});
      await settleNativeWork(tester);
      renderGate = Completer<void>();
      await engine.goToPosition(const ReadingPosition(pageNumber: 7));
      await tester.pump();
      final request = PageTurnRequest();
      var completed = false;
      final ready = engine.waitForPagePresentation(request).then((value) {
        completed = true;
        return value;
      });
      final rejection =
          cancel ? expectLater(ready, throwsA(isA<PageTurnCancelled>())) : null;
      await tester.pump(const Duration(milliseconds: 100));
      expect(completed, isFalse);
      if (cancel) {
        request.cancel();
        await tester.pump();
        await rejection;
      }
      renderGate!.complete();
      renderGate = null;
      await settleNativeWork(tester);
      if (!cancel) expect(await ready, isTrue);
      expect(engine.getCurrentPosition()?.pageNumber, 7);
    });
  }
}
