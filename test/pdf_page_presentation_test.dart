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
  Completer<void>? renderGate;
  setUp(() {
    opened = Completer<Map<String, Object>>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      switch (call.method) {
        case 'open.document.file':
          return opened.future;
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

  Future<PdfReaderEngine> mount(WidgetTester tester) async {
    final engine = PdfReaderEngine(Book(
        id: 'pdf-baseline',
        title: 'PDF baseline',
        author: '',
        filePath: 'baseline.pdf',
        format: 'pdf'));
    await engine.initialize();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: engine.buildReader))));
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
