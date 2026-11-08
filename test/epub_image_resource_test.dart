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
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

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
}

enum _ImageFailure { missing, ambiguous, corrupt }

Future<File> _writeBook({
  required Map<String, Uint8List> images,
  String aSrc = 'fig.png',
  String bSrc = 'fig.png',
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
    final after = List.generate(
        _chapterLength - 2,
        (i) =>
            '<p>${chapter.key} paragraph $i with enough text to occupy a line.</p>');
    add(
        'OEBPS/${chapter.key}/ch.xhtml',
        '<html><body><h2>Chapter ${chapter.key}</h2><img src="${chapter.value}"/>'
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

Future<EpubReaderEngine> _mount(WidgetTester tester, File file,
    {ReadingPosition? saved,
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
  tester.view.physicalSize = const Size(360, 240);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
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

Future<void> _expectImage(WidgetTester tester, ReaderEngine engine, int index,
    Size expected, int red) async {
  final painted = _paintedImage(index);
  await _show(tester, engine, index, painted);
  final bitmap = tester.widget<RawImage>(painted).image!;
  expect(Size(bitmap.width.toDouble(), bitmap.height.toDouble()), expected);
  final pixels = await tester.runAsync(bitmap.toByteData);
  expect(pixels!.getUint8(0), red);
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
