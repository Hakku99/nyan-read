import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart';

import 'baseline_support.dart';

void main() {
  final path = Platform.environment['NYAN_BASELINE_EPUB'];
  if (path == null) throw StateError('Provide the authorized EPUB sample.');
  setUpAll(() async {
    final loader = FontLoader(NyanTypography.uiFontFamily);
    loader.addFont(File('assets/fonts/subset/NotoSansSC-Regular.ttf')
        .readAsBytes()
        .then(ByteData.sublistView));
    await loader.load();
  });
  testWidgets('external EPUB image reflow and fresh-engine restore',
      (tester) async {
    debugPrint('IMAGE_SAMPLE font ready');
    final index = await tester.runAsync(() => compute(_imageIndex, path));
    debugPrint('IMAGE_SAMPLE parsed');
    final engines = <EpubReaderEngine>[];
    tester.view.physicalSize = baselineViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final engine in engines) {
        engine.dispose();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Future<void> settleImages() async {
      // Image extraction/decoding cannot run on the fake widget-test clock.
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        if (find.byType(Image).evaluate().isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      throw StateError('Image scene did not settle');
    }

    Future<EpubReaderEngine> mount(Book book) async {
      final engine = EpubReaderEngine(book);
      engines.add(engine);
      await tester.runAsync(engine.initialize);
      engine.setConfig(baselineConfig(PageTurnMode.tap));
      await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: engine.buildReader)));
      return engine;
    }

    final book = Book(
        id: 'image-reflow',
        title: 'Sample',
        author: '',
        filePath: path,
        format: 'epub');
    final engine = await mount(book);
    debugPrint('IMAGE_SAMPLE mounted');
    // Move directly while initial asynchronous images are still loading.
    final navigation = engine.jumpToChapterStart(index!);
    await settleImages();
    await perform(tester, () => navigation);
    debugPrint('IMAGE_SAMPLE settled');
    final anchor = engine.getCurrentPosition()!;
    expect(anchor.textOffset, isNotNull);
    engine.setConfig(baselineConfig(PageTurnMode.tap, fontSize: 24));
    await settleImages();
    expect(engine.getCurrentPosition()!.paragraphIndex, anchor.paragraphIndex);
    expect(engine.getCurrentPosition()!.textOffset, anchor.textOffset);
    engine.setConfig(baselineConfig(PageTurnMode.tap));
    await settleImages();
    expectSameViewport(anchor, engine.getCurrentPosition()!);
    debugPrint('IMAGE_SAMPLE reflow passed');
    final saved = engine.getCurrentPosition()!;
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
    engines.remove(engine);
    final reopened = await mount(Book(
        id: book.id,
        title: book.title,
        author: '',
        filePath: path,
        format: 'epub',
        lastPositionType: 'epub',
        lastPositionPayload: saved.toJson()));
    await settleImages();
    expectSameViewport(saved, reopened.getCurrentPosition()!);
    expect(tester.takeException(), isNull);
  });
}

Future<int> _imageIndex(String path) async {
  final parsed = await parseEpubFileInIsolate(path);
  for (var i = 1000; i < parsed.paragraphCount; i++) {
    if (parsed.paragraphKinds[i] == EpubParagraphKind.image) return i - 2;
  }
  throw StateError('Missing image scene');
}
