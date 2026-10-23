import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const baselineViewport = Size(360, 640);

ReaderConfig baselineConfig(PageTurnMode mode, {double fontSize = 18}) =>
    ReaderConfig(
      backgroundColor: const Color(0xFFF6F3EA),
      textColor: const Color(0xFF3F3A34),
      fontSize: fontSize,
      lineHeight: 1.5,
      pageTurnMode: mode,
    );

List<String> baselineParagraphs({bool oversized = false}) => List.generate(
      100,
      (index) => oversized && index == 20
          ? 'A deliberately long paragraph preserves every word while turning. ' *
              20
          : 'A normal paragraph with enough words to span several text lines. ' *
              2,
    );

Future<File> writeFixture(String format, List<String> paragraphs) async {
  final directory = await Directory.systemTemp.createTemp('nyan_baseline_');
  final file = File('${directory.path}/fixture.$format');
  addTearDown(() async {
    await file.delete();
    await directory.delete();
  });
  if (format == 'txt') return file.writeAsString(paragraphs.join('\n'));
  final archive = Archive();
  void add(String name, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('mimetype', 'application/epub+zip');
  add('META-INF/container.xml', '''<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
<rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''');
  add('content.opf', '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">baseline</dc:identifier><dc:title>Baseline</dc:title><dc:language>en</dc:language></metadata>
<manifest><item id="body" href="body.xhtml" media-type="application/xhtml+xml"/></manifest>
<spine><itemref idref="body"/></spine></package>''');
  add(
      'body.xhtml',
      '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
          '${paragraphs.map((p) => '<p>${const HtmlEscape().convert(p)}</p>').join()}'
          '</body></html>');
  return file.writeAsBytes(ZipEncoder().encode(archive));
}

Future<ReaderEngine> mountFixture(
  WidgetTester tester,
  String format,
  PageTurnMode mode, {
  bool oversized = false,
  String? path,
  int initialIndex = 20,
  ReadingPosition? beforeAttachPosition,
}) async {
  final file = path == null
      ? await tester.runAsync(
          () => writeFixture(format, baselineParagraphs(oversized: oversized)))
      : File(path);
  final book = Book(
      id: 'baseline',
      title: 'Baseline',
      author: '',
      filePath: file!.path,
      format: format);
  final ReaderEngine engine =
      format == 'txt' ? TxtReaderEngine(book) : EpubReaderEngine(book);
  await tester.runAsync(engine.initialize);
  engine.setConfig(baselineConfig(mode));
  tester.view.physicalSize = baselineViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  if (beforeAttachPosition != null) {
    await engine.goToPosition(beforeAttachPosition);
  }
  await pumpReader(tester, engine, mode);
  if (beforeAttachPosition == null) {
    await perform(
        tester,
        () =>
            engine.goToPosition(ReadingPosition(paragraphIndex: initialIndex)));
  }
  return engine;
}

Future<void> pumpReader(
    WidgetTester tester, ReaderEngine engine, PageTurnMode mode) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: (context) {
      final body = engine.buildReader(context);
      return SmoothPageReader(
          enabled: mode == PageTurnMode.tap,
          onPreviousTap: () {},
          onNextTap: () {},
          onCenterTap: () {},
          child: body);
    })),
  ));
  await tester.pumpAndSettle();
}

// Animated scrollTo and EPUB's settle timer require frames while their Future
// is pending. Awaiting first deadlocks widget tests, including on Windows.
Future<void> perform(
    WidgetTester tester, Future<void> Function() action) async {
  var completed = false;
  Object? failure;
  StackTrace? trace;
  final future = action().then<void>((_) {
    completed = true;
  }, onError: (Object e, StackTrace s) {
    failure = e;
    trace = s;
    completed = true;
  });
  for (var frame = 0; frame < 500 && !completed; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (!completed) {
    throw StateError('Navigation did not complete within 8 simulated seconds');
  }
  await future;
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  await tester.pumpAndSettle();
}

List<ItemPosition> visibleItems(WidgetTester tester) {
  final list = tester
      .widget<ScrollablePositionedList>(find.byType(ScrollablePositionedList));
  final items = list.itemPositionsNotifier!.itemPositions.value
      .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
      .toList();
  items.sort((a, b) => a.index.compareTo(b.index));
  return items;
}

void record(String scenario, ReaderEngine engine) {
  // Only geometry is recorded; never output source paths or book contents.
  debugPrint('BASELINE ${jsonEncode({
        'scenario': scenario,
        'position': engine.getCurrentPosition()?.toJson()
      })}');
}

bool advanced(ReadingPosition before, ReadingPosition after) =>
    after.paragraphIndex! > before.paragraphIndex! ||
    (after.paragraphIndex == before.paragraphIndex &&
        after.paragraphLeadingEdge! < before.paragraphLeadingEdge! - 0.005);

void expectSameViewport(ReadingPosition expected, ReadingPosition actual) {
  expect(actual.paragraphIndex, expected.paragraphIndex);
  // Two logical pixels allow raster rounding without accepting a lost line.
  expect(actual.paragraphLeadingEdge,
      closeTo(expected.paragraphLeadingEdge!, 2 / baselineViewport.height));
}
