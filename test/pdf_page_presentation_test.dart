import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/controllers/reader_controller.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';
import 'package:nyan_read/modules/reader/reader_engine/pdf/pdf_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

RenderRepaintBoundary _boundary(GlobalKey key) =>
    key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

Future<List<int>?> _pixel(WidgetTester tester, GlobalKey key, int x, int y) =>
    tester.runAsync(() async {
      final image = await _boundary(key).toImage();
      try {
        final bytes = (await image.toByteData())!;
        return bytes.buffer
            .asUint8List(bytes.offsetInBytes + (y * image.width + x) * 4, 4)
            .toList();
      } finally {
        image.dispose();
      }
    });

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // This exercises the desktop method-channel implementation of the pinned
  // pdfx version. It models document readiness, not native PDF raster speed.
  const channel = MethodChannel('io.scer.pdf_renderer');
  late Completer<Map<String, Object>> opened;
  late Completer<void> openRequested;
  PlatformException? openFailure;
  Completer<void>? renderGate;
  late bool renderStarted;
  setUp(() {
    renderGate = null;
    renderStarted = false;
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
          renderStarted = true;
          await renderGate?.future;
          final image = img.Image(width: 4, height: 3);
          final isTarget = (call.arguments as Map)['pageId'] == 'page-2';
          img.fill(image,
              color: isTarget
                  ? img.ColorRgb8(0, 0, 255)
                  : img.ColorRgb8(255, 0, 0));
          return {
            'width': image.width,
            'height': image.height,
            'data': img.encodePng(image),
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

  Future<ReaderController> mountTurn(
    WidgetTester tester,
    GlobalKey<SmoothPageReaderState> smooth,
    GlobalKey screen,
    GlobalKey body, {
    ValueNotifier<bool>? pendingPaint,
    bool warmTarget = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 240);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({
      'page_turn_mode': PageTurnMode.tap.index,
    });
    final preferences = ReaderPreferencesService();
    await preferences.initialize();
    final controller = ReaderController(
      Book(
          id: 'pdf-turn',
          title: 'PDF turn',
          author: '',
          filePath: 'turn.pdf',
          format: 'pdf'),
      readerPreferencesService: preferences,
      databaseService: DatabaseService(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      preferences.dispose();
      await tester.pump();
    });
    await controller.engine.initialize();
    late final ui.Image outgoing;
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: screen,
        child: SmoothPageReader(
          key: smooth,
          snapshotIncoming: false,
          duration: const Duration(milliseconds: 64),
          curve: Curves.linear,
          onPreviousTap: () {},
          onNextTap: () {},
          onCenterTap: () {},
          captureFrame: () async => outgoing,
          child: RepaintBoundary(
            key: body,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Builder(builder: controller.engine.buildReader),
                if (pendingPaint != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    width: 16,
                    height: 16,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: pendingPaint,
                      builder: (_, visible, child) =>
                          visible ? child! : const SizedBox.shrink(),
                      child: const ColoredBox(color: Color(0xFF00FF00)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
    opened.complete({'id': 'pdf-turn', 'pagesCount': 2});
    await settleNativeWork(tester);
    final engine = controller.engine as PdfReaderEngine;
    if (warmTarget) {
      await engine.goToPosition(const ReadingPosition(pageNumber: 2));
      await settleNativeWork(tester);
      await engine.goToPosition(const ReadingPosition(pageNumber: 1));
      await settleNativeWork(tester);
    }
    expectPage(engine, 1);
    outgoing = (await tester.runAsync(() => _boundary(body).toImage()))!;
    addTearDown(() {
      if (!outgoing.debugDisposed) outgoing.dispose();
    });
    if (!warmTarget) {
      renderStarted = false;
      final gate = renderGate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
    }
    return controller;
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() reached) async {
    for (var i = 0; i < 100; i++) {
      if (reached()) return;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    fail('The expected PDF turn stage was not reached.');
  }

  Future<void> checkTurn(
    WidgetTester tester,
    ReaderController controller,
    SmoothPageReaderState smooth, {
    VoidCallback? onReady,
    required Future<void> Function(PageTurnRequest, Future<void>) check,
  }) async {
    final request = PageTurnRequest();
    final turn = smooth.playTurn(
      forward: true,
      request: request,
      readyIncludesPaint: controller.pageReadinessIncludesPaint,
      didMove: () => controller.currentPosition?.pageNumber == 2,
      dispatchTurn: () => controller.nextPage(request: request),
      waitForReady: () async {
        final ready = await controller.waitForPagePresentation(request);
        if (ready) onReady?.call();
        return ready;
      },
    );
    try {
      await check(request, turn);
    } finally {
      request.cancel();
      await tester.pump();
      await turn;
    }
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

  for (final queuePaint in [false, true]) {
    testWidgets(
        'PDF painted target ${queuePaint ? 'waits for queued paint' : 'starts without an extra frame'}',
        (tester) async {
      final smooth = GlobalKey<SmoothPageReaderState>();
      final screen = GlobalKey();
      final body = GlobalKey();
      final pendingPaint = ValueNotifier(false);
      addTearDown(pendingPaint.dispose);
      final controller = await mountTurn(tester, smooth, screen, body,
          pendingPaint: pendingPaint, warmTarget: true);
      expect(await _pixel(tester, screen, 300, 120), [255, 0, 0, 255]);
      bool? scheduledAtReady;
      await checkTurn(
        tester,
        controller,
        smooth.currentState!,
        onReady: () {
          scheduledAtReady = binding.hasScheduledFrame;
          if (queuePaint) pendingPaint.value = true;
        },
        check: (_, turn) async {
          await pumpUntil(tester, () => scheduledAtReady != null);
          expect(scheduledAtReady, isFalse);
          expect(await _pixel(tester, body, 160, 120), [0, 0, 255, 255]);
          expect(binding.transientCallbackCount, queuePaint ? 0 : 1,
              reason:
                  'The animation ticker should only wait for queued paint.');
          if (queuePaint) {
            await tester.pump();
            expect(binding.transientCallbackCount, 1);
          }
          // The first tick has zero progress. The following frame exposes the
          // left quarter of the target page on the right of the viewport.
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 16));
          expect(await _pixel(tester, screen, 300, 120), [0, 0, 255, 255]);
          if (queuePaint) {
            expect(await _pixel(tester, screen, 260, 20), [0, 255, 0, 255]);
          }
          await tester.pumpAndSettle();
          await turn;
        },
      );
      expectPage(controller.engine as PdfReaderEngine, 2);
    });
  }

  for (final cancel in [false, true]) {
    testWidgets(
        'PDF turn ${cancel ? 'cancelled' : 'timed out'} during rendering keeps the committed page',
        (tester) async {
      final smooth = GlobalKey<SmoothPageReaderState>();
      final screen = GlobalKey();
      final controller = await mountTurn(tester, smooth, screen, GlobalKey());
      await checkTurn(tester, controller, smooth.currentState!,
          check: (request, turn) async {
        await pumpUntil(tester, () => renderStarted);
        expectPage(controller.engine as PdfReaderEngine, 2);
        if (cancel) request.cancel();
        await tester.pump(cancel ? Duration.zero : const Duration(seconds: 2));
        await turn;
        expect(smooth.currentState!.isAnimating, isFalse);
        expectPage(controller.engine as PdfReaderEngine, 2);
      });

      renderGate!.complete();
      await settleNativeWork(tester);
      expect(smooth.currentState!.isAnimating, isFalse);
      expectPage(controller.engine as PdfReaderEngine, 2);
      expect(await _pixel(tester, screen, 300, 120), [0, 0, 255, 255]);
    });
  }
}
