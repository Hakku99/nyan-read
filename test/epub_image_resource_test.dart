import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../tool/reader_baseline/baseline_support.dart';

const _mode = PageTurnMode.tap;
const _chapterLength = 26;

void main() {
  for (final reverse in [false, true]) {
    testWidgets('same image href stays chapter-local (reverse ZIP: $reverse)',
        (tester) async {
      final a = _png(width: 80, height: 48, red: 240);
      final b = _png(width: 140, height: 96, red: 40);
      final images = {
        'OEBPS/A/fig.png': a,
        'OEBPS/B/fig.png': b,
      };
      final file = (await tester.runAsync(() => _writeBook(
          images: Map.fromEntries(
              reverse ? images.entries.toList().reversed : images.entries))))!;
      final engine = await _mount(tester, file);
      final chapters = await engine.getChapters();
      expect(chapters.map((chapter) => chapter.locator.contentIndex),
          [0, _chapterLength]);
      await _expectImage(tester, engine, 1, const Size(80, 48), 240);
      await _expectImage(
          tester, engine, _chapterLength + 1, const Size(140, 96), 40);
      await _expectImage(tester, engine, 1, const Size(80, 48), 240);
    });
  }

  for (final failure in _ImageFailure.values) {
    testWidgets('${failure.name} image keeps its slot and the other chapter',
        (tester) async {
      final valid = _png(width: 140, height: 96, red: 40);
      final file = (await tester.runAsync(() => _writeBook(images: {
            if (failure == _ImageFailure.ambiguous) ...{
              'OEBPS/A/FIG.PNG': valid,
              'OEBPS/A/Fig.png': valid,
            },
            if (failure == _ImageFailure.corrupt)
              'OEBPS/A/fig.png': Uint8List.fromList([1, 2, 3]),
            'OEBPS/B/fig.png': valid,
          })))!;
      final engine = await _mount(tester, file);
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      await _show(
          tester,
          engine,
          1,
          find.descendant(
              of: _imageRow(1),
              matching: find.text(
                  l10n.readerImageLoadFailed(l10n.readerImageDefaultAlt))));
      expect(engine.getCurrentPosition()!.paragraphIndex, 1);
      expect(engine.getParagraphText(2), startsWith('A paragraph 0'));
      await _expectImage(
          tester, engine, _chapterLength + 1, const Size(140, 96), 40);
    });
  }

  testWidgets('equivalent hrefs share one full-path cache entry',
      (tester) async {
    final image = _png(width: 80, height: 48, red: 240);
    final file = (await tester.runAsync(() => _writeBook(
        images: {'OEBPS/A/fig.png': image},
        bSrc: '../A/./fig.png?rev=1#view')))!;
    final loads = <String>[];
    final engine = await _mount(tester, file, loader: (_, entryPath) async {
      loads.add(entryPath);
      return image;
    });
    await _expectImage(tester, engine, 1, const Size(80, 48), 240);
    await _expectImage(
        tester, engine, _chapterLength + 1, const Size(80, 48), 240);
    expect(loads, ['OEBPS/A/fig.png']);
  });

  testWidgets('legacy saved index reopens on the chapter-local image',
      (tester) async {
    const index = _chapterLength + 1;
    final file = (await tester.runAsync(() => _writeBook(
          images: {
            'OEBPS/A/fig.png': _png(width: 80, height: 48, red: 240),
            'OEBPS/B/fig#one.png': _png(width: 140, height: 96, red: 40),
          },
          bSrc: 'fig%23one.png?rev=1#view',
        )))!;
    final engine = await _mount(tester, file,
        saved: ReadingPosition.fromJson(
            'epub', '{"paragraphIndex":$index,"enumVersion":2}'));
    final painted = _paintedImage(index);
    for (var frame = 0; frame < 100 && painted.evaluate().isEmpty; frame++) {
      await _tick(tester);
    }
    expect(painted, findsOneWidget);
    expect(tester.widget<RawImage>(painted).image!.height, 96);
    expect(engine.getCurrentPosition()!.paragraphIndex, index);
  });

  testWidgets('first turn into a complex EPUB waits for newly visible images',
      (tester) async {
    const viewport = Size(360, 180);
    const lead = _chapterLength + 1;
    const plate = lead + 1;
    const detail = plate + 3;
    const platePath = 'OEBPS/B/fig.png';
    const detailPath = 'OEBPS/B/detail.png';
    final book = await _complexBook(tester);
    final plateGate = Completer<void>();
    final detailGate = Completer<void>();
    final loads = <String>[];
    addTearDown(() {
      if (!plateGate.isCompleted) plateGate.complete();
      if (!detailGate.isCompleted) detailGate.complete();
    });
    final engine = await _mount(tester, book, viewport: viewport,
        loader: (path, entry) async {
      loads.add(entry);
      if (entry == platePath) await plateGate.future;
      if (entry == detailPath) await detailGate.future;
      return extractEpubImageBytesFromFile(path, entry);
    });
    // Warm the same basename in chapter A before first decoding chapter B.
    await _expectImage(tester, engine, 2, const Size(300, 600), 240);
    await _positionBeforeImage(tester, engine, lead, viewport, 8);
    final before = engine.getCurrentPosition()!;
    await _completeNavigation(tester, engine.nextPage());
    _recordImageRows(tester, 'after-turn-before-decode', [plate, detail]);
    expect(visibleItems(tester).map((item) => item.index), contains(plate));
    expect(visibleItems(tester).map((item) => item.index),
        isNot(contains(detail)));
    expect(_paintedImage(plate), findsNothing);

    final request = PageTurnRequest();
    addTearDown(request.cancel);
    bool? ready;
    final presentation = engine.waitForPagePresentation(request).then((value) {
      ready = value;
    });
    await tester.pump();
    expect(ready, isNull);
    plateGate.complete();
    try {
      await _waitForFrames(
          tester,
          () => _paintedImage(plate).evaluate().isNotEmpty,
          'The first image must paint after its decode is released.');
    } finally {
      _recordImageRows(tester, 'after-first-paint-check', [plate, detail]);
    }
    try {
      await _waitForFrames(
          tester,
          () => visibleItems(tester).any((item) => item.index == detail),
          'The second image must enter the viewport after the first shrinks.');
    } finally {
      _recordImageRows(
          tester, 'after-second-visibility-check', [plate, detail]);
    }
    for (var frame = 0; frame < 4; frame++) {
      await _tick(tester);
    }
    expect(ready, isNull,
        reason: 'The second image is visible but still cold.');
    expect(_paintedImage(detail), findsNothing);
    final accepted = engine.getCurrentPosition()!;

    detailGate.complete();
    await _waitForFrames(tester, () => ready != null,
        'The target should become ready after both visible images paint.');
    await presentation;
    expect(ready, isTrue);
    _recordImageRows(tester, 'both-images-ready', [plate, detail]);
    await _expectBitmap(tester, plate, const Size(48, 24), 40);
    await _expectBitmap(tester, detail, const Size(96, 72), 120);
    expect(loads.where((entry) => entry == platePath), [platePath]);
    expect(loads.where((entry) => entry == detailPath), [detailPath]);
    _expectViewport(accepted, engine.getCurrentPosition()!, viewport);
    await perform(tester, engine.previousPage);
    _expectViewport(before, engine.getCurrentPosition()!, viewport);
  });

  testWidgets(
      'clipped image reflows, turns back and restores from legacy edges',
      (tester) async {
    const portrait = Size(360, 640);
    const landscape = Size(640, 360);
    const lead = 1;
    const image = 2;
    final book = await _complexBook(tester);
    var oldEngineDisposed = false;
    void disposeOldEngine(EpubReaderEngine engine) {
      if (oldEngineDisposed) return;
      oldEngineDisposed = true;
      engine.dispose();
    }

    final engine = await _mount(tester, book,
        viewport: portrait, disposeEngine: disposeOldEngine);
    await _expectImage(tester, engine, image, const Size(300, 600), 240);
    // Make a real portrait turn into the clipped figure, leaving history to
    // invalidate when the viewport changes.
    await _positionBeforeImage(tester, engine, lead, portrait, -270);
    await perform(tester, engine.nextPage);
    final saved = engine.getCurrentPosition()!;
    expect(saved.paragraphIndex, image);
    expect(saved.textOffset, isNull);
    final fraction = _imageFraction(tester, image);
    expect(fraction, inExclusiveRange(0.55, 0.75));
    final leading = saved.paragraphLeadingEdge!;
    final trailing = saved.paragraphTrailingEdge!;
    final legacy = ReadingPosition.fromJson(
        'epub',
        '{"paragraphIndex":$image,"paragraphLeadingEdge":$leading,'
            '"paragraphTrailingEdge":$trailing}');

    tester.view.physicalSize = landscape;
    await tester.pumpAndSettle();
    final reflowed = engine.getCurrentPosition()!;
    expect(reflowed.paragraphIndex, image);
    expect(_imageFraction(tester, image), closeTo(fraction, .015));

    await perform(tester, engine.previousPage);
    expect(engine.getCurrentPosition()!.paragraphIndex, lead);
    final previous =
        visibleItems(tester).singleWhere((row) => row.index == image);
    expect(previous.itemLeadingEdge, inExclusiveRange(0, .30),
        reason: 'A landscape back turn must not reuse the portrait step.');
    await perform(tester, engine.nextPage);
    _expectViewport(reflowed, engine.getCurrentPosition()!, landscape);

    await tester.pumpWidget(const SizedBox.shrink());
    disposeOldEngine(engine);
    final reopened =
        await _mount(tester, book, saved: legacy, viewport: landscape);
    await _waitForFrames(
        tester,
        () => _paintedImage(image).evaluate().isNotEmpty,
        'A fresh engine must decode the saved chapter image.');
    await tester.pumpAndSettle();
    await _expectBitmap(tester, image, const Size(300, 600), 240);
    _expectViewport(reflowed, reopened.getCurrentPosition()!, landscape);
    expect(_imageFraction(tester, image), closeTo(fraction, .015));
  });
}

enum _ImageFailure { missing, ambiguous, corrupt }

Future<File> _writeBook({
  required Map<String, Uint8List> images,
  String aSrc = 'fig.png',
  String bSrc = 'fig.png',
  bool complex = false,
}) async {
  final file = await writeFixture('epub', []);
  final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
  void add(String path, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('content.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Image fixture</dc:title>
  </metadata>
  <manifest>
    <item id="a" href="OEBPS/A/ch.xhtml" media-type="application/xhtml+xml"/>
    <item id="b" href="OEBPS/B/ch.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="a"/><itemref idref="b"/></spine>
</package>
''');
  for (final chapter in {'A': aSrc, 'B': bSrc}.entries) {
    final lead = complex
        ? '<p>${'A long passage before the next figure. ' * 36}</p>'
        : '';
    final image = '<img src="${chapter.value}"/>';
    final figure = complex
        ? '<figure>$image<figcaption>Plate ${chapter.key}</figcaption></figure>'
        : image;
    // With the caption and heading between the images, a cold placeholder
    // keeps the detail out of view and the decoded plate brings it into view.
    final extra = complex && chapter.key == 'B'
        ? '<h3>Detail</h3><img src="detail.png"/>'
        : '';
    final after = List.generate(
        _chapterLength - (complex ? 4 : 2),
        (i) =>
            '<p>${chapter.key} paragraph $i with enough text to occupy a line.</p>');
    add(
        'OEBPS/${chapter.key}/ch.xhtml',
        '<html><body><h2>Chapter ${chapter.key}</h2>$lead$figure$extra'
            '${after.join()}</body></html>');
  }
  for (final image in images.entries) {
    archive.addFile(ArchiveFile(image.key, image.value.length, image.value));
  }
  return file.writeAsBytes(ZipEncoder().encode(archive));
}

Uint8List _png({required int width, required int height, required int red}) =>
    img.encodePng(img.Image(width: width, height: height)
      ..clear(img.ColorRgb8(red, 20, 40)));

Future<File> _complexBook(WidgetTester tester) async =>
    (await tester.runAsync(() => _writeBook(complex: true, images: {
          'OEBPS/A/fig.png': _png(width: 300, height: 600, red: 240),
          'OEBPS/B/fig.png': _png(width: 48, height: 24, red: 40),
          'OEBPS/B/detail.png': _png(width: 96, height: 72, red: 120),
        })))!;

Future<EpubReaderEngine> _mount(WidgetTester tester, File file,
    {ReadingPosition? saved,
    Size viewport = const Size(360, 240),
    void Function(EpubReaderEngine)? disposeEngine,
    Future<Uint8List?> Function(String, String)? loader}) async {
  final book = Book(
      id: 'image-paths',
      title: 'Image fixture',
      author: '',
      filePath: file.path,
      format: 'epub',
      lastPositionType: saved == null ? null : 'epub',
      lastPositionPayload: saved?.toJson());
  final engine = loader == null
      ? EpubReaderEngine(book)
      : EpubReaderEngine.withImageLoader(book, loader);
  await tester.runAsync(engine.initialize);
  engine.setConfig(baselineConfig(_mode));
  if (saved == null) {
    await engine.goToPosition(const ReadingPosition(paragraphIndex: 14));
  }
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (disposeEngine == null) {
      engine.dispose();
    } else {
      disposeEngine(engine);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: engine.buildReader)),
  ));
  return engine;
}

Finder _imageRow(int index) => find.byWidgetPredicate((widget) =>
    widget is SizeChangedLayoutNotifier &&
    widget.child?.key == ValueKey(index));

void _recordImageRows(WidgetTester tester, String stage, List<int> indices) {
  final viewport = tester.getRect(find.byType(ScrollablePositionedList));
  final visible = visibleItems(tester).map((row) => row.index).toSet();
  final geometry = {
    'stage': stage,
    'viewportHeight': viewport.height,
    'rows': [
      for (final index in indices)
        {
          'index': index,
          'visible': visible.contains(index),
          'painted': _paintedImage(index).evaluate().isNotEmpty,
          'mountedBounds': [
            for (var i = 0; i < _imageRow(index).evaluate().length; i++)
              _verticalBounds(
                  tester.getRect(_imageRow(index).at(i)), viewport.top),
          ],
        },
    ],
  };
  debugPrint('EPUB_IMAGE_ROWS ${jsonEncode(geometry)}');
}

Map<String, double> _verticalBounds(Rect bounds, double origin) => {
      'top': bounds.top - origin,
      'bottom': bounds.bottom - origin,
    };

Future<void> _expectImage(WidgetTester tester, ReaderEngine engine, int index,
    Size expected, int red) async {
  await _show(tester, engine, index, _paintedImage(index));
  await _expectBitmap(tester, index, expected, red);
}

Future<void> _expectBitmap(
    WidgetTester tester, int index, Size expected, int red) async {
  final painted = _paintedImage(index);
  expect(painted, findsOneWidget);
  final bitmap = tester.widget<RawImage>(painted).image!;
  expect(Size(bitmap.width.toDouble(), bitmap.height.toDouble()), expected);
  final pixels = await tester.runAsync(bitmap.toByteData);
  expect(pixels!.getUint8(0), red);
}

Future<void> _positionBeforeImage(WidgetTester tester, EpubReaderEngine engine,
    int lead, Size viewport, double imageTopAfterTurn) async {
  await _completeNavigation(
      tester, engine.goToPosition(ReadingPosition(paragraphIndex: lead)));
  final row = visibleItems(tester).singleWhere((item) => item.index == lead);
  final extent = row.itemTrailingEdge - row.itemLeadingEdge;
  // Place the figure's top at a chosen edge after one normal 92% page step.
  final clipped = extent - 0.92 - imageTopAfterTurn / viewport.height;
  expect(clipped, greaterThan(0));
  await _completeNavigation(
      tester,
      engine.goToPosition(ReadingPosition(
          paragraphIndex: lead,
          paragraphLeadingEdge: -clipped,
          paragraphTrailingEdge: extent - clipped)));
}

Future<void> _completeNavigation(
    WidgetTester tester, Future<void> navigation) async {
  var finished = false;
  final observed = navigation.whenComplete(() => finished = true);
  // Cold placeholders animate until decode, so pump only until navigation ends.
  await _waitForFrames(tester, () => finished, 'Navigation did not settle.');
  await observed;
}

Future<void> _waitForFrames(
    WidgetTester tester, bool Function() condition, String reason) async {
  for (var frame = 0; frame < 100 && !condition(); frame++) {
    await _tick(tester);
  }
  expect(condition(), isTrue, reason: reason);
}

double _imageFraction(WidgetTester tester, int index) {
  final row = visibleItems(tester).singleWhere((item) => item.index == index);
  expect(row.itemLeadingEdge, lessThan(0));
  return -row.itemLeadingEdge / (row.itemTrailingEdge - row.itemLeadingEdge);
}

void _expectViewport(
    ReadingPosition expected, ReadingPosition actual, Size viewport) {
  expect(actual.paragraphIndex, expected.paragraphIndex);
  expect(actual.paragraphLeadingEdge,
      closeTo(expected.paragraphLeadingEdge!, 2 / viewport.height));
}

Finder _paintedImage(int index) => find.descendant(
    of: _imageRow(index),
    matching: find.byWidgetPredicate(
        (widget) => widget is RawImage && widget.image != null));

Future<void> _show(
    WidgetTester tester, ReaderEngine engine, int index, Finder target) async {
  var settled = false;
  final navigation = engine
      .goToPosition(ReadingPosition(paragraphIndex: index))
      .whenComplete(() => settled = true);
  for (var frame = 0;
      frame < 100 && (!settled || target.evaluate().isEmpty);
      frame++) {
    await _tick(tester);
  }
  expect(settled, isTrue);
  expect(target, findsOneWidget);
  await navigation;
}

Future<void> _tick(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  await tester.pump(const Duration(milliseconds: 16));
}
