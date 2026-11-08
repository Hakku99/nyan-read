// Android-only functional checks. Use an isolated test APK application ID.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/controllers/reader_controller.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

import 'pdf_native_fixtures.dart';

const _viewport = Size(pdfWidth * 1.0, pdfHeight * 1.0);
const _deadline = Duration(seconds: 10);
const _sampleY = pdfHeight ~/ 2;

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final previousErrorHandler = FlutterError.onError;
  FlutterErrorDetails? frameworkError;
  FlutterError.onError = (details) {
    frameworkError ??= details;
    previousErrorHandler?.call(details);
  };
  try {
    if (!Platform.isAndroid) throw StateError('An Android device is required.');
    final directory = await Directory.systemTemp.createTemp('nyan-pdf-native-');
    final reader = _Reader();
    try {
      final path = directory.path;
      await Isolate.run(() => writePdfFixtures(path));
      await reader.preferences.initialize();
      await reader.preferences.setPageTurnMode(PageTurnMode.tap);
      runApp(MaterialApp(home: reader.build()));
      await binding.endOfFrame;
      for (final fixture in PdfFixture.values) {
        await reader.open(path, fixture);
        await reader.checkSettled(fixture, 1);
        await reader.turn(fixture, 2);
        await reader.turn(fixture, 1);
        if (fixture == PdfFixture.multipleImages) {
          await reader.zoom(fixture);
          await reader.close();
          await reader.open(path, fixture);
          await reader.checkSettled(fixture, 1);
        }
        await reader.close();
        if (frameworkError case final error?) throw error.exception;
        debugPrint('NYAN_PDF_NATIVE OK ${fixture.name}');
      }
    } finally {
      await reader.close();
      runApp(const SizedBox.shrink());
      await binding.endOfFrame;
      reader.dispose();
      await directory.delete(recursive: true);
    }
    if (frameworkError case final error?) throw error.exception;
    debugPrint('NYAN_PDF_NATIVE PASS');
  } catch (error, stack) {
    debugPrint('NYAN_PDF_NATIVE FAIL $error\n$stack');
  } finally {
    FlutterError.onError = previousErrorHandler;
  }
}

final class _Reader {
  final preferences = ReaderPreferencesService();
  final _active = ValueNotifier<ReaderController?>(null);
  final _screen = GlobalKey();
  final _live = GlobalKey();
  final _smooth = GlobalKey<SmoothPageReaderState>();
  ReaderController get _controller => _active.value!;
  WidgetsBinding get _binding => WidgetsBinding.instance;

  Widget build() => Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: _viewport,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: _viewport),
                child: RepaintBoundary(
                  key: _screen,
                  child: ValueListenableBuilder<ReaderController?>(
                    valueListenable: _active,
                    builder: (_, reader, __) => reader == null
                        ? const SizedBox.shrink()
                        : SmoothPageReader(
                            key: _smooth,
                            snapshotIncoming: false,
                            onPreviousTap: () {},
                            onNextTap: () {},
                            onCenterTap: () {},
                            child: RepaintBoundary(
                              key: _live,
                              child:
                                  Builder(builder: reader.engine.buildReader),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> open(String directory, PdfFixture fixture) async {
    final reader = ReaderController(
      Book(
        id: 'native-pdf-${fixture.name}',
        title: fixture.name,
        author: '',
        filePath: '$directory/${fixture.name}.pdf',
        format: 'pdf',
      ),
      readerPreferencesService: preferences,
      databaseService: DatabaseService(),
    );
    _active.value = reader;
    await reader.engine.initialize();
    final request = PageTurnRequest();
    try {
      await _waitForOpen(reader, request).timeout(_deadline);
    } finally {
      request.cancel();
    }
  }

  Future<void> _waitForOpen(
      ReaderController reader, PageTurnRequest request) async {
    while (!await reader.waitForPagePresentation(request)) {
      request.checkActive();
    }
    // pdfx keeps the document loader mounted through its opening fade.
    while (_containsLoader(_live.currentContext! as Element)) {
      await request.wait(_binding.endOfFrame);
    }
  }

  Future<void> close() async {
    final reader = _active.value;
    if (reader == null) return;
    _active.value = null;
    await _binding.endOfFrame;
    reader.dispose();
    await _binding.endOfFrame;
  }

  void dispose() {
    preferences.dispose();
    _active.dispose();
  }

  Future<void> turn(PdfFixture fixture, int page) async {
    final request = PageTurnRequest();
    final smooth = _smooth.currentState!;
    final before = _controller.currentPosition?.pageNumber;
    final forward = page > before!;
    ({ui.Image image, int x})? first;
    var observing = true;
    void observe(Duration _) {
      if (!observing || !smooth.isAnimating) return;
      final dx =
          _box(_live).localToGlobal(Offset.zero, ancestor: _box(_screen)).dx;
      // The first complete target pixel can be at the viewport edge.
      final x = forward ? dx.ceil() : (pdfWidth + dx).floor() - 1;
      if (dx != 0 && x >= 0 && x < pdfWidth) {
        first = (image: _box(_screen).toImageSync(), x: x);
      } else {
        _binding.addPostFrameCallback(observe);
      }
    }

    _binding.addPostFrameCallback(observe);
    try {
      await smooth
          .playTurn(
            forward: forward,
            request: request,
            didMove: () => _controller.currentPosition?.pageNumber != before,
            dispatchTurn: () => forward
                ? _controller.nextPage(request: request)
                : _controller.previousPage(request: request),
            readyIncludesPaint: _controller.pageReadinessIncludesPaint,
            waitForReady: () => _controller.waitForPagePresentation(request),
          )
          .timeout(_deadline);
      final captured = first;
      if (captured == null) {
        throw StateError('${fixture.name} page $page never animated.');
      }
      final colors = fixture.pages[page - 1];
      _expectPixel(
          await _pixels(captured.image),
          captured.x,
          _sampleY,
          forward ? colors.left : colors.right,
          '${fixture.name} page $page first visible frame');
    } finally {
      observing = false;
      request.cancel();
      first?.image.dispose();
    }
    await checkSettled(fixture, page);
  }

  Future<void> checkSettled(PdfFixture fixture, int page) async {
    _expectPage(page);
    final colors = fixture.pages[page - 1];
    final pixels = await _readScreen();
    final context = '${fixture.name} page $page';
    _expectPixel(pixels, 48, _sampleY, colors.left, '$context left image');
    _expectPixel(pixels, 208, _sampleY, colors.right, '$context right image');
    _expectPixel(pixels, 136, _sampleY, colors.center, '$context center');
    _expectPixel(pixels, 128, 80, colors.marker, '$context top marker');
  }

  Future<void> zoom(PdfFixture fixture) async {
    const probeX = 88;
    final colors = fixture.pages.first;
    _expectPixel(
        await _readScreen(), probeX, _sampleY, colors.left, 'before zoom');
    final origin = _box(_screen).localToGlobal(Offset.zero);
    final center = origin + _viewport.center(Offset.zero);
    const initialSpan = 28.0;
    final gestures = GestureBinding.instance;
    for (final side in [-1, 1]) {
      gestures.handlePointerEvent(PointerDownEvent(
          pointer: side + 10,
          position: center + Offset(initialSpan * side, 0)));
    }
    var span = initialSpan;
    for (final nextSpan in [42.0, 63.0, 84.0]) {
      for (final side in [-1, 1]) {
        gestures.handlePointerEvent(PointerMoveEvent(
          pointer: side + 10,
          position: center + Offset(nextSpan * side, 0),
          delta: Offset((nextSpan - span) * side, 0),
        ));
      }
      span = nextSpan;
      await _binding.endOfFrame;
    }
    for (final side in [-1, 1]) {
      gestures.handlePointerEvent(PointerUpEvent(
          pointer: side + 10, position: center + Offset(span * side, 0)));
    }
    _expectPage(1);
    _expectPixel(
        await _readScreen(), probeX, _sampleY, colors.center, 'zoomed gutter');
  }

  void _expectPage(int expected) {
    final actual = _controller.currentPosition?.pageNumber;
    if (actual != expected) {
      throw StateError('Expected page $expected, got $actual.');
    }
  }

  Future<ByteData> _readScreen() async {
    await _binding.endOfFrame;
    final boundary = _box(_screen);
    if (boundary.size != _viewport) {
      throw StateError(
          'The device must fit the $pdfWidth×$pdfHeight test view.');
    }
    final image = await boundary.toImage();
    try {
      return await _pixels(image);
    } finally {
      image.dispose();
    }
  }
}

RenderRepaintBoundary _box(GlobalKey key) =>
    key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

Future<ByteData> _pixels(ui.Image image) async => (await image.toByteData())!;

bool _containsLoader(Element element) {
  if (element.widget is CircularProgressIndicator) return true;
  var found = false;
  element.visitChildren((child) {
    if (!found) found = _containsLoader(child);
  });
  return found;
}

void _expectPixel(ByteData pixels, int x, int y, int rgb, String stage) {
  final offset = (y * pdfWidth + x) * 4;
  final actual = List.generate(3, (i) => pixels.getUint8(offset + i));
  final expected = [rgb >> 16, (rgb >> 8) & 255, rgb & 255];
  for (var i = 0; i < expected.length; i++) {
    // The embedded images and the native page output use JPEG.
    if ((actual[i] - expected[i]).abs() > 14 ||
        pixels.getUint8(offset + 3) != 255) {
      throw StateError('$stage at ($x, $y): expected $expected, got $actual.');
    }
  }
}
