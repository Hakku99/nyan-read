import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/pdf/pdf_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

const _pdfChannel = MethodChannel('io.scer.pdf_renderer');
const _sourceChannel = MethodChannel('com.example.nyan_read/book_source');

class _PdfHarness {
  final opened = Completer<Map<String, Object>>();
  final openStarted = Completer<void>();
  final renderStarted = Completer<void>();
  final pageCloseStarted = Completer<void>();
  final documentCloseStarted = Completer<void>();
  Completer<void>? renderGate;
  Completer<void>? pageCloseGate;
  Completer<void>? documentCloseGate;
  bool failOpen = false;
  bool failClose = false;
  bool failRender = false;
  int openedPages = 0;
  int closedPages = 0;
  int documentCloses = 0;
  bool closeSawAllPagesClosed = false;
  bool openedPageAfterDocumentClose = false;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'open.document.file':
        openStarted.complete();
        final result = await opened.future;
        if (failOpen) throw PlatformException(code: 'open_failed');
        return result;
      case 'open.page':
        openedPages++;
        openedPageAfterDocumentClose |= documentCloses > 0;
        return {
          'id': 'page-${(call.arguments as Map)['page']}',
          'width': 360,
          'height': 640,
        };
      case 'render':
        if (!renderStarted.isCompleted) renderStarted.complete();
        await renderGate?.future;
        if (failRender) throw PlatformException(code: 'render_failed');
        return {
          'width': 1,
          'height': 1,
          'data': img.encodePng(img.Image(width: 1, height: 1)),
        };
      case 'close.page':
        if (!pageCloseStarted.isCompleted) pageCloseStarted.complete();
        await pageCloseGate?.future;
        closedPages++;
        return null;
      case 'close.document':
        documentCloses++;
        closeSawAllPagesClosed = openedPages == closedPages;
        if (!documentCloseStarted.isCompleted) documentCloseStarted.complete();
        await documentCloseGate?.future;
        if (failClose) throw PlatformException(code: 'close_failed');
        return null;
      default:
        throw StateError('Unexpected PDF method: ${call.method}');
    }
  }

  void finishOpen() => opened.complete({'id': 'lifecycle', 'pagesCount': 25});
}

Future<void> _flushUntil(
    WidgetTester tester, FutureOr<bool> Function() done) async {
  for (var i = 0; i < 100; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    if (await done()) return;
  }
  fail('PDF lifecycle operation did not complete.');
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _PdfHarness harness;
  late PdfReaderEngine engine;

  setUp(() {
    harness = _PdfHarness();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_pdfChannel, harness.handle);
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_pdfChannel, null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_sourceChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> mount(WidgetTester tester,
      {bool attach = true, String? temporaryPath}) async {
    if (temporaryPath != null) {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_sourceChannel,
          (call) async {
        expect(call.method, 'copyUriToTempFile');
        return temporaryPath;
      });
    }
    engine = PdfReaderEngine(Book(
      id: 'pdf-lifecycle',
      title: 'PDF lifecycle',
      author: '',
      sourceLocator:
          temporaryPath == null ? 'lifecycle.pdf' : 'content://test/pdf',
      sourceType: temporaryPath == null
          ? BookSourceType.filePath
          : BookSourceType.androidContentUri,
      format: 'pdf',
    ));
    await engine.initialize();
    if (attach) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Builder(builder: engine.buildReader))));
    }
    await _flushUntil(tester, () => harness.openStarted.isCompleted);
    debugDefaultTargetPlatformOverride = null;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      engine.dispose();
      await tester.pump();
    });
  }

  Future<void> exit(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
  }

  testWidgets('PDF normal exit closes pages before the document exactly once',
      (tester) async {
    await mount(tester);
    harness.finishOpen();
    await _flushUntil(tester, () => harness.closedPages > 0);
    expect(harness.documentCloses, 0);
    await exit(tester);
    engine.dispose();
    await _flushUntil(tester, () => harness.documentCloses == 1);
    expect(harness.closeSawAllPagesClosed, isTrue);
    expect(harness.openedPageAfterDocumentClose, isFalse);
  });

  testWidgets('PDF loading exit closes a late document without mounting it',
      (tester) async {
    await mount(tester);
    await exit(tester);
    expect(harness.documentCloses, 0);
    harness.finishOpen();
    await _flushUntil(tester, () => harness.documentCloses == 1);
    expect(harness.openedPages, 0);
    expect(engine.getCurrentPosition(), isNull);
  });

  for (final blockPageClose in [false, true]) {
    testWidgets(
        'PDF exit waits for ${blockPageClose ? 'page closure' : 'in-flight rendering'}',
        (tester) async {
      final gate = Completer<void>();
      if (blockPageClose) {
        harness.pageCloseGate = gate;
      } else {
        harness.renderGate = gate;
      }
      await mount(tester);
      harness.finishOpen();
      await _flushUntil(
          tester,
          () => blockPageClose
              ? harness.pageCloseStarted.isCompleted
              : harness.renderStarted.isCompleted);
      await exit(tester);
      await tester.pump();
      expect(harness.documentCloses, 0);
      gate.complete();
      await _flushUntil(tester, () => harness.documentCloses == 1);
      expect(harness.closeSawAllPagesClosed, isTrue);
      expect(harness.closedPages, harness.openedPages);
      expect(harness.openedPageAfterDocumentClose, isFalse);
    });
  }

  testWidgets('PDF failed open has no native document to close',
      (tester) async {
    await mount(tester, attach: false);
    harness.failOpen = true;
    harness.finishOpen();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await exit(tester);
    await tester.pump();
    expect(harness.documentCloses, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF exit drains queued page requests before document closure',
      (tester) async {
    harness.renderGate = Completer<void>();
    await mount(tester);
    harness.finishOpen();
    await _flushUntil(tester, () => harness.renderStarted.isCompleted);
    await engine.goToPosition(const ReadingPosition(pageNumber: 7));
    await tester.pump();
    final pagesBeforeExit = harness.openedPages;
    await exit(tester);
    expect(harness.documentCloses, 0);
    harness.renderGate!.complete();
    await _flushUntil(tester, () => harness.documentCloses == 1);
    expect(harness.openedPages, greaterThan(pagesBeforeExit));
    expect(harness.closeSawAllPagesClosed, isTrue);
    expect(harness.openedPageAfterDocumentClose, isFalse);
  });

  testWidgets('PDF failed open removes its temporary source after settlement',
      (tester) async {
    final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('nyan-pdf-open-failure-'));
    final source = File('${directory!.path}/source.pdf');
    await tester.runAsync(() => source.writeAsBytes([1]));
    addTearDown(() async {
      await tester.runAsync(() => directory.delete(recursive: true));
    });
    await mount(tester, attach: false, temporaryPath: source.path);
    await exit(tester);
    expect(await tester.runAsync(source.exists), isTrue);
    harness.failOpen = true;
    harness.finishOpen();
    await _flushUntil(
        tester, () async => !(await tester.runAsync(source.exists))!);
    expect(harness.documentCloses, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF failed in-flight render still closes its page and document',
      (tester) async {
    harness.renderGate = Completer<void>();
    harness.failRender = true;
    await mount(tester);
    harness.finishOpen();
    await _flushUntil(tester, () => harness.renderStarted.isCompleted);
    await exit(tester);
    expect(harness.documentCloses, 0);
    final errors = <Object>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    try {
      harness.renderGate!.complete();
      await _flushUntil(tester, () => harness.documentCloses == 1);
      await tester.pump();
    } finally {
      FlutterError.onError = previousHandler;
    }
    expect(
        errors,
        everyElement(isA<PlatformException>()
            .having((error) => error.code, 'code', 'render_failed')));
    expect(harness.closeSawAllPagesClosed, isTrue);
    expect(harness.closedPages, harness.openedPages);
  });

  for (final failClose in [false, true]) {
    testWidgets(
        'PDF temporary source ${failClose ? 'survives failed closure' : 'is deleted only after document closure'}',
        (tester) async {
      final directory = await tester.runAsync(
          () => Directory.systemTemp.createTemp('nyan-pdf-lifecycle-'));
      final source = File('${directory!.path}/source.pdf');
      await tester.runAsync(() => source.writeAsBytes([1]));
      addTearDown(() async {
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      harness.documentCloseGate = Completer<void>();
      harness.failClose = failClose;
      await mount(tester, attach: false, temporaryPath: source.path);
      await exit(tester);
      harness.finishOpen();
      await _flushUntil(tester, () => harness.documentCloseStarted.isCompleted);
      expect(await tester.runAsync(source.exists), isTrue);
      harness.documentCloseGate!.complete();
      await tester.pump();
      if (failClose) {
        Object? failure;
        await _flushUntil(tester, () {
          failure ??= tester.takeException();
          return failure != null;
        });
        expect(failure, isA<PlatformException>());
        expect(await tester.runAsync(source.exists), isTrue);
      } else {
        // File I/O completes outside the fake clock; pump between completions
        // so both the exists check and subsequent delete can resume.
        await _flushUntil(
            tester, () async => !(await tester.runAsync(source.exists))!);
        expect(await tester.runAsync(source.exists), isFalse);
      }
      expect(harness.documentCloses, 1);
    });
  }
}
